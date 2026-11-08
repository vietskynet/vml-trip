-- Thương Xá Tắc: mua vật phẩm Limited của người chơi khác (chạy 1 lần trong SQL Editor)
-- Tin rao nằm ở market/<người bán>/<lid> = {lim:1,item,price,name,nm}. Hàm này chuyển món từ túi người bán
-- sang túi người mua, ghi lịch sử + số lượng cả hai bên, xoá tin rao, báo tiền cho người bán (gifts).
create or replace function public.rt_lim_pick(arr jsonb, it text) returns int
language sql immutable as $$
  select (e.ord - 1)::int from jsonb_array_elements_text(
    case jsonb_typeof(arr) when 'array' then arr when 'object' then (select coalesce(jsonb_agg(value), '[]'::jsonb) from jsonb_each(arr)) else '[]'::jsonb end
  ) with ordinality as e(v, ord) where e.v = it order by e.ord limit 1 $$;

create or replace function public.rt_lim_buy(seller uuid, lid text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare b uuid := auth.uid(); t bigint := public.now_ms(); L jsonb; it text; ty text; pr bigint; sdoc jsonb; bdoc jsonb;
        sa jsonb; ba jsonb; ix int; sbag jsonb; bbag jsonb; nm text; money numeric; cnt int; sg int; bg int; hs jsonb; hb jsonb;
begin
  if b is null then raise exception 'Chưa đăng nhập'; end if;
  if b = seller then return jsonb_build_object('ok', false, 'msg', 'Đây là hàng của bạn.'); end if;
  perform pg_advisory_xact_lock(hashtext('market/' || seller::text));
  select r.val -> lid into L from public.rtdb r where r.path = 'market/' || seller::text;
  if L is null or jsonb_typeof(L) <> 'object' or coalesce(L ->> 'lim', '') <> '1' then return jsonb_build_object('ok', false, 'msg', 'Món này vừa được bán hoặc huỷ.'); end if;
  it := L ->> 'item'; pr := floor((L ->> 'price')::numeric);
  ty := case when it ~ '^lo[0-9]+$' then 'o' when it ~ '^lp[0-9]+$' then 'p' else null end;
  if ty is null or pr is null or pr < 10000 or pr > 2000000000 then return jsonb_build_object('ok', false, 'msg', 'Tin rao không hợp lệ.'); end if;
  -- khoá 2 hồ sơ theo thứ tự cố định để tránh kẹt
  perform pg_advisory_xact_lock(hashtext('players/' || least(seller::text, b::text)));
  perform pg_advisory_xact_lock(hashtext('players/' || greatest(seller::text, b::text)));
  select r.val into sdoc from public.rtdb r where r.path = 'players/' || seller::text;
  select r.val into bdoc from public.rtdb r where r.path = 'players/' || b::text;
  if bdoc is null then return jsonb_build_object('ok', false, 'msg', 'Chưa có hồ sơ người chơi.'); end if;
  money := coalesce((bdoc #>> '{state,money}')::numeric, 0);
  if money < pr then return jsonb_build_object('ok', false, 'msg', 'Chưa đủ tiền.'); end if;
  sbag := coalesce(sdoc -> 'bag', '{}'::jsonb); bbag := coalesce(bdoc -> 'bag', '{}'::jsonb);
  sa := coalesce(sbag -> ty, '[]'::jsonb); ba := coalesce(bbag -> ty, '[]'::jsonb);
  if jsonb_typeof(sa) = 'object' then sa := (select coalesce(jsonb_agg(value), '[]'::jsonb) from jsonb_each(sa)); end if;
  if jsonb_typeof(ba) = 'object' then ba := (select coalesce(jsonb_agg(value), '[]'::jsonb) from jsonb_each(ba)); end if;
  ix := public.rt_lim_pick(sa, it);
  if ix is null then
    update public.rtdb set val = nullif(val - lid, '{}'::jsonb), upd = t where path = 'market/' || seller::text;
    return jsonb_build_object('ok', false, 'msg', 'Người bán không còn giữ món này.');
  end if;
  select count(*) into cnt from (
    select 1 from jsonb_array_elements(coalesce(case jsonb_typeof(bbag -> 'o') when 'array' then bbag -> 'o' else '[]'::jsonb end, '[]'::jsonb))
    union all select 1 from jsonb_array_elements(coalesce(case jsonb_typeof(bbag -> 'p') when 'array' then bbag -> 'p' else '[]'::jsonb end, '[]'::jsonb))) q;
  if cnt >= 40 then return jsonb_build_object('ok', false, 'msg', 'Túi Thần Kỳ của bạn đã đầy.'); end if;
  sa := (select coalesce(jsonb_agg(e.v order by e.ord), '[]'::jsonb) from jsonb_array_elements(sa) with ordinality as e(v, ord) where e.ord - 1 <> ix);
  ba := ba || to_jsonb(it);
  -- số lượng đã nhận + lịch sử (giữ 60 dòng gần nhất)
  bg := coalesce((bbag #>> array['g', it])::int, 0) + 1;
  hb := coalesce(case jsonb_typeof(bbag -> 'h') when 'array' then bbag -> 'h' else '[]'::jsonb end, '[]'::jsonb) || jsonb_build_array(jsonb_build_array(t, it, 'buy:' || pr));
  hs := coalesce(case jsonb_typeof(sbag -> 'h') when 'array' then sbag -> 'h' else '[]'::jsonb end, '[]'::jsonb) || jsonb_build_array(jsonb_build_array(t, it, 'sold:' || pr));
  if jsonb_array_length(hb) > 60 then hb := (select jsonb_agg(v) from (select v from jsonb_array_elements(hb) with ordinality as e(v, o) order by o desc limit 60) z); end if;
  if jsonb_array_length(hs) > 60 then hs := (select jsonb_agg(v) from (select v from jsonb_array_elements(hs) with ordinality as e(v, o) order by o desc limit 60) z); end if;
  sbag := jsonb_set(jsonb_set(sbag, array[ty], sa, true), '{h}', hs, true);
  bbag := jsonb_set(jsonb_set(jsonb_set(bbag, array[ty], ba, true), array['g', it], to_jsonb(bg), true), '{h}', hb, true);
  update public.rtdb set val = jsonb_set(coalesce(sdoc, '{}'::jsonb), '{bag}', sbag, true), upd = t where path = 'players/' || seller::text;
  update public.rtdb set val = jsonb_set(bdoc, '{bag}', bbag, true), upd = t where path = 'players/' || b::text;
  update public.rtdb set val = nullif(val - lid, '{}'::jsonb), upd = t where path = 'market/' || seller::text;
  nm := coalesce(bdoc ->> 'name', 'Ai đó');
  insert into public.rtdb(path, val, upd)
    values ('gifts/' || seller::text, jsonb_build_object('m' || t, jsonb_build_object('amount', pr, 'ts', t, 'from', b::text, 'fromName', nm, 'market', true, 'what', coalesce(L ->> 'nm', 'vật phẩm Limited'))), t)
    on conflict (path) do update set val = coalesce(public.rtdb.val, '{}'::jsonb) || excluded.val, upd = excluded.upd;
  return jsonb_build_object('ok', true, 'price', pr, 'item', it);
end $$;

revoke all on function public.rt_lim_buy(uuid, text), public.rt_lim_pick(jsonb, text) from public, anon;
grant execute on function public.rt_lim_buy(uuid, text) to authenticated;

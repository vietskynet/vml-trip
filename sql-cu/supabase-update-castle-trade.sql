drop function if exists public.rt_castle_reserve(int);
-- Cập nhật 09.11.2026: LÂU ĐÀI, bán/trả chỗ.
-- Luật mới: người chơi bán chỗ lâu đài cho người khác (giống bán villa), hoặc trả chỗ và mất 30% giá đã trả.
-- Bỏ luật bỏ phiếu thoát. Chạy 1 lần trong Supabase > SQL Editor. Chạy lại nhiều lần cũng không sao. Không xoá dữ liệu.
-- Yêu cầu: đã chạy supabase-update-castle.sql trước.

-- 1) Đặt chỗ có ghi giá đã trả (pp) để tính hoàn tiền khi trả chỗ
create or replace function public.rt_castle_reserve(tw int, price bigint) returns jsonb
language plpgsql security definer set search_path = public as $$
declare u text := auth.uid()::text; t bigint := public.now_ms(); dv jsonb; k int; nm text; cnt int;
begin
  if auth.uid() is null then raise exception 'Chưa đăng nhập'; end if;
  if tw is null or tw < 0 or tw > 4 then return jsonb_build_object('ok', false, 'msg', 'Tháp không hợp lệ.'); end if;
  perform pg_advisory_xact_lock(hashtext('castle'));
  perform pg_advisory_xact_lock(hashtext('castle/' || tw));
  if public.rt_bedcount(u) >= 6 then return jsonb_build_object('ok', false, 'msg', 'Bạn đã đủ 6 giường. Bán hoặc trả bớt giường trước.'); end if;
  select val into dv from public.rtdb where path = 'castle/' || tw;
  dv := coalesce(dv, '{}'::jsonb);
  if dv ->> 'done' is not null then return jsonb_build_object('ok', false, 'msg', 'Tháp này đã đủ 3 người.'); end if;
  if exists (select 1 from jsonb_each_text(case when jsonb_typeof(dv -> 's') = 'object' then dv -> 's' else '{}'::jsonb end) b where b.value = u) then
    return jsonb_build_object('ok', false, 'msg', 'Mỗi người chỉ được 1 chỗ trong mỗi tháp.'); end if;
  k := null;
  for i in 0..2 loop
    if coalesce(dv #>> array['s', i::text], '') = '' then k := i; exit; end if;
  end loop;
  if k is null then return jsonb_build_object('ok', false, 'msg', 'Tháp đã đủ người đặt.'); end if;
  select coalesce(r.val ->> 'name', 'Ai đó') into nm from public.rtdb r where r.path = 'players/' || u;
  if jsonb_typeof(dv -> 's') is distinct from 'object' then dv := dv || '{"s":{}}'::jsonb; end if;
  if jsonb_typeof(dv -> 'n') is distinct from 'object' then dv := dv || '{"n":{}}'::jsonb; end if;
  if jsonb_typeof(dv -> 'pp') is distinct from 'object' then dv := dv || '{"pp":{}}'::jsonb; end if;
  dv := jsonb_set(dv, array['s', k::text], to_jsonb(u));
  dv := jsonb_set(dv, array['n', k::text], to_jsonb(coalesce(nm, 'Ai đó')));
  dv := jsonb_set(dv, array['pp', k::text], to_jsonb(greatest(0, least(coalesce(price, 0), 1000000000))));
  select count(*) into cnt from jsonb_each_text(dv -> 's') b where b.value <> '';
  if cnt >= 3 then dv := dv || jsonb_build_object('done', t); end if;
  insert into public.rtdb(path, val, upd) values ('castle/' || tw, dv, t)
    on conflict (path) do update set val = excluded.val, upd = excluded.upd;
  return jsonb_build_object('ok', true, 'k', k, 'done', cnt >= 3);
end $$;

-- 2) Trả chỗ: rời tháp bất kỳ lúc nào. Trả về giá đã trả để máy khách hoàn 70% (nếu tháp đã đủ người) hoặc 100% (chưa đủ người).
create or replace function public.rt_castle_return(tw int) returns jsonb
language plpgsql security definer set search_path = public as $$
declare u text := auth.uid()::text; t bigint := public.now_ms(); dv jsonb; k text; wasdone boolean; paid numeric; rest int;
begin
  if auth.uid() is null then raise exception 'Chưa đăng nhập'; end if;
  perform pg_advisory_xact_lock(hashtext('castle'));
  select val into dv from public.rtdb where path = 'castle/' || tw;
  if dv is null then return jsonb_build_object('ok', false, 'msg', 'Bạn không có chỗ ở tháp này.'); end if;
  select b.key into k from jsonb_each_text(case when jsonb_typeof(dv -> 's') = 'object' then dv -> 's' else '{}'::jsonb end) b where b.value = u limit 1;
  if k is null then return jsonb_build_object('ok', false, 'msg', 'Bạn không có chỗ ở tháp này.'); end if;
  wasdone := dv ->> 'done' is not null;
  paid := nullif(dv #>> array['pp', k], '')::numeric;
  dv := dv #- array['s', k] #- array['n', k] #- array['pp', k] #- array['lv'] #- array['done'];
  select count(*) into rest from jsonb_each_text(case when jsonb_typeof(dv -> 's') = 'object' then dv -> 's' else '{}'::jsonb end) b where b.value <> '';
  if rest = 0 then
    update public.rtdb set val = null, upd = t where path = 'castle/' || tw;
    update public.rtdb set val = nullif(val - tw::text, '{}'::jsonb), upd = t where path = 'deco/castle' and val is not null;
  else
    update public.rtdb set val = dv, upd = t where path = 'castle/' || tw;
  end if;
  return jsonb_build_object('ok', true, 'wasdone', wasdone, 'paid', paid);
end $$;

-- 3) Bán chỗ: người bán đồng ý một đề nghị mua (offers/<người bán>/<oid>) của người khác. Máy chủ kiểm lại đề nghị.
create or replace function public.rt_castle_transfer(tw int, k int, oid text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare u text := auth.uid()::text; t bigint := public.now_ms(); dv jsonb; od jsonb; buyer text; price numeric; nm text; cur text;
begin
  if auth.uid() is null then raise exception 'Chưa đăng nhập'; end if;
  perform pg_advisory_xact_lock(hashtext('castle'));
  perform pg_advisory_xact_lock(hashtext('castle/' || tw));
  select val -> oid into od from public.rtdb where path = 'offers/' || u;
  if od is null or jsonb_typeof(od) <> 'object' then return jsonb_build_object('ok', false, 'msg', 'Không thấy đề nghị mua.'); end if;
  if od ->> 'type' is distinct from 'castle' or (od ->> 'i')::int is distinct from tw or (od ->> 'k')::int is distinct from k
     or od ->> 'status' is distinct from 'pending' then return jsonb_build_object('ok', false, 'msg', 'Đề nghị không hợp lệ.'); end if;
  if abs(t - coalesce((od ->> 'ts')::bigint, 0)) > 90000 then return jsonb_build_object('ok', false, 'msg', 'Đề nghị đã hết hạn.'); end if;
  buyer := od ->> 'from'; price := (od ->> 'price')::numeric;
  if buyer is null or buyer = u or price is null or price <= 0 or price > 1000000000 then return jsonb_build_object('ok', false, 'msg', 'Đề nghị không hợp lệ.'); end if;
  select val into dv from public.rtdb where path = 'castle/' || tw;
  if dv is null or coalesce(dv #>> array['s', k::text], '') <> u then return jsonb_build_object('ok', false, 'msg', 'Bạn không còn giữ chỗ này.'); end if;
  if exists (select 1 from jsonb_each_text(case when jsonb_typeof(dv -> 's') = 'object' then dv -> 's' else '{}'::jsonb end) b where b.value = buyer) then
    return jsonb_build_object('ok', false, 'msg', 'Người mua đã có chỗ trong tháp này.'); end if;
  if public.rt_bedcount(buyer) >= 6 then return jsonb_build_object('ok', false, 'msg', 'Người mua đã đủ 6 giường.'); end if;
  select coalesce(r.val ->> 'name', 'Ai đó') into nm from public.rtdb r where r.path = 'players/' || buyer;
  if jsonb_typeof(dv -> 'n') is distinct from 'object' then dv := dv || '{"n":{}}'::jsonb; end if;
  if jsonb_typeof(dv -> 'pp') is distinct from 'object' then dv := dv || '{"pp":{}}'::jsonb; end if;
  dv := jsonb_set(dv, array['s', k::text], to_jsonb(buyer));
  dv := jsonb_set(dv, array['n', k::text], to_jsonb(coalesce(nm, 'Ai đó')));
  dv := jsonb_set(dv, array['pp', k::text], to_jsonb(price));
  dv := dv #- array['lv'];
  update public.rtdb set val = dv, upd = t where path = 'castle/' || tw;
  return jsonb_build_object('ok', true, 'price', price);
end $$;

revoke all on function public.rt_castle_reserve(int, bigint), public.rt_castle_return(int), public.rt_castle_transfer(int, int, text) from public, anon;
grant execute on function public.rt_castle_reserve(int, bigint), public.rt_castle_return(int), public.rt_castle_transfer(int, int, text) to authenticated;

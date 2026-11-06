-- Cập nhật 06.11.2026: LÂU ĐÀI TÌNH BÁO (đặt chỗ 3 người, liên minh, thoát nhóm, trang trí tháp)
-- Chạy 1 lần trong Supabase > SQL Editor. Chạy lại nhiều lần cũng không sao. Không xoá dữ liệu cũ.

-- 8e. Lâu Đài Tình Báo: đặt chỗ 3 người, liên minh, thoát nhóm ---------------
-- Chỗ lâu đài tính là 1 giường trong giới hạn 6 giường
create or replace function public.rt_bedcount(u text) returns int
language sql stable security definer set search_path = public as $$
  select (select count(*)::int from public.rtdb r,
    jsonb_each(case when jsonb_typeof(r.val) = 'object' then r.val else '{}'::jsonb end) a,
    jsonb_each_text(case when jsonb_typeof(a.value) = 'object' then a.value else '{}'::jsonb end) b
    where r.path like 'beds/%' and b.value = u)
  + (select count(*)::int from public.rtdb r,
    jsonb_each_text(case when jsonb_typeof(r.val -> 's') = 'object' then r.val -> 's' else '{}'::jsonb end) b
    where r.path like 'castle/%' and b.value = u)
$$;

create or replace function public.rt_castle_find(u text) returns text
language sql stable security definer set search_path = public as $$
  select substr(r.path, 8) from public.rtdb r,
    jsonb_each_text(case when jsonb_typeof(r.val -> 's') = 'object' then r.val -> 's' else '{}'::jsonb end) b
  where r.path like 'castle/%' and b.value = u limit 1
$$;

create or replace function public.rt_castle_member(u text, tw text) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.rtdb r,
    jsonb_each_text(case when jsonb_typeof(r.val -> 's') = 'object' then r.val -> 's' else '{}'::jsonb end) b
    where r.path = 'castle/' || tw and (r.val ->> 'done') is not null and b.value = u)
$$;

create or replace function public.rt_castle_reserve(tw int) returns jsonb
language plpgsql security definer set search_path = public as $$
declare u text := auth.uid()::text; t bigint := public.now_ms(); dv jsonb; k int; nm text; cnt int;
begin
  if auth.uid() is null then raise exception 'Chưa đăng nhập'; end if;
  if tw is null or tw < 0 or tw > 4 then return jsonb_build_object('ok', false, 'msg', 'Tháp không hợp lệ.'); end if;
  perform pg_advisory_xact_lock(hashtext('castle'));
  perform pg_advisory_xact_lock(hashtext('castle/' || tw));
  if public.rt_castle_find(u) is not null then return jsonb_build_object('ok', false, 'msg', 'Bạn đã có chỗ trong lâu đài rồi.'); end if;
  if public.rt_bedcount(u) >= 6 then return jsonb_build_object('ok', false, 'msg', 'Bạn đã đủ 6 giường. Bán hoặc trả bớt giường trước.'); end if;
  select val into dv from public.rtdb where path = 'castle/' || tw;
  dv := coalesce(dv, '{}'::jsonb);
  if dv ->> 'done' is not null then return jsonb_build_object('ok', false, 'msg', 'Tháp này đã có liên minh ở.'); end if;
  k := null;
  for i in 0..2 loop
    if coalesce(dv #>> array['s', i::text], '') = '' then k := i; exit; end if;
  end loop;
  if k is null then return jsonb_build_object('ok', false, 'msg', 'Tháp đã đủ người đặt.'); end if;
  select coalesce(r.val ->> 'name', 'Ai đó') into nm from public.rtdb r where r.path = 'players/' || u;
  if jsonb_typeof(dv -> 's') is distinct from 'object' then dv := dv || '{"s":{}}'::jsonb; end if;
  if jsonb_typeof(dv -> 'n') is distinct from 'object' then dv := dv || '{"n":{}}'::jsonb; end if;
  dv := jsonb_set(dv, array['s', k::text], to_jsonb(u));
  dv := jsonb_set(dv, array['n', k::text], to_jsonb(coalesce(nm, 'Ai đó')));
  select count(*) into cnt from jsonb_each_text(dv -> 's') b where b.value <> '';
  if cnt >= 3 then dv := dv || jsonb_build_object('done', t); end if;
  insert into public.rtdb(path, val, upd) values ('castle/' || tw, dv, t)
    on conflict (path) do update set val = excluded.val, upd = excluded.upd;
  return jsonb_build_object('ok', true, 'k', k, 'done', cnt >= 3);
end $$;

create or replace function public.rt_castle_cancel(tw int) returns jsonb
language plpgsql security definer set search_path = public as $$
declare u text := auth.uid()::text; t bigint := public.now_ms(); dv jsonb; k text;
begin
  if auth.uid() is null then raise exception 'Chưa đăng nhập'; end if;
  perform pg_advisory_xact_lock(hashtext('castle'));
  select val into dv from public.rtdb where path = 'castle/' || tw;
  if dv is null then return jsonb_build_object('ok', false, 'msg', 'Bạn không có chỗ ở tháp này.'); end if;
  if dv ->> 'done' is not null then return jsonb_build_object('ok', false, 'msg', 'Liên minh đã thành lập, không huỷ được. Muốn rời thì bỏ phiếu thoát.'); end if;
  select b.key into k from jsonb_each_text(case when jsonb_typeof(dv -> 's') = 'object' then dv -> 's' else '{}'::jsonb end) b where b.value = u limit 1;
  if k is null then return jsonb_build_object('ok', false, 'msg', 'Bạn không có chỗ ở tháp này.'); end if;
  dv := dv #- array['s', k] #- array['n', k];
  if coalesce(dv -> 's', '{}'::jsonb) = '{}'::jsonb then dv := null; end if;
  update public.rtdb set val = dv, upd = t where path = 'castle/' || tw;
  return jsonb_build_object('ok', true);
end $$;

create or replace function public.rt_castle_leave(tw int, vote boolean) returns jsonb
language plpgsql security definer set search_path = public as $$
declare u text := auth.uid()::text; t bigint := public.now_ms(); dv jsonb; k text; n int;
begin
  if auth.uid() is null then raise exception 'Chưa đăng nhập'; end if;
  perform pg_advisory_xact_lock(hashtext('castle'));
  select val into dv from public.rtdb where path = 'castle/' || tw;
  if dv is null or dv ->> 'done' is null then return jsonb_build_object('ok', false, 'msg', 'Tháp này chưa có liên minh.'); end if;
  select b.key into k from jsonb_each_text(case when jsonb_typeof(dv -> 's') = 'object' then dv -> 's' else '{}'::jsonb end) b where b.value = u limit 1;
  if k is null then return jsonb_build_object('ok', false, 'msg', 'Bạn không ở trong liên minh này.'); end if;
  if jsonb_typeof(dv -> 'lv') is distinct from 'object' then dv := dv || '{"lv":{}}'::jsonb; end if;
  if vote then dv := jsonb_set(dv, array['lv', k], 'true'::jsonb); else dv := dv #- array['lv', k]; end if;
  select count(*) into n from jsonb_each(dv -> 'lv');
  if n >= 2 then
    update public.rtdb set val = null, upd = t where path = 'castle/' || tw;
    update public.rtdb set val = nullif(val - tw::text, '{}'::jsonb), upd = t where path = 'deco/castle' and val is not null;
    return jsonb_build_object('ok', true, 'evicted', true, 'votes', n);
  end if;
  update public.rtdb set val = dv, upd = t where path = 'castle/' || tw;
  return jsonb_build_object('ok', true, 'evicted', false, 'votes', n);
end $$;

revoke all on function public.rt_castle_find(text), public.rt_castle_member(text, text), public.rt_castle_reserve(int),
  public.rt_castle_cancel(int), public.rt_castle_leave(int, boolean) from public, anon;
grant execute on function public.rt_castle_reserve(int), public.rt_castle_cancel(int), public.rt_castle_leave(int, boolean) to authenticated;

create or replace function public.rt_can(path text, cur jsonb, nv jsonb, docv jsonb) returns boolean
language plpgsql stable security definer set search_path = public as $$
declare s text[] := string_to_array(trim(both '/' from path), '/'); u text := auth.uid()::text; n int;
begin
  if auth.uid() is null then return false; end if;
  if public.is_admin() then return true; end if;
  n := coalesce(array_length(s, 1), 0);
  if n < 2 then return false; end if;
  if s[1] = 'players' then return s[2] = u; end if;
  if s[1] = 'beds' then                                    -- nhận giường trống (tối đa 6) / trả hoặc nhường giường của mình
    return n = 4 and ((cur is null and nv is not null and nv #>> '{}' = u and public.rt_bedcount(u) < 6)
                   or (cur is not null and cur #>> '{}' = u));
  end if;
  if s[1] = 'offers' then
    if s[2] = u then return true; end if;
    if n = 2 then return false; end if;
    return (cur is null and nv is not null and nv ->> 'from' = u)
        or (cur is not null and jsonb_typeof(cur) = 'object' and cur ->> 'from' = u)
        or (n > 3 and docv #>> array[s[3], 'from'] = u);
  end if;
  if s[1] = 'invites' then return n >= 3; end if;
  if s[1] = 'duels' then return docv is null or docv ->> 'a' = u or docv ->> 'b' = u; end if;
  if s[1] = 'gifts' then
    return n = 3 and s[2] <> u and cur is null and nv is not null and nv ->> 'from' = u and (nv ->> 'amount')::numeric > 0;
  end if;
  if s[1] = 'market' then return s[2] = u; end if;          -- chỉ đăng/huỷ tin rao của mình
  if s[1] = 'deco' then                                     -- ai có giường trong căn đó mới được trang trí
    if s[2] = 'castle' then return n = 4 and s[4] in ('top', 'base', 'plate') and public.rt_castle_member(u, s[3]); end if;
    return n = 4 and ((s[2] in ('villa', 'tent') and s[4] in ('g1', 'g2', 'top', 'door', 'plate'))
                   or (s[2] = 'room' and s[4] in ('bal', 'win', 'plate'))) and public.rt_owns(u, s[2], s[3]);
  end if;
  return false;
end $$;

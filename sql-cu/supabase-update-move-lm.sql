-- Sửa lỗi: đăng nhập / nhập mã đồng bộ trên máy khác làm mất liên minh.
-- rt_move_player trước đây chuyển giường, đấu, lâu đài nhưng KHÔNG chuyển liên minh (lm/*).
-- Chạy file này 1 lần trong Supabase SQL Editor (cần đã có rt_move_player từ supabase-update-accounts.sql).
create or replace function public.rt_move_player(o uuid, n uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare t bigint := public.now_ms(); pv jsonb;
begin
  perform pg_advisory_xact_lock(hashtext('rt_claim'));
  select val into pv from public.rtdb where path = 'players/' || o;
  if pv is null then return jsonb_build_object('ok', false, 'msg', 'Nhân vật của tài khoản này không còn.'); end if;
  update public.rtdb set val = replace(val::text, '"' || n::text || '"', 'null')::jsonb, upd = t
    where path like 'beds/%' and val is not null and val::text like '%' || n::text || '%';
  update public.rtdb set val = replace(val::text, o::text, n::text)::jsonb, upd = t
    where (path like 'beds/%' or path like 'duels/%' or path like 'castle/%' or path like 'lm/%') and val is not null and val::text like '%' || o::text || '%';
  insert into public.rtdb(path, val, upd) values ('players/' || n, pv, t)
    on conflict (path) do update set val = excluded.val, upd = excluded.upd;
  update public.rtdb set val = null, upd = t where path = 'players/' || o;
  insert into public.rtdb(path, val, upd)
    select 'gifts/' || n, val, t from public.rtdb where path = 'gifts/' || o and val is not null
    on conflict (path) do update set val = coalesce(public.rtdb.val, '{}'::jsonb) || excluded.val, upd = excluded.upd;
  update public.rtdb set val = null, upd = t where path = 'gifts/' || o;
  delete from public.pos where uid = o;
  delete from public.sync_codes where uid = n;
  update public.sync_codes set uid = n where sync_codes.uid = o;
  update public.accounts set uid = n where accounts.uid = o;
  update public.money_log set uid = n where money_log.uid = o;
  if exists (select 1 from public.admins where uid = o) then insert into public.admins(uid) values (n) on conflict do nothing; end if;
  return jsonb_build_object('ok', true);
end $$;
revoke all on function public.rt_move_player(uuid, uuid) from public, anon, authenticated;

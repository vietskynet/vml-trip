-- ================================================================
-- VML Trip: Admin xem username / đổi mật khẩu người chơi + lịch sử tiền
-- Chạy 1 lần trong Supabase SQL Editor (sau supabase-update-accounts.sql). Chạy lại an toàn.
-- ================================================================

create table if not exists public.money_log (
  id bigserial primary key,
  uid uuid not null,
  t bigint not null,
  d bigint not null,
  bal bigint not null,
  reason text not null default ''
);
create index if not exists money_log_uid_idx on public.money_log(uid, id desc);
alter table public.money_log enable row level security;

-- Nhân vật chuyển sang máy khác (đăng nhập / mã đồng bộ): lịch sử đi theo
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
    where (path like 'beds/%' or path like 'duels/%' or path like 'castle/%') and val is not null and val::text like '%' || o::text || '%';
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

-- Máy người chơi gửi lô giao dịch tiền (tối đa 60 dòng / lần, giữ 1500 dòng gần nhất)
create or replace function public.rt_mlog(entries jsonb) returns int
language plpgsql security definer set search_path = public as $$
declare e jsonb; k int := 0; u uuid := auth.uid(); cutoff bigint;
begin
  if u is null then raise exception 'Chưa đăng nhập'; end if;
  if jsonb_typeof(entries) <> 'array' then return 0; end if;
  for e in select value from jsonb_array_elements(entries) limit 60 loop
    insert into public.money_log(uid, t, d, bal, reason)
      values (u, coalesce((e ->> 't')::numeric, 0)::bigint, coalesce((e ->> 'd')::numeric, 0)::bigint,
              coalesce((e ->> 'b')::numeric, 0)::bigint, left(coalesce(e ->> 'r', ''), 120));
    k := k + 1;
  end loop;
  select id into cutoff from public.money_log where uid = u order by id desc offset 1500 limit 1;
  if cutoff is not null then delete from public.money_log where uid = u and id <= cutoff; end if;
  return k;
end $$;

-- Admin: danh sách username theo uid
create or replace function public.admin_accounts_list() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'Không có quyền'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('uid', a.uid, 'user', a.username)) from public.accounts a), '[]'::jsonb);
end $$;

-- Admin: đổi mật khẩu cho một người chơi
create or replace function public.admin_set_password(target uuid, newp text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare s text := replace(gen_random_uuid()::text, '-', ''); u text;
begin
  if not public.is_admin() then raise exception 'Không có quyền'; end if;
  if length(coalesce(newp, '')) < 6 or length(newp) > 64 then return jsonb_build_object('ok', false, 'msg', 'Mật khẩu dài 6-64 ký tự.'); end if;
  select username into u from public.accounts where uid = target;
  if u is null then return jsonb_build_object('ok', false, 'msg', 'Người chơi này chưa có tài khoản.'); end if;
  update public.accounts set salt = s, hash = public.admin_hash(newp, s), fails = 0, lock_until = 0 where username = u;
  delete from public.account_tokens where username = u;
  return jsonb_build_object('ok', true, 'user', u);
end $$;

-- Admin: lịch sử tiền vào / ra của một người chơi (mới nhất trước)
create or replace function public.admin_mlog(target uuid, lim int default 400) returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'Không có quyền'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id', x.id, 't', x.t, 'd', x.d, 'b', x.bal, 'r', x.reason) order by x.id desc)
    from (select * from public.money_log where uid = target order by id desc limit least(greatest(coalesce(lim, 400), 1), 1500)) x), '[]'::jsonb);
end $$;

revoke all on function public.rt_move_player(uuid, uuid) from public, anon, authenticated;
revoke all on function public.rt_mlog(jsonb), public.admin_accounts_list(), public.admin_set_password(uuid, text), public.admin_mlog(uuid, int) from public, anon;
grant execute on function public.rt_mlog(jsonb), public.admin_accounts_list(), public.admin_set_password(uuid, text), public.admin_mlog(uuid, int) to authenticated;

notify pgrst, 'reload schema';

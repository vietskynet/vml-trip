-- ================================================================
-- VML Trip: Tài khoản người chơi (username + mật khẩu)
-- Chạy 1 lần trong Supabase SQL Editor. An toàn khi chạy lại.
-- Không đụng tới dữ liệu người chơi hiện có.
-- ================================================================

create table if not exists public.accounts (
  username text primary key,
  uid uuid not null unique,
  salt text not null,
  hash text not null,
  fails int not null default 0,
  lock_until bigint not null default 0,
  created bigint not null default 0
);
alter table public.accounts enable row level security;

create table if not exists public.account_tokens (
  th text primary key,
  username text not null references public.accounts(username) on delete cascade,
  created bigint not null default 0
);
alter table public.account_tokens enable row level security;

-- Chuyển toàn bộ nhân vật từ uid cũ (o) sang uid của máy này (n)
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
  if exists (select 1 from public.admins where uid = o) then insert into public.admins(uid) values (n) on conflict do nothing; end if;
  return jsonb_build_object('ok', true);
end $$;

-- rt_claim (mã đồng bộ) dùng chung hàm chuyển nhân vật
create or replace function public.rt_claim(code text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare o uuid; n uuid := auth.uid();
        c text := upper(regexp_replace(coalesce(code, ''), '[^0-9A-Za-z]', '', 'g'));
begin
  if n is null then raise exception 'Chưa đăng nhập'; end if;
  perform pg_sleep(0.3);
  select s.uid into o from public.sync_codes s where s.code = c;
  if o is null then return jsonb_build_object('ok', false, 'msg', 'Mã không đúng. Kiểm tra lại nhé.'); end if;
  if o = n then return jsonb_build_object('ok', true, 'same', true); end if;
  return public.rt_move_player(o, n);
end $$;

create or replace function public.acc_new_token(u text) returns text
language plpgsql security definer set search_path = public as $$
declare tk text := replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', '');
begin
  insert into public.account_tokens(th, username, created) values (encode(sha256(convert_to(tk, 'UTF8')), 'hex'), u, public.now_ms());
  delete from public.account_tokens where username = u and th not in
    (select th from public.account_tokens where username = u order by created desc limit 8);
  return tk;
end $$;

-- Tài khoản của máy này (nếu có)
create or replace function public.acc_status() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare a public.accounts;
begin
  if auth.uid() is null then raise exception 'Chưa đăng nhập'; end if;
  select * into a from public.accounts where accounts.uid = auth.uid();
  if not found then return jsonb_build_object('has', false); end if;
  return jsonb_build_object('has', true, 'user', a.username);
end $$;

-- Tạo tài khoản cho nhân vật hiện tại
create or replace function public.acc_register(u_name text, p_word text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare u text := lower(trim(coalesce(u_name, ''))); s text := replace(gen_random_uuid()::text, '-', '');
begin
  if auth.uid() is null then raise exception 'Chưa đăng nhập'; end if;
  if u !~ '^[a-z0-9_.]{4,16}$' then return jsonb_build_object('ok', false, 'msg', 'Username dài 4-16 ký tự, chỉ gồm chữ không dấu, số, dấu _ hoặc dấu chấm.'); end if;
  if length(coalesce(p_word, '')) < 6 or length(p_word) > 64 then return jsonb_build_object('ok', false, 'msg', 'Mật khẩu dài 6-64 ký tự.'); end if;
  if exists (select 1 from public.accounts where accounts.uid = auth.uid()) then return jsonb_build_object('ok', false, 'msg', 'Máy này đã có tài khoản rồi.'); end if;
  if exists (select 1 from public.admin_accounts where admin_accounts.username = u) then return jsonb_build_object('ok', false, 'msg', 'Username này đã có người dùng.'); end if;
  perform pg_advisory_xact_lock(hashtext('acc_register'));
  if exists (select 1 from public.accounts where accounts.username = u) then return jsonb_build_object('ok', false, 'msg', 'Username này đã có người dùng. Chọn tên khác nhé.'); end if;
  insert into public.accounts(username, uid, salt, hash, created) values (u, auth.uid(), s, public.admin_hash(p_word, s), public.now_ms());
  return jsonb_build_object('ok', true, 'user', u, 'token', public.acc_new_token(u));
end $$;

-- Đăng nhập trên máy mới: nhân vật của tài khoản được chuyển về máy này
create or replace function public.acc_login(u_name text, p_word text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare u text := lower(trim(coalesce(u_name, ''))); a public.accounts; n uuid := auth.uid(); t bigint := public.now_ms(); r jsonb; mine text;
begin
  if n is null then raise exception 'Chưa đăng nhập'; end if;
  perform pg_sleep(0.4);
  select * into a from public.accounts where accounts.username = u;
  if not found then return jsonb_build_object('ok', false, 'msg', 'Sai username hoặc mật khẩu.'); end if;
  if a.lock_until > t then return jsonb_build_object('ok', false, 'msg', 'Nhập sai nhiều lần. Thử lại sau ' || ceil((a.lock_until - t) / 60000.0)::int || ' phút.'); end if;
  if public.admin_hash(p_word, a.salt) <> a.hash then
    update public.accounts set lock_until = case when accounts.fails + 1 >= 6 then t + 300000 else accounts.lock_until end,
      fails = case when accounts.fails + 1 >= 6 then 0 else accounts.fails + 1 end where accounts.username = u;
    return jsonb_build_object('ok', false, 'msg', 'Sai username hoặc mật khẩu.');
  end if;
  update public.accounts set fails = 0, lock_until = 0 where accounts.username = u;
  if a.uid = n then return jsonb_build_object('ok', true, 'user', u, 'same', true, 'token', public.acc_new_token(u)); end if;
  select accounts.username into mine from public.accounts where accounts.uid = n;
  if mine is not null then return jsonb_build_object('ok', false, 'msg', 'Máy này đang đăng nhập tài khoản "' || mine || '". Đăng xuất trước đã.'); end if;
  r := public.rt_move_player(a.uid, n);
  if not (r ->> 'ok')::boolean then return r; end if;
  return jsonb_build_object('ok', true, 'user', u, 'token', public.acc_new_token(u));
end $$;

-- Đăng nhập tự động bằng cookie khi phiên ẩn danh của máy bị mất
create or replace function public.acc_resume(tk text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare a public.accounts; n uuid := auth.uid(); r jsonb;
begin
  if n is null then raise exception 'Chưa đăng nhập'; end if;
  select accounts.* into a from public.account_tokens k join public.accounts on accounts.username = k.username
    where k.th = encode(sha256(convert_to(coalesce(tk, ''), 'UTF8')), 'hex');
  if not found then return jsonb_build_object('ok', false); end if;
  if a.uid = n then return jsonb_build_object('ok', true, 'user', a.username); end if;
  if exists (select 1 from public.accounts where accounts.uid = n) then return jsonb_build_object('ok', false); end if;
  r := public.rt_move_player(a.uid, n);
  if not (r ->> 'ok')::boolean then return r; end if;
  return jsonb_build_object('ok', true, 'user', a.username, 'moved', true);
end $$;

create or replace function public.acc_logout(tk text) returns boolean
language sql security definer set search_path = public as $$
  delete from public.account_tokens where th = encode(sha256(convert_to(coalesce(tk, ''), 'UTF8')), 'hex') returning true
$$;

-- Xoá tài khoản của máy này (dùng khi tạo nhân vật mới)
create or replace function public.acc_delete() returns boolean
language sql security definer set search_path = public as $$
  delete from public.accounts where accounts.uid = auth.uid() returning true
$$;

revoke all on function public.rt_move_player(uuid, uuid), public.acc_new_token(text) from public, anon, authenticated;
revoke all on function public.rt_claim(text), public.acc_status(), public.acc_register(text, text), public.acc_login(text, text),
  public.acc_resume(text), public.acc_logout(text), public.acc_delete() from public, anon;
grant execute on function public.rt_claim(text), public.acc_status(), public.acc_register(text, text), public.acc_login(text, text),
  public.acc_resume(text), public.acc_logout(text), public.acc_delete() to authenticated;

notify pgrst, 'reload schema';

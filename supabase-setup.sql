-- =====================================================================
-- VML COMPANY TRIP · CÀI ĐẶT DATABASE SUPABASE
-- Dán toàn bộ file này vào Supabase → SQL Editor → New query → Run.
-- Chạy lại nhiều lần cũng không sao (an toàn khi chạy lặp).
-- =====================================================================

-- 1. Bảng dữ liệu --------------------------------------------------------
create table if not exists public.rtdb (
  path text primary key,          -- ví dụ: players/<id>, beds/villa, day
  val  jsonb,                     -- null = đã xoá
  upd  bigint not null default 0  -- thời điểm cập nhật (ms)
);
create index if not exists rtdb_upd_idx on public.rtdb (upd);

create unlogged table if not exists public.pos (
  uid uuid primary key,
  v   jsonb not null,
  upd bigint not null
);

create table if not exists public.admins (
  uid uuid primary key
);

-- Không ai được đọc/ghi trực tiếp các bảng; mọi thứ đi qua các hàm bên dưới.
alter table public.rtdb   enable row level security;
alter table public.pos    enable row level security;
alter table public.admins enable row level security;

-- 2. Hàm tiện ích -----------------------------------------------------------
create or replace function public.now_ms() returns bigint
language sql stable as $$ select (extract(epoch from clock_timestamp()) * 1000)::bigint $$;

create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.admins where uid = auth.uid())
$$;

-- Thay {".sv":"timestamp"} bằng giờ máy chủ
create or replace function public.rt_fixts(v jsonb) returns jsonb
language plpgsql stable as $$
declare k text; r jsonb;
begin
  if v is null or jsonb_typeof(v) <> 'object' then return v; end if;
  if v ? '.sv' then return to_jsonb(public.now_ms()); end if;
  r := '{}'::jsonb;
  for k in select jsonb_object_keys(v) loop
    r := r || jsonb_build_object(k, public.rt_fixts(v -> k));
  end loop;
  return r;
end $$;

-- Ghi giá trị vào đường dẫn lồng nhau (v = null nghĩa là xoá)
create or replace function public.rt_jset(doc jsonb, p text[], v jsonb) returns jsonb
language plpgsql immutable as $$
declare c jsonb;
begin
  if coalesce(array_length(p, 1), 0) = 0 then return v; end if;
  if v is null then
    if doc is null or jsonb_typeof(doc) <> 'object' then return doc; end if;
    if array_length(p, 1) = 1 then return doc - p[1]; end if;
    c := public.rt_jset(doc -> p[1], p[2:], null);
    if c is null or c = '{}'::jsonb then return doc - p[1]; end if;
    return doc || jsonb_build_object(p[1], c);
  end if;
  if doc is null or jsonb_typeof(doc) <> 'object' then doc := '{}'::jsonb; end if;
  return doc || jsonb_build_object(p[1], public.rt_jset(doc -> p[1], p[2:], v));
end $$;

-- Tách đường dẫn thành "tài liệu" + phần bên trong
create or replace function public.rt_split(path text, out dk text, out sub text[])
language plpgsql immutable as $$
declare s text[] := string_to_array(trim(both '/' from coalesce(path, '')), '/');
begin
  if s is null or coalesce(array_length(s, 1), 0) = 0 or s[1] = '' then dk := ''; sub := '{}'; return; end if;
  if s[1] = 'day' then dk := 'day'; sub := s[2:];
  elsif array_length(s, 1) = 1 then dk := s[1]; sub := '{}';
  else dk := s[1] || '/' || s[2]; sub := s[3:];
  end if;
end $$;

-- 3. Luật bảo mật: ai được ghi vào đâu (tối đa 6 giường, chợ nhà, trang trí) ---
create or replace function public.rt_bedcount(u text) returns int
language sql stable security definer set search_path = public as $$
  select count(*)::int from public.rtdb r,
    jsonb_each(case when jsonb_typeof(r.val) = 'object' then r.val else '{}'::jsonb end) a,
    jsonb_each_text(case when jsonb_typeof(a.value) = 'object' then a.value else '{}'::jsonb end) b
  where r.path like 'beds/%' and b.value = u
$$;

create or replace function public.rt_owns(u text, typ text, idx text) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.rtdb r,
    jsonb_each_text(case when jsonb_typeof(r.val -> idx) = 'object' then r.val -> idx else '{}'::jsonb end) b
    where r.path = 'beds/' || typ and b.value = u)
$$;

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
    return n = 4 and ((s[2] in ('villa', 'tent') and s[4] in ('g1', 'g2', 'top', 'door', 'plate'))
                   or (s[2] = 'room' and s[4] in ('bal', 'win', 'plate'))) and public.rt_owns(u, s[2], s[3]);
  end if;
  return false;
end $$;

-- Mua nhà/giường đang rao: chuyển giường + trả tiền cho người bán trong 1 bước
create or replace function public.rt_market_buy(seller uuid, lid text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare b uuid := auth.uid(); t bigint := public.now_ms(); L jsonb; ty text; ix text; k text; ks text[]; bv jsonb; pr bigint; nm text; what text;
begin
  if b is null then raise exception 'Chưa đăng nhập'; end if;
  if b = seller then return jsonb_build_object('ok', false, 'msg', 'Đây là tin rao của bạn.'); end if;
  perform pg_advisory_xact_lock(hashtext('market/' || seller::text));
  select r.val -> lid into L from public.rtdb r where r.path = 'market/' || seller::text;
  if L is null or jsonb_typeof(L) <> 'object' then return jsonb_build_object('ok', false, 'msg', 'Tin rao này không còn.'); end if;
  ks := case jsonb_typeof(L -> 'ks') when 'array' then array(select jsonb_array_elements_text(L -> 'ks')) when 'object' then array(select value from jsonb_each_text(L -> 'ks')) else string_to_array(L ->> 'ks', ',') end;
  ty := L ->> 'type'; ix := L ->> 'i'; pr := floor((L ->> 'price')::numeric);
  if ty not in ('villa', 'room', 'tent') or pr is null or pr <= 0 or coalesce(array_length(ks, 1), 0) not between 1 and 2 or not (ks <@ array['0', '1']) then return jsonb_build_object('ok', false, 'msg', 'Tin rao không hợp lệ.'); end if;
  perform pg_advisory_xact_lock(hashtext('beds/' || ty));
  select r.val into bv from public.rtdb r where r.path = 'beds/' || ty;
  foreach k in array ks loop
    if coalesce(bv #>> array[ix, k], '') <> seller::text then return jsonb_build_object('ok', false, 'msg', 'Người bán không còn giữ chỗ này.'); end if;
  end loop;
  if public.rt_bedcount(b::text) + array_length(ks, 1) > 6 then return jsonb_build_object('ok', false, 'msg', 'Mua xong sẽ quá 6 giường.'); end if;
  foreach k in array ks loop bv := public.rt_jset(bv, array[ix, k], to_jsonb(b::text)); end loop;
  update public.rtdb set val = bv, upd = t where path = 'beds/' || ty;
  update public.rtdb set val = nullif(val - lid, '{}'::jsonb), upd = t where path = 'market/' || seller::text;
  select coalesce(r.val ->> 'name', 'Ai đó') into nm from public.rtdb r where r.path = 'players/' || b::text;
  what := case ty when 'villa' then 'Villa V' || (ix::int + 1) when 'tent' then 'Bungalow B' || lpad((ix::int + 1)::text, 2, '0') else 'phòng khách sạn' end;
  insert into public.rtdb(path, val, upd)
    values ('gifts/' || seller::text, jsonb_build_object('m' || t, jsonb_build_object('amount', pr, 'ts', t, 'from', b::text, 'fromName', coalesce(nm, 'Ai đó'), 'market', true, 'what', what)), t)
    on conflict (path) do update set val = coalesce(public.rtdb.val, '{}'::jsonb) || excluded.val, upd = excluded.upd;
  return jsonb_build_object('ok', true, 'price', pr, 'type', ty, 'i', ix::int);
end $$;

revoke all on function public.rt_bedcount(text), public.rt_owns(text, text, text), public.rt_market_buy(uuid, text) from public, anon;
grant execute on function public.rt_market_buy(uuid, text) to authenticated;


-- 4. Ghi dữ liệu (nhiều đường dẫn một lần) --------------------------------
create or replace function public.rt_write(ops jsonb) returns void
language plpgsql security definer set search_path = public as $$
declare op jsonb; p text; v jsonb; dk text; sub text[]; docv jsonb; cur jsonb; newdoc jsonb; t bigint := public.now_ms();
begin
  if auth.uid() is null then raise exception 'Chưa đăng nhập'; end if;
  for op in select * from jsonb_array_elements(ops) loop
    p := op ->> 'p'; v := op -> 'v';
    if v = 'null'::jsonb then v := null; end if;
    v := public.rt_fixts(v);
    select r.dk, r.sub into dk, sub from public.rt_split(p) r;
    if dk = '' or dk = 'pos' or dk like 'pos/%' or dk like 'admins%' then continue; end if;
    perform pg_advisory_xact_lock(hashtext(dk));
    if dk not like '%/%' and dk <> 'day' then               -- cả bộ sưu tập (vd: beds) → chỉ admin
      if not public.is_admin() then raise exception 'Không có quyền ghi %', p; end if;
      update public.rtdb set val = null, upd = t where path like dk || '/%' and val is not null;
      if v is not null then
        insert into public.rtdb(path, val, upd) select dk || '/' || key, value, t from jsonb_each(v)
        on conflict (path) do update set val = excluded.val, upd = excluded.upd;
      end if;
      continue;
    end if;
    select val into docv from public.rtdb where path = dk;
    cur := case when coalesce(array_length(sub, 1), 0) = 0 then docv else docv #> sub end;
    if not public.rt_can(p, cur, v, docv) then raise exception 'Không có quyền ghi %', p; end if;
    newdoc := public.rt_jset(docv, sub, v);
    if newdoc = '{}'::jsonb then newdoc := null; end if;
    insert into public.rtdb(path, val, upd) values (dk, newdoc, t)
    on conflict (path) do update set val = excluded.val, upd = excluded.upd;
  end loop;
end $$;

-- 5. Ghi có điều kiện (chống 2 người cùng giành 1 giường) -------------------
create or replace function public.rt_cas(p text, expected jsonb, v jsonb) returns jsonb
language plpgsql security definer set search_path = public as $$
declare dk text; sub text[]; docv jsonb; cur jsonb; newdoc jsonb;
begin
  if auth.uid() is null then raise exception 'Chưa đăng nhập'; end if;
  if expected = 'null'::jsonb then expected := null; end if;
  if v = 'null'::jsonb then v := null; end if;
  v := public.rt_fixts(v);
  select r.dk, r.sub into dk, sub from public.rt_split(p) r;
  if dk = '' or dk not like '%/%' and dk <> 'day' then return jsonb_build_object('ok', false, 'denied', true); end if;
  perform pg_advisory_xact_lock(hashtext(dk));
  select val into docv from public.rtdb where path = dk;
  cur := case when coalesce(array_length(sub, 1), 0) = 0 then docv else docv #> sub end;
  if cur is distinct from expected then return jsonb_build_object('ok', false, 'cur', cur); end if;
  if not public.rt_can(p, cur, v, docv) then return jsonb_build_object('ok', false, 'cur', cur, 'denied', true); end if;
  newdoc := public.rt_jset(docv, sub, v);
  if newdoc = '{}'::jsonb then newdoc := null; end if;
  insert into public.rtdb(path, val, upd) values (dk, newdoc, public.now_ms())
  on conflict (path) do update set val = excluded.val, upd = excluded.upd;
  return jsonb_build_object('ok', true, 'cur', v);
end $$;

-- 6. Đồng bộ: lấy mọi thay đổi kể từ lần trước + vị trí người đang online ----
create or replace function public.rt_sync(since bigint) returns jsonb
language plpgsql security definer set search_path = public as $$
declare t bigint := public.now_ms();
begin
  if auth.uid() is null then raise exception 'Chưa đăng nhập'; end if;
  return jsonb_build_object(
    'now', t,
    'admin', public.is_admin(),
    'docs', coalesce((select jsonb_agg(jsonb_build_object('p', path, 'v', val)) from public.rtdb
                      where upd > since and (since > 0 or val is not null)), '[]'::jsonb),
    'pos',  coalesce((select jsonb_object_agg(uid::text, v) from public.pos where upd > t - 20000), '{}'::jsonb)
  );
end $$;

-- 7. Vị trí nhân vật (bảng tạm, không lưu lâu dài) ------------------------
create or replace function public.pos_set(v jsonb) returns void
language sql security definer set search_path = public as $$
  insert into public.pos(uid, v, upd) values (auth.uid(), v, public.now_ms())
  on conflict (uid) do update set v = excluded.v, upd = excluded.upd;
$$;
create or replace function public.pos_leave() returns void
language sql security definer set search_path = public as $$
  delete from public.pos where uid = auth.uid();
$$;

-- 8. Quyền gọi hàm: chỉ người đã đăng nhập (kể cả đăng nhập ẩn danh) -------
revoke all on function public.rt_fixts(jsonb), public.rt_jset(jsonb, text[], jsonb), public.rt_split(text),
  public.rt_can(text, jsonb, jsonb, jsonb), public.rt_write(jsonb), public.rt_cas(text, jsonb, jsonb),
  public.rt_sync(bigint), public.pos_set(jsonb), public.pos_leave(), public.is_admin(), public.now_ms() from public, anon;
grant execute on function public.rt_write(jsonb), public.rt_cas(text, jsonb, jsonb), public.rt_sync(bigint),
  public.pos_set(jsonb), public.pos_leave(), public.is_admin(), public.now_ms() to authenticated;

-- 8b. Mã đồng bộ: lấy lại nhân vật trên máy khác ---------------------------
create table if not exists public.sync_codes (
  code text primary key,
  uid  uuid not null unique
);
alter table public.sync_codes enable row level security;

create or replace function public.rt_code() returns text
language plpgsql security definer set search_path = public as $$
declare c text;
begin
  if auth.uid() is null then raise exception 'Chưa đăng nhập'; end if;
  select s.code into c from public.sync_codes s where s.uid = auth.uid();
  if c is not null then return c; end if;
  loop
    c := upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 10));
    begin
      insert into public.sync_codes(code, uid) values (c, auth.uid());
      return c;
    exception when unique_violation then
      select s.code into c from public.sync_codes s where s.uid = auth.uid();
      if c is not null then return c; end if;
    end;
  end loop;
end $$;

create or replace function public.rt_claim(code text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare o uuid; n uuid := auth.uid(); t bigint := public.now_ms(); pv jsonb;
        c text := upper(regexp_replace(coalesce(code, ''), '[^0-9A-Za-z]', '', 'g'));
begin
  if n is null then raise exception 'Chưa đăng nhập'; end if;
  perform pg_sleep(0.3);                                    -- làm chậm việc dò mã
  select s.uid into o from public.sync_codes s where s.code = c;
  if o is null then return jsonb_build_object('ok', false, 'msg', 'Mã không đúng. Kiểm tra lại nhé.'); end if;
  if o = n then return jsonb_build_object('ok', true, 'same', true); end if;
  perform pg_advisory_xact_lock(hashtext('rt_claim'));
  select val into pv from public.rtdb where path = 'players/' || o;
  if pv is null then return jsonb_build_object('ok', false, 'msg', 'Nhân vật của mã này không còn.'); end if;
  -- trả giường của nhân vật tạm trên máy này, rồi chuyển mọi thứ từ mã cũ sang máy này
  update public.rtdb set val = replace(val::text, '"' || n::text || '"', 'null')::jsonb, upd = t
    where path like 'beds/%' and val is not null and val::text like '%' || n::text || '%';
  update public.rtdb set val = replace(val::text, o::text, n::text)::jsonb, upd = t
    where (path like 'beds/%' or path like 'duels/%') and val is not null and val::text like '%' || o::text || '%';
  insert into public.rtdb(path, val, upd) values ('players/' || n, pv, t)
    on conflict (path) do update set val = excluded.val, upd = excluded.upd;
  update public.rtdb set val = null, upd = t where path = 'players/' || o;
  insert into public.rtdb(path, val, upd)
    select 'gifts/' || n, val, t from public.rtdb where path = 'gifts/' || o and val is not null
    on conflict (path) do update set val = coalesce(public.rtdb.val, '{}'::jsonb) || excluded.val, upd = excluded.upd;
  update public.rtdb set val = null, upd = t where path = 'gifts/' || o;
  delete from public.pos where uid = o;
  delete from public.sync_codes where uid = n;
  update public.sync_codes set uid = n where sync_codes.code = c;
  if exists (select 1 from public.admins where uid = o) then insert into public.admins(uid) values (n) on conflict do nothing; end if;
  return jsonb_build_object('ok', true);
end $$;

revoke all on function public.rt_code(), public.rt_claim(text) from public, anon;
grant execute on function public.rt_code(), public.rt_claim(text) to authenticated;

-- 8d. Tài khoản admin (username + mật khẩu) ----------------------------------
alter table public.admins add column if not exists username text;
create table if not exists public.admin_accounts (
  username text primary key,
  salt     text not null,
  hash     text not null,
  created  timestamptz not null default now()
);
alter table public.admin_accounts enable row level security;

create or replace function public.admin_hash(p text, salt text) returns text
language plpgsql immutable as $$
declare h text := salt || coalesce(p, ''); i int;
begin
  for i in 1..5000 loop h := encode(sha256(convert_to(h || salt, 'UTF8')), 'hex'); end loop;
  return h;
end $$;

-- Chỉ chạy được trong SQL Editor: tạo hoặc đặt lại mật khẩu một tài khoản admin
create or replace function public.admin_create(u_name text, p_word text) returns text
language plpgsql security definer set search_path = public as $$
declare s text := replace(gen_random_uuid()::text, '-', ''); u text := lower(trim(u_name));
begin
  if length(u) < 3 or length(coalesce(p_word, '')) < 6 then raise exception 'Username tối thiểu 3 ký tự, mật khẩu tối thiểu 6 ký tự'; end if;
  insert into public.admin_accounts(username, salt, hash) values (u, s, public.admin_hash(p_word, s))
    on conflict (username) do update set salt = excluded.salt, hash = excluded.hash;
  delete from public.admins where admins.username = u;
  return 'Đã tạo tài khoản admin: ' || u;
end $$;

create or replace function public.admin_login(u_name text, p_word text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare a public.admin_accounts; u text := lower(trim(u_name));
begin
  if auth.uid() is null then raise exception 'Chưa đăng nhập'; end if;
  perform pg_sleep(0.6);
  select * into a from public.admin_accounts where admin_accounts.username = u;
  if not found or public.admin_hash(p_word, a.salt) <> a.hash then return jsonb_build_object('ok', false, 'msg', 'Sai username hoặc mật khẩu.'); end if;
  insert into public.admins(uid, username) values (auth.uid(), u) on conflict (uid) do update set username = excluded.username;
  return jsonb_build_object('ok', true, 'user', u);
end $$;

create or replace function public.admin_logout() returns boolean
language sql security definer set search_path = public as $$
  delete from public.admins where uid = auth.uid() returning true
$$;

create or replace function public.admin_whoami() returns text
language sql stable security definer set search_path = public as $$
  select username from public.admins where uid = auth.uid()
$$;

create or replace function public.admin_passwd(oldp text, newp text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare u text; a public.admin_accounts; s text := replace(gen_random_uuid()::text, '-', '');
begin
  select admins.username into u from public.admins where uid = auth.uid();
  if u is null then return jsonb_build_object('ok', false, 'msg', 'Bạn chưa đăng nhập admin.'); end if;
  perform pg_sleep(0.4);
  select * into a from public.admin_accounts where admin_accounts.username = u;
  if not found or public.admin_hash(oldp, a.salt) <> a.hash then return jsonb_build_object('ok', false, 'msg', 'Mật khẩu cũ không đúng.'); end if;
  if length(coalesce(newp, '')) < 6 then return jsonb_build_object('ok', false, 'msg', 'Mật khẩu mới tối thiểu 6 ký tự.'); end if;
  update public.admin_accounts set salt = s, hash = public.admin_hash(newp, s) where admin_accounts.username = u;
  delete from public.admins where admins.username = u and uid <> auth.uid();
  return jsonb_build_object('ok', true);
end $$;

-- Gỡ các mã admin cũ không có mật khẩu
delete from public.admins where username is null;

revoke all on function public.admin_hash(text, text), public.admin_create(text, text) from public, anon, authenticated;
revoke all on function public.admin_login(text, text), public.admin_logout(), public.admin_whoami(), public.admin_passwd(text, text) from public, anon;
grant execute on function public.admin_login(text, text), public.admin_logout(), public.admin_whoami(), public.admin_passwd(text, text) to authenticated;

-- 9. Tạo tài khoản admin: sửa username / mật khẩu ở dòng dưới, bỏ dấu -- rồi chạy
-- select public.admin_create('admin', 'MAT-KHAU-CUA-BAN');

-- 10. Báo cho Supabase nạp lại danh sách hàm ngay
notify pgrst, 'reload schema';

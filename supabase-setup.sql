-- =====================================================================
-- VML COMPANY TRIP · CÀI ĐẶT DATABASE SUPABASE
-- Dán toàn bộ file này vào Supabase → SQL Editor → New query → Run.
-- Chạy lại nhiều lần cũng không sao (an toàn khi chạy lặp).
-- Bản 07.11-g: file này ĐÃ GỒM mọi cập nhật trước đó (tài khoản, admin, lâu đài, trang trí, Team Building, Vườn Liên Minh).
-- Chỉ cần chạy file này, không cần chạy các file trong thư mục sql-cu/. Không xoá dữ liệu người chơi.
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
  if s[1] = 'tb' then                                      -- Team Building: trưởng nhóm ghi phòng của mình, thành viên chỉ ghi dòng của mình
    if s[2] = u then return true; end if;
    return n = 4 and s[3] in ('m', 'res') and s[4] = u;
  end if;
  if s[1] = 'lm' then                                      -- Vườn Liên Minh: Gốc Chủ ghi cả cây, thành viên chỉ ghi dòng của mình (m = tên, c = tiền đã góp)
    if n = 2 then return (cur is null and nv is not null and nv ->> 'h' = u) or (docv is not null and docv ->> 'h' = u); end if;
    if docv is not null and docv ->> 'h' = u then return true; end if;
    return n = 4 and s[3] in ('m', 'c', 'iv') and s[4] = u;
  end if;
  if s[1] = 'errlog' then                                  -- nhật ký lỗi game: ai cũng được GỬI bản ghi mới của mình (nhỏ, không ghi đè), chỉ admin xem/xoá
    return n = 2 and cur is null and nv is not null and nv ->> 'u' = u and length(nv::text) < 3000;
  end if;
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
                      where upd > since and (since > 0 or val is not null)
                        and (path not like 'errlog/%' or public.is_admin())), '[]'::jsonb),
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
  if public.rt_bedcount(u) >= 6 then return jsonb_build_object('ok', false, 'msg', 'Bạn đã đủ 6 giường. Bán hoặc trả bớt giường trước.'); end if;
  select val into dv from public.rtdb where path = 'castle/' || tw;
  dv := coalesce(dv, '{}'::jsonb);
  if dv ->> 'done' is not null then return jsonb_build_object('ok', false, 'msg', 'Tháp này đã có liên minh ở.'); end if;
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

-- 8f. Tài khoản người chơi (username + mật khẩu) ------------------------------
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

revoke all on function public.acc_new_token(text) from public, anon, authenticated;
revoke all on function public.rt_claim(text), public.acc_status(), public.acc_register(text, text), public.acc_login(text, text),
  public.acc_resume(text), public.acc_logout(text), public.acc_delete() from public, anon;
grant execute on function public.rt_claim(text), public.acc_status(), public.acc_register(text, text), public.acc_login(text, text),
  public.acc_resume(text), public.acc_logout(text), public.acc_delete() to authenticated;


-- 8g. Admin: username, đổi mật khẩu, lịch sử tiền ----------------------------
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


-- Admin: tạo username + mật khẩu cho người chơi chưa có tài khoản
create or replace function public.admin_create_account(target uuid, u_name text, p_word text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare u text := lower(trim(coalesce(u_name, ''))); s text := replace(gen_random_uuid()::text, '-', '');
begin
  if not public.is_admin() then raise exception 'Không có quyền'; end if;
  if u !~ '^[a-z0-9_.]{4,16}$' then return jsonb_build_object('ok', false, 'msg', 'Username dài 4-16 ký tự, chỉ gồm chữ không dấu, số, dấu _ hoặc dấu chấm.'); end if;
  if length(coalesce(p_word, '')) < 6 or length(p_word) > 64 then return jsonb_build_object('ok', false, 'msg', 'Mật khẩu dài 6-64 ký tự.'); end if;
  perform pg_advisory_xact_lock(hashtext('acc_register'));
  if not exists (select 1 from public.rtdb where path = 'players/' || target::text and val is not null) then return jsonb_build_object('ok', false, 'msg', 'Không tìm thấy người chơi này.'); end if;
  if exists (select 1 from public.accounts where accounts.uid = target) then return jsonb_build_object('ok', false, 'msg', 'Người chơi này đã có tài khoản.'); end if;
  if exists (select 1 from public.admin_accounts where admin_accounts.username = u) or exists (select 1 from public.accounts where accounts.username = u) then return jsonb_build_object('ok', false, 'msg', 'Username "' || u || '" đã có người dùng.'); end if;
  insert into public.accounts(username, uid, salt, hash, created) values (u, target, s, public.admin_hash(p_word, s), public.now_ms());
  return jsonb_build_object('ok', true, 'user', u);
end $$;

revoke all on function public.admin_create_account(uuid, text, text) from public, anon;
grant execute on function public.admin_create_account(uuid, text, text) to authenticated;

-- 9. Tạo tài khoản admin: sửa username / mật khẩu ở dòng dưới, bỏ dấu -- rồi chạy
-- select public.admin_create('admin', 'MAT-KHAU-CUA-BAN');

-- 10. Báo cho Supabase nạp lại danh sách hàm ngay
notify pgrst, 'reload schema';


-- ===== Thương Xá Tắc (vật phẩm Limited) =====
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
  hb := coalesce(case jsonb_typeof(bbag -> 'h') when 'array' then bbag -> 'h' else '[]'::jsonb end, '[]'::jsonb) || jsonb_build_array(jsonb_build_array(t, it, left('buy:' || pr || ':' || coalesce(sdoc ->> 'name', '?'), 60)));
  hs := coalesce(case jsonb_typeof(sbag -> 'h') when 'array' then sbag -> 'h' else '[]'::jsonb end, '[]'::jsonb) || jsonb_build_array(jsonb_build_array(t, it, left('sold:' || pr || ':' || coalesce(bdoc ->> 'name', '?'), 60)));
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

-- ===== 09.11.2026-h: bán / trả chỗ lâu đài =====
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

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

-- 3. Luật bảo mật: ai được ghi vào đâu -------------------------------------
create or replace function public.rt_can(path text, cur jsonb, nv jsonb, docv jsonb) returns boolean
language plpgsql stable security definer set search_path = public as $$
declare s text[] := string_to_array(trim(both '/' from path), '/'); u text := auth.uid()::text; n int;
begin
  if auth.uid() is null then return false; end if;
  if public.is_admin() then return true; end if;
  n := coalesce(array_length(s, 1), 0);
  if n < 2 then return false; end if;                      -- day, cả bộ sưu tập: chỉ admin
  if s[1] = 'players' then return s[2] = u; end if;        -- chỉ sửa nhân vật của mình
  if s[1] = 'beds' then                                    -- nhận giường trống / trả hoặc nhường giường của mình
    return n = 4 and ((cur is null and nv is not null and nv #>> '{}' = u) or (cur is not null and cur #>> '{}' = u));
  end if;
  if s[1] = 'offers' then                                  -- deal mua lại giường
    if s[2] = u then return true; end if;
    if n = 2 then return false; end if;
    return (cur is null and nv is not null and nv ->> 'from' = u)
        or (cur is not null and jsonb_typeof(cur) = 'object' and cur ->> 'from' = u)
        or (n > 3 and docv #>> array[s[3], 'from'] = u);
  end if;
  if s[1] = 'invites' then return n >= 3; end if;          -- gửi lời thách đấu
  if s[1] = 'duels' then return docv is null or docv ->> 'a' = u or docv ->> 'b' = u; end if;
  if s[1] = 'gifts' then                                   -- chuyển tiền cho người khác (chỉ thêm, không sửa/xoá)
    return n = 3 and s[2] <> u and cur is null and nv is not null and nv ->> 'from' = u and (nv ->> 'amount')::numeric > 0;
  end if;
  return false;
end $$;

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

-- 9. Cấp quyền admin: bỏ dấu -- ở dòng dưới, dán mã của bạn (lấy ở admin.html) rồi chạy lại
-- insert into public.admins(uid) values ('DAN-MA-CUA-BAN-VAO-DAY') on conflict do nothing;

-- 10. Báo cho Supabase nạp lại danh sách hàm ngay
notify pgrst, 'reload schema';

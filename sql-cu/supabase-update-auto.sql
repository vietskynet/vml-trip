-- Cập nhật 10.11.2026: VINH PHÁT Automobile, 5 ổ sạc dùng chung toàn server.
-- Chạy 1 lần trong Supabase > SQL Editor. Chạy lại nhiều lần cũng không sao. Không xoá dữ liệu.
-- Dòng dữ liệu: rtdb 'auto/0'..'auto/4' = {u, id, en0, cap, t0, nm}. Chỉ hai hàm dưới đây ghi được (người chơi không ghi trực tiếp).
-- Sạc đầy từ 0 mất 120 giây. Xe sạc đầy mà chủ không lấy sau 180 giây thì ổ được nhường cho người khác (xe tự về kho của chủ).

create or replace function public.rt_auto_dock(vid text, en0 numeric, cap numeric, nm text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare u text := auth.uid()::text; t bigint := public.now_ms(); k int; cur jsonb; need numeric; slot int := null; e0 numeric;
begin
  if auth.uid() is null then raise exception 'Chưa đăng nhập'; end if;
  if vid is null or vid !~ '^[a-z0-9]{2,8}$' then return jsonb_build_object('ok', false, 'msg', 'Xe không hợp lệ.'); end if;
  if cap is null or cap < 60 or cap > 600 then return jsonb_build_object('ok', false, 'msg', 'Dung lượng pin không hợp lệ.'); end if;
  e0 := greatest(0, least(coalesce(en0, 0), cap));
  perform pg_advisory_xact_lock(hashtext('auto'));
  if exists (select 1 from public.rtdb r where r.path like 'auto/%' and r.val ->> 'u' = u) then
    return jsonb_build_object('ok', false, 'msg', 'Bạn đã có một xe đang sạc. Lấy xe đó ra trước.'); end if;
  for k in 0..4 loop
    select r.val into cur from public.rtdb r where r.path = 'auto/' || k;
    if cur is null or coalesce(cur ->> 'u', '') = '' then slot := k; exit; end if;
    need := (greatest(0, (cur ->> 'cap')::numeric - (cur ->> 'en0')::numeric) / (cur ->> 'cap')::numeric) * 120000;
    if t - (cur ->> 't0')::bigint >= need + 180000 then slot := k; exit; end if;
  end loop;
  if slot is null then return jsonb_build_object('ok', false, 'full', true, 'msg', 'Hết ổ sạc (5/5). Hãy cất xe vào kho.'); end if;
  insert into public.rtdb(path, val, upd) values ('auto/' || slot,
      jsonb_build_object('u', u, 'id', vid, 'en0', e0, 'cap', cap, 't0', t, 'nm', left(coalesce(nm, 'Ai đó'), 24)), t)
    on conflict (path) do update set val = excluded.val, upd = excluded.upd;
  return jsonb_build_object('ok', true, 'slot', slot, 't0', t);
end $$;

create or replace function public.rt_auto_undock() returns jsonb
language plpgsql security definer set search_path = public as $$
declare u text := auth.uid()::text; t bigint := public.now_ms(); r record; en numeric;
begin
  if auth.uid() is null then raise exception 'Chưa đăng nhập'; end if;
  perform pg_advisory_xact_lock(hashtext('auto'));
  select * into r from public.rtdb x where x.path like 'auto/%' and x.val ->> 'u' = u limit 1;
  if not found then return jsonb_build_object('ok', false, 'msg', 'Bạn không có xe nào đang sạc.'); end if;
  en := least((r.val ->> 'cap')::numeric,
              (r.val ->> 'en0')::numeric + (t - (r.val ->> 't0')::bigint) / 1000.0 * ((r.val ->> 'cap')::numeric / 120.0));
  update public.rtdb set val = null, upd = t where path = r.path;
  return jsonb_build_object('ok', true, 'id', r.val ->> 'id', 'cap', (r.val ->> 'cap')::numeric, 'en', round(en, 1));
end $$;

revoke all on function public.rt_auto_dock(text, numeric, numeric, text) from public, anon;
revoke all on function public.rt_auto_undock() from public, anon;
grant execute on function public.rt_auto_dock(text, numeric, numeric, text) to authenticated;
grant execute on function public.rt_auto_undock() to authenticated;

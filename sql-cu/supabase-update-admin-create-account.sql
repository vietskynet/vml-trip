-- ================================================================
-- VML Trip: Admin tạo username + mật khẩu cho người chơi chưa có tài khoản
-- Chạy 1 lần trong Supabase SQL Editor (sau supabase-update-accounts.sql). Chạy lại an toàn.
-- ================================================================
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
notify pgrst, 'reload schema';

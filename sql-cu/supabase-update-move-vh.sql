-- ============================================================
-- SỬA LỖI: đăng nhập sang máy khác (điện thoại) thì Villa / chợ / lời mời
-- không còn là của mình ("Chủ nhà có thể mời bạn tham quan…", mất nút quản lý).
-- Nguyên nhân: rt_move_player chỉ chuyển beds, duels, castle, lm — KHÔNG chuyển
-- vh (Villa), vhlog, market, offers, invites, tb, deco nên chủ sở hữu vẫn là uid cũ.
-- File này (chạy 1 lần, chạy lại được):
--   PHẦN 1: thay rt_move_player bằng bản chuyển đủ các mục trên.
--   PHẦN 2: SỬA những Villa đã bị "mồ côi" do lần đăng nhập trước.
-- Không đụng rt_can nên không cần chạy lại gift-guard.
-- ============================================================

-- PHẦN 1 -----------------------------------------------------
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
    where (path like 'beds/%' or path like 'duels/%' or path like 'castle/%' or path like 'lm/%'
        or path like 'vh/%' or path like 'vhlog/%' or path like 'market/%' or path like 'offers/%'
        or path like 'invites/%' or path like 'tb/%' or path like 'deco/%')
      and val is not null and val::text like '%' || o::text || '%';
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

-- PHẦN 2: sửa Villa đã bị mồ côi ------------------------------
-- (a) XEM TRƯỚC (chỉ đọc): Villa có chủ là uid không còn nhân vật nào, kèm nhân vật cùng tên.
--     Chỉ sửa khi mỗi Villa khớp ĐÚNG 1 nhân vật (cột so_khop = 1).
select v.path as villa, v.val ->> 'on' as ten_chu, v.val ->> 'o' as uid_cu,
       array_agg(substr(p.path, 9)) as uid_moi, count(*) as so_khop
from public.rtdb v
join public.rtdb p on p.path like 'players/%' and p.val is not null
  and left(p.val ->> 'name', 18) = v.val ->> 'on'
where v.path like 'vh/%' and v.val is not null and v.val ->> 'o' is not null
  and not exists (select 1 from public.rtdb q where q.path = 'players/' || (v.val ->> 'o') and q.val is not null)
group by v.path, v.val ->> 'on', v.val ->> 'o';

-- (b) SỬA: đổi chủ Villa mồ côi sang nhân vật cùng tên (chỉ khi khớp đúng 1 nhân vật).
with m as (
  select v.path, v.val ->> 'o' as ou, min(substr(p.path, 9)) as nu
  from public.rtdb v
  join public.rtdb p on p.path like 'players/%' and p.val is not null
    and left(p.val ->> 'name', 18) = v.val ->> 'on'
  where v.path like 'vh/%' and v.val is not null and v.val ->> 'o' is not null
    and not exists (select 1 from public.rtdb q where q.path = 'players/' || (v.val ->> 'o') and q.val is not null)
  group by v.path, v.val ->> 'o'
  having count(*) = 1
)
update public.rtdb r set val = replace(r.val::text, m.ou, m.nu)::jsonb, upd = public.now_ms()
from m where r.path = m.path;

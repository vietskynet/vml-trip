-- ============================================================
-- GIFT GUARD · chặn "in tiền" bằng quà (lỗi B)
-- Người chơi (không phải admin) chỉ được gửi quà có số tiền
--   <= 2 x ví đã lưu trên server của người gửi + 5.000.000₫
-- (dư địa cho phạt, hoàn tiền, góp vốn lâu đài... lúc ví vừa đổi
--  mà server chưa kịp lưu). Quà vượt mức bị từ chối.
--
-- File này BỌC rt_can hiện có (không chép lại logic cũ) nên chạy được
-- dù rt_can đang là phiên bản nào. CHẠY LẠI file này sau mỗi lần chạy
-- 1 file supabase-update-*.sql khác có định nghĩa lại rt_can.
-- Chạy được nhiều lần.
-- ============================================================
do $$
begin
  if position('rt_can_base' in coalesce((select prosrc from pg_proc where proname = 'rt_can' and pronamespace = 'public'::regnamespace), '')) = 0 then
    drop function if exists public.rt_can_base(text, jsonb, jsonb, jsonb);
    alter function public.rt_can(text, jsonb, jsonb, jsonb) rename to rt_can_base;
  end if;
end $$;

create or replace function public.rt_can(path text, cur jsonb, nv jsonb, docv jsonb) returns boolean
language plpgsql stable security definer set search_path = public as $$
declare s text[] := string_to_array(trim(both '/' from path), '/'); u text := auth.uid()::text; bal numeric; amt numeric;
begin
  if auth.uid() is not null and not public.is_admin() and coalesce(array_length(s, 1), 0) = 3 and s[1] = 'gifts' and nv is not null then
    amt := coalesce((nv ->> 'amount')::numeric, 0);
    select coalesce((val #>> '{state,money}')::numeric, 0) into bal from public.rtdb where rtdb.path = 'players/' || u;
    if amt > greatest(coalesce(bal, 0), 0) * 2 + 5000000 then return false; end if;
  end if;
  return public.rt_can_base(path, cur, nv, docv);
end $$;

revoke all on function public.rt_can(text, jsonb, jsonb, jsonb), public.rt_can_base(text, jsonb, jsonb, jsonb) from public, anon;

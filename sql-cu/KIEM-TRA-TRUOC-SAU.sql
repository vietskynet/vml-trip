-- KIỂM TRA (chỉ ĐỌC, an toàn). Dán từng khối vào Supabase SQL Editor, bấm Run, rồi gửi kết quả cho Claude.

-- A) Hàm rt_can đã có quy tắc nhật ký villa (vhlog) chưa?  Cột co_vhlog = true là đã chạy supabase-update-villa.sql
select position('vhlog' in pg_get_functiondef('public.rt_can(text,jsonb,jsonb,jsonb)'::regprocedure)) > 0 as co_vhlog;

-- B) Các lô Vườn Liên Minh (lm/1..12): lô nào đã có chủ, cây gì, bao nhiêu thành viên, trạng thái
select split_part(path,'/',2)::int as lo, val->>'nm' as ten_lien_minh, val->>'hn' as goc_chu, val->>'sd' as hat_giong,
       val->>'st' as trang_thai, (select count(*) from jsonb_object_keys(coalesce(val->'m','{}'::jsonb))) as so_thanh_vien,
       val->'pt' as diem_kenh
from rtdb where path ~ '^lm/[0-9]+$' and val is not null order by 1;

-- C) Riêng các lô 3, 4, 7, 8, 11, 12 (đang cần kiểm tra): có dữ liệu hay trống?
select n as lo, (select val from rtdb where path='lm/'||n) as du_lieu
from unnest(array[3,4,7,8,11,12]) n order by n;

-- D) Khu Villa Riêng (vh/1..6): chủ lô, số tầng, kiểu nhà
select split_part(path,'/',2)::int as lo, val->>'on' as chu, val->>'f' as so_tang, val->>'s' as kieu_nha, val->>'st' as trang_thai
from rtdb where path ~ '^vh/[0-9]+$' and val is not null order by 1;

-- E) Nhật ký villa có ghi được chưa? (có dòng = đã hoạt động)
select count(*) as so_dong_vhlog from rtdb where path like 'vhlog/%' and val is not null;

-- F) Cổng mở khu villa (config/vh*)
select path, val from rtdb where path like 'config/vh%' order by path;

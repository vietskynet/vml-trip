-- Kiểm tra nhân vật ATVNCG26 và liên minh (chỉ đọc, an toàn)
-- 1) Các tài khoản (uid) mang tên này
select path as player_path, val->>'name' as name, (val->'state'->>'money') as money, upd
from rtdb where path like 'players/%' and (val->>'name') ilike '%ATVNCG26%';

-- 2) Liên minh nào có thành viên mang tên này, và uid trong danh sách thành viên là gì
select r.path as lm_path, r.val->>'nm' as ten_lien_minh, r.val->>'h' as uid_goc_chu,
       m.key as uid_thanh_vien, m.value as ten_thanh_vien
from rtdb r, jsonb_each_text(coalesce(r.val->'m','{}'::jsonb)) m
where r.path like 'lm/%' and m.value ilike '%ATVNCG26%';

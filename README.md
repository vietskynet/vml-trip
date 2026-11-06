# VML Company Trip · Maldives (Netlify + Supabase)

- `index.html`: game (tự nhận biết online/offline)
- `config.js`: Project URL + khoá anon của Supabase, cài đặt game
- `supabase-shim.js`: lớp kết nối game với Supabase
- `admin.html`: trang quản trị có đăng nhập (Tổng quan · Người chơi · Giá cả · Sự kiện quái vật · Hệ thống). Tạo tài khoản: `select public.admin_create('admin','mật-khẩu');` trong Supabase SQL Editor
- `supabase-setup.sql`: chạy một lần trong Supabase SQL Editor
- `HUONG-DAN.html`: hướng dẫn từng bước

Mã cheat trong khung chat (phím C): `VMLSANG`. Mỗi lần dùng mã tốn 50.000₫.

Mã hiệu ứng 10 giây (người khác cũng thấy): `VMLTO`, `VMLTIEN`, `VMLPHAN`, `VMLHAOQUANG`, `VMLXICHLO`, `VMLLUA`, `VMLMUA`, `VMLTANGHINH`, `VMLDISCO`, `VMLPHAOHOA`.


## Cập nhật 06.11.2026-g
- Trang trí phòng khách sạn (ban công, cửa sổ, bảng tên), 12 món trang trí mới, quầy thuê phao bơi cạnh hồ (100.000₫ / 2 phút, admin chỉnh giá được).
- **Cần chạy `supabase-update-hotel-deco.sql` một lần** trong Supabase > SQL Editor để bật trang trí phòng khách sạn khi chơi online.

## Cập nhật 06.11.2026-m · LÂU ĐÀI TÌNH BÁO
- Khu mở rộng phía nam (qua cổng sắt), 5 tháp, mỗi tháp 3 người, 20 → 100 triệu/người. Mua chung 3 người, thành liên minh; 2 phiếu thoát thì cả nhóm rời và mất tiền.
- Chỗ lâu đài tính 1 giường trong giới hạn 6 giường. Thêm nút TRẢ GIƯỜNG (hoàn 50%).
- **Cần chạy `supabase-update-castle.sql` một lần** trong Supabase > SQL Editor để bật lâu đài khi chơi online.

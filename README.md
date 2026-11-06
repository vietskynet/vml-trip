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

## Phiên bản v · Tài khoản người chơi

- **Chạy SQL:** `supabase-update-accounts.sql` (1 lần, chạy lại an toàn). Nếu chưa chạy, game vẫn vào bình thường (chưa bắt buộc tài khoản).
- Username (4-16 ký tự `a-z 0-9 _ .`, không phân biệt hoa/thường) khác với tên hiển thị. Mật khẩu 6-64 ký tự, băm có salt phía máy chủ.
- Người chơi mới: chọn nhân vật, bấm VÀO RESORT, tạo tài khoản. Người chơi cũ: lần quay lại đầu tiên hiện "Nâng cấp tài khoản", dữ liệu giữ nguyên.
- Cookie/localStorage `vml_tok` giữ token đăng nhập tự động; nếu phiên ẩn danh của trình duyệt mất, token tự lấy lại nhân vật.
- Nhập sai mật khẩu 6 lần: khoá 5 phút. Tạo nhân vật mới sẽ xoá luôn tài khoản của nhân vật cũ.
- Đổi tên hiển thị: tối đa 5 lần, lần 1 giá 3.000.000₫, mỗi lần sau +20% (3,0 · 3,6 · 4,32 · 5,184 · 6,221 triệu). Đếm ở `players/<uid>/rn`.
- Hằng số `ACC_GRACE_UNTIL` trong `index.html`: đặt mốc thời gian (ms) để người chơi cũ có nút "ĐỂ SAU" trong thời gian chuyển tiếp (mặc định 0 = bắt buộc).

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

## Phiên bản w · Admin tài khoản, lịch sử tiền, ông Bụt, bản đồ

- **SQL:** chạy `supabase-update-admin-log.sql` (sau `supabase-update-accounts.sql`; chạy lại an toàn). Bảng `money_log`, các hàm `rt_mlog`, `admin_accounts_list`, `admin_set_password`, `admin_mlog`.
- **Admin:** cột USERNAME trong tab Người chơi, ô đổi mật khẩu cho từng người (xoá luôn token đăng nhập tự động của họ), tab LỊCH SỬ TIỀN (lọc vào/ra/lý do, tổng vào/ra). Lý do lấy từ thông báo gần nhất trong game; dữ liệu do máy người chơi gửi, giữ 1.500 dòng gần nhất mỗi người.
- **Ông Bụt:** 20% cụ già lú lẫn là ông Bụt. Dẫn về nhà: hiện nguyên hình, ban 1.111.111₫ (chỉnh được ở admin, mục Giá cả), biến mất; người giúp có hào quang "NGƯỜI TỐT" 5 phút, người khác cũng thấy.
- **Bản đồ mini:** nút BẢN ĐỒ ở góc, chấm đỏ cho nhân vật, quái vật (vòng đỏ nhấp nháy) và gián ngoài hành tinh; vòng trắng là bạn.

## Phiên bản x · Vào thẳng game khi đã đăng nhập

- Có tài khoản + cookie/phiên: màn hình đầu hiện "CHÀO MỪNG TRỞ LẠI, <tên> · Đang kết nối máy chủ…" rồi vào thẳng resort, không hiện bảng tạo nhân vật. Cờ `vmlTripAuto` được xoá khi đăng xuất / tạo nhân vật mới.
- Sửa lỗi bản w: hàm `startGame` của nút VÀO RESORT trùng tên với `startGame(z)` của minigame (đã đổi thành `enterResort`).

## Phiên bản y · Mở rộng bản đồ, Team Building
- **+5 bungalow** (B11–B20, tổng 20 tại khu bungalow) và **quầy lễ tân bungalow thứ 2** ở nhánh phải để mua dễ hơn.
- **Shop thời trang** dời sát shop thú cưng. **Đất tím** thu nhỏ, chỉ rải quanh Lâu Đài Tình Báo.
- **+5 bộ trang phục lạ** (tổng 35): Cỗ Xe Ngựa, Chùm Nho Khổng Lồ, Lon Bia "333", Tiền Tài Kéo Dài Lê Thê, Trà Sữa Trân Châu Khổng Lồ.
- **Xoá Sàn Thách Đấu**, thay bằng **Team Building** (cùng vị trí):
  - Cần tối thiểu **5 thành viên** (tối đa 8). Trưởng nhóm tạo phòng, người khác vào từ danh sách phòng đang mở hoặc nhận **lời mời** gửi cho người đang online.
  - Mỗi lượt chọn ngẫu nhiên 1 trong 3 trò nhóm: Nhịp Tay Đồng Đội, Nhớ Dãy Mũi Tên, Canh Vạch Vàng. Mọi người chơi cùng một đề (chung seed), điểm cả đội là tổng điểm.
  - **Level 1–5**: mục tiêu = 50 / 60 / 70 / 78 / 85% tổng điểm tối đa. Thưởng mỗi người khi thắng: 750.000 / 1.000.000 / 1.350.000 / 1.800.000 / 2.400.000₫ (Level 1 = 1,5 lần mức thưởng trung bình của một lượt game cá nhân). Thua không mất tiền. Chờ 120 giây giữa 2 lượt.
  - Chơi offline có thể gọi bot cho đủ 5 người để chơi thử.
- Dữ liệu phòng lưu ở đường dẫn `tb/<uid trưởng nhóm>`. **Cần chạy `supabase-update-team.sql`** trong Supabase (thêm luật ghi cho `tb`), nếu không chức năng online của Team Building sẽ không ghi được.

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

## Phiên bản z · Năng lượng
- Hao năng lượng: đứng yên 0,05%/giây (~33 phút), **di chuyển 0,10%/giây** (~17 phút). Mỗi lượt game trừ 6%.
- **Dưới 30% không chơi được game** (kể cả Team Building). Nhắc liên tục: mỗi 30 giây khi dưới 30%, 20 giây khi dưới 20%, 12 giây khi dưới 10%.
- **Ngủ miễn phí, hồi đầy:** Bungalow 2 phút · Khách sạn 3 phút · Villa 1 phút · Lâu đài 10 giây. Thanh trên màn hình ngủ hiện thời gian còn lại.
- Đồ ăn tính theo kcal, ~400₫/kcal: nước dừa 100 kcal 40.000₫ (+5%), bánh mì 250 kcal 100.000₫ (+12%), cơm gà 500 kcal 200.000₫ (+25%), set hải sản 1000 kcal 400.000₫ (+50%). Ăn tập thể miễn phí vẫn giữ.
- Bot cũng hao nhanh hơn khi đi lại và không đi chơi game khi dưới 30%. "Lều" đổi tên hết thành "Bungalow".
- Hạnh phúc, nhà và Khu Vườn Tuổi Thơ chưa làm (đang thiết kế).

## Phiên bản 07.11-a · Hạnh phúc, Khu Vườn Tuổi Thơ, menu gộp
- **Chỉ số hạnh phúc** (thanh vàng cạnh năng lượng, bấm để xem chi tiết): thang 0–100%, bắt đầu 50%, tụt 1 điểm mỗi 8 phút online.
  - Cộng điểm (giới hạn mỗi 24 giờ): ngủ trọn giấc +7 (1 lần) · vệ sinh đúng lúc +2 (3) · ăn đúng bữa +2 (3) · Team Building +8 thắng / +3 thua (2) · dọn phân, diệt gián, giúp cụ già +3 (5) · ông Bụt +5 · chia tiền từ 100.000₫ +2, từ 1.000.000₫ +3 (3 người khác nhau) · vé số +1 (3), trúng +3.
  - Trừ điểm: tai nạn vệ sinh −6, ngất −8.
  - Trần theo chỗ ở: chưa có nhà 55 · Bungalow 65 · Khách sạn 75 · Villa 85 · Lâu đài 90.
  - Chuỗi ngày đều (≥ 4 loại hoạt động mỗi ngày): 3 ngày +5% điểm, 7 ngày +10%. Có điểm tuần và điểm tổng.
  - **Chưa ảnh hưởng tiền kiếm được.** Lưu cùng trạng thái nhân vật trên server (không cần SQL mới); tính ở máy người chơi.
- **Hàng rào lâu đài nhỏ lại**, chỉ bao quanh Lâu Đài Tình Báo. Bên phải là **KHU VƯỜN TUỔI THƠ**: 12 lô đất trống (LÔ 1–12), cổng có biển "ĐANG XÂY DỰNG", chưa vào được và chưa giao dịch.
- **Menu chính** gom TÀI SẢN, BXH, CHUYỂN, HẠNH PHÚC, LUẬT, NHẠC, NV. Nút BẢN ĐỒ vẫn đứng riêng.
- **Gián và ông già** ưu tiên xuất hiện gần người ít tiền (xếp hạng ví càng thấp càng gần và càng nhanh), người giàu thì xuất hiện ngẫu nhiên khắp resort.

## Phiên bản 07.11-b · Vườn Liên Minh (đợt 1)
Khu Vườn Tuổi Thơ đổi thành **VƯỜN LIÊN MINH**, cổng đã mở, đi bộ vào được. Có 12 lô đất, mỗi lô trồng được 1 **Cây Liên Minh**. Nút **LIÊN MINH** nằm trong menu chính; đứng gần cổng hoặc gần từng lô bấm E cũng mở.
- **Đất:** 6 lô ngoài là **Đất Thường 30 triệu** (cây tối đa 30 điểm, thuế đất 15.000₫/giờ), 6 lô giữa là **Đất Vàng 60 triệu** (tối đa 40 điểm, 30.000₫/giờ). Thuế đất tính theo giờ thực, kể cả lúc offline; quỹ cây trả trước, thiếu thì tự trừ tiền Gốc Chủ, không đủ thì thành nợ (nợ quá 12 giờ thuế thì cây héo, buff còn 50%).
- **Hạt giống** (quyết định hình dáng và điểm gốc): Dừa Vàng 8tr (Tiền) · Anh Đào 5tr (May mắn) · Thông Gió 5tr (Tốc độ) · Sồi Chiến 5tr (Khổng Lồ) · Bồ Đề 5tr (Năng lượng) · Thế Giới Thụ 20tr (đều cả 5 kênh). Mỗi hạt có 2 kênh "ưa" (giá bón −20%) và 1 kênh "kỵ" (+30%).
- **Thành viên:** tối thiểu 3 người mới bấm được TRỒNG, tối đa 8. Level tối đa = 5 × số thành viên (3 người: 15, 8 người: 40, và không vượt giới hạn của lô đất). Thiếu 3 người thì buff còn 50%. Mỗi người chỉ ở 1 liên minh; rời xong chờ 12 giờ. Vào sau khi cây đã trồng phải trả phí 250.000₫ × số điểm cây (bỏ vào quỹ).
- **Thuế:** Gốc Chủ đặt thuế thành viên 250.000–1.500.000₫ mỗi giờ chơi (mặc định 600.000₫, nhích 50.000₫), tự trừ khi đang online, bỏ vào **Quỹ Cây**. Gốc Chủ không rút được quỹ; quỹ chỉ để trả thuế đất và bón cây. Không đủ tiền đóng thuế thì buff của người đó tạm dừng đến khi trả đủ. Mọi người có thể góp thêm vào quỹ.
- **Bón dinh dưỡng** (Gốc Chủ, trừ từ quỹ): giá điểm thứ k = 700.000₫ × 1,11^k (nhân 0,8 nếu hạt ưa, 1,3 nếu kỵ). Mỗi kênh tối đa 10 điểm. 5 kênh và hiệu ứng ở 10 điểm: **Tiền** +8% thưởng ván game và Team Building · **May mắn** +30% thưởng nhặt (gián, ông già, Bụt) và tỉ lệ trúng vé số · **Tốc độ** +15% · **Năng lượng** −30% hao khi đứng/đi và hồi khi ngủ nhanh hơn 25% (không giảm phí 6% mỗi ván) · **Khổng Lồ** nhân vật ×1,25, +30% sát thương quái, đổi lại hao năng lượng +10%.
- Gốc Chủ có thể mời thành viên ra, nhường chức, hoặc trả đất khi chỉ còn một mình. Cây hiển thị trên lô theo 4 giai đoạn (Mầm, Cây con, Trưởng thành, Cổ thụ), màu quả theo kênh nổi trội. Hạnh phúc có thêm nguồn "Cây Liên Minh" (tối đa +4/ngày).
- **Hoãn:** kỹ năng đặc biệt, mời người online trực tiếp, trang admin cho Vườn Liên Minh.
- **Cần chạy lại `supabase-update-team.sql`** trong Supabase (thêm luật ghi cho `lm/<lô>`), nếu không các lô sẽ không ghi được khi chơi online.

### 07.11-c
- Giá bón cây và thuế thành viên nâng gấp 2,5 lần: điểm thứ k = 250.000₫ × 1,11^k (Lv30 khoảng 48M, Lv40 khoảng 144M tiền bón, chưa tính đất và hạt); thuế thành viên 125.000–625.000₫/giờ chơi, mặc định 250.000₫; phí gia nhập sau khi trồng 250.000₫ × số điểm.

### 07.11-d
- Giá bón chỉnh để **Lv40 ≈ 404 triệu**, Lv30 ≈ 136 triệu (điểm thứ k = 700.000₫ × 1,11^k). Thuế đất giữ nguyên (15.000₫ / 30.000₫ mỗi giờ). Thuế thành viên 250.000–1.500.000₫ mỗi giờ chơi, mặc định 600.000₫. Phí gia nhập sau khi trồng: 250.000₫ × số điểm.

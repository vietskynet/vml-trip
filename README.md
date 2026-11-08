# VML Company Trip · Maldives (Netlify + Supabase)

- `index.html`: game (tự nhận biết online/offline)
- `config.js`: Project URL + khoá anon của Supabase, cài đặt game
- `supabase-shim.js`: lớp kết nối game với Supabase
- `admin.html`: trang quản trị có đăng nhập (Tổng quan · Người chơi · Giá cả · Sự kiện quái vật · Hệ thống). Tạo tài khoản: `select public.admin_create('admin','mật-khẩu');` trong Supabase SQL Editor
- `supabase-setup.sql`: chạy một lần trong Supabase SQL Editor
- `HUONG-DAN.html`: hướng dẫn từng bước

Mã cheat trong khung chat (phím C): `VMLSANG`. Mỗi lần dùng mã tốn 50.000₫.

Mã hiệu ứng 10 giây (người khác cũng thấy): `VMLTO`, `VMLTIEN`, `VMLPHAN`, `VMLHAOQUANG`, `VMLXICHLO`, `VMLLUA`, `VMLMUA`, `VMLTANGHINH`, `VMLDISCO`, `VMLPHAOHOA`.


## Phiên bản 08.11-d · Hair Salon Tóc Thề
- **Salon tóc** đặt cạnh Thời Trang Lung Linh. Mặt tiền tím hồng ánh vàng, cửa kính nhìn thấy người đang ngồi bên trong. Bảng hiệu **"Hair Salon Tóc Thề"** là chữ 3D có độ dày, lắc nhẹ rồi xoay một vòng mỗi 7 giây.
- **Tối đa 3 người** mỗi lần (3 ghế). Ai vào sau khi đủ 3 người sẽ được báo "Salon đầy". Số ghế đồng bộ qua trường `pos` (`sa`, `sp`), không cần SQL.
- **Bên trong chi tiết**: 3 gương khung vàng soi hình mình, đèn chùm pha lê, ghế nhung hồng, kệ mỹ phẩm, sàn caro. Mỗi ghế có thợ làm tóc: gội đầu, cắt tạo kiểu, nhuộm (hoặc dưỡng tóc), sấy. Làm xong thợ nhảy mừng, pháo giấy, chữ "CHÚC MỪNG!".
- **12 kiểu tóc** (6 nam, 6 nữ), giá 1,2tr–10tr, bền 1–10 ngày game (1 ngày game = 60 phút thật), mất 1–3 phút để làm. Nhuộm màu +30% giá kiểu (12 màu, có cầu vồng). **6 phụ kiện lấp lánh** dùng chung nam nữ, giá 600k–2,5tr.
- Trong lúc ngồi salon, bộ đếm mắc tiểu / đại tiện tạm dừng.
- Tóc lưu ở `players/<id>/hr` (kiểu, màu, phụ kiện, giờ xong, giờ hết hạn). Thoát game giữa chừng vẫn nhận tóc khi giờ xong đến. Hết hạn thì tóc tự về như cũ.
- Admin: tab CỬA HÀNG có quầy **Salon tóc** (đổi giá kiểu tóc và phụ kiện, xem lượt mua, lượt nhuộm).

## Phiên bản 08.11-c · 20 đồ trang trí cao cấp + Cửa hàng admin
- **20 đồ trang trí cao cấp (★)** cho Villa và Bungalow: giá bungalow 10tr–100tr, **villa gấp đôi** (20tr–200tr). Không đặt được ở phòng khách sạn.
  - Xe & Bay: mô tô nước 20tr, siêu xe 60tr, khinh khí cầu 40tr, trực thăng 100tr.
  - Vườn & Nước: đài phun nước 30tr, hồ bơi vô cực 50tr, hồ cá Koi 15tr, thác đá 35tr.
  - Sang trọng: cặp sư tử vàng 45tr, cổng vòm cẩm thạch 20tr, vương miện vàng 80tr, rương kho báu 12tr.
  - Công nghệ: robot quản gia 18tr, tên lửa 90tr, rồng hologram 70tr, đàn drone đèn 25tr.
  - Tiệc & Lễ hội: sân khấu DJ 40tr, pháo hoa bất tận 30tr, cổng tre hoa giấy 10tr, đèn lồng cung đình 12tr.
- Bảng trang trí trong game có **tab phân loại**: Tất cả, ★ Cao cấp, Vui nhộn, Vườn & Nước, Sang trọng, Công nghệ, Xe & Bay, Tiệc & Lễ hội. 24 món cũ cũng được xếp loại.
- Admin: tab **GIÁ CẢ** đổi thành **CỬA HÀNG**: chọn quầy (Nhà & Lâu đài, Thú cưng, Trang trí, Thời trang, Ăn uống, Dịch vụ, Thuyền, Việc vặt) có biểu tượng, lọc theo loại, tìm tên, sắp xếp theo giá hoặc bán chạy, lọc món đã đổi giá, nút Lưu dính đáy màn hình, hiển thị tốt trên điện thoại. Giá đồ cao cấp trong admin là giá bungalow, villa tự nhân đôi.
- **Thống kê lượt mua**: mỗi món hiện số lượt mua và doanh thu ước tính, kèm Top 5 bán chạy. Game đếm lượt mua của từng người vào `players/<id>/state.bu` (không cần SQL). Số liệu chỉ đếm từ bản này; mỗi người phải vào game bản mới mới đẩy số lên.

## Phiên bản 08.11-b · Tab Kinh tế trong admin
- Admin có tab **KINH TẾ**: tổng tiền lưu hành, ví trung vị/trung bình/top 10%, chỉ số chênh lệch (Gini), phân bố ví, tỉ lệ người đủ tiền mua từng món, nhà/thú/bộ đồ đã bán, top 10 giàu nhất và nhận xét tự động.
- Dùng dữ liệu sẵn có, không cần chạy thêm SQL. Lịch sử tổng tiền chỉ ghi lúc trang admin đang mở.

## Cập nhật 06.11.2026-g
- Trang trí phòng khách sạn (ban công, cửa sổ, bảng tên), 12 món trang trí mới, quầy thuê phao bơi cạnh hồ (100.000₫ / 2 phút, admin chỉnh giá được).
- **Cần chạy `sql-cu/supabase-update-hotel-deco.sql (nay đã gộp vào supabase-setup.sql)` một lần** trong Supabase > SQL Editor để bật trang trí phòng khách sạn khi chơi online.

## Cập nhật 06.11.2026-m · LÂU ĐÀI TÌNH BÁO
- Khu mở rộng phía nam (qua cổng sắt), 5 tháp, mỗi tháp 3 người, 20 → 100 triệu/người. Mua chung 3 người, thành liên minh; 2 phiếu thoát thì cả nhóm rời và mất tiền.
- Chỗ lâu đài tính 1 giường trong giới hạn 6 giường. Thêm nút TRẢ GIƯỜNG (hoàn 50%).
- **Cần chạy `sql-cu/supabase-update-castle.sql (nay đã gộp vào supabase-setup.sql)` một lần** trong Supabase > SQL Editor để bật lâu đài khi chơi online.

## Phiên bản v · Tài khoản người chơi

- **Chạy SQL:** `sql-cu/supabase-update-accounts.sql (nay đã gộp vào supabase-setup.sql)` (1 lần, chạy lại an toàn). Nếu chưa chạy, game vẫn vào bình thường (chưa bắt buộc tài khoản).
- Username (4-16 ký tự `a-z 0-9 _ .`, không phân biệt hoa/thường) khác với tên hiển thị. Mật khẩu 6-64 ký tự, băm có salt phía máy chủ.
- Người chơi mới: chọn nhân vật, bấm VÀO RESORT, tạo tài khoản. Người chơi cũ: lần quay lại đầu tiên hiện "Nâng cấp tài khoản", dữ liệu giữ nguyên.
- Cookie/localStorage `vml_tok` giữ token đăng nhập tự động; nếu phiên ẩn danh của trình duyệt mất, token tự lấy lại nhân vật.
- Nhập sai mật khẩu 6 lần: khoá 5 phút. Tạo nhân vật mới sẽ xoá luôn tài khoản của nhân vật cũ.
- Đổi tên hiển thị: tối đa 5 lần, lần 1 giá 3.000.000₫, mỗi lần sau +20% (3,0 · 3,6 · 4,32 · 5,184 · 6,221 triệu). Đếm ở `players/<uid>/rn`.
- Hằng số `ACC_GRACE_UNTIL` trong `index.html`: đặt mốc thời gian (ms) để người chơi cũ có nút "ĐỂ SAU" trong thời gian chuyển tiếp (mặc định 0 = bắt buộc).

## Phiên bản w · Admin tài khoản, lịch sử tiền, ông Bụt, bản đồ

- **SQL:** chạy `sql-cu/supabase-update-admin-log.sql (nay đã gộp vào supabase-setup.sql)` (sau `supabase-update-accounts.sql`; chạy lại an toàn). Bảng `money_log`, các hàm `rt_mlog`, `admin_accounts_list`, `admin_set_password`, `admin_mlog`.
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
- Dữ liệu phòng lưu ở đường dẫn `tb/<uid trưởng nhóm>`. **Cần chạy `supabase-setup.sql`** trong Supabase (thêm luật ghi cho `tb`), nếu không chức năng online của Team Building sẽ không ghi được.

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

## Phiên bản 08.11-a · Tăng giá nhà
- Villa 5tr lên 25tr mỗi giường, Bungalow 3tr lên 10tr. Khách sạn giữ 2tr (phòng khởi đầu cho người mới). Người đã có nhà không bị ảnh hưởng.
- Nếu admin từng lưu giá riêng trong tab Giá thì giá đó vẫn được ưu tiên, cần bấm khôi phục mặc định.

## Phiên bản 07.11-y · Mỗi tàu một kiểu hoả lực
- Thuyền Điêu: Pháo đôi (2 viên song song, 10 lần). Thiên Nga: Trứng nổ (bay vòng cung, nổ lan, 7 lần). Cá Heo: Tia nước (nhanh, tầm gần, 18 lần).
- Rồng Vàng: Phun lửa (3 luồng hình quạt, 10 lần). Đĩa Bay: Tia laze (rất nhanh, tầm xa, 2 sát thương, 8 lần). Cá Voi: Sóng thần (sóng lớn xuyên thấu, 2 sát thương, 6 lần).
- Bảng chỉnh hoả lực là WPN trong index.html. Thuyền nhỏ vẫn không có súng và không bị bắn.

## Phiên bản 07.11-x · Tàu hải tặc NPC
- Khi bạn lái thuyền vừa/lớn, thỉnh thoảng (30–120 giây) có tàu hải tặc xuất hiện, vòng quanh và bắn đạn chậm vào bạn (mỗi 4–6 giây, né được).
- Thuyền vừa: hải tặc 3 máu, thưởng 250k. Thuyền lớn: 5 máu, thưởng 600k (nhận khi về bến). Thuyền nhỏ được bảo vệ, không gặp hải tặc.
- Hải tặc tự bỏ đi sau 80 giây. Nếu bạn bị bắn chìm: mất nửa số cá và về bến như bị người khác bắn.
- Mỗi người chơi gặp hải tặc riêng, không cần đồng bộ hay sửa SQL.

## Phiên bản 07.11-w · Thuyền sáng tạo, bãi cá động, đại bác
- 9 thuyền mới: Chiếc Lá Xanh, Vịt Vàng Bơi Bơi, Thuyền Tình Ái; Thuyền Điêu (cướp biển), Thiên Nga Đạp Vịt, Cá Heo Nhảy Múa; Rồng Vàng Hoàng Gia, Đĩa Bay Alien, Cá Voi Phun Nước. Mỗi thuyền có hiệu ứng riêng, vệt sóng, lắc lư.
- Bãi cá động: 6 chỗ nước sủi bọt, đổi chỗ mỗi 90 giây (mọi người thấy giống nhau), cá búng lên mặt nước. Câu ở đó cá quý nhiều hơn và cắn nhanh hơn.
- Đứng một chỗ thả câu nhiều lần thì cá sợ, tỉ lệ cá đắt giảm dần, phải đổi chỗ.
- Hai lần thuê cách nhau 1 phút (lưu cả khi tải lại trang).
- Đại bác (phím F hoặc nút BẮN): thuyền vừa 3 máu 8 đạn, thuyền lớn 5 máu 14 đạn. Thuyền nhỏ được bảo vệ, không bị bắn. Bị chìm thì mất nửa số cá và về bến. Không cần sửa SQL (đạn đồng bộ qua vị trí người chơi).
- Giá bán cá giảm 20% (FISH_K=.8).

## Phiên bản 07.11-v · Thuê thuyền câu cá ngoài biển
- Quầy Thuê Thuyền ở bãi biển phía bắc (cạnh cầu tàu), có bến và thuyền đỗ trang trí.
- 3 cấp thuyền, mỗi cấp 3 kiểu (9 mẫu): Nhỏ 80k/3 phút, Vừa 350k/4 phút, Lớn 1,5tr/4 phút. Càng lớn càng nhanh và ra cá quý.
- Chèo tự do ngoài biển gần bờ (không vào màn riêng). E thả câu, chờ dấu ! rồi bấm E để giật. Bơi gần bóng cá thì cá cắn nhanh và hiếm hơn.
- 14 loại cá, giá phụ thuộc cân nặng. Hết giờ hoặc bấm VỀ BẾN thì tự bán cá. Người khác nhìn thấy thuyền và cần câu.
- Hằng số cân bằng nằm ở BTIER, FISHD, FW trong index.html.

## Phiên bản 07.11-u · Thu nhỏ quầy thông tin
- Quầy thông tin ngoài cổng nhỏ hơn khoảng 36%, vùng chắn và nhãn chữ thu theo.

## Phiên bản 07.11-t · Thú cưng chia theo loài, thêm 31 bé mới
- Quầy thú cưng có tab: Côn trùng (10), Động vật có vú (10), Chim (11), Cá & thủy sinh (10), Tâm linh (9). Tổng 50 bé, bé mới giá 2tr–50tr.
- Bán lại thú cưng chỉ nhận 70% giá (lỗ 30%).
- Thú mới được thêm vào cuối danh sách nên không ảnh hưởng thú đã mua. Admin chỉnh giá theo thứ tự mới.

## Phiên bản 07.11-s · Thời trang: tầm trung, đồ thể thao, giá rẻ, Cosplay hài

- Shop có **79 bộ**. Thêm 14 bộ tầm trung (1 đến 4 triệu, chia đều 7 nhóm cũ), nhóm mới **Đồ thể thao** (bóng đá, pickleball, đồ bơi, bóng rổ, tennis, yoga, chạy bộ, golf, lặn), 10 bộ giá rẻ (100 nghìn đến 800 nghìn), nhóm mới **Cosplay hài** (2 đến 6 triệu): Con Gián Bất Tử, Cục Phân Đôi Tình Bạn, Khố Rách Áo Ôm, Bậc Thầy Đa Cấp, 4 Shipper (xanh lá, cam, xanh dương, vàng).
- Thêm kiểu áo (`swim`, `roach`, `poo`, `rags`, `mlm`, `shipper`) và mũ (cap, headband, visor, goggles, sunhat, chef, roach, flies, rathat, slick, shiphelm). Chỉ là dữ liệu client, không cần SQL.

## Phiên bản 07.11-q · Nhật ký lỗi game cho admin

- Lỗi JavaScript trên máy người chơi (lỗi thường, promise bị từ chối, lỗi vòng lặp game) tự gửi về `errlog/<mã>` (tối đa 8 lỗi khác nhau mỗi phiên, chế độ thử nghiệm không gửi). Mỗi bản ghi: giờ, nhân vật, loại, nội dung, stack, vị trí, chế độ, kích thước màn hình, bản game, thiết bị.
- Admin: tab **LỖI GAME** xem danh sách, mở stack, nút XOÁ TẤT CẢ.
- **Cần chạy lại `supabase-setup.sql`** (thêm quyền ghi `errlog`, và chỉ admin mới nhận được dữ liệu này khi đồng bộ).

## Phiên bản 07.11-m · Tăng giá đất, nhân vật thử nghiệm (sandbox)

- Đất Vườn Liên Minh tăng ×1,5: Thường 45 triệu, Vàng 90 triệu (đã mua giá cũ không đổi).
- Admin: tab **THỬ NGHIỆM** chọn 1 nhân vật (lưu `config/tester`, không cần SQL mới).
- Nhân vật đó có nút THỬ NGHIỆM trong menu: game tải lại và chạy **tách biệt hoàn toàn** (ngắt mọi listener, database giả không ghi gì lên server). Có 5 tỷ, sở hữu cả 5 tháp, bảng test: dịch chuyển, vào phòng bất kỳ (Villa/Bungalow/KS), reset 10 phút xe ngựa, thêm bot để trồng cây liên minh. Thoát bằng nút THOÁT (tải lại về game thật).
- Thông báo khai trương/xe ngựa không còn là cửa sổ chặn game, chỉ là thẻ nhỏ góc phải (bản 07.11-l).

## Phiên bản 07.11-k · Dời ngân hàng, cửa xe ngựa, pháo hoa

- Techcombank dời ra giữa quầy Câu Cá và Pha Chế (650,1150).
- Hàng rào trái lâu đài có **cửa ra bãi xe ngựa** (y 1666 đến 1714), có cột đèn và nhãn.
- Xe ngựa lâu đài khi chạy có **pháo hoa và confetti** (số quả pháo tăng theo cấp tháp). Chỉ là hiệu ứng vẽ, không cần SQL.

## Phiên bản 07.11-i/j · Quầy Thông Tin, khai trương Vườn Liên Minh

- **Quầy Thông Tin** cạnh cổng chào (bên trái đường vào): 3 tab PHÒNG TRỐNG (giường/phòng trống theo Villa, Bungalow, Khách Sạn kèm giá), BẮT ĐẦU, CHỈ ĐƯỜNG; nút mở luật đầy đủ.
- **Bảng Vườn Liên Minh** trước cổng vườn: kể chuyện và hướng dẫn chi tiết; biển KHAI TRƯƠNG trên cổng.
- **Thông báo một lần** (lưu trong `state.an`, không cần SQL): khai trương Vườn Liên Minh cho toàn server; xe ngựa chỉ cho chủ Lâu Đài. Có nút tự đi tới vị trí.

## Phiên bản 07.11-h · Xe ngựa Lâu đài

- Bãi xe ngựa nằm ngoài lâu đài (cát bên trái hàng rào), 5 xe theo 5 cấp tháp: Quạ Đen (2 ngựa, +3%), Trăng Máu (3, +5%), Pha Lê Đen (4, +7%), Rồng Ngủ (5, +8,5%), Tối Thượng (6 ngựa kỳ lân cầu vồng, +10%). Độ đẹp ngựa và xe tăng theo cấp.
- Chỉ thành viên lâu đài (đã sở hữu suất ở tháp) mới lên xe; bấm E ở bãi để lên, E để xuống.
- Mỗi người dùng tối đa 10 phút/ngày (đổi ngày theo UTC+7), hết giờ xe tự chạy về bãi.
- Tăng tốc nhân cùng buff Vườn Liên Minh (Tốc độ).
- Người chơi khác thấy bạn ngồi trên xe (trường `cr` trong vị trí). Không cần cập nhật SQL.

## Phiên bản 07.11-g · Vườn Liên Minh (luật hiện hành)
Khu Vườn Tuổi Thơ đã thành **VƯỜN LIÊN MINH**: cổng mở, đi bộ vào được, 12 lô đất, mỗi lô trồng 1 **Cây Liên Minh**. Nút **LIÊN MINH** trong menu chính; đứng gần cổng hoặc từng lô bấm E cũng mở. Bấm vào một cây sẽ thấy bảng thông tin: tên liên minh, Gốc Chủ, tổng quỹ, thành viên, thuế, 5 thông số cây và danh sách thành viên xếp theo đóng góp. Thành viên liên minh có **biểu tượng cây** trên đầu nhân vật.
- **Đất** (mua một lần, **không có thuế đất**): 6 lô ngoài là Đất Thường 45 triệu (cây tối đa 30 điểm), 6 lô giữa là Đất Vàng 60 triệu (tối đa 40 điểm).
- **Hạt giống** (hình dáng + điểm gốc): Dừa Vàng 8tr (Tiền) · Anh Đào 5tr (May mắn) · Thông Gió 5tr (Tốc độ) · Sồi Chiến 5tr (Khổng Lồ) · Bồ Đề 5tr (Năng lượng) · Thế Giới Thụ 20tr (đều 5 kênh). Mỗi hạt có 2 kênh "ưa" (giá nâng cấp −20%) và 1 kênh "kỵ" (+30%).
- **Gốc Chủ đặt tên liên minh**, đổi tên được, mở hoặc đóng đăng ký (đóng thì chỉ người được mời mới vào), mời người online (lời mời lưu 24 giờ), mời ra, nhường chức, trả lại đất.
- **Thành viên:** tối thiểu 3 người mới được TRỒNG, tối đa 10. Level tối đa = 5 × số thành viên, tính đến 8 người (3 người: 15, 8 người: 40), và không vượt giới hạn của lô. Thiếu 3 người thì buff còn 50%. Mỗi người chỉ ở 1 liên minh; rời xong chờ 12 giờ. Vào sau khi cây đã trồng phải trả phí 250.000₫ × số điểm cây (vào quỹ).
- **Thuế thành viên = % tiền thưởng** kiếm được từ ván game và Team Building (trừ ngay khi nhận thưởng, Gốc Chủ cũng đóng): 3% (mặc định), 6% mở từ Lv15, 10% mở từ Lv30. Gốc Chủ chọn mức. Mọi người có thể góp thêm vào quỹ.
- **Quỹ cây chỉ dùng để mua dinh dưỡng nâng cấp** (Gốc Chủ không rút được). Muốn nhanh thì Gốc Chủ tự góp tiền vào quỹ.
- **Nâng cấp dinh dưỡng:** điểm thứ k giá 490.000₫ × 1,11^k (nhân 0,8 nếu kênh hạt ưa, 1,3 nếu kỵ), tối đa 10 điểm mỗi kênh. Lv30 ≈ 95 triệu, **Lv40 ≈ 283 triệu** (hạt thường, kênh thường). **Mỗi lần nâng cấp mất thời gian** và chỉ làm được từng lần một: lần đầu 30 phút, mỗi điểm sau nhân 1,12 (Lv15 khoảng 10 giờ cộng dồn, Lv30 khoảng 3 ngày, Lv40 khoảng 10 ngày). Tiền trừ ngay khi bắt đầu, điểm cộng khi xong.
- **5 kênh, hiệu ứng ở 10 điểm:** Tiền +8% thưởng ván game và Team Building · May mắn +30% thưởng nhặt (gián, ông già, Bụt) và tỉ lệ trúng vé số · Tốc độ +15% · Năng lượng −30% hao khi đứng/đi và hồi khi ngủ nhanh hơn 25% (không giảm phí 6% mỗi ván) · Khổng Lồ nhân vật ×1,25, +30% sát thương quái, đổi lại hao năng lượng +10%.
- Cây hiển thị trên lô theo 4 giai đoạn (Mầm, Cây con, Trưởng thành, Cổ thụ), màu quả theo kênh nổi trội. Hạnh phúc có nguồn "Cây Liên Minh" (tối đa +4/ngày).
- **Hoãn:** kỹ năng đặc biệt, trang admin cho Vườn Liên Minh, bảng xếp hạng cây.

### SQL
- **Chỉ cần chạy `supabase-setup.sql`** trong Supabase SQL Editor (đã gồm mọi cập nhật, chạy lại an toàn, không xoá dữ liệu). Các file cập nhật lẻ cũ được dời vào thư mục `sql-cu/`, không cần chạy nữa.

## 08.11-e
- Dời Hair Salon Tóc Thề xuống thấp hơn (y 1140 → 1225) để không che hàng Bungalow phía trên.

## 08.11-f
- Salon tóc dời xuống ngay dưới Quầy Thú Cưng (x 1500, y 1310), không đè quầy.
- Thiết kế lại 3 kiểu tóc to và lạ hơn: Pompadour Sóng Thần (m1), Sóng Biển Cuộn Trào (m5), Bob Pha Lê Bất Đối (f3).
- Thêm 2 kiểu mới: Xù Bông Mây Bão (m7, nam, 5tr) và Dài Lê Thê Quét Đất (f7, nữ, 9tr, tóc dài chạm đất). Mỗi giới giờ có 7 kiểu; admin tab Cửa hàng đã có sẵn 2 kiểu mới.

## 08.11-g
- **Team Building thưởng x3** (2,25tr → 7,2tr tuỳ level), booth có biển "X3 TIỀN THƯỞNG".
- **Tiệm thời trang đổi tên "Ếch&Em"** (logo ếch xanh vẽ riêng).
- **Kinh tế bến tàu**: thuê 2 phút cho cả 3 hạng. Thuyền nhỏ 100k, vừa 300k, lớn 600k. Mô phỏng 4.000 chuyến: nhỏ ≈ 2,6tr, vừa ≈ 3,7tr (+40%), lớn ≈ 4,4tr (+65%, dùng lưới kéo 2–3 con/mẻ). Có mức tối thiểu bến bù cho chuyến đủ 60 giây trở lên và không bị chìm (2tr / 2,7tr / 3,1tr), và cơ chế cá đắt dễ cắn hơn khi chuyến đi đang chậm.
- Mọi tàu đều có xác suất nhỏ dính cá quý trên 1 triệu (nhỏ ~0,4%, vừa ~1%, lớn ~0,3% mỗi con; bãi cá động tăng lên).
- **Hải tặc 3 cấp, dùng chung cho mọi người**: cấp 1 (3 máu, thưởng 1,2tr), cấp 2 (5 máu, 2,8tr), cấp 3 (8 máu, 6tr, bắn 2 sát thương). Nhiều người cùng bắn thì thưởng chia theo số phát trúng.

## 08.11-h
- **Mọi minigame có 3 độ khó**: Cấp 1 (ban ngày, thưởng ×1, miễn phí), Cấp 2 (hoàng hôn, ×2, phí 100.000₫, nhanh hơn 20%, nhiều bẫy hơn), Cấp 3 (đêm neon, ×3, phí 250.000₫, nhanh hơn 40%, nhiều bẫy, vật phẩm phát sáng viền neon). Hình nền và vật phẩm đổi màu theo cấp. Đứng ở khu game bấm E để chọn cấp.
- **Mục THÁCH ĐẤU** ở mọi game: chọn một người đang online, chọn cấp độ và tiền cược 1–10 triệu. Hai bên chơi cùng một màn (cùng hạt giống ngẫu nhiên), điểm cao hơn thắng toàn bộ cược, hoà thì hoàn tiền, bỏ cuộc quá 2 phút thì xử thua. Cược bị trừ khi cả hai vào trận. Dùng đường dẫn `duels/` đã có sẵn trong `supabase-setup.sql`, không cần chạy SQL mới.
- **Bến Thuyền Bãi Trái** (bên trái khu villa): thuê thuyền như bến chính, xuất phát và về lại đúng bến đã thuê.
- **2 game bãi biển mới** cạnh bến đó: **Săn Kho Báu** (đào ô cát có máy dò kim loại, mỗi bãi sắp xếp rương, kim cương, chai thư, bom, cua ngẫu nhiên, màu cát và bầu trời đổi mỗi lần) và **Lâu Đài Cát** (xếp tầng khối cát, có gió bất chợt, màu khối và kiểu cửa sổ khác nhau mỗi lâu đài).

## 08.11-i
- Thời gian chờ giữa 2 lượt chơi thường theo cấp: cấp 1 = 1 phút, cấp 2 = 2 phút, cấp 3 = 3 phút (chung cho mỗi khu game).
- Thách Đấu: mỗi người gửi lời thách cách nhau 3 phút (tính từ lúc gửi và từ lúc nộp điểm trận trước). Bị từ chối thì cũng phải chờ 3 phút mới mời tiếp.

## 08.11.2026-j · 3 game VIP của Lâu Đài

Ba quầy nhỏ lấp lánh nằm ở sân phía đông Lâu Đài Tình Báo (cạnh đường lát đá, ai cũng chơi được):

| Game | Cách chơi | Điểm chính |
|---|---|---|
| **Tình Báo** | Chộp hồ sơ trong 5 két sắt, tránh 2–3 đèn pha quét ngang | Hồ sơ +110k, cặp vàng +330k, bị đèn rọi −150k và khoá tay 1 giây |
| **Pháp Thuật Hắc Ám** | Bắn phép Lửa/Băng/Độc đúng màu con quái thấp nhất (phím 1 2 3, Z X C hoặc bấm nút) | Quái +60k, combo tăng tới ×2, sai màu −120k, quái chạm đất mất 1 tim, về sau có quái 2 màu |
| **Đua Chổi** | Bay 3 làn (← →, hoặc chạm trái/giữa/phải), qua vòng thần và sao, né mây giông và dơi | Vòng +55k, sao +160k, liên tiếp tăng thưởng, va chạm −150k, tốc độ tăng dần |

- **Vé vào 600.000₫**, chờ 2 phút mới chơi lại cùng quầy. Điểm số thực tế của bot thử: người chơi khá khoảng 4–4,5 triệu, trung bình khoảng 2,4–3,4 triệu, người chơi tệ lỗ vé. Cao hơn cấp 3 bên ngoài khoảng 50%.
- **Ban đêm (19h–5h) thưởng +10%.**
- **Thuế chủ Lâu Đài**: trừ vào tiền thưởng của người chơi, chia cho các thành viên của tháp đã đủ 3 chủ (mỗi tháp chia đều 3 người): Quạ Đen 1%, Trăng Máu 1,5%, Pha Lê Đen 2%, Rồng Ngủ 2,5%, Tối Thượng 3%. Tối đa 10% khi cả 5 tháp có chủ. Chủ nhận tiền qua `gifts/` (không cần sửa SQL), chủ đang online sẽ thấy thông báo "Thu nhập chủ Lâu Đài".
- Các hằng số nằm ở đầu khối `GAME VIP CỦA LÂU ĐÀI` trong `index.html`: `CZ_FEE`, `CZ_CD`, `CZ_NIGHT`, `CZ_SH`.

## 08.11.2026-k · Đêm sáng hơn, admin tạo username, 4 kiểu tóc cao, dời quầy VIP

- **Ban đêm bớt tối:** lớp phủ ban đêm nhẹ hơn nhiều (còn khoảng 60% độ sáng thay vì 25%), vẫn có màu xanh đêm và đèn phát sáng nhưng nhìn rõ vật phẩm.
- **Admin tạo username:** chọn người chơi chưa có tài khoản trong tab Người chơi, admin sẽ thấy sẵn username gợi ý (từ tên hiển thị) và mật khẩu ngẫu nhiên, sửa tuỳ ý rồi bấm TẠO USERNAME. Nút TẠO USERNAME CHO TẤT CẢ NGƯỜI CHƯA CÓ tạo hàng loạt và hiện bảng Tên / Username / Mật khẩu để sao chép gửi riêng. **Cần chạy 1 lần** `sql-cu/supabase-update-admin-create-account.sql` trong Supabase SQL Editor (đã gộp sẵn vào `supabase-setup.sql`).
- **4 kiểu tóc mới (2–4 triệu):** Goku Chĩa Chủa 2,5tr, Bờm Ngựa Phi Nước Đại 3,2tr, Thủy Thủ Mặt Trăng 3,8tr, Tháp Eiffel Chọc Trời 4tr (đã thêm vào bảng giá admin). Kiểu tóc cao dùng `ex` (số dòng thêm phía trên đầu): khung nhân vật tự cao thêm, mọi chỗ vẽ nhân vật vẫn giữ chân đúng vị trí.
- **3 quầy VIP Lâu Đài** dời ra ngay cạnh cổng trước của sân Lâu Đài, xếp ngang để dễ thấy.

## 08.11.2026-l · Game VIP Lâu Đài: vé 300k, 3 cấp độ

- **Vé vào 300.000₫** cho mọi cấp (hằng số `CZ_FEE`).
- **3 cấp như minigame**, thưởng ước tính: Cấp 1 DỄ 0,8–1,5 triệu · Cấp 2 KHÓ 2–4 triệu · Cấp 3 SIÊU KHÓ 4–6 triệu. Cấp thấp chậm hơn, ít bẫy, két mở lâu hơn, chưa có quái 2 màu, đèn pha ít hơn; cấp cao nhanh và nhiều bẫy.
- Hệ số thưởng chỉnh trong `CZMUL` (theo game và cấp), độ khó trong `CZLV`. Đêm vẫn +10%, thuế chủ Lâu Đài vẫn trừ vào tiền thưởng.
- Thời gian chờ chơi lại theo cấp giống minigame: 1 / 2 / 3 phút.
- Số liệu ước tính từ bot mô phỏng (người thật thường thấp hơn bot giỏi một chút).

## 08.11.2026-m · Mã "mattroidem": mặt trời đêm

- Gõ `mattroidem` vào khung chat (không phân biệt hoa thường, dấu cách, dấu) khi **trời tối** (từ 17h30 đến 6h30) và đang đi ngoài resort: tốn **300.000₫** (`SUN_FEE`), tạo một mặt trời nhỏ lơ lửng trên đầu và vầng sáng ấm bán kính khoảng 230px quanh người dùng mã trong **3 phút**, mờ dần ở những giây cuối.
- Ban ngày gõ mã sẽ bị từ chối và **không bị trừ tiền**. Gõ lại khi đang hiệu lực thì tính 300.000₫ nữa và đếm lại 3 phút.
- Hiệu ứng chỉ hiện trên máy người dùng mã (không đồng bộ sang người chơi khác).

## 08.11.2026-n · Thực đơn 10 món có hình, thực phẩm chức năng, thời gian ăn

- **10 món, mỗi món có hình pixel-art** (vẽ bằng code): Nước dừa 40k, Kem dừa 60k, Bánh mì 100k, Phở bò 150k, Cơm gà 200k, Hải sản 400k, cộng 4 thực phẩm chức năng (viền vàng).
- **Thực phẩm chức năng** (không mua lại khi đang còn hiệu lực, lưu cả khi tải lại trang):
  - **Redbull** 2tr: chạy nhanh hơn 10% trong 5 phút.
  - **Trà Xanh Tiêu Hoá** 3tr: khi buồn vệ sinh được chờ 60 giây thay vì 30, hiệu lực 1 ngày game (`CFG.DAY` giây).
  - **Xôi No Lâu** 2tr: năng lượng tụt chậm một nửa trong 1 ngày game (+15% năng lượng).
  - **Collagen** 3tr: phát sáng nhẹ vừa đủ thấy đường vào ban đêm, 1 ngày game.
- **Thời gian ăn 15–30 giây** tuỳ món (dừa 15s … hải sản 30s). Trong lúc ăn nhân vật đứng yên nhai nhóp nhép, cầm món ăn nhấp nhô, có hiệu ứng riêng từng món (giọt nước, hơi nóng, vụn bánh, tia chớp, lá trà, lấp lánh…), tim bay lên, câu khen "Ngon quá trời!" và thanh tiến độ. Năng lượng và hiệu ứng nhận khi ăn xong. Đồng hồ buồn vệ sinh tạm dừng khi đang ăn để không bị tai nạn.
- Bot không mua thực phẩm chức năng. Admin thống kê lượt mua đủ 10 món.

## 08.11.2026-o · Cấp 3 minigame khó hơn

Cấp SIÊU KHÓ của các minigame thường (không áp dụng cho game Lâu Đài): thưởng ×3 → **×2,5**, nhịp nhanh hơn 40% → **55%**, tần suất vật phẩm dày hơn, bẫy 14% → **22%**. Chỉnh trong `LVS` (`mul`, `sp`, `v`, `bad`) ở `index.html`. Thách đấu không tính thưởng nhân nên không đổi tiền, chỉ màn chơi cấp 3 khó hơn.

## 08.11.2026-p · Bản đồ desktop bớt phóng to

Trên màn hình rộng (từ 900px) khung nhìn trước đây luôn ép về khoảng 420×260 điểm ảnh thế giới nên bị phóng to 3–4 lần. Nay mục tiêu là khoảng 700×390: màn 1440×800 thấy 720×400, màn 1920×1080 thấy 960×540 (mỗi điểm ảnh phóng gấp 2). Điện thoại/màn hẹp giữ nguyên. Công thức ở hàm `resize()`.

## 08.11.2026-p · Bản đồ desktop bớt phóng to

Khung nhìn desktop (cửa sổ rộng từ 900px) trước đây dùng hệ số phóng to nguyên (2×, 3×), nên màn hình lớn thấy bản đồ rất gần (1440×780 chỉ thấy khoảng 720×390 điểm ảnh bản đồ, màn 2560 bị 3×). Nay hệ số tính theo mục tiêu thấy khoảng 805×448 điểm ảnh (bản 08.11-q zoom thêm ~15% so với 08.11-p), làm tròn xuống bước 0,05, tối thiểu 1,4. Điện thoại và cửa sổ hẹp giữ nguyên. Chỉnh trong hàm `resize()`: đổi 900 và 500 để phóng to hoặc thu nhỏ thêm.

**08.11.2026-q:** zoom gần thêm khoảng 15%: mục tiêu khung nhìn 805×448 điểm ảnh (1440×780 thấy khoảng 830×450, 1920×950 thấy khoảng 920×460), bước làm tròn 0,05. Chỉnh hai số 805 và 448 trong `resize()`.

## 08.11-r · Bảng thông số nhân vật
- Bảng xếp hạng (BXH): bấm vào tên một người chơi để xem **thông số** (tiền, tốc độ, thu nhập minigame, may mắn, hồi/tiết kiệm năng lượng, Khổng Lồ).
- Chỉ số cộng từ **Liên Minh** (dài hạn) hiện **màu xanh lá, có dấu +** (vd. `100% +6%`, tốc độ `84 +5.2`). Ngựa/thú cưỡi của bản thân cũng hiện `+` xanh ở tốc độ.
- Admin: bấm một người chơi trong danh sách → khung bên phải có mục **Thông số** cùng định dạng (đọc dữ liệu `lm` realtime).

## 08.11-s · BXH: bấm cả dòng để xem thông số (có dòng gợi ý), dùng event delegation

## 08.11-t · Lâu đài 70% + lính hoàng gia + sửa bảng thông số
- Bảng thông số mở ra thì BXH tự đóng; bỏ gạch chân dưới tên.
- Lâu đài (hình, tháp, cửa, vùng bấm, ánh sáng, nhãn tháp, hiệu ứng) thu nhỏ còn **70%**.
- **8 lính hoàng gia** đi tuần quanh lâu đài (vị trí theo giờ server nên mọi người thấy giống nhau). Thành viên đang giữ tháp lâu đài đi gần sẽ được lính **cúi chào** + "Kính chào!".

## 08.11-u · Vật phẩm Limited · Túi Thần Kỳ · Thương Xá Tắc
- **20 món Limited** (10 trang phục + 10 thú huyền bí), 4 hạng: Thường (không công năng) / Hiếm (1) / Rất hiếm (2) / Huyền thoại (3 công năng). Công năng: tốc độ, may mắn, tiền minigame, phát sáng trong đêm, bơi lội. Mỗi chỉ số chỉ lấy món cao nhất; trần tốc độ +7%, tiền/may mắn +1,5%.
- **Rơi ngoài bản đồ** (mọi người cùng thấy, mỗi người nhặt 1 phần): trang phục là **Đống Phân** (Bạc / Vàng / Kim Cương / Ánh Tím Huyền Thoại), thú là **Trứng** (Trắng / Bạc / Vàng / Ánh Tím). Tự rơi theo giờ server (10 phút/lượt, tồn tại 5 phút). **Khuyến mãi +5% trọng số mỗi món** đến 15/11/2026 (admin chỉnh được), sau đó về tiêu chuẩn.
- **Túi Thần Kỳ** (nút TÚI): giữ trang phục/thú Limited, mặc/cất, bán lại shop theo giá mặc định, **ghi số lượng đã nhận từng loại + lịch sử nhận** (nhặt / admin tặng / mua / bán).
- **Thương Xá Tắc** (cạnh Techcombank): mỗi người một quầy (tối đa 8 món), tự đặt giá; mua qua hàm `rt_lim_buy`.
- Ếch&Em và Quầy Thú Cưng có tab **LIMITED** (xem được, không mua được).
- **Admin → tab LIMITED**: nút thả Phân/Trứng từng hạng hoặc ngẫu nhiên, thu hồi, chỉnh hạn khuyến mãi, danh mục + số đã nhận/đang giữ; panel người chơi hiện Túi Thần Kỳ + lịch sử + nút tặng vật phẩm.
- **Cần chạy 1 lần trong SQL Editor:** `sql-cu/supabase-update-limited.sql` (đã gộp vào `supabase-setup.sql`). Chưa chạy thì mua ở Thương Xá báo lỗi, các phần khác vẫn chạy.

## 08.11-v · Dời Thương Xá Tắc và Techcombank
- Thương Xá Tắc và Techcombank dời xuống phía dưới bên trái (khu riêng, dưới hàng bungalow), không còn che bungalow B06–B10. Đường đi tới hai nơi đã kiểm tra thông.

## 08.11-w/x · Giao diện Thương Xá Tắc + sửa lỗi loá sáng
- **Sửa lỗi nghiêm trọng:** màn hình bị loá trắng vào buổi chiều/tối (hàm vẽ ánh sáng của vật phẩm Limited gọi hàm không tồn tại làm hỏng chế độ trộn màu). Đã sửa và bọc `try/catch`.
- Thương Xá Tắc đổi giao diện: mái hiên sọc nhiều màu, đèn nhấp nháy, mỗi người bán một quầy màu riêng, thẻ hàng viền/phát sáng theo hạng (Huyền thoại nhấp nháy), nhãn hạng, giá dạng đồng xu vàng. Thẻ trong Túi Thần Kỳ cũng viền màu theo hạng.

## 08.11-y · Chống mất vật phẩm, ghi tên người mua/bán, danh mục Limited có viền theo hạng
- Lưu Túi Thần Kỳ lên máy chủ nay có **báo lỗi + tự thử lại 3 lần**; nếu lần lưu gần nhất lỗi thì client **không nhận bản cũ từ máy chủ** mà đẩy lại (tránh món vừa nhặt biến mất do ghi hỏng/đồng bộ trễ).
- Lịch sử túi ghi thêm **tên người mua** (khi bán) và **tên người bán** (khi mua). Cần chạy lại `sql-cu/supabase-update-limited.sql` (idempotent) để có tên.
- Admin → tab LIMITED: danh mục hiện dạng thẻ **viền màu theo hạng** (Thường/Hiếm/Rất hiếm/Huyền thoại), nhóm theo Trang phục/Thú; túi người chơi hiển thị chip viền màu theo hạng.

## 08.11.2026-z — Admin: theo dõi vật phẩm Limited
- Tab LIMITED (admin) có thêm thẻ **Theo dõi vật phẩm Limited**:
  - Tổng quan: số món đang giữ / số người giữ, nhặt ngoài map, admin tặng, giao dịch Thương Xá, tổng tiền giao dịch, bán lại shop.
  - Bảng **Ai đang giữ**: mỗi món có số đang giữ, tên người giữ và tổng đã nhận.
  - Bảng **Đang rao ở Thương Xá**: món, người bán, giá, giờ đăng.
  - **Dòng thời gian** toàn server (200 bản ghi mới nhất): người chơi, món, nguồn, giá, đối tác mua/bán.
  - Bộ lọc theo món, nguồn và tên người chơi. Tự cập nhật khi dữ liệu người chơi hoặc chợ thay đổi.
- Không cần chạy SQL mới.

## 09.11.2026-a — Giới hạn vật phẩm Limited rơi mỗi ngày
- Chống lạm phát: mỗi ngày (24h, tính theo ngày giờ Việt Nam, 00:00–24:00) chỉ tối đa **X** vật phẩm Limited rơi ngoài map. Mặc định **X = 12**.
- Admin → tab LIMITED → ô "Tối đa vật phẩm rơi / ngày" → LƯU (lưu vào `config/lim/dayMax`). Đặt 0 để tắt hẳn rơi tự nhiên.
- Cách chọn: mỗi ngày có 144 ô 10 phút, chọn X ô bằng hash cố định nên rải đều cả ngày; mọi máy tính ra cùng kết quả, không cần SQL.
- Món admin thả bằng nút thả và món admin tặng không bị tính vào giới hạn này.
- Giữ nguyên quy tắc cũ: mỗi người nhặt được 1 bản mỗi lần rơi.

## 09.11.2026-b — Chuyển 13 món shop sang Limited, nút tắt rơi, báo cáo rơi/ngày
- **13 món chuyển sang Limited** (hết bán trong shop, vẫn hiện trong shop với nhãn Limited, chỉ nhặt hoặc mua ở Thương Xá):
  - Trang phục (id mới `lo11`–`lo18`): Thiên Sứ Cầu Vồng, Tiền Tài Kéo Dài Lê Thê (Huyền thoại); Hiệp Sĩ Cưỡi Rồng, Hoàng Bào Long Phụng (Rất hiếm); Vua Mặt Trời, Công Chúa Thiên Nga, Lọ Lem Xe Bí Ngô (Hiếm); Cánh Xe Ngựa Hoàng Gia (Thường).
  - Thú (id `lp11`–`lp15`): Rồng 3 Đầu (Huyền thoại); Phượng Hoàng Witty, Kỳ Lân (Rất hiếm); Con Ong Cháu Cha (Hiếm); Gấu Trúc (Thường).
  - Công năng nhẹ theo hạng, vẫn dưới trần: tốc độ ≤7%, tiền ≤1,5%, may mắn ≤1,5%.
  - Giá bán lại cho shop: trang phục 50% giá gốc, thú 70% giá gốc (như refund cũ), tránh nhặt rồi bán lấy lãi.
  - Dùng id `lo*`/`lp*` nên **không cần chạy lại SQL** (`rt_lim_buy` kiểm theo mẫu id này).
- **Người đã mua trước**: khi vào game, đồ đang sở hữu tự chuyển vào Túi Thần Kỳ (lịch sử ghi "Chuyển từ shop sang Túi"). Đang mặc/nuôi thì giữ nguyên. Từ đó bán được ở Thương Xá.
- **Sửa cách tính giới hạn/ngày**: trước đó 12 ô còn bị lọc thêm 80% nên thực tế ~9,6 món; nay chọn đúng X ô trong số ô đủ điều kiện, mỗi ngày đúng X món (X mặc định 12).
- **Admin → LIMITED**:
  - Nút **TẮT/BẬT RƠI TỰ NHIÊN** (`config/lim/dropOff`). Nút thả của admin vẫn dùng khi đang tắt.
  - **Báo cáo hôm nay**: rơi tự nhiên đã rơi / tối đa, trạng thái, số admin thả, lượt đã nhặt, giờ rơi tiếp theo, lịch rơi cả ngày (ngày VN).
  - Danh mục có thêm 13 món mới.

## 09.11.2026-c — Admin: popup chi tiết người chơi
- Bấm vào một người chơi trong tab NGƯỜI CHƠI sẽ mở **popup** (đóng bằng nút ĐÓNG, phím Esc hoặc bấm ra ngoài). Popup tự cập nhật theo dữ liệu mới.
- Đầu popup: **hình nhân vật hiện tại** (đúng ngoại hình, tóc, trang phục đang mặc), các thú đang nuôi, username, trạng thái, năng lượng.
- 6 tab:
  1. **Tổng quan**: tiền mặt, tiền gửi ngân hàng, **tổng tài sản theo giá cơ bản** (villa, bungalow, phòng, chỗ lâu đài, vật trang trí, trang phục, thú, Túi Limited, liên minh) và **thẻ chỉ số cá nhân**: dấu **+ xanh lá** là chỉ số từ liên minh, dấu **+ tím** là chỉ số từ trang phục và thú Limited đang trang bị (tốc độ, minigame, may mắn, hồi năng lượng, khổng lồ, phát sáng đêm, bơi).
  2. **Túi & tủ đồ**: icon vật phẩm trong Túi Thần Kỳ (viền theo hạng, kèm số lượng), trang phục thường đang sở hữu, thú đang nuôi.
  3. **Item đặc biệt**: bộ sưu tập đủ 33 món Limited (món chưa có thì mờ), số giữ/số đã nhận, lịch sử item có icon.
  4. **Tài sản**: giường và bất động sản (kèm người ở cùng), chỗ lâu đài, vật trang trí đã đặt (icon), liên minh đang tham gia và thành viên, số lượt mua theo bộ đếm.
  5. **Lịch sử tiền**: tiền vào/ra, lọc và tìm theo lý do (cần SQL `supabase-update-admin-log.sql` như tab Lịch sử tiền cũ).
  6. **Quản trị**: tặng tiền, tặng vật phẩm Limited, tài khoản, đổi mật khẩu.
- Hình ảnh được vẽ bằng trang phụ **`avatar.html`**, sinh tự động từ `index.html` bằng `python3 tools/make-avatar.py`. Trang này không nạp Supabase, không đăng nhập, nên không đụng phiên admin. **Sau mỗi lần sửa `index.html` phải chạy lại lệnh này** để hình và bảng giá khớp game.
- Fix nhỏ: món đã chuyển sang Limited giữ lại id cũ (`oid`) để admin nhận ra đồ cũ trong tủ.

## 09.11.2026-e — Pha chế khó hơn, cá biển lạ, trần ngân hàng
- **Pha chế**: khó hơn và tiền giảm 30%.
  - Đơn dài hơn 1 nguyên liệu mỗi giai đoạn (5/6/7, cấp 3 thêm 1), khách kiên nhẫn ít hơn (3,3–6,2s xuống 2,5–4,9s cộng 0,38s mỗi nguyên liệu).
  - Cho nhầm nguyên liệu: mất tiền như cũ, đổ ly làm lại từ đầu và **trừ thêm 0,9 giây kiên nhẫn** của khách.
  - Tiền mỗi ly: 17.500₫ xuống 12.250₫ mỗi nguyên liệu (−30%), thưởng nhanh tối đa 31.500₫ xuống 22.000₫. Tiền phạt giữ nguyên.
- **Câu cá biển, thuyền cấp 2 và 3**: thêm nhóm **cá biển lạ** giá cao, cực hiếm (không có ở thuyền cấp 1): Cá Lồng Đèn Vực Sâu, Cá Rồng Biển Bạch Kim, Cá Mặt Trăng Phát Quang, Bạch Tuộc Ngọc Trai, Cá Kỳ Lân Sừng Xoắn, Rùa Cổ Thần Rong Vàng (3tr đến khoảng 9tr mỗi con). Tỉ lệ khoảng 0,25% mỗi con ở thuyền cấp 2 và 0,45% ở cấp 3, tăng khi câu ở bãi cá động. Có thông báo riêng khi câu được.
- **Techcombank**: tổng số dư gửi tối đa **100 triệu** (cộng mọi sổ đang gửi). Lãi 6% nay cần **15 ngày game** (trước là 10 ngày). Sổ đã gửi trước đó giữ nguyên kỳ hạn và lãi cũ. Nút "TẤT CẢ" đổi thành "TỐI ĐA" (theo hạn mức còn lại).

## 09.11.2026-f — Lịch sử tiền ghi rõ lý do thưởng ván game
- Trước đây dòng "+X ₫" của một ván game hiện lý do là "Thuế liên minh −Y ₫" (vì toast thuế hiện sau cùng). Nay lý do ghi "Thưởng ván <tên game> cấp N (đã trừ thuế liên minh Y)". Số tiền X là tiền thực nhận sau thuế.

## 09.11.2026-g — Cân bằng kinh tế lần 2
- **Techcombank**: tổng số dư các sổ tối đa **120 triệu**. Kỳ hạn dài nhất là 15 ngày game, lãi **5%** (trước là 6%, trần 100tr). Các mức 1 ngày 1%, 3 ngày 2%, 5 ngày 3% giữ nguyên. Sổ đã gửi giữ nguyên lãi và kỳ hạn cũ.
- **Giá ×1,5**:
  - Villa: 25tr xuống 37,5tr mỗi giường.
  - Lâu đài: 20/40/60/80/100tr xuống 30/60/90/120/150tr mỗi người.
  - Đất liên minh: Thường 45tr xuống 67,5tr, Vàng 90tr xuống 135tr.
  - Hạt giống: 8tr xuống 12tr (Dừa Vàng), 5tr xuống 7,5tr (Anh Đào, Thông Gió, Sồi Chiến, Bồ Đề), 20tr xuống 30tr (Thế Giới Thụ).
  - Giá nâng điểm cây liên minh: gốc 490.000₫ xuống 735.000₫ (vẫn nhân 1,11 mỗi điểm, kênh ưa ×0,8, kênh kỵ ×1,3).
- Đã cập nhật chữ hướng dẫn trong game và giá mặc định trong tab Cửa hàng của admin.
- **Lưu ý**: nếu admin từng bấm LƯU GIÁ trong tab Cửa hàng, giá lưu trên server sẽ ghi đè giá mặc định trong code. Khi đó cần bấm MẶC ĐỊNH rồi LƯU GIÁ lại.
- Đồ người chơi đã mua không bị ảnh hưởng.

## 09.11.2026-h — Luật lâu đài mới + giảm giá Limited
- **Bán chỗ lâu đài**: bấm "MUA CHỖ CỦA <tên>" ở tháp, chọn giá, gửi đề nghị (giống mua giường villa, 30 giây). Người bán đồng ý thì máy chủ chuyển chỗ, người bán nhận tiền, người mua nhận chỗ (giá đã trả được ghi lại để tính hoàn tiền).
- **Trả chỗ**: bấm 2 lần "TRẢ CHỖ". Tháp đã hoạt động thì hoàn **70%** giá đã trả (mất 30%), chưa đủ người thì hoàn đủ. Có người trả chỗ thì liên minh tạm dừng, chờ đủ 3 người.
- Bỏ luật bỏ phiếu thoát và mất toàn bộ tiền.
- **Giảm giá Limited**: Thiên Sứ Cầu Vồng 30tr, Tiền Tài Kéo Dài Lê Thê 42tr, Hiệp Sĩ Cưỡi Rồng 12tr, Hoàng Bào Long Phụng 15tr, Công Chúa Thiên Nga 8tr, Lọ Lem Xe Bí Ngô 5tr, Cánh Xe Ngựa Hoàng Gia 4tr (cập nhật cả giá cơ bản trong admin).
- **SQL cần chạy**: `sql-cu/supabase-update-castle-trade.sql` (cần đã chạy `supabase-update-castle.sql`).
- Lưu ý: nếu admin từng lưu giá riêng cho các món này trong tab Cửa hàng thì giá lưu trên server sẽ ghi đè, cần bấm MẶC ĐỊNH rồi LƯU GIÁ.

## Sửa lỗi mất liên minh khi sang máy khác (SQL)
- Nguyên nhân: `rt_move_player` (dùng cho Mã đồng bộ và Đăng nhập tài khoản) chuyển nhân vật, giường, đấu, lâu đài nhưng không chuyển **liên minh** (`lm/*`). Người chơi sang máy mới thành uid mới, trong liên minh vẫn còn uid cũ làm "thành viên ma".
- Sửa: chạy `sql-cu/supabase-update-move-lm.sql` (hàm đã thêm `lm/%`). Từ đó các lần chuyển máy sau giữ nguyên liên minh. Các uid ma đã sinh ra từ trước cần sửa tay (xem `sql-cu/check-user-lm.sql` để dò).

## 09.11.2026-i — Chặn mở 2 tab cùng lúc
- Các tab cùng trình duyệt dùng chung phiên đăng nhập (cùng uid), nên mở 2 tab là 2 màn hình chơi cùng 1 nhân vật. Tab cũ vẫn lưu đè dữ liệu, tab mới đăng nhập nhân vật khác sẽ chuyển dữ liệu về uid đó, gây lẫn tiền, liên minh, v.v.
- Giờ chỉ 1 tab được chơi: mở tab thứ hai sẽ thấy màn chặn, có nút DÙNG TAB NÀY (tab kia tự dừng, không còn ghi dữ liệu). Khoá tự hết hạn sau 75 giây nếu tab đóng đột ngột.
- Không cần chạy SQL mới.

## 09.11.2026-j — Xe ngựa lâu đài nhanh hơn
- Tốc độ di chuyển khi đi xe ngựa tăng thêm 5 điểm %: tháp 1 đến 5 từ 3 / 5 / 7 / 8,5 / 10% lên **8 / 10 / 12 / 13,5 / 15%**. Không cần chạy SQL.

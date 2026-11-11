# Ý tưởng (CHƯA LÀM): Chỉ số thu hút

Trạng thái: **đã phân tích, chưa triển khai** (lưu 11/11/2026). Chờ bạn xác nhận 4 điểm ở cuối.

## Yêu cầu gốc
Thêm "Chỉ số thu hút". Vượt các cột mốc thì hút người ở gần đi theo mình. Tăng khi sức khoẻ tăng, mặc trang phục đắt tiền, có làm đầu tóc. Bị trừ nặng khi tiểu tiện.

## Điểm cần lưu ý
- Người chơi thật không thể bị kéo đi (mỗi máy tự điều khiển). Bot chỉ có khi server cấu hình `bots` > 0 (mặc định 0), nên đề xuất tạo **Fan**: NPC hâm mộ tự xuất hiện quanh người chơi.
- "Tiểu tiện" hiểu là **tiểu không kịp** (dính nước tiểu). Đi WC đúng lúc không bị trừ (đang được cộng hạnh phúc).

## Công thức (0–100, tính trực tiếp, không lưu)
| Thành phần | Trọng số | Cách tính |
|---|---|---|
| Sức khoẻ | 35% | 60% thể lực (gym + bước đi) + 40% hạnh phúc |
| Trang phục | 30% | Theo giá bộ đang mặc: <500K≈10, 0,5–2tr≈40, 2–5tr≈65, >5tr≈85; Limited cao hơn theo độ hiếm, tối đa 100 |
| Đầu tóc | 20% | Kiểu tóc salon còn hạn 50, nhuộm +25, phụ kiện +25; hết hạn = 0 |
| Sạch sẽ | 15% | 100 khi sạch; đang mắc tiểu chưa đi: −30% |

Phạt: tiểu không kịp ×0,3 cho tới khi đi tắm, sau tắm hồi dần ~20 phút. Ị không kịp ×0,2. Chỉ số hiển thị chạy mượt về mục tiêu.

## Cột mốc
| Mốc | Danh hiệu | Fan tối đa |
|---|---|---|
| 40 | Dễ nhìn | 1 |
| 55 | Có duyên | 2 |
| 70 | Nổi bật (hào quang nhẹ) | 3 |
| 85 | Idol (trái tim bay) | 5 |
| 95 | Siêu sao | 8 |

Luật hút: NPC rảnh trong ~150px (không xếp hàng, không đi vệ sinh) có xác suất bị hút, nối đuôi như thú cưng; đi theo 2–3 phút rồi nghỉ 10 phút. Fan bỏ đi nếu sức hút tụt dưới mốc, người chơi vào nhà, hoặc dính nước tiểu.

Lợi ích đề xuất: tip 20–100K (~5 lần/ngày game), cộng hạnh phúc có trần ngày, hiệu ứng riêng cho Idol.

## Kỹ thuật
- Hằng số gom trong `CH`. Chỉ lưu bộ đếm phạt `state.ch`.
- Thanh "SỨC HÚT" trong tab Nhân vật + bảng chi tiết + gợi ý.
- Tối đa 8 fan/người, fan chạy ở máy chủ, đồng bộ hiển thị nhẹ (số lượng + kiểu nhân vật) giống thú cưng.
- Trần tip/hạnh phúc theo ngày; làm mượt để chặn đổi đồ liên tục.

## Các bước
1. Công thức + thanh hiển thị + phạt tiểu
2. Fan NPC đi theo + đồng bộ hiển thị
3. Lợi ích (tip, hạnh phúc) + hiệu ứng danh hiệu
4. Tuỳ chọn: người thật chủ động bấm "theo" ai đó

## Cần xác nhận trước khi làm
1. Fan là NPC tự xuất hiện / chỉ dùng bot có sẵn / cho người thật chọn theo?
2. "Tiểu tiện" = tiểu không kịp, hay đi WC bình thường cũng bị trừ?
3. Fan có tip tiền và hạnh phúc, hay chỉ để vui?
4. Số mốc và số fan tối đa (1/2/3/5/8) có ổn không?

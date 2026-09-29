# BotTradeV5 — Bot scalping theo phản ứng giá

Bot MT5 viết bằng **MQL5**, thiết kế cho giao dịch vàng ngắn trên M1/M5.

**Trạng thái: đã có mã và đang kiểm chứng sau review. Chưa nghiệm thu toàn bộ SPEC; chưa chứng minh lợi nhuận.**
Quyết định giữ MQL5 được chủ bot xác nhận ngày 28/09/2026.

## Đọc từ đây

- [Luật chi tiết của bot](docs/SPEC.md): nguồn luật duy nhất, gồm công thức, trạng thái, tham số đề xuất và 41 ca kiểm tra.
- [Bàn giao và việc tiếp theo](docs/HANDOFF.md): trạng thái triển khai.
- [Quy tắc làm việc](AGENTS.md): phải đọc trước khi sửa mã.
- [Công cụ](scripts/TOOLS.md): đọc trước khi chạy lệnh; không phải nguồn luật giao dịch.

## Bot cần làm gì?

Quan sát vùng phản ứng đa khung, đợi xác nhận mới rồi mới tính điểm vào, dừng lỗ, chốt lời và khối lượng.
Hướng lớn là bối cảnh, không bắt mọi khung cùng chiều.

Tám cách vào được xét độc lập:

1. Phản ứng tại vùng theo hướng.
2. Ăn nhịp phản ứng ngược hướng lớn.
3. Hồi nông rồi tiếp diễn.
4. Phản ứng tại biên đi ngang.
5. Đi theo một lần phá vùng mạnh.
6. Phá vùng, quay lại giữ được và đổi vai trò.
7. Phá thất bại rồi quay lại.
8. Phản ứng tại EMA20/50/200 trên M5/M15/H1.

Không vào chỉ vì chạm cản; không treo lệnh giới hạn thiếu xác nhận mới.
Chốt trước cản đối diện có căn cứ; có thể thoát sớm khi xuất hiện phản ứng ngược đủ mạnh.
Dừng lỗ theo mốc nhận định sai, không nới sau khi vào. Khối lượng phải phù hợp số tiền chấp nhận mất.

Quản lý theo giá, không đóng chỉ vì đủ số phút. Mốc thử: đi thuận 2,5 giá bảo vệ tại giá vào;
nếu khối lượng chia được, chốt phần tại 3 giá rồi bảo vệ phần còn lại. Tỷ lệ dự kiến phải tính cả hai phần.
Mục tiêu cần mốc cục bộ M1/M5; cản lớn ở gần vẫn chặn đường. Không kéo mục tiêu xa để cố đạt tỷ lệ.

## Ngôn ngữ và thư mục

| Phần | Công nghệ / vị trí |
|---|---|
| EA chạy trong MT5 | MQL5 `.mq5`, `mql5/Experts/BotVang/` |
| Các phần tính toán và thực thi | MQL5 `.mqh`, `mql5/Include/BotVang/` |
| File biên dịch | `.ex5` |
| Kiểm chứng và xuất dữ liệu | `mql5/Scripts/BotVang/` |
| Công cụ và phân tích ngoài luồng giao dịch | PowerShell `.ps1`, JavaScript `.mjs`, `scripts/` |
| Tài liệu | `docs/` |
| Tham số máy thử | `lab/` |

Tối ưu bằng số đo: giữ xử lý mỗi lần nhận giá ngắn, chỉ tính lại phần thay đổi.
Không chuyển sang Rust và không hứa tránh được mọi lần bỏ lỡ giá.

## Giới hạn sử dụng

- Tham số đề xuất trong SPEC cần được review và đo, chưa phải cấu hình vận hành được duyệt.
- Mặc định quan sát; không tự bật demo hoặc tiền thật.
- Công cụ, báo cáo và mã có sẵn không tự chứng minh đáp ứng SPEC mới.
- Không đưa mật khẩu, khóa hoặc thông tin tài khoản vào Git.
- Kết quả kiểm tra mã và hiệu quả giao dịch là hai điều kiện riêng.

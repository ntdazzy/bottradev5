# Quy tắc làm việc với dự án

Đọc toàn bộ `docs/SPEC.md` và `docs/HANDOFF.md` để hiểu bot mới và trạng thái thực tế.
Giữ MQL5 theo quyết định chủ bot; không coi thiết kế đã được triển khai hoặc có lời khi chưa có bằng chứng.

Trước khi sửa mã, phải đọc `AGENTS.md`. File đó là nguồn quy tắc chính của dự án về cấu trúc, log, kiểm tra, dữ liệu thị trường và triển khai.

Các quy tắc dưới đây được tích hợp từ `multica-ai/andrej-karpathy-skills` để giảm lỗi khi dùng AI viết mã. Với sửa nhỏ, rõ ràng, có thể áp dụng vừa đủ để không làm chậm công việc.

## 1. Nghĩ trước khi sửa

- Không đoán. Nêu rõ giả định; nếu chưa chắc, hỏi lại.
- Nếu có nhiều cách hiểu, nêu các cách đó thay vì tự chọn.
- Nếu có cách đơn giản hơn, nói rõ và chọn cách đó khi phù hợp.
- Nếu thông tin thiếu hoặc mâu thuẫn, dừng lại và nêu phần chưa rõ.

## 2. Chỉ làm phần cần thiết

- Chỉ viết đúng phần giải quyết yêu cầu hiện tại.
- Không thêm tính năng, cấu hình, lớp dùng chung hay phần xử lý cho tình huống chưa được yêu cầu.
- Không tạo phần dùng chung nếu chỉ có một nơi dùng.
- Nếu một cách viết ngắn hơn mà vẫn rõ và đúng, dùng cách ngắn hơn.

## 3. Sửa đúng chỗ

- Chỉ thay đổi các dòng liên quan trực tiếp đến yêu cầu.
- Không tự dọn, đổi định dạng, đổi chú thích hoặc sửa mã ở khu vực không liên quan.
- Giữ phong cách mã đang có.
- Chỉ xóa phần không còn dùng nếu chính thay đổi hiện tại tạo ra phần đó; phần cũ không liên quan thì báo lại, không tự xóa.

## 4. Làm theo kết quả có thể kiểm tra

- Trước khi làm, nêu người dùng cần kết quả gì và cách kiểm tra kết quả đó.
- Với việc nhiều bước, ghi ngắn từng bước cùng cách kiểm tra.
- Sửa lỗi phải có kiểm tra tái hiện lỗi trước hoặc kiểm tra chứng minh lỗi đã hết sau khi sửa.
- Không kết luận hoàn thành nếu chưa có kết quả kiểm tra mới, phù hợp với thay đổi.

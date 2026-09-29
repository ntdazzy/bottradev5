# Quy tắc làm việc

Đọc file này trước khi sửa mã.

Áp dụng thêm hướng dẫn ngắn ở `.agents/skills/karpathy-guidelines/SKILL.md` cho mọi thay đổi code.
`docs/SPEC.md` là nguồn luật của EA; `docs/HANDOFF.md` ghi trạng thái và việc còn lại.
SPEC chỉ mô tả bot mới; không mặc định mã đã đáp ứng. Mọi phần triển khai phải đối chiếu ca AC và có bằng chứng.
Chủ bot đã chốt giữ MQL5. Đo tốc độ trước khi tối ưu; không tự chuyển sang Rust.
Đọc hai file này trước khi sửa tín hiệu hoặc cách chấm kết quả. Các quy tắc chép từ TradingDataHub
(Python, Telegram, VPS, `SYSTEM_SPEC.md`, `ROADMAP.md`) không áp dụng cho dự án MQL5 này.
Khi tài liệu và mã khác nhau, nêu rõ chỗ lệch rồi sửa đúng nguồn; không tự khôi phục luật cũ.

## Cách nói chuyện với người dùng

Áp dụng cho mọi trợ lý AI làm việc trong repo này (opencode, Codex, ...), trong
mọi session. Mục đích: người dùng đọc hiểu ngay, không cần biết tiếng Anh
chuyên ngành.

- Luôn trả lời bằng tiếng Việt đơn giản, ngắn gọn, dễ hiểu.
- Không dùng từ tiếng Anh chuyên ngành khi có từ tiếng Việt tương đương. Ví dụ:
  dừng lỗ (không viết "stop loss"), chốt lời (không viết "take profit"), điểm
  vào (không viết "entry"), chạy lại dữ liệu cũ (không viết "replay"), đo lại
  quá khứ (không viết "backtest"), tỷ lệ lời/lỗ (không viết "RR").
- Nếu buộc phải dùng từ tiếng Anh, viết từ tiếng Việt trước rồi mới ghi từ
  tiếng Anh trong ngoặc, ví dụ: dừng lỗ (stop loss).
- Ưu tiên câu ngắn, gạch đầu dòng, số liệu cụ thể. Nói rõ: đã làm gì, kết quả
  ra sao, còn việc gì làm tiếp.
- Khi báo lỗi phải nói: lỗi gì, ở đâu, vì sao, cách sửa, bằng chứng.
- Tên file, lệnh chạy và mã code giữ nguyên tiếng Anh, nhưng phần giải thích
  xung quanh phải là tiếng Việt dễ hiểu.

## Cấu trúc

- Một file chỉ có một trách nhiệm rõ ràng.
- `mql5/Experts/BotVang/`: EA; `mql5/Include/BotVang/`: các phần tính toán, gửi lệnh và lưu trạng thái.
- `mql5/Scripts/BotVang/`: kiểm chứng/xuất dữ liệu; `scripts/`: công cụ PowerShell; `lab/`: tham số máy thử.
- `docs/`: luật, trạng thái, nghiên cứu; `docs/pine/`: chỉ báo TradingView. Không thêm thư mục cho phần chưa có.
- Không dùng mixin hoặc lớp cha chỉ để giảm vài dòng lặp. Ưu tiên hàm nhỏ và ghép thành phần rõ ràng.
- Không để logic nghiệp vụ, gọi mạng, định dạng tin nhắn và lưu dữ liệu trong cùng một file.

## Mã nguồn

- Không tạo code thừa, code đoán trước nhu cầu, hoặc hàm không có nơi gọi.
- Chỉ gom code khi đã có ít nhất hai nơi dùng cùng một hành vi.
- Không đổi tham số EA, cách lưu dữ liệu hoặc luật giao dịch nếu không có yêu cầu rõ.
- Giữ kiểu dữ liệu chặt, lỗi phải rõ và có thể kiểm tra.
- Không ghi bí mật, token, khóa API hoặc dữ liệu tài khoản vào source, log hay tài liệu.
- EA dùng `CJournal` hoặc nhật ký có tên bot/sự kiện; công cụ đo phải ghi tham số và lý do bỏ/đóng lệnh.
- Mọi lỗi vận hành đã bắt phải ghi tên sự kiện, module, loại lỗi và chi tiết đã che bí mật. Không nuốt lỗi im lặng.

## Hiệu năng

- Đo trước khi tối ưu. Không đổi sang Rust chỉ vì cảm giác chậm.
- Chỉ chuyển dần phần CPU nặng đã có số đo và test, giữ nguyên hợp đồng dữ liệu vào-ra.
- Không đổi ngôn ngữ hoặc viết lại phần gửi lệnh khi chưa có số đo và kiểm chứng tương ứng.
- Mỗi thay đổi hiệu năng phải có số trước/sau và đường quay lui rõ.

## Công cụ lặp lại

- Trước khi gõ lệnh mới, đọc `scripts/TOOLS.md` và kiểm tra tool đã có.
- Nếu đã có tool phù hợp, bắt buộc dùng tool đó thay vì tự viết lại SSH, Docker, Git, kiểm tra hay cấu hình.
- Chỉ tạo tool mới khi thao tác đã lặp lại, dễ làm sai hoặc tiết kiệm rõ thời gian/token; ghi tool mới vào `scripts/TOOLS.md`.
- Dùng script trong `scripts/` cho biên dịch, máy thử và kiểm tra. Dự án không có công cụ VPS.
- Git chỉ stage đường dẫn đã kiểm tra; không ghi lại lịch sử hoặc đẩy đè.
- Script commit chỉ được stage file được truyền rõ; không dùng `git add -A`.

## Kiểm tra và triển khai

- Trước khi sửa: đọc file liên quan, kiểm tra caller và test đang có.
- Sau khi sửa: biên dịch EA/script liên quan bằng `scripts/build.ps1`; chạy ca MQL5 và máy thử MT5 phù hợp.
- Chỉ xóa code khi đã tìm caller và test chứng minh không còn dùng.
- Không sửa file người dùng đang thay đổi nếu không liên quan trực tiếp.
- Chỉ đưa mã lên Git khi đã kiểm tra; kết quả đo lỗ vẫn phải được báo đúng, không đổi ngưỡng để làm đẹp kết quả.
- Chỉ dùng nến/vùng đã biết tại thời điểm quyết định. Tách kết quả máy thử và demo giá mới; tính phí và trượt giá rõ ràng.
- Không tự bật bot trên tài khoản demo hoặc thật. Các file `*_on.set` và `scalp_*.set` chỉ phục vụ máy thử.

## Kiểm tra theo mục tiêu người dùng

- Test xanh chỉ chứng minh mã chạy đúng các tình huống đã viết; không được coi là hoàn thành nếu chưa kiểm tra kết quả người dùng thật sự nhìn và dùng.
- Trước khi làm hoặc sửa một tính năng, ghi rõ: người dùng dùng nó để làm gì, kết quả cuối họ cần là gì, và mỗi chức năng mới giúp họ ra quyết định nào.
- Với bot tín hiệu, phải tự đặt mình vào người dùng và trader có kinh nghiệm để kiểm tra: có hiểu trạng thái trong vài giây không; có biết làm gì tiếp theo không; lý do có đúng dữ liệu không; điều kiện vào và mốc dừng có rõ không; và có cảnh báo thừa hoặc gây nhiễu không.
- Chỉ hiện "tích lũy", "khối lượng tăng/cao", "mô hình nến", "tin tức tác động" hoặc nhận định tương tự khi dữ liệu thực tế đã chứng minh đúng. Thiếu dữ liệu thì nói thiếu, không tự suy ra hoặc bịa lý do.
- Tin nhắn phải chia ý thành dòng/ngăn rõ ràng: trạng thái, giá/vùng, lý do, điều kiện còn thiếu hoặc đã đủ, mốc dừng, và việc người dùng cần làm. Không ghép các ý này thành một câu dài.
- Khi có chart hoặc hình ảnh, phải tự xem ảnh tạo ra: chữ có đọc được không, mốc trên ảnh có khớp với tin nhắn không, mũi tên có nói rõ đây là kịch bản có điều kiện không, và không có chi tiết trang trí làm che tín hiệu.
- Trước khi deploy, phải chạy cả kiểm tra mã lẫn kiểm tra theo tình huống sử dụng thật hoặc dữ liệu thật phù hợp. Báo lại bằng bằng chứng cụ thể: điều gì đã kiểm tra, kết quả, và giới hạn còn lại.

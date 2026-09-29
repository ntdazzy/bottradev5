# Quản lý theo giá và chốt một phần — 28/09/2026

Phiên bản: `SCP-MTF-1.1-price-exit`. Nguồn luật: `../SPEC.md` mục 10–11.

## Điều người dùng đã chốt

- Đánh ngắn; mục tiêu tại vùng có căn cứ, không kéo xa để gồng hoặc làm đẹp tỷ lệ lời/lỗ.
- Không đóng lệnh chỉ vì đủ số phút. Giá hồi bình thường không tự là lý do chốt sớm.
- Giá đi thuận khoảng 2–3 giá có thể kéo dừng về **giá vào**, không phải về chốt lời.
- Với 0,02 lot: chốt 0,01 rồi giữ 0,01; phần còn lại được bảo vệ tại giá vào.
- Vẫn thoát phần còn lại khi có phản ứng ngược mạnh đủ điều kiện; không gồng bất chấp cản.
- Mong muốn lời của lệnh thắng lớn hơn lỗ của lệnh thua. Đây là mục tiêu đo thực tế, không phải cam kết.

## Giá trị thử, không phải thông số tối ưu

| Mục | Giá trị |
|---|---|
| Ngưỡng lời/lỗ ròng tối thiểu | 1,5; tính cả phần chốt đầu |
| Chốt phần | Đi thuận 3,0 giá tính theo giá thoát được |
| Phần chốt | 50% khối lượng ban đầu, làm tròn xuống bước lot |
| Vị thế không chia được | Đi thuận 2,5 giá thì xét dừng về giá vào |
| Sau chốt phần | Dời dừng về giá vào khi sàn cho phép; giữ TP |
| Hạn đóng theo tuổi lệnh | Không có |
| Gửi demo/thật | Tắt; chưa được cho phép |

0,03 lot với bước 0,01 chỉ chốt 0,01, giữ 0,02; không gọi là chia đôi chính xác.
0,01 không chia. Nếu TP tới trước mốc chốt phần, không kéo xa TP để cố chia.
Không tăng lot chỉ để đủ chia. Tài khoản chưa hỗ trợ chốt phần qua ticket bị chặn khởi tạo quyền gửi.

## Những gì đã sửa

- `ScpManage`: bỏ hai điều kiện đóng theo hạn phút; giữ mất mốc vô hiệu, dừng sàn, giới hạn lỗ và nghỉ phiên.
- Hồi nhẹ không đủ thoát: cần P1 hoặc P2 tại cản kèm P3 phá cấu trúc nhỏ đã biết, hình thành sau khớp.
  P2 dùng thoát cần thân ít nhất 0,8 ATR; P1 giữ điều kiện râu mạnh. Mẫu mềm dùng nến M1 đã đóng.
  Không tuyên bố đã đo lực mua/bán thật; chưa thêm thoát theo dòng lệnh trong nến.
- `ScpPlan`: tính lời dự kiến = lời phần đầu + lời phần cuối; phí và đệm trượt tính theo từng khối lượng.
  Chỉ nhận kế hoạch khi tổng lời/rủi ro đạt ngưỡng. Phần đầu phải còn lời sau chi phí dự phòng.
- `ScpExec`: lưu ý định chốt phần trước gửi; đọc lại khối lượng; không chốt phần lần hai sau restart.
  Nếu chưa rõ kết quả thì không gửi lại. Kéo dừng và chốt phần không phải một giao dịch nguyên tử;
  sửa dừng thất bại phải báo chưa bảo vệ xong, vẫn giữ dừng sàn trước đó.
- `ScpZones/ScpScenario`: cần mốc đích M1/M5; cản khung lớn gần hơn vẫn chặn đường.
  Không bỏ cản quá sát để chọn mục tiêu xa; không lấy riêng H4/D1 xa làm đích dự phòng.
- `ScpJournal`: thêm khối lượng phần đầu/mốc chốt/mốc bảo vệ; không ghi nối khác cấu trúc sổ;
  không ghi đè tổng kết nếu khởi tạo lượt trùng tên bị từ chối.
- Dừng về giá vào không bao gồm bảo đảm phí/trượt bằng 0. Dừng đã tốt hơn giá vào không bị nới lại.

## Kiểm tra đã chạy

### Biên dịch và ca logic

- `scripts/build.ps1`: BotScpMtf, ScpVerify, ScpExecVerify, ScpPriceManageVerify đều 0 lỗi, 0 cảnh báo.
- `ScpVerify`: **97/97 đạt**, lần 17:46:58 ngày 28/09.
  PX01–PX19 kiểm hai chiều, chưa đủ giá, dừng đã tốt hơn, giới hạn sàn, 0,01/0,02/0,03 lot,
  phản ứng yếu/mạnh, vùng chưa được biết, mục tiêu gần và lời dự kiến có chia lệnh.
- Ví dụ V08: khi chưa chia, lời/rủi ro 1,298; chia 0,10 thành 0,05+0,05 tại 3 giá thì lời dự kiến
  còn 25,25 trên rủi ro 23,50, tức khoảng 1,074. Kế hoạch phải bị loại ở ngưỡng 1,2 hoặc 1,5.
  Không được ghi tỷ lệ của riêng phần cuối thành tỷ lệ cả vị thế.

### Kiểm thực thi qua MT5

- `ScpExecVerify`: **20/20 đạt**, lần 17:47:23. Có kiểm chốt 0,02 xuống 0,01,
  khởi tạo lại không chốt lặp, dừng về giá vào giữ TP, hạn giờ lưu cũ không ép đóng.
  Ca này gọi trực tiếp hàm chốt để kiểm thực thi; không phải bằng chứng đạt khoảng đi thuận.
- `ScpPriceManageVerify`: **9/9 đạt**, lần 17:48:06, XAUUSDm ngày 02/09 với tick thật:

| Sự kiện | Giá / khối lượng |
|---|---|
| 00:00:00 bán vị thế kiểm | 0,02 tại 4324,688 |
| 00:01:22 đạt điều kiện đi thuận ≥3 giá | Chốt 0,01 tại Ask 4321,648 |
| Cùng lần quản lý | Dừng 0,01 còn lại tại 4324,688; TP giữ 4314,688 |
| 00:01:57 giá quay lại | Khớp dừng phần cuối tại 4324,695, trượt 0,007 giá |
| Tổng tiền theo deal của ca | **+3,03 USD** |

Đây là **vị thế được dựng để kiểm cơ chế quản lý**, không phải điểm vào do bộ chọn cơ hội tìm được.
Không sử dụng +3,03 để kết luận chiến lược đã có lợi nhuận. Giá khớp dừng thực tế khác giá đặt ngay trong ca này.

## Lượt toàn bot — không che kết quả không giao dịch

`scp_price_exit_20260928_02`, XAUUSDm M1, từ 02/09 tới trước 03/09, hoàn tất 17:50:38:

- 328.486 tick, 1.378 nến, chạy hết dữ liệu; vốn cuối 10.000 USD vì **0 lệnh**.
- 1.208 đề nghị bị loại: 678 tỷ lệ lời/lỗ thấp; 395 dừng/chốt không đúng phía;
  70 dừng quá sát; 65 giá ngoài giới hạn. Có một sự kiện xung đột riêng.
- Chưa có mẫu thắng/thua nên **không tính được lời trung bình/lỗ trung bình**, không thể kết luận cơ chế mới cải thiện hiệu quả.
- Giữ giả định hoa hồng khứ hồi 0 cho nghiên cứu, đệm trượt 0,5 giá/chặng trong kế hoạch;
  thiếu lịch tin được ghi rõ. Không được mang giả định này sang demo/thật.
- Thời gian máy thử 127,451 giây; 4.096 tick cuối p50=389/p95=694/p99=4.096 micro giây.
  Đây là thời gian xử lý cục bộ, không phải độ trễ sàn.

Không so 0 lệnh với bộ 4 lệnh trước rồi tuyên bố lợi nhuận tốt hơn. Đã đổi cách chọn mục tiêu,
ngưỡng ròng và quản lý cùng lúc theo yêu cầu mới; chưa có phép đối chứng riêng từng thành phần.

## Còn lại trước khi vận hành

- Điều tra vì sao vùng/mục tiêu gần làm phần lớn đề nghị không đủ khoảng lời; không nới ngưỡng hoặc bỏ cản thiếu căn cứ.
- Đo dài hơn trên nhiều phiên và dữ liệu chưa dùng chỉnh luật. Báo lời/lỗ theo toàn vị thế, không đếm từng phần chốt như lệnh thắng riêng.
- Thử thêm việc sàn chỉ khớp một phần yêu cầu, mất kết nối giữa chốt/dời dừng, mất điện thật, trượt lớn.
  Chưa coi các ca kiểm hiện tại phủ hết các rủi ro này.
- Chốt một phần có thể giảm lợi nhuận nếu giá chạy thẳng tới TP. Không hứa vừa tăng tỷ lệ thắng vừa tăng lời trung bình.

## Tệp và nơi kiểm chứng

- Nguồn chính: `ScpManage.mqh`, `ScpExec.mqh`, `ScpPlan.mqh`, `ScpZones.mqh`, `ScpTypes.mqh`,
  `ScpState.mqh`, `ScpScenario.mqh`, `ScpJournal.mqh`, `BotScpMtf.mq5`.
- Ca kiểm: `ScpVerify.mq5`, `ScpExecVerify.mq5`, `ScpPriceManageVerify.mq5`.
- Hồ sơ mới chỉ máy thử: `lab/scp_price_exit.set`. Cách chạy tại `scripts/TOOLS.md`.
- Nhật ký máy thử: `%APPDATA%/MetaQuotes/Tester/D0E8209F77C8CF37AD8BF550E51FF075/Agent-127.0.0.1-3000/logs/20260928.log`.
- Sổ EA: `%APPDATA%/MetaQuotes/Terminal/Common/Files/BotScp/scp_price_exit_20260928_02/`.
- Hàm chốt phần MT5: [tài liệu chính thức](https://www.mql5.com/en/docs/standardlibrary/tradeclasses/ctrade/ctradepositionclosepartial).
  Phải dùng đúng ticket, kiểm mã trả về và đọc lại khối lượng; true của hàm không tự chứng minh đã khớp.

Không commit/push, không bật demo/thật. Không xóa kết quả các lượt trước.

SHA-256 bản nguồn đã kiểm: `BotScpMtf.mq5` = `017FB1CA35CAED60CD7C9B722BF4A253C412373A6D7DADA2A49C9CAB7875760D`;
`ScpManage.mqh` = `A4A6E31F537B64898B6448C11D2E915809475CF5A0D7DA670543047E9738E67C`;
`ScpExec.mqh` = `6067A8C99AC6F9EA3CA7A5944D2EE977E65B1639983A5E61E4CAB82BC61F4B4C`.

# Sửa lỗi sau review — SCP, 28/09/2026

## Kết luận hiện tại

Đã sửa các lỗi trọng yếu về phản ứng/phá vùng, mốc dừng, độ mới tín hiệu, vòng đời lệnh,
khóa rủi ro và cập nhật chỉ báo khi chạy lâu. Chưa nghiệm thu toàn bộ SPEC và chưa đạt mục tiêu hiệu quả giao dịch.
Không bật demo/thật, không commit/push. Giữ MQL5.

## Bằng chứng trước và sau

| Kiểm tra | Trước sửa | Sau sửa đã quan sát |
|---|---|---|
| REG01: bật khỏi hỗ trợ không phải phá hỗ trợ | FAIL | PASS |
| REG02: mốc dừng gồm râu phản ứng | FAIL | PASS |
| REG03: hai chạm chưa phải hai phản ứng | FAIL | PASS |
| REG04: đỉnh/đáy tiếp tục cập nhật sau đầy bộ nhớ | FAIL | PASS, 5.000 nến |
| REG15: EMA nối tiếp khi vòng nến quay | FAIL, lệch tối đa 0,000005090157 trong dữ liệu dựng | PASS, sai số in 0,000000000000 |
| Bộ ca công thức/trạng thái ScpVerify | 61 ca ban đầu đạt nhưng bỏ sót lỗi tích hợp | 78/78 đạt lúc 17:06:11 |
| ScpExecVerify: gửi/đóng/nhận lại/khóa | Chưa có ca tích hợp | 13/13 đạt lúc 17:01:42 trong máy thử |

Các ca công thức là kiểm bằng dữ liệu dựng, không phải bằng chứng có lời. Các ca thực thi gửi lệnh
trong Strategy Tester của MT5, không gửi ra tài khoản demo/thật.
Ca khôi phục tạo lại đối tượng rồi đọc trạng thái terminal; không giả gọi đó là thử mất điện vật lý.

## Những sửa đổi chính

- Phía tiếp cận quyết định bật hay phá. Đã làm rõ ngữ cảnh này trong SPEC mục 6.2.
- Đáy/đỉnh được cập nhật theo diễn biến đã nhận, không giữ nguyên giá lần chạm đầu.
- Khung nguồn của vùng khác khung phát tín hiệu; điểm vào chỉ M1/M5, EMA nguồn M5/M15/H1.
- Hình học và ATR của lần chạm được khóa; không gộp sửa biên vùng đang theo dõi.
- Dấu dùng-một-lần theo xác nhận; giữ sự kiện phá để các nhánh độc lập còn được xét.
- S06 xét nến xác nhận sau chạm; S07 xét được râu xuyên và lấy lại, không bắt có đóng phá trước.
- Hạn gửi lấy từ xác nhận; giới hạn đuổi giá lấy từ Bid xác nhận; giá mới được đọc và kế hoạch tính lại.
- Khối lượng làm tròn xuống, phí khứ hồi cộng một lần; thiếu ký quỹ/chi phí thì bỏ.
- Sau đóng/từ chối chắc chắn được gửi kế hoạch mới; SENT_UNKNOWN không tự hết hạn.
- Order được gắn với kế hoạch lưu bền; kiểm mã trả về và đọc lại vị thế khi sửa dừng/chốt.
- Tính rủi ro theo giá khớp thật; thiếu bảo vệ/vượt ngân sách yêu cầu đóng an toàn.
- Giữ khóa lỗ qua cập nhật/khởi tạo lại; tính phí mở/đóng và swap. Chặn lệnh ngoài bot.
- Quản lý dùng ATR M1 lúc vào; cấu trúc siết dừng phải hình thành sau khớp; giữ TP khi sửa SL.
- Giữ bảo vệ khi tắt tìm lệnh; tiền thật bị chặn, demo cần quyền riêng.
- Thêm nhật ký deal và danh tính kế hoạch; từ chối ghi đè lượt máy thử có cùng tên.

## Đo tốc độ

Máy kiểm: Intel Core i7-13700H, MT5 build 6230. Đây không phải số đo VPS hoặc độ trễ sàn thật.

- Ca 4.000 nến M5/EMA: trước 36.695 micro giây; sau 176 micro giây trong lần chạy 17:01.
  Mã sau tính nối tiếp theo công thức, không quét lại toàn lịch sử; REG15/16 kiểm giá trị độc lập.
  Đây là phép đo nhỏ trên máy này, không suy thành tốc độ toàn EA tăng cùng tỷ lệ.
- Lượt quan sát hoàn tất ngày 01/09, tên `scp_review_observe_20260928_v4`:
  344.084 tick, 1.378 nến, thời gian máy thử 79,175 giây.
  4.096 mẫu cuối: p50=179, p95=249, p99=1.452 micro giây. Không đại diện toàn bộ phân bố trong ngày.
- Có đo riêng lời gọi gửi/lưu ý định và thời gian nhận sự kiện khớp tại máy cục bộ.
  Thời gian này trong máy thử không chứng minh độ trễ thực trên sàn.

## Kết quả giao dịch — không che phần lỗ

Lượt `scp_review_send_20260928_v5`, từ 02/09 tới trước 04/09, XAUUSDm M1, tick thật:

- 624.031 tick; 2.756 nến; 4 kế hoạch, 4 lần gửi, 4 lần đóng.
- Vốn 10.000 USD; cuối 9.971,17 USD: **−28,83 USD**.
- Giả định hoa hồng khứ hồi 0. Kế hoạch có đệm trượt 0,5 giá mỗi chặng;
  đệm chỉ nằm trong xét kế hoạch, không được tự coi đã trừ vào số dư MT5.
- Lịch tin thiếu, chỉ tiếp tục vì đây là nghiên cứu trong máy thử; demo/thật phải bị chặn.
- Đợt đo ngắn, dùng để kiểm luồng thực thi; không phải dữ liệu chưa từng xem hoặc bằng chứng lợi thế.

Lượt quan sát ngày 01/09 có 369 đề nghị, không có kế hoạch đạt: 123 không có mục tiêu đúng phía,
224 tỷ lệ lời/lỗ thấp, 16 giá ngoài giới hạn, 6 dừng quá gần. Có 37 sự kiện xung đột riêng.
Không hạ ngưỡng để tăng số lệnh. Cần điều tra vị trí vùng/mục tiêu và dữ liệu loại lệnh trước khi đề xuất đổi luật.

Các lượt có tên `final` hoặc lượt dừng giữa chừng không có tổng kết hoàn tất thì không dùng làm kết quả cuối.

Lượt `scp_review_send_20260928_verified`, ngày 02/09 tới trước 03/09, sau sửa chọn đề nghị và nhật ký:

- 328.486 tick; 1.378 nến; 138 đề nghị; 4 kế hoạch và 4 lệnh đã mở/đóng.
- Tiền từng lệnh: −10,61; −9,38; +2,76; −15,14 USD. Tổng **−32,37 USD**, khớp số dư cuối 9.967,63 USD.
- Hai lệnh đóng vì không tiến triển; một vì hết thời hạn; một vì mất mốc vô hiệu.
- 4.096 mẫu cuối: p50=710, p95=1.144, p99=4.968 micro giây; lượt đo hoàn tất 179,051 giây.
- Các lệnh đều có danh tính kế hoạch trong DEAL_IN/DEAL_OUT/DONG; đây là bằng chứng vận hành,
  không phải kết quả cải thiện lợi nhuận. Không so hai lượt khác phạm vi/mã như một phép đo trước/sau chiến lược.

## Phạm vi chưa nghiệm thu

### Điều tra ba lệnh thua ngày 02/09

Nguồn: `BotScp/scp_review_send_20260928_closeout/{ke_hoach,thuc_thi,quyet_dinh}.csv` và OHLC M1
XAUUSDm đã xuất trong `BotScalpPhanUng/scalp_v3_audit_XAUUSDm_M1/nen_M1.csv`.
Chỉ dùng giá OHLC của file nến để đối chiếu; không lấy nhãn hướng/luật của EA xuất dữ liệu làm luật cho SCP.
Giờ trong bảng là giờ sàn. OHLC không chứng minh thứ tự mọi tick bên trong nến.

| Kế hoạch | Diễn biến có bằng chứng | Kết luận giới hạn |
|---|---|---|
| 1, bán 00:07 | M1 00:06 giảm từ 4325,870 xuống 4319,472; vào 4319,536; hai nến sau hồi lên. Đóng 00:09 ở Ask 4323,072, −10,61 USD, vì không tiến triển | Bán ở cuối một nến giảm dài, sau đó bị hồi ngay. Không phải bị SL 4326,443. Mốc phá là 4325,237, đã cách điểm vào 5,701 giá |
| 2, bán 00:55 | M5 00:50–00:54 giảm từ 4323,575 xuống 4314,810; vào 4314,543. Ba phút sau hồi, đóng Ask 4319,234, −9,38 USD | Không bị SL 4324,458; quy tắc không tiến triển 3 phút đóng trong nhịp hồi. Nến 01:02 sau đó xuống 4306,673, nhưng ngoài trần giữ 5 phút ban đầu; không tự coi chờ lâu sẽ cứu chiến lược |
| 4, bán EMA 01:26 | Vào 4320,091; 20 giây sau đóng Ask 4323,874 khi Bid vượt mốc 4323,491, −15,14 USD. M1 đó đạt cao 4324,591, vượt cả SL đặt 4324,175; các nến sau giảm | Phản ứng giảm được chọn chưa đứng vững trước nhịp tăng ngắn. Đúng là giá giảm sau khi đã bị loại, nhưng chỉ bỏ đóng sớm và giữ SL hiện tại vẫn không cứu được lệnh |

Cơ chế đáng điều tra tiếp:

- S05 đo vào đuổi bằng chênh lệch so với **giá đóng nến xác nhận**, chưa có tiêu chí riêng cho quãng chạy
  từ mép phá tới cuối nến. Vì vậy một cú giảm dài vẫn được mua/bán ngay cuối cú đẩy nếu tick vừa nhận gần giá đóng.
- Kế hoạch 1/2 lấy chốt ở vùng H4 quanh 4234: cách điểm vào lần lượt 85,077 và 79,774 giá,
  trong khi trần giữ 3/5 phút. Tỷ lệ dự kiến 10,634 và 7,217 không chứng minh mục tiêu thực tế phù hợp scalping.
- Cả ba được gắn COUNTER_LARGE trong kế hoạch. Không có cơ sở từ ba lệnh để cấm mọi lệnh ngược hướng lớn
  hoặc đảo toàn bộ sang mua. Lệnh bán thứ ba theo S06 vẫn lời 2,76 USD.
- Chưa chạy đối chứng tick cùng tiền chịu lỗ cho vào sau, nới dừng hoặc đổi cách thoát; chưa khẳng định cách nào cải thiện tổng kết quả.

Lượt `closeout` hoàn tất lúc 17:10:19: 328.486 tick, 4 lệnh, số dư 9.967,63 USD;
4.096 mẫu cuối p50=708/p95=1.260/p99=4.708 micro giây, 212,226 giây máy thử.
Không có lệnh gửi lỗi trong `thuc_thi.csv`; tổng DEAL_OUT = −32,37 USD, khớp số dư.

- Chưa phủ toàn bộ AC01–AC41 trên mọi hướng/khung. Cụ thể tại `../AC-MAP.md`.
- Chưa thử thực tế mất điện giữa gửi, mạng sàn chập chờn, khớp từng phần, hai terminal cùng tài khoản.
- Còn cần hoàn thiện/rà quy tắc vùng ngày/tuần trước, phân nhóm ép cản,
  lịch tin có chứng cứ phạm vi phủ, lựa chọn giữa nhiều cụm đi ngang và đối chứng từng nhánh.
- Chưa có bằng chứng nhiều lệnh/ngày hoặc lợi nhuận bền. Chưa được cho phép triển khai.

## Nguồn bằng chứng trên máy

- Ca công thức: `%APPDATA%/MetaQuotes/Terminal/D0E8209F77C8CF37AD8BF550E51FF075/MQL5/Logs/20260928.log`.
- Máy thử: `%APPDATA%/MetaQuotes/Tester/D0E8209F77C8CF37AD8BF550E51FF075/Agent-127.0.0.1-3000/logs/20260928.log`.
- Nhật ký EA: `%APPDATA%/MetaQuotes/Terminal/Common/Files/BotScp/<tên lượt>/`.
- Không chép log đăng nhập hoặc thông tin tài khoản vào repo. Giữ dữ liệu đo gốc trên máy.

## File thuộc lượt sửa

Các `Scp*.mqh`, `BotScpMtf.mq5`, `ScpVerify.mq5`; thêm `ScpExecVerify.mq5`,
`lab/scp_review_observe.set`, `lab/scp_review_send.set` và báo cáo này.
Đồng bộ SPEC/HANDOFF/AC-MAP/README/TOOLS. `mt5-main.ps1` thêm chạy cửa sổ ẩn.
Ba mã băm kiểm lại của BotScalpPhanUng/ScalpSignal/ScalpReport giữ nguyên; không xóa mã hoặc dữ liệu khác.

## Dấu mã tại lượt chốt kiểm

SHA-256 nguồn lúc 17:06, không chứa thông tin tài khoản:

| File | SHA-256 |
|---|---|
| BotScpMtf.mq5 | 7CB676BF65D1BD6274A7C4276B5CC7EE1369F8D4DEB3F73D074BA3270EADD7D7 |
| ScpScenario.mqh | F0B7F5CA53515E4EFC4C00F5FDA13B6812F1D00E8F8FBC7F4379E1097E3138EE |
| ScpExec.mqh | FAB2292ED7894EA71684E17998663B65A1630B2BB94EE475C043F59AD409604E |
| ScpSeries.mqh | 3467EAB5495A1642629E2D347AD819EDA0D70415631E13715D5FEB81F0538CC9 |
| ScpVerify.mq5 | 65F266B13C2FA239137C37291BA392FD8475A2DE3B476B0256284D7414E70B40 |

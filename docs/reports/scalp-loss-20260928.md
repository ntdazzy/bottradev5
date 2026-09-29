# Điều tra vì sao bản M1 còn lỗ — 28/09/2026

## Kết luận có bằng chứng

Điểm cần kiểm tra đầu tiên là **lệnh chờ dùng phản ứng cũ**, tiếp theo là **dừng quá sát so với dao động M1**
và **bảo vệ/thoát làm mất một số nhịp lời**. Chưa có căn cứ để đảo mọi lệnh, nới mọi dừng hoặc bật thêm EMA.
Không có nguyên nhân duy nhất được chứng minh giải thích hết lỗ; các nhóm dưới đây có thể chồng nhau, không cộng thành phần trăm nguyên nhân.

Nguồn: `scalp_v3_audit_XAUUSDm_M1`, XAUUSDm 0,01 lot, 05/01–25/09/2026, 225 ngày có tick theo giờ VN.
Lượt audit chỉ sửa dữ liệu xuất: `lenh.csv` và `quyet_dinh.csv` **giống từng byte** với lượt bản 3 trước đó.
Lịch sử đã được xem, không phải dữ liệu mới hoặc kết quả demo trực tiếp.

## Tiền mất ở đâu?

146 lệnh: 28 thắng, 115 thua, 3 hòa. Tổng lãi **145,27 USD**, tổng lỗ **193,62 USD**, còn **−48,35 USD**.
Lệnh thắng trung bình 5,188 USD, lệnh thua trung bình 1,684 USD; không phải hiện tại lệnh thắng nhỏ hơn lệnh thua.
Trong 143 lệnh có lãi/lỗ, chỉ 19,6% thắng; với mức lãi/lỗ trung bình này cần khoảng 24,5% để hòa vốn.
Hoa hồng/phí/qua đêm máy thử ghi bằng 0, chênh lệch mua–bán đã có trong giá. Trừ thêm đệm trượt thì còn −111,35 USD.
Vì đã âm trước khoản trượt giả định, không thể đổ hết lỗ cho khoản dự phòng này.

| Cách đóng thực tế | Số lệnh | Tổng tiền USD |
|---|---:|---:|
| Dừng ban đầu, chưa dời | 75 | −186,18 |
| Đạt mục tiêu | 25 | +133,97 |
| Dừng sau khi đã bảo vệ giá vào | 42 | −3,18 |
| Đóng chủ động/thời gian | 4 | +7,04 |

## 1. Có phải vào quá sớm?

- Tín hiệu khi nến chưa đóng: 11 lệnh, −5,01 USD.
- Tín hiệu sau nến đóng: 135 lệnh, −43,34 USD.
- Vì nhóm sau nến đóng vẫn lỗ, không thể coi bỏ vào trong nến là giải pháp đủ.
- Trong 75 lệnh chạm dừng ban đầu: 25 lệnh đóng trong 10 giây, 58 trong một phút; thời gian trung bình khoảng 44 giây.
- 62/75 lệnh chưa từng đi thuận được nửa khoảng dừng trước khi đóng. Đây là mô tả giá, không tự phân biệt được sai chiều với nhiễu ngắn.

## 2. Điểm vào chờ có bị cũ?

141/146 lệnh khớp từ lệnh chờ giới hạn; chỉ 5 lệnh vào thị trường. So thời gian từ gửi kế hoạch tới lúc khớp:

| Thời gian chờ khớp | Số lệnh | Tổng tiền USD |
|---|---:|---:|
| Dưới 60 giây | 99 | −1,24 |
| 60–119 giây | 30 | −22,88 |
| Từ 120 giây | 17 | −24,23 |

47 lệnh khớp sau ít nhất một phút đều là lệnh chờ, tổng mất **47,11 USD**.
Mã lập kế hoạch từ nến phản ứng, nhưng khi chờ khớp chủ yếu kiểm vùng còn sống, H1, mốc dừng/chốt và hạn giờ;
không xác nhận lại rằng phản ứng giá ban đầu vẫn còn lúc lệnh được sàn khớp. Đây là lý do có thể kiểm bằng đối chứng hạn chờ,
không phải bằng cách nhìn kết quả rồi xóa những dòng thua.

Liên hệ trên chưa chứng minh nguyên nhân: lệnh phải chờ lâu có thể thuộc hoàn cảnh giá khác. Cần chạy lại EA vì hủy sớm
cũng làm bot rảnh để nhận cơ hội khác và có thể bỏ mất lệnh tốt.

## 3. Dừng có quá ngắn, bị chạm rồi giá đi đúng hướng?

- 132/146 lệnh có khoảng dừng nhỏ hơn một lần dao động trung bình M1; 72/75 lần dừng ban đầu thuộc nhóm này.
- **33/75** lệnh bị dừng ban đầu sau đó vẫn tới mục tiêu gốc, trong cửa sổ 10 phút từ lúc vào.
  Chỉ số này chưa nói nới bao nhiêu sẽ cứu được lệnh; giá có thể đi ngược rất xa trước khi tới mục tiêu.
- Đối chứng nới dừng 1,5 lần: **20 trường hợp tốt hơn, 81 xấu hơn, 45 không đổi** so với giữ dừng/chốt ban đầu.
  Tổng giảm lỗ nhưng vẫn âm. Không đủ căn cứ nới đồng loạt; cùng khối lượng thì tiền chịu lỗ ban đầu tăng 50%.

| Khoảng dừng so với dao động M1 | Số lệnh | Tổng tiền thực USD |
|---|---:|---:|
| Dưới 0,5 lần | 66 | −14,97 |
| Từ 0,5 tới dưới 1 lần | 66 | −31,96 |
| Từ 1 lần | 14 | −1,42 |

Nhóm cuối chỉ có 14 mẫu, không được suy ra cứ dùng dừng dài là tốt. Điểm vào tốt hơn có thể vừa giữ dừng ngoài vùng
vừa giảm khoảng lỗ; chỉ kéo dừng xa là tăng rủi ro.

## 4. Có phải mua thay vì bán?

Thực tế: 74 lệnh mua −52,16 USD; 72 lệnh bán +3,81 USD. Nhóm bán dương rất ít trước khoản trượt dự phòng.
Đảo **toàn bộ** chiều tại đúng các thời điểm đã khớp, dùng đúng Bid/Ask và đối xứng khoảng dừng/đích, vẫn âm **−71,03 USD**.

Trong đối chứng không quản lý: nhóm mua gốc −65,65, đảo thành bán −18,82; nhóm bán gốc +29,40, đảo thành mua −52,21.
Vậy có khác biệt theo chiều trong mẫu, nhưng không có quy tắc đơn giản “cứ làm ngược là thắng”. Không tự đổi bot sang chỉ bán
sau khi xem kết quả của đúng giai đoạn này.

## 5. Có phải kéo dừng hoặc chốt sớm?

Ghép 145 lệnh có cùng giờ vào, chiều và giá khớp giữa hai lượt EA thật:

- Có quản lý: −53,55 USD; giữ dừng/chốt gốc: −41,45 USD.
- Có 29 lệnh tốt hơn và 16 lệnh kém hơn, nhưng tổng **kém 12,10 USD**.
- Bản chủ động có thêm một lệnh, nên không lấy chênh tổng hai lượt thay cho ghép từng lệnh.

Kéo dừng cứu được một số lệnh nhưng làm mất các nhịp lời khác. Dừng đã bảo vệ chỉ mất tổng 3,18 USD không có nghĩa
quản lý đó không gây chi phí cơ hội. Cần kiểm cách siết theo nhịp giá, không chỉ đếm số lệnh được đưa về gần hòa vốn.

## Đối chứng riêng từng trường hợp trên tick

| Cách thử | Số trường hợp vào | Tổng tiền mô phỏng USD |
|---|---:|---:|
| Dừng/chốt gốc, không quản lý | 146 | −36,25 |
| Dừng rộng 1,5 lần, cùng khối lượng, cùng mục tiêu | 146 | −6,04 |
| Đảo chiều, đối xứng khoảng dừng/đích | 146 | −71,03 |
| Chờ thêm 60 giây, kiểm lại điều kiện | 18 | −4,27 |

Chờ 60 giây loại 128 trường hợp; không được gọi việc ít lỗ hơn với rất ít lệnh là cải thiện lợi thế.
Chuẩn hóa trường hợp dừng rộng về cùng tiền chịu lỗ cho −4,027 USD; đây là phép chia lý thuyết, không phải khối lượng
đã xác nhận gửi được lên sàn.

**Kiểm chứng và giới hạn:**

- 146/146 cửa sổ có đủ tick theo kiểm tra; không có dòng thiếu/không hợp lệ.
- Đối chứng dừng/chốt gốc khớp tiền **145/145 lệnh chung** với lượt EA không quản lý, tổng lệch 0.
- Giá thoát mua là Bid, thoát bán là Ask; TP/SL lấy giá tick kích hoạt, thời hạn theo cùng giây POSITION_TIME của EA.
- Chưa có trễ gửi, hoa hồng mới hoặc trượt thêm; chưa tính lịch bận/rảnh và tiền chịu lỗ của nhiều trường hợp giả định chồng nhau.
  Không coi tổng đối chứng là lợi nhuận một EA chạy đầy đủ.
- Nhiều tick cùng một mili giây quanh lúc khớp vẫn có giới hạn thứ tự nội bộ. Việc khớp 145 trường hợp gốc là kiểm hiệu chuẩn,
  không bảo đảm kết quả đối chứng sẽ lặp lại khi giao dịch thật.
- Lượt đối chứng đầu chưa hợp lệ: MT5 có thể trả phép tính tiền bằng 0 trước khi kết nối xong. Đã tái hiện và thêm kiểm tra
  tiền/sẵn sàng; chỉ dùng `diagnose_ticks_final.csv`. Các file thử trước giữ cục bộ, không dùng làm bằng chứng.

## Thay đổi đáng thử trước, chưa chọn làm mặc định

Ưu tiên kiểm tra thời hạn/độ mới của lệnh chờ. Chỉ thử đổi hạn chờ, giữ nguyên hướng, dừng, mục tiêu, khối lượng và giới hạn rủi ro.
Mức một phút là một giả thuyết cần đo bằng EA, không phải mức tối ưu đã biết. Chưa nới dừng hay đổi chiều mặc định.
EMA là nhóm nghiên cứu riêng; chưa bật thêm điều kiện chỉ để tăng số lệnh.

### Kết quả thử hủy chờ sau một phút

Lượt `scalp_v3_fresh_cancel` đã chạy lại đủ 225 ngày, không có lỗi gửi hay lỗi tự kiểm tra:
98 lệnh, thắng 22,45%, −1,22 USD; trừ thêm đệm trượt còn −42,72 USD. Bản ba phút có 146 lệnh,
thắng 19,18%, −48,35 USD, sau đệm −111,35 USD. Sụt vốn lớn nhất giảm từ 54,75 xuống 25,39 USD.
Đây là giảm lỗ trong dữ liệu đã xem, không phải phương pháp đã có lời. Số lệnh giảm từ 0,65 xuống 0,44/ngày.
Lượt gửi hạn sàn một phút trực tiếp bị 473 lỗi 10022, đã loại; lượt hợp lệ dùng EA hủy sớm và hạn sàn dự phòng ba phút.
Mặc định vẫn ba phút; thử nghiệm hạn ngắn chỉ cho máy thử.

### Thiếu sót cần sửa ở cách xác nhận điểm vào

Chủ bot chỉ ra đúng tình huống: giá từng bị cản rồi quay lại, nhưng lần quay lại phá luôn cản thay vì bị đẩy ngược.
EA đã có phản ứng lúc đặt kế hoạch, nhưng lệnh BuyLimit/SellLimit trên sàn không yêu cầu phản ứng mới tại lúc khớp.
`Manage` chỉ kiểm hạn, vùng/hướng H1, mốc dừng/chốt và quyền chạy; chưa xác nhận lại phản ứng ở lần quay lại.
Rút hạn chờ chỉ giảm thời gian dùng tín hiệu cũ, không sửa thiếu sót này. Hướng cần thảo luận/kiểm chứng tiếp là theo dõi vùng
mà chưa đặt lệnh trên sàn, rồi chỉ gửi lệnh khi lần chạm mới có phản ứng và giá vẫn phù hợp. Chưa triển khai hướng này.

## Dữ liệu và công cụ

- `Common/Files/BotScalpPhanUng/scalp_v3_audit_XAUUSDm_M1/`: `lenh.csv`, `deals.csv`, `quyet_dinh.csv`,
  `diagnose_summary.json`, `diagnose_inputs.csv`, `diagnose_ticks_final.csv`.
- `scripts/diagnose-scalp.mjs` ghép kế hoạch/khớp/dời dừng và lập đầu vào; thiếu hoặc không duy nhất thì dừng.
- `mql5/Scripts/BotVang/ScalpDiagnose.mq5` chỉ đọc lịch sử và tính đối chứng, không có lệnh giao dịch.
- Cách chạy và giả định đầy đủ: `scripts/TOOLS.md`, SPEC §26.4–26.5.

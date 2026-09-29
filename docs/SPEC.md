# SPEC mới — Bot scalping theo kịch bản và phản ứng giá

Phiên bản tài liệu: `SCP-MTF-1.3-review-fixes` · Ngày: 28/09/2026. Hướng mới HTF-ZONE 2.0 ở mục 23 (29/09, chưa có mã).

Bản 1.3 (chủ bot duyệt 28/09 sau review): S01 nhận nhịp hồi thuận hướng lớn; kế hoạch bị loại không khóa cả lần chạm;
thoát do mốc vô hiệu cần nến M1 đóng qua mốc; bảo vệ giá vào ở max(2,5 giá, 1R); siết theo cấu trúc sau 1R;
vùng M1 chưa có phản ứng không làm cản mục tiêu; chỉ OB M1 và vùng M5 trở lên mở lần theo dõi vào lệnh.
Các giá trị số vẫn là [THỬ NGHIỆM], có công tắc để đo trước/sau.

**Hướng 1.4 (chủ bot chốt 29/09, chưa vào bot):** cản tìm ở khung lớn M15–W1, M1/M5 chỉ để tìm điểm vào,
vào thị trường sau phản ứng, né tin, khối lượng theo độ lớn cản trong trần 0,25%, chốt hai phần.
Trước khi đổi bot phải đo bằng công cụ đo tín hiệu. Chi tiết mục 22.

**Trạng thái: BẢN THIẾT KẾ ĐỂ CHỦ BOT REVIEW. Chưa phải mô tả mã đã hoàn thành.**

Đã chốt định hướng quản lý: không đóng theo số phút; mục tiêu có căn cứ; bảo vệ tại giá vào sau nhịp thuận;
chốt một phần nếu chia được khối lượng. Các mốc 2,5/3 giá và tối thiểu 1,5R vẫn là cấu hình thử cần đo,
không phải kết quả tối ưu hay quyền chạy demo/thật.

Đây là đặc tả của bot cần xây dựng, đủ độc lập để bàn giao cho một agent lập trình không có lịch sử hội thoại.
Tài liệu chỉ mô tả bot này; trạng thái công việc nằm riêng trong [HANDOFF.md](HANDOFF.md), quy tắc làm việc trong [AGENTS.md](../AGENTS.md).

## 0. Cách đọc và mức độ đã chốt

- **[YÊU CẦU]**: ý định chủ bot đã nêu; triển khai không được âm thầm làm ngược.
- **[ĐỀ XUẤT]**: cách định nghĩa để lập trình được; cần review, không được tự gắn nhãn “chủ bot đã chốt”.
- **[THỬ NGHIỆM]**: giá trị số ban đầu để chạy kiểm tra có thể lặp lại; chưa chứng minh tốt, chưa cấp quyền chạy tiền thật.
- **Phạm vi đặc tả** không đồng nghĩa trạng thái hoàn thành. Tra cứu tiến độ ở HANDOFF, không suy ra từ lời văn của SPEC.

Các quy tắc kỹ thuật định lượng ở mục 4–13 là đề xuất của bản thiết kế này. Chỉ mục 1 và các dòng ghi [YÊU CẦU]
là khẳng định về yêu cầu người dùng. Không dùng một lần đo đẹp để tự nâng mức xác nhận.

Agent/session mới phải đọc toàn bộ SPEC trước khi triển khai. Mục 14 cung cấp hợp đồng lập trình chính xác;
mục 17 là điều kiện nghiệm thu. Không cần lịch sử chat để hiểu mục tiêu.

## 1. Con bot cần tạo là gì?

### 1.1 Mục tiêu [YÊU CẦU]

Tạo EA trên MT5, ban đầu giao dịch vàng Exness `XAUUSDm`, đánh ngắn bằng M1 và M5.
Bot tìm các nhịp phản ứng có lý do rõ ràng, vào gần mốc nhận định sai và thoát nhanh khi tới cản hoặc kịch bản không còn đúng.
Muốn có nhiều cơ hội hợp lý trong ngày; không đặt chỉ tiêu bắt buộc phải đủ số lệnh.

Bot phải hiểu được các tình huống sau bằng quy tắc đo được:

1. Hướng ngày giảm, giá giảm tới hỗ trợ và bật: có thể **mua nhịp hồi ngắn**, không cần tuyên bố ngày đã đảo tăng.
2. Hướng ngày giảm, giá hồi tới kháng cự và bị đẩy xuống: có thể **bán theo nhịp giảm** tới vùng phía dưới.
3. Giá phá cản/cấu trúc: hủy kịch bản đánh bật cũ; có thể đi theo cú phá nếu giá chưa quá xa và còn khoảng chạy.
4. Phá rồi quay lại: nếu giữ được phía mới, đổi vai trò kháng cự/hỗ trợ cho kịch bản tương ứng và xét chiều mới.
5. Phá rồi quay vào vùng cũ: đánh giá phá thất bại; không đổi chiều máy móc chỉ vì một râu vượt cản.
6. Giá đi ngang, hồi nông, chạm EMA hoặc bị ép sát cản: chọn cách xử lý phù hợp, không áp cùng một luật cho mọi hoàn cảnh.
7. Giá đi chưa hết mục tiêu nhưng có phản ứng ngược rõ: được thoát sớm. Không biến lệnh scalping thành giữ dài để chờ hòa vốn.

Hướng ngày tăng thì đảo tương xứng các ví dụ mua/bán. Bot phải biết **đang đánh kịch bản nào**, không chỉ xuất một điểm mua/bán.

### 1.2 Những điều không được làm [YÊU CẦU]

- Không bắt D1, H4, H1, M15, M5 và M1 cùng chiều mới cho vào.
- Không cấm mọi lệnh ngược D1/H1: một nhịp hồi có thể giao dịch được nếu đúng kịch bản và còn đủ khoảng lời.
- Không buộc rút râu, nhấn chìm, RSI, khối lượng và cả ba EMA phải cùng xuất hiện.
- Không đặt BuyLimit/SellLimit mù ở vùng rồi dùng phản ứng cũ để biện minh khi giá quay lại phá thẳng vùng.
- Không coi một vùng mãi mãi chỉ mua hoặc chỉ bán; cũng không tự lật mọi vùng ngay khi giá xuyên qua.
- Không nới dừng của lệnh đang lỗ để “cho giá thêm chỗ”. Không gấp thếp, nhồi lỗ hoặc mở lệnh trả thù.
- Không hứa chắc thắng, không hứa tránh được mọi lần chạm dừng rồi giá quay lại.
- Không giả định nhiều quy tắc hoặc nhiều lệnh hơn tự tạo ra lợi thế.

### 1.3 Phạm vi bản đầu [ĐỀ XUẤT]

- Một EA quản lý cả dữ liệu M1/M5 và các khung lớn; không cần chạy hai bản độc lập tranh nhau gửi lệnh.
- Mỗi tài khoản/ký hiệu chỉ một vị thế đang mở hoặc một yêu cầu mở chưa xác định kết quả. Được theo dõi nhiều cơ hội chưa gửi.
- Mặc định chỉ quan sát, tắt gửi lệnh. Thử trong máy thử trước, demo sau khi được cho phép; tiền thật cần quyết định riêng.
- BTC, ETH, OKX và các sản phẩm khác chưa nằm trong phạm vi thực thi. Không trộn giá của chúng để chấm lệnh XAUUSDm.
- Có chốt một phần đúng một lần nếu khối lượng chia được; không tự tăng khối lượng sau chuỗi thắng.

## 2. Đầu ra để người dùng và agent hiểu được bot

Với mỗi cơ hội, phải trả lời được:

1. Giá đang ở vùng nào? Vùng thuộc khung nào và đang có vai trò gì?
2. Hướng lớn và nhịp đang giao dịch có giống nhau không?
3. Đây là nhánh bật lại, hồi theo hướng, phá tiếp, kiểm tra lại, phá giả, đi ngang hay EMA?
4. Phản ứng mới nào đã có? Điều kiện nào còn thiếu?
5. Giá vào còn chấp nhận được không? Dừng ở đâu, vì sao nhận định sai tại đó?
6. Mục tiêu gần nhất là gì? Có bao nhiêu khoảng lời sau chi phí?
7. Khi nào hủy theo dõi, thoát sớm, hoặc xét vai trò mới?

Không có đủ dữ kiện thì hiển thị “chưa rõ/đang chờ”, không tự viết “lực mua mạnh”, “cá mập gom”, “tin tác động”.

## 3. Vai trò các khung và cách xác định hướng

| Khung | Vai trò | Không được diễn giải thành |
|---|---|---|
| D1 | Hướng nền của ngày theo cấu trúc đã xác nhận | Lệnh cấm giao dịch mọi nhịp ngược |
| H4 | Vị trí trong nhịp lớn, vùng lớn đang gần | M1 phá một mức thì H4 tự đảo |
| H1, M15 | Nhịp trong ngày, vùng gần và trạng thái hồi/phá | Hai điều kiện bắt buộc đồng thuận cho mọi nhánh |
| M5 | Vùng và kịch bản scalping M5; bối cảnh gần cho M1 | Bắt mọi tín hiệu M1 chờ nến M5 đóng |
| M1 | Điểm vào nhanh, kịch bản M1, theo dõi phản ứng/thoát | Bằng chứng mọi khung lớn đã đảo hướng |

### 3.1 Cấu trúc và hướng [ĐỀ XUẤT]

- Đỉnh/đáy cấu trúc chỉ được dùng sau đủ nến xác nhận ở bên phải; xem mục 4. Không gắn nó ngược về quá khứ như đã biết sẵn.
- Có hai đỉnh liên tiếp cao hơn và hai đáy liên tiếp cao hơn: `UP`. Hai đỉnh thấp hơn và hai đáy thấp hơn: `DOWN`.
- Khi đã có hướng, ghi đáy/đỉnh bảo vệ nhịp đó. Nến của **chính khung đó** đóng phá mốc bảo vệ qua đệm xác nhận:
  chuyển `TRANSITION`, không lập tức tuyên bố hướng đối diện đã bền.
- Chỉ chuyển sang hướng đối diện khi cấu trúc đỉnh/đáy đã xác nhận đáp ứng định nghĩa đối diện.
- Không đủ cấu trúc: `UNDEFINED`. Trạng thái này không cấm nhánh đi ngang hoặc phản ứng vùng nếu dữ liệu thực vẫn đầy đủ.
- Đi ngang của M1/M5 là trạng thái nhịp cục bộ riêng; D1 vẫn có thể đang giảm/tăng.

Mỗi kịch bản ghi `entry_tf`, `local_direction`, `d1_direction`, `h4_direction`, `h1_direction`,
và quan hệ `WITH_LARGE / COUNTER_LARGE / MIXED / UNDEFINED`. Không thu tất cả thành một biến “bias” duy nhất.

### 3.2 Hai ví dụ bắt buộc

- D1 giảm, H1 giảm, giá tới hỗ trợ H1, M1 bật lên: được xét `COUNTER_BOUNCE`; không được loại chỉ vì H1 giảm.
- D1 giảm, M5 phá kháng cự rồi giữ được: được xét nhịp mua M5; vẫn ghi D1 giảm, không sửa D1 thành tăng.

## 4. Dữ liệu và định nghĩa cơ bản

### 4.1 Hợp đồng dữ liệu

- Dùng nến và Bid/Ask của đúng ký hiệu/máy chủ giao dịch. Lưu giờ nguồn, thời điểm nhận và `time_msc` nếu có.
- `known_at` là lúc bot thực sự có thông tin. Nhận bù năm nến lúc 10:05 không được ghi cả năm là đã biết đúng giờ đóng trước đó.
- Nến đã đóng khi thời gian kết thúc đã qua và dữ liệu broker xác nhận. Đồng bộ khung lớn tới thời điểm quyết định,
  nhưng không dùng vùng mới tạo lúc đóng để giải thích phản ứng của nến trước lúc vùng đó tồn tại.
- Tách nến đang chạy khỏi nến đã đóng. Mẫu trong nến chỉ được tính từ các giá đã nhận tới lúc đó, không dùng râu/cuối nến tương lai.
- Nếu mô hình phát hiện có độ trễ, lưu cả `origin_time` và `known_at`; chỉ `known_at` quyết định lúc được sử dụng.
- RSI/EMA/dao động chưa đủ lịch sử: tắt riêng nhánh cần dữ liệu đó, không thay giá trị thiếu bằng 0 hoặc vô hiệu hóa tất cả các nhánh.
- Dữ liệu giá lỗi, không đúng tài khoản/ký hiệu, mất đồng bộ nghiêm trọng: không mở mới; ưu tiên quản lý các vị thế thuộc bot.
- Tick volume của vàng được gọi là **mức hoạt động cập nhật giá**, không gọi là khối lượng mua/bán toàn thị trường.

### 4.2 Các đại lượng [ĐỀ XUẤT]

- `tick_size`: bước giá của sản phẩm. Giá gửi sàn phải làm tròn theo bước này, không chỉ theo số chữ số.
- `spread = Ask - Bid` tại đúng lúc quyết định; spread lưu trong nến không thay thế spread khớp thật.
- `ATR(TF,14)`: dao động trung bình, tính Wilder từ nến đã đóng. Nến đang chạy dùng ATR của nến đóng cuối cùng.
- Đỉnh/đáy xác nhận `N/N`: lớn/nhỏ hơn các nến bên phải, không kém cực trị bên trái; xử lý bằng nhau nhất quán.
  Chỉ biết sau N nến bên phải đóng. N ban đầu ở mục 13.
- Cản là khoảng `[bottom, top]`, không phải mức chắc chắn giữ giá. Với mức dạng điểm, vẫn có vùng dung sai/đệm riêng.
- `eps_geom = max(2*tick_size, k_buffer*ATR_ref)` dùng nhận dạng hình học trên Bid.
  `stop_buffer = target_buffer = max(eps_geom, spread_now)` dùng tại lúc lập kế hoạch. Xem cách cố định ATR_ref ở mục 14.
  Không dùng spread tại lúc gửi để sửa lại sự kiện hình học đã xảy ra trước đó.
- Chi phí dự kiến gồm chênh lệch đã nằm trong đúng phía giá, hoa hồng nếu có, đệm trượt và phí giữ nếu có nguy cơ phát sinh.
  Không cộng chênh lệch hai lần. Thiếu phí cần thiết phải ghi thiếu, không báo lợi nhuận ròng như đã biết đủ.

## 5. Bản đồ vùng giá

### 5.1 Những loại vùng cần hỗ trợ [ĐỀ XUẤT]

| Loại | Định nghĩa lập trình ban đầu | Lúc được biết |
|---|---|---|
| Hỗ trợ/kháng cự đỉnh đáy | Đỉnh/đáy đã xác nhận; vùng râu phía cực trị của nến tạo đỉnh/đáy | Lúc nến xác nhận cuối cùng đóng |
| FVG | Ba nến đã đóng: vùng tăng khi đáy nến 3 cao hơn đỉnh nến 1, giảm đối xứng; khoảng trống phải đạt ngưỡng mục 13 | Nến 3 đóng |
| OB | Nến ngược chiều cuối trong chân đẩy trước nến đóng phá đỉnh/đáy cấu trúc đã biết; lấy cả cao/thấp; giới hạn tìm kiếm mục 13 | Nến phá đóng, không phải lúc nến OB gốc mở |
| MSNR/mức đổi màu nến | Giá đóng của nến đầu trong cặp nến đổi màu; chỉ là mức tham khảo yếu khi chưa có cấu trúc hoặc phản ứng độc lập hỗ trợ | Nến thứ hai đóng |
| Đỉnh/đáy ngày, tuần trước | Cực trị kỳ đã hoàn thành, theo lịch phiên broker được ghi rõ | Kỳ trước kết thúc và dữ liệu sẵn sàng |
| EMA | EMA20/50/200 trên M5, M15, H1, tính từ giá đóng; gieo bằng trung bình N nến đầu rồi hệ số 2/(N+1) | Sau khi đủ nến của đúng khung |

FVG không tự chứng minh thiếu thanh khoản; OB không tự chứng minh tổ chức đã đặt lệnh. Đây là vùng hình học từ dữ liệu giá.
Không yêu cầu một vùng phải đồng thời là FVG, OB và EMA.

### 5.2 Vùng đa khung và vùng chồng nhau

- Giữ thông tin từng khung. Có thể gom các vùng gần nhau để hiển thị một cụm, nhưng không xóa vùng M1 chỉ vì gần vùng H1.
- Phân biệt `STRUCTURE_CONFIRMED`, `REACTION_ONLY`, `REFERENCE_ONLY`. Mức MSNR hai nến đơn lẻ không tự thành cản cứng chặn mọi lệnh.
- Mức tham khảo có thể được nâng thành vùng phản ứng sau hai lần phản ứng độc lập, hoặc khi trùng cấu trúc đã xác nhận.
  Hai phản ứng phải thuộc hai lần rời/quay lại khác nhau, không đếm từng tick là một lần.
- Giá nằm trong một vùng H4 rộng không có nghĩa toàn bộ vùng đó là bức tường cấm scalping.
  Phải xét vai trò cục bộ, mép còn ở phía trước và mục tiêu M1/M5 bên trong; ghi rõ đang đánh trong vùng đối nghịch lớn.
- Không bỏ qua một cản có căn cứ gần hơn chỉ để lấy mục tiêu xa cho tỷ lệ lời/lỗ đẹp.
- Vùng hết tuổi/hỏng phải ngừng tạo lệnh mới. Không dùng tuổi kỹ thuật của vùng làm lý do duy nhất nới dừng hoặc cứu vị thế đang lỗ.

### 5.3 Dữ liệu tối thiểu của một vùng

`zone_id, version, type, source_tf, bottom, top, source_role, origin_time, known_at,
source_state, independent_touches, last_touch, expires_at, evidence_ids`.

`source_role` là hỗ trợ/kháng cự/trung lập theo khung nguồn. Mỗi kịch bản có thêm vai trò cục bộ của vùng trên khung giao dịch.
Giữ hình học và phiên bản đã dùng trong kế hoạch, không sửa lịch sử lệnh theo phiên bản vùng mới.

## 6. Trạng thái vùng, lần chạm và đổi vai trò

### 6.1 Không nhầm vùng nguồn với diễn biến cục bộ

Ví dụ vùng kháng cự H1 bị M1 đóng xuyên lên: đó là sự kiện phá **trên M1**.
Kịch bản M1 có thể chuyển sang kiểm tra lại/mua theo nhịp mới, nhưng trạng thái cấu trúc H1 chỉ đổi theo nến H1 của nó.
Lưu `break_tf` và `trade_role`; không ghi đè `source_role` của H1 bằng một nến M1.
Theo dõi vai trò bằng cặp `(zone_id, timeframe)`. Vai trò khung nguồn chỉ đổi khi chính khung đó đủ điều kiện đổi vai trò.
Vùng bị phá không bị xóa khỏi mọi nhánh: còn có thể xét S05/S06/S07 trong cửa sổ tương ứng.
Chỉ loại vai trò giữ vùng đã thất bại; không dùng cờ còn hiệu lực chung để chặn nhánh kiểm tra lại vùng vừa phá.

### 6.2 Vòng đời của một lần tiếp cận vùng [ĐỀ XUẤT]

| Trạng thái | Diễn biến | Hành động |
|---|---|---|
| `WATCHING` | Giá chưa tới vùng | Theo dõi, chưa gửi lệnh |
| `TOUCHED` | Khoảng giá M1/M5 hoặc tick đã chạm vùng | Mở một `episode_id`, ghi đường giá đã thấy |
| `WAIT_REACTION` | Chưa đủ phản ứng mới | Chờ; không gửi limit để đoán trước |
| `REACTION_READY` | Một mẫu phản ứng của nhánh đã đủ | Tính lại giá/dừng/chốt/chi phí trước gửi |
| `BREAK_CANDIDATE` | Giá xuyên qua mép nhưng chưa đủ xác nhận | Ngừng dùng kịch bản bật cũ để mở lệnh; theo dõi hai khả năng |
| `BREAK_CONFIRMED_LOCAL` | Đủ quy tắc phá trên M1 hoặc M5 | Hủy kịch bản cũ; xét nhánh phá tiếp hoặc chờ kiểm tra lại |
| `RETEST_WAIT` | Đã phá, chưa quay lại | Theo dõi, không đặt lệnh mù tại mức cũ |
| `RETEST_HELD` | Quay lại, giữ phía mới và có phản ứng mới | Đổi vai trò giao dịch cục bộ; tạo cơ hội theo chiều mới |
| `FAILED_BREAK` | Quay vào phía cũ và có xác nhận thất bại | Hủy kịch bản đi theo phá; chỉ xét chiều ngược khi có phản ứng mới |
| `EXPIRED/CANCELLED` | Quá hạn, dữ liệu lỗi, mất căn cứ | Không tái sử dụng tín hiệu; lưu lý do |

Chỉ râu xuyên qua rồi rút lại chưa đủ để gọi `BREAK_CONFIRMED_LOCAL`; có thể là nhánh phá giả.
Với nến đóng, xác nhận phá cần đóng vượt **mép xa theo chiều phá** thêm đệm; dùng khung giao dịch của sự kiện.
Phải xét phía tiếp cận: hỗ trợ được tiếp cận từ trên rồi bật lại lên trên không phải phá lên;
kháng cự tiếp cận từ dưới rồi bật lại xuống dưới không phải phá xuống. Sự kiện phá vượt sang phía đối diện
của vùng đang được tiếp cận. Đây là điều kiện ngữ cảnh bắt buộc của các công thức B0 ở mục 14.4.
Hình học bị phá được giữ để quan sát kiểm tra lại, không xóa mất dấu vùng chỉ vì kịch bản cũ bị hủy.

### 6.3 Lần chạm mới và chống đánh lặp

- Nhiều tick trong một lần chạm chỉ là một episode. M1 và M5 nhận cùng sự kiện không được tạo hai lệnh.
- Nhánh bật/EMA được mở lần chạm mới khi có ít nhất một nến khung giao dịch hoàn toàn rời vùng/đường đã đóng băng,
  rồi giá quay lại. Sau khi đã có lệnh, việc rời và quay lại phải mới hơn thời điểm đóng lệnh trước.
- Nhánh phá/đổi vai trò có sự kiện và phiên bản vai trò riêng; không cần giả vờ đó là lần chạm bật cũ.
- Một sự kiện xác nhận chỉ được gửi một yêu cầu mở. Lệnh thua không tự tạo ra sự kiện mới để vào lại.
- **[1.3]** Phản ứng không thành kế hoạch (mục tiêu gần, tỷ lệ thấp, dừng sát...) chỉ khóa đúng nến đó;
  lần chạm vẫn chờ phản ứng mới trong hạn. Phản ứng đã thành kế hoạch thì khóa cả lần chạm như cũ.
- Tín hiệu quá hạn không được sống lại sau restart hoặc khi có thêm một chỉ báo đồng thuận.

## 7. Các kiểu xác nhận giá — dùng thay thế, không bắt đủ tất cả

Mỗi kiểu cần đúng **vị trí và chiều của kịch bản**. Mẫu nến ở giữa đường, không có căn cứ vùng/nhịp, không tự thành điểm vào.

### P1 — Rút râu tại lần chạm hiện tại

- Mua: chạm vùng đỡ, có râu dưới, giá quay lên phía giữ vùng; bán đối xứng.
- Đề xuất nhận dạng nến đóng: râu phía từ chối ≥ 2 lần thân và ≥ 0,5 ATR của khung giao dịch; đóng ở một phần ba phía bật lại.
- Với mẫu này **không bắt buộc** phải đồng thời nhấn chìm, vượt đỉnh nến trước, RSI đồng thuận và hoạt động giá cao.
- Bản vào trong nến là biến thể riêng: dùng hình dạng tại thời điểm nhận, thêm thời gian quan sát và giá giữ phía bật lại.
  Lưu `provisional=true`; không dùng hình dạng cuối nến để sửa lại lý do đã vào trước đó.

### P2 — Nhấn chìm theo hướng phản ứng

- Một trong hai nến chạm vùng; nến thứ hai đóng theo chiều định vào, thân bao phủ thân nến trước và lớn hơn thân trước.
- Nến thứ hai phải giữ được phía hợp lệ của vùng. Không bắt có thêm râu dài hoặc phá cả cực trị râu nến trước.
- Đây là mẫu hai nến đã đóng; không gọi là nhấn chìm hoàn tất khi nến thứ hai còn đang chạy.

### P3 — Nhịp hồi nhỏ bị chặn

- Ghi đỉnh/đáy nhỏ đã biết của nhịp đi vào vùng; không tìm lại mốc đẹp hơn sau khi giá đã chạy.
- Mua khi giá dừng tạo đáy mới và nến khung giao dịch đóng vượt đỉnh nhỏ đó thêm đệm; bán đối xứng.
- Cực trị nhịp đi vào vùng là mốc xem xét vô hiệu. Không thay bằng một đỉnh/đáy chưa xác nhận trong tương lai.

### P4 — Phá cản có chuyển động rõ

- Nến M1/M5 đóng vượt mép vùng hoặc mốc cấu trúc đã biết thêm đệm.
- Thân theo chiều phá ≥ ngưỡng ATR thử nghiệm và đóng gần đầu phía phá; không chỉ là râu xuyên.
- Sau đóng, giá hiện tại vẫn ở phía phá; giá đã quay vào phía cũ thì tín hiệu không còn hợp lệ.
- Đây là **xác nhận theo quy tắc**, không phải lời khẳng định cú phá sẽ không thất bại.

### P5 — Kiểm tra lại giữ được phía mới

- Phải có sự kiện phá đã biết **trước** lần kiểm tra lại; không dùng cùng nến để tự suy cả thứ tự phá rồi hồi.
- Giá tiếp cận mép vùng từ phía mới. Vùng giữ được khi xuất hiện P1, P2 hoặc P3 theo chiều mới và chưa có sự kiện vô hiệu.
- Không chỉ thấy giá chạm lại là gọi giữ được. Nếu xuyên lại phía cũ qua mốc vô hiệu thì hủy kịch bản này.

RSI và hoạt động giá được ghi để giải thích/nghiên cứu; không là cổng bắt buộc toàn hệ thống.
“Lực ngược mạnh” trong bản đầu là chuyển động giá P2/P3/P4 ngược lệnh tại mốc liên quan, không phải lời đoán về dòng tiền tổ chức.

## 8. Các nhánh vào lệnh độc lập

Mỗi nhánh phát ra một đề nghị giao dịch có lý do, không tự gửi lệnh. Được xét trên M1 **hoặc** M5;
không bắt hai khung cùng phát tín hiệu. Những nhánh cùng đủ phải qua quy tắc chống trùng/xung đột ở mục 9.

### S01 — Phản ứng tại vùng, thuận nhịp đang giao dịch

- **Hoàn cảnh:** nhịp cục bộ có hướng; giá hồi tới hỗ trợ/kháng cự đã biết của một khung liên quan.
  **[1.3]** Hoặc hướng lớn (D1, nếu chưa rõ thì H4) rõ và cùng chiều lệnh, trong khi nhịp M1/M5 đang hồi ngược về vùng:
  ví dụ D1 giảm, M1 hồi lên kháng cự rồi bị từ chối → S01 bán. Không bắt M1 phải quay đầu trước.
- **Mua:** nhịp cục bộ tăng, giá hồi về vùng đỡ, P1 hoặc P2 hoặc P3 tăng mới. Bán đối xứng.
- **Dừng:** ngoài cực trị phản ứng/mốc bảo vệ thực sự của nhịp hồi, cộng đệm; không mặc định lấy toàn bộ vùng D1 làm khoảng dừng.
- **Mục tiêu:** cản có căn cứ gần nhất ở phía đi thuận, ưu tiên khoảng scalping M1/M5.
- **Hủy:** giá xuyên mốc vô hiệu, kịch bản phá cùng vùng đã thay thế, phản ứng hết hạn hoặc giá vào không còn đáng nhận.
- **Ghi rõ:** thuận nhịp H1/M15/M5 nào; có thể vẫn ngược D1. Không tự gọi mọi lệnh là thuận hướng lớn.

### S02 — Ăn nhịp bật ngược hướng lớn

- **Hoàn cảnh:** hướng lớn còn tăng/giảm nhưng giá tới một vùng có căn cứ; không bắt hướng lớn đảo trước.
- **Ví dụ mua:** D1/H1 giảm, giá chạm hỗ trợ H1/M15/M5, có P1/P2/P3 tăng mới trên M1 hoặc M5.
- **Mục đích:** lấy đoạn bật, không giữ chờ đảo xu hướng ngày. Ghi `COUNTER_LARGE` nếu ngược hướng lớn đã biết.
- **Dừng:** ngoài đáy/đỉnh phản ứng hiện tại làm nhịp bật thất bại. Nếu dừng ở vùng lớn quá xa, chỉ dùng cấu trúc con
  khi chính nhịp con là lý do vào; phải ghi điều này, không gọi dừng con là vùng lớn đã hỏng.
- **Mục tiêu/thoát:** trước cản gần đối diện của nhịp ngắn. Phản ứng ngược đủ mạnh mới thì thoát theo mục 11; không đóng theo tuổi lệnh.
- **Hủy:** chưa có phản ứng mới, vùng đang bị phá tiếp theo chiều lớn, không có cấu trúc con đủ rõ hoặc không đủ khoảng sau chi phí.

### S03 — Hồi nông trong nhịp mạnh

- **Hoàn cảnh:** cấu trúc cục bộ đang đi thuận; có một nến đẩy đủ rõ và tạo vùng nhỏ/mốc giữ mới.
- **Không bắt:** giá phải hồi về một vùng xa đã vẽ trước đó. Cũng không vào chỉ vì có một nến dài.
- **Điểm vào:** nhịp hồi nông chạm vùng nhỏ đã biết/EMA hợp lệ, rồi P1/P2/P3 cho thấy nhịp hồi bị chặn.
- **Dừng:** ngoài đáy/đỉnh của chính nhịp hồi nông. **Mục tiêu:** vùng phản ứng tiếp theo ở phía đi thuận.
- **Hủy:** nhịp hồi phá mốc bảo vệ, xuất hiện phá ngược hoặc giá đã chạy quá xa trước khi bot gửi.
- Điều kiện “nông”: mức hồi không vượt phần trăm của đoạn đẩy đã xác định trước; mức thử ban đầu ở mục 13.

### S04 — Đánh phản ứng ở biên đi ngang

- **Hoàn cảnh:** trên M1/M5 có hai vùng biên với ít nhất hai lần phản ứng độc lập ở mỗi phía; chưa có đóng phá biên được xác nhận.
- Hai biên và lần chạm phải được xác định bằng dữ liệu đã có. Cửa sổ tìm vùng và độ rộng gom các mức nằm ở mục 13.
- **Mua:** tới biên dưới có P1/P2/P3 tăng mới. **Bán:** tới biên trên có phản ứng giảm mới.
- Không vào giữa vùng đi ngang chỉ vì RSI ở một giá trị nào đó.
- **Mục tiêu:** cản có căn cứ gần nhất bên trong phạm vi; nếu không có cản giữa thì trước biên đối diện.
- **Hủy:** phạm vi quá hẹp sau chi phí hoặc có phá biên. Khi phá, chuyển sang S05/S06/S07, không tiếp tục cố đánh bật.

### S05 — Đi theo cú phá, không chờ hồi bắt buộc

- **Hoàn cảnh:** P4 phá cản/cấu trúc của nhịp M1 hoặc M5 vừa được xác nhận; chưa thất bại.
- **Điểm vào:** giá hiện tại còn ở phía mới, chưa quá xa giá xác nhận và đủ khoảng tới vùng tiếp theo; gửi theo thị trường.
- Không yêu cầu phải có thêm P1, P2 hoặc kiểm tra lại. Nếu chọn chờ kiểm tra lại thì đó là S06, không phải thiếu điều kiện của S05.
- **Dừng:** phía mất hiệu lực của cú phá/đáy-đỉnh nhịp đẩy đã biết, cộng đệm; không đặt tùy tiện sát giá vì mục tiêu hấp dẫn.
- **Hủy:** quay vào phía cũ, khoảng dừng/rủi ro vượt giới hạn, hoặc mục tiêu quá gần. Giá đã chạy xa thì chuyển theo dõi S06 hoặc bỏ.
- Không có vùng/mốc mục tiêu có căn cứ phía trước, kể cả khi lập đỉnh mới: không bịa giá chốt; bản đầu chỉ theo dõi.
- Nhánh vào trong nến phá là biến thể rủi ro riêng, mặc định chưa bật; bản đầu S05 dùng P4 nến đóng.

### S06 — Phá rồi kiểm tra lại, đổi vai trò vùng

- **Mua:** có sự kiện phá lên trước đó; giá quay từ trên xuống vùng cũ, P5 xác nhận giữ được phía trên.
  Ghi kháng cự cũ thành hỗ trợ cho khung giao dịch của kịch bản.
- **Bán:** phá xuống, hồi từ dưới lên và P5 giảm xác nhận; hỗ trợ cũ thành kháng cự cho khung đó.
- **Dừng:** ngoài cực trị lần kiểm tra lại và mốc làm việc giữ phía mới thất bại.
- **Mục tiêu:** vùng phản ứng tiếp theo, không kéo theo toàn bộ D1 chỉ vì vừa đổi vai trò trên M1.
- **Hủy:** lần kiểm tra lại không giữ được, quá thời hạn chờ hoặc thiếu đường giá để xác định đúng thứ tự phá → quay lại → phản ứng.
- Giá chạm vùng rồi tiếp tục xuyên, không có P5: **không vào**.

### S07 — Xuyên cản rồi quay lại, phá thất bại

- **Ví dụ bán:** giá vượt kháng cự đã biết rồi quay xuống phía cũ; có P1/P2/P3 giảm xác nhận mới.
- **Ví dụ mua:** giá xuyên hỗ trợ rồi lấy lại phía trên với phản ứng tăng mới.
- Đề xuất nhận dạng: mức xuyên tối thiểu và thời gian lấy lại ở mục 13; có thể ghi là “quét đỉnh/đáy” theo giá,
  nhưng không khẳng định ai cố ý quét dừng hoặc toàn bộ thanh khoản đã bị lấy.
- **Dừng:** ngoài cực trị cú xuyên, có đệm. **Mục tiêu:** cản trong vùng giá vừa quay trở lại.
- **Hủy:** giá lại giữ được phía phá, vượt mốc vô hiệu, hoặc đã chạy xa sau khi lấy lại vùng.
- Không tự bán ngay khi thấy râu trên dài ở bất kỳ vị trí nào; không mở ngược ngay sau khi lệnh phá bị dừng mà thiếu sự kiện mới.

### S08 — Phản ứng tại EMA đa khung

- Theo dõi riêng EMA20, EMA50, EMA200 của M5, M15, H1: **9 lựa chọn thay thế**, không phải 9 cổng bắt buộc.
- Đường dùng là giá trị từ nến khung nguồn đã đóng trước lúc tiếp cận. Đóng băng giá trị/phiên bản cho một episode;
  không đổi đường trong quá khứ để làm một lần chạm thành đẹp hơn.
- Giá tới đường từ một phía, chạm vùng dung sai quanh đường và có P1/P2/P3 giữ/bật về phía đó thì xét mua/bán tương ứng.
- Bản thân chạm hoặc cắt EMA không phải xác nhận vào. EMA phẳng/cắt nhau có thể thuộc nhịp đi ngang, không tự gọi là xu hướng mạnh.
- Phân loại thuận/ ngược nhịp lớn để đánh giá mục tiêu và rủi ro. Hướng giảm không cấm mua nhịp bật EMA nếu đúng S02/S08.
- **Dừng:** ngoài cực trị phản ứng thực tế, không chỉ dưới/trên đường EMA một số điểm tùy ý.
- EMA là vùng tham khảo động, không thay thế việc tìm cản chốt lời và tính chi phí.
- Chín nhóm phải có số đo riêng. Nhóm chưa đủ lịch sử hoặc bằng chứng thì để trạng thái nghiên cứu, không tự bật cả chín.

### 8.1 Những hoàn cảnh chỉ thay đổi cách quan sát, không tự tạo lệnh

- **Bị ép sát cản:** tối thiểu các nhịp hồi đang ngắn lại theo định nghĩa đo được; theo dõi khả năng phá và phản ứng bật.
  Không tự kết luận cứ chạm nhiều thì cản chắc chắn yếu đi. Vào qua S01/S05/S06/S07, không mở lệnh từ chữ “ép”.
- **Vùng chồng nhau/xung đột nhiều khung:** giữ cả thông tin; nếu có thể xác định một nhịp ngắn với mốc sai/đích rõ thì xét nhánh phù hợp.
  Nếu không phân biệt được hai kịch bản trái chiều đang cùng hợp lệ thì chờ, không chọn ngẫu nhiên.
- **Tin mạnh/giá nhảy/spread tăng:** áp dụng chính sách an toàn ở mục 12. Không tự coi biến động lớn là cơ hội chắc thắng.

## 9. Luồng quyết định và gửi lệnh

### 9.1 Luồng chung [YÊU CẦU]

```text
Dữ liệu đúng thời điểm
    → cập nhật hướng từng khung và bản đồ vùng
    → mở/cập nhật các kịch bản có liên quan
    → chờ phản ứng mới của MỘT nhánh
    → kiểm lại giá, mốc sai, mục tiêu, chi phí, tiền chịu lỗ
    → gửi một yêu cầu mở
    → xác nhận khớp thật
    → quản lý theo kịch bản đã vào
    → đóng/hủy, lưu kết quả, chờ sự kiện mới
```

Các nhánh S01–S08 là OR. Các điều kiện an toàn chung là AND. Không chuyển mọi bằng chứng hỗ trợ thành cổng an toàn bắt buộc.

### 9.2 Chọn và chống trùng [ĐỀ XUẤT]

1. Xử lý dữ liệu lỗi, rủi ro và sự kiện làm kịch bản cũ mất hiệu lực trước khi xét mở mới.
2. Gom các đề nghị cùng vùng/cụm, cùng episode và cùng chiều thành một cơ hội; lưu đủ nhánh đã phát hiện.
3. Chọn nhãn theo sự kiện cụ thể: kiểm tra lại sau phá/ phá thất bại trước nhãn phản ứng chung; EMA/hồi nông trước nhãn vùng chung.
   Đây là cách giải thích và chống trùng, không khẳng định nhánh cụ thể có xác suất thắng cao hơn.
4. Hai hướng đối nghịch cùng một sự kiện chưa được phân định: `WAIT_CONFLICT`, ghi điều còn thiếu.
5. Các cơ hội khác nhau cùng đủ: ưu tiên thời điểm xác nhận mới nhất; nếu cùng lúc thì khoảng tới cản sau chi phí tốt hơn;
   nếu vẫn bằng thì thứ tự mã ổn định. Ghi quy tắc này trong báo cáo, không chọn lại sau khi biết kết quả.
6. Giữ một vị thế/yêu cầu mở mỗi ký hiệu. Khi đang có lệnh chỉ quản lý lệnh đó; không nhồi và không đánh ngược để khóa lỗ.

### 9.3 Quy tắc điểm vào mới

- WATCH/WAIT_REACTION **không phải** BuyLimit/SellLimit trên sàn.
- Bản đầu của thiết kế mới gửi lệnh thị trường **sau xác nhận mới**, nếu giá hiện tại còn trong khoảng chấp nhận.
- Tính lại chi phí, dừng/chốt và tiền chịu lỗ tại giá gửi; không dùng nguyên giá chụp lúc bắt đầu quan sát.
- Giới hạn giá vào được suy từ khoảng tới mốc dừng, mục tiêu và tỷ lệ sau chi phí; thêm giới hạn chạy xa khỏi giá xác nhận.
- Giá đã chạy xa: bỏ lần gửi đó. Chỉ chuyển WATCH_RETEST nếu nhánh cho phép; phải có một episode/phản ứng mới rồi mới vào.
- **Không có đường dự phòng tự chuyển thành limit chỉ vì vào thị trường không đạt.**
- Limit/stop trên sàn sau xác nhận nằm ngoài phạm vi thực thi bản đầu. Không được tự thêm như một lối tắt.

### 9.4 Kế hoạch phải có trước khi gửi

`plan_id, spec_version, parameter_hash, symbol, episode_id, scenario_id, source_zone_ids,
entry_tf, management_tf, direction, context_snapshot, reaction_id, reaction_known_at,
provisional, latest_quote_time_msc, entry_price_limit, invalidation_level, sl,
target_zone_id, tp, expected_cost_money, expected_risk_money, expected_reward_money,
volume, send_deadline, partial_volume, partial_trigger, breakeven_trigger, cancel_reason`.

Lý do phải chỉ tới dữ kiện: ví dụ “M1 rút râu dưới tại hỗ trợ M15 đã biết từ 09:45”, không chỉ ghi “đủ điểm mua”.

### 9.5 Xác nhận giao dịch và các lỗi thực thi

- `OrderSend`/hàm CTrade trả true không có nghĩa đã khớp. Kiểm mã trả về, đối soát order/deal/vị thế.
- Lưu ý định và khóa `plan_id` trước gửi. Kết quả không rõ: `SENT_UNKNOWN`, khóa mở mới, đối soát; không gửi lại để đoán.
- Yêu cầu bị từ chối chắc chắn: ghi lỗi và hủy lần gửi. Không tái dùng tín hiệu đã hết hạn; không nới dừng để cố được sàn nhận.
- Sau khớp, kiểm giá/khối lượng thật và SL/TP đang có. Thiếu bảo vệ hoặc vượt trần tiền chịu lỗ: yêu cầu đóng an toàn, vẫn tính đủ chi phí.
- Thay tài khoản/ký hiệu, có vị thế không thuộc bot hoặc khớp từng phần: xử lý bằng danh tính/ràng buộc rõ; không đóng lệnh người dùng.
- Chỉ thay trạng thái “đã bảo vệ/đã đóng” sau khi sàn xác nhận. Mất kết nối không đồng nghĩa lệnh đã bị hủy.

## 10. Dừng lỗ, mục tiêu và khối lượng

### 10.1 Mốc làm nhận định sai

| Kịch bản | Mốc dừng theo ý nghĩa |
|---|---|
| Bật tại hỗ trợ/kháng cự | Ngoài cực trị phản ứng và biên cấu trúc đang được dùng để đánh nhịp bật |
| Hồi nông | Ngoài đáy/đỉnh của nhịp hồi nông đã xác định |
| Đi ngang | Ngoài biên đang đánh và cực trị phản ứng ở biên đó |
| Phá tiếp | Phía quay lại làm cú phá mất hiệu lực hoặc cực trị nhịp đẩy liên quan |
| Phá rồi kiểm tra lại | Ngoài cực trị kiểm tra lại/mép mà mất nó thì không còn giữ phía mới |
| Phá giả | Ngoài cực trị cú xuyên bị từ chối |
| EMA | Ngoài cực trị phản ứng giá, không lấy riêng đường EMA làm tường chắc chắn |

Chọn mốc **trước khi tính khối lượng**. Đệm theo bước giá/spread/dao động đã biết, không chỉ đúng một tick sau râu.
Phân biệt mốc sai của nhịp M1 với mốc sai của cả vùng H1: một lệnh M1 dừng không tự xóa hỗ trợ H1.

Nếu khoảng dừng quá nhỏ so với dao động thường thấy, đánh dấu `STOP_TOO_CLOSE_TO_NOISE` và kiểm lại hình học.
Không tự dời thêm một khoảng vô nghĩa: chỉ chọn mốc khác nếu mốc đó thực sự làm kịch bản sai; không có thì bỏ lần vào.
Nếu vùng lớn rộng, có thể dùng cấu trúc con cho một nhịp con đã xác nhận, nhưng phải ghi đúng luận điểm đó.

### 10.2 Tính tiền chịu lỗ và khối lượng

- Tính lỗ đến SL bằng thông số broker và đúng chiều giá, cộng phí/trượt dự phòng chưa có trong giá.
- Chọn khối lượng không vượt ngân sách mỗi lệnh; làm tròn **xuống** theo bước lot.
- Nhỏ hơn lot tối thiểu: bỏ, không làm tròn lên vượt tiền chịu lỗ. Không cố định 0,01 cho mọi khoảng dừng rồi gọi rủi ro bằng nhau.
- Kiểm lại ký quỹ, khoảng cách lệnh của broker, giá sau làm tròn và tổng rủi ro trước gửi.
- Không khẳng định SL bảo đảm mất đúng số tiền dự kiến khi giá nhảy hoặc sàn không khớp ở mức đặt.

### 10.3 Chọn mục tiêu

- Chọn cản đối diện gần nhất **có căn cứ cấu trúc/phản ứng**, còn hiệu lực và đã biết tại thời điểm quyết định.
- Mức tham khảo yếu đơn lẻ không tự chặn mọi lệnh; vẫn theo dõi nếu giá thực sự phản ứng tại đó.
- Dùng khoảng của nhịp M1/M5. Không giữ tới mục tiêu D1 rất xa chỉ vì D1 cùng chiều.
- Đặt chốt trước mép cản một khoảng đệm có ghi nhận. Chọn đúng phía Bid/Ask, không áp giá Bid máy móc cho lệnh bán.
- Nếu không còn đủ khoảng sau chi phí: không vào. Không dời mục tiêu xuyên qua cản để làm đẹp tỷ lệ.
- Nếu đang trong vùng lớn đối nghịch, phải có mục tiêu cục bộ và đường đi giải thích được; không tuyên bố vùng lớn đã mất tác dụng.
- Phần còn lại đóng tại mục tiêu đã chọn. Không tự kéo mục tiêu xa hơn để cứu một lệnh thiếu khoảng lời.
  Nếu sau đó giá phá tiếp, có thể là cơ hội S05/S06 mới; phải đáp ứng điều kiện mới, không tái dùng xác nhận cũ.

Trước khi vào cần tìm được mốc đích cục bộ M1/M5 có căn cứ. Nếu cản khung lớn gần hơn mốc ấy, chốt trước cản gần hơn.
Không có mốc cục bộ thì bỏ; không lấy một cản H4/D1 xa làm dự phòng. Cản quá sát không được bỏ qua để chọn cản xa hơn.
Mục tiêu 5–10 giá là kết quả tốt có thể tận dụng, không phải khoảng lời bắt buộc.

### 10.4 Điều kiện chi phí

`net_reward_money = profit_at_target - fees_not_in_prices - slippage_reserve`.
`risk_money = loss_at_stop + fees_not_in_prices + slippage_reserve`.

Chỉ gửi khi hai đại lượng tính được, risk nằm trong ngân sách và `net_reward_money/risk_money` đạt ngưỡng của bộ thử đã khóa.
Ngưỡng không phải dự báo xác suất thắng. Phí thiếu hoặc spread không đúng thời điểm phải hiện rõ, không điền 0 để vượt cổng.

Khi có chốt phần: expected_reward = lời ròng phần đầu tại mốc chốt + lời ròng phần còn lại tại TP.
Risk dùng toàn khối lượng tới dừng ban đầu. Ví dụ chốt 50% ở 1R và 50% ở 2R chỉ là 1,5R trước phí;
nửa sau quay về giá vào thì chỉ còn 0,5R trước phí. Không ghi thành 2R.
Phải báo cả tỷ lệ dự kiến và lời trung bình/lỗ trung bình thực hiện; không lấy tăng tỷ lệ thắng thay cho tăng hiệu quả.

## 11. Quản lý lệnh đang mở

### 11.1 Những việc được ưu tiên theo thứ tự

1. Đối soát vị thế/sàn; kiểm SL/TP có tồn tại, danh tính và giới hạn rủi ro.
2. Thoát khi mốc vô hiệu/kịch bản thất bại hoặc phải dừng do giới hạn an toàn.
3. Thoát do phản ứng ngược có căn cứ trước mục tiêu.
4. Chốt phần/bảo vệ giá vào theo mục 11.2, rồi chỉ siết dừng theo cấu trúc mới; không nới.
5. Chỉ tìm lệnh mới sau khi đã xác nhận vị thế cũ đóng và có sự kiện mới.

### 11.2 Siết dừng và bảo vệ lợi nhuận

- Theo dõi nhịp sau lúc khớp trên M1; tham chiếu M5 nếu kế hoạch dùng cấu trúc M5. Không dùng nến trước lúc khớp như diễn biến sau khớp.
- Đáy/đỉnh mới phải đã được xác nhận tại lúc sửa dừng; không dùng pivot còn cần nến tương lai.
- Chỉ siết ra phía ngoài cấu trúc mới, có đệm và đủ khoảng broker.
  **[1.3]** Chỉ siết theo cấu trúc sau khi đã đi thuận ít nhất 1R (khoảng dừng ban đầu), để nhiễu M1 không đẩy lệnh ra sớm.
- **[YÊU CẦU]** Khi đi thuận khoảng 2–3 giá có thể bảo vệ tại giá vào. Mốc thử: 2,5 giá với vị thế không chia được.
  **[1.3]** Mốc bảo vệ = max(2,5 giá, 1R). Dừng 1,35 giá → 2,5 giá; dừng 4 giá → 4 giá. Tránh bị nhiễu đẩy ra ở hòa vốn.
  Với vị thế chia được, thử chốt phần tại 3 giá rồi bảo vệ phần còn lại. Giá đi thuận tính từ giá khớp tới giá thoát:
  mua dùng Bid, bán dùng Ask. Không dùng MFE quá khứ để sửa dừng khi giá hiện tại đã quay qua giá vào.
- Giá khớp không nhất thiết là hòa vốn ròng. Mức hòa vốn phải tính phí/trượt dự phòng; vẫn không bảo đảm tránh lỗ khi giá nhảy.
- Mỗi lần sửa dừng phải giữ nguyên TP trừ khi có một hành động chốt riêng đã được đặc tả. Không được vô tình xóa TP.

### 11.2a Chốt một phần rồi giữ phần còn lại [YÊU CẦU]

- Nếu khối lượng ban đầu >0,01 lot và chia hợp lệ: chốt một lần tại mức đi thuận thử 3 giá.
  Phần chốt = floor(50% khối lượng / bước lot) * bước lot; phần còn lại phải >= lot tối thiểu.
  0,02 → chốt 0,01/giữ 0,01; 0,03 với bước 0,01 → chốt 0,01/giữ 0,02. Không gọi 0,03 là chia đôi chính xác.
- Nếu mục tiêu đến trước mốc chốt phần, giữ cách đóng tại mục tiêu; không dời mục tiêu để cố chia lệnh.
- Xác nhận khối lượng đã giảm rồi kéo dừng phần còn lại về giá vào khi khoảng cách sàn cho phép.
  Giữ nguyên TP. Nếu chưa sửa dừng được phải báo chưa hoàn tất bảo vệ và thử sửa lại khi giá hợp lệ.
- Lưu ý định chốt trước gửi. Chưa rõ kết quả thì đối soát khối lượng, không gửi lại. Đã chốt không chốt tiếp một nửa nữa sau restart.
- Mất mốc bảo vệ, giới hạn lỗ, sắp nghỉ hoặc phản ứng ngược mạnh vẫn có thể đóng phần còn lại.
- Phí/trượt giá làm hòa vốn theo giá khác hòa vốn ròng. Không hứa luôn có lời sau chốt phần.
- **[YÊU CẦU, chốt 28/09]** Chốt phần là tùy chọn. Nếu chia lệnh làm tỷ lệ cả vị thế dưới ngưỡng
  (hoặc phần đầu không còn lời sau phí/trượt dự phòng) nhưng giữ nguyên khối lượng vẫn đạt ngưỡng,
  thì giữ nguyên khối lượng, không chốt phần; vẫn kéo dừng về giá vào ở mốc bảo vệ của vị thế không chia.
  Không đổi SL/TP/khối lượng để cứu kế hoạch chia; cả hai cách đều không đạt thì bỏ kế hoạch.
- Triển khai chốt phần qua ticket trên tài khoản hedging; cấu hình gửi có chốt phần phải từ chối tài khoản chưa hỗ trợ,
  không tự mở lệnh đối ứng trên tài khoản netting.

### 11.3 Thoát sớm

- Mất mốc bảo vệ của kịch bản: thoát theo mốc, không chờ RSI đồng ý. **[1.3]** "Mất mốc" là nến M1 hình thành sau lúc khớp
  đóng qua mốc vô hiệu. Râu chạm/xuyên mốc trong nến chưa đủ; dừng sàn (mốc + đệm) xử lý phần xuyên sâu.
- Tới vùng đối diện có từ chối P1 hoặc P2 **kèm P3 phá cấu trúc nhỏ** mới: được đóng trước mục tiêu.
  Pivot dùng cho P3 phải hình thành sau lúc khớp và đã được biết trước nến phản ứng. Thiếu thì chờ, không bịa mốc.
  P1 giữ điều kiện râu mạnh ở mục 7; P2 dùng thoát mềm cần thân >=0,8 ATR ngoài việc nhấn chìm.
  Hồi nhẹ hoặc một mẫu rút râu đơn lẻ chưa đủ. Mốc vô hiệu/dừng lỗ bảo vệ vẫn có hiệu lực độc lập.
- Một nến đổi màu nhỏ giữa đường không tự thành lý do đóng. Cần vị trí/mốc và phản ứng đã định nghĩa.
- Bản đầu các mẫu thoát theo nến dùng nến M1 đã đóng; SL khẩn cấp trên sàn vẫn hoạt động trong nến.
  Thoát theo lực tick trong nến chỉ mở khi có định nghĩa/kiểm chứng riêng, không gắn nhãn “mạnh” bằng cảm giác.
- Thoát sai chiều không tự tạo lệnh đảo chiều. Phải trở lại bộ chọn kịch bản và có xác nhận mới.

### 11.4 Theo dõi diễn biến, không đóng theo tuổi lệnh

- Theo dõi mức đi thuận lớn nhất từ lúc khớp, không chỉ lời/lỗ hiện tại.
- **[YÊU CẦU]** Không đóng chỉ vì đủ 2/3/5/10 phút hoặc vì MFE chưa vượt một ngưỡng sau số phút cố định.
- Đánh giá lại theo từng cập nhật giá và nến mới: mất mốc sai, tới cản có phản ứng mạnh, bảo vệ giá vào, siết dừng.
  Tuổi lệnh chỉ là số đo báo cáo; không biến thành quyền gồng lỗ, nới dừng hoặc kéo xa mục tiêu.
- Gần giờ nghỉ sàn không mở một kế hoạch có thể kéo qua giờ nghỉ. Chủ động thoát trước nghỉ theo chính sách đã chốt.
- Mất kết nối/không có giá thì không thể bảo đảm đóng đúng giây. Giữ bảo vệ trên sàn, báo tình trạng, xử lý khi có thể gửi lại.

## 12. An toàn và trạng thái không giao dịch

- Giới hạn tiền chịu lỗ mỗi lệnh, ngày, tuần và tổng phải có trước khi bật gửi. Các mức đề xuất ở mục 13 chưa là chấp thuận dùng tiền thật.
- Lỗ trong ngày/tuần của bot gồm deal đã đóng và lỗ nổi của vị thế thuộc bot. Không dùng lãi bot khác hoặc tiền nạp để che lỗ của bot.
  Vốn tham chiếu và mốc ngày/tuần phải lưu bền; không khởi động lại để reset giới hạn.
- Khi chạm giới hạn: khóa mở mới, xử lý vị thế thuộc bot theo chính sách dừng; không đóng lệnh người dùng hoặc EA khác.
- Khởi động lại: đối soát sàn trước, nhận lại vị thế đúng mã bot, giữ kế hoạch/mốc bảo vệ; bỏ tín hiệu cũ chưa gửi.
  Thiếu kế hoạch: khóa mở mới, không đoán mục tiêu hay nới dừng. Lệnh chờ không thuộc kế hoạch được nhận diện là bất thường, không tự tiếp quản.
- Giá hết độ mới, Bid/Ask sai, spread tăng bất thường, sàn nghỉ, quyền giao dịch thiếu, ký quỹ thiếu: không mở mới, ghi đúng lý do.
- Có vị thế/lệnh chờ không thuộc bot trên cùng mã: không mở mới, không sửa hoặc đóng lệnh đó.
- Với tin mạnh: chỉ chặn theo lịch đã xác thực và đúng múi giờ. Thiếu lịch phải ghi thiếu, không tự dựng sự kiện.
  Chính sách khi thiếu lịch và cửa sổ nghỉ quanh tin phải được chốt trước demo/thật; bản thử không có lịch phải báo giới hạn này.
- Tín hiệu mua/bán mâu thuẫn không giải được, không có mốc sai hoặc mục tiêu, hay giá đã chạy xa: chờ/bỏ, không cố tìm lệnh thay thế.
- Nhiều nhánh cùng thua không được tự làm bot tăng lot hoặc nới ngưỡng để hoàn thành chỉ tiêu số lệnh.

## 13. Bộ tham số đề xuất để review — chưa phải thông số có lợi thế

**Các giá trị số cụ thể trong bảng là [THỬ NGHIỆM].** Người dùng đã chốt cách quản lý ở mục 11,
nhưng chưa nghiệm thu giá trị tối ưu. Không lấy bảng làm quyền chạy demo/thật.
Các hằng số nhận dạng ở trên tham chiếu bảng này. Mỗi lần đổi phải tăng phiên bản bộ tham số, nêu lý do và đo lại;
không âm thầm thử hàng trăm tổ hợp rồi chỉ báo tổ hợp tốt nhất.

| Tham số | Giá trị thử đầu | Ý nghĩa/đánh đổi |
|---|---|---|
| Khung phát tín hiệu | M1 và M5, độc lập | Chung bộ quản lý rủi ro/chống trùng |
| Khung quản lý nhanh | M1 | Không bắt tín hiệu M5 phải có thêm tín hiệu M1; M1 dùng quản lý sau vào |
| Pivot N/N | M1/M5: 2; M15/H1: 3; H4/D1: 2 | N nhỏ nhạy hơn nhưng nhiễu hơn; không dùng pivot trước lúc xác nhận |
| ATR | 14, Wilder | Chuẩn hóa dao động, không dự báo hướng |
| EMA | 20/50/200 của M5/M15/H1 | 9 nhóm đo riêng, không cần chạm cả ba |
| Đệm hình học `k_buffer` | 0,10 ATR_ref, ít nhất 2 tick; đệm gửi/dừng lấy thêm spread hiện tại | Không nhầm đệm hình học với chi phí thực thi |
| Râu P1 | ≥ 2 thân, ≥ 0,5 ATR; đóng trong 1/3 phía bật | Chỉ là định nghĩa thử cho một mẫu |
| Quan sát P1 trong nến | Qua 20% thời lượng nến; giữ phía bật ≥ 2 giây với ≥ 3 cập nhật giá | Biến thể riêng, mặc định chỉ nghiên cứu; không dùng số cập nhật làm khối lượng thật |
| Thân phá P4 | ≥ 0,8 ATR; đóng trong 1/4 phía phá | Không bắt có râu/RSI cùng lúc |
| Thời gian phản ứng sau chạm | Tối đa 2 nến của khung giao dịch | Hết hạn thì hủy episode, không biến thành pending |
| Chờ kiểm tra lại sau phá | Tối đa 5 nến khung giao dịch | Cần sự kiện kiểm tra lại xảy ra sau phá, không suy từ OHLC mơ hồ |
| Lấy lại vùng sau xuyên cho S07 | Tối đa 2 nến; xuyên tối thiểu một đệm giá | Phá giả là tên mẫu quan sát, không biết trước tương lai |
| Đoạn tìm OB | Tối đa 20 nến nguồn trước nến phá, trong cùng chân đẩy | Không nhặt một nến ngược bất kỳ rất xa |
| Bề rộng FVG tối thiểu | max(2 tick, 0,10 ATR nguồn) | Loại sai số giá rất nhỏ, chưa phải mức tối ưu |
| Tuổi vùng tĩnh tối đa | 200 nến của khung nguồn | Giới hạn vòng đời theo dõi; lưu lịch sử, không tự đóng vị thế vì hết tuổi |
| Cửa sổ tìm đi ngang | 20 nến khung giao dịch; ≥ 2 lần chạm độc lập mỗi biên | Không đếm lặp tick thành chạm |
| Dung sai gom biên đi ngang/EMA | max(2 tick, 0,10 ATR khung giao dịch tại lúc tiếp cận) | Đóng băng trong episode |
| Hồi nông S03 | Không quá 50% đoạn đẩy đã biết | Phải có phản ứng mới, không đặt limit cố định tại 50% |
| Dừng quá sát để cần kiểm lại | Khoảng dừng < 0,5 ATR khung giao dịch tại xác nhận | Không tự nới đến 0,5 ATR nếu không có mốc thật; tìm lại hình học hoặc bỏ |
| Giá chạy xa khỏi giá xác nhận | > 0,25 ATR khung giao dịch | Bỏ gửi hiện tại/chờ episode mới, không đuổi |
| Hạn từ xác nhận tới gửi | 2 giây | Quá hạn phải đánh giá mới; không gửi tín hiệu tồn từ phút trước |
| Độ cũ báo giá tối đa | 2 giây tính từ lúc nhận bằng đồng hồ đơn điệu | Không giả vờ biết độ trễ từ sàn nếu chưa đo được |
| Tỷ lệ lời/lỗ dự kiến sau chi phí | ≥ 1,5, tính cả phần chốt đầu | Mốc thử trong khoảng 1,5R–3R người dùng nêu; không ép mục tiêu xuyên cản |
| Đệm trượt giả định | 0,5 giá vàng mỗi chặng thị trường, báo thêm độ nhạy (`InpSlipPerLeg`) | Không phải số trượt thực đã đo trên demo |
| Tiền chịu lỗ mỗi lệnh | 0,25% vốn hiện có | **Cần chủ bot chốt trước gửi demo/thật** |
| Giới hạn lỗ ngày / tuần / tổng | 2% / 5% / 8% vốn tham chiếu tương ứng | **Cần chốt**, lưu bền, không reset bằng restart/nạp tiền |
| Vị thế đồng thời | 1 mỗi tài khoản/ký hiệu | Nhiều nhánh không nhân rủi ro |
| Bảo vệ giá vào khi không chia lệnh | max(2,5 giá, 1R) đi thuận (`InpBreakevenR`=1) | Mốc thử; 0 = chỉ theo 2,5 giá |
| Siết theo cấu trúc | Sau khi đi thuận 1R (`InpTrailAfterR`=1) | 0 = siết ngay như bản 1.2 |
| Vùng mở lần theo dõi vào lệnh | OB M1 và mọi vùng M5 trở lên (`InpUseM1MinorZones`=false) | Đỉnh/đáy, FVG, MSNR M1 chỉ dùng xác nhận/mốc |
| Cản mục tiêu từ vùng M1 | Chỉ khi vùng đã có phản ứng (`InpM1TargetNeedsReaction`=true) | Tránh đỉnh/đáy M1 li ti chặn mọi lệnh |
| Chốt một phần | 3 giá đi thuận, 50% làm tròn xuống | Chỉ một lần; phần chốt và phần giữ đều phải đủ lot tối thiểu |
| Hạn giữ theo phút | Không có | Vẫn đóng khi mất mốc, cản phản ứng mạnh, giới hạn lỗ hoặc nghỉ sàn |
| Tín hiệu/mở lệnh mặc định | Quan sát; mọi gửi lệnh tắt | Chỉ bật nhánh qua cấp kiểm tra tương ứng |

Mốc 2,5/3 giá là lựa chọn thử trong khoảng người dùng nêu, chưa phải số tối ưu.
Các giá trị tiền chịu lỗ, mốc chốt phần/bảo vệ, vào trong nến, chính sách tin và quyền gửi cần review trước demo/thật.
Trong lúc chưa chốt được phép xây bộ máy, viết test và chạy nghiên cứu với hồ sơ ghi rõ `RESEARCH`, không tự dùng tiền thật.

## 14. Hợp đồng lập trình chi tiết — không tự suy diễn

### 14.1 Ký hiệu, thời điểm và công thức nến

Tất cả hình học trong mục này dùng giá Bid. `E` là khung phát tín hiệu M1 hoặc M5; `T` là khung nguồn của vùng.
`d=+1` cho mua, `d=-1` cho bán. `O,H,L,C` lần lượt là mở/cao/thấp/đóng; `range=H-L`, `body=abs(C-O)`.

- Nếu `range<=0`: nến không tạo P1/P2/P4; không chia cho 0.
- `lower_wick=min(O,C)-L`; `upper_wick=H-max(O,C)`.
- `location_buy=(C-L)/range`; `location_sell=(H-C)/range`.
- Nến quá khứ phải có `H>=max(O,C)`, `L<=min(O,C)`, giá hữu hạn/dương và thời gian tăng đúng; sai thì từ chối dữ liệu.
- `ATR_ref` của một episode là ATR14(E) cuối cùng đã đóng trước lúc episode bắt đầu; giữ nguyên trong episode.
  Khi tạo vùng trên T, dùng ATR14(T) trước nến xác nhận cuối; không lấy biến động tương lai.
- Vùng tĩnh chỉ tham gia phản ứng của nến có giờ mở `>= zone.known_at`. Vùng vừa hình thành khi nến đóng
  không được dùng làm vùng mà chính nến đó đã phản ứng.
- Đối với tín hiệu đóng nến, `reaction_known_at` là giờ nhận nến hoàn tất. Đối với trong nến, là giờ nhận tick đủ điều kiện.
- Hạn 2 giây tính bằng đồng hồ đơn điệu từ lúc nhận xác nhận, không trừ giờ máy tính với giờ sàn chưa quy đổi.
  Kiểm tính mới của nến riêng: nhận bù/nhận sau mốc đóng quá 2 giây thì không phát lệnh từ nến đó.
- Lưu `broker_time`, `received_at_utc`, `received_monotonic_ms`, và độ lệch giờ sàn được cấu hình/kiểm chứng.
  Không ngầm coi mọi máy chủ đều UTC. Ngày/tuần rủi ro dùng múi giờ cấu hình, mặc định thử UTC+7.
- Tuần rủi ro bắt đầu thứ Hai 00:00 theo múi giờ rủi ro đã cấu hình.
- Ngày/tuần dùng tạo vùng theo nến D1/W1 của sàn; không tự gộp phiên Chủ nhật. Đây là lịch khác với lịch giới hạn lỗ.
- Đọc lại cùng một giá không làm mới thời điểm giá. Hai tick cùng mili giây giữ thứ tự nhận đã quan sát;
  nếu nguồn không cung cấp thứ tự thì đánh dấu không rõ, không tự tạo thứ tự dưới mili giây.

### 14.2 Pivot, mốc bảo vệ và hướng — thứ tự chính xác

Với nến p và N đã cấu hình, pivot cao hợp lệ khi:

```text
H[p] >= mọi H[p-N .. p-1]
H[p] >  mọi H[p+1 .. p+N]
```

Pivot thấp đối xứng: `<=` phía trái, `<` phía phải. Chỉ công bố khi nến p+N đóng và được nhận.
Nếu liên tiếp có pivot cùng loại, giữ cực trị mạnh hơn làm điểm cấu trúc; vẫn lưu các phát hiện gốc trong nhật ký.
Nếu cùng một nến là cả pivot cao/thấp, không đoán thứ tự diễn biến trong nến: đánh dấu mơ hồ và không dùng cặp đó để đổi hướng.

- `UP` được thiết lập khi hai pivot cao và hai pivot thấp xác nhận gần nhất cùng cao dần.
- `DOWN` đối xứng. Nếu chưa thiết lập được thì `UNDEFINED`.
- Mốc bảo vệ UP là pivot thấp xác nhận cuối trước lần đóng phá pivot cao theo chiều tăng;
  nếu chưa có lần phá ấy, dùng pivot thấp gần nhất đã tham gia cặp cấu trúc tăng. DOWN đối xứng.
- Chỉ cập nhật mốc bảo vệ theo hướng chặt hơn khi một lần phá cấu trúc thuận chiều mới đã được xác nhận.
- Nến của khung đó đóng vượt mốc bảo vệ ngược chiều thêm `eps_geom`: `TRANSITION`.
  Hướng đối diện chỉ thiết lập bằng cặp cấu trúc đối diện đã xác nhận; không lấy một nến đổi màu làm đủ bằng chứng.
- Với `local_direction`, lấy hướng cấu trúc của E. Khi E là TRANSITION/UNDEFINED, S05/S06/S07 vẫn được xét bằng sự kiện giá riêng;
  không mượn H1 làm hướng bắt buộc. S01 cần local_direction = d **hoặc** hướng lớn rõ = d [1.3]; S03 cần local_direction rõ;
  S02/S04/S08 không yêu cầu điều này.
- Hướng lớn tham chiếu là D1 nếu rõ, nếu D1 TRANSITION/UNDEFINED thì H4 nếu rõ; nếu cả hai chưa rõ ghi UNDEFINED.
  S02 là nhánh ngược hướng lớn chỉ khi hướng lớn rõ và `d` ngược hướng đó. Nếu chưa rõ, không giả gắn nhãn S02.

### 14.3 Công thức vùng và mức độ có căn cứ

- Pivot kháng cự: `[max(O_p,C_p), H_p]`; hỗ trợ: `[L_p,min(O_p,C_p)]`. Nếu hai biên bằng nhau, giữ là mức điểm;
  dung sai chạm là vùng riêng, không âm thầm làm rộng vùng gốc.
- FVG tăng từ nến a,b,c: `L_c > H_a`, vùng `[H_a,L_c]`; giảm: `H_c < L_a`, vùng `[H_c,L_a]`.
  Bề rộng đạt ngưỡng mục 13; nến giữa phải có thân theo chiều khoảng trống. Các FVG không kèm phá cấu trúc chỉ là REFERENCE_ONLY;
  FVG cùng chân đẩy đã có đóng phá cấu trúc được STRUCTURE_CONFIRMED.
- OB: trong tối đa 20 nến của chân đẩy dẫn tới lần đóng phá pivot đã biết, lấy **nến ngược chiều cuối về thời gian**;
  vùng `[L,H]` của nến đó. Không tìm thấy nến ngược thì không tạo OB. Biên không đổi theo các nến sau.
- MSNR: cặp xanh-đỏ cho mức kháng cự ở giá đóng nến xanh; đỏ-xanh cho mức hỗ trợ ở giá đóng nến đỏ.
  Doji không tự tạo cặp đổi màu. Ban đầu REFERENCE_ONLY.
- Hai phản ứng độc lập đã hoàn tất ở cùng vùng nâng REFERENCE_ONLY thành REACTION_ONLY. Các episode phải thực sự tách nhau theo mục 6.3.
  Không nâng mức độ dựa trên việc lệnh vừa lời; mức độ chỉ từ giá đã thấy.
- EMA hợp lệ dùng được riêng cho S08 sau đủ lịch sử, không cần nâng thành cấu trúc tĩnh và không tự làm mục tiêu.
- Vùng nguồn không có dữ liệu mới/hết tuổi: không tạo episode mới. Vùng đã phá không biến mất ngay:
  giữ hình học tới hết cửa sổ kiểm tra lại/phá giả của các episode đã mở; không mở các episode vô hạn trên vùng hết tuổi.
- “Chạm vùng”: `[low_seen,high_seen]` giao với `[bottom-eps_geom,top+eps_geom]` và nến/tick tiếp cận từ phía hợp lệ.
  Mua phản ứng hỗ trợ bắt đầu từ phía trên; bán phản ứng kháng cự từ phía dưới. Đi từ phía sai không được giả thành chạm mới.

### 14.4 Xác nhận và hủy — điều kiện số

Đối với cùng hình học `[B,T]`:

| Sự kiện | Điều kiện |
|---|---|
| Phá lên cục bộ `B0_UP` | Nến E đã đóng với `C > T + eps_geom` |
| Phá xuống `B0_DOWN` | `C < B - eps_geom` |
| P4 tăng | B0_UP và `C>O`, `body>=0,8*ATR_ref`, `location_buy>=0,75` |
| P4 giảm | B0_DOWN và các điều kiện đối xứng |
| P1 mua nến đóng | Đã chạm, `lower_wick>=2*body`, `lower_wick>=0,5*ATR_ref`, `location_buy>=2/3`, `C>T`, `C>=O` |
| P1 bán | Đối xứng, `C<B`, `C<=O` |
| P2 mua | Nến trước đỏ; nến hiện tại xanh; `O<=C_prev`, `C>=O_prev`, thân lớn hơn; đã chạm trong một trong hai nến; `C>T` |
| P2 bán | Đối xứng, đóng dưới B |
| P3 mua | Giá đã chạm, sau đó nến E đóng trên đỉnh nhỏ đã khóa của nhịp đi vào vùng thêm eps_geom |
| P3 bán | Đối xứng với đáy nhỏ |
| Kiểm tra lại tăng | B0_UP đã có trước; một nến E mở sau lúc biết B0_UP quay về mép T; P1/P2/P3 tăng quanh mép T |
| Kiểm tra lại giảm | Đối xứng quanh mép B |
| Kiểm tra lại tăng thất bại | Nến E đóng lại dưới `T-eps_geom`, hoặc giá tới mốc vô hiệu đã khóa của episode |
| Kiểm tra lại giảm thất bại | Đối xứng trên `B+eps_geom` |

**B0 khác P4:** một nến đóng vượt mép có thể mở cửa quan sát S06, nhưng chỉ P4 mới cho vào ngay theo S05.
Không bắt nến phá nhẹ và nhánh kiểm tra lại cũng phải đạt thân mạnh của S05.

Với P3, khóa pivot nhỏ gần nhất đã biết tại lúc chạm: mua chọn pivot cao gần nhất trong 20 nến E trước chạm, bán chọn pivot thấp.
Thiếu pivot thì P3 không khả dụng, P1/P2 vẫn được xét. Cực trị mới từ lúc chạm tới xác nhận được dùng cho mốc vô hiệu, không dùng pivot tương lai.

P5 quanh mép đổi vai trò dùng vùng kiểm tra `[edge-eps_geom,edge+eps_geom]`, **không dùng nguyên bề rộng FVG/OB lớn làm mức phải vượt lần nữa**.
Giữ được phía mới đòi P1/P2/P3 tương ứng trong cửa sổ 2 nến từ lần chạm lại; chỉ chạm mép rồi xuyên không đủ.

S07 bán: trong tối đa 2 nến E, giá cao nhất đã thấy `>T+eps_geom`, sau đó nến đóng `C<T-eps_geom` và có P1/P2/P3 giảm mới.
Mua đối xứng qua B. Một nến có thể xuyên và lấy lại nếu đường giá/tick chứng minh thứ tự; nếu chỉ OHLC mà thứ tự ảnh hưởng quyết định,
không giả lập vào trong nến đó. Dùng xác nhận sau đóng hoặc đánh dấu mơ hồ.

### 14.5 Đoạn đẩy, hồi nông, đi ngang và ép cản

- Đoạn đẩy của S03 bắt đầu tại pivot ngược đã biết gần nhất trước P4; kết thúc ở cực trị nến P4 vừa đóng.
  Khóa hai mốc đó. Mức hồi = khoảng giá đi ngược từ cuối đoạn / độ dài đoạn. Hồi >50% hoặc phá điểm đầu thì hủy S03.
  Không có pivot đầu đoạn thì không có S03, không bịa đoạn đẩy.
- Đi ngang: xét 20 nến E đã đóng. Gom pivot cao/thấp đã biết thành cụm bằng dung sai khóa `eps_geom`.
  Hai cực trị cùng một cụm phải cách ít nhất 2 nến E; cần một cụm biên trên có ≥2 lần chạm độc lập
  và một cụm biên dưới có ≥2 lần chạm độc lập.
  Chọn cặp biên có lần chạm hợp lệ gần nhất; nếu bằng thì cặp có nhiều lần chạm hơn, rồi cặp hình thành trước.
  Upper lấy cực trị cao nhất của cụm cao, lower lấy cực trị thấp nhất của cụm thấp. `lower<upper` và sau lần chạm đầu
  không có B0 phá biên tương ứng. Không đủ thì không gắn nhãn đi ngang; không cấm các nhánh khác.
- “Giữa vùng đi ngang” là đoạn từ 25% đến 75% chiều rộng phạm vi; S04 chỉ phát sau tiếp cận biên và phản ứng ở biên,
  không phát từ giữa. Một cản cấu trúc nằm trong phạm vi vẫn có thể là mục tiêu gần hơn biên đối diện.
- Ép kháng cự: ≥3 lần tiếp cận độc lập tới cùng cụm cản, đáy các nhịp rút xuống sau mỗi lần cao dần và khoảng rút ngắn dần.
  Ép hỗ trợ đối xứng. Không đủ ba lần thì chỉ ghi quan sát, không gắn nhãn ép. Nhãn này không được tự gọi gửi lệnh.
- Thiếu dữ liệu để phân biệt hồi với đảo: trạng thái TRANSITION/WATCH, không ép một nhãn tăng/giảm.

### 14.6 Mốc vô hiệu và chuyển từ Bid sang giá lệnh

`episode_low/high` là cực trị đã quan sát từ lúc episode chạm tới thời điểm xác nhận, chỉ trên E hoặc tick đã nhận.
Kế hoạch chọn `thesis_scope` trước khi chọn SL:

- `LOCAL_REACTION`: luận điểm chỉ là nhịp phản ứng con. Mốc mua là episode_low, bán episode_high.
  Vùng T lớn là bối cảnh; dừng con không khẳng định cả vùng lớn đã hỏng.
- `ZONE_HOLD`: luận điểm là giữ cả một vùng nguồn M1/M5. Mốc mua `min(episode_low,B)`, bán `max(episode_high,T)`.
  Nếu T lớn hơn M5, không tự dùng ZONE_HOLD kéo SL dài; phải có kịch bản con LOCAL_REACTION riêng hoặc bỏ.
- `BREAK_HOLD` S05/S06: mua `min(đáy nến phá/kiểm tra lại, edge-eps_geom)`, bán đối xứng với đỉnh và `edge+eps_geom`.
  S05 dùng nến phá; S06 dùng episode kiểm tra lại, không dùng cực trị tương lai.
- S07: mốc mua là đáy cú xuyên, bán là đỉnh cú xuyên đã được ghi; không bỏ phần râu để ép SL sát.
- S04: mốc nằm ngoài biên đang đánh và cực trị phản ứng ở biên; không lấy biên đối diện làm SL.

Mua: `entry=Ask_now`, `SL_bid=invalidation_bid-stop_buffer`.
Bán: `entry=Bid_now`, `SL_ask=invalidation_bid+stop_buffer+spread_now`.
Mục tiêu mua trước kháng cự: `TP_bid=near_edge_bid-target_buffer`.
Mục tiêu bán trước hỗ trợ: `TP_ask=near_edge_bid+target_buffer+spread_now`.

Làm tròn SL ra phía ngoài, TP về phía chốt sớm hơn theo tick_size. Sau làm tròn phải tính lại tiền/ràng buộc broker.
Với dừng quá gần nhiễu hoặc quá xa ngân sách, bản đầu từ chối kế hoạch đó; không lặp tìm một mốc tùy ý để cứu tỷ lệ.
Nếu cần đổi thesis_scope thì phải tạo kế hoạch khác có dữ kiện riêng, không sửa ngầm kế hoạch đã gửi.

### 14.7 Chọn cản mục tiêu — không dùng một điểm yếu để chặn mọi nhánh

1. Xét các vùng còn hiệu lực/đã biết, vai trò đối diện trên khung phù hợp, mức STRUCTURE_CONFIRMED hoặc REACTION_ONLY.
2. Mua: mép gần phải ở trên giá Bid hiện tại; bán: ở dưới. Xếp theo khoảng cách theo chiều giao dịch.
3. Chọn mép gần nhất, có xét các khung lớn ở phía trước. Không cộng điểm rồi bỏ qua cản gần để chọn đích xa.
4. Nếu đang nằm trong một vùng lớn: không coi mép đã ở sau lưng là TP. Tìm mốc M1/M5 phía trước bên trong;
   mép xa của vùng lớn là mốc cảnh báo bổ sung. Không có mốc có căn cứ thì không mở mới.
5. Nếu giá đang trong cản M1/M5 đối diện và chưa có sự kiện phá/đổi vai trò phù hợp, chờ; không gọi đó là khoảng chạy trống.
6. EMA và mức REFERENCE_ONLY không tự làm hard target; phản ứng thực tại đó vẫn có thể kích hoạt thoát sớm theo mục 11.
7. **[1.3]** Vùng M1 chỉ làm cản mục tiêu khi đã có ít nhất một phản ứng được ghi nhận. Vùng M5 trở lên giữ nguyên quy tắc trên.

### 14.8 Hợp đồng trạng thái và danh tính

| Đối tượng | Trường bắt buộc |
|---|---|
| `Bar` | symbol, tf, open_time, close_time, known_at, OHLC Bid, tick_volume, source_id, completeness |
| `FrameContext` | tf, direction, protected_pivot_id, pivot_ids, last_closed_at, known_at, data_status |
| `Zone` | các trường mục 5.3; price_side=BID; geometry_version |
| `Episode` | episode_id, zone/cluster_id, entry_tf, touch_at, approach_side, local_role, role_version, state, ATR_ref, eps_geom, extrema_seen, deadlines |
| `BreakEvent` | event_id, zone_id, break_tf, direction, bar_id, known_at, edge_bid, B0/P4 flags, invalidation_bid |
| `Reaction` | reaction_id, P1/P2/P3/P4/P5, evidence_ids, known_at, provisional, observed_until |
| `TradePlan` | toàn bộ mục 9.4; thesis_scope; risk references; market-only flag |
| `OwnedPosition` | plan_id, broker order/deal/position IDs, actual fills/volume, confirmed SL/TP, fees, execution state |

Khóa gửi tối thiểu `(account_scope, symbol, episode_id, reaction_id, role_version)`; account_scope không công bố dữ liệu tài khoản.
Một sự kiện gặp trên hai khung/loại vùng phải có liên kết cùng cụm/đường giá để chống trùng. Không dùng tên hiển thị làm ID.
Danh sách trạng thái thực thi: `IDLE → PLAN_READY → SENT_UNKNOWN → ACCEPTED/PARTIAL/FILLED → CLOSE_REQUESTED → CLOSED`;
nhánh chắc chắn bị từ chối đi `REJECTED`. Không nhảy từ SENT_UNKNOWN về IDLE vì hết thời gian chờ nếu chưa đối soát.

### 14.9 Đơn vị và công thức tiền

- Tất cả ngân sách là tiền theo đồng tiền tài khoản; giá và số điểm không được gọi là USD lãi nếu chưa chuyển qua thông số sản phẩm.
- Trước dùng OrderCalcProfit/OrderCalcMargin, phải có kết nối/thông số cần thiết và phép kiểm tra tính tiền hợp lệ.
  Kết quả API true nhưng tiền bằng 0 cho một biến động không bằng 0 là lỗi cần điều tra, không phải lệnh miễn rủi ro.
- Dùng một khối lượng tham chiếu hợp lệ để tính `loss_per_volume` tới SL và phí/trượt dự phòng tương ứng.
  `raw_volume=risk_budget_money/loss_per_volume`; làm tròn xuống bước lot, kẹp volume_max; dưới volume_min thì bỏ.
- Kiểm lại toàn bộ tại khối lượng đã làm tròn, đặc biệt nếu phí tối thiểu làm phí không tuyến tính theo lot.
- Phí dự phòng chưa nằm trong giá phải cộng đúng một lần. Với giá khớp mua Ask/thoát Bid và bán Bid/thoát Ask, spread đã có.
- MFE/MAE tính từ giá khớp thật tới giá thoát có thể thực hiện: mua dùng Bid, bán dùng Ask; không dùng giá giữa để làm đẹp kết quả.

### 14.10 Các chính sách vận hành phải có giá trị, không để DeepSeek đoán

Hồ sơ dưới đây dùng để chạy nghiên cứu; không phải sự cho phép chạy tiền thật:

```yaml
spec_version: SCP-MTF-1.3-review-fixes
profile_status: RESEARCH
symbol: XAUUSDm
entry_frames: [M1, M5]
execution_mode: MARKET_AFTER_FRESH_REACTION
broker_pending_entries_allowed: false
max_owned_positions_per_symbol: 1
trading_enabled: false
allow_live_account: false
intrabar_entry_enabled: false
intrabar_pattern_exit_enabled: false
enabled_scenarios_in_observation: [S01, S02, S03, S04, S05, S06, S07, S08]
risk_day_utc_offset_hours: 7
risk_per_trade_pct: 0.25
daily_loss_limit_pct: 2.0
weekly_loss_limit_pct: 5.0
total_loss_limit_pct: 8.0
min_net_reward_risk: 1.5
max_signal_send_age_ms: 2000
max_quote_receive_age_ms: 2000
spread_spike_multiple: 2.0
spread_median_window_seconds: 60
spread_warmup_min_quotes: 30
news_before_minutes: 5
news_after_minutes: 5
missing_news_policy: BLOCK_DEMO_AND_LIVE
close_before_session_end_seconds: 60
time_based_position_exit: false
partial_close_trigger_price: 3.0
partial_close_fraction: 0.5
breakeven_trigger_price: 2.5
breakeven_trigger_r: 1.0
trail_after_r: 1.0
m1_target_needs_reaction: true
use_m1_minor_zones: false
slippage_per_leg_price: 0.5
```

- Quan sát có thể chạy tất cả nhánh; quyền gửi của từng nhánh là cấu hình riêng, mặc định tắt. Trong máy thử phải ghi rõ nhánh nào bật.
- Spread tăng bất thường: `spread_now > 2*median(spread trong 60 giây vừa qua, chỉ dữ liệu đã nhận)`; tối thiểu 30 quote hợp lệ.
  Chưa đủ mẫu thì chỉ quan sát. Đây là tham số thử an toàn, phải đo tỷ lệ bỏ và tác động, không tự gọi tối ưu.
- Tin: sự kiện tác động cao USD có giờ được xác thực; không mở trong cửa sổ −5/+5 phút. Thiếu lịch:
  nghiên cứu được tiếp tục nhưng phải ghi thiếu; demo/thật bị chặn theo hồ sơ này, không tự bỏ cổng.
- Không mở nếu thời gian tới nghỉ sàn không rõ hoặc `<=60 giây`. Đóng chủ động trước nghỉ 60 giây; không giữ qua phiên nghỉ.
- Ngưỡng dừng ngày: 2% vốn tài khoản ở đầu ngày; tuần: 5% vốn đầu tuần; tổng: 8% vốn lúc phiên vận hành được cho phép bắt đầu.
  Lỗ đem so là PnL ròng thuộc bot trong cùng kỳ, cộng lỗ/lãi nổi của vị thế bot; loại nạp/rút/credit.
  Mốc vốn lưu bền, tiền nạp/rút không xóa bộ đếm lỗ. Đổi mốc tổng cần thao tác người dùng rõ ràng khi đã đối soát/phẳng.
- Chạm ngày: khóa tới ngày mới; chạm tuần: khóa tới tuần mới; chạm tổng: khóa tới khi người dùng cho phép đặt lại.
  Trong cả ba trường hợp, yêu cầu đóng vị thế bot, giữ SL sàn nếu chưa gửi được, không tác động vị thế ngoài bot.
- Lỗi xác định không có lệnh được nhận: hủy lần gửi. Lỗi không rõ hoặc bị ngắt khi gửi: đối soát, không thử mở thêm.
  Mất kết nối thì tắt mở mới; sau nối lại phải đồng bộ, đối soát và đợi phản ứng mới, không phát lại tín hiệu tồn.
- Quản lý theo giá khớp thật và ATR_M1 đã biết lúc vào. Thiếu ATR_M1 thì kế hoạch chưa đủ dữ liệu.
- Các trường tương thích hold_deadline/no_progress_deadline/hold_seconds/progress_seconds luôn bằng 0 và không gây đóng;
  giá trị còn lưu từ lần chạy trước cũng không được khôi phục thành hạn đóng theo phút.

### 14.11 Ví dụ có số để kiểm tra cách hiểu

Các số là minh họa hình học, không là tham số tối ưu hoặc khuyến nghị giao dịch. Giả sử tick=0,01, spread=0,20,
ATR_ref=1,00 thì eps_geom=0,10 và stop/target_buffer=0,20.

**V01 — D1 giảm vẫn có thể mua nhịp bật:** hỗ trợ `[99,80;100,20]`; nến M1 O=100,50, H=100,60, L=99,60, C=100,55.
Râu dưới 0,90, thân 0,05, vị trí đóng 0,95: P1 tăng đủ. S02 được xét dù H1 giảm.
LOCAL_REACTION có mốc sai 99,60, SL Bid=99,40. Ask gửi giả sử 100,75, cản 104,00 → TP Bid=103,80.
Vẫn phải kiểm phí, tiền chịu lỗ và khối lượng; ví dụ đủ mẫu không tự có nghĩa được gửi.

**V02 — Không bán khi lần quay lại đang phá:** kháng cự `[101,80;102,20]` từng đẩy giá xuống 100,80.
Lần quay lại giá lên 102,20 rồi 102,50, chưa có phản ứng giảm mới: không có SellLimit chờ sẵn, không bán.
Nến M1 đóng 102,50 có thể tạo B0_UP; chỉ nếu thân/vị trí đóng cũng đủ mới có S05, không tự gọi mọi lần xuyên là P4.

**V03 — Đổi vai trò sau kiểm tra lại:** sau B0_UP đã biết, giá quay từ trên xuống vùng mép `[102,10;102,30]`.
Giả sử mốc vô hiệu đã xác định của lần phá là Bid=101,70; chạm mốc này trong lúc chờ thì hủy, không đợi đóng nến.
Nến sau O=102,50, H=102,60, L=102,15, C=102,55: râu 0,35 <0,5 ATR_ref, nên **P1 chưa đủ**.
Bot không được tự sửa ngưỡng để gọi là đẹp; có thể chờ P2/P3 trong cửa sổ, hoặc hết hạn. Nếu L=101,95 và C=102,55,
râu=0,55, body=0,05, vị trí đóng đủ và không có sự kiện vô hiệu: P1 có thể xác nhận S06 tăng.
Vai trò M1 đổi thành hỗ trợ; D1 giảm vẫn được giữ nguyên trong bối cảnh.

**V04 — Rút râu không phải đảo ngày:** giá vượt 102,30 rồi nến đóng 101,60 với phản ứng giảm đủ.
Đây có thể là S07 bán sau lấy lại phía cũ; không ghi H4/D1 đã đổi hướng chỉ từ nến này.

**V05 — Giá vào chạy xa:** phản ứng mua được xác nhận ở Bid=100,55; trước khi gửi Bid đã lên 100,90,
chênh=0,35 >0,25 ATR_ref. Bỏ lần gửi, dù hình nến vẫn đẹp. Không tự đặt limit quay về giá cũ.
Đo đuổi giá bằng Bid hiện tại so với Bid lúc xác nhận cho cả hai chiều (đảo dấu khi bán), không so Ask với Bid.
Trước gửi phải còn giữ phía xác nhận; quay lại bên trong vùng thì thu hồi READY, chờ phản ứng mới.

**V06 — Chín EMA không phải chín cổng:** chỉ EMA50 M15 bị chạm và có P2 mua; EMA20/200 không bị chạm.
S08 được xét, không trả lý do “thiếu hai EMA”. Nếu EMA200 H1 chưa đủ dữ liệu, chỉ nhóm đó không khả dụng.

**V07 — Khối lượng nhỏ hơn tối thiểu:** ngân sách 10 đơn vị tiền, rủi ro mỗi 0,01 lot tính được 15; sàn chỉ cho từ 0,01 lot.
Không được gửi 0,01 rồi ghi rủi ro là 10. Bỏ kế hoạch. Không kéo SL vào trong vùng chỉ để làm phép tính đạt.

**V08 — Tính tiền và khối lượng:** ví dụ giả định, không phải thông số tài khoản/sàn thực tế:
vốn 10.000, rủi ro 0,25%=25; hợp đồng 100 đơn vị/lot, bước và tối thiểu 0,01 lot, phí 0,
đệm trượt mỗi chiều 0,50 đơn vị giá. Mua Ask=100,75; SL Bid=99,40; cản 105,00 → TP Bid=104,80.
Với 0,01 lot: lỗ dự kiến 1,35+1,00=2,35; lời ròng dự kiến 4,05−1,00=3,05;
tỷ lệ=1,298. Khối lượng thô 25/235=0,10638 lot, làm tròn xuống 0,10 lot: rủi ro 23,50, lời dự kiến 30,50.
Phải dùng thông số thật và phép tính tiền của MT5 khi vận hành, không chép hệ số ví dụ vào mã.
V08 chỉ minh họa tính tiền khi chưa chia lệnh. Với ngưỡng thử 1,5 và chốt phần, ví dụ này chưa đủ để được gửi.

## 15. Phân chia trách nhiệm khi triển khai

**Quyết định đã chốt ngày 28/09/2026: giữ MQL5 cho bot. Không chuyển sang Rust.**
Mã EA dùng `.mq5`, phần tính toán dùng `.mqh`, biên dịch thành `.ex5` chạy trong MT5.
PowerShell `.ps1` phục vụ công cụ; JavaScript `.mjs` phục vụ phân tích ngoài luồng giao dịch.
Không đặt dịch vụ ngoài hoặc mô hình ngôn ngữ vào đường quyết định/gửi lệnh.

Đây là trách nhiệm cần tách, không phải yêu cầu tạo sẵn tám thư mục/lớp trống:

| Phần | Đầu vào | Đầu ra | Không được làm |
|---|---|---|---|
| Dữ liệu/thời gian | Tick, nến, thông số broker | Dữ liệu đúng thời điểm + chất lượng | Tạo tín hiệu từ dữ liệu tương lai |
| Bối cảnh/vùng | Nến đã đóng, định nghĩa vùng | Hướng từng khung, vùng và phiên bản | Gửi lệnh, tự đoán thiếu dữ liệu |
| Kịch bản | Bối cảnh, đường giá mới, trạng thái episode | Đề nghị S01–S08 hoặc lý do chờ/hủy | Tự gọi CTrade |
| Kế hoạch/rủi ro | Đề nghị, giá mới, vốn/chi phí | Giá giới hạn, SL/TP/lot hoặc từ chối | Nới mốc để làm đẹp tỷ lệ |
| Thực thi/đối soát | Kế hoạch đã qua kiểm tra | Xác nhận gửi/khớp/đóng | Gửi lại khi không biết kết quả cũ |
| Quản lý vị thế | Kế hoạch gốc, vị thế thật, diễn biến mới | Siết/đóng hoặc giữ, có lý do | Sửa vị thế ngoài quyền sở hữu |
| Nhật ký/báo cáo | Sự kiện và deal thật | Lịch sử giải thích/kiểm chứng được | Biến mô phỏng thành kết quả thật |

Một nơi duy nhất có quyền gửi lệnh. Không để từng nhánh tự quản lý một CTrade/khóa riêng.
Không cần AI ngôn ngữ quyết định trực tiếp mua/bán; những thuật ngữ trong tài liệu phải được chuyển thành điều kiện có thể kiểm tra.

### 15.1 Trình tự xử lý tại một sự kiện giá

```text
nhận giá và đánh dấu received_at
đối soát sàn, cập nhật rủi ro, ưu tiên vị thế đang mở
đóng các nến đã thật sự đủ thời gian, ghi known_at
cập nhật bối cảnh của các khung vừa đóng
xét phản ứng với hình học vùng đã tồn tại trước phản ứng đó
cập nhật phá/kiểm tra lại/hủy và các episode
tạo các đề nghị độc lập S01..S08
loại trùng/xung đột; chọn tối đa một đề nghị còn mới
nếu đang có vị thế/yêu cầu chưa rõ kết quả: không mở thêm
đọc lại quote; lập kế hoạch; kiểm rủi ro, giá, thời hạn và quyền
lưu ý định; gửi một lần; chờ/đối soát kết quả thật
ghi đủ lý do, bao gồm đề nghị bị bỏ
```

Khi một thời điểm đóng đồng thời M1/M5/H1, phải có ảnh chụp vùng trước đóng để giải thích nến vừa kết thúc,
và ảnh bối cảnh sau đóng để chọn hướng hiện tại. Không sửa thứ tự theo cách gây nhìn trước hoặc dùng H1 cũ.

### 15.2 Tốc độ và tránh bỏ lỡ cơ hội

- Luồng nhận giá phải ngắn: cập nhật trạng thái, bảo vệ vị thế, xét các vùng gần giá và xác nhận còn mới.
- Chỉ tính lại nến, hướng và chỉ báo của khung vừa thay đổi; lưu kết quả để dùng lại. Không quét toàn bộ lịch sử mỗi tick.
- Không bỏ mọi tick trong cùng một giây. Nhánh quan sát trong nến phải nhận được các thay đổi giá có ý nghĩa.
- Không gọi mạng, tạo báo cáo lớn hoặc cập nhật giao diện dày đặc trong đường quyết định.
  Gom nhật ký thông thường để ghi theo đợt có giới hạn; ý định gửi và thay đổi quyền sở hữu phải được lưu bền trước hành động.
- MT5 xử lý sự kiện lần lượt; tick mới có thể không tạo thêm sự kiện nếu OnTick còn bận.
  Không hứa nhận đủ từng tick. Khi cần lấy bù, dùng bộ đệm giới hạn và thứ tự dữ liệu kiểm chứng được;
  dữ liệu nhận bù phục vụ khôi phục trạng thái, không mở bù tín hiệu đã hết độ mới.
- Đo riêng thời gian tính toán, thời gian gọi gửi, thời gian xác nhận/khớp. Báo trung vị, mức 95%, 99%,
  số mẫu, máy/VPS, phiên thị trường, số vùng và mức hoạt động giá. Không coi thời gian sàn trả lời là thời gian phân tích.
- Giới hạn độ trễ phải được chốt từ số đo trước khi cho chạy. Chưa có số đo thì ghi chưa đo, không hứa tốc độ mili giây.
- Chỉ tối ưu phần đã chứng minh chậm; cùng dữ liệu phải cho cùng quyết định trước/sau tối ưu.
  Chỉ xem xét ngôn ngữ khác khi có số đo chứng minh MQL5 không đáp ứng và có phê duyệt mới của chủ bot.

## 16. Nhật ký, hiển thị và khả năng điều tra

### 16.1 Mỗi sự kiện cần lưu

- Phiên bản SPEC/mã/tham số; nguồn dữ liệu; giờ nguồn và giờ nhận, độ phân giải mili giây nếu có.
- Mã vùng, phiên bản, khung, mốc đã biết; episode và nhánh; hướng từng khung, không chỉ một chữ BUY/SELL.
- Thời điểm chạm, phản ứng, đủ điều kiện, gửi, nhận kết quả, khớp, dời dừng và đóng.
- Giá/mốc/chi phí ở lúc quyết định và giá thật; trường thiếu phải là thiếu, không phải 0.
- Lý do chờ/bỏ/hủy/đóng và điều kiện đã kích hoạt. Các dòng kiểm tra lặp không được gọi là cơ hội độc lập.
- Mọi lần sửa dừng phải lưu trước/sau và xác nhận TP còn nguyên.
- Không ghi số tài khoản, mật khẩu, khóa hoặc token vào repo/báo cáo công khai.

### 16.2 Nội dung người dùng nhìn thấy

Ví dụ khi chưa vào:

```text
Trạng thái: Chờ phản ứng mới
Vùng: Hỗ trợ M15 [đáy, đỉnh]
Bối cảnh: D1 giảm; M1 đang tiếp cận hỗ trợ
Kịch bản: Mua nhịp bật ngắn, không phải đảo hướng ngày
Còn thiếu: Giá chưa lấy lại phía trên vùng
Hủy nếu: Phá qua mốc vô hiệu hoặc quá hạn
Hành động: Chưa gửi lệnh
```

Ví dụ khi đã vào phải hiện giá khớp thật, SL/TP, phần đã chốt/còn lại, tiền chịu lỗ, nhánh và điều kiện thoát.
Không hiện “đã hòa vốn” trước khi sửa dừng được sàn xác nhận; không hiện “an toàn” nếu chưa có phí hoặc đang mất kết nối.

## 17. Ma trận tình huống bắt buộc để nghiệm thu

Kiểm đối xứng mua/bán cho mọi ca có chiều. Mỗi ca phải có dữ liệu đầu vào, sự kiện theo thời gian, kết quả mong đợi và bằng chứng.

| Mã | Tình huống | Kết quả bắt buộc |
|---|---|---|
| AC01 | D1/H1 giảm, M1 phản ứng tăng tại hỗ trợ có căn cứ | S02 được xét; không bị cổng H1 loại máy móc |
| AC02 | D1 giảm, hồi lên kháng cự rồi giảm | S01 bán nếu đủ kế hoạch, không cần cả 9 EMA đồng thuận |
| AC03 | Chạm cản, không có phản ứng mới | Chỉ theo dõi, không có pending mù trên sàn |
| AC04 | Có phản ứng cũ, lần quay lại tăng xuyên kháng cự | Không bán theo phản ứng cũ; chuyển trạng thái phá |
| AC05 | Râu xuyên rồi lấy lại vùng | Không tự đổi D1/H4; xét S07 theo quy tắc |
| AC06 | Đóng phá rồi quay lại giữ được | S06 theo chiều mới, có thứ tự và vai trò cục bộ đúng |
| AC07 | Phá nhưng lần kiểm tra lại xuyên ngược | Hủy S06; không mở chiều cũ/new khi chưa có xác nhận mới |
| AC08 | Một M1 phá vùng H1, H1 chưa đóng | Lưu M1 break riêng, không đổi cấu trúc H1 trong quá khứ |
| AC09 | Giá phá mạnh, không hồi nhưng còn khoảng chạy | S05 được xét, không ép chờ limit |
| AC10 | Giá đã chạy quá xa sau xác nhận | Bỏ lần gửi; không tự hạ tiêu chuẩn hoặc dời TP xuyên cản |
| AC11 | Giá hồi nông rồi tiếp diễn | S03 được xét, không bắt về vùng lớn xa |
| AC12 | Đi ngang tại biên/giữa/phá biên | Chỉ xét S04 tại biên; khi phá đổi kịch bản |
| AC13 | Chỉ EMA50 M15 có phản ứng, EMA khác không | S08 được xét riêng, không đòi cả ba/cả ba khung |
| AC14 | EMA đang chạy khác EMA đã đóng | Chỉ dùng đường đã biết và giá trị đóng băng của episode |
| AC15 | Chưa đủ EMA200 nhưng hỗ trợ cấu trúc đủ | Tắt nhánh EMA200, không tắt mọi nhánh |
| AC16 | Chỉ P1 hoặc chỉ P2 đủ | Không bắt thêm P3/RSI/volume như cổng toàn cục |
| AC17 | M1/M5/các vùng chồng phát cùng cơ hội | Chỉ một yêu cầu mở, lưu được lý do chống trùng |
| AC18 | Hai chiều cùng đủ nhưng chưa phân định | Chờ xung đột, không gửi ngẫu nhiên/hai lệnh |
| AC19 | Vùng H4 rộng chứa giá | Không cấm tự động; xét nhịp con, cản và rủi ro có căn cứ |
| AC20 | Mức MSNR yếu nằm sát giá | Không tự biến thành cản cứng chặn mọi giao dịch |
| AC21 | Pivot chỉ được xác nhận sau N nến | Không có quyết định trước known_at |
| AC22 | Mất giá rồi nhận bù nhiều nến | Ghi đúng lúc nhận, không mở bù tín hiệu cũ |
| AC23 | Sang giờ mới H1 vừa đổi cấu trúc | Không chọn chiều bằng H1 cũ, không dùng vùng tương lai |
| AC24 | Tài khoản/thông số tiền chưa sẵn sàng | Không nhận phép tính tiền 0 giả là hợp lệ |
| AC25 | Khối lượng tính được nhỏ hơn lot tối thiểu | Bỏ; không làm tròn lên vượt ngân sách |
| AC26 | Giá khớp khác kế hoạch, SL/TP thiếu hoặc rủi ro vượt | Phát hiện, xử lý bảo vệ và ghi đủ kết quả |
| AC27 | Gửi thành công về mặt API nhưng chưa biết khớp | Khóa gửi lặp, đối soát bằng sàn |
| AC28 | Hai tick trùng mili giây/các sự kiện đảo thứ tự | Không giả định thứ tự không có bằng chứng; đánh dấu giới hạn |
| AC29 | Giá chạm dừng rồi đi đúng hướng | Ghi cả đường giá, không xóa lệnh thua hay tự nới luật |
| AC30 | Siết dừng khi có cấu trúc mới | Chỉ siết, không dùng pivot tương lai, TP còn nguyên |
| AC31 | Giá đi thuận đạt mốc bảo vệ | Dừng về giá vào nếu sàn cho phép; không nới dừng đang tốt hơn, giữ TP |
| AC32 | Phản ứng ngược trước mục tiêu | Từ chối tại cản kèm phá cấu trúc nhỏ; hồi nhẹ không đủ |
| AC33 | Tuổi lệnh cao nhưng chưa có lý do giá/an toàn | Không đóng theo phút; vẫn giữ dừng, mục tiêu và khóa an toàn |
| AC34 | Lệnh vừa đóng, tín hiệu cũ vẫn còn trên chart | Không vào lại cho tới sự kiện/episode mới |
| AC35 | Restart/mất mạng/đổi tài khoản | Nhận lại đúng vị thế, không mở trùng/đóng lệnh ngoài bot |
| AC36 | Giới hạn lỗ, nạp/rút tiền, đổi ngày/tuần | Ngân sách lưu đúng, không vô tình reset hoặc che lỗ |
| AC37 | Thiếu lịch tin hoặc nguồn OKX thay Exness | Hiện thiếu/khác nguồn; không bịa tin hoặc trộn giá để chấm |
| AC38 | Chỉ một nhánh đạt, các nhánh khác chưa đo | Chỉ nhánh đó có thể qua cấp kiểm tra; không bật chung cả hệ |
| AC39 | Giá đổi nhiều lần trong cùng một giây | Không bỏ xác nhận vì khóa một giây; ghi giới hạn dữ liệu nhận được |
| AC40 | Giá dồn dập, ghi báo cáo hoặc sàn trả lời chậm | Đo riêng tính toán/gửi/khớp, không gửi lại hoặc dùng tín hiệu hết hạn |
| AC41 | Tối ưu tính toán bằng lưu kết quả | Quyết định khớp bản chuẩn trên cùng dữ liệu; không dùng kết quả khung đã hết hiệu lực |

## 18. Đánh giá hiệu quả và cách tìm nguyên nhân lỗ

### 18.1 Hai cổng khác nhau

- **Cổng đúng kỹ thuật:** xử lý đúng tình huống, thời điểm, tiền và quyền gửi. Test xanh chỉ chứng minh phần này.
- **Cổng hiệu quả giao dịch:** lãi/lỗ sau chi phí, rủi ro, số cơ hội và ổn định trên dữ liệu không dùng để chỉnh luật.
  Đạt cổng kỹ thuật không có nghĩa đạt cổng hiệu quả.

### 18.2 Phải báo riêng từng nhánh và từng khung

Số lần tiếp cận → phản ứng → đủ kế hoạch → gửi → khớp → đóng. Ghi lý do loại ở từng bước.
Báo số lệnh/ngày, tỷ lệ thắng/hòa/thua, lãi/lỗ trung bình, tiền ròng, sụt vốn, chuỗi lỗ, thời gian giữ và phần phụ thuộc vài lệnh lớn.
Nhánh thuận/ngược D1, M1/M5, EMA từng khung/độ dài phải có thống kê riêng; không cộng các ô trùng thành số lệnh thực.

### 18.3 Khi lỗ, điều tra trước khi chỉnh

- Có phản ứng mới lúc vào hay đang dùng phản ứng cũ? Giá gửi/khớp có thành vào đuổi không?
- Nhóm mua/bán nào lỗ? Đảo cùng thời điểm có thật sự tốt hơn sau đúng phía giá/chi phí không?
- Dừng trước hay sau bảo vệ? Giá đi thuận/ngược bao nhiêu trước dừng? Sau dừng còn chạm mục tiêu không, phải chịu đi ngược thêm bao nhiêu?
- Nới dừng cứu bao nhiêu và làm bao nhiêu xấu hơn, ở cùng tiền chịu lỗ? Không chỉ nhìn số lệnh được cứu.
- Đóng sớm/siết dừng có tốt hơn giữ kế hoạch trên **cùng điểm vào** không? Phân biệt giảm lỗ với mất nhịp lời.
- Có lỗi thực thi, sai thời điểm dữ liệu, sai tính tiền hoặc phí chưa tính không?

Mọi đối chứng giả định phải ghi rõ phạm vi: đơn lệnh hay cả lịch bận/rảnh, cùng khối lượng hay cùng tiền chịu lỗ,
đã tính phí/trượt/độ trễ nào, và mẫu thiếu nào. Không dùng tổng các trường hợp chồng nhau làm lợi nhuận EA.

### 18.4 Không tự đánh lừa bằng dữ liệu cũ

- Khóa mã/tham số và giả thuyết trước mỗi lượt đo. Đổi một nhóm hành vi có lý do, không thay mọi ngưỡng cùng lúc.
- Lịch sử đã xem là dữ liệu khám phá. Không đổi tên đoạn cuối thành dữ liệu mới nếu đã dùng nó để chọn luật.
- Dữ liệu mới cần có mốc khóa trước thu/chấm, dấu mã băm và nguồn rõ. Tách dữ liệu thiếu/tick tự sinh nếu có.
- Cỡ mẫu, số ngày và tiêu chí chấp nhận phải khai báo trước đợt đánh giá; ít mẫu thì kết luận thiếu dữ liệu.
  Một số lượng lệnh cố định tự nó không chứng minh lợi thế. Không dùng tỷ lệ đi đúng chiều sau 5 phút thay tỷ lệ thắng có SL/TP.
- Chạy phí/độ trễ thực tế và các mức xấu hơn có lý do. Một nhánh chỉ dương khi giả định không có chi phí chưa đủ để bật.
- Không cam kết tỷ lệ thắng hoặc số lệnh/ngày trước khi có số đo. Không bắt bot giao dịch trong tình huống không có lợi thế đã kiểm chứng.

## 19. Trình tự triển khai cho agent/session tiếp theo

| Bước | Việc cần làm | Bằng chứng để qua bước |
|---|---|---|
| 1 | Chủ bot review kịch bản, mốc sai, khung và các thông số đề xuất | Ghi quyết định vào SPEC, không chỉ trong chat |
| 2 | Lập bản đồ yêu cầu → phần xử lý → ca kiểm tra | Mỗi yêu cầu có nơi thực hiện và bằng chứng nghiệm thu |
| 3 | Dữ liệu đúng thời điểm, bối cảnh đa khung, vùng và episode | AC08, AC14–15, AC21–24, AC28, AC37 |
| 4 | S01/S02 và luồng theo dõi → phản ứng mới → gửi; bỏ limit mù | AC01–04, AC10, AC16–18, AC25–27 |
| 5 | Phá/kiểm tra lại/đổi vai trò/phá thất bại S05–S07 | AC05–09, không đổi hướng lớn theo một M1 |
| 6 | Hồi nông/đi ngang/EMA S03/S04/S08, từng nhánh riêng | AC11–15, AC19–20, AC38 |
| 7 | Quản lý vị thế và khôi phục trạng thái | AC26–36; không mất bảo vệ/không gửi lặp |
| 8 | Đo từng nhánh rồi đo khi chạy chung bằng đúng EA | Báo cáo mục 18, gồm chi phí và lý do bỏ |
| 9 | Quan sát/demo sau khi được cho phép | Phí/trễ thực, lỗi thực thi, dữ liệu mới; vẫn không suy thành chắc có lời |

Các bước kiểm kỹ thuật và quản lý rủi ro có thể phát triển song song về mã, nhưng không bật thực thi khi phần bảo vệ chưa đạt.
Không viết lại toàn bộ chỉ để đổi tên, không tạo các lớp/thư mục chưa có chức năng. Dùng công cụ hiện có sau khi kiểm chúng còn phù hợp.

## 20. Giao thức bàn giao giữa các agent

Mỗi lần kết thúc một phần việc phải cập nhật HANDOFF với:

1. Phiên bản SPEC/tham số đang làm; nhánh nào mới nghiên cứu, đã code, đã kiểm kỹ thuật, đã đo hay đã được phép chạy.
2. File thực sự đổi, lệnh kiểm đã chạy và kết quả; không biến “dự định” thành “đã làm”.
3. Kết quả đo tiền/số lệnh và giới hạn dữ liệu; đường dẫn báo cáo, không kèm bí mật/tài khoản.
4. Những quyết định người dùng vừa chốt; những câu còn mở; bước kế tiếp cụ thể.
5. Bot có đang bật không, trên môi trường nào; tác vụ nền nào còn chạy; không đụng process/dịch vụ của dự án khác.

Không dùng trí nhớ hội thoại, nhận định của agent trước, một triển khai khác hoặc một bài chỉ báo bên ngoài làm nguồn luật cao hơn SPEC.
Nếu ý người dùng thay đổi thì sửa SPEC có lý do trước khi sửa hành vi. Tài liệu phải nói rõ chỗ chưa được review/định nghĩa.

## 21. Nguồn kỹ thuật và giới hạn khẳng định

- [MQL5: cấu trúc giá Bid/Ask và mili giây](https://www.mql5.com/en/docs/constants/structures/mqltick).
- [MQL5: sự kiện OnTick và hàng đợi xử lý](https://www.mql5.com/en/docs/event_handlers/ontick).
- [MQL5: OrderSend và kiểm tra kết quả](https://www.mql5.com/en/docs/trading/ordersend).
- [MQL5: lấy nến và giới hạn dữ liệu](https://www.mql5.com/en/docs/series/copyrates).
- [CME: hỗ trợ/kháng cự là vùng và có thể đổi vai trò](https://www.cmegroup.com/education/courses/technical-analysis/support-and-resistance).
- [CME: chọn mốc dừng và tính khối lượng theo tiền chịu lỗ](https://www.cmegroup.com/education/courses/trade-and-risk-management/proper-position-size).

Các nguồn trên hỗ trợ khái niệm/cơ chế kỹ thuật, **không chứng minh các ngưỡng hoặc các nhánh của bot này có lợi nhuận**.
Có thể lập trình các trạng thái, điều kiện và hành động này. Kết quả kinh tế và mức khớp với cách nhìn của chủ bot cần được review và kiểm chứng riêng.

## 22. Hướng 1.4 — cản khung lớn, vào ở M1/M5 (chủ bot chốt 29/09/2026)

**Trạng thái:** quyết định hướng; **chưa triển khai trong `BotScpMtf`**. Bot 1.3 giữ nguyên cho tới khi có số đo.
Nghiên cứu nền: `docs/research/13-entry-sl-tp-research.md`. Mọi số dưới đây là [THỬ NGHIỆM] nếu không ghi khác.

### 22.1 Quyết định của chủ bot [YÊU CẦU, chốt 29/09]

1. Cản tìm ở khung lớn: M15, M30, H1, H4, D1, W1, gồm vùng đỉnh/đáy, OB, FVG. M1/M5 chỉ dùng để tìm điểm vào.
2. Chỉ vào ở cản mạnh. Ngoại lệ "cản tạm": khi giá đang đi mạnh và chỉ hồi nông, được vào ở cản nhỏ M5 theo chiều đi mạnh.
3. Vào lệnh thị trường sau phản ứng; không treo lệnh chờ tại FVG/OB (giữ mục 1.2 và 9.3).
4. Phản ứng đủ để vào: giá chạm cản → không có nến M5 đóng vượt mép xa của cản (không phá trong một nhịp)
   → trên M1 hoặc M5 có **một trong**: rút râu (P1), nhấn chìm (P2), phá đỉnh/đáy nhỏ của nhịp đi vào (P3).
5. Né tin.
6. Khối lượng theo độ lớn cản, **không vượt 0,25% vốn mỗi lệnh**: M15/M30 0,10%; H1 0,15%; H4 0,20%;
   D1/W1 hoặc nhiều cản trùng nhau 0,25%. Các mức % là [THỬ NGHIỆM].
7. Chốt hai phần: phần đầu ở đích gần, phần còn lại tới cản khung lớn kế tiếp; chốt phần đầu xong thì dời dừng về giá vào.
   Mức đích gần chọn bằng số đo trên 01–06/2026 (1R, 1,5R hoặc cản M5 gần nhất), khóa trước khi kiểm 07–09/2026.
8. Làm công cụ đo tín hiệu trước khi đổi cách vào của bot. Dữ liệu tìm luật 01–06/2026, dữ liệu kiểm 07–09/2026.

### 22.2 Định nghĩa đo [ĐỀ XUẤT, THỬ NGHIỆM]

- Loại cản: vùng đỉnh/đáy, OB, FVG (hình học mục 14.3) của M15, M30, H1, H4, D1, W1; đỉnh/đáy ngày trước (dùng trong ngày kế tiếp);
  đỉnh/đáy tuần trước (dùng trong tuần kế tiếp); số tròn $10/$50/$100. Cản khung nguồn hết hiệu lực khi nến của chính khung đó
  đóng vượt mép xa thêm `eps_geom` của khung đó, hoặc quá 200 nến nguồn.
- Cản tạm M5: vùng đỉnh/đáy M5, chỉ xét khi hướng cấu trúc M5 cùng chiều lệnh và nhịp hồi hiện tại không quá 50% nhịp đẩy trước
  (từ pivot ngược gần nhất tới cực trị cuối).
- Bậc cản: M5 tạm, M15, M30, số tròn $10 → 0,10%; H1, số tròn $50, đỉnh/đáy ngày trước → 0,15%; H4, số tròn $100,
  đỉnh/đáy tuần trước → 0,20%; D1, W1 hoặc ≥2 cản khác khung/loại trùng nhau tại lúc chạm → 0,25%.
  Cách xếp số tròn và mốc ngày/tuần vào bậc là đề xuất của Claude, cần chủ bot duyệt.
- Chạm: Bid đi vào `[bottom−eps, top+eps]` từ phía hợp lệ; `eps=max(2 tick, 0,10·ATR14 khung vào)`. Tiếp cận từ trên là hỗ trợ (mua),
  từ dưới là kháng cự (bán). Mở lại lần chạm mới cần một nến khung vào đã đóng hoàn toàn ngoài dải.
- Phá trong một nhịp: sau chạm, có nến M5 đóng vượt mép xa thêm `eps` → hủy lần chạm.
- Phản ứng: trong tối đa 3 nến khung vào kể từ nến chạm. P1/P2 dùng công thức mục 14.4 nhưng **không bắt đóng vượt mép gần**
  (cản khung lớn có thể rộng); ghi riêng cờ "đạt cả điều kiện đóng vượt mép gần" để so. P3: đóng vượt đỉnh/đáy nhỏ khung vào đã khóa
  lúc chạm (20 nến trước chạm) thêm `eps`.
- Vào: giá thị trường ở báo giá đầu tiên sau nến phản ứng đóng, trong 2 giây; bỏ nếu Bid đã chạy quá 0,25·ATR khung vào.
- Dừng: ngoài cực trị lần chạm cộng `max(eps, spread)`; lệnh bán cộng thêm spread (mục 14.6). Không nới để giảm tỷ lệ chi phí;
  tín hiệu có (spread + 2·trượt)/R > 5% được đánh dấu để đo riêng.
- Đích khung lớn: mép gần của cản bậc M15 trở lên phía trước, trừ đệm. Đích gần: 1R, 1,5R, cản M5 gần nhất; đo song song.

### 22.3 Công cụ đo tín hiệu (`ScpSignalLab.mq5`) — hợp đồng

- Chỉ chạy trong máy thử; không có hàm gửi lệnh. Mỗi tín hiệu và đối chứng được theo dõi trên từng tick thật tối đa 24 giờ.
- Kết quả theo R sau spread (mua thoát Bid, bán thoát Ask), thêm cột trừ đệm trượt đã khai báo:
  đua dừng/chốt ở 1R, 1,5R, 2R, 3R, tới đích khung lớn; chốt hai phần (đích gần + đích khung lớn, dừng về giá vào sau phần đầu);
  quãng đi thuận/ngược lớn nhất sau 1, 5, 15, 60, 240 phút.
- Đối chứng: đánh ngược cùng lúc; vào ngẫu nhiên cùng giờ trong ngày 1–10 ngày sau (3 lần); cản giả cùng khung/loại/bề rộng
  đặt lệch ngẫu nhiên 1–3 lần max(bề rộng, ATR khung nguồn), đi qua đúng cùng quy trình. Hạt giống ngẫu nhiên là tham số, ghi vào báo cáo.
- Báo cáo: tỷ lệ thắng, R trung bình, khoảng tin cậy 95%, hiệu thật − đối chứng, theo khung cản, loại cản, bậc, kiểu phản ứng,
  khung vào, giờ, gần/xa tin, chi phí cao/thấp. Tín hiệu gần tin được ghi nhưng loại khỏi số chính.
- Kết quả là số đo tín hiệu trên giấy, chồng lấn nhau, không phải tiền của một EA chạy một lệnh mỗi lúc.

### 22.4 Mốc râu, Doji SnR và DOL (chủ bot bổ sung 29/09, kèm ảnh GOLD H1)

- **[ĐỀ XUẤT của chủ bot, cần đo — chưa chốt]** Cản đỉnh/đáy (khung M15, M30, H1, H4…) chưa từng bị phá: mốc chạm là **đỉnh râu** (kháng cự) hoặc **đáy râu** (hỗ trợ)
  của nến tạo đỉnh/đáy. Lần kiểm tra thứ 2 trở đi: mốc là **giữa râu** hoặc đỉnh/đáy râu — chủ bot chưa chắc cách nào tốt,
  yêu cầu **đo cả hai**. Giữa râu = (mép thân + đỉnh/đáy râu)/2 của nến tạo cản. "Bị phá" = nến của chính khung nguồn đóng vượt
  đỉnh/đáy râu thêm `eps_geom` (râu xuyên không tính là phá, theo `docs/research/01-rare-snr.md` mục 2.6).
- **[YÊU CẦU]** Vẫn chờ phản ứng M1/M5 rồi vào thị trường. **[ĐỀ XUẤT của chủ bot, cần đo]** Dừng lỗ sau đỉnh/đáy râu của cản: mua `min(đáy râu, cực trị đã thấy) − đệm`,
  bán `max(đỉnh râu, cực trị đã thấy) + đệm + spread`.
- **[ĐỀ XUẤT, chủ bot giao Claude tra cứu]** Doji SnR theo "Rare SnR" (`docs/research/01-rare-snr.md` mục 2.4), khớp ảnh chủ bot:
  nến động lực c1 → 1–2 nến doji/thân nhỏ → nến động lực c3 cùng chiều đóng vượt qua cụm doji. Giảm: mốc kháng cự = giá mở c3
  (≈ thân doji ≈ đóng c1); tăng: mốc hỗ trợ đối xứng. Vùng cản = [mốc, đỉnh râu cao nhất của cụm doji] (giảm), đối xứng khi tăng;
  dừng lỗ sau râu đó. Ngưỡng [THỬ NGHIỆM] vì tài liệu không cho số: doji/thân nhỏ = thân ≤ 0,3·ATR14 và ≤ 50% biên độ nến;
  nến động lực = thân ≥ 0,6·ATR14 cùng chiều. Xét trên M15, M30, H1, H4, D1, W1.
- **[ĐỀ XUẤT từ ảnh]** DOL (đích thanh khoản): đỉnh/đáy râu gần nhất phía trước của cản đỉnh/đáy M15 trở lên **chưa bị giá quét qua**
  (chưa có giá đi vượt râu đó từ lúc tạo). Đo như một đích phần sau của chốt hai phần, song song với "cản khung lớn kế tiếp".

## 23. HTF-ZONE 2.0 — bot mới theo 4 tài liệu cản (chủ bot chốt hướng 29/09/2026)

**Trạng thái:** thiết kế đã duyệt hướng, **chưa có mã**. Nguồn: `docs/research/01`, `02`, `03`, `14`, `15`.
Mục này thay phần chọn cản/điểm vào của bot 1.3 (mục 5–8) khi được triển khai; phần an toàn, gửi lệnh, khôi phục (mục 9.5, 11–12, 14.8–14.10)
giữ nguyên. Mọi số là [THỬ NGHIỆM] trừ khi ghi khác. Chỗ tài liệu không có luật được ghi "cần đo".

### 23.1 Quyết định chủ bot [YÊU CẦU, chốt 29/09]

- Kịch bản: K1 đảo chiều ở cản mới; K2 phá rồi quay lại cản đã đổi vai; K3 Unicorn; K4 đường xu hướng chạm lần 3; K5 tiếp diễn (411).
- **Chỉ vào lệnh thị trường sau phản ứng M1/M5**; không lệnh chờ (giữ mục 1.2, 9.3). Tài liệu dùng lệnh chờ tại mức — không áp dụng.
- Cản tìm ở M15, M30, H1, H4, D1, W1; M1/M5 chỉ để vào lệnh (mục 22.1).
- Trình tự: SPEC → công cụ đo → chủ bot chạy máy thử 01–06/2026 → chốt tối đa 3 tổ hợp → kiểm một lần 07–09/2026 → EA chỉ bật tổ hợp đạt.

### 23.2 Loại cản (khung nguồn M15–W1; pivot N theo mục 13, M30 như M15, W1 như D1)

| Mã | Loại | Định nghĩa | Vùng [dưới, trên] | Nguồn |
|---|---|---|---|---|
| L1 | Đỉnh/đáy râu | Pivot xác nhận | Kháng cự `[max(O,C), H]`, hỗ trợ `[L, min(O,C)]` | Mục 14.3, ảnh chủ bot |
| L2 | Classic A/V | A: c1 tăng, c2 giảm; V: c1 giảm, c2 tăng; mức `C(c1)`. **Đề xuất lọc**: chỉ khi c1 hoặc c2 là nến pivot (tài liệu nhận mọi cặp → quá nhiều mức) | A: `[C(c1), max(H(c1),H(c2))]`; V: `[min(L(c1),L(c2)), C(c1)]` | Rare SnR R2–R3, 7.2h |
| L3 | Gap SnR | c1, c2 cùng màu; mức `C(c1)`. **Đề xuất lọc**: ít nhất một nến thân ≥ 0,6·ATR | Giảm `[L(c1), H(c2)]`; tăng `[L(c2), H(c1)]` | Rare SnR R4–R7 |
| L4 | Doji SnR | Mục 22.4 | Mục 22.4 | Rare SnR R9–R11 |
| L5 | Vùng Z (411) | Mô hình M/W: A, đỉnh 1, B (`B>A` khi bán), đỉnh 2; Z = nến đầu tiên từ đỉnh 2 có `L(Z)<L(Z−1)`; có hiệu lực khi giá phá B rồi A | `[L(Z), H(Z)]` (cả râu) | 411 phần 1 mục 3–4 |
| L6 | OB, FVG, breaker | Mục 14.3; breaker xem K3 | — | Mục 14.3, Unicorn |
| T | Đích | DOL (mục 22.4), đỉnh/đáy ngày-tuần trước, số tròn, cản mới đối diện | — | Mục 22 |

- **Mốc chạm** (L1, L4): thân / giữa râu / đầu râu — đo cả ba (mục 22.4). L2, L3, L5, L6: mép gần của vùng.
- **Trạng thái cản**: mới (chưa chạm) → đã chạm n lần → **bị phá** → **đổi vai** (mới ở phía kia) → hết hạn (200 nến nguồn).
  "Bị phá" đo hai định nghĩa: (a) **thân nến khung nguồn đóng qua mép xa** (Rare SnR); (b) **râu vượt mép xa** (411). Mặc định dùng (a); (b) để so.
  **[ĐỀ XUẤT, sửa 29/09 sau lượt máy thử đầu]** Mỗi cản gốc khung M15 trở lên chỉ đổi vai **một lần**; bản đổi vai giữ tuổi của cản gốc
  (hết hạn cùng lúc). Cản tạm M5 không đổi vai. Lý do: giá dao động qua lại quanh một cản làm nó đổi vai mãi và không bao giờ hết hạn
  (một tuần đo có 143.572 lần "bị phá" với ~4.500 cản thật).
- Cản được biết lúc nến xác nhận cuối đóng; không dùng trước lúc đó.

### 23.3 Kịch bản

**K1 — Đảo chiều ở cản mới.** Cản L1–L4, L6 chưa bị phá; giá tiếp cận từ phía đúng vai; đo lần chạm 1, 2, 3+ riêng.
Không có nến M5 đóng qua mép xa (không phá trong một nhịp) → phản ứng M1/M5 → vào thị trường.

**K2 — Phá rồi quay lại.** (a) Cản L1–L4 bị phá theo 23.2 và đổi vai; (b) vùng Z của 411 sau khi phá B rồi A.
Chỉ lần quay lại **đầu tiên** sau khi phá (fresh). Phản ứng M1/M5 theo vai mới → vào thị trường.

**K3 — Unicorn.** Trên M5 và M15 (tài liệu dùng 5 phút):
1. DOL = hai đỉnh (hoặc hai đáy) pivot chênh ≤ `tol` (cần đo; thử 0,1·ATR) chưa bị quét; DOL ở trên → chỉ mua, ở dưới → chỉ bán.
2. Nhịp thao túng: giá đi ngược DOL, quét một đáy pivot cũ (mua) / đỉnh pivot cũ (bán).
3. Breaker: nhóm nến xanh cuối trước đáy mới (mua), đỏ cuối trước đỉnh mới (bán); vùng `[L, H]` cả râu. Xác nhận khi nến đóng qua mép xa breaker.
4. FVG trong nhịp đẩy sau quét; vùng Unicorn = giao breaker ∩ FVG; không giao thì không có setup.
5. Giá quay lại chạm mép gần vùng → phản ứng M1 → vào thị trường. Dừng lỗ: đo (a) thân nến thấp/cao nhất nhịp thao túng (tài liệu), (b) đầu râu nhịp thao túng.
   Đích: DOL; bỏ nếu < 2R (tài liệu). Hết hạn: cần đo (thử 24 nến khung nguồn).

**K4 — Đường xu hướng chạm lần 3 (411 phần 2).** Điểm neo = giá đóng: kháng cự ở nến tăng có nến sau giảm; hỗ trợ ở nến giảm có nến sau tăng,
tại pivot giá đóng của khung nguồn. Đường qua 2 neo cùng loại gần nhất theo chỉ số nến: `L(t)=P1+(P2−P1)(t−t1)/(t2−t1)`.
Lần chạm thứ 3 (tính cả 2 neo) khi giá tới đường ± `tol` (cần đo) → phản ứng M1/M5 → vào thị trường. Chỉ kiểu cơ bản trước;
các kiểu 1/2/3/QM/666 và Boom Point để sau khi có số đo. Đường hết hiệu lực khi thân nến khung nguồn đóng qua đường.

**K5 — Tiếp diễn (411 tr.10).** Sau một K2 đã phát theo chiều d: giá tạo cực trị mới C, hồi, tạo cực trị D, rồi phá D và C.
LEVEL 2 = C. Lần quay lại đầu tới LEVEL 2 → phản ứng M1/M5 → vào thị trường theo chiều d.

### 23.4 Vào lệnh, dừng lỗ, chốt lời, khối lượng

- Vào: phản ứng P1/P2/P3 trên M1 hoặc M5 (mục 22.2), thị trường trong 2 giây, bỏ nếu đã chạy > 0,25·ATR khung vào.
- Dừng lỗ: sau mép xa vùng (đầu râu, UL/LL, đỉnh hộp doji, cực trị đã thấy) + đệm {0; 0,3; 0,5}·ATR M5 + spread với lệnh bán. Đo cả ba.
- Chốt lời hai phần (mục 22.1 mục 7): phần đầu {1R; 1,5R; cản M5}; phần sau {DOL; cản mới đối diện khung lớn; 5R (Rare SnR tr.13)};
  sau phần đầu dời dừng về giá vào. Bỏ lệnh khi đích gần hơn 1R sau chi phí.
  Đích "cản khung lớn": mép gần của cản M15 trở lên đầu tiên cách giá vào ≥ 1R sau đệm; cản gần hơn (kể cả cản chồng lên vùng vào)
  bỏ qua, lấy cản kế tiếp (chủ bot đồng ý 29/09 sau lượt 1 tuần: cản gần nhất phía trước chỉ cách trung vị 0,03R, 0,6% lệnh có đích ≥ 1R).
  Đích DOL cùng luật: đỉnh/đáy râu chưa bị quét đầu tiên cách giá vào ≥ 1R (chủ bot đồng ý 29/09; DOL gần nhất trung vị 0,41R, 28% lệnh ≥ 1R).
- Khối lượng theo bậc cản trong trần 0,25% (mục 22.2). Né tin ±5 phút (đo thêm ±30). Mặc định chỉ quan sát; tiền thật bị chặn.

### 23.5 Đo và nghiệm thu

- Công cụ đo `ScpSignalLab` (mục 22.3) đo K1–K5 × mốc × dừng lỗ × chốt lời, so với vào ngẫu nhiên cùng giờ, đánh ngược và cản giả.
- Làm theo đợt: đợt 1 = sổ cản L1–L4, L6, DOL + K1, K2(a), K5; đợt 2 = L5 + K2(b), K3; đợt 3 = K4.
- Một tổ hợp chỉ được đưa vào EA khi trên 01–06/2026: R trung bình sau chi phí > 0 và hơn cả vào ngẫu nhiên lẫn cản giả,
  khoảng tin cậy 95% không chứa 0; rồi kiểm một lần trên 07–09/2026 vẫn > 0. Không chỉnh luật sau khi xem 07–09.

### 23.6 Đợt 2 đã có trong công cụ đo (29/09, chưa có số liệu)

- **L5/K2b vùng Z (411):** khung nguồn M15–D1. Khi một đỉnh (bán) / đáy (mua) vừa xác nhận là đỉnh 2 / đáy 2: lấy B = đáy (đỉnh) cuối trước nó,
  đỉnh 1 = đỉnh (đáy) cuối trước B, A = đáy (đỉnh) cuối trước đỉnh 1; bán cần `B > A`, mua cần `B < A`.
  Z = nến đầu tiên từ nến trước đỉnh 2 có `L < L` nến trước (mua: `H > H` nến trước); vùng `[L(Z), H(Z)]`, vai kháng cự (mua: hỗ trợ).
  Vùng chỉ dùng được sau khi giá phá B rồi A (râu cũng tính), tính từ lúc nến phá A đóng; thân nến đóng qua mép xa trước đó thì vùng hủy.
  Hết tuổi 200 nến, không đổi vai. Chưa lọc HSL, chưa bắt mẫu nhấn chìm (cần đo).
- **K3 Unicorn:** khung nguồn M5 và M15. Đáy (mua) / đỉnh (bán) X vừa xác nhận thấp hơn đáy (cao hơn đỉnh) liền trước = nhánh thao túng;
  G = đỉnh (đáy) ngay trước X; breaker = nến tăng (mua) / giảm (bán) cuối cùng từ G tới X, vùng `[L, H]`.
  Cần DOL: hai đỉnh (mua) / đáy (bán) chênh ≤ 0,1·ATR nguồn, phía trước giá, chưa bị giá vượt, trong 200 nến; lấy nhóm gần nhất.
  Trong 24 nến nguồn: có nến đóng qua mép xa breaker và có FVG 3 nến (nến giữa cùng chiều) từ X trở đi chồng lên breaker.
  Vùng Unicorn = hợp breaker ∪ FVG; biết lúc nến sau cùng trong hai điều kiện đóng; hết tuổi 24 nến, không đổi vai.
  Dừng lỗ đo 3 cách: thân cực trị nhánh thao túng (tài liệu), râu cực trị, râu + 0,3·ATR M5. Đích = DOL của mô hình; bỏ nếu < 2R.
  Chưa đo: đích 2 STDV, breaker là nhóm nến, phiên New York.
- Cả hai đi qua cùng quy trình chạm → phản ứng M1/M5 → vào thị trường như K1/K2; báo cáo tên `K2b`, `K3` (không tách định nghĩa phá).

## 24. Sức mạnh cản và phản ứng tại cản (chủ bot duyệt 29/09/2026)

**Trạng thái:** đã có trong công cụ đo `ScpSignalLab`; **chưa có số liệu**. Lý do: lượt 1 tuần (05–12/01/2026) cho thấy tín hiệu ở cản thật
≈ vào ngẫu nhiên ≈ cản giả; sổ cản nhận mọi đỉnh/đáy, mọi cặp gap… mà không phân biệt cản mạnh/yếu (~4.500 cản mới/tuần).
Chủ bot chọn 4 tiêu chí; ngưỡng lấy từ 4 tài liệu khi có, còn lại [THỬ NGHIỆM] và báo cáo chia nhóm để đo. Chưa dùng làm bộ lọc.

### 24.1 Đặc điểm sức mạnh của mỗi cản

| Tiêu chí | Cách tính | Nhóm báo cáo | Nguồn |
|---|---|---|---|
| Lực bật | Quãng giá rời mép gần xa nhất trong 5 nến nguồn sau nến gốc, chia ATR nguồn lúc tạo | <1, 1–2, 2–3, ≥3 ATR | Rare SnR tr.7, 10, 21 (nến động lực); Unicorn (dịch chuyển mạnh) |
| Thân động lực | Thân lớn nhất theo chiều rời cản, từ nến gốc tới hết 5 nến sau; chỉ nến thân ≥ 60% biên độ; chia ATR nguồn | <1, 1–1,5, ≥1,5 ATR | Rare SnR "thân dài" (không có ngưỡng) |
| Phá cấu trúc | Hai đỉnh (với hỗ trợ) / đáy (với kháng cự) gần nhất trước nến gốc, nằm phía rời cản; đếm số mức bị giá đóng vượt trong 20 nến sau gốc và trước lần chạm đầu | 0, 1, 2 | 411 phần 1 (phá B rồi A); Unicorn |
| Cản trùng | Số cản khác khung/loại (M15 trở lên) có dải chồng lên lúc chạm | 0, 1, 2, 3+ | Rare SnR tr.20; Unicorn (breaker ∩ FVG) |
| Độ lớn đỉnh/đáy | Số nến bên trái trước khi có đáy thấp hơn mép xa (hỗ trợ) / đỉnh cao hơn (kháng cự), tối đa 500 | <10, 10–50, 50–200, ≥200 | Vị trí: đỉnh/đáy lớn hay đỉnh/đáy vặt |
| Độ mới | Lần chạm thứ mấy | 1, 2, 3+ | Rare SnR tr.4, 8–9; 411 tr.5 |
| Nến phá (bản đổi vai) | Thân nến phá theo chiều phá, cách tính như thân động lực | như thân động lực | Rare SnR tr.3–7 (nến động lực lật mức) |

- Không nhìn trước: chỉ dùng nến đã đóng tới lúc chạm; lực bật và phá cấu trúc cập nhật dần sau khi cản được biết.
- Số tròn, đỉnh/đáy ngày-tuần trước: không áp dụng. Bản đổi vai giữ đặc điểm của cản gốc và thêm nến phá.
- Cản giả chép đặc điểm của cản thật gốc: so cùng đặc điểm, khác vị trí giá.
- Không có điểm tổng hay trọng số (tài liệu không có); chọn tiêu chí sau khi đo.

### 24.2 Gộp tín hiệu ở cản chồng nhau

- Giữ từng cản như cũ (mép vùng, dừng lỗ không đổi).
- Các tín hiệu vào thị trường phát ở cùng nến phản ứng, cùng chiều, khung vào, kiểu mốc, cùng lớp thật/giả, có dải chồng nhau (± đệm)
  chỉ giữ một: bậc cản cao hơn → lần chạm sớm hơn → lực bật lớn hơn. Ghi số tín hiệu đã gộp. Lệnh chờ trên giấy không gộp.

### 24.3 Đo phản ứng tại cản (không phụ thuộc cách vào lệnh)

- Mỗi lần chạm mới của một cản: theo dõi giá bật xa nhất khỏi mép gần theo chiều cản; kết thúc khi nến M5 đóng qua mép xa + đệm (bị phá)
  hoặc sau 240 phút. Nến M1 lúc chạm tính theo tick (bỏ phần giá trước lúc chạm), sau đó theo đỉnh/đáy nến M1.
- Báo cáo `phan_ung_can.csv` theo từng đặc điểm ở 24.1 và theo nhóm/loại cản: % lần chạm bật ≥ 1/2/4 ATR M5 trước khi bị phá, % bị phá,
  quãng bật trung bình; so với cản giả cùng đặc điểm.
- Một tiêu chí được coi là "tạo ra cản mạnh" khi trên 01–06/2026 nhóm mạnh bật ≥ 2 ATR M5 nhiều hơn rõ nhóm yếu **và** hơn cản giả cùng nhóm,
  với đủ mẫu. Chỉ khi đó mới dùng làm bộ lọc cho K1/K2, và vẫn phải qua nghiệm thu mục 23.5.

### 24.4 Sửa lỗi tuổi cản (29/09)

- Tuổi 200 nến (mục 23.2) tính theo số nến nguồn đã nhận, tăng mãi. Trước khi sửa, tuổi tính theo số nến chuỗi còn giữ (tối đa 1.500):
  khi chuỗi đầy, cản M5/M15/M30/H1 tạo sau đó không bao giờ hết tuổi, chỉ chết khi bị phá, nên sổ cản dày dần theo thời gian.

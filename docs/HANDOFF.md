# Bàn giao — Bot scalping theo phản ứng giá

Cập nhật 28/09/2026. Nguồn luật: `docs/SPEC.md`; nền tảng MQL5 đã được chủ bot chốt.

## Cập nhật 29/09 — nghiên cứu điểm vào/SL/TP (Claude)

Chỉ nghiên cứu, chưa sửa mã/SPEC. Tổng hợp tại `docs/research/13-entry-sl-tp-research.md`.
Chủ bot định hướng: tìm cản ở khung lớn (M15, M30, H1, H4, D1, W1), M1/M5 chỉ để tìm điểm vào; né tin;
làm công cụ đo tín hiệu (so ngẫu nhiên/đánh ngược/mức giá ngẫu nhiên) trước khi đổi cách vào.

Sau đó (29/09): đọc lại từng trang 4 tài liệu của chủ bot (`docs/research/01`, `02`, `03`, `14`), tổng hợp ở `15`.
Chủ bot duyệt hướng **HTF-ZONE 2.0** (SPEC mục 23): K1 đảo chiều ở cản mới, K2 phá rồi quay lại, K3 Unicorn, K4 đường xu hướng lần 3,
K5 tiếp diễn; **chỉ vào thị trường sau phản ứng M1/M5**; đo trước, EA sau.
- Đã có công cụ đo đợt 1 `ScpSignalLab.mq5` (+ `SigLevels`, `SigDetect`, `SigTrack`, `SigReport`, `SigDraw`) và ca kiểm `SigVerify.mq5`.
  Biên dịch 0 lỗi/0 cảnh báo (MetaEditor build 6231 qua Wine trên máy cloud); `SigVerify` 37/37 đạt trên MT5 cloud (gồm lệnh chờ trên giấy để so sánh).
  **Chưa chạy máy thử với tick thật** (máy cloud không đăng nhập được sàn) → chủ bot chạy theo `scripts/TOOLS.md`.
- Chưa làm: đợt 2 (vùng Z của 411, K3 Unicorn), đợt 3 (K4 đường xu hướng).
- Phát hiện chưa sửa: `ScpNewsGuard` (bot 1.3) chỉ nạp tối đa 256 tin; lịch 12/2025–10/2026 có thể vượt → tin cuối kỳ bị bỏ.
  Công cụ đo dùng bộ đọc riêng không giới hạn.
- Bot 1.3 (`BotScpMtf`) giữ nguyên, vẫn biên dịch sạch.
- Lượt máy thử đầu (chủ bot, máy `tandat`, 05–12/01/2026): **không có tick thật** ("no real ticks, every tick generation used")
  → kết quả không dùng. Lộ lỗi cản đổi vai mãi khi giá dao động (143.572 lần bị phá/tuần, 28.847 tín hiệu, chạy 39 phút);
  đã sửa: mỗi cản đổi vai một lần, giữ tuổi cản gốc (SPEC 23.2), có ca kiểm tái hiện.

## Cập nhật 28/09 tối — bản `SCP-MTF-1.3-review-fixes` (Claude)

Chủ bot duyệt sửa sau review; luật đã ghi ở SPEC (đầu file, mục 6.3, 8 S01, 11.2, 11.2a, 11.3, 13, 14.2, 14.7, 14.10).
Chưa commit/push; không bật demo/thật. Các mục "Trạng thái/Bằng chứng" bên dưới là của bản 1.1, giữ làm lịch sử.

Đã sửa (công tắc trong EA để so trước/sau):
- Thoát vì mốc vô hiệu chỉ khi nến M1 đóng qua mốc (trước: chạm là đóng, vô hiệu hóa đệm dừng).
- S01 nhận nhịp hồi thuận hướng lớn (D1/H4) dù M1 đang ngược.
- Kế hoạch bị loại chỉ khóa đúng nến phản ứng, không khóa cả lần chạm.
- `InpUseM1MinorZones=false`: chỉ OB M1 và vùng M5+ mở lần theo dõi. `InpM1TargetNeedsReaction=true`: vùng M1 chưa có phản ứng không làm cản mục tiêu.
- `InpBreakevenR=1`: bảo vệ giá vào ở max(2,5 giá, 1R). `InpTrailAfterR=1`: siết theo cấu trúc sau 1R. `InpSlipPerLeg=0.5` (giả định, chưa đo).
- Bảng vùng 768→2048, theo dõi 1536→4096, có đếm vùng/theo dõi bị bỏ. Tra theo mã bằng bảng băm (luôn kiểm lại id).
- Bộ đếm "đã đóng" tính cả dừng/chốt do sàn khớp.

Kiểm: build 4 mục 0 lỗi/0 cảnh báo; ScpVerify 122/122 (RF01–RF08 mới); ScpExecVerify 20/20; ScpPriceManageVerify 9/9.

Đo máy thử XAUUSDm M1, tick thật, phí 0, 03/08–20/08/2026, gửi tất cả nhánh (hồ sơ `lab/scp_aug_base.set`, `lab/scp_aug_v13.set`):

| | 1.2 (mốc) | 1.3 |
|---|---|---|
| Lệnh | 44 | 162 (~11/ngày) |
| Thắng/thua/hòa | 5/38/1 | 48/111/3 |
| Tổng | −228 USD | **−406 USD** |
| Lời TB / lỗ TB | +28,3 / −9,7 | +24,8 / −14,4 |
| Đối chứng 1R (điểm vào vs đánh ngược) | −0,134R vs −0,100R | −0,072R vs −0,151R |

Theo nhánh bản 1.3: S08 +114 (13), S05 +86 (19), S01 +6 (21), S02 −51 (8), S06 −148 (32), **S07 −409 (67)**.
03/08–14/08 là −26; 16/08–20/08 là −381, chạm giới hạn lỗ ngày 20/08. Tháng 8 nay là dữ liệu khám phá, không dùng để nghiệm thu.
Lượt 1.2 bị treo 19:33 rồi bị đóng 21:15 (dừng ở 21/08, không có tong_ket); so sánh chỉ dùng phần trước 21/08.
Tốc độ: 1.3 p50 0,14 ms lúc đầu, tăng dần tới ~0,4–0,8 ms (WatchZones vẫn duyệt toàn bộ vùng mỗi tick) — cần sửa tiếp.

Điều tra nguyên nhân (6 góc, mỗi kết luận 2 người phản biện tính lại độc lập; 24/24 đứng vững; dữ liệu tháng 8, trong mẫu):
- Thắng ít là do hình học: TP trung vị 3,46R vì luật RR≥1,5 cộng dự phòng trượt 1,0 giá/lệnh (tester thực tế ~0,05–0,07).
  Vào ngẫu nhiên cùng SL/TP cũng chỉ thắng ~20%. Cần 36,3% để hòa; bot 29,6% (nhờ quản lý lệnh).
- Gốc lỗ: điểm vào tại cản ≈ ngẫu nhiên. 3.114 đề nghị, đua 1R:1R: bot 46,5%, ngẫu nhiên ~44,6%, ngược 42,5%. Hơn ~2 điểm < spread.
  Spread ≈ 10% khoảng dừng (dừng ~1,08 ATR M1 = 2,6 giá). Chi phí (spread+trượt) ≈ 310/406 USD lỗ.
- Luật "phải có cản xa làm đích" nghiêng lệnh về ngược đà trong ngày (75% kế hoạch; 59% lệnh bán trong tháng vàng tăng).
- S07 âm ở mọi mẫu; 33 lệnh S07 vào lại cùng chiều trong 3 giờ sau lệnh S06/S07 thua: −366 USD. S06 lỗ ở ngày chạy mạnh.
- Không giúp: nới SL (1,5x/2x), chờ thêm 1 nến, vào ở hồi 50%, dời SL tại 1R, chỉ thuận hướng lớn, đổi mức chốt.
  Không thấy "quét dừng" nhiều hơn ngẫu nhiên. S05/S08 đẹp trên 32 lệnh nhưng ngang ngẫu nhiên trên mẫu đề nghị.
- Kết luận: chưa có cách sửa triệt để trên dữ liệu hiện có. Cần tín hiệu chọn hướng thắng ≥~53–55% ở 1R:1R sau spread,
  kiểm trên tháng chưa dùng. Script điều tra: scratchpad phiên Claude (không đưa vào repo).

Nghiên cứu phương pháp ngoài bot (28/09 đêm, nến M1 Bid 01–09/2026; tìm luật 01–06, kiểm 07–09; scratchpad phiên Claude `strat\`):
- 5 họ (phá biên, hồi quy trung bình, hồi theo xu hướng, theo giờ/phiên, mẫu nến), 328 biến thể, 15 ứng viên.
  **0/15 qua cả kiểm tra tháng 7–9 lẫn phản biện.** Trung bình ứng viên +2,07 USD/lệnh (0,01 lot) lúc tìm → −0,25 lúc kiểm.
- Giải phẫu thị trường: hướng không đoán được từ nến (|tự tương quan| ≤ 0,03 từ 1 phút tới 4 giờ; phá/quét đỉnh đáy M1–M30
  ≈ 50/50; độ dài sóng = bước ngẫu nhiên). Biên độ đoán được. Spread ≈ 11–13% ATR M1, 5–6% ATR M5, 3% ATR M15.
  Giờ 13–15 phí thấp nhất; 20–23, 3–5 cao nhất. `spread_price` trong nến thấp hơn thực tế ở nến giật → dùng trượt ≥ 0,3.
- Hai nhóm khác (cản M5–H2 có đối chứng; tìm thời điểm xác suất cao, tìm luật 2025, kiểm 2026) đang chạy.
- Đã xuất nến M1 2023–2025 bằng EA `ExportBars` (TOOLS.md). Chủ bot chọn chỉ dùng 2025–2026.

Việc tiếp theo: điều tra S07/S06 (vì sao phá giả/kiểm tra lại thua), kiểm lại trên tháng chưa dùng (7 hoặc 9)
trước khi tắt/bật nhánh; giảm chi phí duyệt vùng mỗi tick; công cụ xem lệnh trên biểu đồ (chờ chủ bot đồng ý).

## Đọc trước khi làm

Đọc `AGENTS.md`, toàn bộ `docs/SPEC.md`, file này, `docs/AC-MAP.md`.
Trước khi chạy lệnh đọc `scripts/TOOLS.md`. Mã chính: `BotScpMtf.mq5` và các `Scp*.mqh`.

## Trạng thái

Chủ bot vừa chốt: bỏ đóng theo số phút; mục tiêu ngắn có căn cứ, không kéo xa để làm đẹp tỷ lệ;
đi thuận 2–3 giá thì có thể bảo vệ tại giá vào. Vị thế >0,01 lot chia được thì chốt một phần một lần,
rồi bảo vệ phần còn lại; không bỏ thoát khi cản phản ứng mạnh.
Mã đang theo `SCP-MTF-1.1-price-exit`. Mốc thử: 2,5 giá bảo vệ, 3 giá chốt phần, tối thiểu 1,5 lời/lỗ tính cả hai phần.
Kéo dừng về giá vào không bảo đảm hòa vốn sau phí/trượt. Phản ứng thoát mềm cần từ chối tại cản kèm phá cấu trúc nhỏ,
không chỉ một nhịp hồi bình thường. Dừng khẩn cấp và giới hạn lỗ vẫn giữ.

Đã sửa các nhóm lỗi sau review, không đổi ngôn ngữ và không bật demo/thật.
Đây chưa phải chứng nhận toàn bộ SPEC hoặc chứng minh lợi nhuận.
Chủ bot cho phép khởi động lại MT5 chính để kiểm tra; không được đụng bản MT5 portable của dự án khác.
Chưa commit/push trong lượt sửa này.

## Những thay đổi đã có trong mã

- Phân biệt bật về phía tiếp cận với phá sang phía đối diện; không biến phản ứng hỗ trợ thành phá lên.
- Cực trị phản ứng cập nhật theo giá/nến đã nhận; vùng nguồn và khung vào M1/M5 tách riêng.
- EMA nguồn M5/M15/H1 được theo dõi trên M1/M5; đường và ATR được khóa lúc chạm.
- Không dùng xác nhận quá 2 giây hoặc giá đã đuổi xa; đọc lại giá và tính tiền lại trước gửi.
- Dấu dùng xác nhận tách với sự kiện phá; không vô tình dùng hết S06 khi chỉ xét S05.
- S06 xét xác nhận trong cửa sổ sau chạm; S07 có thể nhận râu xuyên không cần đóng phá trước.
- Hình học vùng không bị gộp đổi ngầm; hai lần chạm không thay thế hai phản ứng độc lập.
- Khung nguồn chỉ đổi vai trò theo xác nhận khung nguồn; vai trò giao dịch lưu riêng.
- Lệnh đã đóng/bị từ chối chắc chắn được tạo kế hoạch mới; trạng thái chưa rõ không tự mở khóa sau 30 giây.
- Kiểm mã trả về và đọc lại dừng/chốt; kiểm tiền chịu lỗ theo giá khớp thật; giữ kế hoạch qua khởi tạo lại.
- Khóa gửi theo tài khoản/ký hiệu trong một terminal; không mở khi có lệnh ngoài bot.
- Khóa giới hạn lỗ lưu bền; tính cả phí mở/đóng; không tắt bảo vệ chỉ vì tắt tìm lệnh.
- Quản lý dùng ATR M1 lúc vào; không dùng đỉnh/đáy trước lúc khớp làm cấu trúc mới.
- Đỉnh/đáy vẫn cập nhật khi đầy bộ nhớ; ATR/EMA tính nối tiếp, không khởi tạo lại khi vòng nến quay.
- Mẫu đóng nến chỉ xét khi có nến mới; giá vẫn cập nhật lần chạm/cực trị. Lưu kết quả tìm đỉnh/đáy nhỏ theo khung.
- Nhật ký không ghi đè lượt thử có cùng tên; khi vận hành ngoài máy thử thì ghi nối. Mở được để đọc khi đang chạy.

## Bằng chứng kiểm tra

- Biên dịch các mục `BotScpMtf`, `ScpVerify`, `ScpExecVerify` bằng `scripts/build.ps1`.
- `ScpVerify`: bản quản lý mới có 97 ca đạt, gồm kiểm mức giá vào, chia khối lượng, phản ứng ngược và mục tiêu cục bộ.
- `ScpExecVerify`: 20 kiểm tra tích hợp thực thi đã đạt trong máy thử MT5, gồm mở hai lệnh nối tiếp, chống gửi lặp,
  nhận lại kế hoạch, sửa dừng sai bị từ chối, giữ khóa lỗ và giữ SENT_UNKNOWN.
  Có kiểm 0,02 còn 0,01, khởi tạo lại không chốt thêm lần nữa, dừng về giá vào và TP giữ nguyên.
  Ca này gọi trực tiếp hàm chốt phần để kiểm thực thi; điều kiện giá đi đủ khoảng được kiểm riêng trong ScpVerify.
- `ScpPriceManageVerify`: ca trọn chuỗi 0,02 → đủ 3 giá → chốt 0,01 → dừng giá vào → giá quay lại.
  9/9 kiểm đạt, còn lời 3,03 USD trên dữ liệu ca; có trượt 0,007 giá khi phần cuối khớp dừng.
  Đây là vị thế dựng để kiểm quản lý, không phải lệnh do bộ chọn cơ hội tự phát hiện.
- Lượt toàn EA `scp_price_exit_20260928_02`, ngày 02/09, hoàn tất 17:50:38: 1.208 đề nghị, 0 kế hoạch đủ, 0 lệnh.
  Chưa tính được lời trung bình/lỗ trung bình; không coi không lỗ vì không giao dịch là cải thiện chiến lược.
- Có chạy EA trên tick thật XAUUSDm. Tách rõ lượt quan sát với lượt bật gửi trong máy thử.
- Báo cáo bằng chứng: `docs/reports/scp-review-fixes-20260928.md`.
- Luật quản lý mới: `docs/reports/scp-price-management-20260928.md`.
- Ca tính toán dùng dữ liệu dựng kiểm công thức; ca thực thi dùng máy thử MT5. Không gọi hai nhóm này là demo giá mới.

## Cấu hình an toàn

- Mặc định `InpSendEnabled=false`, mọi `InpSendSxx=false`, `InpAllowDemo=false`.
- Tiền thật bị chặn trong mã. Demo cần chấp thuận mới của người dùng.
- `InpCommissionRoundTrip=-1` nghĩa là chưa biết phí; ngoài máy thử không được gửi.
  Trong hồ sơ nghiên cứu phí 0 là giả định rõ, không phải xác nhận tài khoản miễn phí.
- Phải xác thực `InpBrokerUtcOffset` trước demo. Không suy mọi máy chủ đều UTC.
- `lab/scp_review_send.set` chỉ dùng máy thử; tuyệt đối không nạp làm cấu hình demo.
- `lab/scp_price_exit.set` là hồ sơ thử luật quản lý mới; cũng không được nạp lên demo/thật.
- Không đổi ngưỡng chỉ để tạo thêm lệnh hoặc làm kết quả đẹp.

## Chưa được kết luận và việc còn lại

- Bộ kiểm chưa phủ hết 41 yêu cầu theo mọi chiều/khung, mọi lỗi mạng và mọi loại tài khoản.
- Khởi tạo lại đối tượng đã kiểm; mất điện thật ngay giữa gửi/khớp và mạng sàn chập chờn chưa được thử trực tiếp.
- Chưa nghiệm thu đo độ trễ khớp ngoài sàn; thời gian máy thử không thay thế số đo VPS/demo.
- Vùng ngày/tuần trước, phân nhóm ép cản, chọn tối ưu trong mọi đề nghị đồng thời và lịch tin có phạm vi phủ đầy đủ
  cần rà tiếp theo SPEC; không được ghi là đã nghiệm thu chỉ vì các nhánh S01–S08 đều có tên trong mã.
- Chưa có bằng chứng đạt mục tiêu nhiều lệnh/ngày và có lời. Phải điều tra từng nhóm bị loại trước khi đề xuất đổi luật.
- Trước triển khai: khóa mã/tham số, đo dài hơn trên dữ liệu chưa dùng chỉnh luật; báo phí/trượt/sụt vốn và mẫu thiếu.

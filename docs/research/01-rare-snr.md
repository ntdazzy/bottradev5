# Báo cáo: "Rare" SnR (`C:\Users\NTD\Desktop\BotTradeEA\docs\tài liệu trade\Rare SnR.pdf`)

Tôi đã đọc hết 27 trang. Công cụ Read không mở được file vì máy thiếu `pdftoppm`, nên tôi làm hai việc:
- Lấy phần chữ tiếng Việt có sẵn trong PDF bằng `pdftotext -enc UTF-8`.
- Chuyển cả 27 trang thành ảnh PNG bằng bộ đọc PDF có sẵn của Windows, rồi xem từng trang và phóng to từng biểu đồ.

Tôi không sửa hay tạo file nào trong dự án.

## 1. Tổng quan

- **Tên:** "Rare" SnR (tr.1). 27 trang A4, là bản scan có dấu AnyScanner trên mọi trang, kèm lớp chữ tiếng Việt. Nhãn trên chart phần lớn là tiếng Anh, nên đây là bản dịch.
- **Tác giả:** không ghi. Trên chart có logo "PRICE ACTION TRADERS" (tr.20) và chữ "SIMPLICITY-IS-KEY" (tr.23).
- **Thị trường trong ví dụ:** GBPJPY, GBPUSD, EURUSD, XAUUSD, BTC, COQ, BONK, Volatility 75.
  - XAUUSD xuất hiện ở tr.3–6, 18–21, 23, 24, trên các khung 1H/4H/D1/W1.
  - Không có ví dụ nào ở M1/M5. Khung nhỏ nhất là 30 phút (EURUSD, tr.22–23).
- **Ý chính:**
  1. Mức SnR luôn vẽ ở thân nến (giá mở cửa/đóng cửa), bỏ qua râu.
  2. Có 3 loại mức: Classic, Gap, Doji.
  3. Chiến lược chính là lật vai (flip). Khi thân nến đóng cửa xuyên qua một mức, mức đổi vai (hỗ trợ thành kháng cự và ngược lại), rồi giao dịch khi giá quay lại mức đó.
  4. Nếu mức giữ được thì giao dịch đảo chiều (reversal).
  5. Nến động lực (momentum candle) ở khung lớn (HTF) khi xem ở khung nhỏ (LTF) sẽ lộ ra các Gap SNR, gọi là "vùng đảo chiều" (flipzone). Đó là nơi vào lệnh với dừng lỗ rất nhỏ.
- **Bố cục:**
  - tr.1–2: cách vẽ mức.
  - tr.3: ba loại mức và chiến lược flip.
  - tr.4–6: khái niệm fresh, phá vỡ hợp lệ, giao dịch đảo chiều.
  - tr.7–10: lật mức, cách vùng Gap vận hành, tinh chỉnh từ HTF xuống LTF.
  - tr.11–26: ví dụ.
  - tr.27: lời kết, khuyên backtest.

## 2. Định nghĩa

Ký hiệu dùng trong báo cáo:
- c1, c2, c3 là các nến liền kề nhau theo thứ tự thời gian.
- O, H, L, C lần lượt là giá mở cửa, cao nhất, thấp nhất, đóng cửa.

**2.1 Mức của một cây nến (tr.1–2)**
- Nến tăng (bullish): O là hỗ trợ (support), C là kháng cự (resistance).
- Nến giảm (bearish): O là kháng cự, C là hỗ trợ.
- Mũi tên trong hình luôn chỉ vào mép thân nến; râu (wick) nằm ngoài mức.

**2.2 Classic SNR, hay SNR cổ điển (tr.1–3)**
- Hỗ trợ cổ điển (Classic Support), hình chữ V: c1 là nến giảm, c2 là nến tăng. Mức = C(c1).
- Kháng cự cổ điển (Classic Resistance), hình chữ A: c1 là nến tăng, c2 là nến giảm. Mức = C(c1).
- Tr.2 nói rõ: c2 mở cửa cao hơn hay thấp hơn C(c1) cũng không quan trọng (hay gặp ở kim loại, chỉ số, crypto). Luôn kẻ đường tại C(c1), kéo ngang qua O(c2).
- Trong hình tr.1–2, râu của cả hai nến thò qua đường nhưng đường vẫn nằm ở thân.
- Trên biểu đồ đường (chỉ có giá đóng cửa): chữ V là hỗ trợ, chữ A là kháng cự (tr.2).

**2.3 GAP SNR, hay SNR khoảng trống giá (tr.3, 8, 9)**
- Gap giảm (Bearish Gap): c1 và c2 đều là nến giảm. Mức = C(c1) = O(c2).
  - Nhãn bên trái là "SUP." (giá đóng cửa của c1), bên phải là "RES." (giá mở cửa của c2).
- Gap tăng (Bullish Gap): c1 và c2 đều là nến tăng. Mức = C(c1).
  - Tr.9 gọi C(c1) là "SNR ORIGIN (RESISTANCE)" và phía sau là "FRESH SUPPORT". Nghĩa là gap là một mức đã lật vai ngay khi hình thành.
- Biên vùng gap (đọc từ hình tr.8–9):

  | Loại gap | Biên trên (UL) | Biên dưới (LL) | Đường giữa |
  |---|---|---|---|
  | Gap giảm | H(c2), tức đỉnh râu trên nến 2 | L(c1), tức đáy râu dưới nến 1 | C(c1) |
  | Gap tăng | H(c1) | L(c2) | C(c1) |

- Điều kiện còn hiệu lực (có ghi bằng lời):
  - Lệnh Bán (Sell) tại FRESH RESISTANCE còn giá trị "miễn là không có giá đóng cửa nào vượt lên trên UL".
  - Lệnh Mua (Buy) tại FRESH SUPPORT còn giá trị khi không có giá đóng cửa nào xuống dưới LL.
- Gap có doji ở giữa (tr.6, GBPJPY D1): nến tăng, rồi 1–2 doji, rồi nến tăng. Hình kẻ 2 đường: C của nến tăng đầu và O của nến tăng sau.
- Nguồn gốc (tr.9–10): nến động lực ở HTF, khi xem ở LTF, là một chuỗi nến cùng màu, từ đó sinh ra các gap.

**2.4 Doji SNR (tr.3, 19)**
- Doji_SNR tăng (tr.19, có ghi bằng lời):
  1. Một nến tăng có động lực mạnh.
  2. Tiếp theo là nến doji, hoặc nến thân nhỏ (biên độ hẹp).
  3. Cuối cùng là nến tăng động lực mạnh, bứt phá và **đóng cửa phía trên** nến doji.
  - Hình vẽ kẻ đường SUPPORT tại O(c3), gần bằng mức thân doji và C(c1).
- Doji_SNR giảm: chỉ có hình ở tr.3 (đối xứng với mẫu tăng), không có lời giải thích.
- Tài liệu không cho ngưỡng nào cho "doji", "thân nhỏ" hay "động lực mạnh".

**2.5 Nến động lực (tr.7, 9, 21)**
- Là "nến thân dài" bứt phá (breakout) hoặc nhấn chìm (engulf) một mức SNR, và thường chứa một Gap SNR bên trong.
- Không có ngưỡng định lượng.

**2.6 Lật mức: Flip, SBR và RBS (tr.3–5, 7)**
- SBR (Support Becomes Resistance): hỗ trợ bị phá thành kháng cự mới.
- RBS (Resistance Becomes Support): kháng cự bị phá thành hỗ trợ mới.
- Thế nào là phá vỡ hợp lệ:
  - "Bị phá vỡ hoàn toàn bằng thân nến" (tr.5).
  - "Chừng nào giá chưa ĐÓNG CỬA thấp hơn mức kháng cự đã bị phá, giá vẫn đi theo xu hướng ban đầu" (tr.4).
  - Râu xuyên qua không tính là phá. Ví dụ tr.5 (XAUUSD 4H): nhiều râu dài vượt lên trên mức kháng cự nhưng thân nến đều đóng dưới.
- "SNR Flipping Candle" / "Cây nến đảo chiều" là nhãn gắn cho cây nến có thân đóng qua mức (tr.11, 12, 16, 17, 24, 25). Tài liệu không định nghĩa riêng.
- Tr.7 và tr.15: hai nến động lực ngược chiều liền kề ở HTF (một tăng, một giảm) sẽ tạo ra một "Flipped Gap" ở LTF.

**2.7 Vùng đảo chiều (Flipzone) và chuỗi điểm 1–4 (tr.8–9)**
- Định nghĩa: nến giảm phá một hỗ trợ yếu (weak support) và trở thành kháng cự mạnh ở phía bên kia điểm phá. Trường hợp mua thì ngược lại.
- Trong hình LTF, flipzone chính là gap giữa nến phá và nến cùng màu ngay sau nó, nằm đúng tại mức cũ.
- Chuỗi điểm:
  1. SNR ORIGIN: điểm hình thành mức.
  2. 1ST REJECT: giá chạm lần 1, mức yếu đi.
  3. 2ND REJECT: giá chạm lần 2, mức càng yếu.
  - Sau đó một nến mạnh phá dứt khoát.
  4. REJECT OF STRONG RESISTANCE/SUPPORT: râu của nến ngay sau nến phá chạm lại mức. Điểm này dùng để vào lệnh trực tiếp (Direct Entry).
  - Sau điểm 4 là "các điểm vào lệnh xác nhận khi giá quay lại kiểm tra" (retest).
- Hình tr.7 kẻ FLIPZONE tại các gap của chân sóng HTF trước đó, sau khi chúng bị chân sóng ngược chiều phá.

**2.8 Fresh, tức mức mới/nguyên bản (tr.4, 5, 8, 9)**
- FRESH SUPPORT: hỗ trợ chưa bị chạm, chưa bị kiểm tra.
- FRESH RESISTANCE: kháng cự còn nguyên, chưa bị phá.
- "Mức hỗ trợ cũ đã qua sử dụng trở thành kháng cự mới sau khi bị phá" (tr.4).
- "Sự thật quan trọng" (tr.4): mức tồn tại bao lâu hay từng được dùng thế nào không quan trọng. Miễn là trạng thái hiện tại của nó là FRESH thì dùng lại được. Người dịch ghi chú thêm: có thể dùng ngay ở lần chạm đầu tiên sau khi mức lật.
- Tr.5: một mức đã dùng nhiều lần vẫn có giá trị nếu bị thân nến phá hoàn toàn.

**2.9 Các khái niệm khác**
- **Đảo chiều (Reversal, tr.6):** nếu mức giữ được hoặc giá bị từ chối (reject) tại mức, thì giao dịch bật ra khỏi mức.
- **Câu chuyện thị trường (Storyline, tr.7, 19):** hướng thị trường thể hiện qua chuỗi các lần lật mức. Ví dụ "Bullish Storyline" ở tr.19 gồm ba yếu tố:
  - gap tăng phá gap giảm;
  - Doji_SNR khung 4H đẩy giá qua gap giảm;
  - giá bị từ chối tại gap khung tuần (Weekly GAP Reject).
- **Gap nội bộ / gap ẩn (Internal GAP / Hidden Gap_SnR, tr.14, 21):**
  - Khi nến động lực phá qua SNR, tinh chỉnh (refine) nến đó xuống TF nhỏ hơn để tìm các gap ẩn trong toàn biên độ nến.
  - Sau khi phá, giá thường quay lại kiểm tra các gap này. Tr.14 coi chúng là chướng ngại trên đường đi của lệnh.
- **Nhãn chỉ có trong hình, không có định nghĩa:**
  - A-B-C và BMS (tr.10, 16). BMS là đường kẻ ở đỉnh A; tôi đoán là "Break of Market Structure", tài liệu không giải thích.
  - "Pháo đài" (tr.5).
  - "Mức tâm lý" (tr.5).
  - PIN BAR (tr.13).
  - WEEKLY REJECTION BLOCK (tr.15).
  - London/New York Killzone (tr.14–15).
  - New York Open (tr.23).
- **Không có trong tài liệu:**
  - A-level và V-level như tên riêng (chỉ có hình chữ A/V).
  - miss/hit.
  - QM/quasimodo.
  - compression.
  - "unfresh".
  - "Engulf" chỉ được nhắc một lần.

## 3. Quy tắc xác định mức/vùng (tổng hợp từ tr.1–10, 14, 21)

1. Trên HTF (Monthly/Weekly/Daily/4H), kẻ mức tại C(c1) của mọi mẫu Classic A/V, Gap và Doji. Dùng thân nến, bỏ râu, kéo đường sang phải.
2. Theo dõi trạng thái của từng mức:
   - Râu chạm mà thân không đóng qua: mức giữ. Mỗi lần giá chạm hoặc bị từ chối, mức yếu thêm.
   - Có giá đóng cửa ở phía bên kia: mức bị phá hợp lệ, đổi vai (SBR/RBS), trở thành FRESH ở phía mới.
3. Nếu nến phá là nến động lực HTF, tinh chỉnh nó xuống LTF theo chuỗi D1→4H→1H hoặc W→D1→4H (tr.10):
   - Các cặp nến cùng màu nằm trong nến đó là Gap SNR ở LTF.
   - Gap nằm ngay tại mức bị phá là flipzone.
   - Các gap còn lại là gap nội bộ.
4. Với Gap SNR, lập vùng [LL, UL]. Setup hỏng khi có giá đóng cửa vượt UL (với lệnh Bán) hoặc xuống dưới LL (với lệnh Mua).
5. Thứ tự ưu tiên giữa các mức: **tài liệu không có quy tắc rõ ràng**. Chỉ có các gợi ý ngầm:
   - Mức do nến động lực lật là mức "mạnh". Mức bị chạm nhiều lần là mức "yếu", dễ bị phá.
   - Ưu tiên mức trùng giữa nhiều khung:
     - Tr.12: GAP_SNR khung 4H chuyển từ GAP_SNR khung ngày.
     - Tr.19: setup 4H nằm đúng flipzone cũ, và trùng với việc giá bị từ chối ở gap khung tuần.
   - Dấu hiệu cấu trúc thị trường đổi hướng là gap mới phá gap ngược chiều cũ (tr.12, 17, 18).

## 4. Quy tắc vào lệnh

**Hai kiểu vào lệnh (tr.8–9, 20)**
- **Vào lệnh trực tiếp** (điểm 4): vào ở nến ngay sau nến phá, tại mức vừa lật.
  - Tr.20 (XAUUSD 1H): biểu tượng bóng đèn nghĩa là "điểm vào lệnh MUA trực tiếp", đặt ngay lúc nến tăng phá lên qua 2 mức FRESH SUPPORT.
- **Vào lệnh có xác nhận**: chờ giá quay lại kiểm tra mức, râu chạm mức, thân nến đóng lại về phía giao dịch.
  - Tr.13: "SELL khi giá quay lại kiểm tra xác nhận (Confirmatory retest) vùng GAP_SNR tại 1.28239".
  - Tr.11 (BTC 1H): xác nhận gồm giá bị từ chối tại vùng, nến đổi xu hướng ở LTF, và Doji SNR xuất hiện ngay tại điểm phá.
  - Tr.17 (COQ 4H): vào lệnh xác nhận khi một nến giảm đóng cửa đúng tại mức và nến tăng kế tiếp mở từ đó (tạo thành một chữ V mới).

**Giá vào lệnh**
- Trong các ví dụ, giá vào đúng bằng giá của mức, và lệnh khớp khi râu của nến kiểm tra chạm tới.
  - Ví dụ: SELL 1.28239 (tr.13), BUY 2357.808 (tr.20), BUY 2251.292 (tr.23).
- Tài liệu không dùng chữ "lệnh limit".

**Giao dịch đảo chiều (tr.6)**
- SELL tại Classic SNR hình chữ A trên GBPJPY D1.
- BUY tại Classic SNR hình chữ V trên GBPJPY 4H.
- Cả hai lệnh khớp khi râu nến sau đó chạm mức.

**Dừng lỗ (SL)**: không có quy tắc bằng lời.
- Điều gần nhất là quy tắc hiệu lực: setup hỏng khi có giá đóng cửa qua UL/LL.
- Ví dụ tr.13: SL 1.28310, nằm khoảng ở đỉnh râu trên của nến giảm thứ hai, tức gần UL (6.7 pip).
- Tr.6: vùng SL vẽ nhỏ, có trường hợp không bao hết râu dài của nến tạo mức.

**Chốt lời (TP)**: không có quy tắc bằng lời.
- Tr.13 có nhãn "1ST TP @ 1R:5R (35)", tức mục tiêu đầu tiên là 5 lần rủi ro, 35 pip.
- Tr.14 dùng các gap nội bộ làm chướng ngại.

**Giờ giao dịch**: có nhãn killzone trên chart nhưng không có giờ cụ thể, không có quy tắc.

## 5. Quan hệ khung thời gian

- **HTF** (M/W/D/4H) dùng để xác định hướng thị trường, tìm nến động lực, mức HTF bị lật, và các chướng ngại. Tr.14: "Quay trở lại khung Daily để có cái nhìn tổng quan về hướng của xu hướng".
- **LTF** dùng để vào lệnh với SL nhỏ:
  - Tr.14: cùng một lệnh, ở 4H cần SL 13 pip; tinh chỉnh xuống 1H chỉ cần SL 4 pip, lãi 73 pip.
  - Tr.23: tinh chỉnh 4H xuống LTF "để đạt mức rủi ro cực kỳ thấp".
- **Các chuỗi khung trong ví dụ:**

  | Ví dụ | Khung lớn | Khung vào lệnh |
  |---|---|---|
  | BTC (tr.11) | D1 + 4H | 1H |
  | GBPUSD (tr.12–15) | D1 | 4H, tinh chỉnh tiếp xuống 1H |
  | COQ (tr.16–18) | M → W → D → 4H | 1H |
  | XAUUSD (tr.18–20) | W1 + 4H | 1H |
  | EURUSD (tr.23) | 4H SNR | 1H |

- Hệ số giữa hai khung thường khoảng ×4 đến ×6.
- Tài liệu không nhắc M1/M5.

## 6. Mọi con số trong tài liệu

**Quy ước pip**
- Vàng: 1 pip = 0.1 USD, suy ra từ các số đo trong ảnh: 61.017 USD được ghi "610 pips", 114.276 USD là "1,143", 4.369 USD là "44", 9.96 USD là "100".
- EURUSD/GBPUSD: 1 pip = 0.0001.

**Số nến trong mỗi mẫu**
- Classic: 2 nến ngược màu.
- Gap: 2 nến cùng màu (tr.6 có ví dụ xen 2 doji ở giữa).
- Doji SNR: 3 nến.
- Mức "yếu" trong hình: bị chạm 2 lần trước khi bị phá.

**Các lệnh ví dụ**

| Trang | Cặp/khung | Hướng | Giá vào | SL | Kết quả |
|---|---|---|---|---|---|
| tr.13 | GBPUSD (hình không ghi khung, có vẻ 4H) | Sell | 1.28239 | 1.28310 (6.7 pip) | TP 1.27890 (35.1 pip). Lời ghi "SL 7 pip, RR 1:5, TP 35 pip" |
| tr.12 | GBPUSD 4H | Sell | 1.28068 | 1.28232 (15.6 pip) | TP 1.27450 (60.5 pip) |
| tr.14 | GBPUSD 4H | Sell | 1.28066 | 1.28195 (13.1 pip) | +60.3 pip |
| tr.14 | GBPUSD 1H | Sell | — | 4.1 pip | +73.4 pip; một lệnh khác +92.2 pip |
| tr.15 | GBPUSD 1H (Doji_SNR) | Sell | 1.28240 | 1.28298 | +92.3 pip; một lệnh khác +77 pip |
| tr.6 | GBPJPY | — | — | — | +1,328 / +394 / +382 pip |
| tr.20 | XAUUSD 1H | Buy | 2357.808 | 2351.670 | +61 USD ("610 pips trong 2 ngày") |
| tr.22 | EURUSD 30m | — | — | — | +100 pip |
| tr.23 | XAUUSD 4H | Buy | 2251.292 | 2246.793 (44 pip) | +1,143 pip, "1R:26R" |
| tr.23 | EURUSD 30m | Sell | 1.08991 | 3.1 pip | +77 pip |
| tr.23 | EURUSD 1H | Sell | — | 1.3 pip | +95.2 pip |
| tr.24 | XAUUSD 1H | Sell | ~2026.1 | ~2028.0 | +100 pip (nhãn giá mờ) |
| tr.25 | BONK | Buy | 0.000011682 | 0.000011012 | ROI 120.79% và 315.88% |

- Tr.23 có một ô tính tiền (20 vị thế, 0.5 lot, 11600$, …). Các số trong đó không khớp nhau, là quảng cáo, không phải quy tắc.
- Tài liệu không có ngưỡng ATR, tỷ lệ thân nến, quy tắc quản lý vốn hay giờ phiên.

## 7. Phân loại

**Khách quan, code trực tiếp được**
1. Mức Classic và Gap = C(c1).
2. UL/LL của vùng gap theo bảng ở mục 2.3.
3. Setup hỏng khi có giá đóng cửa vượt UL/LL.
4. Mức bị phá khi có giá đóng cửa qua mức (râu không tính).
5. Đổi vai SBR/RBS sau khi bị phá.
6. Mức là fresh khi chưa bị chạm kể từ lúc hình thành hoặc lúc lật.
7. Doji_SNR tăng: nến thứ 3 là nến tăng và đóng cửa trên doji.

**Chủ quan: cần người dùng chọn định nghĩa.** Mọi con số dưới đây là ĐỀ XUẤT của tôi, không phải quy tắc của tài liệu.
- **a. Nến động lực:** thân ≥ 1.5 × ATR(14) của cùng khung, và thân ≥ 60% biên độ nến.
- **b. Doji / thân nhỏ:** thân ≤ 25% biên độ nến.
- **c. Gap có ý nghĩa:** chỉ nhận cặp nến cùng màu khi có ít nhất một nến là nến động lực, hoặc cặp nằm bên trong nến động lực HTF. Nếu không lọc, cặp nến cùng màu nào cũng thành mức.
- **d. Chạm/kiểm tra lại:** giá cao nhất (khi Bán) hoặc thấp nhất (khi Mua) đi vào khoảng mức ± 0.1 × ATR, hoặc đi vào vùng [LL, UL].
- **e. Từ chối (xác nhận):** nến kiểm tra chạm vùng rồi đóng cửa về phía giao dịch so với đường giữa. Vào lệnh ở giá mở của nến kế tiếp. Có thể thay bằng: xuất hiện một mẫu Classic/Gap/Doji cùng chiều ở khung nhỏ hơn.
- **f. Vào lệnh trực tiếp:** đặt lệnh limit tại flipzone ngay khi nến phá đóng cửa. Huỷ nếu có giá đóng cửa vượt UL/LL, hoặc sau khoảng 12 nến mà chưa khớp.
- **g. Mức yếu:** bị chạm ít nhất 2 lần trước khi bị phá. Dùng làm bộ lọc tuỳ chọn.
- **h. UL/LL cho mức Classic:** tài liệu chỉ định nghĩa cho Gap. Với chữ V: LL = thấp nhất của 2 nến. Với chữ A: UL = cao nhất của 2 nến.
- **i. SL:** đặt ngoài UL/LL, cộng spread và một khoảng đệm 0.05–0.1 × ATR. Khớp với ví dụ tr.13.
- **j. TP:** TP1 = 5R như tr.13. Phần còn lại chốt ở gap nội bộ hoặc mức fresh đối diện gần nhất trên HTF.
- **k. Xu hướng HTF:** coi là tăng nếu lần lật gần nhất trên H4 (hoặc D1) là kháng cự bị thân nến đóng cửa vượt lên, và chưa bị phá ngược lại. Giảm thì ngược lại.
- **l. Tinh chỉnh:** lấy các nến LTF nằm trong khoảng thời gian của nến động lực HTF. Gap gần mức HTF bị phá nhất là flipzone.
- **m. Khung cho M1/M5:** H4 để xác định xu hướng, H1 hoặc M15 để tìm mức, M5/M1 để vào lệnh.
- **n. Killzone:** cần người dùng cho giờ cụ thể. Nếu dùng quy ước phổ biến bên ngoài tài liệu thì London 07–10 UTC, New York 12–15 UTC.
- **o. Pip vàng:** 0.1 USD, tức 10 point trên báo giá 2 chữ số thập phân. Cần đối chiếu với broker.
- **p. Pin bar:** râu ≥ 2/3 biên độ nến.
- **q. BMS:** đỉnh/đáy swing gần nhất, được xác nhận khi thân nến đóng cửa vượt qua.

## 8. Điểm mơ hồ / mâu thuẫn cần hỏi người dùng

1. **Ngưỡng huỷ setup mâu thuẫn nhau.**
   - Tr.4: huỷ khi giá đóng cửa qua chính đường mức.
   - Tr.8–9: chỉ huỷ khi giá đóng cửa qua UL/LL.
   - Hình tr.10 có thân nến nhịp hồi B đóng hơi vượt đường mức mà setup vẫn tiếp diễn.
   → EA dùng ngưỡng nào?
2. **Chỉ vào ở lần chạm đầu, hay nhiều lần?**
   - Tr.4 nói mức vẫn dùng được khi trạng thái hiện tại là fresh (chưa chạm).
   - Nhưng tr.4 (4H) cũng nói mức mới hợp lệ "sau nhiều lần kiểm tra lại", và tr.22 có "Sell nhiều lần" tại cùng một mức.
3. **Vào lệnh trực tiếp, chờ xác nhận, hay cả hai?** Và "xác nhận" chính xác là gì?
4. **Gap có cần lọc không?** Mọi cặp nến cùng màu đều là Gap, hay chỉ các cặp trong chân sóng động lực?
5. **Có bắt buộc mức phải bị chạm ít nhất 2 lần** (mức "yếu") trước khi bị phá không?
6. **SL/TP:** tài liệu không có quy tắc. Có theo ví dụ tr.13 (SL ở UL, TP 5R) không? Chữ "1ST TP" gợi ý chốt lời từng phần nhưng không nói cách làm.
7. **Khung thời gian:** EA chạy M1/M5, trong khi tài liệu không có ví dụ nào dưới 30 phút. Cần chọn cặp HTF/LTF.
8. **Mức của Doji_SNR** lấy ở O(c3), thân doji hay C(c1)? Doji_SNR giảm chỉ có hình, không có lời.
9. **Có dùng các nhãn không được định nghĩa không:** BMS, A-B-C, killzone, pin bar, mức tâm lý, weekly rejection block?
10. **Pip vàng = 0.1 USD** có khớp với broker không?
11. **Số liệu đáng ngờ:** tr.23 ghi "R-R = 1R:5.2R" trong khi 77/3 ≈ 25.7. Ảnh mờ, có thể thực ra là "1R:25.7R".
12. **Lỗi dịch:**
    - Tr.12 viết "gap giảm 4H phá vỡ gap giảm", trong khi Sự thật 2 cùng trang nói là phá gap tăng cũ.
    - Tr.10 có nhãn "LTF BEARISH GAP_SNR" trong sơ đồ thị trường mua, không rõ chỉ vào nến nào.
    - Tr.21: ảnh XAUUSD 4H là hai ảnh chồng lên nhau, khó đọc liên kết giữa "BULLISH GAP" và điểm BUY.
13. **Thiếu quy tắc:** không có cách chọn giữa nhiều mức gần nhau, không giới hạn số lệnh, không quy định mức cũ bao lâu thì bỏ, không có quy tắc quản lý vốn.

## 9. Các ví dụ quan trọng nhất

1. **Tr.1–3:** sơ đồ cốt lõi.
   - Mức nằm ở C(c1), dùng thân nến.
   - Sơ đồ "3 TYPES OF SNR" có nhãn SUP./RES. cho gap.
   - XAUUSD 1H minh hoạ hỗ trợ thành kháng cự; các lần kiểm tra lại đều là râu chạm mức.
2. **Tr.4 (XAUUSD 1H/4H):**
   - Kháng cự thành hỗ trợ nhiều lần, kèm quy tắc "chưa đóng cửa dưới thì xu hướng còn".
   - Một FRESH SUPPORT không bị chạm khoảng 2 tuần, sau đó bị thân nến phá và thành kháng cự.
3. **Tr.5–6:**
   - XAUUSD D1: mức 1980 bị chạm nhiều lần, bị thân nến phá hợp lệ, rồi thành kháng cự.
   - XAUUSD 4H: râu vượt lên nhưng thân nến không đóng qua.
   - GBPJPY: giao dịch đảo chiều tại mức Classic.
   - Gap giảm trên XAUUSD D1, và gap có doji ở giữa trên GBPJPY D1.
4. **Tr.8–9:** UL/LL, các điểm 1–4, hai kiểu vào lệnh (trực tiếp và có xác nhận), quy tắc đóng cửa qua UL/LL.
5. **Tr.10:** nến động lực HTF tách thành gap LTF và flipzone, có BMS và chu kỳ A-B-C.
6. **Tr.11 (BTC):** hỗ trợ D1 bị nến lật phá, sinh ra gap giảm ở 4H, và xác nhận vào lệnh ở 1H.
7. **Tr.12–15 (GBPUSD):** bộ ví dụ có đủ giá vào, SL, TP.
   - D1: FRESH RESISTANCE là một gap giảm.
   - Lệnh Sell 7 pip SL / 35 pip TP (tỷ lệ 1:5), SL nằm ở UL.
   - Tinh chỉnh xuống 1H thì SL chỉ 4 pip; có lệnh #Doji_SNR và nhãn killzone.
8. **Tr.18–20 (XAUUSD, gần với EA nhất):**
   - Câu chuyện thị trường tăng trên 4H, Doji_SNR tại khoảng 2357, giá bị từ chối ở gap khung tuần.
   - Trên 1H có hai FRESH SUPPORT; bóng đèn là vào lệnh trực tiếp, dấu tích là vào lệnh có xác nhận.
   - BUY 2357.808, SL 2351.670.
9. **Tr.21:**
   - Gap ẩn trên COQ 1H.
   - Gap bị lật thành kháng cự trên XAUUSD D1, cho nhiều lệnh Sell.
10. **Tr.23–24:**
    - XAUUSD 4H: #FlippedSNR, rủi ro 44 pip, lãi 1,143 pip.
    - EURUSD 1H: Sell tại mức 4H SNR, rủi ro 1 pip.
    - XAUUSD 1H: gap 1H bị phá (nhãn "1-HOUR GAP SNR BO"), Sell khi giá quay lại, +100 pip.
    - Nhãn "SNR Flipping Candle" trên EURUSD D1 và XAUUSD 4H.

---

**Ghi chú kỹ thuật**
- Ảnh các trang để xem lại nằm ở `C:\Users\NTD\AppData\Local\Temp\claude\C--Users-NTD-Desktop-BotTradeEA\370bc82c-3d1b-468b-a881-1aa9fc582185\scratchpad\rare_snr_pages\page_01.png` đến `page_27.png`.
- **Có thể đã ảnh hưởng tới agent khác:** tôi đã ghi đè file `render_pdf.ps1` có sẵn trong scratchpad dùng chung, rất có thể là của agent khác.
  - Hệ quả: thư mục `scratchpad\p1render` đang chứa ảnh của Rare SnR (hash trùng với ảnh của tôi), không phải "Secret Of 411-1".
  - Agent kia có vẻ đã tự render lại vào `secret411_p1_pages`, nhưng nên kiểm tra lại báo cáo của agent đó.
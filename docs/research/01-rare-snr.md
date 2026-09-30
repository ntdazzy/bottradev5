# Báo cáo: "Rare" SnR (`docs/tài liệu trade/Rare SnR.pdf`)

Đã đọc hết 27 trang, từng trang một. Bản cập nhật ngày 29/09/2026:
- Chuyển mọi trang thành ảnh bằng `pdftoppm` (220 dpi), rồi cắt và phóng to từng biểu đồ ở 300–400 dpi để xem nhãn, đường kẻ, mũi tên, nến nào tạo đường, và các ô điểm vào/dừng lỗ/chốt lời.
- Đối chiếu thêm phần chữ lấy bằng `pdftotext -enc UTF-8`.
- Bản trước (viết trên máy Windows) được giữ phần đúng; phần sai hoặc thiếu đã sửa, có ghi "[sửa]" hoặc "[mới]" ở chỗ quan trọng.
- Tóm tắt từng trang nằm ở **mục 10**. Bảng luật viết được thành mã nằm ở **mục 7**. Số thứ tự mục 2.4 (Doji SnR) và 2.6 (phá hợp lệ) giữ nguyên vì `docs/SPEC.md` đang trỏ tới.

Ký hiệu dùng trong báo cáo:
- c1, c2, c3 là các nến liền kề theo thứ tự thời gian (c1 cũ nhất).
- O, H, L, C là giá mở cửa, cao nhất, thấp nhất, đóng cửa. Ví dụ `C(c1)` là giá đóng của c1.
- Nến tăng: `C > O`. Nến giảm: `C < O`.
- Nhãn trong bảng nguồn: **[ghi rõ]** = tài liệu viết bằng chữ; **[từ hình]** = chỉ thấy trong hình, tôi suy ra; **[không có]** = tài liệu không nói, phải đo hoặc chủ bot chọn.

## 1. Tổng quan

- **Tên:** "Rare" SnR (tr.1). 27 trang A4, bản scan có dấu AnyScanner, có lớp chữ tiếng Việt. Nhãn trên hình phần lớn là tiếng Anh nên đây là bản dịch.
- **Tác giả:** không ghi. Trên hình có logo "PRICE ACTION TRADERS" (tr.20) và chữ "SIMPLICITY-IS-KEY" (tr.23).
- **Thị trường trong ví dụ:** GBPJPY, GBPUSD, EURUSD, XAUUSD, BTCUSD, COQ/USDT, BONK/USDT, Volatility 75 Index (Deriv).
  - XAUUSD có ở tr.3, 4, 5, 6, 18, 19, 20, 21, 23, 24; khung 1H, 4H, D1, W1.
  - Không có ví dụ M1/M5/M15. Khung nhỏ nhất là 30 phút (EURUSD, tr.22–23).
- **Ý chính:**
  1. **Mức SnR luôn kẻ ở thân nến**: giá đóng cửa của nến trước, ngang qua giá mở cửa của nến sau. Râu (wick) không dùng để kẻ mức.
  2. Râu chỉ dùng cho 3 việc: (a) biên vùng gap UL/LL (tr.8–9), (b) lần chạm/từ chối (retest) — giá chạm mức bằng râu, thường hơi xuyên qua mức, (c) chỗ đặt dừng lỗ trong một số ví dụ (tr.13).
  3. Có 3 loại mức: Classic (cổ điển), Gap (khoảng trống giá), Doji.
  4. Chiến lược chính là **lật vai (flip)**: thân nến đóng xuyên qua mức thì mức đổi vai (hỗ trợ thành kháng cự và ngược lại), rồi giao dịch khi giá quay lại mức đó.
  5. Nếu mức giữ được thì giao dịch đảo chiều (reversal) bật ra khỏi mức (tr.6).
  6. Nến động lực (momentum candle) ở khung lớn (HTF), khi xem ở khung nhỏ (LTF), lộ ra các Gap SnR. Gap nằm đúng tại mức vừa bị phá gọi là "vùng đảo chiều" (flipzone). Vào lệnh ở đó với dừng lỗ rất nhỏ.
  7. **Tài liệu không có luật bằng chữ cho dừng lỗ và chốt lời.** Chỉ có con số trong các ví dụ (mục 4.3, 4.4).
- **Bố cục:**
  - tr.1–2: cách kẻ mức từ 1–2 cây nến.
  - tr.3: ba loại mức và chiến lược flip.
  - tr.4–6: fresh, phá hợp lệ, giao dịch đảo chiều.
  - tr.7–10: lật mức, cách vùng Gap vận hành, tinh chỉnh từ HTF xuống LTF.
  - tr.11–26: ví dụ.
  - tr.27: lời kết, khuyên đo lại quá khứ (backtest).

## 2. Định nghĩa

**2.1 Mức của một cây nến (tr.1–2)** [ghi rõ]
- Nến tăng: O là hỗ trợ (support), C là kháng cự (resistance).
- Nến giảm: O là kháng cự, C là hỗ trợ.
- Hình "SNR LEVELS" (tr.1): mũi tên OPEN/CLOSE chỉ đúng vào mép thân nến; râu nằm ngoài.

**2.2 Classic SnR, hay SnR cổ điển (tr.1–3)** [ghi rõ]
- **Hỗ trợ cổ điển (Classic Support), hình chữ V:** c1 là nến giảm, c2 là nến tăng. Mức = `C(c1)`.
  - Tr.1 ghi: nến đầu tiên đóng cửa thấp hơn là mức hỗ trợ, nến còn lại mở cửa tại mức đó.
  - Hình phóng to tr.1: c1 đen thân nhỏ, râu dưới dài xuống tới chấm xanh; c2 trắng mở đúng tại đường "SNR". Đường nằm ở đáy thân, không ở đáy râu.
- **Kháng cự cổ điển (Classic Resistance), hình chữ A:** c1 là nến tăng, c2 là nến giảm. Mức = `C(c1)`.
  - Hình tr.2: chấm đỏ ở đỉnh râu c1, nhưng đường "SNR" kẻ ở đỉnh thân c1 = mở cửa c2.
- Tr.2 ghi rõ: c2 mở cao hơn hay thấp hơn `C(c1)` **không quan trọng** (hay gặp ở cổ phiếu, kim loại, chỉ số, crypto). Luôn kẻ tại `C(c1)`, kéo ngang qua `O(c2)`.
  - Hình "3 TYPES OF SNR" (tr.3): ở chữ A, đỉnh thân c2 hơi thấp hơn đường — minh hoạ đúng ý này.
- Trên biểu đồ đường (chỉ có giá đóng cửa): chữ V là hỗ trợ, chữ A là kháng cự (tr.2). Điều này khớp với cách kẻ bằng giá đóng cửa.
- Không có yêu cầu về độ lớn thân c1, c2. [không có]

**2.3 Gap SnR, hay SnR khoảng trống giá (tr.3, 6, 8, 9)**
- **Gap giảm (Bearish Gap):** c1 và c2 đều là nến giảm, liền nhau. Mức = `C(c1)` (≈ `O(c2)`). [ghi rõ bằng hình tr.3, 8]
  - Hình tr.3: nhãn "SUP." bên trái ở giá đóng c1, "RES." bên phải ở giá mở c2. Nghĩa là: `C(c1)` vốn là hỗ trợ của nến giảm, nhưng c2 mở ra và đi xuống luôn, nên hỗ trợ đó đã bị phá ngay và thành kháng cự.
  - Tr.8 ghi mức là "SNR (SUPPORT)" và bên phải là "FRESH RESISTANCE" — gap chính là một mức đã lật vai ngay khi hình thành.
- **Gap tăng (Bullish Gap):** c1 và c2 đều là nến tăng. Mức = `C(c1)` (≈ `O(c2)`).
  - Tr.9 gọi `C(c1)` là "SNR ORIGIN (RESISTANCE)", bên phải là "FRESH SUPPORT".
- **Biên vùng gap** (tên UL/LL ghi rõ ở tr.8–9; vị trí đọc từ hình phóng to):

  | Loại gap | Biên trên (UL) | Biên dưới (LL) | Đường giữa (mức) |
  |---|---|---|---|
  | Gap giảm | `H(c2)` — đỉnh râu trên của nến 2 | `L(c1)` — đáy râu dưới của nến 1 | `C(c1)` |
  | Gap tăng | `H(c1)` — đỉnh râu trên của nến 1 | `L(c2)` — đáy râu dưới của nến 2 | `C(c1)` |

  - Cách nhớ: UL và LL là hai râu "chìa vào" chỗ nối giữa hai thân nến.
- **Điều kiện còn hiệu lực** [ghi rõ tr.8, tr.9]:
  - Lệnh bán tại FRESH RESISTANCE còn giá trị "miễn là không có giá đóng cửa nào vượt lên trên UL".
  - Lệnh mua tại FRESH SUPPORT còn giá trị khi không có giá đóng cửa nào xuống dưới LL.
  - Không nói giá đóng cửa của khung nào (khung của gap hay khung nhỏ hơn). [không có]
- **Gap có doji ở giữa** [từ hình; chữ chỉ nói "đi kèm các mô hình nến Doji nằm ở giữa"]:
  - GBPJPY D1 (tr.6): nến tăng, 2 doji, nến tăng. Hình kẻ **2 đường**: `C` của nến tăng đầu và `O` của nến tăng sau. Hộp xám bao toàn bộ biên độ 4 nến.
  - XAUUSD D1 (tr.6) [mới]: gap giảm cũng có 1 nến rất nhỏ nằm giữa hai nến giảm. Đường "GAP SNR" kẻ ở giá đóng nến giảm đầu.
  - Khi giá quay lại (GBPJPY), râu nến kiểm tra đi xuyên qua cả hai đường, thân vẫn đóng phía trên, và được đánh dấu là điểm vào.
- **Nguồn gốc** (tr.9–10, 21): gap sinh ra từ nến động lực. Nến động lực ở HTF khi xem ở LTF là một chuỗi nến cùng màu, mỗi cặp liền nhau là một gap.
- **Kích thước gap:** không có ngưỡng. Ví dụ XAUUSD 4H (tr.18): nến 1 của gap tăng 2356 là nến trắng rất nhỏ, gần như doji. [không có]

**2.4 Doji SnR (tr.3, 11, 15, 19, 26)**
- **Doji SnR tăng — định nghĩa bằng chữ (tr.19)** [ghi rõ]:
  1. c1: một nến tăng có động lực mạnh.
  2. c2: một nến doji, hoặc nến thân nhỏ (biên độ hẹp).
  3. c3: một nến tăng có động lực mạnh, bứt phá và **đóng cửa phía trên** nến doji.
  - Ý nghĩa: lực mua quay lại.
- **Mức nằm ở đâu** [từ hình]:
  - Hình mẫu tr.19: nhãn "RESISTANCE CLOSE" ở `C(c1)`; thân doji nằm ngang mức đó; nhãn "OPEN … SUPPORT" và đường đỏ ở `O(c3)`. Vậy **mức hỗ trợ = `O(c3)` ≈ thân doji ≈ `C(c1)`**.
  - Hình mẫu tr.19 còn có một đường xám ở đỉnh râu trên của doji, kéo sang phải; thân c3 đóng cao hơn đường này. Tôi đọc "đóng cửa phía trên nến doji" là `C(c3) > H(c2)`. Chữ không nói rõ là trên thân hay trên râu doji.
  - Hình "3 TYPES" (tr.3): tăng = nến trắng thấp, dấu thập (doji) ngang đỉnh thân nến trắng, rồi nến trắng cao mở từ ngang doji. Giảm đối xứng: nến đen, doji ngang đáy thân nến đen, nến đen thấp hơn mở từ ngang doji.
- **Ví dụ thật XAUUSD 4H (tr.19)** [mới]:
  - c1 = nến trắng thân vừa (~5 USD), đóng ≈ 2357; c2 = nến thân rất nhỏ ở ≈ 2357 có râu dưới rất dài (xuống ≈ 2325, tức ~31 USD); c3 = nến trắng lớn mở ≈ 2357, đóng ≈ 2382.
  - Đường đỏ "4H #Doji_SNR" kẻ ở ≈ 2357 = `C(c1)` ≈ thân doji ≈ `O(c3)`.
  - Lưu ý: c1 ở đây **không** phải nến động lực lớn như chữ mô tả.
  - Ngày 17/04 18:00, một nến giảm có râu xuống ≈ 2355 (xuyên ~2 USD dưới đường), thân đóng ≈ 2360 trên đường. Tác giả ghi: giá đang "từ chối mức 4H Doji_SNR".
- **Doji SnR giảm** [từ hình, không có chữ]:
  - Hình tr.3 (đối xứng mẫu tăng).
  - GBPUSD 1H (tr.15): nến giảm lớn, doji, nến giảm. Hộp tím "#Doji_SNR" khoảng [1.2820; 1.2830]. Điểm vào bán 1.28240 (ngang thân doji), dừng lỗ 1.28298 ở gần đỉnh hộp (gần đỉnh râu doji).
  - Volatility 75 D1 (tr.26): nến giảm, nến trắng rất nhỏ (doji), nến giảm. Hộp chữ nhật bao từ đỉnh râu doji xuống quanh thân c3; về sau râu một nến tăng chạm đúng đỉnh hộp rồi giá giảm ("SnR (kháng cự) giữ ở cây nến DOJI").
  - Volatility 75 D1 (tr.26) còn có Doji SnR tăng: nến trắng, doji, nến trắng; hộp bao cụm; râu dưới của nến sau đi vào hộp là điểm "BUY".
- **Số doji:** chữ nói "một nến Doji hoặc một nến thân nhỏ". Ví dụ GBPJPY tr.6 có 2 doji nhưng tài liệu gọi đó là Gap SnR có doji ở giữa. [không có luật cho 2 doji]
- **Doji SnR còn dùng làm tín hiệu xác nhận** ở khung nhỏ: BTC 1H (tr.11) "Doji SNR xuất hiện ngay tại điểm phá vỡ đường SNR".
- **Không có ngưỡng** cho "doji", "thân nhỏ", "động lực mạnh". [không có]

**2.5 Nến động lực (momentum candle) (tr.7, 9, 10, 15, 21)**
- Tr.21 [ghi rõ]: "một cây nến động lực (thân dài) bứt phá hoặc nhấn chìm (engulf) một mức SNR thường chứa đựng một khoảng trống giá GAP SNR bên trong nó".
- Tr.7: nến động lực HTF khi tinh chỉnh sẽ tạo ra các Gap SnR ở LTF.
- Tr.10: "Nến động lực giảm ở HTF" (D1) → "GAP giảm ở LTF" (4H) → 1H.
- Không có ngưỡng định lượng (không ATR, không tỷ lệ thân/biên độ). [không có]

**2.6 Lật mức: Flip, SBR, RBS và phá hợp lệ (tr.3–5, 7, 10)**
- SBR (Support Becomes Resistance): hỗ trợ bị phá thành kháng cự mới. [ghi rõ tr.7]
- RBS (Resistance Becomes Support): kháng cự bị phá thành hỗ trợ mới. [ghi rõ tr.7]
- **Phá vỡ hợp lệ = thân nến đóng cửa qua mức** [ghi rõ]:
  - "Bị phá vỡ hoàn toàn bằng thân nến (body of candlestick)" (tr.5, XAUUSD D1).
  - "Chừng nào giá chưa ĐÓNG CỬA ở mức thấp hơn mức kháng cự đã bị phá, … giá đang tiếp tục di chuyển theo xu hướng ban đầu" (tr.4, XAUUSD 1H).
- **Râu xuyên qua không tính là phá** [từ hình]:
  - XAUUSD 4H (tr.5): mức "Pháo đài (Hỗ trợ)" ≈ 2058.7 kẻ ở đáy thân một nến giảm. Mũi tên đỏ ở 4 đáy râu nằm dưới mức (có râu xuống ≈ 2052), thân vẫn đóng trên → mức còn. Sau khi thân nến đóng dưới, mức thành kháng cự; các mũi tên xanh ở đỉnh râu phía trên mức: ngày 05/01 râu lên ≈ 2063–2064 (**xuyên ~5 USD**), ngày 12/01 râu ≈ 2063, thân vẫn đóng dưới → vẫn là kháng cự.
  - XAUUSD 1H (tr.3): các chấm đỏ "Kháng cự mới" nằm ở đỉnh râu, hơi cao hơn đường SNR.
  - Hình mẫu tr.8–9: râu các nến kiểm tra chạm và hơi vượt đường, thân đóng ở phía giao dịch.
- **Biên độ vượt để tính là phá:** không có. [không có]
- "SNR Flipping Candle" / "Cây nến đảo chiều": nhãn gắn cho cây nến có thân đóng qua mức (tr.11, 12, 17, 18, 24, 25). Tài liệu không định nghĩa riêng; trên hình luôn là nến thân dài đóng hẳn sang phía bên kia mức.
- Tr.7 và tr.15: hai nến động lực ngược chiều liền kề ở HTF (một tăng, một giảm) sẽ tạo ra một "Flipped Gap" ở LTF. [ghi rõ]
- Hình tr.10 (4H, thị trường mua): thân nến nhịp hồi ở điểm B đóng **dưới** đường flipzone mà chuỗi A-B-C vẫn tiếp tục. Đây là mâu thuẫn với "đóng qua mức là phá" (xem mục 8).

**2.7 Vùng đảo chiều (Flipzone) và chuỗi điểm 1–4 (tr.8–9)**
- Định nghĩa bằng chữ [ghi rõ]: nến giảm phá một hỗ trợ yếu (weak support) và trở thành kháng cự mạnh ở phía bên kia điểm phá (SBR). Bên mua: nến tăng phá kháng cự yếu thành hỗ trợ mạnh (RBS).
- Hình LTF (tr.8, bán), đọc từ hình phóng to [từ hình]:
  1. SNR ORIGIN: điểm hình thành mức; giá chạm đúng đường.
  2. 1ST REJECT: giá chạm lần 1 → mức yếu đi.
  3. 2ND REJECT: giá chạm lần 2 → mức càng yếu.
  - Rồi một nến giảm lớn mở trên đường, đóng dưới đường (phá dứt khoát).
  4. Nến giảm kế tiếp mở ngay dưới giá đóng của nến phá (tạo một gap giảm LTF); **râu trên của nó chạm lại đường** = điểm 4 "REJECT OF STRONG RESISTANCE (USED FOR DIRECT ENTRY)". Mũi tên "Nến vào lệnh trực tiếp ngay sau khi giá phá vỡ mức SNR" chỉ vào chính nến này.
  - Sau đó hai lần giá hồi lên; râu trên của nến giảm chạm và **hơi vượt** đường, thân đóng dưới = "Các điểm vào lệnh xác nhận khi giá quay lại kiểm tra".
- Hình LTF (tr.9, mua) đối xứng: nến tăng phá lên, nến tăng kế tiếp có râu dưới chạm/hơi xuyên xuống đường = điểm 4 (vào trực tiếp).
- Vậy flipzone ở LTF = gap giữa nến phá và nến cùng màu ngay sau nó, nằm sát mức cũ.
- Hình tr.7 kẻ FLIPZONE tại các gap của chân sóng HTF trước đó (gap giảm tại `C` nến đen = `O` nến đen kế tiếp), sau khi chúng bị chân sóng ngược chiều phá.

**2.8 Fresh và "unfresh" (tr.4, 5, 8, 9)**
- FRESH SUPPORT: "Hỗ trợ chưa chạm / Hỗ trợ nguyên bản (vùng hỗ trợ mới chưa bị kiểm tra)" (tr.4). [ghi rõ]
- FRESH RESISTANCE: "kháng cự còn nguyên chưa bị phá" (tr.8). [ghi rõ]
- Chữ "unfresh" **không có** trong tài liệu. Suy ra: mức đã bị chạm ít nhất 1 lần kể từ khi hình thành hoặc kể từ lần lật gần nhất; tr.8–9 gọi đó là "WEAK" (yếu). [từ hình]
- "Sự thật quan trọng" (tr.4) [ghi rõ]: mức tồn tại bao lâu hay từng được dùng thế nào không quan trọng; miễn trạng thái hiện tại là FRESH thì dùng lại được. Người dịch ghi thêm: có thể dùng ngay ở lần chạm đầu sau khi mức lật.
- Tr.5 [ghi rõ]: một mức đã dùng nhiều lần vẫn có giá trị nếu bị thân nến phá hoàn toàn (vì sau khi phá nó lại là mức mới ở phía bên kia).
- XAUUSD 4H (tr.4) [sửa, từ hình]: kháng cự ≈ 1991.5 bị phá, được kiểm tra lại nhiều lần; sau đó một đường **mới** "FRESH SUPPORT" ≈ 1995.5 hình thành ngay trên và không bị chạm từ 22/11 tới 08/12 (~2,5 tuần). Ngày 08/12 một nến giảm lớn có râu chạm xuống đường, thân đóng trên; ngày 11/12 thân đóng dưới → "Hỗ trợ bị phá vỡ", rồi thành kháng cự mới.

**2.9 Các khái niệm khác**
- **Đảo chiều (Reversal, tr.6):** mức giữ được hoặc giá bị từ chối (reject) thì giao dịch bật ra khỏi mức. Ví dụ Classic A (bán) và Classic V (mua) trên GBPJPY.
- **Câu chuyện thị trường (Storyline, tr.7, 12, 17, 19):** hướng thị trường thể hiện qua chuỗi các lần lật mức.
  - "Bullish Storyline" XAUUSD (tr.19) gồm: gap tăng phá gap giảm; Doji SnR 4H đẩy giá qua gap giảm; giá bị từ chối ở gap khung tuần (Weekly GAP Reject).
  - Dấu hiệu đổi cấu trúc [ghi rõ tr.12 "Sự thật 2"]: gap mới đóng phá một gap ngược chiều cũ.
- **Gap nội bộ / gap ẩn (Internal GAP / Hidden Gap_SnR, tr.14, 15, 21)** [ghi rõ ý]:
  - Khi nến động lực phá qua SnR, tinh chỉnh (refine) nến đó xuống khung nhỏ hơn để tìm các gap ẩn trong toàn biên độ nến.
  - Sau khi phá, giá thường quay lại kiểm tra các gap này; chúng "đóng vai trò như các rào cản đối với hướng đi của thị trường".
  - Tr.14 D1: nhãn "INTERNAL GAP SNR" ở 4 mức bên trong một nến D1 tăng lớn; mục tiêu của lệnh bán (1.27463) trùng mức gap nội bộ thấp nhất.
  - Tr.15: "1ST GAP TAKEN OUT", "2ND GAP TAKEN OUT" = hai gap 1H bị giá đi xuyên qua.
- **BMS** (tr.10): chỉ là nhãn, không định nghĩa. Từ hình [từ hình]: đường BMS kẻ ở **đỉnh/đáy râu** của đáy/đỉnh gần nhất (4H bán: đáy râu nến giảm thứ 2 = `L(c1)` của gap giảm; D1 mua: đỉnh râu nến tăng = `H(c1)` của gap tăng; 4H mua: đỉnh râu tại điểm A). Nến sau đóng thân vượt đường đó. Có lẽ là "Break of Market Structure".
- **Nhãn chỉ có trong hình, không có định nghĩa:** chu kỳ A-B-C (tr.10, 16), "Pháo đài" (tr.5), "Mức tâm lý" (tr.5, XAUUSD 1980), PIN BAR (tr.13, gap tăng + gap giảm D1 gộp lại thành một pin bar ở đỉnh), WEEKLY REJECTION BLOCK (tr.15), London/New York Killzone (tr.14–15), New York Open (tr.23).
- **Không có trong tài liệu:** A-level/V-level như tên riêng (chỉ có hình chữ A/V); miss/hit; QM/quasimodo; compression; "unfresh"; lệnh chờ (limit) như một chữ; quản lý vốn; giờ phiên cụ thể.

## 3. Quy tắc xác định mức/vùng (tổng hợp từ tr.1–10, 12, 14, 19, 21)

1. Trên HTF (Monthly/Weekly/Daily/4H), kẻ mức tại `C(c1)` của mọi mẫu Classic A/V, Gap và Doji. Dùng thân nến, bỏ râu, kéo đường sang phải.
2. Theo dõi trạng thái từng mức:
   - Râu chạm mà thân không đóng qua: mức giữ. Mỗi lần chạm/bị từ chối, mức "yếu" thêm (tr.8–9).
   - Thân đóng ở phía bên kia: mức bị phá hợp lệ, đổi vai (SBR/RBS), trở thành FRESH ở phía mới.
3. Nếu nến phá là nến động lực HTF, tinh chỉnh nó xuống LTF theo chuỗi D1→4H→1H hoặc W→D1→4H (tr.10):
   - Các cặp nến cùng màu nằm trong khoảng thời gian của nến đó là Gap SnR ở LTF.
   - Gap nằm ngay tại mức bị phá là flipzone.
   - Các gap còn lại là gap nội bộ (rào cản, mục tiêu).
4. Với Gap SnR, lập vùng [LL, UL] theo bảng mục 2.3. Setup hỏng khi có giá đóng cửa vượt UL (với lệnh bán) hoặc xuống dưới LL (với lệnh mua).
5. Gap ở khung nhỏ được "neo" vào gap khung lớn (tr.12 "Sự thật 1": Gap 4H chuyển từ Gap D1). Ví dụ GBPUSD: gap 4H 1.28239 và Doji SnR 1H 1.28240 cùng một giá (tr.13, tr.15).
6. Thứ tự ưu tiên giữa các mức: **tài liệu không có quy tắc rõ ràng**. Chỉ có gợi ý:
   - Mức do nến động lực lật là mức "mạnh"; mức bị chạm nhiều lần là "yếu", dễ bị phá.
   - Ưu tiên mức trùng giữa nhiều khung (tr.12, tr.15, tr.19).
   - Ưu tiên setup cùng chiều câu chuyện thị trường (gap mới phá gap ngược chiều cũ: tr.12, 17, 18, 19).

## 4. Quy tắc vào lệnh

**4.1 Hai kiểu vào lệnh (tr.8–9, 20)**
- **Vào lệnh trực tiếp (Direct Entry)**, điểm 4: vào ở nến ngay sau nến phá, khi râu của nó quay lại mức vừa lật (tr.8–9). [tên ghi rõ; vị trí từ hình]
  - XAUUSD 1H (tr.20): biểu tượng bóng đèn = "Các điểm vào lệnh MUA trực tiếp". Hai bóng đèn đặt ngay dưới hai gap tăng 1H vừa hình thành (≈ 2357.8 và ≈ 2365), ở nến ngay sau gap.
- **Vào lệnh có xác nhận (Confirmation Entry)**: chờ giá quay lại kiểm tra mức sau đó. [tên ghi rõ; "xác nhận" chính xác là gì thì không có]
  - Từ hình, "xác nhận" gồm một trong các dạng:
    - Râu chạm (thường hơi xuyên) mức và thân đóng lại về phía giao dịch (tr.8–9, tr.20 dấu tích đỏ).
    - Có nến đổi hướng ở LTF và Doji SnR tại điểm phá (BTC 1H, tr.11).
    - Một mẫu Classic mới hình thành đúng tại mức: COQ 4H (tr.17), nến giảm rất lớn đóng đúng ở 0.000002208, nến tăng kế tiếp mở từ đó (chữ V mới) → "BUY (Điểm vào lệnh xác nhận)".
  - Tr.13: "SELL khi giá quay lại kiểm tra xác nhận (Confirmatory retest) vùng GAP_SNR tại 1.28239".

**4.2 Giá vào lệnh** [từ ví dụ]
- Trong mọi ví dụ có số, giá vào **đúng bằng giá của mức** (giá đóng c1 của mẫu), và lệnh khớp khi **râu** của nến kiểm tra chạm tới. Nghĩa là thực tế giống lệnh chờ (limit) tại mức; tài liệu không dùng chữ "lệnh chờ".
  - SELL 1 1.28239 (tr.13): khớp bởi râu trên của chính nến phá; râu chạm đúng 1.28239 rồi nến đóng ≈ 1.2785.
  - SELL 2 1.28066 (tr.14 4H): khớp bởi râu trên của nến ngay sau nến phá.
  - BUY 2357.808 (tr.20): râu nến kiểm tra xuống ≈ 2355, tức **xuyên ~2,8 USD** dưới mức rồi đóng lại phía trên.
  - SELL 2026.136 (tr.24): râu nến tăng chạm đúng mức (vòng tròn đỏ).
  - SELL 1.08991 (tr.23 EURUSD 30m): khớp bởi râu lúc mở phiên New York.
- Không có luật hủy lệnh chờ theo thời gian. [không có]

**4.3 Dừng lỗ (stop loss): không có quy tắc bằng chữ** [không có]
- Điều gần nhất là quy tắc hiệu lực: setup hỏng khi có giá đóng cửa qua UL/LL (tr.8–9).
- Bằng chứng từ từng ví dụ (giá đọc từ nhãn trên hình):

  | Trang | Lệnh | Điểm vào | Dừng lỗ | Khoảng cách | Dừng lỗ nằm ở đâu (đọc từ hình) |
  |---|---|---|---|---|---|
  | tr.6 | GBPJPY D1 bán Classic A | ở mức | ô hồng nhỏ trên mức | không ghi số | Ngay trên vùng đỉnh râu của mẫu |
  | tr.6 | GBPJPY 4H mua Classic V (2 lệnh) | ở mức | ô hồng nhỏ dưới mức | không ghi số | Nhỏ; **không** bao hết râu dài của các nến trước (lệnh thứ hai) |
  | tr.12 | GBPUSD 4H bán | 1.28068 | 1.28232 | 15.6 pip (nhãn) | Ở mức gap giảm 4H phía trên (mép thân), không ở đỉnh râu |
  | tr.13 | GBPUSD 4H bán (SELL 1) | 1.28239 | 1.28310 | 6.7 pip (nhãn) | ≈ đỉnh râu trên của nến 2 của gap = **UL** (+~0,5 pip) |
  | tr.14 | GBPUSD 4H bán (SELL 2) | 1.28066 | 1.28195 | 13.1 pip | ≈ giá mở của nến phá = đỉnh thân nến hồi cuối; râu các nến hồi (~1.2822) cao hơn dừng lỗ |
  | tr.14 | GBPUSD 1H bán | ≈ 1.28193–1.28200 | 1.28234 | 4.1 pip | Trên mức gap nội bộ 1H 1.2820 |
  | tr.15 | GBPUSD 1H bán Doji SnR | 1.28240 | 1.28298 | 5.8 pip | ≈ đỉnh hộp Doji SnR (vùng đỉnh râu doji) |
  | tr.16 | BTC 1H bán (2 lệnh) | 73,158.48 / 72,267.14 | 73,422.58 / 72,586.26 | 264 / 319 USD | Trên cặp đường gap nhỏ ở mức vào |
  | tr.20 | XAUUSD 1H mua | 2357.808 | 2351.670 | 6.14 USD (61 pip) | Dưới đáy râu nến kiểm tra (≈ 2355) thêm ~3,3 USD; không nói neo vào đâu |
  | tr.21 | XAUUSD D1 bán | ≈ 1942.3 | ≈ 1954 (đọc trục, độ tin thấp) | ~12 USD | Đỉnh ô hồng trên mức |
  | tr.23 | EURUSD 30m bán | 1.08991 | 1.09022 | 3.1 pip | Ngay trên đỉnh cụm nến tạo mức |
  | tr.23 | XAUUSD 4H mua | 2251.292 | 2246.793 | 4.5 USD theo giá; nhãn đo ghi 4.369 ("44 pips") | Ngay dưới mức |
  | tr.23 | EURUSD 1H bán | ≈ 1.0959 | 1.09604 | 1.3 pip | Ngay trên mức "4HR SNR" |
  | tr.24 | XAUUSD 1H bán | 2026.136 | 2028.014 | 1.88 USD (18.8 pip) | Trên mức gap 1H; có thể là đỉnh râu nến 1 của gap, hình quá mờ để chắc |
  | tr.25 | BONK D1 mua | 0.000011682 | 0.000011012 | 5,7% | Dưới đường FlippedSNR và dưới các đáy râu gần đó |

- Kết luận: dừng lỗ luôn đặt **ngay sau mức hoặc sau biên vùng** (UL/LL, đỉnh hộp doji, mức thân kế tiếp), không theo ATR hay số cố định. Chỗ neo khác nhau giữa các ví dụ.

**4.4 Chốt lời (take profit): không có quy tắc bằng chữ** [không có]
- Chỉ có một nhãn: tr.13 "1ST TP @ 1R:5R (35)" → mục tiêu đầu tiên = 5 lần rủi ro. Số đo thực: 35.1 / 6.7 ≈ 5,2 lần. Chữ "1ST TP" gợi ý chốt nhiều phần, không nói cách làm.
- Tr.14 D1: lệnh bán 1.28066 đo tới 1.27463 = đúng mức gap nội bộ thấp nhất của nến D1 tăng trước đó. Gợi ý: gap nội bộ HTF là mục tiêu. [từ hình]
- Tr.14 4H: ô xanh dừng ở 1.27720 (~2,6 lần rủi ro) nhưng số đo ghi 60.3 pip (tới 1.27463). Hai số này không khớp nhau.
- Các ví dụ khác đo tới đỉnh/đáy cực trị nhìn thấy sau đó (nhìn lại quá khứ), ví dụ tr.20 tới 2418.8 = đỉnh cây nến tăng vọt ngày 19/04; tr.23 XAUUSD tới ≈ 2365.6.
- Tỷ lệ lời/lỗ trong ví dụ trải từ ~2,6 tới ~26 lần (xem mục 6). Không dùng được làm luật.

**4.5 Giờ giao dịch**
- Có nhãn "LONDON KILLZONE", "NEW YORK KILLZONE" (tr.14–15), "NEW YORK OPEN" (tr.23) ngay tại điểm vào. Không có giờ cụ thể, không có luật bắt buộc. [không có]

## 5. Quan hệ khung thời gian (quy trình HTF → LTF)

Quy trình rút ra từ tr.10–20 (các bước có trong ví dụ; chữ không liệt kê thành quy trình):
1. **Khung lớn (M/W/D1)** — tìm nến động lực vừa phá một mức (lật mức) để biết câu chuyện thị trường. Ví dụ COQ (tr.16–17): nến tháng tăng phá kháng cự; BTC (tr.15): cặp nến D1 tăng + giảm liền nhau ("Hidden Bearish Gap").
2. **Khung D1/4H** — kẻ mức vừa lật và các gap tạo ra. Gap 4H được neo vào gap D1 (tr.12 "Sự thật 1").
3. **Kiểm tra đổi cấu trúc** — gap mới đóng phá gap ngược chiều cũ (tr.12 "Sự thật 2", tr.18, tr.19).
4. **Tinh chỉnh** nến động lực xuống khung nhỏ hơn (D1→4H→1H, W→D1→4H; tr.10) để tìm flipzone tại mức bị phá và các gap nội bộ.
5. **Vào lệnh ở khung nhỏ** tại flipzone: trực tiếp hoặc có xác nhận (mục 4.1); ví dụ trùng giờ London/New York.
6. **Dừng lỗ ở khung nhỏ** sau vùng → rủi ro rất nhỏ; mục tiêu hướng tới gap nội bộ HTF hoặc mức HTF kế tiếp.
- Bằng chứng lợi ích của khung nhỏ:
  - Tr.14: cùng một ý bán GBPUSD, ở 4H cần dừng lỗ 13.1 pip; tinh chỉnh xuống 1H chỉ cần 4.1 pip, lãi 73.4 pip.
  - Tr.23: "tinh chỉnh biểu đồ 4H xuống các khung thời gian nhỏ hơn để đạt được mức rủi ro cực kỳ thấp"; EURUSD 1H rủi ro 1.3 pip tại mức "4HR SNR".
  - Tr.14 còn nói: "Quay trở lại khung thời gian Ngày (Daily TF) để có cái nhìn tổng quan về hướng của xu hướng và các chướng ngại vật".
- **Các chuỗi khung trong ví dụ:**

  | Ví dụ | Khung lớn | Khung vào lệnh |
  |---|---|---|
  | BTC (tr.11) | D1 + 4H | 1H |
  | GBPUSD (tr.12–15) | D1 | 4H, tinh chỉnh tiếp xuống 1H |
  | BTC (tr.15–16) | W1 → D1 → 4H → 2H | 1H |
  | COQ (tr.16–18) | M → W → D1 → 4H | 1H |
  | XAUUSD (tr.18–20) | W1 + 4H | 1H |
  | EURUSD (tr.23) | 4H SnR | 1H; một ví dụ khác vào ở 30m |

- Hệ số giữa hai khung thường khoảng ×4 đến ×6 (4H→30m là ×8).
- Tài liệu không nhắc M1/M5/M15.

## 6. Mọi con số trong tài liệu

**Quy ước pip**
- Vàng: 1 pip = 0.1 USD, suy ra từ số đo trên hình: 61.017 USD ghi "610 pips"; 114.276 USD ghi "1,143 pips"; 4.369 USD ghi "44 pips"; 9.96 USD ghi "100 PIPS".
- EURUSD/GBPUSD: 1 pip = 0.0001. GBPJPY: 1 pip = 0.01 (13.284 JPY = "1,328 pips").

**Số nến trong mỗi mẫu**
- Classic: 2 nến ngược màu.
- Gap: 2 nến cùng màu (có ví dụ xen 1–2 doji ở giữa, tr.6).
- Doji SnR: 3 nến (có ví dụ 2 doji nhưng được gọi là gap, tr.6).
- Mức "yếu" trong hình: bị chạm 2 lần trước khi bị phá.

**Các lệnh ví dụ** [sửa và bổ sung]

| Trang | Cặp/khung | Hướng | Điểm vào | Dừng lỗ | Kết quả | Lời/lỗ (lần rủi ro) |
|---|---|---|---|---|---|---|
| tr.6 | GBPJPY D1 | Bán | Classic A | ô nhỏ | +1,328 pip | — |
| tr.6 | GBPJPY 4H | Mua ×2 | Classic V | ô nhỏ | +394 / +382 pip | — |
| tr.12 | GBPUSD 4H | Bán | 1.28068 | 1.28232 (15.6 pip) | tới 1.27450 (60.5 pip) | ≈ 3,9 |
| tr.13 | GBPUSD 4H | Bán | 1.28239 | 1.28310 (6.7 pip) | TP1 1.27890 (35.1 pip), nhãn "1R:5R" | ≈ 5,2 |
| tr.14 | GBPUSD 4H/D1 | Bán | 1.28066 | 1.28195 (13.1 pip) | 60.3 pip (tới 1.27463) | ≈ 4,6 |
| tr.14 | GBPUSD 1H | Bán | ≈ 1.2819–1.2820 | 1.28234 (4.1 pip) | +73.4 pip; lệnh New York +92.2 pip | ≈ 17,9 |
| tr.15 | GBPUSD 1H Doji SnR | Bán | 1.28240 | 1.28298 (5.8 pip) | +77 pip; +92.3 pip (tới 1.27312) | ≈ 13 / 15,9 |
| tr.16 | BTC 1H | Bán ×2 | 73,158.48; 72,267.14 | 73,422.58; 72,586.26 | tới 68,569.74 | ≈ 17 (lệnh 1) |
| tr.17 | COQ 4H | Mua | 0.000002208 | không ghi | — | — |
| tr.20 | XAUUSD 1H | Mua | 2357.808 | 2351.670 (6.14 USD) | +61.017 USD ("610 pips trong 2 ngày") | ≈ 9,9 |
| tr.21 | XAUUSD D1 | Bán | ≈ 1942.3 | ≈ 1954 (độ tin thấp) | tới 1889.223 | ≈ 4,4 |
| tr.22 | EURUSD 30m | Mua | ≈ 1.0180 | không ghi | +100 pip | — |
| tr.23 | EURUSD 30m | Bán | 1.08991 | 1.09022 (3.1 pip) | +77.1 pip; nhãn ghi "R-R = 1R:5.2R" | ≈ 24,9 theo số đo |
| tr.23 | XAUUSD 4H | Mua | 2251.292 | 2246.793 (đo 4.369 USD) | +114.276 USD ("1,143 pips", "1R:26R") | ≈ 26 |
| tr.23 | EURUSD 1H | Bán | ≈ 1.0959 | 1.09604 (1.3 pip) | +95.2 pip | ≈ 73 |
| tr.24 | XAUUSD 1H | Bán | 2026.136 | 2028.014 (1.88 USD) | −9.96 USD ("100 PIPS") | ≈ 5,3 |
| tr.25 | BONK D1 | Mua | 0.000011682 | 0.000011012 (5,7%) | ROI 120.79% và 315.88% | ≈ 21 / 55 |

- Tr.23 có một ô tính tiền (20 vị thế, 80 × 20 = 1600, rủi ro 20 pip, 0.5 lot, 11600$, …). Các số trong đó không khớp nhau; là quảng cáo, không phải quy tắc.
- Tài liệu không có ngưỡng ATR, tỷ lệ thân nến, quy tắc quản lý vốn hay giờ phiên.
- Mọi ví dụ đều là ví dụ thắng, chọn sau khi đã biết kết quả. Không có thống kê, không có lệnh thua.

## 7. Luật có thể viết thành mã

**7.1 Bảng luật** (công thức theo O/H/L/C của c1, c2, c3; `lvl` = giá mức)

| # | Luật | Công thức | Nguồn |
|---|---|---|---|
| R1 | Vai của một nến | Tăng: hỗ trợ `O`, kháng cự `C`. Giảm: kháng cự `O`, hỗ trợ `C` | Tài liệu ghi rõ (tr.1–2) |
| R2 | Classic hỗ trợ (V) | `C(c1)<O(c1)` và `C(c2)>O(c2)`; `lvl = C(c1)`; bỏ qua `O(c2)−C(c1)` | Tài liệu ghi rõ (tr.1–3) |
| R3 | Classic kháng cự (A) | `C(c1)>O(c1)` và `C(c2)<O(c2)`; `lvl = C(c1)` | Tài liệu ghi rõ (tr.2–3) |
| R4 | Gap giảm | `C(c1)<O(c1)` và `C(c2)<O(c2)`; `lvl = C(c1)`; vai = kháng cự (fresh) | Mức: ghi rõ bằng hình (tr.3, 8) |
| R5 | Vùng gap giảm | `UL = H(c2)`, `LL = L(c1)` | Tên UL/LL ghi rõ; vị trí suy ra từ hình (tr.8) |
| R6 | Gap tăng | `C(c1)>O(c1)` và `C(c2)>O(c2)`; `lvl = C(c1)`; vai = hỗ trợ (fresh) | Mức: ghi rõ bằng hình (tr.3, 9) |
| R7 | Vùng gap tăng | `UL = H(c1)`, `LL = L(c2)` | Tên ghi rõ; vị trí suy ra từ hình (tr.9) |
| R8 | Gap có doji giữa | c1 và cN cùng màu, giữa là 1–2 nến doji; kẻ 2 đường `C(c1)` và `O(cN)` | Suy ra từ hình (tr.6) |
| R9 | Doji SnR tăng | c1 tăng "mạnh"; c2 doji/thân nhỏ; c3 tăng "mạnh" và `C(c3) > H(c2)`; `lvl = O(c3)` (≈ `C(c1)` ≈ thân c2) | Chuỗi 3 nến: ghi rõ (tr.19). `lvl = O(c3)` và "trên doji = trên đỉnh râu doji": suy ra từ hình (tr.19). Ngưỡng "mạnh", "doji": Không có — cần đo |
| R10 | Doji SnR giảm | Đối xứng R9: c1 giảm, c2 doji, c3 giảm, `C(c3) < L(c2)`; `lvl = O(c3)` | Suy ra từ hình (tr.3, 15, 26), không có chữ |
| R11 | Vùng Doji SnR | Giảm: `[lvl, H(c2)]`; tăng: `[L(c2), lvl]` | Suy ra từ hộp trong hình (tr.15, 26). Với doji râu rất dài (tr.19) vùng rất rộng — Không có — cần đo |
| R12 | Phá hợp lệ | Kháng cự bị phá khi `C > lvl`; hỗ trợ bị phá khi `C < lvl`. Râu vượt không tính | Tài liệu ghi rõ (tr.4, 5). Biên độ vượt tối thiểu: Không có — cần đo |
| R13 | Lật vai | Sau R12: hỗ trợ → kháng cự (SBR), kháng cự → hỗ trợ (RBS); trạng thái = fresh | Tài liệu ghi rõ (tr.3, 7) |
| R14 | Setup gap hỏng | Bán hỏng khi có `C > UL`; mua hỏng khi có `C < LL` | Tài liệu ghi rõ (tr.8–9). Giá đóng của khung nào: Không có — cần chọn |
| R15 | Fresh | Chưa có nến nào chạm mức kể từ lúc tạo hoặc lúc lật | Ý ghi rõ (tr.4, 8). "Chạm" = `H ≥ lvl − tol` (kháng cự) / `L ≤ lvl + tol` (hỗ trợ): `tol` Không có — cần đo |
| R16 | Mức yếu | Số lần chạm ≥ 1 (hình vẽ 2 lần) trước khi bị phá | Suy ra từ hình (tr.8–9) |
| R17 | Flipzone | Nến phá n0 (thân đóng qua `lvl`) và nến n1 cùng màu ngay sau → gap `C(n0)`; vùng theo R5/R7; nằm sát `lvl` | Suy ra từ hình (tr.8–10) |
| R18 | Vào trực tiếp | Lệnh chờ tại `lvl` (hoặc tại mức gap của flipzone) trên nến ngay sau nến phá; khớp khi râu quay lại | Tên ghi rõ; cách khớp suy ra từ hình (tr.8, 9, 20) |
| R19 | Vào có xác nhận | Lần kiểm tra sau: râu chạm `lvl` (có thể xuyên nhẹ) và thân đóng về phía giao dịch; hoặc Classic/Doji mới tại `lvl` ở khung nhỏ | Tên ghi rõ; điều kiện: suy ra từ hình (tr.8, 11, 17, 20). Luật chính xác: Không có — cần đo |
| R20 | Giá vào | `entry = lvl` (giá mức, không phải giá đóng nến xác nhận) | Suy ra từ ví dụ (tr.13, 14, 20, 23, 24) |
| R21 | Dừng lỗ | Không có luật. Ví dụ: tại UL/LL (tr.13), tại mức thân kế tiếp (tr.12, 14), tại đỉnh hộp doji (tr.15) | Không có — cần đo |
| R22 | Chốt lời | Không có luật. Ví dụ: TP1 = 5R (tr.13); gap nội bộ HTF (tr.14) | Không có — cần đo |
| R23 | Nến động lực | "Thân dài" phá hoặc nhấn chìm một mức | Ý ghi rõ (tr.21); ngưỡng Không có — cần đo |
| R24 | Gap nội bộ | Các gap (R4/R6) của khung nhỏ trong khoảng thời gian `[open_time, close_time)` của nến động lực HTF | Ý ghi rõ (tr.21); cách lấy nến LTF suy ra |
| R25 | Đổi cấu trúc | Một gap mới có nến đóng vượt qua `lvl` của một gap ngược chiều cũ | Tài liệu ghi rõ (tr.12 "Sự thật 2") |
| R26 | Flipped gap từ cặp HTF | Hai nến động lực HTF ngược chiều liền nhau → vùng gap đã lật ở LTF | Tài liệu ghi rõ (tr.7, 15) |
| R27 | BMS | Đỉnh/đáy râu gần nhất; bị phá khi thân đóng vượt | Không có định nghĩa — suy ra từ hình (tr.10) |

**7.2 Đề xuất cho các chỗ "không có"** (giữ từ bản trước; mọi con số là ĐỀ XUẤT, không phải luật của tài liệu, phải đo)
- **a. Nến động lực:** thân ≥ 1,5 × ATR(14) cùng khung, và thân ≥ 60% biên độ nến. (SPEC 22.4 đang thử 0,6 × ATR14.)
- **b. Doji / thân nhỏ:** thân ≤ 25% biên độ nến. (SPEC 22.4 đang thử thân ≤ 0,3 × ATR14 và ≤ 50% biên độ.)
- **c. Gap có ý nghĩa:** chỉ nhận cặp cùng màu khi có ít nhất một nến là nến động lực, hoặc cặp nằm trong nến động lực HTF. Nếu không lọc, cặp nến cùng màu nào cũng thành mức. Lưu ý tr.18 có gap mà nến 1 gần như doji.
- **d. Chạm/kiểm tra lại:** giá cao nhất (khi bán) hoặc thấp nhất (khi mua) đi vào khoảng mức ± 0,1 × ATR, hoặc đi vào vùng [LL, UL]. Tham khảo độ xuyên của râu trong ví dụ vàng: ~2 USD (tr.19 4H), ~2,8 USD (tr.20 1H), ~5 USD (tr.5 4H).
- **e. Từ chối (xác nhận):** nến kiểm tra chạm vùng rồi đóng về phía giao dịch so với mức. Hoặc: có mẫu Classic/Gap/Doji cùng chiều ở khung nhỏ hơn tại mức.
- **f. Vào trực tiếp:** đặt lệnh chờ tại mức ngay khi nến phá đóng cửa. Hủy nếu có giá đóng cửa vượt UL/LL, hoặc sau khoảng 12 nến mà chưa khớp.
- **g. Mức yếu:** bị chạm ≥ 2 lần trước khi bị phá. Dùng làm bộ lọc tuỳ chọn.
- **h. UL/LL cho mức Classic:** tài liệu chỉ định nghĩa cho Gap. Đề xuất: chữ V → LL = thấp nhất của 2 nến; chữ A → UL = cao nhất của 2 nến.
- **i. Dừng lỗ:** ngoài UL/LL (hoặc đỉnh/đáy râu doji), cộng chênh lệch giá (spread) và đệm 0,05–0,1 × ATR. Khớp ví dụ tr.13.
- **j. Chốt lời:** phần 1 ở 5R như tr.13; phần còn lại ở gap nội bộ HTF hoặc mức fresh đối diện gần nhất.
- **k. Hướng HTF:** tăng nếu lần lật gần nhất trên H4 (hoặc D1) là kháng cự bị thân đóng vượt lên và chưa bị phá ngược lại; giảm thì ngược lại.
- **l. Tinh chỉnh:** lấy các nến LTF trong khoảng thời gian của nến động lực HTF; gap gần mức HTF bị phá nhất là flipzone.
- **m. Khung cho M1/M5:** H4 cho hướng, H1 hoặc M15 để tìm mức, M5/M1 để vào lệnh.
- **n. Killzone:** cần chủ bot cho giờ. Quy ước phổ biến bên ngoài tài liệu: London 07–10 UTC, New York 12–15 UTC.
- **o. Pip vàng:** 0.1 USD (10 point với báo giá 2 chữ số thập phân). Cần đối chiếu broker.
- **p. Pin bar:** râu ≥ 2/3 biên độ nến.
- **q. BMS:** đỉnh/đáy swing gần nhất, xác nhận khi thân đóng vượt.

## 8. Điểm mơ hồ / mâu thuẫn cần đo hoặc hỏi chủ bot

1. **Ngưỡng hủy setup mâu thuẫn nhau.**
   - Tr.4: xu hướng còn khi chưa có giá đóng qua chính đường mức.
   - Tr.8–9: chỉ hủy khi giá đóng qua UL/LL (rộng hơn đường mức).
   - Hình tr.10 (4H mua): thân nến ở điểm B đóng dưới flipzone mà chuỗi vẫn tiếp tục.
   - Hình tr.19 (4H): sau khi mức ≈ 2342 lật lên, có thân đóng dưới mức ~14 USD; tác giả coi đó là một lần lật mới (gap tăng phá gap giảm), không nói rõ mức cũ hỏng hay chưa.
   → Đo cả hai ngưỡng: đường mức và UL/LL.
2. **Dung sai chạm và độ xuyên của râu.** Râu kiểm tra thường xuyên qua mức: vàng 1H ~2,8 USD (tr.20), vàng 4H ~2–5 USD (tr.5, tr.19), EURUSD 30m ~6–7 pip (tr.22, hai ngôi sao). Tài liệu không cho số → cần đo phân phối độ xuyên.
3. **Chỉ vào ở lần chạm đầu, hay nhiều lần?** Tr.4 nói dùng khi còn fresh; nhưng tr.4 (4H) nói mức mới hợp lệ "sau nhiều lần kiểm tra lại", và tr.22 có "Kiểm tra lại nhiều lần cho Sell nhiều lần".
4. **Vào trực tiếp, chờ xác nhận, hay cả hai?** "Xác nhận" chính xác là gì (mục 4.1)?
5. **Gap có cần lọc không?** Mọi cặp nến cùng màu đều là Gap, hay chỉ các cặp trong chân sóng động lực? Tr.20: ba nến trắng liền nhau → hai gap đều được đánh dấu FRESH SUPPORT.
6. **Gap có khoảng hở giá** (c2 mở khác `C(c1)`): tr.2 bảo luôn dùng `C(c1)`. Có cần coi đoạn giữa `C(c1)` và `O(c2)` là một vùng không? [không có]
7. **Doji SnR:** ngưỡng doji/thân nhỏ/động lực; 1 hay 2 doji; "đóng trên doji" là trên thân hay trên đỉnh râu; vùng và dừng lỗ khi doji có râu rất dài (tr.19, ~31 USD).
8. **Dừng lỗ/chốt lời:** tài liệu không có quy tắc. Các ví dụ neo dừng lỗ vào chỗ khác nhau (mục 4.3). Chữ "1ST TP" gợi ý chốt nhiều phần nhưng không nói cách làm.
9. **Khung thời gian:** EA chạy M1/M5, tài liệu không có ví dụ dưới 30 phút. Cần chọn cặp HTF/LTF.
10. **Giá đóng của khung nào** dùng để hủy setup gap: khung của gap hay khung vào lệnh?
11. **Nhãn không có định nghĩa:** BMS, A-B-C, killzone, pin bar, mức tâm lý, weekly rejection block, "pháo đài". Có dùng không?
12. **Pip vàng = 0.1 USD** có khớp broker không?
13. **Số liệu không khớp trong hình:**
    - Tr.23 EURUSD 30m: nhãn "R-R = 1R:5.2R" nhưng 77.1 / 3.1 ≈ 24,9. Ảnh phóng to đọc rõ "5.2R" nên nhãn sai, không phải do mờ.
    - Tr.23 XAUUSD 4H: hai nhãn giá cách nhau 4.499 USD nhưng thước đo ghi 4.369 ("44 pips").
    - Tr.12 4H: giá 1.28068 → 1.28232 là 16.4 pip, nhãn đo ghi 15.6 pip.
    - Tr.14 4H: ô xanh dừng ở 1.27720 nhưng số đo 60.3 pip tới 1.27463.
    - Tr.23 EURUSD 1H: ô xanh dừng ở 1.08809 nhưng số đo 95.2 pip.
14. **Lỗi dịch / lỗi nhãn:**
    - Tr.12: nhãn trên hình "Khoảng trống giá giảm 4H phá vỡ khoảng trống giá giảm", còn "Sự thật 2" cùng trang nói phá gap **tăng** cũ. Hình có nhãn "Khoảng trống giá tăng 4H" ở ngay trước → "Sự thật 2" đúng, nhãn hình dịch sai.
    - Tr.10: nhãn "LTF BEARISH GAP_SNR" trong sơ đồ thị trường mua, đặt cạnh gap tăng D1; không rõ chỉ vào nến nào.
    - Tr.16: hình COQ ghi "1ST FEB 2023", trục tuần tr.17 ghi năm 2026, trong khi chữ nói COQ niêm yết trên KuCoin ngày 01/12/2023. Nhãn năm trên hình không tin được.
    - Tr.21: ảnh XAUUSD 4H là hai ảnh chồng lên nhau, khó nối "BULLISH GAP" với điểm BUY.
15. **Một đường có thể kẻ ở râu:** tr.23 XAUUSD 4H có một đường xám không nhãn ≈ 2266, nằm gần đỉnh râu các nến ngày 01/04 chứ không ở mép thân. Không có nhãn nên không coi là luật; chỉ ghi lại để đối chiếu.
16. **Thiếu quy tắc:** không có cách chọn giữa nhiều mức gần nhau, không giới hạn số lệnh, không quy định mức cũ bao lâu thì bỏ, không có quản lý vốn.

## 9. Các ví dụ quan trọng nhất

1. **Tr.1–3:** sơ đồ cốt lõi.
   - Mức nằm ở `C(c1)`, dùng thân nến; râu có chấm đánh dấu nhưng nằm ngoài đường.
   - Sơ đồ "3 TYPES OF SNR" có nhãn SUP./RES. cho gap, và hình Doji SnR tăng/giảm.
   - XAUUSD 1H: hỗ trợ thành kháng cự; các lần kiểm tra lại đều là râu chạm và hơi vượt mức.
2. **Tr.4 (XAUUSD 1H/4H):** kháng cự thành hỗ trợ nhiều lần, kèm "chưa đóng cửa dưới thì xu hướng còn"; FRESH SUPPORT không bị chạm ~2,5 tuần rồi bị thân phá và thành kháng cự.
3. **Tr.5–6:**
   - XAUUSD D1: mức 1980 (mức tâm lý) bị chạm nhiều lần, bị thân phá hợp lệ, rồi thành kháng cự.
   - XAUUSD 4H: râu vượt lên ~5 USD nhưng thân không đóng qua.
   - GBPJPY: giao dịch đảo chiều tại Classic A/V.
   - Gap giảm XAUUSD D1 và gap có 2 doji GBPJPY D1.
4. **Tr.8–9:** UL/LL, điểm 1–4, hai kiểu vào lệnh, quy tắc đóng cửa qua UL/LL.
5. **Tr.10:** nến động lực HTF tách thành gap LTF và flipzone, có BMS và chu kỳ A-B-C.
6. **Tr.11 (BTC):** hỗ trợ Classic D1 bị nến lật phá → gap giảm 4H → vùng 1H với Doji SnR làm xác nhận.
7. **Tr.12–15 (GBPUSD):** bộ ví dụ đủ điểm vào, dừng lỗ, chốt lời.
   - Bán 1.28239, dừng lỗ ≈ UL (6.7 pip), TP1 5R.
   - Tinh chỉnh xuống 1H: dừng lỗ 4.1 pip; Doji SnR 1H ở đúng giá gap 4H.
   - Mục tiêu 1.27463 = gap nội bộ thấp nhất của nến D1.
8. **Tr.18–20 (XAUUSD, gần EA nhất):**
   - 4H: gap giảm 2369 bị gap tăng phá; gap tăng mới 2356; Doji SnR 4H ≈ 2357; gap khung tuần bị râu chạm (Weekly Reject).
   - 1H: hai gap tăng (≈ 2357.8 và ≈ 2365) là FRESH SUPPORT; bóng đèn = vào trực tiếp, dấu tích = vào có xác nhận.
   - Mua 2357.808, dừng lỗ 2351.670, lãi 61 USD.
9. **Tr.21:** gap ẩn trong nến động lực (XAUUSD 4H, COQ 1H); gap D1 bị lật thành kháng cự trên XAUUSD, cho nhiều lệnh bán.
10. **Tr.23–24:**
    - XAUUSD 4H: #FlippedSNR, rủi ro ~4.4 USD, lãi 114 USD.
    - EURUSD 1H: bán tại mức "4HR SNR", rủi ro 1.3 pip.
    - XAUUSD 1H: gap 1H bị phá ("1-HOUR GAP SNR BO"), bán khi giá quay lại, dừng lỗ 1.88 USD, lãi ~10 USD.
    - Nhãn "SNR Flipping Candle" trên EURUSD D1 và XAUUSD 4H.

## 10. Tóm tắt từng trang (tr.1–27)

- **tr.1** — Tiêu đề, định nghĩa hỗ trợ/kháng cự. Sơ đồ "SNR LEVELS": nến đen (OPEN = kháng cự ở đỉnh thân, CLOSE = hỗ trợ ở đáy thân) và nến trắng (OPEN = hỗ trợ, CLOSE = kháng cự). Hình nhỏ: nến đen c1 đóng thấp, nến trắng c2 mở tại đó; đường "SNR" ở mép thân; chấm xanh ở đáy râu dài của c1 (râu nằm ngoài đường).
- **tr.2** — Lưu ý: c2 mở cao/thấp hơn `C(c1)` không quan trọng; luôn kẻ `C(c1)` ngang qua `O(c2)`. Hình kháng cự: c1 trắng đóng cao, c2 đen mở tại đó; chấm đỏ ở đỉnh râu, đường ở đỉnh thân. GBPJPY 4H hai ảnh: biểu đồ đường (chữ V = hỗ trợ, chữ A = kháng cự) và biểu đồ nến (nhãn OPEN/CLOSE, RESISTANCE/SUPPORT ở mép thân). Liệt kê 3 loại: Classical, GAP, Doji.
- **tr.3** — Sơ đồ "3 TYPES OF SNR": Classic Support/Resistance, Bearish/Bullish Gap (nhãn SUP./RES.), Bullish/Bearish Doji SNR. Câu: mức bị phá thì giao dịch ngược lại — chiến lược đảo vai (flipping). XAUUSD 1H OANDA (15–22/01/2024): hỗ trợ ≈ 2044 (chữ V) bị phá thành kháng cự (SBR); hỗ trợ ≈ 2037.8 bị nến giảm lớn phá, về sau các râu ngày 19 và 22/01 chạm hơi vượt đường ("Kháng cự mới").
- **tr.4** — XAUUSD 1H (22–27/12/2023): ba mức Classic A (≈ 2053, 2057.5, 2062) bị phá lên thành "Hỗ trợ mới"; các lần kiểm tra là râu chạm; câu "SỰ THẬT: chừng nào giá chưa đóng cửa dưới…". XAUUSD 4H (17/11–13/12/2023): kháng cự ≈ 1991.5 thành hỗ trợ sau nhiều lần kiểm tra; FRESH SUPPORT ≈ 1995.5 không bị chạm ~2,5 tuần, rồi bị thân phá, "hỗ trợ cũ đã dùng thành kháng cự mới". "Sự thật quan trọng": mức ở trạng thái FRESH thì dùng lại được.
- **tr.5** — XAUUSD D1 (03–10/2023): mức 1980 bị chạm vài lần, bị phá hợp lệ bằng thân, thành "Kháng cự mới bị chạm vài lần", ghi "Mức / Mức tâm lý". Câu "pháo đài". XAUUSD 4H (25/12/2023–17/01/2024): "Pháo đài (Hỗ trợ)" ≈ 2058.7 ở đáy thân nến giảm; 4 mũi tên đỏ ở các đáy râu; sau khi thân phá, "Khu vực đảo chiều" và "Mức kháng cự tiềm năng" với 3 mũi tên xanh ở các đỉnh râu vượt mức tới ~5 USD.
- **tr.6** — Mức giữ được thì giao dịch đảo chiều. GBPJPY D1 bán tại Classic A, +1,328 pip; GBPJPY 4H mua 2 lần tại Classic V, +394 và +382 pip; ô dừng lỗ nhỏ. XAUUSD D1 (08–09/2022) gap giảm (có 1 nến nhỏ ở giữa) giữa xu hướng giảm, đường "GAP SNR" ở giá đóng nến giảm đầu. GBPJPY D1 gap tăng có 2 doji giữa, 2 đường tại `C` nến đầu và `O` nến sau, râu nến kiểm tra xuyên qua cả hai đường, dấu tích đỏ.
- **tr.7** — "Flipping the SNRs": định nghĩa SBR, RBS, storyline. Sơ đồ #Flipped_SNR: Monthly nến giảm + nến tăng → Weekly các gap giảm bị nến tăng phá, FLIPZONE ở mức các gap; bên bán đối xứng. Câu: nến động lực HTF tinh chỉnh ra Gap SnR LTF; hai nến động lực đối lập tạo gap đã lật ở LTF.
- **tr.8** — "Dynamics of GAP_SnR" (gap giảm HTF): đường "SNR (SUPPORT)" ở `C(c1)`, UL ở đỉnh râu c2, LL ở đáy râu c1, "FRESH RESISTANCE"; lệnh bán còn giá trị khi không có giá đóng trên UL. Hình LTF: điểm 1–3 chạm hỗ trợ, nến giảm lớn phá, điểm 4 = râu nến kế tiếp chạm lại (vào trực tiếp), rồi các lần kiểm tra xác nhận. Định nghĩa Flipzone (SBR).
- **tr.9** — Đối xứng tr.8 cho gap tăng: "SNR ORIGIN (RESISTANCE)" ở `C(c1)`, UL = đỉnh râu c1, LL = đáy râu c2, "FRESH SUPPORT"; lệnh mua còn giá trị khi không có giá đóng dưới LL. Hình LTF điểm 1–4, "Vào lệnh trực tiếp", "Các điểm vào lệnh xác nhận". Câu: nền tảng của GAP_SNR là nến động lực.
- **tr.10** — "SELLING MARKET": D1 chữ V tại SNR, nến động lực giảm D1 xuyên qua (FLIPZONE) → 4H ba nến giảm, gap giảm ngay dưới FLIPZONE, BMS ở đáy râu nến giảm thứ 2 → 1H: hồi lên quanh FLIPZONE rồi nến giảm lớn phá BMS. Câu: gap giữ thì giá từ chối và đi tiếp; không giữ thì thị trường đổi hướng. "BUYING MARKET": Weekly → D1 (gap tăng tại SNR, nhãn "LTF BEARISH GAP_SNR", BMS ở đỉnh râu) → 4H chu kỳ A-B-C, BMS tại A; thân nến ở B đóng dưới FLIPZONE.
- **tr.11** — BTCUSD. D1: Classic V ≈ 64,950 (đóng nến đen, mở nến trắng), nến 15/04/2024 đóng dưới → "FRESH RESISTANCE", "Cây nến đảo chiều". 4H: Classic V ≈ 64,150 bị phá; gap giảm 4H ≈ 64,700 tạo từ nến đảo chiều. 1H BINANCE (13–20/04): hộp "Vùng đảo chiều" ≈ 63,450–64,700; "HTF #GAP_SNR", "Nến chuyển đổi xu hướng ở khung nhỏ", hai lần "SNR REJECT", "Doji SNR xuất hiện ngay tại điểm phá vỡ"; ngày 19/04 giá phá lên lại khỏi hộp. Không có số điểm vào/dừng lỗ.
- **tr.12** — GBPUSD. D1: gap tăng rồi gap giảm ở đỉnh; FRESH RESISTANCE = gap giảm D1 (bán, 12/03/2024). 4H: gap tăng 4H ≈ 1.2828; gap giảm 4H (≈ 1.2823) ở điểm ①; Classic V 1.28068 bị "Cây nến đảo chiều" phá; ô bán 1.28068, dừng lỗ 1.28232 (15.6 pip), mục tiêu 1.27450 (60.5 pip). "Sự thật 1" (gap 4H neo vào gap D1), "Sự thật 2" (gap 4H trước đó phá gap tăng 4H cũ = đổi cấu trúc).
- **tr.13** — "Sự thật 3": nến giảm lật phá hỗ trợ thành kháng cự mới. "Sự thật 4": gap tăng + gap giảm D1 gộp thành PIN BAR ở đỉnh. Điểm vào đầu: SELL khi giá kiểm tra lại gap 1.28239, dừng lỗ 7 pip, "RR = 1:5", mục tiêu 35 pip. Hình 4H: gap giảm tại `C` nến đen = `O` nến đen kế tiếp 1.28239; dừng lỗ 1.28310 ≈ đỉnh râu nến 2; "SELL 1" khớp bởi râu của nến phá; "1ST TP @ 1R:5R (35)" tại 1.27890.
- **tr.14** — "Quay lại D1 để xem hướng và chướng ngại (Internal GAPs)". 4H: SELL 2 1.28066 (Classic V bị phá), dừng lỗ 1.28195 (13.1 pip), "PROFIT: 60 PIPS"; nhiều nhãn "INTERNAL GAP SNR" ở nến tăng trước đó. D1: cùng lệnh, mục tiêu 1.27463 = gap nội bộ thấp nhất. 1H OANDA: bán ở mức gap nội bộ 1.2820, dừng lỗ 1.28234 (4.1 pip), "PROFIT: 73 PIPS, RISK: 4 PIPS"; nhãn London/New York Killzone; lệnh New York ngày 14/03 "PROFIT: 92 PIPS".
- **tr.15** — GBPUSD 1H: "#Doji_SNR" (nến giảm, doji, nến giảm) trong hộp ≈ 1.2820–1.2830; "① 1ST GAP TAKEN OUT", "② 2ND GAP TAKEN OUT"; bán 1.28240, dừng lỗ 1.28298, "77 PIPS" và "92 PIPS" (tới 1.27312). BTCUSD: W1 "WEEKLY REJECTION BLOCK" (nến đen nhỏ, râu trên dài); D1 "DAILY BULLISH GAP" + nến giảm = "HIDDEN BEARISH GAP" ("cặp 2 nến ngược chiều tạo vùng Flipped Gap"); 4H "DAILY BULLISH GAP (MOMENTUM CANDLE)", đường ≈ 69,000, "Lực bán bắt đầu xuất hiện".
- **tr.16** — BTC 2H: gap tăng từ nến động lực 4H, gap giảm, nến đen phá xuống dưới các gap tăng ("xác nhận xu hướng giảm"). BTC 1H: "BULLISH GAP FLIPPED", dấu tích ở đỉnh râu, "SnR đảo chiều (Flipped SnR)". BTC 1H: hai lệnh SELL (73,158.48 / dừng lỗ 73,422.58; 72,267.14 / 72,586.26), mục tiêu 68,569.74, "Nến đảo chiều SnR". COQ/USDT sơ đồ: Monthly nến động lực tăng phá kháng cự, chứa chu kỳ A-B-C và gap tăng tuần; Weekly gap giảm theo A-B-C.
- **tr.17** — COQ "Bullish Storyline + MTFs": Monthly SNR ở mép thân; Weekly gap giảm, gap tăng, BUY tại "Vùng đảo chiều", gap nội bộ; D1 nến tăng mạnh phá cả 2 gap giảm cũ, BUY khi giá kiểm tra lại. COQ 4H: hai "Cây nến đảo chiều", ba mức nét đứt; BUY khi râu chạm mức; "BUY (Điểm vào lệnh xác nhận)" tại 0.000002208 (nến giảm lớn đóng đúng mức, nến tăng mở từ đó); vùng hồng ≈ 0.00000208–0.0000022.
- **tr.18** — COQ 1H: hộp "Vùng đảo chiều" ≈ 0.00000205–0.00000218; "Nến đảo chiều" 1H xuyên lên qua hộp; hai vòng tròn là các lần kiểm tra với "Mức mua"; "Khu vực mua" thấp hơn. XAUUSD 4H (15/04/2024) hai ảnh "4H SETUP": gap giảm ≈ 2369 bị gap tăng phá ("sự thay đổi trong cấu trúc thị trường"); gap tăng mới ≈ 2356 ("Vùng đảo chiều"); câu: kỳ vọng giá giảm nhẹ sau nến lật rồi tăng mạnh tại #GAP_SNR (Fresh Support).
- **tr.19** — "Sự thật 1": setup 4H nằm tại các flipzone cũ. "Sự thật 2": #Doji_SNR 4H đẩy giá qua gap giảm, trùng Weekly GAP Reject → Bullish Storyline. XAUUSD 4H: "#Flipped SnR — khoảng trống giá tăng đã phá khoảng trống giá giảm", các vòng tròn ở chỗ gap lật, đường ≈ 2342. XAUUSD W1: "WK SNR" = gap tăng tuần; nến tuần có râu dưới chạm/hơi xuyên = "WEEKLY REJECT", "4H #Doji_SNR". XAUUSD 4H (17/04/2024): các đường 2396, 2370, và 2357 "4H #Doji_SNR"; nến giảm có râu chạm ≈ 2355 = "Từ chối mức 4H Doji_SNR". Hình mẫu Doji SnR tăng và định nghĩa bằng chữ.
- **tr.20** — XAUUSD 1H (15–18/04/2024): hai "(FRESH SUPPORT)" ≈ 2365 và ≈ 2357.8, là gap tăng 1H phá qua gap 1H trước đó và trùng mức Classic A cũ; bóng đèn = vào mua trực tiếp; dấu tích = vào mua có xác nhận (các râu chạm ≈ 2364–2363.5); lệnh mua 2357.808, dừng lỗ 2351.670. Ảnh "Sau đó": "#FlippedSNR #GAP_SNR", BUY khớp bởi râu (≈ 2355), lãi 61.017 USD = "610 Pips trong 2 ngày".
- **tr.21** — "Hidden Gap_SnR": khi nến động lực phá SnR, tinh chỉnh xuống khung nhỏ để tìm gap ẩn; sau khi phá giá thường quay lại kiểm tra. XAUUSD 4H: "Kháng cự yếu bị lật ngược", BULLISH GAP, nến động lực xuyên đường tím, hai BUY. COQ 1H: nhiều "Gap tăng" nhỏ trong chân sóng, giá quay lại chạm. "Sự thật": nến động lực (thân dài) phá hoặc nhấn chìm một mức thường chứa Gap SnR bên trong; sơ đồ "Flipped SnR — Gap đảo chiều". XAUUSD D1 (06–10/2023): hỗ trợ ≈ 1942 bị phá, "Kháng cự mới", "#GAP_SNR FLIPPED" (2 chỗ), "RESISTANCE REJECT", ô bán tới 1889.223.
- **tr.22** — EURUSD 30m OANDA (20–21/07/2022): #FlippedSNR ≈ 1.0217 "Kiểm tra lại (Sell)" bằng râu; gap tăng/gap giảm; #FlippedSNR ≈ 1.0215 "Kiểm tra lại nhiều lần cho Sell nhiều lần" (hai ngôi sao ở đỉnh râu vượt mức ~6–7 pip); #FlippedSNR ≈ 1.0181 "BUYS"; #FlippedSNR ≈ 1.0167 (gap giảm lật) "BUY" khi râu chạm; "100 PIPS" từ ≈ 1.0180.
- **tr.23** — Câu 44 pip rủi ro → 1,143 pip lợi nhuận, "1R:26R". EURUSD 30m: BULLISH GAP bị BEARISH GAP phá; bán 1.08991, dừng lỗ 1.09022, "NEW YORK OPEN", "PROFITS = 77 PIPS, RISK = 3 PIPS, R-R = 1R:5.2R". XAUUSD 4H "SIMPLICITY-IS-KEY": #FlippedSNR, BUY 2251.292, dừng lỗ 2246.793 (nhãn "SL", "44 PIPS"), "1,143 PIPS"; #FlippedSNR khác ≈ 2344. Câu: tinh chỉnh 4H xuống khung nhỏ để rủi ro cực thấp; giữ tư duy xác suất. EURUSD 1H: "4HR SNR", rủi ro 1.3 pip, "RISK = 1 PIPS, REWARD = 95 PIPS"; ô tính tiền quảng cáo.
- **tr.24** — EURUSD D1 (09–10/2023): 4 lần "SELL" tại các mức kẻ ở mép thân, mỗi lần sau một "SNR FLIPPING CANDLE". XAUUSD 4H (05–15/04/2024): "SnR Flipping Candle: Cây nến SnR đảo chiều"; mức ≈ 2328 lật thành hỗ trợ; "Khoảng trống giá tăng phá vỡ khoảng trống giá giảm"; hai BUY; #Doji_SNR. XAUUSD 1H (24–26/01/2024): "FlippedSNR", "1-HOUR GAP SNR BO" ≈ 2026.1 (gap tăng 1H bị phá); SELL khi râu chạm lại, dừng lỗ 2028.014, "100 PIPS".
- **tr.25** — BONK/USDT D1 KUCOIN: "SNR Flipping Candle"; BUY ở mức lật ≈ 0.0000103; "SETUP": BUY 0.000011682, dừng lỗ 0.000011012 trên đường FlippedSNR ≈ 0.0000111; "AFTER": "120.79% ROI từ 26–29/02/2024"; ảnh thứ hai "315.88% ROI 26/02–04/03/2024".
- **tr.26** — Volatility 75 Index D1 (Deriv, MT5): BULLISH GAP, Doji_SNR (giảm) và BEARISH GAP ở đỉnh; hộp Doji SnR; "SnR (kháng cự) giữ ở cây nến DOJI"; Doji_SNR tăng ở đáy với BUY. Ảnh 2: "Gap tăng phá vỡ gap giảm và kháng cự", đường nét đứt ở mức gap giảm, BUY khi râu chạm. Ảnh 3: "Vùng Doji_SnR" ở đỉnh, giá quay lại chạm đỉnh hộp rồi giảm; đường hỗ trợ ở mép thân với các mũi tên ở đáy râu chạm đường.
- **tr.27** — Hình "Pay attention". Lời kết: đo lại quá khứ kế hoạch giao dịch từng tháng một tới khi thành thạo; thành công đến từ "luyện tập có mục đích". Không có quy tắc mới.

---

**Ghi chú kỹ thuật**
- Bản này đọc trên Linux: `pdftoppm -r 220` cho cả trang, `pdftoppm -r 300..400 -x -y -W -H` để cắt phóng to từng biểu đồ. Ảnh chỉ nằm trong thư mục tạm của phiên, không đưa vào repo.
- Giá đọc từ nhãn trên hình là chính xác; giá đọc bằng cách dóng vào trục (có ghi "≈") có thể lệch vài pip hoặc vài chục cent vàng.

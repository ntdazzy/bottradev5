# Báo cáo: "Secret Of 411" phần 2

**File:** `C:\Users\NTD\Desktop\BotTradeEA\docs\tài liệu trade\Secret Of 411-2.pdf`

Tôi đã đọc đủ 10/10 trang. Read tool không mở được PDF vì máy thiếu pdftoppm. Tôi dùng Windows PDF API xuất từng trang ra ảnh vào scratchpad (`C:\Users\NTD\AppData\Local\Temp\claude\C--Users-NTD-Desktop-BotTradeEA\370bc82c-3d1b-468b-a881-1aa9fc582185\scratchpad\s411_2\p01.png` … `p10.png`), rồi phóng to từng chart. Chữ đọc từ ảnh khớp với lớp chữ lấy thẳng từ PDF. Tôi không sửa hay tạo file nào trong dự án. Số trang dưới đây là số trang PDF.

---

## 1. Tổng quan

- **Tên:** "Secret Of 411" phần 2. Metadata ghi tên file "Secret Of 411.2.edit.pdf", làm bằng Canva, trường tác giả là "Ding Nguyễn". Tên này có thể chỉ là tài khoản xuất file; nội dung không ghi tên tác giả hay nguồn.
- **Bố cục 10 trang:**
  - Tr.1: bìa, chỉ có ảnh chân dung, không có chữ.
  - Tr.2–8: kỹ thuật về trendline.
  - Tr.9: trang ngăn ghi "tâm lý", chỉ có ảnh.
  - Tr.10: tâm lý, hệ thống, rủi ro/lợi nhuận.
- **Hình minh họa:** sơ đồ zigzag vẽ tay (tr.3–7) và ảnh chụp chart XAUUSD từ MT4/MT5 bản điện thoại, khung W1, H4, H1, M30 (tr.2, 7, 8).
- **Nội dung chính:** toàn bộ phần kỹ thuật chỉ nói về đường xu hướng (trendline):
  - vẽ bằng tia kéo dài sang phải (Ray Right);
  - đặt điểm neo vào **thân nến**, không vào bóng, theo phương pháp "Móc nến" (Hooking);
  - hợp lưu (confluence) giữa mức hỗ trợ/kháng cự SNR và trendline;
  - hai kiểu góc nghiêng: "Cơ bản" và "Sự phân kỳ";
  - "6 loại trendline": Loại 1, Loại 2, Loại 3, Trendline QM, Trendline 666, Trendline XR;
  - "Boom Point": vào lệnh tại giao điểm của 2 trendline khác loại. Tác giả gọi XR là "bí quyết giao dịch mà tôi sử dụng hàng ngày".
- **Phần 2 không định nghĩa:** SnR, mức A/V (A/V-level), gap, fresh/unfresh, mô hình QM, storyline, thanh khoản (liquidity), nến nhấn chìm (engulfing), FVG, order block, BOS/CHoCH, phiên giao dịch. Chữ "SNR" và "QM" được dùng như thể người đọc đã biết, có lẽ đã học ở phần 1.

---

## 2. Định nghĩa

**2.1 Trendline (tr.2).** Tài liệu ghi: "Công cụ này dùng để: 1. Xác định xem thị trường đang trong xu hướng nào. 2. Xác định điểm vào lệnh."

**2.2 Cách vẽ: tia phải và 3 điểm của công cụ (tr.2).**
- Tài liệu ghi: "Mở chế độ RAY RIGHT (Tia kéo dài sang phải). Điểm thứ 1 của Trendline ứng với Điểm thứ 1 trên giá. Điểm thứ 3 của Trendline ứng với Điểm thứ 2 trên giá."
- Hình cho thấy công cụ trendline trên điện thoại có 3 chấm "1st, 2nd, 3rd":
  - "1st" đặt vào điểm giá 1 (điểm cũ hơn);
  - "3rd" đặt vào điểm giá 2 (điểm mới hơn);
  - "2nd" chỉ là chấm kéo nằm đúng giữa hai điểm, không đặt lên giá.
- Như vậy đường chỉ có **2 điểm neo**. Lệnh vào ở phần tia kéo dài sau neo 2.
- Để lập trình: giá trị đường tại nến t là `L(t) = P1 + (P2 − P1)·(t − t1)/(t2 − t1)`, dùng cho t > t2.

**2.3 Phương pháp Móc nến (Hooking) (tr.2).**
- Tài liệu ghi: "Resistance (Kháng cự): Body Bullish (Dùng Thân nến Tăng). Support (Hỗ trợ): Body Bearish (Dùng Thân nến Giảm)". Kèm lưu ý: "Vui lòng chú ý kỹ vị trí của ĐIỂM TRENDLINE POINT khi đặt trên BODY".
- Tôi phóng to và kiểm tra các neo trong 4 chart thật ở tr.2, 7, 8:
  - **Neo kháng cự** nằm ở mép trên thân nến tăng, tức giá đóng cửa (close) của nến tăng.
  - **Neo hỗ trợ** nằm ở mép dưới thân nến giảm, tức close của nến giảm.
  - Bóng nến (wick) bị bỏ qua. Ví dụ tr.2 H4: neo 1 đặt ở đáy thân ~1800,5, dù bóng dưới dài hơn nhiều.
- **Quan sát thêm, không có trong chữ:** ở mọi neo nhìn rõ được, nến neo là nến cuối cùng trước khi đổi màu:
  - neo kháng cự: nến tăng, ngay sau là nến giảm;
  - neo hỗ trợ: nến giảm, ngay sau là nến tăng.
  - Riêng một neo trên chart W1 tr.8 bị chấm che, không thấy rõ.
- **Vai trò của điểm quyết định loại nến dùng để neo.** Ví dụ Trendline 666 ở tr.8 H1:
  - neo 1 là hỗ trợ, đặt ở đáy thân nến giảm ~1948,7;
  - neo 2 là kháng cự sau khi đường đã bị phá, đặt ở đỉnh thân nến tăng ~1948,1.

**2.4 Sự hợp lưu (confluence) (tr.2–3).**
- Tài liệu ghi: "Hai điểm hội tụ dẫn đến cùng một quyết định giao dịch".
- Sơ đồ: "SNR (Point 1)" cộng "Trendline (Point 2)" dẫn tới "Quyết định".
- Ở tr.3, điểm hợp lưu là chỗ đường ngang SNR và tia trendline cắt nhau, và giá chạm đúng chỗ đó. Nhãn trên hình: "Hợp lưu của SNR và TL (TRENDLINE)".

**2.5 SNR.**
- Phần 2 không định nghĩa SNR.
- Ở tr.3, SNR được vẽ là đường ngang màu đỏ, bắt đầu từ một đỉnh hoặc đáy được khoanh tròn và kéo sang phải.
- Tài liệu không nói vẽ theo thân hay theo bóng; sơ đồ zigzag không có nến.

**2.6 Setup Bán / Setup Mua – "Mẫu đảo chiều" (tr.3).** Ký hiệu: H là đỉnh, L là đáy.
- **Setup Bán:**
  - Giá giảm vào L0. L0 được khoanh tròn và kẻ đường ngang.
  - Giá tăng mạnh lên H1 (neo trendline 1).
  - Giá về L1. L1 cao hơn L0, được khoanh tròn và kẻ đường ngang.
  - Giá lên H2, thấp hơn H1 (neo trendline 2).
  - Giá giảm mạnh, thủng L1 rồi thủng L0, tạo đáy mới.
  - Giá hồi lên đúng mức L1, cũng đúng chỗ chạm tia H1–H2. Nhãn: "Hợp lưu của SNR và TL". Sau đó mũi tên đi xuống.
  - Đường L0 chỉ kéo đến chỗ giá cắt lại nó và không có chú thích. Có vẻ để minh họa việc thủng đáy cũ, nhưng tài liệu không nói.
- **Setup Mua (đối xứng):**
  - H0 → L1 (neo 1) → H1 (được khoanh, thấp hơn H0) → L2 (neo 2, cao hơn L1).
  - Giá tăng mạnh vượt H1 và H0.
  - Giá hồi về mức H1, đúng chỗ chạm tia L1–L2. Sau đó mua.

**2.7 Góc của đường xu hướng (tr.4).** Trang chỉ có 2 tiêu đề và hình, không có lời giải thích.
- **"Cơ bản":**
  - Bán: đường dốc xuống nối 2 đỉnh thấp dần, trong xu hướng có đỉnh và đáy đều thấp dần. Lần chạm thứ 3 thì giá giảm mạnh.
  - Mua: đường dốc lên nối 2 đáy cao dần. Lần chạm thứ 3 thì giá tăng mạnh.
- **"Sự phân kỳ":**
  - Bán: đường **dốc lên** nối 2 đỉnh cao dần, trong xu hướng có đáy cũng cao dần. Lần chạm thứ 3 thì giá giảm mạnh.
  - Mua: đường **dốc xuống** nối 2 đáy thấp dần, trong xu hướng có đỉnh thấp dần. Lần chạm thứ 3 thì giá tăng mạnh.

**2.8 "6 Loại Trendline" (tr.5–6).** Loại 1, 2, 3, QM và 666 **không có chữ giải thích**, chỉ có hình. Tôi mô tả lại hình dưới đây; mỗi loại mua là hình đối xứng của bán.

- **Loại 1 (tr.5): đường cùng chiều lệnh, vào ở lần chạm thứ 3.**
  - Bán: L0 → H1 (neo 1) → L1 → H2 (neo 2, thấp hơn H1) → giá giảm mạnh xuống dưới cả L1 và L0 → giá hồi lên chạm tia H1–H2, nhãn "entry" → giá giảm.
  - Mua: H0 → L1 (neo 1) → H1 → L2 (neo 2, cao hơn L1) → giá tăng mạnh vượt H1 và H0 → giá hồi về tia, nhãn "entry" → giá tăng.
  - Quan sát: điểm entry cao ngang L1 (bán) hoặc H1 (mua). Hình này giống hệt Setup tr.3 nhưng bỏ đường SNR.
- **Loại 2 (tr.5): đường ngược chiều lệnh, bị phá rồi kiểm tra lại (retest).**
  - Bán: L1 (neo 1) → H → L2 (neo 2, cao hơn L1) → H' (thấp hơn H) → giá giảm mạnh, cắt thủng đường dốc lên và thủng L1 → giá hồi lên chạm tia từ phía dưới, nhãn "entry" → giá giảm.
  - Mua: đối xứng, dùng đường dốc xuống nối 2 đỉnh; giá phá lên rồi hồi về chạm tia từ phía trên.
  - Quan sát: điểm entry cao ngang H' (bán) hoặc L' (mua), tức đỉnh/đáy cuối cùng trước khi phá.
- **Loại 3 (tr.5): kênh giá (channel) gồm 2 đường song song.** Hình không có chấm neo và không có nhãn "entry".
  - Bán: kênh giảm. Đường trên chạm 3 đỉnh, đường dưới chạm 2 đáy. Giá thủng đường dưới, tạo đáy, hồi lên chạm lại đường dưới từ phía dưới, rồi giảm tiếp.
  - Mua: kênh tăng. Giá vượt đường trên, hồi về chạm đường trên từ phía trên, rồi tăng tiếp.
- **Trendline QM (tr.6).**
  - Bán: H1 (neo 1) → L1 → HH, đỉnh cao nhất nằm **trên** đường; đường không nối vào HH → L2 (cao hơn L1) → H2 (neo 2, thấp hơn HH) → LL, thủng dưới L1 → giá hồi lên chạm tia H1–H2, nhãn "entry" → giá giảm.
  - Mua: đối xứng. Đáy thấp nhất (LL) xuyên xuống dưới đường; sau neo 2 giá tạo HH vượt đỉnh cũ, rồi hồi về tia để vào lệnh.
  - Nghĩa là đường nối 2 "vai", còn "đầu" xuyên qua đường thì đường vẫn được dùng.
- **Trendline 666 (tr.6).**
  - Bán:
    - A là một đáy (neo 1). Sau A, giá dao động phía trên đường.
    - Giá giảm mạnh, cắt thủng đường và xuống dưới A.
    - Giá hồi lên chạm đường từ phía dưới tại D. D là một **đỉnh** và là neo 2.
    - Giá giảm tiếp, tạo đáy thấp hơn.
    - Giá hồi lên chạm tia A–D lần nữa, nhãn "entry". Sau đó giá giảm.
  - Mua: đối xứng. A là một đỉnh, D là đáy của lần hồi đầu tiên sau khi phá.
  - Khác với Loại 2: neo 2 chính là lần retest đầu tiên, và lệnh vào ở lần retest thứ 2.
- **Trendline XR (tr.6).**
  - "X: Cấu trúc hành động giá được tạo thành bởi 2 Trendline cắt nhau."
  - "R: Việc xoay/điều chỉnh đường xu hướng để tìm ra góc nghiêng phù hợp."
  - "2 đường Trendline bao gồm Kháng cự & Hỗ trợ … để xác định: 1. Xu hướng và hướng đi của giá trong ngắn hạn hoặc dài hạn. 2. Khả năng hình thành động lượng (sức mạnh/tốc độ) của giá."
  - Sơ đồ hình chữ X: ở giao điểm ghi "HIGH MOMENTUM – Less PIPS"; hai bên rộng ghi "LOW MOMENTUM – More PIPS". Không có giải thích thêm.

**2.9 XR – BOOM POINT (tr.7–8).**
- Tài liệu ghi: "*Sự kết hợp giữa các loại Trendline khác nhau".
- **Sơ đồ "QM Trendline + Loại 2" (bán):**
  - Đường QM nối 2 vai, đỉnh đầu xuyên qua đường.
  - Đường Loại 2 nối 2 đáy cao dần; về sau bị sóng giảm cắt thủng.
  - Giá hồi lên đúng giao điểm của 2 đường, nhãn "entry". Sau đó giá giảm.
- **Sơ đồ "Loại 1 + Loại 6" (bán):**
  - Đường Loại 1 dốc xuống, nối 2 đỉnh thấp dần.
  - Đường dốc lên đi từ một đáy qua đỉnh retest sau khi bị phá. Cách dựng này giống Trendline 666.
  - Giá chạm giao điểm, nhãn "entry". Sau đó giá giảm.
- Tài liệu ghi thêm: "Nếu bạn không thể nhìn thấy Trendline ở cùng khung thời gian, hãy sử dụng 2 khung thời gian."

**2.10 Rủi ro và lợi nhuận (tr.10).**
- "RISK (Rủi ro): Số tiền mà chúng ta sẵn sàng chấp nhận mất."
- "REWARDS (Lợi nhuận): Số tiền mà chúng ta mong muốn kiếm được."
- Tỷ lệ **1:5**. Ví dụ: "Cắt lỗ: 40 PIPS, Chốt lời: 200 PIPS".

**2.11 Tâm lý và hệ thống (tr.10).** Không có quy tắc nào dùng được cho EA.
- TRIAL: "Chỉ cần sử dụng một phương pháp/kỹ thuật duy nhất là đủ".
- ADJUST – LEARN: tăng thời gian rèn luyện, kiểm thử trên dữ liệu quá khứ (backtest) đều đặn.
- SYSTEM: lặp lại thói quen tốt, loại bỏ tác động tiêu cực.
- Phần còn lại là kiểm soát cảm xúc: chuyển từ trạng thái "vấn đề hàng ngày" sang "làm mới trí tuệ, cơ thể, tâm hồn".

---

## 3. Cách xác định đường và mức giá

**Những gì tài liệu nói hoặc cho thấy trong hình:**
1. Chọn 2 điểm giá. Tài liệu **không định nghĩa** cách chọn đỉnh/đáy (swing); các ví dụ chỉ dùng những điểm đảo chiều nhìn thấy rõ.
   - Loại 1, QM, Cơ bản, Phân kỳ: 2 điểm cùng vai trò, tức 2 đỉnh hoặc 2 đáy.
   - Loại 2: cũng 2 điểm cùng vai trò, nhưng đường nằm ngược chiều lệnh.
   - 666: 1 đáy và 1 đỉnh retest (hoặc ngược lại).
   - QM: nối 2 vai, bỏ qua đỉnh/đáy đầu.
2. Neo vào thân nến theo mục 2.3: kháng cự dùng close của nến tăng, hỗ trợ dùng close của nến giảm.
3. Đặt điểm 1 của công cụ vào điểm giá cũ, điểm 3 vào điểm giá mới, bật Ray Right.
4. Với SNR: kẻ đường ngang tại đỉnh/đáy được khoanh tròn (tr.3). Quy tắc chi tiết nằm ngoài phần 2.
5. Với kênh (Loại 3): đường song song đi qua các swing ở phía đối diện.
6. Với XR: vẽ 2 đường khác loại. Nếu một khung không thấy đủ cả 2 đường thì dùng 2 khung.

**Khung thời gian để vẽ:** tài liệu không quy định. Các ví dụ dùng W1, H4, H1, M30.

**Khi nào đường còn hoặc hết hiệu lực:** tài liệu không nói. Từ hình chỉ thấy:
- đường đã bị phá vẫn được dùng tiếp, và đổi vai trò (Loại 2, Loại 3, 666);
- bị một mũi giá xuyên qua vẫn được dùng (QM);
- chữ "R" cho phép xoay/chỉnh đường để có góc "phù hợp".

**Thứ tự ưu tiên giữa các đường:** tài liệu không nói. Có nhấn mạnh hợp lưu ("2 điểm → 1 quyết định") và XR là bí quyết dùng hàng ngày.

---

## 4. Quy tắc vào lệnh

**Vị trí vào lệnh theo từng loại:**
- **Chạm lần 3 vào tia kéo dài sau 2 neo:** Loại 1, QM, Cơ bản, Sự phân kỳ; ví dụ thật ở tr.2 H4. Đường nối các đỉnh thì bán, nối các đáy thì mua.
- **Retest đầu tiên sau khi đường bị phá:** Loại 2. Giá phá qua đường và thủng neo 1, sau đó quay lại chạm đường từ phía bên kia. Hướng lệnh là hướng phá.
- **Retest cạnh kênh sau khi phá:** Loại 3. Hình chỉ có mũi tên, không có nhãn "entry".
- **Retest thứ 2:** Trendline 666 (lần retest thứ nhất đã dùng làm neo 2).
- **Hợp lưu SNR + trendline:** Setup Bán/Mua ở tr.3.
- **Giao điểm 2 trendline khác loại:** XR Boom Point ở tr.7.

**Dừng lỗ và chốt lời:**
- Tài liệu **không có** quy tắc đặt dừng lỗ (stop loss) hay chốt lời (take profit).
- Chỉ có tỷ lệ R:R 1:5 với ví dụ 40/200 pips (tr.10).

**Xác nhận:**
- Tài liệu **không có** quy tắc nến xác nhận.
- Tài liệu không nói nên dùng lệnh chờ tại đường hay lệnh thị trường.

**Những gì thấy trên chart thật (quan sát, không phải quy tắc viết ra):**
- **Tr.2 H4:** một nến giảm đóng cửa sát đường (~1813,5–1814), tiếp theo là nến tăng lớn; giá lên ~1847.
- **Tr.7 M30 trái:** nến tăng đóng cửa đúng giao điểm (~1851,1); nến kế tiếp là nến giảm lớn; giá xuống ~1836.
- **Tr.7 M30 phải:** chỉ bóng nến chạm giao điểm (~1845,6); thân nến nằm dưới; sau đó giá giảm.
- **Tr.8 H1:** thân nến chạm giao điểm (~1944,4); có một bóng lên ~1949,7; sau đó giá giảm về ~1932–1937.
- Tóm lại: thân nến thường tôn trọng đường, còn bóng có thể xuyên qua.

---

## 5. Quan hệ khung thời gian

- Tr.2: trendline dùng để xác định xu hướng.
- Tr.6: XR dùng để xác định xu hướng và hướng đi "ngắn hạn hoặc dài hạn".
- Tr.7: dùng 2 khung thời gian nếu không thấy đủ trendline trên cùng một khung.
- **Không có:** quy tắc khung nào để lấy xu hướng lớn (bias), khung nào để vẽ, khung nào để vào lệnh. Không có quy trình phân tích từ khung lớn xuống khung nhỏ. Không nhắc tới M1/M5.

---

## 6. Mọi con số trong tài liệu

- Trendline có 2 điểm neo. Công cụ có 3 điểm: điểm 1 và điểm 3 là neo, điểm 2 là chấm kéo ở giữa.
- Trong hình, lệnh vào thường ở **lần chạm thứ 3**.
- "6 loại" trendline; tên "666", "QM", "XR"; XR gồm 2 đường cắt nhau; dùng 2 khung thời gian.
- R:R **1:5**; ví dụ dừng lỗ **40 pips**, chốt lời **200 pips**. Tài liệu không định nghĩa pip của XAUUSD.
- **Không có:** dung sai khi chạm đường, số nến, giờ hay phiên giao dịch, ATR, spread, % rủi ro mỗi lệnh, giới hạn số lệnh.

---

## 7. Phần nào lập trình thẳng được, phần nào cần anh chốt

**Lập trình thẳng được:**
- Giá neo theo Móc nến: close của nến tăng cho kháng cự, close của nến giảm cho hỗ trợ.
- Phương trình tia `L(t)`.
- Hướng lệnh cố định theo từng loại.
- Thứ tự cấu trúc của từng loại (ví dụ H2 < H1, LL < L1), với điều kiện đã có định nghĩa swing.
- R:R 1:5.

**Cần anh chốt. Mọi mục ghi [ĐỀ XUẤT] là gợi ý của tôi, không phải quy tắc của tài liệu:**

1. **Chọn swing.** [ĐỀ XUẤT] Đỉnh thân tại nến i nếu thỏa cả ba điều kiện:
   - nến i tăng;
   - nến i+1 giảm;
   - Close[i] ≥ max(Open, Close) của N=3 nến mỗi bên.

   Giá neo = Close[i]. Đáy thân làm ngược lại. Chỉ xác nhận swing sau N nến để backtest không nhìn trước tương lai.
2. **Thế nào là "chạm".** [ĐỀ XUẤT] Dung sai tol = 0,1 × ATR(14) của khung vẽ. Kháng cự: coi là chạm khi High ≥ L(t) − tol. Hỗ trợ: khi Low ≤ L(t) + tol.
3. **Thế nào là "phá".** [ĐỀ XUẤT] Giá đóng cửa vượt đường quá tol. Bóng xuyên qua không tính, đúng tinh thần "dùng thân nến".
4. **Điều kiện cấu trúc trước khi vào lệnh.** [ĐỀ XUẤT] Lấy đúng như hình:
   - Loại 1 bán: sau neo 2 phải có một nến đóng cửa dưới L1.
   - Loại 2 bán: đường đã bị phá và giá đã đóng cửa dưới neo 1.
   - QM bán: đỉnh HH nằm giữa 2 neo, cao hơn cả hai neo và nằm trên đường; sau đó có nến đóng cửa dưới L1.
   - 666 bán: sau khi phá, giá xuống dưới A; neo 2 là lần hồi đầu tiên chạm đường mà không đóng cửa vượt lên trên đường; sau neo 2 có đáy mới; lệnh vào ở lần chạm tiếp theo.
5. **Hiệu lực của đường.** [ĐỀ XUẤT] Đường hết hiệu lực khi:
   - đã dùng cho 1 lệnh;
   - hoặc với kiểu chạm lần 3, giá đã phá đường trước khi vào lệnh. Khi đó đường chuyển sang trạng thái "đã phá" và có thể dùng cho Loại 2;
   - hoặc đã quá 3 × (t2 − t1) nến kể từ neo 2.
6. **Cách vào lệnh.** [ĐỀ XUẤT] Có 2 phương án để anh chọn:
   - (A) Lệnh chờ tại L(t), cập nhật lại mỗi nến.
   - (B) Chờ một nến chạm đường rồi đóng cửa quay lại đúng phía, vào ở nến kế tiếp. Có thể thêm điều kiện nến kế tiếp đổi màu, giống ví dụ tr.2 H4 và tr.7 M30 trái.
7. **"R – xoay đường cho góc phù hợp".** [ĐỀ XUẤT] Không mô phỏng việc xoay. Thay bằng giới hạn độ dốc |slope| ≤ 0,5 × ATR mỗi nến. Vẫn cho phép đường gần nằm ngang, vì tr.7 có đường như vậy.
8. **Boom Point.** [ĐỀ XUẤT]
   - 2 đường phải khác loại.
   - Vào lệnh khi thời điểm hiện tại cách giao điểm không quá 3 nến và giá nằm trong tol của cả 2 đường.
   - Nếu 2 đường cho hai hướng lệnh ngược nhau thì bỏ qua.
9. **Hợp lưu SNR + trendline.** [ĐỀ XUẤT] Khoảng cách giữa mức SNR và L(t) tại lúc chạm ≤ tol. Cách vẽ SNR phụ thuộc phần 1.
10. **2 khung thời gian.** [ĐỀ XUẤT] Vẽ trên H1/H4 và M15, vào lệnh trên M5/M1.
    - Lưu ý khi lập trình: tính L(t) theo số thứ tự nến trên đúng khung đã vẽ. Trên MT5, đường nối theo vị trí nến và bỏ qua khoảng trống cuối tuần/giờ nghỉ, nên tính theo thời gian tuyệt đối sẽ lệch.
11. **Dừng lỗ / chốt lời.** [ĐỀ XUẤT] Dừng lỗ đặt ngoài bóng của nến chạm đường, cộng thêm 0,1 × ATR; chốt lời = 5 × dừng lỗ.
12. **Pip của XAUUSD.** [ĐỀ XUẤT] Cần anh xác nhận. Cách tính thường gặp là 1 pip = 0,10 USD, khi đó 40 pips = 4 USD và 200 pips = 20 USD. Có nơi dùng 1 pip = 0,01 USD hoặc 1 USD.
13. **Sơ đồ momentum của XR.** [ĐỀ XUẤT] Chưa dùng làm điều kiện cho đến khi anh giải thích ý nghĩa.
14. **Xu hướng khung lớn (bias).** [ĐỀ XUẤT] Lấy theo đường "Cơ bản" gần nhất còn hiệu lực trên H1/H4:
    - đường nối 2 đáy cao dần, chưa bị phá → chỉ mua;
    - đường nối 2 đỉnh thấp dần, chưa bị phá → chỉ bán.

---

## 8. Điểm mơ hồ cần hỏi lại anh

1. **"Loại 6" trên sơ đồ tr.7 là loại nào?** Đếm theo thứ tự thì loại thứ 6 là XR, nhưng hình lại dựng giống Trendline 666. Và có đúng QM là Loại 4, 666 là Loại 5, XR là Loại 6 không?
2. **"Loại 1" có phụ thuộc độ dốc không?** Hình Loại 1 ở tr.5 dùng đường dốc xuống cho lệnh bán. Nhưng trên chart tr.8 H1 "666 + Loại 1", đường hợp lý nhất để gọi là "Loại 1" lại dốc **lên** nối 2 đỉnh, giống kiểu "Sự phân kỳ".
3. **Có giao dịch kiểu "Sự phân kỳ" (ngược xu hướng) không, hay chỉ kiểu "Cơ bản"?**
4. **Móc nến khi đỉnh không có nến tăng, hoặc nến neo là doji, thì neo ở đâu?**
5. **SNR vẽ theo thân hay theo bóng, tại loại điểm nào?** Tr.3 chỉ khoanh đỉnh/đáy. Mẫu Setup ở tr.3 có bắt buộc phải thủng mức L0/H0 không?
6. **Nhãn "entry" ở chart H1 tr.2 không chỉ vào nến cụ thể nào.** Sau điểm 2 không có nến nào quay lại chạm đường. Vậy nên vào bằng lệnh chờ hay chờ xác nhận?
7. **Loại 3 có vào lệnh bên trong kênh không, hay chỉ vào sau khi phá rồi retest?**
8. **Trong hình Loại 1 và Loại 2, điểm entry cao ngang một đỉnh/đáy trước đó.** Đây là yêu cầu hợp lưu với SNR hay chỉ trùng hợp?
9. **Các thông số tài liệu không nêu:** dung sai khi chạm, "phá" tính theo giá đóng cửa hay theo bóng, thời gian hiệu lực của đường, số lần chạm tối đa.
10. **R:R 1:5 là bắt buộc hay chỉ là ví dụ?** Đặt dừng lỗ ở đâu? 1 pip vàng bằng bao nhiêu?
11. **Vẽ trên khung nào, vào lệnh trên khung nào?** "2 khung thời gian" là cặp khung nào? Tài liệu không có M1/M5.
12. **Sơ đồ XR "High momentum – Less pips / Low momentum – More pips" áp dụng thế nào trong giao dịch?**
13. **Boom Point ở đâu trên chart W1 tr.8?** Chart này không đánh dấu entry. 2 đường cắt nhau lúc giá còn ở xa phía trên, vùng ~1900+.

---

## 9. Các ví dụ quan trọng

1. **Tr.2 trái – XAUUSD H4, "Hỗ trợ: Thân nến Giảm".**
   - Neo 1 ở đáy thân nến giảm ~1800,5 (khoảng 16/5); neo 2 ở đáy thân nến giảm ~1810,5 (khoảng 18/5).
   - Giá quay lại chạm lần 3 ở ~1813,5–1814, nhãn "entry", rồi tăng lên ~1847.
   - Có đường song song minh họa 3 chấm 1st/2nd/3rd của công cụ.
2. **Tr.2 phải – XAUUSD H1, "Resistance: Body Bullish".**
   - Neo ở đỉnh thân nến tăng ~1859,1 và ~1854,7 (30–31/5).
   - Sau đó giá giảm về ~1836.
3. **Tr.3 – Setup Bán và Setup Mua.** Mẫu đảo chiều, vào lệnh ở hợp lưu giữa SNR và trendline.
4. **Tr.4 – Hai kiểu góc nghiêng.** Cơ bản (đường cùng xu hướng) và Sự phân kỳ (đường ngược xu hướng), cả hai vào ở lần chạm thứ 3.
5. **Tr.5–6 – Sơ đồ đủ 6 loại.** Loại 1, 2, 3, QM, 666 (mục 2.8) và sơ đồ chữ X của XR.
6. **Tr.7 sơ đồ – Boom Point.** "QM + Loại 2" và "Loại 1 + Loại 6"; entry nằm đúng giao điểm.
7. **Tr.7 trái – XAUUSD M30, "QM Trendline + Loại 2".**
   - Đường QM qua đỉnh thân nến tăng ~1850,2 và ~1850,9; đầu ở ~1857 nằm trên đường.
   - Đường Loại 2 qua đáy thân nến giảm ~1842,2 và ~1845,0, sau đó bị phá.
   - Giao điểm ~1851,1 (16–17/6): nến tăng đóng cửa tại đó, rồi nến giảm lớn; giá xuống ~1836.
8. **Tr.7 phải – XAUUSD M30, "Loại 1 + Loại 2".**
   - Đường dốc xuống qua đỉnh thân nến tăng ~1857,1 và ~1851,2.
   - Đường gần ngang qua đáy thân nến giảm ~1845,1–1845,2, bị phá.
   - Giao điểm ~1845,6 (khoảng 20/6): chỉ bóng nến chạm, rồi giá giảm.
9. **Tr.8 trái – XAUUSD W1, "Loại 2 + Loại 1".**
   - Đường dốc xuống qua đỉnh thân ~1864,5 và ~1834,6; bị phá lên đầu năm 2022.
   - Đường dốc lên qua ~1782,9 và đáy thân nến giảm ~1790,7.
   - Tháng 5/2022 giá về chạm đường dốc lên (thân nến ~1809, bóng ~1787,6) rồi bật lên. Chart không đánh dấu entry.
10. **Tr.8 phải – XAUUSD H1, "Trendline 666 + Loại 1".**
    - Đường 666 qua đáy thân nến giảm ~1948,7 và đỉnh thân nến tăng retest ~1948,1 (25/3).
    - Đường dốc lên qua đỉnh thân nến tăng ~1927,9 (28/3) và ~1937,1 (30/3).
    - Giao điểm ~1944,4 (31/3): bóng nến lên ~1949,7, rồi giá giảm.

Giá và ngày ở trên là tôi ước lượng từ trục của ảnh chụp. Trừ chart W1, các chart không ghi năm. Nếu cần, có thể dựng lại các đường này trên dữ liệu XAUUSD lịch sử để kiểm tra code.
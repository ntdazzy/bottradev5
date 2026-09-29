# Báo cáo: "Secret Of 411" phần 2

**File:** `docs/tài liệu trade/Secret Of 411-2.pdf` (10 trang).

**Cách đọc (bản sửa lần 2):**
- Tôi đã đọc đủ 10/10 trang. Dựng ảnh từng trang bằng PyMuPDF và lấy lớp chữ của PDF.
- Mỗi trang PDF có **một ảnh trang gốc tiếng Anh** nằm bên dưới; bản Việt là chữ dán đè lên. Tôi đọc cả hai bản, rồi cắt, phóng to và tăng tương phản từng chart để thấy bóng nến (wick) mờ.
- Giá và ngày đọc từ trục của ảnh chụp. Sai số ước chừng: ~0,1–0,3 USD với M30/H1, ~0,3–0,5 USD với H4, ~2 USD với W1.
- Số trang dưới đây là số trang PDF. Tôi chỉ sửa file này.

**Những gì bản này sửa so với bản trước:**
- Trường tác giả trong metadata là "Dũng Nguyễn" (bản trước ghi "Ding Nguyễn").
- Chart tr.2 H1: sau neo 2 **có** bóng nến vượt lên trên đường (thân thì không). Bản trước ghi là không có nến nào chạm.
- Chart tr.7 phải: ảnh chụp dừng ngay sau lúc chạm giao điểm, nên **không thấy kết quả lệnh**. Bản trước ghi "sau đó giá giảm" là chưa đủ căn cứ.
- Chart tr.7: hai chart là **cùng một dữ liệu M30** (16–20/6). Nến vào lệnh ở chart trái chính là neo 2 của đường Loại 1 ở chart phải.
- Chart tr.8 W1: giao điểm (~1802,5, khoảng đầu tháng 4/2022) **không được giá chạm**; lúc đó giá đang ở ~1920–1990.
- Thêm phát hiện: ở mọi hình, điểm vào luôn là **lần chạm thứ 3 của đường** (tính cả 2 neo).
- Thêm phát hiện: Setup ở tr.3 chính là setup A/B của phần 1, chỉ thêm trendline nối 2 đỉnh (2 đáy) của mô hình.
- Đã bỏ các ngưỡng số tự đặt ở bản trước (0,1 × ATR, N = 3, 3 × (t2 − t1)…). Tài liệu không có các số này. Chúng được chuyển thành câu hỏi cần đo ở mục 7.

---

## 1. Tổng quan

- **Tên và nguồn:**
  - Metadata: tên "Secret Of 411.2.edit.pdf", làm bằng Canva, tác giả "Dũng Nguyễn" (có thể chỉ là tài khoản xuất file).
  - Bìa gốc tiếng Anh bị che ở tr.1 ghi "trendline by 411". Trang ngăn tr.9 bản gốc ghi "psycology by 411".
  - Vậy đây là chương Trendline và chương Tâm lý của bộ "Secret Of 411". Mục lục phần 1 có liệt kê hai chương này.
- **Bố cục:**
  - Tr.1: bìa, ảnh chân dung.
  - Tr.2–8: kỹ thuật trendline.
  - Tr.9: trang ngăn "tâm lý".
  - Tr.10: tâm lý, hệ thống, rủi ro/lợi nhuận.
- **Hình:**
  - Sơ đồ zigzag vẽ tay: tr.3–7.
  - Ảnh chụp chart XAUUSD trên MT4/MT5 bản điện thoại: tr.2 (H4, H1), tr.7 (M30, M30), tr.8 (W1, H1).
  - Quy ước màu trên chart thật: nến tăng màu xám nhạt, nến giảm màu đen/xám đậm. Tôi kiểm lại bằng các nhịp tăng/giảm rõ ràng.
- **Năm của các chart:** trục chart W1 tr.8 ghi rõ 2021–2022.
  - Các chart khác không ghi năm. Giá và thứ trong tuần khớp với năm 2022: tháng 3, 5, 6/2022.
  - Ví dụ: bóng dưới của neo 1 chart H4 tr.2 là ~1786,8, khớp với đáy vàng giữa tháng 5/2022.
  - Đây là suy luận. Tôi chưa đối chiếu với dữ liệu broker.
- **Dãy số OHLC trên đầu mỗi chart** là của nến **đang chạy lúc chụp** (khoảng giữa/cuối tháng 6/2022), không phải của nến ví dụ. Không dùng các số đó để đọc ví dụ.
- **Nội dung kỹ thuật chỉ nói về trendline:**
  - vẽ bằng tia kéo dài sang phải (Ray Right);
  - neo vào **thân nến** theo phương pháp "Móc nến" (Hooking);
  - hợp lưu (confluence) giữa SNR và trendline;
  - 2 kiểu góc: "Cơ bản" (Basic) và "Sự phân kỳ" (Divergence);
  - 6 loại: Loại 1, Loại 2, Loại 3, QM, 666, XR;
  - "Boom Point": vào lệnh ở giao điểm của 2 trendline khác loại.
- **Phần 2 không định nghĩa:** SnR, fresh/unfresh, engulfing, ISL/HSL, FVG, khối lệnh (order block), BOS/CHoCH, phiên giao dịch.
  - Chữ "SNR" và "QM" được dùng như thể người đọc đã biết (phần 1 có dạy SnR và engulf Quasimodo).
  - Mục lục phần 1 nhắc "5 LIVES SYSTEM" trong chương Tâm lý, nhưng phần 2 **không có** nội dung này.

---

## 2. Tóm tắt từng trang

**Tr.1 – Bìa.**
- Chỉ có ảnh chân dung.
- Ảnh gốc bên dưới có tiêu đề "trendline by 411", bị che trong bản Việt. Không có quy tắc.

**Tr.2 – Trendline: công dụng, cách vẽ, Móc nến, 2 chart thật.**
- Chữ: trendline dùng để (1) xác định xu hướng tăng/giảm, (2) xác định điểm vào lệnh.
- Hợp lưu: hai điểm hội tụ cho cùng một quyết định. Sơ đồ chữ Y: "SNR – Point 1" và "TL – Point 2" gộp vào "Quyết định".
- Cách vẽ: bật Ray Right. Điểm 1 của công cụ đặt vào điểm giá 1; điểm 3 của công cụ đặt vào điểm giá 2.
- Móc nến: kháng cự dùng thân nến tăng; hỗ trợ dùng thân nến giảm. Có lưu ý: chú ý vị trí điểm trendline trên THÂN nến.
- **Chart trái – XAUUSD H4, "Hỗ trợ: Thân nến Giảm", khoảng 16–19/5/2022:**
  - Neo "1": đáy thân của một nến giảm, ~1800,4 (tức giá đóng cửa). Bóng dưới của nến này xuống tới ~1786,8, bị bỏ qua. Nến ngay sau là nến tăng.
  - Neo "2": đáy thân nến giảm ~1810,4, ngày 18/5 05:00. Bóng dưới ~1807,6 bị bỏ qua. Nến ngay sau là nến tăng.
  - Hai neo cách nhau ~13 nến H4.
  - "entry": nến thứ 4 sau neo 2 là một nến giảm, đóng cửa ~1813,9, đúng trên đường (đường ở đó ~1813,6–1814). Bóng dưới xuyên xuống đường ~0,3–0,5 USD.
  - Nến kế tiếp là nến tăng lớn (~1814 → ~1829). Giá lên tới ~1849 trong khoảng 6–8 nến.
  - Có thêm một đường song song vẽ phía dưới, ghi "1st / 2nd / 3rd", để minh họa 3 chấm của công cụ. "2nd" nằm đúng giữa "1st" và "3rd".
  - Trên đường chính cũng có chấm giữa, nằm đúng giữa 2 neo.
- **Chart phải – XAUUSD H1, "Resistance: Body Bullish", 30–31/5/2022:**
  - Neo "1": đỉnh thân nến tăng ~1859,1. Bóng trên ~1860,8 bị bỏ qua. Nến sau là nến giảm.
  - Neo "2": đỉnh thân nến tăng nhỏ ~1854,8, cách neo 1 ~15 nến. Nến sau là nến giảm.
  - Nến giảm ngay sau neo 2 có bóng trên ~1857,1, vượt đường ~2,3 USD.
  - Chữ "entry" đặt bên phải neo 2. Khoảng 6 nến sau neo 2 có một nến tăng: thân 1849–1851,2, nằm dưới đường (~1853,1); bóng trên ~1855,4, vượt lên đường ~2,3 USD.
  - Sau đó là nến giảm lớn, giá xuống ~1836 (bóng ~1835,5).
- Hai chart này đều là kiểu chạm lần 3 thông thường. Giữa neo 2 và điểm vào, giá **không** phá đáy/đỉnh trước đó. Như vậy khớp với kiểu "Cơ bản" (tr.4) hơn là "Loại 1" (tr.5).

**Tr.3 – Hợp lưu SNR + TL: "Setup Bán" và "Setup Mua" (mẫu đảo chiều).**
- Setup Bán (sơ đồ zigzag):
  - L0 → H1 → L1 (cao hơn L0) → H2 (thấp hơn H1);
  - giá giảm thủng L1 rồi thủng L0;
  - giá hồi lên đúng mức L1, cũng là chỗ tia H1–H2 đi qua; sau đó giảm.
  - L0 và L1 được khoanh tròn và kẻ ngang màu đỏ.
  - Trendline màu vàng có 3 chấm: H1, chấm giữa, H2.
  - Đường L0 dừng ở chỗ nhịp hồi cắt lại nó. Đường L1 kéo tới điểm hợp lưu.
- Setup Mua: đối xứng. H0 → L1 → H1 (thấp hơn H0) → L2 (cao hơn L1) → giá vượt H1 và H0 → hồi về H1 đúng chỗ tia L1–L2 đi qua → mua.
- **Liên hệ phần 1:** đây chính là setup SELL/BUY của phần 1.
  - L0 = A (mốc gợi ý phá vỡ – Hint Breakout);
  - L1 = B (đường vào lệnh – Entry);
  - H1, H2 là 2 đỉnh của mô hình M.
  - Phần 2 chỉ thêm trendline nối 2 đỉnh của M (2 đáy của W). Điểm vào là chỗ đường B gặp trendline.
  - Đây là suy luận từ việc so hai hình; tài liệu không viết ra.

**Tr.4 – "Góc của đường xu hướng" (Angle of trendline).** Chỉ có hình, không có lời giải thích.
- "Cơ bản" (Basic):
  - Bán: đường dốc xuống nối 2 đỉnh thấp dần, trong xu hướng giảm (đỉnh và đáy đều thấp dần). Chạm lần 3 thì giảm mạnh.
  - Mua: đường dốc lên nối 2 đáy cao dần, trong xu hướng tăng. Chạm lần 3 thì tăng mạnh.
- "Sự phân kỳ" (Divergence):
  - Bán: đường **dốc lên** nối 2 đỉnh cao dần, trong khi đáy cũng cao dần, tức đang tăng. Chạm lần 3 thì giảm mạnh. Đây là lệnh ngược xu hướng.
  - Mua: đường **dốc xuống** nối 2 đáy thấp dần, trong khi đang giảm. Chạm lần 3 thì tăng mạnh.
- Mỗi hình có 3 chấm (2 neo và chấm giữa của công cụ).

**Tr.5 – 6 loại trendline (phần 1): Loại 1, 2, 3.** Chỉ có hình; mô tả chi tiết ở mục 3.7.
- Loại 1: có nhãn "entry" ở lần chạm 3.
- Loại 2: có nhãn "entry" ở lần hồi về chạm đường sau khi đường bị phá.
- Loại 3: kênh giá (channel), không có chấm neo và không có nhãn "entry".

**Tr.6 – 6 loại trendline (phần 2): QM, 666, XR.**
- QM và 666: chỉ có hình, có nhãn "entry".
- XR: có chữ.
  - X là cấu trúc giá tạo bởi 2 trendline cắt nhau.
  - R là xoay/chỉnh đường để tìm góc phù hợp.
  - 2 đường (kháng cự + hỗ trợ) dùng để xác định xu hướng/hướng đi ngắn hạn hoặc dài hạn, và khả năng hình thành động lượng (momentum).
  - Tác giả ghi đây là "bí quyết dùng hằng ngày".
- Sơ đồ chữ X:
  - ở giao điểm: "HIGH MOMENTUM – Less PIPS", có ô tô màu;
  - ở hai đầu mở rộng: "LOW MOMENTUM – More PIPS", có sọc hồng dày dần ra ngoài.
  - Không có giải thích thêm.

**Tr.7 – XR Boom Point: 2 sơ đồ và 2 chart M30.**
- Chữ: Boom Point là sự kết hợp các loại trendline khác nhau. Nếu không thấy trendline trên cùng khung thì dùng 2 khung.
- Sơ đồ "QM TL + Loại 2" (bán):
  - QM nối 2 vai H1, H2; đầu HH vượt lên trên đường.
  - Loại 2 nối 2 đáy L1 < L2; sau đó bị nhịp giảm (LL) phá.
  - Giá hồi lên đúng giao điểm, nhãn "entry"; sau đó giảm.
- Sơ đồ "Loại 1 + Loại 6" (bán):
  - Loại 1 nối 2 đỉnh thấp dần.
  - Đường dốc lên đi từ một đáy A, qua đỉnh D của lần hồi đầu tiên sau khi đường bị phá. Cách dựng này đúng như Trendline 666.
  - Giá chạm giao điểm, nhãn "entry"; sau đó giảm.
- Chart trái và chart phải là **cùng dữ liệu XAUUSD M30, 16–20/6/2022**. Số liệu chi tiết ở mục 4.2.
  - Chart trái "QM TL + Loại 2": bán tại giao điểm ~1851,1.
  - Chart phải "Loại 1 + Loại 2": giao điểm ~1845,6. Ảnh chụp dừng khi giá mới giảm ~3,7 USD.
  - Nến vào lệnh ở chart trái (nến tăng đóng ~1851,2, chiều 17/6) chính là **neo 2 của đường Loại 1** ở chart phải.
- Cả hai chart không có nhãn "entry"; điểm vào suy ra từ giao điểm.

**Tr.8 – XR Boom Point: 2 chart.**
- **W1 "Loại 2 + Loại 1", 10/2021–6/2022:**
  - Đường dốc xuống qua đỉnh thân 2 nến tăng ~1864,2 (tuần ~8/11/2021) và ~1834,6 (tuần ~16/1/2022). Đường bị phá lên vào tháng 1–2/2022.
  - Đường dốc lên qua 2 đáy thân:
    - ~1783,5 (tuần ~5/12/2021): chấm che mất thân, không thấy màu nến;
    - ~1791,5 (nến giảm, tuần ~23/1/2022).
  - Giao điểm ~1802,5, khoảng đầu tháng 4/2022. Lúc đó giá ở ~1920–1990, **không chạm**.
  - Tháng 5/2022, giá về đường dốc lên:
    - thân nến tăng mở ~1809,5, đúng trên đường; nến giảm trước đó đóng ~1812,5;
    - bóng dưới xuống ~1788, cách đường dốc xuống (~1784,6) khoảng 3–4 USD;
    - sau đó giá bật lên ~1871–1879.
  - Không có nhãn "entry".
- **H1 "Trendline 666 + Loại 1", 25–31/3/2022:**
  - Đường 666:
    - neo 1 = đáy thân nến giảm ~1948,7 (25/3);
    - một nến giảm lớn phá xuống qua đường;
    - neo 2 = đỉnh thân nến tăng nhỏ ~1948,1 ngay sau cú phá, tức lần hồi đầu tiên chạm đường từ dưới lên.
  - Giá sau đó xuống ~1893.
  - Đường Loại 1 dốc **lên**, nối đỉnh thân 2 nến tăng ~1927,9 (28/3) và ~1937,2 (30/3). Hai neo cách nhau ~35 nến.
  - Giao điểm ~1944,3 (31/3):
    - một nến tăng đóng đúng ~1944,2;
    - nến tăng nhỏ kế tiếp có thân ~1944,3–1945,1 (vượt ~0,8 USD) và bóng lên ~1949,8 (vượt ~5,5 USD);
    - sau đó nến giảm đóng ~1941,5; giá về ~1932,4 ở cuối chart.

**Tr.9 – Trang ngăn "tâm lý".** Chỉ có ảnh. Bản gốc ghi "psycology by 411".

**Tr.10 – Tâm lý, hệ thống, rủi ro & lợi nhuận.**
- Bản gốc tiếng Anh ghi phân tích kỹ thuật chỉ chiếm **10%** việc giao dịch. Bản Việt bỏ con số 10% và chỉ ghi "một phần".
- Hệ thống:
  - TRIAL: chỉ dùng một kỹ thuật;
  - ADJUST (LEARN): tăng thời gian luyện tập, đo lại quá khứ (backtest) đều đặn;
  - SYSTEM: lặp lại thói quen tốt, tránh điều tiêu cực.
- Rủi ro là số tiền sẵn sàng mất; lợi nhuận là số tiền muốn kiếm.
- Chữ lớn "RISK 1 : 5 REWARDS". Ví dụ: dừng lỗ 40 pips, chốt lời 200 pips.
- Khung bên phải: cách kiểm soát cảm xúc (tinh thần, cơ thể, tâm hồn). Không có quy tắc cho bot.

---

## 3. Định nghĩa chính xác và công thức nến

### 3.0 Ký hiệu
- Nến i trên khung vẽ đường: `O[i], H[i], L[i], C[i]`.
- i tăng dần theo thời gian (khác kiểu đánh số series của MQL5).
- Mô tả cho lệnh BÁN; lệnh MUA là đối xứng: đổi đỉnh ↔ đáy, tăng ↔ giảm, trên ↔ dưới.

### 3.1 Nến tăng, nến giảm, thân, bóng
- Nến tăng: `C[i] > O[i]`. Nến giảm: `C[i] < O[i]`.
- Thân trên = `max(O,C)`, thân dưới = `min(O,C)`. Bóng trên = từ thân trên tới `H`; bóng dưới = từ `L` tới thân dưới.
- Nến doji (`C = O`): **tài liệu không nói** xử lý thế nào.

### 3.2 Điểm neo theo Móc nến (Hooking)
- **Tài liệu ghi rõ:** kháng cự dùng thân nến tăng, hỗ trợ dùng thân nến giảm, và điểm phải đặt trên thân.
- **Suy ra từ hình** (18/20 neo nhìn rõ trên 6 chart thật):
  - Neo kháng cự: nến i tăng, giá neo `P = C[i]` (mép trên thân).
  - Neo hỗ trợ: nến i giảm, giá neo `P = C[i]` (mép dưới thân).
  - Bóng bị bỏ qua. Có ca bóng dài hơn thân rất nhiều, ví dụ neo 1 chart H4 tr.2: thân 1800,4, bóng 1786,8.
  - Nến i+1 luôn **đổi màu** so với nến i. Đúng ở 18/20 neo; 1 neo bị chấm che (W1); 1 neo có nến kế tiếp mờ, khó xác định màu (H1 tr.8).
  - Nến neo là đỉnh/đáy **thân** cục bộ. Độ rộng cửa sổ để xác định "cục bộ" thì **không có**.
- **Vai trò của điểm quyết định loại nến, không phải loại đường.** Ví dụ đường 666 ở tr.8:
  - neo 1 là hỗ trợ (đáy thân nến giảm);
  - neo 2 là kháng cự sau khi đường bị phá (đỉnh thân nến tăng).

### 3.3 Đường tia (Ray Right)
- **Tài liệu ghi rõ:** điểm 1 của công cụ đặt ở điểm giá cũ, điểm 3 ở điểm giá mới, bật Ray Right. Điểm 2 của công cụ là chấm kéo ở giữa (hình cho thấy luôn nằm đúng giữa).
- Công thức (suy ra), với `t` là **số thứ tự nến trên đúng khung đã vẽ**:
  `L(t) = P1 + (P2 − P1) · (t − t1) / (t2 − t1)`, dùng cho `t > t2`.
- Trên MT5, trendline nối theo vị trí nến, bỏ qua khoảng trống cuối tuần/giờ nghỉ. Nếu tính theo thời gian tuyệt đối, giá trị sẽ lệch.

### 3.4 "Chạm", "phá", "bên nào của đường"
- **Tài liệu không định nghĩa** chạm hay phá. Hình cho thấy:
  - **Chạm khi vào lệnh**, đo trên 5 chart thật có điểm vào (chi tiết ở mục 4.2):
    - thân nến đóng đúng trên đường (lệch ~0–0,1 USD): H4 tr.2, M30 trái tr.7, H1 tr.8;
    - hoặc chỉ bóng chạm/vượt, thân còn cách ~1–1,9 USD: H1 tr.2, M30 phải tr.7.
    - Thân nến chạm có lúc vượt đường tối đa ~0,8 USD (H1 tr.8).
    - Bóng vượt đường tới ~2,3 USD (H1 tr.2) và ~5,5 USD (H1 tr.8).
  - **Phá đường:** trong các chart thật, đường bị phá bằng **thân nến đóng hẳn qua đường** (M30 trái, M30 phải tr.7; H1 tr.8). Trong sơ đồ zigzag, nét giá cắt qua đường.
- Tóm lại: thân nến thường tôn trọng đường, còn bóng có thể xuyên qua. Dung sai cụ thể **không có**, phải đo.

### 3.5 Hợp lưu SNR + trendline (tr.2–3)
- **Tài liệu ghi rõ:** hai điểm hội tụ (SNR là điểm 1, trendline là điểm 2) cho ra một quyết định.
- **Suy ra từ hình tr.3** (bán):
  - mức SNR = `B = L1`, đáy giữa của mô hình M;
  - trendline qua đỉnh H1 và H2, với `H2 < H1`;
  - trước khi vào lệnh phải có giá xuống dưới `L1` rồi dưới `L0` (= A của phần 1, với `L0 < L1`);
  - điểm vào là lúc giá hồi lên chạm `B`, và `|L(t) − B|` gần bằng 0.
- Cách kẻ SNR (theo thân hay bóng): phần 2 không nói. Phần 1 dùng High/Low (tính cả bóng) cho mức phá, và cả cây nến cho vùng.

### 3.6 Góc: Cơ bản và Phân kỳ (tr.4, suy ra từ hình)
Gọi `S = (P2 − P1)/(t2 − t1)` là độ dốc của đường.
- Cơ bản bán: 2 neo là đỉnh, `S < 0`, các đáy cũng thấp dần. Vào ở lần chạm 3.
- Phân kỳ bán: 2 neo là đỉnh, `S > 0`, các đáy cao dần. Vào ở lần chạm 3 (ngược xu hướng).
- Mua: đổi dấu.
- **Không có:** giới hạn độ dốc, hay có nên giao dịch kiểu Phân kỳ không.

### 3.7 Sáu loại trendline (suy ra từ hình; chỉ XR có chữ)
Ký hiệu: `Hk` là đỉnh, `Lk` là đáy, theo thứ tự thời gian; `N1, N2` là 2 neo. Tất cả mô tả cho lệnh bán.

- **Loại 1 (tr.5)** – đường cùng chiều lệnh, vào ở lần chạm 3.
  - Chuỗi: `L0 → H1 (N1) → L1 → H2 (N2) → đáy mới → hồi chạm tia → bán`.
  - Điều kiện: `H2 < H1`; `L1 > L0`; sau N2, giá xuống dưới **cả** `L1` và `L0`.
  - Điểm vào nằm ngang mức `L1`, giống hệt Setup tr.3 nhưng bỏ đường đỏ.
  - Chart tr.8 H1 gọi một đường **dốc lên** qua 2 đỉnh là "Loại 1", tức Loại 1 không bắt buộc dốc xuống.
- **Loại 2 (tr.5)** – đường ngược chiều lệnh, bị phá rồi kiểm tra lại (retest).
  - Chuỗi: `L1 (N1) → H → L2 (N2) → H' (< H) → giảm mạnh, thủng đường và thủng L1 → hồi lên chạm tia từ phía dưới → bán`.
  - Điều kiện: `L2 > L1` (đường dốc lên); có nến phá xuống dưới đường; giá xuống dưới `L1`.
  - Điểm vào nằm ngang mức `H'` (đỉnh cuối trước khi phá), cao hơn mức B của phần 1.
- **Loại 3 (tr.5)** – kênh giá. Hình không có neo và không có nhãn "entry".
  - Bán: kênh **giảm**; đường trên chạm 3 đỉnh, đường dưới chạm 2 đáy.
  - Giá thủng đường dưới, tạo đáy, hồi lên chạm lại đường dưới từ phía dưới (lần chạm thứ 3 của đường này), rồi giảm tiếp.
  - Mua: kênh **tăng** bị phá lên, hồi về chạm đường trên từ phía trên.
  - Nghĩa là phá kênh **theo chiều dốc của kênh**, rồi retest.
- **QM (tr.6)** – nối 2 vai, bỏ qua đầu.
  - Chuỗi: `H1 (N1) → L1 → HH → L2 → H2 (N2) → LL → hồi chạm tia → bán`.
  - Điều kiện: `HH > H1`, `HH > H2`, và HH nằm trên đường; `L2 > L1`; `LL < L1`.
  - Mua: `LL` xuyên xuống dưới đường; sau N2 giá tạo `HH` vượt đỉnh cũ.
- **666 (tr.6)** – neo 2 là lần retest đầu tiên sau khi phá.
  - Chuỗi: `A = đáy (N1) → giá dao động phía trên đường → giảm mạnh, cắt đường và xuống dưới A → hồi chạm đường từ dưới tại D = đỉnh (N2) → đáy thấp hơn → hồi chạm tia lần nữa → bán`.
  - Neo 1 dùng thân nến giảm; neo 2 dùng thân nến tăng (mục 3.2).
- **XR (tr.6–8)** – 2 đường cắt nhau.
  - Tài liệu ghi rõ: 2 đường (kháng cự + hỗ trợ) cắt nhau; "R" là xoay đường cho góc phù hợp; dùng để xác định xu hướng và động lượng.
  - Boom Point: giao điểm của 2 đường **khác loại**.
  - Suy ra từ hình: trong cả 5 hình Boom Point, **cả hai đường đều cho cùng một hướng lệnh**.

**Nhận xét chung (suy ra):** ở mọi hình có điểm vào (tr.2–8), điểm vào là **lần chạm thứ 3 của đường** (neo 1, neo 2, rồi điểm vào), kể cả Loại 2 và 666. Ở Loại 3, lần retest cạnh bị phá cũng là lần chạm thứ 3 của cạnh đó, dù hình không ghi "entry". Các loại chỉ khác nhau ở điều kiện cấu trúc trước lần chạm 3:
- chưa phá (Cơ bản, Phân kỳ);
- phá cấu trúc cùng chiều (Loại 1, QM);
- đường đã bị phá (Loại 2, Loại 3, 666).

### 3.8 Rủi ro/lợi nhuận (tr.10)
- **Tài liệu ghi rõ:** tỷ lệ lời/lỗ 1:5, ví dụ dừng lỗ 40 pips, chốt lời 200 pips.
- **Không có:** pip vàng bằng bao nhiêu, tỷ lệ này bắt buộc hay chỉ là ví dụ, % vốn rủi ro mỗi lệnh.

### 3.9 Tâm lý và hệ thống (tr.10)
Không có quy tắc nào dùng được cho EA. Ý duy nhất gần với bot là: dùng một kỹ thuật và đo lại quá khứ đều đặn.

---

## 4. Kiểu vào lệnh, giá vào, dừng lỗ, chốt lời

### 4.1 Các kiểu vào lệnh (tài liệu chỉ vẽ, không viết thành quy tắc)
| Kiểu | Hướng lệnh | Giá vào (theo hình) | Nguồn |
|---|---|---|---|
| Chạm lần 3 – Cơ bản / Phân kỳ | Đường qua đỉnh → bán; qua đáy → mua | `L(t)` tại lần chạm 3 | tr.4; chart tr.2 |
| Loại 1 | Như trên | `L(t)`, ngang mức `L1` (bán) / `H1` (mua) | tr.5 |
| Hợp lưu SNR + TL | Như trên | Mức B = `L(t)` | tr.3 |
| Loại 2 | Theo hướng phá | `L(t)` lúc hồi về chạm từ phía bên kia | tr.5 |
| Loại 3 | Theo hướng phá kênh | Cạnh kênh bị phá, lúc retest (hình không ghi "entry") | tr.5 |
| QM | Đường qua 2 vai đỉnh → bán | `L(t)` tại lần chạm 3 | tr.6 |
| 666 | Theo hướng phá | `L(t)` ở lần retest thứ 2 (lần chạm 3) | tr.6 |
| XR Boom Point | Hướng chung của 2 đường | Giá tại giao điểm | tr.7–8 |

### 4.2 Số liệu từng ví dụ thật (đọc từ ảnh; tài liệu không ghi số nào)
| Chart | Khung | Đường | Giá vào (đường/giao điểm) | Nến lúc chạm | Ngược chiều tối đa thấy được | Thuận chiều tối đa thấy được |
|---|---|---|---|---|---|---|
| tr.2 trái | H4 | Hỗ trợ: 1800,4 → 1810,4 (13 nến) | ~1813,6–1814 (mua) | Nến giảm đóng ~1813,9 trên đường; nến sau là nến tăng lớn | Bóng xuống dưới đường ~0,3–0,5 | Lên ~1849 (≈ +35) |
| tr.2 phải | H1 | Kháng cự: 1859,1 → 1854,8 (15 nến) | ~1853,1 (bán) | Nến tăng, thân ≤ 1851,2 (dưới đường ~1,9), bóng 1855,4; nến sau là nến giảm lớn | Bóng trên đường ~2,3 | Xuống ~1836 (≈ −17 so với đường) |
| tr.7 trái | M30 | QM 1850,2 → 1850,9 (32 nến) × Loại 2 1842,1 → 1845,5 (6 nến) | ~1851,1 (bán) | Nến tăng đóng ~1851,2, bóng ~1853,0; nến sau giảm 1851,4 → 1846,2 | Bóng trên giao điểm ~1,9 | Xuống ~1836, bóng ~1833,8 (≈ −15 đến −17) |
| tr.7 phải | M30 | Loại 1 1857,1 → 1851,2 × Loại 2 1844,9 → 1845,0 | ~1845,6 (bán) | Thân ≤ 1844,6, bóng ~1846,1 | Bóng trên giao điểm ~0,5 | Chỉ thấy −3,7 (ảnh dừng ở 1841,9) – **không biết kết quả** |
| tr.8 trái | W1 | Loại 2 1864,2 → 1834,6 × Loại 1 1783,5 → 1791,5 | Giao điểm ~1802,5, **không được chạm** | Tháng 5/2022: thân chạm đường Loại 1 (~1809,5), bóng ~1788 | – | Bật lên ~1871–1879 |
| tr.8 phải | H1 | 666: 1948,7 → 1948,1 × Loại 1 1927,9 → 1937,2 | ~1944,3 (bán) | Nến tăng đóng ~1944,2; nến tăng nhỏ thân tới 1945,1, bóng 1949,8; rồi nến giảm | Bóng trên giao điểm ~5,5 | Xuống ~1932,4 ở cuối chart (≈ −12) |

- Ở 4/5 ca có điểm vào, cây nến ngay sau lần chạm là **nến mạnh theo hướng lệnh**. Ca còn lại (tr.7 phải) thì ảnh chụp dừng trước khi thấy kết quả.
- Giao điểm và nến chạm cách nhau khoảng 0–2 nến: tr.7 trái cùng nến; tr.7 phải sớm ~1,5 nến; tr.8 phải cùng nến.

### 4.3 Dừng lỗ (stop loss)
- **Tài liệu không có quy tắc** đặt dừng lỗ ở đâu: không nói trên bóng nến, trên neo, trên đỉnh gần nhất, hay cộng thêm đệm.
- Chỉ có ví dụ độ lớn 40 pips (tr.10), không gắn với chart nào.

### 4.4 Chốt lời (take profit)
- **Tài liệu không có quy tắc** chốt ở đâu. Chỉ có tỷ lệ 1:5 và ví dụ 200 pips.
- Phần 1 có ý: chốt tại vùng cản ngược chiều, theo bảng khung (TF Roadblock). Phần 2 không nhắc lại.

### 4.5 Xác nhận và loại lệnh
- **Không có** quy tắc nến xác nhận.
- **Không nói** dùng lệnh chờ tại đường hay lệnh thị trường.
- Hình cho thấy có ca vào bằng thân đóng đúng trên đường, có ca chỉ bóng chạm (mục 3.4).

---

## 5. Khung thời gian, quy trình khung lớn → khung nhỏ, và quan hệ với phần 1

**Tài liệu ghi rõ:**
- Trendline dùng để xác định xu hướng và điểm vào (tr.2).
- XR xác định xu hướng/hướng đi ngắn hạn hoặc dài hạn (tr.6).
- Nếu không thấy trendline trên cùng một khung thì dùng 2 khung (tr.7).

**Hình cho thấy:**
- Khung dùng trong ví dụ: W1, H4, H1, M30.
- Cả 5 ví dụ XR đều vẽ **cả 2 đường trên cùng 1 khung**. Không có ví dụ nào dùng 2 khung.

**Không có:**
- quy tắc khung nào lấy hướng lớn (bias), khung nào vẽ đường, khung nào vào lệnh;
- quy trình từ khung lớn xuống khung nhỏ;
- M15, M5, M1.

**Phần 2 mở rộng phần 1 như thế nào:**
1. **Setup A/B của phần 1 được thêm trendline** (tr.3). Mức B (đường vào lệnh) trùng với tia nối 2 đỉnh của M (2 đáy của W) → "hợp lưu SNR + TL". Loại 1 ở tr.5 là cùng hình, bỏ đường SNR.
2. **Cách neo khác nhau:**
   - phần 1: mức phá dùng High/Low (tính bóng); vùng vào lệnh là cả cây nến gồm bóng;
   - phần 2: trendline neo vào **giá đóng cửa ở thân**, bỏ bóng.
   - Hai công cụ dùng hai cách lấy giá khác nhau.
3. **"Phá 2 mức" của phần 1** có dạng tương tự ở Loại 1 (thủng L1 rồi L0), QM (LL thủng L1 và L2) và Loại 2 (thủng L2 rồi L1). Phần 2 không viết điều này ra; đây là tôi so hình.
4. **Số 3:** phần 1 có câu "ONLY 3 TIMES MAXIMUM PRECISE". Phần 2 luôn vào ở lần chạm 3 của đường. Có thể liên quan, nhưng tài liệu không nói.
5. **Fresh:** phần 1 chỉ dùng vùng chưa chạm (fresh). Phần 2 thì 666 dùng đường **sau** một lần retest, và Loại 2/Loại 3 dùng đường đã bị phá. Tức trendline không theo luật fresh của vùng.
6. **Khung:** phần 1 có HTF (W1, D1, H4) cho vùng/hướng và LTF (H1, M30, M15) để vào lệnh. Các khung trong phần 2 nằm trong hai nhóm này, nhưng phần 2 không gắn đường với nhóm nào.
7. **Rủi ro:** phần 1 không có tỷ lệ lời/lỗ; phần 2 thêm 1:5 (ví dụ 40/200 pips).

**Liên hệ với bot** (theo `docs/SPEC.md`: vùng ở M15–W1, M1/M5 chỉ để tìm điểm vào):
- Tài liệu không cho biết trendline vẽ ở M15/H1 có dùng để vào lệnh ở M1/M5 được không.
- Đây là quyết định của chủ bot và phải đo (mục 7).

---

## 6. Bảng quy tắc lập trình được

Cột "Nguồn": **Tài liệu ghi rõ** = có chữ trong tài liệu; **Suy ra từ hình** = thấy nhất quán trên sơ đồ/chart nhưng không có chữ; **Không có — cần đo** = tài liệu không nói, phải chọn và đo.

| # | Quy tắc | Công thức / cách code | Nguồn |
|---|---|---|---|
| 1 | Đường là tia sang phải qua 2 neo | `L(t) = P1 + (P2−P1)(t−t1)/(t2−t1)`, `t` = số nến của khung vẽ, `t > t2` | Tài liệu ghi rõ (Ray Right, điểm 1/điểm 3); công thức suy ra |
| 2 | Neo kháng cự ở thân nến tăng | `C[i] > O[i]`, `P = C[i]` | Tài liệu ghi rõ (thân nến tăng); chọn đúng `C` là suy ra từ hình |
| 3 | Neo hỗ trợ ở thân nến giảm | `C[i] < O[i]`, `P = C[i]` | Tài liệu ghi rõ; chọn `C` suy ra từ hình |
| 4 | Bỏ bóng khi neo | Không dùng `H`/`L` cho neo | Suy ra từ hình (tài liệu dặn đặt trên thân) |
| 5 | Nến sau neo đổi màu | Kháng cự: `C[i+1] < O[i+1]`; hỗ trợ: `C[i+1] > O[i+1]` | Suy ra từ hình (18/20 neo) |
| 6 | Neo là đỉnh/đáy thân cục bộ | Cửa sổ so sánh bao nhiêu nến | Không có — cần đo |
| 7 | Loại nến neo theo vai trò của điểm | Neo đỉnh dùng nến tăng, neo đáy dùng nến giảm, kể cả khi cùng một đường (666) | Suy ra từ hình |
| 8 | Hướng lệnh theo phía đường | Đường qua 2 đỉnh chưa bị phá → bán khi chạm; qua 2 đáy → mua; đường đã bị phá → theo hướng phá | Suy ra từ hình |
| 9 | Vào ở lần chạm 3 | Lần chạm đầu tiên sau N2 thỏa điều kiện cấu trúc của loại | Suy ra từ hình (mọi hình có "entry") |
| 10 | Cơ bản: đường cùng xu hướng | Bán: `P2 < P1`, đáy thấp dần; mua ngược lại | Suy ra từ hình tr.4 |
| 11 | Phân kỳ: đường ngược xu hướng | Bán: 2 đỉnh cao dần (`P2 > P1`), đáy cao dần | Suy ra từ hình; có dùng hay không thì không có |
| 12 | Loại 1 | `H2 < H1`, `L1 > L0`; sau N2 có giá `< L1` và `< L0`; rồi chạm `L(t)` | Suy ra từ hình tr.5 |
| 13 | Hợp lưu SNR + TL | Như #12, và mức `B = L1` gần `L(t)` khi chạm | Suy ra từ hình tr.3 + phần 1; dung sai không có |
| 14 | Loại 2 | Đường qua 2 đáy (`L2 > L1`) bị nến đóng dưới đường, giá `< L1`; bán khi hồi chạm `L(t)` từ dưới | Suy ra từ hình tr.5 và chart tr.7 |
| 15 | Loại 3 (kênh) | 2 đường song song; phá cạnh theo chiều dốc của kênh; retest cạnh đó | Suy ra từ hình; không có nhãn "entry" |
| 16 | QM | Có `HH` giữa 2 neo, nằm trên đường, cao hơn cả 2 neo; `L2 > L1`; `LL < L1`; rồi chạm `L(t)` | Suy ra từ hình tr.6 và chart tr.7 |
| 17 | 666 | N1 = đáy (nến giảm); phá xuống dưới N1; N2 = lần hồi đầu tiên chạm đường từ dưới (nến tăng); có đáy thấp hơn; vào ở lần chạm kế | Suy ra từ hình tr.6 và chart tr.8 |
| 18 | XR Boom Point | 2 đường khác loại, cùng hướng lệnh; vào khi giá chạm gần giao điểm | Tài liệu ghi rõ "kết hợp các loại khác nhau"; cùng hướng và vào tại giao điểm là suy ra từ hình |
| 19 | Xoay đường ("R") | Chọn neo khác để có góc phù hợp | Tài liệu ghi rõ ý; cách làm thì không có |
| 20 | Dung sai chạm | Thân/bóng cách `L(t)` bao nhiêu thì tính là chạm | Không có — cần đo (hình: thân lệch 0–1,9; bóng vượt tới 5,5 USD) |
| 21 | Định nghĩa phá | Đóng cửa qua đường, hay bóng qua đường, có cần đệm không | Không có — cần đo (hình: thân đóng qua) |
| 22 | Khoảng cách giao điểm ↔ lúc chạm | Số nến cho phép | Không có — cần đo (hình: 0–2 nến) |
| 23 | Loại lệnh | Lệnh chờ tại `L(t)` hay chờ nến đóng xác nhận | Không có |
| 24 | Dừng lỗ | Vị trí và đệm | Không có |
| 25 | Chốt lời | 5 × rủi ro? | Tài liệu ghi rõ tỷ lệ 1:5 (ví dụ 40/200 pips); bắt buộc hay không thì không có |
| 26 | Pip vàng | 0,01 / 0,1 / 1 USD | Không có (Exness ghi pip vàng = 0,01, xem research 05) |
| 27 | Khung vẽ / khung vào lệnh | Cặp khung | Không có (chỉ ghi "dùng 2 khung nếu cần"; ví dụ W1/H4/H1/M30) |
| 28 | Hạn dùng của đường | Hết hạn sau bao lâu, sau mấy lần chạm, sau khi đã dùng | Không có — cần đo |
| 29 | Ưu tiên giữa các loại/đường | – | Không có (chỉ ghi XR là bí quyết dùng hằng ngày) |

---

## 7. Câu hỏi mở

### 7a. Quyết định bằng đo đạc (chạy lại dữ liệu cũ XAUUSD)
Mỗi câu nên đo thành phân bố trên nhiều ca, không chọn trước một con số.
1. **Chọn neo:**
   - Cửa sổ bao nhiêu nến để coi một thân nến là đỉnh/đáy cục bộ?
   - Điều kiện "nến sau đổi màu" (#5) làm tăng hay giảm tỷ lệ thắng?
2. **Dung sai chạm:**
   - Tính theo ATR của khung vẽ, theo spread, hay theo USD cố định?
   - Xét thân (đóng cửa) hay xét bóng?
   - Mốc đối chiếu từ hình: thân lệch 0–1,9 USD, bóng vượt tới 2,3 USD (H1) và 5,5 USD (H1).
3. **Định nghĩa phá:** chỉ cần thân đóng qua đường, hay cần thêm một đệm? Có cần giá vượt neo 1 (Loại 2) hoặc thủng cả `L1` và `L0` (Loại 1) không?
4. **Loại lệnh:** so (A) lệnh chờ tại `L(t)` (cập nhật lại mỗi nến) với (B) chờ nến chạm đường rồi đóng quay lại đúng phía. Ở 4/5 ca, nến sau lần chạm là nến mạnh theo hướng lệnh.
5. **Dừng lỗ:** đo mức ngược chiều tối đa (MAE) sau khi chạm, theo từng khung, để chọn giữa:
   - trên/dưới bóng nến chạm;
   - trên/dưới neo 2;
   - một khoảng cố định tương đương "40 pips".
   - Từ hình: bóng vượt 0,3–5,5 USD.
6. **Chốt lời:** đo mức thuận chiều tối đa (MFE) để xem 1:5 có đạt được không.
   - Từ hình: +35 (H4), −12 đến −17 USD (H1/M30).
   - Với quy ước 1 pip = 0,1 USD thì 200 pips = 20 USD: chỉ ca H4 đạt.
   - Với quy ước 0,01 USD (Exness) thì 200 pips = 2 USD: mọi ca đều đạt, nhưng dừng lỗ 0,4 USD nhỏ hơn phần bóng vượt đường ở hầu hết các hình (trừ ca H4: 0,3–0,5).
7. **Khoảng cách giao điểm ↔ lúc chạm** cho Boom Point: bao nhiêu nến là còn hợp lệ (hình: 0–2)?
8. **Độ dốc:** có loại đường quá dốc hay quá phẳng không?
   - Hình có đường gần nằm ngang (tr.7 phải: 1844,9 → 1845,0) và đường rất dốc (tr.7 trái, Loại 2: +3,4 USD trong 6 nến M30).
9. **Hạn dùng của đường:** sau bao nhiêu nến kể từ N2 thì bỏ?
   - Từ hình: lần chạm 3 đến sau N2 khoảng 4 nến (H4), 6 nến (H1), 7–12 nến (M30), 25 nến (H1 tr.8), ~16 tuần (W1).
10. **Khung:** trendline vẽ ở khung nào (M15, H1, H4) cho kết quả tốt nhất khi vào lệnh ở M1/M5? Có cần đường ở khung lớn cùng hướng không?
11. **Loại nào đáng giữ:** đo riêng từng loại (Cơ bản, Phân kỳ, 1, 2, 3, QM, 666, XR) trước khi gộp.

### 7b. Cần chủ bot giải thích hoặc chốt (tài liệu mơ hồ)
1. **Đánh số loại:** sơ đồ tr.7 ghi "Loại 1 + Loại 6" nhưng đường vẽ đúng kiểu 666. Vậy QM là Loại 4, 666 là Loại 5, XR là Loại 6? Hay 666 chính là "Loại 6"?
2. **Loại 1 có phải dốc xuống (bán) không?** Chart tr.8 H1 gọi đường dốc lên qua 2 đỉnh là "Loại 1".
3. **Có giao dịch kiểu Phân kỳ (ngược xu hướng) không?**
4. **Hai chart tr.2 là kiểu Cơ bản** (không có cú phá trước khi chạm lần 3). Loại 1 có bắt buộc phải thủng `L1` và `L0` trước không?
5. **Móc nến khi không có nến đúng màu ở đỉnh/đáy, hoặc nến neo là doji:** neo ở đâu?
6. **SNR trong hợp lưu:** SNR chính là mức B của phần 1 (theo High/Low), hay là mức kẻ theo thân?
7. **Chart tr.2 H1:** nhãn "entry" không chỉ vào nến nào. Nến ngay sau neo 2 đã có bóng vượt đường. Lần chạm bằng bóng có tính không?
8. **Loại 3:** có vào lệnh bên trong kênh (chạm cạnh) không, hay chỉ vào sau khi phá rồi retest?
9. **Sơ đồ XR "High momentum – Less pips / Low momentum – More pips":** nghĩa là gì trong giao dịch?
   - Đây chỉ là cách tôi hiểu, không phải của tài liệu: gần giao điểm thì 2 đường sát nhau, nên có thể đặt dừng lỗ ngắn và giá đi mạnh; xa giao điểm thì ngược lại.
10. **Chart W1 tr.8:** giao điểm không được chạm. Lần giá về tháng 5/2022 (thân trên đường Loại 1, bóng gần đường Loại 2) có phải là "Boom Point" tác giả muốn chỉ không?
11. **"Dùng 2 khung":** cặp khung nào? Tính giao điểm thế nào khi 2 đường nằm ở 2 khung khác nhau?
12. **Tỷ lệ 1:5 và 40/200 pips:** là bắt buộc hay ví dụ? 1 pip vàng bằng bao nhiêu?

---

## 8. Mọi con số có trong tài liệu

- Trendline có 2 neo. Công cụ có 3 chấm: chấm 1 và chấm 3 là neo, chấm 2 ở giữa.
- "6 loại" trendline; tên "666", "QM", "XR"; XR gồm 2 đường; "dùng 2 khung thời gian".
- Tỷ lệ lời/lỗ **1:5**; ví dụ dừng lỗ **40 pips**, chốt lời **200 pips**.
- Bản gốc tiếng Anh: phân tích kỹ thuật chỉ chiếm **10%** việc giao dịch (bản Việt bỏ con số này).
- **Không có:** dung sai chạm, định nghĩa phá, số nến, độ dốc, giờ/phiên, ATR, spread, % rủi ro mỗi lệnh, giới hạn số lệnh, pip vàng.
- Mọi giá, ngày và số nến ở mục 2 và 4.2 là tôi đọc từ trục ảnh chụp, không phải số tài liệu ghi. Có thể dựng lại các đường này trên dữ liệu XAUUSD năm 2022 để kiểm tra code:
  - H4: 16–19/5;
  - H1: 30–31/5 và 25–31/3;
  - M30: 16–20/6;
  - W1: 10/2021–6/2022.

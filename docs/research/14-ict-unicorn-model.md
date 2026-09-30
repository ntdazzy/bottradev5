# Báo cáo: ICT Unicorn Model (`docs/tài liệu trade/ICTs Unicorn Model.pdf`)

Tôi đã đọc hết 7 trang. Công cụ Read không mở được file vì máy thiếu `pdftoppm`, nên tôi làm như sau:
- Cài thư viện PyMuPDF bằng `pip` (chỉ thay đổi môi trường máy, không đổi file dự án), lấy phần chữ có sẵn trong PDF.
- Chuyển từng trang thành ảnh PNG (220 dpi), tách 9 ảnh nhúng ở độ phân giải gốc, rồi xem từng ảnh và phóng to từng biểu đồ.
- Với 2 biểu đồ nến thật ở tr.6, tôi dò từng cột điểm ảnh để lấy tọa độ dọc (px) của thân nến, râu nến, cạnh các hộp và các đường.
  Biểu đồ **không có trục giá, không có trục thời gian, không có tên mã**, nên tôi chỉ tính được **tỷ lệ** (ví dụ số R), không tính được giá thật.
  Trên ảnh, px nhỏ hơn nghĩa là giá cao hơn. Tỷ lệ R chỉ đúng nếu trục giá là thang tuyến tính (mặc định của TradingView). Tôi coi đó là giả định.

Các thuật ngữ FVG/OB/breaker dùng cùng nghĩa với `docs/research/10-tradingview-smc-msnr-ob-fvg.md` (mục 1.2, 1.3, 2.2, 2.3).

Ký hiệu dùng trong báo cáo:
- c1, c2, c3 là các nến liền kề nhau theo thứ tự thời gian.
- O, H, L, C là giá mở cửa, cao nhất, thấp nhất, đóng cửa. Thân trên = max(O, C), thân dưới = min(O, C).
- "Nến xanh" = nến tăng (C > O); "nến đỏ" = nến giảm (C < O).

## 1. Tổng quan

- **Tên:** "ICT Unicorn Model — Checklist and setup guide" (tr.1).
- **Nguồn:** logo **FX Replay** ở tr.1 và tr.7. Đây là tài liệu quảng cáo cho nền tảng chạy lại dữ liệu (backtest) của FX Replay; tr.7 là trang quảng cáo.
  - Tài liệu không ghi tên tác giả. Chữ "ICT" không được giải thích. (Ngoài tài liệu: ICT thường là viết tắt của "Inner Circle Trader"; tài liệu không nói điều này.)
  - Tài liệu không có số liệu kết quả, không có thống kê thắng/thua. Câu "profitable strategy" ở tr.7 là lời quảng cáo, không có bằng chứng kèm theo.
- **Thị trường và khung thời gian:**
  - Tr.2 ghi thông số chung: khung **5 phút (5m)**, mã **ES** (hợp đồng tương lai chỉ số S&P 500), **phiên New York (NY Session)**. Không ghi giờ bắt đầu/kết thúc phiên.
  - Hai biểu đồ nến thật ở tr.6 **không có nhãn mã, khung, giờ hay giá**. Không kiểm được chúng có đúng là ES 5m hay không.
  - Ảnh chụp giao diện FX Replay ở tr.7 có chữ EURUSD 1h, nhưng đó là ảnh quảng cáo phần mềm, không phải ví dụ của mô hình.
  - Không có ví dụ nào về vàng (XAUUSD), không có M1, không có khung lớn.
- **Ý chính (4 bước):**
  1. Chọn **đích thanh khoản** (draw on liquidity, DOL): đỉnh bằng nhau tương đối (relative equal highs) hoặc đáy bằng nhau tương đối (relative equal lows). DOL quyết định chiều lệnh.
  2. Chờ **nhánh thao túng** (manipulation leg): giá chạy **ngược hướng DOL**, tạo đỉnh cao hơn / đáy thấp hơn.
  3. Sau đó giá **dịch chuyển mạnh** (displacement) về phía DOL, tạo ra một **khối phá vỡ** (breaker block, BB) và một **khoảng trống giá trị** (fair value gap, FVG) **chồng lên nhau**. Chỗ chồng nhau này chính là "Unicorn".
  4. Đặt **lệnh chờ** (limit order) khi giá quay lại thử vùng BB/FVG. Dừng lỗ ở **thân** cao nhất/thấp nhất của nhánh thao túng. Chốt lời ở **mức 2 độ lệch chuẩn** (2 standard deviations, tính bằng Fibonacci trên nhánh thao túng) hoặc giữ tới DOL. Lệnh phải cho ít nhất 2R.
- **Bố cục:** tr.1 bìa; tr.2 thông số, breaker, FVG; tr.3 bước 1–2 (DOL, thao túng); tr.4 vào lệnh, dừng lỗ, chốt lời, luật khác, danh sách kiểm; tr.5 một câu nhắc; tr.6 hai ví dụ nến thật; tr.7 quảng cáo.

## 2. Tóm tắt từng trang

**Tr.1 — Bìa.** Logo FX Replay, tựa "ICT Unicorn Model", phụ đề "Checklist and setup guide". Phía dưới là một đường giá trang trí màu xanh, không có ý nghĩa giao dịch.

**Tr.2 — Strategy Details (thông số, breaker, FVG).**
- Chữ: khung 5m, ES, phiên NY. Breaker = **khối lệnh thất bại** (failed order block); có thể là **một nhóm nến cùng màu** chứ không chỉ một nến.
  - Breaker tăng (bullish breaker): **nến xanh cuối cùng trước đáy thấp hơn** (lower low).
  - Breaker giảm (bearish breaker): **nến đỏ cuối cùng trước đỉnh cao hơn** (higher high).
- Hình "Bullish Breaker" (biểu đồ đường, không có nến):
  - Giá tạo đáy 1 (có đường chấm ngang kéo sang phải), tăng lên một đỉnh, rồi rơi xuống **đáy thấp hơn đáy 1** (đường chấm của đáy 1 bị cắt qua).
  - Sau đó giá tăng mạnh, vượt lên trên đỉnh đó (đường chấm ở đỉnh bị cắt), tạo đỉnh mới cao hơn.
  - Hộp màu cam nhãn "BRK" được vẽ **quanh đỉnh** trước cú rơi và kéo dài sang phải. Giá quay xuống chạm vào hộp rồi bật lên (mũi tên đi lên).
  - Có thêm một đường chấm mờ chạy suốt chiều ngang, nằm giữa đáy 1 và hộp. Hình không giải thích đường này.
- Hình "Bearish Breaker": đối xứng. Đỉnh 1 → đáy → **đỉnh cao hơn đỉnh 1** → rơi mạnh xuyên qua đáy → hồi lên chạm hộp "BRK" (vẽ **quanh đáy** trước cú tăng) → giảm tiếp (mũi tên đi xuống).
- Chữ về FVG: "các râu nến trước và sau một nến không chồng lên nhau".
- Hình FVG tăng: 3 nến xanh. Hộp FVG có **cạnh trên = đáy râu của c3**, **cạnh dưới = đỉnh râu của c1**; thân c2 phủ hết hộp. Mũi tên hai đầu chỉ chiều cao hộp. Hộp kéo sang phải.
- Hình FVG giảm: 3 nến đỏ. **Cạnh trên = đáy râu của c1**, **cạnh dưới = đỉnh râu của c3**.

**Tr.3 — Strategy Details (bước 1 và 2).**
- Bước 1: tìm DOL; tìm các đỉnh/đáy bằng nhau tương đối để làm DOL.
  - Hình trái "Equal Highs": ba đỉnh râu (khoanh tròn xanh) chạm cùng một đường ngang màu xanh. Ba mũi tên từ nhãn chỉ xuống ba đỉnh này. Các đỉnh không cần bằng nhau tuyệt đối; chúng chỉ chạm gần đường. Bên dưới có một đường chấm mảnh, không được giải thích. Sau đó giá giảm sâu rồi có nến xanh lớn hồi lên.
  - Hình phải "Equal Lows": hai đáy râu (khoanh tròn đen) chạm cùng một đường ngang hồng. Hai đáy cách nhau khoảng 20 nến.
  - Không có mã, khung, trục giá hay số đo sai số cho phép.
- Bước 2: sau khi có DOL, tìm **thao túng chạy xa khỏi DOL**, rồi **dịch chuyển mạnh** tạo ra breaker và FVG chồng nhau.
  - Hình trái (mua; nhãn "Draw on Liquidity" ở trên, "Manipulation" ở dưới). Đây là hình Bullish Breaker ở tr.2 có thêm hộp FVG màu xanh ngọc.
    - Hộp FVG bắt đầu ở đoạn giá tăng mạnh cắt qua hộp BRK, và nằm **ngay dưới** hộp BRK.
    - Theo đo điểm ảnh: BRK ≈ 145–170 px, FVG ≈ 166/172–195 px. Phần chồng nhau chỉ là **một dải mỏng ở mép dưới BRK / mép trên FVG**.
    - Điểm hồi (vòng tròn) nằm đúng dải chồng nhau đó; sau đó giá đi thẳng lên phía DOL (có một đường chấm ở mép trên hình).
  - Hình phải (bán; nhãn "Manipulation" ở trên, "Draw on Liquidity" ở dưới). Hộp FVG màu hồng nằm **ngay trên** hộp BRK cam. Theo đo điểm ảnh: BRK ≈ 166–192 px, FVG ≈ 140–164 px, dải chồng nhau hẹp ở mép trên BRK (≈ 164–170 px).
    - Điểm hồi lên chạm đúng dải chồng nhau, rồi giá giảm tiếp (mũi tên).
    - Các nút tròn/vuông trên hộp BRK và đường chữ thập chấm là dấu vết con trỏ/đang sửa hình trong phần mềm, không phải mức giá.

**Tr.4 — Strategy Details (vào lệnh, dừng lỗ, chốt lời) và Trade Checklist.**
- Vào lệnh: "cho đơn giản", vào khi giá **thử lại (retest) BB/FVG**.
- Dừng lỗ (stop loss, SL): tại **đỉnh/đáy thân nến (body high/low) của nhánh thao túng**.
- Chốt lời (take profit, TP): kẻ **Fibonacci thoái lui** (fib retracement) trên đỉnh/đáy của nhánh thao túng, rồi chọn một trong hai:
  - nhắm **2 độ lệch chuẩn** (2 standard deviations, "2 STDV");
  - hoặc **giữ lâu hơn tới DOL**.
- Luật khác:
  - Không giao dịch trong tin "thư mục đỏ" (red folder news). Đây là biểu tượng tin tác động mạnh trên lịch kinh tế. Tài liệu không ghi tránh trước/sau tin bao nhiêu phút.
  - **Không quản lý lệnh** (no trade management): để lệnh tự chạy tới SL hoặc TP.
  - Lệnh phải cho **ít nhất 2R**.
- Danh sách kiểm (3 dấu tích):
  1. có DOL cho chiều lệnh và có nhánh thao túng chạy xa khỏi DOL;
  2. breaker và FVG chồng nhau;
  3. vào khi giá thử lại FVG/breaker, nhắm 2 STDV hoặc DOL.

**Tr.5 — Một câu nhắc.** Nếu thiếu bất kỳ thông số nào thì chất lượng lệnh giảm; chỉ nên vào các mẫu "A+". Không có bảng chấm điểm hay trọng số.

**Tr.6 — Hai ví dụ nến thật.** Nền đen, kiểu TradingView, không có trục giá/thời gian/tên mã. Chi tiết đo ở mục 4.2.
- **Ví dụ A (trên, lệnh bán):**
  - Có các nhãn "Manipulation leg away from draw on liquidity", "Limit order on retest of overlapping FVG and Breaker" và "Draw on Liquidity" (đường xanh lam ở dưới).
  - Có Fibonacci với các mức 0, 1, 2 và hộp breaker cam kéo dài sang phải.
  - Hộp FVG có viền xanh lá; công cụ vị thế có phần đỏ (vùng lỗ) ở trên và phần xanh (vùng lời) ở dưới.
- **Ví dụ B (dưới, lệnh mua):**
  - Có các nhãn "Draw on Liquidity" (đường xanh lam ở trên, nối hai điểm neo tròn), "Limit order on retest…" và "Manipulation leg away from draw on liquidity".
  - Có Fibonacci 0, 1, 2 và hộp breaker cam. FVG chỉ là hai đường xanh lá rất sát nhau, tức một FVG rất mỏng, nằm trong hộp breaker.
  - Có thêm một đường xanh lam thứ hai **không có nhãn**, ở dưới vùng vào lệnh.

**Tr.7 — Quảng cáo.** "Now that you have a profitable strategy…", nút "Start backtesting for free", ảnh giao diện FX Replay (EURUSD 1h, lịch kinh tế). Không có nội dung về mô hình.

## 3. Định nghĩa chính xác

Mỗi mục ghi rõ nguồn: **[GHI RÕ]** là chữ trong tài liệu; **[HÌNH]** là suy ra từ hình/đo điểm ảnh; **[KHÔNG CÓ]** là tài liệu không nói.

**3.1 Đỉnh/đáy (swing high/low)**
- [KHÔNG CÓ] Tài liệu không định nghĩa đỉnh/đáy bằng số nến hai bên (pivot N/N) hay bằng cách nào khác.
- [HÌNH] Trong các hình đường ở tr.2–3, đỉnh/đáy là điểm gãy của đường zigzag. Ở tr.6, các đỉnh/đáy được dùng đều là **râu** cao nhất/thấp nhất của một nhịp.
- Nếu cần mã hóa, có thể dùng định nghĩa pivot trong tài liệu 10 (mục 1.1, 2.5). Đó là lựa chọn của mình, không phải của tài liệu Unicorn.

**3.2 Đích thanh khoản (draw on liquidity, DOL) — đỉnh/đáy bằng nhau tương đối**
- [GHI RÕ] DOL là nơi giá được "hút" tới. Tài liệu gợi ý dùng **đỉnh bằng nhau tương đối / đáy bằng nhau tương đối**.
- [GHI RÕ] DOL quyết định **chiều lệnh**: DOL ở trên thì tìm lệnh mua, DOL ở dưới thì tìm lệnh bán (danh sách kiểm tr.4 ghi "DOL for trade direction").
- [HÌNH] Tr.3: đường DOL kẻ qua **đỉnh râu** (hoặc đáy râu). Có 3 đỉnh (Equal Highs) hoặc 2 đáy (Equal Lows).
- [HÌNH] Ví dụ B (tr.6): DOL = đường ngang ở ≈125 px, neo ở đỉnh râu của một nến rất xa bên trái (x≈86). Một đỉnh khác (x≈232) lên tới ≈140 px, gần bằng nhưng thấp hơn, nên đây có thể là "đỉnh bằng nhau tương đối". Ví dụ A: gốc của đường DOL nằm ngoài khung hình, không thấy được.
- [KHÔNG CÓ] Không có ngưỡng "bằng nhau" (bao nhiêu điểm, bao nhiêu ATR). Không nói DOL lấy ở khung nào. Không nói DOL phải **chưa bị quét** hay phải là DOL gần nhất.

**3.3 Nhánh thao túng (manipulation leg) = quét thanh khoản (liquidity sweep/raid)**
- [GHI RÕ] Nhánh thao túng là đoạn giá chạy **ra xa DOL** (ngược chiều lệnh), ngay trước cú dịch chuyển mạnh.
- [GHI RÕ, gián tiếp qua định nghĩa breaker] Mua cần có **đáy thấp hơn** (lower low); bán cần có **đỉnh cao hơn** (higher high).
- [HÌNH] Tr.2–3: đáy thấp hơn cắt qua đường chấm của đáy trước (bán thì đỉnh cao hơn cắt qua đỉnh trước). Nghĩa là nhánh thao túng **quét** một đỉnh/đáy cũ.
  - Ví dụ A: đỉnh râu 174 px vượt đỉnh râu cũ 198 px.
  - Ví dụ B: đáy râu 1173 px thấp hơn các đáy cũ ≈956–971 px.
- [HÌNH] Mốc Fibonacci trên nhánh thao túng (ví dụ A và B):
  - **mức 0 = cực trị râu của nhánh thao túng** (đỉnh cao nhất nếu bán, đáy thấp nhất nếu mua);
  - **mức 1 = râu ở gốc nhánh**, tức đỉnh/đáy mà nhánh bắt đầu chạy.
  - Ví dụ A: 0 = H của nến đạt đỉnh (174 px); 1 = L của nến xanh ở đáy gốc (364 px).
  - Ví dụ B: 0 = L của nến đạt đáy (1173 px); 1 = H của nến đỏ ở đỉnh gốc (658 px).
- [KHÔNG CÓ] Tài liệu không đòi giá phải đóng cửa quay lại sau khi quét; không có độ sâu quét tối thiểu; không nói về số nến.

**3.4 Chuyển cấu trúc / phá cấu trúc (market structure shift/break, MSS/BOS)**
- [KHÔNG CÓ] Tài liệu **không dùng** từ MSS/BOS/CHoCH. Chỉ nói "displacement" (dịch chuyển mạnh) tạo ra breaker.
- [HÌNH] Tr.2–3: sau nhánh thao túng, giá đi mạnh về phía DOL và **vượt qua đỉnh (mua) / đáy (bán) nằm giữa** hai nhánh, tức chính đỉnh/đáy chứa hộp breaker.
- [HÌNH, đo tr.6]
  - Ví dụ A (bán): nến đỏ dịch chuyển có thân 301–444 px. Nó **đóng ở 444 px**, dưới đáy nến breaker (348 px) và dưới gốc nhánh thao túng (364 px). Như vậy nến đóng cửa xuyên cả hai mốc.
  - Ví dụ B (mua): nến xanh dịch chuyển đóng ở 668 px, **trên đỉnh nến breaker** (683 px). Nhưng nó **chưa đóng trên** gốc nhánh thao túng (658 px); chỉ râu lên tới 617 px. Nến đầu tiên đóng vượt 658 px xuất hiện sau khi đã vào lệnh.
  - Kết luận từ hình: điều kiện chung của cả hai ví dụ là **đóng cửa xuyên qua mép xa của nến breaker**. "Đóng cửa xuyên gốc nhánh" chỉ đúng ở ví dụ A.
- [KHÔNG CÓ] Không có ngưỡng "mạnh" cho cú dịch chuyển (thân bao nhiêu ATR, bao nhiêu nến). Chỉ thấy bằng mắt rằng nến dịch chuyển lớn hơn hẳn các nến xung quanh: ví dụ A thân 143 px, trong khi các nến trước nó có thân khoảng 8–87 px.

**3.5 Khối phá vỡ (breaker block, BB)**
- [GHI RÕ] BB là **khối lệnh thất bại** (failed order block). Nó có thể là **một nhóm nến cùng màu**.
  - BB tăng = **nến xanh cuối cùng trước đáy thấp hơn**.
  - BB giảm = **nến đỏ cuối cùng trước đỉnh cao hơn**.
- [HÌNH] Vị trí: BB nằm ở **đỉnh/đáy giữa**, tức ngay trước nhánh thao túng. Mua: BB là (các) nến xanh ở đỉnh trước cú rơi xuống đáy thấp hơn. Bán: BB là (các) nến đỏ ở đáy trước cú tăng lên đỉnh cao hơn.
- [HÌNH, đo tr.6] **Hộp BB = toàn bộ biên độ của nến breaker, tính cả râu: từ L đến H.**
  - Ví dụ A: nến đỏ breaker có thân 253–325 px, râu dưới tới 348 px, không có râu trên. Hộp cam = 253–348 px, tức [L, H] của nến này.
    - Hộp **không** gồm đáy râu 364 px của nến xanh ngay sau (nến tạo đáy gốc).
    - Hộp bắt đầu vẽ từ nến breaker và kéo dài sang phải.
  - Ví dụ B: nến xanh breaker có thân 709–774 px, râu 683–783 px. Hộp cam = 684–784 px, tức [L, H] của nến này.
    - Hộp **không** gồm râu đỉnh 658 px của nến đỏ ngay sau.
  - Cả hai ví dụ đều chỉ dùng **một nến**. Không có ví dụ nhóm nến, nên không biết khi là nhóm thì lấy [min L, max H] của cả nhóm hay cách khác.
- [HÌNH] Điều kiện "thất bại": ở ví dụ B, nến đỏ thứ hai sau breaker đóng ở 805 px, dưới đáy breaker 783 px (khối lệnh bị xuyên). Sau đó nến dịch chuyển đóng trên đỉnh breaker. Ví dụ A là trường hợp đối xứng.
- Công thức gợi ý (mua):
  - k = nến xanh cuối cùng trước nến đạt đáy thấp nhất của nhánh thao túng.
  - BB = [L(k), H(k)].
  - Hợp lệ khi có nến đóng cửa **> H(k)** sau đáy đó.
  - Bán thì đối xứng: k = nến đỏ cuối cùng trước đỉnh cao nhất; hợp lệ khi có nến đóng cửa **< L(k)**.
  - Cách này khớp biến thể "(g) ICT breaker" và "Full wick" trong tài liệu 10, mục 1.2.
- [KHÔNG CÓ] Không nói nên lấy thân hay râu; tôi rút từ hình ra là râu. Không nói khi nào BB hết hiệu lực.

**3.6 Khoảng trống giá trị (fair value gap, FVG)**
- [GHI RÕ] FVG gồm 3 nến; râu của c1 và c3 không chồng lên nhau.
- [HÌNH, tr.2] Công thức:
  - FVG tăng: tồn tại khi **L(c3) > H(c1)**. Vùng = **[H(c1), L(c3)]**.
  - FVG giảm: tồn tại khi **H(c3) < L(c1)**. Vùng = **[H(c3), L(c1)]**.
  - Chỉ biết có FVG sau khi c3 đóng cửa. Công thức này giống "Core rule" ở tài liệu 10, mục 1.3.
- [HÌNH, đo tr.6] Ví dụ A: c1 = nến đỏ có L = 300 px; c2 = nến dịch chuyển; c3 = nến xanh có H = 388 px. Hộp FVG = 300–388 px, khớp đúng công thức.
- [HÌNH, đo tr.6] Ví dụ B: c1 có H ≈ 754 px, c3 có L ≈ 748 px. Hộp FVG = 748–754 px, **rất mỏng**, khoảng 6% chiều cao hộp BB.
  - FVG này **không** nằm trong cú dịch chuyển đầu tiên. Nó hình thành về sau, khi giá đi ngang/hồi **bên trong** hộp BB.
  - Các FVG trong chính cú dịch chuyển (tôi đo lại) đều nằm **dưới** hộp BB, không chồng lên. Gần nhất là ≈789–825 px, cách đáy BB (784 px) khoảng 5 px.
- [KHÔNG CÓ] Không có ngưỡng kích thước FVG. Không đòi c2 phải là nến dịch chuyển. Không đòi 3 nến cùng màu (hình vẽ cùng màu nhưng chữ không bắt buộc). Không nói FVG hết hiệu lực khi nào.

**3.7 Unicorn = BB chồng FVG**
- [GHI RÕ] Điều kiện: **breaker và FVG chồng lên nhau** (overlapping). Tài liệu không định nghĩa "chồng" bằng số.
- Vùng chồng chính xác, với BB = [bB, tB] và FVG = [bF, tF]:
  - **Vùng chồng = [max(bB, bF), min(tB, tF)]**, chỉ có khi max(bB, bF) < min(tB, tF).
- [HÌNH, đo]
  - Tr.3 (hình đường): hai hộp chỉ chồng một **dải mỏng**; FVG thò ra ngoài BB về phía giá sẽ quay lại.
  - Ví dụ A: BB 253–348 px, FVG 300–388 px. Vùng chồng = **300–348 px**, bằng 50% chiều cao BB và 55% chiều cao FVG. Phần FVG thò ra ngoài BB là 348–388 px, nằm dưới BB, tức phía giá hồi lên chạm trước.
  - Ví dụ B: BB 684–784 px, FVG 748–754 px. FVG nằm **trọn trong** BB, vùng chồng = cả FVG (6 px).
- Vậy trong tài liệu có hai kiểu: "chồng một phần" (tr.3, ví dụ A) và "FVG nằm trong BB" (ví dụ B). Cả hai đều được coi là Unicorn.

**3.8 Vùng đắt/rẻ (premium/discount), khung giờ (killzone), thời gian**
- [KHÔNG CÓ] Không nhắc premium/discount, không nhắc mức 50% của nhịp.
- [GHI RÕ] Chỉ ghi "NY Session". Không có giờ cụ thể, không có từ "killzone". Biểu đồ không có trục giờ nên không kiểm được.
- [GHI RÕ] Không vào lệnh khi có tin "red folder". Không nói khoảng tránh là bao lâu.
- [KHÔNG CÓ] Không giới hạn số nến từ lúc có Unicorn tới lúc giá thử lại.

## 4. Vào lệnh, dừng lỗ, chốt lời, R:R

### 4.1 Luật bằng chữ (tr.4)

| Nội dung | Tài liệu nói | Tài liệu KHÔNG nói |
|---|---|---|
| Kiểu lệnh | Lệnh chờ (limit) khi thử lại BB/FVG (nhãn tr.6: "Limit order on retest") | Đặt ở mép nào, ở giữa (50%, consequent encroachment) hay vùng chồng |
| Dừng lỗ | Đỉnh/đáy **thân nến** của nhánh thao túng | Có cộng thêm khoảng đệm (buffer), spread hay không |
| Chốt lời | Fib trên nhánh thao túng: 2 STDV, hoặc giữ tới DOL | Khi nào chọn cái nào; có chốt một phần hay không |
| R tối thiểu | ≥ 2R | Tính 2R theo TP nào (2 STDV hay DOL) |
| Quản lý | Không quản lý, để lệnh chạy hết | Không dời SL về giá vào, không đóng theo thời gian |
| Tin tức | Không giao dịch khi có tin đỏ | Khoảng thời gian tránh |
| Khối lượng | — | Không có quy tắc rủi ro theo % tài khoản |

**Mức "2 STDV" rút từ hình:**
- Fib có mức 0 = cực trị râu nhánh thao túng (X) và mức 1 = gốc nhánh (G). Mức "2" nằm cách G thêm đúng một chiều dài nhánh, về phía DOL.
- **TP_2STDV = X + 2·(G − X)**, tức 2G − X.
  - Bán: X là đỉnh, nên TP = G − (X − G).
  - Mua: X là đáy, nên TP = G + (G − X).
- Kiểm lại bằng số đo:
  - Ví dụ A: 174 + 2·(364 − 174) = 554, hình vẽ ở 555 px.
  - Ví dụ B: 1173 + 2·(658 − 1173) = 143, hình vẽ ở ≈140 px.
- Tài liệu không giải thích vì sao gọi là "độ lệch chuẩn"; đây chỉ là mức mở rộng Fibonacci.

### 4.2 Số đo từng ví dụ (tr.6)

Đơn vị là px trên ảnh gốc. R = khoảng từ giá vào tới SL. Số chỉ là ước lượng từ điểm ảnh.

**Ví dụ A — bán**

| Thành phần | Vị trí (px) | Nến/điểm tạo ra nó |
|---|---|---|
| Đỉnh cũ bị quét | 198 | H của một nến xanh trước đó |
| Nhánh thao túng | từ 364 lên 174 | L nến xanh gốc → H nến xanh đạt đỉnh cao hơn |
| BB | 253–348 | [H, L] của nến đỏ cuối cùng trước đỉnh cao hơn |
| Nến dịch chuyển | thân 301→444 | đóng dưới L(BB) và dưới gốc 364 |
| FVG | 300–388 | L(c1) = 300, H(c3) = 388 |
| Vùng chồng | 300–348 | |
| **Giá vào** | **388** | **mép dưới FVG = H(c3)**: mép **gần nhất** của hợp BB∪FVG, nơi giá hồi lên chạm đầu tiên. Nằm **ngoài** vùng chồng |
| **SL** | **237** | **thân trên cao nhất** của nhánh thao túng: thân nến xanh đạt đỉnh (237–293) và thân một nến xanh khác cũng tới 237. Râu đỉnh ở 174 nằm ngoài SL |
| TP theo DOL | 1061 | đường DOL (hộp xanh của công cụ vị thế kết thúc ở đây) |
| Mức 2 STDV | 555 | vẽ trên hình nhưng hộp lời **không** kết thúc ở đây |
| Giá hồi cao nhất | 293 (râu) | vào qua hết vùng chồng, vượt mép trên FVG 7 px, vẫn trong BB. Mức chịu lỗ ≈ 95/151 ≈ 0,63R |

- R = 388 − 237 = 151 px.
- Tới DOL: (1061 − 388)/151 ≈ **4,5R**. Giá đóng cửa xuyên qua DOL, nên lệnh đạt TP.
- Tới 2 STDV: (555 − 388)/151 ≈ **1,1R**, **nhỏ hơn 2R tối thiểu**. Theo luật tr.4, ví dụ này chỉ hợp lệ nếu nhắm DOL.

**Ví dụ B — mua**

| Thành phần | Vị trí (px) | Nến/điểm tạo ra nó |
|---|---|---|
| Đáy cũ bị quét | ≈956–971 | L của các nến trước đó |
| Nhánh thao túng (theo Fib) | từ 658 xuống 1173 | H nến đỏ gốc → L nến xanh đạt đáy thấp nhất |
| BB | 684–784 | [L, H] của nến xanh cuối cùng trước đáy thấp hơn |
| Nến dịch chuyển | đóng 668 | đóng trên H(BB) = 683, **chưa** đóng trên gốc 658 |
| Giá đi ngang/hồi | 663–880 | nhiều nến quanh và dưới BB. Hai râu đáy bằng nhau ở 880 px, có một đường xanh lam **không nhãn** kẻ qua |
| FVG | 748–754 | H(c1) ≈ 754, L(c3) ≈ 748; hình thành bên trong BB |
| Vùng chồng | 748–754 | cả FVG |
| **Giá vào** | **683** | **mép trên BB = H(nến breaker)**: mép gần nhất của hợp BB∪FVG khi giá hồi xuống. Nằm **ngoài** vùng chồng |
| **SL** | **850** | **thân dưới thấp nhất của đoạn hồi/đi ngang sau cú dịch chuyển**: nến đỏ đóng ở 850 và nến xanh kế tiếp mở ở 850. Râu đáy 880 nằm ngoài SL |
| TP theo DOL | 125 | đường DOL |
| Mức 2 STDV | ≈140–143 | gần trùng đỉnh ≈140 của nến x≈232 |

- R = 850 − 683 = 167 px.
- Tới DOL: (683 − 125)/167 ≈ **3,3R**. Nến cuối vượt DOL.
- Tới 2 STDV: (683 − 143)/167 ≈ **3,2R**.
- Ô vị thế bắt đầu ở một nến có râu dưới 682 px, tức vừa chạm giá vào. Nến trước đó đã đóng lại trên mép BB.

**Chỗ mâu thuẫn ở ví dụ B:**
- Luật chữ nói SL ở thân thấp nhất của **nhánh thao túng**. Nếu nhánh thao túng là đoạn đã kẻ Fib (658→1173), thân thấp nhất là **1093 px**.
- Nhưng SL vẽ trên hình ở **850 px**, là thân thấp nhất của đoạn hồi **sau** cú dịch chuyển.
- Nhãn "Manipulation leg…" ở ví dụ B lại đặt dưới đoạn đi ngang đó, không đặt dưới đáy sâu. Vậy có hai cách hiểu:
  1. Nhánh thao túng là cú rơi sâu (theo Fib). Khi đó SL trên hình **không theo** luật chữ.
     - Nếu dùng SL 1093 px: R = 410 px; tới DOL ≈ 1,36R, tới 2 STDV ≈ 1,3R. Cả hai **dưới 2R**, nên theo luật tr.4 thì **không được vào lệnh**.
  2. "Nhánh thao túng" để đặt SL là cú hồi gần nhất trước khi vào lệnh. Khi đó Fib và SL dùng hai nhánh khác nhau.
- Tài liệu không giải thích. Cần chủ bot chọn cách hiểu, hoặc đo cả hai.

**Rút ra từ hai ví dụ (suy từ hình, không phải luật chữ):**
- Giá vào đặt ở **mép gần nhất của phần hợp BB∪FVG**, tức mép giá chạm đầu tiên khi hồi về, **không** đặt ở vùng chồng, cũng không đặt ở mức 50%.
- Hình đường ở tr.3 lại cho thấy điểm hồi chạm đúng dải chồng. Hai loại hình không thống nhất về độ sâu.
- SL luôn ở **thân** nến, không ở râu.
- TP trên công cụ vị thế ở cả hai ví dụ là **DOL**, không phải 2 STDV.

## 5. Thuật toán từng bước cho bot và bảng luật

### 5.1 Các bước (mua; bán thì đối xứng)

Mọi phép so sánh chỉ dùng **nến đã đóng**. Mỗi đối tượng có thời điểm biết được (t_known).

1. **DOL.** Tìm các nhóm đỉnh bằng nhau tương đối ở phía trên giá, chưa bị đóng cửa xuyên qua. Mức DOL = đỉnh cao nhất của nhóm.
   - Chiều lệnh = mua.
   - Sai số "bằng nhau", số đỉnh tối thiểu, khung tìm DOL: **cần đo**.
2. **Nhánh thao túng.** Sau khi có DOL, chờ một đáy pivot mới X **thấp hơn** một đáy pivot trước đó (quét đáy cũ).
   - Gọi G là đỉnh pivot ngay trước X (gốc nhánh).
3. **Nến breaker.** k = nến xanh cuối cùng trước nến đạt X, tính từ G trở đi.
   - BB = [L(k), H(k)].
   - (Biến thể nhóm nến cùng màu liền nhau: [min L, max H]; **cần đo**.)
4. **Dịch chuyển.** Có nến j sau X với **C(j) > H(k)** (đóng trên BB).
   - Biến thể chặt hơn, giống ví dụ A: C(j) > H(G) (**cần đo**).
   - Ngưỡng "mạnh" cho j: **cần đo**.
5. **FVG.** Tìm FVG tăng [H(c1), L(c3)] với c3 đóng sau X.
   - Lấy FVG trong cú dịch chuyển (giống tr.3 và ví dụ A), hoặc FVG hình thành sau đó khi BB còn hiệu lực (giống ví dụ B).
   - Cửa sổ thời gian: **cần đo**.
6. **Unicorn.** Vùng chồng = [max(L(k), H(c1)), min(H(k), L(c3))] phải có chiều cao > 0.
   - t_known = lúc c3 đóng (hoặc lúc j đóng, lấy cái muộn hơn).
7. **Lệnh.**
   - Giá vào = mép trên của hợp BB∪FVG = max(H(k), L(c3)) (theo hai ví dụ).
     - Biến thể: mép trên vùng chồng; mức 50% vùng chồng; mép trên FVG.
     - Nếu lúc có Unicorn giá đang ở dưới mức này (đã ở trong vùng), thì cần luật riêng. Ví dụ B cho thấy chờ giá đóng lại trên mép rồi mới thử lại. Luật này **cần chốt**.
   - SL = thân dưới thấp nhất của nhánh thao túng (luật chữ). Biến thể: thân dưới thấp nhất của đoạn hồi ngay trước khi vào lệnh (theo ví dụ B). Có cộng đệm hay không: **cần đo**.
   - TP = DOL; hoặc 2G − X (2 STDV).
8. **Lọc.**
   - Bỏ lệnh nếu (TP − giá vào)/(giá vào − SL) < 2.
   - Bỏ lệnh nếu đang trong khoảng tin đỏ (khoảng thời gian **cần đo**).
   - Bỏ lệnh nếu ngoài phiên NY (giờ phiên **cần chốt**).
9. **Hủy lệnh chờ.** Tài liệu không có luật hủy. Các điều kiện cần đo:
   - giá chạm TP/DOL trước khi khớp;
   - nến đóng dưới L(k) hoặc dưới đáy FVG;
   - quá N nến.
10. **Sau khi khớp.** Không quản lý; chỉ thoát ở SL hoặc TP.

### 5.2 Bảng luật có thể mã hóa

| # | Luật | Công thức / cách làm | Nguồn |
|---|---|---|---|
| 1 | Khung, mã, phiên | 5m, ES, phiên NY | Tài liệu ghi rõ (giờ phiên: Không có — cần đo/chốt) |
| 2 | Chiều lệnh theo DOL | DOL trên thì mua, DOL dưới thì bán | Tài liệu ghi rõ |
| 3 | DOL = đỉnh/đáy bằng nhau tương đối | nhóm đỉnh có \|ΔH\| ≤ ε | Tài liệu ghi rõ khái niệm; ε và số đỉnh: Không có — cần đo |
| 4 | DOL neo ở râu | mức = H (hoặc L) cực trị của nhóm | Suy ra từ hình |
| 5 | Nhánh thao túng quét đỉnh/đáy cũ | mua: X = L < một đáy pivot cũ; bán: X = H > một đỉnh pivot cũ | Suy ra từ hình ("lower low/higher high" có trong chữ) |
| 6 | Định nghĩa pivot | N nến mỗi bên | Không có — cần đo |
| 7 | Nến breaker | mua: nến xanh cuối trước X; bán: nến đỏ cuối trước X | Tài liệu ghi rõ |
| 8 | Hộp BB | [L(k), H(k)], tính cả râu | Suy ra từ hình (đo 2 ví dụ) |
| 9 | BB là nhóm nến | [min L, max H] của nhóm cùng màu? | Tài liệu ghi rõ là "có thể nhóm"; cách lấy biên: Không có — cần đo |
| 10 | Xác nhận dịch chuyển | mua: C(j) > H(k); bán: C(j) < L(k) | Suy ra từ hình |
| 11 | Đóng xuyên gốc nhánh | mua: C(j) > H(G) | Suy ra từ hình, chỉ đúng ở ví dụ A — cần đo |
| 12 | Độ mạnh dịch chuyển | thân/ATR ≥ ? | Không có — cần đo |
| 13 | FVG tăng/giảm | L(c3) > H(c1) → [H(c1), L(c3)]; H(c3) < L(c1) → [H(c3), L(c1)] | Tài liệu ghi rõ (chữ + hình tr.2) |
| 14 | FVG nằm trong cú dịch chuyển hay được hình thành sau | c2 ∈ cú dịch chuyển, hoặc c3 sau j trong N nến | Suy ra từ hình (hai ví dụ khác nhau) — cần đo |
| 15 | Kích thước FVG tối thiểu | ≥ ? | Không có — cần đo (ví dụ B chỉ ≈6% chiều cao BB) |
| 16 | Unicorn | [max(bB, bF), min(tB, tF)] có chiều cao > 0 | Tài liệu ghi rõ "chồng nhau"; công thức: Suy ra từ hình |
| 17 | Độ chồng tối thiểu | chiều cao vùng chồng ≥ ? | Không có — cần đo |
| 18 | Kiểu lệnh | lệnh chờ limit | Tài liệu ghi rõ (nhãn tr.6) |
| 19 | Giá vào | mép gần của BB∪FVG | Suy ra từ hình (2/2 ví dụ); chữ chỉ nói "retest" |
| 20 | SL | thân cao/thấp nhất của nhánh thao túng | Tài liệu ghi rõ; ví dụ B dùng nhánh khác (xem 4.2) |
| 21 | Đệm SL | + ? | Không có — cần đo |
| 22 | TP 2 STDV | 2G − X (Fib neo râu) | Tài liệu ghi rõ "2 STDV"; công thức: Suy ra từ hình |
| 23 | TP DOL | mức DOL | Tài liệu ghi rõ |
| 24 | Chọn TP nào | cả 2 ví dụ đều dùng DOL | Không có luật — cần đo |
| 25 | R tối thiểu | reward/risk ≥ 2 | Tài liệu ghi rõ; tính với TP nào: Không có |
| 26 | Tin đỏ | không vào | Tài liệu ghi rõ; khoảng thời gian: Không có — cần đo |
| 27 | Quản lý lệnh | không có | Tài liệu ghi rõ |
| 28 | Hủy lệnh chờ / hết hiệu lực vùng | ? | Không có — cần đo |
| 29 | Premium/discount, killzone | — | Không có |
| 30 | Khối lượng/rủi ro mỗi lệnh | — | Không có |

## 6. So với ý tưởng hiện tại của chủ bot

Ý tưởng hiện tại (Hướng 1.4 trong `docs/SPEC.md`):
- tìm mức cản ở khung lớn M15–H4 (tới W1);
- vào lệnh ở M1/M5 sau khi thấy phản ứng;
- SL sau râu của mức;
- TP ở thanh khoản gần nhất chưa bị quét (DOL);
- né tin, chốt hai phần.

**Giống nhau**
- **DOL làm mục tiêu:** cả hai nhắm tới nơi có thanh khoản (đỉnh/đáy bằng nhau). Unicorn gọi thẳng là "draw on liquidity".
- **Quét rồi đảo:** nhánh thao túng của Unicorn là cú quét đỉnh/đáy cũ, rồi giá quay ngược. Ý tưởng chủ bot cũng chờ giá chạm mức rồi phản ứng.
- **Né tin mạnh:** cả hai đều có. Cả hai đều chưa có khoảng thời gian cụ thể trong tài liệu Unicorn.
- **Tỷ lệ lời/lỗ:** Unicorn đòi ≥ 2R. Chủ bot cũng đòi mục tiêu có căn cứ và R tối thiểu (1,5R đang là cấu hình thử).

**Khác nhau**

| Điểm | Unicorn (tài liệu này) | Ý tưởng chủ bot |
|---|---|---|
| Khung tìm vùng | Cùng một khung 5m cho BB, FVG, nhánh thao túng. Không có khung lớn | Vùng/cản ở M15–H4; M1/M5 chỉ để vào |
| Vùng vào | BB∩FVG **mới sinh ra sau cú dịch chuyển**, không phải mức cũ đã có sẵn | Mức cản đã có từ trước ở khung lớn |
| Vai trò DOL | DOL **có trước**, quyết định chiều lệnh, và là TP. Không bắt buộc là DOL gần nhất | DOL chủ yếu là mục tiêu: thanh khoản **gần nhất** chưa bị quét |
| Cách vào | **Lệnh chờ** ở mép vùng khi giá thử lại. Không chờ nến phản ứng | **Vào thị trường sau phản ứng** ở M1/M5 |
| SL | **Thân nến** cao/thấp nhất của nhánh thao túng (râu nằm ngoài SL) | **Sau râu** của mức |
| TP | DOL hoặc 2 STDV Fib. Một TP duy nhất | DOL gần nhất; chốt hai phần |
| Quản lý | Không quản lý | Có: dời SL về giá vào, chốt một phần, siết theo cấu trúc |
| Khối lượng | Không nói | Theo độ lớn SL, trần 0,25% |
| Thị trường | ES, phiên NY | Vàng (XAUUSD), nhiều phiên |

**Nếu muốn ghép:**
- Có thể dùng Unicorn như một **mẫu vào lệnh ở M1/M5** bên trong vùng khung lớn. Khi đó:
  - nhánh thao túng = cú quét qua mép vùng khung lớn;
  - BB∩FVG ở M1/M5 = điểm vào;
  - DOL = TP.
- Đây là ý của tôi, tài liệu không nói.
- Hai điểm vênh cần chủ bot quyết:
  1. lệnh chờ hay vào sau phản ứng;
  2. SL ở thân (Unicorn) hay sau râu (chủ bot).

## 7. Câu hỏi mở — cần đo để quyết

1. **DOL:**
   - Sai số "bằng nhau tương đối" là bao nhiêu (theo ATR/spread)? Cần 2 hay 3 đỉnh?
   - Lấy DOL ở khung nào?
   - Bắt buộc DOL gần nhất chưa bị quét, hay DOL nào cũng được?
2. **Pivot:** N bao nhiêu cho đỉnh/đáy của nhánh thao túng và của đỉnh/đáy cũ bị quét?
3. **Quét:**
   - Chỉ cần râu vượt đỉnh/đáy cũ, hay cần nến đóng lại bên trong?
   - Cần độ sâu tối thiểu không?
4. **Breaker:**
   - Một nến hay cả nhóm nến cùng màu? Biên lấy râu (theo hình) hay thân?
   - So sánh kết quả hai cách.
5. **Dịch chuyển:**
   - Chỉ cần đóng qua BB (ví dụ B), hay phải đóng qua gốc nhánh (ví dụ A)?
   - Có cần ngưỡng thân/ATR không?
6. **FVG:**
   - Chỉ FVG trong cú dịch chuyển, hay cả FVG sinh ra sau đó (ví dụ B)? Trong bao nhiêu nến?
   - Kích thước tối thiểu bao nhiêu?
   - Khi có nhiều FVG thì chọn cái nào?
7. **Độ chồng:** vùng chồng tối thiểu bao nhiêu? Nếu hai hộp chỉ sát nhau mà không chồng thì sao (ví dụ B có FVG cách BB 5 px mà tác giả không dùng)?
8. **Giá vào:**
   - Mép gần của BB∪FVG (theo 2 ví dụ), mép vùng chồng (theo hình tr.3), hay 50% vùng chồng?
   - Đo tỷ lệ khớp và R thực tế cho từng cách.
9. **SL:**
   - Thân nhánh thao túng (luật chữ) hay thân đoạn hồi gần nhất (ví dụ B)?
   - Cần đệm bao nhiêu (spread/ATR)?
   - Với vàng M1/M5, SL ở thân có bị quét nhiều hơn SL sau râu không?
10. **TP:**
    - Luôn DOL, hay 2 STDV, hay chọn cái gần hơn?
    - Luật "≥ 2R" tính với TP nào? (Ví dụ A: 2 STDV chỉ ≈1,1R; DOL ≈4,5R.)
11. **Hủy lệnh chờ:** sau bao nhiêu nến? Hủy khi giá chạm DOL trước khi khớp? Hủy khi nến đóng xuyên qua vùng?
12. **Thời gian:**
    - "Phiên NY" là giờ nào?
    - Tránh tin đỏ bao nhiêu phút trước/sau?
    - Với vàng, có cần giới hạn phiên không?
13. **Chuyển thị trường:** mô hình viết cho ES 5m. Với XAUUSD M1/M5 (chi phí spread ≈ 5–13% ATR theo tài liệu 13), R nhỏ có còn lời sau phí không? Chỉ biết được sau khi đo.
14. **Bằng chứng:** tài liệu chỉ có 2 ví dụ đã chọn sẵn, đều thắng. Không có thống kê. Không được coi mô hình là có lời trước khi đo trên dữ liệu chưa dùng, có tính phí.

# Báo cáo nghiên cứu: thuật toán S/R, MSNR, FVG, OB và sự thật nền tảng Exness/MT5 cho EA lưới lệnh chờ XAUUSD

**Cách thu thập dữ liệu (ngày truy cập 2026-09-26)**
- Mã Pine của TradingView được đọc trực tiếp trong tab "Source code" của các script open-source. Mã Python được đọc từ file nguồn trên GitHub. Tôi không chép lại mã gốc. Phần dưới là mô tả logic và pseudo-code do tôi viết lại.
- Máy này không phân giải được DNS của mọi tên miền Exness. Vì vậy nội dung Exness được đọc qua proxy đọc trang `r.jina.ai` (proxy tải trang gốc từ phía server), hoặc qua trích đoạn của công cụ tìm kiếm. Tôi ghi rõ "(snippet)" ở những chỗ chỉ có trích đoạn.
- Một số bài Exness có trang kiểm tra chống bot, tôi không vượt qua. Help Center Exness chỉ ghi ngày dạng tương đối ("updated X ago").

---

## A. Thuật toán phát hiện

### A1. Tự động phát hiện hỗ trợ/kháng cự (support/resistance, S/R)

**1) Cách xác định điểm xoay (swing/pivot) trong các nguồn có mã**

| Phương pháp | Quy tắc chính xác | Tham số mặc định trong nguồn | Độ trễ/repaint |
|---|---|---|---|
| Fractal Bill Williams | Chuỗi ít nhất 5 nến. Nến giữa có High cao nhất, 2 nến mỗi bên có High thấp hơn (đáy thì ngược lại). [13] | 2 nến trái, 2 nến phải | Xác nhận sau 2 nến |
| Pivot N trái/N phải (`ta.pivothigh(src,L,R)`) | `src[R]` là cực trị so với L nến trước và R nến sau | DoN: nguồn = **close**, L=R=3 [4][5]. LonesomeTheBlue: L=R=10, nguồn High/Low hoặc max/min(open, close) [12]. Bài MQL5: 7 nến mỗi bên [15] | Trễ R nến |
| ZigZag của MetaQuotes | Depth=12, Deviation=5, Backstep=3. **Deviation tính bằng point** (nhân với `Point`), không phải %. [14] | 12/5/3 | Vàng 3 chữ số: 5 point = 0,005 USD, gần như vô tác dụng, nên thực tế chỉ có Depth quyết định. Đỉnh cuối bị vẽ lại |
| ZigZag theo ATR (Wonra) | Chỉ thành swing khi giá hồi ≥ 1,3×ATR(14) từ cực trị, rồi giữ thêm 2 nến để xác nhận. Không dùng cửa sổ số nến cố định. [3] | 1,3×ATR(14), xác nhận 2 nến. Tác giả khuyên hạ xuống 1,0–1,2 khi lên khung lớn, nâng lên 1,6–2,0 khi chart nhiễu | Trễ đến lúc hồi đủ ngưỡng |
| LuxAlgo `leg()` | Nến cách đây `size` nến là đỉnh nếu high của nó lớn hơn highest(size) của các nến **sau** nó. Pivot được ghi khi trạng thái "leg" đổi chiều, nên đỉnh và đáy luôn xen kẽ. [2] | swing = 50, internal = 5 | Trễ `size` nến |
| joshyattridge `swing_highs_lows` | high[i] là max của cửa sổ [i−L+1, i+L]. Sau đó loại các đỉnh (hoặc đáy) liên tiếp cùng loại, chỉ giữ cái cực trị hơn. [1] | L = 50 | **Dùng dữ liệu tương lai** (look-ahead). Trong EA phải chờ đủ L nến |

**2) Gom cụm (clustering) và độ mạnh của mức**
- **LonesomeTheBlue "Support Resistance Channels"** [12]:
  - Lấy các pivot trong 290 nến gần nhất (loopback).
  - Độ rộng kênh tối đa = 5% × (highest(300) − lowest(300)).
  - Với mỗi pivot, nới rộng [lo, hi] bằng các pivot khác, miễn là độ rộng không vượt ngưỡng trên.
  - Độ mạnh = 20 × số pivot trong kênh + số nến trong loopback có high hoặc low nằm trong kênh.
  - Chọn tham lam (greedy) các kênh mạnh nhất, loại những pivot đã thuộc kênh đã chọn. Mặc định hiển thị 6 kênh, tối đa 10. Độ mạnh tối thiểu là 1×20.
  - Kênh bị "gãy" khi close cắt qua mép kênh trong lúc giá không nằm trong kênh nào.
- **Wonra** [3]:
  - Gộp các mức cách nhau ≤ 0,5×ATR.
  - "Chạm" (touch) khi high/low đi vào band ± 0,15×ATR. Chỉ đếm một lần chạm mới nếu trước đó giá đã rời xa ≥ 1,0×ATR, và cách lần chạm trước hơn 3 nến.
  - "Miss" là khi swing quay đầu trong khoảng (0,15–0,60)×ATR trước mép gần của mức.
  - Độ tin cậy = touches + misses. Từ 3 trở lên là mức mạnh.
- **LuxAlgo** [2]: đỉnh/đáy bằng nhau (equal highs/lows, EQH/EQL) là khi pivot mới cách pivot cũ < 0,1×ATR(200), xác nhận sau 3 nến. Đây là vùng thanh khoản (liquidity).

**3) Độ rộng vùng (zone width) theo ATR, lấy từ các nguồn**
- Wonra [3]: vùng QML rộng 0,2×ATR về một phía; dung sai chạm 0,15×ATR; gap tối thiểu 0,10×ATR; FVG "Balanced" tối thiểu 0,5×ATR.
- DoN [4]: hộp đi từ mức close-pivot tới râu (high hoặc low) của nến pivot.

**4) Tham số khởi điểm cho XAUUSD M5/M1.** Đây là gợi ý của tôi, không có nguồn, phải tối ưu bằng backtest real ticks.
- M5, cấu trúc nhỏ: pivot 3–5 nến (DoN dùng 3, LuxAlgo internal dùng 5).
- M5, cấu trúc lớn: 10–20 nến.
- HTF (H1/H4): pivot 5 nến (giống storyline của Wonra).
- ATR(14) tính trên chính khung đang dùng: dung sai chạm 0,1–0,2×ATR, gộp mức 0,5×ATR, nửa độ rộng vùng 0,15–0,25×ATR.
- M1 quá nhiễu. Nên lấy mức từ M5/M15, chỉ dùng M1 để canh khớp lệnh.
- Nếu dùng ZigZag thì phải đặt Deviation theo point của vàng (ví dụ tương đương 0,3–1,0×ATR) thay vì để 5.

```
// Pseudo-code (MQL5, series: 0 = nến đang chạy). Chỉ dùng nến ĐÃ ĐÓNG.
bool PivotHigh(src[], i, L, R):           // gọi với i = R+1 mỗi khi có nến mới
  for k=1..R: if src[i-k] >= src[i] return false   // phía mới hơn
  for k=1..L: if src[i+k] >  src[i] return false   // phía cũ hơn
  return true
```

### A2. Malaysian SnR (MSNR)

**Định nghĩa tổng hợp từ các nguồn**

| Khái niệm | Định nghĩa | Nguồn |
|---|---|---|
| A-level (hình Λ) | Kháng cự nhìn trên line chart: điểm nối **close của nến tăng** với **open của nến giảm ngay sau**, ở đỉnh. Bỏ qua râu. Wonra vẽ mức tại **close**, còn [close, open kế tiếp] là band dung sai | [9][3][8] |
| V-level | Hỗ trợ: close của nến giảm nối với open của nến tăng ngay sau, ở đáy | [9][3][8] |
| Gap level (có nơi gọi OCL, open-close level) | Có 3 biến thể: (a) DanielM, trading-guide, MQL5 #115614: **2 nến cùng màu**, vùng giữa close nến 1 và open nến 2, vẽ tại close nến 1. (b) Wonra: không cần cùng màu; nếu \|open − close[1]\| ≥ 0,10×ATR thì tạo mức tại close[1], band [close[1], open]. Gap đi lên là hỗ trợ, gap đi xuống là kháng cự. (c) DoN "Decision level": trên **H4**, 2 nến liên tiếp cùng màu thì vẽ mức tại **open của nến thứ 2** | [6][7][8][3][4] |
| Fresh / Unfresh | Fresh là mức chưa bị **râu** chạm từ khi hình thành. Unfresh là đã bị râu chạm. Mức unfresh trở lại fresh khi bị **thân nến** cắt qua, và bị râu chạm lần nữa thì lại unfresh | [6][7][8][11]. Snippet UAlgo [10] |
| Miss | Giá tiến về mức nhưng râu các nến sau không chạm tới rồi quay đi. Theo học thuyết, miss **xác nhận** mức (thanh khoản ở đó chưa bị lấy) | [3] |
| SBR / RBS | Mức bị close xuyên qua thì đổi vai: hỗ trợ thành kháng cự (support becomes resistance), hoặc ngược lại | [3][4][5][11] |
| QM/QML (quasimodo) | QM tăng gồm 5 swing L2, H2, L1, H1, L0 với L0 < L1 (đầu thấp hơn vai trái) và H2 > H1 (có xu hướng giảm để đảo). Sau đó phá lên trên H1. Điểm vào là **vai trái L1**; đầu (apex) là L0 | [3][11] |
| Storyline | Hướng đi kỳ vọng lấy từ khung lớn: giá bị từ chối (rejection) tại mức HTF (mức lấy từ **thân** nến), rồi khung nhỏ breakout xác nhận. Breakout **internal** là qua mức hình thành sau rejection; **external** là qua mức có từ trước. Mức nằm ngược storyline là "roadblock": chỗ giá dừng tạm, không phải đảo chiều | [3][9][11] |
| Engulf (EG/EF) | EG là nến nhấn chìm theo thân, thân ≥ 0,8×ATR và lớn hơn thân nến trước. **Vùng là thân của nến bị nhấn chìm** (coi như OB). EG bị close xuyên qua thì thành EF, cùng vùng giá nhưng đổi hướng. Gãy lần hai thì bỏ | [3] |

Một snippet tìm kiếm nói "mỗi mức chỉ dùng được 2 lần", chưa xác minh được. Script trading-guide có tham số "Max Level Break" (ẩn mức bị vượt quá N lần) [7].

**Logic cụ thể từ mã open-source**
- **Wonra Alchemist SNR Engine** [3]. Đọc được mã nguồn, gồm cả MSNR và QM:
  - *Tạo A/V*: khi ZigZag-ATR xác nhận một swing high, tìm trong ±3 nến quanh swing các cặp (nến tăng, rồi nến giảm). Lấy close **cao nhất** làm A. Với swing low thì tìm cặp (giảm, rồi tăng) và lấy close **thấp nhất** làm V.
  - Không tạo mức mới nếu nó đã bị close vượt từ trước khi được xác nhận. Nếu cách mức cũ ≤ 0,5×ATR thì chỉ cộng một lần chạm vào mức cũ.
  - *Gãy*: close vượt **mép xa** của band ± 0,15×ATR. Lần gãy đầu đổi vai thành SBR/RBS, fresh = true. Lần gãy thứ hai xóa mức.
  - *Unfresh*: bất kỳ nến nào có high/low chạm band ± 0,15×ATR.
  - Giới hạn 6 mức cho mỗi loại.
- **DoN** [4] và **Kai[DoN]** [5]:
  - A/V lấy từ `ta.pivothigh/low(close, 3, 3)`, tức đỉnh/đáy của line chart. Hộp đi từ close tới high/low của nến pivot.
  - Mức bị gãy khi close cắt qua, lúc đó thành đường SBR/RBS. Kai còn xóa SBR/RBS khi close cắt ngược lại, và chỉ giữ 2 đường gần giá nhất.
  - Kai lọc thêm bằng SMA21: chỉ nhận V khi mức nằm dưới SMA21, chỉ nhận A khi nằm trên.
  - DoN có "Decision level" H4 như ở bảng trên.
- **Nguồn đóng hoặc đã bị gỡ**: DanielM (gỡ khỏi TradingView, chỉ còn mô tả, cập nhật 27/01/2025) [6], trading-guide (invite-only) [7], MQL5 #115614 [8], zacdivan (protected) [9]. Mô tả của các nguồn này thống nhất với luật fresh/unfresh ở bảng trên.

**Nhận xét quan trọng khi code EA:** trên feed liên tục của MT5, open của nến N+1 thường gần như bằng close của nến N. Vì vậy "gap level" theo cách hiểu (a) thực chất là close của nến đầu trong 2 nến cùng màu, tức một mức giữa nhịp đẩy. Muốn có gap thật thì nên thêm ngưỡng tối thiểu kiểu Wonra (≥ 0,1×ATR).

```
// Level engine, chạy khi đóng nến (i=1 là nến vừa đóng, i+1 là nến cũ hơn)
Level{price, bandLo, bandHi, isSupport, fresh, flipped, touches, misses, awayOk}
if swingHighConfirmed(idx): tìm k∈[idx-3,idx+3] có bull(k)&&bear(k-1 mới hơn); A = max close[k]
if swingLowConfirmed(idx):  tìm k có bear(k)&&bull(k-1);                     V = min close[k]
if open[1]-close[2] >= 0.1*ATR  -> GAP support tại close[2], band[close[2],open[1]]
if close[2]-open[1] >= 0.1*ATR  -> GAP resistance
for L in levels:
  broken = L.isSupport ? close[1] < L.bandLo-0.15ATR : close[1] > L.bandHi+0.15ATR
  if broken: if !L.flipped {đổi vai; fresh=true; flipped=true} else xóa
  else if high[1] >= L.bandLo-0.15ATR && low[1] <= L.bandHi+0.15ATR:
         fresh=false; if awayOk && barsSinceTouch>3 {touches++; awayOk=false}
  else if swing mới quay đầu trong (0.15..0.60)ATR trước mép gần: misses++
  if |close[1]-L.price| > 1.0ATR: awayOk=true
```

```
// QM (Wonra) — xét 5 swing ZigZag-ATR gần nhất theo thứ tự thời gian s0..s4
Bull: s0=L2 s1=H2 s2=L1 s3=H1 s4=L0 ;  cần L0<L1, H2>H1, |H2-L0| >= 1.0*ATR
  BOS: có nến sau L0 (trong ≤150 nến) close > H1 + 0.15*ATR
  close hiện tại > L1; không có swing nào giữa L1..L0 thấp hơn L1 (đáy) hoặc cao hơn H1 (đỉnh)
  không trùng QML cũ (cách ≤0.15ATR). QML=L1; vùng=[L1-0.2ATR, L1]
  Vô hiệu (mặc định): close < L0 ("Close Beyond Head"). Tùy chọn khác: râu < L0; L0-0.15ATR; close ra khỏi vùng
  First-touch-back: sau BOS+2 nến, giá vào ±0.18ATR quanh L1 + xác nhận (mặc định "Close Reclaim")
  Sau BOS+2 nếu close < L1-0.15ATR -> đổi vai 1 lần. Hết hạn sau 300 nến hoặc khi giá xa >25ATR
Bear: đối xứng
```

```
// Storyline (Wonra): HTF tự động M1->H1, ≤M15->H4, ≤H1->D1, còn lại ->W1
HTF R = pivotHigh(max(open,close), 5, 5); HTF S = pivotLow(min(open,close), 5, 5)  // nến HTF đã đóng
Rejection bear: high >= R-0.5ATR && close < R-0.1ATR  -> chờ; bull đối xứng
Xác nhận: close < swing-low gần nhất đã xác nhận ở LTF -> storyline = GIẢM
          internal nếu swing đó hình thành sau nến rejection
```

### A3. Khoảng trống giá trị hợp lý (fair value gap, FVG)
- **Định nghĩa 3 nến** (nến 1 cũ nhất, nến 3 mới nhất). FVG tăng khi low(3) > high(1), vùng là [high(1), low(3)]. FVG giảm khi high(3) < low(1), vùng là [high(3), low(1)]. [1][2][3]
- **Điều kiện bổ sung theo từng nguồn**:
  - joshyattridge: nến giữa phải cùng hướng (close > open với FVG tăng). Có tùy chọn `join_consecutive` gộp các FVG liền nhau thành một (top lớn nhất, bottom nhỏ nhất). [1]
  - LuxAlgo: close(2) > high(1). Thân của nến giữa tính theo % phải lớn hơn ngưỡng tự động, bằng 2 × trung bình tích lũy của \|close−open\| chia open. [2]
  - "Strong FVG" (của Fleezzuss, nằm trong Wonra) [3]:
    - Chế độ All: không lọc kích thước.
    - Balanced: kích thước ≥ 0,5×ATR(14).
    - Conservative: ≥ 1,0×ATR **và** thân nến giữa > 60% biên độ.
    - **Bỏ FVG vắt qua phiên nghỉ**: nếu khoảng thời gian giữa hai nến > 2 lần khung thời gian. Điều này quan trọng với daily break và cuối tuần của vàng.
    - Bỏ FVG mới nếu nó trùng ≥ 60% với FVG đã có.
- **Mitigation/invalid, ba định nghĩa khác nhau**:
  - (i) joshyattridge: "mitigated" tại nến đầu tiên, tính từ nến i+2, có low ≤ top (FVG tăng), tức **chạm mép gần**. [1]
  - (ii) LuxAlgo: **xóa** khi low < bottom (FVG tăng) hoặc high > top (FVG giảm), tức giá đi xuyên hết vùng. Hộp được chia đôi tại trung điểm, tức mức 50% (consequent encroachment). [2]
  - (iii) Fleezzuss: "filled" khi râu chạm **mép xa**. Hộp dừng mở rộng tại nến đó. [3]
- Gợi ý cho EA: FVG chỉ được xác nhận khi nến 3 đóng. Cho FVG đi qua các trạng thái ACTIVE → TOUCHED → HALF (qua 50%) → FILLED, và tùy chọn INVALID khi close xuyên mép xa.

### A4. Khối lệnh (order block, OB)
- **LuxAlgo SMC** (cập nhật 23/09/2025) [2]:
  - OB được tạo ngay khi có BOS hoặc CHoCH, tức close cắt lên một swing high chưa từng bị cắt.
  - OB tăng là nến có "parsedLow" thấp nhất trong khoảng từ nến pivot tới nến ngay trước nến phá.
  - Vùng OB là [parsedLow, parsedHigh] của nến đó, tức cả biên độ kể cả râu.
  - Nến có high−low ≥ 2×ATR(200) (hoặc ≥ 2× trung bình TR tích lũy) bị **hoán đổi high/low**, nên gần như không bao giờ được chọn.
  - Xóa OB tăng khi low (hoặc close, nếu chọn chế độ Close) < đáy OB. OB giảm đối xứng.
  - Lưu tối đa 100 OB. Hiển thị 5 OB internal (mặc định bật) và 5 OB swing (mặc định tắt). Bộ lọc mặc định "Atr", mitigation mặc định "High/Low".
- **joshyattridge** (PyPI 0.0.27, 03/04/2026) [1]:
  - Khi close > high của swing high gần nhất chưa bị cắt: OB là nến có low thấp nhất trong khoảng (swing, nến phá), nếu bằng nhau thì lấy nến muộn hơn. Vùng là [low, high] của nến đó.
  - Nếu nến phá nằm ngay sau swing thì lấy nến trước nó. Ở nhánh này mã **gán top và bottom bị đảo**, đây là một lỗi cần tránh khi port.
  - Khi low < bottom (hoặc min(open, close) < bottom nếu bật `close_mitigation`), OB thành "breaker". Breaker bị hủy khi high > top.
  - Chỉ số độ mạnh = min/max của khối lượng hai nhóm nến. Hàm swing phía trên có look-ahead.
- **MSNR (Wonra)**: OB chính là thân của nến bị nhấn chìm trong EG, lật thành EF khi gãy (xem A2). [3]

### A5. Cấu trúc thị trường và xu hướng khung lớn (bias)
- **Máy trạng thái của LuxAlgo** [2]:
  - `bias` ∈ {BULL, BEAR}.
  - Khi close cắt lên swing high hiện tại (chưa bị cắt): nếu bias đang BEAR thì gắn nhãn **CHoCH** (change of character), ngược lại là **BOS** (break of structure). Sau đó đặt bias = BULL, đánh dấu mức đã bị cắt, và lưu OB. Chiều giảm đối xứng.
  - Chạy song song hai lớp: internal (size 5) và swing (size 50). Lớp internal chỉ tính khi mức internal khác mức swing.
- **joshyattridge** (phân loại sau khi đã có dữ liệu) [1]:
  - Xét 4 swing gần nhất có dạng [L, H, L, H].
  - BOS tăng khi L1 < L2 < H1 < H2. CHoCH tăng khi H2 > H1 > L1 > L2, tức có đáy thấp hơn rồi phá đỉnh.
  - Mức phá là H1. Chỉ số phá là nến đầu tiên, từ i+2 trở đi, có close > H1.
  - Bỏ các cấu trúc không bị phá, hoặc bị cấu trúc sau thay thế.
  - Vì cần swing H2 (tương lai) nên cách này không dùng trực tiếp được trong EA thời gian thực. Nên dùng kiểu LuxAlgo.
- **Kiểm tra BOS của Wonra**: close phải vượt mức + 0,15×ATR trong vòng ≤ 150 nến. [3]
- **Các cách lấy bias khung lớn**:
  - (1) EMA50 so với EMA200 trên HTF, lấy **nến HTF đã đóng** (shift 1, không nhìn trước). Khung HTF chọn tự động: M1→H1, M5/M15→H4. [3]
  - (2) Hướng của lần BOS/CHoCH cuối cùng trên H1/H4. [2]
  - (3) Storyline MSNR. [3]
- Trong MQL5: lấy dữ liệu HTF bằng `CopyRates` hoặc `iMA` với shift ≥ 1, và chỉ tính lại khi có nến M5 mới.

---

## B. Sự thật về Exness và MT5 cho vàng

### B1. Tên symbol và đặc tả theo loại tài khoản

| Tài khoản | Symbol vàng | Lot min / max | Kiểu khớp lệnh | Phí hoa hồng XAUUSD | Vị thế / lệnh chờ tối đa (MT5 real) | Margin call / Stop out |
|---|---|---|---|---|---|---|
| Standard Cent | **XAUUSDc** [16] | 0,01 / 200 cent lot. 1 cent lot = 0,01 lot chuẩn [17] | Market, không requote [17] | 0 | 1.000 (200 chờ) trên server Real23/40/42/46; 10.000 (200 chờ) trên các server MT5 khác [17] | 60% / 0% [17] |
| Standard | **XAUUSDm** [16] | 0,01 / 200 (07:00–20:59 GMT+0), 60 (21:00–06:59) [18] | Market [18] | 0 | Không giới hạn (1.000 chờ) [18] | 60% / 0% |
| Pro | **XAUUSD** [16] | 0,01 / 200 và 60 [19]. Trang Pro ghi XAUUSD ban đêm vẫn 200 [41] | **Instant** cho forex và kim loại, có requote [19][41] | 0 | Không giới hạn (1.000 chờ) [19] | 30% / 0% (100% trong giờ nghỉ cổ phiếu) |
| Raw Spread | **XAUUSD hoặc XAUUSDr** [16] | 0,01 / 200 và 60 [20] | Market [20] | 3,5 USD/lot/chiều [37] (snippet) | Không giới hạn (1.000 chờ) [20] | 30% / 0% |
| Zero | **XAUUSDz** [16] | 0,01 / 200 và 60 [21] | Market [21] | 5,5 USD/lot/chiều [37] (snippet), [36] | Không giới hạn (1.000 chờ) [21] | 30% / 0% |

- **Sửa lại giả định ban đầu:** Zero dùng **XAUUSDz** chứ không phải XAUUSD. Raw Spread có thể là XAUUSD hoặc XAUUSDr. [16]
- Với Pro, Help Center ghi market execution chỉ có khi tiền tệ tài khoản là USD/JPY/THB/CNY/IDR/VND. Câu này viết mơ hồ, cần đọc `SYMBOL_TRADE_EXEMODE` trong terminal. [19]
- Hợp đồng vàng: 1 lot = 100 oz. Tôi suy ra từ máy tính của Exness (0,01 lot có giá trị pip 0,01 USD) [35]. Pip vàng = 0,01, giá dạng 1934.567, tức 3 chữ số thập phân, point = 0,001 [38].
- **Bước lot (lot step)** không có trong các tài liệu tôi đọc được. Đọc `SYMBOL_VOLUME_STEP` lúc chạy.
- Tài khoản Cent: 1 lot XAUUSDc ≈ 1 oz tiền thật. Đây là suy luận từ quy đổi 0,01 lot chuẩn, cần kiểm tra lại bằng `SYMBOL_TRADE_CONTRACT_SIZE` và tick value.

### B2. Khớp lệnh, stop/freeze level, spread, swap, giờ giao dịch

**Mức dừng (stop level)** [24]
- Exness nói phần lớn khách hàng không có stop level, nhưng giá trị có thể thay đổi. Xem trong Personal Area → Contract Specifications.
- Khoảng cách tối thiểu: Buy stop ≥ Ask + 1 point; Sell stop ≤ Bid − 1 point; Buy limit ≤ Ask − 1 point; Sell limit ≥ Bid + 1 point.
- **Buy/Sell stop và SL không được đặt bên trong spread.** Limit và TP thì được.

**Mức đóng băng (freeze level):** Exness không công bố. Phải đọc `SYMBOL_TRADE_FREEZE_LEVEL` [46].

**Spread (thay đổi theo ngày)**
- Standard XAUUSDm: trung bình **26 pip = 0,26 USD**, tính trên phiên giao dịch trước, trang hiển thị lúc 26/09/2026 [35].
- Máy tính cho 0,01 lot: chi phí spread 0,26 USD, margin 21,43 USD ở đòn bẩy 1:200 [35]. Suy ra giá vàng khoảng 4.286 USD.
- Zero: trung bình 5 pip cộng 5,5 USD/chiều [36].
- Pro và Raw: tôi không lấy được con số riêng cho XAUUSD. Trang Exness chỉ ghi chung "từ 0,1 / 0,0 pip" [41].
- Spread nới rộng khi có tin, lúc mở hoặc đóng phiên [35].

**Swap**
- XAUUSD long −56,74 pip/lot/đêm (≈ −56,74 USD/lot), short = 0 [35][36].
- Có ghi "swap-free available" [35][36]; điều kiện được hưởng tùy khách hàng.
- Swap ba ngày tính vào đêm thứ Tư [36].

**Giờ máy chủ (server time):** MT5 của Exness chạy **GMT+0** và không đổi được [32].

**Giờ giao dịch vàng (UTC)** [34]
- Mở Chủ nhật 22:05 (hè) / 23:05 (đông), đóng thứ Sáu 20:58 / 21:58.
- **Nghỉ hằng ngày 20:58–22:01 (hè), 21:58–23:01 (đông).** Trang exness.jo ghi 20:58–22:02 [36].
- Khung "23:59–00:05" trong giả định ban đầu là của broker chạy giờ GMT+2/+3, **không đúng với Exness**.

**Yêu cầu ký quỹ cao hơn (Higher Margin Requirements, HMR) cho vàng** [31]. Áp dụng cho lệnh mở trong các khung giờ sau, đòn bẩy bị giới hạn ở 1:200–1:1000:
- Từ 15 phút trước đến 90 giây sau tin có tác động mạnh.
- 30 phút trước và khoảng 10 phút sau giờ nghỉ hằng ngày.
- Khoảng 3 giờ trước khi đóng cửa cuối tuần và 1 giờ sau khi mở lại.

### B3. Số lệnh chờ và vị thế tối đa
- Xem bảng B1. Bài "Too many orders" cập nhật khoảng 10 tháng trước ghi các con số cũ hơn và **mâu thuẫn** với trang từng loại tài khoản (ví dụ Standard Cent 50 lệnh chờ; Pro/Raw/Zero MT4 100) [23]. Nên tin trang tài khoản hơn.
- Luôn đọc `ACCOUNT_LIMIT_ORDERS` lúc chạy; giá trị 0 nghĩa là không giới hạn [47][49]. Xử lý mã lỗi 10033 (quá số lệnh chờ) và 10040 (quá số vị thế) [48].
- Trong MT5, SL/TP gắn vào vị thế (position), không tính là lệnh chờ [50].

### B4. Cách lệnh STOP và SL được khớp; chính sách trượt giá (slippage)

**Cơ chế MT5** [50]
- Buy Stop mua ở giá **Ask ≥ giá lệnh**; Sell Stop bán ở **Bid ≤ giá lệnh**. Nghĩa là giá khớp có thể bằng hoặc tệ hơn giá đặt.
- SL của lệnh mua được kích hoạt bằng Bid, SL của lệnh bán bằng Ask. SL/TP đóng toàn bộ vị thế.

**Chính sách của Exness**
- Lệnh stop không thể trượt có lợi, chỉ có thể trượt bất lợi. Lệnh limit thì ngược lại [26].
- Khi thị trường chạy gấp, SL/TP đóng ở giá có sẵn tiếp theo, sau khi đi qua một hàng đợi thực thi [29].
- **Quy tắc trượt giá (slippage rule)** [25]:
  - Áp dụng cho lệnh chờ, trên mọi công cụ và mọi loại tài khoản.
  - Với **XAUUSD, vùng miễn trượt = 0 đến 3× spread tại thời điểm khớp.** Nếu chênh lệch nhỏ hơn vùng này thì khớp đúng giá yêu cầu; nếu lớn hơn hoặc bằng thì khớp giá thị trường.
  - Ví dụ minh họa của Exness chính là **một SL XAUUSD trên tài khoản Pro**, nên thực tế quy tắc này áp dụng cho cả SL.
- **Đơn vị "pip" không nhất quán:** ví dụ gọi chênh lệch 0,010 là "10 pip" (tức pip = 0,001), trong khi bảng thuật ngữ ghi pip vàng = 0,01 [38]. Trong EA nên tính mọi thứ bằng giá thật: 3 × (Ask − Bid).
- Một snippet cũ ghi 5× spread, nghĩa là quy tắc này đã từng thay đổi.
- Lệnh chờ rơi vào gap: nếu chênh lệch giữa giá đầu tiên sau gap và giá yêu cầu ≥ vùng miễn trượt thì khớp ở giá đầu tiên sau gap [30] (snippet).
- Có trang bên thứ ba nói Exness "không trượt giá với lệnh chờ khớp sau khi thị trường mở ≥ 3 giờ" [43]. Câu này không còn trong Help Center hiện tại; nên coi là đã lỗi thời.

### B5. Lệnh BUY_STOP_LIMIT / SELL_STOP_LIMIT
- **Cơ chế:** khi giá chạm giá kích hoạt (`price`), MT5 đặt một lệnh Limit tại giá `stoplimit` [45][44].
- **Theo MT5 chính thức: với Buy Stop Limit, giá StopLimit phải NẰM DƯỚI giá kích hoạt; với Sell Stop Limit, NẰM TRÊN** [51].
  - Tức không thể đặt giá limit "tệ hơn" giá kích hoạt để giới hạn trượt giá.
  - Khoảng cách tối thiểu do `SYMBOL_TRADE_STOPS_LEVEL` quyết định; nếu bằng 0 thì có thể đặt limit bằng đúng giá kích hoạt [52] (thảo luận forum 2023, chưa xác minh).
- **Hệ quả trên Exness (OTC):**
  - Stop-limit là kiểu vào lệnh "breakout rồi chờ hồi về". Ưu điểm: không bao giờ trượt bất lợi.
  - Nhược điểm: có thể **không khớp** nếu giá chạy thẳng hoặc gap qua. Lệnh limit còn lại vẫn chiếm quota lệnh chờ và phải dọn dẹp.
  - **Không dùng được làm SL có trần trượt giá.** Bài MQL5 [53] làm được việc này vì đó là sàn Moscow (exchange execution). Thêm nữa, ở chế độ hedging, lệnh chờ mở vị thế mới chứ không đóng vị thế cũ.
- Exness có hỗ trợ stop-limit trên MT5 [27]. Nhưng phải kiểm tra `SYMBOL_ORDER_MODE & SYMBOL_ORDER_STOP_LIMIT` cho đúng symbol vàng [46].
- Luật Exness yêu cầu Buy limit ≤ Ask − 1 point [24]. Vì vậy đặt limit bằng đúng giá kích hoạt có thể bị từ chối lúc kích hoạt. Cần thử trên demo.
- Kiểu khớp khối lượng (filling): tài liệu MQL5 khuyên dùng `ORDER_FILLING_RETURN` cho lệnh chờ; RETURN không được phép với market order trên symbol market execution [45]. Kiểm tra `SYMBOL_FILLING_MODE`; nếu sai sẽ nhận lỗi 10030.
- **Chỉ tài khoản Pro (instant execution)** mới có trần giá thật cho market order, thông qua `price` + `deviation`, và có requote [44][28]. Trên tài khoản market execution, deviation bị bỏ qua.

### B6. Kỹ thuật chống trượt giá khi thị trường chạy nhanh

1. **Lọc spread:** chặn khi spread hiện tại > 2,0 × trung bình của 200 mẫu gần nhất [62]. Nên thêm trần tuyệt đối, ví dụ Standard là 0,5–0,6 USD (gợi ý của tôi).
2. **Lọc tốc độ tick:** chặn khi > 40 tick/giây (mặc định cho FX) [62]. Cần hiệu chỉnh lại cho vàng.
3. **Lọc nhảy giá giữa hai tick liên tiếp:** chặn khi > 150 point [62]. Với vàng 3 chữ số, 150 point chỉ là 0,15 USD, còn nhỏ hơn spread. Phải đổi thang, ví dụ > 1× spread hoặc > 0,2×ATR(M1) (gợi ý).
4. **Lọc biến động vi mô:** độ lệch chuẩn của lợi suất 20 tick nằm ngoài [3, 120] point thì chặn [62]. Bài viết còn gộp các yếu tố trên thành điểm tổng hợp (ngưỡng 2,5) và phân loại trạng thái như HIGH_RISK_NEWS [62].
5. **Lọc tin tức:**
   - Dùng `CalendarValueHistory(v, from, to, "US", "USD")` rồi `CalendarEventById`, lọc `importance` = HIGH. Thời gian tính theo giờ server [58].
   - Cửa sổ chặn tối thiểu: từ −15 phút đến +90 giây, trùng với HMR [31].
   - **Lịch kinh tế không chạy trong Strategy Tester.** Phải xuất ra CSV hoặc resource để backtest [59].
6. **Tham số deviation:** chỉ có tác dụng với instant/request execution [44]. Exness không áp dụng deviation cho lệnh đóng bởi SL/TP [28].
7. **SL ảo và SL trên server:**
   - Kiểu lai hay dùng: SL ảo chặt để điều khiển, cộng một SL cứng xa hơn trên server để phòng mất kết nối [63].
   - Suy luận của tôi, cần kiểm chứng: SL trên server (và lệnh chờ) được hưởng slippage rule của Exness; còn lệnh đóng market do EA tự gửi thì không.
8. **Đo trượt giá sau khi khớp:**
   - Dùng `OnTradeTransaction` với sự kiện DEAL_ADD, so `DEAL_PRICE` với giá lệnh đặt. Nếu trượt quá X thì đóng ngay, hoặc dời SL/TP để giữ nguyên tỷ lệ rủi ro.
   - Lưu ý: thứ tự các transaction không được đảm bảo, và hàng đợi chỉ chứa 1024 phần tử [56].
9. **Tạm dừng sau cú giật và freeze level:** sau spike, chờ một khoảng cooldown; hủy các lệnh chờ gần giá **trước khi** giá lọt vào vùng freeze. Trong vùng freeze thì không sửa hay xóa được lệnh, ví dụ BuyStop cần OpenPrice − Ask ≥ FREEZE_LEVEL [49].
10. **Phiên nghỉ và gap trên Exness** (gợi ý dựa trên [31][34]):
    - Hủy lệnh chờ ít nhất 30 phút trước giờ nghỉ hằng ngày (20:28 UTC mùa hè / 21:28 mùa đông).
    - Đặt lại ít nhất 10 phút sau khi mở lại, và khi spread đã bình thường.
    - Cuối tuần: hủy lệnh chờ ít nhất 3 giờ trước khi đóng thứ Sáu. Thứ Hai đặt lại ít nhất 1 giờ sau khi mở.
    - Dùng `SymbolInfoSessionTrade` và `TimeTradeServer` để tự xử lý giờ hè/đông [64]. Bỏ các FVG vắt qua giờ nghỉ [3].

### B7. Ràng buộc MQL5 với EA lưới lệnh
- **OnTick:** nếu một sự kiện NewTick đang chờ hoặc đang xử lý thì tick mới **không được xếp hàng**, tức bị bỏ qua [54]. Việc nặng nên chuyển sang `OnTimer`. Timer có độ phân giải 10–16 ms và mỗi chương trình chỉ có một timer [55]. Lần gọi `CopyTicks` đầu tiên có thể chờ đồng bộ đến 45 giây [57].
- **Giới hạn tần suất lệnh:**
  - Không có con số được công bố. Server có thể trả lỗi 10024 (gửi lệnh quá dày) [48].
  - Exness có thể **tắt EA** nếu cấu hình "quá hung hăng" và gửi yêu cầu dồn dập [40].
  - Gợi ý: chỉ sửa lệnh khi thay đổi đủ lớn, gom thao tác theo nến hoặc theo timer, và lùi thời gian thử lại khi gặp 10024.
- **Mã trả về cần xử lý:** 10004 requote, 10016 SL/TP không hợp lệ, 10029 lệnh bị đóng băng, 10030 sai kiểu filling, 10033 quá số lệnh chờ, 10040 quá số vị thế, 10046 cấm hedge [48].
- **Hedging và netting:**
  - Chế độ netting chỉ có **một vị thế cho mỗi symbol**. Một Sell Stop khớp sẽ giảm hoặc đảo vị thế long hiện có.
  - Lưới có vị thế BUY và SELL độc lập, mỗi cái có SL/TP riêng, **bắt buộc dùng `ACCOUNT_MARGIN_MODE_RETAIL_HEDGING`** [47]. Kiểm tra điều này trong OnInit.
  - Exness cho phép hedge; lệnh hedge hoàn toàn không tốn margin, trừ trong khung giờ HMR [39].
- **Strategy Tester:**
  - Chế độ "Every tick based on real ticks" dùng tick thật do broker lưu. Phút nào thiếu tick thì tester tự sinh; spread thay đổi được trong từng phút [60][61].
  - Chế độ "No delay" khớp mọi lệnh **đúng giá yêu cầu**, không requote, nên **không mô phỏng trượt giá** [60]. Hãy bật độ trễ ngẫu nhiên hoặc cố định, hoặc tự viết mô hình trượt giá.
  - Symbol trong tester phải khớp đúng hậu tố của tài khoản (XAUUSDm, XAUUSDz…).
  - Chưa rõ tester có tính phí hoa hồng Raw/Zero hay không. Cần kiểm tra trong báo cáo backtest.

---

## Các điểm chưa chắc, cần kiểm tra trên terminal hoặc demo
1. Giá trị thật của `SYMBOL_TRADE_STOPS_LEVEL`, `SYMBOL_TRADE_FREEZE_LEVEL`, `SYMBOL_VOLUME_STEP`, `SYMBOL_TRADE_CONTRACT_SIZE` và `SYMBOL_ORDER_MODE` (có cho stop-limit không) trên đúng symbol vàng của từng loại tài khoản.
2. Phí hoa hồng Raw/Zero cho XAUUSD chỉ có từ snippet [37] và trang exness.jo [36]. Spread XAUUSD của Pro/Raw chưa lấy được.
3. Mâu thuẫn về giới hạn lệnh chờ giữa [23] và [17]–[21].
4. Kiểu khớp lệnh thực tế của tài khoản Pro với XAUUSD.
5. Hệ số của slippage rule (3× hay 5×) và đơn vị "pip".
6. Stop-limit với limit bằng giá kích hoạt có được chấp nhận không.
7. Tester có tính phí hoa hồng hay không.
8. Mọi ngưỡng ở mục A1 và B6 đánh dấu "gợi ý" là của tôi, chưa backtest.

## Nguồn
[1] https://github.com/joshyattridge/smart-money-concepts/blob/master/smartmoneyconcepts/smc.py · https://pypi.org/project/smartmoneyconcepts/
[2] https://www.tradingview.com/script/CnB3fSph-Smart-Money-Concepts-SMC-LuxAlgo/
[3] https://www.tradingview.com/script/ANCSINu0-Wonra-Alchemist-SNR-Engine/ (đăng 28/7, năm không hiển thị, có thể là 2026)
[4] https://www.tradingview.com/script/iWgxW7bW/
[5] https://www.tradingview.com/script/xg43U6tE/
[6] https://www.tradingview.com/scripts/malaysiansnr/
[7] https://www.tradingview.com/script/20NljIPT-Malaysian-SnR-Levels/
[8] https://www.mql5.com/en/market/product/115614
[9] https://www.tradingview.com/script/zHJLrkfS-Malaysian-SnR-Storyline/
[10] https://www.tradingview.com/script/v5zEBKFJ-Malaysian-SnR-Levels-UAlgo/ (đã bị gỡ)
[11] https://crowinvesting.com/guides/msnr-trading-explained/
[12] https://www.tradingview.com/script/Ej53t8Wv-Support-Resistance-Channels/
[13] https://www.metatrader5.com/en/terminal/help/indicators/bw_indicators/fractals
[14] https://github.com/fxpro-com/0mqL/blob/master/clienteRobo1/MQL4/Indicators/ZigZag.mq4
[15] https://www.mql5.com/en/articles/20021
[16] https://get.exness.help/hc/en-us/articles/360014560220-Account-type-suffixes
[17] https://get.exness.help/hc/en-us/articles/17537782786588-Standard-Cent-account
[18] https://get.exness.help/hc/en-us/articles/17537782738460-Standard-account
[19] https://get.exness.help/hc/en-us/articles/17537794560540-Pro-account
[20] https://get.exness.help/hc/en-us/articles/17537767270556-Raw-Spread-account
[21] https://get.exness.help/hc/en-us/articles/17537782878236-Zero-account
[22] https://get.exness.help/hc/en-us/articles/360013782240-Trading-account-types
[23] https://get.exness.help/hc/en-us/articles/360012824139--Too-many-orders-error
[24] https://get.exness.help/hc/en-us/articles/360011676519-About-stop-levels
[25] https://get.exness.help/hc/en-us/articles/18054855363484-Slippage-rule
[26] https://get.exness.help/hc/en-us/articles/4418146279954-How-slippage-happens
[27] https://get.exness.help/hc/en-us/articles/360017885880-Available-order-and-execution-types
[28] https://get.exness.help/hc/en-us/articles/4402644779538-Setting-deviation
[29] https://get.exness.help/hc/en-us/articles/360017263680-Setting-stop-loss-SL-and-take-profit-TP
[30] https://get.exness.help/hc/en-us/articles/7766359507484-Why-was-my-pending-order-not-executed (snippet)
[31] https://get.exness.help/hc/en-us/articles/20618327917596-Higher-Margin-Requirements-HMR
[32] https://get.exness.help/hc/en-us/articles/360014390760-What-is-the-default-timezone-set-for-MetaTrader
[33] https://get.exness.help/hc/en-us/articles/4405235684498-Instrument-trading-hours
[34] https://www.exness.global/blog/product/exness-trading-hours/
[35] https://www.exness.com/commodities/ · https://www.exness.com/commodities/xauusd/
[36] https://www.exness.jo/en/commodities/
[37] https://get.exness.help/hc/en-us/articles/17854173039388-Commodities (snippet)
[38] https://get.exness.help/hc/en-us/articles/360014740179-Common-trading-terms
[39] https://get.exness.help/hc/en-us/articles/360014696320-Hedged-orders
[40] https://get.exness.help/hc/en-us/articles/360019530859-Using-Expert-Advisors-EA
[41] https://www.exness.com/pro-accounts/
[42] https://www.exness.com/order-execution/
[43] https://www.forexbrokerz.com/news/exness-forex-broker-execution
[44] https://www.mql5.com/en/docs/constants/structures/mqltraderequest
[45] https://www.mql5.com/en/docs/constants/tradingconstants/orderproperties
[46] https://www.mql5.com/en/docs/constants/environment_state/marketinfoconstants
[47] https://www.mql5.com/en/docs/constants/environment_state/accountinformation
[48] https://www.mql5.com/en/docs/constants/errorswarnings/enum_trade_return_codes
[49] https://www.mql5.com/en/articles/2555
[50] https://www.metatrader5.com/en/terminal/help/trading/general_concept
[51] https://www.metatrader5.com/en/mobile-trading/android/help/trade/general_concept/order_types
[52] https://www.mql5.com/en/forum/444972
[53] https://www.mql5.com/en/articles/1683
[54] https://www.mql5.com/en/docs/event_handlers/ontick
[55] https://www.mql5.com/en/docs/eventfunctions/eventsetmillisecondtimer
[56] https://www.mql5.com/en/docs/event_handlers/ontradetransaction
[57] https://www.mql5.com/en/docs/series/copyticks
[58] https://www.mql5.com/en/docs/calendar/calendarvaluehistory · https://www.mql5.com/en/docs/calendar
[59] https://www.mql5.com/en/forum/312462 · https://www.mql5.com/en/articles/22231
[60] https://www.metatrader5.com/en/terminal/help/algotrading/testing
[61] https://www.metatrader5.com/en/terminal/help/algotrading/tick_generation
[62] https://www.mql5.com/en/articles/22772
[63] https://www.mql5.com/en/blogs/post/766160
[64] https://www.mql5.com/en/docs/marketinformation/symbolinfosessiontrade
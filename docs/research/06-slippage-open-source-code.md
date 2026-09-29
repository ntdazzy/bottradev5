# Nghiên cứu mã nguồn: bảo vệ trượt giá (slippage) cho EA MT5 gọi vàng XAUUSD trên Exness Standard

**Kết luận chính:**
- Trên Exness Standard, kiểu khớp lệnh gần như chắc chắn là khớp theo thị trường (Market Execution). Khi đó trường `deviation` không có tác dụng. Muốn bảo vệ thì chỉ còn ba cách: lọc trước khi vào lệnh, chọn đúng kiểu lệnh, và đo trượt giá sau khi khớp.
- Tôi không tìm thấy mã nguồn mở nào xử lý trường hợp lệnh dừng-giới hạn (stop-limit) đã kích hoạt nhưng lệnh giới hạn sinh ra không khớp. EA của bạn phải tự viết phần này.
- Chế độ trễ (delay) của Strategy Tester không mô phỏng trượt giá cho SL và lệnh chờ đặt trên server. Nghĩa là thiết kế của bạn không thể kiểm tra trượt giá bằng chế độ trễ.

**Quy ước nhãn:**
- **[đã đọc mã]**: tôi tải file nguồn và đọc/grep trực tiếp.
- **[đã đọc mã – trích xuất]**: đọc qua công cụ trích xuất tự động từ file thô hoặc trang bài viết. Có thể bị diễn giải lại một chút, chưa đối chiếu từng dòng.
- **[mô tả]**: chỉ có mô tả, bài viết hoặc diễn đàn, không thấy mã.
- Nhiều bài trên MQL5 ghi ngày năm 2026. Tôi ghi đúng như trang hiển thị.

---

## 1. Đo trượt giá sau khi khớp (post-fill slippage measurement)

**1a. ExecutionQualityMonitor.mq5** (Walter M. Rando, 11/08/2026) — https://www.mql5.com/en/articles/22998, mã: https://www.mql5.com/en/articles/download/22998/ExecutionQualityMonitor.mq5 **[đã đọc mã]**

- **Chế độ thụ động (passive):**
  - Trong `OnTradeTransaction`, chỉ xử lý `TRADE_TRANSACTION_DEAL_ADD`, rồi `HistoryDealSelect(trans.deal)`.
  - Lọc theo symbol, magic, `DEAL_TYPE` là BUY/SELL, và `DEAL_ENTRY_IN` so với `OUT/OUT_BY`.
  - Giá tham chiếu (reference) = `SymbolInfoTick()` tại lúc xử lý sự kiện (ask nếu buy, bid nếu sell). Giá khớp (fill) = `DEAL_PRICE`. Thời gian lấy từ `DEAL_TIME_MSC`.
- **Chế độ thăm dò (probe):**
  - Chụp `t0` trước `trade.Buy()`, `refIn = t0.ask/bid`.
  - Đo `GetTickCount()` trước và sau lệnh để có độ trễ. Giá khớp = `trade.ResultPrice()`. Lưu cả mã trả về (retcode).
- **Công thức:** `slip = isBuy ? (fill-ref)/_Point : (ref-fill)/_Point`. Số dương nghĩa là bất lợi.
- **Thống kê:**
  - Trung bình, trung vị và p95 qua `StatPctl`: sắp xếp rồi lấy `rank = MathRound(p*(n-1))`.
  - Giá trị lớn nhất (max).
  - Độ bất đối xứng (asymmetry) = `avg(entry) − avg(exit)`.
  - Ghi CSV các cột `time, source, symbol, side, phase, reference, fill, slippage_points, spread_points, retcode, latency_ms`.
- **Ví dụ XAUUSD trong bài** [mô tả]: trung bình 22.5 point, trung vị 18, p95 70, bất đối xứng 14.5 point, độ trễ 95 ms (tệ nhất 320 ms). Không rõ broker và số chữ số thập phân, chỉ nên coi là minh họa.
- Tác giả tự cảnh báo: chế độ thụ động chỉ là xấp xỉ, vì tick đọc lúc xử lý sự kiện không phải giá lúc khớp.

**1b. Phát hiện bất thường khi khớp bằng Isolation Forest** (O. D. Adebayo, 17/09/2026) — https://www.mql5.com/en/articles/24251 **[mô tả + trích đoạn]**

- `RecordPendingRequest()` lưu giá và `GetTickCount64()` vào biến toàn cục ngay trước `trade.Buy()`.
- Trong `OnTradeTransaction` (chỉ `DEAL_ENTRY_IN`): `slippage_pts = MathAbs(DEAL_PRICE − g_pending_request_price)/point`. Dùng giá trị tuyệt đối nên mất dấu (không phân biệt lợi hay bất lợi).
- Ngưỡng bất thường 0.68. Khi vượt ngưỡng: tạm dừng 10 nến, nới stop ×1.5. Dừng hẳn nếu tỷ lệ bất thường vượt 35% trên 30 lệnh gần nhất.

**1c. Các trường dữ liệu cần dùng**

- Với khớp theo thị trường, `ORDER_PRICE_OPEN` của lệnh thị trường bằng 0. Muốn đo phải tự chụp giá trước khi gửi, hoặc tra lịch sử tick theo mili-giây [mô tả] — https://www.mql5.com/en/forum/437629
- Với lệnh chờ: lấy giá kích hoạt từ `HistoryOrderGetDouble(ORDER_PRICE_OPEN)`, giá khớp từ `HistoryDealGetDouble(DEAL_PRICE)` [mô tả] — https://www.mql5.com/en/forum/428338
- Tài liệu chính thức: với deal thoát, `DEAL_SL` là SL của vị thế tại lúc đóng; `DEAL_REASON_SL` cho biết deal do SL kích hoạt — https://www.mql5.com/en/docs/constants/tradingconstants/dealproperties
  - Từ đó (suy luận của tôi): trượt giá SL của vị thế buy = `DEAL_SL − DEAL_PRICE`.
- `OnTradeTransaction`: thứ tự sự kiện không được đảm bảo, hàng đợi tối đa 1024 phần tử, `request/result` chỉ có dữ liệu với `TRADE_TRANSACTION_REQUEST` — https://www.mql5.com/en/docs/event_handlers/ontradetransaction
- Với `DEAL_ADD`, `trans.price` là giá deal. Theo dõi yêu cầu qua `result.request_id` [mô tả] — https://www.mql5.com/en/book/automation/experts/experts_ontradetransaction

**1d. Đặt lại SL/TP theo giá khớp thật**

- **PulseStrike** (trang tên "ZetaBurst Scalper", code 77220; header file lại ghi `PulseStrike_Scalper.mq5`, tên không khớp) — https://www.mql5.com/en/code/download/77220/Zeta_Burst.mq5 **[đã đọc mã]**
  - Mở `trade.Buy(lot,_Symbol,0.0,0.0,0.0)` không kèm SL/TP, rồi `PositionSelect`, lấy `POSITION_PRICE_OPEN`, tính `sl = open ∓ slDist`, gọi `PositionModify`.
  - Nếu `PositionModify` thất bại thì `PositionClose` ngay.
  - Chú thích trong mã giải thích lý do: SL tính từ giá chụp trước bị lỗi "Invalid stops" khi có trễ.
- **SlippageReduction()** (K. F. Mampa, 06/11/2024) — https://www.mql5.com/en/articles/16169 **[mô tả + trích đoạn]**
  - Tính lại `SL = POSITION_PRICE_OPEN − SL×Point`. Nếu khác `POSITION_SL` thì gọi `PositionModify`.
  - `FundamentalMode` xóa lệnh stop ngược chiều sau khi một bên đã khớp.
- **CTradeManager** lưu `entry_price = m_trade.ResultPrice()` **[đã đọc mã – trích xuất]** — https://github.com/francomascareloai/EA_SCALPER_XAUUSD/blob/main/MQL5/Include/EA_SCALPER/Execution/CTradeManager.mqh

## 2. Bộ lọc thị trường nhanh trước khi vào lệnh (pre-trade fast-market filters)

**Lọc spread tuyệt đối, có số cụ thể cho XAUUSD:**

- **gold-pro-scalper** — https://github.com/n30dyn4m1c/gold-pro-scalper **[đã đọc mã – trích xuất]**
  - Biến thể TickRobust:
    - `InpMaxSpreadPts=50`.
    - Chi phí `cost = spread + InpExtraCostPts`. Chỉ vào lệnh khi độ lệch chuẩn (StdDev) ≥ 3×cost và khoảng TP ≥ 4×cost.
    - `SL = max(800 pts, 2.5×ATR)`, TP đặt bằng lệnh limit trên server, `deviation=30`.
  - Biến thể Breakout:
    - Tỷ lệ ATR nhanh/chậm phải trong khoảng [0.5, 2.0].
    - Chặn tin tức ±60 phút quanh tin USD mức cao (dùng lịch MQL5), có tùy chọn đóng lệnh trước tin.
    - Chờ 10 nến sau một lệnh thua.
- **trillex-10s-ea**: `InpMaxSpreadPoints=30`, SL cứng 200 point [mô tả, README] — https://github.com/NadirAliOfficial/trillex-10s-ea
- **PulseStrike** **[đã đọc mã]**: `InpMaxSpreadPoints=20` (đọc từ `SYMBOL_SPREAD`), bắt buộc `tpDist ≥ 3×spread`, nghỉ `InpCooldownSeconds=5`.

**Lọc spread theo ATR:**

- **nyao_scalper**: `MaxSpreadATRRatio=0.25` (các profile từ 0.20 đến 0.35). Giới hạn = `MaxSpreadPoints>0 ? MaxSpreadPoints : ATR×0.25` **[đã đọc mã – trích xuất]** — https://github.com/elrizwiraswara/nyao_scalper_mt5
  - Có thể lệch đơn vị: vế trái là giá, vế phải là point khi `MaxSpreadPoints>0`. Chưa kiểm chứng từng dòng.
- **Bài 20371** (30/01/2026) — https://www.mql5.com/en/articles/20371
  - `MaxAbsoluteSpread=10 pips`, `MaxSpreadATRRatio=0.25` so với ATR(H1,14).
  - Khi vượt ngưỡng tuyệt đối thì khóa giao dịch `DisableTimeoutSec=60` giây.
  - Tính trên giá trị tức thời, không có trung bình trượt.
  - Công thức chia `spreadInPips/atrValue` có vẻ lệch đơn vị.
- **PropSpread** (code 77391): lấy mẫu spread mỗi giây bằng timer (trung bình theo thời gian), tính spread theo % ATR(14), phải giữ trên ngưỡng 5 giây, nghỉ giữa hai lần cảnh báo 300 giây [mô tả] — https://www.mql5.com/en/code/77391
- **Spread Monitor Panel** (code 74565): cảnh báo khi spread ≥ ngưỡng nguy hiểm liên tục N giây [mô tả] — https://www.mql5.com/en/code/74565
- **SpreadMonitor.mqh** (code 69096): vòng đệm (ring buffer) 500 mẫu, trung bình và độ lệch chuẩn `sqrt(sum²/n − mean²)`. Tuy vậy `IsSpreadAcceptable()` chỉ so với ngưỡng tuyệt đối (mặc định 3.0 pip) **[đã đọc mã – trích xuất]** — https://www.mql5.com/en/code/69096
- **Chưa tìm được mã đã kiểm chứng** cho kiểu "spread hiện tại > k × trung bình trượt".

**Tốc độ và cú nhảy giá:**

- **Burst z-score của PulseStrike** **[đã đọc mã]**
  - Đệm giá giữa (mid) trong `InpBurstWindowSeconds=4` giây. Lưu ý `TimeCurrent()` chỉ có độ phân giải 1 giây.
  - Mỗi 4 giây ghi `windowReturn = last − first` vào mẫu nền, giữ 120 mẫu (khoảng 8 phút).
  - Cần n ≥ 20 mẫu. `z = (move − mean)/stddev`, coi là bùng nổ khi |z| ≥ 3.0.
  - Tác giả dùng để vào lệnh, nhưng có thể đảo lại thành bộ lọc thị trường nhanh.
- **Tick Speed Indicator** (code 43889): đo số giây để đủ 100 tick [mô tả] — https://www.mql5.com/en/code/43889
- **Diễn đàn 392046**: chỉ xử lý tick khi `MathAbs(prev−last) >= minDistance`, hoặc xử lý theo nhịp 1 giây/lần [mô tả] — https://www.mql5.com/en/forum/392046

**Đột biến biến động và thời gian nghỉ (cooldown):**

- **CVirtualGate** **[đã đọc mã – trích xuất]** — https://github.com/francomascareloai/EA_SCALPER_XAUUSD/blob/main/MQL5/Include/EA_SCALPER/Risk/CVirtualGate.mqh
  - Chỉ dùng nến đã đóng, tính trung vị biên độ (range) của 20 nến.
  - Chặn khi biên độ/trung vị > 3.0.
  - Chặn theo cụm: nếu hơn 30% số nến có biên độ > 2.5× trung vị.
- **CGapCooldown** (cùng repo, `Risk/CGapCooldown.mqh`): khi khoảng cách giữa hai nến ≥ 30 phút thì nghỉ 15 phút **[đã đọc mã – trích xuất]**

## 3. SL ảo (virtual/hidden) so với SL trên server, và kiểu lai (hybrid)

**C_Trade.mqh** (Balrog100, MT4, 2017) — https://www.mql5.com/en/code/download/19149/C_Trade.mqh **[đã đọc mã]**

- SL thật trên server cho lệnh BUY: `max(0, min(price − max(STOPLEVEL,FREEZELEVEL)·Point − LiveSpread, hiddenSL − LiveSpread))`. Lệnh SELL đối xứng. `LiveSpread` là khoảng đệm theo giá, truyền vào qua tham số.
- `ScanWithEveryTick`:
  - BUY: nếu `Bid < hiddenSL` thì `OrderClose(Bid, slippage)`.
  - Nếu đóng thất bại mà `OrderSelect(...MODE_HISTORY)` tìm thấy lệnh thì coi như đã bị đóng theo cách khác, ví dụ SL thật đã khớp. Đây là cách duy nhất mã này xử lý gap hoặc mất kết nối.
  - Không có vòng thử lại. Tác giả ghi rõ chưa chạy thử trên tài khoản thật.

**Virtual Trailing Stop** (cmillion, code 13853) — https://www.mql5.com/en/code/download/13853/virtual_trailing_stop.mq4 **[đã đọc mã]**

- Có hai lỗi đáng lưu ý:
  - Đóng lệnh buy nhưng truyền giá **Ask**, dựa vào `slippage=30` để lệnh vẫn qua.
  - Chỉ đóng khi `OrderProfit()>0`, và không có SL trên server. Nếu giá gap vào vùng lỗ thì trailing ảo sẽ **không đóng** lệnh.

**Local SL** (bài 22691, 11/06/2026) — https://www.mql5.com/en/articles/22691 [trích đoạn]

- Lưu SL trong `CHashMap` trên bộ nhớ, không lưu bền, không có SL trên server.
- Đóng khi `bid<=SL` hoặc `ask>=SL`.
- Mất kết nối không gọi `OnDeinit`; EA chỉ chờ tick tiếp theo.

**Kiểu lai** [mô tả]: SL ảo ở mức rủi ro 1%, SL cứng trên server ở 2%. Khi trailing, giữ nguyên khoảng cách giữa hai mức — https://www.mql5.com/en/forum/369345. SL trên server nằm ở phía broker — https://www.mql5.com/en/forum/494584

**Quy tắc trượt giá của Exness (slippage rule)** [mô tả; trang không truy cập được, thông tin lấy từ tóm tắt kết quả tìm kiếm] — https://get.exness.help/hc/en-us/articles/18054855363484-Slippage-rule

- Áp dụng cho lệnh chờ, gồm cả SL: khớp đúng giá yêu cầu nếu chênh lệch nằm trong "vùng không trượt" (slippage-free range).
- Với XAUUSD vùng này từ 0 đến 3× spread. Vùng thay đổi động và có thể về 0.
- Suy luận của tôi, chưa kiểm chứng: SL trên server có thể khớp tốt hơn việc đóng bằng lệnh thị trường khi dùng SL ảo.

## 4. Lệnh dừng-giới hạn (stop-limit) để giới hạn trượt giá

**Bài 1683** (V. Sokolov, 09/10/2015), `panelsl.mqh` — https://www.mql5.com/en/articles/download/1683/panelsl.mqh **[đã đọc mã]**

- Vào lệnh bằng lệnh limit: `ask + m_deviation·Point` với buy, `bid − m_deviation·Point` với sell.
- SL đặt bằng `ORDER_TYPE_SELL_STOP_LIMIT`: `price = m_sl_level`, `stoplimit = m_sl_level − m_deviation·Point`. Chiều ngược lại dùng BUY_STOP_LIMIT.
- `type_filling = ORDER_FILLING_RETURN`, `type_time = ORDER_TIME_DAY`, mặc định `m_deviation = 3`.
- Chỉ kiểm tra `m_sl_level < bid` trước khi đặt. **Không quản lý** trường hợp lệnh limit không khớp.

**Tài liệu:**

- Khi kích hoạt, stop-limit đặt ra một lệnh Buy Limit hoặc Sell Limit, không phải lệnh thị trường — https://www.mql5.com/en/book/automation/experts/experts_order_type
- Nên kiểm tra `SYMBOL_ORDER_MODE & SYMBOL_ORDER_STOP_LIMIT (8)` và `SYMBOL_TRADE_EXEMODE` trước khi dùng — https://www.mql5.com/en/docs/constants/environment_state/marketinfoconstants
- Exness có liệt kê Buy/Sell Stop Limit trên MT5, nhưng không rõ tài khoản Standard có được dùng không [mô tả] — https://get.exness.help/hc/en-us/articles/360017885880-Available-order-and-execution-types

**Lỗ hổng:** không tìm thấy mã mở nào quản lý lệnh limit sinh ra từ stop-limit mà không khớp (hủy sau T giây, hoặc hủy khi giá vượt X).

## 5. Thử lại khi gửi lệnh lỗi (retry / requote)

**Bài 23315** (U. K. Iorkumbul, 13/07/2026) — https://www.mql5.com/en/articles/23315 **[đã đọc mã – trích đoạn trong bài]**

- **Thử lại:** tối đa 4 lần. Thời gian chờ `min(200·2^(attempt−1), 5000)` ms.
- **Cầu dao ngắt (circuit breaker):** 5 lần lỗi liên tiếp thì chuyển sang OPEN. Sau 30 giây sang HALF-OPEN. Cần 2 lần thử thành công thì đóng lại. Lỗi vĩnh viễn không tính vào bộ đếm.
- **Chống lệnh trùng:** `IsSubmissionSafe()` chặn gửi nếu đã có vị thế cùng symbol/magic, hoặc có lệnh với `ORDER_TYPE<=SELL && ORDER_POSITION_ID==0` (lệnh thị trường đang trên đường đi).
- **Lỗi trong mã:** mảng mã được phép thử lại là `10006 // CONNECTION`, `10010 // TIMEOUT`, `10030 // TOO_MANY_REQUESTS`. Theo tài liệu chính thức thì 10006=REJECT, 10010=DONE_PARTIAL, 10030=INVALID_FILL. Mã đúng là CONNECTION=10031, TIMEOUT=10012, TOO_MANY_REQUESTS=10024 — https://www.mql5.com/en/docs/constants/errorswarnings/enum_trade_return_codes. Nên dùng hằng số có tên thay vì số.
- Ngoài ra không làm mới giá trước khi thử lại, và gọi `Sleep()` ngay trong `OnTick`.

**TradeExecutor** (repo francomascareloai) **[đã đọc mã – trích xuất]**

- `deviation = 10`. Hủy lệnh nếu spread > 2×deviation.
- Chỉ thử lại 2 lần, với REQUOTE và PRICE_CHANGED. Làm mới giá bằng `SymbolInfoTick` giữa các lần. Không có khóa chống trùng.

**CTradeManager** **[đã đọc mã – trích xuất]**

- Sửa lệnh thử lại 3 lần với REQUOTE, PRICE_CHANGED, PRICE_OFF.
- Có cờ `m_operation_in_progress`. Nhận định của tôi: `OnTick` vốn không chạy chồng (re-entrant) nên cờ này tác dụng hạn chế.

**Deviation không có tác dụng với khớp theo thị trường:** danh sách trường bắt buộc không có `price` và `deviation` — https://www.mql5.com/en/docs/constants/structures/mqltraderequest; xem thêm https://www.mql5.com/en/forum/374269

**`OrderSendAsync`** chỉ điền `request_id`. Kết quả phải theo dõi trong `OnTradeTransaction` — https://www.mql5.com/en/book/automation/experts/experts_ontradetransaction

## 6. Mô phỏng trượt giá khi kiểm thử (backtest)

**Trễ của Tester** — https://www.metatrader5.com/en/terminal/help/algotrading/testing (tài liệu chính thức)

- Trễ ngẫu nhiên: chọn 0–9 giây; nếu ra 9 thì cộng thêm một số 0–9 nữa. Kết quả 90% trường hợp trễ 0–8 giây, 10% trễ 9–18 giây.
- Trễ **chỉ áp dụng cho thao tác do EA gửi**, không áp dụng khi lệnh chờ, SL hay TP khớp trên server.

**Custom symbol để kiểm thử căng thẳng (stress test)** (bài 22391, MetaQuotes, 21/05/2026) — https://www.mql5.com/en/articles/22391 [trích đoạn]

- `ticks[i].ask = ticks[i].bid + StressSpreadPoints·point`, mặc định 50 point.
- Quy trình: `CopyTicksRange` → sửa tick → `CustomTicksReplace` theo từng lô ngày.
- Ngoài ra đặt `SYMBOL_TRADE_STOPS_LEVEL = 500` và nhân margin lên 2 lần.

**Thư viện của fxsaber:**

- **Virtual** (code 22577): stop và SL khớp ở "giá chấp nhận đầu tiên" (trượt bất lợi); limit và TP khớp đúng giá [mô tả] — https://www.mql5.com/en/code/22577
- **SlipPage** (code 16134): trừ phần trượt dương không thực tế của limit/TP trong chế độ real ticks [mô tả] — https://www.mql5.com/en/code/16134

**CBacktestRealism.mqh** **[đã đọc mã – trích xuất]** — https://github.com/francomascareloai/EA_SCALPER_XAUUSD/blob/main/MQL5/Include/EA_SCALPER/Backtest/CBacktestRealism.mqh

- Công thức: `slip = base·mult + base·mult·random_factor·(MathRand()/32767)`.
- Nếu không bật `adverse_only`: 50% trường hợp trả về trượt có lợi bằng `−0.3·slip`.
- Các bộ tham số (base / news / vol / random / adverse_only):

  | Chế độ | base | news | vol | random | adverse_only |
  |---|---|---|---|---|---|
  | NORMAL | 2 | 5 | 2 | 0.3 | không |
  | PESSIMISTIC | 5 | 10 | 3 | 0.5 | có |
  | EXTREME | 10 | 20 | 5 | 0.7 | có |

- Chỉ điều chỉnh lãi/lỗ ảo, không can thiệp vào lệnh thật trong Tester.

**Bài 23299** (23/07/2026) — https://www.mql5.com/en/articles/23299 [trích đoạn]

- `Net(m) = Σ[profit − m·(Fixed + CostPerLot·vol)]`, mặc định `CostPerLot = 12`.
- Chi phí hòa vốn mỗi deal = lợi nhuận ròng / số deal.

**Diễn đàn 395408:** nếu thời điểm gửi lệnh + độ trễ > thời điểm tick kế tiếp thì khớp theo giá tick mới [mô tả] — https://www.mql5.com/en/forum/395408/page56

---

## Hệ quả cho thiết kế EA (suy luận của tôi, không lấy từ nguồn)

1. **Xác nhận kiểu khớp lệnh.** Kiểm tra `SYMBOL_TRADE_EXEMODE == MARKET` và `_Digits` của XAUUSD trên Exness. Ví dụ của Exness dùng giá 1965.636 (3 chữ số) nên 1 USD có thể bằng 1000 point.
2. **Công thức đo trượt giá trong `DEAL_ADD`:**
   - Thoát do SL (`DEAL_REASON_SL`): `slip = DEAL_SL − DEAL_PRICE` với vị thế buy (đổi dấu với sell).
   - Vào lệnh đảo chiều bằng lệnh stop: `slip = DEAL_PRICE − ORDER_PRICE_OPEN` của `DEAL_ORDER` với buy.
   - Lưu theo point, USD và theo bội số của bước trailing.
3. **Rủi ro gap nhân đôi.** SL và lệnh stop ngược chiều nằm cùng một mức giá, nên khi gap thì trượt ở **cả hai chân**.
   - Có thể dùng stop-limit cho chân vào lệnh, nhưng phải tự viết phần xử lý khi lệnh limit không khớp: hủy sau T giây hoặc khi giá vượt X, rồi xét lại các bộ lọc.
4. **Tranh chấp khi trailing.** SL và lệnh chờ phải sửa bằng hai yêu cầu riêng. Nếu giá vượt qua SL ở giữa hai yêu cầu, lệnh stop sẽ bị từ chối (INVALID_PRICE, 10015). Cần một máy trạng thái (state machine) và phương án dự phòng. Nhớ tính cả freeze level (10029 FROZEN).
5. **Kiểm thử.** Chế độ trễ không mô phỏng được trượt giá cho SL và lệnh chờ trên server. Nên dùng custom symbol có gap/spread nới rộng, hoặc cộng thêm trượt giá sau khi chạy theo phân phối p50/p95 đo được trên tài khoản thật.

**Sources:**
- Bài viết và mã MQL5: [22998](https://www.mql5.com/en/articles/22998), [24251](https://www.mql5.com/en/articles/24251), [16169](https://www.mql5.com/en/articles/16169), [23315](https://www.mql5.com/en/articles/23315), [1683](https://www.mql5.com/en/articles/1683), [20371](https://www.mql5.com/en/articles/20371), [22391](https://www.mql5.com/en/articles/22391), [23299](https://www.mql5.com/en/articles/23299), [22691](https://www.mql5.com/en/articles/22691)
- MQL5 CodeBase: [77220](https://www.mql5.com/en/code/77220), [19149](https://www.mql5.com/en/code/19149), [13853](https://www.mql5.com/en/code/13853), [69096](https://www.mql5.com/en/code/69096), [74565](https://www.mql5.com/en/code/74565), [77391](https://www.mql5.com/en/code/77391), [43889](https://www.mql5.com/en/code/43889), [22577](https://www.mql5.com/en/code/22577), [16134](https://www.mql5.com/en/code/16134)
- GitHub: [EA_SCALPER_XAUUSD](https://github.com/francomascareloai/EA_SCALPER_XAUUSD), [gold-pro-scalper](https://github.com/n30dyn4m1c/gold-pro-scalper), [nyao_scalper_mt5](https://github.com/elrizwiraswara/nyao_scalper_mt5), [trillex-10s-ea](https://github.com/NadirAliOfficial/trillex-10s-ea)
- Tài liệu chính thức: [MT5 Tester](https://www.metatrader5.com/en/terminal/help/algotrading/testing), [Deal properties](https://www.mql5.com/en/docs/constants/tradingconstants/dealproperties), [Return codes](https://www.mql5.com/en/docs/constants/errorswarnings/enum_trade_return_codes), [MqlTradeRequest](https://www.mql5.com/en/docs/constants/structures/mqltraderequest)
- Exness: [Slippage rule](https://get.exness.help/hc/en-us/articles/18054855363484-Slippage-rule)
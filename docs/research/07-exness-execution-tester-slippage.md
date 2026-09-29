# Báo cáo nghiên cứu: trượt giá (slippage) của XAUUSD trên Exness MT5 và cách kiểm thử

Mức độ tin cậy được gắn nhãn cho từng nhận định như sau:
- **[CT]**: tài liệu chính thức của Exness hoặc MetaQuotes.
- **[ĐO]**: số liệu đo độc lập.
- **[GT]**: giai thoại, khiếu nại của một người.
- **[MK]**: marketing hoặc blog SEO, chưa kiểm chứng.
- **[SL-Suy luận]**: suy luận của tôi.

Trang Help Center của Exness không hiển thị ngày cập nhật. Tôi đọc chúng qua r.jina.ai vào ngày 27/09/2026.

---

## A. Cơ chế khớp lệnh (execution) vàng tại Exness

**1. Kiểu khớp lệnh theo loại tài khoản [CT]**
- Standard và Standard Cent dùng khớp lệnh thị trường (market execution), không có báo giá lại (requote). Nguồn: https://get.exness.help/hc/en-us/articles/17537782738460-Standard-account và https://get.exness.help/hc/en-us/articles/17537782786588-Standard-Cent-account (có XAUUSDc).
- Pro dùng khớp lệnh tức thì (instant execution) cho forex, hàng hóa và chỉ số, còn crypto dùng market execution.
  - Lệnh thị trường trên Pro có thể bị requote, cửa sổ requote là 3 giây.
  - "For pending orders in instant execution, there will not be a requote notification."
  - Nguồn: https://get.exness.help/hc/en-us/articles/17537794560540-Pro-account và https://get.exness.help/hc/en-us/articles/360011802860-Requotes
- Theo tài liệu MQL5, ở chế độ market execution thì trường `deviation` không nằm trong danh sách bắt buộc. Nghĩa là không thể giới hạn trượt giá của lệnh market bằng deviation. Nguồn: https://www.mql5.com/en/docs/constants/structures/mqltraderequest

**2. Quy tắc trượt giá (Slippage rule) hiện hành [CT]**
Nguồn: https://get.exness.help/hc/en-us/articles/18054855363484-Slippage-rule
- Quy tắc áp dụng cho lệnh chờ (pending order), bao gồm cả SL và TP.
- Cách hoạt động: nếu chênh lệch giữa giá thị trường lúc khớp và giá yêu cầu **nhỏ hơn** "vùng không trượt" (slippage-free range) thì lệnh khớp đúng giá yêu cầu. Nếu chênh lệch **bằng hoặc lớn hơn** vùng này thì lệnh khớp ở giá thị trường.
- XAUUSD: "0 - (3x spread)", tính theo "Spread used is at the time of order execution". XAGUSD, USOIL, USTEC, US30 và BTCUSD cũng là 3×.
- Áp dụng cho các tài khoản Standard Cent, Standard, Pro, Raw Spread và Zero.
  - Với Raw và Zero: "include the commission per lot per side into the calculation… along with spread". Trang không có ví dụ quy đổi cụ thể.
- **Hai câu quan trọng:**
  - "Slippage-free ranges are dynamic and can vary from the values specified based on market conditions and your trading activity."
  - "Any changes affect new and existing pending orders."
- **Hệ quả [SL-Suy luận]:** vùng 3× spread là một **ngưỡng**, không phải **mức trần**. Khi vượt ngưỡng, lệnh ăn toàn bộ trượt giá thị trường. Phân phối trượt giá vì thế có hai đỉnh: phần lớn lệnh trượt 0, một phần nhỏ trượt lớn. Exness cũng nói rõ vùng này có thể bị thu hẹp tùy "trading activity", mà EA đảo chiều liên tục thì có nguy cơ rơi vào diện đó.
- **Đơn vị "pip" không rõ ràng [SL-Suy luận]:** ví dụ của Exness gọi 1965.636 → 1965.626 là "10 pips", tức 1 pip = 0.001. Tuy vậy ca khiếu nại FPA ở mục B lại khớp với cách hiểu 1 pip = 0.01. Nên luôn tính trực tiếp theo giá: vùng = 3 × (Ask − Bid) tại thời điểm khớp. Với spread Standard khoảng 0.20–0.35 USD [MK], vùng này vào khoảng 0.6–1.05 USD. Con số này đáng kể so với bước trailing 1.5–3 USD của bạn.

**3. Lịch sử "5× spread": CHƯA XÁC MINH**
Tôi chỉ thấy "0 to 5x spread… 0 and 120 pips" trong đoạn trích của công cụ tìm kiếm (search snippet), có lẽ lấy từ bản cũ của trang https://get.exness.help/hc/en-us/articles/360011050319. Trang này hiện không còn nội dung đó. Tôi không truy cập được archive.org để xác nhận. Trang hiện hành ghi 3×.

**4. Gap, lệnh stop và SL [CT]**
Nguồn: https://get.exness.help/hc/en-us/articles/4418146279954-How-slippage-happens
- "Limit orders cannot result in negative slippage, and stop orders cannot result in positive slippage." Nghĩa là SL và lệnh stop chỉ có thể khớp đúng giá hoặc tệ hơn.
- Khi có gap, SL/TP có thể khớp vượt mức đặt, tùy vào vùng không trượt.

Lệnh chờ bị hủy do slippage rule, nguồn: https://get.exness.help/hc/en-us/articles/7766359507484-Why-was-my-pending-order-not-executed
- Lệnh stop bị hủy với lỗi "[SL Violated]" nếu sau khi khớp ở giá thị trường, TP rơi sai phía so với giá kích hoạt.
- Lệnh chờ cũng bị xóa nếu thiếu ký quỹ (margin).

Snippet từ trang commodities của exness.jo/.ke có nội dung "guarantee no slippage for virtually all pending orders that are executed at least three hours after trading opens" kèm các ngoại lệ (thanh khoản thấp, biến động cao). Tôi **không đọc được toàn văn**, nên chưa xác minh.

**5. Giờ giao dịch và nghỉ ngày [CT]**
- XAU: "Sunday 22:05 – Friday 20:58 (daily break 20:58-22:02)", "All timings are in server time (GMT+0)". Nguồn: https://www.exness.ke/commodities/ (qua jina).
- Trang này không ghi chú về giờ mùa hè/mùa đông (DST). Suy luận của tôi: khung này khớp với giờ nghỉ CME 17:00–18:00 ET trong mùa DST, nên có thể lùi 1 giờ vào mùa đông. Nên đọc trực tiếp bằng `SymbolInfoSessionTrade()`.
- Disclaimer của Exness: spread "may… widen… when markets open or close". Nguồn: https://www.exness.com/commodities/xauusd/
- Server Cent và Trial có thể bảo trì hằng ngày lúc 23:20 UTC. Thông tin này chỉ có trong snippet của trang "MetaTrader server optimization schedule", tôi không đọc được toàn văn.

**6. Chế độ "Only close" [CT]**
- Có thể bật khi biến động cao, trước giờ đóng cửa, hoặc trước khi hủy niêm yết (delist). Nguồn: https://get.exness.help/hc/en-us/articles/11449086534044--Only-Close-error
- **Rất quan trọng cho EA của bạn:** "During close-only periods, pending orders will not execute even if the market price is reached… automatically canceled". Nguồn: https://get.exness.help/hc/en-us/articles/4402645127186-What-can-close-my-orders-automatically
  - Nghĩa là SL vẫn đóng lệnh, nhưng lệnh STOP dùng để đảo chiều sẽ bị hủy, và EA sẽ ở trạng thái không có lệnh (flat).
- Các lỗi khác khi thị trường biến động:
  - "Price uncertainty" khi "High market volatility or news events". Nguồn: https://get.exness.help/hc/en-us/articles/8063279667868
  - "Off quotes" khi thanh khoản thấp. Nguồn: https://get.exness.help/hc/en-us/articles/360009143252

**7. Hàng đợi khớp lệnh (execution queue) và tốc độ**
- Theo snippet của trang "Closing orders" [CT, chưa đọc toàn văn]: Close-all được server xử lý "one by one separately and consecutively", nên mỗi lệnh có thể khớp ở giá khác nhau. Nguồn: https://get.exness.help/hc/en-us/articles/11541096471068-Closing-orders
- Về tốc độ, Exness chỉ nói "milliseconds", "nearly instantaneous" và "No guarantee of execution speed or precision". Nguồn: https://www.exness.com/order-execution/
- Con số "<25 ms" chỉ xuất hiện ở blog bên thứ ba, không có phương pháp đo [MK]. Nguồn: https://newyorkcityservers.com/blog/exness-review

**8. Thống kê chất lượng khớp lệnh của Exness [MK, tự công bố]**
- "99% of XAUUSD orders on Exness are executed without slippage".
- Dữ liệu là lệnh chờ trên tài khoản Standard, thu thập trong hai khoảng ngắn: 06–12/09/2024 và 24–29/01/2025, so với 3 broker khác.
- Nguồn: https://www.myfxbook.com/press-release/-99-slippage-free-advantage/36625 (thông cáo báo chí ngày 29/04/2025).
- Chú thích trên website thì ghi giai đoạn "September 2024 – July 2025" và so với 4 broker.
- **Nhận xét [SL-Suy luận]:** con số 99% gần như là hệ quả trực tiếp của quy tắc 3× spread. Phần 1% còn lại chính là nhóm trượt lớn.

---

## B. Bằng chứng về mức trượt giá thực tế

| Nguồn | Nội dung | Loại |
|---|---|---|
| GitHub qkt issue #1135 (13–14/09/2026), https://github.com/elitekaycy/qkt/issues/1135 | Server Exness-MT5Trial9 (**demo**, tài khoản chỉ tính spread), 0.01 lot XAUUSD/XAGUSD, 20 lần thoát bằng SL. So với replay khớp ở tick đầu tiên cắt qua SL: trung bình **−$0.187/oz**, trung vị −$0.055, p10 −$0.84, tệ nhất −$1.27. Độ trễ thoát SL trung vị **+264 ms**, TP 0 ms. Ví dụ: SELL, SL 4338.943, live khớp 4340.265 | [ĐO], mẫu nhỏ, demo |
| FPA (lệnh ngày 06/04/2026, XAUUSDm #232705399), https://www.forexpeacearmy.com/community/threads/exness-sc-ltd-breach-of-policy-415-pips-slippage-on-gold-order-232705399.89181/ | Trượt 415.8 pips, lỗ $20.43. Support nói "max allowed 126 pips". Tôi chỉ đọc được qua snippet | [GT] |
| WikiFX (07/2024) | Gold 0.3 lot, SL 2442, khiếu nại khớp tệ hơn quanh giờ ra tin 20:30; hòa giải $350 | [GT] |
| FXCM Slippage Statistics (01/01–30/11/2025), https://www.fxcm.com/markets/execution/slippage-statistics/ | 57.42% lệnh stop/stop-entry bị trượt âm, 74.58% lệnh limit được trượt dương. Số liệu gộp mọi sản phẩm, không riêng XAU | [CT broker khác] |
| goldpriceactiontrading (05/2026) | Spread Standard 20–35 "pips" (0.20–0.35 USD). Khi NFP, spread lên 80–120 pips trong 30–60 giây đầu | [MK], không có phương pháp đo |
| MQL5 forum 462908 (23/02/2024) | Tester MT5 trên XAUUSD M5: SL khoảng 160 pips nhưng khớp khoảng 1080 pips | [GT] |

Ghi chú về các con số trên [SL-Suy luận]:
- Ca FPA ở trên nhất quán với cách hiểu 1 pip = 0.01 USD: trượt khoảng 4.16 USD/oz trên khoảng 0.05 lot. "126 pips" ≈ 3 × spread 0.42. Như vậy người khiếu nại đã hiểu sai ngưỡng thành trần.
- Dữ liệu GitHub có điểm khó hiểu: trung vị live **tệ hơn** replay. Nếu vùng 3× spread được áp dụng đầy đủ thì các gap nhỏ lẽ ra phải khớp đúng giá SL, tức tốt hơn replay. Các khả năng: server demo, vùng không trượt bị thu hẹp, hoặc giá đã chạy quá 3× spread trong khoảng ~264 ms. Mẫu 20 lệnh chưa đủ để kết luận.
- Tôi **không tìm thấy** bộ dữ liệu độc lập, đáng tin nào đo trượt giá XAUUSD của Exness riêng trong lúc NFP, CPI hay FOMC. Mọi con số "news spike" hiện có đều từ blog SEO.

---

## C. MT5 Strategy Tester và trượt giá

**1. Chế độ "Every tick based on real ticks" [CT]**
- Dùng tick thật của broker, có spread biến động. Nguồn: https://www.metatrader5.com/en/terminal/help/algotrading/tick_generation
- Phút nào thiếu tick thì tester tự sinh tick. Tick lệch khỏi High/Low của nến M1 sẽ bị loại và thay bằng tick sinh ra. Nguồn: https://www.mql5.com/en/docs/runtime/testing
- "During testing, the spread is not modeled but is taken from historical data."

**2. Cách tester khớp SL, TP và lệnh chờ [CT]**
Nguồn: https://www.metatrader5.com/en/terminal/help/algotrading/testing_features
- Với symbol không phải sàn: lệnh được kích hoạt theo Bid/Ask và "Execution is performed by the current Bid and Ask market prices". Nghĩa là ở chế độ Every tick và Real ticks, **gap giữa hai tick có được phản ánh**.
- Ở "Open prices only" và "1 minute OHLC", lệnh khớp đúng giá đặt. Thay đổi này có từ build 1375, ngày 15/07/2016: https://www.metatrader5.com/en/releasenotes/terminal/1357
- Nhận định "tester lấy SL/TP đúng giá đặt" (Fernando Carreiro, 26/03/2022, https://www.mql5.com/en/forum/393096) thiên về MT4. Với MT5 ở chế độ tick, nhận định này không còn chính xác theo tài liệu.

**3. Độ trễ (execution delay) [CT]**
Nguồn: https://www.metatrader5.com/en/terminal/help/algotrading/testing
- Có ba chế độ: không trễ, trễ ngẫu nhiên và trễ cố định.
  - Trễ ngẫu nhiên có đơn vị là **giây**, 0–18 s (90% rơi vào 0–8 s). Mức này không thực tế cho EA chạy trên VPS, nên dùng trễ cố định tùy chỉnh theo ms.
- "A certain time delay is inserted between placing a trade request and its execution… the price can change."
- "Delays work only for trades performed by an EA (placing orders, changing stop levels, etc.)… if an EA uses pending orders, delays are only applied to order placing but not to order execution (in real conditions, execution occurs on the server without a network delay)."
- **Hệ quả:**
  - Lệnh market khớp ở giá sau khoảng trễ.
  - Việc sửa SL trailing và sửa lệnh chờ bị trễ, và điều này thực tế.
  - Việc kích hoạt SL hoặc lệnh STOP trên server **không bị trễ**, nên không mô phỏng được khoảng ~264 ms đo ở mục B.
  - Requote chỉ được mô phỏng ở chế độ instant execution.
  - Tester không mô phỏng slippage rule 3× spread, chế độ close-only hủy lệnh chờ, hay các lỗi off-quotes và price uncertainty [SL-Suy luận].
- Moderator MQL5 (16/08/2022) nói: "the only way to make the strategy tester give you slippage is by setting the execution delay…". Câu này đúng với trượt do độ trễ, nhưng bỏ sót trượt do gap tick. Nguồn: https://www.mql5.com/en/forum/430831

**4. Kiểm thử độ bền (robustness)**
- **Custom symbol với tick đã chỉnh sửa:**
  - Dùng `CustomTicksReplace` hoặc `CustomTicksAdd`, tick phải được sắp xếp tăng dần theo thời gian. Nguồn: https://www.mql5.com/en/docs/customsymbols/customticksreplace
  - Custom symbol dùng được trong Tester. Nguồn: https://www.metatrader5.com/en/terminal/help/trading_advanced/custom_instruments
  - MetaQuotes có bài (21/05/2026) về stress test bằng cách nới spread và chèn gap: https://www.mql5.com/en/articles/22391
  - fxsaber (12/2017) khuyên chỉ test custom symbol ở chế độ real ticks. Nguồn: https://www.mql5.com/en/forum/216050/page4
  - Lưu ý của fxsaber: lệnh limit trên custom symbol được "trượt dương" nên cho kết quả đẹp giả tạo ("graals"). Nguồn: https://www.mql5.com/en/forum/393733/page2174
- **Trừ phạt trượt giá theo từng lệnh:**
  - `TesterWithdrawal(double money)` mô phỏng việc rút tiền trong tester. Nguồn: https://www.mql5.com/en/docs/common/testerwithdrawal
  - Đề xuất [SL-Suy luận]: sau mỗi deal có reason SL hoặc lệnh STOP, lấy Bid hoặc Ask tại thời điểm t+Δ (Δ khoảng 250–300 ms). Nếu chênh lệch nhỏ hơn 3×spread thì phạt 0, ngược lại thì phạt bằng chênh lệch × khối lượng. Cách này mô phỏng kiểu khớp của Exness. Nên quét thêm các mức phạt cố định (0.1, 0.3, 0.5, 1.0 USD/oz) và độ trễ cố định (0, 50, 100, 250, 500 ms).
- **Ghi log lệnh thật:** MQL5 forum (25/08/2026) khuyên đo trung vị và p95/p99 của trượt giá thật để làm đầu vào cho kiểm thử. Nguồn: https://www.mql5.com/en/forum/430831
- **Lọc tin trong tester:** các hàm Calendar không trả dữ liệu quá khứ đáng tin trong tester, nên dùng file CSV tĩnh. Nguồn: https://www.mql5.com/en/articles/22231 (28/04/2026).

---

## D. SL và lệnh STOP đặt cùng một giá

**1. Phía giá kích hoạt [CT]**
Nguồn: https://www.metatrader5.com/en/terminal/help/trading/general_concept
- SL của lệnh buy được kiểm tra theo **Bid**. Sell Stop được định nghĩa là "sell at the 'Bid' price equal to or less than" giá đặt. Vì vậy cả hai kích hoạt trên cùng một tick.
- Tương tự, SL của lệnh sell kiểm tra theo Ask, và Buy Stop cũng theo Ask.
- Lưu ý: vị thế mới mở sẽ khớp ở phía Bid hoặc Ask đối diện, nên spread làm giảm khoảng cách SL ban đầu của vị thế mới.

**2. Khớp lệnh live**
- Hai lệnh là hai thao tác thị trường riêng biệt. Trên Exness, mỗi lệnh chịu slippage rule riêng [SL-Suy luận]:
  - Nếu gap nhỏ hơn 3× spread, cả hai khớp đúng cùng giá.
  - Nếu không, mỗi lệnh khớp theo giá thị trường tại thời điểm riêng của nó, và hai giá có thể khác nhau.
- Thứ tự xử lý **không được Exness hay MetaQuotes công bố**.
- Một broker (không phải Exness, tháng 05/2014) cho biết họ xử lý theo FIFO, SL được coi như một lệnh chờ, và "any modification… will make the order lost its original priority". Nguồn: https://www.mql5.com/en/forum/31201
  - Nếu cơ chế này cũng đúng ở Exness, thì lệnh nào được EA sửa sau cùng khi trailing sẽ xếp sau. Điều này **chưa được xác minh**.
- Alain Verleyen: "with MT5, there is no difference, on execution point of view, between a stoploss and a stop order."
- Nếu thao tác SL/TP bị từ chối, "the order will not be deleted. It will trigger again at the next tick" [CT].
- Sửa SL (`TRADE_ACTION_SLTP`) và sửa lệnh chờ (`TRADE_ACTION_MODIFY`) là hai request riêng, không nguyên tử (atomic). Vì vậy có một cửa sổ ngắn trong đó SL và lệnh STOP lệch giá nhau.

**3. Tài khoản hedging và netting [CT]**
- **Hedging:** lệnh STOP mở một vị thế riêng.
  - Nếu STOP khớp trước SL, bạn tạm thời có hai vị thế ngược chiều. Exness nói: "There is no margin held for fully hedged orders". Nguồn: https://get.exness.help/hc/en-us/articles/360014696320-Hedged-orders
  - Exness MT5 được cho là dùng hedging (tin năm 2018), nhưng hãy kiểm tra `ACCOUNT_MARGIN_MODE` trong code.
- **Netting:** lệnh ngược chiều cùng khối lượng chỉ đóng vị thế, không đảo chiều. Muốn đảo chiều cần gấp đôi khối lượng. Nếu cùng lúc có SL và lệnh STOP gấp đôi, có nguy cơ vào lệnh ngược gấp đôi. SL/TP của vị thế sẽ bị thay bằng SL/TP của lệnh mới nhất.
- **Các rủi ro riêng của Exness:**
  - Lệnh STOP bị hủy trong chế độ close-only.
  - Lệnh STOP gắn TP có thể bị hủy "[SL Violated]" khi có gap lớn.
  - Lệnh STOP bị xóa nếu thiếu margin.
- **Trong tester:** hai lệnh kích hoạt trên cùng tick và khớp ở cùng Bid của tick đó (chế độ tick). Thứ tự giữa chúng không được tài liệu hóa.

---

## E. Thực hành tốt để hạn chế thiệt hại do trượt giá

**1. Tránh tin tức (news blackout)**
- FTMO cấm "open or close any trades, including the execution of pending orders (such as Stop Loss or Take Profit)" trong khoảng **2 phút trước và sau** tin. XAUUSD được liệt kê là chịu ảnh hưởng của tin Mỹ. Nguồn: https://ftmo.com/en/faq/can-i-trade-news/
- FundedNext và The5ers dùng khung 5 phút, Funding Pips 3 phút (theo tóm tắt của bên thứ ba).
- Các bài MQL5 mặc định 5/5 phút. Nguồn: https://www.mql5.com/en/articles/21235 (18/02/2026).
- Blog SEO khuyên dừng EA 15–30 phút trước NFP, CPI, FOMC [MK].
- Các sự kiện cần lọc: NFP, CPI, FOMC (cả thông cáo lẫn họp báo), phát biểu của Chủ tịch Fed, PCE, PPI, Retail Sales, GDP, ISM, JOLTS.
- Nghiên cứu học thuật Elder, Miao & Ramchander (2012, J. Banking & Finance 36(1)) cho thấy biến động và khối lượng của hợp đồng tương lai vàng tăng theo tin vĩ mô.
- **Đề xuất [SL-Suy luận]:** vì SL và lệnh STOP nằm trên server nên không thể "tạm dừng" chúng. Khoảng T−5 đến T+10 phút (với FOMC thì đến hết họp báo), nên gỡ lệnh STOP đảo chiều và đóng băng trailing, hoặc đứng ngoài thị trường.

**2. Ngưỡng spread**
- Spread Standard điển hình khoảng 0.20–0.35 USD [MK].
- Đề xuất [SL-Suy luận]: chặn lệnh khi spread lớn hơn 2–2.5 lần trung vị spread theo từng giờ, đo từ tick Exness bằng `CopyTicksRange`. Lưu ý thêm là vùng không trượt tăng theo spread.

**3. Rollover và giờ nghỉ**
- Giờ nghỉ của XAU là 20:58–22:02 GMT+0 theo bảng hiện tại. Nên tránh khoảng 15–30 phút trước và sau.
- Nên gỡ lệnh STOP trước giờ nghỉ và trước khi thị trường đóng cửa cuối tuần (thứ Sáu 20:58), vì gap cuối tuần có thể vượt xa vùng 3× spread.

**4. Tính khối lượng lệnh (position sizing) [SL-Suy luận]**
- Công thức: lot = Rủi ro$ / (ContractSize × (khoảng SL + spread + đệm trượt giá)).
- Lấy `ContractSize` từ `SYMBOL_TRADE_CONTRACT_SIZE`. Với XAUUSDc, 1 cent lot = 0.01 lot chuẩn.
- Mức đệm ban đầu gợi ý: khoảng 0.5–1.0 USD/oz trong giờ thường (tham chiếu p10 = −0.84 ở mục B), và kịch bản đuôi 3–5 USD/oz (tham chiếu ca FPA khoảng 4.16).
- Sau đó thay bằng p95/p99 lấy từ log thật: ghi giá yêu cầu, giá khớp, spread và độ trễ trong `OnTradeTransaction`, lọc theo `DEAL_REASON_SL`.

---

**Những điểm còn chưa chắc chắn:**
- Mốc 5× có tồn tại trong quá khứ hay không.
- Nguyên văn đoạn cam kết "3 hours after trading opens".
- Giờ nghỉ của XAU có đổi theo mùa đông hay không.
- Thứ tự Exness xử lý SL và lệnh STOP cùng giá.
- Server Trial (demo) và Standard Cent có hành xử giống tài khoản real hay không.

Nên xác nhận trực tiếp các điểm này với Exness support và bằng log thật trên tài khoản nhỏ.
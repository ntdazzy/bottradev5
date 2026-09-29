Nghiên cứu xong. Mình đã đọc mã nguồn của 7 dự án mở và các bài viết MQL5 có kèm mã. Những dự án còn lại chỉ có mô tả. Vài trang (ForexFactory, traderviet, Exness Help Center, myfxbook) không mở được từ môi trường của mình, nên thông tin từ các trang đó chỉ lấy từ đoạn trích của kết quả tìm kiếm. Những chỗ như vậy đều được ghi "(đoạn trích)".

# Bot rải lưới BUY STOP/SELL STOP theo xu hướng, đảo chiều khi dính SL (XAUUSD, Exness): logic và thuật toán

## 0. Kết luận chính

1. **Bot này thuộc họ nào.** Mô tả của bạn khớp nhất với **lưới lệnh dừng theo xu hướng (stop-order breakout grid, còn gọi là "anti-grid")**: BUY STOP đặt trên giá, SELL STOP đặt dưới giá, và nhồi thêm lệnh khi giá chạy tiếp (pyramiding). Bot còn cộng thêm logic **đảo chiều khi dính SL (stop-and-reverse, SAR)**.
   - Lot của các lệnh SELL đã khớp trong ảnh (0.04 → 0.29 qua 11 bậc) tăng gần như **tuyến tính, khoảng +0.025 lot mỗi bậc**. Đây không phải kiểu nhân hệ số.
   - Thang BUY STOP phía trên lại bắt đầu ở lot đã lớn (0.27 → 0.41). Điều này gợi ý bot có thêm thành phần **"gỡ/hedge" bằng lot lớn ở phía ngược**, giống EA m-GRID/GRIDAW ở mục 1. Đây chỉ là suy luận từ mô tả ảnh, chưa kiểm chứng.
2. **Tỉ lệ "4 TP : 1 SL" không phải là lợi thế.** Nếu giá đi ngẫu nhiên (random walk), xác suất chạm TP trước SL chỉ phụ thuộc vào khoảng cách: P(TP) = SL/(TP+SL). Đặt SL = 4×TP thì tự nhiên thắng khoảng 80% mà kỳ vọng vẫn bằng 0 trước phí ([Gambler's ruin](https://en.wikipedia.org/wiki/Gambler%27s_ruin)).
   - Đảo chiều hay đổi khối lượng đều không đổi dấu kỳ vọng. Spread, trượt giá và commission luôn bị trừ thêm vào.
   - Bài MQL5 của Ilin kết luận các chiến lược chỉ thay đổi khối lượng lệnh là "doomed to fail without knowing the approximate movement direction" (E. Ilin, [MQL5 8390](https://www.mql5.com/en/articles/8390)).
   - Chen và cộng sự (2025) cũng chứng minh lưới truyền thống có kỳ vọng xấp xỉ 0 ([arXiv 2506.11921](https://arxiv.org/abs/2506.11921)).
   - Lợi thế, nếu có, chỉ đến từ việc giá thật sự có quán tính (momentum) ở đúng khung thời gian của lưới.
3. **Lot tăng dần là điểm yếu lớn nhất.** Lệnh lớn nhất luôn là lệnh mới nhất, tức vào ở giá xấu nhất. Vì vậy một cú hồi nhỏ đã xóa hết lãi nổi, và SL luôn "ăn" vào các lệnh to nhất trước (tính toán ở mục 4).
4. **Chi phí so với bước lưới trên vàng 2026 rất lớn.**
   - Giá vàng khoảng 4,285 USD ngày 26/9/2026, đỉnh 5,602 USD ngày 29/1/2026 ([TradingView](https://www.tradingview.com/symbols/XAUUSD/), đoạn trích).
   - Biên độ ngày trung bình (ADR) khoảng 30–45 USD ([fxnx](https://fxnx.com/en/blog/trading-xauusd-adr-how-master-gold-s-volatility-ceiling), đoạn trích).
   - Spread tài khoản Standard của Exness khoảng 0.20–0.35 USD/oz, lúc ra tin NFP lên 0.8–1.2 USD, lúc rollover trên 0.5 USD ([bài thứ ba](https://goldpriceactiontrading.com/2026/05/exness-gold-spread-2026.html)).
   - Như vậy bước lưới 0.5–1.0 USD chỉ bằng khoảng 1.5–5 lần spread thường, và **nhỏ hơn spread lúc ra tin**.
5. **Chưa có track record kiểm chứng.** Mình không tìm thấy kết quả nhiều năm đã được xác minh (myfxbook, MQL5 Signals) cho đúng họ bot này. Bằng chứng hiện có chỉ là backtest ngắn và quảng cáo. Nhiều bot lưới quảng bá trên TikTok gắn với động cơ hoa hồng IB tính theo khối lượng lệnh (mục 5).

---

## 1. Các dự án mã nguồn mở và thuật toán

Mỗi dự án đều ghi rõ nguồn: **[đã đọc mã]** nghĩa là mình đọc trực tiếp mã nguồn; **[mô tả]** nghĩa là chỉ dựa vào mô tả hoặc bài viết.

### 1A. Lưới lệnh dừng: nhóm gần với bot của bạn nhất

**(1) EA Stop Order (MT5, tác giả V. Karputov)**, https://www.mql5.com/en/code/20304, **[đã đọc mã]**
- **Đặt lưới:** chỉ khi không còn lệnh chờ nào. Bot đặt `InpMaxOrders` (mặc định 15) Buy Stop tại Ask + i×`InpDistance` (mặc định 100 point) và 15 Sell Stop tại Bid − i×`InpDistance`, với i = 1..15.
- **Lot:** bậc 1 dùng `InpLots` (0.1). Từ bậc 2 trở đi, lot = `InpLots`×(i−1)×`InpLotRatio` (mặc định 1.5). Kết quả là 0.10, 0.15, 0.30, 0.45, 0.60…, tức **tăng tuyến tính theo khoảng cách ở cả hai phía**. Một người dùng trên diễn đàn xác nhận: đặt ratio = 1.0 thì mỗi bậc cộng thêm 1 lot gốc ([forum](https://www.mql5.com/en/forum/251419)).
- **TP/SL:** mỗi lệnh có SL/TP riêng, tính từ giá đặt lệnh. Mặc định đặt 0, tức tắt.
- **Đóng rổ:** khi tổng profit + swap + commission ≥ `InpProfitClose` (mặc định 5) thì đóng hết, xóa lệnh chờ và bắt đầu chu kỳ mới.
- **Giới hạn:** không có dừng lỗ theo equity, không có logic đảo chiều.
- **Liên hệ với ảnh:** "lot lớn dần theo khoảng cách ở cả thang BUY STOP lẫn SELL STOP" trông giống ảnh bạn gửi.

**(2) m-GRID EA (MT4)**, https://github.com/bailzx5522/mql_divergence/blob/master/m-GRID%20EA.mq4, **[đã đọc các dòng mã chính]**. Biến thể GRIDAW có cùng bộ tham số: http://egia4.blogspot.com/2014/07/gridaw.html **[mô tả]**
- **Đầu chu kỳ:** giá gốc = Ask. Hai biên của "hộp" là giá gốc ± (LEVELS+1)×INCREMENT. Bot đặt 3 Buy Stop phía trên và 3 Sell Stop phía dưới, mỗi bậc cách nhau 35 point, lot 0.1.
- **TP/SL:** mọi Buy Stop có TP ở biên trên và SL ở biên dưới; Sell Stop thì ngược lại. Tức TP/SL là **chung, nằm ở hai biên hộp**.
- **Khi đang có lệnh:** bot tính lãi dự kiến nếu giá chạm từng biên. Phía nào lãi dự kiến chưa đạt mục tiêu thì bot **đặt thêm lệnh dừng ở phía đó với lot = số thứ tự bậc × LOTS** (bậc càng xa, lot càng lớn), cho đến khi lãi dự kiến tại biên đó đủ mục tiêu. Kết quả: phía ngược với các lệnh đang lỗ luôn có lot lớn hơn để gỡ.
- **GRIDAW** mô tả tương tự: ở mức Buy thì phía trên dùng lot gốc, còn 3 mức Sell dùng lot gấp đôi. Bản sau thêm quy tắc đóng hết khi lỗ khoảng 25% tài khoản.
- **Kết thúc:** ngay khi một lệnh của phiên đóng (giá chạm biên), bot đóng tất cả. Nếu tham số CONTINUE bật, bot mở phiên mới.
- **Các kiểm tra:** INCREMENT ≥ stoplevel + spread; margin trống ≥ 100×LOTS; MAX_LOTS = 99.

**(3) NC_Grid_EA (MT4)**, https://github.com/kolier/NC_Grid_EA/blob/master/NC_Grid_EA.mq4, **[đã đọc mã]**
- **Mức giá:** tính theo phần trăm quanh đường EMA(14): mức thứ k = MA×(1 + 0.25%×k).
- **Vào lệnh:** khi nến vừa đóng cắt qua một mức (có thể chờ xác nhận ở nến mới). Lệnh đầu vào bằng market, các bậc sau là Buy Stop (hoặc Sell Stop). Lot mỗi bậc lấy từ mảng `Level_Lots_Buy` = "1,0,1.5,0,2,3,3,4,5,6,6,7", trong đó số 0 nghĩa là bỏ qua bậc đó.
- **TP/SL tính cho cả nhóm lệnh:** TP khi giá đi thêm 2 mức, SL khi giá lùi 2 mức. Có hòa vốn theo mức. Có thoát khi giá cắt ngược lại sau ít nhất 2 lệnh.
- **Đảo chiều có "gỡ":** mỗi lần thua, bộ đếm thua liên tiếp tăng 1. Nhóm lệnh tiếp theo được **cộng thêm lot** từ mảng `Level_CLS_Lots`. Bộ đếm reset khi có lần chốt TP. Đây là kiểu martingale cộng.
- **Bộ lọc:** ngày trong tuần, khung giờ giao dịch, volume tick, không cho mở hai chiều cùng lúc, tối đa 20 mức, quản lý vốn 5% cho mỗi 100 pip.

**(4) BGC Grid EA, chế độ TGT (bài MQL5 21833, năm 2026)**, https://www.mql5.com/en/articles/21833, **[mã kèm bài]**
- **Đặt lưới:** chỉ đặt lệnh dừng theo hướng xu hướng, tại anchor + k×spacing. Không vào lệnh ngay tại anchor.
- **Spacing:** ATR(D1)×0.12, có kẹp giá trị min/max.
- **Lot:** equity của chu kỳ × tỉ lệ `InpLotFraction`.
- **Không có TP từng lệnh.** Cả rổ thoát khi: lãi đạt 3%, drawdown chu kỳ vượt 25% (kill switch), chu kỳ kéo dài quá 72 giờ, hoặc đến cuối tuần (đóng hết để tránh gap).
- **Nhận diện xu hướng:** tỉ số σ/μ < 5 hoặc CUSUM báo có điểm gãy. Nếu không có tín hiệu, bot tạm nghỉ theo thời gian cooldown.
- **Backtest XAUUSD M1 (3/2–19/3/2026):** lưới 8 mức cho PF 2.20, DD 4.13%, 119 lệnh. Nhưng lưới 5 mức cho −1,223 pip, chỉ vì kill switch bị kích ở DD 25.1% so với ngưỡng 25.0%. Kết quả rất nhạy với tham số và mẫu chỉ khoảng 6 tuần.

**(5) Lưới theo vùng giá, đặt thuận xu hướng (bài MQL5 6954)**, https://www.mql5.com/en/articles/6954, **[mô tả]**
- **Đặt lưới:** Buy Stop trên giá, Sell Stop dưới giá, đặt tại các mức giá tròn.
- **Lot:** cố định. Tác giả đã thử tăng lot theo chuỗi và thấy chỉ làm tăng drawdown.
- **TP/SL:** TP mỗi lệnh bằng N bước lưới. Tác giả thử dùng SL, thấy kém nên tắt.
- **Giới hạn:** tối đa 33 lệnh tại cùng một giá; đóng hết khi equity tăng đủ mức.
- **Kết quả 2015–2019:** tốt nhất là AUDCAD với hệ số phục hồi (RF) 3.73. Các cặp khác đều RF < 4. Tác giả tự nhận kết quả dễ gây ảo tưởng vì dựa vào vùng giá trong quá khứ.

**(6) Lưới lệnh dừng trên sàn MOEX (bài MQL5 10671)**, https://www.mql5.com/en/articles/10671, **[mô tả]**
- **Đặt lưới:** Buy Stop phía trên một mức chọn trước, Sell Stop phía dưới. TP có thể nhỏ hơn bước lưới (ví dụ TP 100 point, bước 184 point).
- **Tái lập sau TP:** nếu giá đang cao hơn mức vừa chốt thì đặt lại Sell Stop tại mức đó; nếu thấp hơn thì đặt lại Buy Stop.
- **Cảnh báo của tác giả:** khi thị trường đi ngang trong kênh rộng, giá có thể kích hoạt 5–6 lệnh dừng ở mỗi phía và phải mất rất lâu mới thoát được drawdown.

**(7) Pending order grid (MT4, CodeBase 17984)**, https://www.mql5.com/en/code/17984, **[mô tả]**
- Buy Stop và Sell Stop đặt cách giá một khoảng, có tham số tăng lot theo phần trăm, có TP/SL/trailing.
- Tác giả ghi chú phải reset thủ công định kỳ. Người dùng nhận xét: sau khi giá chạy một chiều, lưới để lại khoảng trống nên không tận dụng được cú đảo chiều ([forum](https://www.mql5.com/en/forum/188847)).

**(8) Anti-grid / "Snowball" của 7bit (Bernd Kreuss)**, **[mô tả]**. Repo GitHub của bản sửa (amaldini/Snowball2) hiện báo 404 nên mình không đọc được mã.
- **Định nghĩa anti-grid:** Buy Stop phía trên, Sell Stop phía dưới ([SnowRoller](https://sites.google.com/site/marketformula/snowroller)).
- **Cách Snowball quản lý lệnh** (đoạn trích từ [FF 239717](https://www.forexfactory.com/thread/239717-trading-the-anti-grid-with-the-snowball-ea)): khi bậc sau khớp thì dời SL của bậc trước về hòa vốn; TP tự động ở 2 mức trên điểm hòa vốn; có tạm dừng/tiếp tục; khuyên chỉ chạy một "snowball" mỗi lúc.
- **Toán học** ([MQL5 forum 126410](https://www.mql5.com/en/forum/126410/page2)): lãi của anti-grid tăng theo n(n+1)/2 với n là số mức giá đi được. Lỗ của nó tăng tuyến tính theo thời gian khi giá đi ngang. Chính 7bit thừa nhận không vượt qua được chi phí spread.

**(9) Lưới hedge dạng sách giáo khoa (forexop)**, https://forexop.com/basic-hedged-grid-strategy/, **[mô tả]**
- 4 Buy Stop phía trên và 4 Sell Stop phía dưới, mỗi bậc 15 pip, TP 15 pip, không có SL.
- Trường hợp tốt nhất lãi +90 pip. Trường hợp xấu nhất lỗ −316 pip, đã tính spread.
- Khuyên hủy lệnh chờ đối diện khi một mức đã bị "ăn". Cảnh báo slippage có thể làm mất trạng thái hedge.

### 1B. Đảo chiều, hedge và "zone recovery"

- **Simple Hedge EA (bài MQL5 13845)**, https://www.mql5.com/en/articles/13845, **[mã trong bài]**
  - Có 4 mức giá A > B > C > D. Buy tại B (TP ở A, SL ở C), Sell tại C (TP ở D, SL ở B).
  - Mỗi lần đảo chiều, lot nhân với hệ số (mặc định 2.0). Chu kỳ kết thúc khi giá chạm A hoặc D.
  - Tác giả tính rằng tài khoản 10.000 USD chỉ chịu được khoảng 11–12 lần đảo liên tiếp là hết margin; backtest đã suýt chạm lệnh thứ 11.
  - Phần III ([13972](https://www.mql5.com/en/articles/13972)) chỉ ra chi phí spread tăng rất mạnh theo số lệnh.
- **Zone recovery nhiều tầng (bài MQL5 17001)**, https://www.mql5.com/en/articles/17001, **[mã trong bài]**
  - Vào lệnh theo RSI 30/70. Zone rộng 200 point, target 400 point.
  - Giá xuyên biên zone thì mở lệnh ngược với lot × 2.0. Đóng tất cả khi chạm target. Tối đa 11 vị thế.
  - Công thức tổng quát (do mình tự suy ra): lệnh đảo thứ 2 cần lot ≥ L1×(Z+T)/T để về hòa.
- **Zone Recovery Hedge EA (CodeBase 35784)**, https://www.mql5.com/en/code/35784, **[mô tả]**: người dùng bình luận EA cháy tài khoản khi thị trường đi ngang.
- **PZ Stop And Reverse (sản phẩm thương mại)**, https://www.mql5.com/en/blogs/post/729068, **[mô tả]**
  - Khoảng cách đảo chiều khuyên đặt ≥ 30–50 lần spread. Lot tăng dần. Giới hạn số lệnh bằng tham số "Amount of trades".
  - Nếu dùng hết kế hoạch mà chưa có lãi, EA dừng và chấp nhận mức lỗ đã định sẵn.
- **Stop and reverse advanced EA**, https://www.mql5.com/en/market/product/162632, **[mô tả]**
  - Lot tăng ×1.5 sau thua. Sau 10 lần thua thì dùng hệ số mạnh hơn.
  - Sau chuỗi thua chỉ đòi thoát hòa (+1 USD). Có lọc biến động nến M30 và khung giờ giao dịch.
- **Opposite trade (CodeBase 18904)**, https://www.mql5.com/en/code/18904: cứ vị thế nào đóng thì mở ngay vị thế ngược, cùng khối lượng. Đây là SAR thuần.
- **SAR kiểu martingale** ([forum 23397](https://www.mql5.com/en/forum/23397)): BUY 0.1 dính SL → SELL 0.2 dính SL → BUY 0.4 dính SL → SELL 0.8 chốt TP → quay lại lot 0.1.

### 1C. Nhồi lệnh thuận xu hướng (pyramiding)

- **CPyramidEngine (bài MQL5 22187)**, https://www.mql5.com/en/articles/22187, **[mã trong bài]**
  - Nhồi thêm ở +50 và +100 pip. Lot **bắt buộc giảm dần** (0.30 / 0.20 / 0.10).
  - SL chung dời dần từ 120 → 25 → 10 pip. Nhờ vậy rủi ro tổng chuyển từ −360 USD sang +25 USD rồi +340 USD.
- **Quy tắc Turtle**, https://www.theturtletrader.com/turtle-trading-rules/
  - Một "unit" có kích thước sao cho 1N (ATR) tương đương 1% tài khoản.
  - Thêm 1 unit mỗi khi giá đi thuận ½N, tối đa 4 unit. SL đặt 2N và được dời lên khi thêm unit.
  - Hệ thống 1 bỏ qua tín hiệu nếu lần breakout trước đó thắng.
- **Anti-martingale (forexop)**, https://forexop.com/anti-martingale-trading-system/
  - Nhân đôi lot mỗi 20 pip. Chỉ một lệnh thua là xóa lãi của cả chuỗi.
  - Theo bảng thử nghiệm của forexop: khi đi ngang −6.98 pip/lot, khi có xu hướng +3.71 pip/lot.

### 1D. Nhóm đối chứng: lưới ngược xu hướng

- **Orchard Forex "Stop Loss Grid"**, https://github.com/OrchardForexTutorials/220403_stop_loss_grid, **[đã đọc mã]**
  - Mở 1 Buy và 1 Sell. Mỗi lần giá đi thêm 1 mức: đóng Buy (lãi), rồi mở một Buy mới và một Sell mới. Nếu giá hồi 1 mức thì đóng tất cả. Đến mức thứ 4 thì đóng hết và tự gỡ EA.
  - Mình tính thử (bỏ qua spread): nếu giá hồi sau n mức thì kết quả = n(3−n)/2 lot×bước. Lãi ở n = 1–2, hòa ở n = 3, lỗ −6 ở n = 4. Tức là **cược giá hồi**, ngược hẳn với bot của bạn.
  - Trạng thái chỉ lưu trong biến, nên khởi động lại là mất (tác giả tự ghi chú trong mã).
- **grid-scalper-ea**, https://github.com/shahmeetk/grid-scalper-ea/blob/main/grid-scalper.mql5, **[đã đọc mã]**
  - Lệnh market ngược chiều, lot theo chuỗi 0.01 → 0.25, bước 400 point và nới thêm 200 sau 3 lệnh.
  - Có lọc RSI/MA, có cooldown sau khi đóng rổ, đóng hết khi drawdown vượt ngưỡng.

---

## 2. Các họ thiết kế lưới và hành vi trong từng kiểu thị trường

| Họ | Có xu hướng (trend) | Đi ngang (range) | Tin mạnh / gap |
|---|---|---|---|
| (a) Lưới ngược xu hướng (mean-reversion limit grid) | Lỗ tăng theo n(n+1)/2, tức bậc hai, và dẫn tới cháy tài khoản ([21833](https://www.mql5.com/en/articles/21833), [126410](https://www.mql5.com/en/forum/126410/page2)) | Lãi đều | Gom nhiều lệnh sai chiều, cạn margin |
| (b) Lưới lệnh dừng / anti-grid | Lãi tăng nhanh | Lỗ tuyến tính theo thời gian; kênh rộng kích 5–6 lệnh mỗi phía ([10671](https://www.mql5.com/en/articles/10671)) | Khớp nhiều mức cùng lúc với trượt giá; SL cũng trượt |
| (c) Lưới hai chiều / hedge | Lãi một phía, phía kia "khóa lỗ" | Các cặp khóa lỗ tích tụ, ví dụ −316 pip ([forexop](https://forexop.com/basic-hedged-grid-strategy/)) | Trượt giá làm mất hedge |
| (d) Zone recovery / đảo chiều khi SL | Thường thắng nhanh | Đảo liên tục, lot tăng theo hàm mũ, hết margin ([13845](https://www.mql5.com/en/articles/13845)) | Gap vượt qua cả zone |
| (e) Pyramiding | Lot tăng dần: lãi lớn nhất | Lot tăng: một lệnh thua xóa hết lãi ([forexop](https://forexop.com/anti-martingale-trading-system/)); lot giảm: rủi ro giảm dần ([22187](https://www.mql5.com/en/articles/22187)) | Lệnh lớn nhất bị trượt SL |

**Họ nào khớp với bot của bạn:** kết hợp (b) + (e, lot tăng tuyến tính) + (d) (đảo chiều khi SL), và có thể thêm (c). Ảnh của bạn có thể được giải thích bằng 3 giả thuyết. Bạn có thể tự phân biệt bằng cách quan sát bot đang chạy:
- **(i) Hai thang lệnh chung một điểm gốc, lot tăng theo khoảng cách tới điểm gốc** (kiểu EA Stop Order). Cách nhận biết: có một mức giá gốc chung, và bot đóng cả rổ khi đạt mục tiêu tiền.
- **(ii) Thang lệnh phía ngược có lot lớn để "gỡ"** (kiểu m-GRID/GRIDAW). Cách nhận biết: các BUY STOP nằm đúng các bậc lưới, và nếu giá quay lên tới biên trên thì tổng lãi/lỗ dự kiến của cả rổ ≥ 0.
- **(iii) Mỗi lệnh có sẵn một lệnh đảo chiều đặt tại đúng giá SL của nó** (SAR). Cách nhận biết: giá các BUY STOP trùng với SL của các SELL đang mở.

Sau đó xem thêm: sau khi dính SL, lệnh ngược chiều đầu tiên có lot **về lại 0.04** hay **tiếp tục lot lớn**? Nếu tiếp tục lot lớn thì bot mang tính martingale.

**Các kiểu hỏng thường gặp và cách EA thật xử lý:**
- **Giá răng cưa (whipsaw) khi đi ngang.** Cách xử lý:
  - Lọc chế độ thị trường: σ/μ, CUSUM ([21833](https://www.mql5.com/en/articles/21833)); ADX ≥ 25 ([blog](https://www.mql5.com/en/blogs/post/767009), nguồn này không đưa số liệu chứng minh).
  - Bỏ qua tín hiệu kiểu Turtle; chờ xác nhận ở nến mới cộng lọc volume (NC_Grid).
  - Đặt zone/SL đủ rộng so với spread: PZ khuyên ≥ 30–50 lần spread.
- **Tin mạnh, spread giãn, gap cuối tuần.** Cách xử lý:
  - Lọc tin và phiên giao dịch ([GridTrailling](https://www.mql5.com/en/market/product/178132)).
  - Đóng hết trước cuối tuần (BGC). Đặt thời hạn hết hiệu lực cho lệnh chờ.
  - Không gửi lệnh khi spread quá rộng. Tránh giờ rollover ([bài spread](https://goldpriceactiontrading.com/2026/05/exness-gold-spread-2026.html)).
- **Cháy tài khoản (stop-out).** Cách xử lý:
  - Kill switch theo equity: BGC cắt ở 25%, GRIDAW cắt ở 25%.
  - Giới hạn số mức và tổng lot (MAX_LOTS); kiểm tra margin trước khi vào lệnh (m-GRID, Stop and reverse advanced); giới hạn tuổi chu kỳ (BGC 72 giờ).
  - Riêng Exness Standard Cent: mức margin call 60%, **stop-out 0%**; MT5 cho tối đa 200 lệnh chờ ([Exness Help](https://get.exness.help/hc/en-us/articles/360014693340-Margin-call-and-stop-out-levels-by-account-type), đoạn trích).
- **Sàn hạn chế giao dịch.** Exness có thể chuyển mã sang chế độ chỉ cho đóng lệnh khi biến động mạnh ([Exness Help](https://get.exness.help/hc/en-us/articles/11449086534044--Only-Close-error), đoạn trích).
  - Có một bài trên X nói Exness tắt giao dịch XAUUSD trong cú tăng vọt tháng 1/2026 ([X](https://x.com/mukasareef8/status/2016908747302461931)). Đây là mạng xã hội, chưa kiểm chứng.

**Chống trượt giá khi giá chạy nhanh:**
- **Tham số deviation vô tác dụng với khớp lệnh kiểu Market Execution** ([forum 243417](https://www.mql5.com/en/forum/243417), [forum 374269](https://www.mql5.com/en/forum/374269)).
- **Nên dùng Buy Stop Limit / Sell Stop Limit của MT5** để giới hạn giá khớp tối đa, đổi lại có thể bị lỡ lệnh ([MQL5 docs](https://www.mql5.com/en/docs/constants/tradingconstants/orderproperties)). Exness MT5 có hỗ trợ loại lệnh này ([Exness Help](https://get.exness.help/hc/en-us/articles/360017885880-Available-order-and-execution-types), đoạn trích).
- **Tính lại SL/TP theo giá khớp thực tế** trong `OnTradeTransaction`, không dùng giá đặt lệnh.
- **Quy tắc slippage của Exness:** với XAUUSD, lệnh chờ trượt trong khoảng 0–3 lần spread vẫn được khớp đúng giá đặt; khoảng này thay đổi theo tình hình ([Exness Help](https://get.exness.help/hc/en-us/articles/18054855363484-Slippage-rule), đoạn trích).

---

## 3. "Đảo chiều khi dính SL" trong các EA đã biết

**Các dạng thường gặp:**
- **SAR thuần:** Opposite trade (18904).
- **SAR kèm tăng lot:** forum 23397, PZ, Stop and reverse advanced.
- **Zone recovery:** 17001, 13845, 35784.
- **Đảo chiều theo cấu trúc hoặc chỉ báo:** NC_Grid đảo khi giá cắt mức EMA theo chiều ngược; BGC đổi chế độ khi σ/μ hoặc CUSUM báo.
- **Đảo chiều bằng thang lệnh chờ sẵn ở phía ngược:** EA Stop Order, m-GRID.

**Cách cài đặt trong MT5:**
- **Đặt sẵn lệnh dừng ngược chiều tại đúng giá SL.** Trên tài khoản netting thì lệnh này cần gấp đôi khối lượng để lật vị thế. Cách này không bị trễ nhưng vẫn có trượt giá.
- **Hoặc bắt sự kiện SL** (`DEAL_REASON_SL` trong `OnTradeTransaction`) rồi mới mở lệnh ngược. Cách này trễ thêm một vòng gửi lệnh ([forum 341810](https://www.mql5.com/en/forum/341810/page2), đoạn trích).
- **Lưu ý:** đảo ngược một chiến lược không có lợi thế thì cũng không tạo ra lợi thế ([forum 268529](https://www.mql5.com/en/forum/268529/page2)).

**Các quy tắc chống đảo chiều liên tục, có trong EA thật:**
- Giới hạn số lần: PZ ("Amount of trades"), Orchard (dừng ở mức 4), zone recovery (tối đa 11 vị thế).
- Cooldown sau khi đóng: grid-scalper, BGC.
- Lọc chế độ thị trường hoặc xu hướng khung lớn: BGC, ADX, bộ lọc bỏ tín hiệu của Turtle.
- Lọc biến động: PZ, Stop and reverse advanced.
- Lọc phiên và ngày giao dịch: NC_Grid, Stop and reverse advanced.
- Sau chuỗi thua chỉ đòi thoát hòa: Stop and reverse advanced.

**Bộ quy tắc gợi ý cho bot của bạn** (đây là tổng hợp của mình, chưa kiểm chứng):
1. Chỉ bật lưới theo hướng xu hướng khung lớn (HTF).
2. Mỗi phiên tối đa F lần đảo chiều; vượt quá thì nghỉ T phút.
3. Sau khi đảo chiều, lot về lại mức gốc.
4. Đặt trần tổng lot và trần rủi ro nếu tất cả SL cùng dính.
5. Kill switch theo equity.
6. Gỡ hết lệnh chờ trước tin mạnh, giờ rollover và cuối tuần.
7. Không cho khớp lệnh khi spread vượt k lần mức bình thường.

---

## 4. Tăng lot và toán rủi ro

**Công thức tổng lot sau N bậc:**
- Lot cộng đều (w_k = L0 + kΔ): E_N = N·L0 + Δ·N(N−1)/2, tăng theo **bậc hai**.
- Lot nhân hệ số m: E_N = L0·(mᴺ−1)/(m−1), tăng theo **hàm mũ**.
- Ví dụ với L0 = 0.04 và 11 bậc: cộng đều cho 1.8 lot; nhân hệ số 1.5 cho khoảng 6.84 lot, và riêng lệnh cuối đã khoảng 2.31 lot.
- Theo equity: BGC, Turtle, NC_Grid tính lot theo phần trăm tài khoản.

**Áp vào ảnh của bạn** (giả định: bước lưới d; trên Exness cent, 1 lot XAUUSDc lỗ/lãi khoảng 100 USC ≈ 1 USD khi giá chạy 1 USD; nên kiểm tra lại contract size trong MT5):
- **Hiện tại:** 11 lệnh SELL tổng 1.80 lot. Giá vào trung bình (có trọng số theo lot) nằm ở khoảng bậc 6.55 trên 10.
- **Lãi nổi ở đáy:** khoảng 6.2 lot×bậc. Với d = 0.5–1.0 USD, tức khoảng 310–620 USC.
- **Chỉ cần giá hồi khoảng 3.5 bậc (1.7–3.5 USD) là mất hết lãi nổi.** Sau đó mỗi 1 USD giá chạy ngược lỗ thêm khoảng 180 USC.
- **Với lot cộng đều, độ hồi đủ xóa lãi xấp xỉ (N−2)/3 bậc.** Nếu lot bằng nhau thì con số này là (N−1)/2. Lot tăng làm giá vào trung bình dịch sát giá hiện tại, nên đệm an toàn mỏng đi.
- **Nếu các SELL STOP khớp tiếp tới lot 0.6:** khoảng 23 bậc, tổng khoảng 7.2 lot, tức khoảng 725 USC cho mỗi 1 USD giá chạy. Độ hồi đủ xóa lãi khoảng 7.5 bậc (3.8–7.5 USD), vẫn nhỏ so với ADR 30–45 USD.

**Chuỗi SL khi giá đảo chiều:**
- Với SL riêng cách s, lệnh bị dừng đầu tiên là lệnh mới nhất, tức lệnh lớn nhất. Tổng lỗ ≈ s × Σ(lot các lệnh bị dừng) + chi phí.
- Ví dụ minh họa (giả định TP = 1 bậc, SL = 2 bậc, d = 0.75 USD): hai lệnh 0.27 + 0.31 cùng dính SL mất khoảng 87 USC. Mỗi TP của lệnh 0.04 ban đầu chỉ lãi khoảng 3 USC. Vậy **một lần đảo hụt xóa khoảng 29 lần TP**.
- Chi phí spread 0.20–0.35 USD bằng 27–47% một TP 0.75 USD.

---

## 5. Bằng chứng về hiệu quả

- **Học thuật và toán học:**
  - Ilin: chỉ thay đổi khối lượng lệnh mà không biết hướng giá thì thất bại ([8390](https://www.mql5.com/en/articles/8390)).
  - Chen và cộng sự 2025: lưới truyền thống có kỳ vọng khoảng 0 ([arXiv](https://arxiv.org/abs/2506.11921)).
  - Taranto & Khan: lưới cho lãi ngắn hạn tốt hơn nhưng dài hạn gần như chắc chắn cháy ([JMSS 2021](https://thescipub.com/abstract/jmssp.2021.22.29); phần kết luận "cháy" là theo tóm tắt trong [bài 21833](https://www.mql5.com/en/articles/21833)).
  - 7bit và Gordon: anti-grid có kỳ vọng âm sau khi trừ spread ([126410](https://www.mql5.com/en/forum/126410/page2)).
  - Quán tính trong ngày của vàng (quỹ GLD) có tồn tại nhưng rất nhỏ: R² chỉ 0.49%, ở khung nửa giờ, không phải M1 ([Xu và cộng sự 2020](https://pmc.ncbi.nlm.nih.gov/articles/PMC7480318/)).
- **Backtest công khai:**
  - Bài 6954: 4 năm, RF < 4.
  - Bài 21833: 6 tuần, rất nhạy tham số.
  - Thread anti-grid trên MQL5 forum: backtest 2007–2010, DD khoảng 28% ([forum 135003](https://www.mql5.com/en/forum/135003)).
  - EA Grape/Frame: ổn khi đi ngang, bị stop-out khi có xu hướng ([forum 180268](https://www.mql5.com/en/forum/180268)).
- **Quảng cáo, chưa kiểm chứng:**
  - Số liệu backtest do người bán GridTrailling đưa ra.
  - "Lot Rebate Grid Hedging" nói thẳng mục tiêu là tạo khối lượng để lấy rebate ([link](https://www.mql5.com/en/market/product/102749)).
  - Bài case study về tài khoản cent chỉ có con số USC, không có myfxbook ([link](https://www.huongnghiepdulieu.com/case-study-tai-khoan-exness-vuot-sieu-bao-vang-212-bi-mat-tu-chien-thuat-full-hedge-cua-bot-9-2-pro/)).
  - Hoa hồng IB/backcom tính theo khối lượng lệnh; cùng trang này còn khuyên dùng "Bot Rải 1 Chiều" để giữ khách hàng giao dịch đều ([link](https://www.huongnghiepdulieu.com/backcom-khac-loi-nhuan-trade-opc-ib-bot/)).
- **Cách tự kiểm tra một track record** ([blog 772046](https://www.mql5.com/en/blogs/post/772046)):
  - Phải có ít nhất 100 lệnh và là tài khoản thật.
  - Không có reset tài khoản giữa chừng.
  - Xem drawdown theo equity, không chỉ theo balance.
  - Đường equity có những cú "hồi phục đột ngột" là dấu hiệu lưới/martingale bị giấu.
  - Khi backtest bot M1, chạy chế độ tick thật (real ticks) với spread thay đổi ([2612](https://www.mql5.com/en/articles/2612)).

**Kết luận:** chưa có track record dài hạn đã xác minh cho đúng họ bot này.

---

## 6. Mã hóa SNR / FVG / OB / MSNR để đặt lưới

- **MSNR (Malaysian SnR):**
  - A-level là đỉnh và V-level là đáy của biểu đồ đường (dùng giá đóng cửa).
  - Gap-level nằm ở khoảng giữa giá đóng và giá mở của hai nến cùng màu.
  - Mức "fresh" là mức chưa bị râu nến chạm; mức đã chạm lại thành fresh nếu bị thân nến cắt qua.
  - Có thể vẽ mức của khung lớn lên khung nhỏ ([MQL5 product 115614](https://www.mql5.com/en/market/product/115614)).
- **FVG:**
  - FVG tăng khi đáy nến 1 cao hơn đỉnh nến 3; FVG giảm thì ngược lại.
  - Chỉ nhận FVG có chiều cao ≥ True Range trung bình × hệ số.
  - FVG hết hiệu lực khi bị râu nến chạm, hoặc khi giá đóng cửa vượt qua (tùy chọn) ([23539](https://www.mql5.com/en/articles/23539)).
- **OB (order block):** 7 nến tích lũy có đỉnh/đáy lệch nhau ≤ 50 point, sau đó một nến đóng cửa phá vỡ vùng, rồi xác nhận có lực đẩy mạnh (impulse) sau 3 nến ([17135](https://www.mql5.com/en/articles/17135)).
- **Cách áp vào lưới** (đề xuất của mình):
  - Thay bước lưới cố định bằng các mức "fresh" nói trên.
  - Đặt lệnh chờ ngay sau mức, cách một đệm ≥ k lần spread.
  - Đặt SL phía sau mức vừa bị phá; đặt TP ở mức kế tiếp.
  - Gộp các mức gần nhau hơn khoảng cách tối thiểu (ví dụ 0.5×ATR M5).
  - Không đặt lệnh bên trong vùng ngược chiều của khung lớn.
  - Chưa có bằng chứng kiểm chứng rằng cách đặt này tạo ra kỳ vọng dương.

---

## 7. Những điểm chưa chắc chắn

- Việc diễn giải ảnh (cấp số cộng khoảng +0.025 lot/bậc, ba giả thuyết i/ii/iii) dựa trên mô tả bằng chữ, mình không xem ảnh gốc.
- Quy đổi 1 lot XAUUSDc ≈ 1 USD cho mỗi 1 USD giá chạy (tức 100 USC) chưa được kiểm tra trực tiếp.
- Mọi thông tin từ Exness Help Center, ForexFactory và fxnx chỉ lấy từ đoạn trích của kết quả tìm kiếm. Số liệu spread lấy từ một trang của bên thứ ba.
- Mô tả Snowball chỉ dựa trên đoạn trích; repo mã nguồn báo 404.
- Hai lần WebFetch tự lưu bản sao file vào thư mục tool-results của Claude, không nằm trong thư mục dự án: file .mq5 của EA Stop Order và file PDF quy tắc Turtle. Trong dự án không có file nào được tạo hay sửa, và không có gì được chạy.
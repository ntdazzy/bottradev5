# Nghiên cứu D: Hành vi trong ngày của vàng (XAUUSD) có bằng chứng

Ngày: 2026-09-29. Chỉ tra cứu web, không sửa gì trong repo.
Cách chấm bằng chứng:
- **proven_with_data**: bài bình duyệt hoặc backtest tái lập được, có phí và kiểm tra ngoài mẫu.
- **reported_numbers_unverified**: có số liệu nhưng tôi chưa kiểm lại được (bản thảo, blog, bài chưa bình duyệt).
- **claim_only**: chỉ là lời khẳng định, thường từ người bán khóa học/EA.

---

## 1. Kết luận ngắn

1. **Chưa có bằng chứng độc lập nào** cho một bot vàng M1/M5 có lời sau phí khi đánh theo cản, phá biên phiên Á, ORB hay "quét thanh khoản".
2. Những điều **có thật và đã được chứng minh** về vàng trong ngày chủ yếu là chuyện **khi nào giá chạy mạnh** (mở cửa London, 8:30 giờ New York khi có tin Mỹ, giờ chồng London–New York). Chúng giúp chọn giờ và né rủi ro, **không cho biết giá đi lên hay xuống**.
3. Các mẫu có hướng (số tròn, đà trong ngày, dò rỉ giá fix London) đều **rất nhỏ**, phần lớn **chưa trừ phí**, và có mẫu đã **biến mất** (giá fix London đổi cách làm từ 3/2015).
4. Tính phí của mình: spread 0,16 + trượt giá 0,3 × 2 chiều = **khoảng 0,76 USD mỗi lệnh khứ hồi**. ATR M5 khoảng 4,6 USD, nên nếu dừng lỗ khoảng 1 ATR(M5) thì **phí đã ăn khoảng 0,165R mỗi lệnh**. Kết quả đo được là -0,15R, **gần bằng đúng phần phí này**. Nghĩa là trước phí, lệnh vào tại vùng cản gần như hòa vốn: không có lợi thế, và phí làm cho lỗ.
5. Một tuần dữ liệu (05–12/01/2026) là **quá ngắn** để kết luận chắc. Nhưng kết quả đi đúng hướng với các nghiên cứu: lợi thế S/R có thật nhưng nhỏ hơn phí khi đánh khung nhỏ.

---

## 2. Các phát hiện chính (mạnh và liên quan nhất trước)

### 2.1 ORB (phá biên đầu phiên) trên hợp đồng tương lai không sống nổi sau phí
- Nghiên cứu đăng ký trước (pre-registered) của Mulham Fetna (SSRN, 2026) thử **225 biến thể ORB**: 9 thị trường tương lai Mỹ (chỉ số, **kim loại**, năng lượng), dữ liệu 1 phút 2010–2026, biên mở cửa 5/15/30/60 phút, 3 kiểu thoát lệnh.
- Với phí **25 USD mỗi lệnh khứ hồi**, **0/225 biến thể có lời**. 28 biến thể **lỗ có ý nghĩa thống kê**. Biên 5 phút, loại được quảng cáo nhiều nhất, lại **tệ nhất**.
- Biến thể tốt nhất **thua phép thử "mốc giờ ngẫu nhiên"**. Tức là nó chỉ ăn theo lúc biến động tăng, không có gì đặc biệt ở giờ mở cửa.
- Nếu hợp đồng thử là GC (100 oz) thì 25 USD tương đương khoảng 0,25 USD/oz. Phí của mình khoảng 0,76 USD/oz, **gấp khoảng 3 lần**. Bài không ghi rõ dùng GC hay MGC, và tôi không thấy kết quả riêng cho vàng.
- Bằng chứng: **reported_numbers_unverified**. Đây là bản thảo chưa bình duyệt, dù tác giả có mã công khai để tái lập.
- Nguồn: https://papers.ssrn.com/sol3/papers.cfm?abstract_id=7428398 ; https://github.com/mulhamfetna/trading-strategy-finder

### 2.2 Phí retail: phép tính của mình và số liệu ESMA
- Phí khứ hồi khoảng 0,76 USD, bằng khoảng 16,5% ATR(M5) tháng 1/2026 (4,6 USD). Với dừng lỗ 1 ATR(M5), mỗi lệnh phải thắng thêm khoảng 0,165R chỉ để hòa vốn. Các lợi thế đo được trong nghiên cứu (xem mục 2.5, 2.6) nhỏ hơn con số này rất nhiều.
- ESMA (2018): theo phân tích của các cơ quan quản lý EU, **74–89% tài khoản CFD retail bị lỗ**, lỗ trung bình từ 1.600 đến 29.000 EUR mỗi khách.
- Bằng chứng: phép tính là số học từ số liệu của dự án. Số ESMA là số liệu chính thức nhưng không tái lập được, nên xếp **reported_numbers_unverified**.
- Nguồn: https://www.esma.europa.eu/press-news/esma-news/esma-agrees-prohibit-binary-options-and-restrict-cfds-protect-retail-investors

### 2.3 Tin Mỹ (NFP, CPI, GDP...) làm vàng chạy mạnh và rất nhanh
- Elder, Miao & Ramchander (Journal of Banking & Finance, 2012), dữ liệu trong ngày 2002–2008: vàng, bạc, đồng phản ứng **nhanh và mạnh** với tin bất ngờ. Nhóm tin **8:30 sáng giờ New York**, nhất là **NFP** và đơn hàng lâu bền, có tác động lớn nhất. Tin kinh tế tốt hơn dự báo thì vàng thường giảm.
- Cai, Cheung & Wong (Journal of Futures Markets, 2001), vàng COMEX: trong 23 loại tin Mỹ, **báo cáo việc làm, GDP, CPI và thu nhập cá nhân** tác động mạnh nhất. Biến động của vàng có mẫu hình rõ theo giờ trong ngày.
- FXStreet (blog, 35 kỳ NFP): trong 15 phút sau khi NFP xấu hơn dự báo, vàng tăng trung bình 3,66 USD; khi NFP tốt hơn thì giảm trung bình 1,68 USD. Phản ứng yếu dần sau 4 giờ. **Không tính phí.**
- Ý nghĩa: đây là **sự kiện rủi ro**, không phải lợi thế. Giá phản ứng trong vài phút, spread giãn và trượt giá lớn. Bot nên **tránh hoặc đóng lệnh quanh tin**, không nên "bắt tin".
- Bằng chứng: **proven_with_data** cho việc vàng phản ứng mạnh với tin (có bình duyệt). Chưa có bằng chứng cho một chiến lược đánh tin có lời sau phí.
- Nguồn: https://www.sciencedirect.com/science/article/abs/pii/S0378426611001968 ; https://onlinelibrary.wiley.com/doi/10.1002/1096-9934(200103)21:3%3C257::AID-FUT4%3E3.0.CO;2-W ; https://www.fxstreet.com/analysis/us-february-nonfarm-payrolls-preview-analyzing-gold-price-reaction-to-nfp-surprises-202503061000

### 2.4 Phiên giao dịch: phiên Á nhiễu, giờ London–New York mang thông tin
- Sobti, Sehgal & Ilango (International Review of Financial Analysis, 2021), dữ liệu từng phút ở New York, London, Thượng Hải:
  - Hợp đồng tương lai New York dẫn giá với **56% "information share"**.
  - Giờ chồng **New York/London** đóng góp **51%** việc hình thành giá.
  - Tin xấu của Mỹ gây phản ứng mạnh hơn tin tốt.
- Iwatsubo, Watkins & Xu (2017): phiên Tokyo chủ yếu là **giao dịch không có thông tin** (thanh khoản). Phiên New York có nhiều **giao dịch có thông tin**.
- Ý nghĩa cho bot:
  - Phiên Á thường đi ngang, là "nhiễu", nên mẫu bật lại có thể hợp hơn, nhưng biên độ nhỏ nên phí chiếm tỷ lệ lớn.
  - Giờ London/New York là lúc giá đi theo thông tin, nên phá cản dễ xảy ra hơn.
  - Đây là **mô tả**, không phải chiến lược đã thử sau phí.
- Bằng chứng: **proven_with_data** cho phần mô tả, không có phí, không có chiến lược.
- Nguồn: https://ideas.repec.org/a/eee/finana/v78y2021ics1057521921002209.html ; https://ideas.repec.org/p/koe/wpaper/1722.html

### 2.5 Đà trong ngày (intraday momentum) của vàng: có nhưng rất nhỏ
- Quỹ vàng GLD, dữ liệu 1 phút 2004–2019 (bài bình duyệt trên PMC):
  - Lợi nhuận **nửa giờ thứ 5** dự báo được **nửa giờ cuối** phiên Mỹ: t = 3,03, **R² chỉ 0,49%**, ngoài mẫu R² 0,26%.
  - Mẫu mạnh hơn vào ngày biến động cao.
  - Bài **không trừ phí**.
- Vàng tương lai Trung Quốc (Ma, Bouri, Xu, Zhou; Global Finance Journal, 2025):
  - Có **cả đà lẫn đảo chiều** trong ngày.
  - Sau khi mở phiên đêm, nửa giờ đầu **phiên đêm** mới là thứ dự báo được.
  - Đảo chiều đến từ người giao dịch không có thông tin cung thanh khoản quá mức.
- Ý nghĩa: mỗi ngày chỉ có 1 tín hiệu, lợi thế nhỏ, và chưa ai chứng minh nó có lời sau phí CFD. Không áp thẳng cho XAUUSD chạy 24 giờ được.
- Bằng chứng: **proven_with_data** cho việc dự báo được (có ngoài mẫu), nhưng **không có phí**.
- Nguồn: https://pmc.ncbi.nlm.nih.gov/articles/PMC7480318/ ; https://ideas.repec.org/a/eee/glofin/v64y2025ics1044028325000110.html

### 2.6 Số tròn (cản tâm lý) ở vàng: có thật nhưng rất nhỏ
- Aggarwal & Lucey (Review of Financial Economics, 2007): có **cản tâm lý ở mức trăm** (ví dụ 2.600, 2.700). Mức này ảnh hưởng đến trung bình và biến động của giá quanh đó.
- Lucey & O'Connor (Finance Research Letters, 2016), giá fix London AM/PM 1975–2015 (20.452 quan sát):
  - Giá vàng **ít dừng ở số tận cùng 00 hơn** bình thường, chỉ khoảng **0,23% mỗi ô** quanh 00.
  - Phép thử lợi nhuận có điều kiện ủng hộ cản ở **mức chục** (số tận cùng 0), **không** ủng hộ ở mức trăm.
  - Phép thử "gù" không có ý nghĩa thống kê.
  - Bạc không có cản.
- Dữ liệu là giá fix 2 lần mỗi ngày, không phải giá từng tick, và **không thử chiến lược, không tính phí**.
- Ý nghĩa: số tròn là loại vùng cản có bằng chứng tốt nhất cho vàng. Nhưng hiệu ứng chỉ vài phần trăm của một phần trăm, nhỏ hơn nhiều so với phí 0,76 USD/lệnh.
- Bằng chứng: **proven_with_data** (có bình duyệt) cho hiện tượng thống kê; không có bằng chứng lợi nhuận sau phí.
- Nguồn: https://onlinelibrary.wiley.com/doi/10.1016/j.rfe.2006.04.001 ; https://ray.yorksj.ac.uk/id/eprint/1438/1/The%20Gap%20Psychological%20Barriers%20in%20Gold%20and%20Silver%20Prices.pdf

### 2.7 Giá fix London: từng có "rò rỉ", nay đã đổi luật
- Caminschi & Heaney (Journal of Futures Markets, 2014), vàng tương lai GC và quỹ GLD, phiên fix PM (15:00 London):
  - Khối lượng và biến động **tăng vọt ngay khi phiên fix bắt đầu**, trước khi công bố giá.
  - Có lợi thế lợi nhuận **trong 4 phút đầu**.
  - Các lệnh ở những phút đầu **dự báo đúng hướng giá fix, có lúc trên 90%**.
  - Sau khi công bố thì không còn gì.
  - Khối lượng 1 phút sau khi bắt đầu cao hơn khoảng 50% so với 20 phút trước đó.
- Từ **20/3/2015**, giá fix chuyển sang **đấu giá điện tử** do ICE quản lý, nhiều bên tham gia hơn và công khai từng vòng. Crain và cộng sự (2020) thấy việc đổi luật làm thay đổi biến động và giá.
- Ý nghĩa: lợi thế này thuộc chế độ cũ, cần tốc độ tính bằng phút và phí sàn tương lai. **Không nên xây bot dựa vào nó.** Giờ fix (10:30 và 15:00 London) vẫn là giờ có thanh khoản cao, chỉ nên dùng làm bộ lọc giờ.
- Bằng chứng: **proven_with_data** cho giai đoạn trước 2015; không còn áp dụng.
- Nguồn: https://onlinelibrary.wiley.com/doi/10.1002/fut.21636 ; https://www.news.uwa.edu.au/archive/201410067021/research/uwa-research-finds-gold-and-silver-price-setting-open-exploitation/ ; https://bearworks.missouristate.edu/articles-cob/566/

### 2.8 Thử nghiệm "đập bỏ" tín hiệu đà từ nến OHLCV (thị trường tương tự)
- Bản thảo arXiv 2026 trên hợp đồng MNQ, dữ liệu 5 phút 2021–2025, walk-forward:
  - Thử **14 họ tín hiệu** đà trong ngày từ OHLCV.
  - **0 họ qua được** tất cả tiêu chí sau phí.
  - 11 họ có lãi gộp chỉ 0,07–1,50 điểm, **thấp hơn phí 2 điểm**.
- Không phải vàng, nhưng cùng bài học: tín hiệu nến khung nhỏ thường có lãi gộp nhỏ hơn phí.
- Bằng chứng: **reported_numbers_unverified** (bản thảo).
- Nguồn: https://arxiv.org/abs/2605.04004

### 2.9 Phá biên phiên Á / quét thanh khoản trước London: chỉ có lời quảng cáo
- Các trang bán EA, khóa học và blog (pro-scalper, FXNX, Medium...) mô tả chiến lược phá biên phiên Á. Họ tự nói khoảng 30% cú phá lúc mở London sẽ quay đầu, nhưng **không có backtest công khai có phí và kiểm tra ngoài mẫu**.
- Bằng chứng: **claim_only**.
- Nguồn: https://www.pro-scalper.com/xauusd-strategies/asian-session-gold-strategy ; https://fxnx.com/en/blog/london-ny-overlap-goldmine-strategy-xau-usd ; https://medium.com/@fxmbrand/asian-session-gold-strategy-how-to-trade-xauusd-like-a-pro-before-london-opens-8614172d4e06

### 2.10 Cách "bot" có bằng chứng tốt nhất là theo xu hướng khung dài, không phải scalping
- AQR (Hurst, Ooi, Pedersen), "A Century of Evidence on Trend-Following Investing": theo xu hướng trên hợp đồng tương lai hàng hóa, tiền tệ, chỉ số, trái phiếu **có lời ổn định hơn 100 năm**, với tầm giữ lệnh từ tháng trở lên. Tôi chỉ đọc được trang tóm tắt, chưa kiểm lại số Sharpe hay phí trong bài gốc.
- Bản thảo arXiv "Forecast-to-Fill" trên vàng tương lai 2015–2025 báo Sharpe 2,88 và sụt giảm tối đa chỉ 0,52%. Chính trang tóm tắt ghi hai con số CAGR mâu thuẫn nhau (2,65% và 43%). Đây là **dấu hiệu cần nghi ngờ**; không nên tin khi chưa tái lập.
- Bằng chứng: AQR xếp **proven_with_data** (có bình duyệt), nhưng không phải vàng trong ngày. Forecast-to-Fill xếp **reported_numbers_unverified**.
- Nguồn: https://www.aqr.com/Insights/Research/Journal-Article/A-Century-of-Evidence-on-Trend-Following-Investing ; https://arxiv.org/abs/2511.08571

---

## 3. Vì sao đánh tay bằng cản thấy "được" mà code thì không?

Từ góc nhìn hành vi trong ngày của vàng:

1. **Người đánh tay lọc rất nhiều, code thì lấy hết.**
   - Code vẽ mọi pivot, gap, FVG, OB, số tròn, đỉnh/đáy ngày/tuần, nên vùng dày đặc (trung vị 19 vùng chồng nhau). Chạm "vùng" gần như là chạm ngẫu nhiên.
   - Người đánh tay chỉ chọn vài vùng, theo bối cảnh: khung lớn, giờ London/New York, có tin hay không.
   - Chưa ai viết phần "chọn lọc" đó thành luật.
2. **Giờ và tin quan trọng hơn vùng.**
   - Nghiên cứu cho thấy giá vàng chạy mạnh và "có thông tin" vào giờ London/New York và 8:30 New York.
   - Người đánh tay có thể vô thức chỉ vào lệnh ở những giờ này và tránh ngày tin lớn.
   - Code đang đánh cả ngày, kể cả phiên Á nhiễu.
3. **Lợi thế S/R nhỏ hơn phí ở khung M1/M5.**
   - Hiệu ứng số tròn chỉ vài phần nghìn. Phí 0,76 USD/lệnh bằng khoảng 0,165R nếu dừng lỗ 1 ATR(M5).
   - Kết quả -0,15R gần đúng bằng phần phí này, nghĩa là **trước phí gần như hòa vốn**.
4. **Trí nhớ đánh lừa.**
   - Không có nhật ký lệnh đầy đủ (mọi lệnh, cả lệnh bỏ qua) thì ta dễ nhớ lệnh thắng, quên lệnh thua.
   - Cách duy nhất để biết phương pháp tay có lời thật là **ghi 50–100 lệnh thật hoặc demo**, kèm ảnh chụp, giờ vào, dừng lỗ, chốt lời, lý do chọn vùng. Sau đó tính R trung bình sau phí.
5. **Mẫu 1 tuần quá ngắn.** Cần nhiều tháng và nhiều chế độ thị trường (đi ngang, xu hướng, tuần có tin lớn) trước khi kết luận chắc.

---

## 4. "Phương pháp bot nào tốt nhất hiện nay?" Trả lời thật

- **Không có** phương pháp bot vàng M1/M5 nào có bằng chứng độc lập là có lời sau phí retail. Ai bán EA "thắng 80%" mà không có backtest tái lập được, có phí và ngoài mẫu, thì coi là quảng cáo.
- Điều có bằng chứng mạnh nhất về hệ thống tự động nói chung là **theo xu hướng khung dài** (ngày, tuần, tháng) trên nhiều thị trường. Lợi nhuận vừa phải, có giai đoạn sụt giảm dài, và không phải scalping.
- Với vàng trong ngày, những gì dùng được là **bộ lọc**, không phải "máy in tiền":
  - chỉ đánh giờ London/New York;
  - tắt bot hoặc đóng lệnh quanh NFP, CPI, FOMC;
  - ưu tiên số tròn và mức cản khung lớn thay vì mọi vùng;
  - giữ lệnh lâu hơn, mục tiêu lớn hơn (H1 trở lên) để phí chỉ chiếm phần nhỏ của R.

### Việc nên thử tiếp (đều phải đo có phí và ngoài mẫu)
1. Ghi nhật ký cách đánh tay của chủ bot để biết **luật lọc thật** trước khi code.
2. Chạy lại công cụ đo với **nhiều tháng** dữ liệu, tách theo phiên (Á / London / New York) và bỏ khung giờ có tin.
3. Chỉ giữ vùng khung H4 trở lên và số tròn 10/50/100 USD. So sánh với vùng giả như đã làm.
4. Thử mục tiêu và dừng lỗ lớn hơn (ví dụ theo ATR H1), để 0,76 USD phí chỉ là vài phần trăm của R.

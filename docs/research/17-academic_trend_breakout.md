# Nghiên cứu D: bằng chứng học thuật về trend-following, breakout, intraday momentum cho vàng

Góc nhìn: các bài báo khoa học và nghiên cứu định lượng. Chỉ đọc tài liệu trên web, không sửa gì trong repo.
Ngày làm: 29/09/2026. Khoảng 20 lần đọc/tìm kiếm.

Cách ghi mức bằng chứng:
- **proven_with_data**: bài có bình duyệt (peer-reviewed) hoặc backtest làm lại được, CÓ tính phí và CÓ kiểm tra ngoài mẫu (out-of-sample).
- **reported_numbers_unverified**: có số liệu nhưng thiếu phí, thiếu ngoài mẫu, hoặc tôi chỉ đọc được phần tóm tắt.
- **claim_only**: chỉ là nhận định, hoặc là phép tính của tôi dựa trên giả định.

---

## 1. Trả lời ngắn

**"Phương pháp bot nào tốt nhất hiện nay?"**
Không có phương pháp nào được chứng minh là "chắc thắng" cho MỘT mã vàng trên M1/M5 sau phí. Phương pháp có bằng chứng mạnh nhất trong giới học thuật là **đi theo xu hướng khung dài (trend-following / time-series momentum)**: nhìn lợi nhuận 1–12 tháng qua, giữ lệnh vài tuần tới vài tháng, chỉnh khối lượng theo độ biến động. Nhưng bằng chứng đó mạnh chủ yếu khi chạy **cùng lúc 50–67 thị trường**. Với **riêng vàng**, bằng chứng yếu (không có ý nghĩa thống kê khi xét riêng từng mã).

**Ở khung M1/M5:** các nghiên cứu về vàng đều cho kết quả giống công cụ đo của dự án: có "mẫu hình" nhỏ trong dữ liệu, nhưng **phí + trượt giá ăn hết**. Kết quả -0,15R của dự án khớp gần đúng với chi phí mỗi lệnh (khoảng 0,165 ATR M5), tức là lợi thế gốc trước phí gần như bằng 0.

**"Sao tôi trade tay bằng cản thì được, còn code thì không?"** (trong phạm vi góc nhìn này)
- Một nghiên cứu thử hơn 7.000 quy tắc kỹ thuật, **có cả quy tắc hỗ trợ/kháng cự và breakout kênh**, trên 15 loại hàng hóa **có vàng**: sau khi trừ yếu tố "may mắn do thử quá nhiều quy tắc", **không quy tắc nào thắng thị trường**.
- Lợi nhuận của các quy tắc kỹ thuật cơ học **giảm dần theo thời gian** (1978–1984 có lời; 1985–2003 lỗ sau phí).
- Điều này không chứng minh cách trade tay của anh là sai. Nó chỉ cho thấy: phần "cản" viết thành luật cơ học thì không có lợi thế sau phí. Nếu cách trade tay có lời thật, lợi thế nằm ở phần **chưa được viết ra** (chọn lọc bối cảnh, bỏ qua phần lớn vùng, chọn khung lớn, quản lý lệnh). Muốn biết chắc, cần **nhật ký lệnh thật** (thời điểm, vùng, SL/TP, kết quả sau phí) để đo, không đoán.

---

## 2. Bảng các phát hiện (mạnh và liên quan nhất trước)

| # | Phương pháp | Khung giữ lệnh | Có phí? | Ngoài mẫu? | Áp dụng cho vàng M1/M5? | Mức bằng chứng |
|---|---|---|---|---|---|---|
| 1 | Trend-following nhiều thị trường (1–12 tháng) | tuần–tháng | Có (+ phí quỹ 2/20) | Có (dữ liệu 1880–1984) | Không | proven_with_data |
| 2 | Trend-following riêng từng mã (có vàng) | tháng | Không (kiểm định thống kê) | Có | Không | proven_with_data (kết quả âm cho vàng) |
| 3 | Luật kỹ thuật M5 trên vàng (MA, breakout…) | phút–giờ | Có (Jin 2022) | Có | Có | proven_with_data (kết quả âm) |
| 4 | Intraday momentum 30 phút cuối phiên (có vàng COMEX) | 30 phút | Không | Có (R² ngoài mẫu) | Có | reported_numbers_unverified (sau phí) |
| 5 | Phép tính chi phí XAUUSDm | — | Có | — | Có | claim_only (phép tính của tôi) |
| 6 | MA crossover / breakout kênh trên hàng hóa, dữ liệu tháng | tháng | Có | Chia giai đoạn | Không | proven_with_data |
| 7 | Luật kỹ thuật tối ưu từng thị trường (có kênh Donchian) | ngày | Có | Có (1985–2003) | Không | proven_with_data (lợi nhuận biến mất) |
| 8 | >7.000 luật gồm S/R và breakout, 15 hàng hóa có vàng | ngày | Chưa xác nhận | Kiểm tra "data snooping" | Không | reported_numbers_unverified (chỉ đọc tóm tắt) |
| 9 | Time-series momentum gốc (MOP 2012), 58 hợp đồng có vàng | tháng | Không (lợi nhuận gộp) | Có (1966–1985) | Không | reported_numbers_unverified (thiếu phí) |
| 10 | Intraday momentum SPY / GLD | 30 phút | SPY có; GLD không | Có | Gần (GLD) | reported_numbers_unverified |

---

## 3. Chi tiết từng phát hiện

### 3.1. Trend-following 137 năm, 67 thị trường: có lời sau phí, nhưng yếu dần
- Hurst, Ooi, Pedersen (2017), *A Century of Evidence on Trend-Following Investing*, Journal of Portfolio Management.
- 67 thị trường (29 hàng hóa, 11 chỉ số cổ phiếu, 15 trái phiếu, 12 cặp tiền), 1880–2016. Tín hiệu: gộp đều lợi nhuận 1 tháng, 3 tháng, 12 tháng. Mục tiêu biến động 10%/năm.
- Toàn giai đoạn: **18,0%/năm trước phí → 11,0% sau phí giao dịch ước tính → 7,3% sau phí quỹ 2/20**, Sharpe sau mọi phí **0,76**. Tương quan với cổ phiếu Mỹ ≈ -0,01.
- **2010–2016: chỉ 3,3%/năm, Sharpe 0,41** (thấp nhất kể từ những năm 1910).
- Chi phí giao dịch lấy theo ước tính 2012, nhân 2 cho 1993–2002 và nhân 6 cho 1880–1992. Chưa tính phí "roll" hợp đồng. Chính tác giả nói chi phí có độ không chắc chắn lớn.
- Lưu ý: tác giả làm ở AQR, một công ty bán quỹ trend-following (có xung đột lợi ích). Dữ liệu trước 1985 là "tái dựng", không phải giao dịch thật.
- Nguồn: https://static.twentyoverten.com/593e8a9e7299b471eaecf644/SkLoGL67M/A-Century-of-Evidence-on-Trend-Following-Investing.pdf ; https://www.aqr.com/Insights/Research/Journal-Article/A-Century-of-Evidence-on-Trend-Following-Investing

### 3.2. Nhưng xét RIÊNG vàng thì bằng chứng trend yếu
- Huang, Li, Wang, Zhou (2020), *Time series momentum: Is it there?*, Journal of Financial Economics.
- 55 tài sản, 1985–2015. Xét từng tài sản riêng: **47/55 có t-stat < 1,65** (không có ý nghĩa).
- **Vàng: hệ số 0,29, t = 1,43, R² trong mẫu 0,42%, R² ngoài mẫu (2000–2015) = -0,38%** → dự báo bằng xu hướng 12 tháng cho riêng vàng **kém hơn** dùng trung bình lịch sử.
- Chiến lược TSM có lời, nhưng "gần như giống hệt" chiến lược chỉ dựa vào trung bình lịch sử (không cần dự báo được).
- Kim, Tse, Wald (2016, Journal of Financial Markets): phần lớn lợi nhuận TSMOM đến từ **chỉnh khối lượng theo biến động**, không phải từ tín hiệu xu hướng; bỏ chỉnh biến động thì gần bằng mua-và-giữ.
- Nguồn: https://down.aefweb.net/WorkingPapers/w717.pdf ; https://www.sciencedirect.com/science/article/abs/pii/S0304405X19301953 ; https://papers.ssrn.com/sol3/papers.cfm?abstract_id=2786955

### 3.3. Luật kỹ thuật trên vàng khung 5 phút: "ảo" sau phí
- Jin (2022), *Performance of intraday technical trading in China's gold market*, J. of International Financial Markets, Institutions & Money. Vàng tương lai SHFE, nến 5 phút, 03/2018–03/2021. Sau khi xét data snooping, phí, điều kiện thị trường, tần suất giao dịch: **không có luật nào cho kết quả ngoài mẫu tốt ổn định; khả năng dự báo là "ảo" (illusory)**. (Tóm tắt từ công cụ tìm kiếm nói phí chỉ 20 điểm cơ bản đã xóa hết lợi nhuận; tôi chưa đọc được bài đầy đủ để xác nhận con số này.)
- Batten, Lucey, McGroarty, Peat, Urquhart (2018), cùng tạp chí: vàng giao ngay 5 phút, 2008–2014, **66.297 cặp MA**. Tham số chuẩn: **không dự báo được gì**. Một số tham số dài có ý nghĩa thống kê, nhưng **chưa trừ phí** (CXO Advisory nhận xét: bỏ qua phí thì thiên vị khung ngắn).
- Neely & Weller (2003), FX nửa giờ: khi tính phí thực tế và giờ giao dịch, **không có lợi nhuận vượt trội**.
- Bản thảo arXiv 2026 (chưa bình duyệt) trên MNQ 5 phút: 14 họ tín hiệu intraday momentum từ OHLCV, walk-forward 2023–2025: **không họ nào qua được chi phí**; 11/14 có lợi gộp 0,07–1,50 điểm, thấp hơn mức ma sát 2,0 điểm.
- Nguồn: https://ideas.repec.org/a/eee/intfin/v76y2022ics1042443121001876.html ; https://ideas.repec.org/a/eee/intfin/v52y2018icp102-113.html ; https://www.cxoadvisory.com/technical-trading/high-frequency-technical-trading-of-gold-and-silver/ ; https://ideas.repec.org/a/eee/jimfin/v22y2003i2p223-237.html ; https://arxiv.org/abs/2605.04004

### 3.4. Intraday momentum trong vàng có thật, nhưng quá nhỏ so với phí CFD
- Baltussen, Da, Lammers, Martens (2021), *Hedging demand and market intraday momentum*, Journal of Financial Economics. Hơn 60 hợp đồng tương lai, 1974–2020, **có vàng COMEX (GC, 1984–2020, phiên 8:20–13:30 NY)**.
- Quy luật: lợi nhuận từ đóng cửa hôm trước tới 30 phút trước đóng cửa dự báo cùng chiều cho **30 phút cuối**. Nguyên nhân được cho là dòng lệnh phòng hộ gamma của nhà tạo lập quyền chọn / ETF đòn bẩy. Hiệu ứng **đảo lại trong các ngày sau**.
- Vàng: hệ số 1,09 (có ý nghĩa 1%), **R² chỉ 0,25%, R² ngoài mẫu 0,08%**.
- Rổ hàng hóa: chiến lược vào lệnh 30 phút cuối **4,34%/năm, Sharpe 1,42 – CHƯA trừ phí**. Tác giả tự viết: chiến lược "có thể không khai thác được với nhiều nhà đầu tư sau khi tính phí".
- Nguồn: https://academicweb.nd.edu/~zda/intramom.pdf ; https://www.sciencedirect.com/science/article/abs/pii/S0304405X21001598

### 3.5. Phép tính chi phí cho XAUUSDm (phép tính của tôi, cần kiểm lại)
Dựa trên số của dự án: spread 0,16 + trượt giá 0,3 × 2 chiều ≈ **0,76 USD mỗi lệnh khứ hồi**; ATR M5 tháng 1/2026 ≈ 4,6 USD.
- **Khung M5:** 0,76 / 4,6 ≈ **0,165 ATR M5 mỗi lệnh**. Nếu SL ≈ 1 ATR M5 thì phí ≈ 0,165R. Công cụ đo được -0,15R sau phí → **trước phí ≈ 0R**. Tức là vào lệnh ở vùng cản trên M1/M5 không có lợi thế gốc; phí là toàn bộ khoản lỗ. (Cần kiểm lại R trong công cụ có đúng bằng khoảng 1 ATR M5 không.)
- **Intraday momentum 30 phút cuối:** 4,34%/năm / ~252 lệnh ≈ **1,7 điểm cơ bản (bps) mỗi lệnh, trước phí**. Nếu giá vàng khoảng 4.000–4.600 USD thì 0,76 USD ≈ **1,7–1,9 bps**. → **Phí bằng hoặc lớn hơn toàn bộ lợi thế.**
- **Khung D1 (giả định chưa đo):** nếu biên độ ngày ≈ 1,5–2% giá (khoảng 60–90 USD), phí 0,76 USD chỉ ≈ **1% ATR D1**, nhỏ hơn M5 khoảng 15 lần. Nhưng giữ lệnh qua đêm thì phải tính **phí swap** của Exness, chưa có trong số trên. Cần đo bằng dữ liệu thật của dự án.
- Nguồn đối chiếu: https://academicweb.nd.edu/~zda/intramom.pdf (số 4,34%/năm); các số chi phí lấy từ bối cảnh dự án.

### 3.6. MA crossover và breakout kênh trên hàng hóa, dữ liệu tháng: có lời sau phí
- Szakmary, Shen, Sharma (2010), *Trend-following trading strategies in commodity futures: A re-examination*, Journal of Banking & Finance. 28 hàng hóa, dữ liệu tháng, 48 năm.
- Mọi bộ tham số của **MA kép** và **breakout kênh** đều có lợi nhuận vượt trội trung bình **dương sau phí ở ít nhất 22/28 thị trường**; gộp lại thì có ý nghĩa rất mạnh và đúng ở hầu hết các giai đoạn con.
- Han, Hu, Yang (2016, cùng tạp chí): chiến lược MA trên **rổ** hàng hóa thắng mua-và-giữ, **sống được sau phí**, không tập trung ở một giai đoạn, bền với thay đổi độ dài MA và kiểm tra "data mining".
- Lưu ý: đây là dữ liệu **tháng** và **nhiều thị trường**, không phải M5 và không phải riêng vàng.
- Nguồn: https://www.sciencedirect.com/science/article/abs/pii/S037842660900199X ; https://www.researchgate.net/publication/46497190_Trend-following_trading_strategies_in_commodity_futures_A_re-examination ; https://ideas.repec.org/a/eee/jbfina/v70y2016icp214-234.html

### 3.7. Luật kỹ thuật tối ưu hóa cho từng thị trường: lợi nhuận biến mất theo thời gian
- Park & Irwin (2005), báo cáo AgMAS, Đại học Illinois. 12 hợp đồng (có bạc, đồng), 12 hệ thống (MA, **kênh giá kiểu Donchian**, dao động, lọc…), tối ưu tham số rồi kiểm tra ngoài mẫu, phí 50–100 USD/hợp đồng.
- 1978–1984: có lời. **1985–2003: danh mục 12 thị trường × 12 hệ thống lỗ -5,82%/năm sau phí**; giảm phí xuống vẫn -3,80%. Lợi nhuận **giảm khoảng 0,7 điểm %/năm**.
- Ý nghĩa cho bot: tối ưu tham số trên một mã rồi chạy thật là cách dễ "đẹp trong quá khứ, lỗ trong tương lai" nhất.
- Nguồn: https://farmdoc.illinois.edu/assets/marketing/agmas/AgMAS05_04.pdf

### 3.8. Hơn 7.000 luật, có cả hỗ trợ/kháng cự, có vàng: không luật nào thắng
- Marshall, Cahan, Cahan (2008), *Can commodity futures be profitably traded with quantitative market timing strategies?*, Journal of Banking & Finance. 15 hàng hóa (có vàng), dữ liệu ngày, 5 họ luật: lọc, MA, **hỗ trợ và kháng cự**, **breakout kênh**, OBV.
- Sau khi kiểm tra "data snooping" bằng bootstrap: **không luật nào thắng thị trường hơn mức ngẫu nhiên**.
- Tôi chỉ đọc được phần tóm tắt, chưa xác nhận họ có trừ phí hay không.
- Nguồn: https://www.sciencedirect.com/science/article/abs/pii/S0378426607004001 ; https://papers.ssrn.com/sol3/papers.cfm?abstract_id=1003064

### 3.9. Bài gốc time-series momentum (MOP 2012)
- Moskowitz, Ooi, Pedersen (2012), *Time series momentum*, Journal of Financial Economics. 58 hợp đồng (vàng từ 12/1969), 1985–2009.
- Nhìn lợi nhuận 12 tháng, giữ 1 tháng: **dương ở cả 58 hợp đồng**; hiệu ứng kéo dài khoảng 1 năm rồi **đảo một phần**. Dữ liệu 1966–1985 (ngoài mẫu): Sharpe 1,1.
- **Sharpe theo từng mã là gộp (chưa trừ phí)**; Hình 2 trong bài ghi rõ "gross Sharpe ratio".
- Nguồn: https://w4.stern.nyu.edu/facdir/lpederse/papers/TimeSeriesMomentum.pdf ; https://www.aqr.com/Insights/Research/Journal-Article/Time-Series-Momentum

### 3.10. Intraday momentum SPY và GLD
- Gao, Han, Li, Zhou (2018), JFE. SPY 1993–2013: nửa giờ đầu dự báo nửa giờ cuối, R² 1,6%; chiến lược 6,67%/năm, Sharpe 1,08. Sau phí bid-ask (từ 2001) còn **4,46%/năm**. Chú ý: SPY chỉ có spread khoảng 1 cent, rẻ hơn CFD vàng rất nhiều.
- Xu, Bouri, Saeed, Wen (2020), Resources Policy. **GLD** 2004–2019: nửa giờ thứ 5 dự báo nửa giờ cuối, R² 0,49%, ngoài mẫu 0,26%. Chiến lược chỉ **0,81%/năm, chưa trừ phí**; tỷ lệ thắng 53%. Với phí thật, gần như chắc chắn không còn lời (nhận định của tôi).
- Nguồn: https://assets.super.so/e46b77e7-ee08-445e-b43f-4ffd88ae0a0e/files/ee7dac49-530b-4950-b5d0-e0b5eee08f2e.pdf ; https://www.sciencedirect.com/science/article/abs/pii/S0304405X18301351 ; https://pmc.ncbi.nlm.nih.gov/articles/PMC7480318/

---

## 4. Ý nghĩa cho bot vàng (D1/H4 so với M1/M5)

1. **M1/M5:** mọi nghiên cứu về vàng khung ngắn tôi tìm được đều kết luận: lợi thế thống kê (nếu có) nhỏ hơn phí. Kết quả của dự án (-0,15R sau phí, vùng thật ≈ vùng giả) là **bình thường**, không phải lỗi code. Tiếp tục mài M1/M5 dễ rơi vào tối ưu hóa quá mức (kiểu Park & Irwin).
2. **D1/H4, giữ nhiều ngày:** phí tương đối nhỏ hơn khoảng 15 lần (giả định ATR D1, cần đo). Bằng chứng trend-following mạnh nhất ở khung này, **nhưng** chủ yếu là cho danh mục nhiều thị trường. Với riêng vàng, kỳ vọng thực tế: Sharpe thấp. Hurst và cộng sự ghi Sharpe trung bình **từng thị trường ≈ 0,4 trước phí** (1880–2016); danh mục đạt 0,76 sau phí là nhờ đa dạng hóa, một mã vàng không có được lợi ích này. Thêm vào đó: có nhiều năm đi ngang/lỗ, và cần tính swap.
3. **Intraday momentum 30 phút cuối phiên NY:** có thật trong vàng COMEX, nhưng lợi thế ≈ 1,7 bps/lệnh, bằng phí XAUUSDm. Chưa có nghiên cứu nào chứng minh chạy được trên CFD sau phí.
4. **Mean reversion ngắn hạn:** tài liệu cho thấy hiệu ứng momentum trong ngày **đảo lại trong các ngày sau** và TSMOM đảo sau khoảng 1 năm, nhưng tôi **không tìm được** nghiên cứu nào chứng minh chiến lược đảo chiều trên vàng có lời sau phí. Để trống, không kết luận.
5. **Hỗ trợ/kháng cự viết thành luật:** đã được thử trong nghiên cứu lớn (Marshall 2008, có vàng) và không thắng. Nếu vẫn muốn dùng cản, hợp lý hơn là dùng làm **bộ lọc ở khung lớn** cho một hệ trend D1/H4, rồi đo xem có cải thiện so với hệ không lọc hay không.

## 5. Cách kiểm chứng tiếp (không phải thêm tính năng, chỉ để có số thật)
- Đo lại: R trong công cụ có đúng ≈ 1 ATR M5 không, để xác nhận "trước phí ≈ 0R".
- Backtest một hệ trend D1 đơn giản, tham số cố định từ tài liệu (ví dụ: tín hiệu lợi nhuận 1/3/12 tháng, hoặc breakout kênh 20/55 ngày), tick thật + swap Exness, chia trước/sau 2020 để có ngoài mẫu. So sánh với mua-và-giữ vàng cùng mức biến động.
- Thu nhật ký lệnh tay thật của chủ bot để đo lợi thế sau phí, trước khi cố viết lại thành luật.

## 6. Giới hạn của báo cáo này
- Một số bài chỉ đọc được phần tóm tắt (Marshall 2008, Jin 2022, Szakmary 2010, Han 2016, Kim-Tse-Wald 2016).
- Chưa có nghiên cứu học thuật nào tôi tìm được làm trực tiếp trên **CFD XAUUSD của Exness**; các bài dùng hợp đồng tương lai COMEX/SHFE, vàng giao ngay hoặc ETF GLD. Phí và swap trên CFD khác.
- Các phép tính ở mục 3.5 là của tôi, dựa trên số liệu dự án và giả định giá vàng khoảng 4.000–4.600 USD.

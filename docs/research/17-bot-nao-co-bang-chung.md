# Vì sao code cản chưa ra lời, và bot nào có bằng chứng tốt nhất

Ngày 29/09/2026. Cách đọc nhãn:
- **Đã chứng minh**: bài có bình duyệt hoặc kiểm tra làm lại được, có tính phí, có kiểm tra trên dữ liệu không dùng để tìm luật.
- **Số liệu chưa kiểm lại**: có con số cụ thể, nhưng chưa ai kiểm lại độc lập, hoặc thiếu phí hay thiếu kiểm tra ngoài mẫu.
- **Chỉ là lời kể**: lời người bán, diễn đàn, hoặc mẫu quá nhỏ.
- **Số đo dự án**: kết quả công cụ của mình, ghi trong `docs/HANDOFF.md`.

## Trả lời ngắn

- Code không "sai" vì lỗi lập trình. Nó chép được cách *vẽ* cản, nhưng chưa chép được cách anh *chọn* cản. Ở khung M1/M5, phí lại gần bằng toàn bộ lợi thế của cản.
- Hiện chưa có phương pháp bot vàng M1/M5 nào được chứng minh có lời sau phí. Phương pháp có bằng chứng mạnh nhất là đi theo xu hướng khung dài (giữ lệnh vài tuần tới vài tháng), chạy trên nhiều thị trường cùng lúc. Nếu chỉ chạy riêng vàng thì bằng chứng yếu.

## 1. Vì sao bạn trade cản bằng tay được mà code thì chưa

**Lý do 1: Code lấy mọi vùng, còn anh chỉ chọn một ít.**
Mỗi lần giá chạm cản, trung vị có 19 vùng khác chồng lên. Vì vậy giá gần như lúc nào cũng nằm trong một vùng cản nào đó. Vùng thật bật ≥ 2 ATR M5 được 43,9%, vùng giả dời ngẫu nhiên được 41,3%. Lệnh 1R: vùng thật −0,15R, vào ngẫu nhiên −0,16R, vùng giả −0,18R [Số đo dự án, 1 tuần, `docs/HANDOFF.md`]. Trên dữ liệu Dukascopy 03–12/2025 kết quả cũng vậy: 44,0% so với 42,7% (+1,3 ± 1,9 điểm) [Số đo dự án].
Người khác viết cản thành luật cũng gặp đúng chuyện này:
- Hơn 7.000 luật (có cả hỗ trợ/kháng cự và phá kênh) trên 15 loại hàng hóa có vàng, khung ngày: không luật nào hơn mức may rủi [Số liệu chưa kiểm lại, https://www.sciencedirect.com/science/article/abs/pii/S0378426607004001].
- Một repo viết SMC/ICT thành luật cứng, thử trên vàng và 4 mã khác, có tính phí và kiểm tra walk-forward: −0,33R/lệnh, 0/210 cấu hình qua kiểm định. Các cấu hình vàng "đẹp" vẫn ngang vào lệnh ngẫu nhiên [Số liệu chưa kiểm lại, https://github.com/AaroNLaU0307/quant-backtest-framework]. Repo này chỉ thử một cách hiểu SMC, không phải Rare SnR/411/Unicorn của anh.

Nghĩa là nếu anh có lợi thế, nó nằm ở phần chưa được viết thành luật: chọn vùng nào, bỏ vùng nào, lúc nào thì đứng ngoài. Bot hay người tự nó không quyết định thắng thua: hơn 9.000 quỹ chạy bằng hệ thống và quỹ do người quyết định cho kết quả tương đương sau điều chỉnh rủi ro [Đã chứng minh, https://papers.ssrn.com/sol3/papers.cfm?abstract_id=2880641].

**Lý do 2: Ở M1/M5, phí quá lớn so với lợi thế.**
Mỗi lệnh khứ hồi tốn khoảng 0,76 USD (spread 0,16 + trượt giá 0,3 × 2), bằng khoảng 16% ATR M5 (4,6 USD). Con số trượt 0,3 là giả định, chưa đo thật [phép tính của dự án]. Các nghiên cứu độc lập:
- Phá biên mở phiên (ORB): 225 biến thể trên 9 loại hợp đồng tương lai (có vàng GC), 2010–2026, phí khoảng 0,25 USD/oz. Không biến thể nào đạt ngưỡng có lời đã đăng ký trước, và phần vàng tổng cộng lỗ [Số liệu chưa kiểm lại, https://github.com/mulhamfetna/trading-strategy-finder]. Phí của mình cao hơn khoảng 3 lần.
- Luật kỹ thuật trên vàng 5 phút (sàn Thượng Hải, 2018–2021): khả năng dự báo là "ảo" sau khi tính phí và loại phần may mắn do thử quá nhiều luật [Số liệu chưa kiểm lại, https://ideas.repec.org/a/eee/intfin/v76y2022ics1042443121001876.html].
- Ngoại hối nửa giờ: không còn lời khi tính phí thật và giờ giao dịch thật [Đã chứng minh, https://ideas.repec.org/a/eee/jimfin/v22y2003i2p223-237.html].
- Nến M1 vàng 2026: hướng giá gần như không đoán được từ nến (tự tương quan ≤ 0,03). Trong 15 ứng viên, không có ứng viên nào qua kiểm tra tháng 7–9 [Số đo dự án].

**Lý do 3: Người trade tay tự lọc theo giờ và tin mà không để ý.**
Giờ London và New York chồng nhau là lúc giá mang nhiều thông tin nhất. Phiên Á có nhiều giao dịch "không mang thông tin" hơn [Đã chứng minh, https://ideas.repec.org/a/eee/finana/v78y2021ics1057521921002209.html ; Số liệu chưa kiểm lại, https://ideas.repec.org/p/koe/wpaper/1722.html]. Tin Mỹ lúc 8:30 sáng giờ New York (bảng lương NFP, lạm phát CPI) làm vàng chạy mạnh nhất [Đã chứng minh, https://econpapers.repec.org/RePEc:eee:jbfina:v:36:y:2012:i:1:p:51-65]. Các nghiên cứu này chỉ nói giá chạy mạnh hay yếu, không nói hướng. Nhưng chọn giờ và né tin có thể là một phần "bộ lọc trong đầu" anh.

**Lý do 4: Kết quả trade tay chưa được đo đủ.** Đây là giới hạn chung của trí nhớ con người, không phải nghi ngờ anh.
- 215 nhà đầu tư Đức gần như không ước đúng lợi nhuận thật của chính mình [Đã chứng minh, https://ideas.repec.org/p/xrs/sfbmaa/07-70.html].
- Ở Đài Loan, khoảng 20% người lướt sóng trong ngày có lãi trong một năm bất kỳ, nhưng dưới 1% lãi đều qua các năm sau phí. Nhóm giỏi đó có thật và giữ được phong độ [Đã chứng minh, https://faculty.haas.berkeley.edu/odean/papers/day%20traders/The%20Cross-Section%20of%20Speculator%20Skill.pdf].
- Ở Brazil, 97% người lướt sóng trong ngày quá 300 ngày bị lỗ [Đã chứng minh, https://ideas.repec.org/p/spa/wpaper/2019wpecon47.html].

Anh có thể thuộc nhóm giỏi. Chỉ nhật ký lệnh có tính phí mới cho biết điều đó.

**Lý do 5: Mẫu 1 tuần quá ngắn** để kết luận chắc về từng loại cản [Số đo dự án].

## 2. Phương pháp bot nào có bằng chứng tốt nhất hiện nay

| # | Phương pháp | Khung | Mức bằng chứng | Phí / kiểm tra ngoài mẫu | Hợp bot vàng của mình? | Rủi ro chính | Nguồn |
|---|---|---|---|---|---|---|---|
| 1 | Theo xu hướng trên nhiều thị trường (tín hiệu 1, 3, 12 tháng; khối lượng chỉnh theo biến động) | Ngày–tháng, giữ vài tuần–vài tháng | Đã chứng minh (cho danh mục 67 thị trường) | Có phí. Sau phí giao dịch và phí quỹ: 7,3%/năm, Sharpe 0,76. Giai đoạn 2010–2016 Sharpe chỉ còn 0,41. Là mô phỏng, không phải tiền thật | Một phần. Lợi thế đến từ nhiều thị trường; riêng vàng, xu hướng 12 tháng không có ý nghĩa thống kê (t = 1,43, ngoài mẫu kém cả trung bình lịch sử) | Nhiều năm đi ngang; tác giả làm ở AQR, công ty bán quỹ xu hướng | https://static.twentyoverten.com/593e8a9e7299b471eaecf644/SkLoGL67M/A-Century-of-Evidence-on-Trend-Following-Investing.pdf ; https://down.aefweb.net/WorkingPapers/w717.pdf |
| 2 | Đường trung bình / phá kênh trên danh mục hàng hóa | Ngày–tháng | Số liệu chưa kiểm lại | Có phí; không có kiểm tra ngoài mẫu chính thức | Yếu. Riêng vàng, đường trung bình khung ngày 1,60%/năm, t = 0,71, không có ý nghĩa | Tối ưu riêng từng mã thì lỗ −5,82%/năm sau phí giai đoạn 1985–2003 [Đã chứng minh] | https://www.sciencedirect.com/science/article/abs/pii/S037842660900199X ; https://ideas.repec.org/a/eee/jbfina/v70y2016icp214-234.html ; https://farmdoc.illinois.edu/assets/marketing/agmas/AgMAS05_04.pdf |
| 3 | Đà trong ngày (diễn biến trong ngày dự báo 30 phút cuối) | 1 lệnh/ngày | Hiệu ứng có thật về thống kê; có lời sau phí thì chưa ai chứng minh | Chưa tính phí. Lời trước phí khoảng 1,7 phần vạn mỗi lệnh (danh mục hàng hóa), xấp xỉ phí XAUUSDm | Không, phí ăn hết | Vàng chạy 24 giờ nên không rõ đâu là "30 phút cuối" | https://academicweb.nd.edu/~zda/intramom.pdf |
| 4 | Xu hướng D1 + giá bị từ chối tại vùng H4 đã chạm ≥ 2 lần, vào lệnh ở M15 | H4/M15 | Chỉ là lời kể: 29 lệnh ngoài mẫu, +0,45R, khoảng tin cậy vẫn chứa 0 | Tính spread thật, không tính hoa hồng. Ngoài mẫu rơi đúng đợt vàng tăng mạnh | Đáng thử, gần cách anh làm nhất | Có thể chỉ nhờ vàng tăng | https://github.com/anirudhatalmale6-alt/xauusd-strategy-backtest |
| 5 | Phá biên phiên Á lúc mở London | M5–M15 | Số liệu chưa kiểm lại: −0,035R trên 611 lệnh, gần hòa vốn | Có phí, có kiểm tra ngoài mẫu | Không, chưa thấy lợi thế | Người bán quảng cáo quá mức | https://github.com/VishalKhati/asset-manager-platform |
| 6 | Hồi theo xu hướng (EMA 20/50/200 + Stochastic) trên vàng | M15/M5 | Số liệu chưa kiểm lại: −0,09R trên 1.378 lệnh ngoài mẫu, PF 0,82 | Có phí, có kiểm tra ngoài mẫu | Không, bỏ hoa hồng và trượt giá vẫn lỗ | Lỗ ngay cả khi vàng đang tăng mạnh | https://github.com/VishalKhati/asset-manager-platform |
| 7 | Máy học / học tăng cường trên vàng M15 | M15 | Số liệu chưa kiểm lại: tài khoản demo 763 lệnh, PF 1,05, không hơn may rủi (t = 0,55) | Có phí, chạy demo thật | Không | Chỉnh tham số khoảng 1.100 lần trên cùng dữ liệu | https://www.mql5.com/en/articles/21314 |
| 8 | Lưới / gấp thếp | Mọi khung | Chỉ là lời kể | Không có | Không | Cháy tài khoản khi vàng chạy một chiều | https://newyorkcityservers.com/blog/waka-waka-ea-review |

**Kết luận thẳng:** với vàng M1/M5, chưa có phương pháp nào được chứng minh có lời sau phí. Mọi kiểm tra trung thực ở khung nhỏ mà nhóm nghiên cứu tìm được đều lỗ hoặc hòa vốn.

## 3. Đề xuất cho dự án

### Hướng chính: đo cách anh chọn vùng trước, rồi mới code tiếp

Lý do chọn: đây là phần duy nhất chưa được đo, dùng đúng thế mạnh của anh và công cụ đo đã có.

Bước đầu, đo được:
1. Trong 1–2 tháng, trước mỗi phiên, anh vẽ những vùng anh thật sự sẽ đánh, ở khung anh vẫn dùng (nên ưu tiên H1 trở lên để dừng lỗ đủ lớn). Chụp ảnh có giờ và ghi vào một file: giá trên, giá dưới, khung, kiểu (Rare SnR / 411 / Unicorn), lý do. Ghi cả vùng anh bỏ qua. Vẽ xong thì không sửa.
2. Công cụ đo có sẵn chạy trên đúng các vùng đó (cần thêm phần đọc file vùng của anh; phần này chưa có). Đo tỷ lệ bật so với vùng giả cùng độ rộng, và lệnh 1R sau phí so với vào lệnh ngẫu nhiên.
3. Song song, ghi nhật ký 50–100 lệnh tay thật: có phí, ghi lý do trước khi vào lệnh.
4. Đặt dừng lỗ đủ lớn (ví dụ ≥ 15 USD) để phí 0,76 USD chỉ còn khoảng 5% của R, thay vì khoảng 16%.

Tiêu chí dừng (đề xuất; anh chỉnh được, nhưng phải chốt trước khi xem kết quả): sau khoảng 200 lần chạm, nếu lệnh 1R sau phí từ vùng anh chọn không hơn vào ngẫu nhiên, hoặc khoảng tin cậy 95% của phần chênh vẫn chứa 0, thì dừng code điểm vào tại cản ở M1/M5. Thêm một mốc từ `docs/HANDOFF.md`: ở tỷ lệ lời/lỗ 1:1, cần thắng khoảng 53–55% sau spread mới có lời.
Nếu vùng anh chọn thắng rõ: so vùng anh chọn với vùng máy vẽ để tìm ra luật chọn (khung, số lần chạm, số tròn, giờ). Viết luật ra trước khi đo, rồi kiểm trên tháng chưa dùng theo cách chia dữ liệu ở SPEC 24.6.

### Lựa chọn khác A: bot theo xu hướng khung ngày trên XAUUSDm

- Bước đầu: một hệ đơn giản, tham số cố định lấy từ tài liệu (tín hiệu 1/3/12 tháng hoặc phá kênh), không tối ưu. Chạy kiểm tra nhiều năm, có tính swap của Exness, và so với mua rồi giữ vàng. Trước đó phải kiểm xem có đủ lịch sử tick thật hay không.
- Tiêu chí dừng: trên phần dữ liệu khóa, nếu sau phí và swap không hơn mua rồi giữ, hoặc mức sụt vốn vượt ngưỡng anh chịu được, thì dừng.
- Nói trước: lợi nhuận kỳ vọng thấp (mỗi thị trường riêng lẻ có Sharpe khoảng 0,4 trước phí), có nhiều năm đi ngang, và bằng chứng riêng cho vàng còn yếu.

### Lựa chọn khác B: bot bán tự động

- Bước đầu: bot chỉ tìm vùng H4 trở lên rồi báo; anh bấm "đánh" hoặc "bỏ"; bot ghi lại cả hai loại.
- Tiêu chí dừng: sau khoảng 200 tín hiệu, nếu tín hiệu anh duyệt không hơn tín hiệu anh bỏ, nghĩa là bộ lọc của anh chưa thêm giá trị, thì dừng.
- Lưu ý: chưa có bằng chứng rằng máy học từ quyết định của chuyên gia sẽ có lời khi trading. Nghiên cứu duy nhất về trading thấy mô hình không bắt chước được người [Số liệu chưa kiểm lại, https://www.sciencedirect.com/science/article/abs/pii/S0169207007000714].

## 4. Những thứ nên tránh

- **Lưới / gấp thếp:** đường vốn đẹp cho tới khi cháy. Waka Waka, tài khoản lưới công khai sống lâu nhất (chạy AUD/NZD/CAD, không phải vàng), vẫn sụt hơn 40% năm 2024 [Chỉ là lời kể, https://newyorkcityservers.com/blog/waka-waka-ea-review].
- **Tin backtest đẹp hay số của người bán:** Gold Reaper có backtest PF 2,72, chạy thật chỉ còn PF 1,08 và sụt vốn 41,7% [Số liệu chưa kiểm lại, nguồn là bên bán VPS, https://newyorkcityservers.com/blog/the-gold-reaper-review]. Với 888 thuật toán, Sharpe lúc backtest gần như không dự báo được Sharpe về sau (R² < 0,025); backtest chỉ dự báo được mức rủi ro [Đã chứng minh, https://papers.ssrn.com/sol3/papers.cfm?abstract_id=2745220].
- **Chỉnh tham số trên một mã hoặc vài tuần dữ liệu:** hệ tối ưu riêng từng thị trường lỗ −5,82%/năm khi kiểm tra ngoài mẫu [Đã chứng minh, https://farmdoc.illinois.edu/assets/marketing/agmas/AgMAS05_04.pdf]. Ứng viên của chính mình: +2,07 USD/lệnh lúc tìm, −0,25 USD/lệnh lúc kiểm [Số đo dự án].
- **Chiến lược "phiên Á / quét thanh khoản London" trên blog:** không có kiểm tra công khai nào có tính phí [Chỉ là lời kể, https://www.pro-scalper.com/xauusd-strategies/asian-session-gold-strategy].
- **Scalping M1/M5 với dừng lỗ nhỏ:** dừng lỗ 1 ATR M5 thì phí đã chiếm khoảng 16% R, dừng nhỏ hơn thì còn tệ hơn [phép tính của dự án].
- **Thêm bộ lọc liên tục trên cùng một dữ liệu:** mỗi lần thử thêm là thêm một cơ hội "trúng" nhờ may mắn. Phải đếm số lần thử và giữ riêng phần dữ liệu khóa.

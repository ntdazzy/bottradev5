# Nghiên cứu D - Thực tế từ cộng đồng trader, quỹ cấp vốn (prop firm) và sàn

Ngày: 29/09/2026. Chỉ dùng tìm kiếm web. Không sửa gì trong repo.

Ghi chú giới hạn: Reddit (r/algotrading) chặn công cụ đọc web của tôi, nên tôi KHÔNG đọc trực tiếp được các thread Reddit. Phần "ý kiến cộng đồng" lấy từ EliteTrader, MQL5, ForexFactory (một số trang cũng bị chặn).

Mức bằng chứng:
- proven_with_data: số liệu của cơ quan quản lý, bài báo khoa học có bình duyệt, hoặc backtest có chi phí và kiểm tra ngoài mẫu.
- reported_numbers_unverified: có con số nhưng tôi không kiểm lại được (tự công bố, bản thảo chưa bình duyệt).
- claim_only: chỉ là ý kiến, không có dữ liệu.

---

## 1. Câu trả lời ngắn cho chủ bot

**"Phương pháp bot nào tốt nhất hiện nay?"**
Không có bằng chứng độc lập nào cho thấy một phương pháp bot "tốt nhất" cho vàng khung M1/M5 sau khi trừ chi phí. Bằng chứng mạnh nhất về một lợi thế bền là **đi theo xu hướng chậm (time-series momentum) giữ lệnh vài tuần đến vài tháng trên nhiều thị trường**, không phải scalping M1/M5. Ở cấp quỹ chuyên nghiệp, bot và người làm tay cho kết quả tương đương sau khi điều chỉnh rủi ro, nên "bot" tự nó không thua "người". Cái thua là: lợi thế nhỏ + chi phí lớn ở khung nhỏ.

**"Sao tôi trade tay được mà code thì sai?"**
Có 3 khả năng, cần kiểm tra chứ không đoán:
1. **Kết quả trade tay chưa được đo cùng cách** (mọi lệnh, có phí, có spread, có trượt giá). Nghiên cứu cho thấy nhà đầu tư cá nhân thường KHÔNG đoán đúng lợi nhuận thật của chính mình.
2. **Kỹ năng nằm ở chỗ CHỌN vùng**, không nằm ở vùng. Công cụ của ta vẽ mọi vùng (trung vị 19 vùng chồng lên nhau mỗi lần chạm) nên vùng nào cũng "đúng" và không vùng nào có lợi thế. Người trade tay có thể bỏ qua 90% vùng. Trên EliteTrader, nhiều người nói gần như không thể định nghĩa S/R cho máy hiểu.
3. **Lợi thế có thật nhưng nhỏ, bị phí ăn hết** ở M1/M5. Phép tính thô: spread 0.16 + trượt 0.3 x 2 chiều = 0.76 USD mỗi lệnh. Nếu dừng lỗ khoảng 1 ATR(M5) = 4.6 USD thì chi phí khoảng 0.17R mỗi lệnh. Con số -0.15R mà công cụ đo được gần bằng đúng mức chi phí này, tức là lợi thế trước phí gần như bằng 0 (đây là suy luận của tôi từ số trong đề bài, chưa kiểm).

**Cách kiểm tra đơn giản nhất:** chủ bot tự vẽ trước vùng S/R mình sẽ dùng cho 1-2 tuần (lưu ảnh trước khi giá tới), rồi ta chỉ đo những vùng đó (không đo mọi vùng máy tìm ra), so với vùng giả dịch ngẫu nhiên, có tính phí. Đồng thời ghi nhật ký 50-100 lệnh tay thật, có phí.

---

## 2. Các phát hiện chính

### F1. 70-80% tài khoản CFD cá nhân thua lỗ (kể cả ở Exness)
- ESMA (2018): các cơ quan quản lý châu Âu thấy 74-89% tài khoản CFD cá nhân thua lỗ; lỗ trung bình mỗi khách 1.600-29.000 EUR.
  Nguồn: https://www.esma.europa.eu/press-news/esma-news/esma-agrees-prohibit-binary-options-and-restrict-cfds-protect-retail-investors
- Tổng hợp cảnh báo bắt buộc của 49 sàn (2026): trung bình 71.0% thua, thấp nhất 51% (eToro), cao nhất 81% (FXTM); **Exness 71.67%**.
  Nguồn: https://brokerrank.net/research/retail-loss-rates (tổng hợp của bên thứ ba từ số sàn tự công bố)
- Mức bằng chứng: proven_with_data (số của cơ quan quản lý, tiền thật, đã trừ phí). Không tách riêng vàng hay bot.

### F2. Người day trade kiên trì gần như không sống được bằng nghề
- Brazil, 19.646 người day trade hợp đồng mini-Ibovespa 2013-2015: **97% người kiên trì trên 300 ngày thua lỗ**; chỉ 1,1% kiếm hơn lương tối thiểu; **không thấy dấu hiệu học được nghề theo thời gian**.
  Nguồn: https://ideas.repec.org/p/spa/wpaper/2019wpecon47.html , https://papers.ssrn.com/sol3/papers.cfm?abstract_id=3423101
- Mức bằng chứng: proven_with_data (dữ liệu đầy đủ của cơ quan quản lý Brazil, tiền thật).

### F3. Kỹ năng có thật nhưng cực hiếm: dưới 1%
- Đài Loan 1992-2006: xếp hạng day trader theo năm trước, xem năm sau. 500 người đứng đầu tiếp tục lãi 37,9 bps/ngày sau phí; nhóm cuối lỗ 28,9 bps/ngày. **"Dưới 1% day trader có thể lãi ổn định, dự đoán được, sau phí."**
  Nguồn: https://faculty.haas.berkeley.edu/odean/papers/day%20traders/The%20Cross-Section%20of%20Speculator%20Skill.pdf (Journal of Financial Markets 18, 2014)
- Ý nghĩa: người trade tay giỏi có tồn tại và kết quả của họ lặp lại được. Nhưng tỷ lệ rất nhỏ, nên muốn tin mình thuộc nhóm đó thì cần số liệu.
- Mức bằng chứng: proven_with_data, có kiểm tra ngoài mẫu (năm sau).

### F4. Quỹ cấp vốn (prop firm): khoảng 7% từng nhận tiền, rất ít lên tài khoản thật
- FPFX Tech (hạ tầng cho 10 prop firm), hơn 300.000 tài khoản / 100.000 trader: 14% qua thử thách; 7% tổng số trader từng được trả tiền; tiền trả trung bình = 4% cỡ tài khoản; mỗi người tốn trung bình 800 USD phí thi.
  Nguồn: https://www.financemagnates.com/forex/analysis/exclusive-only-7-of-300000-prop-trading-accounts-achieved-payouts/ (18/09/2024)
- Topstep (tự công bố năm 2025): 16,8% lượt thi đạt; 51,8% người thi từng đạt ít nhất 1 lần; 33,3% người ở cấp Funded nhận được tiền; **chỉ 0,71% người có Express Funded được lên tài khoản Live**. Lưu ý: phần lớn là tài khoản mô phỏng.
  Nguồn: https://www.topstep.com/blog/truth-about-prop-firm-payouts
- FTMO không công bố tỷ lệ qua; các con số "10%" trên mạng là suy đoán.
  Nguồn: https://coinlaw.io/ftmo-statistics/
- Mức bằng chứng: reported_numbers_unverified (công ty tự công bố, không có kiểm toán độc lập; prop firm có lợi khi bán phí thi).

### F5. Người đầu tư thường không biết kết quả thật của chính mình
- Glaser & Weber: khảo sát 215 nhà đầu tư dùng sàn online, so với sổ lệnh thật: họ **gần như không ước lượng đúng lợi nhuận đã đạt**; người ít kinh nghiệm sai nhiều hơn. Các bài tóm tắt cho biết hệ số tương quan giữa lợi nhuận tự đoán và thật không khác 0, và họ đoán cao hơn thực tế khoảng 11,5%/năm.
  Nguồn: https://ideas.repec.org/p/xrs/sfbmaa/07-70.html , https://www.cbsnews.com/news/of-course-my-returns-beat-the-market/
- Ý nghĩa cho dự án: câu "tôi trade tay được" cần một nhật ký lệnh có phí để so, không thể dùng làm bằng chứng cho bot.
- Mức bằng chứng: proven_with_data cho cổ phiếu (không phải vàng, không phải intraday).

### F6. Backtest đẹp gần như không dự báo được kết quả thật
- Quantopian, 888 thuật toán có ít nhất 6 tháng chạy ngoài mẫu: **Sharpe trong backtest giải thích dưới 2,5% (R² < 0,025) kết quả ngoài mẫu**; càng backtest nhiều lần thì chênh lệch backtest với thực tế càng lớn.
  Nguồn: https://papers.ssrn.com/sol3/papers.cfm?abstract_id=2745220 , https://quantpedia.com/quantopians-academic-paper-about-in-vs-out-of-sample-performance-of-trading-alg/
- Bailey, Borwein, López de Prado, Zhu: thử càng nhiều cấu hình thì cấu hình "tốt nhất" trong mẫu càng dễ tệ ngoài mẫu.
  Nguồn: https://papers.ssrn.com/sol3/papers.cfm?abstract_id=2326253
- Mức bằng chứng: proven_with_data (cổ phiếu Mỹ là chủ yếu, nhưng nguyên lý áp dụng cho mọi EA dò tham số).

### F7. Bot không thua người ở cấp chuyên nghiệp
- Harvey, Rattray, Sinclair, Van Hemert (Man AHL, 1996-2014): quỹ hệ thống (máy) và quỹ tùy ý (người) có hiệu suất tương đương sau khi điều chỉnh rủi ro và yếu tố thị trường.
  Nguồn: https://papers.ssrn.com/sol3/papers.cfm?abstract_id=2880641 , https://www.ahl.com/man-vs-machine
- Lo và cộng sự (2010): con người phân biệt được biểu đồ giá thật với giá xáo trộn ngẫu nhiên (p ≤ 0,5%), tức là mắt người thấy được cấu trúc có thật. Nhưng "thấy cấu trúc" chưa phải "lãi sau phí".
  Nguồn: https://arxiv.org/abs/1002.4592
- Mức bằng chứng: proven_with_data, nhưng là quỹ lớn, khung ngày/tuần, không phải scalping vàng.

### F8. Cộng đồng: S/R rất khó viết thành luật cho máy; chưa ai báo bot S/R có lời
- EliteTrader, thread "Support and Resistance Algorithm": có người thử cao/thấp/đóng ngày trước và zigzag; người backtest (FaceOff) nói S/R "không lời bằng các hệ khác" vì "giá phá S/R rồi đảo chiều mạnh quá nhiều lần". Không ai báo bot S/R tự động có lời.
  Nguồn: https://www.elitetrader.com/et/threads/support-and-resistance-algorithm.159100/
- EliteTrader, thread "automated vs mechanical vs discretionary": người viết (capm) hỏi "làm sao định nghĩa vùng S/R cho máy hiểu... tôi thấy về cơ bản là không làm được". ValeryN: đi theo hệ máy thì phải dùng luật đơn giản, lợi thế mỗi lệnh thấp hơn, bù bằng số lệnh.
  Nguồn: https://www.elitetrader.com/et/threads/the-automated-vs-mechanical-vs-discretionary-trading-debate.355696/
- Mức bằng chứng: claim_only (ý kiến diễn đàn). Nhưng khớp với kết quả đo của ta: vùng máy vẽ quá dày, vùng thật chỉ hơn vùng giả 43,9% so với 41,3%.

### F9. EA vàng khung nhỏ chết vì chi phí thực thi; martingale/lưới chắc chắn cháy
- Blog MQL5 (người viết đang quảng cáo EA riêng, không có số liệu): EA vàng M1 thắng backtest nhưng thua thật vì spread giãn lúc tin tức, trượt giá bất lợi ở dừng lỗ, độ trễ vài trăm ms.
  Nguồn: https://www.mql5.com/en/blogs/post/769035
- Luồng EliteTrader về robot scalping XAUUSD M1-M5 cũng nhắc giá vàng chạy nhanh, cần dừng lỗ rộng, spread thả nổi làm hỏng điểm vào.
  Nguồn: https://www.elitetrader.com/et/threads/scalping-robot-for-metatrader-4-xauusd-period-m1-m5.387621/
- Martingale/lưới không dừng lỗ: lãi đều nhiều tuần rồi cháy tài khoản trong vài ngày; bài MQL5 chứng minh bằng toán rằng lưới ngây thơ tiến tới cháy.
  Nguồn: https://www.mql5.com/en/articles/8390 , https://www.mql5.com/en/articles/21833
- Mức bằng chứng: claim_only (thực thi); phần martingale là lập luận toán học chuẩn.

### F10. Tín hiệu bán lẻ phổ biến bị bác bỏ khi kiểm tra nghiêm; chỉ xu hướng chậm có bằng chứng
- Bản thảo arXiv 2607.20093 (07/2026, chưa bình duyệt): kiểm tra 5 họ tín hiệu (xu hướng, dao động, nến, khối lượng, lịch), có sửa lỗi kiểm định nhiều lần và có phí: dao động, khối lượng, lịch, nến bị bác bỏ; xu hướng và momentum "chưa kết luận"; **không tín hiệu nào được xác nhận**. Không kiểm tra S/R trực tiếp.
  Nguồn: https://arxiv.org/abs/2607.20093
- Moskowitz, Ooi, Pedersen (2012): time-series momentum (giữ 1-12 tháng) có lợi thế ở cả 58 hợp đồng tương lai, gồm hàng hóa.
  Nguồn: https://papers.ssrn.com/sol3/papers.cfm?abstract_id=2089463
- Intraday momentum (nửa giờ đầu dự báo nửa giờ cuối) có ở hợp đồng tương lai hàng hóa Trung Quốc, kim loại mạnh nhất; chưa rõ còn lời sau phí CFD vàng.
  Nguồn: https://mpra.ub.uni-muenchen.de/97134/1/MPRA_paper_97134.pdf
- Mức bằng chứng: arXiv = reported_numbers_unverified; Moskowitz = proven_with_data (không phải intraday); intraday momentum = reported_numbers_unverified cho trường hợp của ta.

---

## 3. Điều gì tách người sống sót khỏi số đông (tổng hợp)

1. Có lợi thế **đo được**, có phí, ngoài mẫu - không phải cảm giác (F3, F5, F6).
2. Chi phí nhỏ so với biên độ mỗi lệnh: khung càng nhỏ càng khó (F9, và phép tính 0.17R ở trên).
3. Không dùng martingale/lưới không dừng lỗ (F9).
4. Giữ rủi ro mỗi ngày nhỏ: đa số người trượt thử thách prop firm vì phạm lỗ ngày, không phải vì không đạt mục tiêu (nguồn tổng hợp, chưa kiểm: https://www.quantvps.com/blog/prop-firm-statistics).
5. Ít tham số, ít lần tối ưu (F6).

## 4. Đề xuất cho dự án (không sửa mã)

- Không coi "trade tay được" là bằng chứng cho bot. Cần nhật ký lệnh tay có phí.
- Thử nghiệm quyết định: chủ bot đánh dấu trước các vùng mình sẽ dùng (ảnh có giờ), ta đo chỉ các vùng đó so với vùng giả. Nếu vùng chủ bot chọn thắng rõ vùng giả sau phí, thì kỹ năng nằm ở khâu chọn vùng và cần tìm luật chọn đó. Nếu không, S/R khung M1/M5 trên vàng khó có lời sau phí.
- Nếu muốn bot có bằng chứng tốt nhất hiện có: xem xét khung lớn hơn (H1-D1), giữ lệnh lâu hơn, để chi phí nhỏ so với biên độ; dùng S/R như bộ lọc chứ không phải nguồn lợi thế chính. Đây là hướng gợi ý, chưa có bằng chứng riêng cho XAUUSD Exness.

# Nghiên cứu D: Bot công khai / mã nguồn mở cho vàng và forex có kết quả trung thực

Ngày: 2026-09-29. Chỉ nghiên cứu web, không sửa gì trong repo.
Khoảng 18 lần tải trang + 12 lần tìm kiếm.

Mức bằng chứng:
- **proven_with_data**: bài báo có bình duyệt, hoặc backtest công khai có thể chạy lại, có tính phí và có kiểm tra ngoài mẫu (OOS).
- **reported_numbers_unverified**: có số liệu nhưng tôi không tự kiểm lại được (repo cá nhân chưa chạy lại, bài blog, trang review).
- **claim_only**: chỉ là lời nói, thường từ người bán.

---

## 1. Trả lời ngắn cho chủ bot

**"Phương pháp bot nào tốt nhất hiện nay?"**
Không có phương pháp nào được chứng minh công khai là "tốt nhất" cho vàng khung M1/M5.
Phương pháp có bằng chứng mạnh nhất, lâu nhất và đã tính phí là **đi theo xu hướng chậm**
(time-series momentum: nhìn lợi nhuận 1–12 tháng, giữ lệnh vài tuần, chia rủi ro theo biến động,
chạy trên nhiều thị trường, trong đó có vàng). Nhưng lợi nhuận của nó ở mức vừa phải
(Sharpe khoảng 0,4–0,8), có giai đoạn lỗ kéo dài, và nó **không phải bot scalping S/R**.

Ở khung ngắn (M1–M15) trên vàng, mọi dự án công khai trung thực mà tôi tìm được (có dữ liệu bid/ask,
tính phí, có OOS) đều cho kết quả **âm hoặc không phân biệt được với vào lệnh ngẫu nhiên**.
Các EA vàng bán trên thị trường thì hoặc là lưới/gấp thếp (grid/martingale — sẽ cháy khi vàng chạy một chiều),
hoặc là breakout mà kết quả thật kém xa backtest.

**"Tại sao tôi trade tay theo cản được mà code thì sai?"**
Một dự án mã nguồn mở đã làm đúng việc chúng ta đang làm: chuyển Smart Money Concepts (gần với ICT)
thành luật cứng, thử 42 cấu hình × 5 thị trường (có vàng), trả kết quả: **0/210 ô qua được kiểm định**,
walk-forward **−0,33R/lệnh**, và các cấu hình "đẹp" trên vàng vẫn **nằm trong vùng của vào lệnh ngẫu nhiên**.
Nghĩa là kết quả đo của chúng ta (vùng thật bật 43,9% so với vùng giả 41,3%) **không phải lỗi riêng của code mình**:
người khác đo độc lập cũng ra như vậy.

Có ba khả năng, cần kiểm tra chứ không đoán:
1. Chủ bot có thêm bộ lọc trong đầu mà code chưa có (chọn rất ít vùng, bỏ qua ngày xấu, đọc bối cảnh tin tức...).
   Nếu đúng, phải viết các bộ lọc đó ra thành luật rõ ràng rồi đo lại.
2. Kết quả tay chưa được đo đủ: ít lệnh, không tính phí/trượt giá, nhớ lệnh thắng hơn lệnh thua.
   Nghiên cứu lớn ở Brazil: 97% người day-trade bền bỉ trên 300 ngày vẫn lỗ.
3. Có lợi thế thật nhưng nhỏ và chỉ nằm ở vài tình huống (ví dụ: vùng cản cùng chiều xu hướng lớn).
   Repo `xauusd-strategy-backtest` thấy "xu hướng + từ chối tại vùng" có OOS dương (+0,447R)
   nhưng **chỉ 29 lệnh**, khoảng tin cậy vẫn chứa 0 → chưa chứng minh.

Cách kiểm tra công bằng nhất: ghi nhật ký giao dịch tay **trước khi vào lệnh** (ảnh chụp, giá vào, SL, TP, lý do),
tính cả spread + trượt giá, đủ ít nhất 50–100 lệnh, rồi so với vào lệnh ngẫu nhiên cùng giờ, cùng SL/TP.

---

## 2. Các phát hiện chính (mạnh và liên quan nhất trước)

### F1. SMC/ICT viết thành code: không có lợi thế, giống ngẫu nhiên (có vàng)
- Nguồn: https://github.com/AaroNLaU0307/quant-backtest-framework
- Chiến lược: SMC nhiều khung (D1 → H1 → M5), cấu trúc, swing, vùng... viết thành luật.
- Dữ liệu: HistData M1, 2015–2022; 5 thị trường: XAUUSD, EURUSD, GBPUSD, GBPJPY, WTI.
- Phí: spread, commission, swap theo từng mã (mức "retail đại diện").
- Kết quả: walk-forward (IS 18 tháng / OOS 6 tháng) **E[R] = −0,329R**, khoảng tin cậy 95% [−0,416; −0,228];
  11/12 giai đoạn âm. **0/210** ô (cấu hình × mã) sống sót sau kiểm định nhiều phép thử (BH-FDR).
  Trên vàng, 3 cấu hình "sống" chỉ hơn trung bình ngẫu nhiên +0,09 đến +0,14R nhưng nằm ở phân vị 72–91
  của vào lệnh ngẫu nhiên → không khác ngẫu nhiên. Một ô vàng "+2,0R" không lặp lại ở mã khác.
- Mức bằng chứng: repo công khai, phương pháp chặt, nhưng tôi chưa chạy lại → reported_numbers_unverified.

### F2. Vàng M15/M5 pullback và breakout phiên London: âm sau phí, OOS
- Nguồn: https://github.com/VishalKhati/asset-manager-platform
- Dữ liệu: Dukascopy M1 bid/ask hơn 7 năm, có spread, commission, trượt giá; walk-forward + năm 2026 giữ riêng.
- EMA 20/50/200 (M15) + pullback Stochastic (M5) + ATR: **−0,09R/lệnh trên 1.378 lệnh OOS, PF 0,82**;
  năm 2026 giữ riêng: **−0,19R/lệnh**.
- Breakout vùng phiên Á lúc mở phiên London (đăng ký trước): **−0,035R/lệnh trên 611 lệnh OOS**, khoảng tin cậy chứa 0.
- Mức: reported_numbers_unverified.

### F3. Vàng: "xu hướng + từ chối tại vùng" dương nhưng quá ít lệnh
- Nguồn: https://github.com/anirudhatalmale6-alt/xauusd-strategy-backtest
- Dữ liệu: Dukascopy bid/ask phút, 08/2021–08/2026 (1,79 triệu nến), đã đối chiếu với tick.
  Mua ở giá ask, bán ở bid, trượt 5 cent ở lệnh vào và SL, nếu SL và TP cùng phút thì tính thua.
  Không thấy nhắc commission.
- 001A (breakout + retest): IS −0,022R, OOS −0,127R → không có lợi thế.
- 001B (xu hướng + từ chối tại vùng S/R): IS +0,095R (97 lệnh), OOS +0,447R (**29 lệnh**).
  Tác giả tự nói: "chưa chứng minh", nên paper trade thêm.
- Ý nghĩa với ta: hướng "vùng cùng chiều xu hướng lớn, lọc rất chặt, ít lệnh" là giả thuyết đáng thử,
  nhưng chưa phải bằng chứng.
- Mức: reported_numbers_unverified.

### F4. Bài MQL5 về bot vàng M15 (RL) có kết quả live demo trung thực: gần bằng 0
- Nguồn: https://www.mql5.com/en/articles/21314
- XAUUSD M15, ~4 năm dữ liệu, walk-forward có "embargo", nhiều seed; live demo 05–08/2026.
- Mô hình LightGBM nền: AUC trung bình **0,509** (gần tung đồng xu).
- Live: 763 lệnh, lãi +3.589 USD, **PF 1,05**, thắng 45,1%, DD tối đa 4.441 USD, **t = 0,55 (không có ý nghĩa)**.
  Bỏ tháng 6 thì hệ thống lỗ. Trượt giá khi thoát lệnh ≈ −2.370 USD, bằng khoảng 2/3 lợi nhuận.
- Tác giả kết luận: "quy trình chạy tốt, nhưng alpha thì không".
- Bài học cho ta: ở vàng khung ngắn, **trượt giá khi thoát** có thể ăn gần hết lợi thế.
- Mức: reported_numbers_unverified (có live, nhưng tác giả tự báo cáo).

### F5. Đi theo xu hướng chậm: bằng chứng mạnh nhất, đã tính phí (có vàng trong rổ)
- Nguồn: Hurst, Ooi, Pedersen (AQR), "A Century of Evidence on Trend-Following Investing":
  https://www.aqr.com/Insights/Research/Journal-Article/A-Century-of-Evidence-on-Trend-Following-Investing
  (bản PDF: https://www.trendfollowing.com/whitepaper/Century_Evidence_Trend_Following.pdf)
- Cách làm: tín hiệu 1, 3, 12 tháng; lên thì mua, xuống thì bán; chia vốn theo biến động; mục tiêu biến động danh mục 10%/năm;
  hàng hóa, tiền tệ, cổ phiếu, trái phiếu (67 thị trường).
- Phí: commodity một chiều 0,58% (1880–1992), 0,19% (1993–2002), 0,10% (2003–2013); cộng phí quỹ 2/20.
- Kết quả 1880–2013: lợi nhuận gộp 14,9%/năm, sau phí 2/20 là 11,2%/năm, **Sharpe sau phí 0,77**;
  2000–2013 Sharpe sau phí 0,62; mọi thập kỷ đều dương. Tác giả còn lấy giả định thận trọng Sharpe 0,4 cho tương lai.
- Giới hạn: đây là **danh mục nhiều thị trường, khung tháng**, không phải bot vàng một mã, không phải intraday.
  Một mình vàng sẽ yếu hơn nhiều. Đây là mô phỏng (hypothetical), không phải tài khoản thật.
- Mức: proven_with_data (bài bình duyệt, rất nhiều nghiên cứu lặp lại).

### F6. Xu hướng ngắn hạn đã "chết" từ khoảng 2009, nhất là ở hợp đồng tick nhỏ
- Nguồn: Kurth, Eisler, Rej, Bouchaud (07/2026), "Is Trend Still Your Friend?": https://arxiv.org/abs/2607.01550
- ~100 hợp đồng futures 1995–2025 (danh sách có vàng "GOLD0").
- Tín hiệu nhanh (EWMA τ = 5 ngày): Sharpe **0,84 trước 2009 → 0,12 sau 2008**. Xu hướng dài (τ = 50) vẫn còn.
- Phần sụt giảm tập trung ở hợp đồng có "tick nhỏ so với biến động"; ngay cả khi không tính phí vẫn phẳng.
- Bài không nói rõ vàng thuộc nhóm nào. **Suy luận của tôi** (chưa kiểm chứng): tick vàng 0,01–0,10 USD
  rất nhỏ so với biến động ngày vài chục USD → vàng nhiều khả năng thuộc nhóm tick nhỏ.
- Mức: reported_numbers_unverified (bản arXiv mới, chưa bình duyệt; tác giả là nhóm CFM có uy tín).

### F7. Động lượng trong ngày: có thật ở vàng nhưng rất nhỏ, chưa tính phí
- Nguồn: Baltussen, Da, Lammers, Martens (2021), Journal of Financial Economics 142:377–403:
  https://academicweb.nd.edu/~zda/intramom.pdf
- Hơn 60 futures, 1974–2020. Lợi nhuận "từ đầu ngày đến 30 phút cuối" dự báo 30 phút cuối cùng chiều.
- Vàng (GC, 1984–2020): hệ số 1,43, có ý nghĩa 1%; nhưng **R² chỉ 0,23%, R² ngoài mẫu 0,18%** (dự báo rất yếu).
- Danh mục hàng hóa: Sharpe gộp 1,42, lợi nhuận 4,34%/năm với biến động 3,05% — **chưa trừ phí**.
  Tác giả nói rõ: "chúng tôi không xét chi phí giao dịch… có thể không khai thác được với nhiều nhà đầu tư".
- Mức: proven_with_data cho hiệu ứng thống kê; **không** chứng minh có lời sau phí trên XAUUSDm.

### F8. EA vàng thương mại dạng breakout (không grid): live kém xa backtest
- Nguồn: https://newyorkcityservers.com/blog/the-gold-reaper-review (trang bán VPS, có lợi ích quảng cáo)
- The Gold Reaper: breakout vùng S/R nhiều khung, 9 chiến lược con, không grid/martingale.
- Backtest 2020–2024: DD 12,43%, PF 2,72. Live (theo review): lãi +14,98%, **DD 41,66%, PF 1,08**.
- Đây là mẫu điển hình: bot "S/R breakout" trên vàng bán ra, khi chạy thật PF gần 1.
- Mức: reported_numbers_unverified.

### F9. Grid/martingale: đường vốn đẹp rồi cháy; vàng đặc biệt nguy hiểm
- Grid trên vàng: vàng thường chạy một chiều 150–300 USD không hồi (2024–2026), grid chuẩn sẽ bị gọi ký quỹ.
  Nguồn: https://www.mql5.com/en/blogs/post/766446 và https://www.mql5.com/en/forum/507892 (ý kiến, claim_only).
- Waka Waka (grid, AUDCAD/AUDNZD/NZDCAD M15, **không phải vàng**): là tài khoản grid công khai sống lâu nhất
  (từ 2018, "70+ tháng lãi liên tiếp"), nhưng **DD của tài khoản dev vượt 40% đầu năm 2024**,
  một số tài khoản người dùng bị cháy năm 2024. Nguồn: https://newyorkcityservers.com/blog/waka-waka-ea-review
- Grid chỉ "sống lâu" trên cặp tiền đi ngang (AUD/NZD/CAD), không phải trên vàng.
- Bảng xếp hạng MQL5 Signals đổi gần hết tên sau 3–5 năm vì nhiều tài khoản top cháy hoặc DD lớn
  (nguồn: https://www.mql5.com/en/blogs/post/775297 — nhận xét, không có số liệu tổng hợp).
- Tôi **không tìm được** thống kê công khai đáng tin về tỷ lệ sống sót của EA vàng theo loại chiến lược.
  Một bài MQL5 có tiêu đề "dữ liệu Myfxbook nói gì" (https://www.mql5.com/en/blogs/post/772467)
  thực ra không có số liệu tổng hợp nào và tác giả là người bán EA.
- Mức: claim_only / reported_numbers_unverified.

### F10. Tỷ lệ nền: trader cá nhân trong ngày gần như đều lỗ
- Nguồn: Chague, De-Losso, Giovannetti, "Day Trading for a Living?" (2019/2020):
  https://papers.ssrn.com/sol3/papers.cfm?abstract_id=3423101
- Toàn bộ 19.646 người bắt đầu day-trade futures chỉ số Brazil 2013–2015.
  **97% người kéo dài hơn 300 ngày bị lỗ** sau phí; chỉ 1,1% kiếm hơn lương tối thiểu.
- Liên quan: câu "tôi trade tay thấy được" cần nhật ký có phí để kiểm tra; không phải nghi ngờ cá nhân,
  mà vì tỷ lệ nền rất thấp.
- Mức: proven_with_data (dữ liệu toàn thị trường), nhưng không phải vàng và không phải bot.

### Bổ sung (không đưa vào top 10)
- Hsu, Taylor, Wang (2016), J. International Economics 102:188–208: hơn 21.000 luật kỹ thuật trên 30 đồng tiền,
  dữ liệu **ngày**, 45 năm, có kiểm soát data-snooping, phí 2–6 bp, có OOS → có khả năng dự báo.
  Nguồn: https://papers.ssrn.com/sol3/papers.cfm?abstract_id=2765673 (tôi chỉ đọc được tóm tắt qua kết quả tìm kiếm,
  không mở được toàn văn). Đây là khung ngày, không phải M1/M5.
- Chiến lược "vàng qua đêm": giữ vàng chỉ trong phiên ngày gần như phẳng, lợi nhuận nằm ở phần qua đêm,
  nhưng biên rất nhỏ, "có lẽ không giao dịch được sau phí" nếu không lọc thêm.
  Nguồn: https://quantifiedstrategies.substack.com/p/a-quantitative-look-at-the-gold-overnight (blog, chưa kiểm).
- MQL5 forum: backtest vàng với spread 0,20 khác xa spread thật 0,35–0,50 lúc phiên London/NY.
  Nguồn: https://www.mql5.com/en/forum/513663 (ý kiến).

---

## 3. So sánh phí của ta với biên độ (tính nhanh)

- Phí một vòng của ta: spread 0,16 + trượt 0,3 × 2 chân ≈ **0,76 USD**.
- ATR M5 tháng 1/2026 ≈ 4,6 USD → phí ≈ **16% ATR M5**. Nếu SL = 1 ATR M5 thì phí ≈ 0,16R mỗi lệnh.
  Điều này khớp với kết quả đo của ta (−0,15R, giống vào ngẫu nhiên): lợi thế thô gần 0, còn lại là phí.
- Với khung D1 (ATR vài chục USD), cùng mức phí chỉ còn khoảng 1–2% ATR.
  Đây là lý do các bằng chứng tốt đều ở khung chậm.

---

## 4. Gợi ý cho dự án (để chủ bot quyết định, chưa phải kết luận đã kiểm)

1. **Không** dùng grid/martingale cho vàng.
2. Nếu vẫn muốn S/R: đo trước **nhật ký trade tay** của chủ bot (ghi trước khi vào lệnh, có phí), rồi mới viết code bắt chước.
   Viết code từ "mọi pivot/FVG/OB" đã được chứng minh là quá dày và giống ngẫu nhiên (của ta và F1).
3. Thử giả thuyết hẹp: "vùng S/R cùng chiều xu hướng H4/D1, rất ít vùng, SL rộng hơn (H1 thay vì M1/M5)",
   so với vào lệnh ngẫu nhiên cùng điều kiện, có OOS đăng ký trước (như F3), và đủ lệnh (>100 OOS).
4. Nếu mục tiêu là "phương pháp có bằng chứng nhất": xu hướng chậm (H4/D1, giữ nhiều ngày, SL theo ATR, rủi ro nhỏ mỗi lệnh).
   Kỳ vọng thực tế: Sharpe dưới 1, có năm lỗ, và trên một mã (vàng) sẽ kém hơn danh mục nhiều thị trường.

---

## 5. Nguồn đã dùng
- https://github.com/AaroNLaU0307/quant-backtest-framework
- https://github.com/VishalKhati/asset-manager-platform
- https://github.com/anirudhatalmale6-alt/xauusd-strategy-backtest
- https://www.mql5.com/en/articles/21314
- https://www.aqr.com/Insights/Research/Journal-Article/A-Century-of-Evidence-on-Trend-Following-Investing
- https://www.trendfollowing.com/whitepaper/Century_Evidence_Trend_Following.pdf
- https://arxiv.org/abs/2607.01550
- https://academicweb.nd.edu/~zda/intramom.pdf
- https://newyorkcityservers.com/blog/the-gold-reaper-review
- https://newyorkcityservers.com/blog/waka-waka-ea-review
- https://www.mql5.com/en/blogs/post/766446
- https://www.mql5.com/en/forum/507892
- https://www.mql5.com/en/blogs/post/775297
- https://www.mql5.com/en/blogs/post/772467
- https://www.mql5.com/en/articles/23928 (chỉ là bài dạy phương pháp, không có dữ liệu sống sót thật)
- https://papers.ssrn.com/sol3/papers.cfm?abstract_id=3423101
- https://papers.ssrn.com/sol3/papers.cfm?abstract_id=2765673
- https://quantifiedstrategies.substack.com/p/a-quantitative-look-at-the-gold-overnight
- https://www.mql5.com/en/forum/513663

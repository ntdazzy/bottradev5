# Nghiên cứu B: Người chạy bot S/R thật sự chọn mức giá thế nào và kết quả ra sao

Phạm vi: có 16 lượt tìm/tải trang. Reddit và ForexFactory chặn công cụ tải trang (lỗi 403 hoặc không truy cập được), nên phần "cộng đồng" chủ yếu lấy từ blog MQL5, GitHub, bài học thuật, EliteTrader và các blog. Mọi con số dưới đây là con số do nguồn tự báo cáo, tôi chưa tự kiểm lại.

## 1. Mức giá nào quan trọng: bằng chứng học thuật (đáng tin nhất)

**Có số liệu**
- Osler 2000 (Fed New York) lấy mức S/R mà 6 công ty FX gửi cho khách, giai đoạn 1996–98. Giá bật lại ở mức được công bố **60,8%**, ở mức giả ngẫu nhiên **56,2%**. Chênh lệch chỉ khoảng 4,6 điểm %, dù mức thật thắng trong cả 16/16 cặp công ty-tiền tệ. Tác dụng còn ít nhất 5 ngày. → Mức "thật" chỉ hơn mức ngẫu nhiên **một chút**, khớp với đo đạc của ta (vùng thật gần như không hơn vùng giả). https://ideas.repec.org/a/fip/fednep/y2000ijulp53-68nv.6no.2.html , https://www.researchgate.net/publication/5050393
- Osler 2001/2003 dùng 9.667 lệnh chờ thật của NatWest. Lệnh chốt lời (TP) dồn **đúng** vào số tròn: 9,3% TP khớp ở mức đuôi "00", trong khi lệnh cắt lỗ chỉ 4,4%. Lệnh cắt lỗ lại dồn **ngay sau** số tròn: stop mua nằm ngay trên, stop bán nằm ngay dưới. Hệ quả: giá hay **dừng/đảo đúng tại** số tròn, còn nếu **vượt qua** thì hay chạy nhanh. https://www.newyorkfed.org/medialibrary/media/research/staff_reports/sr125.pdf
- arXiv 2101.07410: mức S/R nào đã bật **nhiều lần** thì dễ bật tiếp, và khả năng bật **giảm dần theo thời gian**. Cả hai hiệu ứng đều có ý nghĩa thống kê. https://arxiv.org/abs/2101.07410

## 2. Mức ngày trước / phiên (PDH/PDL, vùng giá phiên Á, mở cửa)

**Có số liệu**
- Edgeful (futures YM, 6 tháng, phiên NY): khi giá phá đỉnh ngày trước (PDH) thì 67% phiên đóng cửa tăng; khi phá đáy ngày trước (PDL) thì 62% phiên đóng cửa giảm. Nguồn kết luận: PDH/PDL là **tín hiệu đi tiếp theo hướng phá**, không phải chỗ đảo chiều. Lưu ý: mẫu nhỏ, không phải vàng, và là trang bán công cụ. https://www.edgeful.com/blog/posts/previous-days-range-trading-mistake
- GitHub xauusd-backtest: chiến lược "quét PDH/PDL rồi đảo" trên XAUUSD, khung 15m, 4.547 lệnh, tỉ lệ thắng 71%. Nhưng **không tính spread, không trượt giá, không có R**. Con số này không dùng được. https://github.com/ikeawesom/xauusd-backtest/blob/main/README.md
- GitHub ShiTmoZ/forex: phá vùng giá phiên Á hoặc "Judas swing" (giá đâm qua đỉnh/đáy phiên Á rồi quay lại). Có tính spread. Kết quả 5.259 lệnh, thắng 28,9%, RR 1:2, dời về hòa vốn khi đạt 1R. Với các thông số này, kỳ vọng xấp xỉ 0 hoặc âm, **không có kiểm tra ngoài mẫu**. https://github.com/ShiTmoZ/forex

**Người ta nói (không có số kiểm chứng)**
- Chiến lược "London quét vùng giá phiên Á rồi đảo" trên vàng được mô tả rất nhiều, nhưng toàn trên trang bán chỉ báo hoặc khóa học. https://grandalgo.com/blog/asian-session-trading-strategy , https://www.tradingview.com/script/4IevbowH-Asia-Liquidity-Sweep-Reversal-Scalper-GC-Gold-Strategy/
- Có trang nói vàng "phá giả 62% trong ngày". Không rõ phương pháp đo, trang mang tính quảng cáo. https://fortraders.com/blog/false-breakouts-why-they-happen-how-to-trade

## 3. Chi phí giết lợi thế nhỏ (bài học quan trọng nhất cho M1/M5)

**Có số liệu**
- Blog MQL5 (25/09/2026) chạy lại chiến lược phá vùng mở cửa (ORB) 5 phút trên 5 chỉ số CFD, dữ liệu 2015–2026. Trước chi phí đúng như bài báo gốc: NQ +0,131R, SPX +0,119R, DAX +0,116R. Sau khi trừ spread và trượt giá, **về khoảng 0 hoặc âm**: NQ +0,002R, SPX −0,081R, DAX −0,038R. Kiểm tra đối chứng (vào lệnh ngẫu nhiên với cùng SL/TP) cho thấy tín hiệu có thật, nhưng chỉ khoảng 0,1R, vừa đủ để chi phí ăn hết. Tác giả còn đặt quy tắc: rủi ro ban đầu phải ≥ 2 lần chi phí khứ hồi, nếu không phần chi phí trên mỗi lệnh sẽ "nổ". https://www.mql5.com/en/blogs/post/776235
- Chạy lại ORB trên QQQ: hòa vốn khi trượt giá khoảng 2,2 cent/cổ phiếu, và **76% lợi nhuận đến từ riêng năm 2022**. Các năm 2017, 2020, 2023 lỗ. https://github.com/giovannibrusco/zarattini-2023-orb-qqq
- → Suy ra: lợi thế của S/R, dù có thật, chỉ khoảng 4–5 điểm % tần suất bật (Osler), tức cỡ 0,1R. Với SL rất hẹp trên M1, spread vàng dễ chiếm phần lớn R. Điều này khớp với kết quả −0,15R của ta.

## 4. Bot/EA S/R trên MQL5, ForexFactory, EliteTrader

**Người ta nói**
- Các bài MQL5 dạy làm EA S/R thường chọn vùng theo "đỉnh/đáy swing chạm ≥ 2 lần" và chỉ đưa kết quả rất nhỏ, không tính chi phí, không kiểm tra ngoài mẫu. Ví dụ: XAGUSD M15 2017–2025 chỉ 136 lệnh, lãi $588, không nói chi phí. https://www.mql5.com/en/articles/17049 , https://www.mql5.com/en/articles/20021
- EliteTrader: "ai cũng có một backtest có lời; thử 20 thứ thì chắc có 1 thứ trông có ý nghĩa ở mức 5% chỉ do may mắn". Có người bỏ hẳn lệnh stop đặt ngay tại mức S/R vì bị quét. https://www.elitetrader.com/et/threads/backtesting-and-optimization-discussion.190116/
- Các thread ForexFactory về scalping vàng M1 bằng S/R hoặc EA S/R (tôi không đọc được nội dung vì bị chặn) chủ yếu là mô tả phương pháp và lời hứa forward test. Tôi không tìm thấy kết quả forward test dài hạn có số liệu. https://www.forexfactory.com/thread/1389918-scalping-method-on-m1-with-trend-and-resistancesupport , https://www.forexfactory.com/thread/261327-support-resistance-ea

## 5. Số tròn trên vàng

**Người ta nói, kèm "số liệu" chưa kiểm chứng**
- Pro-Scalper nói: trên H1, XAUUSD phản ứng ≥ 50 pip ở các mức $100/$500 khoảng 61% số lần, đo trên 24 tháng, có loại nến tin tức. Không có mức đối chứng ngẫu nhiên, và là trang bán hàng. https://www.pro-scalper.com/xauusd-strategies/gold-round-number-strategy
- Cơ chế thì có nền học thuật (mục 1, Osler). Tuy nhiên dữ liệu Osler là FX năm 1999–2000, **chưa ai chứng minh trên vàng M1**.

## Nhận xét chung
- Không tìm thấy nguồn độc lập nào có kết quả **dương sau chi phí và ngoài mẫu** cho bot S/R scalping vàng M1/M5.
- Nguồn nghiêm túc nhất đều nói hai điều: lợi thế S/R là có nhưng nhỏ, và chi phí ăn hết lợi thế nhỏ đó.
- Nhiều nguồn cho thấy PDH/PDL hay dẫn đến **đi tiếp** hơn là đảo chiều.

## 3–5 ý tưởng cụ thể, đáng tin nhất cho bot
1. **Cắt mạnh số vùng: chỉ giữ vài mức "khách quan" mà cả thị trường cùng nhìn.** Gồm PDH/PDL, đỉnh/đáy tuần trước, đỉnh/đáy phiên Á, và số tròn $10/$50/$100. Mỗi ngày chỉ nên còn khoảng 4–8 mức. Sau đó đo lại với **đối chứng ngẫu nhiên đúng cách** như Osler: mức giả đặt cùng khoảng cách tới giá. Nếu tần suất bật không hơn mức giả ≥ 4–5 điểm % thì dừng. (Osler; arXiv 2101.07410)
2. **Thêm hai đặc trưng có bằng chứng: số lần đã bật và độ "tươi" của mức.** Mức bật nhiều lần có trọng số cao hơn; mức cũ thì giảm trọng số hoặc bỏ (ví dụ quá 5 ngày giao dịch). (arXiv 2101.07410; Osler 5 ngày)
3. **Tách hai kịch bản ở số tròn và PDH/PDL:** chạm đúng mức rồi đảo (TP của người khác nằm ở đó), và vượt qua mức rồi chạy tiếp (stop nằm ngay sau mức). Đặt SL **không ngay sau** số tròn hoặc mức cực trị, vì đó là chỗ stop bị dồn. Nên kiểm tra cả hướng "phá rồi đi tiếp" chứ không chỉ "đảo chiều". (Osler 2001; Edgeful)
4. **Bắt buộc lọc chi phí:** chỉ vào lệnh khi SL ≥ khoảng 3–5 lần (spread + trượt giá), và R mục tiêu đủ lớn. Nếu SL M1 quá hẹp thì chuyển sang vào lệnh trên M5 hoặc M15. Luôn báo cáo R trước chi phí và R sau chi phí, cạnh kết quả vào lệnh ngẫu nhiên cùng SL/TP. (Blog MQL5 ORB; replication QQQ)
5. **Kiểm tra độ bền:** chia kết quả theo năm và theo phiên (Á/London/NY). Nếu lợi nhuận dồn vào một giai đoạn, như 76% trong một năm ở replication QQQ, thì coi là không có lợi thế.

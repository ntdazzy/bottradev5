# Đề xuất thiết kế BotVang v1: vùng cản, vào lệnh, dừng lỗ, chốt lời, lọc đi ngang và lệnh đảo

## 0. Cách đọc và kết luận quan trọng nhất

**Cách đánh dấu trong bài:**
- **[BẰNG CHỨNG]**: có nghiên cứu hoặc mã đã được người kiểm tra xác nhận.
- **[GIẢ ĐỊNH]**: là thiết kế hoặc ngưỡng tôi chọn, chưa có dữ liệu chứng minh.
- **[SAI/CHƯA KIỂM]**: bên kiểm tra kết luận sai, hoặc không mở được nguồn. Dùng thận trọng.

**Kết luận chính:**
1. Không có nguồn nào kiểm tra, có đối chứng, câu hỏi: "lần chạm lại đầu tiên của một vùng vừa lật có lợi thế không". Các nghiên cứu hiện có chỉ xét mức chưa bị phá.
   - Osler 2000 là nguồn tốt nhất. Mức S/R do chuyên gia công bố bật lại 60,8%, mức ngẫu nhiên 56,2%. Lợi thế chỉ khoảng 4–5 điểm %. (https://www.newyorkfed.org/medialibrary/media/research/epr/00v06n2/0007osle.pdf)
2. Trong phần bổ sung, người nghiên cứu tự chạy kiểm tra trên futures vàng GC=F. Phần này **chưa được người kiểm tra xác nhận**, dữ liệu M5 chỉ có 10 tuần.
   - Lần chạm lại đầu của vùng lật có xác suất đi đúng mỗi bậc là p ≈ 0,46–0,51. Vùng ngẫu nhiên cho 0,50–0,51. Mức hòa vốn là p* ≈ 0,51–0,53.
   - Vào theo hướng phá (tức lệnh đảo) có p ≈ 0,46 trên M5.
   - Tự tương quan của vàng ở khung 5–60 phút gần bằng 0.
   - Đây là tín hiệu cảnh báo, chưa phải kết luận.
3. Nếu giá không có quán tính, mọi cách đặt SL, dời SL hay đảo lệnh đều cho kỳ vọng khoảng **−spread mỗi lệnh**. [BẰNG CHỨNG lý thuyết: Kaminski & Lo 2014, https://ideas.repec.org/p/hhs/sifrwp/0063.html; mô hình Brown đã được tính lại.]
   - Nghĩa là lợi thế chỉ có thể đến từ **điều kiện vào lệnh**, không đến từ cách quản lý lệnh.
   - Vì vậy mọi phần dưới đây được viết thành **cài đặt để chạy lại dữ liệu cũ, có vùng giả làm đối chứng**, không phải là sự thật đã được chứng minh.

**Hai công thức hòa vốn dùng xuyên suốt** (s = spread ≈ 0,25 USD). Đã kiểm lại bằng số học.
- Thang bậc dời SL, mỗi bậc là cược 1:1: p* = (B+s)/(2B+s). Với B = 1,5 thì p* ≈ 0,538; với B = 3 thì p* ≈ 0,52.
- Lệnh đảo, hoặc một bậc +1B so với −1B: p* = 0,5 + s/(2B). Với B = 1,25 thì cần 60%; B = 2,5 cần 55%; B = 3,2 cần 53,9%.

---

## 1. Cách tính vùng cản

### 1.1 Nguyên tắc chung
- Chỉ dùng nến đã đóng. Dữ liệu khung lớn lấy từ shift ≥ 1.
- Không dùng `lookahead`. Mã okinawan21 bị rò dữ liệu tương lai. [BẰNG CHỨNG, đã đọc mã: https://www.tradingview.com/script/t49SbqQG/]
- Mọi ngưỡng tính theo ATR, không theo point. Các bài MQL5 dùng "30 points" thì trên XAUUSDm chỉ còn 0,03–0,30 USD, vô nghĩa.

### 1.2 Nguồn sinh vùng

| Loại | Công thức | Khung | Nguồn / mức tin |
|---|---|---|---|
| A-level | `pivothigh(close,3,3)`, tức đỉnh xét trên giá đóng cửa | M15, H1 | Mã Malaysian SnR [DoN] đã đọc: https://www.tradingview.com/script/iWgxW7bW/ [BẰNG CHỨNG về mã, không có số liệu hiệu quả] |
| V-level | `pivotlow(close,3,3)` | M15, H1 | Như trên |
| Gap level | Hai nến cùng màu liên tiếp; mức = close nến đầu (≈ open nến sau) | H1, H4 | DoN dùng open[1] của nến H4 đã đóng nên không vẽ lại |
| Swing | Fractal 3/3 hiện có, hoặc ZigZag theo ATR: xác nhận đỉnh khi low < đỉnh tạm − 1·ATR(14) của khung | M15, H1 | neurotrader (mã đã đọc): https://github.com/neurotrader888/market-structure/blob/main/atr_directional_change.py [GIẢ ĐỊNH là tốt hơn fractal] |
| PDH/PDL | `iHigh/iLow(PERIOD_D1,1)` | D1 | Chưa có nghiên cứu riêng cho vàng; cần kiểm tra giờ server và nến Chủ nhật |
| Số tròn | Chỉ bội số $50 và $100 | – | Chỉ dùng làm điểm cộng (mục 2), không tự thành vùng |

**Lọc Gap theo động lượng.** Nguồn là MQL5 20904 (https://www.mql5.com/en/articles/20904), bài chỉ **mô tả** trên XAUUSDr M5 và không đo kết quả tương lai.
- Thân nến đầu ≤ 0,3·ATR(14). Đây là ngưỡng chính bài viết đề xuất; người nghiên cứu ban đầu ghi 0,5 là lỏng hơn.
- Thân nến sau ≥ 3 × thân nến đầu và ≥ 0,5·ATR(14).
- Loại nến sau có thân > 3,5·ATR [GIẢ ĐỊNH]. Cụm "tin tức" trong bài có thân exit trung bình 6,39 ATR.

**Lọc swing lỗi thời** [GIẢ ĐỊNH, từ FractalSRClusters đã đọc mã: https://github.com/dshea89/FractalSRClusters]: chỉ giữ một đỉnh khi đáy đã tạo ra đỉnh đó chưa bị phá.

**Loại nến tin tức khỏi việc dựng vùng:** bỏ nến có biên độ ≥ 2·ATR(200). Lấy từ mã LuxAlgo SMC đã đọc: https://www.tradingview.com/script/CnB3fSph-Smart-Money-Concepts-SMC-LuxAlgo/

### 1.3 Độ rộng vùng [lo, hi]
- Theo MSnR: từ mức close đến râu của nến pivot (DoN).
- **Kẹp độ rộng** trong khoảng [max(0,15·ATR_TF, 2·spread), 0,5·ATR_TF] [GIẢ ĐỊNH].
- Lý do kẹp:
  - Vùng kiểu Shved cao 0,75–1,125·ATR(7) của khung vùng (mã đã xác nhận: https://github.com/khiladi23295/Indicators/blob/main/shved_supply_and_demand_v1.7.mq5).
  - Vùng kiểu Matrix cao 2·ATR(200).
  - Trên H1, cả hai rộng hơn nhiều so với bước SL 0,8·ATR(M5).
  - Tỉ lệ ATR(H1)/ATR(M5) ≈ 3–3,5 chỉ là **suy luận, chưa đo**.
- Band dày làm tỉ lệ "bật" cao lên giả tạo. Theo Osler 2000, khi dung sai bằng 0% thì mức ngẫu nhiên bật dưới 50%. Chung & Bellotti cũng nói δ lớn làm p(b) phồng lên (https://arxiv.org/pdf/2101.07410). [BẰNG CHỨNG]

### 1.4 Gộp vùng
- Gộp hai vùng cùng phía khi chúng chồng lấn, hoặc khi |mức_i − mức_j| < 0,1·ATR(200) của khung. Đây là ngưỡng đỉnh/đáy bằng nhau của LuxAlgo SMC [BẰNG CHỨNG về mã].
- Trần độ rộng sau khi gộp là 1·ATR_TF. Vượt trần thì giữ riêng, ưu tiên vùng mạnh hơn [GIẢ ĐỊNH].
- **Không chép luật gộp của Shved.** Khi gộp, Shved cộng dồn số lần chạm, và gán luôn hits = 1 cho vùng chưa từng được chạm, nên độ mạnh bị thổi phồng (bên kiểm tra đã xác nhận).
- Cách làm đề xuất: số lần chạm lấy **max**, không lấy tổng; khung lấy khung lớn nhất; ghi thêm một cờ "hợp lưu".

### 1.5 Máy trạng thái của vùng
- **fresh → touched:** râu đi vào band **sau khi** giá đã rời vùng ≥ 0,5·ATR_TF. Hai lần chạm cách nhau ≥ 10 nến (Shved). Nguồn: luật `readyForTest` của MQL5 19674 và Demand Supply Matrix. [GIẢ ĐỊNH về ngưỡng]
- **broken:** **thân nến đóng qua mép XA** của band.
  - Shved dùng râu. DoN dùng đường mức, không dùng mép xa.
  - Không nguồn nào chứng minh thân tốt hơn râu. Đây là lựa chọn của bot, cần tự đo.
- **flipped:** đổi vai trò và đặt lại số lần chạm về 0, như Shved "forget previous hits". Nên lưu số lần bật trước khi lật thành một đặc trưng riêng để kiểm định.
- **invalid:** vùng bị hủy khi có một trong các điều sau:
  - Thân nến đóng ngược lại qua mép xa. Đây là luật Breaker của LuxAlgo và luật lịch sử SBR/RBS của DoN (mã đã đọc: https://www.tradingview.com/script/piIbWMpY-Order-Blocks-Breaker-Blocks-LuxAlgo/).
  - Bị phá lần thứ hai.
  - Đã dùng lần chạm lại đầu.
  - Hết hạn.
- **Hạn dùng:** vùng M15 sống 1–2 ngày; vùng H1/H4/PDH/PDL sống 5 ngày làm việc [GIẢ ĐỊNH].
  - Osler 2000: sau 5 ngày mức vẫn còn tác dụng nhưng yếu đi 1,7 điểm %, và chỉ còn có ý nghĩa ở 9/16 trường hợp. Đây là dữ liệu FX 1996–98.

---

## 2. Cách chấm độ mạnh của vùng

### 2.1 Bằng chứng nói gì
- **Điểm độ mạnh do người chấm tay và độ hợp lưu KHÔNG dự báo được** [BẰNG CHỨNG mạnh, Osler 2000, bảng 11–12].
  - So hạng 2 với hạng 1: mọi chênh lệch có ý nghĩa đều âm.
  - Mức được nhiều công ty đồng thuận không tốt hơn; kết quả có ý nghĩa duy nhất lại cho thấy kém hơn.
  - Đây là bằng chứng quan trọng nhất chống lại bảng cộng điểm "khung + hợp lưu".
- **Số lần bật trước.** Garzarelli 2014 (https://pmc.ncbi.nlm.nih.gov/articles/PMC3967202/) và Chung & Bellotti 2021 đều thấy p(bật) tăng theo số lần bật trước, so với chuỗi xáo trộn. Nhưng có ba giới hạn:
  - Garzarelli có **hai bản số liệu mâu thuẫn**. Bảng 1 bản arXiv v1 cho p < 0,0001 ở 45/60/90 giây. Bảng trên PMC cho p = 0,13/0,17 ở 90 giây. Cả hai bản đều mất ý nghĩa ở 180 giây. Vậy hiệu ứng chỉ ở thang **dưới 1–3 phút**, gần như không áp dụng được cho M5/M15. [SAI một phần ở báo cáo ban đầu]
  - Chung & Bellotti, cửa sổ 600 phút: mức mới bật 1 lần có p ≈ 0,50 (EURUSD), 0,54 (LLOY), **0,46 (BRENT)**. Chỉ mức bật 4 lần mới đạt khoảng 0,60.
  - Con số 350 và 900 phút là **độ dài cửa sổ dùng để tìm mức**, không phải tuổi của vùng.
- **Số lần chạm làm vùng mạnh hay yếu đi?** Chưa kết luận được.
  - OTA/Seiden ("lần đầu 2 điểm, lần ba 0 điểm") và SMC ("đỉnh bằng nhau sẽ bị quét") không có số liệu.
  - Kiểm tra tự chạy trên GC=F (chưa được xác nhận) thấy p giảm dần theo số lần chạm **ở cả vùng thật lẫn vùng giả**, tức đây là hiệu ứng cơ học.
  - Kết luận: **không trừ điểm vì số lần chạm, và cũng không cộng nhiều**. Chỉ đếm lần "bật thật", tức giá ra khỏi band rồi quay lại, không đếm lúc giá đi ngang trong band.
- **Độ mới theo thời gian:** có cơ sở là mức yếu dần theo thời gian (Osler, Chung). Còn "mới theo nghĩa chưa ai chạm" thì **không có bằng chứng**.
- **Số tròn:** Osler 2003/2005 cho thấy lệnh chốt lời dồn tại 00, lệnh dừng lỗ dồn ngay bên kia số tròn.
  - SR125: TP 9,3%, SL 4,4%. SR150: 9,9% và 3,8%. Stop mua ở đuôi 01–10 chiếm 14,3–14,4%, ở 90–99 chỉ 6,9–7,4%. (https://www.newyorkfed.org/medialibrary/media/research/staff_reports/sr150.pdf)
  - Bằng chứng gần vàng nhất là tickbench, dữ liệu tick Exness 2020–2025, chưa qua bình duyệt (https://raw.githubusercontent.com/datxbt/tickbench/main/docs/findings/level-interaction.md). Kết quả: **vàng xuyên qua số tròn chứ không bật lại**.
  - Thứ tự khi phá là $100 > $50 > $10, nhưng chỉ do xu hướng tăng; sau khi trung hòa xu hướng thì không có ý nghĩa.
- **Trọng số khung, lực rời vùng, thời gian nằm trong vùng, tick volume:** không có bằng chứng.

### 2.2 Công thức tạm, chỉ dùng làm điểm xuất phát rồi thay bằng dữ liệu

```
Score_prior = min(b_prev,4)·1.0              // số lần bật thật TRƯỚC khi lật (lưu riêng)
            + RN·w_rn                          // xx00: 1.0, xx50: 0.6, xx10: 0 (cờ bật 0.25 sau khi đo), $5/$1: 0
            + 1.0 nếu gốc có động lượng (lọc Gap mục 1.2, hoặc nến phá đạt ngưỡng mục 3.1)
            + 0.5 nếu khung ≥ H1
            + 0.25 mỗi nguồn trùng (tối đa 0.5)
Score = Score_prior × w_age,   w_age = exp(−Δt/τ)
τ = 6–12 giờ cho vùng M15;  2–5 ngày cho H1/H4/PDH/PDL
```

- Tất cả trọng số là **[GIẢ ĐỊNH]**.
- Điểm số tròn tối đa khoảng 10% thang điểm, và không bao giờ tự đủ để thành tín hiệu.
- Chỉ cộng điểm số tròn khi vùng lật bị phá bằng thân nến xuyên qua số tròn.
- Lý do không cộng cho $10: một vùng rộng $2 có khoảng 30% khả năng tình cờ chứa một mức $10, nên điểm này sẽ bị rải gần như ngẫu nhiên.

### 2.3 Hiệu chỉnh bắt buộc
Thay điểm cộng tay bằng xác suất đo được: p̂ = (n+1)/(N+2) cho từng nhóm. Chỉ giữ yếu tố nào làm p̂ cao hơn **vùng giả cùng độ rộng** ít nhất 3–5 điểm %, và p̂ phải tăng đều theo các nhóm điểm (quintile). Đây đúng là chỗ bảng điểm của các ngân hàng trong Osler đã thất bại.

---

## 3. Cách vào lệnh

### 3.1 Định nghĩa "phá" để lật vùng
Ví dụ cho vùng kháng cự lật thành hỗ trợ. Một nến đã đóng phải thỏa:
- `close > hi + kB·ATR(M5)`. Mặc định kB = 0,16 (AGPro; mã đã đọc: https://www.tradingview.com/script/W32TURZ3-Breakout-Retest-Readiness-AGPro-Series/).
- `close[1] ≤ hi + 0,25·kB·ATR`, tức nến này vừa cắt qua chứ không phải đã ở ngoài từ trước.
- Thân nến ≥ 50% biên độ, **hoặc** (close−low)/(high−low) ≥ 0,6 [GIẢ ĐỊNH].
- Tùy chọn: biên độ nến phá ≥ 1,5 × chiều cao band (MQL5 21677, mã đã đọc, không có số liệu: https://www.mql5.com/en/articles/21677).
- Giá đóng không nằm trong một vùng mạnh khác (LonesomeTheBlue).
- Cân nhắc đo cú phá trên nến M15 khi vùng thuộc M15/H1 [GIẢ ĐỊNH, cần A/B].

**Lọc phá giả (kiểu Turtle Soup):** nếu trong 1–2 nến M5 sau cú phá có giá đóng quay lại trong band, thì **hủy việc lật vùng**. Vùng giữ vai trò cũ.
- Cơ sở gián tiếp: stop dồn ngay sau mức, nên râu vượt qua rồi quay lại thường chỉ là quét stop (Osler 2005). [BẰNG CHỨNG gián tiếp, FX]

### 3.2 Giá rời xa và lần chạm đầu
- Chỉ tính là chạm lần đầu khi:
  - giá đã đi ≥ 0,34·ATR(M5) ra ngoài mép vùng (AGPro), **và**
  - đã qua ≥ 2 nến kể từ nến phá (HoanGhetti `retSince=2`, mã đã đọc: https://www.tradingview.com/script/Xeeko6TV-Support-Resistance-with-Breaks-and-Retests/).
- Lưu ý: điều kiện `max(0,35·ATR, 1·B)` trong đề xuất ban đầu **luôn bằng B**, vì B ≥ 0,8·ATR. Như vậy nó chặt gấp khoảng 2,4 lần AGPro. Chỉ giữ nếu cố ý chọn.
- Định nghĩa chạm: nến có phần giao với band **và** open nằm đúng phía (DoN, kiểu `open > lvl AND low <= lvl`). Sau lần chạm này, đánh dấu vùng là "đã dùng" vĩnh viễn, kể cả khi không vào lệnh (NoRetrade, MQL5 19674).
- **Cho phép giá đâm sâu vào band**, miễn là sau đó có close quay ra ngoài.
  - Bulkowski, cổ phiếu khung ngày: chỉ khoảng 13% lần quay lại giữ được trên giá phá, 87% xuyên xuống dưới (https://thepatternsite.com/throwbacks.html). Nếu bắt buộc "chạm nông" thì sẽ loại gần hết setup. [BẰNG CHỨNG, nhưng là cổ phiếu]

### 3.3 Nến xác nhận và hủy setup
- **Xác nhận:** trong chính nến chạm hoặc tối đa 2 nến M5 sau đó, có một nến thỏa đủ ba điều: `close > hi`, `close > open`, `(close−low)/(high−low) ≥ 0,6`.
- **Không đòi pin bar hay engulfing chuẩn sách.**
  - Duvinage 2013: dữ liệu 5 phút DJIA, sau phí và hiệu chỉnh việc thử quá nhiều luật (SSPA), không luật nến nào thắng (https://ideas.repec.org/p/ajf/louvlr/2013001.html). [BẰNG CHỨNG]
  - Fock 2005 [CHƯA KIỂM]: các nguồn thứ cấp mâu thuẫn nhau.
- **Hủy setup** khi có một trong hai điều:
  - close < giữa band (LuxAlgo Breaker Blocks, mã đã đọc);
  - close < hi − 0,74·ATR (mức "risk edge" của AGPro).
- Không dùng ngưỡng "1,35·ATR" làm điều kiện hủy. Trong mã AGPro, con số đó chỉ là mốc của hàm tính điểm. [SAI ở báo cáo ban đầu]

### 3.4 Kiểu vào lệnh
- **Mặc định:** lệnh market ở giá mở nến kế tiếp sau nến xác nhận.
  - Bulkowski ThrowbackEntry: cách tốt nhất trong ba cách ông thử là chờ giá đóng vượt lại rồi vào ở giá mở nến sau.
- **Phương án thử:** BUY STOP tại max(high nến chạm, high nến xác nhận) + spread, hết hạn sau 2 nến.
- **Lệnh limit tại vùng:** chỉ chạy dạng "bóng", tức ghi lại chứ không đặt thật.
  - Lệnh limit hay khớp đúng lúc bất lợi: Linnainmaa 2010 (https://onlinelibrary.wiley.com/doi/abs/10.1111/j.1540-6261.2010.01576.x), DeLise 2024, Albers 2025. [BẰNG CHỨNG, thị trường khác]
- **Lọc đuổi giá:** bỏ lệnh nếu entry − (lo − 0,2·ATR) > 1,2·B, vì khi đó SL 1 bước sẽ nằm trong vùng [GIẢ ĐỊNH].
- **Lọc khoảng trống phía trước:** xem mục 5.

### 3.5 Thời hạn chờ
- Chờ lần chạm đầu tối đa 24 nến M5 (2 giờ, theo AGPro). Thử thêm 36.
- Hoặc bỏ khi giá đã đi xa hơn 3·B mà chưa quay lại [GIẢ ĐỊNH].
- Hết thời hạn thì chỉ hạ điểm của vùng, không xóa vùng.

**Cảnh báo:** Bulkowski cho thấy khoảng 40% cú phá không có lần quay lại, và 97% loại mẫu hình cho kết quả tốt hơn khi KHÔNG có lần quay lại (https://thepatternsite.com/studystudy.html). Chỉ vào ở lần chạm lại nghĩa là **tự chọn ra các cú phá yếu hơn**. Chưa có số liệu nào cho vàng trong ngày.

---

## 4. Dừng lỗ ban đầu và dời dừng lỗ

### 4.1 Đánh giá thiết kế hiện tại
Thiết kế hiện tại (đọc từ `Engine.mqh`):
- B = max(0,8·ATR(M5), 5·spread), cố định lúc vào lệnh.
- Lệnh mua vào ở Ask, SL = Ask − B. Bậc được đo theo Bid. Vì vậy giá phải đi **B + s** mới lên bậc 1, trong khi khoảng cách tới SL chỉ còn **B − s**.

Các con số từ mô hình Brown (bên kiểm tra đã tính lại; σ = ATR/1,6 là giả định):
- Xác suất nhiễu chạm SL ngay trong nến M5 đầu: 0,26 với SL = 0,8·ATR; 0,15 với 1,0·ATR; 0,03 với 1,5·ATR.
- Nếu giá không có xu hướng, kỳ vọng mỗi lệnh = −s/B tính theo R: −0,125R khi B = 2; **−0,20R khi B chạm sàn 5·spread**.
- Nếu có xu hướng kéo dài, độ trễ dời SL lớn hơn và B rộng hơn sẽ ăn được nhiều hơn. Ví dụ B = 1,2·ATR với trễ 2 bậc cho khoảng +1,0R. Nhưng kết quả này dựa trên giả định xu hướng kéo dài vô hạn, **không phải dự báo**.

Bằng chứng thực nghiệm đều là cổ phiếu/chỉ số, khung ngày hoặc tháng. Hướng chung: **SL càng chặt càng tệ sau chi phí.**
- Lo & Remorov 2017 (https://doi.org/10.2139/ssrn.2695383).
- Clare và cộng sự 2013: lợi suất cao nhất khi dời SL ở mức 12% (https://openaccess.city.ac.uk/id/eprint/17842/).
- Dai 2021: đúng về chiều hướng, nhưng ngưỡng "10%" [CHƯA KIỂM].
- Kaminski & Lo: chính bài báo ghi rằng quy tắc dừng lỗ ngắn hạn cho phần bù âm trên một dải tham số rộng.

Các nguồn cần bỏ qua:
- Glynn & Iglehart ("không dời SL là tối ưu") [CHƯA KIỂM], và câu này phát biểu cho trường hợp có xu hướng dương.
- Bài MQL5 16991 ("dời SL theo DEMA +1.397 USD") [SAI]. Thực tế có 1.942 deal, trong đó XAUUSD chỉ 118. Bản gốc có TP 500 còn các bản dời SL bỏ TP, nên hai tác động bị trộn lẫn. Tham số được chọn ngẫu nhiên. Không dùng được.

### 4.2 Mặc định và các phương án
Mặc định để so sánh (baseline) = thiết kế hiện tại. Ứng viên đề xuất [GIẢ ĐỊNH, cần chạy lại dữ liệu cũ]:

1. **SL ban đầu theo cấu trúc:** SL_mua = min(entry − B, lo − buf), tức lấy mức xa hơn, với buf = max(0,25·ATR(M5), 2·spread).
   - Bỏ lệnh nếu entry − SL > 2·B, hoặc nếu rủi ro vượt 0,5% vốn.
   - Với 0,01 lot = 1 oz, mỗi 1 USD giá bằng 1 USD lãi/lỗ. SL 5 USD là lỗ 5 USD, nên cần vốn ≥ 1.000 USD để giữ mức 0,5%.
2. **Tránh cụm stop ở số tròn** (chỉ xét xx00 và xx50, bỏ quy tắc "xx.0"):
   - Nếu SL mua rơi vào [L − B_rn, L) với B_rn = max(0,25·ATR, 2·spread), đẩy SL ra L − B_rn − spread, nhưng chỉ khi khoảng cách mới ≤ 1,25 bước. Nếu vượt thì bỏ lệnh.
   - Cơ sở là Osler (FX). Chưa có dữ liệu về cụm stop của vàng.
3. **Nâng sàn bước:** B = max(0,8·ATR, 8·spread), để spread chiếm ≤ khoảng 12,5% R. Nếu mức sàn spread quyết định B, tức ATR quá thấp, thì nên bỏ lệnh.
4. **Hòa vốn phải cộng spread:** SL = entry + spread chứ không phải entry. Đây là **nên làm chắc chắn**, vì hòa vốn đúng giá vào vẫn lỗ spread.
5. **Các kiểu dời SL để so sánh:**
   - (a) Hiện tại: trễ 1 bậc, hòa vốn ở +1B.
   - (b) Hòa vốn ở +2B, sau đó trễ 1 bậc.
   - (c) Trễ 2 bậc.
   - (d) Dời liên tục SL = Bid − k·ATR với k = 1,2–1,5, bật khi lãi ≥ 1B, bước dời tối thiểu 0,5B (khuôn CSimpleTrailing: https://www.mql5.com/en/articles/14862).
   - (e) Cho phần đã chạy xa (≥ 3 bậc): Chandelier HH(22) − 2·ATR(22), SL chỉ đi một chiều.
6. **Dừng theo thời gian:** sau N = 6 nến M5 mà giá chưa đạt +1B thì siết SL về −0,5B, hoặc thoát.
7. **Không dùng** CTrailingFixedPips/MA/PSAR của thư viện chuẩn. Ví dụ CTrailingFixedPips kéo SL về Bid − 0,30 USD ngay cả khi lệnh đang lỗ.

**Đo trước khi chọn:** ghi MFE/MAE (lãi tạm lớn nhất / lỗ tạm lớn nhất) theo từng nến M5, và theo dõi giá thêm 12 nến sau khi thoát. Từ đó vẽ tỉ số E-ratio (Kestner) và phân phối MAE của các lệnh thắng (Sweeney) để chọn B, độ trễ, điểm hòa vốn và N.

---

## 5. Chốt lời và thoát lệnh

### 5.1 Toán học của thang bậc [BẰNG CHỨNG mô hình, đã suy lại]
- Tới +1B mới chỉ hòa. Phải tới **+2B mới có lãi +1B**.
- Phân phối kết quả: lỗ −B với xác suất 1−p; hòa với p(1−p); lãi từ +1B trở lên với p².
- **Hệ quả chắc chắn:** bỏ lệnh nếu mép gần của vùng mạnh đối diện cách giá vào **< 2B**.

### 5.2 Chỉ dời SL, TP tại vùng đối diện, hay chốt một phần
- **Bằng chứng lẫn lộn:**
  - Imkeller & Rogers 2014 (https://www.skokholm.co.uk/wp-content/uploads/2013/02/TTS.pdf) bị khái quát quá mức ở báo cáo ban đầu [SAI một phần]. Trong kịch bản gần với bot nhất (mỗi lệnh là một setup độc lập, "story B"), chỉ dời SL đạt 1,3354, TP + SL cố định đạt 1,4071 (chỉ hơn khoảng 5%), dời SL + TP đạt 1,3431.
  - Leung & Zhang chứng minh TP limit + dời SL là tối ưu, nhưng trong bài toán đã áp sẵn việc dời SL (https://arxiv.org/abs/1701.03960).
  - **Davey** viết rõ trong ba kiểu stop, target, stop+target thì **stop+target luôn tệ nhất** (https://kjtradingsystems.com/algo-trading-exits.html). Ông không ủng hộ TP+SL [đã sửa lại].
- **Chốt một phần:** về toán, đó chỉ là trung bình của hai chiến lược, nên **không tăng kỳ vọng**. Với 0,01 lot có lẽ không làm được, nhưng chưa xác minh: phải đọc `SYMBOL_VOLUME_MIN` và `SYMBOL_VOLUME_STEP` trong terminal [CHƯA KIỂM]. Mặc định: tắt.

### 5.3 Hành vi tại vùng mạnh ngược chiều
- Mức khóa lợi nhuận hiện tại (SL = giá − 0,5B ≈ 0,4·ATR) quá sát nhiễu, chỉ 0,6–1,6 USD. [GIẢ ĐỊNH là nên đổi]
- Các phương án để so sánh:
  - (a) Giữ nguyên, khóa ở 0,5B.
  - (b) **TP limit = lo_đối_diện − buf**, với buf = max(spread, 0,1·ATR(M5)). Nếu có số tròn xx00/xx50 nằm trước vùng thì đặt TP = L − (0,1·ATR + 1 point); lệnh bán cộng thêm spread.
  - (c) Đóng lệnh ngay khi chạm mép vùng.
  - (d) Khóa ở 1B.
- Nếu vùng đối diện bị phá bằng thân nến đóng qua, hủy TP và tiếp tục dời SL.
- Có hai bằng chứng ngược chiều:
  - Osler: lệnh chốt lời dồn tại số tròn nên giá hay quay đầu ở đó.
  - tickbench: vàng Exness chạm số tròn thì đi xuyên qua.
  - Vì vậy phải kiểm tra bằng A/B.
- Không lật lệnh khi đang ở bên trong vùng (giữ quy tắc hiện tại).
- Thoát sớm tùy chọn: nến M5 đóng thân ngược qua vùng vừa lật, tức vùng lật đã thất bại [GIẢ ĐỊNH].

---

## 6. Lọc đi ngang và điều kiện đảo chiều

### 6.1 Bằng chứng [đã mô phỏng lại]
Trên giá đi ngẫu nhiên, các ngưỡng quen thuộc vẫn báo "có xu hướng" rất thường xuyên:
- ADX14 bản Wilder > 25 ở khoảng 36% số nến.
- **iADX của MT5 > 25 ở khoảng 61%.** Bản này khác Wilder: tính tỉ lệ theo từng nến rồi làm mượt bằng EMA. Mã đã đọc: https://www.mql5.com/en/code/7
- CHOP14 < 38,2 ở khoảng 17,5%.
- ER10 > 0,3 ở khoảng 46%.

Hệ quả:
- Bộ lọc 14 nến trên M5 gần như mù. Lên H1 thì bắt xu hướng tốt hơn nhiều.
- MQL5 22754 (EURUSD H1, ngoài mẫu): lọc ADXR chỉ làm bớt lệnh và bớt sụt vốn; kỳ vọng vẫn âm (−0,9 / −1,2 / −0,4 pip) (https://www.mql5.com/en/articles/22754).
- Indicator Hurst 76439 tính trên giá thay vì lợi suất, nên luôn cho H ≈ 1. Không dùng.
- **Không dùng bộ lọc chế độ cho lệnh vào chính.** Chỉ dùng làm cổng cho lệnh đảo.

### 6.2 Cổng cho lệnh đảo [GIẢ ĐỊNH, mọi ngưỡng lấy theo phân vị trên dữ liệu XAUUSDm]
Lệnh đảo cần thỏa TẤT CẢ:
- (a) Phiên London/NY, khoảng 07–20 GMT. Không đảo gần tin mạnh.
  - Cơ sở: Batten 2017, giao dịch vàng tập trung 11–17 GMT (https://pmc.ncbi.nlm.nih.gov/articles/PMC5407636/).
  - Chưa ổn định: kiểm tra tự chạy thấy London hơi thiên về hồi quy (VR15 ≈ 0,93), chưa được kiểm chứng.
- (b) R_t = ATR(M5) / trung vị ATR của cùng khung 5 phút trong 20 ngày trước, nằm trong [1,0; 3,0]. Chỉ số này thay cho `LowVolatility` hiện tại, vốn so với trung bình 288 nến nên trộn lẫn các phiên.
- (c) Trên H1, một trong hai:
  - ADX14 **bản Wilder** ≥ phân vị P70 và DI cùng chiều đảo;
  - ER14 có dấu, cùng chiều, ≥ P70;
  - kèm CHOP14(H1) < P60.
- (d) Có sự kiện CUSUM theo chiều đảo trên lợi suất M5 trong 1–3 nến gần nhất, với ngưỡng h = 1,0–1,5·B (mã đã đọc: https://github.com/BlackArbsCEO/Adv_Fin_ML_Exercises/blob/master/notebooks/mlfinlab/corefns/core_functions.py).
- (e) Mỗi vùng tối đa 1 lần đảo, mỗi phiên tối đa 2 lần.
- Đảo **ngược** hướng lớn (bias) chỉ khi thân nến phá swing H1 hoặc PDH/PDL. Đây là ý "failsafe" của Turtle.

### 6.3 Các phương án thay cho lệnh đảo
- `FlipMode`: TẮT / hiện tại / có cổng / "Whipsaw".
- Whipsaw là sau khi dính SL, vào lại **theo hướng lớn** tại giá vào cũ, có hạn chờ. Luật này thuộc Original Turtle Rules của Faith, **không phải** bài MQL5 23448 [đã sửa lại] (https://turtletradersystem.blogspot.com/2009/01/original-turtle-trading-rules-chapter-5.html).
- **Đề xuất khi chạy tiền thật: TẮT đảo cho tới khi đo được** p sau SL > p* một cách có ý nghĩa thống kê. Kiểm tra tự chạy (chưa xác nhận) cho p ≈ 0,46 khi vào theo hướng phá.

### 6.4 Phanh sau chuỗi thua và hướng lớn
- **Phanh:** Carver cho thấy lọc theo đường vốn làm giảm lợi nhuận của hệ có lãi, trừ khi tự tương quan của kết quả ≥ 0,2 (https://qoppac.blogspot.com/2015/11/random-data-evaluating-trading-equity.html).
  - Cần làm runs test trên nhật ký lệnh.
  - Đếm riêng số lần thua của lệnh đảo.
  - Thử phanh kiểu "lệnh ảo": mở lại khi một lệnh ảo thắng ≥ 1B.
- **Hướng lớn** (phần bổ sung, mô phỏng tự chạy, chưa xác nhận): `Bias.mqh` đúng về thời gian, không nhìn trước.
  - Nhưng yêu cầu H4 == H1 chặn khoảng 36,6% số giờ ngay cả khi giá đi ngẫu nhiên.
  - H4 đổi hướng sau đỉnh khoảng 8 nến H4, tức khoảng 32 giờ và khoảng 3 ATR(H4).
  - Cần đo `BiasMode` = H4==H1 / chỉ H1 / chỉ H4.

---

## 7. Thiết lập cần chạy lại dữ liệu cũ để so sánh

Mặc định = hành vi hiện tại (baseline), hoặc TẮT với tính năng mới. Mọi phép thử dùng tick thật và walk-forward.

| Nhóm | Setting (tên đề xuất) | Mặc định | Phương án thử |
|---|---|---|---|
| Vùng | `InpBreakMode` | Thân nến đóng qua mép xa | Qua đường mức (DoN); râu (Shved) |
| Vùng | `InpBreakBufAtr` (kB) | 0 | 0,16; 0,25 |
| Vùng | `InpBreakImpulseMult` (biên độ/chiều cao band) | 0 (tắt) | 1,5 |
| Vùng | `InpBreakBodyFrac` | 0 (tắt) | 0,5 / vị trí đóng ≥ 0,6 |
| Vùng | `InpSweepCancelBars` | 0 (tắt) | 1; 2 |
| Vùng | `InpBandMinAtr` / `InpBandMaxAtr` (của khung vùng) | không kẹp | 0,15 / 0,5 |
| Vùng | `InpMergeEqAtr200` | theo luật chồng lấn hiện tại | 0,1 |
| Vùng | `InpMergeTouches` | (hiện tại) | MAX thay cho tổng |
| Vùng | `InpSpikeExclAtr200` | 0 | 2,0 |
| Vùng | `InpGapBaseMaxAtr` / `InpGapExitRatio` / `InpGapExitMinAtr` | (hiện tại) | 0,3 / 3,0 / 0,5 |
| Vùng | `InpSwingMode` | Fractal 3/3 | ZigZag 1·ATR_TF |
| Vùng | `InpZoneExpiry` M15 / H1+ | (hiện tại) | 1–2 ngày / 5 ngày |
| Độ mạnh | `InpRoundW100/50/10` | (hiện tại) | 1,0 / 0,6 / 0 (hoặc 0,25) |
| Độ mạnh | `InpAgeTau` M15 / H1+ | tắt | 6–12 giờ / 2–5 ngày |
| Độ mạnh | `InpTfWeight`, `InpConfluenceW` | (hiện tại) | 0,5 / 0,25 (tối đa 0,5); 0 |
| Vào lệnh | `InpMoveAwayAtr` | (hiện tại) | 0,34; 1·B |
| Vào lệnh | `InpRetestMinBars` | 0 | 2 |
| Vào lệnh | `InpConfirmBars` | (hiện tại) | 0; 1; 2 |
| Vào lệnh | `InpConfirmCloseLoc` | 0 | 0,6 |
| Vào lệnh | `InpCancelMidBand` | tắt | bật |
| Vào lệnh | `InpEntryType` | market sau xác nhận | BUY/SELL STOP 2 nến; limit (chỉ lệnh bóng) |
| Vào lệnh | `InpMaxChaseB` | tắt | 1,2 |
| Vào lệnh | `InpRetestTimeoutBars` | (hiện tại) | 24; 36 |
| Vào lệnh | `InpMinRoomB` (khoảng trống tới vùng đối diện) | 0 | **2,0** |
| SL | `InpStepAtrMult` | 0,8 | 1,0; 1,2 |
| SL | `InpStepMinSpreadMult` | 5 | 8; 10 |
| SL | `InpInitSLMode` | entry − B | max(entry−B, lo − buf), buf 0,25·ATR |
| SL | `InpMaxInitSL_B` | tắt | 2,0 |
| SL | `InpRoundSLAvoid` | tắt | xx00/xx50, B_rn = max(0,25·ATR, 2·spread) |
| SL | `InpBEOffsetSpread` | 0 | 1 |
| SL | `InpBETriggerB` | 1 | 2 |
| SL | `InpTrailLag` | 1 | 2 |
| SL | `InpTrailMode` | bậc | ATR liên tục k = 1,2–1,5, bật ở 1B, bước 0,5B |
| SL | `InpTimeStopBars` | tắt | 6; 12 |
| SL | `InpRunnerChandelier` | tắt | sau 3 bậc, HH22 − 2·ATR22 |
| Thoát | `InpOppZoneAction` | khóa 0,5B | TP limit tại mép − buf; đóng tại mép; khóa 1B |
| Thoát | `InpTPRoundOffsetAtr` | tắt | 0,1·ATR + 1 point |
| Thoát | `InpFixedTP_B` | 0 (không TP) | 3; 4 |
| Thoát | `InpExitOnFailedFlip` | tắt | bật |
| Thoát | `InpPartialClose` | tắt | (chỉ khi được phép dùng ≥ 0,02 lot) |
| Đảo | `InpFlipMode` | hiện tại | TẮT; có cổng (mục 6.2); Whipsaw vào lại theo hướng lớn |
| Đảo | `InpFlipMinSpreadMult` | 5 | 8–10 |
| Đảo | `InpFlipSessionGMT` | tắt | 07–20 |
| Đảo | `InpFlipRtRange` | tắt | [1,0; 3,0] |
| Đảo | `InpFlipRegime` (H1) | tắt | ADX Wilder ≥ P70 / ER14 ≥ P70 / CHOP < P60 |
| Đảo | `InpFlipCusumB` | tắt | 1,0; 1,5 |
| Đảo | `InpFlipCountSeparate` | chung | tách riêng |
| Phanh | `InpBrakeMode` | 2 lần thua + nghỉ theo phút | lệnh ảo; tắt |
| Bias | `InpBiasMode` | H4 == H1 | chỉ H1; chỉ H4 |
| Bias | `InpBiasNeutralOnProtect` | tắt | bật (giá đóng qua mức bảo vệ thì về 0) |

**Quy trình kiểm tra bắt buộc** [đúc kết từ Osler 2000 và Sullivan–Timmermann–White 1999, https://ideas.repec.org/a/bla/jfinan/v54y1999i5p1647-1691.html]:
- Mỗi vùng thật đi kèm 5 vùng giả tại L ± U(0,5; 3)·ATR, chạy cùng logic.
- Chỉ giữ một thiết lập nếu p(thật) − p(giả) ≥ 3 điểm %, với N ≥ 1.000 sự kiện mỗi nhóm.
- Chia dữ liệu theo thời gian (walk-forward).
- Dùng Reality Check hoặc SPA cho cả lưới tham số, vì thử nhiều tổ hợp sẽ tự sinh kết quả đẹp giả.
- Nếu muốn so với Osler, phải dùng đúng định nghĩa của ông: "bật" = giá **vẫn ở phía cũ tại thời điểm t+15 phút** (hoặc t+30), không phải "không cắt qua trong 15 phút" [đã sửa lại].

---

## 8. Rủi ro, điểm yếu và những điều CHƯA có bằng chứng

1. **Tiền đề cốt lõi chưa được chứng minh.**
   - Không có nghiên cứu có đối chứng nào về lần chạm lại đầu của vùng lật.
   - Kiểm tra tự chạy (chưa xác nhận: GC=F, định nghĩa vùng đơn giản hóa, M5 chỉ 10 tuần) cho kết quả bằng hoặc tệ hơn vùng giả.
   - Chưa nên chạy tiền thật dựa trên tiền đề này.
2. **Chi phí.** Trong ngày, lợi thế S/R nếu có chỉ khoảng 4–5 điểm %, xấp xỉ mức p* cần vượt.
   - Neely & Weller 2003: các quy tắc FX trong ngày mất hết lợi nhuận sau phí (https://sci2s.ugr.es/keel/pdf/specific/articulo/science2_13.pdf).
   - Jin 2022: vàng SHFE 5 phút có khả năng dự báo "ảo" sau hiệu chỉnh. Chỉ đọc tóm tắt.
3. **Không có quán tính.** Vàng GC=F có VR ≈ 1 ở 5–60 phút (tự tính, chưa xác nhận). Nếu đúng thì dời SL hay lệnh đảo không tạo ra kỳ vọng dương.
4. **Chưa có bằng chứng** cho các điểm sau:
   - thân nến tốt hơn râu khi xác định phá;
   - mức vẽ theo thân nến (Malaysian SnR) tốt hơn mức theo râu;
   - trọng số theo khung thời gian;
   - lực rời vùng và thời gian nằm trong vùng;
   - tick volume của Exness;
   - hằng số suy giảm τ;
   - H4 == H1 tốt hơn chỉ H1;
   - số tròn $10;
   - cụm stop của vàng nằm cách mức bao xa;
   - lệnh đảo tại SL.
5. **Nguồn không dùng được:**
   - MQL5 16991 và Davey (cách dùng ban đầu bị sai).
   - Bảng điểm OTA/Seiden, các số liệu kiểu "thắng 57% khi ADX > 25".
   - smartmoneyconcepts bản gốc: nhìn trước 50 nến. Issue #101 cho thấy tỷ lệ thắng tụt từ 81% xuống 53% sau khi bỏ lỗi này.
6. **Dữ liệu thiếu** (cần trả lời trước khi backtest):
   - XAUUSDm/XAUUSDc có 2 hay 3 chữ số thập phân?
   - Giờ server là múi nào?
   - `SYMBOL_VOLUME_MIN/STEP`, `STOPS_LEVEL`, `FREEZE_LEVEL` là bao nhiêu?
   - Có dữ liệu tick Exness 2–3 năm, kèm spread thật theo thời điểm, không?
   - Tỉ lệ ATR(H1)/ATR(M5) thực tế là bao nhiêu?
7. **Rủi ro của chính backtest:**
   - Nến M5 không cho biết giá chạm SL hay chạm bậc kế trước, nên phải dùng "Every tick based on real ticks".
   - Lệnh limit "chạm là khớp" sẽ quá lạc quan.
   - Các sự kiện chồng lấn nhau làm khoảng tin cậy hẹp hơn thực tế.
   - Tối ưu nhiều tham số dễ khớp quá mức với dữ liệu cũ.
8. **Ngoài phạm vi:** trượt giá được nghiên cứu riêng. Mọi kỳ vọng ở trên mới tính spread.

# Nghiên cứu C – Mức hỗ trợ/kháng cự (S/R) nào có bằng chứng?

Ghi chú: "bật" = giá chạm mức rồi quay lại, không xuyên qua. Mọi con số dưới đây lấy từ bài gốc (đã đọc toàn văn Osler 2000, Osler 2003, Chung & Bellotti 2021; Garzarelli 2014 đọc bản PMC).

## 1. Từng nghiên cứu

**Osler 2000, "Support for Resistance" (FRBNY EPR)** – https://www.newyorkfed.org/medialibrary/media/research/epr/00v06n2/0007osle.pdf
- Mức: do 6 công ty FX công bố mỗi ngày; DEM, JPY, GBP; 1/1996–3/1998; dữ liệu tick, 9h–16h New York.
- Định nghĩa: "chạm" = giá bid (ask) vào trong 0,01% của mức; "bật" = sau 15 phút giá vẫn ở phía cũ. Có thử lại với 0,00%/0,02% và 30 phút.
- Mức đối chứng: 20 mức hỗ trợ + 20 mức kháng cự ngẫu nhiên mỗi ngày, làm tròn cùng số chữ số như mức thật.
- **Đã chứng minh bằng số liệu:** mức thật bật 60,8%, mức ngẫu nhiên 56,2%. Mức thật hơn mức ngẫu nhiên ở cả 16 cặp công ty–tiền tệ; hơn 4,0–5,6 điểm tùy đồng tiền. Sau 5 ngày mức vẫn có tác dụng, chỉ giảm 1,7 điểm.
- **Đã chứng minh (kết quả âm):** mức được nhiều công ty cùng chọn (trùng trong 2 hoặc 5 pip) không bật tốt hơn một cách có ý nghĩa. Điểm "độ mạnh 1/2/3" do công ty tự chấm không có giá trị, phần lớn còn cho kết quả ngược.
- Chú thích 8 của bài: bản thân số tròn và đỉnh/đáy cục bộ cũng có khả năng dự báo.
- Giới hạn: chưa kiểm lời sau phí. Ngay cả mức ngẫu nhiên cũng "bật" 56%, do giá hay đảo chiều ngắn và do cách định nghĩa.

**Osler 2003, "Currency Orders and Exchange-Rate Dynamics" (J. Finance; bản SR125)** – https://www.newyorkfed.org/medialibrary/media/research/staff_reports/sr125.pdf
- Dữ liệu: 9.667 lệnh chốt lời/cắt lỗ thật tại một ngân hàng lớn, 9/1999–4/2000, USDJPY, EURUSD, GBPUSD.
- **Đã chứng minh bằng số liệu:** lệnh dồn mạnh nhất ở giá đuôi 00 (~8,7% số lệnh; nếu phân bố đều chỉ ~1%). Sau đó giảm dần ở đuôi 50, các đuôi 0 khác, rồi đuôi 5. **Không** dồn ở đuôi 25/75. Lệnh chốt lời dồn đúng số tròn nên giá hay đảo ở đó. Lệnh cắt lỗ mua dồn ngay trên số tròn, cắt lỗ bán dồn ngay dưới. Theo Osler 2001 (được trích trong bài), 15 phút sau khi giá vượt số tròn, giá đi xa hơn so với khi vượt mức ngẫu nhiên.
- Giới hạn: một ngân hàng; FX; giai đoạn cũ.

**Chung & Bellotti 2021 (arXiv 2101.07410)** – https://arxiv.org/abs/2101.07410
- Mức: trong cửa sổ trượt W phút, hỗ trợ = min ± γ, kháng cự = max ± γ. γ = trung bình |giá(t) − giá(t−1)| của chuỗi phút. Số lần bật = số lần giá cắt biên của vùng, chia 2. Bật = vào vùng rồi ra lại phía cũ.
- Dữ liệu: nến M1 năm 2018 của EURUSD, cổ phiếu LLOY, dầu Brent.
- **Đã chứng minh bằng số liệu:** mức đã bật càng nhiều lần thì xác suất bật lần sau càng cao. Chuỗi thật cao hơn chuỗi trộn ngẫu nhiên các bước giá (trộn 1.000 lần); phần lớn Λ > 0,95. Với LLOY chỉ chắc đến 5 lần bật trước. Hiệu ứng giảm dần: với EURUSD, mức bật 1 lần về 0,5 khi cửa sổ khoảng 350 phút, mức bật 4 lần về 0,5 khi khoảng 900 phút.
- Giới hạn: số liệu từng xác suất chỉ có trên đồ thị. Mỗi lúc chỉ có 1 cặp mức. γ lớn hơn thì kết quả bị đẩy cao lên. Không tính lời/lỗ.

**Garzarelli và cộng sự 2014 (PLoS ONE)** – https://pmc.ncbi.nlm.nih.gov/articles/PMC3967202/
- Mức: đỉnh/đáy cục bộ trên chuỗi lấy mẫu mỗi T giây. Độ rộng vùng = trung bình |bước giá| ở thang T.
- Dữ liệu: tick của 9 cổ phiếu LSE, năm 2002.
- **Đã chứng minh bằng số liệu:** xác suất bật tăng theo số lần bật trước; chuỗi trộn chỉ khoảng 0,5; kiểm định χ² cho p < 0,001 ở thang 45–90 giây. Hiệu ứng **mất** khi thang lớn hơn 150–180 giây (p = 0,38 ở 180 giây).
- Giới hạn: một năm, 9 mã, thang rất ngắn.

**Brock, Lakonishok & LeBaron 1992: phá vỡ vùng giá** – https://onlinelibrary.wiley.com/doi/10.1111/j.1540-6261.1992.tb04681.x
- Mức: đỉnh/đáy của 50, 150 hoặc 200 ngày trước; vào lệnh khi giá phá qua (có bản thêm dải 1%). DJIA theo ngày, 1897–1986. Kết quả: lợi nhuận sau tín hiệu **phá vỡ** cao hơn mức nền.
- **Bị bác khi kiểm ngoài mẫu:** Sullivan, Timmermann & White 1999 kiểm thêm 10 năm sau 1986 và điều chỉnh sai lệch do thử nhiều quy tắc; kết quả không còn giữ được. https://ideas.repec.org/a/bla/jfinan/v54y1999i5p1647-1691.html

**Vàng, số tròn** – Aggarwal & Lucey 2007: https://www.sciencedirect.com/science/article/abs/pii/S1058330006000218 ; Lucey & O'Connor 2016 (giá fix AM/PM 1975–2015, 20.452 quan sát): https://www.sciencedirect.com/science/article/abs/pii/S1544612316300216
- **Có bằng chứng, nhưng chỉ ở dữ liệu ngày/fix:** gần mốc $10/$100, trung bình và biến động của giá thay đổi. Tôi chưa đọc được toàn văn; chưa có nghiên cứu cho vàng M1/M5.

**Mở cửa phá vùng (ORB)** – Holmberg, Lönnbark & Lundström 2013: https://ideas.repec.org/a/eee/finlet/v10y2013i1p27-33.html
- Dầu thô futures: tỉ lệ thắng hơn trò chơi công bằng và lợi nhuận > 0 có ý nghĩa. Đây là bằng chứng cho **phá vùng**, không cho bật. Tóm tắt không ghi con số.

**Hồ sơ khối lượng (HVN/POC)**
- Chỉ có các bài quảng bá, số liệu không kiểm chứng được. Ví dụ: https://ninjatrader.com/futures/blogs/how-to-trade-futures-use-volume-profile-to-reveal-significant-price-level/
- Tôi không tìm thấy nghiên cứu có bình duyệt nào.

## 2. Tổng hợp

**(a) Loại mức có bằng chứng (đã chứng minh bằng số liệu)**
1. Số tròn: đuôi 00 > 50 > 0 > 5. Giá dễ đảo **đúng tại** số tròn; khi đã vượt qua thì giá chạy nhanh (Osler 2003).
2. Đỉnh/đáy cục bộ gần đây, nhất là mức đã bật nhiều lần (Chung; Garzarelli; chú thích 8 của Osler 2000).
3. Tác dụng của mức giảm dần theo thời gian. Mức bật càng nhiều lần thì giữ tác dụng càng lâu (Chung). Osler thấy mức vẫn còn tác dụng sau 5 ngày.
4. Độ lợi thực tế nhỏ: khoảng +4–5 điểm so với mức ngẫu nhiên (Osler).

**(b) Loại mức chưa có bằng chứng (hoặc có bằng chứng âm)**
- Mức "mạnh" vì nhiều nguồn trùng nhau: Osler 2000 không thấy lợi có ý nghĩa, tức gộp nhiều loại mức không làm mức mạnh hơn.
- Điểm độ mạnh chấm theo cảm tính: Osler thấy vô dụng.
- FVG, OB, khoảng trống giá (gap), Fibonacci: chưa có bài bình duyệt. FVG/Fib đã kiểm (không bình duyệt): không có lời sau phí, xem `docs/research/13`.
- Đỉnh/đáy ngày hoặc tuần trước, đỉnh/đáy từng phiên: **không tìm thấy** bài kiểm riêng. Chỉ có thể coi là một trường hợp của "đỉnh/đáy cục bộ" (chỉ là gợi ý).
- Hồ sơ khối lượng: chỉ có lời quảng bá.
- Đảo chiều sau khi "quét thanh khoản": bằng chứng của Osler nghiêng về phía ngược lại (vượt qua cụm cắt lỗ thì giá chạy tiếp).

**(c) Đề xuất định nghĩa mức để kiểm tra (ít mức, ít nhiễu). Phần này chỉ là gợi ý, cần tự kiểm.**
- Chỉ dùng 2 họ mức. Mỗi họ chỉ lấy 1 mức gần nhất phía trên và 1 mức gần nhất phía dưới, tức tối đa 4 mức.
  - **R (số tròn):** bội số của N USD, thử N ∈ {10, 25, 50, 100}. Đánh giá riêng từng bậc.
  - **E (đỉnh/đáy đã bật):** max/min của W phút gần nhất trên M1, thử W ∈ {60, 240, 600, 1440}. Độ rộng vùng γ = k × trung bình |Δgiá M1|, k ∈ {1, 2}. Đếm số lần bật trước (b_prev) theo cách của Chung. Chỉ giữ mức có b_prev ≥ m, thử m ∈ {1, 2, 3, 4}. Mức hết hạn sau A giờ, thử A ∈ {4, 12, 24}. Đỉnh/đáy ngày trước chính là E với W = 1440; nên kiểm như một nhóm riêng.
- **Chạm:** bid vào trong 0,01% của mức hỗ trợ, ask vào trong 0,01% của mức kháng cự; thử thêm 0,005% và 0,02%. **Bật:** sau H phút giá vẫn ở phía cũ, thử H ∈ {5, 15, 30}. Nên đo thêm cách của Chung: khi giá ra khỏi vùng, ra ở phía nào.
- **Đối chứng bắt buộc:**
  1. Mỗi ngày tạo mức ngẫu nhiên với cùng số lượng, cùng khoảng cách tới giá hiện tại và **cùng cách làm tròn**. Khi kiểm họ E, mức ngẫu nhiên không được trùng số tròn.
  2. Trộn ngẫu nhiên các bước giá M1 rồi chạy lại toàn bộ quy trình (Chung).
- **Cỡ mẫu:** độ lợi dự kiến khoảng 4–5 điểm trên nền khoảng 56%. Cần khoảng 1.500–2.000 lần chạm cho **mỗi** tổ hợp tham số. Phải điều chỉnh cho việc thử nhiều tổ hợp (Sullivan và cộng sự 1999).
- **Kiểm cả chiều ngược lại:** sau khi giá vượt số tròn, 15 phút tiếp theo giá có chạy xa hơn khi vượt mức ngẫu nhiên không (Osler)? Có thể lợi thế nằm ở việc đi theo cú phá, không nằm ở việc chờ giá bật lại.
- **Tiêu chí dừng:** nếu R và E không hơn mức ngẫu nhiên ít nhất 3 điểm với z ≥ 3 sau điều chỉnh, thì không dùng mức S/R làm điều kiện vào lệnh. Bật hơn mức ngẫu nhiên cũng chưa có nghĩa là có lời sau spread.

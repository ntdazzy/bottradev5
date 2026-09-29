# Nghiên cứu D: Vì sao cách S/R đánh tay có vẻ chạy nhưng code lại thua, và cách chuyển phán đoán của người thành bot

Ngày: 29/09/2026. Chỉ nghiên cứu trên web, không sửa gì trong `/home/user/bottradev5`.

Mức bằng chứng:
- **proven_with_data**: bài có phản biện hoặc backtest làm lại được, có tính phí và có kiểm tra ngoài mẫu.
- **reported_numbers_unverified**: có số liệu nhưng tôi chưa kiểm tra được phí, dữ liệu ngoài mẫu hoặc toàn văn.
- **claim_only**: chỉ là lời nói, không có số liệu.

---

## 1. Trả lời thẳng hai câu hỏi của chủ bot

### "Hiện tại phương pháp bot nào là tốt nhất?"

- Tôi **không tìm thấy bằng chứng độc lập** nào cho thấy có một bot S/R vàng M1/M5 có lãi sau phí. Kết luận này giống với phần đã có trong repo.
- Ở cấp quỹ lớn, bot và người **thắng ngang nhau** sau khi điều chỉnh rủi ro. Nghiên cứu trên hơn 9.000 quỹ giai đoạn 1996–2014 cho thấy lợi nhuận năm sau phí chỉ khoảng 2,86%–5,01% cho cả bốn nhóm. Như vậy "bot" hay "tay" tự nó không phải lợi thế. Lợi thế nằm ở chỗ **có edge thật hay không** ([Harvey và cộng sự 2017](https://people.duke.edu/~charvey/Research/Published_Papers/P130_Man_vs_machine.pdf), [SSRN](https://papers.ssrn.com/sol3/papers.cfm?abstract_id=2880641)).
- Với quy tắc kỹ thuật trong ngày trên FX (thị trường giống vàng nhất về cách vận hành), khi tính đủ phí thật và giờ giao dịch thật thì **không còn lãi** ([Neely & Weller 2003](https://ideas.repec.org/a/eee/jimfin/v22y2003i2p223-237.html), [PDF](https://wrap.warwick.ac.uk/id/eprint/1846/1/WRAP_Neely_fwp99-02.pdf)).
- Một bài mới tháng 07/2026 (chưa phản biện) thử 5 họ tín hiệu phổ biến với trader nhỏ lẻ. Kết quả: 4/6 bị bác bỏ, 2/6 chưa kết luận được, **0/6 được xác nhận** sau khi tính phí và kiểm tra thử nhiều lần ([Darmanin 2026, arXiv](https://arxiv.org/abs/2607.20093)).

=> Theo góc nhìn này, **"phương pháp tốt nhất" là phương pháp mà chủ bot chứng minh được bằng nhật ký lệnh thật**, rồi mới dần tự động hóa. Làm ngược lại (code trước, hy vọng sau) chính là con đường đã cho kết quả −0,15R.

### "Tôi đánh S/R bằng tay được mà, sao code lại sai?"

Có 5 lý do, và chúng có thể xảy ra cùng lúc:

1. **Chưa có con số chứng minh cách đánh tay có lãi.** Ở Đài Loan, dưới 1% người day trade có lãi ổn định sau phí ([Barber và cộng sự](https://faculty.haas.berkeley.edu/odean/papers/day%20traders/The%20Cross-Section%20of%20Speculator%20Skill.pdf)). Ở Brazil, 97% người day trade hợp đồng tương lai kiên trì trên 300 ngày bị lỗ ([Chague và cộng sự](https://papers.ssrn.com/sol3/papers.cfm?abstract_id=3423101)). Điều này không có nghĩa chủ bot thua. Nó có nghĩa là **cảm giác "chạy được" chưa đủ làm bằng chứng**. Cần nhật ký.
2. **Nhìn lại quá khứ làm ta thấy mình giỏi hơn thực tế.** Khi vẽ vùng trên chart cũ, mắt tự chọn các vùng mà giá *đã* bật. Nghiên cứu trên 85 nhân viên ngân hàng đầu tư cho thấy người bị thiên kiến nhìn lại càng nặng thì kết quả càng kém ([Biais & Weber 2009](https://papers.ssrn.com/sol3/papers.cfm?abstract_id=1209774)). Trên 107 trader, người càng tin mình kiểm soát được thị trường thì hiệu suất và thu nhập càng thấp ([Fenton-O'Creevy và cộng sự 2003](https://eprints.lse.ac.uk/14954/)).
3. **Người chọn lọc, còn code lấy hết.** Công cụ đo của mình cho thấy mỗi lần chạm có trung vị 19 vùng khác chồng lên. Code như vậy gần như "vùng nào cũng là vùng", nên kết quả giống vùng giả (43,9% so với 41,3%). Người giỏi thường bỏ phần lớn vùng và chỉ vào vài lệnh. Trong nghiên cứu về chuyên gia phân tích kỹ thuật trái phiếu Đức, khả năng đoán hướng của họ **chỉ ở mức trung bình**, nhưng họ **có lãi nhờ chọn thời điểm** ([Batchelor & Kwan 2007](https://www.sciencedirect.com/science/article/abs/pii/S0169207007000714)). Nghĩa là giá trị nằm ở **lúc nào vào và lúc nào đứng ngoài**, chứ không nằm ở danh sách vùng.
4. **S/R có tác dụng ở chỗ lệnh chờ thật sự nằm.** Nghiên cứu cho thấy mức S/R trùng với chỗ sổ lệnh dày nhất ([Kavajecz & Odders-White 2004](https://papers.ssrn.com/sol3/papers.cfm?abstract_id=315660)). Mọi pivot/FVG/OB đều được code thành vùng, nhưng không phải vùng nào cũng có lệnh chờ lớn. Người đánh tay có thể đang ngầm chọn những mức "ai cũng thấy" (đỉnh/đáy lớn, số tròn), và đó là phần code chưa nắm được.
5. **Chi phí nuốt hết edge nhỏ. Đây là phép tính của chính dự án, không phải trích dẫn.** Phí một vòng lệnh = spread 0,16 + trượt 0,3 × 2 = **0,76 USD**. Nếu SL ≈ 1 ATR(M5) ≈ 4,6 USD thì phí ≈ **0,165R**. Kết quả đo là −0,15R, gần bằng đúng phần phí. Vậy **trước phí, điểm vào gần như bằng 0**, đúng như lệnh ngẫu nhiên. Muốn có lãi thì hoặc edge phải lớn hơn 0,165R mỗi lệnh (rất khó), hoặc phải dùng SL/TP lớn hơn nhiều để phí chỉ còn một phần nhỏ của R.

Một điểm tốt: con người **thật sự nhìn ra** cấu trúc trên chart. Trong "bài kiểm tra Turing tài chính", người chơi phân biệt được chart thật với chart xáo trộn ngẫu nhiên, với p ≤ 0,5%, khi được phản hồi ngay ([Hasanhodzic, Lo, Viola 2010](https://arxiv.org/abs/1002.4592)). Nhưng "nhìn ra cấu trúc" chưa phải là "có lãi sau phí".

---

## 2. Bằng chứng về cách chuyển phán đoán của người thành bot

### 2.1 Bắt chước chuyên gia (judgmental bootstrapping) là cách có bằng chứng nhiều nhất

- Cách làm: ghi lại các **thông tin (cue)** mà chuyên gia nhìn, cùng **quyết định** của họ, rồi dùng hồi quy để "học" quy tắc đó. Mô hình áp dụng quy tắc **đều tay hơn** người, nên thường chính xác hơn.
- Tổng kết của Armstrong: mô hình bắt chước chính xác hơn chuyên gia ở **8/11 so sánh**, kém hơn ở 1, hòa ở 2 ([Armstrong 2001](https://repository.upenn.edu/marketing_papers/150/)).
- Phân tích tổng hợp 136 nghiên cứu (y tế, hành vi): dự báo bằng máy **bằng hoặc tốt hơn** người, trung bình chính xác hơn khoảng 10%. Người chỉ tốt hơn rõ rệt ở 6–16% nghiên cứu ([Grove và cộng sự 2000](https://pubmed.ncbi.nlm.nih.gov/10752360/)). Đây không phải nghiên cứu về trading.
- **Riêng về trading** ([Batchelor & Kwan 2007](https://www.sciencedirect.com/science/article/abs/pii/S0169207007000714)): mô hình xây từ các chỉ báo mà chính các nhà phân tích kỹ thuật nói họ dùng **kiếm được nhiều hơn** các nhà phân tích. Gộp dữ liệu nhiều thị trường thì còn tốt hơn. **Nhưng** lệnh của mô hình khác lệnh của người và **rủi ro hơn**, nên không thể nói mô hình đã "bắt chước đúng" người. Tôi chưa đọc được toàn văn, nên chưa kiểm tra được phí và phần ngoài mẫu.

=> Áp dụng: đừng để code tự "đoán" vùng nào quan trọng. Hãy **để chủ bot đánh dấu**, rồi cho mô hình học từ các nhãn đó.

### 2.2 Meta-labeling: lớp lọc thứ hai quyết định "vào hay không"

- Ý tưởng của López de Prado: mô hình chính đưa ra hướng (ví dụ: chạm vùng S/R thì mua/bán), mô hình phụ đoán **"lần này mô hình chính đúng hay sai"** rồi quyết định vào lệnh hay bỏ ([Joubert 2022, JFDS](https://papers.ssrn.com/sol3/papers.cfm?abstract_id=4032018)).
- Số liệu công khai còn **yếu**. Một dự án tốt nghiệp trên ES futures 2011–2019, kiểm tra ngoài mẫu khoảng 1 năm: độ chính xác của lệnh vào tăng từ 0,17 lên 0,20 (đảo chiều Bollinger) và từ 0,48 lên 0,54 (theo xu hướng). Chưa có phí rõ ràng. Chính tác giả ghi: "nếu mô hình chính kém thì meta-labeling có lẽ chỉ giảm lỗ" ([Singh & Joubert](https://hudsonthames.org/wp-content/uploads/2022/04/Does-Meta-Labeling-Add-to-Signal-Efficacy.pdf)).
- Cách này hợp với dự án: công cụ đo đã có sẵn "mô hình chính" (mọi lần chạm vùng). Có thể thử một mô hình phụ nhỏ để học **vùng nào/lúc nào đáng vào**. Nhãn lấy từ (a) chủ bot chọn/không chọn, hoặc (b) lệnh chạm +xR trước −1R hay không (triple barrier).

### 2.3 Bộ lọc bối cảnh (xu hướng khung lớn, biến động, phiên)

- Tôi **không tìm thấy nghiên cứu có phí và có ngoài mẫu** nào chứng minh "S/R + lọc xu hướng khung lớn" có lãi trên vàng trong ngày. Đa số là bài quảng cáo (claim_only).
- Bằng chứng gián tiếp về bộ lọc biến động: với quỹ ETF vàng GLD, tín hiệu dự báo trong ngày (lợi nhuận nửa giờ thứ 5 dự báo nửa giờ cuối) **có ý nghĩa ở mức 1% khi biến động cao, nhưng gần như vô nghĩa khi biến động thấp**. Bài này **không tính phí giao dịch** ([Intraday return predictability, commodity ETFs](https://pmc.ncbi.nlm.nih.gov/articles/PMC7480318/)). Ý chính: bối cảnh (biến động) có thể quyết định tín hiệu có tác dụng hay không, nhưng chưa chứng minh được là có lãi.
- Một bài năm 2022 cho thấy thêm đặc trưng S/R vào mô hình ML trên 4 cặp FX làm lợi nhuận tổng tăng 65% so với không có S/R. Tôi **không đọc được toàn văn** nên không biết có phí hay không ([Chan và cộng sự 2022](https://www.mdpi.com/2227-7390/10/20/3888)). Mức bằng chứng: reported_numbers_unverified.
- **Cảnh báo quan trọng:** mỗi bộ lọc thêm vào là thêm một lần "thử". Càng thử nhiều cấu hình thì xác suất cấu hình tốt nhất trong mẫu lại thua ngoài mẫu càng tiến gần 1 ([Bailey, Borwein, López de Prado, Zhu – PBO](https://papers.ssrn.com/sol3/papers.cfm?abstract_id=2326253)). Dữ liệu 1 tuần là quá ít để chọn bộ lọc.

### 2.4 Quản lý lệnh (SL, TP, chốt một phần) không tạo ra edge

- Về mặt toán: nếu giá đi ngẫu nhiên thì **quy tắc cắt lỗ luôn làm giảm lợi nhuận kỳ vọng**. Cắt lỗ chỉ có ích khi thị trường có quán tính (momentum) ([Kaminski & Lo 2014](https://dspace.mit.edu/bitstream/handle/1721.1/114876/Lo_When%20Do%20Stop-Loss.pdf)). Nghiên cứu dùng dữ liệu tháng, nhưng ý toán học vẫn đúng: **nếu điểm vào bằng 0 thì đổi cách thoát lệnh không biến nó thành dương**. Cách thoát chỉ đổi hình dạng kết quả (tỉ lệ thắng, độ sụt giảm), còn phí thì vẫn phải trả.
- Vì vậy việc "thêm trailing, chốt 50%, dời SL về hòa" **không phải bước đầu tiên**. Chỉ làm sau khi điểm vào đã có edge trước phí.

### 2.5 Người chọn lọc, máy đánh nhiều

- Nhóm hộ gia đình giao dịch nhiều nhất chỉ đạt 11,4%/năm, trong khi thị trường đạt 17,9%/năm ([Barber & Odean 2000](https://papers.ssrn.com/sol3/papers.cfm?abstract_id=219228)). Đây là dữ liệu cổ phiếu Mỹ, nhưng cho thấy phí cộng với giao dịch quá nhiều đã ăn mòn lợi nhuận.
- Với dự án: công cụ đo coi **mọi** lần chạm vùng là tín hiệu. Người thật có lẽ chỉ vào vài lệnh mỗi tuần. Phải đo lại trên **tập nhỏ vùng mà chủ bot thật sự chọn**, không phải trên mọi vùng.

---

## 3. Các bước cụ thể cho dự án (không sửa code trong lần này)

Mục tiêu: trả lời được **"edge của chủ bot có thật không, và nó nằm ở đâu"** trước khi viết thêm EA.

1. **Nhật ký lệnh thật, ghi trước khi giá chạm (8–12 tuần, hoặc ít nhất 50–100 lệnh).**
   - Đầu phiên, chủ bot vẽ vùng lên chart. Vùng phải được lưu *trước* khi giá tới, kèm thời gian vẽ. Có thể viết sau một script MQL5 nhỏ để xuất các đối tượng HLINE/RECTANGLE ra CSV, nhưng phần này chưa làm.
   - Ghi cả lệnh **vào** và các vùng **bỏ qua**, kèm lý do ngắn (xu hướng H4, phiên, phản ứng nến...).
   - Kiểm tra: nhật ký có thời gian vẽ vùng sớm hơn thời gian giá chạm. Không vẽ bù sau.
2. **Đo nhật ký bằng đúng thước của bot.** Tính theo R, sau phí thật (spread 0,16 + trượt 0,3 mỗi chiều). So với lệnh ngẫu nhiên có cùng giờ, cùng SL/TP (dùng công cụ đo sẵn có với vùng giả).
   - Nếu nhật ký thật **không** hơn ngẫu nhiên sau phí thì dừng việc mã hóa S/R, vì không có gì để bắt chước.
3. **Nếu có edge: xây mô hình bắt chước nhỏ** (hồi quy logistic hoặc cây quyết định nông), chỉ 5–8 đặc trưng:
   - hướng xu hướng H1/H4, khoảng cách tới vùng tính theo ATR, số lần vùng đã bật, tuổi vùng, vùng có trùng số tròn/đỉnh đáy ngày-tuần không, phiên giao dịch, ATR hiện tại so với trung bình.
   - Nhãn 1: chủ bot chọn hay bỏ vùng này. Nhãn 2: lệnh đạt +xR trước −1R hay không.
   - Kiểm tra: đo trên các tuần **chưa dùng để xây mô hình** (walk-forward). Ghi rõ số cấu hình đã thử.
4. **Đưa phí về mức nhỏ so với R.** Với phí 0,76 USD/lệnh, muốn phí ≤ 5% R thì SL phải khoảng ≥ 15 USD (≈ 3,3 ATR M5, tức cấu trúc cỡ M15–H1). Vào lệnh kiểu M1/M5 với SL 1 ATR M5 thì phí đã chiếm khoảng 16,5% R. (Phép tính của dự án.)
5. **Làm bot bán tự động trước.** Bot tìm vùng, báo khi có phản ứng, **chủ bot bấm duyệt**, và bot ghi lại cả lệnh được duyệt lẫn bị từ chối. Cách này vừa giữ phán đoán của người, vừa sinh ra nhãn sạch cho bước 3. Bằng chứng ủng hộ (gián tiếp): mô hình bắt chước chuyên gia thường đều tay hơn chuyên gia ([Armstrong](https://repository.upenn.edu/marketing_papers/150/), [Grove](https://pubmed.ncbi.nlm.nih.gov/10752360/)).
6. **Chống tự lừa mình.** Mọi bộ lọc phải được viết ra *trước* khi đo. Đếm số lần thử. Dùng ít nhất vài tháng dữ liệu tick thật (không phải 1 tuần) và giữ lại một khoảng thời gian chưa ai nhìn để kiểm tra cuối ([PBO](https://papers.ssrn.com/sol3/papers.cfm?abstract_id=2326253)).

---

## 4. Những gì tôi KHÔNG tìm thấy

- Không có nghiên cứu độc lập nào về việc mã hóa **Rare SnR, Secret of 411 hay ICT Unicorn** có tính phí và ngoài mẫu. Những gì có trên mạng đều là bài của người bán khóa học hoặc video (claim_only).
- Không có bộ dữ liệu công khai nào về "vùng S/R do người vẽ" để học theo.
- Các bài học tăng cường "bắt chước trader chuyên nghiệp" (ví dụ Pro Trader RL 2024) chỉ có tóm tắt nói "tốt hơn" và dùng dữ liệu cổ phiếu. Tôi không kiểm tra được phí ([ACM](https://dl.acm.org/doi/10.1016/j.eswa.2024.124465)). Mức bằng chứng: reported_numbers_unverified, không dùng làm căn cứ.

## Nguồn chính
- Harvey, Rattray, Sinclair, Van Hemert (2017), Man vs. Machine: https://people.duke.edu/~charvey/Research/Published_Papers/P130_Man_vs_machine.pdf
- Neely & Weller (2003): https://ideas.repec.org/a/eee/jimfin/v22y2003i2p223-237.html
- Barber, Lee, Liu, Odean: https://faculty.haas.berkeley.edu/odean/papers/day%20traders/The%20Cross-Section%20of%20Speculator%20Skill.pdf
- Chague, De-Losso, Giovannetti: https://papers.ssrn.com/sol3/papers.cfm?abstract_id=3423101
- Batchelor & Kwan (2007): https://www.sciencedirect.com/science/article/abs/pii/S0169207007000714
- Armstrong (2001): https://repository.upenn.edu/marketing_papers/150/
- Grove và cộng sự (2000): https://pubmed.ncbi.nlm.nih.gov/10752360/
- Biais & Weber (2009): https://papers.ssrn.com/sol3/papers.cfm?abstract_id=1209774
- Fenton-O'Creevy và cộng sự (2003): https://eprints.lse.ac.uk/14954/
- Kavajecz & Odders-White (2004): https://papers.ssrn.com/sol3/papers.cfm?abstract_id=315660
- Kaminski & Lo (2014): https://dspace.mit.edu/bitstream/handle/1721.1/114876/Lo_When%20Do%20Stop-Loss.pdf
- Joubert (2022); Singh & Joubert: https://papers.ssrn.com/sol3/papers.cfm?abstract_id=4032018 ; https://hudsonthames.org/wp-content/uploads/2022/04/Does-Meta-Labeling-Add-to-Signal-Efficacy.pdf
- Bailey và cộng sự, PBO: https://papers.ssrn.com/sol3/papers.cfm?abstract_id=2326253
- Hasanhodzic, Lo, Viola (2010): https://arxiv.org/abs/1002.4592
- Darmanin (2026, chưa phản biện): https://arxiv.org/abs/2607.20093
- Barber & Odean (2000): https://papers.ssrn.com/sol3/papers.cfm?abstract_id=219228
- Chan và cộng sự (2022): https://www.mdpi.com/2227-7390/10/20/3888
- Intraday return predictability (commodity ETFs, gold): https://pmc.ncbi.nlm.nih.gov/articles/PMC7480318/

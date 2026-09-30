# Nghiên cứu điểm vào, dừng lỗ, chốt lời cho bot vàng M1/M5 (29/09/2026)

Nguồn: 5 nhóm tra cứu song song (học thuật; mã nguồn mở/cộng đồng; cách tìm lợi thế khi hướng khó đoán;
nơi chia sẻ/bán EA; rà lại repo) và phân tích riêng. Đây là **tài liệu nghiên cứu**, không phải luật bot.
Luật vẫn là `docs/SPEC.md`; mọi ý dưới đây chỉ thành luật sau khi chủ bot duyệt và ghi vào SPEC.

Nhãn độ tin: **[BẰNG CHỨNG]** nghiên cứu có bình duyệt hoặc kiểm độc lập có tính phí; **[YẾU]** một lần đo,
blog, chưa tính phí hoặc chưa kiểm dữ liệu chưa dùng; **[CHƯA KIỂM]** chỉ lời quảng cáo/chưa mở được nguồn gốc.
Một số bài 2025–2026 chỉ được tóm tắt qua công cụ tra cứu, chưa đọc lại từng trang; Myfxbook và Forex Factory chặn công cụ tra cứu.

## 1. Toán cơ bản — vì sao đổi SL/TP một mình không tạo lời

- Gọi R = khoảng dừng lỗ, k = chốt lời/dừng lỗ, c = chi phí (spread + trượt) tính theo R, p = tỷ lệ thắng.
  Kỳ vọng mỗi lệnh = p·k − (1−p) − c (đơn vị R). Hòa vốn khi p = (1+c)/(1+k).
- Nếu giá không có hướng: p = 1/(1+k), kỳ vọng = −c với **mọi** k. Chốt xa hơn thì thắng ít hơn đúng theo tỷ lệ.
  [BẰNG CHỨNG: bài toán phá sản con bạc; Kaminski & Lo 2014 https://dspace.mit.edu/bitstream/handle/1721.1/114876/Lo_When%20Do%20Stop-Loss.pdf]
- "Dừng lỗ nhỏ + chốt lời xa + thắng cao" chỉ có được khi điểm vào có thông tin hướng thật. Không tìm thấy EA vàng
  nào có kết quả chạy thật được xác minh đạt cả ba cùng lúc.
- Chi phí theo khung (số HANDOFF): spread ≈ 11–13% ATR M1, 5–6% ATR M5, 3% ATR M15.
  Ở 1R:1R cần thắng khoảng 55–56% nếu dừng cỡ ATR M1; 52,5–53% cỡ M5; 51,5% cỡ M15.
- Cỡ mẫu (một phía, 5%, lực 80%): phân biệt 53% với 50% cần ~1.700 lần thử; 55% với 50% cần ~620.
  Tháng 8: 162 lệnh, sai số của hiệu bot − ngẫu nhiên ≈ 5,5 điểm, nên 46,5% vs 44,6% chưa phân biệt được.
- Đã thử hơn 328 biến thể: tổ hợp tốt nhất của nhiễu thuần có z ≈ 2,9. Kết quả trong mẫu có z < 3 không nói lên gì.
  [BẰNG CHỨNG phương pháp: Bailey & López de Prado, Deflated Sharpe Ratio https://papers.ssrn.com/sol3/papers.cfm?abstract_id=2460551]

## 2. Cản giá có tác dụng không?

- Mức hỗ trợ/kháng cự do 6 công ty FX công bố: giá dừng lại 60,8% so với 56,2% ở mức ngẫu nhiên (hơn 4–5 điểm).
  Chưa kiểm lời sau phí. [BẰNG CHỨNG: Osler 2000 https://papers.ssrn.com/sol3/papers.cfm?abstract_id=888805]
- Sổ lệnh thật của một ngân hàng: lệnh chốt lời dồn **đúng** số tròn → giá hay đảo ở đó; lệnh dừng lỗ dồn **ngay sau**
  số tròn → khi phá qua giá chạy nhanh thêm 30–60 phút. [BẰNG CHỨNG: Osler 2003, 2005
  https://www.newyorkfed.org/medialibrary/media/research/staff_reports/sr125.pdf ;
  https://faculty.georgetown.edu/evansm1/New%20Micro/osler1.pdf]
- Vàng có "rào tâm lý" ở mốc $10 và $100 (dữ liệu ngày). [BẰNG CHỨNG: Aggarwal & Lucey 2007
  https://www.sciencedirect.com/science/article/abs/pii/S1058330006000218]
- Mức đã bật nhiều lần có xác suất bật cao hơn, giảm dần theo thời gian. [BẰNG CHỨNG, chứng khoán:
  Garzarelli 2014 https://pmc.ncbi.nlm.nih.gov/articles/PMC3967202/ ; YẾU: Chung & Bellotti 2021 https://arxiv.org/abs/2101.07410]
- Hỗ trợ/kháng cự trùng nơi sổ lệnh dày; chúng chỉ ra chỗ có thanh khoản, không đoán hướng.
  [BẰNG CHỨNG: Kavajecz & Odders-White 2004 https://academic.oup.com/rfs/article-abstract/17/4/1043/1570736]
- Quy tắc hỗ trợ/kháng cự trong ngày của chuyên gia FX: không có lời sau phí. [BẰNG CHỨNG: Curcio và cộng sự 1997
  http://support-and-resistance.technicalanalysis.org.uk/Curcio-etal1997.pdf ; Neely & Weller 2003
  https://ideas.repec.org/a/eee/jimfin/v22y2003i2p223-237.html]
- FVG trên vàng, chỉ số, bạc 2019–2026 (~40.000 vùng, có phí/trượt): giá phản ứng hơn mức ngẫu nhiên ~5 điểm nhưng
  **không cách vào nào có lời sau phí**; bản 5–15 phút tệ nhất, H1 gần hòa. [BẰNG CHỨNG, chưa bình duyệt:
  https://mpmmarkets.com/research/does-the-fair-value-gap-strategy-work]
- Vào ở mức hồi Fibonacci/50%: không hơn ngẫu nhiên. [BẰNG CHỨNG, chưa bình duyệt:
  https://mpmmarkets.com/research/do-fibonacci-pullbacks-actually-make-money]

## 3. Lệnh chờ ở nhịp hồi so với lệnh thị trường

- Lệnh mua giới hạn khớp nhiều hơn khi giá đang giảm; lệnh đã khớp có kết quả kém hơn (chọn nhầm bất lợi).
  [BẰNG CHỨNG: Linnainmaa 2010 https://onlinelibrary.wiley.com/doi/abs/10.1111/j.1540-6261.2010.01576.x]
- Lệnh giới hạn chỉ có lợi khi biến động ngắn hạn tự quay lại và mình không kém thông tin.
  [BẰNG CHỨNG: Handa & Schwartz 1996 https://onlinelibrary.wiley.com/doi/abs/10.1111/j.1540-6261.1996.tb05228.x]
- Trên MT5 CFD, lệnh mua giới hạn vẫn khớp ở Ask nên vẫn trả spread.
- Khớp với các thử nghiệm cũ của repo: bot lệnh chờ BotScalpPhanUng khớp sau ≥60 giây mất 47,11 USD; vào ở mức hồi 50% không giúp.
- Lệnh chờ dạng stop (chỉ khớp khi giá quay lại vượt mốc, tức cú phá đã hỏng) tránh được cảnh "giá phá thẳng qua".
  [YẾU: Connors & Raschke "Turtle Soup", kiểm trên hợp đồng tương lai ngày bị xếp hạng thấp https://oxfordstrat.com/trading-strategies/turtle-soup-plus-1/]

## 4. Quét đỉnh/đáy rồi đảo chiều

- Không có nghiên cứu bình duyệt ủng hộ. Bằng chứng học thuật (Osler 2005) nghiêng về phá qua cụm dừng thì chạy tiếp.
- Tỷ lệ "68–72% phá vỡ M1 thất bại" trên blog cũng là điều bước ngẫu nhiên tạo ra. [YẾU]
- EA mã mở vàng M15 (quét ≥0,15 ATR → nến đóng vượt OB ≥0,3 ATR trong 3 nến → vào thị trường; SL 0,1 ATR ngoài râu; TP 2R;
  lọc EMA50 H1; SL ≥ 3 lần spread): 2025 hệ số lời/lỗ 1,12, 2026 1,10; không phí, một sàn, không kiểm dữ liệu chưa dùng.
  [YẾU: https://www.mql5.com/en/code/77639]
- S07 hiện tại của bot gần giống cách này và lỗ nặng nhất (−409 USD/67 lệnh tháng 8).

## 5. Giờ giao dịch, biến động, tin

- Biến động vàng đoán được (theo giờ trong ngày, HAR-RV); hướng thì không. [BẰNG CHỨNG:
  https://www.sciencedirect.com/science/article/abs/pii/S2405851318300102 ; Andersen & Bollerslev
  https://public.econ.duke.edu/~boller/Published_Papers/joef_00.pdf]
- XAUUSD 2019–2024, dự báo biến động đúng ngoài mẫu nhưng chiến lược đảo về trung bình trên đó lỗ:
  ~22.000 lệnh, thắng 55%, hệ số lời/lỗ 0,54; lời nhỏ không bù spread. [YẾU, có spread theo thời gian:
  https://github.com/vanillaextractor/XAUSD_STRATEGY]
- Tin kinh tế Mỹ 8:30 giờ New York làm vàng chạy nhanh. [BẰNG CHỨNG:
  https://www.sciencedirect.com/science/article/abs/pii/S0378426611001968]
- Đà trong ngày (nửa giờ đầu báo nửa giờ cuối) là tầm 30 phút theo phiên sàn, không áp cho M1/M5.
  [BẰNG CHỨNG: Gao, Han, Li & Zhou 2018 https://papers.ssrn.com/sol3/papers.cfm?abstract_id=2440866]
- Lọc giờ và biến động chỉ **giảm chi phí theo R** (ví dụ −0,12R → −0,03R mỗi lệnh), không tự tạo lời.

## 6. EA được chia sẻ/bán — kết quả chạy thật

- Các EA vàng có kết quả chạy thật được xác minh và có dừng lỗ cứng đều **quyết định ở M15/H1/D1**, giữ lệnh 4–16 giờ,
  phần lớn là phá vùng có xác nhận, dừng cứng + chốt lời kéo theo. Ví dụ Gold Reaper (tín hiệu MQL5 138 tuần,
  +277%, thắng 72,5% nhưng lời TB 11,94 < lỗ TB 16,30, sụt số dư 45,6%) [https://www.mql5.com/en/signals/2195619].
  Có nguồn cho rằng EA này dùng lưới, các nguồn không thống nhất.
- Lời thật thấp hơn nhiều so với đo lại quá khứ (Gold Reaper: 2,72 khi đo lại, 1,08–1,93 khi chạy thật); sụt 30–45% là thường.
- Phá biên đầu phiên đơn thuần đã thất bại khi chạy thật (ORB Master: 52 tuần −18,5%, hệ số 0,89)
  [https://www.mql5.com/en/signals/2336314].
- EA M1/M5 "thắng 90%+": lỗ TB gấp 5–8 lần lời TB, lưới/gấp thếp/không dừng cứng (Quantum Emperor, Waka Waka,
  AI Gold Sniper, EA Gold Stuff...) [https://newyorkcityservers.com/blog/quantum-emperor-review ;
  https://newyorkcityservers.com/blog/waka-waka-ea-review]. Trái luật dự án, không dùng.
- Một bot công khai lỗ nặng (hệ số 0,72) vì chốt một phần ở 1R trong khi dừng lỗ giữ nguyên
  [YẾU: https://dev.to/alallaqi/i-built-a-gold-trading-bot-from-scratch-heres-what-actually-works-and-what-destroyed-my-account-3pij].
- Cổng chi phí trong EA mã mở: chốt ≥ 4 lần chi phí khứ hồi, dừng ≥ 2,5–3 lần spread, spread ≤ 10% dừng
  [https://github.com/n30dyn4m1c/gold-pro-scalper ; https://www.mql5.com/en/code/77691].

## 7. Dừng lỗ và chốt lời

- 567.000 lượt đo lại trên 40 hợp đồng tương lai (có phí/trượt): chốt cố định, hòa vốn, đảo chiều xếp trên;
  kéo dừng kiểu Chandelier/kênh/đường trung bình/Parabolic xếp dưới. [YẾU→BẰNG CHỨNG thực nghiệm lớn:
  https://kjtradingsystems.com/algo-trading-exits.html]
- Đặt dừng theo quãng đi ngược lớn nhất (MAE) của các lệnh thắng; đặt chốt theo quãng đi thuận lớn nhất (MFE). Cần ≥100 lệnh.
  [Sweeney https://store.traders.com/-v05-c04-usingma-pdf.html]
- Kiểm điểm vào độc lập với cách thoát: thoát sau N nến cố định, so với vào ngẫu nhiên.
  [https://bettersystemtrader.com/162-building-effective-entries-and-exits-kevin-davey/]
- Không đặt dừng ngay sau số tròn/đỉnh đáy rõ (chỗ lệnh dừng dồn); đặt chốt ngay trước số tròn (Osler).

## 8. Lọc tín hiệu bằng mô hình

- Lọc lại tín hiệu bằng mô hình phụ (meta-labeling): độ chính xác tăng 0,48→0,54 (xu hướng), 0,17→0,20 (đảo về)
  trên E-mini; chủ yếu giảm lỗ, cần tín hiệu gốc có thông tin. [YẾU: https://hudsonthames.org/does-meta-labeling-add-to-signal-efficacy-triple-barrier-method/]
- Cần ≥1.000 tín hiệu có nhãn; kiểm chéo có loại chồng lấn thời gian. MQL5 chạy được ONNX trong máy thử
  [https://www.mql5.com/en/docs/onnx]; hồi quy logistic 3–5 biến có thể viết thẳng hệ số trong MQL5.

## 9. Những gì repo còn thiếu để đo công bằng

- Phép so ngẫu nhiên/ngược chiều/đua 1R:1R của tháng 8 chạy bằng script tạm, không còn trong repo.
- Mã lệch SPEC đáng chú ý: vùng M1 thực tế không bao giờ làm đích; xung đột bỏ cả loạt đề nghị; S05 có thể vào cuối nến rất dài;
  chưa có đỉnh/đáy ngày-tuần trước và số tròn; FVG không bao giờ được nâng thành STRUCTURE_CONFIRMED.

## 10. Hướng đề xuất (chờ chủ bot duyệt)

0. Công cụ đo tín hiệu trong MQL5 (bắt buộc trước): mọi tín hiệu, MFE/MAE 1/5/15/60 phút, đua ±R ở nhiều cỡ R,
   đối chứng ngẫu nhiên cùng giờ, đánh ngược, mức giá ngẫu nhiên; lệnh chờ trên giấy.
1. Giảm chi phí theo R: cản và dừng theo khung lớn, M1/M5 chỉ canh vào; lọc giờ/tin; đệm trượt theo số đo thật.
2. Chỉ cản có căn cứ: khung M15 trở lên, đỉnh/đáy ngày-tuần trước, số tròn $10/$50/$100, cản đã bật nhiều lần.
3. Kiểm tối đa 3 ứng viên chốt trước trên 07–09/2026, một lần, có đối chứng ngẫu nhiên.

Không nên theo: chỉnh thêm hình học SL/TP khi điểm vào chưa có lợi thế; lệnh chờ ở nhịp hồi khi chưa chứng minh cản tự quay lại;
quét-rồi-đảo làm lợi thế độc lập; tín hiệu "dòng lệnh" từ tick báo giá Exness; mô hình nến làm nguồn lợi thế;
lưới, gấp thếp, dừng lỗ xa gấp nhiều lần chốt lời; chỉ đo trên giai đoạn vàng tăng 2024–2026.

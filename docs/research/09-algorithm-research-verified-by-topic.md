===== verify:regime =====
TÓM TẮT ĐÃ KIỂM CHỨNG: bộ lọc chế độ thị trường và điều kiện dừng-rồi-đảo cho BotVang v1

Tôi đã kiểm tra 18 nhận định: 16 đúng, 1 sai do gán nhầm nguồn (luật Turtle), 1 không kiểm chứng được (con số 50-100 bps trong bản working paper của Kaminski-Lo). Tôi cũng chạy lại mô phỏng độc lập bằng Python và ra kết quả gần như trùng với mô phỏng của người nghiên cứu.

1. Công thức và mặc định: đã đọc code, đáng tin
- iADX của MT5 (ADX.mq5) KHÁC Wilder. Nó chia PD = 100*(+DM)/TR cho từng nến rồi làm mượt bằng EMA với alpha = 2/(N+1). Bản Wilder làm mượt RMA (alpha = 1/N) cho +DM, -DM và TR trước rồi mới chia. N = 14. Nếu dùng ADX, hãy dùng iADXWilder (tức Wilder RMA).
- CHOP (mladen, CodeBase 21585): 100*log(tổng TR thật của n nến / (maxTH - minTL))/log(n), với TH = max(H, C[1]) và TL = min(L, C[1]); n = 14. Hai mức 38.2 và 61.8 chỉ là số Fibonacci, code không có ngưỡng nào.
- AMA/ER (AMA.mq5): mặc định 10/2/30. ER = |P - P[n]| / tổng|ΔP|. SC = (ER*(2/3 - 2/31) + 2/31)^2.
- Squeeze của LazyBear có lỗi: dev = 1.5*stdev, nên sqzOn thực chất là stdev(C,20) < SMA(TR,20).
- Indicator Hurst 76439 tính R/S trên GIÁ thay vì trên lợi suất. Thực tế chỉ có 4 thang đo (8 đến 64) và H bị kẹp trong [0, 1]. Kết quả là H khoảng 0.97 và 100% cửa sổ bị gắn 'xu hướng', nên không dùng được.
- VarianceRatio của arch: mặc định debiased, robust, overlap, trend = 'c'.
- CUSUM: logic trong code BlackArbsCEO đúng; getDailyVol dùng EWM span 100. Lưu ý repo mlfinlab của hudson-and-thames hiện chỉ còn 'pass', không có code.

2. Tỷ lệ báo nhầm trên giá đi ngẫu nhiên: đã mô phỏng lại
Với giá không có xu hướng, các ngưỡng quen thuộc vẫn báo 'xu hướng' rất thường xuyên:
- ADX14 Wilder > 25: khoảng 36%.
- iADX14 > 25: khoảng 61%.
- CHOP14 < 38.2: khoảng 17.5%.
- ER10 > 0.3: khoảng 46%.

Muốn chỉ 10% báo nhầm thì ngưỡng phải khoảng ADX 37 hoặc ER20 0.45 trên M5. Khi đó bộ lọc trên M5 chỉ bắt được 16-27% số nến có xu hướng; lên H1 thì bắt được nhiều hơn hẳn. Tuy vậy xu hướng dùng trong mô phỏng (0.15 sigma mỗi nến M5) là rất mạnh, và nhiễu là Gauss. Vì vậy chỉ nên tin kết luận định tính: ngưỡng sách vô nghĩa, và khung H1 tốt hơn M5. Ngưỡng cụ thể phải hiệu chỉnh lại trên dữ liệu XAUUSDm thật.

3. Bằng chứng thực nghiệm về bộ lọc: yếu
- Bài 22754 (EURUSD H1, kiểm tra ngoài mẫu 2022-2024) có số liệu khớp: 546 lệnh với -0.9 pip/lệnh; 51 lệnh với -1.2 pip và thắng 47.1%; 29 lệnh với -0.4 pip. Bộ lọc ADX/ADXR chỉ giảm số lệnh và giảm sụt vốn, không biến kỳ vọng âm thành dương.
- Bài 22553 (NQ M1, 133 phiên): H khoảng 0.51 và không dự báo được; kết quả tốt nhất p = 0.094.
- Chưa có nghiên cứu ngoài mẫu nào về bộ lọc chế độ trên vàng M5.

4. Nền lý thuyết cho lệnh đảo: đáng tin
- Kaminski-Lo (bản JFM; dữ liệu futures S&P và trái phiếu 10 năm theo ngày, 1993-2011; không phải dữ liệu tháng 1950-2004) chứng minh: giá đi ngẫu nhiên thì dừng lỗ luôn làm giảm lợi suất kỳ vọng. Dừng lỗ chỉ có lợi khi có tự tương quan dương (rho phải lớn hơn khoảng Sharpe) hoặc khi chế độ thị trường chuyển đổi.
- Công thức hòa vốn cho lệnh đảo: p* = 0.5 + spread/(2B). Với spread 0.25 USD: B = 1.25 cần 60%, B = 2.5 cần 55%, B = 3.2 cần 53.9%. Nếu giá đi ngẫu nhiên thì mỗi lần đảo mất đúng một spread.
- Carver (nguyên văn): lọc theo đường vốn 'reduces rather than increases' lợi nhuận của hệ có lãi. Chỉ đáng xét khi tự tương quan của lợi nhuận chiến lược từ 0.2 trở lên, và các phép tính của ông chưa gồm chi phí. Vì vậy phanh 2 lệnh thua chỉ đáng giữ nếu nhật ký lệnh cho thấy các lần thua có tương quan với nhau.

5. Mẫu hình theo giờ của vàng: đúng, nhưng phạm vi hẹp
- Batten 2017 (vàng giao ngay, nến 5 phút): giao dịch nhiều nhất khoảng 11-17 GMT.
- Xu và cộng sự 2020 (GLD, chỉ giờ giao dịch Mỹ): động lượng trong ngày có R^2 0.49%, chỉ có ý nghĩa vào ngày biến động cao (t = 2.82 so với t = 0.44).
- Iwatsubo và cộng sự: kết quả về futures TOCOM/COMEX, không phải vàng giao ngay. Phiên Tokyo thiên về giao dịch không dựa trên thông tin mới; phiên New York thiên về giao dịch có thông tin.

6. Sửa sai
- Bài MQL5 23448 định nghĩa thắng/thua bằng lợi nhuận THẬT của lệnh (total_profit > 0). Bài không theo dõi breakout ảo, không có biến thể Whipsaw và không có luật giảm vốn 20% cho mỗi 10% sụt. Các luật này thuộc 'Original Turtle Rules' của Faith; phần Whipsaw (dừng lỗ nửa N, vào lại khi giá về giá vào ban đầu) tôi đã xác nhận ở nguồn đó.
- Con số '50-100 bps/tháng' trong bản working paper của Kaminski-Lo: tôi không mở được nguồn.

7. Ứng dụng cho bot (từ code Engine.mqh đã đọc)
- FlipAllowed cho đảo CÙNG bias mà không cần cổng chế độ thị trường nào. Đảo NGƯỢC bias được phép nếu vừa phá hoặc bật khỏi vùng trong 15 phút (3 nến M5).
- consLosses đếm chung cho lệnh chính và lệnh đảo.
- LowVolatility so ATR với trung bình 288 nến, nên phiên Á gần như luôn bị coi là biến động thấp.

Thứ tự đáng tin để làm tiếp:
(1) Đo trước khi thêm bộ lọc. Với mỗi lần dính dừng lỗ trong lịch sử, đo p = xác suất giá chạm +1B theo chiều đảo trước khi chạm -1B, chia theo phiên và theo cùng/ngược bias, rồi so với p*. Tính thêm VR(q = 3, 6, 12) bản robust cho lợi suất M5 theo từng phiên.
(2) Chỉ giữ lệnh đảo ở nhóm có p lớn hơn p* một cách có ý nghĩa thống kê.
(3) Nếu cần cổng chế độ, đặt nó trên H1: ADX Wilder, ER có dấu hoặc CHOP. Ngưỡng lấy theo phân vị trên dữ liệu vàng thật, kiểm tra theo cửa sổ trượt (walk-forward) và so với dữ liệu xáo trộn khối (block bootstrap).
(4) Không dùng iADX với ngưỡng 25, không dùng indicator Hurst 76439, không dùng ngưỡng CHOP 38.2/61.8 hay ER 0.3 theo sách.
(5) Kiểm tra runs test trên nhật ký lệnh trước khi quyết định giữ phanh 2 lệnh thua.
--- wrong claims:
* Luật Turtle theo bài MQL5 23448: 'thua' nghĩa là giá đi ngược 2N trước khi có lối thoát có lãi theo mức 10 ngày; có biến thể Whipsaw dừng lỗ nửa N; giảm vốn danh nghĩa 20% cho mỗi 10% sụt; bài chỉ có đồ thị. => Dòng code 'if(bar1_high > high_20 && !g_long.last_s1_winner)' có thật, nhưng bài 23448 định nghĩa thắng/thua là 'was_winner = (total_profit > 0)' của lệnh THẬT khi đóng hết unit. Bài không theo dõi breakout ảo, không có biến thể Whipsaw và không có luật 20%/10%; bài giữ rủi ro cố định 1% mỗi unit. Định nghĩa 2N và Whipsaw (nửa N, rủi ro 0.5%, vào lại khi giá về giá vào ban đầu) thuộc 'Original Turtle Rules' của Faith; phần Whipsaw tôi đã xác nhận trên blogspot chương 5. Luật 20%/10% tôi chỉ thấy qua đoạn trích tìm kiếm, chưa mở được bản PDF gốc. Kết quả số của bài nằm trong hình (Figure 7).
===== verify:zones =====
Tóm tắt đã hiệu chỉnh: những điểm đáng tin về thuật toán phát hiện vùng S/R cho BotVang v1.

1) Phần mã nguồn: tôi đã tự đọc code và xác nhận đúng.
- Shved S&D v1.7: fu = ATR(7)/2*0.75, nên band cao 0.75–1.125 ATR(7) của khung vùng. Fractal cố định 7 nến (nhanh) và 15 nến (chậm) ở mọi khung. Một lần chạm phải là fractal nhanh nằm trong band và cách lần trước ≥ 10 nến. Phá tính bằng RÂU. Phá 2 lần liên tiếp, hoặc vùng weak phá 1 lần, thì xóa. Vùng lật (turncoat) được reset số lần chạm. Chỗ researcher bỏ sót: khi gộp, vùng chưa có lần chạm bị gán hits=1 và thành VERIFIED, nên strength sau gộp bị thổi phồng. Không nên chép luật gộp này nguyên văn.
- SR Channels (LonesomeTheBlue v6): prd=10, ChannelW=5% của biên độ 300 nến, loopback=290, mỗi pivot 20 điểm. Điểm +1 chỉ tính khi HIGH hoặc LOW của nến nằm trong kênh, không tính thân. minstrength=1 nên 1 pivot đã đủ.
- Malaysian SnR [DoN]: pivot trên giá đóng cửa 3/3; band từ close tới râu của nến pivot; phá khi close qua đường mức; lịch sử SBR/RBS bị xóa khi close quay lại. Decision level H4 = open[1] khi hai nến H4 đã đóng cùng màu, nên KHÔNG repaint. Chỉ pivot HTF (D1) có thể đổi trong lúc nến D1 đang chạy.
- okinawan21: dùng lookahead_on trên nến HTF hiện tại, nên rò rỉ tương lai trên dữ liệu lịch sử. Không dùng để kiểm tra hay backtest.
- LuxAlgo: ngưỡng equal high/low = 0.1*ATR(200), xác nhận bằng pivot 3 nến. Bộ lọc nến biến động mạnh = 2*ATR(200). Breaker được tạo khi thân nến đóng qua đáy OB và bị hủy khi close vượt đỉnh OB. SR with Breaks dùng pivot 15/15 và dao động khối lượng EMA 5/10 > 20%.
- MQL5 21677 (RatioMultiplier 3.0, ViolationMultiplier 1.5, H1) và 19674 (tính theo points, chỉ phá khi vùng chưa được test, không gộp vùng chồng lấn): tham số đúng như báo cáo, không có số liệu kiểm chứng.
- pricelevels: sklearn mặc định linkage 'ward', nên distance_threshold không phải trần độ rộng giá của cụm. Có lỗi rolling().min() cho High. Điểm TouchScorer −2/−1/+1/+2 là đúng.
- neurotrader KDE: bw_method nhận hệ số nhân với độ lệch chuẩn chứ không nhận băng thông theo ATR. ZigZag theo ATR xác nhận đỉnh khi giá hồi đủ 1 ATR.

2) Phần bằng chứng thực nghiệm, sau khi hiệu chỉnh.
- Osler 2000 là bằng chứng chính. Mức S/R do các công ty công bố bật lại 60.8%, mức ngẫu nhiên bật 56.2% (10,000 bộ). Lợi thế 4.0–5.6 điểm phần trăm, có ý nghĩa ở 13/16 cặp công ty–tiền tệ, kéo dài ≥ 5 ngày làm việc. Dữ liệu là FX 1996–1998. SỬA định nghĩa 'bounce': giá vẫn ở phía ban đầu của mức TẠI thời điểm t+15 phút (bài cũng thử t+30 phút). Đây không phải 'không cắt qua trong 15 phút'. 'Hit' là giá tới trong 0.01% của mức; với vàng 4300, 0.01% ≈ 0.43 USD. Muốn đối chiếu với con số 56%/61% thì bot phải dùng đúng định nghĩa này. Tỷ lệ nền của vàng thì chưa biết, phải tự đo.
- Osler 2003: 9,667 lệnh, 9/1999–4/2000. Take-profit khớp đúng tại đuôi 00 là 9.3%, stop-loss là 4.4%. Stop-loss mua gom ở đuôi 01–10 (14.4%, so với 7.4% ở 90–99); stop-loss bán đối xứng, gom ngay dưới 00/50. Đáng tin về cơ chế. Hàm ý cho bot: không đặt SL ngay sau $X00/$X50.
- Chung & Bellotti 2021 (preprint, dữ liệu 1 phút năm 2018): số bounce trước đó giúp dự báo lần bật tiếp theo. Mức giảm dần theo ĐỘ DÀI CỬA SỔ dùng để tìm mức: trên EURUSD, mức 1 bounce về 0.5 ở khoảng 350 phút, mức 4 bounce ở khoảng 900 phút. Đây là cơ sở dè dặt cho 'strength suy giảm theo thời gian', chưa phải hàm suy giảm theo tuổi vùng.
- Garzarelli 2014: SỬA. Kiểm định χ² chỉ có ý nghĩa tới 60 giây. Ở 90 giây p = 0.13/0.17, không có ý nghĩa; ở 180 giây p = 0.38/0.99. Không nên dùng bài này làm căn cứ cho M5/M15.
- O'Connor & Lucey 2016: giá fix London AM/PM của vàng 1975–2015 (20,452 quan sát) có rào cản ở đuôi 0 và 00. Chỉ dùng làm yếu tố confluence, vì là dữ liệu fix chứ không phải intraday.
- MQL5 20904: chỉ mô tả hình dạng nến trên XAUUSDr M5, không có kết quả tương lai. Chính bài đề xuất thân base ≤ 0.3 ATR và tỷ lệ exit/base ≥ 3.0, chặt hơn mức 0.5 ATR và 2–3 lần mà researcher đưa ra. Các ngưỡng này chỉ là giả thuyết, cần kiểm chứng.

3) Kết luận thực dụng cho bot.
Không có chỉ báo vùng nào (Shved, LuxAlgo, DoN, Matrix, SR Channels) công bố hiệu quả. Chỉ dùng chúng làm nguồn logic. Những phần mượn được, đã kiểm chứng ở mức code: máy trạng thái fresh → touched → broken → flipped → invalid (Shved, DoN, Breaker); luật hủy khi close ngược qua mép xa; gộp theo ngưỡng 0.1*ATR(200); loại nến ≥ 2*ATR(200).
Phá bằng THÂN nến qua mép xa là lựa chọn của bot, không có nguồn nào chứng minh tốt hơn râu. Cần tự đo.
Band kiểu Shved (0.75–1.125 ATR của khung vùng) hoặc 2*ATR(200) rộng hơn nhiều so với SL 0.8*ATR(M5). Cần kẹp band hoặc xem lại luật SL. Hai hướng này cần người dùng quyết định.
Bước bắt buộc: tái lập phương pháp Osler trên XAUUSD Exness, dùng đúng định nghĩa hit/bounce ở t+15 và t+30 phút, và ≥ 1,000 bộ mức ngẫu nhiên. Chỉ giữ yếu tố strength nào làm tăng tần suất bật so với ngẫu nhiên một cách ổn định.
Chưa kiểm chứng được: logic của Malaysian SnR [UAlgo] (trang vẫn trả 404) và SS_SupportResistance. Tỷ lệ ATR(H1)/ATR(M5) ≈ 3–3.5 là suy luận, chưa đo. Số chữ số thập phân và múi giờ server Exness chưa được xác nhận.
--- wrong claims:
* Định nghĩa của Osler 2000: 'hit' khi giá tới trong 0.01% của mức; 'bounce' khi giá KHÔNG vượt qua mức trong 15 phút. Recommendation (6) dựa vào đó để đề xuất 'không có thân M5 đóng qua mép xa trong 3 nến M5'. => Phần 'hit' đúng: giá bid/ask tới trong 0.01%, và bài thử thêm 0.00% và 0.02%. Phần 'bounce' SAI: bounce được kiểm tra tại MỘT thời điểm. Nguyên văn: 'the trend was interrupted if the bid (ask) price exceeded (fell short of) the support (resistance) level fifteen minutes later'. Tức là giá vẫn ở phía ban đầu của mức tại t+15 phút; bài thử thêm mốc 30 phút. Định nghĩa này không đòi hỏi 'không cắt qua trong suốt 15 phút'. Nếu bot muốn so sánh được với con số 56.2%/60.8%, phải dùng đúng định nghĩa này. Luật 'không thân M5 nào đóng qua mép xa trong 3 nến' là tiêu chí khác và chặt hơn, nên tỷ lệ nền sẽ khác.
* Garzarelli et al. 2014 (Sci. Rep. 4:4487): 9 cổ phiếu LSE năm 2002, dữ liệu tick. Hiệu ứng nhớ có ý nghĩa tới thang 90 giây (p<0.001–0.002) và biến mất ở 150–180 giây. => Table 1 (kiểm định χ², 3 bậc tự do) cho p-value của kháng cự/hỗ trợ: <0.001 ở 1, 15, 30, 45 giây; 0.002/0.001 ở 60 giây; 0.13/0.17 ở 90 giây, KHÔNG có ý nghĩa; 0.38/0.99 ở 180 giây. Chú thích bảng ghi 'up to the 60–90 seconds timescale'. Như vậy p<0.001–0.002 chỉ đúng tới 60 giây. Phân tích độ dốc riêng cho kết quả khác: độ dốc của kháng cự khác 0 ở mọi thang tới 180 giây, còn của hỗ trợ tiến về 0 khi thang trên 150 giây. Kết luận: bằng chứng chỉ ở thang dưới 1–3 phút, gần như không liên quan tới M5/M15.
===== verify:strength =====
Tôi đã mở lại nguồn và kiểm tra 19 nhận định. 17 nhận định đúng. Hai nhận định sai một phần: day0market (chạm từ trên KHÔNG đối xứng) và dải giá vàng mà O'Connor–Lucey dùng. Có vài chỗ cần diễn đạt lại (Strong SR, Chung, Garzarelli, Bulkowski). Tôi đã tự đọc source code của Shved v1.7, LonesomeTheBlue (Channels, Dynamic v2), LuxAlgo Strength Classifier, Strong SR Zones, MAP, day0market TouchScorer và smartmoneyconcepts. Pine lấy qua pine-facade của TradingView.

1) Phần code có thể tin để mượn
- Shved v1.7. Mọi công thức đều đúng như báo cáo. Bề dày vùng là 0.75–1.125 × ATR(7). Fractal 7 và 15 nến mỗi bên. Phá tính bằng râu. Phá lần 2 hoặc vùng yếu thì xoá. Lật thì testcount = 0. Xếp hạng PROVEN > 3 test; TURNCOAT = 1 trên thang 0–4. Bổ sung:
  - Sau khi lật, lần chạm được đếm bằng fractal loại ngược lại.
  - Lần chạm đầu phải cách nến gốc hơn 10 nến.
  - Mâu thuẫn với bot là có thật: vùng vừa lật chưa test, tức điểm vào chính của bot, bị Shved xếp gần thấp nhất.
- LuxAlgo Strength Classifier. Đúng: dist là trung bình biên độ tích luỹ từ đầu lịch sử, close phá thì xoá vùng. Nên thay dist bằng ATR cuộn.
- LonesomeTheBlue. Đúng: điểm = 20 × pivot + số nến chạm. minstrength = 1 vẫn cho qua kênh 1 pivot. Riêng bản Channels báo phá bằng biên kênh; chỉ bản v2 dùng điểm giữa kênh.
- Strong SR Zones. Công thức đúng. Bổ sung:
  - Gộp pivot không làm tăng touches.
  - Trên phần hiển thị, điểm tuổi thực tế tối đa khoảng 2.
  - Thưởng cho tuổi vẫn là ngược bằng chứng.
- MAP. Đúng: suy giảm tuyến tính có sàn 0.5, tuổi đo bằng số pivot, số lần chạm không vào công thức điểm.
- day0market. Có HAI lỗi chứ không phải một:
  - rolling_highs dùng .min() thay vì .max().
  - Nhánh chạm từ trên chấm ngược: cực trị được +2, không cực trị được +1.
  - Cờ cực trị dùng cửa sổ 3 nến.
  - Ý 'thân cắt −2, râu cắt −1' và 'chỉ tính chạm khi giá đến từ xa ít nhất 0.5%' vẫn đúng.
- smartmoneyconcepts. Đúng. Có nhìn trước tương lai: swing xem trước 50 nến, pip_range lấy trên toàn bộ dữ liệu.
- Không có indicator hay EA nào trong danh sách công bố backtest có đối chứng. Các bài MQL5 19674, 20904, 21677 chỉ có tham số và thống kê mô tả. Bài 20904 ghi rõ chỉ lượng hoá cú rời vùng; ATR 14; 'ứng viên mạnh' là tỷ lệ > 1.5. Không bài nào có tỷ lệ thắng.

2) Bằng chứng thực nghiệm đáng tin (đã đọc toàn văn)
- Osler 2000 (FX 1996–1998, quote 1 phút):
  - Mức S/R thật nảy nhiều hơn mức ngẫu nhiên +4,0 đến +5,6 điểm %, hãng tốt nhất +9,2.
  - Điểm 'strength' chuyên gia tự chấm vô dụng: các hiệu số có ý nghĩa đều âm.
  - Mức được nhiều hãng đồng thuận (hợp lưu) không tốt hơn.
  - Sau 5 ngày còn tác dụng, chỉ giảm 1,7 điểm.
  - Khi biến động trở lại bình thường thì chỉ còn có ý nghĩa ở một nửa số trường hợp.
  - Sắc thái quan trọng: mức ngẫu nhiên nảy trên 50% một phần vì dung sai 'hit'. Với dung sai 0,00%, chúng nảy hơi dưới 50%. Vậy band càng dày thì tỷ lệ nảy càng cao giả tạo. Chung–Bellotti cũng xác nhận δ lớn làm p(b) cao lên.
- Osler 2001/2005 (sổ lệnh của một ngân hàng, 1999–2000):
  - 8,7% lệnh đặt đúng mức 00.
  - Khi giá lên tới 00, 10,5% lệnh TP bán được kích hoạt so với 2,8% lệnh stop mua.
  - Stop mua tụ ở [01,10] (14,3%) so với [90,99] (6,9%).
  - Tại số tròn giá nảy nhiều hơn ngẫu nhiên +4,6 điểm; khi vượt qua thì tăng tốc, có ý nghĩa ở thang giờ.
- Garzarelli (tick, cổ phiếu LSE 2002):
  - p(nảy) tăng theo số lần nảy trước, so với chuỗi xáo trộn phẳng quanh 0,5.
  - χ² có p < 0,0001 ở 45/60/90 giây; không có ý nghĩa ở 180 giây.
  - Không kiểm được dải 0,55–0,63: văn bản không ghi số, chỉ đọc gần đúng từ đồ thị.
- Chung–Bellotti (1 phút, 2018):
  - Xác nhận p tăng theo b_prev và có suy giảm.
  - Cần diễn đạt lại: 350/900 phút là độ dài CỬA SỔ dùng để xác định mức. Hiểu thành 'tuổi vùng 6 giờ / 15 giờ' chỉ là xấp xỉ.
  - Logistic chỉ có ý nghĩa với b_prev = 4 và 5.
- Neely–Weller 2003: tính chi phí 1–2 bp một chiều và giờ giao dịch thì hết lợi suất vượt trội trong ngày.
- Bulkowski (cổ phiếu Mỹ khung ngày, không có kiểm định):
  - 58% cú phá có throwback; 35% trong số đó thủng tiếp.
  - Giữ được trên điểm phá thì tăng 40%, so với 29%.
  - 97% loại mẫu hình tốt hơn khi KHÔNG có throwback. Nguồn là studystudy.html, không phải ThrowPull.
- Vàng: Aggarwal–Lucey và O'Connor–Lucey xác nhận rào cản quanh 00 là có nhưng yếu, dữ liệu ngày hoặc giá fix. O'Connor–Lucey trải dải giá khoảng 100–1.900 USD, không phải 250–850. Áp sang giá 4300 trên M5 vẫn là suy diễn.

3) Hàm ý cho BotVang (tách khỏi phần heuristic)
- Có cơ sở:
  - Cộng điểm đơn điệu theo số lần NẢY thật (không đếm lúc đi ngang trong band), bão hoà khoảng 4.
  - Có suy giảm theo thời gian. Không thưởng cho tuổi như Strong SR.
  - Bỏ trọng số hợp lưu hay khung thời gian cộng tay, hoặc để rất nhỏ.
  - Hiệu chỉnh điểm bằng mức ngẫu nhiên CÙNG bề dày band (khung Osler), không so với 50%.
  - Ngưỡng hoà vốn bước đầu p* = 0,5 + c/(2B), khoảng 0,54–0,60 với spread 0,25. Phép tính đã kiểm lại.
  - Số tròn 00 > 50 > 0: có xu hướng phản xạ giá, còn vượt qua thì tăng tốc. Không đặt SL ngay sau số tròn.
- Chưa có bằng chứng:
  - Retest đầu của vùng lật trong ngày.
  - Mức vẽ trên thân nến (Malaysian SnR) so với mức dựng từ râu.
  - Tick volume của Exness.
  - Lực rời vùng hay thời gian ở vùng (OTA/Seiden chỉ là tài liệu giảng dạy).
  - Các hằng số τ và trọng số prior trong khuyến nghị. Đây là heuristic, phải kiểm định walk-forward trên dữ liệu XAUUSD của chính Exness.
--- wrong claims:
* day0market TouchScorer: thân nến cắt qua mức −2, râu cắt −1. Chạm từ dưới: +2 nếu nến không phải cực trị địa phương, +1 nếu là cực trị. Chạm từ trên làm đối xứng. Có lỗi: rolling_highs dùng .min() thay vì .max(). => Lỗi .min() là có thật. Nhưng 'chạm từ trên làm đối xứng' SAI. Trong nhánh touch_low, nến không phải cực trị nhận score_for_touch_high_low (+1), còn nến cực trị nhận +2, tức ngược với nhánh touch_high. Ngoài ra, cờ cực trị dùng cửa sổ rolling 3 nến (không phải 21; bars_for_peak = 21 chỉ thuộc bộ tìm mức trong cluster.py). Sự kiện CUT_WICK cũng ghi nhầm điểm −2 vào log (chỉ sai ở log, điểm vẫn cộng −1). Vậy code có hai lỗi logic, không phải một.
* Vàng: Aggarwal & Lucey (2007) thấy rào cản ở 100 USD (200, 300) nhưng không ở 310, 350 (COMEX ngày 1982–2002, UBS 15 phút 2001–2003), đóng vai kháng cự. O'Connor & Lucey (2016): giá fix London 1975–2015 có hệ số −0,2265%/ô quanh 00, có rào cản cho vàng, không cho bạc. Nhận định kèm theo: 'vùng giá 250–850 USD'. => Các kết quả chính khớp: 5.255 điểm COMEX và 12.938 điểm UBS; hệ số (0,2384% − 0,0119%) = 0,2265%; bạc không có ý nghĩa thống kê. Nhưng 'vùng giá 250–850 USD' sai với O'Connor–Lucey: giai đoạn 1975–2015 giá vàng đi từ khoảng 100 lên khoảng 1.900 USD (đỉnh 2011). Giai đoạn của Aggarwal–Lucey chỉ khoảng 250–500 USD. Kết luận 'khó áp sang 4300' vẫn đúng.
===== verify:stoploss =====
Tôi đã mở lại nguồn và kiểm 16 nhận định. Kết quả: 12 đúng, 1 sai (bài MQL5 16991) và 3 chưa kiểm chứng được (Glynn-Iglehart; ngưỡng 10% của Dai et al.; phần mô tả Turtle/Sweeney/Kestner do không có mã và không mở lại).

A. Các nhận định về mã đã kiểm và đáng tin
1) CTrailingFixedPips: lệnh mua có base = SL hiện tại (bằng giá mở nếu chưa có SL). Nếu Bid - base > 30·adjusted_point thì SL = Bid - delta và TP = Bid + 50·adjusted_point. Với vàng, 30 point = 0.30 USD. Vì base là SL hiện tại, lớp này kéo SL sát giá ngay cả khi lệnh đang lỗ. Cần sửa một chi tiết: CExpert chỉ xử lý mỗi tick khi every_tick=true. Mẫu Wizard mặc định là false, khi đó trailing chỉ chạy lúc có nến mới.
2) CTrailingMA: dùng SMA 12 của nến đã đóng (MA.Main(1)); lệnh bán cộng thêm spread; SL chỉ đi một chiều và chỉ dời khi MA đã vượt giá mở hoặc SL cũ.
3) Mẫu TrailingStop + TrailingStep (CodeBase 22001): SL dời khi lời > TS+Step và SL < giá - (TS+Step), rồi đặt SL = giá - TS. Mặc định 50/50/5/5 pip, phải quy đổi lại cho vàng.
4) CSimpleTrailing (bài 14862): khung start/step/offset. Khi sàn trả StopLevel = 0, dùng 2×spread làm khoảng cách tối thiểu.
5) EarnForex ATR trailing: SL mua = Bid - 1.0·ATR(14, nến 1), SL bán = Ask + ATR + spread. Mặc định không kích hoạt (EnableTrailingParam=false). Lỗi dùng nhầm ActivationATRMult ở nhánh lệnh bán là có thật.
6) ATR của MT5 là SMA của TR, không phải RMA.
7) Chandelier (mã everget): 22/3.0/useClose, lấy đỉnh trong 22 nến chứ không phải từ lúc vào lệnh.
8) Keltner của MetaQuotes: EMA20 ± 2·ATR(10), vẽ lệch 1 nến.
9) Kase DevStop (ProRealCode): n=20, hệ số 1/2.2/3.6, chiều theo SMA5/21.
Tất cả các mục trên chỉ là mã tham khảo, không có kiểm định thực nghiệm đi kèm.

B. Thang bậc của BotVang, đúng như Engine.mqh
- B = max(0.8·ATR(M5,14) của nến 1, 5·spread), cố định lúc vào lệnh.
- SL mua ban đầu = Ask - B. Bậc được đo và SL được kích hoạt theo Bid, nên giá phải đi B+s mới lên bậc 1, trong khi cự ly tới SL chỉ còn B-s.
- Hòa vốn ở +1B, sau đó SL = open + (n-1)B. Khi còn cách cản mạnh dưới B thì khóa lời ở giá - 0.5B.

C. Phần lý thuyết đã tính lại và khớp
- Nếu giá không có xu hướng và SL khớp đúng giá, kỳ vọng mỗi lệnh luôn bằng -spread, dù dời SL kiểu nào (định lý dừng tùy chọn). Tính theo R là -s/B: khoảng -0.125R khi B=2, và -0.20R khi B chạm sàn 5·spread.
- Xác suất lên bậc 1 trước khi dính SL là (B-s)/(2B), khoảng 0.44 hoặc 0.40.
- Nếu coi giá là chuyển động Brown với σ = ATR/1.6, xác suất SL 0.8·ATR bị chạm trong nến M5 đầu là khoảng 0.26. Đây là con số của mô hình, chưa đo trên dữ liệu thật.
- Khi có xu hướng kéo dài, độ trễ lớn hơn ăn được nhiều hơn (tôi mô phỏng lại được thứ tự và độ lớn: lag2 > lag1 > dời liên tục). Kết quả này phụ thuộc vào giả định xu hướng kéo dài không giới hạn thời gian, nên không phải dự báo cho bot.

D. Bằng chứng thực nghiệm, đã sửa
- Kaminski & Lo: công thức Δμ = -p_o·π khi giá là bước ngẫu nhiên là đúng. Hai bộ số đến từ hai phiên bản: 50-100 bps/tháng nằm trong working paper; +1.5% lợi suất, -5% biến động, Sharpe +20% là futures 1993-2011, chỉ ở một cách hiệu chỉnh theo tháng. Người nghiên cứu bỏ sót rằng chính bài báo ghi SL ngắn hạn cho phần bù âm trên một dải tham số rộng. Đây là bài toán phân bổ cổ phiếu/trái phiếu, không phải SL M5.
- Clare et al. 2013: đúng. S&P500 1988-2011, dời SL 3-15%, lợi suất cao nhất ở 12%, và SL làm kết quả tệ hơn quy tắc MA.
- Dai et al. 2021: chiều hướng đúng (giảm rủi ro; chi phí làm hỏng các mức dời chặt). Ngưỡng '10%' chưa kiểm được.
- Glynn & Iglehart: tóm tắt gốc không nói 'không dùng trailing là tối ưu'. Câu này đến từ nguồn thứ cấp và phát biểu cho trường hợp có xu hướng dương, nên không phải bằng chứng cho giá không xu hướng.
- Osler: các con số đúng (RBS 1999-2000, 9.655 lệnh, 43%, 14.3% so với 6.9%, TP đúng số 00 là 9.9% còn SL là 3.8%). Hiệu ứng có ý nghĩa thống kê ít nhất 2 giờ nhưng nhỏ (USD/JPY chỉ đi thêm khoảng 0.013% sau 15 phút) và là dữ liệu FX thập niên 1990.
- Bài MQL5 16991 bị mô tả sai. Thực tế là 1.942 deal (không phải 1.922 giao dịch) trên 9 mã, XAUUSD chỉ có 118 deal. Giao dịch gốc dùng SL100/TP500, còn mọi biến thể trailing dùng TP = 0, nên phần lời 'nhờ trailing' trộn lẫn với việc bỏ TP. VIDYA ra -283.3 USD bị bỏ qua, và tham số chọn ngẫu nhiên. Bằng chứng này hầu như vô giá trị.

E. Điều còn dùng được cho bot
- Trailing tự nó không tạo lợi thế. Chi phí spread/B và mức trôi hoặc tự tương quan của giá sau điểm vào mới quyết định kết quả.
- Việc cần làm trước tiên là ghi MFE/MAE theo từng nến và giá bóng sau khi thoát, rồi mới chọn B, độ trễ, điểm hòa vốn và SL theo thời gian.
- Có thể tách 3 tham số: điểm kích hoạt, độ trễ và bước tối thiểu. SL luôn phải chỉ đi một chiều, không dùng thẳng các lớp CTrailing* của Thư viện chuẩn, và nâng sàn spread trong B để chi phí không quá khoảng 10% R.
- Đặt SL theo cấu trúc (mép vùng cộng đệm, tránh cụm số tròn) và time stop chỉ là đề xuất thiết kế, chưa có kiểm định cho vàng M5. Mọi thay đổi cần kiểm thử trên tick thật theo kiểu cuốn chiếu (walk-forward).
--- wrong claims:
* MQL5 article 16991: chạy lại 1.922 giao dịch thật trên 9 mã (có XAUUSD) từ 13/09/2024, SL ban đầu 100 point; không dời -658, dời đơn giản -746, PSAR +541.8, SMA +563.1, AMA +806.5, FRAMA +1291.6, TEMA +1355.1, DEMA +1397.1 USD. => Các con số USD đúng, nhưng cách mô tả dữ liệu sai và bỏ sót một yếu tố gây nhiễu (confound). (1) Nhật ký ghi 'Total deals' theo mã: 222+120+526+352+182+22+250+150+118 = 1.942 deal, không phải 1.922 giao dịch. Mỗi giao dịch thường gồm 2 deal (vào và ra), nên số lệnh thực chỉ khoảng một nửa. XAUUSD chỉ có 118 deal và không có kết quả riêng. (2) Bảng kết quả cho thấy giao dịch gốc dùng SL 100 / TP 500, còn mọi biến thể trailing dùng TP = 0. Như vậy phần chênh lệch trộn lẫn tác động của việc bỏ TP với tác động của trailing. (3) Bảng còn có VIDYA -283.3 USD mà người nghiên cứu bỏ qua. (4) Tác giả tự ghi rằng tham số trailing 'chosen randomly'. Kết luận: bằng chứng rất yếu, không đủ để quy lợi nhuận cho trailing theo MA/PSAR.
===== verify:entry =====
TÓM TẮT ĐÃ HIỆU CHỈNH: Thuật toán vào lệnh tại vùng lật (phá rồi retest, first touch, nến xác nhận)

1. Mức độ tin cậy chung
- Tôi đã tự đọc mã của HoanGhetti, AGPro, DoN Malaysian SnR, LuxAlgo Breaker Blocks, smc.py, EarnForex, bản port Python của LonesomeTheBlue, và đọc code trong các bài MQL5 19638, 19674, 21677, 23155. Công thức và default mà researcher báo cáo nhìn chung chính xác.
- Tuy vậy, không nguồn nào có backtest đáng tin cho chuỗi "phá → tách xa → first touch → nến xác nhận". Mọi tham số (0.16/0.42/0.74 ATR, ngưỡng 1.5 lần chiều cao vùng, cửa sổ 2–3 nến...) chỉ là heuristic do tác giả tự đặt. Chúng chỉ nên dùng làm điểm khởi đầu để đo, chưa phải giá trị đã được chứng minh.

2. Công thức lấy được từ mã đã đọc
- Phá (AGPro): close(nến đã đóng) > mức + 0.16×ATR và close[1] <= mức + 0.04×ATR.
- Tách xa: AGPro đòi 0.34×ATR (đo bằng high cao nhất sau phá). MQL5 19674 và 19638 dùng hằng số point, không nên chép.
- First touch: HoanGhetti tính khi barssince(phá) > 2, còn AGPro trong 1–24 nến. Nếu áp vào band [lo,hi] của bot thì cần hai điều kiện: bar có chồng lấn band, và open ở đúng phía (theo DoN hoặc LuxAlgo).
- Xác nhận: có ba kiểu. (a) Một nến vừa chạm vừa đóng ra ngoài vùng (MQL5 19638/19674). (b) Trong 1–2 nến sau, có close >= high của nến chạm (HoanGhetti). (c) Open trong nửa trên band và close > hi (LuxAlgo).
- Hủy: close < giữa band (LuxAlgo). AGPro hủy khi close < mức − 0.29×ATR (bằng 0.70 × pocket 0.42) hoặc close < mức − 0.74×ATR, và hết hạn sau 24 nến nếu chưa chạm.
- Sửa lại khuyến nghị cũ:
  - Ngưỡng "hủy khi retest sâu hơn 1.35×ATR" KHÔNG có trong AGPro. Con số 1.35 ở đó chỉ là mốc của hàm điểm độ sâu, không phải điều kiện hủy.
  - Điều kiện tách xa max(0.35×ATR, 1×B) luôn bằng B, vì B >= 0.8×ATR. Tức ngưỡng này chặt gấp khoảng 2.4 lần AGPro; nếu giữ thì phải là lựa chọn có chủ ý.
- Vùng lật (MQL5 21677): nến phá phải có close vượt vùng, là nến cùng chiều, và range >= 1.5 lần chiều cao vùng. Khi lật thì reset first touch và thời hạn. DoN xóa mức HTF đã lật nếu có close quay lại xuyên qua; đây là một luật vô hiệu hóa flip dùng được.
- Cảnh báo mã:
  - smc.py có look-ahead (swing dùng 50 nến tương lai, xóa BOS dựa trên dữ liệu tương lai), không được dùng nguyên trạng cho backtest.
  - Thời hạn block của MQL5 19638 phụ thuộc mức zoom chart.
  - EarnForex có lỗi input: thiếu phép gán cho một tham số trong OnInit.
  - HoanGhetti mặc định repaint, và mức xác nhận bị dịch mỗi khi có low sâu hơn.

3. Bằng chứng thực nghiệm (sau khi kiểm)
- Osler 2000 (FX, dữ liệu từng phút, 1996–1998): giá bật tại mức S/R công bố 60.8%, tại mức ngẫu nhiên 56.2%.
  - Lợi thế có thật nhưng nhỏ, khoảng 4–5.6 điểm %.
  - Mức nhiều bên cùng đưa ra (confluence) và điểm strength tự gán đều không giúp. Strength score và confluence của bot cần tự kiểm chứng.
- Osler 2003: con số đúng là 9.3% lệnh take-profit ở 00, so với 4.4% lệnh stop-loss (không phải 8.7%).
  - Stop mua tụ ngay trên số tròn: 14.4% ở 00–09, so với 7.4% ở 90–99.
  - Hàm ý: số tròn vừa có xu hướng làm giá bật lại, vừa làm giá tăng tốc khi đã xuyên qua. Đây là dữ liệu FX, chưa kiểm cho vàng.
- Bulkowski (cổ phiếu, khung ngày) cần sửa hai điểm:
  - Con số 58% có throwback là mẫu từ năm 2000; con số 40%/29% đến từ một mẫu khác (1991–2005).
  - Trong mẫu đó, khoảng 87% throwback xuyên xuống dưới giá phá, chỉ 13% giữ được trên mức. Nếu bot đòi retest "nông, giữ trên mép vùng" thì sẽ loại phần lớn setup. Nên cho phép giá xuyên vào band nhưng bắt buộc có close quay lại ngoài band.
  - Ở 97% loại mẫu hình, throwback làm kết quả kém hơn. Trong ba cách vào sau throwback mà ông thử, tốt nhất là chờ close vượt lại đỉnh mẫu hình rồi vào ở giá mở cửa kế tiếp. Điều này ủng hộ kiểu "market hoặc stop sau xác nhận" hơn là limit.
- Mẫu nến:
  - Duvinage 2013 (dữ liệu 5 phút, 30 cổ phiếu DJIA) đã kiểm: sau phí và hiệu chỉnh data snooping, không luật nến nào thắng buy-and-hold.
  - Fock 2005 chỉ kiểm được qua nguồn thứ cấp, và các nguồn này mâu thuẫn nhau về vai trò của oscillator.
  - Kết luận giữ nguyên: nến xác nhận nên là bộ lọc lỏng (close vượt band, nến cùng chiều, vị trí đóng cửa tốt), không đòi pin bar hay engulfing chuẩn sách.
- Lệnh limit: Linnainmaa 2010 (giải thích "phần lớn", không phải "đủ để giải thích"), DeLise 2024 và Albers 2025 đều xác nhận lệnh limit bị adverse selection. Không có nghiên cứu nào so trực tiếp limit, market và stop cho retest S/R trên vàng.
- Garzarelli 2014: ở thang giây, xác suất bật tăng theo số lần đã bật trước. Kết quả này không áp dụng trực tiếp cho vùng đã lật trên M5, nên giả định "first touch tốt nhất" vẫn chưa có bằng chứng.

4. Việc nên làm với BotVang v1
- Chỉ dùng nến đã đóng, mọi ngưỡng tính theo ATR(M5) hoặc B, không dùng point.
- Log đủ các chỉ số: tỉ lệ vùng lật có retest trong 24–36 nến, độ sâu retest tính theo ATR, số thứ tự lần chạm, kết quả của ba kiểu vào lệnh trên cùng tín hiệu.
- Kiểm bằng dữ liệu tick thật của Exness trước khi tin vào bất kỳ ngưỡng nào ở trên.
--- wrong claims:
* Osler (2003): khoảng 8.7% lệnh take-profit nằm ở mức kết thúc bằng 00; stop-loss buy tụ ngay trên số tròn; biến động 15 phút sau khi xuyên số tròn lớn hơn. => Bản working paper ghi 9.3% lệnh take-profit khớp đúng ở 00, so với chỉ 4.4% lệnh stop-loss, không phải 8.7%. Dữ liệu là 9,667 lệnh có điều kiện tại một ngân hàng (43% USDJPY, 33% EURUSD, 24% GBPUSD) trong giai đoạn 1/9/1999–11/4/2000. 7.4% lệnh stop-loss buy đặt ở mức kết thúc 90–99, còn ở 00–09 gần gấp đôi (14.4%), tức stop mua nằm ngay trên số tròn. Kết quả biến động 15 phút sau khi xuyên số tròn được trích từ Osler (2001), không phải phân tích mới trong bài. Dữ liệu là FX, không phải vàng.
* Bulkowski: 58% trong 10,305 mẫu hình phá lên có throwback (dữ liệu 1991–2005); 65% phục hồi; khi throwback giữ trên giá phá thì mức tăng trung bình 40%, so với 29% khi xuyên xuống; không có throwback thì tốt hơn. => Các con số đúng nhưng bị gộp sai nguồn dữ liệu, và bỏ sót chi tiết quan trọng nhất. Con số 58%/10,305 là mẫu 'từ năm 2000'. Con số 40% và 29% đến từ một mẫu khác (1991–2005, 10,348 mẫu hình, chỉ 3,167 có throwback). Trong mẫu đó chỉ 400 throwback (~13%) giữ ở hoặc trên giá phá; 2,767 (~87%) xuyên xuống dưới giá phá. Như vậy retest 'nông' là hiếm. 'Throwback làm giảm hiệu quả' đúng ở 97% loại mẫu hình. Nghiên cứu ThrowbackEntry (cổ phiếu khung ngày, 1991–2012) so ba cách vào: tốt nhất là chờ close quay lại trên đỉnh mẫu hình rồi mua ở giá mở cửa hôm sau. Tất cả đều là cổ phiếu Mỹ khung ngày.
* MQL5 23155 Turtle Soup sweep: defaults Lookback 20, tuổi mức 4, cửa sổ quét 1, số close xác nhận 1, đòi thân nến đảo, độ sâu quét 30 pts và 2% range, RR 1.0, SL buffer 3000 pts; MQL5 2717: hủy lệnh chờ nếu hôm sau không còn tín hiệu. => Các default của bài 23155 đúng: 20/4/1/1/true/30/2.0/1.0/3000/1 lệnh mỗi hướng. Bài 2717 nói mô tả gốc KHÔNG quy định thời hạn lệnh chờ; bản cài đặt của tác giả hủy lệnh khi hình thành cực trị 20 ngày mới, chứ không phải 'hôm sau không còn tín hiệu'. Phần còn lại của 2717 đúng: cách đáy cũ ít nhất 3 ngày, buy stop cách 5–10 point, SL 1 point dưới đáy ngày, được vào lại trong ngày 1–2; test trên USDJPY và vàng 5 năm, dầu 4 năm, khung ngày.
===== verify:takeprofit =====
TÓM TẮT ĐÃ KIỂM CHỨNG: chốt lời và thoát lệnh cho BotVang v1

A. Phần đáng tin

1. Toán của bậc thang (giả định giá là Brownian motion có drift):
- Đặt θ = 2μ/σ². Xác suất lên thêm một bậc: p = 1/(1+e^(−θB)).
- Kỳ vọng mỗi lệnh: E = B·(e^(θB)−1) − s.
- Điểm hòa vốn: p* = (B+s)/(2B+s), khoảng 0.538 khi B=1.5, s=0.25; 0.52 khi B=3.
- Trailing liên tục ở khoảng cách d: E = (e^(θd)−1)/θ − d, bằng 0 khi μ=0.
- Tôi tự suy lại và chạy Monte Carlo, kết quả khớp. Mô phỏng hơi cao hơn công thức vì giá được theo dõi theo bước rời rạc.
- Hệ quả chắc chắn: tới +1B chỉ hòa (chưa tính spread). Cần giá đi tới +2B mới có +1B lãi. Nếu không có drift thì mỗi lệnh lỗ đúng bằng spread.
- Đây là mô hình, không phải bằng chứng thị trường. p thực tế sau retest phải đo bằng tick thật.

2. Mã triển khai đã đọc và xác nhận. Tất cả chỉ là cách viết, không phải bằng chứng hiệu quả.
- freqtrade:
  - stoploss_from_open = 1 − (1+open_rel)/(1+profit).
  - SL chỉ đi lên (với lệnh long).
  - trailing_stop_positive mặc định None, offset mặc định 0.0.
  - Ví dụ bậc thang: lãi 0.20/0.25/0.40 thì khóa 0.07/0.15/0.25.
  - Khi backtest, SL được nâng theo high rồi kiểm tra bằng low của cùng nến, nên kết quả lạc quan.
- MQL5 thư viện chuẩn:
  - TrailingFixedPips: 30/50 điểm điều chỉnh; TP bị đẩy đi trước giá.
  - PSAR: step 0.02, max 0.2; SL = SAR[1]; lệnh short cộng spread.
  - TrailingMA: chu kỳ 12.
  - Ngưỡng tín hiệu: mở 50, đóng 100.
- Lean: đóng lệnh khi giá trị vị thế sụt 5% từ đỉnh.
- Chandelier (Pine): 22/3; useClose = true; SL chỉ dịch về phía có lợi (ratchet) khi close[1] > mức cũ.
- Bài MQL5 19674: SL = zone.low − 200 điểm, TP = entry + 400 điểm. TP là khoảng cách cố định, không nhắm vùng đối diện.
- Bài MQL5 23716: các nấc 1R đóng 50% (kèm dời về hòa vốn), 2R đóng 25%, 3R đóng 25%.

3. Bằng chứng về vùng giá và số tròn (chỉ có trên FX 1996–2000, chưa kiểm cho vàng):
- Osler 2000: giá bật lại ở mức được công bố 60.8%, ở mức ngẫu nhiên 56.2%. Lợi thế nhỏ, khoảng 4–5 điểm %, kéo dài ít nhất 5 ngày làm việc. 'Strength' do các công ty tự gán không có giá trị dự báo.
- Osler 2005 (SR150, 9.655 lệnh):
  - Lệnh TP khớp ở đuôi 00 chiếm 9.9%, lệnh SL chỉ 3.8%.
  - Stop mua ở đuôi 01–10 chiếm 14.3%, ở 90–99 chỉ 6.9%. Bản SR125 báo 9.3/4.4 và 14.4/7.4.
  - Sau khi vượt số tròn, giá đi 0.061% trong 15 phút, so với 0.054% ở mức bất kỳ.
  - Phản ứng với cụm stop mạnh và dài hơn cụm TP, có ý nghĩa trong vài giờ chứ không tới vài ngày.
- Chung & Bellotti 2021:
  - Mức đã bật nhiều lần thì dễ bật hơn, và ảnh hưởng giảm dần theo thời gian.
  - Với EURUSD 2018: mức bật 1 lần về 0.5 ở cửa sổ khoảng 350 phút, mức bật 4 lần ở khoảng 900 phút.
  - Nhưng mức S/R trong nghiên cứu là min/max của cửa sổ lăn, không phải vùng thân nến như của bot. Lần chạm đầu (đúng kiểu bot vào lệnh) có tác dụng yếu nhất.

4. Bằng chứng về dừng lỗ nói chung:
- Kaminski & Lo: dưới random walk, quy tắc dừng lỗ luôn làm giảm lợi nhuận kỳ vọng; cần có momentum thì mới có ích. Dữ liệu là tháng, chuyển từ cổ phiếu sang trái phiếu.
- Lo & Remorov: stop chặt thua buy-and-hold vì chi phí, trừ khi lợi suất tự tương quan cao.
- Backtrader lặp lại thí nghiệm vào lệnh ngẫu nhiên kèm trailing 3·ATR: chỉ 49% số lần chạy có lãi. Trailing không tự tạo ra lợi thế.
- Batten 2017 (vàng, dữ liệu 5 phút, 2000–2015): biến động tăng nhẹ tới 14:00 GMT rồi giảm. Khối lượng cao nhất khoảng 11–17 GMT. Spread gần như ổn định cả ngày.

B. Phần cần sửa

1. Imkeller & Rogers bị khái quát quá mức.
- Mô hình dùng hữu dụng mũ (γ=2.5), chiết khấu ρ=0.1, phí c=0.0005 rất nhỏ so với σ=0.3. Bot thì tốn spread khoảng 8–20% mỗi bậc.
- 'Hai biên tốt hơn nhiều so với chỉ trailing' chỉ đúng khi drift đã biết hoặc khi vào lại cùng một tài sản (story A).
- Khi mỗi lệnh là một setup độc lập (story B, gần với bot nhất), chỉ dùng trailing đạt 1.3354, biên cố định 1.4071 (chỉ hơn khoảng 5%), trailing + TP 1.3431.
- 'SL chặt + TP xa' chỉ đúng ở story B. Story A thì ngược lại: SL rộng, TP gần.
- Thêm độ dốc theo thời gian cải thiện 13.5% ở story B, gần như không cải thiện ở story A.

2. Davey bị dùng sai.
- Parabolic và Trailing thuộc nhóm trung bình. Nhóm kém nhất là Chandelier, Yo-Yo, Channel và MA.
- Davey ghi rõ: trong ba kiểu stop, target và stop+target, kiểu stop+target luôn tệ nhất. Vì vậy Davey không ủng hộ TP+SL.
- Stop & Reverse của Davey là hệ luôn có lệnh, đảo chiều khi có tín hiệu vào ngược và không có SL. Nó không phải 'đảo chiều khi chạm SL' như bot, nên không dùng để bảo vệ quy tắc flip được.

3. Bài MQL5 16991:
- Có 1.942 deal chứ không phải 1.762.
- Các biến thể trailing đồng thời bỏ luôn TP 500 điểm của bản gốc, và tham số trailing được 'chọn ngẫu nhiên'. Kết quả gần như không có giá trị làm bằng chứng.

4. Leung & Zhang: đúng là chứng minh lệnh limit bán kèm trailing stop là tối ưu, nhưng trong bài toán đã áp đặt sẵn trailing stop. Đây là lý thuyết, không có kiểm định thị trường.

C. Kết luận thực tế cho bot

1. Chắc chắn nên làm:
- Lọc khoảng trống: cần ≥2B tới vùng cản đối diện, vì đây là hệ quả toán học của bậc thang.
- Hòa vốn phải cộng spread.
- Backtest bằng real ticks, tôn trọng StopsLevel và FreezeLevel.
- Lệnh short tính SL theo giá Ask.

2. Chỉ là giả thuyết cần A/B test (walk-forward, ≥300 lệnh, đo kỳ vọng theo R sau spread):
- Thêm TP ở mép vùng đối diện.
- Thay việc khóa 0.5B bằng TP limit.
- Trailing có offset hoặc rộng hơn.
- Biên hội tụ theo thời gian.
Bằng chứng về các ý này lẫn lộn: Imkeller & Rogers phụ thuộc kịch bản, Leung & Zhang ủng hộ, còn Davey lại xếp stop+target tệ nhất.

3. Chưa có nghiên cứu nghiêm túc nào về thoát lệnh trong ngày cho vàng M5. Mọi tham số (u, N, buffer, d) phải đo từ dữ liệu của chính bot. Điểm độ mạnh của vùng chỉ nên giữ nếu tăng đều theo tỷ lệ bật lại đo được.

4. Chốt một phần: đẳng thức 'chốt một phần chỉ là trung bình của hai chiến lược nên không tăng kỳ vọng' đúng về toán. Việc không làm được với 0.01 lot thì chưa xác minh (không mở được trang Exness). Cần đọc SYMBOL_VOLUME_MIN và SYMBOL_VOLUME_STEP trong terminal cho XAUUSDm và XAUUSDc.

5. Flip sau khi dính SL: Osler (cụm stop gây giá chạy tiếp ở số tròn) chỉ ủng hộ gián tiếp khi SL trùng số tròn hoặc vùng bị phá. Davey không ủng hộ.
--- wrong claims:
* Imkeller & Rogers: two-sided rules (TP+SL or TP+trailing) are substantially better than trailing-only or a fixed exit time; with uncertain drift, a tight SL plus a distant TP is optimal; a fixed barrier with a time slope is near-optimal. => This generalises beyond the paper. Two-sided rules are much better only with known drift (fixed stops 4.1553 vs trailing ≈0.53) and in story A, re-entering the same fund (0.84 vs 0.24). In story B, a new independent fund each trade, which is closest to a bot taking independent setups: trailing-only 1.3354 vs fixed stops 1.4071 (about −5%) vs trailing+TP 1.3431. The paper says 'the difference in value of Examples 2 and 3 is comparatively small'. 'Tight SL + far TP' holds only in story B (a≈0.02, b≈0.66). Story A is the reverse (a≈0.22, b≈0.05). A time slope adds +13.5% in story B (1.4071→1.5976 vs optimum 1.6770). In story A it gives 'not a substantial improvement'.
* Davey: Chandelier, Parabolic and Yo-Yo all performed poorly; Davey supports adding a fixed TP to an SL (a two-sided rule). => Parabolic and Trailing are in the average group ('a step down from the Breakeven Exit'). Only Chandelier and Yo-Yo are in the worst group, with Channel and MA exits also 'not that good'. More important: Davey writes 'Of all 3 combinations (stop, target or stop/target), the stop/target is always the worst.' The runner-up was the Dollar Target alone, with no stop. Davey's data therefore argue against TP+SL, not for it.
* MQL5 article 16991 replays 1,762 real deals (XAUUSD included): original −658 USD; simple trailing −746; PSAR +542; MA +563; DEMA(14) +1,397. => The per-symbol deal counts on the page sum to 1,942, not 1,762: 222+120+526+352+182+22+250+150+118, with 118 on XAUUSD, from 13 Sep 2024. The P&L figures are correct (AMA +806.5, FRAMA +1,291.6, TEMA +1,355.1, VIDYA −283.3). The original run used SL 100 / TP 500 points, but every trailing variant set TP=0, so the TP was removed at the same time. The author says the trailing settings 'were chosen randomly' (start 150, step 50). This is very weak evidence.
===== critic =====
- Thuật toán hướng lớn (bias cấu trúc H4+H1) chưa được nghiên cứu, dù mọi lệnh vào và lệnh đảo đều phải qua nó
- Chưa kiểm chứng tiền đề cốt lõi: retest đầu của vùng vừa lật và độ trôi giá sau điểm vào trong ngày
- Cỡ số tròn của vàng và độ rộng cụm stop quanh số tròn chưa được xác định; các chủ đề đang đề xuất mâu thuẫn nhau

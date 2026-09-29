# Nghiên cứu A: mã nguồn mở phát hiện và xếp hạng vùng S/R

Nhãn dùng trong báo cáo:
- **[code]**: tôi đã đọc mã nguồn.
- **[tác giả nói]**: chỉ có mô tả, không có số liệu.
- **[có số liệu]**: có kết quả định lượng.

## 1. Bảng tóm tắt

| # | Nguồn (URL) | Cách tìm mức | Gộp / chống trùng | Công thức sức mạnh | Giữ tối đa | Bằng chứng |
|---|---|---|---|---|---|---|
| 1 | LonesomeTheBlue "Support Resistance Channels": [TV](https://www.tradingview.com/script/Ej53t8Wv-Support-Resistance-Channels/), mã Pine v4 + bản Python: [edyatl/sup-res-channels](https://github.com/edyatl/sup-res-channels) | Pivot trái/phải = 10 nến (High/Low hoặc thân nến) | Kênh = các pivot nằm gọn trong độ rộng tối đa `cwidth = (Highest300 − Lowest300) × 5%`. Chọn tham lam, loại bỏ kênh chồng lấn (như NMS) | `20 × số pivot trong kênh` + số nến trong 290 nến gần nhất có High hoặc Low nằm trong kênh | 10 kênh được tính, mặc định hiện 6 | [code]. Không có số liệu |
| 2 | LuxAlgo "S/R Levels with Breaks": [TV](https://www.tradingview.com/script/JDFoWQbL-Support-and-Resistance-Levels-with-Breaks-LuxAlgo/), [bản port ToS](https://usethinkscript.com/threads/support-and-resistance-levels-with-breaks-lux-for-thinkorswim.11556/) | Chỉ lấy pivot high/low mới nhất, trái/phải = 15 | Không gộp. Mỗi phía chỉ có 1 mức | Không có. Tín hiệu phá mức cần bộ dao động khối lượng `100×(EMA5−EMA10)/EMA10 > 20` | 1 hỗ trợ + 1 kháng cự | [tác giả nói] |
| 3 | `smartmoneyconcepts` (joshyattridge): [smc.py](https://raw.githubusercontent.com/joshyattridge/smart-money-concepts/master/smartmoneyconcepts/smc.py) | Swing: cực trị trong ±`swing_length` nến, **mặc định 50**. Hai swing liền nhau cùng loại thì chỉ giữ swing cực trị hơn, nên đỉnh và đáy luôn xen kẽ | Liquidity: gom các swing cách nhau ≤ `1% × (max−min của toàn bộ dữ liệu)`, cần ≥2 swing; mức = trung bình của nhóm. FVG: `join_consecutive` gộp các FVG liền nhau | OB: khối lượng 3 nến; % = `min(vol cao, vol thấp)/max × 100` | Không giới hạn. Mức bị hủy khi bị quét (sweep) hoặc bị giảm hiệu lực (mitigated). BOS/CHoCH cần 4 swing xen kẽ và giá đóng cửa phá mức | [code]. Không có số liệu |
| 4 | Gom cụm phân cấp (agglomerative): [day0market/support_resistance](https://github.com/day0market/support_resistance) | Pivot ZigZag (lọc theo % biến động và số nến tối thiểu giữa hai pivot) | `AgglomerativeClustering(distance_threshold = merge_distance hoặc merge_percent)`; mức = trung vị của cụm | TouchScorer: **+2 khi chạm, +1 khi chạm tại đỉnh/đáy, −2 khi thân nến cắt qua, −1 khi râu nến cắt qua**; hai mức phải cách nhau tối thiểu 0,1% | Tùy tham số | [code]. Không có số liệu |
| 5 | KDE / hồ sơ thị trường (market profile): neurotrader888, [mp_support_resist.py](https://github.com/neurotrader888/TechnicalAnalysisAutomation/blob/main/mp_support_resist.py) | Ước lượng mật độ Gaussian (KDE) trên log(close) của cửa sổ `lookback`. Băng thông = **3 × ATR(log)**. Trọng số tăng dần theo độ mới, từ 0,01 lên 1 | Chia thành 200 bin giá, lấy đỉnh bằng `find_peaks(prominence ≥ 25% × đỉnh cao nhất)`. Việc gộp mức xảy ra tự nhiên qua băng thông | Độ nổi bật (prominence) của đỉnh | Thường chỉ vài mức | [code]. Có chiến lược "giá đóng cửa xuyên mức" nhưng mã không kèm số liệu |
| 6 | KMeans: [lambdalearner](https://lambdalearner.com/picking-support-and-resistance-levels-with-k-means/), [alpharithms](https://www.alpharithms.com/calculating-support-resistance-in-python-using-k-means-clustering-101517/) | KMeans trên các đỉnh/đáy. Chọn k bằng phương pháp khuỷu tay (elbow) rồi cộng thêm 2 | Mức = min/max của mỗi cụm | Không có | k mức | [tác giả nói]: tác giả tự nhận cách này **kém chính xác khi scalping trong ngày** |
| 7 | Hồ sơ khối lượng (volume profile): [LunqFX VPVR](https://www.tradingview.com/script/Y1H9GJzv-Smart-Volume-Profile-VPVR-POC-Value-Area-SR-LunqFX/), [mervinj3546/volume-profile](https://github.com/mervinj3546/volume-profile) | Chia cửa sổ thành các hàng giá và rải khối lượng mỗi nến lên dải giá nến đó đi qua. POC = hàng có khối lượng lớn nhất | Vùng giá trị (value area) = mở rộng dần từ POC sang hàng bên cạnh có khối lượng lớn hơn, đến khi đủ 70% | HVN/LVN: trang không nêu ngưỡng | Không rõ | [tác giả nói] |
| 8 | MQL5 SRSI: [bài 17450](https://www.mql5.com/en/articles/17450) | Swing ±5 nến, xét 1000 nến | Không gộp | Đếm số lần kiểm tra trong khoảng 0,0007; từ **3 lần** trở lên là mức mạnh | Không giới hạn | [tác giả nói]. Không có backtest |
| 9 | MQL5 "Automatic construction of S/R lines": [bài 3215](https://www.mql5.com/en/articles/3215) | Điểm ZigZag. Lọc theo tỉ lệ AB/AC ≥ 0,382, số lần xuyên qua đoạn AB/BC, khoảng cách tới giá hiện tại, độ dốc | Không gộp. Dung sai 200 điểm | Không có | Vài đường | **[có số liệu]** nhưng yếu: 13 cặp tiền năm 2017, tỉ lệ thắng 52,9–91%, DD 0,57–2,37%. Đây là kết quả đã tối ưu tham số, không có kiểm tra ngoài mẫu |
| 10 | Chung & Bellotti 2021: [arXiv 2101.07410](https://arxiv.org/abs/2101.07410) | Vùng S/R là một khoảng [a,b]. **Bounce** = giá vào vùng rồi ra lại đúng phía đã vào; **penetration** = giá ra phía bên kia | — | Xác suất bật lại p(b \| số lần bật trước), ước lượng bằng Beta-Binomial | — | **[có số liệu]**, xem mục 3 |

## 2. Chi tiết LonesomeTheBlue (ưu tiên 1, đã đọc mã) — [mã Pine trong README](https://github.com/edyatl/sup-res-channels)

- **Đầu vào mặc định:** Pivot Period = 10 (từ 4 đến 30); Source = High/Low; Max Channel Width = 5% (từ 1 đến 8); Min Strength = 1; Max S/R = 6 (tối đa 10); Loopback = 290 (từ 100 đến 400).
- **Pivot:** dùng `pivothigh(src,10,10)` và `pivotlow`. Mỗi pivot được lưu kèm vị trí nến. Pivot cũ hơn 290 nến bị xóa.
- **Độ rộng tối đa:** `cwidth = (highest(300) − lowest(300)) × 5/100`. Độ rộng này co giãn theo biên độ gần đây, không cố định bằng điểm.
- **Dựng kênh cho từng pivot i:**
  - Ban đầu `lo = hi = pivot_i`.
  - Duyệt mọi pivot y: nếu thêm y mà kênh vẫn rộng ≤ `cwidth` thì mở rộng lo/hi và cộng `numpp += 20`.
  - Kết quả là mỗi pivot sinh ra một kênh ứng viên.
- **Sức mạnh:**
  - `strength = 20 × số pivot trong kênh`.
  - Cộng thêm số nến (trong 0..290 nến gần nhất) có **High hoặc Low nằm trong [lo,hi]**.
  - Vì vậy 1 pivot có trọng số bằng 20 lần chạm.
- **Chọn top N (dạng NMS):**
  - Lặp lại các bước sau: lấy kênh mạnh nhất có `strength ≥ 20 × minstrength`.
  - Gán `strength = −1` cho mọi kênh ứng viên có hi hoặc lo nằm trong kênh vừa chọn.
  - Dừng khi đủ 10 kênh, sắp xếp theo sức mạnh rồi hiện `maxnumsr`.
- **Tính lại:** chỉ tính lại khi có pivot mới.
- **Hủy mức:** không có luật hủy. Kênh tự mất khi pivot của nó ra khỏi cửa sổ 290 nến. Khi giá đóng cửa ra ngoài kênh thì chỉ báo cảnh báo "broken", kênh không bị xóa.
- **Tôi nhận xét:**
  - Mặc định `minstrength = 1` thì luôn thỏa, vì chính pivot đã cho 20 điểm. Tooltip ghi "cần ít nhất 2 pivot" không khớp với mã.
  - Kiểm tra chồng lấn chỉ xét hi/lo của ứng viên. Một kênh bao trùm kênh đã chọn vẫn có thể lọt qua.

## 3. Bằng chứng định lượng về S/R ([Chung & Bellotti](https://arxiv.org/abs/2101.07410); dữ liệu EURUSD 2018, LLOY, BRENT)

- **Số lần bật trước càng nhiều thì xác suất bật lại càng cao.** Chuỗi giá thật cho xác suất cao hơn chuỗi đã xáo trộn lợi suất. Đa số chỉ số Λ > 0,95, tức giá thật bật tốt hơn chuỗi xáo trộn với xác suất > 95%.
- **Mức S/R suy giảm theo thời gian.** Với EURUSD:
  - Mức có 1 lần bật trước: xác suất về 0,5 khi cửa sổ dài khoảng **350 phút**.
  - Mức có 4 lần bật trước: xác suất về 0,5 khi cửa sổ dài khoảng **900 phút**.
- **Độ rộng vùng nên theo bước giá trung bình** của chuỗi giá.
- Phép kiểm tra "so với chuỗi xáo trộn" của họ tương tự phép kiểm tra "so với vùng dịch ngẫu nhiên" của mình (44% so với 41%).

## 4. Ý tưởng tốt nhất cho vấn đề NHIỄU (khoảng 19 vùng chồng nhau mỗi lần chạm)

1. **Chọn top N bằng NMS thay vì giữ mọi vùng** ([LonesomeTheBlue](https://github.com/edyatl/sup-res-channels)). Tính sức mạnh cho mọi ứng viên, chọn vùng mạnh nhất, xóa mọi ứng viên chồng lấn, rồi lặp lại, giữ khoảng 4–6 vùng mỗi khung.
   - *Lý do:* cách này trực tiếp đưa số vùng chồng nhau từ 19 xuống còn 0–1.
2. **Vùng phải là cụm của ≥2 pivot và có giới hạn độ rộng** (tính theo % biên độ 300 nến hoặc theo ATR). Không để một pivot đơn lẻ, một FVG hay một "gap" tự thành vùng. Các loại đó chỉ nên cộng điểm cho cụm chứa chúng.
   - *Lý do:* [LonesomeTheBlue](https://github.com/edyatl/sup-res-channels) cho mỗi pivot trọng số 20; [smc liquidity](https://raw.githubusercontent.com/joshyattridge/smart-money-concepts/master/smartmoneyconcepts/smc.py) cần ≥2 swing trong 1% biên độ; [Chung & Bellotti](https://arxiv.org/abs/2101.07410) có số liệu cho thấy nhiều lần bật trước thì xác suất bật cao hơn.
3. **Trừ điểm khi giá cắt qua vùng, không chỉ cộng khi chạm** ([day0market TouchScorer](https://github.com/day0market/support_resistance)): +2 khi chạm, −2 khi thân nến cắt qua, −1 khi râu nến cắt qua; hai mức cách nhau tối thiểu một khoảng nhất định.
   - *Lý do:* vùng bị xuyên liên tục là nhiễu. Cách đếm "số nến chạm" của LonesomeTheBlue lại thưởng cho cả vùng giá đi ngang qua.
4. **Lấy mức từ đỉnh của KDE hoặc volume profile, có ngưỡng prominence** ([neurotrader888](https://github.com/neurotrader888/TechnicalAnalysisAutomation/blob/main/mp_support_resist.py)): băng thông khoảng 3×ATR, chỉ giữ đỉnh có prominence ≥ 25% đỉnh cao nhất, trọng số theo độ mới.
   - *Lý do:* các mức gần nhau tự gộp lại, và số mức thường chỉ vài cái. Có thể dùng để kiểm tra chéo, chỉ giữ vùng pivot nằm gần một đỉnh KDE.
5. **Swing lớn hơn và có hạn dùng:** [smc](https://raw.githubusercontent.com/joshyattridge/smart-money-concepts/master/smartmoneyconcepts/smc.py) mặc định `swing_length = 50` và bắt đỉnh/đáy xen kẽ; LonesomeTheBlue bỏ pivot cũ quá 290 nến. [Chung & Bellotti](https://arxiv.org/abs/2101.07410) có số liệu về suy giảm: mức ít lần bật mất tác dụng nhanh hơn.

**Không nên:**
- KMeans với k cố định: [tác giả tự nói](https://lambdalearner.com/picking-support-and-resistance-levels-with-k-means/) cách này kém khi scalping.
- Tin kết quả của [MQL5 3215](https://www.mql5.com/en/articles/3215): tham số đã tối ưu trên chính dữ liệu kiểm tra, chỉ 1 năm, không có kiểm tra ngoài mẫu.

**Lưu ý:** mọi tham số ở trên đều là mặc định do tác giả tự chọn cho các thị trường khác. Chưa có nguồn nào kiểm chứng trên XAUUSD M1/M5. Cần kiểm tra lại bằng phép thử "vùng thật so với vùng dịch ngẫu nhiên" của mình.

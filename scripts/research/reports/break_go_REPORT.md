# Phá rồi đi (break_go) — discovery 03–12/2025

## Kết luận
- Cấu hình đóng băng là **C3** (vào khi nến M1 đóng vượt cản ≥ 0,1·ATR M5).
- C3 **đạt cả 5 ngưỡng, nhưng sát nút**.
- Lời sau phí là +0,066R ± 0,089. Khoảng này chứa 0, nên **chưa chứng minh là có lời**.
- Chưa chạy validation.

## Cách làm
- **Cản**: số tròn $100/$50 (mỗi ngày, cả hai chiều), số tròn $10 riêng ở C8, đỉnh/đáy ngày trước, tuần trước, phiên Á, và đỉnh/đáy H1/H4 lớn.
- **Vào lệnh**: cản phải "sẵn sàng" trước. Vào theo chiều phá ở nến đầu tiên đóng vượt ≥ k·ATR M5.
- **Dừng lỗ**: cản − 0,5·ATR M15, rủi ro tối thiểu 1·ATR M15.
- **Không vào lệnh**:
  - 20–24 UTC.
  - ±5 phút quanh 12:30 và 13:30 UTC. Tôi thêm 12:30 vì tin Mỹ mùa hè ra lúc 12:30 UTC.
- **Đối chứng cùng chiều**: 10 bản mỗi lệnh, cùng chiều, cùng khoảng dừng/chốt, cùng giờ trong ngày, ngày khác trong ±20 ngày.
- **Kiểm nhìn trước**: cắt dữ liệu tại lúc ra lệnh với 20 lệnh ngẫu nhiên (C1, C3, C8). **20/20 trùng khớp**, không thừa lệnh.

## 8 cấu hình
"Hơn/cần" = lệnh trừ đối chứng cùng chiều / tổng hai ci95.

| | Thay đổi | n | meanR ± ci | Đối chứng | Hơn/cần | Bỏ top3 | 03–07/08–12 | Đạt |
|---|---|---|---|---|---|---|---|---|
| C1 | M5, k 0,1, 2R, 240 phút | 810 | +0,021 ± 0,092 | −0,094 | 0,115/0,119 | +0,014 | +0,036/+0,008 | không |
| C2 | k 0,3 | 782 | +0,027 ± 0,094 | −0,111 | 0,138/0,121 | +0,019 | +0,038/+0,016 | có (sát) |
| **C3** | vào theo M1 | 918 | **+0,066 ± 0,089** | −0,092 | **0,158/0,115** | +0,060 | +0,104/+0,032 | **có** |
| C4 | rủi ro ≥ 10 USD | 810 | +0,038 ± 0,082 | −0,045 | 0,083/0,106 | +0,031 | +0,059/+0,019 | không |
| C5 | 1,5R | 810 | 0,000 ± 0,081 | −0,100 | 0,100/0,105 | −0,006 | −0,015/+0,013 | không |
| C6 | 3R | 810 | +0,013 ± 0,106 | −0,084 | 0,097/0,136 | +0,002 | +0,035/−0,007 | không |
| C7 | thoát sau 60 phút | 810 | −0,033 ± 0,085 | −0,120 | 0,087/0,109 | −0,054 | −0,049/−0,019 | không |
| C8 | chỉ số tròn $10 | 1628 | −0,065 ± 0,063 | −0,067 | 0,002/0,082 | −0,069 | −0,082/−0,050 | không |

- Đối chứng chiều ngẫu nhiên của runner2 cho C3: −0,100.
- **Luật đóng băng** (ghi trước khi chạy): chọn cấu hình "hơn" nhiều nhất. C3 hơn C2 đúng 0,0206R, vừa qua mức 0,02. Nếu dưới 0,02 thì luật sẽ chọn C2.

## Soi kỹ C3
- **Theo chiều**: mua +0,082, bán +0,046. Cả hai đều hơn đối chứng khoảng 0,16. Vậy lợi thế không chỉ nhờ xu hướng tăng.
- **Theo loại cản**:
  - Có lời: $100 +0,30 (n 208), đỉnh/đáy H1/H4 +0,20 (n 64), tuần trước +0,53 (n 33).
  - Không có lời: phiên Á, ngày trước, $50.
  - Số tròn $10 không có lợi thế. Điều này khớp với Osler, nhưng các nhóm còn nhỏ.
- **Theo phiên**: London −0,04, New York +0,09, còn lại +0,13.
- **Theo tháng**: 5/10 tháng có lời. Tổng +61R, phần lớn đến từ tháng 4, 5 và 12.
- **Lệnh chồng nhau**: lấy mẫu lại theo ngày thì phần "hơn" nằm trong [+0,06; +0,26].
- **Cản giả cùng hình học** (10 lần rải, tuổi cản 24 giờ):
  - C3: cản thật +0,044, cản giả −0,113. Hơn 0,157, cần 0,117, nên qua.
  - C1 và C2 không qua kiểm tra này.

## Đo cản (runner2)
- **Tỷ lệ bị phá**: cản thật 89,3%, cản giả 87,4%, chênh +1,9 ± 1,8 điểm (khoảng sai số do tôi tự tính).
- **Tỷ lệ bật**: −2,5 ± 2,4 điểm.
- **Theo loại cản**:
  - Đỉnh/đáy H1/H4 bị phá 93,2% so với 88,0% ở cản giả.
  - Số tròn $100 bị phá 90,3% so với 87,3%.
- Hướng đúng như giả thuyết, nhưng chênh lệch yếu.
- Có 22,5 cản mới mỗi ngày; trung vị số cản chồng nhau là 1.

## Điểm yếu
- Lời tuyệt đối chưa chắc khác 0. Phần hơn đối chứng chủ yếu là do lệnh ngẫu nhiên bị phí ăn khoảng −0,1R.
- C3 là cấu hình tốt nhất trong 8, nên kết quả bị thiên lệch do chọn lọc.
- Nửa sau năm yếu.
- Chưa thử "không chốt lời, thoát sau 240 phút".
- Có tạo thêm `break_go_cfgs.json` và thư mục `break_go_logs/`.

## Đề nghị
Nếu chủ bot đồng ý, chạy **một lần** validation cho C3, không sửa luật:
```
node runner2.mjs break_go validation '{"id":"C3","entry":"M1","_life_h":24}'
```
Kèm đối chứng cùng chiều và cản giả (sửa ngày trong `break_go_eval.mjs` và `break_go_placebo.mjs`).

**File**: `methods/break_go.mjs`, `break_go_eval.mjs` (→ `break_go_eval.json`), `break_go_placebo.mjs`, `break_go_trunc.mjs`, `break_go_count.mjs`, `results2/break_go_discovery_*.json`.

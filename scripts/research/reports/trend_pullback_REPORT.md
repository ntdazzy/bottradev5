# trend_pullback — xu hướng khung lớn + hồi về vùng (discovery 03–12/2025)

## Kết luận: KHÔNG ĐẠT
Lợi nhuận dương của phương pháp chỉ đến từ việc **mua trong năm vàng tăng mạnh**. Vào lệnh mua ngẫu nhiên cùng chiều, cùng khoảng dừng lỗ và chốt lời cho kết quả **bằng hoặc tốt hơn** ở cả 8 cấu hình. Vì vậy phần "hồi về vùng rồi vào" không tạo thêm lợi thế.

## Luật (cố định trước khi chạy)
- **Xu hướng:** lên khi giá đóng D1 > EMA50(D1) **và** EMA20(H4) > EMA50(H4). Xuống thì ngược lại. Chỉ dùng nến đã đóng.
- **Vùng ('fib'):** khi một đỉnh fractal H4 (N=2) được xác nhận trong xu hướng lên, lấy nhịp đẩy từ đáy fractal trước tới đỉnh. Vùng mua là mức hồi 38,2–61,8% của nhịp đó. Xu hướng xuống làm đối xứng. Vùng mới thay vùng cũ. Vùng hết hiệu lực sau 10 ngày, khi nến đóng qua gốc nhịp, hoặc sau khi đã ra 1 lệnh.
- **Vào lệnh:** chờ nến H1 chạm vùng, đóng cùng màu với chiều lệnh và không đóng qua mép xa của vùng. Xu hướng lúc đó vẫn phải đúng chiều. Vào ở giá mở M1 kế tiếp.
- **Dừng lỗ và chốt lời:** dừng lỗ đặt sau gốc nhịp thêm 0,2·ATR(H4). Rủi ro phải từ 15 USD trở lên (trung vị khoảng 27–37 USD, nên phí chỉ khoảng 2–3% R). Mặc định chốt ở 2R, giữ tối đa 5 ngày.
- **Đối chứng cùng chiều (tự tính):** mỗi lệnh có 10 lệnh ngẫu nhiên, vào ở thời điểm ngẫu nhiên trong ±20 ngày, **cùng chiều**, cùng khoảng dừng lỗ và chốt lời tính từ giá vào thật, dùng `L.simulate`.
- **Luật đóng băng (định trước):** trong C1–C7, chỉ xét cấu hình có ít nhất 100 lệnh, rồi chọn cấu hình có (meanR − đối chứng cùng chiều) lớn nhất. C8 chỉ để chẩn đoán, không được chọn.

## Tất cả cấu hình (`node runner2.mjs trend_pullback discovery '<cfg>'`)
| # | cfg | n | meanR ± ci95 | Ngẫu nhiên, chiều ngẫu nhiên (runner2) | **Ngẫu nhiên cùng chiều** | Hơn cùng chiều | Mua / Bán |
|---|---|---|---|---|---|---|---|
| C1 | `{}` | 76 | +0,22 ± 0,29 | +0,01 ± 0,09 | +0,31 ± 0,09 | **−0,09** | +0,39 (66) / −0,85 (10) |
| C2 | `{"tp":"3R"}` | 76 | +0,25 ± 0,34 | +0,05 | +0,45 ± 0,11 | **−0,20** | +0,41 / −0,85 |
| C3 | `{"tp":"swing"}` | 76 | +0,06 ± 0,16 | −0,03 | +0,11 ± 0,05 | **−0,05** | +0,10 / −0,18 |
| C4 | `{"entry":"M15"}` | 81 | +0,22 ± 0,28 | +0,04 | +0,36 ± 0,09 | **−0,14** | +0,37 / −0,85 |
| **C5** | `{"tf":"H1"}` | **184** | **+0,29 ± 0,20** | +0,08 ± 0,06 | **+0,48 ± 0,07** | **−0,19** | +0,33 (174) / −0,54 (10) |
| C6 | `{"lvl":"swing"}` | 34 | +0,07 ± 0,48 | +0,09 | +0,40 ± 0,15 | **−0,34** | +0,10 / −1,01 (1) |
| C7 | `{"entry":"limit"}` | 45 | +0,31 ± 0,40 | −0,00 | +0,35 ± 0,13 | **−0,05** | +0,32 / +0,20 (5) |
| C8 | `{"trend":"off"}` | 195 | +0,09 ± 0,17 | +0,09 | +0,06 ± 0,06 | +0,03 | +0,40 (96) / −0,22 (99) |

Mua ngẫu nhiên cùng chiều trong C8 được +0,43, còn bán ngẫu nhiên được −0,32. Nói cách khác, chỉ riêng chiều lệnh đã quyết định kết quả.

## Cấu hình đóng băng: C5 (H1, fib, vào H1, 2R)
Chỉ C5 có ít nhất 100 lệnh trong C1–C7.
- n = 184, meanR = +0,287 ± 0,203. Điều kiện meanR > 0: **đạt**.
- So với ngẫu nhiên cùng chiều: +0,477 ± 0,065. Phần hơn là −0,19, trong khi ngưỡng cần vượt là +0,27. **Trượt.**
- So với ngẫu nhiên của runner2 (chiều ngẫu nhiên): +0,077 ± 0,062. Phần hơn là +0,21, vẫn nhỏ hơn tổng ci95 là 0,27. **Cũng trượt.**
- Chia theo chiều: mua +0,33 (174 lệnh, đối chứng mua +0,54); bán −0,54 (10 lệnh). Gần như toàn bộ là lệnh mua.
- Chia hai nửa: nửa 1 (03–07) **−0,18** ± 0,28, n = 81; nửa 2 (08–12) +0,66 ± 0,27, n = 103. Các tháng 04–07 đều âm; riêng tháng 09 đóng góp +30,8R, trùng với đợt vàng tăng mạnh.
- Bỏ 3 lệnh lời nhất: +0,26 ± 0,20.
- Đo chất lượng cản (runner2): thật − giả = −0,6 ± 4,5 điểm, tức vùng hồi không bật tốt hơn vùng giả đặt cùng khoảng cách.

## Kiểm tra không nhìn trước
- Chọn ngẫu nhiên 20 lệnh, cắt dữ liệu M1 ngay tại lúc quyết định của từng lệnh, rồi chạy lại toàn bộ. Kết quả **20/20 lệnh giống hệt** ở C5, và 20/20 ở C7.
- Mã chỉ dùng nến có close_t ≤ t, và chỉ dùng pivot sau known_t.

## Ghi chú
- Các cấu hình dựa trên H4 chỉ có 34–81 lệnh, dưới mức 100 lệnh.
- EMA50(D1) mới có khoảng 50 nến D1 khi bắt đầu đo (tháng 3), nên phần đầu có thể chưa ổn định.
- Lệnh chờ (C7) khớp đúng giá, còn đối chứng vào lệnh thị trường nên chịu thêm khoảng 0,46 USD. Điều này làm C7 được lợi nhẹ, nhưng C7 vẫn thua.
- Đối chứng cùng chiều dùng ci95 gộp. Nếu tính ci95 theo từng lệnh thì khoảng rộng hơn, ví dụ C5 là ±0,084. Kết luận không đổi.

## Tệp
- `methods/trend_pullback.mjs`
- `trend_pullback_eval.mjs` (đối chứng cùng chiều)
- `trend_pullback_trunc.mjs`
- `trend_pullback_funnel.mjs`
- `results2/trend_pullback_*.json`

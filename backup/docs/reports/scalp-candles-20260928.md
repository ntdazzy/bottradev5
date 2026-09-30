# Nghiên cứu nến và EMA — 28/09/2026

## Kết luận hiện tại

Đã sửa thời điểm nhận nến sang tick nhận thật và chạy lại. Sổ lệnh/quyết định trước và sau sửa giống từng byte.
Bảng dưới chỉ dùng dữ liệu xuất đã sửa; lượt nghiên cứu đầu được giữ cục bộ, không dùng để chọn luật.

Chưa có bằng chứng để bật thêm 9 nhánh EMA vào bot. Trong phép đo chuyển động sau 5 phút dưới đây,
cả 9 nhóm cùng chiều H1 đều âm sau khoản chi phí xấp xỉ đã ghi trước. Điều này **không chứng minh mọi cách giao dịch EMA đều lỗ**:
nghiên cứu này chưa đặt dừng/chốt, chưa mô phỏng khớp hay quản lý từng lệnh.

Bản sửa vùng M1 đã tăng số lệnh thực khớp, nhưng bản tự chọn vẫn lỗ; số đo EA và nghiên cứu nến phải đọc riêng.
Không chọn mẫu tốt nhất sau khi nhìn bảng rồi gọi là phương pháp đã kiểm chứng.

## Nguồn và chất lượng

- Nguồn chính: nến vàng XAUUSDm được MT5 cung cấp trong lần đo `scalp_v3_audit_XAUUSDm_M1`.
- Từ 2026.01.05 00:00:00 tới 2026.09.25 20:56:00, giờ nguồn/sàn; không tự chuyển thành UTC.
- 259116 nến M1; 196 khoảng không liên tiếp và 11659 hàng được biết muộn hơn giờ đóng.
  Chưa tự kết luận mọi khoảng trống đều là lỗi: có giờ nghỉ/tuần nghỉ của sàn.
- 190509 cửa sổ đủ điều kiện; 68600 cửa sổ loại do khoảng trống/biết muộn.
- Không có hàng khối lượng cập nhật hoặc spread bằng 0. Bộ đọc từ chối thứ tự trùng, sai giá mở/cao/thấp/đóng, thiếu cột/số.
- SHA-256 của `nen_M1.csv`: `b42c8c02ef1a010e99a4dbccf0d09ac8305d4aa6d8213c17c8e2ac2236d79dbd`.
- Dữ liệu thô ở thư mục dùng chung MT5; toàn bộ nhóm chia quý/hướng ở `local/research-scalp-v3-audit.json`, không đưa dữ liệu thô lên Git.

Đã tìm thấy `scripts/connect-vps.bat` trong TradingDataHub và đọc thử API nến trên VPS, không thay đổi dịch vụ.
Nguồn trả về là OKX `XAU-USDT-SWAP`, có cảnh báo `okx_xau-usdt-swap_candle_recovery_required`.
Không dùng nguồn này thay giá mua/bán Exness hoặc giả định đó là cùng sản phẩm.

Có thể lấy nến qua [CopyRates của MT5](https://www.mql5.com/en/docs/series/copyrates).
[Exness cũng cung cấp lịch sử từng báo giá](https://get.exness.help/hc/en-us/articles/360021547851-Tick-history);
nguồn tải đó lấy từ các máy chủ MT4 được Exness quy định, không bảo đảm giống từng giá của máy chủ MT5 hiện dùng.

## Cách đo đã cố định trước khi xem kết quả

- Các nhánh độc lập: rút râu, nhấn chìm, phá rồi chạm lại cực trị nến; thêm 20/50/200 EMA trên M5/M15/H1.
  Không yêu cầu cả 9 đường hay cả 3 mẫu cùng thỏa.
- Các mẫu cụ thể ở `scripts/research-scalp.mjs` và `scripts/TOOLS.md`; EMA gieo bằng trung bình N giá đóng đầu, sau đó cập nhật chuẩn 2/(N+1).
- EMA chỉ dùng nến khung lớn đã đóng trước lúc M1 mở; nhóm chưa đủ N nến không được tính.
  EMA được dựng từ nến M1 theo giờ nguồn, chưa đối chiếu từng điểm với nến khung lớn của broker.
- Một nhịp chạm EMA liên tục chỉ được tính phản ứng đầu; phải có nến không chạm đường rồi mới nhận lần chạm tiếp.
- Chuyển động = giá đóng nến thứ 5 sau tín hiệu trừ giá mở nến ngay sau tín hiệu, đổi dấu với chiều bán.
- Khoản chi phí xấp xỉ = spread lưu trong nến vào (mua) hoặc nến thoát (bán), cộng 0,5 giá mỗi chặng.
  Spread trong nến không phải spread chính xác tại lúc khớp; chưa tính hoa hồng.
- Bảng dưới lấy mẫu cùng chiều H1, gộp hai chiều theo số mẫu. Có nhóm mọi nến làm mốc;
  chưa ghép đối chứng theo đúng cùng giờ/biến động, nên không suy ra quan hệ nhân quả từ chênh lệch.
- Cửa sổ 5 phút và các mẫu có thể chồng nhau. Đây **không phải tỷ lệ thắng hoặc tiền lời của EA**.
  Toàn bộ khoảng này đã được xem ở các nghiên cứu trước, không còn là kiểm tra độc lập.

## Kết quả khám phá, đơn vị giá vàng

| Nhóm | Số mẫu | Ngày có mẫu (giờ sàn) | Dịch chuyển trung bình | Trừ chi phí xấp xỉ |
|---|---:|---:|---:|---:|
| Mọi nến (đối chiếu) | 190509 | 226 | 0.020 | -1.236 |
| Nhấn chìm | 8801 | 226 | 0.053 | -1.202 |
| Rút râu | 5598 | 217 | 0.049 | -1.207 |
| Chạm EMA20 M5 | 534 | 174 | 0.497 | -0.756 |
| Phá rồi chạm lại cực trị nến | 784 | 191 | 0.586 | -0.669 |
| Chạm EMA50 M15 | 221 | 121 | 0.062 | -1.196 |
| Chạm EMA50 M5 | 357 | 165 | 0.242 | -1.009 |
| Chạm EMA20 M15 | 353 | 156 | -0.505 | -1.760 |
| Chạm EMA20 H1 | 160 | 90 | -0.678 | -1.940 |
| Chạm EMA200 M5 | 178 | 102 | 0.206 | -1.058 |
| Chạm EMA50 H1 | 110 | 68 | 0.184 | -1.070 |
| Chạm EMA200 M15 | 114 | 68 | 0.128 | -1.139 |
| Chạm EMA200 H1 | 52 | 29 | -0.556 | -1.817 |

Ví dụ về sự thiếu ổn định của mẫu phá rồi chạm lại:

| Quý | Số mẫu | Dịch chuyển trung bình | Trừ chi phí xấp xỉ |
|---|---:|---:|---:|
| 2026-Q1 | 293 | 1.934 | 0.693 |
| 2026-Q2 | 245 | -0.082 | -1.358 |
| 2026-Q3 | 246 | -0.355 | -1.605 |

Một quý dương không đủ để chọn làm luật. Các quý đều thuộc lịch sử đã xem, không gọi quý cuối là dữ liệu mới.

## Nguyên tắc giữ lại để phát triển

1. Mỗi nhánh cần một lý do giá rõ ràng, một mốc chứng minh nhận định sai và đủ khoảng tới cản sau chi phí.
2. Các nhánh là lựa chọn thay thế, không nối mọi dấu hiệu thành một chuỗi bắt buộc.
3. Kiểm tra dữ liệu, tiền chịu lỗ, tránh vào đuổi và không nới dừng là hàng rào dùng chung; không bỏ chúng để tăng số lệnh.
4. Thử một thay đổi có lý do mỗi lần, ghi luật trước và so bằng cùng giá mua/bán, phí, độ trễ. Không dùng tỷ lệ đi đúng chiều thay lợi nhuận.
5. Chưa tự bật EMA, chưa tăng khối lượng và chưa bật demo/thật. Cần kiểm chứng nhánh cụ thể bằng dừng/chốt thực tế và dữ liệu chưa dùng để chỉnh luật.

## Chạy lại

Dùng Node.js 18+; không cần thư viện ngoài:

```powershell
node scripts/research-scalp.mjs --self-test
node scripts/research-scalp.mjs --input '<Common Files>/BotScalpPhanUng/scalp_v3_audit_XAUUSDm_M1/nen_M1.csv' --output local/research-scalp-new.json
```

Công cụ từ chối ghi đè kết quả. Bộ tự kiểm tra bao gồm hạt giống EMA, không dùng nến khung lớn tương lai,
không đếm lặp cùng nhịp chạm, cửa sổ 5 nến, loại khoảng trống/biết muộn và tính chi phí hai chiều.

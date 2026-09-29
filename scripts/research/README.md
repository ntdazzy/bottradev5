# Bộ nghiên cứu cản trên nến M1 XAUUSD (Dukascopy) — SPEC 24.6

Thư mục: `/tmp/claude-0/-home-user-bottradev5/af7de232-0909-5609-b39b-6378847ffc36/scratchpad/research`

## Luật bắt buộc
- **Chia dữ liệu:** tìm luật trên `discovery` (đo 03–12/2025; 01–02/2025 làm nền). `validation` (01–06/2026) chỉ chạy **một lần** cho cấu hình đã
  đóng băng, ở bước kiểm riêng. **Phần khóa 07–09/2026 không được đọc** (đã chuyển ra thư mục khác; `lib.loadM1` cũng chặn).
- **Không nhìn trước:** cản chỉ dùng từ `known_t` (lúc nến cuối trong định nghĩa đã đóng). Lệnh quyết định lúc `t` chỉ được dùng nến có
  `close_t <= t`. Đỉnh/đáy từ `L.pivots` có `known_t` = lúc nến xác nhận thứ N đóng — phải lọc `known_t <= t` khi dùng ở thời điểm t.
- **Phí:** do `lib.simulate` tính (spread 0,16 + trượt 0,3/chặng; dừng lỗ và chốt lời cùng nến M1 → dừng lỗ trước). Không tự sửa.
- **Không sửa** `lib.mjs`, `runner.mjs`. Thấy lỗi thì báo trong kết quả.
- Mỗi họ phương pháp thử **tối đa 8 cấu hình** trên discovery, báo **tất cả** (không chọn lọc), rồi chọn **một** cấu hình đóng băng.

## Cách viết một phương pháp
File `methods/<tên>.mjs`:
```js
import * as L from '../lib.mjs';
export function levels(data, cfg) { /* trả mảng cản */ }
export function signals(data, levels, cfg) { /* tùy chọn: trả mảng lệnh */ }
```
- `data.m`: M1 (mảng `t,o,h,l,c`, `n`); `data.tf.M5|M15|M30|H1|H4|D1|W1 = {bars, atr}`; nến `{t, close_t, o,h,l,c, i0,i1}`;
  `data.from_t`, `data.to_t` (khoảng đo).
- Cản: `{id, side: +1 hỗ trợ | -1 kháng cự, lo, hi, known_t, expire_t, atr_src, tags: {...}}`. `tags` dùng để chia nhóm báo cáo.
- Lệnh: `{t, dir, sl, tp|null, maxMin, entry_ref, tags}` — vào ở giá mở M1 đầu tiên có `t >= lệnh.t`; `entry_ref` = giá tham chiếu để
  đặt khoảng dừng/chốt cho đối chứng ngẫu nhiên.
- Hàm có sẵn: `L.pivots(bars, N)`, `L.atr`, `L.resample`, `L.idxAt(m, t)`, `L.lastClosed(bars, t)`, `L.rng(seed)`, `L.bucket`.
- Ví dụ: `methods/baseline_pivots.mjs` (cản kiểu mã hiện tại).

## Chạy
```
node runner.mjs <tên> discovery '{"x":1}'
```
Kết quả: `results/<tên>_discovery[_cfg].json` và một dòng tóm tắt. Các số chính:
- `levels_per_day`: số cản mới mỗi ngày giao dịch (càng ít càng ít nhiễu).
- `overlap.p50`: số cản thật khác chồng lên tại mỗi lần chạm (mục tiêu ≤ 1).
- `probe` nhóm `tat_ca`: `bounce_real` / `bounce_fake` = % lần chạm giá bật ≥ 2 ATR M5 trước khi nến M5 đóng qua mép xa; `diff` ± `ci95`.
- `trades.all` vs `trades.random`: R trung bình sau phí, khoảng 95%, % thắng; đối chứng = cùng giờ, ngày khác, chiều ngẫu nhiên, cùng khoảng dừng/chốt.

## Mốc so sánh (discovery, `baseline_pivots`)
23,1 cản/ngày; chồng p50 = 5; bật thật 44,0% vs giả 42,7% (+1,3 ± 1,9); lệnh −0,183R ± 0,047 vs ngẫu nhiên −0,158R ± 0,034.

## Ngưỡng để được đi tiếp sang bước kiểm (validation)
- Chất lượng cản: `diff` ≥ +3 điểm và khoảng 95% không chứa 0 (nhóm `tat_ca` hoặc nhóm chính đã khai báo trước), **hoặc**
- Lệnh: `meanR` > 0 sau phí, và `meanR − random.meanR` > tổng hai `ci95`, với ≥ 200 lệnh.

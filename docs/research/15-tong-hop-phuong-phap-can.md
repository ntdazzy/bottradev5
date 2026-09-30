# Tổng hợp 4 tài liệu phương pháp cản và đề xuất bot mới (29/09/2026)

Nguồn: `01-rare-snr.md`, `02-secret-of-411-part1.md`, `03-secret-of-411-part2.md`, `14-ict-unicorn-model.md`
(đọc từng trang bản PDF gốc ở `docs/tài liệu trade/`), ý chủ bot (ảnh GOLD H1 ngày 28/09, SPEC mục 22)
và nghiên cứu `13-entry-sl-tp-research.md`. Tài liệu này là **đề xuất**, chưa phải luật; luật chỉ có hiệu lực khi ghi vào SPEC.

## 1. Bốn tài liệu nói gì — so sánh nhanh

| Mục | Rare SnR | Secret 411 phần 1 | Secret 411 phần 2 | ICT Unicorn | Ý chủ bot (ảnh 28/09) |
|---|---|---|---|---|---|
| Loại cản | Mức thân nến: Classic A/V, Gap, Doji | Vùng cả cây nến Z sau mô hình M/W | Đường xu hướng nối 2 giá đóng | Breaker ∩ FVG sau cú quét | Đỉnh/đáy râu, Doji SnR, DOL |
| Mức đặt ở | Thân (`C(c1)`); vùng Gap dùng râu (UL/LL) | Cả nến, **tính râu** `[L(Z), H(Z)]` | Giá đóng thân, bỏ râu | Cả nến breaker (tính râu) giao FVG 3 nến | Đỉnh/đáy râu (lần đầu); giữa râu (lần sau) |
| Điều kiện trước | Mức fresh; hoặc bị thân đóng phá rồi đổi vai | Phá 2 mức B rồi A (râu cũng tính) | Không / phá cấu trúc / đường đã bị phá | Có DOL; quét đỉnh/đáy cũ; nến đóng qua breaker | Cản chưa bị phá |
| Lần chạm dùng | Fresh (lần đầu sau tạo/lật) | Chỉ lần chạm đầu sau khi phá A | Lần chạm thứ 3 vào đường | Lần quay lại đầu | Lần đầu và lần sau (đo cả hai) |
| Vào lệnh | Đúng giá mức, khớp bằng râu (như lệnh chờ); có kiểu "có xác nhận" | "Vào ở vùng vàng"; ví dụ khớp ở mép gần | Không có luật | **Lệnh chờ** ở mép gần vùng | Thị trường sau phản ứng M1/M5 |
| Dừng lỗ | Không có luật; ví dụ ngay sau UL/LL, mức thân kế, đỉnh hộp doji (vàng 1,9–6,1 USD) | Không có luật giá; chỉ có bảng khung | Không có | Thân nến cú quét (ví dụ B không theo) | Sau đỉnh/đáy râu cản |
| Chốt lời | 1 nhãn "TP1 = 5R"; gap nội bộ HTF | Vùng ngược chiều, khung thấp hơn 1 cấp | Tỷ lệ 1:5 | DOL hoặc 2 STDV; ≥ 2R | DOL, chốt hai phần |
| Khung | Tháng→4H tìm mức, 1H/30m vào | W1/D1/H4 vùng, H1/M30/M15 vào | Nhiều khung | 5 phút, ES | M15–W1 tìm cản, M1/M5 vào |
| Tin tức | Không | Không | Không | Né tin mạnh | Né tin |
| Số liệu thống kê | Không có; ví dụ chọn sau | Không có | Không có | Không có; 2 ví dụ thắng | — |

## 2. Những điểm cả 4 tài liệu thống nhất

1. **Tìm cản ở khung lớn, vào lệnh ở khung nhỏ** để dừng lỗ nhỏ (Rare SnR tr.14: cùng lệnh, 4H cần 13,1 pip, 1H chỉ 4,1 pip).
2. **Chỉ dùng cản còn "mới" (fresh)**: lần chạm đầu sau khi cản hình thành hoặc sau khi đổi vai.
3. **Kịch bản chủ lực là "phá rồi quay lại"**: Rare SnR (lật vai SBR/RBS, flipzone), 411 (phá B rồi A, chạm lại vùng Z),
   Unicorn (quét đỉnh/đáy, đổi cấu trúc, quay lại breaker/FVG). Đảo chiều thẳng tại cản chưa phá chỉ có vài ví dụ (Rare SnR tr.6) và ý chủ bot.
4. **Giá vào = đúng mép cản**, khớp khi râu nến chạm tới — thực chất là lệnh chờ tại mức. Không tài liệu nào bắt chờ nến xác nhận,
   trừ kiểu "vào có xác nhận" của Rare SnR (không có luật số).
5. **Dừng lỗ ngay sau biên vùng** (không theo ATR); **chốt ở vùng/thanh khoản đối diện**, tỷ lệ lời/lỗ lớn (Rare SnR 1:5, 411 phần 2 1:5).

## 3. Những điểm mâu thuẫn — phải đo, không tự chọn

| Mâu thuẫn | Bên A | Bên B | Cách xử lý |
|---|---|---|---|
| Mức ở thân hay râu | Rare SnR, 411 phần 2: thân | 411 phần 1, Unicorn, ý chủ bot: cả râu | Đo cả ba mốc: thân, giữa râu, đầu râu (SPEC 22.4) |
| Thế nào là phá | Rare SnR: **thân đóng** qua mức | 411 phần 1: **râu cũng tính** | Đo hai định nghĩa |
| Vào lệnh | Tài liệu: lệnh chờ tại mức | Chủ bot + SPEC 1.2/9.3: thị trường sau phản ứng M1/M5 | Đo cả hai trên cùng cản (lệnh chờ đo trên giấy) |
| Hủy setup | Rare SnR tr.4: đóng qua đường mức | Rare SnR tr.8–9: đóng qua UL/LL | Đo hai ngưỡng |
| Số lần chạm | Fresh = 1 lần | 411 "tối đa 3 lần", Rare SnR tr.22 bán nhiều lần | Ghi số thứ tự lần chạm, so từng lần |

## 4. Rủi ro đã biết khi đưa vào bot

- **Tài liệu không có thống kê**; mọi ví dụ được chọn sau khi đã biết kết quả. Tỷ lệ 1:5 là ví dụ đẹp, không phải kỳ vọng.
- **Lệnh chờ tại mức bị "chọn nhầm bất lợi"**: lệnh chỉ khớp khi giá đi ngược mình; lệnh chạy thẳng thì bị lỡ (Linnainmaa 2010).
  Bot cũ của dự án từng lỗ vì lệnh chờ dùng phản ứng cũ (`docs/reports/scalp-loss-20260928.md`). Khác biệt lần này: cản khung lớn,
  chỉ lần chạm đầu, hạn ngắn — nhưng vẫn phải đo, kể cả phần lệnh bị lỡ.
- **Dừng lỗ ngay sau râu nằm đúng chỗ lệnh dừng dồn** (Osler 2003); cần đo thêm đệm.
- **Vàng M1/M5**: không tài liệu nào có ví dụ dưới 15–30 phút. Chênh lệch giá ~11–13% biên độ M1 → dừng lỗ quá nhỏ sẽ bị chi phí ăn.

## 5. Đề xuất bot mới (chờ chủ bot duyệt)

Tên tạm: **HTF-ZONE**. Giữ nguyên phần an toàn/gửi lệnh/khôi phục của bot 1.3 (`ScpExec`, `ScpSafety`, `ScpState`, `ScpJournal`),
thay toàn bộ phần tìm cản và chọn điểm vào.

**5.1 Sổ cản khung lớn (M15, M30, H1, H4, D1, W1)** — mỗi cản có: khung, loại, mốc thân, mốc râu, vùng, vai trò, trạng thái
(fresh → đã chạm → bị phá → đổi vai → fresh ở phía mới), số lần chạm, lúc được biết.
- Rare SnR: Classic A/V, Gap (vùng UL/LL), Doji SnR (vùng tới râu doji).
- 411 phần 1: vùng nến Z sau mô hình M/W phá 2 mức.
- Đỉnh/đáy râu (ý chủ bot), OB, FVG, đỉnh/đáy ngày-tuần trước, số tròn.
- DOL: đỉnh/đáy râu chưa bị quét (đích).

**5.2 Kịch bản vào lệnh (mỗi kịch bản bật/tắt và đo riêng)**
- **K1 Đảo chiều ở cản fresh** (Rare SnR tr.6, ảnh chủ bot).
- **K2 Phá rồi quay lại cản đã đổi vai** (Rare SnR flipzone SBR/RBS; 411 vùng Z sau phá B rồi A).
- **K3 Unicorn**: quét đỉnh/đáy → đổi cấu trúc → quay lại breaker ∩ FVG, đích DOL.
- **K4 Đường xu hướng chạm lần 3** (411 phần 2) — đề xuất để giai đoạn sau vì cần vẽ đường và nhiều giả định.

**5.3 Cách vào**: V1 thị trường sau phản ứng M1/M5 (rút râu / nhấn chìm / phá đỉnh-đáy nhỏ); V2 lệnh chờ tại mép cản (như tài liệu),
hạn ngắn, hủy khi thân đóng qua mép xa. Công cụ đo so V1 với V2 trên cùng cản, kể cả lệnh V2 bị lỡ.

**5.4 Dừng lỗ**: sau mép xa của vùng (UL/LL, đầu râu, đỉnh hộp doji) + đệm {0; 0,3; 0,5 ATR M5} + spread.
**5.5 Chốt lời**: hai phần — phần đầu ở 1R/1,5R/cản M5; phần sau ở DOL hoặc cản fresh đối diện khung lớn; dời dừng về giá vào sau phần đầu.
**5.6 Khối lượng** theo bậc khung cản trong trần 0,25%; **né tin** ±5 phút (đo thêm ±30); mặc định chỉ quan sát, chặn tiền thật.

**5.7 Trình tự làm**: (1) ghi SPEC 2.0; (2) công cụ đo `ScpSignalLab` đo K1–K3 × V1/V2 × mốc × dừng lỗ, so với vào ngẫu nhiên
và cản giả; (3) chủ bot chạy máy thử 01–06/2026; (4) chốt tối đa 3 tổ hợp, kiểm một lần 07–09/2026;
(5) viết EA HTF-ZONE chỉ bật tổ hợp đạt; (6) chạy máy thử cả EA có phí/trượt.

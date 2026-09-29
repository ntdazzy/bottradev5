# Tìm cản ít nhiễu: tổng hợp nghiên cứu và phương án thuật toán (29/09/2026)

Nguồn: `16a-sr-ma-nguon-mo.md` (mã nguồn mở), `16b-sr-cong-dong-bot.md` (cộng đồng chạy bot), `16c-sr-hoc-thuat.md` (học thuật),
cùng số liệu đo của dự án (lượt `siglab_2026h1_v5`, `v7`, tuần 05–12/01/2026). Tài liệu này là **đề xuất**, chưa phải luật; luật chỉ có
hiệu lực khi chủ bot duyệt và ghi vào SPEC.

## 1. Vì sao cách tìm cản hiện tại nhiễu

Số đo của ta (1 tuần, XAUUSDm):
- Mỗi lần chạm có trung vị **19 cản khác** chồng lên (v5: 24). Gần như giá lúc nào cũng nằm trong vùng cản.
- Cản thật bật ≥ 2 ATR M5 trước khi bị phá: **43,9%**, cản giả dịch ngẫu nhiên: **41,3%**. Lệnh vào ở cản: **−0,15R** sau phí, bằng vào ngẫu nhiên.

Nguyên nhân, đối chiếu nghiên cứu:
1. **Tạo cản từ mọi hình nến** (mọi pivot, mọi cặp gap, mọi Classic, FVG, OB, Doji) trên 6 khung. Không mã nguồn mở nào làm vậy: họ tính
   điểm rồi **chỉ giữ vài vùng mạnh nhất, không chồng nhau** (LonesomeTheBlue: tối đa 6; LuxAlgo: 1 trên + 1 dưới) — 16a mục 1, 2.
2. **Một pivot đơn lẻ đã thành vùng.** Nơi có số liệu (Chung & Bellotti 2021; Garzarelli 2014) cho thấy mức **đã bật nhiều lần** mới có
   xác suất bật cao hơn ngẫu nhiên; mã mở cũng cần ≥ 2 pivot trong một cụm — 16a, 16c.
3. **Cộng cản trùng không làm cản mạnh hơn**: Osler 2000 đo trên mức của 6 công ty FX — mức được nhiều nơi cùng chọn không bật tốt hơn;
   điểm "mạnh/yếu" chấm cảm tính vô dụng — 16c.
4. **FVG, OB, gap, Fibonacci chưa có nghiên cứu nào chứng minh** — 16c mục 2b. (Trong v7 FVG/OB nhỉnh hơn cản giả nhưng mẫu nhỏ.)
5. **Cản sống quá lâu.** Tác dụng của mức giảm dần theo thời gian; mức bật ít lần mất tác dụng sau vài giờ (EURUSD M1: ~350 phút với 1 lần bật,
   ~900 phút với 4 lần) — 16c (Chung & Bellotti).

## 2. Điều nghiên cứu nói chắc chắn

| Kết luận | Bằng chứng | Nguồn |
|---|---|---|
| Số tròn là nơi lệnh dồn: chốt lời **đúng tại**, dừng lỗ **ngay sau**; thứ tự $100 > $50 > $10 | Lệnh thật của ngân hàng (9.667 lệnh) | Osler 2003 (16c) |
| Qua số tròn thì giá hay **chạy tiếp nhanh** | So với mức ngẫu nhiên | Osler 2001/2003 (16c) |
| Mức đã bật nhiều lần thì dễ bật tiếp; tác dụng giảm theo thời gian | So với chuỗi giá xáo trộn | Chung & Bellotti 2021; Garzarelli 2014 (16c) |
| Lợi thế của cản có thật nhưng **nhỏ**: ~+4–5 điểm % so với mức ngẫu nhiên | 16/16 cặp công ty–tiền | Osler 2000 (16c) |
| Lợi thế nhỏ bị **phí ăn hết** khi dừng lỗ hẹp | ORB 5 chỉ số: +0,12R trước phí → ~0 hoặc âm sau phí | Blog MQL5 (16b) |
| Chưa có nguồn độc lập nào có bot cản scalping vàng M1/M5 lời sau phí, kiểm ngoài mẫu | — | 16b |

## 3. Phương án đề xuất: "Cản lõi" (ít, rõ, có lý do)

### 3.1 Chỉ 3 họ cản, mỗi họ có lý do lệnh dồn ở đó

| Họ | Định nghĩa | Lý do / nguồn |
|---|---|---|
| **R — số tròn** | Bội số $100, $50, $10 (báo cáo tách từng bậc). Vùng = mức ± γ | Osler 2003 (lệnh thật) |
| **E — đỉnh/đáy đã được tôn trọng** | **Cụm** ≥ 2 đỉnh (hoặc đáy) pivot khung M15/H1/H4 nằm trong độ rộng tối đa W; vùng = [thấp nhất, cao nhất] các đầu râu trong cụm | Chung & Bellotti; Garzarelli; LonesomeTheBlue; smc "equal highs/lows" |
| **P — mốc ai cũng nhìn** | Đỉnh/đáy ngày trước, tuần trước, phiên Á (00:00–07:00 giờ sàn) | 16b (cộng đồng; học thuật coi là một dạng đỉnh/đáy gần) — **đo riêng**, không coi là đã chứng minh |

- **Bỏ** làm cản riêng: Classic A/V, Gap SnR, Doji SnR, FVG, OB, cản tạm M5, cản đổi vai hàng loạt. Giữ công cụ cũ để chạy đối chứng.
- Vùng Z (411) và Unicorn giữ như kịch bản riêng, không nằm trong sổ cản lõi.

### 3.2 Chấm điểm và chọn vùng (bỏ nhiễu)

1. **Điểm của vùng E** (theo 16a TouchScorer + 16c):
   - +1 cho mỗi lần **bật** trước đó (giá vào vùng rồi ra lại đúng phía; cách đếm của Chung & Bellotti);
   - −2 khi **thân nến M15 đóng xuyên qua** vùng, −1 khi râu xuyên;
   - giảm theo thời gian: nhân `0,5^(tuổi / T½)`, thử T½ ∈ {1, 2, 5} ngày.
2. **Chọn không chồng nhau (NMS, như LonesomeTheBlue):** xếp vùng theo điểm; lấy vùng mạnh nhất, xóa mọi vùng chồng lên nó, lặp lại.
3. **Giới hạn số vùng tại mỗi thời điểm:** họ E tối đa **2 vùng trên + 2 vùng dưới** giá; họ R 1 mức gần nhất mỗi phía cho từng bậc;
   họ P theo định nghĩa (≤ 6 mức). Tổng khoảng **6–10 mức**, so với hàng trăm hiện nay.
4. **Độ rộng:** W = k × ATR(M15), thử k ∈ {0,5; 1}; γ cho R = 0,1 × ATR(M5). Vùng quá rộng thì không nhận.
5. **Hết hạn:** thân nến M15 đóng xuyên qua 2 lần, hoặc điểm sau giảm < ngưỡng, hoặc quá 5 ngày.

### 3.3 Hai cách vào lệnh, đo riêng (vì nghiên cứu chỉ ra cả hai)

- **Bật (đảo chiều):** giá chạm vùng → phản ứng M5 (rút râu / nhấn chìm) → vào thị trường. Dừng lỗ sau mép xa vùng + đệm, **không đặt
  ngay sau số tròn hay ngay sau đỉnh/đáy** (dừng lỗ của người khác dồn ở đó — Osler).
- **Phá rồi đi tiếp:** nến M5 đóng qua vùng R/P → vào theo chiều phá, dừng lỗ lại trong vùng (Osler: qua cụm dừng lỗ thì giá chạy nhanh).
- **Lọc phí bắt buộc:** chỉ vào khi dừng lỗ ≥ 4 × (spread + trượt 2 chặng). Nếu M1 không đạt thì chỉ dùng M5.

### 3.4 Cách chứng minh (đúng yêu cầu "input chất lượng")

1. **Đo chất lượng cản trước, lệnh sau** (công cụ `phan_ung_can` đã có):
   - so với cản giả **cùng khoảng cách tới giá và cùng kiểu làm tròn** (Osler); và
   - cần ≥ 1.500–2.000 lần chạm mỗi cấu hình (16c) → phải dùng **đủ 01–06/2026**.
2. **Ngưỡng đạt:** cản lõi bật hơn cản giả **≥ 5 điểm %** (hiện tại chỉ 2–3), và số cản chồng mỗi lần chạm ≤ 1.
3. Đạt bước 1–2 mới đo lệnh: R sau phí > 0, hơn vào ngẫu nhiên cùng SL/TP; tách theo tháng và phiên — nếu lời dồn vào một giai đoạn thì
   coi như không có lợi thế (16b). Không đạt thì **dừng hướng cản** cho M1/M5, báo chủ bot, không cố chỉnh tham số.

## 4. Điều cần nói thẳng

- Nghiên cứu cho thấy lợi thế của cản **nhỏ** (~4–5 điểm %). Phương án này nhằm **đo đúng và bỏ nhiễu**, không hứa có lời.
- Nếu cản lõi vẫn không hơn cản giả rõ rệt trên 6 tháng, thì cách "vào ở cản trên M1/M5" khó có lời sau phí; lúc đó cần xem hướng khác
  (khung M15 trở lên, hoặc chiến lược phá/đi tiếp).

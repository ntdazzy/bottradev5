# Tổng kết 7 họ phương pháp cản trên vàng M1 (discovery 03–12/2025)

Ngày 29/09/2026. Dữ liệu: nến M1 Dukascopy. Phí tính theo `lib.simulate`: spread 0,16 và trượt 0,3 mỗi chặng, tức khoảng 0,76 USD mỗi lệnh.

## Trả lời ngắn

- **Chưa có phương pháp nào đạt.** Cả 7 họ đều bị kiểm toán độc lập đánh trượt ngay ở bước tìm luật (discovery).
- **Chưa phương pháp nào được chạy kiểm trên 01–06/2026**, vì không họ nào qua kiểm toán. Như vậy phần 01–06/2026 vẫn còn "sạch" để dùng cho lần kiểm sau.
- **Không có gì "đã chứng minh".** Có 3 hướng "hứa hẹn nhưng chưa chắc" đáng đo tiếp (mục 3).
- Tất cả đều giảm nhiễu rất tốt: từ 23 cản/ngày xuống còn 0,3–6 cản/ngày, và số cản chồng nhau từ 5 xuống 0–1. Nhưng **ít nhiễu chưa có nghĩa là có lời**.

## Cách đọc bảng

- **Cản/ngày**: số cản mới mỗi ngày. Càng ít thì càng ít nhiễu.
- **Chồng**: trung vị số cản khác nằm đè lên cản đang được chạm.
- **Thật − giả**: tỷ lệ giá bật ở cản thật trừ tỷ lệ bật ở cản giả dời chỗ ngẫu nhiên, tính bằng điểm %, kèm khoảng sai số 95%. Nếu khoảng này chứa số 0 thì chưa chắc có lợi thế.
- **Lệnh R**: lời/lỗ trung bình mỗi lệnh sau phí, tính theo đơn vị rủi ro (1R = khoảng dừng lỗ). Số này được so với vào lệnh ngẫu nhiên cùng giờ, cùng khoảng dừng.
- **Ngưỡng đi tiếp** phải đạt một trong hai điều sau:
  - Thật − giả ≥ +3 điểm và khoảng sai số không chứa 0.
  - Lệnh R > 0, phần hơn ngẫu nhiên lớn hơn tổng hai khoảng sai số, và có ít nhất 200 lệnh.

**Mốc cũ (mã hiện tại)**: 23,1 cản/ngày; chồng 5; thật − giả +1,3 ± 1,9; lệnh −0,183R so với ngẫu nhiên −0,158R.

## 1. Bảng xếp hạng

Xếp theo mức bằng chứng, từ khá nhất đến yếu nhất. Số trong bảng là của cấu hình đóng băng; nếu kiểm toán tìm ra lỗi thì dùng số sau khi sửa.

| # | Họ phương pháp | Cản/ngày | Chồng | Thật − giả (điểm) | Lệnh R sau phí / ngẫu nhiên (số lệnh) | Kiểm 01–06/2026 | Kết luận |
|---|---|---|---|---|---|---|---|
| 1 | Râu đỉnh/đáy lớn H1–D1 (`owner_wick_htf`) | 2,2 | 0 | +10,8 ± 8,2. Đổi cách rải cản giả thì chỉ còn **+5,1 ± 8,3** | +0,28 ± 0,73 / +0,05 (283). Bỏ 3 lệnh lời lớn nhất thì còn **−0,24** | Không chạy | Không đạt |
| 2 | Unicorn M5/M15 (`unicorn_strict`) | 1,6 | 0 | +9,2 ± 9,6 | +0,09 ± 0,30 / −0,19 (248). Bỏ 5 lệnh lớn nhất thì còn −0,11 | Không chạy | Không đạt |
| 3 | Đỉnh/đáy ngày trước, tuần trước, phiên Á, giờ mở London (`reference_levels`) | 6,3 | 1 | +4,5 ± 4,2. Khi cản giả đặt cùng khoảng cách tới giá thì chỉ còn **+0,6 ± 2,8** | −0,05 ± 0,10 / −0,16 (573) | Không chạy | Không đạt |
| 4 | Phá biên 30 phút đầu phiên London/New York (`session_momentum`) | 3,9 | 0 | +3,3 ± 5,6 | +0,04 ± 0,12 / −0,04 (400). 03–07: +0,14; 08–12: **−0,06** | Không chạy | Không đạt |
| 5 | Mô hình 411, hình M/W (`s411_strict`) | 1,0 | 1 | +4,4 ± 11,6 | −0,05 ± 0,21 / +0,05 (149) | Không chạy | Không đạt |
| 6 | Số tròn và cụm đỉnh/đáy (`core_evidence`) | 5,6 | 0 | +1,1 ± 4,1 (đã sửa lỗi đối chứng) | −0,06 ± 0,06 / −0,15 (1479) | Không chạy | Không đạt |
| 7 | Rare SnR nghiêm ngặt (`rare_snr_strict`) | 2,5 | 0 | +6,0 ± 8,2 | **−0,21** ± 0,16 / −0,08 (236), sau khi sửa lỗi bỏ sót lệnh thua | Không chạy | Không đạt |

Ghi chú:

- Hai họ #1 và #3 được người viết tự chấm là "đạt" ở phần chất lượng cản. Kiểm toán bác cả hai vì cản giả không được đặt công bằng:
  - Với #1, kết quả phụ thuộc vào một lần rải cản giả "may". Thử 20 cách rải khác thì chỉ 2 cách còn đạt.
  - Với #3, cản giả nằm xa giá hơn cản thật. Khi đặt cản giả cùng khoảng cách tới giá thì lợi thế biến mất.
- Họ #1, #2 và #4 có lệnh R dương, nhưng phần hơn ngẫu nhiên vẫn nằm trong nhiễu:
  - #1 và #2 sống nhờ vài lệnh lời rất lớn. Riêng #1 lời chủ yếu trong tháng 10/2025.
  - #4 chỉ lời ở nửa đầu năm, nửa sau lỗ.
- Không cấu hình nào thắng vào lệnh ngẫu nhiên một cách chắc chắn.

## 2. Phương pháp tốt nhất

**Không có phương pháp nào đủ bằng chứng để gọi là "tốt nhất" và đưa vào bot chạy thật.** Các lý do:

- Không họ nào qua ngưỡng discovery sau kiểm toán.
- Vì vậy không họ nào được phép chạy kiểm 01–06/2026. Theo luật dự án, chỉ cấu hình qua ngưỡng mới được kiểm.
- Ba kiểm toán còn phát hiện lỗi làm kết quả đẹp hơn thực tế:
  - Rare SnR bỏ sót những lệnh chờ khớp rồi thua ngay trong cùng phút.
  - Số tròn và cụm đỉnh/đáy, cùng Rare SnR: cản giả hết hạn theo cản thật chứ không theo chính nó.
  - Râu HTF và đỉnh/đáy tham chiếu: cách rải cản giả không công bằng.

Kết quả này khớp với tài liệu (`research_D_synthesis.md`): chưa có nghiên cứu trung thực nào cho thấy vào lệnh tại cản vàng M1/M5 có lời sau phí.

## 3. Nhóm đáng đo tiếp (chỉ là giả thuyết)

Các nhóm dưới đây đều được tìm ra *sau khi* đã xem kết quả. Vì vậy mỗi nhóm phải được **khai báo trước là nhóm chính** rồi mới đo lại. Không được coi các con số dưới đây là bằng chứng.

1. **Râu đỉnh/đáy lớn H1, lần chạm đầu (cản còn mới)** (#1).
   - Số đo: H1 +18,0 ± 10,1 với cách rải cản giả mặc định, còn +7,4 ± 10,2 khi gộp nhiều cách rải. Lần chạm đầu +16,3 ± 9,8.
   - Đây là nhóm có tín hiệu mạnh nhất. Khung H4/D1 và các lần chạm sau không có gì.
2. **Kháng cự là đỉnh ngày/tuần/phiên** (#3, nhãn `hl=H`).
   - Số đo: +8,0 ± 5,9. Ổn định qua hai nửa năm: +7,4 rồi +8,7.
   - Cần đo lại với cản giả đặt cùng khoảng cách tới giá.
   - Lưu ý: năm 2025 vàng tăng mạnh, nên lợi thế ở đỉnh có thể chỉ do xu hướng năm đó.
3. **Unicorn khung M5** (#2).
   - Số đo: +10,5 ± 10,2. Hai nửa năm đều dương (+7,4 và +11,0) nhưng từng nửa chưa chắc chắn.
   - Lệnh phụ thuộc vào vài lệnh lời lớn.

Các hướng nên bỏ vì bằng chứng cho thấy xấu rõ:

- Cản lật vai.
- Cản classic kiểu Rare SnR.
- Vùng khung H4 của 411: lệnh −0,55R.
- Chốt lời ở cản đối diện.
- Chiến lược quét rồi đảo chiều.
- Vào lệnh trong khung 17–24 giờ UTC.

**Việc cần sửa công cụ đo trước khi đo tiếp.** Không sửa thì kết quả vẫn không đáng tin.

- Cản giả phải đặt cùng khoảng cách tới giá, cùng giờ và cùng độ rộng với cản thật. Tuổi cản giả phải cố định, không lấy theo cản thật.
- Phải gộp kết quả của nhiều cách rải cản giả, thay vì chỉ dùng một cách.
- Đối chứng ngẫu nhiên cho lệnh phải gộp nhiều lần rải. Hiện một lần rải có thể dao động từ −0,23R đến +0,02R.
- Trình chạy (runner) đặt tên file kết quả theo 9 ký tự đầu của cấu hình, nên các cấu hình giống đầu ghi đè lên nhau. Cần sửa lỗi này.
- Mô phỏng lệnh chờ phải khớp đúng giá. Lệnh vừa khớp đã chạm dừng lỗ ngay trong phút đó phải tính là thua.

## 4. Bước tiếp theo: MQL5 và máy thử Exness

Nói thẳng: **hiện chưa có luật nào đủ tư cách để viết thành phần gửi lệnh trong MQL5.** Nếu viết bây giờ thì chỉ là chuyển một phương pháp chưa có lời sang MQL5.

Đề xuất theo thứ tự:

1. **Chủ bot quyết định có đo tiếp hay không.** Tài liệu gợi ý hướng chính là đo chính những vùng anh tự chọn trước (xem `research_D_synthesis.md`, mục 3). Làm vậy có thể rẻ hơn tiếp tục thử thêm luật máy.
2. **Nếu đo tiếp:**
   - Sửa công cụ đo như mục 3.
   - Viết sẵn luật cho tối đa 3 nhóm ở mục 3, mỗi nhóm có một cấu hình cố định và một nhóm chính khai báo trước.
   - Chạy lại trên discovery. Nhóm nào qua ngưỡng thì mới chạy **một lần** trên 01–06/2026.
3. **Đưa vào MQL5 chỉ ở chế độ quan sát, không gửi lệnh.**
   - Mỗi nhóm qua được 01–06/2026 thì viết phần vẽ cản và tín hiệu trong EA, tắt phần gửi lệnh.
   - Làm theo `AGENTS.md`: tách lượt quan sát với lượt gửi, và ghi nhật ký đủ.
   - Chạy máy thử Exness XAUUSDm với tick thật trên **01–06/2026**. So cản và tín hiệu của EA với bản Node trên cùng ngày, để bắt lỗi chuyển mã và thấy khác biệt giữa giá Dukascopy (chỉ có giá bid) và tick Exness (spread thật, trượt giá thật).
   - Theo `docs/HANDOFF.md`, chủ bot phải tự chạy máy thử (xem `scripts/TOOLS.md`), vì máy cloud không đăng nhập được sàn.
4. **Chốt tối đa 3 tổ hợp.** Tổ hợp là một phương pháp cùng một cấu hình cố định. Chủ bot chốt bằng văn bản, gồm mã phương pháp, cấu hình và tiêu chí đạt/trượt. Các tổ hợp phải đã qua 01–06/2026 cả ở bản Node lẫn máy thử.
5. **Chỉ sau bước 4 mới mở phần khóa 07–09/2026**, và mỗi tổ hợp chỉ chạy một lần.
   - Lưu ý: chạy máy thử Exness trên 07–09/2026 cũng tính là đã mở phần khóa.
   - `docs/HANDOFF.md` ghi có lượt máy thử 03–20/08/2026 của bot cũ. Nếu dùng lại lượt đó để chọn luật mới thì phần khóa không còn sạch.
6. Nếu tổ hợp nào qua phần khóa, cần thêm các bước sau trước khi chạy tiền thật:
   - Chạy demo dài hơn, có tính phí hoa hồng thật và trượt giá thật.
   - Báo đủ mức sụt vốn và số lệnh.

## Tệp liên quan

- Phương pháp và bản đã sửa lỗi nằm trong `research/methods/`:
  - `rare_snr_strict_fixed.mjs`
  - `s411_strict_fixed.mjs`
  - `core_evidence_fixed.mjs`
- Kết quả discovery nằm trong `research/results/`. Không có file kết quả nào cho 01–06/2026.

## Bổ sung 29/09: đo lại với đối chứng công bằng (`scripts/research/runner2.mjs`)

Theo yêu cầu kiểm toán: cản giả đặt **cùng khoảng cách có dấu tới giá lúc biết và cùng bề rộng** (theo ATR H1), cùng thứ và giờ,
dời ±1–3 tuần; **gộp 10 lần rải**; tuổi đo cố định 120 giờ cho cả thật lẫn giả (không lấy theo sự kiện của cản thật); lệnh chờ khớp
đúng giá (khớp rồi chạm dừng lỗ cùng phút = thua); đối chứng lệnh ngẫu nhiên 10 bản mỗi lệnh. Discovery 03–12/2025, cấu hình đóng băng:

| Họ | Cản/ngày | Thật − giả (điểm) | Lệnh R / ngẫu nhiên | Bỏ 3 lệnh lớn nhất |
|---|---|---|---|---|
| Mốc (mã hiện tại) | 22,6 | −0,3 ± 1,3 | −0,18 / −0,13 | −0,19 |
| Râu đỉnh/đáy lớn H1–D1 (của chủ bot) | 2,2 | −0,5 ± 4,2 | +0,28 ± 0,73 / +0,09 | −0,24 |
| — chỉ H1 | 1,6 | −0,2 ± 5,0 (lần chạm đầu +2,3 ± 6,1) | +0,14 / −0,04 | −0,32 |
| Unicorn | 1,6 | +3,5 ± 4,8 | +0,09 / +0,07 | −0,04 |
| Mốc ngày/tuần/phiên | 6,3 | +1,5 ± 2,3 (đỉnh: +0,5 ± 3,1) | −0,05 / −0,09 | −0,06 |
| Rare SnR chặt | 2,5 | +3,7 ± 4,3 | −0,21 / −0,08 | −0,24 |
| 411 chặt | 0,9 | −1,8 ± 6,8 | −0,05 / −0,10 | −0,11 |
| Cản lõi (số tròn + cụm) | 5,5 | +1,1 ± 3,0 | −0,06 / −0,10 | −0,06 |
| Phá vùng mở phiên | 3,9 | −0,4 ± 3,0 | +0,04 / −0,04 | +0,03 |

**Kết luận:** khi so công bằng, **mọi định nghĩa cản đã thử đều bật không hơn một vùng bất kỳ cùng khoảng cách tới giá** (chênh −2..+4 điểm,
khoảng 95% đều chứa 0). Các "lợi thế" +5..+11 điểm trước đó là do cản giả đặt xa giá hơn. Không lệnh nào hơn ngẫu nhiên một cách chắc chắn;
các kết quả dương đều nhờ vài lệnh rất lớn. Khớp với tài liệu (Osler: +4–5 điểm trên FX; ở vàng M1 2025 còn nhỏ hơn).
Công cụ nghiên cứu (không kèm dữ liệu) lưu ở `scripts/research/`; dữ liệu nến Dukascopy để ngoài repo (đặt `DUKA_DIR`).

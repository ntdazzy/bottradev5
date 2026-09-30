# Công cụ của các bot cũ (đã chuyển vào backup)

Đường dẫn trong file này là đường dẫn cũ; file thật nằm dưới `backup/` với cùng cấu trúc thư mục.

## `scripts/run-scalp.ps1` — đo BotScalpPhanUng

```powershell
& .\scripts\build.ps1 -Target 'Experts\BotVang\BotScalpPhanUng.mq5','Scripts\BotVang\ScalpVerify.mq5'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run-script.ps1 -Script BotVang\ScalpVerify -Period M1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run-scalp.ps1
```

- `ScalpVerify` kiểm tra công thức điểm vào/mục tiêu/RSI/râu/chi phí bằng MQL5, không gửi lệnh.
- `run-scalp.ps1`: `auto`, `market`, `limit`, `passive` trên **M1**, vốn 10.000, tick thật; bộ luật 3.
  `passive` giữ cùng cách vào tự chọn nhưng tắt dời dừng/thoát sớm để đối chiếu.
- Chạy lẻ: `-Modes auto -Periods M1 -From 2026.01.05 -To 2026.02.01`; thử trễ bằng `-DelayMs 250`.
- Để thử trễ mà giữ nguyên kết quả gốc, dùng `run-tester.ps1 -Expert BotVang\BotScalpPhanUng.ex5
  -SetFile lab\scalp_delay250.set -Symbol XAUUSDm -Period M1 -From 2026.01.05 -To 2026.09.26 -DelayMs 250`.
  Kết quả riêng có tên `scalp_v3_delay250_XAUUSDm_M1`.
- Kết quả `Common\Files\BotScalpPhanUng\scalp_v3_<mode>_XAUUSDm_M1\`: `quyet_dinh.csv`,
  `deals.csv`, `lenh.csv`, `tong_ket.txt`. Cùng tên chạy lại sẽ ghi đè, cần chép kết quả muốn giữ trước.
- Script kiểm tra file mới được ghi và số lỗi tự kiểm tra bằng 0; dừng nếu thất bại. Nhật ký ở `%TEMP%\botscalp-runs`.
- Các file `lab/scalp_*.set` bật EA **trong máy thử**. Mặc định EA vẫn tắt trên biểu đồ demo.
- Kiểm chứng sổ sau khi chạy:
  `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\check-scalp.ps1 -Run scalp_v3_auto_XAUUSDm_M1`.
  Công cụ cộng lại tiền từ `deals.csv`, so từng lệnh và tổng kết, kiểm lệnh không chồng nhau, tỷ lệ trước gửi,
  dừng lỗ chỉ siết và mục tiêu không bị đổi khi dời dừng. Với `rules>=2`, kiểm thêm cùng chiều H1, có vùng đúng khung (bản 2 M15, bản 3 M1),
  không gửi trùng lần chạm, đúng lúc biết vùng, giới hạn khoảng dừng/thời gian giữ. Đây là kiểm số liệu MT5, không mô phỏng lại giá.

## `scripts/research-scalp.mjs` — nghiên cứu nến và 9 nhánh EMA

- Cần Node.js 18+, không thư viện ngoài. `node scripts/research-scalp.mjs --self-test` kiểm công thức/thời điểm.
- `lab/scalp_auto.set` bật `InpExportCandles=true`; EA xuất `nen_M1.csv` với giá, spread nến, RSI/ATR/hoạt động và hướng khung lớn.
- Chạy: `node scripts/research-scalp.mjs --input '<Common Files>/BotScalpPhanUng/scalp_v3_auto_XAUUSDm_M1/nen_M1.csv' --output local/research-new.json`.
- Đếm riêng mẫu rút râu/nhấn chìm/phá rồi hồi và EMA20/50/200 M5/M15/H1; chia theo quý, chiều và hướng H1.
  Kết quả chuyển động sau 5 phút không phải kết quả một EA có dừng/chốt. Không tự sửa luật hay bật EMA.
- Từ chối ghi đè kết quả. Dữ liệu nhận muộn/khoảng trống bị loại khỏi cửa sổ đo; không tự lấp nến.

## Điều tra lệnh — `diagnose-scalp.mjs` và `ScalpDiagnose.mq5`

1. Chạy lại cùng luật với `run-tester.ps1 -Expert BotVang\BotScalpPhanUng.ex5 -SetFile lab\scalp_audit.set -Symbol XAUUSDm -Period M1 -From 2026.01.05 -To 2026.09.26`.
   Bộ này chỉ đổi tên kết quả `scalp_v3_audit_XAUUSDm_M1` và bật xuất nến, không đổi cách giao dịch.
2. `node scripts/diagnose-scalp.mjs '<Common Files>/BotScalpPhanUng/scalp_v3_audit_XAUUSDm_M1'` ghép chính xác kế hoạch/khớp/dời dừng/deal,
   ghi `diagnose_summary.json` và `diagnose_inputs.csv`. Chưa có `time_msc` thì không tạo đầu vào đối chứng tick.
3. Biên dịch `Scripts\BotVang\ScalpDiagnose.mq5`; chạy `run-script.ps1 -Script BotVang\ScalpDiagnose -Period M1 -Params 'InpSelfTest=true'` để kiểm công thức.
4. Chạy `run-script.ps1 -Script BotVang\ScalpDiagnose -Period M1 -Params 'InpRun=scalp_v3_audit_XAUUSDm_M1'`.
   Script chỉ đọc CopyTicksRange, không có hàm gửi lệnh; ghi `diagnose_ticks_final.csv`, từ chối ghi đè.
5. Đối chứng chỉ có giá trị trong phạm vi công cụ, không phải nghiệm thu SPEC mới. Thiếu tick phải giữ là thiếu, không đổi thành thắng/thua. Không chạy script khi máy thử chính còn chạy.

## `scripts/run-smclab.ps1` — đo 4 cách vào lệnh SMC

```
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build.ps1 -Target Experts\BotVang\SmcLab.mq5
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run-smclab.ps1 -RunName smc
```
- Lần đo 2 (scalping): chốt lời 1R / 1,5R / 2R × vàng/BTC/ETH × M1/M5 (18 lần, khoảng 30–40 phút), tick thật 05/01–26/09/2026;
  đệm trượt vàng 0,5, BTC 25, ETH 2,3 (theo giá). Mỗi lần ghi đè `lab\smc_<vang|btc|eth>.set`.
- Kết quả: `Common\Files\SmcLab\<tên>_tp<1|15|2>_<ký hiệu>_<khung>\tong_ket.txt` (mỗi dòng: cách chọn mua/bán — tín hiệu / xu hướng H1 /
  EMA200 H1 —, ô, phần, số lần đặt, khớp, R sau phí, thật − đối chứng ngẫu nhiên, thật − đảo chiều, kết luận) và `lenh.csv`
  (từng lệnh thật + đối chứng). Log ở `%TEMP%\smclab-runs`.
- Chạy một lần lẻ: `run-tester.ps1 -Expert BotVang\SmcLab.ex5 -SetFile lab\smc_vang.set -Symbol XAUUSDm -Period M5`
  (file cài đặt có `InpRunName`, `InpSlip`, `InpTpR`).

## `scripts/run-phanung.ps1` — đo vào lệnh khi có phản ứng ở vùng

```
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build.ps1 -Target Experts\BotVang\PhanUngLab.mq5
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run-phanung.ps1 -RunName pu
```
- 5 loại vùng (FVG, OB, SNR, MSNR, EMA) × 4 kiểu phản ứng (R1 rút râu, R2 nhấn chìm, R3 đóng quay ra, R4 CHoCH M1 — R4 chỉ có khi chạy M5);
  chốt lời 1R / 1,5R / 2R × vàng/BTC/ETH × M1/M5 (18 lần), tick thật 05/01–26/09/2026; đệm trượt vàng 0,5, BTC 25, ETH 2,3 (theo giá).
  Mỗi lần ghi đè `lab\pu_<vang|btc|eth>.set`. Một lần vàng mất khoảng 40 giây (M5 17 giây, M1 24 giây trong tester).
- Kết quả: `Common\Files\PhanUngLab\<tên>_tp<1|15|2>_<ký hiệu>_<khung>\tong_ket.txt` (3 dòng đầu: tham số; số lệnh thật, X1, X2, kể cả số chưa xong khi hết dữ liệu;
  đối chứng thời điểm cộng lại phải ra "khớp" và dòng tự kiểm tra "dừng lỗ ngay ở tick vào" phải bằng 0; mỗi dòng: cách chọn
  mua/bán, ô, phần, lần vào, R sau phí, thật − đối chứng thời điểm (kèm số lệnh ghép, thiếu, R ghép), thật − đảo chiều, thật − X1, thật − X2,
  kết luận; cuối file: các nhóm X1, X2)
  và `lenh.csv` (lệnh thật, đảo chiều, X1, X2; đối chứng thời điểm chỉ ghi mẫu 1/50 cho file nhỏ). Log ở `%TEMP%\phanung-runs`.
- Chạy một lần lẻ: `run-tester.ps1 -Expert BotVang\PhanUngLab.ex5 -SetFile lab\pu_vang.set -Symbol XAUUSDm -Period M5`
  (file cài đặt có `InpRunName`, `InpSlip`, `InpTpR`).

## `scripts/run-phanung-scalp.ps1` — đo cách thoát scalping theo phản ứng

```
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build.ps1 -Target Experts\BotVang\PhanUngLab.mq5
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run-phanung-scalp.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run-phanung-scalp.ps1 -Slip0
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run-phanung-scalp.ps1 -Htf
```
- Chỉ vàng XAUUSDm; khung M1, M5 × chốt đầu TP1 1 / 2 / 3 / 5 giá / "tùy lực" × ăn thêm 0 / 10 giá (20 lần), dừng lỗ sau râu nến
  phản ứng (`InpSlMode=1`), đệm trượt 0,5 giá, tick thật 05/01–26/09/2026. Một lần mất khoảng 30 giây (M5) tới 50 giây (M1, có ăn thêm).
- `-Slip0`: chạy cùng 20 lần với đệm trượt 0 (tên `pus0_...`) để xem kết quả nhạy với trượt giá tới đâu; không chạy lại bản 0,5.
- Mỗi lần ghi đè `lab\pus_vang.set` (`InpRunName`, `InpSlip`, `InpSlMode`, `InpTp1Price` — −1 là "tùy lực" —, `InpRunnerPrice`).
- Kết quả: `Common\Files\PhanUngLab\<pus|pus0>_tp<1|2|3|5|luc>_r<0|10>_XAUUSDm_<khung>\tong_ket.txt`: dòng đầu ghi cách thoát (dừng lỗ, TP1,
  ăn thêm; TP1 tính từ giá khớp); mỗi dòng như `run-phanung.ps1` và thêm cột "giá TB mỗi 0,01 lot sau phí" ngay sau R (bản ăn thêm: tổng 2 nửa / 2;
  R = giá mỗi 0,01 lot / khoảng dừng lỗ; nhãn ĐẠT của công cụ trên R của từng lần vào, không phải đạt SPEC mới); mỗi cột hiệu (RC-T, đảo chiều, X1, X2) in
  "theo R [KTC95]; giá theo giá [KTC95]" — hiệu với X1, X2 đọc theo giá (SL hai nhóm dài khác nhau nên R không so được). `lenh.csv`: mỗi nửa một dòng, thêm cột
  `nua` (0 lệnh đơn, 1 nửa A chốt ở TP1, 2 nửa B ăn thêm), `hoa_von` (1: nửa B đã dời SL về giá vào khi nửa A chốt lời),
  `gia_c` (nửa này theo giá sau phí), `gia_lan_vao` / `gia_001` / `R_lan_vao` (cả lần vào, mỗi 0,01 lot, R; ở dòng nửa 0/1).
  Cột `sl` là SL ban đầu (in làm tròn 3 số lẻ). Log ở `%TEMP%\phanung-runs\<tên>_vang_<khung>.txt`.
- Không đặt `InpSlMode`, `InpTp1Price`, `InpRunnerPrice` thì PhanUngLab chạy đúng như cũ, ra kết quả giống hệt từng byte.
- `-Htf` (cản khung lớn M15/H1/H4/D1): thêm `InpHtf=true` vào file cài đặt, tên lần chạy thêm chữ `h` ở đầu (`hpus_...`,
  cùng `-Slip0` thì `hpus0_...`); không có `-Htf` thì y như trước. Một lần mất khoảng 25 giây (M5) tới 45 giây (M1) trong tester.
  Nhóm A (vùng khung vào lệnh) giữ nguyên từng dòng: bỏ các dòng có chữ `HTF` trong `lenh.csv` thì còn đúng file bản không `-Htf`;
  trong `tong_ket.txt` các dòng thêm bắt đầu bằng `HTF`, `B `, `C `, `A không trùng`, `B theo khung`.
  - `tong_ket.txt` thêm: sau 3 dòng đầu, các dòng `HTF ...` (số nến khung lớn nạp được và từ lúc nào; mỗi khung × loại vùng: tạo, gộp
    lên khung lớn, hỏng, hết tuổi, chưa đúng phía lúc biết, chạm đầu, lật; ngày/tuần; số lần gắn nhãn trùng; dòng tự kiểm tra phải bằng 0:
    dùng vùng trước lúc biết, nạp nến chưa đóng, nạp trễ; PWH/PWL so với nến W1 của sàn; nhóm B và RC-T nhóm B với dòng "khớp"; số lệnh
    C / A không trùng). Cuối file: 20 ô nhóm B (FVG, OB, SNR, MSNR, Ngày/Tuần × R1–R4, cùng cột như nhóm A), từng ô nhóm A tách thành
    `C` (vùng trùng vùng khung lớn lúc chạm đầu) và `A không trùng`, dòng `C` có thêm cột "C − A không trùng" theo R và theo giá;
    X2 của nhóm B; nhóm B theo khung M15/H1/H4/D1 (ngày/tuần) chỉ để xem.
  - File thêm: `lenh_vung.csv` (mỗi lần vào lệnh thật nhóm A và B: khung, loại, mã, biên, lúc biết, lúc đúng phía, lúc chạm đầu của vùng;
    nhóm A thêm nhãn trùng và vùng H), `vung_htf.csv` (mọi vùng khung lớn: biên, lúc biết, đúng phía, chạm đầu, hết lúc nào và vì sao,
    gộp vào mã nào), `d1_gop.csv` (nến D1 sau khi gộp nến CN vào T2), `d1_san.csv` và `w1_san.csv` (nến D1, W1 gốc của sàn để đối chiếu).
  - Nến W1 trong đoạn tester tự dựng tính tuần từ T2 00:00 (gồm phiên CN tối tuần sau), khác nến W1 lịch sử của sàn (CN–T7); PWH/PWL không
    đọc W1 (tính từ D1 gộp) nên dòng tự kiểm tra ghi số tuần khác và số tuần giải thích được bằng cách tính T2 → CN tuần sau.

## `scripts/run-luoi.ps1` — đo bot lưới BotLuoi 15 lần

```
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build.ps1 -Target Experts\BotVang\BotLuoi.mq5
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run-luoi.ps1
```
- Vàng, BTC, ETH × (đúng luật; "cho chạy lại sau mỗi lần dừng hẳn"; "cho chạy lại" với trễ 100/250/500 ms), 05/01–26/09/2026,
  vốn 5.000. Mất khoảng 35–40 phút. Log từng lần ở `%TEMP%\botluoi-runs` (đổi bằng `-LogDir`).
- Kết quả: `Common\Files\BotLuoi\<lần chạy>_<ký hiệu>\tong_ket.txt` (có 2 dòng tự kiểm tra, phải cùng ra KHỚP) và `ro.csv` (từng rổ).

## `scripts/compare-bot-lab.ps1` — so lệnh bot trong tester với Lab

```
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run-tester.ps1 -Expert BotVang\BotVang.ex5 -SetFile lab\bot_on.set
copy "%APPDATA%\MetaQuotes\Tester\D0E8…\Agent-127.0.0.1-3000\logs\<yyyyMMdd>.log" <bản sao>.log
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\compare-bot-lab.ps1 -Log <bản sao>.log -Csv "%APPDATA%\MetaQuotes\Terminal\Common\Files\BotVangLab\goc_KIEMTRA_s1_<mã>\su_kien.csv" -Out <kết quả>.txt
```
- Đọc lần chạy bot cuối cùng trong log agent; so với các lệnh Lab có `bot_chon = 1` (lúc bot rảnh, luật gốc):
  cùng giờ vào, chiều, giá vào, bước B. In R bot và R Lab (chưa trừ phí c).
- `-PerPrice` = lot × contract: vàng 1 (mặc định), BTC 0.01, ETH 0.1. File cài đặt bot khi thử: `lab\bot_on.set` (vàng),
  `lab\bot_btc_on.set`, `lab\bot_eth_on.set`; thêm `-Symbol BTCUSDm`/`ETHUSDm` cho `run-tester.ps1`.

## `scripts/compare-bot-fvgnc.ps1` — so lệnh bot demo BotFvgNhanChim trong tester với PhanUngLab

```
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build.ps1 -Target Experts\BotVang\BotFvgNhanChim.mq5
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run-tester.ps1 -Expert BotVang\BotFvgNhanChim.ex5 -SetFile lab\fvgnc_on.set -Symbol XAUUSDm -Period M5 -From 2026.01.05 -To 2026.09.26 -Deposit 100000 -TimeoutMin 60
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\compare-bot-fvgnc.ps1 -Out %TEMP%\so_fvgnc.txt
```
- `lab\fvgnc_on.set` chỉ bật bot (`InpEnabled=true`); vốn 100.000 để giới hạn lỗ ngày/tuần/tổng không chạm.
- Bot ghi mỗi lệnh đã đóng một dòng (dấu `;`) vào `Common\Files\BotFvgNhanChim\tester_XAUUSDm.csv` khi chạy tester (xóa và ghi lại
  mỗi lần chạy) hoặc `lenh_<số tài khoản>_XAUUSDm.csv` khi chạy demo (ghi nối). Cột: nến tín hiệu (giờ mở, giờ sàn), chiều, vùng FVG,
  giá lúc gửi, SL, TP, lúc/giá khớp, lúc/giá đóng, lý do (1 chốt lời, 2 dừng lỗ, 3 giữ đủ 500 nến, 4 còn mở lúc hết dữ liệu,
  5 giới hạn lỗ, 6 đóng tay/khác, 7 sàn cắt lệnh), R chưa trừ phí, tiền.
- Lab mặc định: `Common\Files\PhanUngLab\pu_tp2_XAUUSDm_M5\lenh.csv`, ô `FVG R2 nhan chim`, dòng `kieu = 0` (đổi bằng `-Lab`, `-Cell`;
  file bot đổi bằng `-Bot`).
- Ghép theo lúc đóng nến phản ứng + chiều. In: số ghép / chỉ bot / chỉ Lab; giá lúc gửi = giá vào Lab; chênh lệch lớn nhất giá khớp,
  SL, TP (theo giá); khớp cùng giây; lý do đóng giống nhau; tổng và trung bình R (chưa trừ phí) hai bên; danh sách lệnh lệch (`-List`).
- Thử trễ khớp lệnh: thêm `-DelayMs 100` (250, 500) cho `run-tester.ps1`. File tester bị ghi lại mỗi lần chạy nên chép ra trước.
- Khi bot demo đang chạy trên MT5 chính thì không chạy tester bằng script (script đóng MT5).


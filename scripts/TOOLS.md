# Công cụ của dự án BotVang

Đọc file này trước khi gõ lệnh mới. Có công cụ phù hợp thì dùng công cụ đó.

Danh mục này mô tả công cụ đang có, không phải luật của bot mới. Nguồn luật là `docs/SPEC.md`.
Các công cụ nghiên cứu bên dưới chưa được nghiệm thu cho `SCP-MTF-1.0-draft`;
không chạy cả bộ hoặc dùng kết luận của chúng làm bằng chứng đạt SPEC mới.

Máy khác có thể đặt `$env:BOTVANG_MT5_DATA` (thư mục `File → Open Data Folder`) và
`$env:BOTVANG_MT5_INSTALL` (thư mục chứa terminal/MetaEditor). `build.ps1` và các công cụ chạy MT5 dùng chung hai biến này.
Không đặt thì giữ đường dẫn mặc định của máy phát triển. Không đưa thông tin đăng nhập vào biến này hoặc Git.

## `scripts/git-commit-files.ps1` — lưu đúng các file đã chọn

```powershell
& .\scripts\git-commit-files.ps1 -Message 'docs: update guide' -Files 'README.md','docs/SPEC.md'
```

Chỉ nhận đường dẫn file nằm trong dự án; từ chối thư mục hoặc danh sách đã stage từ trước. Không tự push.

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

## `scripts/build.ps1` — chép và biên dịch code MQL5

Việc làm:
1. Chép mọi file `.mq5`/`.mqh` trong `mql5/` sang `MQL5/` của thư mục dữ liệu MT5
   (`%APPDATA%\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075`), lưu dạng UTF-16 để MetaEditor đọc đúng tiếng Việt.
2. Biên dịch từng file trong `-Target` (đường dẫn tính từ thư mục `MQL5/`) bằng `MetaEditor64.exe /compile`.
3. In các dòng lỗi/cảnh báo và dòng `Result`. Có lỗi thì thoát mã 1.

Chạy:
```
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build.ps1 -Target Experts\BotVang\BotVangLab.mq5
```

Lưu ý:
- Luôn sửa code trong `mql5/` của dự án, không sửa bản chép trong thư mục dữ liệu MT5 (lần build sau sẽ bị ghi đè).
- MetaEditor luôn trả mã thoát 0, nên script đọc kết quả từ file `.log` cạnh file `.mq5` trong thư mục dữ liệu.
- File `.ps1` phải lưu UTF-8 có BOM, nếu không Windows PowerShell 5.1 in sai chữ Việt.
- Không sửa file `.md`/`.ps1` bằng chuỗi Python có dấu `\` (dễ biến `\b`, `\r`, `\n` thành ký tự điều khiển).

## `scripts/mt5-main.ps1` — hàm dùng chung để chạy MT5 chính tự động

Không chạy trực tiếp; các script dưới đây nạp nó. MT5 chỉ cho 1 phiên trên một thư mục dữ liệu, nên hàm
`Stop-MainTerminal` đóng MT5 chính **đúng cách** (không ép tắt), `Invoke-MainTerminal` chạy MT5 với file cấu hình và
chờ nó tự tắt (kể cả khi MT5 tự cập nhật rồi khởi động lại), `Start-MainTerminal` mở lại MT5 như trước.
Không đụng các bản MT5 portable của dự án khác. Không dùng mật khẩu: MT5 chính tự đăng nhập bằng tài khoản đã lưu.
(Bản MT5 portable không đăng nhập thì Strategy Tester báo "account is not specified" và không chạy.)

## `scripts/run-tester.ps1` — chạy Strategy Tester bằng dòng lệnh

```
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run-tester.ps1 -Expert BotVang\BotVangLab.ex5 -SetFile lab\goc.set -From 2026.01.05 -To 2026.09.26
```
- Mặc định: `XAUUSDm`, M5, mọi tick theo tick thật (`-Model 4`), nạp 10.000 USD. Thêm `-Visual` để chạy trực quan,
  `-DelayMs 250` để khớp lệnh trễ cố định (thử chịu trượt giá).
- `-SetFile`: file tham số (UTF-8, dạng `Ten=giatri`), được chép vào `MQL5\Profiles\Tester`.
- In log của lần chạy (thư mục agent: `%APPDATA%\MetaQuotes\Tester\D0E8…\Agent-127.0.0.1-3000\logs`).
- File do EA ghi bằng `FILE_COMMON` nằm ở `%APPDATA%\MetaQuotes\Terminal\Common\Files`.
- Tick thật có sẵn: `XAUUSDm` từ 05/01/2026 (sàn không cho tải cũ hơn; trước mốc này tester tự sinh tick giả);
  tester tự nạp thêm nến 1 năm trước ngày bắt đầu.

## `scripts/run-script.ps1` — chạy một script MQL5 trên MT5 chính

```
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build.ps1 -Target Scripts\BotVang\ExportNews.mq5
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run-script.ps1 -Script BotVang\ExportNews
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run-script.ps1 -Script BotVang\LabVerify -Params 'InpRun=<thư mục lần chạy>'
```
- Script phải có input `InpCloseTerminal` (tự đóng MT5 khi xong); `-Params` là các cặp `Ten=giatri` ngăn nhau bằng `;`.
- `-Period M1` chạy script trên biểu đồ một phút; mặc định vẫn M5 cho các script cũ.
- In log của script (`MQL5\Logs`) rồi mở lại MT5.
- `ExportNews`: ghi lịch tin mạnh USD vào `Common\Files\BotVang\news_usd.csv` (giờ sàn = GMT+0;
  cột `time_server;event_id;event_code;name`) cho Strategy Tester.
- `LabVerify`: kiểm chứng độc lập một lần chạy BotVangLab bằng tick thật trên terminal (nến chạm đúng luật,
  giá vào, kết quả +kB/−1B).

## `ScpVerify` + `BotScpMtf` — bot SCP-MTF-1.0 (thiết kế mới)

- Hồ sơ `lab/scp_price_exit.set` kiểm bản `SCP-MTF-1.1-price-exit`: không đóng theo tuổi lệnh,
  tối thiểu 1,5 lời/lỗ sau tính cả phần chốt; chốt phần tại 3 giá, bảo vệ giá vào 2,5 giá cho vị thế không chia được.
  Chỉ dùng máy thử; thay `InpRunName` trước mỗi lượt để không ghi đè. `InpPartialAtPrice=0` chỉ để đối chứng tắt chốt phần.
- `ScpPriceManageVerify.mq5` kiểm trọn chuỗi bán 0,02 → thuận 3 giá → chốt 0,01 → dừng giá vào → giá quay lại.
  Chỉ chạy máy thử XAUUSDm từ 2026.09.02 tới trước 2026.09.03. Kiểm `[SCP_PRICE_TEST] TOTAL ... FAIL 0`.
  Đây là vị thế dựng để kiểm quản lý, không phải bằng chứng hiệu quả chọn điểm vào.

- `ScpExecVerify.mq5` là EA kiểm gửi/đóng/khôi phục, chỉ khởi động trong máy thử, mã nhận diện riêng 779991.
  Biên dịch bằng `build.ps1 -Target 'Experts\BotVang\ScpExecVerify.mq5'`, rồi dùng
  `run-tester.ps1 -Expert 'BotVang\ScpExecVerify.ex5' -From 2026.09.01 -To 2026.09.02 -Period M1`.
  Chỉ chấp nhận log có `[SCP_EXEC_TEST] TOTAL` và `FAIL 0`; không coi mã thoát công cụ là kết quả ca.

```
powershell -NoProfile -ExecutionPolicy Bypass -Command "& '.\scripts\build.ps1' -Target 'Experts\BotVang\BotScpMtf.mq5','Scripts\BotVang\ScpVerify.mq5'"
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run-script.ps1 -Script BotVang\ScpVerify -Period M1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run-tester.ps1 -Expert BotVang\BotScpMtf.ex5 -SetFile lab\scp_observe.set -Symbol XAUUSDm -Period M1 -From 2026.09.01 -To 2026.09.08
```

- `ScpVerify` chạy các ca AC của SPEC mới, in `PASS`/`FAIL` và tổng kết ra log; log cuối có dòng `Tổng: N ca | PASS .. | FAIL ..`.
  Ca lỗi phải bằng 0 trước khi báo cáo tiến độ. Thêm `-Params 'InpOnly=AC16'` để chạy một nhóm.
- `BotScpMtf` mặc định **chỉ quan sát**; có phần gửi nhưng từng nhánh mặc định tắt. Ghi `quyet_dinh.csv`, `ke_hoach.csv`, `vung.csv`, `tong_ket.txt`
  vào `Common\Files\BotScp\<InpRunName>\`. Dòng `[SCP]` cuối log tổng kết số chạm vùng/đề nghị/kế hoạch/bỏ.
- `lab/scp_observe.set`: tham số chạy máy thử (`InpEnabled`, `InpRunName`, `InpRiskPct`, `InpMinRR`).
  Máy thử từ chối tên `InpRunName` đã tồn tại; dùng tên mới, không xóa bằng chứng để chạy đè.
- `lab/scp_review_observe.set`: lượt quan sát kiểm sửa; `lab/scp_review_send.set`: chỉ gửi trong máy thử,
  giả định phí khứ hồi 0 và vẫn có đệm trượt 0,5 giá/chặng. Không nạp hồ sơ này lên demo/thật.
- Chạy dài hơn: đổi `-From`/`-To`. Một tuần M1 mất khoảng 4 phút, một tháng khoảng 15 phút trên máy này.

## `ExportBars` — xuất nến M1 dài hạn để nghiên cứu ngoài MT5

MT5 chính giới hạn số nến nên script `CopyRates` theo khoảng dài báo lỗi 4401. EA chỉ-máy-thử này ghi từng nến M1 (Bid):

```
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build.ps1 -Target 'Experts\BotVang\ExportBars.mq5'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run-tester.ps1 -Expert BotVang\ExportBars.ex5 -Symbol XAUUSDm -Period M1 -Model 1 -From 2023.01.02 -To 2026.01.05
```

- File ra: `Common\Files\BotVang\bars_XAUUSDm_M1_<ngày đầu>.csv`, cột `time;open;high;low;close;tick_volume;spread_price`.
- Máy thử có lịch sử M1 từ 2022; mất khoảng 2 giây cho 3 năm. `spread_price` là spread lưu trong nến, không thay spread khớp thật.
- Đã xuất 28/09/2026: 2023-01-02..2026-01-04, 1.061.044 nến. Dùng làm dữ liệu kiểm tra độc lập, không dùng để chọn luật.

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

## `scripts/tai-pine-tradingview.ps1` — tải mã Pine công khai từ TradingView

```
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\tai-pine-tradingview.ps1
```
- Đọc `docs\pine\tradingview\danh_sach.csv` (dấu `;`, cột `nhom;ten;tac_gia;url`), lấy mã script `PUB;...` trên trang rồi tải mã
  nguồn từ `https://pine-facade.tradingview.com/pine-facade/get/PUB;<mã>/last` (giữ nguyên dấu `;`, không mã hóa). Không đăng nhập.
- Lưu nguyên văn vào `docs\pine\tradingview\<nhóm>\<tên>.pine`, ghi `ket_qua_tai.csv` và mục lục `README.md` (tác giả, giấy phép, link).
- Chỉ báo khóa mã hoặc đã gỡ thì ghi trạng thái, không tải được. Thêm chỉ báo mới: thêm dòng vào CSV rồi chạy lại.

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

## `ScpSignalLab` + `SigVerify` — đo tín hiệu HTF-ZONE (SPEC mục 22–23)

EA chỉ chạy trong máy thử, **không có lệnh gửi**. Đợt 1: cản khung lớn M15–W1 (đỉnh/đáy râu, Classic A/V, Gap SnR, Doji SnR,
OB, FVG, đỉnh/đáy ngày-tuần trước, số tròn, cản tạm M5), kịch bản K1/K2/K5, vào thị trường sau phản ứng M1/M5.
Mỗi tín hiệu được theo dõi trên tick thật và so với đánh ngược, vào ngẫu nhiên cùng giờ 1–10 ngày sau, và cản giả.

```
powershell -NoProfile -ExecutionPolicy Bypass -Command "& '.\scripts\build.ps1' -Target 'Experts\BotVang\ScpSignalLab.mq5','Scripts\BotVang\SigVerify.mq5'"
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run-script.ps1 -Script BotVang\SigVerify -Period M1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run-tester.ps1 -Expert BotVang\ScpSignalLab.ex5 -SetFile lab\siglab_2026h1.set -Symbol XAUUSDm -Period M1 -From 2026.01.05 -To 2026.07.01
```

- `SigVerify`: log phải có `[SIG_VERIFY] TOTAL 30 | PASS 30 | FAIL 0` (đã chạy đạt 29/09 trên MT5 build 6231).
- Cần lịch tin `Common\Files\BotVang\news_usd.csv` (chạy `ExportNews` trước); thiếu lịch thì tín hiệu ghi `tin=thieu_lich`.
- Nên chạy thử 1 tuần trước (`-From 2026.01.05 -To 2026.01.12`) để đo thời gian, rồi mới chạy 01–06.
  **Không chạy 07–09 cho tới khi chốt tối đa 3 tổ hợp** (SPEC 23.5).
- Kết quả `Common\Files\BotScp\SignalLab\<InpRunName>\`:
  `tong_ket.txt` (mỗi biến thể một dòng), `nhom.csv` (mọi nhóm × cách tính), `tin_hieu.csv` (từng bản ghi thật/đối chứng),
  `vung_htf.csv` (sổ cản: khung, loại, biên, lúc biết, lúc hết và lý do). Từ chối tên lượt đã có.
- Chạy máy thử có hình (`-Visual`) thì vẽ cản theo màu khung (M15 xanh nhạt → W1 tím; nét đứt = cản đã đổi vai) và mũi tên tín hiệu.
- R tính sau spread (mua thoát Bid, bán thoát Ask) và trừ `InpSlipPerLeg`×2. Khoảng ±95% coi các bản ghi độc lập nên hẹp hơn thật.
  Đây là số đo trên giấy, chồng lấn nhau, không phải tiền của một EA.

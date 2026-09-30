# Công cụ của dự án BotVang

Đọc file này trước khi gõ lệnh mới. Có công cụ phù hợp thì dùng công cụ đó.

Danh mục này mô tả công cụ đang có, không phải luật của bot mới. Nguồn luật là `docs/SPEC.md`.
Các công cụ nghiên cứu bên dưới chưa được nghiệm thu cho `SCP-MTF-1.3-review-fixes`;
không chạy cả bộ hoặc dùng kết luận của chúng làm bằng chứng đạt SPEC mới.

Máy khác có thể đặt `$env:BOTVANG_MT5_DATA` (thư mục `File → Open Data Folder`) và
`$env:BOTVANG_MT5_INSTALL` (thư mục chứa terminal/MetaEditor). `build.ps1` và các công cụ chạy MT5 dùng chung hai biến này.
Không đặt thì giữ đường dẫn mặc định của máy phát triển. Không đưa thông tin đăng nhập vào biến này hoặc Git.

## `scripts/git-commit-files.ps1` — lưu đúng các file đã chọn

```powershell
& .\scripts\git-commit-files.ps1 -Message 'docs: update guide' -Files 'README.md','docs/SPEC.md'
```

Chỉ nhận đường dẫn file nằm trong dự án; từ chối thư mục hoặc danh sách đã stage từ trước. Không tự push.

## `scripts/tai-nen-dukascopy.mjs` và `scripts/tai-tick-exness.mjs` — tải dữ liệu giá để nghiên cứu ngoài MT5

```bash
npm install --no-save dukascopy-node@1.50.0          # một lần, chỉ cần cho tai-nen-dukascopy.mjs
node scripts/tai-nen-dukascopy.mjs m1   --tu 2015-01-01 --den 2026-07-01   # nến M1 vàng (bid, UTC)
node scripts/tai-nen-dukascopy.mjs h1   --ma xagusd --tu 2003-01-01        # nến H1 một mã, mỗi năm một file
node scripts/tai-nen-dukascopy.mjs tick --tu 2025-03-01 --den 2026-07-01   # tick Dukascopy có bid và ask
node scripts/tai-tick-exness.mjs --ma XAUUSDm --tu 2023-01 --den 2026-06   # tick thật của Exness (kho công khai), cần curl và unzip
```

- Lưu vào `data/dukascopy/<mã>/{m1,h1,tick}/` và `data/exness/<mã>/tick/`; `data/` không đưa lên Git. Chạy lại bỏ qua file đã có.
- M1: `t,o,h,l,c,v` mỗi dòng, `t` là mili giây UTC lúc mở nến. H1: `t,o,h,l,c`.
  Tick (cả hai nguồn): 10 byte mỗi tick = Int32LE mili giây trong ngày, Int32LE bid×1000, Int16LE (ask−bid)×1000.
- Từ chối `--den` sau 2026-07-01 (tháng 07/2026 với Exness): 07–09/2026 là dữ liệu khóa theo SPEC 24.6.
- Dukascopy hay giới hạn tần suất (lỗi 429): script báo `loi_tai`, không ghi file thiếu và thoát mã 2; chạy lại sau vài phút để tải tiếp.
  Ngày tick thiếu giờ nào trong 00–20h UTC thì báo `canh_bao_thieu_gio`.
- Kho Exness chỉ có mã thường (`XAUUSDm`, `XAUUSD`…), không có `XAUUSD247m`; chênh giá trong kho có thể đã làm tròn, không phải chênh thật của tài khoản.
- Thời gian tải ước tính: nến M1 10 năm ~1–2 giờ, tick Dukascopy 16 tháng ~2 giờ (tải chậm để tránh 429), tick Exness 3,5 năm ~30 phút; tổng ~4 GB.

## `scripts/build.ps1` — chép và biên dịch code MQL5

Việc làm:
1. Chép mọi file `.mq5`/`.mqh` trong `mql5/` sang `MQL5/` của thư mục dữ liệu MT5
   (`%APPDATA%\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075`), lưu dạng UTF-16 để MetaEditor đọc đúng tiếng Việt.
2. Biên dịch từng file trong `-Target` (đường dẫn tính từ thư mục `MQL5/`) bằng `MetaEditor64.exe /compile`.
3. In các dòng lỗi/cảnh báo và dòng `Result`. Có lỗi thì thoát mã 1.

Chạy:
```
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build.ps1 -Target Experts\BotVang\BotScpMtf.mq5
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
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run-tester.ps1 -Expert BotVang\ScpSignalLab.ex5 -SetFile lab\siglab_2026h1.set -From 2026.01.05 -To 2026.07.01
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
```
- Script phải có input `InpCloseTerminal` (tự đóng MT5 khi xong); `-Params` là các cặp `Ten=giatri` ngăn nhau bằng `;`.
- `-Period M1` chạy script trên biểu đồ một phút; mặc định vẫn M5 cho các script cũ.
- In log của script (`MQL5\Logs`) rồi mở lại MT5.
- `ExportNews`: ghi lịch tin mạnh USD vào `Common\Files\BotVang\news_usd.csv` (giờ sàn = GMT+0;
  cột `time_server;event_id;event_code;name`) cho Strategy Tester.

## `ScpVerify` + `BotScpMtf` — bot SCP-MTF-1.3 (thiết kế mới)

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

## `scripts/tai-pine-tradingview.ps1` — tải mã Pine công khai từ TradingView

```
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\tai-pine-tradingview.ps1
```
- Đọc `docs\pine\tradingview\danh_sach.csv` (dấu `;`, cột `nhom;ten;tac_gia;url`), lấy mã script `PUB;...` trên trang rồi tải mã
  nguồn từ `https://pine-facade.tradingview.com/pine-facade/get/PUB;<mã>/last` (giữ nguyên dấu `;`, không mã hóa). Không đăng nhập.
- Lưu nguyên văn vào `docs\pine\tradingview\<nhóm>\<tên>.pine`, ghi `ket_qua_tai.csv` và mục lục `README.md` (tác giả, giấy phép, link).
- Chỉ báo khóa mã hoặc đã gỡ thì ghi trạng thái, không tải được. Thêm chỉ báo mới: thêm dòng vào CSV rồi chạy lại.

## `ScpSignalLab` + `SigVerify` — đo tín hiệu HTF-ZONE (SPEC mục 22–23)

EA chỉ chạy trong máy thử, **không có lệnh gửi**. Đợt 1: cản khung lớn M15–W1 (đỉnh/đáy râu, Classic A/V, Gap SnR, Doji SnR,
OB, FVG, đỉnh/đáy ngày-tuần trước, số tròn, cản tạm M5), kịch bản K1/K2/K5, vào thị trường sau phản ứng M1/M5.
Đợt 2: vùng Z của 411 (K2b) và Unicorn (K3) (SPEC 23.6); sức mạnh cản và phản ứng tại cản (SPEC 24);
vùng H4/D1/W1 tinh chỉnh xuống khung nhỏ, tuổi cản theo thời gian (SPEC 24.5).
Mỗi tín hiệu được theo dõi trên tick thật và so với đánh ngược, vào ngẫu nhiên cùng giờ 1–10 ngày sau, và cản giả.

```
powershell -NoProfile -ExecutionPolicy Bypass -Command "& '.\scripts\build.ps1' -Target 'Experts\BotVang\ScpSignalLab.mq5','Scripts\BotVang\SigVerify.mq5'"
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run-script.ps1 -Script BotVang\SigVerify -Period M1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run-tester.ps1 -Expert BotVang\ScpSignalLab.ex5 -SetFile lab\siglab_2026h1.set -Symbol XAUUSDm -Period M1 -From 2026.01.05 -To 2026.07.01
```

- `SigVerify`: log phải có `[SIG_VERIFY] TOTAL 58 | PASS 58 | FAIL 0` (đã chạy đạt 29/09 trên MT5 build 6231).
- Có thêm "lệnh chờ trên giấy" tại mốc chạm (nhóm `CHO_GIAY` trong báo cáo): khớp khi Bid tới đúng mốc, không chờ phản ứng;
  chỉ để so với cách vào của bot, bot không dùng lệnh chờ (SPEC 23.1). Lệnh chờ hết khi lần chạm kết thúc.
- Cần lịch tin `Common\Files\BotVang\news_usd.csv` (chạy `ExportNews` trước); thiếu lịch thì tín hiệu ghi `tin=thieu_lich`.
- Mỗi lượt cần `InpRunName` mới (hồ sơ 1 tuần `siglab_2026h1_v7`, hồ sơ đủ 01–06 `siglab_2026h1_full_v6`); tên đã có thì công cụ dừng và không ghi gì.
- Lượt đủ 01–06: dùng hồ sơ riêng `lab\siglab_2026h1_full.set` (`-From 2026.01.05 -To 2026.07.01`). Lượt 1 tuần trên máy chủ bot (i7-1355U) mất 2 phút 48 giây.
- Nên chạy thử 1 tuần trước (`-From 2026.01.05 -To 2026.01.12`) để đo thời gian, rồi mới chạy 01–06.
  **Không chạy 07–09 cho tới khi chốt tối đa 3 tổ hợp** (SPEC 23.5).
- Kết quả `Common\Files\BotScp\SignalLab\<InpRunName>\`:
  `tong_ket.txt` (mỗi biến thể một dòng), `nhom.csv` (mọi nhóm × cách tính), `tin_hieu.csv` (từng bản ghi thật/đối chứng;
  chỉ ghi khi `InpWriteSignals=true`, ~80 MB mỗi tuần — hồ sơ 1 tuần bật, hồ sơ 01–06 tắt),
  `phan_ung_can.csv` (SPEC 24.3: giá bật bao xa tại cản theo từng đặc điểm sức mạnh, so cản giả; `cham_can.csv` từng lần chạm khi bật `InpWriteSignals`),
  `vung_htf.csv` (sổ cản: khung, loại, biên, lúc biết, lúc hết và lý do). Từ chối tên lượt đã có.
- Chạy máy thử có hình (`-Visual`) thì vẽ cản theo màu khung (M15 xanh nhạt → W1 tím; nét đứt = cản đã đổi vai) và mũi tên tín hiệu.
- R tính sau spread (mua thoát Bid, bán thoát Ask) và trừ `InpSlipPerLeg`×2. Khoảng ±95% coi các bản ghi độc lập nên hẹp hơn thật.
  Đây là số đo trên giấy, chồng lấn nhau, không phải tiền của một EA.

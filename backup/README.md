# Backup — bot cũ và code cũ

Chuyển vào đây ngày 30/09/2026 theo yêu cầu chủ bot. Không nằm trong bản build hiện tại; giữ lại để tham khảo hoặc khôi phục.
Cấu trúc thư mục bên trong giống thư mục gốc dự án (`backup/mql5/...` ứng với `mql5/...`).

Muốn dùng lại một bot: chép bot đó cùng các file `.mqh` nó include về đúng chỗ cũ, rồi biên dịch bằng `scripts/build.ps1`.

## Bot và công cụ đã chuyển

| Nhóm | File chính | Công cụ / tham số đi kèm |
|---|---|---|
| BotVang (bot gốc) | `mql5/Experts/BotVang/BotVang.mq5`, `Engine`, `Exec`, `Filters`, `Bias`, `Panel`, `State`, `Journal`, `Types`, `Signal`, `Zones`, `Stats`, `MarketSim` | `lab/bot_*.set` |
| BotVangLab (đo điểm vào) | `BotVangLab.mq5`, `Lab*.mqh`, `LabVerify.mq5` | `lab/goc*.set`, `lab/btc_goc*.set`, `lab/eth_goc*.set`, `scripts/compare-bot-lab.ps1` |
| BotLuoi (lưới) | `BotLuoi.mq5`, `Grid.mqh` | `scripts/run-luoi.ps1` |
| SmcLab | `SmcLab.mq5`, `Smc*.mqh`, `docs/pine/BotVang_SMC.pine` | `lab/smc_vang.set`, `scripts/run-smclab.ps1` |
| PhanUngLab | `PhanUngLab.mq5`, `HtfZones.mqh` | `lab/pu_vang.set`, `lab/pus_vang.set`, `scripts/run-phanung*.ps1` |
| ThuChotSat | `ThuChotSat.mq5` | `lab/chotsat_*.set` |
| BotScalpPhanUng | `BotScalpPhanUng.mq5`, `Scalp*.mqh`, `ScalpVerify.mq5`, `ScalpDiagnose.mq5` | `lab/scalp_*.set`, `scripts/run-scalp.ps1`, `check-scalp.ps1`, `research-scalp.mjs`, `diagnose-scalp.mjs`, `docs/reports/scalp-*` |
| BotFvgNhanChim (demo) | `BotFvgNhanChim.mq5`, `FvgNc*.mqh` | `lab/fvgnc_on.set`, `scripts/compare-bot-fvgnc.ps1` |

Hướng dẫn cũ của các công cụ trên: `backup/scripts/TOOLS-cu.md`.

## Còn dùng ở thư mục gốc

Bot `BotScpMtf`, bộ đo `ScpSignalLab`, các ca kiểm `ScpVerify`, `SigVerify`, `ScpExecVerify`, `ScpPriceManageVerify`,
`ExportBars`, `ExportNews` cùng các file `Scp*.mqh`, `Sig*.mqh`. Luật: `docs/SPEC.md`; trạng thái: `docs/HANDOFF.md`.

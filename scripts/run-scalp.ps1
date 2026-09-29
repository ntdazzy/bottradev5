# Chạy 4 chế độ scalping M1 §26 bằng EA thật trong máy thử, dùng công cụ MT5 sẵn có.
param(
    [string]$From = '2026.01.05',
    [string]$To = '2026.09.26',
    [ValidateSet('auto','market','limit','passive')][string[]]$Modes = @('auto','market','limit','passive'),
    [ValidateSet('M1')][string[]]$Periods = @('M1'),
    [int]$DelayMs = 0,
    [string]$LogDir = (Join-Path $env:TEMP 'botscalp-runs')
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
Push-Location $root
try {
    foreach ($mode in $Modes) {
        foreach ($tf in $Periods) {
            $log = Join-Path $LogDir ("scalp_v3_{0}_{1}_d{2}.txt" -f $mode, $tf, $DelayMs)
            $output = Join-Path $env:APPDATA "MetaQuotes\Terminal\Common\Files\BotScalpPhanUng\scalp_v3_${mode}_XAUUSDm_${tf}\tong_ket.txt"
            $started = Get-Date
            & powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run-tester.ps1 `
                -Expert BotVang\BotScalpPhanUng.ex5 -SetFile "lab\scalp_$mode.set" -Symbol XAUUSDm `
                -Period $tf -From $From -To $To -Deposit 10000 -DelayMs $DelayMs -TimeoutMin 45 *> $log
            if ($LASTEXITCODE -ne 0) { throw "Máy thử lỗi: $mode $tf; xem $log" }
            if (-not (Test-Path -LiteralPath $output) -or (Get-Item -LiteralPath $output).LastWriteTime -lt $started) {
                throw "Không có tổng kết mới: $mode $tf; xem $log"
            }
            $summary = Get-Content -LiteralPath $output -Raw -Encoding UTF8
            if ($summary -notmatch 'Tu kiem tra loi 0;') { throw "Tự kiểm tra không đạt: $output" }
            Write-Output $summary
            Write-Output "Xong $mode $tf; nhật ký: $log"
        }
    }
} finally { Pop-Location }

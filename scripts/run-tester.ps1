# Chạy Strategy Tester của MT5 chính bằng dòng lệnh, in log của lần chạy, rồi mở lại MT5 như trước.
# Ví dụ:
#   powershell -ExecutionPolicy Bypass -File scripts\run-tester.ps1 -Expert BotVang\BotVangLab.ex5 -SetFile lab\base.set
param(
    [Parameter(Mandatory = $true)][string]$Expert,
    [string]$SetFile = '',
    [string]$From = '2026.01.01',
    [string]$To = '2026.09.26',
    [string]$Symbol = 'XAUUSDm',
    [string]$Period = 'M5',
    [int]$Model = 4,                 # 4 = mọi tick theo tick thật
    [int]$Deposit = 10000,
    [int]$DelayMs = 0,               # độ trễ khớp lệnh cố định (ms) để thử chịu trượt giá (§17 bước 4); 0 = không trễ
    [switch]$Visual,
    [int]$TimeoutMin = 180
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'mt5-main.ps1')

$setLine = ''
if ($SetFile) {
    # File tham số phải nằm trong MQL5\Profiles\Tester của thư mục dữ liệu.
    $profiles = Join-Path $Mt5Data 'MQL5\Profiles\Tester'
    New-Item -ItemType Directory -Force $profiles | Out-Null
    $setName = Split-Path $SetFile -Leaf
    $text = [System.IO.File]::ReadAllText((Resolve-Path $SetFile).Path, (New-Object System.Text.UTF8Encoding($false)))
    [System.IO.File]::WriteAllText((Join-Path $profiles $setName), $text, $Mt5Utf16)
    $setLine = "ExpertParameters=$setName`r`n"
}
$iniText = @"
[Tester]
Expert=$Expert
$($setLine)Symbol=$Symbol
Period=$Period
Model=$Model
FromDate=$From
ToDate=$To
Deposit=$Deposit
Currency=USD
Leverage=1:200
ExecutionMode=$DelayMs
Optimization=0
Visual=$([int][bool]$Visual)
ShutdownTerminal=1
"@

$agentLog = Join-Path $env:APPDATA ("MetaQuotes\Tester\" + (Split-Path $Mt5Data -Leaf) + "\Agent-127.0.0.1-3000\logs\" + (Get-Date -Format 'yyyyMMdd') + '.log')
$logStart = if (Test-Path $agentLog) { (Get-Item $agentLog).Length } else { 0 }

$was = Stop-MainTerminal
$done = Invoke-MainTerminal $iniText $TimeoutMin
if (-not $done) { Write-Host 'QUÁ GIỜ: MT5 vẫn đang chạy tester, không mở lại MT5.' }

if (Test-Path $agentLog) {
    # Chỉ in phần log của lần chạy này.
    $bytes = [System.IO.File]::ReadAllBytes($agentLog)
    $skip = [Math]::Min($logStart, $bytes.Length)
    if ($skip % 2 -eq 1) { $skip-- }
    [System.Text.Encoding]::Unicode.GetString($bytes, $skip, $bytes.Length - $skip) -split "`r?`n" |
        Where-Object { $_ -match '\S' } | Select-Object -Last 60 | ForEach-Object { Write-Host $_ }
} else { Write-Host "Không thấy log của agent: $agentLog" }

if ($was -and $done) { Start-MainTerminal }
if (-not $done) { exit 2 }

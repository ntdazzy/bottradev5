# Chạy một script MQL5 trên MT5 chính (đang kết nối sàn), in log của script, rồi mở lại MT5 như trước.
# Script phải có input InpCloseTerminal (script tự đóng MT5 khi xong). Cần build trước bằng scripts\build.ps1.
# Ví dụ:
#   powershell -ExecutionPolicy Bypass -File scripts\run-script.ps1 -Script BotVang\ExportNews
#   powershell -ExecutionPolicy Bypass -File scripts\run-script.ps1 -Script BotVang\LabVerify -Params 'InpRun=goc_KHAMPHA_s1_1234abcd;InpMax=1000'
param(
    [Parameter(Mandatory = $true)][string]$Script,
    [string]$Params = '',            # các cặp Ten=giatri, ngăn nhau bằng dấu ;
    [ValidateSet('M1','M5')][string]$Period = 'M5',
    [int]$TimeoutMin = 10
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'mt5-main.ps1')

$presets = Join-Path $Mt5Data 'MQL5\Presets'
New-Item -ItemType Directory -Force $presets | Out-Null
$preset = 'botvang_' + ($Script -replace '[\\/]', '_') + '.set'
[System.IO.File]::WriteAllText((Join-Path $presets $preset), ((@('InpCloseTerminal=true') + ($Params -split ';' | Where-Object { $_ -match '=' })) -join "`r`n") + "`r`n", $Mt5Utf16)
$iniText = @"
[StartUp]
Script=$Script
ScriptParameters=$preset
Symbol=XAUUSDm
Period=$Period
"@

$log = Join-Path $Mt5Data ("MQL5\Logs\" + (Get-Date -Format 'yyyyMMdd') + '.log')
$logStart = if (Test-Path $log) { (Get-Item $log).Length } else { 0 }
$was = Stop-MainTerminal
$done = Invoke-MainTerminal $iniText $TimeoutMin
if (Test-Path $log) {
    $bytes = [System.IO.File]::ReadAllBytes($log)
    $skip = [Math]::Min($logStart, $bytes.Length)
    if ($skip % 2 -eq 1) { $skip-- }
    [System.Text.Encoding]::Unicode.GetString($bytes, $skip, $bytes.Length - $skip) -split "`r?`n" |
        Where-Object { $_ -match '\S' } | Select-Object -Last 40 | ForEach-Object { Write-Host $_ }
}
if (-not $done) { Write-Host "MT5 chưa tự đóng sau $TimeoutMin phút - kiểm tra cửa sổ MT5."; exit 2 }
if ($was) { Start-MainTerminal }

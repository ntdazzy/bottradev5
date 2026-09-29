# Chạy BotLuoi (SPEC §19) 9 tháng cho vàng, BTC, ETH: bản đúng luật, bản "cho chạy lại sau mỗi lần dừng hẳn",
# và bản "cho chạy lại" với độ trễ 100/250/500 ms. Tạo file cài đặt lab\luoi_<ký hiệu>_<lần chạy>.set.
# Kết quả mỗi lần: %APPDATA%\MetaQuotes\Terminal\Common\Files\BotLuoi\<lần chạy>_<ký hiệu>\tong_ket.txt, ro.csv
param([string]$LogDir = "$env:TEMP\botluoi-runs")
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$root = Split-Path -Parent $PSScriptRoot
$enc = New-Object System.Text.UTF8Encoding($false)
New-Item -ItemType Directory -Force $LogDir | Out-Null
Set-Location $root
$syms = @(@('vang', 'XAUUSDm', '0.01', '0.4'), @('btc', 'BTCUSDm', '0.01', '20'), @('eth', 'ETHUSDm', '0.1', '1.8'))
$runs = @(@('goc', 'false', 0), @('chaylai', 'true', 0), @('chaylai_d100', 'true', 100), @('chaylai_d250', 'true', 250), @('chaylai_d500', 'true', 500))
foreach($r in $runs)
  {
   foreach($x in $syms)
     {
      $set = "lab\luoi_$($x[0])_$($r[0]).set"
      [IO.File]::WriteAllText((Join-Path $root $set), "InpRunName=$($r[0])`r`nInpLot=$($x[2])`r`nInpStep=$($x[3])`r`nInpRestartAfterStop=$($r[1])`r`n", $enc)
      powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run-tester.ps1 -Expert BotVang\BotLuoi.ex5 -SetFile $set -Symbol $x[1] -From 2026.01.05 -To 2026.09.26 -Deposit 5000 -DelayMs $r[2] -TimeoutMin 40 *> "$LogDir\luoi_$($x[0])_$($r[0]).txt"
      "xong $($x[0]) $($r[0]): exit $LASTEXITCODE"
      Start-Sleep -Seconds 20
     }
  }
"TAT CA XONG"

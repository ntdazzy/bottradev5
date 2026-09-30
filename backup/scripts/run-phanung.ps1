# Chạy PhanUngLab (SPEC §22, vào lệnh khi có phản ứng ở vùng) cho vàng, BTC, ETH × khung M1, M5 × chốt lời 1R, 1,5R, 2R trên tick thật 05/01–26/09/2026.
# Kết quả mỗi lần: %APPDATA%\MetaQuotes\Terminal\Common\Files\PhanUngLab\<tên>_tp<mức>_<ký hiệu>_<khung>\tong_ket.txt, lenh.csv
param([string]$RunName = "pu", [string]$LogDir = "$env:TEMP\phanung-runs")
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$root = Split-Path -Parent $PSScriptRoot
$enc = New-Object System.Text.UTF8Encoding($false)
New-Item -ItemType Directory -Force $LogDir | Out-Null
Set-Location $root
# đệm trượt theo giá của từng ký hiệu (SPEC §16.8 "Ngưỡng theo giá")
$syms = @(@('vang', 'XAUUSDm', '0.5'), @('btc', 'BTCUSDm', '25'), @('eth', 'ETHUSDm', '2.3'))
foreach($tp in @(@('1', '1.0'), @('15', '1.5'), @('2', '2.0')))
  {
   foreach($tf in 'M1', 'M5')
     {
      foreach($x in $syms)
        {
         $name = "$($RunName)_tp$($tp[0])"
         $set = "lab\pu_$($x[0]).set"
         [IO.File]::WriteAllText((Join-Path $root $set), "InpRunName=$name`r`nInpSlip=$($x[2])`r`nInpTpR=$($tp[1])`r`n", $enc)
         powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run-tester.ps1 -Expert BotVang\PhanUngLab.ex5 -SetFile $set -Symbol $x[1] -Period $tf -From 2026.01.05 -To 2026.09.26 -TimeoutMin 60 *> "$LogDir\$($name)_$($x[0])_$tf.txt"
         "xong $name $($x[0]) $tf : exit $LASTEXITCODE"
         Start-Sleep -Seconds 20
        }
     }
  }
"TAT CA XONG"

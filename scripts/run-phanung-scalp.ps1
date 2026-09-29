# Chạy PhanUngLab lần đo 4 (SPEC §24, scalping theo phản ứng): vàng XAUUSDm × khung M1, M5 × TP1 1, 2, 3, 5 giá, "tùy lực" × ăn thêm 0 / 10 giá,
# dừng lỗ sau râu nến phản ứng (InpSlMode=1), tick thật 05/01–26/09/2026, đệm trượt 0,5 giá (20 lần). Thêm -Slip0: cùng 20 lần với đệm trượt 0, tên pus0_...
# Thêm -Htf: bật cản khung lớn M15/H1/H4/D1 (SPEC §25, InpHtf=true), tên lần chạy thêm chữ h ở đầu (hpus_..., hpus0_...); nhóm A giữ nguyên.
# Kết quả mỗi lần: %APPDATA%\MetaQuotes\Terminal\Common\Files\PhanUngLab\<pus|pus0|hpus|hpus0>_tp<1|2|3|5|luc>_r<0|10>_XAUUSDm_<khung>\tong_ket.txt, lenh.csv
param([switch]$Slip0, [switch]$Htf, [string]$LogDir = "$env:TEMP\phanung-runs")
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$root = Split-Path -Parent $PSScriptRoot
$enc = New-Object System.Text.UTF8Encoding($false)
New-Item -ItemType Directory -Force $LogDir | Out-Null
Set-Location $root
$prefix = if ($Slip0) { 'pus0' } else { 'pus' }
if ($Htf) { $prefix = 'h' + $prefix }
$htfLine = if ($Htf) { "InpHtf=true`r`n" } else { '' }
$slip = if ($Slip0) { '0' } else { '0.5' }
$set = 'lab\pus_vang.set'
# TP1: tên trong tên lần chạy, giá trị InpTp1Price (−1 = "tùy lực")
foreach($tp in @(@('1', '1'), @('2', '2'), @('3', '3'), @('5', '5'), @('luc', '-1')))
  {
   foreach($runner in '0', '10')
     {
      foreach($tf in 'M1', 'M5')
        {
         $name = "$($prefix)_tp$($tp[0])_r$runner"
         [IO.File]::WriteAllText((Join-Path $root $set), "InpRunName=$name`r`nInpSlip=$slip`r`nInpSlMode=1`r`nInpTp1Price=$($tp[1])`r`nInpRunnerPrice=$runner`r`n$htfLine", $enc)
         powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run-tester.ps1 -Expert BotVang\PhanUngLab.ex5 -SetFile $set -Symbol XAUUSDm -Period $tf -From 2026.01.05 -To 2026.09.26 -TimeoutMin 60 *> "$LogDir\$($name)_vang_$tf.txt"
         "xong $name $tf : exit $LASTEXITCODE"
         Start-Sleep -Seconds 20
        }
     }
  }
"TAT CA XONG"

# So từng lệnh của BotFvgNhanChim trong Strategy Tester (nhật ký Common\Files\BotFvgNhanChim\tester_XAUUSDm.csv) với lệnh thật của
# PhanUngLab ô "FVG R2 nhan chim" (lenh.csv của lần đo pu_tp2_XAUUSDm_M5, cột kieu = 0) — SPEC §23.3.
# Ghép theo lúc đóng nến phản ứng (bot: nen_tin_hieu + 5 phút; Lab: pu_dong) + chiều. In số khớp / chỉ bot / chỉ Lab; chênh lệch lớn
# nhất giá vào, SL, TP (theo giá); lý do đóng giống nhau; tổng và trung bình R (chưa trừ phí) của hai bên; danh sách các lệnh lệch.
# Ví dụ:
#   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\compare-bot-fvgnc.ps1 -Out $env:TEMP\so_fvgnc.txt
param(
   [string]$Bot = (Join-Path $env:APPDATA 'MetaQuotes\Terminal\Common\Files\BotFvgNhanChim\tester_XAUUSDm.csv'),
   [string]$Lab = (Join-Path $env:APPDATA 'MetaQuotes\Terminal\Common\Files\PhanUngLab\pu_tp2_XAUUSDm_M5\lenh.csv'),
   [string]$Cell = 'FVG R2 nhan chim',
   [string]$Out = '',          # thêm: ghi kết quả ra file (UTF-8)
   [int]$List = 40,            # số dòng tối đa mỗi danh sách lệch
   [int]$BarMinutes = 5
)
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$inv = [Globalization.CultureInfo]::InvariantCulture
$eps = 0.0005   # giá vàng có 3 chữ số: nhỏ hơn mức này coi là bằng nhau

function Num([string]$s) { if ($s -eq '') { return [double]::NaN } return [double]::Parse($s, $inv) }
function F([double]$v, [int]$d = 3) { if ([double]::IsNaN($v)) { return '-' } return $v.ToString('F' + $d, $inv) }

# Lệnh thật của ô trong Lab: dòng 1 là chú thích, dòng 2 là tiêu đề
$labRows = @{}
$prefix = ";$Cell;0;"
foreach ($line in [IO.File]::ReadLines($Lab)) {
   if ($line.IndexOf($prefix) -lt 0) { continue }
   $f = $line.Split(';')
   if ($f[1] -ne $Cell -or $f[2] -ne '0') { continue }
   $key = $f[4] + ' ' + $f[3]
   $labRows[$key] = [pscustomobject]@{ key = $key; pu = $f[4]; dir = [int]$f[3]; fillT = $f[5]; exitT = $f[6]; entry = (Num $f[7]); sl = (Num $f[8])
                                       tp = (Num $f[9]); why = [int]$f[10]; r = (Num $f[11]) }
}

# Lệnh của bot: bỏ dòng chú thích (#) và dòng tiêu đề
$botRows = @{}
$dupBot = 0
foreach ($line in [IO.File]::ReadLines($Bot)) {
   if ($line.StartsWith('#') -or $line.StartsWith('ma_lenh') -or $line.Trim() -eq '') { continue }
   $f = $line.Split(';')
   $pu = ''
   if ($f[1] -ne '') { $pu = [datetime]::ParseExact($f[1], 'yyyy.MM.dd HH:mm', $inv).AddMinutes($BarMinutes).ToString('yyyy.MM.dd HH:mm:ss', $inv) }
   $key = $pu + ' ' + $f[2]
   if ($botRows.ContainsKey($key)) { $dupBot++; $key = $key + ' #' + $f[0] }
   $botRows[$key] = [pscustomobject]@{ key = $key; id = $f[0]; pu = $pu; dir = [int]$f[2]; want = (Num $f[6]); sl = (Num $f[7]); tp = (Num $f[8])
                                       fillT = $f[9]; fill = (Num $f[10]); exitT = $f[11]; exit = (Num $f[12]); why = [int]$f[13]; r = (Num $f[15]) }
}

$matched = @(); $onlyLab = @(); $onlyBot = @()
foreach ($k in ($labRows.Keys | Sort-Object)) { if ($botRows.ContainsKey($k)) { $matched += , @($labRows[$k], $botRows[$k]) } else { $onlyLab += $labRows[$k] } }
foreach ($k in ($botRows.Keys | Sort-Object)) { if (-not $labRows.ContainsKey($k)) { $onlyBot += $botRows[$k] } }

# Lệnh ghép: chênh lệch giá, lý do đóng, R
$maxWant = 0.0; $maxFill = 0.0; $maxSl = 0.0; $maxTp = 0.0; $maxR = 0.0
$sameWant = 0; $sameSl = 0; $sameTp = 0; $sameSec = 0; $sameWhy = 0
$whyPairs = @{}; $diffRows = @()
$pairLab = 0.0; $pairBot = 0.0; $pairN = 0
foreach ($m in $matched) {
   $l = $m[0]; $b = $m[1]
   $dWant = [math]::Abs($b.want - $l.entry); $dFill = [math]::Abs($b.fill - $l.entry)
   $dSl = [math]::Abs($b.sl - $l.sl); $dTp = [math]::Abs($b.tp - $l.tp)
   $maxWant = [math]::Max($maxWant, $dWant); $maxFill = [math]::Max($maxFill, $dFill); $maxSl = [math]::Max($maxSl, $dSl); $maxTp = [math]::Max($maxTp, $dTp)
   if ($dWant -lt $eps) { $sameWant++ }
   if ($dSl -lt $eps) { $sameSl++ }
   if ($dTp -lt $eps) { $sameTp++ }
   if ($b.fillT -eq $l.fillT) { $sameSec++ }
   if ($b.why -eq $l.why) { $sameWhy++ } else { $p = "Lab $($l.why) / bot $($b.why)"; $whyPairs[$p] = 1 + [int]$whyPairs[$p] }
   if (-not [double]::IsNaN($l.r) -and -not [double]::IsNaN($b.r) -and $l.why -ne 4 -and $b.why -ne 4) {
      $pairLab += $l.r; $pairBot += $b.r; $pairN++
      $maxR = [math]::Max($maxR, [math]::Abs($b.r - $l.r))
   }
   if ($dFill -ge $eps -or $dSl -ge $eps -or $dTp -ge $eps -or $b.why -ne $l.why -or $b.fillT -ne $l.fillT) {
      $diffRows += [string]::Format($inv, '{0} {1,2} | Lab khớp {2} vào {3} SL {4} TP {5} đóng {6} lý do {7} R {8} | bot khớp {9} gửi {10} khớp {11} SL {12} TP {13} đóng {14} lý do {15} R {16}',
         $l.pu, $l.dir, $l.fillT, (F $l.entry), (F $l.sl), (F $l.tp), $l.exitT, $l.why, (F $l.r), $b.fillT, (F $b.want), (F $b.fill), (F $b.sl), (F $b.tp), $b.exitT, $b.why, (F $b.r))
   }
}

function Stat($rows) {
   $done = @($rows | Where-Object { $_.why -ne 4 -and -not [double]::IsNaN($_.r) })
   $sum = 0.0; foreach ($x in $done) { $sum += $x.r }
   $mean = $(if ($done.Count -gt 0) { $sum / $done.Count } else { [double]::NaN })
   return [string]::Format($inv, 'tổng {0} R, trung bình {1} R trên {2} lệnh đã xong', (F $sum), (F $mean), $done.Count)
}

$nM = $matched.Count
$lines = @()
$lines += "Lab: $Lab"
$lines += "Bot: $Bot"
$lines += "Ô '$Cell' (lệnh thật): Lab $($labRows.Count) lệnh, bot $($botRows.Count) lệnh$(if ($dupBot -gt 0) { " (bot có $dupBot lệnh trùng nến + chiều)" })"
$lines += "Ghép được (cùng lúc đóng nến phản ứng + chiều): $nM; chỉ bot: $($onlyBot.Count); chỉ Lab: $($onlyLab.Count)"
$lines += [string]::Format($inv, 'Lệnh ghép: giá lúc gửi = giá vào Lab {0}/{1} (lệch lớn nhất {2}); giá khớp lệch lớn nhất {3}; khớp cùng giây {4}/{1}', $sameWant, $nM, (F $maxWant), (F $maxFill), $sameSec)
$lines += [string]::Format($inv, 'Lệnh ghép: SL giống {0}/{1} (lệch lớn nhất {2}); TP giống {3}/{1} (lệch lớn nhất {4})', $sameSl, $nM, (F $maxSl), $sameTp, (F $maxTp))
$lines += "Lệnh ghép: lý do đóng giống nhau $sameWhy/$nM (1 chốt lời, 2 dừng lỗ, 3 giữ đủ 500 nến, 4 còn mở lúc hết dữ liệu, 5 giới hạn lỗ, 6 khác)$(if ($whyPairs.Count -gt 0) { '; khác: ' + (($whyPairs.Keys | Sort-Object | ForEach-Object { "$_ : $($whyPairs[$_])" }) -join ', ') })"
$lines += "R chưa trừ phí — Lab (R0): $(Stat $labRows.Values)"
$lines += "R chưa trừ phí — bot: $(Stat $botRows.Values)"
$lines += [string]::Format($inv, 'R trên {0} lệnh ghép cả hai đã xong: Lab tổng {1}, bot tổng {2}, lệch R lớn nhất một lệnh {3}', $pairN, (F $pairLab), (F $pairBot), (F $maxR))
if ($onlyLab.Count -gt 0) {
   $lines += "--- Chỉ Lab có ($($onlyLab.Count), in tối đa $List): lúc đóng nến phản ứng, chiều, giá vào, SL, TP, lý do, R"
   $lines += $onlyLab | Select-Object -First $List | ForEach-Object { [string]::Format($inv, '{0} {1,2} vào {2} SL {3} TP {4} lý do {5} R {6}', $_.pu, $_.dir, (F $_.entry), (F $_.sl), (F $_.tp), $_.why, (F $_.r)) }
}
if ($onlyBot.Count -gt 0) {
   $lines += "--- Chỉ bot có ($($onlyBot.Count), in tối đa $List)"
   $lines += $onlyBot | Select-Object -First $List | ForEach-Object { [string]::Format($inv, '{0} {1,2} #{2} khớp {3} {4} SL {5} TP {6} lý do {7} R {8}', $_.pu, $_.dir, $_.id, $_.fillT, (F $_.fill), (F $_.sl), (F $_.tp), $_.why, (F $_.r)) }
}
if ($diffRows.Count -gt 0) {
   $lines += "--- Lệnh ghép có chênh lệch (giá khớp, SL, TP, giây khớp hoặc lý do đóng) ($($diffRows.Count), in tối đa $List)"
   $lines += $diffRows | Select-Object -First $List
}
if ($Out -ne '') { [IO.File]::WriteAllLines($Out, [string[]]$lines, (New-Object Text.UTF8Encoding($true))) }
$lines

# Kiểm chứng độc lập sổ deal/lệnh/quyết định do BotScalpPhanUng xuất, không mô phỏng lại giá.
param(
    [Parameter(Mandatory = $true)][string]$Run,
    [string]$BaseDir = (Join-Path $env:APPDATA 'MetaQuotes\Terminal\Common\Files\BotScalpPhanUng')
)
$ErrorActionPreference = 'Stop'
$inv = [Globalization.CultureInfo]::InvariantCulture
$folder = Join-Path $BaseDir $Run
function Number([string]$text) { return [double]::Parse($text, $inv) }
function Date([string]$text) { return [datetime]::ParseExact($text, 'yyyy.MM.dd HH:mm:ss', $inv) }
$trades = @(Import-Csv -LiteralPath (Join-Path $folder 'lenh.csv') -Delimiter ';' -Encoding UTF8)
$deals = @(Import-Csv -LiteralPath (Join-Path $folder 'deals.csv') -Delimiter ';' -Encoding UTF8)
$events = @(Import-Csv -LiteralPath (Join-Path $folder 'quyet_dinh.csv') -Delimiter ';' -Encoding UTF8)
$summary = Get-Content -LiteralPath (Join-Path $folder 'tong_ket.txt') -Raw -Encoding UTF8
if ($summary -notmatch 'Tu kiem tra loi 0;') { throw 'EA báo tự kiểm tra không đạt.' }
if ($summary -match 'loi gui (\d+)' -and [int]$Matches[1] -gt 0) { throw "Có $($Matches[1]) lỗi gửi lệnh; phải đọc quyet_dinh.csv trước khi chấp nhận lần đo." }
$rules = 1
if ($summary -match 'rules=(\d+)') { $rules = [int]$Matches[1] }
$fastRules = $rules -ge 2
$entryFrame = if ($rules -ge 3) { 'M1' } else { 'M15' }
$holdLimit = 0.0
if ($fastRules -and $summary -match 'max_minutes=([\d.]+)') { $holdLimit = Number $Matches[1] }
$dealSums = @{}
$dealIds = @{}
foreach ($d in $deals) {
    if ($dealIds.ContainsKey($d.deal)) { throw "Deal bị ghi trùng: $($d.deal)" }
    $dealIds[$d.deal] = $true
    $value = (Number $d.loi) + (Number $d.hoa_hong) + (Number $d.phi) + (Number $d.qua_dem)
    $dealSums[$d.lenh] = [double]$dealSums[$d.lenh] + $value
}
$total = 0.0
$lastClose = [datetime]::MinValue
foreach ($t in ($trades | Sort-Object mo)) {
    if (-not $dealSums.ContainsKey($t.lenh)) { throw "Lệnh thiếu deal: $($t.lenh)" }
    if ([math]::Abs($dealSums[$t.lenh] - (Number $t.tien)) -gt 0.021) { throw "Cộng tiền lệch ở lệnh $($t.lenh)" }
    if ((Date $t.mo) -lt $lastClose) { throw "Lệnh chồng nhau: $($t.lenh)" }
    if ($t.da_xong -eq '1') {
        $lastClose = Date $t.dong
        $total += Number $t.tien
        $elapsed = ($lastClose - (Date $t.mo)).TotalMinutes
        if ($elapsed -lt 0.0 -or [math]::Abs($elapsed - (Number $t.phut)) -gt 0.011) { throw 'Thời gian giữ không khớp giờ mở/đóng.' }
        if ($fastRules -and $elapsed -gt $holdLimit + 0.2) { throw "Lệnh giữ quá giới hạn đánh ngắn: $($t.lenh)" }
    }
    if ((Number $t.tru_them_truot) -gt (Number $t.tien) + 0.001) { throw 'Trừ chi phí lại làm tăng tiền.' }
}
if ($summary -match 'Tien sau phi san ([-+\d.]+);') {
    if ([math]::Abs($total - (Number $Matches[1])) -gt 0.021) { throw 'Tổng sổ lệnh lệch tổng kết.' }
} else { throw 'Tổng kết thiếu số tiền.' }
$direction = 0
$lastSl = 0.0
$target = 0.0
$modifications = 0
$plans = 0
$visits = @{}
foreach ($e in $events) {
    if ($e.su_kien -eq 'ke_hoach') {
        if ($e.chi_tiet -notmatch 'ty le ([\d.]+)') { throw 'Kế hoạch thiếu tỷ lệ.' }
        $ratio = Number $Matches[1]
        if ($summary -match 'min_ratio=([\d.]+)' -and $ratio + 0.001 -lt (Number $Matches[1])) { throw 'Gửi kế hoạch dưới tỷ lệ tối thiểu.' }
        $plans++
        if ($fastRules) {
            if ($e.chi_tiet -notmatch '^(MUA|BAN) .+?vao ([\d.]+), dung ([\d.]+)') { throw 'Thiếu giá vào/dừng trong kế hoạch M1.' }
            $side = if ($Matches[1] -eq 'MUA') { 1 } else { -1 }
            $risk = $side * ((Number $Matches[2]) - (Number $Matches[3]))
            if ($e.chi_tiet -notmatch 'H1 (-?\d+) H4 (-?\d+) D1 (-?\d+), ATR ([\d.]+)') { throw 'Thiếu hướng khung lớn/ATR.' }
            if ([int]$Matches[1] -ne $side) { throw 'Kế hoạch trái hướng H1.' }
            if ($risk -le 0.0 -or $risk -gt 3.0 * (Number $Matches[4]) + 0.002) { throw 'Khoảng dừng vượt giới hạn M1.' }
            if ($e.chi_tiet -notmatch ('vung ' + $entryFrame + ' #(\d+), cham ([\d.]+ [\d:]+), biet ([\d.]+ [\d:]+)')) { throw 'Thiếu vùng đúng khung/thời điểm biết.' }
            $visit = '{0}:{1}:{2}' -f $Matches[1], $side, $Matches[2]
            if ($visits.ContainsKey($visit)) { throw "Gửi trùng cùng lần chạm: $visit" }
            if ((Date $Matches[3]) -gt (Date $Matches[2]) -or (Date $Matches[2]) -gt (Date $e.luc)) { throw 'Dùng vùng/lần chạm trước lúc biết.' }
            $visits[$visit] = $true
        }
    }
    if ($e.su_kien -eq 'khop' -and $e.chi_tiet -match '^(MUA|BAN) gia ([\d.]+), dung ([\d.]+), chot ([\d.]+)') {
        $direction = if ($Matches[1] -eq 'MUA') { 1 } else { -1 }
        $lastSl = Number $Matches[3]
        $target = Number $Matches[4]
    }
    if ($e.su_kien -eq 'doi_dung') {
        if ($direction -eq 0 -or $e.chi_tiet -notmatch 'Dừng mới ([\d.]+), giữ chốt ([\d.]+)') { throw 'Dời dừng thiếu lệnh/mốc.' }
        $next = Number $Matches[1]
        $tp = Number $Matches[2]
        if ($direction * ($next - $lastSl) -le 0.0) { throw 'Dừng lỗ bị nới hoặc không đổi.' }
        if ([math]::Abs($tp - $target) -gt 0.001) { throw 'Dời dừng làm mất/đổi mục tiêu.' }
        $lastSl = $next
        $modifications++
    }
}
[pscustomobject]@{ Run=$Run; Trades=$trades.Count; Deals=$deals.Count; Plans=$plans; StopMoves=$modifications; NetMoney=[math]::Round($total,2); Result='PASS' }

# So từng lệnh của bot (log agent Strategy Tester) với lệnh Lab chọn cho bot (su_kien.csv, cột bot_chon = 1).
# Khớp khi cùng giờ vào, chiều, giá vào và bước B. In R của bot (lời/lỗ tiền ÷ B ÷ PerPrice) và R của Lab (R_gop, chưa trừ phí c).
# PerPrice = tiền lời/lỗ khi giá đi 1 = lot × contract (vàng 0.01 × 100 = 1; BTC 0.01 × 1 = 0.01; ETH 0.1 × 1 = 0.1).
param(
   [Parameter(Mandatory = $true)][string]$Log,   # bản sao log agent (UTF-16) của lần chạy bot
   [Parameter(Mandatory = $true)][string]$Csv,   # su_kien.csv của lần Lab KIEMTRA cùng ký hiệu
   [Parameter(Mandatory = $true)][string]$Out,   # file kết quả (UTF-8); thêm <Out>.json cho biểu đồ [thứ tự, R bot, R Lab]
   [double]$PerPrice = 1.0
)
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$lines = Get-Content $Log -Encoding Unicode
$start = 0
for($i = $lines.Count - 1; $i -ge 0; $i--) { if($lines[$i] -match '\[BotVang\] khoi_dong \| BotVang v2') { $start = $i; break } }
$bot = @()
$cur = $null
for($i = $start; $i -lt $lines.Count; $i++)
  {
   $l = $lines[$i]
   if($l -match '(\d{4}\.\d\d\.\d\d \d\d:\d\d):\d\d\s+\[BotVang\] vao_lenh \| (\S+) [\d.]+ gi\S+ ([\d.]+) d\S+ l\S+ ([\d.]+) b\S+ ([\d.]+)')
     {
      $cur = [pscustomobject]@{ t = $matches[1]; dir = $(if($matches[2] -eq 'MUA') { 1 } else { -1 }); entry = [double]$matches[3]; B = [double]$matches[5]; pnl = $null; how = '' }
      $bot += $cur
     }
   elseif($cur -ne $null -and $cur.pnl -eq $null -and $l -match '\[BotVang\] dong_lenh \| (.+?) ([+-]?[\d.]+) USD')
     {
      $cur.pnl = [double]$matches[2]
      $cur.how = $(if($matches[1] -match 'D\S+ d\S+ l') { 'dung_lo' } else { 'dong' })
     }
  }
$labRows = Import-Csv $Csv | Where-Object { $_.bot_chon -eq '1' }
$labByT = @{}
foreach($row in $labRows) { $labByT[$row.gio_cham_san] = $row }
$inv = [Globalization.CultureInfo]::InvariantCulture
$match = 0; $sumBot = 0.0; $sumLab = 0.0; $k = 0
$json = @()
$rows = foreach($b in $bot)
  {
   $k++
   $row = $labByT[$b.t]
   $ok = $row -ne $null -and [int]$row.chieu -eq $b.dir -and [math]::Abs([double]::Parse($row.gia_vao, $inv) - $b.entry) -lt 0.0015 -and [math]::Abs([double]::Parse($row.B, $inv) - $b.B) -lt 0.006
   if($ok) { $match++ }
   $rBot = $(if($b.pnl -ne $null) { $b.pnl / $b.B / $PerPrice } else { [double]::NaN })
   $rLab = $(if($row) { [double]::Parse($row.R_gop, $inv) } else { [double]::NaN })
   $sumBot += $rBot
   if($row) { $sumLab += $rLab }
   if($row -and $b.pnl -ne $null) { $json += [string]::Format($inv, '[{0},{1},{2}]', $k, [math]::Round($rBot, 3), [math]::Round($rLab, 3)) }
   [string]::Format($inv, '{0} {1,3} vao {2,10} B {3,7} | Lab {4,-8} | R bot {5,6:F2} | R Lab {6,6:F2} | {7}', $b.t, $b.dir, $b.entry, $b.B,
                    $(if($ok) { 'KHOP' } elseif($row) { 'LECH' } else { 'KHONG_CO' }), $rBot, $rLab, $b.how)
  }
$botT = $bot | ForEach-Object { $_.t }
$missing = $labByT.Keys | Where-Object { $botT -notcontains $_ } | Sort-Object
$summary = @("Bot: $($bot.Count) lệnh; Lab chọn: $($labRows.Count); khớp: $match",
             [string]::Format($inv, 'Tổng R bot {0:F2}; Lab (các lệnh có cặp, chưa trừ phí) {1:F2}', $sumBot, $sumLab),
             "Lab có mà bot không có: $($missing -join ', ')")
($rows + $summary) | Set-Content $Out -Encoding UTF8
'[' + ($json -join ',') + ']' | Set-Content "$Out.json" -Encoding ASCII
$summary

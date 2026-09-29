# Tải mã nguồn Pine công khai (open-source) từ TradingView về docs\pine\tradingview\<nhóm>\, giữ nguyên nguyên văn
# (kể cả dòng giấy phép của tác giả), rồi tạo mục lục README.md. Chỉ đọc trang công khai, không đăng nhập.
# Danh sách vào: CSV (dấu ;) có cột nhom, ten, tac_gia, url. Chỉ báo khóa mã / đã gỡ thì ghi lại, không tải được.
param(
   [string]$List = "",
   [string]$OutDir = "",
   [int]$DelaySec = 2
)
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$ProgressPreference = 'SilentlyContinue'
$root = Split-Path -Parent $PSScriptRoot
if($OutDir -eq "") { $OutDir = Join-Path $root "docs\pine\tradingview" }
if($List -eq "") { $List = Join-Path $OutDir "danh_sach.csv" }
$enc = New-Object System.Text.UTF8Encoding($false)
$headers = @{ 'User-Agent' = 'Mozilla/5.0'; 'Referer' = 'https://www.tradingview.com/' }

function Norm([string]$s) { return ([regex]::Replace($s.ToLower(), '[^a-z0-9]', '')) }
function SafeName([string]$s)
  {
   $n = [regex]::Replace($s, '[\\/:*?"<>|]', '')
   $n = [regex]::Replace($n, '\s+', ' ').Trim()
   if($n.Length -gt 80) { $n = $n.Substring(0, 80).Trim() }
   return $n
  }
function LicenseOf([string]$src)
  {
   $head = ($src -split "`n" | Select-Object -First 20) -join "`n"
   if($head -match 'Mozilla Public License') { return 'MPL 2.0' }
   if($head -match 'NonCommercial|NC-SA|BY-NC') { return 'CC BY-NC-SA 4.0 (không dùng thương mại)' }
   if($head -match 'GNU|GPL') { return 'GPL' }
   if($head -match 'MIT License') { return 'MIT' }
   return 'không ghi trong mã (theo quy định TradingView)'
  }

$rows = Import-Csv $List -Delimiter ';'
$out = @()
foreach($r in $rows)
  {
   $status = ''; $file = ''; $lic = ''; $ver = ''; $upd = ''
   try
     {
      $page = Invoke-WebRequest -Uri $r.url -UseBasicParsing -Headers $headers -TimeoutSec 60
      $title = ''
      if($page.Content -match '<title>([^<]+)</title>') { $title = [System.Net.WebUtility]::HtmlDecode($matches[1]) }
      $ids = [regex]::Matches($page.Content, 'PUB;[A-Za-z0-9]{20,40}') | ForEach-Object { $_.Value } | Select-Object -Unique
      $best = $null
      foreach($id in $ids)
        {
         Start-Sleep -Seconds $DelaySec
         try { $j = Invoke-RestMethod -Uri "https://pine-facade.tradingview.com/pine-facade/get/$id/last" -Headers $headers -TimeoutSec 60 } catch { continue }
         if(-not $j.source) { continue }
         $match = (Norm $title).Contains((Norm $j.scriptName)) -or (Norm $r.ten).Contains((Norm $j.scriptName)) -or (Norm $j.scriptName).Contains((Norm $r.ten))
         if($match) { $best = $j; break }
         if($best -eq $null) { $best = $j; $best | Add-Member -NotePropertyName khongChac -NotePropertyValue $true -Force }
        }
      if($best -eq $null)
        { $status = 'không lấy được mã (khóa mã hoặc không tìm thấy)' }
      else
        {
         $sub = Join-Path $OutDir $r.nhom
         New-Item -ItemType Directory -Force $sub | Out-Null
         $name = SafeName $r.ten
         $path = Join-Path $sub ($name + '.pine')
         [IO.File]::WriteAllText($path, $best.source, $enc)
         $file = "$($r.nhom)/$name.pine"
         $lic = LicenseOf $best.source
         $ver = $best.version
         $upd = $best.updated
         $status = $(if($best.khongChac) { 'đã tải (tên trong mã khác tên trang, cần xem lại)' } else { 'đã tải' })
        }
     }
   catch
     { $status = 'lỗi: ' + $_.Exception.Message }
   "$($r.nhom) | $($r.ten) | $status"
   $out += [pscustomobject]@{ nhom = $r.nhom; ten = $r.ten; tac_gia = $r.tac_gia; giay_phep = $lic; phien_ban = $ver; cap_nhat = $upd; file = $file; trang_thai = $status; url = $r.url; doc_ky = $r.doc_ky }
   Start-Sleep -Seconds $DelaySec
  }
$out | Export-Csv (Join-Path $OutDir 'ket_qua_tai.csv') -NoTypeInformation -Encoding UTF8 -Delimiter ';'

# Mục lục
$md = @()
$md += '# Chỉ báo TradingView đã tải (SMC, MSNR, OB, FVG, thanh khoản, price action)'
$md += ''
$md += 'Tải bằng `scripts/tai-pine-tradingview.ps1` từ trang công khai của TradingView, **giữ nguyên văn mã và dòng giấy phép của tác giả**.'
$md += 'Chỉ để nghiên cứu cá nhân. Giấy phép: **MPL 2.0** được dùng lại khi giữ ghi chú giấy phép; **CC BY-NC-SA 4.0** (phần lớn của LuxAlgo, BigBeluga, Zeiierman) cấm dùng thương mại, bản sửa phải ghi công và giữ cùng giấy phép; không đăng lại lên TradingView. Bot và chỉ báo của dự án viết bằng code riêng theo định nghĩa đã chọn, không chép các file này.'
$md += ''
$md += "Tải lúc $(Get-Date -Format 'dd/MM/yyyy HH:mm'). Cột 'Đọc kỹ' = đã được phân tích luật chi tiết trong đợt nghiên cứu."
$md += ''
$md += '| Nhóm | Tên | Tác giả | Giấy phép | Đọc kỹ | File | Trạng thái |'
$md += '|---|---|---|---|---|---|---|'
foreach($x in ($out | Sort-Object nhom, ten))
  {
   $link = "[$($x.ten -replace '\|', '/')]($($x.url))"
   $f = $(if($x.file) { "``$($x.file)``" } else { '' })
   $md += "| $($x.nhom) | $link | $($x.tac_gia -replace '\|', '/') | $($x.giay_phep) | $($x.doc_ky) | $f | $($x.trang_thai) |"
  }
[IO.File]::WriteAllText((Join-Path $OutDir 'README.md'), ($md -join "`r`n") + "`r`n", $enc)
"XONG: tải được $(($out | Where-Object { $_.file -ne '' }).Count)/$($out.Count)"

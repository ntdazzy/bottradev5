# Chép mql5/ của dự án vào thư mục dữ liệu MT5 (lưu UTF-16 để MetaEditor đọc đúng tiếng Việt),
# biên dịch từng file .mq5 bằng MetaEditor và in lỗi. Thoát mã 1 nếu có lỗi.
# Ví dụ: powershell -ExecutionPolicy Bypass -File scripts\build.ps1 -Target Experts\BotVang\BotScpMtf.mq5
param(
    [string[]]$Target = @('Experts\BotVang\BotScpMtf.mq5'),
    [string]$DataDir = $(if ($env:BOTVANG_MT5_DATA) { $env:BOTVANG_MT5_DATA } else { Join-Path $env:APPDATA 'MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075' }),
    [string]$MetaEditor = $(if ($env:BOTVANG_MT5_INSTALL) { Join-Path $env:BOTVANG_MT5_INSTALL 'MetaEditor64.exe' } else { 'C:\Program Files\MetaTrader 5\MetaEditor64.exe' })
)
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8   # in tiếng Việt đúng khi đầu ra được chuyển tiếp

$src = (Resolve-Path (Join-Path $PSScriptRoot '..\mql5')).Path
$mql = Join-Path $DataDir 'MQL5'
if (-not (Test-Path $mql)) { throw "Không thấy thư mục dữ liệu MT5: $mql" }

# MetaEditor mở file UTF-8 không BOM theo bảng mã ANSI, làm hỏng chữ Việt; UTF-16 LE có BOM thì đọc đúng.
$utf16 = New-Object System.Text.UnicodeEncoding($false, $true)
$utf8 = New-Object System.Text.UTF8Encoding($false)
$copied = 0
Get-ChildItem $src -Recurse -File -Include *.mq5, *.mqh | ForEach-Object {
    $dst = Join-Path $mql $_.FullName.Substring($src.Length + 1)
    New-Item -ItemType Directory -Force (Split-Path $dst) | Out-Null
    [System.IO.File]::WriteAllText($dst, [System.IO.File]::ReadAllText($_.FullName, $utf8), $utf16)
    $copied++
}
Write-Host "Đã chép $copied file vào $mql"

$failed = $false
foreach ($t in $Target) {
    $file = Join-Path $mql $t
    if (-not (Test-Path $file)) { Write-Host "LỖI: không có $file"; $failed = $true; continue }
    $log = [System.IO.Path]::ChangeExtension($file, '.log')
    Remove-Item $log -ErrorAction SilentlyContinue
    # MetaEditor luôn trả mã thoát 0, nên kết quả phải đọc từ file log.
    Start-Process -FilePath $MetaEditor -ArgumentList "/compile:`"$file`"", "/log:`"$log`"", "/inc:`"$mql`"" -Wait -NoNewWindow
    if (-not (Test-Path $log)) { Write-Host "LỖI: MetaEditor không tạo log cho $t"; $failed = $true; continue }
    $lines = [System.IO.File]::ReadAllLines($log, [System.Text.Encoding]::Unicode)
    $lines | Where-Object { $_ -match ': (error|warning) ' } | ForEach-Object { Write-Host $_ }
    $result = $lines | Where-Object { $_ -match '^Result: (\d+) errors?' } | Select-Object -Last 1
    Write-Host "$t -> $result"
    if (-not $result -or [int]([regex]::Match($result, '\d+').Value) -gt 0) { $failed = $true }
}
if ($failed) { exit 1 }

# Hàm dùng chung: đóng MT5 chính đúng cách, chạy nó với file cấu hình, chờ nó tự tắt, rồi mở lại như trước.
# MT5 chỉ cho 1 phiên trên một thư mục dữ liệu, nên phải đóng phiên đang mở trước khi chạy tự động.
# Dùng bằng: . (Join-Path $PSScriptRoot 'mt5-main.ps1')

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8   # in tiếng Việt đúng khi đầu ra được chuyển tiếp
$Mt5Install = if ($env:BOTVANG_MT5_INSTALL) { $env:BOTVANG_MT5_INSTALL } else { 'C:\Program Files\MetaTrader 5' }
$Mt5Terminal = Join-Path $Mt5Install 'terminal64.exe'
$Mt5Data = if ($env:BOTVANG_MT5_DATA) { $env:BOTVANG_MT5_DATA } else { Join-Path $env:APPDATA 'MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075' }
$Mt5Utf16 = New-Object System.Text.UnicodeEncoding($false, $true)

# Process của bản cài chính (kể cả trình cập nhật trong thư mục dữ liệu); bỏ qua bản portable của dự án khác.
function Get-MainTerminal {
    Get-CimInstance Win32_Process -Filter "name='terminal64.exe'" |
        Where-Object { $_.CommandLine -notmatch '/portable' -and ($_.ExecutablePath -eq $Mt5Terminal -or $_.ExecutablePath -like "$Mt5Data*") }
}

# Trả về $true nếu MT5 chính đang mở trước đó. Không ép tắt: không đóng được trong 60 giây thì báo lỗi.
function Stop-MainTerminal {
    $was = [bool](Get-MainTerminal)
    foreach ($t in Get-MainTerminal) {
        $p = Get-Process -Id $t.ProcessId
        # MT5 vừa mở lại có thể chưa có cửa sổ: gửi lệnh đóng lặp lại mỗi giây cho tới khi nó tắt (tối đa 90 giây)
        $closed = $false
        for ($i = 0; $i -lt 90 -and -not $closed; $i++) {
            $p.Refresh()
            # MT5 có thể tự tắt đúng giữa hai lệnh: khi đó .NET báo InvalidOperationException, coi như đã đóng
            try { if ($p.MainWindowHandle -ne [IntPtr]::Zero) { [void]$p.CloseMainWindow() } }
            catch [System.InvalidOperationException] { }
            $closed = $p.WaitForExit(1000)
        }
        if (-not $closed) { throw "MT5 chính không tự đóng trong 90 giây (pid $($t.ProcessId)); dừng, không ép tắt." }
    }
    return $was
}

# Chạy MT5 chính với file cấu hình (UTF-16) và chờ tới khi không còn process MT5 chính.
# Trình cập nhật của MT5 có thể tự khởi động lại terminal với cùng cấu hình, nên chờ theo process chứ không theo PID.
# Trả về $true nếu MT5 đã tự tắt trước khi hết giờ.
function Invoke-MainTerminal([string]$IniText, [int]$TimeoutMin) {
    $ini = Join-Path $env:TEMP 'botvang-mt5.ini'
    [System.IO.File]::WriteAllText($ini, $IniText, $Mt5Utf16)
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    Start-Process -FilePath $Mt5Terminal -ArgumentList "/config:`"$ini`"" -WindowStyle Hidden | Out-Null
    $idle = 0
    while ($sw.Elapsed.TotalMinutes -lt $TimeoutMin -and $idle -lt 3) {
        Start-Sleep -Seconds 3
        if (Get-MainTerminal) { $idle = 0 } else { $idle++ }
    }
    Write-Host ("MT5 chạy {0:N0} giây" -f $sw.Elapsed.TotalSeconds)
    return -not (Get-MainTerminal)
}

function Start-MainTerminal { Start-Process -FilePath $Mt5Terminal -WindowStyle Hidden | Out-Null; Write-Host 'Đã mở lại MT5 chính.' }

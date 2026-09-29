# Chỉ stage và commit danh sách file đã chỉ rõ. Không tự push, không gom thay đổi đã stage của người khác.
param(
    [Parameter(Mandatory = $true)][string]$Message,
    [Parameter(Mandatory = $true)][string[]]$Files
)
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
Push-Location $root
try {
    $gitRoot = & git rev-parse --show-toplevel 2>$null
    if ($LASTEXITCODE -ne 0 -or [IO.Path]::GetFullPath($gitRoot) -ne $root) { throw 'Không ở đúng kho Git của dự án.' }
    $staged = @(& git diff --cached --name-only)
    if ($LASTEXITCODE -ne 0) { throw 'Không đọc được danh sách đã stage.' }
    if ($staged.Count -gt 0) { throw 'Đã có file được stage. Cần kiểm tra chúng trước khi dùng công cụ này.' }
    foreach ($file in $Files) {
        $full = [IO.Path]::GetFullPath((Join-Path $root $file))
        if (-not $full.StartsWith($root + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
            throw "File ngoài dự án: $file"
        }
        if (-not (Test-Path -LiteralPath $full -PathType Leaf)) { throw "Phải truyền file cụ thể: $file" }
    }
    & git add -- $Files
    if ($LASTEXITCODE -ne 0) { throw 'Stage thất bại.' }
    & git diff --cached --check
    if ($LASTEXITCODE -ne 0) { throw 'File chuẩn bị commit còn lỗi định dạng.' }
    & git commit -m $Message
    if ($LASTEXITCODE -ne 0) { throw 'Commit thất bại.' }
} finally { Pop-Location }

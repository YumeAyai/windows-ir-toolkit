# ============================================================
# Volatility 3 一键安装(分析机用,Windows)
# ============================================================

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Vol3Dir = Join-Path $ScriptDir "volatility3"

Write-Host "[*] Volatility 3 安装脚本 (Windows)" -ForegroundColor Cyan
Write-Host "[*] 工具包: $Vol3Dir" -ForegroundColor Cyan
Write-Host ""

# 检查 Python
try {
    $pyVer = python --version 2>&1
    Write-Host "[OK] $pyVer" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] python 未找到" -ForegroundColor Red
    Write-Host "  请先装 Python 3.8+ (https://www.python.org/downloads/)"
    exit 1
}

# 找 wheel
$WHL = Get-ChildItem "$Vol3Dir\volatility3-*.whl" -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $WHL) {
    Write-Host "[ERROR] 找不到 vol3 wheel" -ForegroundColor Red
    Write-Host "  期待: $Vol3Dir\volatility3-*.whl"
    exit 1
}
Write-Host "[OK] Wheel: $($WHL.Name)" -ForegroundColor Green
Write-Host ""

# 安装(用 --user 避免系统权限问题)
Write-Host "[*] 装 vol3 (用 --user)..." -ForegroundColor Cyan
python -m pip install --user $WHL.FullName 2>&1 | Select-Object -Last 3
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] pip install 失败" -ForegroundColor Red
    exit 1
}

# 验证
Write-Host ""
Write-Host "[*] 验证..." -ForegroundColor Cyan
try {
    python -m volatility3 --help 2>&1 | Select-Object -First 3
    Write-Host "[OK] 'python -m volatility3' 可用" -ForegroundColor Green
} catch {
    Write-Host "[WARN] 'python -m volatility3' 不可用" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "[*] 接下来:" -ForegroundColor Cyan
Write-Host "  python -m volatility3 -f mem.raw windows.info"
Write-Host "  python -m volatility3 -f mem.raw windows.pstree"
Write-Host "  python -m volatility3 -f mem.raw windows.netscan"

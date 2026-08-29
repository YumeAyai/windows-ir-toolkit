<#
.SYNOPSIS
    下载 windows-ir-toolkit 所需的全部取证工具

.DESCRIPTION
    从 GitHub Releases 拉取最新的 tools-* release,自动放到 01_获取/ 和 03_分析/
    自动跳过需要手动下载的工具(FTK Imager / Magnet / DumpIt),只给提示

.PARAMETER OutputDir
    解压目标目录,默认当前目录

.EXAMPLE
    .\install_tools.ps1
    .\install_tools.ps1 -OutputDir D:\IR_Toolkit
#>

[CmdletBinding()]
param(
    [string]$OutputDir = ".",
    [string]$Repo = "YumeAyai/windows-ir-toolkit"
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# ============== 准备 ==============
$OutputDir = Resolve-Path $OutputDir
Write-Host "[*] 输出目录: $OutputDir" -ForegroundColor Cyan
Write-Host "[*] 仓库: $Repo" -ForegroundColor Cyan
Write-Host ""

# 创建目录
New-Item -ItemType Directory -Force -Path "$OutputDir\01_获取" | Out-Null
New-Item -ItemType Directory -Force -Path "$OutputDir\03_分析" | Out-Null

# ============== 找最新 tools-* release ==============
Write-Host "[+] 查询 GitHub 最新 tools release..." -ForegroundColor Green
try {
    $release = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases" -Method Get |
        Where-Object { $_.tag_name -like "tools-*" } |
        Sort-Object created_at -Descending |
        Select-Object -First 1
} catch {
    Write-Host "[!] GitHub API 查询失败: $_" -ForegroundColor Red
    Write-Host "    可能需要配置代理或检查网络" -ForegroundColor Yellow
    exit 1
}

if (-not $release) {
    Write-Host "[!] 还没生成过 tools-* release" -ForegroundColor Yellow
    Write-Host "    请先去 https://github.com/$Repo/actions 手动触发 'Fetch Forensics Tools' workflow" -ForegroundColor Yellow
    exit 1
}

Write-Host "    找到: $($release.tag_name)" -ForegroundColor Green
Write-Host "    发布时间: $($release.published_at)" -ForegroundColor Green
Write-Host ""

# ============== 下载 ==============
$tempDir = Join-Path $env:TEMP "ir-toolkit-$(Get-Random)"
New-Item -ItemType Directory -Force -Path $tempDir | Out-Null

$success = @()
$skipped = @()
$failed = @()

foreach ($asset in $release.assets) {
    $name = $asset.name
    $url = $asset.browser_download_url
    $size = [math]::Round($asset.size / 1MB, 2)

    # 决定目标位置
    if ($name -like "winpmem*") {
        $targetPath = Join-Path $OutputDir "01_获取\$name"
    } elseif ($name -like "capa*" -or $name -like "*.zip") {
        $targetPath = Join-Path $tempDir $name
    } else {
        $targetPath = Join-Path $tempDir $name
    }

    Write-Host "  [↓] $name ($size MB)..."

    try {
        Invoke-WebRequest -Uri $url -OutFile $targetPath -UseBasicParsing -TimeoutSec 60
        $success += $name
        Write-Host "       ✓" -ForegroundColor Green
    } catch {
        $failed += $name
        Write-Host "       ✗ $($_.Exception.Message)" -ForegroundColor Red
    }
}

# ============== 处理 capa zip ==============
$capaZip = Get-ChildItem $tempDir -Filter "*.zip" -ErrorAction SilentlyContinue
if ($capaZip) {
    Write-Host ""
    Write-Host "[+] 解压 capa..." -ForegroundColor Green
    foreach ($zip in $capaZip) {
        Expand-Archive -Path $zip.FullName -DestinationPath $tempDir\capa_extracted -Force
    }

    # 找到 capa.exe 并放到 03_分析
    $capaExe = Get-ChildItem $tempDir\capa_extracted -Recurse -Filter "capa.exe" -ErrorAction SilentlyContinue |
        Select-Object -First 1

    if ($capaExe) {
        # 复制整个目录(包含 dll 等依赖)
        $capaDir = $capaExe.DirectoryName
        $targetCapa = Join-Path $OutputDir "03_分析\capa"
        Copy-Item -Path $capaDir\* -Destination $targetCapa -Recurse -Force
        Write-Host "    ✓ capa 已放到 03_分析\capa\" -ForegroundColor Green
    }
}

# ============== 算 hash 验证 ==============
Write-Host ""
Write-Host "[+] 校验..." -ForegroundColor Green
$expectedHashes = $release.body | Select-String -Pattern "([a-f0-9]{64})" -AllMatches |
    ForEach-Object { $_.Matches.Value }

if ($expectedHashes) {
    foreach ($file in Get-ChildItem $OutputDir\01_获取, $OutputDir\03_分析\capa -Recurse -File -ErrorAction SilentlyContinue) {
        $actual = (Get-FileHash -Algorithm SHA256 $file.FullName).Hash.ToLower()
        if ($expectedHashes -contains $actual) {
            Write-Host "    ✓ $($file.Name): hash 匹配" -ForegroundColor Green
        } else {
            Write-Host "    ⚠ $($file.Name): hash 不匹配 (可能不是从 release 下载的)" -ForegroundColor Yellow
        }
    }
}

# ============== 清理 + 报告 ==============
Remove-Item -Recurse -Force $tempDir -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "=" * 60 -ForegroundColor Cyan
Write-Host "完成!" -ForegroundColor Green
Write-Host "  ✓ 下载成功: $($success.Count) 个" -ForegroundColor Green
if ($failed.Count -gt 0) {
    Write-Host "  ✗ 失败:     $($failed.Count) 个" -ForegroundColor Red
}
Write-Host ""
Write-Host "[!] 以下工具需要手动下载(官方需注册账号):" -ForegroundColor Yellow
Write-Host "    - FTK Imager        https://www.exterro.com/ftk-imager" -ForegroundColor Yellow
Write-Host "    - Magnet RAM Capture https://www.magnetforensics.com/" -ForegroundColor Yellow
Write-Host "    - DumpIt            https://www.comae.com/" -ForegroundColor Yellow
Write-Host ""
Write-Host "[*] 接下来: 双击 02_辅助收集\acquire.bat 开始取证" -ForegroundColor Cyan

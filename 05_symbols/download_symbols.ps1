<#
.SYNOPSIS
    按受害机 Windows 版本下载对应的 Volatility symbols
.NOTES
    现场第一次 dump 内存后,根据受害机 OS 版本跑这个脚本
    网络允许时自动下载,网络隔离时可手动离线拷贝
#>

[CmdletBinding()]
param(
    [string]$OutputDir = ".",
    [string]$Mirror = "https://downloads.volatilityfoundation.org/volatility3/symbols"
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

function Get-WindowsVersion {
    try {
        $os = Get-CimInstance Win32_OperatingSystem
        return @{
            Product = $os.Caption
            Version = $os.Version
            Build   = $os.BuildNumber
            Arch    = $os.OSArchitecture
        }
    } catch {
        Write-Host "无法读取 OS 信息(需要管理员权限?)" -ForegroundColor Red
        return $null
    }
}

function Get-SymbolFileName {
    param($info)
    # 映射 Windows 版本到 Volatility 官方 symbols 文件名
    $map = @{
        "10.0.22000" = "win11_22h2"
        "10.0.22621" = "win11_22h2"
        "10.0.19041" = "win10_20h1_19041"
        "10.0.19042" = "win10_20h2_19042"
        "10.0.19043" = "win10_21h1_19043"
        "10.0.19044" = "win10_21h2_19044"
        "10.0.19045" = "win10_22h2_19045"
        "10.0.18362" = "win10_19h1_18362"
        "10.0.18363" = "win10_19h2_18363"
        "6.3.9600"   = "win81_9600"
        "6.2.9200"   = "win8_9200"
        "6.1.7601"   = "win7_7601"
        "6.1.7600"   = "win7_7600"
        "6.0.6002"   = "vista_6002"
    }
    $v = "$($info.Version).$($info.Build)"
    $key = "$($info.Version).$($info.Build)"
    if ($map.ContainsKey($key)) { return $map[$key] }
    # 部分匹配
    foreach ($k in $map.Keys) {
        if ($k -like "$($info.Version).*") { return $map[$k] }
    }
    return $null
}

# ============== 主流程 ==============
Write-Host "[*] 受害机 Windows 版本检测..." -ForegroundColor Cyan
$info = Get-WindowsVersion
if (-not $info) { exit 1 }
Write-Host "    Product: $($info.Product)" -ForegroundColor Green
Write-Host "    Version: $($info.Version) (Build $($info.Build))" -ForegroundColor Green
Write-Host "    Arch:    $($info.Arch)" -ForegroundColor Green

$symName = Get-SymbolFileName $info
if (-not $symName) {
    Write-Host ""
    Write-Host "[!] 找不到 $($info.Version) 对应的 symbols 名称" -ForegroundColor Red
    Write-Host "    已知:6.0-6.3, 10.0.18362-10.0.22621" -ForegroundColor Yellow
    Write-Host "    可以去 https://downloads.volatilityfoundation.org/volatility3/symbols/ 找手动下载" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "[+] 对应 symbol: $symName" -ForegroundColor Cyan

$arch = if ($info.Arch -like "*64*") { "x64" } else { "x86" }
$url = "$Mirror/$symName.zip"
$zipPath = Join-Path $OutputDir "$symName.zip"
$extractDir = Join-Path $OutputDir "windows"
$symFile = "$symName-$arch.zip"

Write-Host "[*] 首选官方标准包: $url" -ForegroundColor Cyan
try {
    Invoke-WebRequest -Uri $url -OutFile $zipPath -UseBasicParsing -TimeoutSec 120
    Expand-Archive -Path $zipPath -DestinationPath $OutputDir -Force
    Remove-Item $zipPath
    Write-Host "[+] 下载完成,已解压到 $OutputDir" -ForegroundColor Green
    return
} catch {
    Write-Host "[!] 官方包下载失败,尝试 PDB 单独下载..." -ForegroundColor Yellow
}

# Fallback: 单独下 PDB
$pdbUrl = "$Mirror/$symFile"
Write-Host "[*] 备用下载: $pdbUrl" -ForegroundColor Cyan
try {
    Invoke-WebRequest -Uri $pdbUrl -OutFile (Join-Path $OutputDir $symFile) -UseBasicParsing -TimeoutSec 120
    Expand-Archive -Path (Join-Path $OutputDir $symFile) -DestinationPath $OutputDir -Force
    Write-Host "[+] 已下载 $symFile" -ForegroundColor Green
} catch {
    Write-Host "[!] 下载失败,网络可能受限" -ForegroundColor Red
    Write-Host "    手动方案:浏览器访问 https://downloads.volatilityfoundation.org/volatility3/symbols/" -ForegroundColor Yellow
    Write-Host "    找 $symFile 下载到本目录后跑本脚本" -ForegroundColor Yellow
    exit 1
}

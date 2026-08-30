<#
.SYNOPSIS
    Windows 应急响应一键证据收集脚本 (针对 Cobalt Strike / RAT 类事件)

.DESCRIPTION
    用法: .\collect_artifacts.ps1 -OutputDir C:\evidence
    必须以管理员权限运行

.NOTES
    编码说明:文件保存为 UTF-8 BOM,PowerShell 5.1+ 可正确解析中文。
             脚本头部强制 UTF-8 输出,所有 Out-File/Export-Csv 写出的文件也是 UTF-8。
    Version: 1.2
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$OutputDir = "C:\evidence",

    [string]$CaseID = "IR-$(Get-Date -Format 'yyyyMMdd-HHmmss')",

    [switch]$LightMode   # 只收集最关键项,减少取证时间
)

# ============== 强制 UTF-8 输出(关键!)==============
# PowerShell 5.1 默认按系统区域(中文系统 CP936/GBK)写文件
# 强制设 UTF-8,保证所有 CSV/日志在跨平台分析时不乱码
$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'
$PSDefaultParameterValues['Export-Csv:Encoding'] = 'utf8'
$PSDefaultParameterValues['Set-Content:Encoding'] = 'utf8'
$PSDefaultParameterValues['Add-Content:Encoding'] = 'utf8'
try {
    $PSDefaultParameterValues['*:Encoding'] = 'utf8'
} catch {}
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# ============== 初始化 ==============
$ErrorActionPreference = "Continue"
$CaseDir = Join-Path $OutputDir $CaseID
$null = New-Item -ItemType Directory -Force -Path "$CaseDir\01_system"
$null = New-Item -ItemType Directory -Force -Path "$CaseDir\02_process"
$null = New-Item -ItemType Directory -Force -Path "$CaseDir\03_network"
$null = New-Item -ItemType Directory -Force -Path "$CaseDir\04_persistence"
$null = New-Item -ItemType Directory -Force -Path "$CaseDir\05_logs"
$null = New-Item -ItemType Directory -Force -Path "$CaseDir\06_files"

Write-Host "[*] 案件: $CaseID" -ForegroundColor Cyan
Write-Host "[*] 输出: $CaseDir" -ForegroundColor Cyan
Write-Host "[*] 时间: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Cyan
Write-Host ""

# ============== 1. 系统信息 ==============
Write-Host "[+] 1/8 系统信息..." -ForegroundColor Green
systeminfo | Out-File "$CaseDir\01_system\systeminfo.txt"
hostname | Out-File "$CaseDir\01_system\hostname.txt"
whoami /all | Out-File "$CaseDir\01_system\whoami.txt"
Get-ComputerInfo -Property * | Out-File "$CaseDir\01_system\computerinfo.txt" -ErrorAction SilentlyContinue
Get-HotFix | Out-File "$CaseDir\01_system\hotfix.txt"
w32tm /query /status | Out-File "$CaseDir\01_system\time_sync.txt" -ErrorAction SilentlyContinue

# ============== 2. 进程信息 (CS 重点) ==============
Write-Host "[+] 2/8 进程信息..." -ForegroundColor Green

# 全进程列表 + 服务
Get-Process | Select-Object Id, ProcessName, Path, Company, Description, StartTime |
    Sort-Object StartTime | Export-Csv "$CaseDir\02_process\pslist.csv" -NoTypeInformation

# 带命令行的进程(找 rundll32 / powershell -enc 之类)
Get-CimInstance Win32_Process |
    Select-Object ProcessId, ParentProcessId, Name, CommandLine, CreationDate |
    Export-Csv "$CaseDir\02_process\pslist_wmic.csv" -NoTypeInformation

# 任务列表 / 服务
tasklist /svc | Out-File "$CaseDir\02_process\tasklist_svc.txt"

# DLL 列表(重点进程)
Get-Process | Where-Object { $_.Path -ne $null } | ForEach-Object {
    $procName = $_.ProcessName
    try {
        $dlls = Get-Process -Id $_.Id -Module -ErrorAction SilentlyContinue
        $dlls | Select-Object ModuleName, FileName, Company, FileVersion |
            Export-Csv "$CaseDir\02_process\dlls_$procName.csv" -NoTypeInformation -Append
    } catch {}
}

# 父进程关系(CS 经典:Office/浏览器 -> rundll32/dllhost)
Write-Host "    - 父进程关系..." -ForegroundColor DarkGreen
Get-CimInstance Win32_Process | Where-Object {
    $_.ParentProcessId -ne 0
} | ForEach-Object {
    $parent = Get-CimInstance Win32_Process -Filter "ProcessId = $($_.ParentProcessId)" -ErrorAction SilentlyContinue
    [PSCustomObject]@{
        ChildPID   = $_.ProcessId
        Child      = $_.Name
        ChildCmd   = $_.CommandLine.Substring(0, [Math]::Min(200, $_.CommandLine.Length))
        ParentPID  = $_.ParentProcessId
        Parent     = if ($parent) { $parent.Name } else { "N/A" }
    }
} | Export-Csv "$CaseDir\02_process\process_tree.csv" -NoTypeInformation

# ============== 3. 网络信息 ==============
Write-Host "[+] 3/8 网络信息..." -ForegroundColor Green
netstat -anob | Out-File "$CaseDir\03_network\netstat_anob.txt"
netstat -ano | Out-File "$CaseDir\03_network\netstat_ano.txt"
ipconfig /displaydns | Out-File "$CaseDir\03_network\dns_cache.txt"
arp -a | Out-File "$CaseDir\03_network\arp.txt"
route print | Out-File "$CaseDir\03_network\routes.txt"
netsh advfirewall show allprofiles | Out-File "$CaseDir\03_network\firewall.txt"
netsh advfirewall firewall show rule name=all | Out-File "$CaseDir\03_network\firewall_rules.txt"
Get-SmbConnection | Out-File "$CaseDir\03_network\smb_connections.txt" -ErrorAction SilentlyContinue
net session | Out-File "$CaseDir\03_network\net_session.txt" -ErrorAction SilentlyContinue
net use | Out-File "$CaseDir\03_network\net_use.txt"
net share | Out-File "$CaseDir\03_network\net_share.txt"
query session | Out-File "$CaseDir\03_network\rdp_sessions.txt" -ErrorAction SilentlyContinue

# ============== 4. 持久化(CS 重点) ==============
Write-Host "[+] 4/8 持久化检查..." -ForegroundColor Green

# 计划任务
schtasks /query /fo LIST /v | Out-File "$CaseDir\04_persistence\schtasks.txt"
Get-ScheduledTask | Get-ScheduledTaskInfo |
    Select-Object TaskName, TaskPath, State, LastRunTime, NextRunTime |
    Export-Csv "$CaseDir\04_persistence\schtasks_summary.csv" -NoTypeInformation

# 注册表 Run 键(CS 经典持久化)
$runKeys = @(
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run",
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce",
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnceEx",
    "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run",
    "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\RunOnce",
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run",
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce",
    "HKLM:\System\CurrentControlSet\Services",
    "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Winlogon"
)
foreach ($key in $runKeys) {
    $safeName = $key -replace "[:\\]", "_"
    reg export $key "$CaseDir\04_persistence\reg_$safeName.reg" 2>$null
}

# WMI 持久化(CS / 高级攻击常用)
Get-WmiObject -Namespace "root\subscription" -Class __EventConsumer |
    Export-Csv "$CaseDir\04_persistence\wmi_consumers.csv" -NoTypeInformation -ErrorAction SilentlyContinue
Get-WmiObject -Namespace "root\subscription" -Class __EventFilter |
    Export-Csv "$CaseDir\04_persistence\wmi_filters.csv" -NoTypeInformation -ErrorAction SilentlyContinue

# 服务
Get-WmiObject Win32_Service | Select-Object Name, DisplayName, State, StartMode, PathName |
    Export-Csv "$CaseDir\04_persistence\services.csv" -NoTypeInformation

# ============== 5. 事件日志 ==============
Write-Host "[+] 5/8 事件日志..." -ForegroundColor Green

$logs = @("Security", "System", "Application",
          "Microsoft-Windows-PowerShell/Operational",
          "Microsoft-Windows-Sysmon/Operational",
          "Microsoft-Windows-Windows Defender/Operational",
          "Microsoft-Windows-TaskScheduler/Operational")
foreach ($log in $logs) {
    $safeLog = $log -replace "[/\\:]", "_"
    wevtutil epl $log "$CaseDir\05_logs\${safeLog}.evtx" 2>$null
}

# 安全事件(最近 24h)
Get-WinEvent -FilterHashtable @{LogName='Security'; StartTime=(Get-Date).AddDays(-1)} -ErrorAction SilentlyContinue |
    Select-Object TimeCreated, Id, ProviderName, Message |
    Export-Csv "$CaseDir\05_logs\security_24h.csv" -NoTypeInformation

# 登录事件(最近 7d)
Get-WinEvent -FilterHashtable @{LogName='Security'; Id=@(4624,4625,4648,4672,4688); StartTime=(Get-Date).AddDays(-7)} -ErrorAction SilentlyContinue |
    Select-Object TimeCreated, Id, @{N='User';E={$_.Properties[5].Value}}, @{N='LogonType';E={$_.Properties[8].Value}} |
    Export-Csv "$CaseDir\05_logs\logon_events_7d.csv" -NoTypeInformation

# ============== 6. 文件系统痕迹 ==============
Write-Host "[+] 6/8 文件痕迹..." -ForegroundColor Green

# Prefetch
Copy-Item "$env:SystemRoot\Prefetch\*.pf" "$CaseDir\06_files\prefetch\" -Force -ErrorAction SilentlyContinue

# 近期文件
$recentDays = -7
$recentFiles = Get-ChildItem -Path C:\Users, C:\Windows\Temp, C:\Temp, "$env:ProgramData" -Recurse -File -Force -ErrorAction SilentlyContinue |
    Where-Object { $_.LastWriteTime -gt (Get-Date).AddDays($recentDays) } |
    Select-Object FullName, LastWriteTime, Length, CreationTime
$recentFiles | Export-Csv "$CaseDir\06_files\recent_files_7d.csv" -NoTypeInformation

# 用户 Recent
$users = Get-ChildItem C:\Users -Directory -Force -ErrorAction SilentlyContinue
foreach ($u in $users) {
    $recent = "$($u.FullName)\AppData\Roaming\Microsoft\Windows\Recent"
    if (Test-Path $recent) {
        Copy-Item "$recent\*" "$CaseDir\06_files\recent_$($u.Name)\" -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# 临时目录
$tempDirs = @($env:TEMP, $env:TMP, "C:\Windows\Temp", "C:\Temp", "$env:ProgramData")
foreach ($td in $tempDirs) {
    if (Test-Path $td) {
        Get-ChildItem $td -Recurse -File -Force -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -gt (Get-Date).AddDays(-7) } |
            Select-Object FullName, LastWriteTime, Length |
            Export-Csv "$CaseDir\06_files\temp_${td}.csv" -NoTypeInformation
    }
}

# ============== 7. 用户行为 ==============
Write-Host "[+] 7/8 用户行为..." -ForegroundColor Green

# PowerShell 历史
$psHistFiles = @(
    "$env:APPDATA\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt",
    "$env:LOCALAPPDATA\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt"
)
foreach ($ph in $psHistFiles) {
    if (Test-Path $ph) {
        Copy-Item $ph "$CaseDir\06_files\ps_history_$(Split-Path $ph -Leaf)" -Force
    }
}

# SSH known_hosts
$users | ForEach-Object {
    $ssh = "$($_.FullName)\.ssh\known_hosts"
    if (Test-Path $ssh) { Copy-Item $ssh "$CaseDir\06_files\ssh_$($_.Name)_known_hosts" -Force }
}

# ============== 8. 浏览器 / Office ==============
Write-Host "[+] 8/8 浏览器 / Office..." -ForegroundColor Green

$users | ForEach-Object {
    $chrome = "$($_.FullName)\AppData\Local\Google\Chrome\User Data\Default\History"
    $edge = "$($_.FullName)\AppData\Local\Microsoft\Edge\User Data\Default\History"
    if (Test-Path $chrome) { Copy-Item $chrome "$CaseDir\06_files\chrome_history_$($_.Name).db" -Force }
    if (Test-Path $edge) { Copy-Item $edge "$CaseDir\06_files\edge_history_$($_.Name).db" -Force }
}

# ============== 完成 ==============
Write-Host ""
Write-Host "[+] 完成!" -ForegroundColor Green
Write-Host "[*] 案件目录: $CaseDir"
Write-Host "[*] 下一步:运行 winpmem dump 内存,再算 SHA256:" -ForegroundColor Yellow
Write-Host "    Get-FileHash -Algorithm SHA256 mem.raw"
Write-Host "[*] 然后压缩整个 $CaseDir 目录,传回分析机" -ForegroundColor Yellow
Write-Host ""

explorer $CaseDir

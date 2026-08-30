<#
.SYNOPSIS
    Windows 应急响应一键证据收集脚本 (针对 Cobalt Strike / RAT 类事件)

.DESCRIPTION
    用法: 双击此脚本(自动请求管理员权限)
          或 .\collect_artifacts.ps1 -OutputDir C:\evidence(需先以管理员身份启动 PowerShell)
    必须以管理员权限运行

.NOTES
    编码说明:文件保存为 UTF-8 BOM,PowerShell 5.1+ 可正确解析中文。
             脚本头部强制 UTF-8 输出,所有 Out-File/Export-Csv 写出的文件也是 UTF-8。
    自动提权:如果不是管理员,自动弹出 UAC 重新启动。
    Version: 1.3
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$OutputDir = "C:\evidence",

    [string]$CaseID = "IR-$(Get-Date -Format 'yyyyMMdd-HHmmss')",

    [switch]$LightMode   # 只收集最关键项,减少取证时间
)

# ============== 阶段 0: 自动提权 ==============
# 如果不是管理员,自动用 UAC 重新启动
$principal = New-Object Security.Principal.WindowsPrincipal(
    [Security.Principal.WindowsIdentity]::GetCurrent()
)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "[!] 需要管理员权限,正在请求提权..." -ForegroundColor Yellow
    $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath)
    foreach ($a in $args) { $argList += $a }
    try {
        Start-Process -FilePath 'powershell.exe' -ArgumentList $argList -Verb RunAs
    } catch {
        Write-Host "[X] 提权失败,请右键此脚本 → 以管理员身份运行" -ForegroundColor Red
        pause
    }
    exit
}

# ============== 强制 UTF-8 输出(关键!)==============
# PowerShell 5.1 默认按系统区域(中文系统 CP936/GBK)写文件
# 强制设 UTF-8,保证所有 CSV/日志在跨平台分析时不乱码
$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'
$PSDefaultParameterValues['Export-Csv:Encoding'] = 'utf8'
$PSDefaultParameterValues['Set-Content:Encoding'] = 'utf8'
$PSDefaultParameterValues['Add-Content:Encoding'] = 'utf8'
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
try { systeminfo | Out-File "$CaseDir\01_system\systeminfo.txt" } catch { Write-Host "  [!] systeminfo 失败" -ForegroundColor Yellow }
try { hostname | Out-File "$CaseDir\01_system\hostname.txt" } catch {}
try { whoami /all | Out-File "$CaseDir\01_system\whoami.txt" } catch {}
try { Get-ComputerInfo -Property * | Out-File "$CaseDir\01_system\computerinfo.txt" -ErrorAction SilentlyContinue } catch {}
try { Get-HotFix | Out-File "$CaseDir\01_system\hotfix.txt" } catch {}
try { w32tm /query /status | Out-File "$CaseDir\01_system\time_sync.txt" -ErrorAction SilentlyContinue } catch {}

# ============== 2. 进程信息 (CS 重点) ==============
Write-Host "[+] 2/8 进程信息..." -ForegroundColor Green

# 全进程列表 + 服务
try {
    $processes = @(Get-Process -ErrorAction SilentlyContinue | Select-Object Id, ProcessName, Path, Company, Description, StartTime)
    $processes | Sort-Object StartTime | Export-Csv "$CaseDir\02_process\pslist.csv" -NoTypeInformation
} catch { Write-Host "  [!] pslist 失败" -ForegroundColor Yellow }

# 带命令行的进程(找 rundll32 / powershell -enc 之类)
try {
    $cimProcs = @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue)
    if ($cimProcs.Count -gt 0) {
        $cimProcs | Select-Object ProcessId, ParentProcessId, Name, CommandLine, CreationDate |
            Export-Csv "$CaseDir\02_process\pslist_wmic.csv" -NoTypeInformation
    } else {
        Write-Host "  [!] Get-CimInstance Win32_Process 返回空" -ForegroundColor Yellow
    }
} catch { Write-Host "  [!] pslist_wmic 失败 (CIM 服务不可用?)" -ForegroundColor Yellow }

# 任务列表 / 服务
try { tasklist /svc | Out-File "$CaseDir\02_process\tasklist_svc.txt" } catch {}

# DLL 列表(重点进程)
try {
    Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Path -ne $null } | ForEach-Object {
        $procName = $_.ProcessName
        try {
            $dlls = @(Get-Process -Id $_.Id -Module -ErrorAction SilentlyContinue)
            if ($dlls.Count -gt 0) {
                $dlls | Select-Object ModuleName, FileName, Company, FileVersion |
                    Export-Csv "$CaseDir\02_process\dlls_$procName.csv" -NoTypeInformation -Append
            }
        } catch {}
    }
} catch {}

# 父进程关系(CS 经典:Office/浏览器 -> rundll32/dllhost)
Write-Host "    - 父进程关系..." -ForegroundColor DarkGreen
try {
    $allProcs = @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue)
    if ($allProcs.Count -gt 0) {
        $tree = foreach ($p in $allProcs) {
            if ($p.ParentProcessId -ne 0) {
                $parent = $allProcs | Where-Object { $_.ProcessId -eq $p.ParentProcessId } | Select-Object -First 1
                [PSCustomObject]@{
                    ChildPID   = $p.ProcessId
                    Child      = if ($p.Name) { $p.Name } else { "Unknown" }
                    ChildCmd   = if ($p.CommandLine) { $p.CommandLine.Substring(0, [Math]::Min(200, $p.CommandLine.Length)) } else { "" }
                    ParentPID  = $p.ParentProcessId
                    Parent     = if ($parent -and $parent.Name) { $parent.Name } else { "N/A" }
                }
            }
        }
        if ($tree) { @($tree) | Export-Csv "$CaseDir\02_process\process_tree.csv" -NoTypeInformation }
    }
} catch { Write-Host "  [!] process_tree 失败" -ForegroundColor Yellow }

# ============== 3. 网络信息 ==============
Write-Host "[+] 3/8 网络信息..." -ForegroundColor Green
try { netstat -anob | Out-File "$CaseDir\03_network\netstat_anob.txt" } catch {}
try { netstat -ano | Out-File "$CaseDir\03_network\netstat_ano.txt" } catch {}
try { ipconfig /displaydns | Out-File "$CaseDir\03_network\dns_cache.txt" } catch {}
try { arp -a | Out-File "$CaseDir\03_network\arp.txt" } catch {}
try { route print | Out-File "$CaseDir\03_network\routes.txt" } catch {}
try { netsh advfirewall show allprofiles | Out-File "$CaseDir\03_network\firewall.txt" } catch {}
try { netsh advfirewall firewall show rule name=all | Out-File "$CaseDir\03_network\firewall_rules.txt" } catch {}
try { Get-SmbConnection | Out-File "$CaseDir\03_network\smb_connections.txt" -ErrorAction SilentlyContinue } catch {}
try { net session | Out-File "$CaseDir\03_network\net_session.txt" -ErrorAction SilentlyContinue } catch {}
try { net use | Out-File "$CaseDir\03_network\net_use.txt" } catch {}
try { net share | Out-File "$CaseDir\03_network\net_share.txt" } catch {}
try { query session | Out-File "$CaseDir\03_network\rdp_sessions.txt" -ErrorAction SilentlyContinue } catch {}

# ============== 4. 持久化(CS 重点) ==============
Write-Host "[+] 4/8 持久化检查..." -ForegroundColor Green

# 计划任务
try { schtasks /query /fo LIST /v | Out-File "$CaseDir\04_persistence\schtasks.txt" } catch {}
try {
    $tasks = @(Get-ScheduledTask -ErrorAction SilentlyContinue)
    if ($tasks.Count -gt 0) {
        $tasks | Get-ScheduledTaskInfo -ErrorAction SilentlyContinue |
            Select-Object TaskName, TaskPath, State, LastRunTime, NextRunTime |
            Export-Csv "$CaseDir\04_persistence\schtasks_summary.csv" -NoTypeInformation
    }
} catch {}

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
    try { reg export $key "$CaseDir\04_persistence\reg_$safeName.reg" 2>$null } catch {}
}

# WMI 持久化(CS / 高级攻击常用)
try {
    $consumers = @(Get-WmiObject -Namespace "root\subscription" -Class __EventConsumer -ErrorAction SilentlyContinue)
    if ($consumers.Count -gt 0) { $consumers | Export-Csv "$CaseDir\04_persistence\wmi_consumers.csv" -NoTypeInformation }
} catch {}
try {
    $filters = @(Get-WmiObject -Namespace "root\subscription" -Class __EventFilter -ErrorAction SilentlyContinue)
    if ($filters.Count -gt 0) { $filters | Export-Csv "$CaseDir\04_persistence\wmi_filters.csv" -NoTypeInformation }
} catch {}

# 服务
try {
    $services = @(Get-WmiObject Win32_Service -ErrorAction SilentlyContinue)
    if ($services.Count -gt 0) {
        $services | Select-Object Name, DisplayName, State, StartMode, PathName |
            Export-Csv "$CaseDir\04_persistence\services.csv" -NoTypeInformation
    }
} catch {}

# ============== 5. 事件日志 ==============
Write-Host "[+] 5/8 事件日志..." -ForegroundColor Green

$logs = @("Security", "System", "Application",
          "Microsoft-Windows-PowerShell/Operational",
          "Microsoft-Windows-Sysmon/Operational",
          "Microsoft-Windows-Windows Defender/Operational",
          "Microsoft-Windows-TaskScheduler/Operational")
foreach ($log in $logs) {
    $safeLog = $log -replace "[/\\:]", "_"
    try { wevtutil epl $log "$CaseDir\05_logs\${safeLog}.evtx" 2>$null } catch {}
}

# 安全事件(最近 24h)
try {
    $secEvents = @(Get-WinEvent -FilterHashtable @{LogName='Security'; StartTime=(Get-Date).AddDays(-1)} -ErrorAction SilentlyContinue)
    if ($secEvents.Count -gt 0) {
        $secEvents | Select-Object TimeCreated, Id, ProviderName, Message |
            Export-Csv "$CaseDir\05_logs\security_24h.csv" -NoTypeInformation
    }
} catch {}

# 登录事件(最近 7d)
try {
    $logonEvents = @(Get-WinEvent -FilterHashtable @{LogName='Security'; Id=@(4624,4625,4648,4672,4688); StartTime=(Get-Date).AddDays(-7)} -ErrorAction SilentlyContinue)
    if ($logonEvents.Count -gt 0) {
        $logonEvents | Select-Object TimeCreated, Id, @{N='User';E={ if ($_.Properties.Count -gt 5) { $_.Properties[5].Value } else { "" } }}, @{N='LogonType';E={ if ($_.Properties.Count -gt 8) { $_.Properties[8].Value } else { "" } }} |
            Export-Csv "$CaseDir\05_logs\logon_events_7d.csv" -NoTypeInformation
    }
} catch {}

# ============== 6. 文件系统痕迹 ==============
Write-Host "[+] 6/8 文件痕迹..." -ForegroundColor Green

# Prefetch
try { Copy-Item "$env:SystemRoot\Prefetch\*.pf" "$CaseDir\06_files\prefetch\" -Force -ErrorAction SilentlyContinue } catch {}

# 近期文件
try {
    $recentDays = -7
    $recentFiles = @(Get-ChildItem -Path C:\Users, C:\Windows\Temp, C:\Temp, "$env:ProgramData" -Recurse -File -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -gt (Get-Date).AddDays($recentDays) } |
        Select-Object FullName, LastWriteTime, Length, CreationTime)
    if ($recentFiles.Count -gt 0) {
        $recentFiles | Export-Csv "$CaseDir\06_files\recent_files_7d.csv" -NoTypeInformation
    }
} catch {}

# 用户 Recent
try {
    $users = @(Get-ChildItem C:\Users -Directory -Force -ErrorAction SilentlyContinue)
    foreach ($u in $users) {
        $recent = "$($u.FullName)\AppData\Roaming\Microsoft\Windows\Recent"
        if (Test-Path $recent) {
            Copy-Item "$recent\*" "$CaseDir\06_files\recent_$($u.Name)\" -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
} catch {}

# 临时目录
$tempDirs = @($env:TEMP, $env:TMP, "C:\Windows\Temp", "C:\Temp", "$env:ProgramData")
foreach ($td in $tempDirs) {
    if (Test-Path $td) {
        try {
            Get-ChildItem $td -Recurse -File -Force -ErrorAction SilentlyContinue |
                Where-Object { $_.LastWriteTime -gt (Get-Date).AddDays(-7) } |
                Select-Object FullName, LastWriteTime, Length |
                Export-Csv "$CaseDir\06_files\temp_${td}.csv" -NoTypeInformation
        } catch {}
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
        try { Copy-Item $ph "$CaseDir\06_files\ps_history_$(Split-Path $ph -Leaf)" -Force } catch {}
    }
}

# SSH known_hosts
try {
    $users = @(Get-ChildItem C:\Users -Directory -Force -ErrorAction SilentlyContinue)
    foreach ($u in $users) {
        $ssh = "$($u.FullName)\.ssh\known_hosts"
        if (Test-Path $ssh) { Copy-Item $ssh "$CaseDir\06_files\ssh_$($u.Name)_known_hosts" -Force }
    }
} catch {}

# ============== 8. 浏览器 / Office ==============
Write-Host "[+] 8/8 浏览器 / Office..." -ForegroundColor Green

try {
    $users = @(Get-ChildItem C:\Users -Directory -Force -ErrorAction SilentlyContinue)
    foreach ($u in $users) {
        $chrome = "$($u.FullName)\AppData\Local\Google\Chrome\User Data\Default\History"
        $edge = "$($u.FullName)\AppData\Local\Microsoft\Edge\User Data\Default\History"
        if (Test-Path $chrome) { Copy-Item $chrome "$CaseDir\06_files\chrome_history_$($u.Name).db" -Force }
        if (Test-Path $edge) { Copy-Item $edge "$CaseDir\06_files\edge_history_$($u.Name).db" -Force }
    }
} catch {}

# ============== 完成 ==============
Write-Host ""
Write-Host "[+] 完成!" -ForegroundColor Green
Write-Host "[*] 案件目录: $CaseDir" -ForegroundColor Cyan
Write-Host "[*] 下一步:运行 winpmem dump 内存,再算 SHA256:" -ForegroundColor Yellow
Write-Host "    Get-FileHash -Algorithm SHA256 mem.raw"
Write-Host "[*] 然后压缩整个 $CaseDir 目录,传回分析机" -ForegroundColor Yellow
Write-Host ""

# 尝试打开目录(在 PS 主机窗口中可能无效)
try { Invoke-Item $CaseDir } catch {}

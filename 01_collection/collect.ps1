<#[
.SYNOPSIS
    COL: collect volatile and triage evidence from a Windows host.

.DESCRIPTION
    The script creates one case directory, captures memory first, then collects
    supporting artifacts and writes a SHA256 manifest. It never deletes source
    files and continues when an individual collector fails.
#>
[CmdletBinding()]
param(
    [string]$CaseDir,
    [string]$EvidenceRoot = 'C:\IR_Evidence',
    [string]$CaseId,
    [switch]$SkipMemory,
    [int]$LookbackDays = 7
)

$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'
$script:Failures = [System.Collections.Generic.List[string]]::new()

function Write-Log {
    param([string]$Message, [ConsoleColor]$Color = [ConsoleColor]::Gray)
    $line = "[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ssK'), $Message
    Write-Host $line -ForegroundColor $Color
    if ($script:LogPath) { Add-Content -LiteralPath $script:LogPath -Value $line -Encoding UTF8 }
}

function Invoke-Capture {
    param(
        [string]$Name,
        [scriptblock]$Action,
        [string]$OutFile
    )
    try {
        # Native commands use the process-wide LASTEXITCODE; reset it so a
        # previous command cannot make an unrelated PowerShell collector fail.
        $global:LASTEXITCODE = 0
        if ($OutFile) {
            & $Action 2>&1 | Out-File -LiteralPath $OutFile -Encoding UTF8
        } else {
            & $Action | Out-Null
        }
        if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) { throw "exit code $LASTEXITCODE" }
        Write-Log "OK  $Name" Green
    } catch {
        $reason = "FAIL $Name : $($_.Exception.Message)"
        $script:Failures.Add($reason)
        Write-Log $reason Yellow
    }
}

function New-Directory([string]$Path) {
    New-Item -ItemType Directory -Force -LiteralPath $Path | Out-Null
}

# Resolve the exact case directory once. Do not nest a second CaseId beneath it.
if (-not $CaseId) { $CaseId = 'IR-' + (Get-Date -Format 'yyyyMMdd-HHmmss') }
if (-not $CaseDir) { $CaseDir = Join-Path $EvidenceRoot $CaseId }
$CaseDir = [System.IO.Path]::GetFullPath($CaseDir)
New-Directory $CaseDir
if (Test-Path -LiteralPath $CaseDir) {
    if ((Get-ChildItem -LiteralPath $CaseDir -Force -ErrorAction SilentlyContinue | Measure-Object).Count -gt 0) {
        throw "Case directory is not empty: $CaseDir"
    }
}

foreach ($name in @('00_meta','01_memory','02_system','03_process','04_network','05_persistence','06_logs','07_files')) {
    New-Directory (Join-Path $CaseDir $name)
}
$script:LogPath = Join-Path $CaseDir '00_meta\collection.log'

$start = Get-Date
Write-Log "COL start; case=$CaseId; host=$env:COMPUTERNAME; user=$env:USERNAME" Cyan
Write-Log "Output: $CaseDir" Cyan

# Memory is first because it is the most volatile evidence.
$memoryPath = Join-Path $CaseDir '01_memory\mem.raw'
$memoryLog = Join-Path $CaseDir '01_memory\memory.log'
if ($SkipMemory) {
    Write-Log 'SKIP memory capture requested by operator' Yellow
} else {
    $winpmem = @(
        (Join-Path $PSScriptRoot 'tools\winpmem_mini_x64_rc2.exe'),
        (Join-Path $PSScriptRoot 'winpmem_mini_x64_rc2.exe')
    ) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    if ($winpmem) {
        Write-Log "Memory capture: $winpmem" Cyan
        try {
            & $winpmem $memoryPath *> $memoryLog
            $rc = $LASTEXITCODE
            if (-not (Test-Path -LiteralPath $memoryPath)) { throw "mem.raw was not created (exit code $rc)" }
            Write-Log "OK  memory capture; exit code $rc" Green
        } catch {
            $reason = "FAIL memory capture: $($_.Exception.Message)"
            $script:Failures.Add($reason)
            Write-Log $reason Red
        }
    } else {
        $reason = 'FAIL memory capture: WinPmem not found under 01_collection\tools'
        $script:Failures.Add($reason)
        Write-Log $reason Red
    }
}

$system = Join-Path $CaseDir '02_system'
Invoke-Capture 'systeminfo' { systeminfo } (Join-Path $system 'systeminfo.txt')
Invoke-Capture 'hostname' { hostname } (Join-Path $system 'hostname.txt')
Invoke-Capture 'whoami /all' { whoami /all } (Join-Path $system 'whoami.txt')
Invoke-Capture 'computerinfo' { Get-ComputerInfo -Property CsName,OsName,OsVersion,OsBuildNumber,WindowsProductName,WindowsVersion,OsArchitecture } (Join-Path $system 'computerinfo.txt')
Invoke-Capture 'hotfix' { Get-HotFix } (Join-Path $system 'hotfix.txt')
Invoke-Capture 'time status' { w32tm /query /status } (Join-Path $system 'time_status.txt')

$process = Join-Path $CaseDir '03_process'
Invoke-Capture 'process list with command line' {
    Get-CimInstance Win32_Process | Select-Object ProcessId,ParentProcessId,Name,ExecutablePath,CommandLine,CreationDate |
        Export-Csv -NoTypeInformation -Encoding UTF8 -LiteralPath (Join-Path $process 'processes.csv')
} $null
Invoke-Capture 'services' {
    Get-CimInstance Win32_Service | Select-Object Name,DisplayName,State,StartMode,StartName,PathName |
        Export-Csv -NoTypeInformation -Encoding UTF8 -LiteralPath (Join-Path $process 'services.csv')
} $null
Invoke-Capture 'task list' { tasklist /svc } (Join-Path $process 'tasklist_svc.txt')
Invoke-Capture 'scheduled task list' { schtasks /query /fo LIST /v } (Join-Path $process 'scheduled_tasks.txt')

$network = Join-Path $CaseDir '04_network'
Invoke-Capture 'netstat with owners' { netstat -anob } (Join-Path $network 'netstat_anob.txt')
Invoke-Capture 'DNS cache' { ipconfig /displaydns } (Join-Path $network 'dns_cache.txt')
Invoke-Capture 'ARP cache' { arp -a } (Join-Path $network 'arp.txt')
Invoke-Capture 'routes' { route print } (Join-Path $network 'routes.txt')
Invoke-Capture 'firewall profiles' { netsh advfirewall show allprofiles } (Join-Path $network 'firewall_profiles.txt')
Invoke-Capture 'RDP sessions' { query session } (Join-Path $network 'rdp_sessions.txt')
Invoke-Capture 'SMB connections' { Get-SmbConnection } (Join-Path $network 'smb_connections.txt')

$persistence = Join-Path $CaseDir '05_persistence'
foreach ($key in @(
    'HKLM\Software\Microsoft\Windows\CurrentVersion\Run',
    'HKLM\Software\Microsoft\Windows\CurrentVersion\RunOnce',
    'HKCU\Software\Microsoft\Windows\CurrentVersion\Run',
    'HKCU\Software\Microsoft\Windows\CurrentVersion\RunOnce',
    'HKLM\System\CurrentControlSet\Services',
    'HKLM\Software\Microsoft\Windows NT\CurrentVersion\Winlogon'
)) {
    $safe = $key -replace '[\\ ]', '_'
    Invoke-Capture "registry $key" { reg.exe export $key (Join-Path $persistence "registry_$safe.reg") /y } $null
}
Invoke-Capture 'WMI event consumers' { Get-CimInstance -Namespace root/subscription -ClassName __EventConsumer | Export-Csv -NoTypeInformation -Encoding UTF8 -LiteralPath (Join-Path $persistence 'wmi_consumers.csv') } $null
Invoke-Capture 'WMI event filters' { Get-CimInstance -Namespace root/subscription -ClassName __EventFilter | Export-Csv -NoTypeInformation -Encoding UTF8 -LiteralPath (Join-Path $persistence 'wmi_filters.csv') } $null

$logs = Join-Path $CaseDir '06_logs'
foreach ($log in @('Security','System','Application','Microsoft-Windows-PowerShell/Operational','Microsoft-Windows-Sysmon/Operational','Microsoft-Windows-Windows Defender/Operational','Microsoft-Windows-TaskScheduler/Operational')) {
    $safe = $log -replace '[/\\:]', '_'
    Invoke-Capture "event log $log" { wevtutil.exe epl $log (Join-Path $logs "$safe.evtx") } $null
}
Invoke-Capture 'recent security events' {
    Get-WinEvent -FilterHashtable @{ LogName='Security'; StartTime=(Get-Date).AddDays(-$LookbackDays) } |
        Select-Object TimeCreated,Id,ProviderName,Message |
        Export-Csv -NoTypeInformation -Encoding UTF8 -LiteralPath (Join-Path $logs "security_${LookbackDays}d.csv")
} $null

$files = Join-Path $CaseDir '07_files'
$prefetch = Join-Path $files 'prefetch'
New-Directory $prefetch
Invoke-Capture 'Prefetch copy' { Copy-Item -LiteralPath "$env:SystemRoot\Prefetch\*.pf" -Destination $prefetch -Force -ErrorAction SilentlyContinue } $null

$users = @(Get-ChildItem -LiteralPath 'C:\Users' -Directory -Force -ErrorAction SilentlyContinue)
foreach ($u in $users) {
    $history = Join-Path $u.FullName 'AppData\Roaming\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt'
    if (Test-Path -LiteralPath $history) { Copy-Item -LiteralPath $history -Destination (Join-Path $files "powershell_history_$($u.Name).txt") -Force }
    $ssh = Join-Path $u.FullName '.ssh\known_hosts'
    if (Test-Path -LiteralPath $ssh) { Copy-Item -LiteralPath $ssh -Destination (Join-Path $files "ssh_known_hosts_$($u.Name)") -Force }
    foreach ($browser in @(
        @{ Name='chrome'; Path='AppData\Local\Google\Chrome\User Data\Default\History' },
        @{ Name='edge'; Path='AppData\Local\Microsoft\Edge\User Data\Default\History' }
    )) {
        $source = Join-Path $u.FullName $browser.Path
        if (Test-Path -LiteralPath $source) { Copy-Item -LiteralPath $source -Destination (Join-Path $files "$($browser.Name)_history_$($u.Name).db") -Force }
    }
}

$cutoff = (Get-Date).AddDays(-$LookbackDays)
foreach ($root in @('C:\Windows\Temp','C:\Temp',$env:TEMP)) {
    if (Test-Path -LiteralPath $root) {
        Invoke-Capture "recent files $root" {
            Get-ChildItem -LiteralPath $root -File -Force -ErrorAction SilentlyContinue |
                Where-Object LastWriteTime -ge $cutoff |
                Select-Object FullName,Length,CreationTime,LastWriteTime |
                Export-Csv -NoTypeInformation -Encoding UTF8 -LiteralPath (Join-Path $files (('recent_' + ($root -replace '[:\\]','_')) + '.csv'))
        } $null
    }
}

$end = Get-Date
$metadata = [ordered]@{
    CaseId = $CaseId
    Hostname = $env:COMPUTERNAME
    Operator = "$env:USERDOMAIN\$env:USERNAME"
    StartedAt = $start.ToUniversalTime().ToString('o')
    FinishedAt = $end.ToUniversalTime().ToString('o')
    LookbackDays = $LookbackDays
    MemoryPath = if (Test-Path -LiteralPath $memoryPath) { '01_memory\mem.raw' } else { $null }
    FailureCount = $script:Failures.Count
    Failures = @($script:Failures)
}
$metadata | ConvertTo-Json -Depth 4 | Set-Content -Encoding UTF8 -LiteralPath (Join-Path $CaseDir '00_meta\collection.json')
$manifestPath = Join-Path $CaseDir '00_meta\sha256_manifest.csv'
Write-Log "COL finished; preparing hash manifest; failures=$($script:Failures.Count)" Cyan
$manifest = foreach ($file in Get-ChildItem -LiteralPath $CaseDir -Recurse -File | Where-Object FullName -ne $manifestPath) {
    $hash = Get-FileHash -Algorithm SHA256 -LiteralPath $file.FullName
    [PSCustomObject]@{
        RelativePath = $file.FullName.Substring($CaseDir.Length).TrimStart('\\')
        SizeBytes = $file.Length
        LastWriteTimeUtc = $file.LastWriteTimeUtc.ToString('o')
        SHA256 = $hash.Hash.ToLowerInvariant()
    }
}
$manifest | Sort-Object RelativePath | Export-Csv -NoTypeInformation -Encoding UTF8 -LiteralPath $manifestPath
Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ssK')] COL hash manifest created; files=$(@($manifest).Count)" -ForegroundColor Cyan
if ($script:Failures.Count -gt 0) { exit 2 }
exit 0

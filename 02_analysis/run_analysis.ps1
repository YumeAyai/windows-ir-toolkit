<#[
.SYNOPSIS
    ANA: verify a collection case and run a small Volatility 3 triage set.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$EvidenceDir,
    [string]$OutputDir,
    [string]$VolatilityPath,
    [string]$PythonPath,
    [string]$CapaPath,
    [string]$SamplePath,
    [switch]$SkipVolatility
)

$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'
$EvidenceDir = [System.IO.Path]::GetFullPath((Resolve-Path -LiteralPath $EvidenceDir -ErrorAction Stop))
if (-not $OutputDir) { $OutputDir = Join-Path (Split-Path $EvidenceDir -Parent) ((Split-Path $EvidenceDir -Leaf) + '-analysis') }
$OutputDir = [System.IO.Path]::GetFullPath($OutputDir)
$metaDir = Join-Path $OutputDir '00_meta'
$volDir = Join-Path $OutputDir 'volatility'
New-Item -ItemType Directory -Force -Path $metaDir,$volDir | Out-Null
$logPath = Join-Path $metaDir 'analysis.log'

function Log([string]$Message, [ConsoleColor]$Color = [ConsoleColor]::Gray) {
    $line = "[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ssK'), $Message
    Write-Host $line -ForegroundColor $Color
    Add-Content -LiteralPath $logPath -Value $line -Encoding UTF8
}

Log "ANA start; evidence=$EvidenceDir" Cyan
$manifestPath = Join-Path $EvidenceDir '00_meta\sha256_manifest.csv'
if (-not (Test-Path -LiteralPath $manifestPath)) {
    Log 'Collection manifest not found; collection likely stopped before finalization. Check 00_meta\collection.log and rerun collection after preserving this case.' Red
    exit 1
}
Copy-Item -LiteralPath $manifestPath -Destination (Join-Path $metaDir 'input_manifest.csv') -Force

$verification = foreach ($row in Import-Csv -LiteralPath $manifestPath) {
    $path = Join-Path $EvidenceDir $row.RelativePath
    $exists = Test-Path -LiteralPath $path
    $actual = if ($exists) { (Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash.ToLowerInvariant() } else { $null }
    [PSCustomObject]@{
        RelativePath = $row.RelativePath
        ExpectedSHA256 = $row.SHA256
        ActualSHA256 = $actual
        Status = if (-not $exists) { 'MISSING' } elseif ($actual -eq $row.SHA256) { 'MATCH' } else { 'MISMATCH' }
    }
}
$verification | Export-Csv -NoTypeInformation -Encoding UTF8 -LiteralPath (Join-Path $metaDir 'hash_verification.csv')
$bad = @($verification | Where-Object Status -ne 'MATCH')
if ($bad.Count -gt 0) { Log "Hash verification: $($bad.Count) problem(s); preserve the original and investigate transfer." Yellow }
else { Log 'Hash verification: all collection files match.' Green }

$memoryPath = Join-Path $EvidenceDir '01_memory\mem.raw'
if (-not (Test-Path -LiteralPath $memoryPath)) {
    Log 'Memory image not found; filesystem triage results can still be reviewed.' Yellow
} else {
    Log "Memory image: $memoryPath" Cyan
}

if ($SkipVolatility -or -not (Test-Path -LiteralPath $memoryPath)) {
    Log 'Volatility triage skipped.' Yellow
    exit 0
}

# Resolve the runtime without assuming a particular installation layout.
$volExe = $null
$volPy = $null
$python = $PythonPath
if ($VolatilityPath -and (Test-Path -LiteralPath $VolatilityPath)) {
    if ([IO.Path]::GetExtension($VolatilityPath) -ieq '.py') { $volPy = (Resolve-Path -LiteralPath $VolatilityPath).Path }
    else { $volExe = (Resolve-Path -LiteralPath $VolatilityPath).Path }
}
if (-not $volExe) {
    $bundledVol = Join-Path $PSScriptRoot 'tools\vol.exe'
    if (Test-Path -LiteralPath $bundledVol) { $volExe = $bundledVol }
}
if (-not $python) {
    $bundledPython = Join-Path $PSScriptRoot 'python\python.exe'
    if (Test-Path -LiteralPath $bundledPython) { $python = $bundledPython }
}
if (-not $python) {
    $pythonCmd = Get-Command python.exe -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $pythonCmd) { $pythonCmd = Get-Command python3 -ErrorAction SilentlyContinue | Select-Object -First 1 }
    if ($pythonCmd) { $python = $pythonCmd.Source }
}
if (-not $volExe -and -not $volPy) {
    $bundledVolPy = Join-Path $PSScriptRoot 'tools\vol.py'
    if (Test-Path -LiteralPath $bundledVolPy) { $volPy = $bundledVolPy }
}

if (-not $volExe -and -not $volPy -and -not $python) {
    Log 'No Volatility executable or Python runtime found. Place vol.exe in 02_analysis\tools or pass -VolatilityPath.' Yellow
    exit 0
}

function Invoke-Volatility([string]$Plugin, [string]$Destination) {
    $volArgs = @('-f', $memoryPath, $Plugin)
    Log "Run: $Plugin" Cyan
    try {
        if ($volExe) { & $volExe @volArgs 2>&1 | Out-File -LiteralPath $Destination -Encoding UTF8 }
        elseif ($volPy) { & $python $volPy @volArgs 2>&1 | Out-File -LiteralPath $Destination -Encoding UTF8 }
        else { & $python -m volatility3 @volArgs 2>&1 | Out-File -LiteralPath $Destination -Encoding UTF8 }
        $rc = $LASTEXITCODE
        if ($rc -and $rc -ne 0) { Log "WARN $Plugin returned exit code $rc" Yellow }
        else { Log "OK  $Plugin" Green }
    } catch { Log "FAIL $Plugin : $($_.Exception.Message)" Yellow }
}

foreach ($plugin in @('windows.info','windows.pslist','windows.pstree','windows.netscan','windows.cmdline','windows.malfind')) {
    $safe = $plugin.Replace('.','_')
    Invoke-Volatility $plugin (Join-Path $volDir "$safe.txt")
}

if (-not $CapaPath) { $CapaPath = Join-Path $PSScriptRoot 'tools\capa\capa.exe' }
if ($SamplePath -and (Test-Path -LiteralPath $CapaPath) -and (Test-Path -LiteralPath $SamplePath -PathType Leaf)) {
    $capaOutput = Join-Path $OutputDir 'capa.txt'
    Log "Run capa: $SamplePath" Cyan
    try {
        & $CapaPath $SamplePath 2>&1 | Out-File -LiteralPath $capaOutput -Encoding UTF8
        Log 'OK  capa' Green
    } catch { Log "FAIL capa : $($_.Exception.Message)" Yellow }
} elseif ($SamplePath) {
    Log 'capa skipped: provide a valid executable with -CapaPath or place capa.exe in 02_analysis\tools\capa.' Yellow
}

Log "ANA finished; output=$OutputDir" Cyan
exit 0

[CmdletBinding()]
param(
    [string]$OutputDir = (Join-Path $PSScriptRoot 'windows'),
    [string]$Url = 'https://downloads.volatilityfoundation.org/volatility3/symbols/windows.zip'
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
$zip = Join-Path ([IO.Path]::GetTempPath()) ('volatility-symbols-' + [guid]::NewGuid().ToString('N') + '.zip')
try {
    Write-Host "Downloading symbols: $Url"
    Invoke-WebRequest -Uri $Url -OutFile $zip -UseBasicParsing -TimeoutSec 180
    Expand-Archive -LiteralPath $zip -DestinationPath $OutputDir -Force
    Write-Host "Symbols extracted to $OutputDir" -ForegroundColor Green
} finally {
    if (Test-Path -LiteralPath $zip) { Remove-Item -LiteralPath $zip -Force }
}

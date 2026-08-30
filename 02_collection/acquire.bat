@echo off
REM ============================================================
REM Windows IR one-click acquirer
REM Must run as Administrator!
REM ============================================================

setlocal enabledelayedexpansion

echo.
echo ============================================================
echo   IR Toolkit - Incident Response One-Click
echo   Time: %date% %time%
echo ============================================================
echo.

REM Check admin rights
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [!] Requires Administrator. Right-click this script - Run as administrator.
    pause
    exit /b 1
)

REM 1. Create evidence directory
set EVDIR=C:\evidence
set CASEDIR=%EVDIR%\IR-%date:~0,4%%date:~5,2%%date:~8,2%-%time:~0,2%%time:~3,2%%time:~6,2%
set CASEDIR=%CASEDIR: =0%
mkdir "%CASEDIR%" 2>nul
echo [+] Case dir: %CASEDIR%

REM 2. Collect artifacts
echo [+] Collecting artifacts...
powershell -ExecutionPolicy Bypass -File "%~dp0collect_artifacts.ps1" -OutputDir "%CASEDIR%" %*

REM 3. Dump memory
echo [+] Dumping memory (takes several minutes depending on RAM size)...
if exist "%~dp001_acquire\winpmem_mini_x64_rc2.exe" (
    "%~dp001_acquire\winpmem_mini_x64_rc2.exe" "%CASEDIR%\mem.raw"
) else (
    echo [!] winpmem not found. Please copy 01_acquire\winpmem_mini_x64_rc2.exe to toolkit root.
)

REM 4. Compute hash
echo [+] Computing SHA256...
powershell -Command "Get-FileHash -Algorithm SHA256 '%CASEDIR%\mem.raw' | Out-File '%CASEDIR%\mem.raw.sha256.txt'"

echo.
echo ============================================================
echo   Done!
echo   Case: %CASEDIR%
echo   Next: compress entire dir, transfer to analysis workstation
echo ============================================================
pause

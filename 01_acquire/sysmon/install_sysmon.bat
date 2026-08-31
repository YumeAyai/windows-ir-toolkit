@echo off
REM ============================================================
REM Sysmon one-click installer (for IR scenarios)
REM Must run as Administrator
REM ============================================================

setlocal enabledelayedexpansion

REM Stage 0: auto-elevate
net session >nul 2>&1
if errorlevel 1 (
    echo [WARN] Need admin. Requesting elevation...
    powershell -NoProfile -Command "Start-Process cmd.exe -ArgumentList '/c \"\"%~f0\"\"' -Verb RunAs"
    exit /b
)

set "TOOLKIT_ROOT=%~dp0..\.."

echo.
echo ============================================================
echo   Sysmon Installer (IR Edition)
echo   Toolkit root: %TOOLKIT_ROOT%
echo ============================================================
echo.

REM Check if already installed
sc query Sysmon64 >nul 2>&1
if not errorlevel 1 (
    echo [i] Sysmon already installed. Skipping.
    sc query Sysmon64 | findstr STATE
    goto END
)

set "WORKDIR=%TEMP%\SysmonInstall"
if not exist "%WORKDIR%" mkdir "%WORKDIR%"

REM Stage 1: Find Sysmon (prefer zip-bundled, fallback to download)
set "LOCAL_SYSMON=%~dp0Sysmon64.exe"
set "LOCAL_ZIP=%~dp0Sysmon.zip"
if exist "%LOCAL_SYSMON%" (
    echo [i] Found Sysmon64.exe bundled in zip. Skipping download.
    set "SYSMON_EXE=%LOCAL_SYSMON%"
    goto SKIP_DOWNLOAD
)

echo [+] Downloading Sysmon...
set "SYSMON_URL=https://download.sysinternals.com/files/Sysmon.zip"
set "ZIP_PATH=%WORKDIR%\Sysmon.zip"
powershell -NoProfile -Command "try { Invoke-WebRequest -Uri '%SYSMON_URL%' -OutFile '%ZIP_PATH%' -UseBasicParsing -TimeoutSec 60 } catch { exit 1 }"
if errorlevel 1 (
    echo [ERROR] Download failed (network issue?)
    echo         URL: %SYSMON_URL%
    goto END
)
echo     [OK] Downloaded Sysmon.zip
:SKIP_DOWNLOAD

REM Stage 2: Extract if we have a zip
if exist "%LOCAL_ZIP%" (
    echo [+] Extracting bundled Sysmon.zip...
    powershell -NoProfile -Command "Expand-Archive -Path '%LOCAL_ZIP%' -DestinationPath '%WORKDIR%' -Force"
)
if not defined SYSMON_EXE (
    echo [+] Extracting downloaded Sysmon.zip...
    powershell -NoProfile -Command "Expand-Archive -Path '%WORKDIR%\Sysmon.zip' -DestinationPath '%WORKDIR%' -Force"
)

REM Stage 3: Find Sysmon binary
if not defined SYSMON_EXE (
    if exist "%WORKDIR%\Sysmon64.exe" set "SYSMON_EXE=%WORKDIR%\Sysmon64.exe"
)
if not defined SYSMON_EXE (
    if exist "%WORKDIR%\Sysmon.exe" set "SYSMON_EXE=%WORKDIR%\Sysmon.exe"
)
if not exist "%SYSMON_EXE%" (
    echo [ERROR] Sysmon executable not found.
    goto END
)

REM Stage 4: Install
set "CONFIG=%TOOLKIT_ROOT%\01_acquire\sysmon\sysmon_config.xml"
if not exist "%CONFIG%" (
    echo [WARN] Config not found: %CONFIG%
    set "CONFIG="
)

echo [+] Installing Sysmon from: %SYSMON_EXE%
if defined CONFIG echo     Config: %CONFIG%
"%SYSMON_EXE%" -accepteula -i "%CONFIG%"
if errorlevel 1 (
    echo [ERROR] Install failed.
    goto END
)
echo     [OK] Installed.

sc start Sysmon64 >nul 2>&1
echo [+] Started Sysmon service.
echo     [OK]

:END
echo.
echo ============================================================
echo   Sysmon log path:
echo     Applications and Services Logs / Microsoft / Windows / Sysmon / Operational
echo.
echo   collect_artifacts.ps1 will auto-export this log to:
echo     C:\evidence\IR-*\05_logs\Microsoft-Windows-Sysmon_Operational.evtx
echo ============================================================
pause

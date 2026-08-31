@echo off
setlocal

REM Sysmon is an optional pre-incident preparation step.
net session >nul 2>&1
if errorlevel 1 (
    echo [!] 需要管理员权限，正在请求提权...
    powershell.exe -NoProfile -Command "Start-Process -FilePath '%ComSpec%' -ArgumentList '/c', '""%~f0""' -Verb RunAs"
    exit /b 0
)

set "TOOLKIT_ROOT=%~dp0..\.."
set "CONFIG=%TOOLKIT_ROOT%\01_collection\sysmon\sysmon_config.xml"
set "WORKDIR=%TEMP%\IR-Sysmon"
set "ZIP=%WORKDIR%\Sysmon.zip"
set "SYS=%WORKDIR%\Sysmon64.exe"
if not exist "%WORKDIR%" mkdir "%WORKDIR%"

if exist "%~dp0Sysmon64.exe" set "SYS=%~dp0Sysmon64.exe"
if not exist "%SYS%" if exist "%~dp0Sysmon.zip" (
    powershell.exe -NoProfile -Command "Expand-Archive -LiteralPath '%~dp0Sysmon.zip' -DestinationPath '%WORKDIR%' -Force"
)
if not exist "%SYS%" (
    echo [+] 正在从 Microsoft 下载 Sysmon...
    powershell.exe -NoProfile -Command "Invoke-WebRequest -Uri 'https://download.sysinternals.com/files/Sysmon.zip' -OutFile '%ZIP%' -UseBasicParsing -TimeoutSec 120"
    if errorlevel 1 (
        echo [ERROR] Sysmon 下载失败。
        exit /b 1
    )
    powershell.exe -NoProfile -Command "Expand-Archive -LiteralPath '%ZIP%' -DestinationPath '%WORKDIR%' -Force"
)
if not exist "%SYS%" (
    echo [ERROR] 找不到 Sysmon64.exe。
    exit /b 1
)

echo [+] 安装 Sysmon...
"%SYS%" -accepteula -i "%CONFIG%"
if errorlevel 1 (
    echo [ERROR] Sysmon 安装失败。
    exit /b 1
)
echo [OK] Sysmon 已安装。日志由 collect.ps1 导出到 06_logs。
pause

@echo off
REM ============================================================
REM Sysmon 一键安装脚本(应急响应版)
REM 自动从 Microsoft 官网下载,应用推荐配置,安装为服务
REM 必须以管理员权限运行
REM ============================================================

setlocal enabledelayedexpansion

REM 阶段 0: 自动提权
net session >nul 2>&1
if errorlevel 1 (
    echo [!] 需要管理员权限,自动请求提权...
    powershell -NoProfile -Command "Start-Process cmd.exe -ArgumentList '/c \"\"%~f0\"\"' -Verb RunAs"
    exit /b
)

REM 工具根目录
set "TOOLKIT_ROOT=%~dp0..\.."

echo.
echo ============================================================
echo   Sysmon 安装脚本 (应急响应版)
echo   工具根: %TOOLKIT_ROOT%
echo ============================================================
echo.

REM 检查 sysmon 状态
sc query Sysmon64 >nul 2>&1
if not errorlevel 1 (
    echo [i] Sysmon 已安装,跳过下载和安装
    sc query Sysmon64 | findstr STATE
    goto END
)

REM 工作目录
set "WORKDIR=%TEMP%\SysmonInstall"
if not exist "%WORKDIR%" mkdir "%WORKDIR%"

REM 阶段 1: 下载 Sysmon
echo [+] 下载 Sysmon...
set "SYSMON_URL=https://download.sysinternals.com/files/Sysmon.zip"
set "ZIP_PATH=%WORKDIR%\Sysmon.zip"
powershell -NoProfile -Command "try { Invoke-WebRequest -Uri '%SYSMON_URL%' -OutFile '%ZIP_PATH%' -UseBasicParsing -TimeoutSec 60 } catch { exit 1 }"
if errorlevel 1 (
    echo [ERROR] 下载失败,网络问题?
    echo         URL: %SYSMON_URL%
    goto END
)
echo     [OK] 已下载 Sysmon.zip

REM 阶段 2: 解压
echo [+] 解压...
powershell -NoProfile -Command "Expand-Archive -Path '%ZIP_PATH%' -DestinationPath '%WORKDIR%' -Force"
echo     [OK] 已解压到 %WORKDIR%

REM 阶段 3: 复制配置(如果存在)
set "CONFIG=%TOOLKIT_ROOT%\01_acquire\sysmon\sysmon_config.xml"
if not exist "%CONFIG%" (
    echo [WARN] 找不到推荐配置 %CONFIG%
    set "CONFIG=%WORKDIR%\.default"
) else (
    echo [i] 使用配置: %CONFIG%
)

REM 阶段 4: 安装(64 位)
set "SYSMON_EXE=%WORKDIR%\Sysmon64.exe"
if not exist "%SYSMON_EXE%" (
    set "SYSMON_EXE=%WORKDIR%\Sysmon.exe"
)
if not exist "%SYSMON_EXE%" (
    echo [ERROR] 找不到 Sysmon 可执行文件
    goto END
)

echo [+] 安装 Sysmon...
"%SYSMON_EXE%" -accepteula -i "%CONFIG%"
if errorlevel 1 (
    echo [ERROR] 安装失败
    goto END
)
echo     [OK] 已安装

sc start Sysmon64 >nul 2>&1
echo [+] 启动 Sysmon 服务...
echo     [OK]

:END
echo.
echo ============================================================
echo   Sysmon 日志路径:
echo     应用程序和服务日志 / Microsoft / Windows / Sysmon / Operational
echo.
echo   应急响应时,collect_artifacts.ps1 已自动导出此日志到:
echo     C:\evidence\IR-*\05_logs\Microsoft-Windows-Sysmon_Operational.evtx
echo ============================================================
pause

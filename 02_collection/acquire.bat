@echo off
REM ============================================================
REM Windows 应急响应一键启动(针对 Cobalt Strike / RAT)
REM 必须以管理员权限运行(脚本会自动检测并请求提权)
REM ============================================================

REM 阶段 0: 自动提权
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [!] 需要管理员权限,自动请求提权...
    REM 修复: 使用 PowerShell 的 -Command 块并正确转义路径,防止路径含空格时提权失败
    powershell -NoProfile -Command "Start-Process cmd.exe -ArgumentList '/c \"\"%~f0\"\"' -Verb RunAs"
    exit /b
)

REM 修复: 必须在提权检查之后、使用 !var! 之前开启延迟展开
setlocal enabledelayedexpansion

REM 工具包根目录(从 02_collection\ 回到仓根)
set "TOOLKIT_ROOT=%~dp0.."

echo.
echo ============================================================
echo   IR Toolkit - 应急响应一键启动
echo   时间: %date% %time%
echo   工具根: %TOOLKIT_ROOT%
echo ============================================================
echo.

REM 1. 创建证据目录(用引号包裹,防空格路径)
set "EVDIR=C:\evidence"
if not exist "%EVDIR%" mkdir "%EVDIR%"

REM 时间戳处理(中文系统 date 格式可能含空格或斜杠,统一替换)
set "TS=%date:~0,4%%date:~5,2%%date:~8,2%_%time:~0,2%%time:~3,2%%time:~6,2%"
set "TS=!TS: =0!"
set "TS=!TS:/=!"
set "TS=!TS:\=!"
set "CASEDIR=%EVDIR%\IR-!TS!"
mkdir "!CASEDIR!" 2>nul
echo [+] 案件目录: !CASEDIR!

REM 2. 收集 artifacts(ps1 自身也会提权,这里直接调)
echo [+] 收集 artifacts(5-30 分钟)...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0collect_artifacts.ps1" -OutputDir "!CASEDIR!"
if errorlevel 1 (
    echo [!] collect_artifacts.ps1 失败,继续执行内存 dump
)

REM 3. Dump 内存
set "WINPMEM=%TOOLKIT_ROOT%\01_acquire\winpmem_mini_x64_rc2.exe"
echo [+] Dump 内存(等几分钟到几十分钟)...
if exist "%WINPMEM%" (
    "%WINPMEM%" "!CASEDIR!\mem.raw"
) else (
    echo [!] 找不到 winpmem: %WINPMEM%
    echo     请从 GitHub Releases 下载完整 ir-toolkit.zip,或跑 install_tools.ps1
)

REM 4. 算 hash(mem.raw 可能不存在,先检查)
echo [+] 计算 SHA256...
if exist "!CASEDIR!\mem.raw" (
    powershell -NoProfile -Command "Get-FileHash -Algorithm SHA256 '!CASEDIR!\mem.raw' | Out-File '!CASEDIR!\mem.raw.sha256.txt' -Encoding utf8"
) else (
    echo [!] mem.raw 不存在,跳过 hash 计算
)

echo.
echo ============================================================
echo   完成!
echo   案件目录: !CASEDIR!
echo.
echo   下一步:
echo   1. 拔 U 盘
echo   2. 压缩整个 !CASEDIR! 目录
echo   3. 安全传回分析机
echo ============================================================
pause
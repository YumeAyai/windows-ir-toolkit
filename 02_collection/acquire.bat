@echo off
REM ============================================================
REM Windows 应急响应一键启动(针对 Cobalt Strike / RAT)
REM 必须以管理员权限运行!
REM ============================================================

setlocal enabledelayedexpansion

echo.
echo ============================================================
echo   IR Toolkit - 应急响应一键启动
echo   时间: %date% %time%
echo ============================================================
echo.

REM 检权限
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [!] 需要管理员权限!右键此脚本 → "以管理员身份运行"
    pause
    exit /b 1
)

REM 1. 创建证据目录
set EVDIR=C:\evidence
set CASEDIR=%EVDIR%\IR-%date:~0,4%%date:~5,2%%date:~8,2%-%time:~0,2%%time:~3,2%%time:~6,2%
set CASEDIR=%CASEDIR: =0%
mkdir "%CASEDIR%" 2>nul
echo [+] 案件目录: %CASEDIR%

REM 2. 收集 artifacts
echo [+] 收集系统信息...
powershell -ExecutionPolicy Bypass -File "%~dp0collect_artifacts.ps1" -OutputDir "%CASEDIR%" %*

REM 3. Dump 内存
echo [+] Dump 内存(这一步会等几分钟到几十分钟,取决于内存大小)...
if exist "%~dp001_acquire\winpmem_mini_x64_rc2.exe" (
    "%~dp001_acquire\winpmem_mini_x64_rc2.exe" "%CASEDIR%\mem.raw"
) else (
    echo [!] 找不到 winpmem,请先把 01_acquire\winpmem_mini_x64_rc2.exe 放到同目录
)

REM 4. 算 hash
echo [+] 计算 hash...
powershell -Command "Get-FileHash -Algorithm SHA256 '%CASEDIR%\mem.raw' | Out-File '%CASEDIR%\mem.raw.sha256.txt'"

echo.
echo ============================================================
echo   完成!
echo   案件: %CASEDIR%
echo   下一步: 压缩整个目录,安全传输到分析机
echo ============================================================
pause

@echo off
setlocal

REM 01_collection is the only live-response entry point.
net session >nul 2>&1
if errorlevel 1 (
    echo [!] 需要管理员权限，正在请求提权...
    powershell.exe -NoProfile -Command "Start-Process -FilePath '%ComSpec%' -ArgumentList '/c', '""%~f0""' -Verb RunAs"
    exit /b 0
)

set "SCRIPT=%~dp0collect.ps1"
if not exist "%SCRIPT%" (
    echo [ERROR] 找不到采集脚本：%SCRIPT%
    pause
    exit /b 1
)

echo.
echo ============================================================
echo   01_collection - Windows Incident Response Collection
echo ============================================================
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" %*
set "RC=%errorlevel%"
echo.
if "%RC%"=="0" echo [OK] 采集完成。请将完整案件目录复制到分析机。
if not "%RC%"=="0" echo [WARN] 采集结束，退出码 %RC%。请查看 00_meta\collection.log。
pause
exit /b %RC%

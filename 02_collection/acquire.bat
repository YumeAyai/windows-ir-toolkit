@echo off
REM ============================================================
REM Windows 应急响应一键启动(针对 Cobalt Strike / RAT)
REM 必须以管理员权限运行(脚本会自动检测并请求提权)
REM ============================================================

REM 不依赖 delayed expansion,所有变量在 set 后立即可用
REM 所有路径加引号,防空格 / 中文路径

REM ----- 阶段 0: 自动提权 -----
net session >nul 2>&1
if errorlevel 1 (
    echo [WARN] Not running as Administrator. Requesting elevation...
    powershell -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

REM ----- 工具包根目录 -----
REM bat 在 02_collection\ 下,父目录就是工具根
set "TOOLKIT_ROOT=%~dp0.."

REM ----- 证据目录 + 时间戳 -----
set "EVDIR=C:\evidence"
if not exist "%EVDIR%" mkdir "%EVDIR%"
set "YEAR=%date:~0,4%"
set "MON=%date:~5,2%"
set "DAY=%date:~8,2%"
set "HH=%time:~0,2%"
set "MM=%time:~3,2%"
set "SS=%time:~6,2%"
REM 时分秒的小时可能是 " 1" 前导空格,补 0
if "%HH:~0,1%"==" " set "HH=0%HH:~1,1%"
set "CASEDIR=%EVDIR%\IR-%YEAR%%MON%%DAY%-%HH%%MM%%SS%"
mkdir "%CASEDIR%" 2>nul
echo [+] Case directory: %CASEDIR%
echo.

REM ----- 阶段 1: 收集 artifacts -----
echo [+] Collecting artifacts (5-30 minutes)...
set "PS1=%~dp0collect_artifacts.ps1"
powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%" -OutputDir "%CASEDIR%"
if errorlevel 1 (
    echo [WARN] collect_artifacts.ps1 exited with error. Continue to memory dump...
)

REM ----- 阶段 2: Dump 内存 -----
set "WINPMEM=%TOOLKIT_ROOT%\01_acquire\winpmem_mini_x64_rc2.exe"
echo.
echo [+] Dumping memory (may take several minutes)...
if exist "%WINPMEM%" (
    "%WINPMEM%" "%CASEDIR%\mem.raw"
) else (
    echo [WARN] winpmem not found at: %WINPMEM%
    echo        Download the full ir-toolkit.zip from GitHub Releases, or run install_tools.ps1
)

REM ----- 阶段 3: 算 SHA256 -----
echo.
echo [+] Computing SHA256...
if exist "%CASEDIR%\mem.raw" (
    powershell -NoProfile -Command "Get-FileHash -Algorithm SHA256 '%CASEDIR%\mem.raw' | Out-File '%CASEDIR%\mem.raw.sha256.txt' -Encoding utf8"
) else (
    echo [WARN] mem.raw missing. Skipping hash.
)

echo.
echo ============================================================
echo [OK] Done.
echo     Case: %CASEDIR%
echo.
echo     Next steps:
echo       1. Remove USB drive
echo       2. Compress the entire %CASEDIR% folder
echo       3. Transfer securely to analysis workstation
echo ============================================================
pause

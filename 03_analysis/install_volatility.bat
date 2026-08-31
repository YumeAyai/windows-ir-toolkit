@echo off
REM ============================================================
REM Volatility 3 一键安装 (Windows, 用 Python embeddable)
REM 分析机不需要预装 Python
REM ============================================================

setlocal enabledelayedexpansion

set "SCRIPT_DIR=%~dp0"
set "PYTHON_DIR=%SCRIPT_DIR%python"
set "PYTHON_EXE=%PYTHON_DIR%\python.exe"
set "WHL=%SCRIPT_DIR%volatility3\volatility3-*.whl"

echo.
echo ============================================================
echo   Volatility 3 一键安装 (Windows)
echo ============================================================
echo.

REM 检查 Python embeddable
if not exist "%PYTHON_EXE%" (
    echo [ERROR] 找不到 Python embeddable:%PYTHON_EXE%
    echo         请从 GitHub Releases 重新下载完整 ir-toolkit.zip
    exit /b 1
)
echo [OK] Python embeddable:%PYTHON_EXE%
"%PYTHON_EXE%" --version

REM 检查 wheel
for %%F in ("%WHL%") do set "WHL_FILE=%%~fF"
if not exist "%WHL_FILE%" (
    echo [ERROR] 找不到 vol3 wheel:%WHL%
    exit /b 1
)
echo [OK] Wheel:%WHL_FILE%

REM 装到 embeddable
echo.
echo [+] 装 vol3 到 embeddable Python...
"%PYTHON_EXE%" -m pip install --no-warn-script-location "%WHL_FILE%"
if errorlevel 1 (
    echo [ERROR] pip install 失败
    exit /b 1
)

REM 验证
echo.
echo [+] 验证...
"%PYTHON_EXE%" -m volatility3 --help >nul 2>&1
if errorlevel 1 (
    echo [WARN] vol3 装好但 --help 报错,可能依赖未装全
) else (
    echo [OK] vol3 已可用
)

echo.
echo ============================================================
echo   下一步:
echo     跑 vol3 用 run_volatility.bat,例如:
echo       run_volatility.bat -f mem.raw windows.info
echo       run_volatility.bat -f mem.raw windows.pstree
echo       run_volatility.bat -f mem.raw windows.netscan
echo.
echo   symbols:
echo       .\install_symbols.bat   (从本目录或 05_symbols 跑)
echo ============================================================
pause

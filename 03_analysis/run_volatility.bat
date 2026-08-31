@echo off
REM ============================================================
REM Volatility 3 一键运行 (Windows)
REM 用法: run_volatility.bat -f mem.raw windows.pstree
REM      run_volatility.bat -f mem.raw windows.netscan
REM ============================================================

setlocal

set "SCRIPT_DIR=%~dp0"
set "PYTHON_EXE=%SCRIPT_DIR%python\python.exe"

if not exist "%PYTHON_EXE%" (
    echo [ERROR] Python embeddable 未找到,请先跑 install_volatility.bat
    exit /b 1
)

REM 把 vol3 装到默认 symbols 路径(便于 vol 自动找)
REM 默认 %USERPROFILE%\AppData\Roaming\volatility3\symbols
REM 也加本目录 symbols
set "VOLATILITY3_SYMBOLS_DIR=%SCRIPT_DIR%volatility3\symbols"

"%PYTHON_EXE%" -m volatility3 %*

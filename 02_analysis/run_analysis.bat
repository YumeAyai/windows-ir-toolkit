@echo off
setlocal
if "%~1"=="" (
    echo ”√∑®£∫run_analysis.bat D:\Cases\IR-001
    exit /b 1
)
set "SCRIPT=%~dp0run_analysis.ps1"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" -EvidenceDir "%~1"
exit /b %errorlevel%

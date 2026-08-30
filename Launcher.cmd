@echo off
setlocal
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\Start-Stronghold2AIOverhaul.ps1" %*
set "exitCode=%ERRORLEVEL%"
endlocal & exit /b %exitCode%

@echo off
echo 🚀 AitherZero v1.3.2 - Windows Local Build
pwsh -File "Start-AitherZero.ps1" %*
if %ERRORLEVEL% NEQ 0 pause

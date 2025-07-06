@echo off
REM Aither CLI for Windows
REM Simple wrapper for aither.ps1

REM Try PowerShell 7 first
where pwsh >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0aither.ps1" %*
    exit /b %ERRORLEVEL%
)

REM Try standard PS7 paths
if exist "C:\Program Files\PowerShell\7\pwsh.exe" (
    "C:\Program Files\PowerShell\7\pwsh.exe" -NoProfile -ExecutionPolicy Bypass -File "%~dp0aither.ps1" %*
    exit /b %ERRORLEVEL%
)

REM No PS7 found
echo Aither CLI requires PowerShell 7
echo Install from: https://aka.ms/powershell-release
echo Or run: winget install Microsoft.PowerShell
exit /b 1
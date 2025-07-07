@echo off
REM AitherZero Launcher for Windows
REM Automatically detects and uses PowerShell 7
REM Provides fallback to Windows PowerShell with universal launcher

echo.
echo ===========================================================
echo                    AitherZero Launcher
echo ===========================================================
echo.

REM Try to find PowerShell 7
set PWSH7=
set PWSH_FOUND=0

REM Check standard installation paths
if exist "C:\Program Files\PowerShell\7\pwsh.exe" (
    set "PWSH7=C:\Program Files\PowerShell\7\pwsh.exe"
    set PWSH_FOUND=1
    goto :found
)

if exist "C:\Program Files\PowerShell\7-preview\pwsh.exe" (
    set "PWSH7=C:\Program Files\PowerShell\7-preview\pwsh.exe"
    set PWSH_FOUND=1
    goto :found
)

REM Check additional paths
if exist "%ProgramFiles%\PowerShell\7\pwsh.exe" (
    set "PWSH7=%ProgramFiles%\PowerShell\7\pwsh.exe"
    set PWSH_FOUND=1
    goto :found
)

REM Try to find pwsh in PATH
where pwsh >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    set "PWSH7=pwsh"
    set PWSH_FOUND=1
    goto :found
)

REM PowerShell 7 not found - try fallback
echo [33mPowerShell 7 not found. Trying Windows PowerShell fallback...[0m
echo.

REM Check if Windows PowerShell exists
where powershell >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    REM Use the universal launcher that handles PS7 detection
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0aitherzero.ps1" %*
    exit /b %ERRORLEVEL%
)

:notfound
echo [31mPowerShell 7 is not installed![0m
echo.
echo To install PowerShell 7, run one of these commands:
echo.
echo   [36mwinget install Microsoft.PowerShell[0m
echo.
echo Or download from:
echo   [36mhttps://aka.ms/powershell-release[0m
echo.
echo After installing, run this launcher again.
echo.
pause
exit /b 1

:found
echo [32mFound PowerShell 7[0m
echo Launching AitherZero...
echo.

REM Launch PowerShell 7 with the Start-AitherZero.ps1 script
"%PWSH7%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0Start-AitherZero.ps1" %*

REM Check if the script exited with an error
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [31mAitherZero exited with an error.[0m
    pause
)
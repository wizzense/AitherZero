@echo off
:: AitherZero Universal Windows Launcher
:: Automatically detects and uses PowerShell 7 if available

setlocal enabledelayedexpansion

echo.
echo AitherZero Universal Launcher for Windows
echo =========================================
echo.

:: Check if PowerShell 7 is available
where pwsh >nul 2>&1
if %errorlevel% equ 0 (
    echo Found PowerShell 7, launching AitherZero...
    pwsh -NoProfile -ExecutionPolicy Bypass -File "%~dp0Start-AitherZero.ps1" %*
    exit /b %errorlevel%
)

:: Check common PowerShell 7 installation paths
set "PWSH_PATHS=C:\Program Files\PowerShell\7\pwsh.exe;C:\Program Files\PowerShell\7-preview\pwsh.exe"

for %%P in (%PWSH_PATHS%) do (
    if exist "%%P" (
        echo Found PowerShell 7 at: %%P
        echo Launching AitherZero...
        "%%P" -NoProfile -ExecutionPolicy Bypass -File "%~dp0Start-AitherZero.ps1" %*
        exit /b !errorlevel!
    )
)

:: PowerShell 7 not found, try with Windows PowerShell
echo PowerShell 7 not found, attempting with Windows PowerShell...
echo.
echo Note: AitherZero requires PowerShell 7 for full functionality.
echo The launcher will attempt to auto-install or provide instructions.
echo.

:: Launch with Windows PowerShell (it will handle PS7 detection/installation)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Start-AitherZero.ps1" %*

exit /b %errorlevel%
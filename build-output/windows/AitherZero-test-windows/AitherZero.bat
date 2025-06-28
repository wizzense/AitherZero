@echo off
echo.
echo 🚀 AitherZero v0.11.0 - Windows Quick Start
echo ================================================
echo.
echo Starting AitherZero with enhanced compatibility...
echo This launcher handles PowerShell version detection automatically.
echo.

REM Enhanced PowerShell detection and fallback
echo 🔍 Detecting PowerShell versions...

REM Try PowerShell 7 first
where pwsh >nul 2>nul
if %ERRORLEVEL% EQU 0 (
    echo ✅ PowerShell 7 detected - using optimal launcher
    pwsh -ExecutionPolicy Bypass -File "%~dp0Start-AitherZero.ps1" %*
    set LAUNCH_EXIT_CODE=%ERRORLEVEL%
    goto :handle_exit
)

echo ⚠️ PowerShell 7 not found, trying Windows PowerShell...

REM Try Windows PowerShell
where powershell >nul 2>nul
if %ERRORLEVEL% EQU 0 (
    echo ⚠️ Using Windows PowerShell 5.1 (limited compatibility)
    powershell -ExecutionPolicy Bypass -File "%~dp0Start-AitherZero.ps1" %*
    set LAUNCH_EXIT_CODE=%ERRORLEVEL%
    goto :handle_exit
)

echo ❌ No PowerShell found!
echo.
echo 💡 Please install PowerShell:
echo    PowerShell 7: https://aka.ms/powershell-release-windows
echo    Windows PowerShell is usually pre-installed
echo.
pause
exit /b 1

:handle_exit

REM Handle exit codes and provide troubleshooting
if %LAUNCH_EXIT_CODE% EQU 0 (
    echo.
    echo ✅ AitherZero completed successfully!
    echo.
) else (
    echo.
    echo ❌ AitherZero encountered an error (Exit code: %LAUNCH_EXIT_CODE%)
    echo.
    echo 💡 Troubleshooting Windows Issues:
    echo.
    echo   1. Try: pwsh -ExecutionPolicy Bypass -File "aither-core.ps1" -Help
    echo   2. Check PowerShell version: pwsh -c "$PSVersionTable.PSVersion"
    echo   3. Verify all files extracted properly
    echo.
    echo   📖 For PowerShell 5.1 users:
    echo   Some advanced features may be limited. Consider upgrading to PowerShell 7+
    echo   Download: https://aka.ms/powershell-release-windows
    echo.
    pause
    exit /b %LAUNCH_EXIT_CODE%
)


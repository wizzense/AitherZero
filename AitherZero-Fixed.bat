@echo off
echo.
echo 🚀 AitherZero v0.10.1 - Windows Quick Start (HOTFIX)
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
    pwsh -ExecutionPolicy Bypass -File "Start-AitherZero-Fixed.ps1" %*
    set LAUNCH_EXIT_CODE=%ERRORLEVEL%
) else (
    echo ⚠️ PowerShell 7 not found, trying Windows PowerShell...
    
    REM Try Windows PowerShell
    where powershell >nul 2>nul
    if %ERRORLEVEL% EQU 0 (
        echo ⚠️ Using Windows PowerShell 5.1 (limited compatibility)
        powershell -ExecutionPolicy Bypass -File "Start-AitherZero-Fixed.ps1" %*
        set LAUNCH_EXIT_CODE=%ERRORLEVEL%
    ) else (
        echo ❌ No PowerShell found!
        echo.
        echo 💡 Please install PowerShell:
        echo    PowerShell 7: https://aka.ms/powershell-release-windows
        echo    Windows PowerShell is usually pre-installed
        echo.
        pause
        exit /b 1
    )
)

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
    echo   🔓 If you see 'file is blocked' or security warnings:
    echo      1. Right-click this folder ^> Properties ^> Unblock ^> Apply
    echo      2. Or run: powershell -Command "Get-ChildItem -Recurse | Unblock-File"
    echo.
    echo   🛠️ Alternative launch methods:
    echo      1. pwsh -ExecutionPolicy Bypass -File Start-AitherZero-Fixed.ps1 -Setup
    echo      2. pwsh -ExecutionPolicy Bypass -File Start-AitherZero-Fixed.ps1 -Help
    echo      3. powershell -ExecutionPolicy Bypass -File Start-AitherZero-Fixed.ps1 -Setup
    echo.
    echo   📋 Requirements check:
    echo      - PowerShell 7+ (recommended): https://aka.ms/powershell-release-windows
    echo      - Git: https://git-scm.com/download/win
    echo      - OpenTofu or Terraform
    echo.
    echo   🌐 For more help: https://github.com/wizzense/AitherZero/wiki
    echo.
    pause
)

exit /b %LAUNCH_EXIT_CODE%

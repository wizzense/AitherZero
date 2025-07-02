@echo off
REM AitherZero Modern CLI - Windows Launcher
REM This batch file provides easy access to the aither.ps1 PowerShell script

REM Detect PowerShell version and use the best available
where pwsh >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    REM PowerShell 7+ available
    pwsh -ExecutionPolicy Bypass -File "%~dp0aither.ps1" %*
) else (
    REM Fallback to Windows PowerShell
    powershell -ExecutionPolicy Bypass -File "%~dp0aither.ps1" %*
)
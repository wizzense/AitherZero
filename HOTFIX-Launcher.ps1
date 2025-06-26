# 🚀 AitherZero v0.10.0 IMMEDIATE HOTFIX
# This script provides a working launcher for the broken v0.10.0 release
# Save this as "HOTFIX-Launcher.ps1" and run it instead of the broken launchers

[CmdletBinding()]
param(
    [Parameter(HelpMessage="Show setup information")]
    [switch]$Setup,

    [Parameter(HelpMessage="Show help")]
    [switch]$Help,

    [Parameter(HelpMessage="Logging verbosity")]
    [ValidateSet("silent", "normal", "detailed")]
    [string]$Verbosity = "normal",

    [Parameter(HelpMessage="Scripts to run")]
    [string[]]$Scripts,

    [Parameter(HelpMessage="Automated mode")]
    [switch]$Auto,

    [Parameter(HelpMessage="Configuration file")]
    [string]$ConfigFile
)

Write-Host "🚀 AitherZero v0.10.0 HOTFIX Launcher" -ForegroundColor Green
Write-Host "This bypasses the broken launchers in v0.10.0" -ForegroundColor Yellow
Write-Host ""

if ($Help) {
    Write-Host "HOTFIX Usage Examples:" -ForegroundColor Cyan
    Write-Host "  pwsh HOTFIX-Launcher.ps1 -Setup" -ForegroundColor White
    Write-Host "  pwsh HOTFIX-Launcher.ps1 -Verbosity detailed" -ForegroundColor White
    Write-Host "  pwsh HOTFIX-Launcher.ps1 -Auto" -ForegroundColor White
    Write-Host ""
    Write-Host "Direct Core Access (also works):" -ForegroundColor Cyan
    Write-Host "  pwsh -ExecutionPolicy Bypass -File aither-core.ps1 -Help" -ForegroundColor White
    Write-Host ""
    return
}

if ($Setup) {
    Write-Host "🔧 Environment Check:" -ForegroundColor Green
    Write-Host "PowerShell Version: $($PSVersionTable.PSVersion)" -ForegroundColor White
    Write-Host "Platform: $($PSVersionTable.Platform)" -ForegroundColor White
    Write-Host ""

    if (Test-Path "aither-core.ps1") {
        Write-Host "✅ Core script found" -ForegroundColor Green
    } else {
        Write-Host "❌ Core script missing" -ForegroundColor Red
    }

    if (Test-Path "modules") {
        $moduleCount = (Get-ChildItem "modules" -Directory).Count
        Write-Host "✅ Found $moduleCount modules" -ForegroundColor Green
    } else {
        Write-Host "❌ Modules directory missing" -ForegroundColor Red
    }

    Write-Host ""
    Write-Host "🎯 Ready to use AitherZero!" -ForegroundColor Green
    Write-Host "Run: pwsh HOTFIX-Launcher.ps1" -ForegroundColor Cyan
    return
}

# Build arguments for core script
$coreArgs = @()
if ($PSBoundParameters.ContainsKey('Verbosity')) { $coreArgs += @('-Verbosity', $Verbosity) }
if ($PSBoundParameters.ContainsKey('Scripts')) { $coreArgs += @('-Scripts', ($Scripts -join ',')) }
if ($PSBoundParameters.ContainsKey('Auto')) { $coreArgs += @('-Auto') }
if ($PSBoundParameters.ContainsKey('ConfigFile')) { $coreArgs += @('-ConfigFile', $ConfigFile) }

Write-Host "Launching AitherZero core..." -ForegroundColor Cyan

try {
    if (Test-Path "aither-core.ps1") {
        & ".\aither-core.ps1" @coreArgs
    } else {
        throw "aither-core.ps1 not found in current directory"
    }
} catch {
    Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "💡 Make sure you're in the AitherZero directory with:" -ForegroundColor Yellow
    Write-Host "   - aither-core.ps1" -ForegroundColor White
    Write-Host "   - modules/ folder" -ForegroundColor White
    Write-Host "   - configs/ folder" -ForegroundColor White
    exit 1
}

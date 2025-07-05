# AitherZero Quick Setup Script
# Provides a simplified first-run experience for new users
#
# This script is a wrapper around Start-AitherZero.ps1 with preset options
# for the most common use case: getting started quickly with minimal prompts

[CmdletBinding()]
param(
    [Parameter(HelpMessage = "Skip all prompts and use defaults")]
    [switch]$Auto,
    
    [Parameter(HelpMessage = "Installation profile: minimal, standard, or full")]
    [ValidateSet("minimal", "standard", "full")]
    [string]$Profile = "standard"
)

# Banner
Write-Host ""
Write-Host "====================================" -ForegroundColor Cyan
Write-Host " AitherZero Quick Setup" -ForegroundColor Cyan
Write-Host "====================================" -ForegroundColor Cyan
Write-Host ""

# Check PowerShell version
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Host "[!] PowerShell 5.1 detected. Some features may be limited." -ForegroundColor Yellow
    Write-Host "[i] For the best experience, install PowerShell 7+" -ForegroundColor Yellow
    Write-Host "    Download from: https://aka.ms/powershell" -ForegroundColor Gray
    Write-Host ""
}

# Ensure we're in the right directory
if (-not (Test-Path ".\Start-AitherZero.ps1")) {
    Write-Host "[!] Error: Start-AitherZero.ps1 not found in current directory" -ForegroundColor Red
    Write-Host "[i] Please run this script from the AitherZero installation directory" -ForegroundColor Yellow
    exit 1
}

Write-Host "[*] Quick setup will:" -ForegroundColor Green
Write-Host "    - Run first-time setup wizard" -ForegroundColor White
Write-Host "    - Configure AitherZero with $Profile profile" -ForegroundColor White
Write-Host "    - Create necessary directories" -ForegroundColor White
Write-Host "    - Initialize configuration" -ForegroundColor White
Write-Host ""

if (-not $Auto) {
    $continue = Read-Host "Continue with quick setup? (Y/n)"
    if ($continue -and $continue -ne 'Y' -and $continue -ne 'y') {
        Write-Host "[!] Setup cancelled" -ForegroundColor Yellow
        exit 0
    }
}

try {
    # Run the main setup with appropriate parameters
    Write-Host "[~] Starting AitherZero setup..." -ForegroundColor Cyan
    
    if ($Auto) {
        # Fully automated setup
        & .\Start-AitherZero.ps1 -Setup -InstallationProfile $Profile -Auto
    } else {
        # Interactive setup with the selected profile
        & .\Start-AitherZero.ps1 -Setup -InstallationProfile $Profile
    }
    
    Write-Host ""
    Write-Host "[+] Quick setup completed!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "  1. Run .\Start-AitherZero.ps1 to launch AitherZero" -ForegroundColor White
    Write-Host "  2. Select 'LabRunner' to deploy infrastructure" -ForegroundColor White
    Write-Host "  3. Check ./docs for documentation" -ForegroundColor White
    Write-Host ""
    
} catch {
    Write-Host "[!] Setup failed: $_" -ForegroundColor Red
    Write-Host "[i] Try running .\Start-AitherZero.ps1 -Setup manually" -ForegroundColor Yellow
    exit 1
}
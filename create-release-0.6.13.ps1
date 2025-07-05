# Create GitHub Release v0.6.13
# Run this after the PR is merged

Write-Host "=== AitherZero Release v0.6.13 ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "This script will help you create the GitHub release." -ForegroundColor White
Write-Host ""

# Check if gh CLI is available
$ghAvailable = Get-Command gh -ErrorAction SilentlyContinue
if (-not $ghAvailable) {
    Write-Host "[!] GitHub CLI (gh) not found. Please install it first:" -ForegroundColor Red
    Write-Host "    winget install GitHub.cli" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Or create the release manually at:" -ForegroundColor Yellow
    Write-Host "    https://github.com/wizzense/AitherZero/releases/new" -ForegroundColor White
    Write-Host ""
    Write-Host "Release details:" -ForegroundColor Cyan
    Write-Host "  Tag: v0.6.13" -ForegroundColor White
    Write-Host "  Title: Release v0.6.13 - Bootstrap & Startup Fixes" -ForegroundColor White
    Write-Host "  Description:" -ForegroundColor White
    Write-Host @"
## What's Changed
- Fixed bootstrap.ps1 profile name mapping issues
- Fixed Start-AitherZero.ps1 path resolution for null `$PSScriptRoot
- Improved PowerShell 5.1 compatibility
- Better error handling for execution policy issues
- Network retry logic for unstable connections

## Bug Fixes
- Bootstrap now correctly maps profile names to build artifacts
- Start script handles various execution contexts properly
- Removed module loading errors in PowerShell 5.1

## Installation
``````powershell
# Windows - One command downloads and runs AitherZero:
iex (irm "https://raw.githubusercontent.com/wizzense/AitherZero/main/bootstrap.ps1")
``````

## Files to Upload
Upload these files from the dist folder:
- AitherZero-0.6.13-standard-windows.zip
- AitherZero-0.6.13-development-windows.zip
- aitherzero-standard-windows-latest.zip (for backward compatibility)
- aitherzero-full-windows-latest.zip (for backward compatibility)
"@ -ForegroundColor Gray
    exit
}

# Create release with gh CLI
Write-Host "[i] Creating GitHub release with gh CLI..." -ForegroundColor Cyan

$releaseNotes = @"
## What's Changed
- Fixed bootstrap.ps1 profile name mapping issues
- Fixed Start-AitherZero.ps1 path resolution for null `$PSScriptRoot
- Improved PowerShell 5.1 compatibility  
- Better error handling for execution policy issues
- Network retry logic for unstable connections

## Bug Fixes
- Bootstrap now correctly maps profile names to build artifacts
- Start script handles various execution contexts properly
- Removed module loading errors in PowerShell 5.1

## Installation
``````powershell
# Windows - One command downloads and runs AitherZero:
iex (irm "https://raw.githubusercontent.com/wizzense/AitherZero/main/bootstrap.ps1")
``````
"@

# Create the release
try {
    gh release create v0.6.13 `
        --title "Release v0.6.13 - Bootstrap & Startup Fixes" `
        --notes $releaseNotes `
        ./dist/AitherZero-0.6.13-standard-windows.zip `
        ./dist/AitherZero-0.6.13-development-windows.zip `
        ./dist/aitherzero-standard-windows-latest.zip `
        ./dist/aitherzero-full-windows-latest.zip
        
    Write-Host "[+] Release created successfully!" -ForegroundColor Green
    Write-Host "    View at: https://github.com/wizzense/AitherZero/releases/tag/v0.6.13" -ForegroundColor Cyan
} catch {
    Write-Host "[!] Failed to create release: $_" -ForegroundColor Red
    Write-Host "[i] Please create the release manually at:" -ForegroundColor Yellow
    Write-Host "    https://github.com/wizzense/AitherZero/releases/new" -ForegroundColor White
}
#Requires -Version 7.0

<#
.SYNOPSIS
    Creates a GitHub release with the built packages
.DESCRIPTION
    Creates a GitHub release and uploads the release packages as assets.
    Requires GitHub CLI (gh) to be installed and authenticated.
.PARAMETER Version
    Version number for the release
.PARAMETER Draft
    Create as draft release
.PARAMETER PreRelease
    Mark as pre-release
.PARAMETER ReleaseDir
    Directory containing release packages
.EXAMPLE
    ./9102_Create-GitHubRelease.ps1 -Version "1.0.0"
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $true)]
    [string]$Version,
    
    [switch]$Draft = $false,
    
    [switch]$PreRelease = $false,
    
    [string]$ReleaseDir = "./release",
    
    [string]$ReleaseNotes
)

# Initialize logging
$script:ProjectRoot = Split-Path $PSScriptRoot -Parent

function Write-ReleaseLog {
    param(
        [string]$Message,
        [string]$Level = 'Information'
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] [GitHubRelease] $Message"
    
    switch ($Level) {
        'Error' { Write-Host $logMessage -ForegroundColor Red }
        'Warning' { Write-Host $logMessage -ForegroundColor Yellow }
        'Success' { Write-Host $logMessage -ForegroundColor Green }
        default { Write-Host $logMessage -ForegroundColor Cyan }
    }
}

Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Blue
Write-Host " GitHub Release Creator v$Version" -ForegroundColor White
Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Blue
Write-Host ""

# Check if gh CLI is available
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-ReleaseLog "GitHub CLI (gh) is not installed or not in PATH" -Level 'Error'
    Write-Host "Install from: https://cli.github.com/" -ForegroundColor Yellow
    exit 1
}

# Check if authenticated
try {
    $authStatus = gh auth status 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-ReleaseLog "Not authenticated with GitHub. Run: gh auth login" -Level 'Error'
        exit 1
    }
} catch {
    Write-ReleaseLog "Failed to check GitHub authentication: $_" -Level 'Error'
    exit 1
}

# Check if release packages exist
if (-not (Test-Path $ReleaseDir)) {
    Write-ReleaseLog "Release directory not found: $ReleaseDir" -Level 'Error'
    exit 1
}

$packages = Get-ChildItem "$ReleaseDir/AitherZero-$Version-*.zip" -ErrorAction SilentlyContinue
if ($packages.Count -eq 0) {
    Write-ReleaseLog "No release packages found for version $Version" -Level 'Error'
    Write-Host "Run ./9100_Build-Release.ps1 first" -ForegroundColor Yellow
    exit 1
}

Write-ReleaseLog "Found $($packages.Count) package(s) to upload"

# Generate release notes if not provided
if (-not $ReleaseNotes) {
    $ReleaseNotes = @"
# AitherZero v$Version

## Installation

Download the appropriate package for your needs:
- **Core**: Minimal installation with essential features
- **Standard**: Recommended for most users
- **Full**: Complete installation with all features

### Quick Start
``````powershell
# Download and extract
Expand-Archive AitherZero-$Version-[Profile].zip -DestinationPath ./AitherZero

# Run bootstrap
cd AitherZero
./bootstrap.ps1
``````

## What's New
- Enhanced CI/CD pipeline with PSD1 playbooks
- Improved build and release automation
- Better cross-platform support

## Packages
"@

    foreach ($package in $packages) {
        $size = [math]::Round($package.Length / 1MB, 2)
        $profile = $package.Name -replace ".*-(\w+)\.zip", '$1'
        $ReleaseNotes += "`n- **$profile** (${size}MB): ``$($package.Name)``"
    }
}

# Create the release
Write-ReleaseLog "Creating GitHub release..."

$releaseArgs = @(
    "release", "create", "v$Version",
    "--title", "AitherZero v$Version",
    "--notes", $ReleaseNotes
)

if ($Draft) {
    $releaseArgs += "--draft"
    Write-ReleaseLog "Creating as draft release"
}

if ($PreRelease) {
    $releaseArgs += "--prerelease"
    Write-ReleaseLog "Marking as pre-release"
}

# Add all packages as assets
foreach ($package in $packages) {
    $releaseArgs += $package.FullName
    Write-ReleaseLog "Adding asset: $($package.Name)"
}

try {
    if ($PSCmdlet.ShouldProcess("v$Version", "Create GitHub release")) {
        $output = gh @releaseArgs 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-ReleaseLog "Successfully created release!" -Level 'Success'
            Write-Host ""
            Write-Host "Release URL: $output" -ForegroundColor Green
            
            # Also create/update latest release tag if not pre-release
            if (-not $PreRelease -and -not $Draft) {
                if ($PSCmdlet.ShouldProcess("latest", "Update tag")) {
                    Write-ReleaseLog "Updating 'latest' tag..."
                    git tag -f latest
                    git push origin latest -f
                }
            }
        } else {
            throw "GitHub CLI returned error: $output"
        }
    }
} catch {
    Write-ReleaseLog "Failed to create release: $_" -Level 'Error'
    exit 1
}

Write-Host ""
Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Blue
Write-Host " Release created successfully!" -ForegroundColor Green
Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Blue
<#
.SYNOPSIS
    Dead simple release script for AitherZero
.DESCRIPTION
    ONE COMMAND - THAT'S IT! Creates a release with automatic version bumping.
.PARAMETER Type
    Release type: patch (default), minor, or major
.PARAMETER Description
    Description for the release
.EXAMPLE
    ./release.ps1
    ./release.ps1 -Type minor -Description "New features"
    ./release.ps1 -Type major -Description "Breaking changes"
#>

param(
    [ValidateSet('patch', 'minor', 'major')]
    [string]$Type = 'patch',
    
    [string]$Description = "Release"
)

Write-Host "🚀 Starting $Type release process..." -ForegroundColor Cyan

# Sync with origin first to prevent merge conflicts
Write-Host "📥 Syncing with origin/main..." -ForegroundColor Yellow
try {
    # Fetch latest changes
    git fetch origin
    
    # Check if we're behind origin/main
    $behind = git rev-list --count HEAD..origin/main
    if ($behind -gt 0) {
        Write-Host "⚠️  Local branch is $behind commits behind origin/main" -ForegroundColor Yellow
        Write-Host "🔄 Pulling latest changes..." -ForegroundColor Yellow
        git pull origin main --rebase
        
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to sync with origin/main. Please resolve conflicts manually."
        }
        Write-Host "✅ Successfully synced with origin/main" -ForegroundColor Green
    } else {
        Write-Host "✅ Already up to date with origin/main" -ForegroundColor Green
    }
} catch {
    Write-Host "❌ Failed to sync with origin: $_" -ForegroundColor Red
    Write-Host "Please run 'git pull origin main --rebase' manually and resolve any conflicts" -ForegroundColor Yellow
    exit 1
}

# Import PatchManager
$modulePath = Join-Path $PSScriptRoot "aither-core" "modules" "PatchManager"
Import-Module $modulePath -Force

# Use PatchManager's release workflow
try {
    Invoke-ReleaseWorkflow -ReleaseType $Type -Description $Description
    Write-Host "✅ Release process completed!" -ForegroundColor Green
} catch {
    Write-Host "❌ Release failed: $_" -ForegroundColor Red
    exit 1
}
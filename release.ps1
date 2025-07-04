#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Ultra-simple release script for AitherZero

.DESCRIPTION
    Just run ./release.ps1 to create a patch release.
    No complexity, no BS, just works.

.PARAMETER Type
    Release type: patch (default), minor, or major

.PARAMETER Description
    Release description (default: "Bug fixes and improvements")

.EXAMPLE
    ./release.ps1
    Creates a patch release with default description

.EXAMPLE
    ./release.ps1 -Type minor -Description "New features added"
    Creates a minor release with custom description

.EXAMPLE
    ./release.ps1 patch "Quick fix for bootstrap"
    Positional parameters work too
#>

param(
    [Parameter(Position = 0)]
    [ValidateSet('patch', 'minor', 'major')]
    [string]$Type = 'patch',
    
    [Parameter(Position = 1)]
    [string]$Description = 'Bug fixes and improvements'
)

# Simple header
Write-Host "`n🚀 AitherZero Release Script" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

try {
    # Import PatchManager
    Write-Host "`n📦 Loading PatchManager..." -ForegroundColor Yellow
    Import-Module ./aither-core/modules/PatchManager -Force
    
    # Show what we're doing
    Write-Host "`n📋 Release Details:" -ForegroundColor Green
    Write-Host "   Type: $Type" -ForegroundColor White
    Write-Host "   Description: $Description" -ForegroundColor White
    
    # Run the release
    Write-Host "`n🔧 Creating release..." -ForegroundColor Yellow
    Invoke-ReleaseWorkflow -ReleaseType $Type -Description $Description
    
    Write-Host "`n✅ Release process completed successfully!" -ForegroundColor Green
    Write-Host "`n📌 What happened:" -ForegroundColor Cyan
    Write-Host "   1. ✅ Created PR with version update" -ForegroundColor Green
    Write-Host "   2. ✅ Created and pushed release tag" -ForegroundColor Green
    Write-Host "   3. ⏳ Build pipeline will start when PR is merged" -ForegroundColor Yellow
    Write-Host "`n📌 Next steps:" -ForegroundColor Cyan
    Write-Host "   1. Review and merge the PR" -ForegroundColor White
    Write-Host "   2. Build pipeline runs automatically" -ForegroundColor White
    Write-Host "   3. Release artifacts will be created" -ForegroundColor White
    
} catch {
    Write-Host "`n❌ Release failed: $_" -ForegroundColor Red
    Write-Host "`n💡 Common fixes:" -ForegroundColor Yellow
    Write-Host "   - Make sure you're on the main branch" -ForegroundColor White
    Write-Host "   - Pull latest changes: git pull" -ForegroundColor White
    Write-Host "   - Check if you have uncommitted changes" -ForegroundColor White
    exit 1
}
#Requires -Version 7.0

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
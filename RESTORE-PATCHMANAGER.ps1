#!/usr/bin/env pwsh
# Emergency PatchManager Restoration Script
# Restores PatchManager functionality after domain migration

[CmdletBinding()]
param()

Write-Host "🔧 Restoring PatchManager Functionality..." -ForegroundColor Cyan

try {
    # Find project root
    . "$PSScriptRoot/aither-core/shared/Find-ProjectRoot.ps1"
    $projectRoot = Find-ProjectRoot
    
    # Set up environment
    $env:PROJECT_ROOT = $projectRoot
    
    # Create fallback Write-CustomLog if needed
    if (-not (Get-Command Write-CustomLog -ErrorAction SilentlyContinue)) {
        function global:Write-CustomLog {
            param(
                [Parameter(Mandatory = $true)][string]$Message,
                [Parameter()][string]$Level = 'INFO',
                [Parameter()][string]$Component = 'PatchManager'
            )
            $color = switch ($Level) {
                'ERROR' { 'Red' }; 'WARN' { 'Yellow' }; 'INFO' { 'Green' }; 'SUCCESS' { 'Cyan' }
                'DEBUG' { 'Gray' }; 'VERBOSE' { 'Magenta' }; default { 'White' }
            }
            Write-Host "[$Level] [$Component] $Message" -ForegroundColor $color
        }
    }
    
    # Load Automation domain (contains PatchManager functions)
    Write-Host "📦 Loading Automation domain..." -ForegroundColor Yellow
    . "$projectRoot/aither-core/domains/automation/Automation.ps1"
    
    # Test PatchManager functions
    Write-Host "🧪 Testing PatchManager functions..." -ForegroundColor Yellow
    
    $patchFunctions = @('New-Patch', 'New-QuickFix', 'New-Feature', 'New-Hotfix')
    $availableFunctions = @()
    
    foreach ($func in $patchFunctions) {
        if (Get-Command $func -ErrorAction SilentlyContinue) {
            $availableFunctions += $func
            Write-Host "  ✅ $func - Available" -ForegroundColor Green
        } else {
            Write-Host "  ❌ $func - Not found" -ForegroundColor Red
        }
    }
    
    Write-Host ""
    Write-Host "🎉 PatchManager Restoration Complete!" -ForegroundColor Green
    Write-Host "📋 Available functions: $($availableFunctions -join ', ')" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "💡 Usage Examples:" -ForegroundColor Yellow
    Write-Host "  New-QuickFix -Description 'Fix typo' -Changes { # Your changes }" -ForegroundColor White
    Write-Host "  New-Feature -Description 'New feature' -Changes { # Your changes }" -ForegroundColor White
    Write-Host "  New-Patch -Description 'General patch' -Changes { # Your changes }" -ForegroundColor White
    Write-Host ""
    Write-Host "🔗 For automatic loading, add to your profile:" -ForegroundColor Yellow
    Write-Host "  . '$PSScriptRoot/RESTORE-PATCHMANAGER.ps1'" -ForegroundColor White
    
} catch {
    Write-Host "❌ Failed to restore PatchManager: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "📋 Manual fix: Load automation domain directly:" -ForegroundColor Yellow
    Write-Host "  . './aither-core/domains/automation/Automation.ps1'" -ForegroundColor White
    throw
}
#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Creates release v1.4.2 with enhanced menu system
.DESCRIPTION
    This script creates the v1.4.2 release with comprehensive menu improvements:
    - Multi-column layout for better horizontal space usage
    - Support for 4-digit script prefix execution (e.g., 0200)
    - Support for script name execution (e.g., Get-SystemInfo)
    - Comma-separated batch execution (e.g., 0200,0201,0202)
    - Improved formatting and spacing
    - Compact banner with version display
#>

[CmdletBinding()]
param(
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

function Write-Log {
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        [ValidateSet('INFO', 'SUCCESS', 'WARNING', 'ERROR')]
        [string]$Level = 'INFO'
    )
    
    $color = switch ($Level) {
        'SUCCESS' { 'Green' }
        'WARNING' { 'Yellow' }
        'ERROR' { 'Red' }
        default { 'White' }
    }
    
    Write-Host "[$Level] $Message" -ForegroundColor $color
}

try {
    Write-Log "🚀 Creating Release v1.4.2 - Enhanced Menu System" -Level 'INFO'
    Write-Log "=============================================" -Level 'INFO'
    
    if ($DryRun) {
        Write-Log "RUNNING IN DRY RUN MODE - No actual changes will be made" -Level 'WARNING'
    }
    
    # Step 1: Import PatchManager v3.0
    Write-Log "Step 1: Loading PatchManager v3.0..." -Level 'INFO'
    
    $patchManagerPath = Join-Path $PSScriptRoot "aither-core/modules/PatchManager"
    if (-not (Test-Path $patchManagerPath)) {
        throw "PatchManager module not found at: $patchManagerPath"
    }
    
    Import-Module $patchManagerPath -Force
    Write-Log "✅ PatchManager v3.0 loaded" -Level 'SUCCESS'
    
    # Step 2: Use Invoke-ReleaseWorkflow for automated release
    Write-Log "Step 2: Creating v1.4.2 release with enhanced menu system..." -Level 'INFO'
    
    $releaseDescription = @"
Enhanced menu system with comprehensive improvements:

## 🎨 Visual Improvements
- Multi-column layout adapts to terminal width (up to 3 columns)
- Compact banner with integrated version display
- Better spacing and alignment throughout
- Cleaner category grouping

## 🚀 Input Enhancements
- **Menu Numbers**: Original functionality preserved (e.g., `3`)
- **4-Digit Prefixes**: Legacy script support (e.g., `0200`)
- **Script Names**: Case-insensitive name matching (e.g., `Get-SystemInfo`)
- **Module Names**: Direct module access (e.g., `patchmanager`)
- **Batch Execution**: Comma-separated inputs (e.g., `0200,0201,0202`)

## 📝 User Experience
- Shows both index and prefix for scripts (e.g., `[45/0200]`)
- Clear input instructions displayed
- Partial name matching for convenience
- Improved help documentation

## 🔧 Technical Details
- Complete rewrite of `Show-DynamicMenu.ps1`
- New input parsing engine in `Process-MenuInput`
- Flexible item lookup via `Find-MenuItem`
- Maintains backward compatibility

This release significantly improves the user experience when interacting with AitherZero's menu system.
"@
    
    if ($DryRun) {
        Write-Log "DRY RUN: Would create release v1.4.2" -Level 'INFO'
        Write-Log "Release Description:" -Level 'INFO'
        Write-Host $releaseDescription -ForegroundColor Gray
    } else {
        Write-Log "Creating release using PatchManager v3.0..." -Level 'INFO'
        
        # Use Invoke-ReleaseWorkflow for full automation
        $result = Invoke-ReleaseWorkflow -ReleaseType "patch" -Description $releaseDescription
        
        if ($result) {
            Write-Log "✅ Release workflow initiated successfully" -Level 'SUCCESS'
            
            # The workflow will:
            # 1. Update VERSION to 1.4.2
            # 2. Create and push the PR
            # 3. Wait for merge (if not using -AutoMerge)
            # 4. Create and push the release tag
            # 5. Monitor the build pipeline
            
            Write-Log "The release workflow is now handling:" -Level 'INFO'
            Write-Log "  • VERSION update to 1.4.2" -Level 'INFO'
            Write-Log "  • Pull request creation" -Level 'INFO'
            Write-Log "  • Tag creation after merge" -Level 'INFO'
            Write-Log "  • Build pipeline monitoring" -Level 'INFO'
        } else {
            throw "Release workflow failed to initiate"
        }
    }
    
    Write-Log "=============================================" -Level 'INFO'
    Write-Log "🎉 Release v1.4.2 Process Initiated!" -Level 'SUCCESS'
    Write-Log "" -Level 'INFO'
    
    if (-not $DryRun) {
        Write-Log "Next Steps:" -Level 'INFO'
        Write-Log "1. Review and merge the PR when ready" -Level 'INFO'
        Write-Log "2. The release tag will be created automatically" -Level 'INFO'
        Write-Log "3. Monitor GitHub Actions for build completion" -Level 'INFO'
        Write-Log "4. Test the enhanced menu system in the release" -Level 'INFO'
        Write-Log "" -Level 'INFO'
        Write-Log "Menu Enhancement Features:" -Level 'SUCCESS'
        Write-Log "• Multi-column display (adapts to terminal width)" -Level 'SUCCESS'
        Write-Log "• 4-digit prefix support (0200, 0201, etc.)" -Level 'SUCCESS'
        Write-Log "• Script name execution (Get-SystemInfo, etc.)" -Level 'SUCCESS'
        Write-Log "• Comma-separated batch execution" -Level 'SUCCESS'
        Write-Log "• Improved visual formatting" -Level 'SUCCESS'
    } else {
        Write-Log "This was a DRY RUN - no actual changes were made." -Level 'WARNING'
        Write-Log "Remove -DryRun flag to create the release." -Level 'INFO'
    }
    
} catch {
    Write-Log "❌ Release creation failed: $($_.Exception.Message)" -Level 'ERROR'
    Write-Log "Stack trace: $($_.ScriptStackTrace)" -Level 'ERROR'
    exit 1
}
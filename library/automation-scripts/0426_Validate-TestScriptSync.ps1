#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Validate synchronization between test files and automation scripts

.DESCRIPTION
    Detects and optionally removes orphaned test files (tests that reference non-existent scripts).
    This prevents test execution failures from missing script files.
    
    Exit Codes:
    0   - All tests are in sync or orphans removed successfully
    1   - Orphaned tests found (when not using -RemoveOrphaned)
    2   - Execution error

.PARAMETER RemoveOrphaned
    Remove orphaned test files automatically

.PARAMETER WhatIf
    Show what would be done without making changes

.PARAMETER CI
    Run in CI mode with minimal output

.EXAMPLE
    ./0426_Validate-TestScriptSync.ps1
    Detect and report orphaned tests

.EXAMPLE
    ./0426_Validate-TestScriptSync.ps1 -RemoveOrphaned
    Remove orphaned test files

.EXAMPLE
    ./0426_Validate-TestScriptSync.ps1 -RemoveOrphaned -WhatIf
    Preview what would be removed

.NOTES
    Stage: Testing
    Order: 0426
    Dependencies: None
    Tags: testing, validation, cleanup
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$RemoveOrphaned,
    [switch]$CI
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Script paths
$projectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$testRoot = Join-Path $projectRoot "library/tests/unit/automation-scripts"
$scriptRoot = Join-Path $projectRoot "library/automation-scripts"
$loggingModule = Join-Path $projectRoot "aithercore/utilities/Logging.psm1"

# Import Logging module if available
if (Test-Path $loggingModule) {
    Import-Module $loggingModule -Force -ErrorAction SilentlyContinue
}

function Write-ScriptLog {
    param(
        [string]$Level = 'Information',
        [string]$Message,
        [hashtable]$Data = @{}
    )

    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Level $Level -Message $Message -Source "0426_Validate-TestScriptSync" -Data $Data
    } else {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $color = @{
            'Error' = 'Red'
            'Warning' = 'Yellow'
            'Information' = 'White'
            'Debug' = 'Gray'
        }[$Level]
        if (-not $CI) {
            Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
        }
    }
}

try {
    Write-ScriptLog -Message "Starting test-script synchronization validation"

    if (-not (Test-Path $testRoot)) {
        Write-ScriptLog -Level Warning -Message "Test directory not found: $testRoot"
        exit 0
    }

    if (-not (Test-Path $scriptRoot)) {
        Write-ScriptLog -Level Error -Message "Script directory not found: $scriptRoot"
        exit 2
    }

    # Find all test files
    $testFiles = @(Get-ChildItem -Path $testRoot -Filter "*.Tests.ps1" -Recurse -ErrorAction SilentlyContinue)
    Write-ScriptLog -Message "Found $($testFiles.Count) test files"

    if (-not $CI) {
        Write-Host ""
        Write-Host "🔍 Scanning for orphaned test files..." -ForegroundColor Cyan
        Write-Host ""
    }

    # Check each test file for corresponding script
    $orphanedTests = @()
    $validTests = 0

    foreach ($testFile in $testFiles) {
        # Extract script name from test file name
        $scriptName = $testFile.BaseName -replace '\.Tests$', ''
        $scriptPath = Join-Path $scriptRoot "$scriptName.ps1"
        
        # Check if the corresponding script exists
        if (-not (Test-Path $scriptPath)) {
            $orphanedTests += [PSCustomObject]@{
                TestFile = $testFile.Name
                TestPath = $testFile.FullName
                ScriptName = $scriptName
                ScriptPath = $scriptPath
                Range = $testFile.Directory.Name
            }
            
            if (-not $CI) {
                Write-Host "❌ ORPHANED: $($testFile.Name)" -ForegroundColor Red
                Write-Host "   Missing script: $scriptName.ps1" -ForegroundColor DarkRed
                Write-Host "   Location: $($testFile.Directory.Name)/" -ForegroundColor DarkGray
                Write-Host ""
            }
        } else {
            $validTests++
        }
    }

    # Report results
    if (-not $CI) {
        Write-Host ""
        Write-Host "📊 Validation Summary:" -ForegroundColor Cyan
        Write-Host "   Total test files: $($testFiles.Count)"
        Write-Host "   Valid tests: $validTests" -ForegroundColor Green
        Write-Host "   Orphaned tests: $($orphanedTests.Count)" -ForegroundColor $(if ($orphanedTests.Count -gt 0) { 'Yellow' } else { 'Green' })
        Write-Host ""
    }

    $syncData = @{
        TotalTests = $testFiles.Count
        ValidTests = $validTests
        OrphanedTests = $orphanedTests.Count
    }
    Write-ScriptLog -Message "Validation completed" -Data $syncData

    if ($orphanedTests.Count -eq 0) {
        if (-not $CI) {
            Write-Host "✅ All test files are synchronized with scripts!" -ForegroundColor Green
            Write-Host ""
        }
        Write-ScriptLog -Message "All tests are in sync"
        exit 0
    }

    # Handle orphaned tests
    if ($RemoveOrphaned) {
        if (-not $CI) {
            Write-Host "🗑️  Removing orphaned test files..." -ForegroundColor Yellow
            Write-Host ""
        }

        $removedCount = 0
        foreach ($orphan in $orphanedTests) {
            if ($PSCmdlet.ShouldProcess($orphan.TestPath, "Remove orphaned test file")) {
                try {
                    Remove-Item -Path $orphan.TestPath -Force -ErrorAction Stop
                    $removedCount++
                    
                    if (-not $CI) {
                        Write-Host "   ✓ Removed: $($orphan.TestFile)" -ForegroundColor Green
                    }
                    
                    Write-ScriptLog -Message "Removed orphaned test file: $($orphan.TestFile)"
                }
                catch {
                    Write-ScriptLog -Level Error -Message "Failed to remove: $($orphan.TestFile)" -Data @{
                        Error = $_.Exception.Message
                    }
                    
                    if (-not $CI) {
                        Write-Host "   ✗ Failed to remove: $($orphan.TestFile)" -ForegroundColor Red
                        Write-Host "     Error: $_" -ForegroundColor DarkRed
                    }
                }
            }
        }

        if (-not $CI) {
            Write-Host ""
            Write-Host "✅ Cleanup complete!" -ForegroundColor Green
            Write-Host "   Removed: $removedCount orphaned test file(s)" -ForegroundColor Green
            Write-Host ""
        }

        Write-ScriptLog -Message "Orphaned tests removed" -Data @{
            RemovedCount = $removedCount
        }
        exit 0
    } else {
        # Report orphaned tests and provide guidance
        if (-not $CI) {
            Write-Host "⚠️  Orphaned test files detected!" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "These test files reference non-existent scripts:" -ForegroundColor Yellow
            
            # Group by range for better visibility
            $orphanedTests | Group-Object Range | ForEach-Object {
                Write-Host ""
                Write-Host "  Range: $($_.Name)" -ForegroundColor Cyan
                $_.Group | ForEach-Object {
                    Write-Host "    - $($_.TestFile) → $($_.ScriptName).ps1" -ForegroundColor DarkYellow
                }
            }
            
            Write-Host ""
            Write-Host "💡 Recommended Actions:" -ForegroundColor Cyan
            Write-Host "   1. If scripts were deleted: Run with -RemoveOrphaned to clean up" -ForegroundColor White
            Write-Host "      ./automation-scripts/0426_Validate-TestScriptSync.ps1 -RemoveOrphaned" -ForegroundColor Gray
            Write-Host ""
            Write-Host "   2. If scripts exist elsewhere: Move them to automation-scripts/" -ForegroundColor White
            Write-Host ""
            Write-Host "   3. Preview cleanup: Use -WhatIf" -ForegroundColor White
            Write-Host "      ./automation-scripts/0426_Validate-TestScriptSync.ps1 -RemoveOrphaned -WhatIf" -ForegroundColor Gray
            Write-Host ""
        }

        Write-ScriptLog -Level Warning -Message "Orphaned tests detected but not removed" -Data @{
            OrphanedCount = $orphanedTests.Count
            Files = ($orphanedTests | ForEach-Object { $_.TestFile }) -join ', '
        }
        
        exit 1
    }
}
catch {
    Write-ScriptLog -Level Error -Message "Validation failed: $_" -Data @{
        Exception = if ($_.Exception) { $_.Exception.Message } else { $_.ToString() }
    }
    
    if (-not $CI) {
        Write-Host ""
        Write-Host "❌ Validation failed with error:" -ForegroundColor Red
        Write-Host "   $_" -ForegroundColor Red
        Write-Host ""
    }
    
    exit 2
}

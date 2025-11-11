#!/usr/bin/env pwsh
#Requires -Version 7.0
# Dependencies: 0400

<#
.SYNOPSIS
    Validates all PowerShell module manifest files in the project for Unicode and parsing issues
.DESCRIPTION
    This script validates all .psd1 module manifest files in the AitherZero project to ensure:
    - No Unicode characters that could cause parsing issues on Windows PowerShell
    - Proper PowerShell restricted language compliance
    - Consistent encoding across all manifest files
    
    This is part of the quality assurance automation (0400-0499 series).
.PARAMETER Fix
    If specified, automatically fixes detected Unicode issues
.PARAMETER Path
    Optional path to validate specific manifest files. If not specified, validates all .psd1 files in the project.
.EXAMPLE
    az 0405
    Validates all module manifests in the project
.EXAMPLE
    az 0405 -Fix
    Validates and automatically fixes all Unicode issues found
.NOTES
    Stage: Testing
    Order: 0405
    Dependencies: 0400
    Tags: testing, validation, manifest, unicode
    Script ID: 0405
    Category: Testing & Validation
    Requires: PowerShell 7.0+
    
    This script is designed to prevent the specific Unicode parsing errors that can occur
    when .psd1 files contain characters like → (Unicode arrows) that break PowerShell's
    restricted language parser, especially on Windows systems.
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$Fix,
    [string[]]$Path
)

# Script metadata (kept as comment for documentation)
# Stage: Testing
# Order: 0405
# Dependencies: 0400
# Tags: testing, validation, manifest, unicode
# RequiresAdmin: No
# SupportsWhatIf: Yes

# Import required functions
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent (Split-Path -Parent $scriptRoot)

# Import ScriptUtilities for common functions
$scriptUtilsPath = Join-Path $projectRoot "aithercore/automation/ScriptUtilities.psm1"
if (Test-Path $scriptUtilsPath) {
    Import-Module $scriptUtilsPath -Force -ErrorAction SilentlyContinue
}

# Source the validation tool
$validationScript = Join-Path $projectRoot "library/automation-scripts/0416_Validate-ModuleManifest.ps1"
if (-not (Test-Path $validationScript)) {
    Write-Error "Validation script not found: $validationScript"
    exit 1
}

try {
    Write-ScriptLog "Starting module manifest validation..." -Level Information -Source "0405"

    # Find all .psd1 files to validate
    if ($Path) {
        $manifestFiles = $Path | Where-Object { Test-Path $_ }
    } else {
        Write-ScriptLog "Discovering .psd1 files in project..." -Level Information
        
        # Find all .psd1 files, excluding test fixtures and config files
        $manifestFiles = Get-ChildItem -Path $projectRoot -Filter "*.psd1" -Recurse | 
            Where-Object { 
                $_.FullName -notlike "*test-fixtures*" -and
                $_.FullName -notlike "*examples*" -and
                $_.Name -notlike "config*.psd1" -and
                $_.Name -ne "PSScriptAnalyzerSettings.psd1"
            } | 
            Select-Object -ExpandProperty FullName
    }

    if ($manifestFiles.Count -eq 0) {
        Write-ScriptLog "No .psd1 files found to validate" -Level Warning
        exit 0
    }

    Write-ScriptLog "Found $($manifestFiles.Count) manifest files to validate" -Level Information

    # Check if we should proceed with validation
    if (-not $PSCmdlet.ShouldProcess("$($manifestFiles.Count) module manifest file(s)", "Validate module manifests")) {
        Write-ScriptLog "WhatIf: Would validate $($manifestFiles.Count) module manifest file(s)" -Level Information
        exit 0
    }

    $totalIssues = 0
    $fixedFiles = 0
    $failedFiles = 0

    foreach ($manifestFile in $manifestFiles) {
        Write-ScriptLog "Validating: $manifestFile" -Level Information
        
        try {
            # Build arguments for validation script
            $validationArgs = @('-Path', $manifestFile)
            if ($Fix) {
                # Check if user approves fixing this specific file
                if (-not $PSCmdlet.ShouldProcess($manifestFile, "Fix Unicode issues")) {
                    Write-ScriptLog "Skipping fixes for: $(Split-Path $manifestFile -Leaf)" -Level Information
                    continue
                }
                $validationArgs += '-Fix'
            }

            # Run validation in a separate PowerShell process to avoid module loading conflicts
            $result = & pwsh -NoProfile -ExecutionPolicy Bypass -File $validationScript @validationArgs 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                Write-ScriptLog "✓ Validation passed: $(Split-Path $manifestFile -Leaf)" -Level Information
                
                # Check if the validation output indicates fixes were applied
                if ($Fix -and ($result -join "`n") -like "*Applied fixes*") {
                    $fixedFiles++
                    Write-ScriptLog "  → Unicode issues were automatically fixed" -Level Information
                }
            } else {
                $failedFiles++
                $totalIssues++
                Write-ScriptLog "✗ Validation failed: $(Split-Path $manifestFile -Leaf)" -Level Error
                
                # Show validation output for debugging
                if ($result) {
                    $result | ForEach-Object { Write-ScriptLog "  $_" -Level Error }
                }
            }
        } catch {
            $failedFiles++
            $totalIssues++
            Write-ScriptLog "✗ Validation error for $(Split-Path $manifestFile -Leaf): $($_.Exception.Message)" -Level Error
        }
    }

    # Summary
    Write-ScriptLog "`nValidation Summary:" -Level Information
    Write-ScriptLog "Files validated: $($manifestFiles.Count)" -Level Information
    Write-ScriptLog "Files passed: $($manifestFiles.Count - $failedFiles)" -Level Information
    
    if ($fixedFiles -gt 0) {
        Write-ScriptLog "Files fixed: $fixedFiles" -Level Information
    }
    
    if ($failedFiles -gt 0) {
        Write-ScriptLog "Files failed: $failedFiles" -Level Error
    }

    if ($totalIssues -eq 0) {
        Write-ScriptLog "✓ All module manifests are valid and free of Unicode issues!" -Level Information
        exit 0
    } else {
        Write-ScriptLog "✗ Found issues in $totalIssues manifest file(s)" -Level Error
        
        if (-not $Fix) {
            Write-ScriptLog "Run with -Fix parameter to automatically resolve Unicode issues" -Level Information
        }
        
        exit 1
    }

} catch {
    Write-ScriptLog "Script execution failed: $($_.Exception.Message)" -Level Error
    exit 1
}
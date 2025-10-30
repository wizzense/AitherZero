#!/usr/bin/env pwsh
#Requires -Version 7.0

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
$projectRoot = Split-Path -Parent $scriptRoot

# Source the validation tool
$validationScript = Join-Path $projectRoot "tools/Validate-ModuleManifest.ps1"
if (-not (Test-Path $validationScript)) {
    Write-Error "Validation script not found: $validationScript"
    exit 1
}

try {
    # Load logging if available
    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        $useLogging = $true
    } else {
        $useLogging = $false
        Write-Verbose "Custom logging not available, using Write-Host"
    }

    function Write-Log {
        param([string]$Message, [string]$Level = 'Information')
        if ($useLogging) {
            Write-CustomLog -Message $Message -Level $Level
        } else {
            $colors = @{
                'Information' = 'White'
                'Success' = 'Green'
                'Warning' = 'Yellow'
                'Error' = 'Red'
            }
            Write-Host $Message -ForegroundColor $colors[$Level]
        }
    }

    # WhatIf support
    if ($WhatIfPreference) {
        Write-Log "WhatIf: Would validate module manifests" -Level Information
        if ($Fix) {
            Write-Log "WhatIf: Would automatically fix Unicode issues" -Level Information
        }
        Write-Log "WhatIf: No changes will be made" -Level Information
        exit 0
    }

    Write-Log "Starting module manifest validation..." -Level Information

    # Find all .psd1 files to validate
    if ($Path) {
        $manifestFiles = $Path | Where-Object { Test-Path $_ }
    } else {
        Write-Log "Discovering .psd1 files in project..." -Level Information
        
        # Find all .psd1 files, excluding legacy migration folders, test fixtures, and config files
        $manifestFiles = Get-ChildItem -Path $projectRoot -Filter "*.psd1" -Recurse | 
            Where-Object { 
                $_.FullName -notlike "*legacy-to-migrate*" -and 
                $_.FullName -notlike "*test-fixtures*" -and
                $_.FullName -notlike "*examples*" -and
                $_.Name -notlike "config*.psd1" -and
                $_.Name -ne "PSScriptAnalyzerSettings.psd1"
            } | 
            Select-Object -ExpandProperty FullName
    }

    if ($manifestFiles.Count -eq 0) {
        Write-Log "No .psd1 files found to validate" -Level Warning
        exit 0
    }

    Write-Log "Found $($manifestFiles.Count) manifest files to validate" -Level Information

    $totalIssues = 0
    $fixedFiles = 0
    $failedFiles = 0

    foreach ($manifestFile in $manifestFiles) {
        Write-Log "Validating: $manifestFile" -Level Information
        
        try {
            # Build arguments for validation script
            $validationArgs = @('-Path', $manifestFile)
            if ($Fix) {
                $validationArgs += '-Fix'
            }

            # Run validation in a separate PowerShell process to avoid module loading conflicts
            $result = & pwsh -NoProfile -ExecutionPolicy Bypass -File $validationScript @validationArgs 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                Write-Log "✓ Validation passed: $(Split-Path $manifestFile -Leaf)" -Level Success
                
                # Check if the validation output indicates fixes were applied
                if ($Fix -and ($result -join "`n") -like "*Applied fixes*") {
                    $fixedFiles++
                    Write-Log "  → Unicode issues were automatically fixed" -Level Success
                }
            } else {
                $failedFiles++
                $totalIssues++
                Write-Log "✗ Validation failed: $(Split-Path $manifestFile -Leaf)" -Level Error
                
                # Show validation output for debugging
                if ($result) {
                    $result | ForEach-Object { Write-Log "  $_" -Level Error }
                }
            }
        } catch {
            $failedFiles++
            $totalIssues++
            Write-Log "✗ Validation error for $(Split-Path $manifestFile -Leaf): $($_.Exception.Message)" -Level Error
        }
    }

    # Summary
    Write-Log "`nValidation Summary:" -Level Information
    Write-Log "Files validated: $($manifestFiles.Count)" -Level Information
    Write-Log "Files passed: $($manifestFiles.Count - $failedFiles)" -Level Success
    
    if ($fixedFiles -gt 0) {
        Write-Log "Files fixed: $fixedFiles" -Level Success
    }
    
    if ($failedFiles -gt 0) {
        Write-Log "Files failed: $failedFiles" -Level Error
    }

    if ($totalIssues -eq 0) {
        Write-Log "✓ All module manifests are valid and free of Unicode issues!" -Level Success
        exit 0
    } else {
        Write-Log "✗ Found issues in $totalIssues manifest file(s)" -Level Error
        
        if (-not $Fix) {
            Write-Log "Run with -Fix parameter to automatically resolve Unicode issues" -Level Information
        }
        
        exit 1
    }

} catch {
    Write-Log "Script execution failed: $($_.Exception.Message)" -Level Error
    exit 1
}
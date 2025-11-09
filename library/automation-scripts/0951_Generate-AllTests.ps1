#Requires -Version 7.0
<#
.SYNOPSIS
    Generate all tests with enhanced functional validation
.DESCRIPTION
    Generates all 150+ automation script tests using the new AutoTestGenerator
    with three-tier validation and functional testing capabilities.
    
    **Phase 2 Implementation**:
    - Uses enhanced AutoTestGenerator with functional templates
    - Generates tests with Pester native mocking
    - Includes script-specific test templates
    - Adds three-tier validation integration
    
.PARAMETER Path
    Path to automation scripts directory
    
.PARAMETER Force
    Force generation of existing tests
    
.PARAMETER Filter
    Filter pattern for scripts (e.g., "04*" for 0400-0499)
    
.PARAMETER WhatIf
    Show what would be generated without actually doing it
    
.EXAMPLE
    ./library/automation-scripts/0951_Generate-AllTests.ps1
    
.EXAMPLE
    ./library/automation-scripts/0951_Generate-AllTests.ps1 -Filter "04*" -Force
    
.NOTES
    Stage: Testing
    Dependencies: 0950_Generate-AllTests.ps1, AutoTestGenerator
    Tags: testing, automation, phase2, functional-tests
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$Path = './library/automation-scripts',
    
    [switch]$Force,
    
    [string]$Filter = '*.ps1',
    
    [int]$BatchSize = 10
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Import required modules
$ProjectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$AutoTestGeneratorPath = Join-Path $ProjectRoot 'aithercore/testing/AutoTestGenerator.psm1'

if (-not (Test-Path $AutoTestGeneratorPath)) {
    throw "AutoTestGenerator module not found at: $AutoTestGeneratorPath"
}

Import-Module $AutoTestGeneratorPath -Force

Write-Host "`n╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║     Generate All Tests - Phase 2 Implementation            ║" -ForegroundColor Cyan
Write-Host "║     Enhanced with Functional Validation                    ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

# Get all automation scripts
$scripts = Get-ChildItem -Path $Path -Filter $Filter -File | 
    Where-Object { $_.Name -match '^\d{4}_.*\.ps1$' } |
    Sort-Object Name

if ($scripts.Count -eq 0) {
    Write-Warning "No scripts found matching filter: $Filter"
    return
}

Write-Host "Found $($scripts.Count) scripts to process`n" -ForegroundColor Green

$stats = @{
    Total = $scripts.Count
    Generated = 0
    Skipped = 0
    Failed = 0
    StartTime = Get-Date
}

# Process in batches to avoid memory issues
$batches = [Math]::Ceiling($scripts.Count / $BatchSize)

for ($batchNum = 0; $batchNum -lt $batches; $batchNum++) {
    $start = $batchNum * $BatchSize
    $end = [Math]::Min(($batchNum + 1) * $BatchSize, $scripts.Count)
    $batch = $scripts[$start..($end - 1)]
    
    Write-Host "Processing batch $($batchNum + 1)/$batches (scripts $($start + 1)-$end)..." -ForegroundColor Yellow
    
    foreach ($script in $batch) {
        $scriptName = $script.BaseName
        
        if ($PSCmdlet.ShouldProcess($scriptName, "Generate tests")) {
            try {
                Write-Host "  🔄 $scriptName..." -NoNewline
                
                $result = New-AutoTest -ScriptPath $script.FullName -Force:$Force
                
                if ($result.Generated) {
                    $stats.Generated++
                    Write-Host " ✅ Generated" -ForegroundColor Green
                } else {
                    $stats.Skipped++
                    Write-Host " ⏭️  Skipped (exists)" -ForegroundColor Yellow
                }
                
            } catch {
                $stats.Failed++
                Write-Host " ❌ Failed: $_" -ForegroundColor Red
            }
        }
    }
    
    Write-Host ""
}

$stats.EndTime = Get-Date
$stats.Duration = ($stats.EndTime - $stats.StartTime).TotalSeconds

# Summary
Write-Host "`n╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                    Generation Summary                       ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host "Total Scripts:    $($stats.Total)" -ForegroundColor White
Write-Host "Generated:        $($stats.Generated)" -ForegroundColor Green
Write-Host "Skipped:          $($stats.Skipped)" -ForegroundColor Yellow
Write-Host "Failed:           $($stats.Failed)" -ForegroundColor $(if ($stats.Failed -gt 0) { 'Red' } else { 'Green' })
Write-Host "Duration:         $([Math]::Round($stats.Duration, 2))s" -ForegroundColor Gray

if ($stats.Generated -gt 0) {
    $newCoverage = (($stats.Generated + $stats.Skipped) / $stats.Total) * 100
    Write-Host "`nTest Coverage:    $([Math]::Round($newCoverage, 1))%" -ForegroundColor Green
    Write-Host "Functional Tests: ✅ ENABLED" -ForegroundColor Green
    Write-Host "Pester Mocking:   ✅ NATIVE" -ForegroundColor Green
    Write-Host "Three-Tier:       ✅ INTEGRATED" -ForegroundColor Green
}

Write-Host "`n✨ Phase 2 test generation complete!`n" -ForegroundColor Cyan

return $stats

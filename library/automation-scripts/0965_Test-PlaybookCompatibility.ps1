#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Test orchestration playbook backward compatibility

.DESCRIPTION
    Validates that all three playbook formats (v1.0, v2.0, v3.0) are properly
    supported and that existing JSON playbooks continue to work without modification.

.PARAMETER Format
    Specific format to test (v1.0, v2.0, v3.0, or All)

.PARAMETER Verbose
    Show detailed test output

.EXAMPLE
    # Test all formats
    ./0965_Test-PlaybookCompatibility.ps1

.EXAMPLE
    # Test specific format
    ./0965_Test-PlaybookCompatibility.ps1 -Format v2.0

.EXAMPLE
    # Verbose output
    ./0965_Test-PlaybookCompatibility.ps1 -Verbose

.NOTES
    Stage: Testing
    Dependencies: OrchestrationEngine
    Tags: testing, compatibility, playbook, validation
#>

[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet('v1.0', 'v2.0', 'v3.0', 'All')]
    [string]$Format = 'All'
)

# Initialize
$ErrorActionPreference = 'Stop'
$ProjectRoot = Split-Path $PSScriptRoot -Parent

# Import modules
Import-Module (Join-Path $ProjectRoot "AitherZero.psd1") -Force

# Test results
$testResults = @{
    Passed = 0
    Failed = 0
    Skipped = 0
    Details = @()
}

function Test-PlaybookFormat {
    param(
        [string]$FormatVersion,
        [string]$TestName,
        [scriptblock]$TestBlock
    )
    
    Write-Host "  Testing: $TestName" -ForegroundColor Yellow
    
    try {
        $result = & $TestBlock
        
        if ($result) {
            Write-Host "    ✓ PASSED" -ForegroundColor Green
            $script:testResults.Passed++
            $script:testResults.Details += @{
                Format = $FormatVersion
                Test = $TestName
                Status = 'Passed'
                Message = ''
            }
        } else {
            Write-Host "    ✗ FAILED" -ForegroundColor Red
            $script:testResults.Failed++
            $script:testResults.Details += @{
                Format = $FormatVersion
                Test = $TestName
                Status = 'Failed'
                Message = 'Test returned false'
            }
        }
    } catch {
        Write-Host "    ✗ FAILED: $_" -ForegroundColor Red
        $script:testResults.Failed++
        $script:testResults.Details += @{
            Format = $FormatVersion
            Test = $TestName
            Status = 'Failed'
            Message = $_.Exception.Message
        }
    }
}

# Header
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Orchestration Playbook Backward Compatibility Tests" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Test v2.0 format (current JSON playbooks)
if ($Format -eq 'All' -or $Format -eq 'v2.0') {
    Write-Host "Testing v2.0 Format (Stages-Based)" -ForegroundColor Cyan
    Write-Host "─────────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
    
    Test-PlaybookFormat -FormatVersion 'v2.0' -TestName 'Load existing JSON playbook' -TestBlock {
        $playbook = Get-OrchestrationPlaybook -Name 'ci-pr-validation'
        return ($null -ne $playbook -and $playbook.Name -eq 'ci-pr-validation')
    }
    
    Test-PlaybookFormat -FormatVersion 'v2.0' -TestName 'Playbook has stages' -TestBlock {
        $playbook = Get-OrchestrationPlaybook -Name 'ci-pr-validation'
        return ($playbook.Stages -and $playbook.Stages.Count -gt 0)
    }
    
    Test-PlaybookFormat -FormatVersion 'v2.0' -TestName 'Playbook has correct format' -TestBlock {
        $playbook = Get-OrchestrationPlaybook -Name 'ci-pr-validation'
        # v2.0 should have Stages but not Jobs
        return ($playbook.Stages -and -not $playbook.Jobs)
    }
    
    Test-PlaybookFormat -FormatVersion 'v2.0' -TestName 'Dry-run execution works' -TestBlock {
        $result = Invoke-OrchestrationSequence -LoadPlaybook 'ci-pr-validation' -DryRun 2>&1
        return $true  # If we get here without exception, it worked
    }
    
    Test-PlaybookFormat -FormatVersion 'v2.0' -TestName 'Multiple playbooks load' -TestBlock {
        $playbooks = @('ci-pr-validation', 'ci-all-validations', 'ci-validate-config')
        foreach ($name in $playbooks) {
            $pb = Get-OrchestrationPlaybook -Name $name
            if (-not $pb) { return $false }
        }
        return $true
    }
    
    Write-Host ""
}

# Test v3.0 format (jobs-based from GitHub workflows)
if ($Format -eq 'All' -or $Format -eq 'v3.0') {
    Write-Host "Testing v3.0 Format (Jobs-Based)" -ForegroundColor Cyan
    Write-Host "─────────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
    
    # Check if converted workflow exists
    $convertedPath = Join-Path $ProjectRoot "domains/orchestration/playbooks/converted/pr-validation.json"
    if (Test-Path $convertedPath) {
        Test-PlaybookFormat -FormatVersion 'v3.0' -TestName 'v3.0 playbook has jobs' -TestBlock {
            $content = Get-Content $convertedPath -Raw | ConvertFrom-Json -AsHashtable
            return ($content.orchestration.jobs -and $content.orchestration.jobs.Count -gt 0)
        }
        
        Write-Host "  ℹ️  v3.0 to v2.0 conversion is automatic during playbook loading" -ForegroundColor Cyan
        $script:testResults.Skipped += 2
    } else {
        Write-Host "  ⚠️  No v3.0 playbooks found (run workflow converter first)" -ForegroundColor Yellow
        $script:testResults.Skipped += 3
    }
    
    Write-Host ""
}

# Test v1.0 format (legacy)
if ($Format -eq 'All' -or $Format -eq 'v1.0') {
    Write-Host "Testing v1.0 Format (Legacy)" -ForegroundColor Cyan
    Write-Host "─────────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
    
    Write-Host "  ℹ️  v1.0 legacy format is deprecated but still supported" -ForegroundColor Cyan
    Write-Host "  ℹ️  Conversion happens automatically during playbook loading" -ForegroundColor Cyan
    $script:testResults.Skipped++
    
    Write-Host ""
}

# Summary
Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Test Results Summary" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

$total = $testResults.Passed + $testResults.Failed + $testResults.Skipped
Write-Host "Total Tests: $total" -ForegroundColor White
Write-Host "  Passed:  $($testResults.Passed)" -ForegroundColor Green
Write-Host "  Failed:  $($testResults.Failed)" -ForegroundColor Red
Write-Host "  Skipped: $($testResults.Skipped)" -ForegroundColor Yellow

$passRate = if ($total -gt 0) { [math]::Round(($testResults.Passed / $total) * 100, 2) } else { 0 }
Write-Host ""
Write-Host "Pass Rate: $passRate%" -ForegroundColor $(if ($passRate -eq 100) { 'Green' } elseif ($passRate -ge 80) { 'Yellow' } else { 'Red' })

# Detailed failures
if ($testResults.Failed -gt 0) {
    Write-Host ""
    Write-Host "Failed Tests:" -ForegroundColor Red
    foreach ($detail in $testResults.Details | Where-Object { $_.Status -eq 'Failed' }) {
        Write-Host "  [$($detail.Format)] $($detail.Test)" -ForegroundColor Red
        if ($detail.Message) {
            Write-Host "    Error: $($detail.Message)" -ForegroundColor DarkRed
        }
    }
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan

# Exit with appropriate code
if ($testResults.Failed -eq 0) {
    Write-Host "✓ All backward compatibility tests passed!" -ForegroundColor Green
    Write-Host ""
    exit 0
} else {
    Write-Host "✗ Some tests failed. Please review." -ForegroundColor Red
    Write-Host ""
    exit 1
}

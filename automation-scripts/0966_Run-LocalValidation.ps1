#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Run local PR validation checks without requiring GitHub Actions.

.DESCRIPTION
    This script provides a local alternative to GitHub Actions workflow checks.
    It runs the same validation steps that would run in CI/CD, allowing developers
    to validate changes before pushing.

.PARAMETER ValidationLevel
    Level of validation to perform:
    - Fast: Quick syntax and config checks (< 2 min)
    - Standard: Syntax, linting, unit tests (< 5 min)
    - Full: Complete validation including integration tests (< 10 min)

.PARAMETER Playbook
    Specific playbook to run. Options:
    - pr-validation-fast
    - pr-validation-full
    - integration-tests-full
    - code-quality-full

.PARAMETER GenerateReport
    Generate a markdown report of the validation results.

.PARAMETER ReportPath
    Path where the validation report should be saved.
    Default: ./reports/local-validation-{timestamp}.md

.EXAMPLE
    ./automation-scripts/0960_Run-LocalValidation.ps1 -ValidationLevel Fast
    Run fast validation (syntax + config)

.EXAMPLE
    ./automation-scripts/0960_Run-LocalValidation.ps1 -ValidationLevel Full -GenerateReport
    Run complete validation and generate report

.EXAMPLE
    ./automation-scripts/0960_Run-LocalValidation.ps1 -Playbook pr-validation-full
    Run specific validation playbook
#>

[CmdletBinding(DefaultParameterSetName = 'Level')]
param(
    [Parameter(ParameterSetName = 'Level')]
    [ValidateSet('Fast', 'Standard', 'Full')]
    [string]$ValidationLevel = 'Standard',
    
    [Parameter(ParameterSetName = 'Playbook', Mandatory = $true)]
    [ValidateSet('pr-validation-fast', 'pr-validation-full', 'integration-tests-full', 'code-quality-full')]
    [string]$Playbook,
    
    [switch]$GenerateReport,
    
    [string]$ReportPath
)

# Script metadata for orchestration
<#
.METADATA
Stage = "Validation"
Dependencies = @("OrchestrationEngine")
Tags = @("validation", "local", "ci-parity", "development")
#>

$ErrorActionPreference = 'Stop'
$ProjectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent

# Import required modules
try {
    Import-Module (Join-Path $ProjectRoot "AitherZero.psd1") -Force -ErrorAction Stop
} catch {
    Write-Error "Failed to import AitherZero module: $_"
    exit 1
}

# Determine which playbook to run
if ($PSCmdlet.ParameterSetName -eq 'Playbook') {
    $selectedPlaybook = $Playbook
} else {
    $selectedPlaybook = switch ($ValidationLevel) {
        'Fast' { 'pr-validation-fast' }
        'Standard' { 'pr-validation-full' }
        'Full' { 'integration-tests-full' }
    }
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Local PR Validation - CI/CD Parity Check" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "Validation Level: " -NoNewline -ForegroundColor White
Write-Host $ValidationLevel -ForegroundColor Yellow
Write-Host "Playbook: " -NoNewline -ForegroundColor White
Write-Host $selectedPlaybook -ForegroundColor Yellow
Write-Host ""

# Configure report path
if (-not $ReportPath) {
    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $ReportPath = Join-Path $ProjectRoot "reports/local-validation-$timestamp.md"
}

# Ensure reports directory exists
$reportsDir = Split-Path $ReportPath -Parent
if (-not (Test-Path $reportsDir)) {
    New-Item -ItemType Directory -Path $reportsDir -Force | Out-Null
}

Write-Host "Starting validation..." -ForegroundColor Cyan
Write-Host ""

$startTime = Get-Date

try {
    # Load configuration and run playbook
    $config = Get-Configuration
    $playbookPath = Join-Path $ProjectRoot "orchestration/playbooks/$selectedPlaybook.psd1"
    
    if (-not (Test-Path $playbookPath)) {
        throw "Playbook not found: $playbookPath"
    }
    
    # Load the playbook data from the .psd1 file
    $playbookData = Import-PowerShellDataFile $playbookPath
    
    if (-not $playbookData.Sequence) {
        throw "Playbook file does not contain a 'Sequence' property: $playbookPath"
    }
    
    # Build sequence from playbook steps - extract script numbers (0407, 0404, etc.)
    $sequenceScripts = @()
    foreach ($step in $playbookData.Sequence) {
        # Extract the script number from filenames like "0407_Validate-Syntax.ps1"
        if ($step.Script -match '^(\d{4})') {
            $sequenceScripts += $matches[1]
        }
    }
    
    # Execute the playbook sequence
    $result = Invoke-OrchestrationSequence -Sequence $sequenceScripts -Configuration $config
    
    $endTime = Get-Date
    $duration = $endTime - $startTime
    
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  Validation Complete" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Duration: " -NoNewline -ForegroundColor White
    Write-Host "$([Math]::Round($duration.TotalMinutes, 2)) minutes" -ForegroundColor Yellow
    Write-Host ""
    
    # Check results
    $allPassed = $true
    if ($result) {
        foreach ($step in $result.Steps) {
            $status = if ($step.Success) { "✓" } else { "✗"; $allPassed = $false }
            $color = if ($step.Success) { "Green" } else { "Red" }
            Write-Host "$status $($step.Name)" -ForegroundColor $color
        }
    }
    
    Write-Host ""
    
    if ($allPassed) {
        Write-Host "✓ All validation checks passed!" -ForegroundColor Green
        Write-Host "  Your changes are ready for PR submission." -ForegroundColor White
        $exitCode = 0
    } else {
        Write-Host "✗ Some validation checks failed." -ForegroundColor Red
        Write-Host "  Please review the output above and fix the issues." -ForegroundColor White
        $exitCode = 1
    }
    
    # Generate report if requested
    if ($GenerateReport) {
        Write-Host ""
        Write-Host "Generating validation report..." -ForegroundColor Cyan
        
        $reportContent = @"
# Local Validation Report

**Generated:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
**Validation Level:** $ValidationLevel
**Playbook:** $selectedPlaybook
**Duration:** $([Math]::Round($duration.TotalMinutes, 2)) minutes
**Status:** $(if ($allPassed) { '✓ PASSED' } else { '✗ FAILED' })

## Results

| Check | Status | Duration |
|-------|--------|----------|
"@
        
        if ($result) {
            foreach ($step in $result.Steps) {
                $status = if ($step.Success) { '✓ Pass' } else { '✗ Fail' }
                $duration = if ($step.Duration) { "$([Math]::Round($step.Duration.TotalSeconds, 1))s" } else { 'N/A' }
                $reportContent += "`n| $($step.Name) | $status | $duration |"
            }
        }
        
        $reportContent += @"


## Next Steps

$(if ($allPassed) {
    '- ✓ All checks passed - ready to submit PR'
    '- Run `git push` to trigger CI/CD workflows'
} else {
    '- ✗ Fix the failing checks above'
    '- Re-run validation: `./automation-scripts/0960_Run-LocalValidation.ps1 -ValidationLevel $ValidationLevel`'
    '- Review detailed logs in `./reports/` and `./tests/results/`'
})

## Comparison with GitHub Actions

This local validation runs the same checks as these workflows:
- `.github/workflows/pr-validation.yml` (syntax, linting)
- `.github/workflows/quality-validation.yml` (code quality)
- `.github/workflows/comprehensive-test-execution.yml` (tests)

By running these checks locally, you can:
- Get faster feedback (no CI queue time)
- Validate changes before pushing
- Work offline or when workflows are disabled
- Debug issues more easily with full output

"@
        
        Set-Content -Path $ReportPath -Value $reportContent -Force
        Write-Host "✓ Report saved to: $ReportPath" -ForegroundColor Green
    }
    
    Write-Host ""
    exit $exitCode
    
} catch {
    Write-Host ""
    Write-Host "✗ Validation failed with error:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host ""
    Write-Host "Stack trace:" -ForegroundColor Yellow
    Write-Host $_.ScriptStackTrace -ForegroundColor Gray
    exit 1
}

#Requires -Version 7.0
<#
.SYNOPSIS
    Validate automated workflow configuration and health
.DESCRIPTION
    Tests the automated workflow chain to ensure all components are properly configured
    and ready to handle test failures, issue creation, and copilot automation.

    This script validates:
    - Workflow file syntax and structure
    - Proper exit code handling in CI
    - Issue creation workflow triggers
    - Copilot automation configuration
    - Label and permission setup

.PARAMETER Quick
    Run quick validation only (skip deep checks)
.PARAMETER Verbose
    Display verbose output during validation
.EXAMPLE
    ./automation-scripts/0840_Validate-WorkflowAutomation.ps1
    Run full validation of workflow automation
.EXAMPLE
    ./automation-scripts/0840_Validate-WorkflowAutomation.ps1 -Quick
    Run quick validation checks only
.NOTES
    Stage: Validation
    Order: 0840
    Dependencies: None
    Tags: validation, workflows, automation, ci-cd
#>

[CmdletBinding()]
param(
    [switch]$Quick
)

$ErrorActionPreference = 'Continue'
Set-StrictMode -Version Latest

# Script metadata
$scriptMetadata = @{
    Stage = 'Validation'
    Order = 0840
    Name = 'Validate-WorkflowAutomation'
    Description = 'Validate automated workflow configuration and health'
    Dependencies = @()
    Tags = @('validation', 'workflows', 'automation', 'ci-cd')
}

# Configuration
$projectRoot = Split-Path $PSScriptRoot -Parent
$workflowsDir = Join-Path $projectRoot ".github/workflows"
$issuesScript = Join-Path $projectRoot "automation-scripts/0830_Generate-IssueFiles.ps1"

$validationResults = @{
    Total = 0
    Passed = 0
    Failed = 0
    Warnings = 0
    Checks = @()
}

function Write-ValidationLog {
    param(
        [string]$Message,
        [ValidateSet('Info', 'Success', 'Warning', 'Error')]
        [string]$Level = 'Info'
    )
    
    $color = switch ($Level) {
        'Error' { 'Red' }
        'Warning' { 'Yellow' }
        'Success' { 'Green' }
        default { 'Cyan' }
    }
    
    $icon = switch ($Level) {
        'Error' { '❌' }
        'Warning' { '⚠️' }
        'Success' { '✅' }
        default { 'ℹ️' }
    }
    
    Write-Host "$icon $Message" -ForegroundColor $color
}

function Add-ValidationCheck {
    param(
        [string]$Name,
        [bool]$Passed,
        [string]$Message = '',
        [string]$Fix = ''
    )
    
    $script:validationResults.Total++
    
    if ($Passed) {
        $script:validationResults.Passed++
        $status = 'Success'
    } else {
        $script:validationResults.Failed++
        $status = 'Error'
    }
    
    $script:validationResults.Checks += @{
        Name = $Name
        Passed = $Passed
        Message = $Message
        Fix = $Fix
        Status = $status
    }
    
    Write-ValidationLog -Message "$Name - $Message" -Level $status
}

function Test-WorkflowFile {
    param([string]$FilePath, [string]$Name)
    
    Write-Host "`n🔍 Checking $Name..." -ForegroundColor Cyan
    
    # Check file exists
    if (-not (Test-Path $FilePath)) {
        Add-ValidationCheck -Name "$Name exists" -Passed $false -Message "File not found: $FilePath"
        return
    }
    
    Add-ValidationCheck -Name "$Name exists" -Passed $true -Message "File found"
    
    # Read file content
    $content = Get-Content $FilePath -Raw -ErrorAction SilentlyContinue
    
    if (-not $content) {
        Add-ValidationCheck -Name "$Name readable" -Passed $false -Message "Cannot read file"
        return
    }
    
    Add-ValidationCheck -Name "$Name readable" -Passed $true -Message "File readable"
    
    # Check for invalid 'exit 0' patterns in test sections
    if ($Name -match 'CI|Test|Orchestrator') {
        $hasInvalidExitZero = $content -match '# Always exit 0 to not block CI'
        
        if ($hasInvalidExitZero) {
            Add-ValidationCheck -Name "$Name exit codes" -Passed $false `
                -Message "Found 'Always exit 0' pattern - tests won't fail properly" `
                -Fix "Change to 'exit 1' when tests fail"
        } else {
            Add-ValidationCheck -Name "$Name exit codes" -Passed $true -Message "Proper exit code handling"
        }
    }
    
    # Check for invalid copilot assignee
    if ($content -match "assignee.*['\`"]copilot['\`"]") {
        Add-ValidationCheck -Name "$Name copilot assignment" -Passed $false `
            -Message "Invalid 'copilot' user assignment found" `
            -Fix "Remove assignee, use 'copilot-task' label instead"
    } else {
        Add-ValidationCheck -Name "$Name copilot assignment" -Passed $true `
            -Message "No invalid copilot assignments"
    }
    
    # Check for proper label usage
    if ($content -match 'copilot-task') {
        Add-ValidationCheck -Name "$Name copilot labels" -Passed $true `
            -Message "Uses copilot-task label correctly"
    }
    
    # Check workflow_run trigger configuration
    if ($Name -match 'auto-create-issues') {
        if ($content -match 'workflow_run\.conclusion.*failure') {
            Add-ValidationCheck -Name "$Name trigger condition" -Passed $false `
                -Message "Only triggers on failures - will miss test results" `
                -Fix "Remove 'conclusion == failure' condition to trigger on all completions"
        } else {
            Add-ValidationCheck -Name "$Name trigger condition" -Passed $true `
                -Message "Triggers on all workflow completions"
        }
    }
}

# Main validation
Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║           Workflow Automation Validation                    ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# 1. Check workflow files exist
Write-ValidationLog -Message "Checking workflow files..." -Level Info

$requiredWorkflows = @{
    'quality-validation.yml' = 'Quality validation workflow'
    'pr-validation.yml' = 'PR validation workflow'
    'auto-create-issues-from-failures.yml' = 'Issue creation from test failures'
    'validate-manifests.yml' = 'Manifest validation'
    'validate-config.yml' = 'Config validation'
}

foreach ($workflow in $requiredWorkflows.Keys) {
    $filePath = Join-Path $workflowsDir $workflow
    Test-WorkflowFile -FilePath $filePath -Name $workflow
}

# 2. Check issue generation scripts
Write-Host "`n🔍 Checking issue automation scripts..." -ForegroundColor Cyan

if (Test-Path $issuesScript) {
    Add-ValidationCheck -Name "Issue generation script exists" -Passed $true `
        -Message "Found $issuesScript"
} else {
    Add-ValidationCheck -Name "Issue generation script exists" -Passed $false `
        -Message "Missing issue generation script" `
        -Fix "Create automation-scripts/0830_Generate-IssueFiles.ps1"
}

# 3. Check for proper exit code handling in test scripts
Write-Host "`n🔍 Checking test script exit codes..." -ForegroundColor Cyan

$testScript = Join-Path $projectRoot "automation-scripts/0402_Run-UnitTests.ps1"
if (Test-Path $testScript) {
    $content = Get-Content $testScript -Raw
    
    # Check for proper exit code logic - look for both patterns
    $hasFailExit = $content -match 'exit 1' -and ($content -match 'FailedCount' -or $content -match 'Failed')
    $hasSuccessExit = $content -match 'exit 0'
    
    if ($hasFailExit -and $hasSuccessExit) {
        Add-ValidationCheck -Name "Test script exit codes" -Passed $true `
            -Message "0402 script has proper exit code handling (exit 0 and exit 1)"
    } else {
        Add-ValidationCheck -Name "Test script exit codes" -Passed $false `
            -Message "0402 script may not exit properly on failure" `
            -Fix "Ensure script exits with 1 when tests fail and 0 when tests pass"
    }
}

# 4. Quick check - skip deep analysis
if ($Quick) {
    Write-Host "`n⚡ Quick mode - skipping deep analysis" -ForegroundColor Yellow
} else {
    # 5. Check Pester configuration
    Write-Host "`n🔍 Checking Pester configuration..." -ForegroundColor Cyan
    
    if (Get-Command Invoke-Pester -ErrorAction SilentlyContinue) {
        Add-ValidationCheck -Name "Pester installed" -Passed $true `
            -Message "Pester module available"
    } else {
        Add-ValidationCheck -Name "Pester installed" -Passed $false `
            -Message "Pester module not found" `
            -Fix "Install-Module Pester -Force"
    }
    
    # 6. Check for test files
    Write-Host "`n🔍 Checking test files..." -ForegroundColor Cyan
    
    $testDirs = @(
        (Join-Path $projectRoot "tests/unit"),
        (Join-Path $projectRoot "tests/integration"),
        (Join-Path $projectRoot "tests/domains")
    )
    
    $totalTests = 0
    foreach ($dir in $testDirs) {
        if (Test-Path $dir) {
            $tests = Get-ChildItem -Path $dir -Filter "*.Tests.ps1" -Recurse -ErrorAction SilentlyContinue
            $totalTests += $tests.Count
        }
    }
    
    if ($totalTests -gt 0) {
        Add-ValidationCheck -Name "Test files found" -Passed $true `
            -Message "Found $totalTests test files"
    } else {
        Add-ValidationCheck -Name "Test files found" -Passed $false `
            -Message "No test files found"
    }
}

# 7. Summary
Write-Host "`n╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                    Validation Summary                        ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

Write-Host "Total Checks: $($validationResults.Total)" -ForegroundColor White
Write-Host "Passed: $($validationResults.Passed)" -ForegroundColor Green
Write-Host "Failed: $($validationResults.Failed)" -ForegroundColor Red
Write-Host "Warnings: $($validationResults.Warnings)" -ForegroundColor Yellow
Write-Host ""

if ($validationResults.Failed -gt 0) {
    Write-Host "❌ VALIDATION FAILED - Issues found that need attention" -ForegroundColor Red
    Write-Host ""
    Write-Host "Failed Checks:" -ForegroundColor Red
    
    $failedChecks = $validationResults.Checks | Where-Object { -not $_.Passed }
    foreach ($check in $failedChecks) {
        Write-Host "  • $($check.Name)" -ForegroundColor Red
        Write-Host "    $($check.Message)" -ForegroundColor DarkRed
        if ($check.Fix) {
            Write-Host "    Fix: $($check.Fix)" -ForegroundColor Yellow
        }
    }
    
    Write-Host "`n💡 To fix these issues, review the workflow files and apply the suggested fixes manually." -ForegroundColor Cyan
    
    exit 1
} else {
    Write-Host "✅ ALL VALIDATION CHECKS PASSED" -ForegroundColor Green
    Write-Host ""
    Write-Host "Workflow automation is properly configured!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "1. Test the workflow chain with a failing test" -ForegroundColor White
    Write-Host "2. Verify issues are automatically created" -ForegroundColor White
    Write-Host "3. Check that @copilot comments are added" -ForegroundColor White
    Write-Host "4. Monitor for automated PR creation" -ForegroundColor White
    Write-Host ""
    Write-Host "See docs/AUTOMATED-WORKFLOW-CHAIN.md for details" -ForegroundColor Cyan
    
    exit 0
}

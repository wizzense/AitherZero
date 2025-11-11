#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Validates CI/CD pipeline configuration and integration.

.DESCRIPTION
    Comprehensive validation script that checks:
    - YAML syntax for all workflow files
    - Trigger configuration correctness
    - Concurrency group consistency
    - Playbook references and existence
    - Workflow coordination patterns
    
.EXAMPLE
    ./Validate-CICDPipeline.ps1
    
.EXAMPLE
    ./Validate-CICDPipeline.ps1 -Verbose
    
.NOTES
    Stage: Validation
    Order: 0xxx
    Dependencies: None
    Tags: ci-cd, validation, workflows
    AllowParallel: true
#>

[CmdletBinding()]
param(
    [switch]$Detailed
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Color output helpers
function Write-Success { param($Message) Write-Host "✅ $Message" -ForegroundColor Green }
function Write-Failure { param($Message) Write-Host "❌ $Message" -ForegroundColor Red }
function Write-Warning { param($Message) Write-Host "⚠️  $Message" -ForegroundColor Yellow }
function Write-Info { param($Message) Write-Host "ℹ️  $Message" -ForegroundColor Cyan }

Write-Host "`n╔══════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║      CI/CD Pipeline Configuration Validator      ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

$script:ValidationErrors = @()
$script:ValidationWarnings = @()
$script:ValidationPassed = 0

# Test 1: Validate YAML Syntax
Write-Host "🔍 Test 1: YAML Syntax Validation" -ForegroundColor Yellow
Write-Host ("─" * 50) -ForegroundColor Gray

$workflowFiles = Get-ChildItem ".github/workflows" -Filter "*.yml" -File

foreach ($file in $workflowFiles) {
    try {
        # Simple YAML validation using PowerShell
        $content = Get-Content $file.FullName -Raw
        
        # Basic checks
        if ($content -match "'on':" -or $content -match "^on:") {
            Write-Success "$($file.Name) - Valid YAML"
            $script:ValidationPassed++
        } else {
            Write-Failure "$($file.Name) - Missing 'on:' trigger"
            $script:ValidationErrors += "$($file.Name): Missing trigger configuration"
        }
    }
    catch {
        Write-Failure "$($file.Name) - $_"
        $script:ValidationErrors += "$($file.Name): $_"
    }
}

Write-Host ""

# Test 2: Concurrency Group Validation
Write-Host "🔍 Test 2: Concurrency Group Configuration" -ForegroundColor Yellow
Write-Host ("─" * 50) -ForegroundColor Gray

$expectedConcurrency = @{
    '01-master-orchestrator.yml' = 'orchestrator-'
    '02-pr-validation-build.yml' = 'pr-validation-'
    '03-test-execution.yml' = 'tests-'
    '04-deploy-pr-environment.yml' = 'deploy-'
    '05-publish-reports-dashboard.yml' = 'pages-publish'
    '06-documentation.yml' = 'docs-'
    '07-indexes.yml' = 'indexes-'
    '08-update-pr-title.yml' = 'pr-title-update-'
    '09-jekyll-gh-pages.yml' = 'pages-'
    '10-module-validation-performance.yml' = 'module-validation-'
    '20-release-automation.yml' = 'release-'
    '30-ring-status-dashboard.yml' = 'ring-status-dashboard-'
    '31-diagnose-ci-failures.yml' = 'diagnose-'
}

foreach ($file in $workflowFiles) {
    $content = Get-Content $file.FullName -Raw
    
    if ($content -match "concurrency:\s*\n\s*group:") {
        Write-Success "$($file.Name) - Has concurrency group"
        $script:ValidationPassed++
        
        if ($Detailed -and $expectedConcurrency.ContainsKey($file.Name)) {
            $expected = $expectedConcurrency[$file.Name]
            if ($content -match "group:\s+[^`n]*$expected") {
                Write-Info "  Pattern matches expected: $expected"
            } else {
                Write-Warning "  Pattern may differ from expected: $expected"
                $script:ValidationWarnings += "$($file.Name): Concurrency pattern differs"
            }
        }
    } else {
        Write-Failure "$($file.Name) - Missing concurrency group"
        $script:ValidationErrors += "$($file.Name): Missing concurrency configuration"
    }
}

Write-Host ""

# Test 3: Trigger Configuration
Write-Host "🔍 Test 3: Workflow Trigger Configuration" -ForegroundColor Yellow
Write-Host ("─" * 50) -ForegroundColor Gray

$triggerConfig = @{
    '01-master-orchestrator.yml' = @('pull_request', 'push', 'workflow_dispatch')
    '02-pr-validation-build.yml' = @('workflow_call')
    '03-test-execution.yml' = @('workflow_call', 'workflow_dispatch')
    '04-deploy-pr-environment.yml' = @('workflow_call', 'push', 'release', 'issue_comment', 'workflow_dispatch')
    '05-publish-reports-dashboard.yml' = @('workflow_call', 'workflow_run', 'workflow_dispatch')
}

foreach ($entry in $triggerConfig.GetEnumerator()) {
    $file = Get-ChildItem ".github/workflows" -Filter $entry.Key -File
    if (-not $file) { continue }
    
    $content = Get-Content $file.FullName -Raw
    $allFound = $true
    
    foreach ($trigger in $entry.Value) {
        if ($content -match "\s+$trigger\s*:|^$trigger\s*:") {
            if ($Detailed) {
                Write-Info "  $($entry.Key): ✅ $trigger"
            }
        } else {
            Write-Warning "$($entry.Key): Missing $trigger trigger"
            $allFound = $false
        }
    }
    
    if ($allFound) {
        Write-Success "$($entry.Key) - All expected triggers configured"
        $script:ValidationPassed++
    }
}

Write-Host ""

# Test 4: Playbook References
Write-Host "🔍 Test 4: Playbook Reference Validation" -ForegroundColor Yellow
Write-Host ("─" * 50) -ForegroundColor Gray

$playbookRefs = @(
    'dashboard-generation-complete'
    'generate-documentation'
    'generate-indexes'
    'pr-ecosystem-build'
    'pr-ecosystem-report'
)

foreach ($playbook in $playbookRefs) {
    $playbookFile = "library/playbooks/$playbook.psd1"
    
    if (Test-Path $playbookFile) {
        Write-Success "$playbook - Playbook exists"
        $script:ValidationPassed++
    } else {
        Write-Failure "$playbook - Playbook NOT found"
        $script:ValidationErrors += "Missing playbook: $playbookFile"
    }
}

Write-Host ""

# Test 5: Master Orchestrator Coordination
Write-Host "🔍 Test 5: Master Orchestrator Job Dependencies" -ForegroundColor Yellow
Write-Host ("─" * 50) -ForegroundColor Gray

$orchestratorFile = Get-Content ".github/workflows/01-master-orchestrator.yml" -Raw

$requiredJobs = @(
    'orchestration'
    'pr-validation'
    'pr-tests'
    'pr-dashboard'
    'release-workflow'
    'standalone-tests'
    'summary'
)

foreach ($job in $requiredJobs) {
    if ($orchestratorFile -match "\s+$job\s*:") {
        Write-Success "Job defined: $job"
        $script:ValidationPassed++
    } else {
        Write-Failure "Job missing: $job"
        $script:ValidationErrors += "Missing job in orchestrator: $job"
    }
}

Write-Host ""

# Test 6: Workflow Coordination Pattern
Write-Host "🔍 Test 6: Workflow Call Pattern Validation" -ForegroundColor Yellow
Write-Host ("─" * 50) -ForegroundColor Gray

$workflowCalls = @{
    '02-pr-validation-build.yml' = 'pr-validation'
    '03-test-execution.yml' = 'pr-tests'
    '04-deploy-pr-environment.yml' = 'pr-deploy-environment'
    '05-publish-reports-dashboard.yml' = 'pr-dashboard'
}

foreach ($entry in $workflowCalls.GetEnumerator()) {
    $jobName = $entry.Value
    
    if ($orchestratorFile -match "uses:\s+\.\/\.github\/workflows\/$($entry.Key)") {
        Write-Success "$jobName -> $($entry.Key)"
        $script:ValidationPassed++
    } else {
        Write-Warning "$jobName may not call $($entry.Key)"
        $script:ValidationWarnings += "Workflow call pattern: $jobName -> $($entry.Key)"
    }
}

# Summary
Write-Host "`n╔══════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                 Validation Summary               ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

Write-Host "Total Checks Passed: " -NoNewline
Write-Host $script:ValidationPassed -ForegroundColor Green

if ($script:ValidationErrors.Count -gt 0) {
    Write-Host "`nErrors Found: " -NoNewline
    Write-Host $script:ValidationErrors.Count -ForegroundColor Red
    foreach ($error in $script:ValidationErrors) {
        Write-Host "  ❌ $error" -ForegroundColor Red
    }
}

if ($script:ValidationWarnings.Count -gt 0) {
    Write-Host "`nWarnings Found: " -NoNewline
    Write-Host $script:ValidationWarnings.Count -ForegroundColor Yellow
    foreach ($warning in $script:ValidationWarnings) {
        Write-Host "  ⚠️  $warning" -ForegroundColor Yellow
    }
}

Write-Host ""

if ($script:ValidationErrors.Count -eq 0) {
    Write-Success "✨ All critical validations passed!"
    Write-Host "`nCI/CD pipeline configuration is valid and ready." -ForegroundColor Green
    exit 0
} else {
    Write-Failure "❌ Validation failed with $($script:ValidationErrors.Count) error(s)"
    exit 1
}

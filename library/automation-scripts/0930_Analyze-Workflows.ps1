#Requires -Version 7.0

<#
.SYNOPSIS
    Analyze GitHub Actions workflows for triggers, usage, and status
.DESCRIPTION
    Comprehensive analysis of all GitHub Actions workflows including:
    - Trigger types (pull_request, push, workflow_call, etc.)
    - Workflow dependencies (which workflows call which)
    - Active vs inactive workflows
    - YAML syntax validation
    
    Exit Codes:
    0   - Success
    1   - Validation errors found
    
.NOTES
    Stage: Validation
    Order: 0930
    Dependencies: None
    Tags: workflows, github-actions, validation, analysis
    AllowParallel: false
#>

[CmdletBinding()]
param(
    [switch]$ValidateYAML = $true,
    [switch]$CheckUsage = $true,
    [switch]$OutputJSON = $false,
    [string]$OutputPath = "./library/reports/workflow-analysis.json"
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Ensure TERM is set for terminal operations
if (-not $env:TERM) {
    $env:TERM = 'xterm-256color'
}

# Import ScriptUtilities
$projectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
Import-Module (Join-Path $projectRoot "aithercore/automation/ScriptUtilities.psm1") -Force -ErrorAction SilentlyContinue

Write-Host "🔍 Analyzing GitHub Actions Workflows" -ForegroundColor Cyan
Write-Host ""

$workflowDir = Join-Path $projectRoot ".github/workflows"
$workflows = Get-ChildItem -Path $workflowDir -Filter "*.yml" -File

$results = @{
    Total = $workflows.Count
    Valid = 0
    Invalid = 0
    Active = 0
    Inactive = 0
    ManualOnly = 0
    Workflows = @()
}

foreach ($workflow in $workflows) {
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
    Write-Host "📋 $($workflow.Name)" -ForegroundColor Yellow
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
    
    $workflowInfo = @{
        Name = $workflow.Name
        Path = $workflow.FullName
        Valid = $false
        Triggers = @()
        CalledBy = @()
        Status = "Unknown"
    }
    
    # Validate YAML
    if ($ValidateYAML) {
        try {
            $content = Get-Content $workflow.FullName -Raw
            # Simple YAML validation - check for basic structure
            if ($content -match '^---' -and $content -match 'name:' -and $content -match 'jobs:') {
                Write-Host "  ✅ YAML Valid" -ForegroundColor Green
                $workflowInfo.Valid = $true
                $results.Valid++
            } else {
                Write-Host "  ❌ YAML Invalid" -ForegroundColor Red
                $results.Invalid++
            }
        } catch {
            Write-Host "  ❌ YAML Invalid: $_" -ForegroundColor Red
            $results.Invalid++
        }
    }
    
    # Analyze triggers
    $content = Get-Content $workflow.FullName -Raw
    
    Write-Host ""
    Write-Host "TRIGGERS:" -ForegroundColor Cyan
    
    if ($content -match 'pull_request:') {
        Write-Host "  ✓ pull_request" -ForegroundColor Green
        $workflowInfo.Triggers += "pull_request"
    }
    if ($content -match 'push:') {
        Write-Host "  ✓ push" -ForegroundColor Green
        $workflowInfo.Triggers += "push"
    }
    if ($content -match 'workflow_call:') {
        Write-Host "  ✓ workflow_call (called by other workflows)" -ForegroundColor Green
        $workflowInfo.Triggers += "workflow_call"
    }
    if ($content -match 'workflow_dispatch:') {
        Write-Host "  ✓ workflow_dispatch (manual)" -ForegroundColor Green
        $workflowInfo.Triggers += "workflow_dispatch"
    }
    if ($content -match 'workflow_run:') {
        Write-Host "  ✓ workflow_run (triggered by other workflows)" -ForegroundColor Green
        $workflowInfo.Triggers += "workflow_run"
    }
    if ($content -match 'schedule:') {
        Write-Host "  ✓ schedule (cron)" -ForegroundColor Green
        $workflowInfo.Triggers += "schedule"
    }
    
    if ($workflowInfo.Triggers.Count -eq 0) {
        Write-Host "  ⚠️  NO TRIGGERS DEFINED!" -ForegroundColor Red
    }
    
    # Check if called by other workflows
    if ($CheckUsage) {
        Write-Host ""
        Write-Host "CALLED BY:" -ForegroundColor Cyan
        
        foreach ($otherWorkflow in $workflows) {
            if ($otherWorkflow.Name -eq $workflow.Name) { continue }
            
            $otherContent = Get-Content $otherWorkflow.FullName -Raw
            if ($otherContent -match "uses:.*$($workflow.Name)" -or 
                $otherContent -match "\./\.github/workflows/$($workflow.Name)") {
                Write-Host "  → $($otherWorkflow.Name)" -ForegroundColor Yellow
                $workflowInfo.CalledBy += $otherWorkflow.Name
            }
        }
        
        if ($workflowInfo.CalledBy.Count -eq 0) {
            Write-Host "  (not called by other workflows)" -ForegroundColor Gray
        }
    }
    
    # Determine status
    if ($workflowInfo.Triggers.Count -eq 0) {
        $workflowInfo.Status = "INACTIVE"
        $results.Inactive++
        Write-Host ""
        Write-Host "STATUS: ❌ INACTIVE (no triggers)" -ForegroundColor Red
    }
    elseif ($workflowInfo.Triggers -contains "pull_request" -or 
            $workflowInfo.Triggers -contains "push" -or
            $workflowInfo.Triggers -contains "workflow_run" -or
            $workflowInfo.Triggers -contains "schedule") {
        $workflowInfo.Status = "ACTIVE"
        $results.Active++
        Write-Host ""
        Write-Host "STATUS: ✅ ACTIVE (automatic triggers)" -ForegroundColor Green
    }
    elseif ($workflowInfo.Triggers -contains "workflow_dispatch" -and $workflowInfo.Triggers.Count -eq 1) {
        $workflowInfo.Status = "MANUAL"
        $results.ManualOnly++
        Write-Host ""
        Write-Host "STATUS: ⚠️  MANUAL ONLY (workflow_dispatch only)" -ForegroundColor Yellow
    }
    else {
        $workflowInfo.Status = "ACTIVE"
        $results.Active++
        Write-Host ""
        Write-Host "STATUS: ✅ ACTIVE" -ForegroundColor Green
    }
    
    $results.Workflows += $workflowInfo
    Write-Host ""
}

# Summary
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "📊 WORKFLOW ANALYSIS SUMMARY" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host ""
Write-Host "Total Workflows: $($results.Total)" -ForegroundColor White
Write-Host "  ✅ Valid YAML: $($results.Valid)" -ForegroundColor Green
Write-Host "  ❌ Invalid YAML: $($results.Invalid)" -ForegroundColor Red
Write-Host ""
Write-Host "  ✅ Active: $($results.Active)" -ForegroundColor Green
Write-Host "  ⚠️  Manual Only: $($results.ManualOnly)" -ForegroundColor Yellow
Write-Host "  ❌ Inactive: $($results.Inactive)" -ForegroundColor Red
Write-Host ""

if ($OutputJSON) {
    $resultsDir = Split-Path $OutputPath -Parent
    if (-not (Test-Path $resultsDir)) {
        New-Item -ItemType Directory -Path $resultsDir -Force | Out-Null
    }
    
    $results | ConvertTo-Json -Depth 10 | Out-File -FilePath $OutputPath -Encoding UTF8
    Write-Host "✅ Analysis saved to: $OutputPath" -ForegroundColor Green
}

if ($results.Invalid -gt 0 -or $results.Inactive -gt 0) {
    Write-Host ""
    Write-Host "⚠️  WARNING: Found $($results.Invalid) invalid and $($results.Inactive) inactive workflows" -ForegroundColor Yellow
    exit 1
}

exit 0

#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Convert and execute GitHub Actions workflows locally

.DESCRIPTION
    Parse GitHub Actions YAML workflow files and execute them locally using the
    AitherZero orchestration engine. Enables seamless workflow migration from
    GitHub Actions to local orchestration.

.PARAMETER WorkflowPath
    Path to the GitHub Actions workflow YAML file (e.g., .github/workflows/test.yml)

.PARAMETER JobId
    Optional specific job to run. If not specified, converts all jobs.

.PARAMETER ConvertOnly
    Only convert the workflow to a playbook without executing

.PARAMETER Execute
    Execute the converted workflow locally

.PARAMETER DryRun
    Show what would be executed without running

.PARAMETER UseCache
    Enable caching for workflow execution

.PARAMETER GenerateSummary
    Generate execution summary report

.PARAMETER OutputPlaybook
    Path to save the converted playbook

.EXAMPLE
    # Convert a workflow and show the result
    ./0964_Run-GitHubWorkflow.ps1 -WorkflowPath ".github/workflows/test.yml" -ConvertOnly

.EXAMPLE
    # Convert and execute a workflow
    ./0964_Run-GitHubWorkflow.ps1 -WorkflowPath ".github/workflows/test.yml" -Execute

.EXAMPLE
    # Dry run to see execution plan
    ./0964_Run-GitHubWorkflow.ps1 -WorkflowPath ".github/workflows/test.yml" -DryRun

.EXAMPLE
    # Execute with caching and summary
    ./0964_Run-GitHubWorkflow.ps1 -WorkflowPath ".github/workflows/test.yml" -Execute -UseCache -GenerateSummary

.NOTES
    Stage: Development
    Dependencies: GitHubWorkflowParser, powershell-yaml
    Tags: github-actions, workflow, conversion, orchestration
#>

[CmdletBinding(DefaultParameterSetName = 'Convert')]
param(
    [Parameter(Mandatory, Position = 0)]
    [string]$WorkflowPath,

    [Parameter()]
    [string]$JobId,

    [Parameter(ParameterSetName = 'Convert')]
    [switch]$ConvertOnly,

    [Parameter(ParameterSetName = 'Execute')]
    [switch]$Execute,

    [Parameter()]
    [switch]$DryRun,

    [Parameter()]
    [switch]$UseCache,

    [Parameter()]
    [switch]$GenerateSummary,

    [Parameter()]
    [string]$OutputPlaybook
)

# Initialize
$ErrorActionPreference = 'Stop'
$ProjectRoot = Split-Path $PSScriptRoot -Parent

# Import required modules
try {
    Import-Module (Join-Path $ProjectRoot "domains/automation/GitHubWorkflowParser.psm1") -Force
    Write-Verbose "Loaded GitHubWorkflowParser module"
} catch {
    Write-Error "Failed to load GitHubWorkflowParser module: $_"
    exit 1
}

# Check for powershell-yaml module
if (-not (Get-Module -ListAvailable -Name powershell-yaml)) {
    Write-Host "⚠️  powershell-yaml module is required but not installed." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "To install it, run:" -ForegroundColor Cyan
    Write-Host "  Install-Module powershell-yaml -Scope CurrentUser" -ForegroundColor White
    Write-Host ""
    
    $install = Read-Host "Would you like to install it now? (y/N)"
    if ($install -eq 'y' -or $install -eq 'Y') {
        try {
            Install-Module powershell-yaml -Scope CurrentUser -Force
            Write-Host "✓ powershell-yaml installed successfully" -ForegroundColor Green
        } catch {
            Write-Error "Failed to install powershell-yaml: $_"
            exit 1
        }
    } else {
        Write-Error "powershell-yaml is required to parse YAML workflows"
        exit 1
    }
}

# Validate workflow path
if (-not (Test-Path $WorkflowPath)) {
    Write-Error "Workflow file not found: $WorkflowPath"
    exit 1
}

# Display header
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  GitHub Actions Workflow → AitherZero Orchestration" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

Write-Host "Workflow File: $WorkflowPath" -ForegroundColor White
if ($JobId) {
    Write-Host "Target Job: $JobId" -ForegroundColor White
}
Write-Host ""

try {
    # Convert the workflow
    Write-Host "Converting workflow..." -ForegroundColor Yellow
    
    $playbook = ConvertFrom-GitHubWorkflow -WorkflowPath $WorkflowPath -Verbose:$VerbosePreference
    
    Write-Host "✓ Conversion successful" -ForegroundColor Green
    Write-Host ""
    
    # Display conversion summary
    Write-Host "Conversion Summary:" -ForegroundColor Cyan
    Write-Host "  Name: $($playbook.metadata.name)" -ForegroundColor White
    Write-Host "  Description: $($playbook.metadata.description)" -ForegroundColor White
    Write-Host "  Jobs: $($playbook.orchestration.jobs.Count)" -ForegroundColor White
    
    # List jobs
    Write-Host ""
    Write-Host "Jobs:" -ForegroundColor Cyan
    foreach ($jobKey in $playbook.orchestration.jobs.Keys) {
        $job = $playbook.orchestration.jobs[$jobKey]
        $stepCount = if ($job.steps) { $job.steps.Count } else { 0 }
        Write-Host "  [$jobKey] $($job.name) - $stepCount steps" -ForegroundColor White
        
        # Show matrix if present
        if ($job.strategy -and $job.strategy.matrix) {
            $dimensions = $job.strategy.matrix.Keys -join ', '
            Write-Host "    Matrix: $dimensions" -ForegroundColor DarkGray
        }
        
        # Show dependencies
        if ($job.needs) {
            $deps = $job.needs -join ', '
            Write-Host "    Needs: $deps" -ForegroundColor DarkGray
        }
    }
    
    # Save the playbook if requested or if not executing
    $savedPath = $null
    if ($OutputPlaybook) {
        $savedPath = $OutputPlaybook
    } elseif (-not $Execute) {
        # Auto-save to converted directory
        $workflowName = [System.IO.Path]::GetFileNameWithoutExtension($WorkflowPath)
        $savedPath = Join-Path $ProjectRoot "domains/orchestration/playbooks/converted/$workflowName.json"
    }
    
    if ($savedPath) {
        $playbookDir = Split-Path $savedPath -Parent
        if (-not (Test-Path $playbookDir)) {
            New-Item -ItemType Directory -Path $playbookDir -Force | Out-Null
        }
        
        $playbook | ConvertTo-Json -Depth 20 | Set-Content -Path $savedPath
        Write-Host ""
        Write-Host "✓ Playbook saved to: $savedPath" -ForegroundColor Green
    }
    
    # Show playbook structure if dry run
    if ($DryRun) {
        Write-Host ""
        Write-Host "Playbook Structure:" -ForegroundColor Cyan
        Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
        $playbook | ConvertTo-Json -Depth 10 | Write-Host
    }
    
    # Execute if requested
    if ($Execute -and -not $DryRun) {
        Write-Host ""
        Write-Host "Execution:" -ForegroundColor Cyan
        Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host ""
        
        Write-Host "⚠️  Note: Full v3 schema execution is in development." -ForegroundColor Yellow
        Write-Host "The workflow has been converted to a playbook format." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "To execute manually:" -ForegroundColor Cyan
        Write-Host "  1. Review the converted playbook: $savedPath" -ForegroundColor White
        Write-Host "  2. Map jobs to AitherZero scripts (0000-9999)" -ForegroundColor White
        Write-Host "  3. Execute using orchestration engine" -ForegroundColor White
        Write-Host ""
        Write-Host "Coming soon: Direct execution of v3 playbook format!" -ForegroundColor Yellow
    }
    
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  Conversion Complete!" -ForegroundColor Green
    Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    
    # Show next steps
    if ($ConvertOnly -or (-not $Execute)) {
        Write-Host "Next Steps:" -ForegroundColor Cyan
        Write-Host "  • Review the converted playbook structure" -ForegroundColor White
        Write-Host "  • Map GitHub Actions to AitherZero scripts" -ForegroundColor White
        Write-Host "  • Test execution with -DryRun flag" -ForegroundColor White
        Write-Host "  • Execute with -Execute flag" -ForegroundColor White
        Write-Host ""
    }
    
    exit 0
    
} catch {
    Write-Host ""
    Write-Host "✗ Conversion failed:" -ForegroundColor Red
    Write-Host "  $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    
    if ($VerbosePreference -eq 'Continue') {
        Write-Host "Stack trace:" -ForegroundColor Yellow
        Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
    }
    
    exit 1
}

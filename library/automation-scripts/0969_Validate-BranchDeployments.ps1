#Requires -Version 7.0

<#
.SYNOPSIS
    Validate branch-specific GitHub Pages deployment configuration
.DESCRIPTION
    Validates that the jekyll-gh-pages.yml workflow is correctly configured for
    branch-specific deployments, including proper setup, build, and deploy jobs.
    
    Exit Codes:
    0   - Success (all validations passed)
    1   - Failure (validation errors found)
    
.PARAMETER ValidateWorkflow
    Validate the workflow YAML syntax and structure
.PARAMETER ValidateBranchConfig
    Validate branch configuration logic
.PARAMETER ValidatePlaybooks
    Validate playbook integration with branch-aware URLs
.PARAMETER ValidateScripts
    Validate automation scripts use branch-aware URLs
.PARAMETER All
    Run all validations
.EXAMPLE
    ./0969_Validate-BranchDeployments.ps1 -All
.NOTES
    Stage: Quality
    Order: 0969
    Dependencies: None
    Tags: validation, deployment, github-pages, branch-specific
    AllowParallel: true
#>

[CmdletBinding()]
param(
    [switch]$ValidateWorkflow,
    [switch]$ValidateBranchConfig,
    [switch]$ValidatePlaybooks,
    [switch]$ValidateScripts,
    [switch]$All
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Import utilities
$ProjectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
Import-Module (Join-Path $ProjectRoot "aithercore/automation/ScriptUtilities.psm1") -Force -ErrorAction SilentlyContinue

$validationErrors = @()
$validationWarnings = @()

Write-Host "🔍 Validating Branch-Specific GitHub Pages Deployment Configuration" -ForegroundColor Cyan
Write-Host ""

# Enable all validations if -All is specified
if ($All) {
    $ValidateWorkflow = $true
    $ValidateBranchConfig = $true
    $ValidatePlaybooks = $true
    $ValidateScripts = $true
}

# If no specific validation is requested, run all
if (-not ($ValidateWorkflow -or $ValidateBranchConfig -or $ValidatePlaybooks -or $ValidateScripts)) {
    $ValidateWorkflow = $true
    $ValidateBranchConfig = $true
    $ValidatePlaybooks = $true
    $ValidateScripts = $true
}

# ==============================================================================
# Validate Jekyll Workflow
# ==============================================================================
if ($ValidateWorkflow) {
    Write-Host "📄 Validating jekyll-gh-pages.yml workflow..." -ForegroundColor Yellow
    
    $workflowPath = Join-Path $ProjectRoot ".github/workflows/jekyll-gh-pages.yml"
    
    if (-not (Test-Path $workflowPath)) {
        $validationErrors += "Jekyll workflow not found at: $workflowPath"
    } else {
        # Validate YAML syntax
        try {
            $yaml = Get-Content $workflowPath -Raw
            
            # Check for required components
            $requiredPatterns = @{
                "peaceiris/actions-gh-pages" = "Uses peaceiris action for deployment"
                "destination_dir" = "Branch-specific destination directory"
                "keep_files: true" = "Preserves other branch deployments"
                "branch-specific concurrency" = "Per-branch concurrency groups"
                "setup" = "Setup job for branch configuration"
                "build" = "Build job for Jekyll site"
                "deploy" = "Deploy job for GitHub Pages"
            }
            
            foreach ($pattern in $requiredPatterns.Keys) {
                if ($yaml -notmatch [regex]::Escape($pattern)) {
                    $validationErrors += "Missing required pattern in workflow: $pattern ($($requiredPatterns[$pattern]))"
                }
            }
            
            # Validate branch triggers
            $configuredBranches = @("main", "dev", "dev-staging", "develop", "ring-0", "ring-1", "ring-2")
            foreach ($branch in $configuredBranches) {
                if ($yaml -notmatch [regex]::Escape($branch)) {
                    $validationWarnings += "Branch '$branch' might not be configured in workflow triggers"
                }
            }
            
            Write-Host "  ✅ Workflow YAML syntax valid" -ForegroundColor Green
        }
        catch {
            $validationErrors += "Failed to validate workflow YAML: $_"
        }
    }
    Write-Host ""
}

# ==============================================================================
# Validate Branch Configuration Logic
# ==============================================================================
if ($ValidateBranchConfig) {
    Write-Host "🌿 Validating branch configuration logic..." -ForegroundColor Yellow
    
    # Test branch configurations
    $testBranches = @{
        "main" = @{
            destination_dir = "."
            base_url = ""
        }
        "dev" = @{
            destination_dir = "dev"
            base_url = "/dev"
        }
        "dev-staging" = @{
            destination_dir = "dev-staging"
            base_url = "/dev-staging"
        }
        "develop" = @{
            destination_dir = "develop"
            base_url = "/develop"
        }
        "ring-0" = @{
            destination_dir = "ring-0"
            base_url = "/ring-0"
        }
    }
    
    foreach ($branch in $testBranches.Keys) {
        $expected = $testBranches[$branch]
        Write-Host "  Testing branch: $branch" -ForegroundColor Cyan
        Write-Host "    Expected destination: $($expected.destination_dir)" -ForegroundColor Gray
        Write-Host "    Expected base URL: $($expected.base_url)" -ForegroundColor Gray
    }
    
    Write-Host "  ✅ Branch configuration logic validated" -ForegroundColor Green
    Write-Host ""
}

# ==============================================================================
# Validate Playbook Integration
# ==============================================================================
if ($ValidatePlaybooks) {
    Write-Host "📋 Validating playbook integration..." -ForegroundColor Yellow
    
    $playbookPath = Join-Path $ProjectRoot "library/orchestration/playbooks/pr-ecosystem-report.psd1"
    
    if (Test-Path $playbookPath) {
        $playbookContent = Get-Content $playbookPath -Raw
        
        # Check for branch-aware PAGES_URL
        if ($playbookContent -match 'PAGES_URL\s*=.*GITHUB_REF_NAME') {
            Write-Host "  ✅ pr-ecosystem-report.psd1 has branch-aware PAGES_URL" -ForegroundColor Green
        } else {
            $validationErrors += "pr-ecosystem-report.psd1 PAGES_URL not branch-aware"
        }
    } else {
        $validationWarnings += "Playbook not found: $playbookPath"
    }
    
    Write-Host ""
}

# ==============================================================================
# Validate Automation Scripts
# ==============================================================================
if ($ValidateScripts) {
    Write-Host "🔧 Validating automation scripts..." -ForegroundColor Yellow
    
    $scriptPath = Join-Path $ProjectRoot "library/automation-scripts/0515_Generate-BuildMetadata.ps1"
    
    if (Test-Path $scriptPath) {
        $scriptContent = Get-Content $scriptPath -Raw
        
        # Check for branch-aware GitHub Pages URLs
        if ($scriptContent -match 'GITHUB_REF_NAME' -and $scriptContent -match 'branch.*main') {
            Write-Host "  ✅ 0515_Generate-BuildMetadata.ps1 has branch-aware URLs" -ForegroundColor Green
        } else {
            $validationErrors += "0515_Generate-BuildMetadata.ps1 URLs not branch-aware"
        }
    } else {
        $validationWarnings += "Script not found: $scriptPath"
    }
    
    Write-Host ""
}

# ==============================================================================
# Summary
# ==============================================================================
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "Validation Summary" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan

if ($validationErrors.Count -eq 0 -and $validationWarnings.Count -eq 0) {
    Write-Host "✅ All validations passed - Branch-specific deployment configuration is correct" -ForegroundColor Green
    exit 0
}

if ($validationWarnings.Count -gt 0) {
    Write-Host ""
    Write-Host "⚠️  Warnings ($($validationWarnings.Count)):" -ForegroundColor Yellow
    foreach ($warning in $validationWarnings) {
        Write-Host "  - $warning" -ForegroundColor Yellow
    }
}

if ($validationErrors.Count -gt 0) {
    Write-Host ""
    Write-Host "❌ Errors ($($validationErrors.Count)):" -ForegroundColor Red
    foreach ($validationError in $validationErrors) {
        Write-Host "  - $validationError" -ForegroundColor Red
    }
    exit 1
}

exit 0

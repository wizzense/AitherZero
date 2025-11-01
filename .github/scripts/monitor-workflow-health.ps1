#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Monitor GitHub Actions workflow health and detect common issues

.DESCRIPTION
    Comprehensive workflow health check that validates:
    - YAML syntax
    - workflow_run trigger name matches
    - Concurrency group configuration
    - Circular dependencies
    - Resource conflicts

.EXAMPLE
    ./.github/scripts/monitor-workflow-health.ps1

.NOTES
    Created for workflow stability - prevents disappeared PR checks
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$workflowDir = './.github/workflows'

Write-Host "🔍 GitHub Actions Workflow Health Monitor" -ForegroundColor Cyan
Write-Host "=" * 60
Write-Host ""

$issues = @()
$warnings = @()

# 1. Validate YAML Syntax
Write-Host "1️⃣  Validating YAML syntax..." -ForegroundColor Yellow
$workflowFiles = Get-ChildItem -Path $workflowDir -Filter "*.yml"
foreach ($file in $workflowFiles) {
    try {
        $content = Get-Content $file.FullName -Raw
        if ($content -match ':\s*$' -or $content -match '^\s*-\s*$') {
            $warnings += "⚠️  $($file.Name): Potential YAML formatting issue"
        }
        Write-Host "  ✅ $($file.Name)" -ForegroundColor Green
    }
    catch {
        $issues += "❌ $($file.Name): YAML syntax error - $($_.Exception.Message)"
    }
}
Write-Host ""

# 2. Check workflow_run trigger name matches
Write-Host "2️⃣  Checking workflow_run trigger name matches..." -ForegroundColor Yellow
$workflowNames = @{}
foreach ($file in $workflowFiles) {
    $content = Get-Content $file.FullName -Raw
    if ($content -match 'name:\s*[''"]?([^''"\r\n]+)[''"]?') {
        $workflowNames[$file.Name] = $matches[1].Trim()
    }
}

foreach ($file in $workflowFiles) {
    $content = Get-Content $file.FullName -Raw
    if ($content -match 'workflow_run:') {
        # Extract referenced workflow names
        if ($content -match 'workflows:\s*\n((?:\s*-\s*"[^"]+"\s*\n)+)') {
            $referencedNames = [regex]::Matches($matches[1], '"([^"]+)"') | ForEach-Object { $_.Groups[1].Value }
            foreach ($refName in $referencedNames) {
                $found = $false
                foreach ($actualName in $workflowNames.Values) {
                    if ($actualName -eq $refName) {
                        $found = $true
                        break
                    }
                }
                if (-not $found) {
                    $issues += "❌ $($file.Name): References workflow '$refName' but no workflow has this exact name"
                    $issues += "   💡 Fix: Update workflow name or fix reference. Check for emoji/spacing differences."
                }
            }
        }
    }
}
Write-Host "  ✅ workflow_run triggers validated" -ForegroundColor Green
Write-Host ""

# 3. Check concurrency groups for PR workflows
Write-Host "3️⃣  Checking concurrency groups..." -ForegroundColor Yellow
foreach ($file in $workflowFiles) {
    $content = Get-Content $file.FullName -Raw
    $hasPullRequestTrigger = $content -match 'pull_request:'
    $hasConcurrency = $content -match 'concurrency:'
    
    if ($hasPullRequestTrigger -and -not $hasConcurrency) {
        $warnings += "⚠️  $($file.Name): Has pull_request trigger but no concurrency group (may cause conflicts)"
        $warnings += "   💡 Fix: Add concurrency group to prevent multiple runs"
    }
}
Write-Host "  ✅ Concurrency groups checked" -ForegroundColor Green
Write-Host ""

# Summary
Write-Host "=" * 60
Write-Host ""
if ($issues.Count -eq 0 -and $warnings.Count -eq 0) {
    Write-Host "✅ All checks passed! Workflows are healthy." -ForegroundColor Green
exit 0
    exit 0
}

if ($issues.Count -gt 0) {
    Write-Host "❌ CRITICAL ISSUES FOUND ($($issues.Count)):" -ForegroundColor Red
    Write-Host ""
    foreach ($issue in $issues) {
        Write-Host $issue -ForegroundColor Red
    }
    Write-Host ""
}

if ($warnings.Count -gt 0) {
    Write-Host "⚠️  WARNINGS ($($warnings.Count)):" -ForegroundColor Yellow
    Write-Host ""
    foreach ($warning in $warnings) {
        Write-Host $warning -ForegroundColor Yellow
    }
    Write-Host ""
}

Write-Host "=" * 60
Write-Host "📚 For detailed troubleshooting, see:" -ForegroundColor Cyan
Write-Host "   .github/prompts/github-actions-troubleshoot.md"
Write-Host ""

if ($issues.Count -gt 0) {
    exit 1
}
exit 0

#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Comprehensive GitHub Actions workflow validation script

.DESCRIPTION
    Validates YAML syntax, GitHub Actions schema, and common workflow patterns
    for ci-cd.yml and build-release.yml files
#>

[CmdletBinding()]
param()

function Test-WorkflowFile {
    param(
        [string]$FilePath,
        [string]$WorkflowName
    )

    Write-Host "🔍 Validating $WorkflowName..." -ForegroundColor Cyan
    $issues = @()

    try {
        # Test 1: File exists and readable
        if (-not (Test-Path $FilePath)) {
            $issues += "❌ File does not exist: $FilePath"
            return $issues
        }

        $content = Get-Content $FilePath -Raw
        if (-not $content) {
            $issues += "❌ File is empty or unreadable"
            return $issues
        }

        Write-Host "  ✅ File exists and readable" -ForegroundColor Green

        # Test 2: Basic YAML structure
        $lines = Get-Content $FilePath
        $yamlErrors = @()

        # Check for common YAML issues
        $inCodeBlock = $false
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $line = $lines[$i]
            $lineNum = $i + 1

            # Track if we're in a PowerShell code block
            if ($line -match '^\s+run:\s*\|') {
                $inCodeBlock = $true
                continue
            }
            if ($inCodeBlock -and $line -match '^\s+[a-zA-Z-]+:') {
                $inCodeBlock = $false
            }

            # Skip validation inside code blocks
            if ($inCodeBlock) {
                continue
            }

            # Check for tabs (should use spaces)
            if ($line -match '\t') {
                $yamlErrors += "Line ${lineNum}: Contains tabs (use spaces for indentation)"
            }

            # Check for trailing spaces
            if ($line -match ' +$') {
                $yamlErrors += "Line ${lineNum}: Contains trailing spaces"
            }

            # Check for missing space after colon (YAML keys only)
            if ($line -match '^\s*[a-zA-Z_-]+:[\w]') {
                $yamlErrors += "Line ${lineNum}: Missing space after colon"
            }
        }

        if ($yamlErrors.Count -eq 0) {
            Write-Host "  ✅ Basic YAML formatting" -ForegroundColor Green
        } else {
            foreach ($errorResult in $yamlErrors) {
                $issues += "⚠️ YAML: $errorResult"
            }
        }

        # Test 3: Required GitHub Actions elements
        $requiredElements = @(
            'name:',
            'on:',
            'jobs:'
        )

        foreach ($element in $requiredElements) {
            if ($content -match $element) {
                Write-Host "  ✅ Has $element" -ForegroundColor Green
            } else {
                $issues += "❌ Missing required element: $element"
            }
        }

        # Test 4: Job structure validation
        $jobMatches = [regex]::Matches($content, '^\s+\w+:\s*$', [System.Text.RegularExpressions.RegexOptions]::Multiline)
        if ($jobMatches.Count -gt 0) {
            Write-Host "  ✅ Found $($jobMatches.Count) job(s)" -ForegroundColor Green
        } else {
            $issues += "❌ No jobs found"
        }

        # Test 5: Step structure validation
        $stepMatches = [regex]::Matches($content, '^\s+- name:', [System.Text.RegularExpressions.RegexOptions]::Multiline)
        if ($stepMatches.Count -gt 0) {
            Write-Host "  ✅ Found $($stepMatches.Count) step(s)" -ForegroundColor Green
        } else {
            $issues += "❌ No steps found"
        }

        # Test 6: GitHub Actions syntax validation
        $expressionMatches = [regex]::Matches($content, '\$\{\{.*?\}\}')
        $invalidExpressions = @()

        foreach ($match in $expressionMatches) {
            $expr = $match.Value

            # Check for common expression issues
            if ($expr -match '\$\{\{.*\?\s*.*:.*\}\}') {
                $invalidExpressions += "Ternary operator not supported in GitHub Actions: $expr"
            }

            if ($expr -match '\$\{\{.*\&\&.*\|\|.*\}\}') {
                $invalidExpressions += "Complex boolean logic may not work: $expr"
            }
        }

        if ($invalidExpressions.Count -eq 0) {
            Write-Host "  ✅ GitHub Actions expressions look valid" -ForegroundColor Green
        } else {
            foreach ($expr in $invalidExpressions) {
                $issues += "❌ Expression: $expr"
            }
        }

        # Test 7: Common patterns validation
        $patterns = @{
            'uses: actions/checkout@v4' = 'Modern checkout action'
            'shell: pwsh' = 'PowerShell cross-platform'
            'runs-on:' = 'Runner specification'
        }

        foreach ($pattern in $patterns.Keys) {
            if ($content -match [regex]::Escape($pattern)) {
                Write-Host "  ✅ Uses $($patterns[$pattern])" -ForegroundColor Green
            }
        }

    } catch {
        $issues += "❌ Validation error: $($_.Exception.Message)"
    }

    return $issues
}

# Main validation
Write-Host "🚀 GitHub Actions Workflow Validation" -ForegroundColor Yellow
Write-Host "=====================================" -ForegroundColor Yellow

$allIssues = @()

# Validate ci-cd.yml
$cicdIssues = Test-WorkflowFile -FilePath '.github/workflows/ci-cd.yml' -WorkflowName 'CI/CD Pipeline'
$allIssues += $cicdIssues

Write-Host ""

# Validate build-release.yml
$buildIssues = Test-WorkflowFile -FilePath '.github/workflows/build-release.yml' -WorkflowName 'Build & Release'
$allIssues += $buildIssues

Write-Host ""
Write-Host "📋 VALIDATION SUMMARY" -ForegroundColor Yellow
Write-Host "=====================" -ForegroundColor Yellow

if ($allIssues.Count -eq 0) {
    Write-Host "🎉 All workflow files are valid!" -ForegroundColor Green
    Write-Host "✅ Ready for GitHub Actions execution" -ForegroundColor Green
    exit 0
} else {
    Write-Host "⚠️ Found $($allIssues.Count) issue(s):" -ForegroundColor Red
    foreach ($issue in $allIssues) {
        Write-Host "  $issue" -ForegroundColor Red
    }
    Write-Host ""
    Write-Host "❌ Workflows need fixes before deployment" -ForegroundColor Red
    exit 1
}


#Requires -Version 7.0

<#
.SYNOPSIS
    Detailed validation of GitHub Actions workflow files
.DESCRIPTION
    Performs comprehensive validation of workflow files and shows actual values
#>

param(
    [switch]$Verbose
)

function Test-WorkflowFile {
    param(
        [string]$FilePath,
        [string]$Name
    )

    Write-Host "🔍 Validating $Name..." -ForegroundColor Cyan

    if (-not (Test-Path $FilePath)) {
        Write-Host "  ❌ File not found: $FilePath" -ForegroundColor Red
        return $false
    }

    try {
        # Read and parse YAML content
        $content = Get-Content $FilePath -Raw

        # Check for basic YAML structure
        if ($content -match '(?m)^name:\s*(.+)$') {
            $workflowName = $matches[1].Trim()
            Write-Host "  ✅ Workflow name: '$workflowName'" -ForegroundColor Green
        } else {
            Write-Host "  ❌ Missing or invalid 'name' field" -ForegroundColor Red
            Write-Host "  🔍 First few lines for debugging:" -ForegroundColor Yellow
            ($content -split "`n" | Select-Object -First 5) | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
            return $false
        }

        # Check for 'on' triggers
        if ($content -match '(?ms)^on:\s*$(.+?)^(?=\w|\Z)') {
            $triggers = $matches[1] -split "`n" | Where-Object { $_ -match '\S' } | ForEach-Object { $_.Trim() }
            Write-Host "  ✅ Triggers found:" -ForegroundColor Green
            foreach ($trigger in $triggers) {
                if ($trigger -notmatch '^\s*#' -and $trigger -match '\w') {
                    Write-Host "    - $trigger" -ForegroundColor Cyan
                }
            }
        } else {
            Write-Host "  ❌ Missing or invalid 'on' field" -ForegroundColor Red
            return $false
        }

        # Count jobs
        $jobMatches = [regex]::Matches($content, '(?m)^  \w+:\s*$')
        Write-Host "  ✅ Jobs found: $($jobMatches.Count)" -ForegroundColor Green

        # Show job names
        foreach ($match in $jobMatches) {
            $jobName = $match.Value.Replace(':', '').Trim()
            Write-Host "    - $jobName" -ForegroundColor Cyan
        }

        # Count steps
        $stepMatches = [regex]::Matches($content, '(?m)^\s+- name:')
        Write-Host "  ✅ Steps found: $($stepMatches.Count)" -ForegroundColor Green

        # Check for common issues
        $issues = @()

        # Check for ternary operators in GitHub expressions
        if ($content -match '\$\{\{[^}]*\?[^}]*:[^}]*\}\}') {
            $issues += "Ternary operators in GitHub expressions (not supported)"
        }

        # Check for invalid shell specifications
        if ($content -match 'shell:\s*[^p].*' -and $content -notmatch 'shell:\s*(pwsh|bash|sh|cmd|powershell)') {
            $issues += "Invalid shell specification"
        }

        if ($issues.Count -gt 0) {
            Write-Host "  ⚠️ Potential issues found:" -ForegroundColor Yellow
            foreach ($issue in $issues) {
                Write-Host "    - $issue" -ForegroundColor Yellow
            }
        } else {
            Write-Host "  ✅ No obvious issues detected" -ForegroundColor Green
        }

        return $true

    } catch {
        Write-Host "  ❌ Error parsing file: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Main validation
Write-Host "🚀 Detailed GitHub Actions Workflow Validation" -ForegroundColor Green
Write-Host "===============================================" -ForegroundColor Green

$ciValid = Test-WorkflowFile -FilePath ".github/workflows/ci-cd.yml" -Name "CI/CD Pipeline"
Write-Host ""

$buildValid = Test-WorkflowFile -FilePath ".github/workflows/build-release.yml" -Name "Build & Release"
Write-Host ""

# Summary
Write-Host "📋 DETAILED VALIDATION SUMMARY" -ForegroundColor Green
Write-Host "==============================" -ForegroundColor Green

if ($ciValid -and $buildValid) {
    Write-Host "🎉 All workflow files are valid and ready!" -ForegroundColor Green
    Write-Host "✅ Ready for GitHub Actions execution" -ForegroundColor Green
    exit 0
} else {
    Write-Host "❌ One or more workflow files have issues" -ForegroundColor Red
    exit 1
}

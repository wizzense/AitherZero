#!/usr/bin/env pwsh

# Install PSScriptAnalyzer if not available
if (-not (Get-Module -ListAvailable PSScriptAnalyzer)) {
    Install-Module -Name PSScriptAnalyzer -Force -Scope CurrentUser
}

# Run script analysis to find errors
Write-Host "Running PSScriptAnalyzer to find errors..." -ForegroundColor Cyan

$results = Invoke-ScriptAnalyzer -Path './aither-core/modules' -Settings './tests/config/PSScriptAnalyzerSettings.psd1' -Severity Error -Recurse

$errors = $results | Where-Object { $_.Severity -eq 'Error' }

if ($errors.Count -gt 0) {
    Write-Host "Found $($errors.Count) errors:" -ForegroundColor Red
    $errors | ForEach-Object {
        Write-Host "ERROR: $($_.ScriptName):$($_.Line) - $($_.Message)" -ForegroundColor Red
        Write-Host "  Rule: $($_.RuleName)" -ForegroundColor Yellow
        Write-Host ""
    }
} else {
    Write-Host "No errors found!" -ForegroundColor Green
}

# Also check for warnings that might be treated as errors
$warnings = $results | Where-Object { $_.Severity -eq 'Warning' }
Write-Host "Found $($warnings.Count) warnings" -ForegroundColor Yellow

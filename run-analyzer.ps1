#!/usr/bin/env pwsh
# Script to run PSScriptAnalyzer and save results

Import-Module PSScriptAnalyzer

Write-Host "Running PSScriptAnalyzer on entire codebase..."
$errors = @()
$warnings = @()

# Get all errors
$allIssues = Invoke-ScriptAnalyzer -Path . -Recurse -Severity Error,Warning

foreach ($issue in $allIssues) {
    if ($issue.Severity -eq 'Error') {
        $errors += $issue
    } else {
        $warnings += $issue
    }
}

Write-Host "`nFound $($errors.Count) errors and $($warnings.Count) warnings"

# Display errors
if ($errors.Count -gt 0) {
    Write-Host "`n=== ERRORS ===" -ForegroundColor Red
    foreach ($error in $errors) {
        Write-Host "`nFile: $($error.ScriptPath)" -ForegroundColor Yellow
        Write-Host "Line: $($error.Line)" -ForegroundColor Yellow
        Write-Host "Rule: $($error.RuleName)" -ForegroundColor Cyan
        Write-Host "Message: $($error.Message)" -ForegroundColor White
    }
}

# Save results to JSON
$results = @{
    TotalErrors = $errors.Count
    TotalWarnings = $warnings.Count
    Errors = $errors | Select-Object ScriptPath, Line, RuleName, Message, Severity
    Warnings = $warnings | Select-Object ScriptPath, Line, RuleName, Message, Severity | Select-Object -First 20
}

$results | ConvertTo-Json -Depth 10 | Out-File -FilePath analyzer_results.json -Encoding UTF8
Write-Host "`nResults saved to analyzer_results.json"
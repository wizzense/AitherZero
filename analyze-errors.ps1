#!/usr/bin/env pwsh
# Script to analyze PSScriptAnalyzer errors

Import-Module PSScriptAnalyzer

Write-Host "Running PSScriptAnalyzer for ERRORS only..."

# Get all errors
$allErrors = Invoke-ScriptAnalyzer -Path . -Recurse -Severity Error

Write-Host "`nFound $($allErrors.Count) errors"

# Group by rule name
$errorsByRule = $allErrors | Group-Object -Property RuleName | Sort-Object -Property Count -Descending

Write-Host "`n=== ERROR SUMMARY BY RULE ===" -ForegroundColor Red
foreach ($group in $errorsByRule) {
    Write-Host "$($group.Count) occurrences of: $($group.Name)" -ForegroundColor Yellow
}

# Show first 10 errors in detail
Write-Host "`n=== FIRST 10 ERRORS IN DETAIL ===" -ForegroundColor Red
$allErrors | Select-Object -First 10 | ForEach-Object {
    Write-Host "`nFile: $($_.ScriptPath)" -ForegroundColor Yellow
    Write-Host "Line: $($_.Line)" -ForegroundColor Yellow
    Write-Host "Rule: $($_.RuleName)" -ForegroundColor Cyan
    Write-Host "Message: $($_.Message)" -ForegroundColor White
}

# Save detailed results
$detailedErrors = $allErrors | Select-Object ScriptPath, Line, RuleName, Message | ConvertTo-Json -Depth 10
$detailedErrors | Out-File -FilePath detailed_errors.json -Encoding UTF8
Write-Host "`nDetailed results saved to detailed_errors.json"
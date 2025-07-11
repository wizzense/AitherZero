#!/usr/bin/env pwsh
# Check for critical PSScriptAnalyzer errors

Write-Host "Checking for critical PSScriptAnalyzer errors..." -ForegroundColor Cyan

# Get all errors
$allErrors = Invoke-ScriptAnalyzer -Path . -Recurse -Severity Error

# Filter out less critical rules
$criticalErrors = $allErrors | Where-Object { 
    $_.RuleName -notin @(
        'PSUseOutputTypeCorrectly',     # Functions missing OutputType attribute
        'PSUseBOMForUnicodeEncodedFile' # Files missing BOM encoding
    )
}

Write-Host "`nTotal errors: $($allErrors.Count)" -ForegroundColor Yellow
Write-Host "Critical errors: $($criticalErrors.Count)" -ForegroundColor Red

if ($criticalErrors) {
    Write-Host "`nCritical errors found:" -ForegroundColor Red
    $criticalErrors | ForEach-Object {
        Write-Host "`nFile: $($_.ScriptName)" -ForegroundColor Yellow
        Write-Host "Line: $($_.Line)" -ForegroundColor Yellow
        Write-Host "Rule: $($_.RuleName)" -ForegroundColor Yellow
        Write-Host "Message: $($_.Message)" -ForegroundColor Red
    }
    
    # Group by rule
    Write-Host "`n`nCritical errors by rule:" -ForegroundColor Cyan
    $criticalErrors | Group-Object RuleName | ForEach-Object {
        Write-Host "$($_.Name): $($_.Count) occurrences" -ForegroundColor Yellow
    }
}

# Check what the CI would see
Write-Host "`n`nCI Error Count Check:" -ForegroundColor Cyan
$ciErrors = $allErrors | Where-Object { $_.Severity -eq 'Error' }
Write-Host "Errors that CI sees: $($ciErrors.Count)" -ForegroundColor Yellow
Write-Host "CI threshold: 10" -ForegroundColor Yellow
if ($ciErrors.Count -gt 10) {
    Write-Host "FAIL: Exceeds threshold by $($ciErrors.Count - 10)" -ForegroundColor Red
} else {
    Write-Host "PASS: Within threshold" -ForegroundColor Green
}
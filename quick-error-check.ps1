#!/usr/bin/env pwsh

# Quick error check for PSScriptAnalyzer
Write-Host 'Checking for PSScriptAnalyzer errors...' -ForegroundColor Cyan

try {
    $results = Invoke-ScriptAnalyzer -Path './aither-core/modules' -Settings './tests/config/PSScriptAnalyzerSettings.psd1' -Severity Error -Recurse
    $errors = $results | Where-Object { $_.Severity -eq 'Error' }

    Write-Host "Total errors found: $($errors.Count)" -ForegroundColor $(if ($errors.Count -eq 0) { 'Green' } else { 'Red' })

    if ($errors.Count -gt 0) {
        Write-Host 'Specific errors:' -ForegroundColor Yellow
        $errors | ForEach-Object {
            Write-Host "  ERROR: $($_.ScriptName):$($_.Line) - $($_.Message)" -ForegroundColor Red
            Write-Host "    Rule: $($_.RuleName)" -ForegroundColor Yellow
        }
    }
} catch {
    Write-Host "Error running PSScriptAnalyzer: $($_.Exception.Message)" -ForegroundColor Red
}
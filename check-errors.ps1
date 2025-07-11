#!/usr/bin/env pwsh
# Script to check PSScriptAnalyzer errors

Write-Host "Checking for PSScriptAnalyzer errors..." -ForegroundColor Cyan

$errors = Invoke-ScriptAnalyzer -Path . -Recurse -Severity Error -ExcludeRule PSUseDeclaredVarsMoreThanAssignments

if ($errors) {
    Write-Host "`nFound $($errors.Count) errors:" -ForegroundColor Red
    $errors | ForEach-Object {
        Write-Host "`nFile: $($_.ScriptName)" -ForegroundColor Yellow
        Write-Host "Line: $($_.Line)" -ForegroundColor Yellow
        Write-Host "Rule: $($_.RuleName)" -ForegroundColor Yellow
        Write-Host "Message: $($_.Message)" -ForegroundColor Red
        Write-Host "Extent: $($_.Extent)" -ForegroundColor Gray
    }
    
    # Group by file
    Write-Host "`n`nErrors by file:" -ForegroundColor Cyan
    $errors | Group-Object ScriptName | ForEach-Object {
        Write-Host "`n$($_.Name): $($_.Count) errors" -ForegroundColor Yellow
    }
} else {
    Write-Host "No errors found!" -ForegroundColor Green
}
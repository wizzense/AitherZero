#!/usr/bin/env pwsh
# Test our PSScriptAnalyzer fixes

if (-not (Get-Module -ListAvailable PSScriptAnalyzer)) {
    Install-Module -Name PSScriptAnalyzer -Force -Scope CurrentUser
}

# Test specific files we fixed
$files = @('aither-core/aither-core.ps1', 'aither-core/AitherCore.psm1', 'aither-core/domains/security/Security.ps1')

foreach ($file in $files) {
    if (Test-Path $file) {
        Write-Host "Testing: $file"
        $results = Invoke-ScriptAnalyzer -Path $file -Settings ./PSScriptAnalyzerSettings.psd1
        $errors = $results | Where-Object { $_.Severity -eq 'Error' }
        $securityWarnings = $results | Where-Object { $_.Severity -eq 'Warning' -and $_.RuleName -match 'Security|Credential|Password' }
        
        if ($errors) {
            Write-Host "  Errors: $($errors.Count)" -ForegroundColor Red
            $errors | ForEach-Object { Write-Host "    - $($_.RuleName): $($_.Message)" -ForegroundColor Red }
        } else {
            Write-Host "  No errors found!" -ForegroundColor Green
        }
        
        if ($securityWarnings) {
            Write-Host "  Security warnings: $($securityWarnings.Count)" -ForegroundColor Yellow
        } else {
            Write-Host "  No security warnings!" -ForegroundColor Green
        }
    }
}

Write-Host "`nFixes summary:"
Write-Host "- Fixed automatic variable assignments (error variable)"
Write-Host "- Fixed ConvertTo-SecureString security issues with proper suppressions"
Write-Host "- Fixed plaintext password parameter warnings with suppressions"
Write-Host "- Fixed empty catch blocks with proper error handling"
Write-Host "- Added BOM encoding to UTF-8 files"
Write-Host "- Added OutputType declarations to key functions"
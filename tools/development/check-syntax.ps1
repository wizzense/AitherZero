#!/usr/bin/env pwsh
#Requires -Version 7.0

$ErrorActionPreference = 'Stop'

try {
    Write-Host "Checking syntax of Invoke-ReleaseWorkflow.ps1..." -ForegroundColor Cyan

    # Try to parse the script
    $file = "/workspaces/AitherZero/aither-core/modules/PatchManager/Public/Invoke-ReleaseWorkflow.ps1"
    $tokens = $null
    $parseErrors = $null

    $ast = [System.Management.Automation.Language.Parser]::ParseFile($file, [ref]$tokens, [ref]$parseErrors)

    if ($parseErrors) {
        Write-Host "❌ Syntax errors found:" -ForegroundColor Red
        foreach ($parseError in $parseErrors) {
            Write-Host "  Line $($parseError.Extent.StartLineNumber): $($parseError.Message)" -ForegroundColor Yellow
        }
    } else {
        Write-Host "✅ No syntax errors found" -ForegroundColor Green
    }

    # Count braces
    $content = Get-Content $file -Raw
    $openBraces = ($content.ToCharArray() | Where-Object { $_ -eq '{' }).Count
    $closeBraces = ($content.ToCharArray() | Where-Object { $_ -eq '}' }).Count

    Write-Host "Brace count: $openBraces opening, $closeBraces closing" -ForegroundColor White

    if ($openBraces -ne $closeBraces) {
        Write-Host "❌ Brace mismatch detected!" -ForegroundColor Red
    } else {
        Write-Host "✅ Braces are balanced" -ForegroundColor Green
    }

} catch {
    Write-Host "❌ Error checking syntax: $_" -ForegroundColor Red
}

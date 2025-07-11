#!/usr/bin/env pwsh

Set-Location '/workspaces/AitherZero'

Write-Host 'Testing module import with error capture...'
try {
    Import-Module ./aither-core/modules/Logging -Force -Global
    Write-Host '✓ Logging module imported successfully'
} catch {
    Write-Host "✗ Logging module failed: $($_.Exception.Message)"
}

try {
    $module = Import-Module ./aither-core/modules/ParallelExecution -Force -PassThru
    Write-Host "✓ ParallelExecution module imported successfully"
    Write-Host "  Module Name: $($module.Name)"
    Write-Host "  Module Version: $($module.Version)"
    Write-Host "  Functions Exported: $($module.ExportedFunctions.Count)"
    
    $module.ExportedFunctions.Keys | ForEach-Object { Write-Host "    - $_" }
    
    # Test if the function is available in the current scope
    $cmd = Get-Command Start-ParallelExecution -ErrorAction SilentlyContinue
    if ($cmd) {
        Write-Host '  ✓ Start-ParallelExecution is available in current scope'
        Write-Host "    Source: $($cmd.Source)"
        Write-Host "    Module: $($cmd.Module.Name)"
    } else {
        Write-Host '  ✗ Start-ParallelExecution is NOT available in current scope'
    }
    
} catch {
    Write-Host "✗ ParallelExecution module failed: $($_.Exception.Message)"
    Write-Host "Stack trace: $($_.ScriptStackTrace)"
}
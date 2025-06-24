#Requires -Version 7.0

<#
.SYNOPSIS
    Debug script to test core-runner output issues
#>

param([object]$Config)

Write-Host '===== DEBUG SCRIPT OUTPUT TEST ====='
Write-Host 'This is a Write-Host message'
Write-Output 'This is a Write-Output message'
Write-Information 'This is a Write-Information message' -InformationAction Continue
Write-Warning 'This is a Write-Warning message'
Write-Verbose 'This is a Write-Verbose message' -Verbose

# Test standard output and errors
'This is a string sent to stdout'
Write-Error 'This is a non-terminating error' -ErrorAction Continue

# Test script block execution
$scriptBlock = {
    Write-Host 'Output from script block'
    'String from script block'
}

& $scriptBlock

# Test command execution
try {
    $result = Get-Date
    Write-Host "Current time: $result"
} catch {
    Write-Host "Error getting date: $($_.Exception.Message)"
}

Write-Host '===== END DEBUG SCRIPT OUTPUT TEST ====='

#!/usr/bin/env pwsh

Set-Location '/workspaces/AitherZero'
Import-Module ./aither-core/modules/Logging -Force -Global
Import-Module ./aither-core/modules/ParallelExecution -Force

Write-Host 'Available commands in ParallelExecution:'
Get-Command -Module ParallelExecution | ForEach-Object { Write-Host "  - $($_.Name)" }

Write-Host ''
Write-Host 'Testing if Start-ParallelExecution is available:'
$cmd = Get-Command Start-ParallelExecution -ErrorAction SilentlyContinue
if ($cmd) {
    Write-Host '  ✓ Start-ParallelExecution is available'
} else {
    Write-Host '  ✗ Start-ParallelExecution is NOT available'
}

Write-Host ''
Write-Host 'Testing basic parallel execution...'
$testItems = 1..5
try {
    $result = Invoke-ParallelForEach -InputObject $testItems -ScriptBlock { param($x) $x * 2 } -ThrottleLimit 2
    Write-Host "Results: $($result -join ', ')"
} catch {
    Write-Host "Error: $($_.Exception.Message)"
}

Write-Host ''
Write-Host 'Testing job-based parallel execution...'
$jobs = @(
    @{ Name = 'Job1'; ScriptBlock = { param($x) $x * 2 }; Arguments = @(5) },
    @{ Name = 'Job2'; ScriptBlock = { param($x) $x + 10 }; Arguments = @(3) }
)

if (Get-Command Start-ParallelExecution -ErrorAction SilentlyContinue) {
    try {
        $jobResult = Start-ParallelExecution -Jobs $jobs -MaxConcurrentJobs 2
        Write-Host "Job execution successful: $($jobResult.Success)"
        Write-Host "Completed: $($jobResult.CompletedJobs)/$($jobResult.TotalJobs)"
    } catch {
        Write-Host "Job execution failed: $($_.Exception.Message)"
    }
} else {
    Write-Host "Start-ParallelExecution function not available"
}
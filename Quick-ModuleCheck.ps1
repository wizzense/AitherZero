#Requires -Version 7.0
<#
.SYNOPSIS
Ultra-fast module validation using aggressive parallelization

.DESCRIPTION
Lightning-fast module check targeting 3-5 second completion time.
Uses parallel processing to validate all modules simultaneously.

.PARAMETER MaxThreads
Maximum number of parallel threads (default: 8)

.EXAMPLE
.\Quick-ModuleCheck.ps1
.\Quick-ModuleCheck.ps1 -MaxThreads 12
#>

param([int]$MaxThreads = 8)

Write-Host "⚡ LIGHTNING MODULE CHECK (Target: 3-5 seconds)" -ForegroundColor Yellow
$startTime = Get-Date

# Import shared utilities
. "$PSScriptRoot/aither-core/shared/Find-ProjectRoot.ps1"
$projectRoot = Find-ProjectRoot

# Get all modules
$modules = Get-ChildItem "$projectRoot/aither-core/modules" -Directory

Write-Host "🔍 Checking $($modules.Count) modules in parallel..." -ForegroundColor Cyan

# Parallel validation with aggressive threading
$validationJobs = $modules | ForEach-Object -Parallel {
    $module = $_
    try {
        # Quick import test
        Import-Module $module.FullName -Force -ErrorAction Stop

        # Get exported functions count
        $moduleInfo = Get-Module $module.Name
        $exports = if ($moduleInfo) { $moduleInfo.ExportedFunctions.Count } else { 0 }

        # Quick manifest validation
        $manifestPath = Join-Path $module.FullName "$($module.Name).psd1"
        $hasManifest = Test-Path $manifestPath

        return @{
            Name = $module.Name
            Status = "✅"
            Functions = $exports
            HasManifest = $hasManifest
            Message = "$exports functions"
        }
    } catch {
        return @{
            Name = $module.Name
            Status = "❌"
            Functions = 0
            HasManifest = $false
            Message = $_.Exception.Message.Split("`n")[0]
        }
    }
} -ThrottleLimit $MaxThreads

# Display results
$successCount = 0
$failCount = 0

$validationJobs | ForEach-Object {
    $result = $_
    if ($result.Status -eq "✅") {
        $successCount++
        Write-Host "$($result.Status) $($result.Name): $($result.Message)" -ForegroundColor Green
    } else {
        $failCount++
        Write-Host "$($result.Status) $($result.Name): $($result.Message)" -ForegroundColor Red
    }
}

$elapsed = ((Get-Date) - $startTime).TotalSeconds

# Summary
Write-Host "`n📊 RESULTS:" -ForegroundColor White
Write-Host "   ✅ Success: $successCount modules" -ForegroundColor Green
Write-Host "   ❌ Failed:  $failCount modules" -ForegroundColor Red
Write-Host "   ⏱️ Time:    $([math]::Round($elapsed, 1)) seconds" -ForegroundColor Yellow

if ($elapsed -le 5) {
    Write-Host "🎯 LIGHTNING SPEED ACHIEVED!" -ForegroundColor Green
} elseif ($elapsed -le 10) {
    Write-Host "🚀 Good speed, consider optimizing further" -ForegroundColor Yellow
} else {
    Write-Host "⚠️ Slower than expected, check system performance" -ForegroundColor Orange
}

# Return summary object for programmatic use
return @{
    TotalModules = $modules.Count
    SuccessCount = $successCount
    FailCount = $failCount
    ElapsedSeconds = $elapsed
    Results = $validationJobs
}

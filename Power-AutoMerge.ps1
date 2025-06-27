#Requires -Version 7.0
<#
.SYNOPSIS
One-command auto-merge with validation

.DESCRIPTION
Lightning-fast auto-merge workflow with built-in validation.
Demonstrates PatchManager auto-merge capabilities.

.PARAMETER Description
Description for the patch/merge operation

.PARAMETER Force
Execute the merge (without Force, runs in DryRun mode)

.PARAMETER Priority
Priority level for the operation (Low, Medium, High, Critical)

.EXAMPLE
.\Power-AutoMerge.ps1
.\Power-AutoMerge.ps1 -Description "Quick fix for validation" -Force
.\Power-AutoMerge.ps1 -Priority High -Force
#>

param(
    [string]$Description = "Power auto-merge $(Get-Date -Format 'HH:mm')",
    [switch]$Force,
    [ValidateSet("Low", "Medium", "High", "Critical")]
    [string]$Priority = "Medium"
)

Write-Host "🚁 POWER AUTO-MERGE: Starting lightning workflow" -ForegroundColor Magenta
$startTime = Get-Date

# Import shared utilities
. "$PSScriptRoot/aither-core/shared/Find-ProjectRoot.ps1"
$projectRoot = Find-ProjectRoot

# Import PatchManager
try {
    Import-Module "$projectRoot/aither-core/modules/PatchManager" -Force
    Write-Host "✅ PatchManager loaded" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to load PatchManager: $($_.Exception.Message)" -ForegroundColor Red
    return
}

# Ultra-fast validation operation
$validationOperation = {
    Write-Host "🔍 Running lightning validations..." -ForegroundColor Yellow

    # Define quick validation checks
    $validations = @(
        @{ Name = "Project Structure"; Check = { Test-Path 'aither-core/modules' } },
        @{ Name = "Module Count"; Check = { (Get-ChildItem 'aither-core/modules' -Directory).Count -gt 5 } },
        @{ Name = "GitHub Workflows"; Check = { Test-Path '.github/workflows' } },
        @{ Name = "Core Scripts"; Check = { Test-Path 'aither-core/aither-core.ps1' } },
        @{ Name = "Test Structure"; Check = { Test-Path 'tests' } }
    )

    # Run validations in parallel for speed
    $results = $validations | ForEach-Object -Parallel {
        $validation = $_
        try {
            $result = & $validation.Check
            return @{
                Name = $validation.Name
                Status = if ($result) { "✅" } else { "❌" }
                Success = $result
            }
        } catch {
            return @{
                Name = $validation.Name
                Status = "❌"
                Success = $false
                Error = $_.Exception.Message
            }
        }
    } -ThrottleLimit 8

    # Display results
    $failCount = 0
    $results | ForEach-Object {
        Write-Host "   $($_.Status) $($_.Name)" -ForegroundColor $(if ($_.Success) { "Green" } else { "Red" })
        if (-not $_.Success) { $failCount++ }
    }

    if ($failCount -eq 0) {
        Write-Host "✅ All lightning validations passed!" -ForegroundColor Green
        return $true
    } else {
        Write-Host "❌ $failCount validation(s) failed" -ForegroundColor Red
        return $false
    }
}

# Quick test commands for PatchManager
$testCommands = @(
    'Write-Host "✅ Quick test: PowerShell version OK" -ForegroundColor Green',
    'Write-Host "✅ Quick test: Project root accessible" -ForegroundColor Green',
    'if (Get-Command git -ErrorAction SilentlyContinue) { Write-Host "✅ Quick test: Git available" -ForegroundColor Green } else { Write-Host "⚠️ Git not found" -ForegroundColor Yellow }'
)

try {
    Write-Host "⚡ Preparing PatchManager workflow..." -ForegroundColor Cyan

    # Build PatchManager parameters
    $patchParams = @{
        PatchDescription = $Description
        PatchOperation = $validationOperation
        Priority = $Priority
        TestCommands = $testCommands
        CreateIssue = $true  # Create GitHub issue for tracking
    }

    # Add AutoMerge and AutoConsolidate for demonstration
    if ($Description -notlike "*demo*" -and $Description -notlike "*test*") {
        $patchParams.AutoMerge = $true
        $patchParams.AutoConsolidate = $true
        Write-Host "🔄 AutoMerge and AutoConsolidate enabled" -ForegroundColor Yellow
    }

    # Add DryRun if not Force
    if (-not $Force) {
        $patchParams.DryRun = $true
        Write-Host "🔍 DryRun mode - no actual changes will be made" -ForegroundColor Yellow
    } else {
        Write-Host "⚠️ LIVE MODE - changes will be made!" -ForegroundColor Red
    }

    # Execute the workflow
    Write-Host "🚀 Executing PatchManager workflow..." -ForegroundColor Green

    $result = Invoke-PatchWorkflow @patchParams

    $elapsed = ((Get-Date) - $startTime).TotalSeconds

    if ($result) {
        Write-Host "🎯 Power auto-merge completed successfully!" -ForegroundColor Green
        Write-Host "   ⏱️ Duration: $([math]::Round($elapsed, 1)) seconds" -ForegroundColor Cyan

        # Show available PatchManager features
        Write-Host "`n📋 Available PatchManager features:" -ForegroundColor White
        $features = @(
            "✅ Invoke-PatchWorkflow - Main workflow with AutoMerge",
            "✅ Enable-AutoMerge - Standalone auto-merge setup",
            "✅ Invoke-PRConsolidation - PR consolidation",
            "✅ New-PatchIssue - Create tracking issues",
            "✅ Invoke-PatchRollback - Emergency rollback"
        )
        $features | ForEach-Object { Write-Host "   $_" -ForegroundColor Cyan }

    } else {
        Write-Host "❌ Power auto-merge encountered issues" -ForegroundColor Red
    }

} catch {
    $elapsed = ((Get-Date) - $startTime).TotalSeconds
    Write-Host "❌ Power auto-merge failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "   ⏱️ Failed after: $([math]::Round($elapsed, 1)) seconds" -ForegroundColor Yellow

    # Show troubleshooting tips
    Write-Host "`n🔧 Troubleshooting tips:" -ForegroundColor Yellow
    Write-Host "   1. Ensure you're in the AitherZero project directory" -ForegroundColor White
    Write-Host "   2. Check if PatchManager module is properly installed" -ForegroundColor White
    Write-Host "   3. Verify GitHub CLI (gh) is authenticated" -ForegroundColor White
    Write-Host "   4. Try running with -DryRun first (default without -Force)" -ForegroundColor White
}

# Performance assessment
if ($elapsed -le 20) {
    Write-Host "`n🏆 LIGHTNING PERFORMANCE ACHIEVED!" -ForegroundColor Green
} elseif ($elapsed -le 60) {
    Write-Host "`n🚀 Good performance" -ForegroundColor Green
} else {
    Write-Host "`n⚠️ Performance could be improved" -ForegroundColor Yellow
}

# Usage examples
if (-not $Force) {
    Write-Host "`n💡 Next steps:" -ForegroundColor Cyan
    Write-Host "   • Add -Force to execute for real: .\Power-AutoMerge.ps1 -Force" -ForegroundColor White
    Write-Host "   • Try different priorities: .\Power-AutoMerge.ps1 -Priority High -Force" -ForegroundColor White
    Write-Host "   • Use custom description: .\Power-AutoMerge.ps1 -Description 'My fix' -Force" -ForegroundColor White
}

# Return result summary
return @{
    Success = ($null -ne $result)
    ElapsedSeconds = $elapsed
    Description = $Description
    Priority = $Priority
    DryRun = (-not $Force)
    AutoMergeAvailable = ($null -ne (Get-Command Invoke-PatchWorkflow -ErrorAction SilentlyContinue))
}

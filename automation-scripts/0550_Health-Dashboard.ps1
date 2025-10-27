#Requires -Version 7.0
# Stage: Reporting
# Dependencies: LogViewer, Testing
# Description: Consolidated health and status dashboard for AitherZero

[CmdletBinding()]
param(
    [Parameter()]
    [hashtable]$Configuration,

    [Parameter()]
    [switch]$NonInteractive,

    [Parameter()]
    [switch]$ShowAll
)

# Initialize environment
$ProjectRoot = Split-Path $PSScriptRoot -Parent

# Import required modules
$modulesToImport = @(
    "domains/utilities/LogViewer.psm1",
    "domains/utilities/Logging.psm1"
)

foreach ($modulePath in $modulesToImport) {
    $fullPath = Join-Path $ProjectRoot $modulePath
    if (Test-Path $fullPath) {
        Import-Module $fullPath -Force -ErrorAction SilentlyContinue
    }
}

function Write-ScriptLog {
    param([string]$Message, [string]$Level = 'Information')
    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Message $Message -Level $Level
    }
}

function Get-SystemHealth {
    <#
    .SYNOPSIS
        Gets overall system health status
    #>
    $health = @{
        Status = 'Healthy'
        Issues = @()
        Checks = @{
            PowerShell = $false
            Modules = $false
            Logging = $false
            Tests = $false
        }
    }

    # Check PowerShell version
    if ($PSVersionTable.PSVersion.Major -ge 7) {
        $health.Checks.PowerShell = $true
    } else {
        $health.Status = 'Warning'
        $health.Issues += "PowerShell 7+ required (Current: $($PSVersionTable.PSVersion))"
    }

    # Check core modules
    $coreModules = @('Logging', 'LogViewer', 'Configuration')
    $loadedModules = Get-Module | Select-Object -ExpandProperty Name
    $missingModules = $coreModules | Where-Object { $_ -notin $loadedModules }
    
    if ($missingModules.Count -eq 0) {
        $health.Checks.Modules = $true
    } else {
        $health.Status = 'Warning'
        $health.Issues += "Missing modules: $($missingModules -join ', ')"
    }

    # Check logging system
    if (Test-Path (Join-Path $ProjectRoot "logs")) {
        $health.Checks.Logging = $true
    } else {
        $health.Status = 'Warning'
        $health.Issues += "Logs directory not found"
    }

    # Check test infrastructure
    if (Test-Path (Join-Path $ProjectRoot "tests")) {
        $health.Checks.Tests = $true
    }

    # Determine overall status
    $healthyChecks = ($health.Checks.Values | Where-Object { $_ -eq $true }).Count
    $totalChecks = $health.Checks.Count
    
    if ($healthyChecks -lt $totalChecks * 0.5) {
        $health.Status = 'Critical'
    } elseif ($health.Issues.Count -gt 0) {
        $health.Status = 'Warning'
    }

    return [PSCustomObject]$health
}

function Get-RecentErrors {
    <#
    .SYNOPSIS
        Gets recent errors and warnings from logs
    #>
    $logFiles = Get-LogFiles -Type Application -ErrorAction SilentlyContinue
    if (-not $logFiles) {
        return @()
    }

    $latest = $logFiles[0]
    $content = Get-Content $latest.FullName -Tail 200 -ErrorAction SilentlyContinue
    
    $errors = @{
        Errors = @()
        Warnings = @()
    }

    foreach ($line in $content) {
        if ($line -match '\[ERROR\s*\]') {
            $errors.Errors += $line
        } elseif ($line -match '\[WARNING\s*\]') {
            $errors.Warnings += $line
        }
    }

    return [PSCustomObject]$errors
}

function Get-TestResults {
    <#
    .SYNOPSIS
        Gets latest test execution results if available
    #>
    $testResults = @{
        Available = $false
        LastRun = $null
        Passed = 0
        Failed = 0
        Skipped = 0
        Total = 0
    }

    # Check for test results file
    $resultsPath = Join-Path $ProjectRoot "tests/test-results.json"
    if (Test-Path $resultsPath) {
        try {
            $data = Get-Content $resultsPath -Raw | ConvertFrom-Json
            $testResults.Available = $true
            $testResults.LastRun = $data.Timestamp
            $testResults.Passed = $data.Passed
            $testResults.Failed = $data.Failed
            $testResults.Skipped = $data.Skipped
            $testResults.Total = $data.Total
        } catch {
            Write-ScriptLog "Failed to read test results: $_" -Level 'Warning'
        }
    }

    return [PSCustomObject]$testResults
}

function Show-HealthDashboard {
    <#
    .SYNOPSIS
        Displays the consolidated health dashboard
    #>
    param([switch]$ShowAll)

    Write-Host "`n╔═══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║           AitherZero Health Dashboard                    ║" -ForegroundColor Cyan
    Write-Host "╚═══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

    # System Health
    Write-Host "`n📊 System Health" -ForegroundColor White
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor DarkGray
    
    $health = Get-SystemHealth
    
    $statusColor = switch ($health.Status) {
        'Healthy' { 'Green' }
        'Warning' { 'Yellow' }
        'Critical' { 'Red' }
        default { 'Gray' }
    }
    
    $statusIcon = switch ($health.Status) {
        'Healthy' { '✅' }
        'Warning' { '⚠️ ' }
        'Critical' { '❌' }
        default { '❓' }
    }
    
    Write-Host "  Overall Status: " -NoNewline
    Write-Host "$statusIcon $($health.Status)" -ForegroundColor $statusColor

    Write-Host "`n  Component Checks:" -ForegroundColor Gray
    foreach ($check in $health.Checks.GetEnumerator()) {
        $icon = if ($check.Value) { '✅' } else { '❌' }
        $color = if ($check.Value) { 'Green' } else { 'Red' }
        Write-Host "    $icon $($check.Key)" -ForegroundColor $color
    }

    if ($health.Issues.Count -gt 0) {
        Write-Host "`n  Issues Detected:" -ForegroundColor Yellow
        foreach ($issue in $health.Issues) {
            Write-Host "    • $issue" -ForegroundColor Yellow
        }
    }

    # Recent Errors & Warnings
    Write-Host "`n🔍 Recent Errors & Warnings" -ForegroundColor White
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor DarkGray
    
    $recent = Get-RecentErrors
    
    if ($recent.Errors.Count -eq 0 -and $recent.Warnings.Count -eq 0) {
        Write-Host "  ✅ No recent errors or warnings" -ForegroundColor Green
    } else {
        if ($recent.Errors.Count -gt 0) {
            Write-Host "  ❌ Errors: $($recent.Errors.Count)" -ForegroundColor Red
            if ($ShowAll) {
                $recent.Errors | Select-Object -First 5 | ForEach-Object {
                    Write-Host "     $_" -ForegroundColor Red
                }
                if ($recent.Errors.Count -gt 5) {
                    Write-Host "     ... and $($recent.Errors.Count - 5) more" -ForegroundColor DarkRed
                }
            }
        }
        
        if ($recent.Warnings.Count -gt 0) {
            Write-Host "  ⚠️  Warnings: $($recent.Warnings.Count)" -ForegroundColor Yellow
            if ($ShowAll) {
                $recent.Warnings | Select-Object -First 5 | ForEach-Object {
                    Write-Host "     $_" -ForegroundColor Yellow
                }
                if ($recent.Warnings.Count -gt 5) {
                    Write-Host "     ... and $($recent.Warnings.Count - 5) more" -ForegroundColor DarkYellow
                }
            }
        }
    }

    # Test Results
    Write-Host "`n🧪 Test Results" -ForegroundColor White
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor DarkGray
    
    $testResults = Get-TestResults
    
    if ($testResults.Available) {
        Write-Host "  Last Run: $($testResults.LastRun)" -ForegroundColor Gray
        Write-Host "  Total Tests: $($testResults.Total)" -ForegroundColor White
        
        if ($testResults.Passed -gt 0) {
            Write-Host "  ✅ Passed: $($testResults.Passed)" -ForegroundColor Green
        }
        if ($testResults.Failed -gt 0) {
            Write-Host "  ❌ Failed: $($testResults.Failed)" -ForegroundColor Red
        }
        if ($testResults.Skipped -gt 0) {
            Write-Host "  ⏭️  Skipped: $($testResults.Skipped)" -ForegroundColor Yellow
        }
        
        $passRate = if ($testResults.Total -gt 0) {
            [Math]::Round(($testResults.Passed / $testResults.Total) * 100, 1)
        } else { 0 }
        
        Write-Host "  Pass Rate: $passRate%" -ForegroundColor $(if ($passRate -ge 90) { 'Green' } elseif ($passRate -ge 70) { 'Yellow' } else { 'Red' })
    } else {
        Write-Host "  ℹ️  No test results available" -ForegroundColor Gray
        Write-Host "  Run tests from the Testing menu to generate results" -ForegroundColor DarkGray
    }

    # Log Statistics
    Write-Host "`n📋 Log Statistics" -ForegroundColor White
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor DarkGray
    
    $logFiles = Get-LogFiles -Type Application -ErrorAction SilentlyContinue
    if ($logFiles) {
        $latest = $logFiles[0]
        $stats = Get-LogStatistics -Path $latest.FullName -ErrorAction SilentlyContinue
        
        if ($stats) {
            Write-Host "  Current Log: $($stats.FileName)" -ForegroundColor Gray
            Write-Host "  Size: $($stats.SizeKB) KB" -ForegroundColor Gray
            Write-Host "  Total Entries: $($stats.TotalLines)" -ForegroundColor White
            
            if ($stats.LogLevels.Critical -gt 0) {
                Write-Host "  🔴 Critical: $($stats.LogLevels.Critical)" -ForegroundColor Magenta
            }
            if ($stats.LogLevels.Error -gt 0) {
                Write-Host "  ❌ Errors: $($stats.LogLevels.Error)" -ForegroundColor Red
            }
            if ($stats.LogLevels.Warning -gt 0) {
                Write-Host "  ⚠️  Warnings: $($stats.LogLevels.Warning)" -ForegroundColor Yellow
            }
            Write-Host "  ℹ️  Info: $($stats.LogLevels.Information)" -ForegroundColor Cyan
        }
    } else {
        Write-Host "  ⚠️  No log files found" -ForegroundColor Yellow
    }

    # Quick Actions
    Write-Host "`n💡 Quick Actions" -ForegroundColor White
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor DarkGray
    Write-Host "  • View detailed errors: Reports & Logs > View Errors & Warnings" -ForegroundColor Gray
    Write-Host "  • Run tests: Testing > Run Unit Tests" -ForegroundColor Gray
    Write-Host "  • View full logs: Reports & Logs > Log Dashboard" -ForegroundColor Gray
    Write-Host "  • Check system: Testing > Validate Environment" -ForegroundColor Gray

    Write-Host ""
}

# Main execution
Write-ScriptLog "Starting Health Dashboard"

try {
    Show-HealthDashboard -ShowAll:$ShowAll
    Write-ScriptLog "Health Dashboard completed successfully"
} catch {
    Write-ScriptLog "Health Dashboard error: $_" -Level 'Error'
    Write-Host "Error displaying health dashboard: $_" -ForegroundColor Red
    exit 1
}

<#
.SYNOPSIS
Performs comprehensive backup maintenance operations for the OpenTofu Lab Automation project.

.DESCRIPTION
This function provides unified backup maintenance capabilities including:
- Backup file consolidation and organization
- Permanent cleanup of problematic files
- Statistics generation and reporting
- Integration with unified maintenance system
- Cross-platform backup management

.PARAMETER Mode
The maintenance mode to execute:
- Quick: Fast backup consolidation and basic cleanup
- Full: Complete backup maintenance with statistics
- Cleanup: Focus on permanent cleanup operations
- Statistics: Generate backup statistics and reports
- All: Execute all backup maintenance operations

.PARAMETER AutoFix
Whether to automatically apply fixes for backup issues.

.PARAMETER OutputFormat
The format for output messages:
- Standard: Human-readable output
- CI: Structured output for CI/CD systems
- JSON: JSON formatted results

.PARAMETER WhatIf
Show what operations would be performed without executing them.

.EXAMPLE
Invoke-BackupMaintenance -Mode "Quick"
Performs quick backup consolidation and cleanup.

.EXAMPLE
Invoke-BackupMaintenance -Mode "Full" -AutoFix -OutputFormat "CI"
Performs comprehensive backup maintenance with auto-fixes and CI output.

.EXAMPLE
Invoke-BackupMaintenance -Mode "Statistics" -OutputFormat "JSON"
Generates backup statistics in JSON format.

.NOTES
This function integrates with the unified maintenance system and follows
project standards for logging, error handling, and cross-platform compatibility.
#>
function Invoke-BackupMaintenance {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory=$false)]
        [ValidateSet("Quick", "Full", "Cleanup", "Statistics", "All")]
        [string]$Mode = "Quick",
        
        [Parameter(Mandatory=$false)]
        [switch]$AutoFix,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet("Standard", "CI", "JSON")]
        [string]$OutputFormat = "Standard"
    )
    
    $ErrorActionPreference = "Stop"    # Import required modules
    try {
        $labRunnerPath = "$env:PROJECT_ROOT\pwsh\modules\LabRunner"
        Import-Module $labRunnerPath -Force -ErrorAction Stop
    } catch {
        Write-Error "Failed to import LabRunner module: $($_.Exception.Message)"
        return
    }
    
    # Initialize results tracking
    $results = @{
        Mode = $Mode
        StartTime = Get-Date
        Operations = @()
        Statistics = @{
            BackupDirectories = @()
            TotalBackupSize = 0
            OldestBackup = $null
            NewestBackup = $null
        }
        Errors = @()
        Success = $true
    }
    
    try {
        Write-CustomLog "Starting backup maintenance in $Mode mode..." "INFO"
          # Execute maintenance operations based on mode
        switch ($Mode) {
            "Quick" {
                $results = Invoke-QuickBackupMaintenance -Results $results -AutoFix:$AutoFix
            }
            "Full" {
                $results = Invoke-FullBackupMaintenance -Results $results -AutoFix:$AutoFix
            }
            "Cleanup" {
                $results = Invoke-CleanupBackupMaintenance -Results $results -AutoFix:$AutoFix
            }
            "Statistics" {
                $results = Invoke-StatisticsBackupMaintenance -Results $results
            }
            "All" {
                $results = Invoke-AllBackupMaintenance -Results $results -AutoFix:$AutoFix
            }
        }
        
        # Generate final statistics
        $results.EndTime = Get-Date
        $results.Duration = $results.EndTime - $results.StartTime
        $results.TotalOperations = $results.Operations.Count
        
        # Output results based on format
        Write-BackupMaintenanceResults -Results $results -OutputFormat $OutputFormat
        
        if ($results.Errors.Count -eq 0) {
            Write-CustomLog "Backup maintenance completed successfully" "INFO"
        } else {
            Write-CustomLog "Backup maintenance completed with $($results.Errors.Count) errors" "WARN"
        }
        
        return $results
        
    } catch {
        $results.Success = $false
        $results.Errors += $_.Exception.Message
        Write-CustomLog "Backup maintenance failed: $($_.Exception.Message)" "ERROR"
        throw
    }
}

# Internal helper functions
function Invoke-QuickBackupMaintenance {
    param($Results, [switch]$AutoFix)
    
    Write-CustomLog "Executing quick backup maintenance..." "INFO"
      # 1. Quick backup consolidation
    try {
        Write-CustomLog "Running backup consolidation..." "INFO"
        if ($WhatIfPreference) {
            Write-CustomLog "WhatIf: Would run backup consolidation" "INFO"
            $consolidationResult = @{
                FilesProcessed = 0
                DirectoriesProcessed = 0
            }
        } else {
            $consolidationResult = Invoke-BackupConsolidation -ProjectRoot "." -Force
        }
        $Results.Operations += @{
            Operation = "BackupConsolidation"
            Status = "Success"
            FilesProcessed = $consolidationResult.FilesProcessed
            DirectoriesProcessed = $consolidationResult.DirectoriesProcessed
        }
    } catch {
        $Results.Errors += "Backup consolidation failed: $($_.Exception.Message)"
        $Results.Operations += @{
            Operation = "BackupConsolidation"
            Status = "Failed"
            Error = $_.Exception.Message
        }
    }
    
    # 2. Basic cleanup of problematic files
    if ($AutoFix) {        try {
            Write-CustomLog "Running basic cleanup..." "INFO"            if ($WhatIfPreference) {
                Write-CustomLog "WhatIf: Would run basic cleanup for temp and cache files" "INFO"
                $cleanupResult = @{
                    FilesRemoved = 0
                }
            } else {
                $cleanupResult = Invoke-PermanentCleanup -ProjectRoot "." -ProblematicPatterns @("*.tmp", "*~", "*.cache") -Force
            }
            $Results.Operations += @{
                Operation = "BasicCleanup"
                Status = "Success"
                FilesRemoved = $cleanupResult.FilesRemoved
            }
        } catch {
            $Results.Errors += "Basic cleanup failed: $($_.Exception.Message)"
            $Results.Operations += @{
                Operation = "BasicCleanup"
                Status = "Failed"
                Error = $_.Exception.Message
            }
        }
    }
    
    return $Results
}

function Invoke-FullBackupMaintenance {
    param($Results, [switch]$AutoFix)
    
    Write-CustomLog "Executing full backup maintenance..." "INFO"
    
    # Run quick maintenance first
    $Results = Invoke-QuickBackupMaintenance -Results $Results -AutoFix:$AutoFix
    
    # 3. Complete permanent cleanup
    if ($AutoFix) {        try {
            Write-CustomLog "Running comprehensive cleanup..." "INFO"            if ($WhatIfPreference) {
                Write-CustomLog "WhatIf: Would run comprehensive cleanup" "INFO"
                $cleanupResult = @{
                    FilesRemoved = 0
                    DirectoriesRemoved = 0
                }
            } else {
                $cleanupResult = Invoke-PermanentCleanup -ProjectRoot "." -Force
            }
            $Results.Operations += @{
                Operation = "ComprehensiveCleanup"
                Status = "Success"
                FilesRemoved = $cleanupResult.FilesRemoved
                DirectoriesRemoved = $cleanupResult.DirectoriesRemoved
            }
        } catch {
            $Results.Errors += "Comprehensive cleanup failed: $($_.Exception.Message)"
            $Results.Operations += @{
                Operation = "ComprehensiveCleanup"
                Status = "Failed"
                Error = $_.Exception.Message
            }
        }
    }
      # 4. Generate statistics
    try {
        Write-CustomLog "Generating backup statistics..." "INFO"
        $stats = Get-BackupStatistics -ProjectRoot "."
        $Results.Statistics = $stats
        $Results.Operations += @{
            Operation = "StatisticsGeneration"
            Status = "Success"
            BackupDirectories = $stats.BackupDirectories.Count
            TotalBackupSize = $stats.TotalBackupSize
        }
    } catch {
        $Results.Errors += "Statistics generation failed: $($_.Exception.Message)"
        $Results.Operations += @{
            Operation = "StatisticsGeneration"
            Status = "Failed"
            Error = $_.Exception.Message
        }
    }
    
    return $Results
}

function Invoke-CleanupBackupMaintenance {
    param($Results, [switch]$AutoFix)
    
    Write-CustomLog "Executing cleanup-focused backup maintenance..." "INFO"
    
    if ($AutoFix) {
        try {
            Write-CustomLog "Running comprehensive permanent cleanup..." "INFO"        if ($WhatIfPreference) {
            $cleanupResult = Invoke-PermanentCleanup -ProjectRoot "." -WhatIf
        } else {
            $cleanupResult = Invoke-PermanentCleanup -ProjectRoot "." -Force
        }
            $Results.Operations += @{
                Operation = "PermanentCleanup"
                Status = "Success"
                FilesRemoved = $cleanupResult.FilesRemoved
                DirectoriesRemoved = $cleanupResult.DirectoriesRemoved
                SpaceFreed = $cleanupResult.SpaceFreed
            }
        } catch {
            $Results.Errors += "Permanent cleanup failed: $($_.Exception.Message)"
            $Results.Operations += @{
                Operation = "PermanentCleanup"
                Status = "Failed"
                Error = $_.Exception.Message
            }
        }
    } else {
        Write-CustomLog "AutoFix not enabled - skipping cleanup operations" "WARN"
    }
    
    return $Results
}

function Invoke-StatisticsBackupMaintenance {
    param($Results)
    
    Write-CustomLog "Executing statistics-focused backup maintenance..." "INFO"
      try {
        Write-CustomLog "Generating comprehensive backup statistics..." "INFO"
        $stats = Get-BackupStatistics -ProjectRoot "."
        $Results.Statistics = $stats
        $Results.Operations += @{
            Operation = "ComprehensiveStatistics"
            Status = "Success"
            BackupDirectories = $stats.BackupDirectories.Count
            TotalBackupSize = $stats.TotalBackupSize
            OldestBackup = $stats.OldestBackup
            NewestBackup = $stats.NewestBackup
        }
    } catch {
        $Results.Errors += "Comprehensive statistics failed: $($_.Exception.Message)"
        $Results.Operations += @{
            Operation = "ComprehensiveStatistics"
            Status = "Failed"
            Error = $_.Exception.Message
        }
    }
    
    return $Results
}

function Invoke-AllBackupMaintenance {
    param($Results, [switch]$AutoFix)
    
    Write-CustomLog "Executing complete backup maintenance..." "INFO"
    
    # Run full maintenance
    $Results = Invoke-FullBackupMaintenance -Results $Results -AutoFix:$AutoFix
    
    # 5. Update backup exclusions
    try {
        Write-CustomLog "Updating backup exclusions..." "INFO"
        $exclusionResult = New-BackupExclusion
        $Results.Operations += @{
            Operation = "BackupExclusions"
            Status = "Success"
            ExclusionsUpdated = $exclusionResult.ExclusionsUpdated
        }
    } catch {
        $Results.Errors += "Backup exclusions update failed: $($_.Exception.Message)"
        $Results.Operations += @{
            Operation = "BackupExclusions"
            Status = "Failed"
            Error = $_.Exception.Message
        }
    }
    
    # 6. Generate comprehensive report
    try {
        Write-CustomLog "Generating backup maintenance report..." "INFO"
        $reportPath = "./reports/backup-maintenance-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
        
        if (-not $WhatIfPreference) {
            Results | ConvertTo-Json-Depth 10  Set-Content -Path $reportPath
        }
        
        $Results.Operations += @{
            Operation = "ReportGeneration"
            Status = "Success"
            ReportPath = $reportPath
        }
    } catch {
        $Results.Errors += "Report generation failed: $($_.Exception.Message)"
        $Results.Operations += @{
            Operation = "ReportGeneration"
            Status = "Failed"
            Error = $_.Exception.Message
        }
    }
    
    return $Results
}

function Write-BackupMaintenanceResults {
    param($Results, $OutputFormat)
    
    switch ($OutputFormat) {
        "JSON" {
            Results | ConvertTo-Json-Depth 10
        }
        "CI" {
            Write-Host "::group::Backup Maintenance Results"
            Write-Host "Mode: $($Results.Mode)"
            Write-Host "Duration: $($Results.Duration.TotalSeconds) seconds"
            Write-Host "Operations: $($Results.TotalOperations)"
            Write-Host "Errors: $($Results.Errors.Count)"
            
            foreach ($operation in $Results.Operations) {
                if ($operation.Status -eq "Success") {
                    Write-Host " $($operation.Operation)" -ForegroundColor Green
                } else {
                    Write-Host " $($operation.Operation): $($operation.Error)" -ForegroundColor Red
                }
            }
            Write-Host "::endgroup::"
        }
        default {
            Write-Host "`n=== Backup Maintenance Results ===" -ForegroundColor Cyan
            Write-Host "Mode: $($Results.Mode)" -ForegroundColor White
            Write-Host "Duration: $($Results.Duration.TotalSeconds) seconds" -ForegroundColor White
            Write-Host "Total Operations: $($Results.TotalOperations)" -ForegroundColor White
            
            if ($Results.Operations.Count -gt 0) {
                Write-Host "`nOperations:" -ForegroundColor Yellow
                foreach ($operation in $Results.Operations) {
                    if ($operation.Status -eq "Success") {
                        Write-Host "   $($operation.Operation)" -ForegroundColor Green
                    } else {
                        Write-Host "   $($operation.Operation): $($operation.Error)" -ForegroundColor Red
                    }
                }
            }
            
            if ($Results.Statistics.Count -gt 0) {
                Write-Host "`nStatistics:" -ForegroundColor Yellow
                Write-Host "  Backup Directories: $($Results.Statistics.BackupDirectories.Count)" -ForegroundColor White
                Write-Host "  Total Backup Size: $($Results.Statistics.TotalBackupSize)" -ForegroundColor White
            }
            
            if ($Results.Errors.Count -gt 0) {
                Write-Host "`nErrors:" -ForegroundColor Red
                foreach ($error in $Results.Errors) {
                    Write-Host "  • $error" -ForegroundColor Red
                }
            }
            
            Write-Host "=================================" -ForegroundColor Cyan
        }
    }
}



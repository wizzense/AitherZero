#Requires -Version 7.0
<#
.SYNOPSIS
    Consolidates backup files for PatchManager operations
    
.DESCRIPTION
    Migrated from BackupManager into PatchManager to provide unified backup consolidation
    with enhanced Git integration and change control features.
    
.PARAMETER Config
    Configuration object with ProjectRoot, Force, and ExcludePaths properties
    
.EXAMPLE
    $config = @{
        ProjectRoot = "."
        Force = $true
        ExcludePaths = @("*.tmp", "node_modules")
    }
    Invoke-BackupConsolidation -Config $config
    
.NOTES
    This function is now part of PatchManager's comprehensive change management system.
    Integrated with Git operations and provides audit trails.
#>

function Invoke-BackupConsolidation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectRoot,
        
        [Parameter()]
        [int]$RetentionDays = 30,
        
        [Parameter()]
        [switch]$DryRun
    )
    
    begin {        # Initialize consolidation results
        $script:ConsolidationResults = @{
            StartTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            TotalSizeReclaimed = 0
            FilesConsolidated = 0
            BackupsRemoved = 0
            Errors = @()
            DryRun = $DryRun.IsPresent
            ConsolidatedPaths = @()
        }

        # Define backup patterns to look for
        $BackupPatterns = @(
            "*_backup_*",
            "*.bak",
            "*_old",
            "*.backup",
            "*_archive_*"
        )
    }
    
    process {
        try {
            $CutoffDate = (Get-Date).AddDays(-$RetentionDays)
            Write-CustomLog "Starting backup consolidation with cutoff date: $CutoffDate"
            
            foreach ($Pattern in $BackupPatterns) {
                try {
                    Write-CustomLog "Scanning for pattern: $Pattern"
                    
                    # Get all matching files
                    $Files = Get-ChildItem -Path $ProjectRoot -Recurse -File -Filter $Pattern
                    
                    # Filter files by date
                    $FilteredFiles = $Files | Where-Object{
                        $_.LastWriteTime -lt $CutoffDate
                    }
                    
                    foreach ($File in $FilteredFiles) {
                        $RelativePath = $File.FullName.Replace($ProjectRoot, "").TrimStart('\', '/')
                        
                        if (-not $DryRun) {
                            try {
                                Remove-Item $File.FullName -Force
                                $script:ConsolidationResults.FilesConsolidated++
                                $script:ConsolidationResults.TotalSizeReclaimed += $File.Length
                                $script:ConsolidationResults.ConsolidatedPaths += $RelativePath
                            }
                            catch {
                                Write-CustomLog "Error removing file $($File.FullName): $_" "ERROR"
                            }
                        }                        else {
                            Write-CustomLog "Would remove: $RelativePath (DryRun)" "INFO"
                        }
                    }
                }                catch {
                    Write-CustomLog "Error processing pattern ${Pattern}: $($_.Exception.Message)" "ERROR"
                }
            }
            
            # Update the consolidation manifest
            $ManifestPath = Join-Path $ProjectRoot "consolidation-manifest.json"
            $script:ConsolidationResults | ConvertTo-Json-Depth 3 | Set-Content -Path $ManifestPath -Encoding UTF8
            
            Write-CustomLog "Consolidation completed. Files consolidated: $($script:ConsolidationResults.FilesConsolidated), Size reclaimed: $($script:ConsolidationResults.TotalSizeReclaimed) bytes"
        }
        catch {
            Write-CustomLog "Critical error during consolidation: $_" "ERROR"
            throw
        }
    }
    
    end {
        return $script:ConsolidationResults
    }
}





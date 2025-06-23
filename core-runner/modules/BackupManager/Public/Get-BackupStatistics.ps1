<#
.SYNOPSIS
Gets comprehensive statistics about backup files in the project

.DESCRIPTION
Analyzes backup files throughout the project and provides detailed statistics
including file counts, sizes, and age information.

.PARAMETER ProjectRoot
The root directory of the project to analyze

.PARAMETER IncludeDetails
Include detailed information about individual backup files

.EXAMPLE
Get-BackupStatistics -ProjectRoot "." -IncludeDetails

.NOTES
Follows OpenTofu Lab Automation maintenance standards
#>
function Get-BackupStatistics {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectRoot,
        
        [switch]$IncludeDetails
    )
    
    $ErrorActionPreference = "Stop"
    
    try {
        # Import LabRunner for logging
        if (Get-Module LabRunner -ErrorAction SilentlyContinue) {
            Write-CustomLog "Analyzing backup file statistics" "INFO"
        } else {
            Write-Host "INFO Analyzing backup file statistics" -ForegroundColor Green
        }
        
        # Resolve project root
        $ProjectRoot = Resolve-Path $ProjectRoot -ErrorAction Stop
        
        # Define backup patterns
        $BackupPatterns = @("*.bak", "*backup*", "*.old", "*.orig", "*~", "*.backup.*")
        $BackupFiles = @()
        
        foreach ($Pattern in $BackupPatterns) {
            $Files = Get-ChildItem -Path $ProjectRoot -Recurse -File -Filter $Pattern -ErrorAction SilentlyContinue
            $BackupFiles += $Files
        }
        
        if ($BackupFiles.Count -eq 0) {
            $result = @{
                TotalFiles = 0
                TotalSize = 0
                AverageSize = 0
                OldestFile = $null
                NewestFile = $null
                FileTypes = @{}
                Details = @()
            }
        } else {
            # Calculate statistics
            $TotalSize = (BackupFiles | Measure-Object -Property Length -Sum).Sum
            $AverageSize = [Math]::Round($TotalSize / $BackupFiles.Count, 2)
            
            # Find oldest and newest files
            $OldestFile = BackupFiles | Sort-ObjectLastWriteTime | Select-Object -First 1
            $NewestFile = BackupFiles | Sort-ObjectLastWriteTime -Descending | Select-Object -First 1
            
            # Group by file extension
            $FileTypes = BackupFiles | Group-ObjectExtension | ForEach-Object{
                $percentage = [Math]::Round(($_.Count / $BackupFiles.Count) * 100, 1)
                @{
                    Extension = if ($_.Name) { $_.Name } else { "(no extension)" }
                    Count = $_.Count
                    Percentage = $percentage
                }
            }
            
            $result = @{
                TotalFiles = $BackupFiles.Count
                TotalSize = [Math]::Round($TotalSize / 1MB, 2)
                AverageSize = [Math]::Round($AverageSize / 1KB, 2)
                OldestFile = if ($OldestFile) { 
                    @{
                        Name = $OldestFile.Name
                        Age = [Math]::Round(((Get-Date) - $OldestFile.LastWriteTime).TotalDays, 1)
                    }
                } else { $null }
                NewestFile = if ($NewestFile) { 
                    @{
                        Name = $NewestFile.Name
                        Age = [Math]::Round(((Get-Date) - $NewestFile.LastWriteTime).TotalDays, 1)
                    }
                } else { $null }
                FileTypes = $FileTypes
            }
            
            if ($IncludeDetails) {
                $result.Details = BackupFiles | ForEach-Object{
                    @{
                        Name = $_.Name
                        Path = $_.FullName.Replace($ProjectRoot, "").TrimStart('\', '/')
                        Size = [Math]::Round($_.Length / 1KB, 2)
                        LastModified = $_.LastWriteTime
                        Age = [Math]::Round(((Get-Date) - $_.LastWriteTime).TotalDays, 1)
                    }
                }
            }
        }
        
        # Log summary
        $summaryMessage = "Backup statistics analysis completed: $($result.TotalFiles) files, $($result.TotalSize) MB"
        if (Get-Module LabRunner -ErrorAction SilentlyContinue) {
            Write-CustomLog $summaryMessage "INFO"
        } else {
            Write-Host "INFO $summaryMessage" -ForegroundColor Green
        }
        
        return $result
        
    } catch {
        $ErrorMessage = "Failed to get backup statistics: $($_.Exception.Message)"
        if (Get-Module LabRunner -ErrorAction SilentlyContinue) {
            Write-CustomLog $ErrorMessage "ERROR"
        } else {
            Write-Host "ERROR $ErrorMessage" -ForegroundColor Red
        }
        throw $_
    }
}





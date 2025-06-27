#Requires -Version 7.0

<#
.SYNOPSIS
Consolidates all backup files into a centralized backup location

.DESCRIPTION
Finds and moves all backup files from throughout the project into a consolidated
backup directory structure, organized by date and type.

.PARAMETER Config
A PSCustomObject containing configuration parameters:
- ProjectRoot: The root directory of the project to scan for backup files
- Force: Skip confirmation prompts and force the consolidation (Optional)
- ExcludePaths: Additional paths to exclude from backup consolidation (Optional)

.EXAMPLE
$config = [PSCustomObject]@{
    ProjectRoot = "."
    Force = $true
}
Invoke-BackupConsolidation -Config $config

.NOTES
Follows OpenTofu Lab Automation maintenance standards
#>
function Invoke-BackupConsolidation {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'Config')]
        [ValidateNotNull()]
        [PSCustomObject]$Config,
        
        [Parameter(Mandatory = $true, ParameterSetName = 'Individual')]
        [string]$SourcePath,
        
        [Parameter(Mandatory = $true, ParameterSetName = 'Individual')]
        [string]$BackupPath,
        
        [Parameter(ParameterSetName = 'Individual')]
        [string[]]$ExcludePatterns = @(),
        
        [Parameter(ParameterSetName = 'Individual')]
        [ValidateSet("NoCompression", "Fastest", "Optimal")]
        [string]$CompressionLevel = "Optimal",
        
        [Parameter(ParameterSetName = 'Individual')]
        [switch]$Force
    )
    
    begin {
        $ErrorActionPreference = "Stop"
        
        # Define backup exclusions and root path
        $script:BackupExclusions = @(
            "*.git*",
            "*node_modules*",
            "*bin*",
            "*obj*",
            "*logs*",
            "*temp*",
            "*tmp*"
        )
        $script:BackupRootPath = "consolidated-backups"
        
        Write-CustomLog -Level 'INFO' -Message "Starting $($MyInvocation.MyCommand.Name)"
    }
      process {
        try {
            # Handle different parameter sets
            if ($PSCmdlet.ParameterSetName -eq 'Config') {
                # Extract configuration parameters from Config object
                $ProjectRoot = $Config.ProjectRoot
                $ForceOperation = if ($null -ne $Config.Force) { $Config.Force } else { $false }
                $ExcludePaths = if ($null -ne $Config.ExcludePaths) { $Config.ExcludePaths } else { @() }
                $BackupDestination = Join-Path $ProjectRoot $script:BackupRootPath (Get-Date -Format "yyyyMMdd")
            } else {
                # Individual parameters mode - for backward compatibility with tests
                $ProjectRoot = $SourcePath
                $ForceOperation = $Force.IsPresent
                $ExcludePaths = $ExcludePatterns
                $BackupDestination = $BackupPath
            }
            
            if ($PSCmdlet.ShouldProcess("Backup consolidation in $ProjectRoot", "Consolidate backup files")) {
                # Resolve project root
                $ProjectRoot = Resolve-Path $ProjectRoot -ErrorAction Stop
                
                # Ensure backup destination exists
                if (-not (Test-Path $BackupDestination)) {
                    New-Item -ItemType Directory -Path $BackupDestination -Force | Out-Null
                    Write-CustomLog -Level 'INFO' -Message "Created backup destination directory: $BackupDestination"
                }
                
                # Build exclusion patterns
                $AllExclusions = $script:BackupExclusions + $ExcludePaths
                Write-CustomLog -Level 'INFO' -Message "Using exclusion patterns: $($AllExclusions -join ', ')"
                
                # Find backup files with proper exclusion handling
                $BackupPatterns = @("*.bak", "*backup*", "*.old", "*.orig", "*~")
                $BackupFiles = @()
                
                foreach ($Pattern in $BackupPatterns) {
                    try {
                        $Files = Get-ChildItem -Path $ProjectRoot -Recurse -File -Filter $Pattern -ErrorAction SilentlyContinue
                        $FilteredFiles = $Files | Where-Object {
                            $FilePath = $_.FullName
                            $RelativePath = $FilePath.Replace($ProjectRoot, "").TrimStart('\', '/')
                            
                            $Excluded = $false
                            foreach ($Exclusion in $AllExclusions) {
                                if ($RelativePath -like $Exclusion -or $FilePath -like "*$($Exclusion.Replace('*', ''))*") {
                                    $Excluded = $true
                                    break
                                }
                            }
                            return -not $Excluded
                        }
                        $BackupFiles += $FilteredFiles
                        Write-CustomLog -Level 'INFO' -Message "Found $($FilteredFiles.Count) files matching pattern '$Pattern'"
                    }
                    catch {
                        Write-CustomLog -Level 'WARN' -Message "Error searching for pattern '$Pattern': $($_.Exception.Message)"
                    }
                }
                
                if ($BackupFiles.Count -eq 0) {
                    Write-CustomLog -Level 'INFO' -Message "No backup files found to consolidate"
                    return @{
                        Success = $true
                        FilesProcessed = 0
                        TotalSize = 0
                        Message = "No backup files found"
                    }
                }
                  # Confirm operation unless Force is specified or running in non-interactive mode
                if (-not $ForceOperation) {
                    Write-CustomLog -Level 'INFO' -Message "Found $($BackupFiles.Count) backup files to consolidate"
                    
                    # Check if we're in non-interactive mode (test environment, etc.)
                    $IsNonInteractive = ($Host.Name -eq 'Default Host') -or 
                                      ([Environment]::UserInteractive -eq $false) -or
                                      ($env:PESTER_RUN -eq 'true') -or
                                      ($PSCmdlet.WhatIf)
                    
                    if ($IsNonInteractive) {
                        Write-CustomLog -Level 'INFO' -Message "Non-interactive mode detected - skipping confirmation (defaulting to 'no')"
                        Write-CustomLog -Level 'INFO' -Message "Operation cancelled - use Force=true to proceed in non-interactive mode"
                        return @{ Success = $false; Message = "Cancelled - non-interactive mode without Force" }
                    } else {
                        $Confirmation = Read-Host "Proceed with consolidation? (y/N)"
                        if ($Confirmation -notmatch '^[Yy]') {
                            Write-CustomLog -Level 'INFO' -Message "Operation cancelled by user"
                            return @{ Success = $false; Message = "Cancelled by user" }
                        }
                    }
                }
            
                # Process backup files
                $ProcessedCount = 0
                $TotalSize = 0
                $FailedMoves = @()

                Write-Progress -Activity "Backup Consolidation" -Status "Preparing to process files" -PercentComplete 0
                
                for ($i = 0; $i -lt $BackupFiles.Count; $i++) {
                    $File = $BackupFiles[$i]
                    $percentComplete = ($i / $BackupFiles.Count) * 100
                    Write-Progress -Activity "Backup Consolidation" -Status "Processing file $($i+1) of $($BackupFiles.Count)" -PercentComplete $percentComplete
                    
                    try {
                        $RelativePath = $File.FullName.Replace($ProjectRoot, "").TrimStart([char]'\', [char]'/')
                        $DestinationPath = Join-Path $BackupDestination $RelativePath
                        $DestinationDir = Split-Path $DestinationPath -Parent

                        if (-not (Test-Path $DestinationDir)) {
                            New-Item -ItemType Directory -Path $DestinationDir -Force | Out-Null
                        }

                        Move-Item -Path $File.FullName -Destination $DestinationPath -Force
                        Write-CustomLog -Level 'INFO' -Message "Moved $($File.FullName) to $DestinationPath"
                        $ProcessedCount++
                        $TotalSize += $File.Length
                    }
                    catch {
                        $ErrorMessage = "Failed to move $($File.FullName): $($_.Exception.Message)"
                        Write-CustomLog -Level 'WARN' -Message $ErrorMessage
                        $FailedMoves += $File.FullName
                    }
                }
                
                Write-Progress -Activity "Backup Consolidation" -Status "Complete" -Completed
                
                $SummaryMessage = "Backup consolidation completed: $ProcessedCount files moved, $([Math]::Round($TotalSize / 1MB, 2)) MB total size"
                Write-CustomLog -Level 'SUCCESS' -Message $SummaryMessage

                if ($FailedMoves.Count -gt 0) {
                    Write-CustomLog -Level 'WARN' -Message "Failed to move $($FailedMoves.Count) files. See warnings for details."
                }
                
                return @{
                    Success = ($FailedMoves.Count -eq 0)
                    FilesProcessed = $ProcessedCount
                    TotalSize = $TotalSize
                    Message = $SummaryMessage
                    FailedFiles = $FailedMoves
                }
            }
        }
        catch {
            Write-CustomLog -Level 'ERROR' -Message "Fatal error during backup consolidation: $($_.Exception.Message)"
            throw
        }
    }
    
    end {
        Write-CustomLog -Level 'SUCCESS' -Message "Completed $($MyInvocation.MyCommand.Name)"
    }
}
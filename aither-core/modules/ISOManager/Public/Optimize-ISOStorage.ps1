function Optimize-ISOStorage {
    <#
    .SYNOPSIS
        Optimizes ISO repository storage through cleanup, compression, and space management.

    .DESCRIPTION
        Provides comprehensive storage optimization for ISO repositories including
        duplicate detection, old file cleanup, compression options, and disk space
        monitoring with automated cleanup policies.

    .PARAMETER RepositoryPath
        Path to the ISO repository to optimize

    .PARAMETER MaxSizeGB
        Maximum repository size in GB before cleanup is triggered

    .PARAMETER RetentionDays
        Days to retain ISO files before considering them for cleanup

    .PARAMETER RemoveDuplicates
        Remove duplicate ISO files based on checksum comparison

    .PARAMETER CompressOldFiles
        Compress ISO files older than retention period

    .PARAMETER ArchiveOldFiles
        Move old files to archive location instead of deleting

    .PARAMETER ArchivePath
        Custom archive path (default: repository/Archive)

    .PARAMETER DryRun
        Show what would be optimized without making changes

    .PARAMETER Force
        Force optimization without confirmation prompts

    .EXAMPLE
        Optimize-ISOStorage -RepositoryPath "C:\ISOs" -MaxSizeGB 500

    .EXAMPLE
        Optimize-ISOStorage -RepositoryPath "C:\ISOs" -RemoveDuplicates -CompressOldFiles -RetentionDays 90

    .EXAMPLE
        Optimize-ISOStorage -RepositoryPath "C:\ISOs" -DryRun -ArchiveOldFiles
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateScript({Test-Path $_ -PathType Container})]
        [string]$RepositoryPath,

        [Parameter(Mandatory = $false)]
        [int]$MaxSizeGB = 1000,

        [Parameter(Mandatory = $false)]
        [int]$RetentionDays = 30,

        [Parameter(Mandatory = $false)]
        [switch]$RemoveDuplicates,

        [Parameter(Mandatory = $false)]
        [switch]$CompressOldFiles,

        [Parameter(Mandatory = $false)]
        [switch]$ArchiveOldFiles,

        [Parameter(Mandatory = $false)]
        [string]$ArchivePath,

        [Parameter(Mandatory = $false)]
        [switch]$DryRun,

        [Parameter(Mandatory = $false)]
        [switch]$Force
    )

    begin {
        Write-CustomLog -Level 'INFO' -Message "Starting ISO storage optimization: $RepositoryPath"

        # Initialize optimization results
        $optimizationResults = @{
            RepositoryPath = $RepositoryPath
            StartTime = Get-Date
            InitialSizeGB = 0
            FinalSizeGB = 0
            SpaceFreedGB = 0
            FilesProcessed = 0
            DuplicatesRemoved = 0
            FilesArchived = 0
            FilesCompressed = 0
            FilesDeleted = 0
            Errors = @()
            Warnings = @()
            DryRun = $DryRun.IsPresent
        }

        # Set default archive path
        if (-not $ArchivePath) {
            $ArchivePath = Join-Path $RepositoryPath "Archive"
        }
    }

    process {
        try {
            # Get initial repository size
            $initialInventory = Get-ISOInventory -RepositoryPath $RepositoryPath
            $optimizationResults.InitialSizeGB = [math]::Round(($initialInventory | Measure-Object -Property Size -Sum).Sum / 1GB, 2)
            $optimizationResults.FilesProcessed = $initialInventory.Count

            Write-CustomLog -Level 'INFO' -Message "Repository analysis: $($initialInventory.Count) files, $($optimizationResults.InitialSizeGB) GB"

            # Check if optimization is needed
            if ($optimizationResults.InitialSizeGB -le $MaxSizeGB -and -not $RemoveDuplicates -and -not $CompressOldFiles -and -not $ArchiveOldFiles) {
                Write-CustomLog -Level 'INFO' -Message "Repository size ($($optimizationResults.InitialSizeGB) GB) is within limit ($MaxSizeGB GB). No optimization needed."
                return $optimizationResults
            }

            if ($PSCmdlet.ShouldProcess($RepositoryPath, "Optimize ISO Storage")) {

                # 1. Remove duplicates if requested
                if ($RemoveDuplicates) {
                    Write-CustomLog -Level 'INFO' -Message "Scanning for duplicate ISO files..."
                    $duplicates = Find-DuplicateISOs -Inventory $initialInventory

                    foreach ($duplicate in $duplicates) {
                        try {
                            if ($DryRun) {
                                Write-CustomLog -Level 'INFO' -Message "DRYRUN: Would remove duplicate: $($duplicate.FilePath)"
                            } else {
                                $removeResult = Remove-ISOFile -FilePath $duplicate.FilePath -Force:$Force
                                if ($removeResult.FilesRemoved -gt 0) {
                                    $optimizationResults.DuplicatesRemoved++
                                    $optimizationResults.SpaceFreedGB += [math]::Round($duplicate.Size / 1GB, 2)
                                }
                            }
                        } catch {
                            $optimizationResults.Errors += "Failed to remove duplicate $($duplicate.FileName): $($_.Exception.Message)"
                        }
                    }

                    Write-CustomLog -Level 'INFO' -Message "Duplicate removal: $($optimizationResults.DuplicatesRemoved) files, $($optimizationResults.SpaceFreedGB) GB freed"
                }

                # 2. Process old files
                $cutoffDate = (Get-Date).AddDays(-$RetentionDays)
                $oldFiles = $initialInventory | Where-Object { $_.Modified -lt $cutoffDate }

                if ($oldFiles.Count -gt 0) {
                    Write-CustomLog -Level 'INFO' -Message "Found $($oldFiles.Count) files older than $RetentionDays days"

                    foreach ($oldFile in $oldFiles) {
                        try {
                            if ($ArchiveOldFiles) {
                                # Archive old files
                                $relativePath = $oldFile.FilePath.Replace($RepositoryPath, "").TrimStart('\/', '\\')
                                $archiveFilePath = Join-Path $ArchivePath $relativePath
                                $archiveDir = Split-Path $archiveFilePath -Parent

                                if ($DryRun) {
                                    Write-CustomLog -Level 'INFO' -Message "DRYRUN: Would archive $($oldFile.FileName) to $archiveFilePath"
                                } else {
                                    # Create archive directory if needed
                                    if (-not (Test-Path $archiveDir)) {
                                        New-Item -ItemType Directory -Path $archiveDir -Force | Out-Null
                                    }

                                    # Move file to archive
                                    Move-Item -Path $oldFile.FilePath -Destination $archiveFilePath -Force
                                    $optimizationResults.FilesArchived++
                                    Write-CustomLog -Level 'INFO' -Message "Archived: $($oldFile.FileName)"
                                }

                            } elseif ($CompressOldFiles) {
                                # Compress old files
                                $compressedPath = $oldFile.FilePath + ".gz"

                                if ($DryRun) {
                                    Write-CustomLog -Level 'INFO' -Message "DRYRUN: Would compress $($oldFile.FileName)"
                                } else {
                                    $compressionResult = Compress-ISOFile -FilePath $oldFile.FilePath -OutputPath $compressedPath -RemoveOriginal
                                    if ($compressionResult.Success) {
                                        $optimizationResults.FilesCompressed++
                                        $optimizationResults.SpaceFreedGB += [math]::Round($compressionResult.SpaceSaved / 1GB, 2)
                                        Write-CustomLog -Level 'INFO' -Message "Compressed: $($oldFile.FileName) (saved $([math]::Round($compressionResult.SpaceSaved / 1MB, 2)) MB)"
                                    }
                                }

                            } else {
                                # Delete old files if over size limit
                                if ($optimizationResults.InitialSizeGB -gt $MaxSizeGB) {
                                    if ($DryRun) {
                                        Write-CustomLog -Level 'INFO' -Message "DRYRUN: Would delete old file: $($oldFile.FileName)"
                                    } else {
                                        $removeResult = Remove-ISOFile -FilePath $oldFile.FilePath -Force:$Force
                                        if ($removeResult.FilesRemoved -gt 0) {
                                            $optimizationResults.FilesDeleted++
                                            $optimizationResults.SpaceFreedGB += [math]::Round($oldFile.Size / 1GB, 2)
                                        }
                                    }
                                }
                            }

                        } catch {
                            $optimizationResults.Errors += "Failed to process old file $($oldFile.FileName): $($_.Exception.Message)"
                        }
                    }
                }

                # 3. Clean up empty directories
                if (-not $DryRun) {
                    try {
                        Remove-EmptyDirectories -Path $RepositoryPath -Exclude @("Metadata", "Logs", "Temp")
                    } catch {
                        $optimizationResults.Warnings += "Failed to clean up empty directories: $($_.Exception.Message)"
                    }
                }

                # 4. Update repository statistics
                if (-not $DryRun) {
                    try {
                        $syncResult = Sync-ISORepository -RepositoryPath $RepositoryPath -UpdateMetadata
                        $optimizationResults.FinalSizeGB = $syncResult.Statistics.TotalSizeGB
                    } catch {
                        $optimizationResults.Warnings += "Failed to update repository statistics: $($_.Exception.Message)"

                        # Calculate final size manually
                        $finalInventory = Get-ISOInventory -RepositoryPath $RepositoryPath
                        $optimizationResults.FinalSizeGB = [math]::Round(($finalInventory | Measure-Object -Property Size -Sum).Sum / 1GB, 2)
                    }
                } else {
                    $optimizationResults.FinalSizeGB = $optimizationResults.InitialSizeGB - $optimizationResults.SpaceFreedGB
                }

                # 5. Generate optimization report
                $optimizationResults.EndTime = Get-Date
                $optimizationResults.Duration = $optimizationResults.EndTime - $optimizationResults.StartTime

                # Save optimization report
                $reportPath = Join-Path $RepositoryPath "Logs" "storage-optimization-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
                $logsDir = Split-Path $reportPath -Parent
                if (-not (Test-Path $logsDir)) {
                    New-Item -ItemType Directory -Path $logsDir -Force | Out-Null
                }

                $optimizationResults | ConvertTo-Json -Depth 10 | Set-Content $reportPath

                # Log summary
                $totalSpaceFreed = $optimizationResults.InitialSizeGB - $optimizationResults.FinalSizeGB
                $summary = "Storage optimization completed: $($optimizationResults.DuplicatesRemoved) duplicates removed, $($optimizationResults.FilesArchived) files archived, $($optimizationResults.FilesCompressed) files compressed, $($optimizationResults.FilesDeleted) files deleted, $totalSpaceFreed GB freed"

                if ($DryRun) {
                    Write-CustomLog -Level 'INFO' -Message "DRYRUN: $summary"
                } else {
                    Write-CustomLog -Level 'SUCCESS' -Message $summary
                }

                return $optimizationResults
            }

        } catch {
            $optimizationResults.Errors += "Storage optimization failed: $($_.Exception.Message)"
            Write-CustomLog -Level 'ERROR' -Message "Storage optimization failed: $($_.Exception.Message)"
            return $optimizationResults
        }
    }

    end {
        Write-CustomLog -Level 'INFO' -Message "Completed ISO storage optimization"
    }
}

function Sync-ISORepository {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepositoryPath,

        [Parameter(Mandatory = $false)]
        [string]$ConfigPath,

        [Parameter(Mandatory = $false)]
        [switch]$UpdateMetadata,

        [Parameter(Mandatory = $false)]
        [switch]$ValidateIntegrity,

        [Parameter(Mandatory = $false)]
        [switch]$CleanupOrphaned
    )

    begin {
        Write-CustomLog -Level 'INFO' -Message "Starting repository synchronization: $RepositoryPath"
    }

    process {
        try {
            # Verify repository exists
            if (-not (Test-Path $RepositoryPath)) {
                throw "Repository path does not exist: $RepositoryPath"
            }

            $repoConfigPath = Join-Path $RepositoryPath "repository.config.json"
            if (-not (Test-Path $repoConfigPath)) {
                throw "Repository configuration not found. This may not be a valid AitherZero ISO repository."
            }

            $repoConfig = Get-Content $repoConfigPath | ConvertFrom-Json
            Write-CustomLog -Level 'INFO' -Message "Synchronizing repository: $($repoConfig.Name)"

            $syncResults = @{
                RepositoryPath = $RepositoryPath
                StartTime = Get-Date
                TotalISOs = 0
                ValidatedISOs = 0
                UpdatedMetadata = 0
                RemovedOrphaned = 0
                Errors = @()
                Statistics = @{}
            }

            if ($PSCmdlet.ShouldProcess($RepositoryPath, "Synchronize ISO Repository")) {
                # Get current inventory
                $inventory = Get-ISOInventory -RepositoryPath $RepositoryPath -IncludeMetadata:$UpdateMetadata

                $syncResults.TotalISOs = $inventory.Count
                Write-CustomLog -Level 'INFO' -Message "Found $($inventory.Count) ISO files in repository"

                # Update repository statistics
                $statistics = @{
                    TotalISOs = $inventory.Count
                    WindowsISOs = ($inventory | Where-Object { $_.Type -eq 'Windows' }).Count
                    LinuxISOs = ($inventory | Where-Object { $_.Type -eq 'Linux' }).Count
                    CustomISOs = ($inventory | Where-Object { $_.Type -eq 'Unknown' }).Count
                    TotalSizeGB = [math]::Round(($inventory | Measure-Object -Property Size -Sum).Sum / 1GB, 2)
                    LastSynced = Get-Date
                }

                # Validate integrity if requested
                if ($ValidateIntegrity) {
                    Write-CustomLog -Level 'INFO' -Message "Validating ISO integrity..."
                    foreach ($iso in $inventory) {
                        try {
                            $integrity = Test-ISOIntegrity -FilePath $iso.FilePath -ValidateStructure
                            if ($integrity.Valid) {
                                $syncResults.ValidatedISOs++
                            } else {
                                $syncResults.Errors += "Integrity check failed for $($iso.FileName): $($integrity.ErrorMessage)"
                                Write-CustomLog -Level 'WARN' -Message "Integrity check failed for $($iso.FileName)"
                            }
                        } catch {
                            $syncResults.Errors += "Error validating $($iso.FileName): $($_.Exception.Message)"
                        }
                    }
                }

                # Update metadata if requested
                if ($UpdateMetadata) {
                    Write-CustomLog -Level 'INFO' -Message "Updating ISO metadata..."
                    $metadataDir = Join-Path $RepositoryPath "Metadata"
                    if (-not (Test-Path $metadataDir)) {
                        New-Item -ItemType Directory -Path $metadataDir -Force | Out-Null
                    }

                    foreach ($iso in $inventory) {
                        try {
                            $metadata = Get-ISOMetadata -FilePath $iso.FilePath -IncludeVolumeInfo
                            $metadataFile = Join-Path $metadataDir "$($iso.Name).metadata.json"
                            $metadata | ConvertTo-Json -Depth 10 | Set-Content $metadataFile
                            $syncResults.UpdatedMetadata++
                        } catch {
                            $syncResults.Errors += "Error updating metadata for $($iso.FileName): $($_.Exception.Message)"
                        }
                    }
                }

                # Cleanup orphaned metadata files if requested
                if ($CleanupOrphaned) {
                    Write-CustomLog -Level 'INFO' -Message "Cleaning up orphaned metadata files..."
                    $metadataDir = Join-Path $RepositoryPath "Metadata"
                    if (Test-Path $metadataDir) {
                        $metadataFiles = Get-ChildItem -Path $metadataDir -Filter "*.metadata.json"
                        foreach ($metaFile in $metadataFiles) {
                            $baseName = $metaFile.BaseName -replace '\.metadata$', ''
                            $correspondingISO = $inventory | Where-Object { $_.Name -eq $baseName }
                            if (-not $correspondingISO) {
                                Remove-Item -Path $metaFile.FullName -Force
                                $syncResults.RemovedOrphaned++
                                Write-CustomLog -Level 'INFO' -Message "Removed orphaned metadata: $($metaFile.Name)"
                            }
                        }
                    }
                }

                # Update repository configuration with new statistics
                $repoConfig.Statistics = $statistics
                $repoConfig.LastSynced = Get-Date
                $repoConfig | ConvertTo-Json -Depth 10 | Set-Content $repoConfigPath

                $syncResults.Statistics = $statistics
                $syncResults.EndTime = Get-Date
                $syncResults.Duration = $syncResults.EndTime - $syncResults.StartTime

                # Save sync results
                $syncResultsPath = Join-Path $RepositoryPath "Logs" "sync-results-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
                $logsDir = Split-Path $syncResultsPath -Parent
                if (-not (Test-Path $logsDir)) {
                    New-Item -ItemType Directory -Path $logsDir -Force | Out-Null
                }
                $syncResults | ConvertTo-Json -Depth 10 | Set-Content $syncResultsPath

                Write-CustomLog -Level 'SUCCESS' -Message "Repository synchronization completed. Duration: $($syncResults.Duration.TotalMinutes.ToString('F2')) minutes"
                return $syncResults
            }
        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Failed to synchronize repository: $($_.Exception.Message)"
            $syncResults.Errors += $_.Exception.Message
            $syncResults.EndTime = Get-Date
            return $syncResults
        }
    }

    end {
        Write-CustomLog -Level 'INFO' -Message "Completed repository synchronization"
    }
}

function Sync-InfrastructureRepository {
    <#
    .SYNOPSIS
        Synchronizes a registered infrastructure repository.

    .DESCRIPTION
        Pulls latest changes from remote repository, validates infrastructure code,
        and updates local cache. Supports offline mode fallback.

    .PARAMETER Name
        The repository name to sync.

    .PARAMETER Force
        Force sync even if cache is still valid.

    .PARAMETER ValidateOnly
        Only validate without pulling changes.

    .PARAMETER Offline
        Use cached version without attempting remote sync.

    .EXAMPLE
        Sync-InfrastructureRepository -Name "hyperv-prod" -Force

    .OUTPUTS
        PSCustomObject with sync status and details
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [string[]]$Name,

        [Parameter()]
        [switch]$Force,

        [Parameter()]
        [switch]$ValidateOnly,

        [Parameter()]
        [switch]$Offline
    )

    begin {
        Write-CustomLog -Level 'INFO' -Message "Starting repository synchronization"
        $repoConfig = Get-RepositoryConfiguration
        $results = @()
    }

    process {
        foreach ($repoName in $Name) {
            try {
                Write-CustomLog -Level 'INFO' -Message "Processing repository: $repoName"

                # Get repository configuration
                if (-not $repoConfig.Repositories.ContainsKey($repoName)) {
                    Write-CustomLog -Level 'ERROR' -Message "Repository '$repoName' not registered"
                    $results += [PSCustomObject]@{
                        Name = $repoName
                        Status = 'NotFound'
                        Success = $false
                        Message = "Repository not registered"
                    }
                    continue
                }

                $repo = $repoConfig.Repositories[$repoName]
                $repoPath = $repo.LocalPath

                # Check if repository exists locally
                if (-not (Test-Path $repoPath)) {
                    Write-CustomLog -Level 'WARNING' -Message "Repository path not found, cloning repository"

                    # Clone repository
                    $cloneResult = Invoke-GitClone -Url $repo.Url -Path $repoPath -Branch $repo.Branch -CredentialName $repo.CredentialName

                    if (-not $cloneResult.Success) {
                        $results += [PSCustomObject]@{
                            Name = $repoName
                            Status = 'CloneFailed'
                            Success = $false
                            Message = "Failed to clone repository: $($cloneResult.Error)"
                        }
                        continue
                    }
                }

                # Check cache validity
                $cacheValid = $false
                if ($repo.LastSync) {
                    $timeSinceSync = (Get-Date).ToUniversalTime() - [DateTime]$repo.LastSync
                    $cacheValid = $timeSinceSync.TotalSeconds -lt $repo.CacheTTL
                }

                # Handle offline mode
                if ($Offline) {
                    Write-CustomLog -Level 'INFO' -Message "Using offline mode for repository: $repoName"
                    $results += [PSCustomObject]@{
                        Name = $repoName
                        Status = 'Offline'
                        Success = $true
                        Message = "Using cached version"
                        LastSync = $repo.LastSync
                        CacheValid = $cacheValid
                    }
                    continue
                }

                # Check if sync needed
                if ($cacheValid -and -not $Force -and -not $ValidateOnly) {
                    Write-CustomLog -Level 'INFO' -Message "Cache still valid for repository: $repoName"
                    $results += [PSCustomObject]@{
                        Name = $repoName
                        Status = 'CacheValid'
                        Success = $true
                        Message = "Cache still valid, skipping sync"
                        LastSync = $repo.LastSync
                        CacheValid = $true
                    }
                    continue
                }

                # Validate only mode
                if ($ValidateOnly) {
                    Write-CustomLog -Level 'INFO' -Message "Validating repository: $repoName"
                    $validationResult = Test-RepositoryStructure -Path $repoPath

                    $results += [PSCustomObject]@{
                        Name = $repoName
                        Status = 'Validated'
                        Success = $validationResult.IsValid
                        Message = if ($validationResult.IsValid) { "Validation successful" } else { "Validation failed: $($validationResult.Errors -join ', ')" }
                        ValidationDetails = $validationResult
                    }
                    continue
                }

                # Perform sync
                Write-CustomLog -Level 'INFO' -Message "Syncing repository: $repoName"

                # Store current commit for rollback if needed
                $currentCommit = Get-GitCommit -Path $repoPath

                # Pull latest changes
                $pullResult = Invoke-GitPull -Path $repoPath -Branch $repo.Branch -CredentialName $repo.CredentialName

                if ($pullResult.Success) {
                    # Validate repository after sync
                    $validationResult = Test-RepositoryStructure -Path $repoPath

                    if ($validationResult.IsValid) {
                        # Update last sync time
                        $repo.LastSync = (Get-Date).ToUniversalTime()
                        $repo.Status = 'Synced'
                        $repo.Metadata = $validationResult.Metadata

                        # Save updated configuration
                        $repoConfig.Repositories[$repoName] = $repo
                        Save-RepositoryConfiguration -Configuration $repoConfig

                        $results += [PSCustomObject]@{
                            Name = $repoName
                            Status = 'Synced'
                            Success = $true
                            Message = "Repository synchronized successfully"
                            LastSync = $repo.LastSync
                            Changes = $pullResult.Changes
                            Metadata = $validationResult.Metadata
                        }

                        Write-CustomLog -Level 'SUCCESS' -Message "Repository '$repoName' synchronized successfully"
                    } else {
                        # Validation failed, rollback
                        Write-CustomLog -Level 'WARNING' -Message "Validation failed after sync, rolling back"
                        Reset-GitRepository -Path $repoPath -Commit $currentCommit

                        $results += [PSCustomObject]@{
                            Name = $repoName
                            Status = 'ValidationFailed'
                            Success = $false
                            Message = "Sync rolled back due to validation failure: $($validationResult.Errors -join ', ')"
                            ValidationDetails = $validationResult
                        }
                    }
                } else {
                    $results += [PSCustomObject]@{
                        Name = $repoName
                        Status = 'SyncFailed'
                        Success = $false
                        Message = "Failed to sync repository: $($pullResult.Error)"
                    }
                }

            } catch {
                Write-CustomLog -Level 'ERROR' -Message "Error syncing repository '$repoName': $_"
                $results += [PSCustomObject]@{
                    Name = $repoName
                    Status = 'Error'
                    Success = $false
                    Message = "Error: $_"
                }
            }
        }
    }

    end {
        # Return results
        if ($results.Count -eq 1) {
            $results[0]
        } else {
            $results
        }

        # Summary logging
        $successCount = ($results | Where-Object { $_.Success }).Count
        $totalCount = $results.Count

        if ($successCount -eq $totalCount) {
            Write-CustomLog -Level 'SUCCESS' -Message "All repositories synchronized successfully ($successCount/$totalCount)"
        } elseif ($successCount -gt 0) {
            Write-CustomLog -Level 'WARNING' -Message "Partial synchronization success ($successCount/$totalCount)"
        } else {
            Write-CustomLog -Level 'ERROR' -Message "All repository synchronizations failed (0/$totalCount)"
        }
    }
}

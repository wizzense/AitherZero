function Get-InfrastructureRepository {
    <#
    .SYNOPSIS
        Gets registered infrastructure repositories.

    .PARAMETER Name
        Filter by repository name (supports wildcards).

    .PARAMETER Tag
        Filter by tags.

    .PARAMETER IncludeStatus
        Include sync status and cache information.

    .EXAMPLE
        Get-InfrastructureRepository -Tag "production" -IncludeStatus

    .OUTPUTS
        Array of repository objects
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Name = "*",

        [Parameter()]
        [string[]]$Tag,

        [Parameter()]
        [switch]$IncludeStatus
    )

    begin {
        Write-CustomLog -Level 'DEBUG' -Message "Getting infrastructure repositories with filter: $Name"
        $repoConfig = Get-RepositoryConfiguration
    }

    process {
        try {
            # Get all repositories
            $repositories = @()

            foreach ($repoKey in $repoConfig.Repositories.Keys) {
                $repo = $repoConfig.Repositories[$repoKey]

                # Apply name filter
                if ($repo.Name -notlike $Name) {
                    continue
                }

                # Apply tag filter
                if ($Tag) {
                    $hasMatchingTag = $false
                    foreach ($filterTag in $Tag) {
                        if ($repo.Tags -contains $filterTag) {
                            $hasMatchingTag = $true
                            break
                        }
                    }
                    if (-not $hasMatchingTag) {
                        continue
                    }
                }

                # Create repository object
                $repoObject = [PSCustomObject]@{
                    Name = $repo.Name
                    Url = $repo.Url
                    Branch = $repo.Branch
                    LocalPath = $repo.LocalPath
                    Tags = $repo.Tags
                    RegisteredAt = $repo.RegisteredAt
                    CacheTTL = $repo.CacheTTL
                }

                # Add status information if requested
                if ($IncludeStatus) {
                    $repoObject | Add-Member -MemberType NoteProperty -Name Status -Value $repo.Status
                    $repoObject | Add-Member -MemberType NoteProperty -Name LastSync -Value $repo.LastSync

                    # Calculate cache status
                    $cacheValid = $false
                    $cacheRemaining = 0

                    if ($repo.LastSync) {
                        $timeSinceSync = (Get-Date).ToUniversalTime() - [DateTime]$repo.LastSync
                        $cacheValid = $timeSinceSync.TotalSeconds -lt $repo.CacheTTL

                        if ($cacheValid) {
                            $cacheRemaining = [Math]::Round(($repo.CacheTTL - $timeSinceSync.TotalSeconds) / 3600, 2)
                        }
                    }

                    $repoObject | Add-Member -MemberType NoteProperty -Name CacheValid -Value $cacheValid
                    $repoObject | Add-Member -MemberType NoteProperty -Name CacheRemainingHours -Value $cacheRemaining

                    # Check local path existence
                    $localExists = Test-Path $repo.LocalPath
                    $repoObject | Add-Member -MemberType NoteProperty -Name LocalExists -Value $localExists

                    # Get repository size if exists
                    if ($localExists) {
                        try {
                            $size = Get-DirectorySize -Path $repo.LocalPath
                            $repoObject | Add-Member -MemberType NoteProperty -Name SizeMB -Value ([Math]::Round($size / 1MB, 2))
                        } catch {
                            $repoObject | Add-Member -MemberType NoteProperty -Name SizeMB -Value 0
                        }
                    } else {
                        $repoObject | Add-Member -MemberType NoteProperty -Name SizeMB -Value 0
                    }

                    # Add metadata if available
                    if ($repo.Metadata) {
                        $repoObject | Add-Member -MemberType NoteProperty -Name Metadata -Value $repo.Metadata
                    }
                }

                # Add credential status if credential is configured
                if ($repo.CredentialName) {
                    $credentialValid = Test-StoredCredential -Name $repo.CredentialName
                    $repoObject | Add-Member -MemberType NoteProperty -Name CredentialName -Value $repo.CredentialName
                    $repoObject | Add-Member -MemberType NoteProperty -Name CredentialValid -Value $credentialValid
                }

                $repositories += $repoObject
            }

            # Sort by name
            $repositories | Sort-Object Name

        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Failed to get infrastructure repositories: $_"
            throw
        }
    }

    end {
        $count = $repositories.Count
        Write-CustomLog -Level 'DEBUG' -Message "Found $count infrastructure repositories"
    }
}

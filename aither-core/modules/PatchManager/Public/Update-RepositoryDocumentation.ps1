#Requires -Version 7.0

# Import shared utilities
$sharedPath = Resolve-Path (Join-Path $PSScriptRoot "../../../shared/Find-ProjectRoot.ps1") -ErrorAction Stop
. $sharedPath

function Update-RepositoryDocumentation {
    <#
    .SYNOPSIS
        Updates README.md and configuration files to use the correct repository URLs dynamically.

    .DESCRIPTION
        Detects the current repository context (AitherZero, AitherLabs, or Aitherium) and updates
        all documentation and configuration files to reference the correct repository URLs.

        This ensures that quickstart instructions and clone commands work correctly regardless
        of which fork in the chain the user is working from.

    .PARAMETER DryRun
        Show what would be updated without making changes.

    .PARAMETER Force
        Overwrite files without prompting.

    .EXAMPLE
        Update-RepositoryDocumentation -DryRun

    .EXAMPLE
        Update-RepositoryDocumentation -Force

    .NOTES
        This function updates:
        - README.md files with correct repository URLs
        - kicker-git.ps1 download URLs
        - Documentation links
        - Any hardcoded repository references
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [switch]$DryRun,
        [switch]$Force
    )

    begin {
        Write-CustomLog -Level 'INFO' -Message "Starting repository documentation update..."

        # Get current repository information
        try {
            $repoInfo = Get-GitRepositoryInfo
            Write-CustomLog -Level 'INFO' -Message "Detected repository: $($repoInfo.GitHubRepo) ($($repoInfo.Type))"
        }
        catch {
            Write-CustomLog -Level 'ERROR' -Message "Failed to detect repository info: $($_.Exception.Message)"
            throw
        }

        # Define repository mappings for the fork chain
        $repoMappings = @{
            'wizzense/AitherZero' = @{
                Name = 'AitherZero'
                Owner = 'wizzense'
                Description = 'Development fork'
                BaseUrl = 'https://github.com/wizzense/AitherZero'
                RawUrl = 'https://raw.githubusercontent.com/wizzense/AitherZero'
            }
            'Aitherium/AitherLabs' = @{
                Name = 'AitherLabs'
                Owner = 'Aitherium'
                Description = 'Public staging repository'
                BaseUrl = 'https://github.com/Aitherium/AitherLabs'
                RawUrl = 'https://raw.githubusercontent.com/Aitherium/AitherLabs'
            }
            'Aitherium/Aitherium' = @{
                Name = 'Aitherium'
                Owner = 'Aitherium'
                Description = 'Premium/enterprise repository'
                BaseUrl = 'https://github.com/Aitherium/Aitherium'
                RawUrl = 'https://raw.githubusercontent.com/Aitherium/Aitherium'
            }
        }

        $currentRepo = $repoMappings[$repoInfo.GitHubRepo]
        if (-not $currentRepo) {
            Write-CustomLog -Level 'ERROR' -Message "Unknown repository: $($repoInfo.GitHubRepo)"
            throw "Repository not recognized in fork chain"
        }

        Write-CustomLog -Level 'INFO' -Message "Current repository: $($currentRepo.Name) - $($currentRepo.Description)"
    }

    process {
        # Files to update with repository-specific content
        $filesToUpdate = @(
            @{
                Path = 'README.md'
                Type = 'README'
                Updates = @(
                    @{
                        Pattern = 'https://raw\.githubusercontent\.com/wizzense/opentofu-lab-automation/main/kicker-git\.ps1'
                        Replacement = "$($currentRepo.RawUrl)/main/kicker-git.ps1"
                        Description = 'Bootstrap download URL'
                    }
                    @{
                        Pattern = 'https://github\.com/wizzense/opentofu-lab-automation/blob/main/kicker-git\.ps1'
                        Replacement = "$($currentRepo.BaseUrl)/blob/main/kicker-git.ps1"
                        Description = 'Documentation link'
                    }
                    @{
                        Pattern = 'wizzense/opentofu-lab-automation'
                        Replacement = "$($currentRepo.Owner)/$($currentRepo.Name)"
                        Description = 'Repository references'
                    }
                )
            }
            @{
                Path = 'aither-core/README.md'
                Type = 'README'
                Updates = @(
                    @{
                        Pattern = 'wizzense/opentofu-lab-automation'
                        Replacement = "$($currentRepo.Owner)/$($currentRepo.Name)"
                        Description = 'Repository references'
                    }
                )
            }
            @{
                Path = 'kicker-git.ps1'
                Type = 'Script'
                Updates = @(
                    @{
                        Pattern = 'wizzense/opentofu-lab-automation'
                        Replacement = "$($currentRepo.Owner)/$($currentRepo.Name)"
                        Description = 'Self-update repository reference'
                    }
                )
            }
        )

        foreach ($file in $filesToUpdate) {
            $filePath = $file.Path

            if (-not (Test-Path $filePath)) {
                Write-CustomLog -Level 'WARN' -Message "File not found: $filePath"
                continue
            }

            Write-CustomLog -Level 'INFO' -Message "Processing $($file.Type): $filePath"

            try {                $content = Get-Content $filePath -Raw
                $changesMade = $false

                foreach ($update in $file.Updates) {
                    $matches = [regex]::Matches($content, $update.Pattern)
                    if ($matches.Count -gt 0) {
                        Write-CustomLog -Level 'INFO' -Message "  - Updating $($update.Description): $($matches.Count) matches found"
                        $content = $content -replace $update.Pattern, $update.Replacement
                        $changesMade = $true
                    }
                }

                if ($changesMade) {
                    if ($DryRun) {
                        Write-CustomLog -Level 'INFO' -Message "  - DRY RUN: Would update $filePath"
                    }                    else {
                        if ($PSCmdlet.ShouldProcess($filePath, "Update repository references") -or $Force) {
                            Set-Content -Path $filePath -Value $content -NoNewline
                            Write-CustomLog -Level 'SUCCESS' -Message "  - Updated $filePath"
                        }
                    }
                }
                else {
                    Write-CustomLog -Level 'INFO' -Message "  - No changes needed for $filePath"
                }
            }            catch {
                Write-CustomLog -Level 'ERROR' -Message "Failed to update ${filePath}: $($_.Exception.Message)"
            }
        }

        # Create a dynamic configuration template
        $dynamicConfigPath = 'configs/dynamic-repo-config.json'
        $dynamicConfig = @{
            repository = @{
                name = $currentRepo.Name
                owner = $currentRepo.Owner
                fullName = "$($currentRepo.Owner)/$($currentRepo.Name)"
                type = $repoInfo.Type
                description = $currentRepo.Description
                urls = @{
                    base = $currentRepo.BaseUrl
                    raw = $currentRepo.RawUrl
                    clone = "$($currentRepo.BaseUrl).git"
                }
            }
            forkChain = @()
            lastUpdated = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ssZ')
        }

        # Add fork chain information
        foreach ($fork in $repoInfo.ForkChain) {
            $forkMapping = $repoMappings[$fork.GitHubRepo]
            if ($forkMapping) {
                $dynamicConfig.forkChain += @{
                    name = $fork.Name
                    repository = $fork.GitHubRepo
                    type = $fork.Type
                    description = $forkMapping.Description
                    urls = @{
                        base = $forkMapping.BaseUrl
                        raw = $forkMapping.RawUrl
                    }
                }
            }
        }

        if ($DryRun) {
            Write-CustomLog -Level 'INFO' -Message "DRY RUN: Would create dynamic config at $dynamicConfigPath"            Write-CustomLog -Level 'INFO' -Message "Config content preview:"
            Write-CustomLog -Level 'INFO' -Message ($dynamicConfig | ConvertTo-Json -Depth 5)
        }        else {
            if ($PSCmdlet.ShouldProcess($dynamicConfigPath, "Create dynamic repository configuration") -or $Force) {
                $dynamicConfig | ConvertTo-Json -Depth 5 | Set-Content -Path $dynamicConfigPath
                Write-CustomLog -Level 'SUCCESS' -Message "Created dynamic repository configuration: $dynamicConfigPath"
            }
        }
    }

    end {
        Write-CustomLog -Level 'SUCCESS' -Message "Repository documentation update completed"
          # Provide usage instructions
        Write-CustomLog -Level 'SUCCESS' -Message "Repository documentation update completed"
        Write-CustomLog -Level 'SUCCESS' -Message "📋 Updated Repository Information:"
        Write-CustomLog -Level 'INFO' -Message "  Repository: $($currentRepo.Name) ($($currentRepo.Description))"
        Write-CustomLog -Level 'INFO' -Message "  Owner: $($currentRepo.Owner)"
        Write-CustomLog -Level 'INFO' -Message "  URL: $($currentRepo.BaseUrl)"
        Write-CustomLog -Level 'WARN' -Message "🔄 Users can now use the correct URLs for this repository:"
        Write-CustomLog -Level 'INFO' -Message "  Bootstrap: $($currentRepo.RawUrl)/main/kicker-git.ps1"
        Write-CustomLog -Level 'INFO' -Message "  Clone: $($currentRepo.BaseUrl).git"

        if (-not $DryRun) {
            Write-CustomLog -Level 'SUCCESS' -Message "✅ All documentation and configurations updated for $($currentRepo.Name)"
        }
    }
}
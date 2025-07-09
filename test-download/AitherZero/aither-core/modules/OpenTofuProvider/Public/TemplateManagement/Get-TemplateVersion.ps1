function Get-TemplateVersion {
    <#
    .SYNOPSIS
        Gets version information for infrastructure templates.

    .DESCRIPTION
        Retrieves version information for templates including available versions,
        latest version, and version metadata.

    .PARAMETER Name
        Name of the template.

    .PARAMETER Path
        Path to search for templates.

    .PARAMETER Version
        Specific version to retrieve (default: all versions).

    .PARAMETER Latest
        Get only the latest version.

    .PARAMETER IncludePrerelease
        Include pre-release versions.

    .EXAMPLE
        Get-TemplateVersion -Name "web-server" -Latest

    .EXAMPLE
        Get-TemplateVersion -Name "web-server" -Version "2.0.0"

    .OUTPUTS
        PSCustomObject with version information
    #>
    [CmdletBinding(DefaultParameterSetName = 'All')]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter()]
        [string]$Path = (Get-TemplateConfiguration).TemplatePath,

        [Parameter(ParameterSetName = 'Specific')]
        [string]$Version,

        [Parameter(ParameterSetName = 'Latest')]
        [switch]$Latest,

        [Parameter()]
        [switch]$IncludePrerelease
    )

    begin {
        Write-CustomLog -Level 'DEBUG' -Message "Getting version information for template: $Name"
        $templatePath = Join-Path $Path $Name
    }

    process {
        try {
            # Check if template exists
            if (-not (Test-Path $templatePath)) {
                Write-CustomLog -Level 'WARNING' -Message "Template not found: $Name"
                return
            }

            # Get all version directories
            $versionDirs = Get-ChildItem -Path $templatePath -Directory |
                Where-Object { $_.Name -match '^\d+\.\d+\.\d+(-[a-zA-Z0-9-]+)?(\+[a-zA-Z0-9-]+)?$' }

            if (-not $IncludePrerelease) {
                $versionDirs = $versionDirs | Where-Object { $_.Name -notmatch '-' }
            }

            if ($versionDirs.Count -eq 0) {
                Write-CustomLog -Level 'WARNING' -Message "No versions found for template: $Name"
                return
            }

            # Parse and sort versions
            $versions = @()
            foreach ($dir in $versionDirs) {
                try {
                    $versionObj = [System.Management.Automation.SemanticVersion]::new($dir.Name)
                    $versionPath = $dir.FullName

                    # Load version metadata
                    $metadataPath = Join-Path $versionPath "template.json"
                    $versionInfoPath = Join-Path $versionPath "version.json"

                    $metadata = if (Test-Path $metadataPath) {
                        Get-Content $metadataPath -Raw | ConvertFrom-Json
                    } else {
                        @{}
                    }

                    $versionInfo = if (Test-Path $versionInfoPath) {
                        Get-Content $versionInfoPath -Raw | ConvertFrom-Json
                    } else {
                        @{}
                    }

                    # Check dependencies
                    $dependencies = @()
                    if ($metadata.dependencies) {
                        foreach ($dep in $metadata.dependencies) {
                            $dependencies += [PSCustomObject]@{
                                Name = $dep.name
                                Version = $dep.version
                                Provider = $dep.provider
                                Optional = $dep.optional
                            }
                        }
                    }

                    # Create version object
                    $versionData = [PSCustomObject]@{
                        Template = $Name
                        Version = $dir.Name
                        SemanticVersion = $versionObj
                        Path = $versionPath
                        Description = $metadata.description ?? "No description"
                        Provider = $metadata.provider ?? "Unknown"
                        Created = $metadata.created ?? $dir.CreationTime
                        Released = $versionInfo.released ?? $metadata.created
                        Author = $metadata.author ?? "Unknown"
                        Dependencies = $dependencies
                        Changelog = $versionInfo.changelog ?? @{}
                        IsPrerelease = $versionObj.PreReleaseLabel -ne $null
                        Metadata = $metadata
                    }

                    $versions += $versionData
                } catch {
                    Write-CustomLog -Level 'WARNING' -Message "Failed to parse version: $($dir.Name) - $_"
                }
            }

            # Sort versions (newest first)
            $versions = $versions | Sort-Object SemanticVersion -Descending

            # Handle parameter sets
            switch ($PSCmdlet.ParameterSetName) {
                'Specific' {
                    $specificVersion = $versions | Where-Object { $_.Version -eq $Version }
                    if ($specificVersion) {
                        return $specificVersion
                    } else {
                        Write-CustomLog -Level 'WARNING' -Message "Version not found: $Name v$Version"
                        return
                    }
                }

                'Latest' {
                    $latestVersion = $versions | Select-Object -First 1
                    if ($latestVersion) {
                        Write-CustomLog -Level 'DEBUG' -Message "Latest version: $($latestVersion.Version)"
                        return $latestVersion
                    }
                }

                default {
                    # Return all versions
                    Write-CustomLog -Level 'DEBUG' -Message "Found $($versions.Count) versions"

                    # Add summary object
                    $summary = [PSCustomObject]@{
                        Template = $Name
                        Path = $templatePath
                        TotalVersions = $versions.Count
                        LatestVersion = $versions[0].Version
                        LatestStable = ($versions | Where-Object { -not $_.IsPrerelease } | Select-Object -First 1).Version
                        Versions = $versions
                    }

                    return $summary
                }
            }

        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Failed to get template versions: $_"
            throw
        }
    }

    end {
        Write-CustomLog -Level 'DEBUG' -Message "Version query completed"
    }
}

function Get-ISOConfiguration {
    <#
    .SYNOPSIS
        Gets ISO configuration and metadata for deployment.

    .DESCRIPTION
        Retrieves detailed ISO configuration including paths, versions,
        customization status, and readiness for deployment. Provides
        inventory management capabilities.

    .PARAMETER Name
        Specific ISO name to retrieve (supports wildcards).

    .PARAMETER Repository
        ISO repository path (default: from environment).

    .PARAMETER IncludeMetadata
        Include detailed metadata from ISOs.

    .PARAMETER CheckUpdates
        Check for available updates.

    .PARAMETER DeploymentConfig
        Get ISOs specific to a deployment configuration.

    .EXAMPLE
        Get-ISOConfiguration -Name "WindowsServer*" -IncludeMetadata

    .EXAMPLE
        Get-ISOConfiguration -DeploymentConfig ".\deploy.yaml" -CheckUpdates

    .OUTPUTS
        Array of ISO configuration objects
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Name = "*",

        [Parameter()]
        [string]$Repository,

        [Parameter()]
        [switch]$IncludeMetadata,

        [Parameter()]
        [switch]$CheckUpdates,

        [Parameter()]
        [string]$DeploymentConfig
    )

    begin {
        Write-CustomLog -Level 'INFO' -Message "Getting ISO configuration"

        # Determine repository path
        if (-not $Repository) {
            $Repository = Join-Path $env:PROJECT_ROOT "iso-repository"
        }

        # Check for ISOManager
        $script:hasISOManager = (Get-Command -Name 'Get-ISOInventory' -ErrorAction SilentlyContinue) -ne $null
    }

    process {
        try {
            $isoConfigurations = @()

            # If deployment config specified, get requirements first
            if ($DeploymentConfig) {
                Write-CustomLog -Level 'INFO' -Message "Loading ISOs from deployment configuration"

                $isoReq = Initialize-DeploymentISOs -DeploymentConfig $DeploymentConfig -ISORepository $Repository -SkipExistingCheck

                foreach ($req in $isoReq.Requirements) {
                    $config = Get-SingleISOConfiguration -Requirement $req -Repository $Repository -IncludeMetadata:$IncludeMetadata -CheckUpdates:$CheckUpdates
                    if ($config) {
                        $isoConfigurations += $config
                    }
                }
            } else {
                # Get all ISOs from repository
                Write-CustomLog -Level 'INFO' -Message "Scanning repository: $Repository"

                if (-not (Test-Path $Repository)) {
                    Write-CustomLog -Level 'WARN' -Message "ISO repository not found: $Repository"
                    return @()
                }

                # Find all ISO files
                $isoFiles = Get-ChildItem -Path $Repository -Filter "*.iso" -File | Where-Object { $_.Name -like $Name }

                Write-CustomLog -Level 'INFO' -Message "Found $($isoFiles.Count) ISO file(s)"

                foreach ($isoFile in $isoFiles) {
                    $config = Get-SingleISOConfiguration -ISOFile $isoFile -IncludeMetadata:$IncludeMetadata -CheckUpdates:$CheckUpdates
                    if ($config) {
                        $isoConfigurations += $config
                    }
                }
            }

            # Sort by name
            $isoConfigurations = $isoConfigurations | Sort-Object Name

            # Add summary if multiple ISOs
            if ($isoConfigurations.Count -gt 1) {
                $summary = @{
                    TotalISOs = $isoConfigurations.Count
                    TotalSize = ($isoConfigurations | Measure-Object -Property Size -Sum).Sum
                    TotalSizeGB = [Math]::Round(($isoConfigurations | Measure-Object -Property Size -Sum).Sum / 1GB, 2)
                    UpdatesAvailable = ($isoConfigurations | Where-Object { $_.UpdateAvailable }).Count
                    Customized = ($isoConfigurations | Where-Object { $_.IsCustomized }).Count
                }

                Write-CustomLog -Level 'INFO' -Message "ISO Summary: $($summary.TotalISOs) ISOs, $($summary.TotalSizeGB) GB total"

                # Add summary as first item if returning array
                if ($isoConfigurations -is [array]) {
                    $summaryObj = [PSCustomObject]@{
                        Name = "=== SUMMARY ==="
                        Type = "Summary"
                        Summary = $summary
                    }
                    $isoConfigurations = @($summaryObj) + $isoConfigurations
                }
            }

            return $isoConfigurations

        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Failed to get ISO configuration: $($_.Exception.Message)"
            throw
        }
    }
}

function Get-SingleISOConfiguration {
    param(
        [object]$Requirement,
        [System.IO.FileInfo]$ISOFile,
        [string]$Repository,
        [switch]$IncludeMetadata,
        [switch]$CheckUpdates
    )

    try {
        # Initialize configuration object
        $config = @{
            Name = $null
            Type = $null
            Path = $null
            Exists = $false
            Size = 0
            SizeGB = 0
            Created = $null
            Modified = $null
            Version = $null
            IsCustomized = $false
            CustomizationProfile = $null
            Checksum = $null
            UpdateAvailable = $false
            LatestVersion = $null
            Ready = $false
            Metadata = @{}
        }

        # Process based on input type
        if ($Requirement) {
            # From deployment requirement
            $config.Name = $Requirement.Name
            $config.Type = $Requirement.Type
            $config.Path = $Requirement.Path
            $config.Exists = $Requirement.Exists
            $config.CustomizationProfile = $Requirement.Customization

            if ($Requirement.Path -and (Test-Path $Requirement.Path)) {
                $ISOFile = Get-Item $Requirement.Path
            }
        } elseif ($ISOFile) {
            # From file system scan
            $config.Name = $ISOFile.BaseName
            $config.Path = $ISOFile.FullName
            $config.Exists = $true

            # Determine type from filename
            $config.Type = Get-ISOTypeFromFileName -FileName $ISOFile.Name
        }

        # Get file details if exists
        if ($ISOFile) {
            $config.Size = $ISOFile.Length
            $config.SizeGB = [Math]::Round($ISOFile.Length / 1GB, 2)
            $config.Created = $ISOFile.CreationTime
            $config.Modified = $ISOFile.LastWriteTime

            # Check for customization in filename
            if ($ISOFile.Name -match '_([^_]+)\.iso$') {
                $possibleCustomization = $matches[1]
                if ($possibleCustomization -notmatch '^\d+$' -and $possibleCustomization -ne 'x64' -and $possibleCustomization -ne 'x86') {
                    $config.IsCustomized = $true
                    $config.CustomizationProfile = $possibleCustomization
                }
            }
        }

        # Include metadata if requested
        if ($IncludeMetadata -and $config.Exists) {
            $config.Metadata = Get-ISOMetadata -Path $config.Path

            # Update version from metadata if available
            if ($config.Metadata.Version) {
                $config.Version = $config.Metadata.Version
            }
        }

        # Check for updates if requested
        if ($CheckUpdates -and $config.Type) {
            $updateInfo = Check-ISOUpdate -Type $config.Type -CurrentVersion $config.Version
            if ($updateInfo) {
                $config.UpdateAvailable = $updateInfo.UpdateAvailable
                $config.LatestVersion = $updateInfo.LatestVersion
            }
        }

        # Calculate checksum if not in metadata
        if ($config.Exists -and -not $config.Checksum) {
            try {
                # Look for checksum file first
                $checksumFile = "$($config.Path).sha256"
                if (Test-Path $checksumFile) {
                    $config.Checksum = (Get-Content $checksumFile -First 1).Split(' ')[0]
                } elseif ($config.Size -lt 1GB) {
                    # Only calculate for smaller files to avoid long delays
                    $hash = Get-FileHash -Path $config.Path -Algorithm SHA256 -ErrorAction Stop
                    $config.Checksum = $hash.Hash.Substring(0, 16) + "..."  # Truncate for display
                }
            } catch {
                Write-CustomLog -Level 'DEBUG' -Message "Could not calculate checksum: $_"
            }
        }

        # Determine readiness
        $config.Ready = $config.Exists -and $config.Size -gt 100MB

        return [PSCustomObject]$config

    } catch {
        Write-CustomLog -Level 'WARN' -Message "Error processing ISO configuration: $($_.Exception.Message)"
        return $null
    }
}

function Get-ISOTypeFromFileName {
    param([string]$FileName)

    $type = switch -Regex ($FileName) {
        'Server.*2025' { 'WindowsServer2025' }
        'Server.*2022' { 'WindowsServer2022' }
        'Server.*2019' { 'WindowsServer2019' }
        'Server.*2016' { 'WindowsServer2016' }
        'Windows.*11' { 'Windows11' }
        'Windows.*10' { 'Windows10' }
        'Win11' { 'Windows11' }
        'Win10' { 'Windows10' }
        'Ubuntu' { 'Ubuntu' }
        'CentOS' { 'CentOS' }
        'RHEL|RedHat' { 'RHEL' }
        'Debian' { 'Debian' }
        default { 'Unknown' }
    }

    return $type
}

function Get-ISOMetadata {
    param([string]$Path)

    $metadata = @{
        FileName = [System.IO.Path]::GetFileName($Path)
        Directory = [System.IO.Path]::GetDirectoryName($Path)
    }

    try {
        # Use ISOManager if available
        if ($script:hasISOManager) {
            $isoInfo = Get-ISOInventory -Path $Path -ErrorAction SilentlyContinue
            if ($isoInfo) {
                $metadata.Version = $isoInfo.Version
                $metadata.Architecture = $isoInfo.Architecture
                $metadata.Language = $isoInfo.Language
                $metadata.Edition = $isoInfo.Edition
            }
        }

        # Check for metadata files
        $metadataFile = "$Path.metadata"
        if (Test-Path $metadataFile) {
            $fileMetadata = Get-Content $metadataFile | ConvertFrom-Json
            foreach ($prop in $fileMetadata.PSObject.Properties) {
                $metadata[$prop.Name] = $prop.Value
            }
        }

        # Try to extract info from filename if not available
        if (-not $metadata.Version -and $Path -match '(\d{5}\.\d+)') {
            $metadata.Version = $matches[1]
        }

        if (-not $metadata.Architecture) {
            if ($Path -match 'x64|amd64') {
                $metadata.Architecture = 'x64'
            } elseif ($Path -match 'x86|i386') {
                $metadata.Architecture = 'x86'
            } elseif ($Path -match 'arm64') {
                $metadata.Architecture = 'arm64'
            }
        }

    } catch {
        Write-CustomLog -Level 'DEBUG' -Message "Could not get ISO metadata: $_"
    }

    return $metadata
}

function Check-ISOUpdate {
    param(
        [string]$Type,
        [string]$CurrentVersion
    )

    # This would normally check online sources or update catalog
    # For now, return mock data for demonstration

    $updateInfo = @{
        UpdateAvailable = $false
        LatestVersion = $CurrentVersion
        DownloadUrl = $null
    }

    # Simulate update check based on type
    $latestVersions = @{
        'WindowsServer2025' = '26100.1742'
        'WindowsServer2022' = '20348.2849'
        'WindowsServer2019' = '17763.6414'
        'Windows11' = '23H2.3737'
        'Windows10' = '22H2.3693'
    }

    if ($latestVersions.ContainsKey($Type)) {
        $latest = $latestVersions[$Type]

        if ($CurrentVersion -and $CurrentVersion -ne $latest) {
            # Simple version comparison
            try {
                $current = [version]($CurrentVersion -replace '[^\d.]', '')
                $new = [version]($latest -replace '[^\d.]', '')

                if ($new -gt $current) {
                    $updateInfo.UpdateAvailable = $true
                    $updateInfo.LatestVersion = $latest
                }
            } catch {
                # If version parsing fails, just check if different
                if ($CurrentVersion -ne $latest) {
                    $updateInfo.UpdateAvailable = $true
                    $updateInfo.LatestVersion = $latest
                }
            }
        }
    }

    return $updateInfo
}

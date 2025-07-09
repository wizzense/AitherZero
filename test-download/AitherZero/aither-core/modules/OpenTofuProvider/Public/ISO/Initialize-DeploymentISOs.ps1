function Initialize-DeploymentISOs {
    <#
    .SYNOPSIS
        Initializes ISO requirements for deployment.

    .DESCRIPTION
        Analyzes deployment configuration to determine ISO requirements,
        checks existing inventory, and prepares for deployment.

    .PARAMETER DeploymentConfig
        Path to deployment configuration or config object.

    .PARAMETER ISORepository
        Path to ISO repository (default: from config).

    .PARAMETER UpdateCheck
        Check for newer ISO versions.

    .PARAMETER Interactive
        Prompt for ISO selection when multiple options exist.

    .PARAMETER SkipExistingCheck
        Skip checking for existing ISOs.

    .EXAMPLE
        Initialize-DeploymentISOs -DeploymentConfig ".\deploy-config.yaml" -UpdateCheck

    .OUTPUTS
        ISO preparation status object
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$DeploymentConfig,

        [Parameter()]
        [string]$ISORepository,

        [Parameter()]
        [switch]$UpdateCheck,

        [Parameter()]
        [switch]$Interactive,

        [Parameter()]
        [switch]$SkipExistingCheck
    )

    begin {
        Write-CustomLog -Level 'INFO' -Message "Initializing deployment ISO requirements"

        # Import ISOManager module if available
        try {
            Import-Module (Join-Path $env:PWSH_MODULES_PATH "ISOManager") -Force -ErrorAction Stop
            $script:isoManagerAvailable = $true
        } catch {
            Write-CustomLog -Level 'WARN' -Message "ISOManager module not available - using basic ISO handling"
            $script:isoManagerAvailable = $false
        }
    }

    process {
        try {
            # Load deployment configuration if path provided
            if ($DeploymentConfig -is [string]) {
                if (-not (Test-Path $DeploymentConfig)) {
                    throw "Deployment configuration not found: $DeploymentConfig"
                }

                # Use Read-DeploymentConfiguration if available
                if (Get-Command -Name 'Read-DeploymentConfiguration' -ErrorAction SilentlyContinue) {
                    $config = Read-DeploymentConfiguration -Path $DeploymentConfig
                } else {
                    # Fallback to basic JSON parsing
                    $config = Get-Content $DeploymentConfig | ConvertFrom-Json
                }
            } else {
                $config = $DeploymentConfig
            }

            # Initialize result object
            $result = @{
                Success = $true
                ConfigPath = if ($DeploymentConfig -is [string]) { $DeploymentConfig } else { "Object" }
                Requirements = @()
                ExistingISOs = @()
                MissingISOs = @()
                UpdatesAvailable = @()
                TotalSizeRequired = 0
                ISORepository = $ISORepository
                Timestamp = Get-Date
            }

            # Determine ISO repository path
            if (-not $ISORepository) {
                if ($config.iso_repository) {
                    $ISORepository = $config.iso_repository
                } else {
                    # Default repository path
                    $ISORepository = Join-Path $env:PROJECT_ROOT "iso-repository"
                }
            }

            $result.ISORepository = $ISORepository

            # Ensure ISO repository exists
            if (-not (Test-Path $ISORepository)) {
                Write-CustomLog -Level 'INFO' -Message "Creating ISO repository at: $ISORepository"
                New-Item -Path $ISORepository -ItemType Directory -Force | Out-Null
            }

            # Check if configuration has ISO requirements
            if (-not $config.iso_requirements -or $config.iso_requirements.Count -eq 0) {
                Write-CustomLog -Level 'INFO' -Message "No ISO requirements found in deployment configuration"
                return $result
            }

            Write-CustomLog -Level 'INFO' -Message "Processing $($config.iso_requirements.Count) ISO requirement(s)"

            # Process each ISO requirement
            foreach ($isoReq in $config.iso_requirements) {
                $requirement = Process-ISORequirement -Requirement $isoReq -Repository $ISORepository -UpdateCheck:$UpdateCheck
                $result.Requirements += $requirement

                if ($requirement.Exists -and -not $SkipExistingCheck) {
                    $result.ExistingISOs += $requirement
                    Write-CustomLog -Level 'INFO' -Message "ISO exists: $($requirement.Name) at $($requirement.Path)"
                } else {
                    $result.MissingISOs += $requirement
                    $result.TotalSizeRequired += $requirement.EstimatedSize
                    Write-CustomLog -Level 'WARN' -Message "ISO missing: $($requirement.Name)"
                }

                if ($requirement.UpdateAvailable) {
                    $result.UpdatesAvailable += $requirement
                    Write-CustomLog -Level 'INFO' -Message "Update available for: $($requirement.Name) ($($requirement.CurrentVersion) -> $($requirement.AvailableVersion))"
                }
            }

            # Interactive mode handling
            if ($Interactive -and $result.MissingISOs.Count -gt 0) {
                Write-Host "`nMissing ISOs detected. Would you like to:" -ForegroundColor Yellow
                Write-Host "1. Download missing ISOs automatically"
                Write-Host "2. Specify custom ISO paths"
                Write-Host "3. Continue without ISOs (deployment may fail)"

                $choice = Read-Host "Select option (1-3)"

                switch ($choice) {
                    "1" {
                        $result.UserAction = "DownloadMissing"
                    }
                    "2" {
                        $result.UserAction = "CustomPaths"
                        $result.CustomPaths = @{}
                        foreach ($missing in $result.MissingISOs) {
                            $customPath = Read-Host "Enter path for $($missing.Name)"
                            if ($customPath -and (Test-Path $customPath)) {
                                $result.CustomPaths[$missing.Name] = $customPath
                            }
                        }
                    }
                    "3" {
                        $result.UserAction = "Continue"
                        Write-CustomLog -Level 'WARN' -Message "User chose to continue without missing ISOs"
                    }
                }
            }

            # Calculate summary
            $result.Summary = @{
                TotalRequired = $result.Requirements.Count
                Existing = $result.ExistingISOs.Count
                Missing = $result.MissingISOs.Count
                UpdatesAvailable = $result.UpdatesAvailable.Count
                EstimatedDownloadSize = "$([Math]::Round($result.TotalSizeRequired / 1GB, 2)) GB"
                Ready = ($result.MissingISOs.Count -eq 0)
            }

            # Log summary
            Write-CustomLog -Level 'INFO' -Message "ISO initialization complete: $($result.Summary.Existing)/$($result.Summary.TotalRequired) available"

            if ($result.Summary.Missing -gt 0) {
                Write-CustomLog -Level 'WARN' -Message "$($result.Summary.Missing) ISO(s) missing, estimated download: $($result.Summary.EstimatedDownloadSize)"
            }

            return [PSCustomObject]$result

        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Failed to initialize deployment ISOs: $($_.Exception.Message)"
            throw
        }
    }
}

function Process-ISORequirement {
    param(
        [object]$Requirement,
        [string]$Repository,
        [switch]$UpdateCheck
    )

    $processed = @{
        Name = $Requirement.name
        Type = if ($Requirement.type) { $Requirement.type } else { $Requirement.name }
        Customization = $Requirement.customization
        Cache = if ($null -ne $Requirement.cache) { $Requirement.cache } else { $true }
        Exists = $false
        Path = $null
        CurrentVersion = $null
        UpdateAvailable = $false
        AvailableVersion = $null
        EstimatedSize = 5GB  # Default estimate
    }

    # Determine expected ISO filename
    $isoFileName = Get-ExpectedISOFileName -Name $processed.Type -Customization $processed.Customization
    $isoPath = Join-Path $Repository $isoFileName

    # Check if ISO exists
    if (Test-Path $isoPath) {
        $processed.Exists = $true
        $processed.Path = $isoPath

        # Get ISO info if ISOManager available
        if ($script:isoManagerAvailable -and (Get-Command -Name 'Get-ISOInventory' -ErrorAction SilentlyContinue)) {
            try {
                $isoInfo = Get-ISOInventory -Path $isoPath
                if ($isoInfo) {
                    $processed.CurrentVersion = $isoInfo.Version
                    $processed.Size = $isoInfo.Size
                }
            } catch {
                Write-CustomLog -Level 'DEBUG' -Message "Could not get ISO info: $_"
            }
        } else {
            # Get basic file info
            $fileInfo = Get-Item $isoPath
            $processed.Size = $fileInfo.Length
        }
    }

    # Check for updates if requested
    if ($UpdateCheck -and $processed.Exists) {
        if ($script:isoManagerAvailable -and (Get-Command -Name 'Test-ISOUpdate' -ErrorAction SilentlyContinue)) {
            try {
                $updateInfo = Test-ISOUpdate -Name $processed.Name
                if ($updateInfo.UpdateAvailable) {
                    $processed.UpdateAvailable = $true
                    $processed.AvailableVersion = $updateInfo.LatestVersion
                }
            } catch {
                Write-CustomLog -Level 'DEBUG' -Message "Could not check for ISO updates: $_"
            }
        }
    }

    # Set estimated size based on ISO type
    if (-not $processed.Exists) {
        $processed.EstimatedSize = switch -Regex ($processed.Type) {
            'WindowsServer2025' { 5GB }
            'WindowsServer2022' { 5GB }
            'WindowsServer2019' { 4.5GB }
            'Windows11' { 5.5GB }
            'Windows10' { 4GB }
            'Ubuntu' { 3GB }
            'CentOS|RHEL' { 9GB }
            default { 5GB }
        }
    }

    return $processed
}

function Get-ExpectedISOFileName {
    param(
        [string]$Name,
        [string]$Customization
    )

    # Generate expected ISO filename
    $baseFileName = switch -Regex ($Name) {
        'WindowsServer2025' { 'WindowsServer2025_x64' }
        'WindowsServer2022' { 'WindowsServer2022_x64' }
        'WindowsServer2019' { 'WindowsServer2019_x64' }
        'Windows11' { 'Windows11_x64' }
        'Windows10' { 'Windows10_x64' }
        default { $Name }
    }

    if ($Customization) {
        return "${baseFileName}_${Customization}.iso"
    } else {
        return "${baseFileName}.iso"
    }
}

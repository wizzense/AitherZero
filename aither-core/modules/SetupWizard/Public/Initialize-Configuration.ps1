function Initialize-Configuration {
    <#
    .SYNOPSIS
        Initialize configuration files for AitherZero
    .DESCRIPTION
        Creates and configures initial configuration files and directories
    .PARAMETER SetupState
        Setup state object
    .EXAMPLE
        $result = Initialize-Configuration -SetupState $setupState
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$SetupState
    )

    $result = @{
        Name = 'Configuration Files'
        Status = 'Unknown'
        Details = @()
    }

    try {
        # Try to use ConfigurationCore first
        $configCoreModule = Join-Path (Find-ProjectRoot) "aither-core/modules/ConfigurationCore"
        $usingConfigCore = $false
        
        if (Test-Path $configCoreModule) {
            try {
                Import-Module $configCoreModule -Force -ErrorAction Stop
                $usingConfigCore = $true
                $result.Details += "✓ Loaded ConfigurationCore module"

                # Initialize ConfigurationCore
                if (Get-Command Initialize-ConfigurationCore -ErrorAction SilentlyContinue) {
                    Initialize-ConfigurationCore
                }

                # Register SetupWizard module configuration
                if (Get-Command Register-ModuleConfiguration -ErrorAction SilentlyContinue) {
                    Register-ModuleConfiguration -ModuleName 'SetupWizard' -Schema @{
                        Platform = @{ Type = 'string'; Required = $true }
                        InstallationProfile = @{ Type = 'string'; Required = $true }
                        Settings = @{
                            Type = 'object'
                            Properties = @{
                                Verbosity = @{ Type = 'string'; Default = 'normal' }
                                AutoUpdate = @{ Type = 'boolean'; Default = $true }
                                TelemetryEnabled = @{ Type = 'boolean'; Default = $false }
                                MaxParallelJobs = @{ Type = 'integer'; Default = 4 }
                            }
                        }
                        Modules = @{
                            Type = 'object'
                            Properties = @{
                                EnabledByDefault = @{ Type = 'array'; Default = @('Logging', 'PatchManager', 'LabRunner') }
                                AutoLoad = @{ Type = 'boolean'; Default = $true }
                            }
                        }
                    }

                    # Set initial configuration
                    $initialConfig = @{
                        Platform = $SetupState.Platform.OS
                        InstallationProfile = $SetupState.InstallationProfile
                        Settings = @{
                            Verbosity = 'normal'
                            AutoUpdate = $true
                            TelemetryEnabled = $false
                            MaxParallelJobs = 4
                        }
                        Modules = @{
                            EnabledByDefault = @('Logging', 'PatchManager', 'LabRunner')
                            AutoLoad = $true
                        }
                    }

                    Set-ModuleConfiguration -ModuleName 'SetupWizard' -Configuration $initialConfig
                    $result.Details += "✓ Initialized SetupWizard configuration with ConfigurationCore"
                }

            } catch {
                Write-Verbose "ConfigurationCore not available, using legacy method: $_"
                $usingConfigCore = $false
            }
        }

        if (-not $usingConfigCore) {
            # Fallback to legacy configuration method
            $result.Details += "⚠️ ConfigurationCore not found, using legacy configuration"

            # Determine config directory
            $configDir = if ($SetupState.Platform.OS -eq 'Windows') {
                Join-Path $env:APPDATA "AitherZero"
            } else {
                Join-Path $env:HOME ".config/aitherzero"
            }

            # Create config directory if needed
            if (-not (Test-Path $configDir)) {
                New-Item -Path $configDir -ItemType Directory -Force | Out-Null
                $result.Details += "✓ Created configuration directory: $configDir"
            }

            # Create default configuration
            $defaultConfig = @{
                Version = '1.0'
                Platform = $SetupState.Platform.OS
                CreatedAt = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
                Settings = @{
                    Verbosity = 'normal'
                    AutoUpdate = $true
                    TelemetryEnabled = $false
                    MaxParallelJobs = 4
                }
                Modules = @{
                    EnabledByDefault = @('Logging', 'PatchManager', 'LabRunner')
                    AutoLoad = $true
                }
            }

            $configFile = Join-Path $configDir "config.json"
            if (-not (Test-Path $configFile)) {
                $defaultConfig | ConvertTo-Json -Depth 5 | Set-Content -Path $configFile
                $result.Details += "✓ Created legacy configuration file"
            }
        }

        $result.Status = 'Passed'

    } catch {
        $result.Status = 'Warning'
        $result.Details += "⚠️ Configuration initialization had issues: $_"
        $result.Details += "✓ Setup can continue, configuration can be set up later"
    }

    return $result
}

Export-ModuleMember -Function Initialize-Configuration
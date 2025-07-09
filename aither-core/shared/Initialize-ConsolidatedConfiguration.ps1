#Requires -Version 7.0

<#
.SYNOPSIS
    Initialize the consolidated configuration system for AitherZero
.DESCRIPTION
    This function provides backward compatibility while implementing the new consolidated configuration system
.PARAMETER ConfigFile
    Legacy configuration file parameter (maintained for compatibility)
.PARAMETER Environment
    Environment name (dev, staging, prod)
.PARAMETER Profile
    Configuration profile (minimal, developer, enterprise, full)
.PARAMETER AutoMigrate
    Automatically migrate legacy configurations if found
.EXAMPLE
    $config = Initialize-ConsolidatedConfiguration -ConfigFile "custom-config.json"
.EXAMPLE
    $config = Initialize-ConsolidatedConfiguration -Environment "dev" -Profile "developer"
#>

# Import shared Find-ProjectRoot utility
. "$PSScriptRoot/Find-ProjectRoot.ps1"

function Initialize-ConsolidatedConfiguration {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$ConfigFile,

        [Parameter()]
        [ValidateSet('dev', 'staging', 'prod')]
        [string]$Environment = 'dev',

        [Parameter()]
        [ValidateSet('minimal', 'developer', 'enterprise', 'full', '')]
        [string]$Profile = '',

        [Parameter()]
        [switch]$AutoMigrate = $true
    )

    # Find project root
    $projectRoot = $env:PROJECT_ROOT
    if (-not $projectRoot) {
        $projectRoot = Find-ProjectRoot -StartPath $PSScriptRoot
    }

    Write-Verbose "Initializing consolidated configuration system"
    Write-Verbose "  Project Root: $projectRoot"
    Write-Verbose "  Environment: $Environment"
    Write-Verbose "  Profile: $Profile"
    Write-Verbose "  Auto Migrate: $AutoMigrate"

    try {
        # Check if legacy migration is needed
        if ($AutoMigrate) {
            $migrationResult = Test-LegacyConfigurationMigration -ProjectRoot $projectRoot -ConfigFile $ConfigFile

            if ($migrationResult.MigrationNeeded) {
                Write-Host "🔄 Legacy configurations detected - performing automatic migration..." -ForegroundColor Yellow

                # Load migration script
                $migrationScript = Join-Path $PSScriptRoot "Invoke-ConfigurationMigration.ps1"
                . $migrationScript

                # Perform migration
                $migration = Invoke-ConfigurationMigration -ProjectRoot $projectRoot -BackupLegacy:$true

                if ($migration.Success) {
                    Write-Host "✅ Configuration migration completed successfully" -ForegroundColor Green
                } else {
                    Write-Warning "Configuration migration had issues: $($migration.Message)"
                }
            }
        }

        # Load consolidated configuration script
        $configScript = Join-Path $PSScriptRoot "Get-ConsolidatedConfiguration.ps1"
        . $configScript

        # Load the consolidated configuration
        $consolidatedConfig = Get-ConsolidatedConfiguration -ConfigPath $ConfigFile -Environment $Environment -Profile $Profile -ValidateSchema

        # Convert to legacy-compatible format for backward compatibility
        $legacyConfig = Convert-ConsolidatedToLegacy -ConsolidatedConfig $consolidatedConfig

        Write-Verbose "Configuration successfully initialized with consolidated system"

        return @{
            # New consolidated format
            Consolidated = $consolidatedConfig
            # Legacy compatible format
            Legacy = $legacyConfig
            # Metadata about the configuration system
            Metadata = @{
                System = "Consolidated"
                Version = "1.0"
                Environment = $Environment
                Profile = $Profile
                LoadedAt = Get-Date
                ProjectRoot = $projectRoot
            }
        }

    } catch {
        Write-Warning "Failed to initialize consolidated configuration: $($_.Exception.Message)"
        Write-Verbose "Falling back to legacy configuration loading"

        # Fallback to legacy configuration loading
        return Initialize-LegacyConfigurationFallback -ConfigFile $ConfigFile -ProjectRoot $projectRoot
    }
}

function Test-LegacyConfigurationMigration {
    [CmdletBinding()]
    param(
        [string]$ProjectRoot,
        [string]$ConfigFile
    )

    $migrationNeeded = $false
    $reasons = @()

    # Check for legacy core configurations
    $legacyCoreConfig = Join-Path $ProjectRoot "aither-core" "default-config.json"
    if (Test-Path $legacyCoreConfig) {
        $migrationNeeded = $true
        $reasons += "Legacy core configuration found"
    }

    # Check for legacy core configs directory
    $legacyCoreConfigsDir = Join-Path $ProjectRoot "aither-core" "configs" "default-config.json"
    if (Test-Path $legacyCoreConfigsDir) {
        $migrationNeeded = $true
        $reasons += "Legacy core configs directory found"
    }

    # Check if main config needs structure update
    $mainConfig = Join-Path $ProjectRoot "configs" "default-config.json"
    if (Test-Path $mainConfig) {
        try {
            $content = Get-Content $mainConfig -Raw | ConvertFrom-Json

            # Check for flat structure (legacy format)
            if ($content.PSObject.Properties.Name -contains "ComputerName" -and
                -not ($content.PSObject.Properties.Name -contains "system")) {
                $migrationNeeded = $true
                $reasons += "Main configuration needs structure update"
            }
        } catch {
            Write-Verbose "Could not analyze main configuration structure: $_"
        }
    }

    return @{
        MigrationNeeded = $migrationNeeded
        Reasons = $reasons
    }
}

function Convert-ConsolidatedToLegacy {
    [CmdletBinding()]
    param(
        [hashtable]$ConsolidatedConfig
    )

    # Create a flat legacy configuration for backward compatibility
    $legacyConfig = @{}

    # Flatten the hierarchical structure to legacy format
    foreach ($section in $ConsolidatedConfig.Keys) {
        if ($section -eq '_metadata') {
            continue
        }

        $sectionData = $ConsolidatedConfig[$section]

        if ($sectionData -is [hashtable]) {
            foreach ($key in $sectionData.Keys) {
                $legacyConfig[$key] = $sectionData[$key]
            }
        } else {
            $legacyConfig[$section] = $sectionData
        }
    }

    # Add legacy-specific mappings
    if ($ConsolidatedConfig.ContainsKey('certificates')) {
        $legacyConfig['CertificateAuthority'] = $ConsolidatedConfig.certificates
    }

    if ($ConsolidatedConfig.ContainsKey('ui')) {
        $legacyConfig['UIPreferences'] = $ConsolidatedConfig.ui
    }

    return $legacyConfig
}

function Initialize-LegacyConfigurationFallback {
    [CmdletBinding()]
    param(
        [string]$ConfigFile,
        [string]$ProjectRoot
    )

    Write-Verbose "Using legacy configuration fallback"

    # Legacy configuration search paths
    $configPaths = @(
        $ConfigFile,
        (Join-Path $ProjectRoot "configs" "default-config.json"),
        (Join-Path $ProjectRoot "aither-core" "default-config.json"),
        (Join-Path $PSScriptRoot ".." "default-config.json")
    ) | Where-Object { $_ -and (Test-Path $_) }

    if ($configPaths.Count -eq 0) {
        throw "No configuration file found in legacy fallback mode"
    }

    $configPath = $configPaths[0]
    Write-Verbose "Loading legacy configuration from: $configPath"

    try {
        $configContent = Get-Content $configPath -Raw | ConvertFrom-Json

        # Convert to hashtable for compatibility
        $legacyConfig = @{}
        $configContent.PSObject.Properties | ForEach-Object {
            $legacyConfig[$_.Name] = $_.Value
        }

        return @{
            Legacy = $legacyConfig
            Consolidated = $null
            Metadata = @{
                System = "Legacy Fallback"
                Version = "0.7.x"
                ConfigPath = $configPath
                LoadedAt = Get-Date
                ProjectRoot = $ProjectRoot
            }
        }

    } catch {
        throw "Failed to load legacy configuration: $($_.Exception.Message)"
    }
}

# Find-ProjectRoot function is now imported from shared utility

# Function to update the main core script to use the new configuration system
function Update-CoreScriptConfiguration {
    [CmdletBinding()]
    param(
        [string]$CoreScriptPath,
        [switch]$DryRun
    )

    if (-not (Test-Path $CoreScriptPath)) {
        throw "Core script not found: $CoreScriptPath"
    }

    Write-Host "🔧 Updating core script to use consolidated configuration system..." -ForegroundColor Cyan

    if ($DryRun) {
        Write-Host "🔍 DRY RUN - Would update configuration loading in: $CoreScriptPath" -ForegroundColor Yellow
        return @{ Success = $true; DryRun = $true }
    }

    # Backup original
    $backupPath = "$CoreScriptPath.config-backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    Copy-Item $CoreScriptPath $backupPath

    # Read current content
    $content = Get-Content $CoreScriptPath -Raw

    # Replace legacy configuration loading with new system
    $newConfigLoadingCode = @"
# Load consolidated configuration system
`$consolidatedConfigScript = Join-Path `$PSScriptRoot 'shared' 'Initialize-ConsolidatedConfiguration.ps1'
if (Test-Path `$consolidatedConfigScript) {
    . `$consolidatedConfigScript
    `$configResult = Initialize-ConsolidatedConfiguration -ConfigFile `$ConfigFile -Environment 'dev' -Profile `$Profile -AutoMigrate
    `$config = `$configResult.Legacy  # Use legacy format for backward compatibility
    Write-CustomLog "Configuration loaded using consolidated system (v`$(`$configResult.Metadata.Version))" -Level DEBUG
} else {
    # Fallback to legacy loading if consolidated system not available
    if (Test-Path `$ConfigFile) {
        Write-CustomLog "Loading configuration from: `$ConfigFile" -Level DEBUG
        `$configObject = Get-Content `$ConfigFile -Raw | ConvertFrom-Json

        if (`$configObject -is [PSCustomObject]) {
            `$config = @{}
            `$configObject.PSObject.Properties | ForEach-Object {
                `$config[`$_.Name] = `$_.Value
            }
            Write-CustomLog "Configuration converted from PSCustomObject to Hashtable" -Level DEBUG
        } else {
            `$config = `$configObject
        }
    } else {
        Write-CustomLog "Configuration file not found: `$ConfigFile" -Level WARN
        Write-CustomLog 'Using default configuration' -Level DEBUG
        `$config = @{}
    }
}
"@

    # Replace the legacy configuration loading block
    $legacyConfigPattern = '# Load configuration\s*try\s*\{.*?\} catch \{.*?exit 1\s*\}'
    $updatedContent = $content -replace $legacyConfigPattern, $newConfigLoadingCode

    # Write updated content
    Set-Content $CoreScriptPath -Value $updatedContent -Encoding UTF8

    Write-Host "✅ Core script updated successfully" -ForegroundColor Green
    Write-Host "📦 Backup created at: $backupPath" -ForegroundColor Gray

    return @{
        Success = $true
        BackupPath = $backupPath
        UpdatedScript = $CoreScriptPath
    }
}

# Main function for easy access
function Initialize-AitherZeroConfiguration {
    [CmdletBinding()]
    param(
        [string]$ConfigFile,
        [string]$Environment = 'dev',
        [ValidateSet('minimal', 'developer', 'enterprise', 'full', '')]
        [string]$Profile = '',
        [switch]$AutoMigrate = $true,
        [switch]$UpdateCoreScript
    )

    $result = Initialize-ConsolidatedConfiguration -ConfigFile $ConfigFile -Environment $Environment -Profile $Profile -AutoMigrate:$AutoMigrate

    if ($UpdateCoreScript) {
        $coreScriptPath = Join-Path (Find-ProjectRoot) "aither-core" "aither-core.ps1"
        if (Test-Path $coreScriptPath) {
            $updateResult = Update-CoreScriptConfiguration -CoreScriptPath $coreScriptPath
            $result.CoreScriptUpdate = $updateResult
        }
    }

    return $result
}

# Configuration Functions - Consolidated into AitherCore Configuration Domain
# Unified configuration management including Core, Carousel, Manager, and Repository

#Requires -Version 7.0

using namespace System.IO
using namespace System.Security
using namespace System.Text.Json

# MODULE CONSTANTS AND VARIABLES

$script:MODULE_VERSION = '1.0.0'
$script:CONFIG_FILE_VERSION = '1.0'
$script:MAX_BACKUP_COUNT = 10
$script:CONFIG_FILE_PERMISSIONS = if ($IsWindows) { 'Owner' } else { '600' }

# Enhanced configuration store with metadata and security
$script:ConfigurationStore = @{
    Metadata = @{
        Version = $script:CONFIG_FILE_VERSION
        LastModified = Get-Date
        CreatedBy = $env:USERNAME
        Platform = if ($IsWindows) { 'Windows' } elseif ($IsLinux) { 'Linux' } else { 'macOS' }
        PSVersion = $PSVersionTable.PSVersion.ToString()
    }
    Modules = @{}
    Environments = @{
        'default' = @{
            Name = 'default'
            Description = 'Default configuration environment'
            Settings = @{}
            Created = Get-Date
            CreatedBy = $env:USERNAME
        }
    }
    CurrentEnvironment = 'default'
    Schemas = @{}
    HotReload = @{
        Enabled = $false
        Watchers = @{}
        LastReload = $null
    }
    Security = @{
        EncryptionEnabled = $false
        HashValidation = $true
        LastSecurityCheck = Get-Date
    }
    StorePath = $null
}

# Configuration paths
$script:ConfigCarouselPath = Join-Path $env:PROJECT_ROOT "configs/carousel"
$script:ConfigBackupPath = Join-Path $env:PROJECT_ROOT "configs/backups"
$script:ConfigEnvironmentsPath = Join-Path $env:PROJECT_ROOT "configs/environments"

# Unified configuration store
$script:UnifiedConfigurationStore = @{}

# Event system
$script:ConfigurationEventSubscriptions = @()
$script:ConfigurationEventHistory = @()

# Configuration watchers
$script:ConfigurationWatchers = @{}

# SECURITY AND VALIDATION FUNCTIONS

function Test-ConfigurationSecurity {
    <#
    .SYNOPSIS
        Tests configuration for security issues
    .DESCRIPTION
        Scans configuration for potentially sensitive data in plain text
    .PARAMETER Configuration
        Configuration hashtable to test
    #>
    param([hashtable]$Configuration)

    $securityIssues = @()

    # Check for potentially sensitive data in plain text
    $sensitivePatterns = @(
        '(?i)(password|pwd|secret|key|token|credential)',
        '(?i)(api[_-]?key|access[_-]?token)',
        '(?i)(connection[_-]?string)',
        '(?i)(private[_-]?key|certificate)'
    )

    function Test-HashtableForSensitiveData {
        param([hashtable]$Data, [string]$Path = '')

        foreach ($key in $Data.Keys) {
            $currentPath = if ($Path) { "$Path.$key" } else { $key }
            $value = $Data[$key]

            if ($value -is [hashtable]) {
                Test-HashtableForSensitiveData -Data $value -Path $currentPath
            } elseif ($value -is [string]) {
                foreach ($pattern in $sensitivePatterns) {
                    if ($key -match $pattern -or $value -match $pattern) {
                        $script:securityIssues += "Potentially sensitive data found at: $currentPath"
                    }
                }
            }
        }
    }

    Test-HashtableForSensitiveData -Data $Configuration
    return $securityIssues
}

function Get-ConfigurationHash {
    <#
    .SYNOPSIS
        Generates hash for configuration integrity validation
    .PARAMETER Configuration
        Configuration hashtable to hash
    #>
    param([hashtable]$Configuration)

    try {
        $json = $Configuration | ConvertTo-Json -Depth 20 -Compress
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
        $hashAlgorithm = [System.Security.Cryptography.SHA256]::Create()
        $hashBytes = $hashAlgorithm.ComputeHash($bytes)
        return [System.Convert]::ToBase64String($hashBytes)
    } catch {
        Write-CustomLog -Level 'WARNING' -Message "Failed to compute configuration hash: $_"
        return $null
    } finally {
        if ($hashAlgorithm) {
            $hashAlgorithm.Dispose()
        }
    }
}

function Validate-Configuration {
    <#
    .SYNOPSIS
        Validates configuration structure and content
    .PARAMETER Configuration
        Configuration to validate
    .PARAMETER Schema
        Optional schema to validate against
    #>
    param(
        [hashtable]$Configuration,
        [hashtable]$Schema = @{}
    )

    $validationResult = @{
        IsValid = $true
        Errors = @()
        Warnings = @()
    }

    try {
        # Basic structure validation
        if (-not $Configuration) {
            $validationResult.IsValid = $false
            $validationResult.Errors += "Configuration is null or empty"
            return $validationResult
        }

        # Security validation
        $securityIssues = Test-ConfigurationSecurity -Configuration $Configuration
        if ($securityIssues.Count -gt 0) {
            $validationResult.Warnings += $securityIssues
        }

        # Schema validation if provided
        if ($Schema.Count -gt 0) {
            $schemaValidation = Test-ConfigurationSchema -Configuration $Configuration -Schema $Schema
            if (-not $schemaValidation.IsValid) {
                $validationResult.IsValid = $false
                $validationResult.Errors += $schemaValidation.Errors
            }
        }

        return $validationResult

    } catch {
        $validationResult.IsValid = $false
        $validationResult.Errors += "Validation error: $($_.Exception.Message)"
        return $validationResult
    }
}

function Test-ConfigurationSchema {
    <#
    .SYNOPSIS
        Tests configuration against a schema
    .PARAMETER Configuration
        Configuration to test
    .PARAMETER Schema
        Schema to test against
    #>
    param(
        [hashtable]$Configuration,
        [hashtable]$Schema
    )

    $result = @{
        IsValid = $true
        Errors = @()
    }

    try {
        # Basic schema validation implementation
        foreach ($key in $Schema.Keys) {
            $schemaRule = $Schema[$key]
            
            if ($schemaRule.Required -and -not $Configuration.ContainsKey($key)) {
                $result.IsValid = $false
                $result.Errors += "Required key '$key' is missing"
                continue
            }

            if ($Configuration.ContainsKey($key)) {
                $value = $Configuration[$key]
                
                if ($schemaRule.Type -and $value -isnot $schemaRule.Type) {
                    $result.IsValid = $false
                    $result.Errors += "Key '$key' has incorrect type. Expected: $($schemaRule.Type), Got: $($value.GetType())"
                }

                if ($schemaRule.Pattern -and $value -is [string] -and $value -notmatch $schemaRule.Pattern) {
                    $result.IsValid = $false
                    $result.Errors += "Key '$key' does not match required pattern: $($schemaRule.Pattern)"
                }

                if ($schemaRule.MinLength -and $value.Length -lt $schemaRule.MinLength) {
                    $result.IsValid = $false
                    $result.Errors += "Key '$key' is too short. Minimum length: $($schemaRule.MinLength)"
                }

                if ($schemaRule.MaxLength -and $value.Length -gt $schemaRule.MaxLength) {
                    $result.IsValid = $false
                    $result.Errors += "Key '$key' is too long. Maximum length: $($schemaRule.MaxLength)"
                }
            }
        }

        return $result

    } catch {
        return @{
            IsValid = $false
            Errors = @("Schema validation error: $($_.Exception.Message)")
        }
    }
}

# CONFIGURATION STORAGE AND PERSISTENCE

function Initialize-ConfigurationStorePath {
    <#
    .SYNOPSIS
        Initializes configuration storage path with proper permissions
    #>
    try {
        # Platform-specific configuration paths with security considerations
        if ($IsWindows) {
            $configDir = Join-Path $env:APPDATA 'AitherZero'
        } elseif ($IsLinux -or $IsMacOS) {
            $configDir = Join-Path $env:HOME '.aitherzero'
        } else {
            throw "Unsupported platform for configuration storage"
        }

        $script:ConfigurationStore.StorePath = Join-Path $configDir 'configuration.json'

        # Create directory with appropriate permissions
        if (-not (Test-Path $configDir)) {
            $directory = New-Item -ItemType Directory -Path $configDir -Force

            # Set directory permissions (Unix-like systems)
            if ($IsLinux -or $IsMacOS) {
                chmod 700 $configDir 2>/dev/null
            }
        }

        # Set up backup directory
        $backupDir = Join-Path $configDir 'backups'
        if (-not (Test-Path $backupDir)) {
            New-Item -ItemType Directory -Path $backupDir -Force | Out-Null

            if ($IsLinux -or $IsMacOS) {
                chmod 700 $backupDir 2>/dev/null
            }
        }

        Write-CustomLog -Level 'DEBUG' -Message "Configuration storage path initialized at $($script:ConfigurationStore.StorePath)"

    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to initialize storage path: $_"
        throw
    }
}

function Save-ConfigurationStore {
    <#
    .SYNOPSIS
        Saves configuration store to disk with backup
    .PARAMETER Configuration
        Configuration to save (uses script store if not provided)
    #>
    param([hashtable]$Configuration)

    try {
        if (-not $Configuration) {
            $Configuration = $script:ConfigurationStore
        }

        if (-not $Configuration.StorePath) {
            Initialize-ConfigurationStorePath
        }

        # Create backup if file exists
        if (Test-Path $Configuration.StorePath) {
            $backupPath = "$($Configuration.StorePath).backup.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
            Copy-Item $Configuration.StorePath $backupPath -Force
        }

        # Update metadata
        $Configuration.Metadata.LastModified = Get-Date
        $Configuration.Metadata.Version = $script:CONFIG_FILE_VERSION

        # Generate hash for integrity
        if ($Configuration.Security.HashValidation) {
            $Configuration.Security.LastHash = Get-ConfigurationHash -Configuration $Configuration
        }

        # Save to file
        $json = $Configuration | ConvertTo-Json -Depth 20
        $json | Set-Content $Configuration.StorePath -Encoding UTF8

        # Set file permissions
        if ($IsLinux -or $IsMacOS) {
            chmod 600 $Configuration.StorePath 2>/dev/null
        }

        Write-CustomLog -Level 'DEBUG' -Message "Configuration saved to $($Configuration.StorePath)"

        # Cleanup old backups
        Invoke-BackupCleanup

    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to save configuration: $_"
        throw
    }
}

function Import-ExistingConfiguration {
    <#
    .SYNOPSIS
        Loads existing configuration from disk with validation
    #>
    $configPath = $script:ConfigurationStore.StorePath

    if (-not (Test-Path $configPath)) {
        Write-CustomLog -Level 'DEBUG' -Message "No existing configuration found"
        return
    }

    try {
        # Read configuration file
        $configContent = Get-Content $configPath -Raw -Encoding UTF8

        if ([string]::IsNullOrWhiteSpace($configContent)) {
            Write-CustomLog -Level 'WARNING' -Message "Configuration file is empty"
            return
        }

        # Parse JSON with enhanced error handling
        try {
            $storedConfig = $configContent | ConvertFrom-Json -AsHashtable -Depth 20
        } catch [System.Text.Json.JsonException] {
            Write-CustomLog -Level 'WARNING' -Message "Invalid JSON in configuration file, creating backup and starting fresh"
            $backupPath = "$configPath.corrupt.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
            Copy-Item $configPath $backupPath
            return
        }

        if (-not $storedConfig -or $storedConfig.Count -eq 0) {
            Write-CustomLog -Level 'WARNING' -Message "Configuration file contains no data"
            return
        }

        # Validate configuration structure
        $requiredKeys = @('Modules', 'Environments', 'CurrentEnvironment')
        foreach ($key in $requiredKeys) {
            if (-not $storedConfig.ContainsKey($key)) {
                Write-CustomLog -Level 'WARNING' -Message "Missing required key '$key', migrating configuration"
                $storedConfig[$key] = $script:ConfigurationStore[$key]
            }
        }

        # Ensure default environment exists
        if (-not $storedConfig.Environments.ContainsKey('default')) {
            $storedConfig.Environments['default'] = $script:ConfigurationStore.Environments['default']
        }

        # Validate current environment
        if (-not $storedConfig.Environments.ContainsKey($storedConfig.CurrentEnvironment)) {
            Write-CustomLog -Level 'WARNING' -Message "Invalid current environment, resetting to default"
            $storedConfig.CurrentEnvironment = 'default'
        }

        # Update metadata
        if (-not $storedConfig.Metadata) {
            $storedConfig.Metadata = $script:ConfigurationStore.Metadata
        }
        $storedConfig.Metadata.LastModified = Get-Date

        # Security validation
        $securityIssues = Test-ConfigurationSecurity -Configuration $storedConfig
        if ($securityIssues.Count -gt 0) {
            Write-CustomLog -Level 'WARNING' -Message "Security issues detected in configuration:"
            foreach ($issue in $securityIssues) {
                Write-CustomLog -Level 'WARNING' -Message "  - $issue"
            }
        }

        # Apply loaded configuration
        $script:ConfigurationStore = $storedConfig
        $script:ConfigurationStore.StorePath = $configPath

        Write-CustomLog -Level 'DEBUG' -Message "Successfully loaded existing configuration"

        # Validate hash if available
        if ($storedConfig.Security -and $storedConfig.Security.HashValidation) {
            $currentHash = Get-ConfigurationHash -Configuration $storedConfig
            if ($currentHash) {
                $script:ConfigurationStore.Security.LastHash = $currentHash
            }
        }

    } catch {
        Write-CustomLog -Level 'WARNING' -Message "Failed to load existing configuration: $_"
        Write-CustomLog -Level 'WARNING' -Message "Starting with default configuration"

        # Create backup of problematic file
        if (Test-Path $configPath) {
            $backupPath = "$configPath.error.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
            try {
                Copy-Item $configPath $backupPath
                Write-CustomLog -Level 'DEBUG' -Message "Problematic configuration backed up to $backupPath"
            } catch {
                Write-CustomLog -Level 'WARNING' -Message "Failed to backup problematic configuration: $_"
            }
        }
    }
}

function Invoke-BackupCleanup {
    <#
    .SYNOPSIS
        Cleans up old backup files
    #>
    try {
        $configDir = Split-Path $script:ConfigurationStore.StorePath -Parent
        $backupDir = Join-Path $configDir 'backups'

        if (Test-Path $backupDir) {
            $backupFiles = Get-ChildItem $backupDir -Filter 'config-backup-*.json' |
                           Sort-Object LastWriteTime -Descending

            if ($backupFiles.Count -gt $script:MAX_BACKUP_COUNT) {
                $filesToRemove = $backupFiles | Select-Object -Skip $script:MAX_BACKUP_COUNT
                foreach ($file in $filesToRemove) {
                    try {
                        Remove-Item $file.FullName -Force
                        Write-CustomLog -Level 'DEBUG' -Message "Removed old backup $($file.Name)"
                    } catch {
                        Write-CustomLog -Level 'WARNING' -Message "Failed to remove old backup $($file.Name): $_"
                    }
                }
            }
        }
    } catch {
        Write-CustomLog -Level 'WARNING' -Message "Backup cleanup failed: $_"
    }
}

# CONFIGURATION CORE FUNCTIONS

function Initialize-ConfigurationCore {
    <#
    .SYNOPSIS
        Initializes the configuration core system
    .DESCRIPTION
        Sets up the configuration storage, loads existing configuration,
        and initializes the core configuration system
    #>
    [CmdletBinding()]
    param()

    try {
        Write-CustomLog -Level 'INFO' -Message "Initializing configuration core system"

        # Initialize storage path
        Initialize-ConfigurationStorePath

        # Load existing configuration
        Import-ExistingConfiguration

        # Initialize schemas
        Initialize-DefaultSchemas

        # Initialize unified store
        $script:UnifiedConfigurationStore = @{
            Metadata = @{
                Version = $script:MODULE_VERSION
                LastModified = Get-Date
                Platform = if ($IsWindows) { 'Windows' } elseif ($IsLinux) { 'Linux' } elseif ($IsMacOS) { 'macOS' } else { 'Unknown' }
                PowerShellVersion = $PSVersionTable.PSVersion.ToString()
            }
            Modules = @{}
            Environments = @{
                default = @{
                    Name = 'default'
                    Description = 'Default configuration environment'
                    Settings = @{}
                    Created = Get-Date
                    CreatedBy = $env:USERNAME
                }
            }
            CurrentEnvironment = 'default'
            Carousel = @{
                Configurations = @{}
                CurrentConfiguration = 'default'
                Registry = @{}
            }
            Repository = @{
                Templates = @{}
                DefaultProvider = 'filesystem'
                Settings = @{}
            }
            Events = @{
                Subscriptions = @()
                History = @()
            }
            Security = @{
                HashValidation = $true
                EncryptionEnabled = $false
            }
            StorePath = Join-Path ([Environment]::GetFolderPath('UserProfile')) '.aitherzero' 'unified-config.json'
        }

        Write-CustomLog -Level 'SUCCESS' -Message "Configuration core system initialized successfully"

    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to initialize configuration core: $_"
        throw
    }
}

function Initialize-DefaultSchemas {
    <#
    .SYNOPSIS
        Initializes default configuration schemas
    #>
    try {
        # Default module configuration schema
        $script:ConfigurationStore.Schemas['module'] = @{
            name = @{ Required = $true; Type = [string] }
            version = @{ Required = $true; Type = [string] }
            settings = @{ Required = $false; Type = [hashtable] }
            enabled = @{ Required = $false; Type = [bool] }
        }

        # Default environment schema
        $script:ConfigurationStore.Schemas['environment'] = @{
            name = @{ Required = $true; Type = [string] }
            description = @{ Required = $false; Type = [string] }
            settings = @{ Required = $false; Type = [hashtable] }
            securityPolicy = @{ Required = $false; Type = [hashtable] }
        }

        Write-CustomLog -Level 'DEBUG' -Message "Default schemas initialized"

    } catch {
        Write-CustomLog -Level 'WARNING' -Message "Failed to initialize default schemas: $_"
    }
}

function Get-ConfigurationStore {
    <#
    .SYNOPSIS
        Gets the current configuration store
    .DESCRIPTION
        Returns the complete configuration store including all modules, environments, and schemas
    .PARAMETER AsJson
        Return the configuration store as JSON string
    .PARAMETER IncludeMetadata
        Include metadata like last modified dates and version information
    #>
    [CmdletBinding()]
    param(
        [switch]$AsJson,
        [switch]$IncludeMetadata
    )

    try {
        # Create a deep copy of the configuration store
        $store = @{}
        foreach ($key in $script:ConfigurationStore.Keys) {
            if ($script:ConfigurationStore[$key] -is [hashtable]) {
                $store[$key] = $script:ConfigurationStore[$key].Clone()
            } else {
                $store[$key] = $script:ConfigurationStore[$key]
            }
        }

        if ($IncludeMetadata) {
            $store.Metadata = @{
                LastModified = (Get-Item $script:ConfigurationStore.StorePath -ErrorAction SilentlyContinue).LastWriteTime
                Version = $script:MODULE_VERSION
                CreatedBy = $env:USERNAME
                Platform = if ($IsWindows) { 'Windows' } elseif ($IsLinux) { 'Linux' } else { 'macOS' }
            }
        }

        if ($AsJson) {
            return ($store | ConvertTo-Json -Depth 10)
        } else {
            return $store
        }

    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to get configuration store: $_"
        throw
    }
}

function Set-ConfigurationStore {
    <#
    .SYNOPSIS
        Sets configuration store values
    .DESCRIPTION
        Updates configuration store with new values
    .PARAMETER Configuration
        Configuration hashtable to set
    .PARAMETER Path
        Dot-notation path to specific configuration value
    .PARAMETER Value
        Value to set at the specified path
    #>
    [CmdletBinding()]
    param(
        [hashtable]$Configuration,
        [string]$Path,
        [object]$Value
    )

    try {
        if ($Configuration) {
            # Validate configuration
            $validationResult = Validate-Configuration -Configuration $Configuration
            if (-not $validationResult.IsValid) {
                throw "Configuration validation failed: $($validationResult.Errors -join '; ')"
            }

            $script:ConfigurationStore = $Configuration
        } elseif ($Path -and $Value) {
            # Set specific path value
            $pathParts = $Path.Split('.')
            $current = $script:ConfigurationStore

            for ($i = 0; $i -lt $pathParts.Length - 1; $i++) {
                if (-not $current.ContainsKey($pathParts[$i])) {
                    $current[$pathParts[$i]] = @{}
                }
                $current = $current[$pathParts[$i]]
            }

            $current[$pathParts[-1]] = $Value
        } else {
            throw "Either Configuration or Path/Value must be provided"
        }

        # Save configuration
        Save-ConfigurationStore

        Write-CustomLog -Level 'SUCCESS' -Message "Configuration store updated successfully"

    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to set configuration store: $_"
        throw
    }
}

function Get-ModuleConfiguration {
    <#
    .SYNOPSIS
        Gets configuration for a specific module
    .PARAMETER ModuleName
        Name of the module
    .PARAMETER Setting
        Specific setting to retrieve
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ModuleName,
        [string]$Setting
    )

    try {
        if (-not $script:ConfigurationStore.Modules.ContainsKey($ModuleName)) {
            Write-CustomLog -Level 'WARNING' -Message "Module '$ModuleName' not found in configuration"
            return $null
        }

        $moduleConfig = $script:ConfigurationStore.Modules[$ModuleName]

        if ($Setting) {
            return $moduleConfig.Settings[$Setting]
        } else {
            return $moduleConfig
        }

    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to get module configuration: $_"
        throw
    }
}

function Set-ModuleConfiguration {
    <#
    .SYNOPSIS
        Sets configuration for a specific module
    .PARAMETER ModuleName
        Name of the module
    .PARAMETER Configuration
        Module configuration hashtable
    .PARAMETER Setting
        Specific setting name
    .PARAMETER Value
        Setting value
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ModuleName,
        [hashtable]$Configuration,
        [string]$Setting,
        [object]$Value
    )

    try {
        if (-not $script:ConfigurationStore.Modules.ContainsKey($ModuleName)) {
            $script:ConfigurationStore.Modules[$ModuleName] = @{
                name = $ModuleName
                settings = @{}
                enabled = $true
                lastModified = Get-Date
            }
        }

        if ($Configuration) {
            $script:ConfigurationStore.Modules[$ModuleName] = $Configuration
        } elseif ($Setting -and $Value) {
            $script:ConfigurationStore.Modules[$ModuleName].Settings[$Setting] = $Value
        } else {
            throw "Either Configuration or Setting/Value must be provided"
        }

        $script:ConfigurationStore.Modules[$ModuleName].lastModified = Get-Date

        # Save configuration
        Save-ConfigurationStore

        Write-CustomLog -Level 'SUCCESS' -Message "Module configuration updated: $ModuleName"

    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to set module configuration: $_"
        throw
    }
}

function Register-ModuleConfiguration {
    <#
    .SYNOPSIS
        Registers a module configuration with the core system
    .PARAMETER ModuleName
        Name of the module
    .PARAMETER Configuration
        Module configuration
    .PARAMETER Schema
        Optional configuration schema
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ModuleName,
        [Parameter(Mandatory)]
        [hashtable]$Configuration,
        [hashtable]$Schema = @{}
    )

    try {
        # Validate against schema if provided
        if ($Schema.Count -gt 0) {
            $validationResult = Test-ConfigurationSchema -Configuration $Configuration -Schema $Schema
            if (-not $validationResult.IsValid) {
                throw "Configuration validation failed: $($validationResult.Errors -join '; ')"
            }
        }

        # Register configuration
        $script:ConfigurationStore.Modules[$ModuleName] = @{
            name = $ModuleName
            configuration = $Configuration
            schema = $Schema
            registered = Get-Date
            lastModified = Get-Date
        }

        # Save configuration
        Save-ConfigurationStore

        Write-CustomLog -Level 'SUCCESS' -Message "Module configuration registered: $ModuleName"

    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to register module configuration: $_"
        throw
    }
}

# CONFIGURATION CAROUSEL FUNCTIONS

function Initialize-ConfigurationCarousel {
    <#
    .SYNOPSIS
        Initializes the configuration carousel system
    #>
    $paths = @($script:ConfigCarouselPath, $script:ConfigBackupPath, $script:ConfigEnvironmentsPath)

    foreach ($path in $paths) {
        if (-not (Test-Path $path)) {
            New-Item -Path $path -ItemType Directory -Force | Out-Null
        }
    }

    # Create carousel registry if it doesn't exist
    $registryPath = Join-Path $script:ConfigCarouselPath "carousel-registry.json"
    if (-not (Test-Path $registryPath)) {
        $defaultRegistry = @{
            version = "1.0"
            currentConfiguration = "default"
            currentEnvironment = "dev"
            configurations = @{
                default = @{
                    name = "default"
                    description = "Default AitherZero configuration"
                    path = "../../configs"
                    type = "builtin"
                    environments = @("dev", "staging", "prod")
                }
            }
            environments = @{
                dev = @{
                    name = "dev"
                    description = "Development environment"
                    securityPolicy = @{
                        destructiveOperations = "allow"
                        autoConfirm = $true
                    }
                }
                staging = @{
                    name = "staging"
                    description = "Staging environment"
                    securityPolicy = @{
                        destructiveOperations = "confirm"
                        autoConfirm = $false
                    }
                }
                prod = @{
                    name = "prod"
                    description = "Production environment"
                    securityPolicy = @{
                        destructiveOperations = "block"
                        autoConfirm = $false
                    }
                }
            }
            lastUpdated = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        }

        $defaultRegistry | ConvertTo-Json -Depth 10 | Set-Content -Path $registryPath
    }
}

function Get-ConfigurationRegistry {
    <#
    .SYNOPSIS
        Gets the configuration carousel registry
    #>
    Initialize-ConfigurationCarousel

    $registryPath = Join-Path $script:ConfigCarouselPath "carousel-registry.json"
    if (Test-Path $registryPath) {
        return Get-Content -Path $registryPath | ConvertFrom-Json
    }

    throw "Configuration registry not found"
}

function Set-ConfigurationRegistry {
    <#
    .SYNOPSIS
        Sets the configuration carousel registry
    #>
    param(
        [Parameter(Mandatory)]
        $Registry
    )

    $registryPath = Join-Path $script:ConfigCarouselPath "carousel-registry.json"
    $Registry.lastUpdated = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    $Registry | ConvertTo-Json -Depth 10 | Set-Content -Path $registryPath
}

function Switch-ConfigurationSet {
    <#
    .SYNOPSIS
        Switches to a different configuration set
    .DESCRIPTION
        Changes the active configuration set and optionally the environment
    .PARAMETER ConfigurationName
        Name of the configuration to switch to
    .PARAMETER Environment
        Environment to use (optional)
    .PARAMETER BackupCurrent
        Create backup of current configuration
    .PARAMETER Force
        Force switch even with validation warnings
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ConfigurationName,

        [string]$Environment,
        [switch]$BackupCurrent,
        [switch]$Force
    )

    try {
        Write-CustomLog -Level 'INFO' -Message "Switching to configuration: $ConfigurationName"

        $registry = Get-ConfigurationRegistry

        # Validate configuration exists
        if (-not ($registry.configurations.PSObject.Properties.Name -contains $ConfigurationName)) {
            throw "Configuration '$ConfigurationName' not found. Available: $($registry.configurations.PSObject.Properties.Name -join ', ')"
        }

        $targetConfig = $registry.configurations.$ConfigurationName

        # Validate environment if specified
        if ($Environment) {
            if ($Environment -notin $targetConfig.environments) {
                throw "Environment '$Environment' not supported by configuration '$ConfigurationName'. Available: $($targetConfig.environments -join ', ')"
            }
        } else {
            $Environment = $targetConfig.environments[0]  # Use first available environment
        }

        # Backup current configuration if requested
        if ($BackupCurrent) {
            $backupResult = Backup-CurrentConfiguration -Reason "Before switching to $ConfigurationName"
            Write-CustomLog -Level 'INFO' -Message "Current configuration backed up: $($backupResult.BackupPath)"
        }

        # Enhanced validation for target configuration
        $validationResult = Validate-ConfigurationSet -ConfigurationName $ConfigurationName -Environment $Environment
        if (-not $validationResult.IsValid) {
            Write-CustomLog -Level 'ERROR' -Message "Configuration validation failed:"
            foreach ($Verror in $validationResult.Errors) {
                Write-CustomLog -Level 'ERROR' -Message "  - $error"
            }
            
            if (-not $Force) {
                throw "Configuration validation failed. Use -Force to override."
            } else {
                Write-CustomLog -Level 'WARNING' -Message "Validation failed but -Force specified, continuing anyway"
            }
        }

        # Update registry
        $registry.currentConfiguration = $ConfigurationName
        $registry.currentEnvironment = $Environment
        Set-ConfigurationRegistry -Registry $registry

        # Apply configuration
        $applyResult = Apply-ConfigurationSet -ConfigurationName $ConfigurationName -Environment $Environment

        Write-CustomLog -Level 'SUCCESS' -Message "Successfully switched to configuration '$ConfigurationName' with environment '$Environment'"

        return @{
            Success = $true
            PreviousConfiguration = $registry.currentConfiguration
            NewConfiguration = $ConfigurationName
            Environment = $Environment
            ValidationResult = $validationResult
            ApplyResult = $applyResult
        }

    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to switch configuration: $_"
        return @{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

function Get-AvailableConfigurations {
    <#
    .SYNOPSIS
        Lists all available configuration sets
    .DESCRIPTION
        Returns information about all registered configuration sets and their environments
    .PARAMETER IncludeDetails
        Include detailed information about each configuration
    #>
    [CmdletBinding()]
    param(
        [switch]$IncludeDetails
    )

    try {
        $registry = Get-ConfigurationRegistry

        $configurations = @()

        foreach ($configName in $registry.configurations.PSObject.Properties.Name) {
            $config = $registry.configurations.$configName

            $configInfo = @{
                Name = $configName
                Description = $config.description
                Type = $config.type
                Environments = $config.environments
                IsActive = ($configName -eq $registry.currentConfiguration)
            }

            if ($IncludeDetails) {
                $configInfo.Path = $config.path
                $configInfo.Repository = $config.repository
                $configInfo.LastValidated = $config.lastValidated
                $configInfo.IsAccessible = Test-ConfigurationAccessible -Configuration $config
            }

            $configurations += $configInfo
        }

        return @{
            CurrentConfiguration = $registry.currentConfiguration
            CurrentEnvironment = $registry.currentEnvironment
            TotalConfigurations = $configurations.Count
            Configurations = $configurations
        }

    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to get available configurations: $_"
        throw
    }
}

function Add-ConfigurationRepository {
    <#
    .SYNOPSIS
        Adds a new configuration repository to the carousel
    .DESCRIPTION
        Registers a new configuration set from a Git repository or local path
    .PARAMETER Name
        Name of the configuration
    .PARAMETER Source
        Source path or URL
    .PARAMETER Description
        Description of the configuration
    .PARAMETER Environments
        Available environments
    .PARAMETER SourceType
        Type of source (git, local, template)
    .PARAMETER Branch
        Git branch to use
    .PARAMETER SetAsCurrent
        Set as current configuration after adding
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$Source,

        [string]$Description,
        [string[]]$Environments = @('dev', 'staging', 'prod'),

        [ValidateSet('git', 'local', 'template')]
        [string]$SourceType = 'auto',

        [string]$Branch = 'main',
        [switch]$SetAsCurrent
    )

    try {
        Write-CustomLog -Level 'INFO' -Message "Adding configuration repository: $Name"

        $registry = Get-ConfigurationRegistry

        # Check if configuration already exists
        if ($registry.configurations.PSObject.Properties.Name -contains $Name) {
            throw "Configuration '$Name' already exists"
        }

        # Determine source type if auto
        if ($SourceType -eq 'auto') {
            if ($Source -match '^https?://|\.git$|^git@') {
                $SourceType = 'git'
            } elseif (Test-Path $Source) {
                $SourceType = 'local'
            } else {
                $SourceType = 'template'
            }
        }

        # Create configuration directory
        $configPath = Join-Path $script:ConfigCarouselPath $Name
        if (Test-Path $configPath) {
            Remove-Item -Path $configPath -Recurse -Force
        }

        # Download/copy configuration based on source type
        switch ($SourceType) {
            'git' {
                Write-CustomLog -Level 'INFO' -Message "Cloning Git repository: $Source"
                $cloneResult = git clone --branch $Branch $Source $configPath 2>&1
                if ($LASTEXITCODE -ne 0) {
                    throw "Git clone failed: $cloneResult"
                }
            }
            'local' {
                Write-CustomLog -Level 'INFO' -Message "Copying local configuration: $Source"
                Copy-Item -Path $Source -Destination $configPath -Recurse -Force
            }
            'template' {
                Write-CustomLog -Level 'INFO' -Message "Creating from template: $Source"
                $templateResult = New-ConfigurationFromTemplate -TemplateName $Source -Destination $configPath
                if (-not $templateResult.Success) {
                    throw "Template creation failed: $($templateResult.Error)"
                }
            }
        }

        # Add to registry
        $newConfig = @{
            name = $Name
            description = $Description ?? "Custom configuration: $Name"
            path = $configPath
            type = 'custom'
            sourceType = $SourceType
            source = $Source
            branch = $Branch
            environments = $Environments
            addedDate = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
            lastValidated = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        }

        $registry.configurations | Add-Member -MemberType NoteProperty -Name $Name -Value $newConfig
        Set-ConfigurationRegistry -Registry $registry

        Write-CustomLog -Level 'SUCCESS' -Message "Configuration '$Name' added successfully"

        # Set as current if requested
        if ($SetAsCurrent) {
            $switchResult = Switch-ConfigurationSet -ConfigurationName $Name -Environment $Environments[0]
            return @{
                Success = $true
                Name = $Name
                Path = $configPath
                SwitchResult = $switchResult
            }
        }

        return @{
            Success = $true
            Name = $Name
            Path = $configPath
        }

    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to add configuration repository: $_"
        return @{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

function Get-CurrentConfiguration {
    <#
    .SYNOPSIS
        Gets information about the currently active configuration
    #>
    [CmdletBinding()]
    param()

    try {
        $registry = Get-ConfigurationRegistry
        $currentName = $registry.currentConfiguration
        $currentEnv = $registry.currentEnvironment

        if ($registry.configurations.PSObject.Properties.Name -contains $currentName) {
            $config = $registry.configurations.$currentName

            return @{
                Name = $currentName
                Environment = $currentEnv
                Description = $config.description
                Type = $config.type
                Path = $config.path
                Source = $config.source
                AvailableEnvironments = $config.environments
                IsAccessible = Test-ConfigurationAccessible -Configuration $config
                LastValidated = $config.lastValidated
            }
        } else {
            throw "Current configuration '$currentName' not found in registry"
        }

    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to get current configuration: $_"
        throw
    }
}

function Backup-CurrentConfiguration {
    <#
    .SYNOPSIS
        Creates a backup of the current configuration
    .PARAMETER Reason
        Reason for the backup
    .PARAMETER BackupName
        Name for the backup
    #>
    [CmdletBinding()]
    param(
        [string]$Reason = "Manual backup",
        [string]$BackupName
    )

    try {
        $current = Get-CurrentConfiguration

        if (-not $BackupName) {
            $BackupName = "$($current.Name)-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        }

        $backupPath = Join-Path $script:ConfigBackupPath $BackupName

        if ($current.IsAccessible -and (Test-Path $current.Path)) {
            Copy-Item -Path $current.Path -Destination $backupPath -Recurse -Force

            # Create backup metadata
            $metadata = @{
                originalName = $current.Name
                originalEnvironment = $current.Environment
                backupDate = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
                reason = $Reason
                originalPath = $current.Path
            }

            $metadataPath = Join-Path $backupPath "backup-metadata.json"
            $metadata | ConvertTo-Json -Depth 5 | Set-Content -Path $metadataPath

            Write-CustomLog -Level 'SUCCESS' -Message "Configuration backed up: $backupPath"

            return @{
                Success = $true
                BackupName = $BackupName
                BackupPath = $backupPath
                OriginalConfiguration = $current.Name
            }
        } else {
            throw "Current configuration path is not accessible: $($current.Path)"
        }

    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to backup configuration: $_"
        return @{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

function Validate-ConfigurationSet {
    <#
    .SYNOPSIS
        Validates a configuration set for completeness and correctness
    .PARAMETER ConfigurationName
        Name of configuration to validate
    .PARAMETER Environment
        Environment to validate for
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ConfigurationName,

        [string]$Environment = 'dev'
    )

    try {
        $registry = Get-ConfigurationRegistry

        if (-not ($registry.configurations.PSObject.Properties.Name -contains $ConfigurationName)) {
            return @{
                IsValid = $false
                Errors = @("Configuration '$ConfigurationName' not found")
            }
        }

        $config = $registry.configurations.$ConfigurationName
        $errors = @()
        $warnings = @()

        # Check if path exists and is accessible
        if (-not (Test-Path $config.path)) {
            $errors += "Configuration path does not exist: $($config.path)"
        } else {
            # Check for required configuration files
            $requiredFiles = @('app-config.json', 'module-config.json')
            foreach ($file in $requiredFiles) {
                $filePath = Join-Path $config.path $file
                if (-not (Test-Path $filePath)) {
                    $warnings += "Optional configuration file missing: $file"
                }
            }
        }

        # Environment-specific validation
        if ($Environment -and $Environment -notin $config.environments) {
            $errors += "Environment '$Environment' not supported by this configuration"
        }

        return @{
            IsValid = ($errors.Count -eq 0)
            Errors = $errors
            Warnings = $warnings
            ConfigurationName = $ConfigurationName
            Environment = $Environment
        }

    } catch {
        return @{
            IsValid = $false
            Errors = @("Validation error: $($_.Exception.Message)")
        }
    }
}

# EVENT SYSTEM FUNCTIONS

function Publish-ConfigurationEvent {
    <#
    .SYNOPSIS
        Publishes a configuration event
    .PARAMETER EventName
        Name of the event
    .PARAMETER EventData
        Data associated with the event
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$EventName,
        [hashtable]$EventData = @{}
    )

    try {
        $event = @{
            Name = $EventName
            Data = $EventData
            Timestamp = Get-Date
            Source = 'ConfigurationCore'
        }

        # Add to history
        $script:ConfigurationEventHistory += $event

        # Notify subscribers
        foreach ($subscription in $script:ConfigurationEventSubscriptions) {
            if ($subscription.EventName -eq $EventName -or $subscription.EventName -eq '*') {
                try {
                    & $subscription.ScriptBlock $event
                } catch {
                    Write-CustomLog -Level 'ERROR' -Message "Error in event subscription: $_"
                }
            }
        }

        Write-CustomLog -Level 'DEBUG' -Message "Configuration event published: $EventName"

    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to publish configuration event: $_"
    }
}

function Subscribe-ConfigurationEvent {
    <#
    .SYNOPSIS
        Subscribes to configuration events
    .PARAMETER EventName
        Name of the event to subscribe to (use '*' for all events)
    .PARAMETER ScriptBlock
        Script block to execute when event occurs
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$EventName,
        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock
    )

    try {
        $subscription = @{
            EventName = $EventName
            ScriptBlock = $ScriptBlock
            SubscribedAt = Get-Date
            Id = [guid]::NewGuid().ToString()
        }

        $script:ConfigurationEventSubscriptions += $subscription

        Write-CustomLog -Level 'DEBUG' -Message "Subscribed to configuration event: $EventName"

        return $subscription.Id

    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to subscribe to configuration event: $_"
        throw
    }
}

function Unsubscribe-ConfigurationEvent {
    <#
    .SYNOPSIS
        Unsubscribes from configuration events
    .PARAMETER SubscriptionId
        ID of the subscription to remove
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$SubscriptionId
    )

    try {
        $script:ConfigurationEventSubscriptions = $script:ConfigurationEventSubscriptions | Where-Object { $_.Id -ne $SubscriptionId }
        Write-CustomLog -Level 'DEBUG' -Message "Unsubscribed from configuration event: $SubscriptionId"

    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to unsubscribe from configuration event: $_"
        throw
    }
}

function Get-ConfigurationEventHistory {
    <#
    .SYNOPSIS
        Gets configuration event history
    .PARAMETER EventName
        Filter by event name
    .PARAMETER Since
        Get events since specified date
    .PARAMETER Last
        Get last N events
    #>
    [CmdletBinding()]
    param(
        [string]$EventName,
        [DateTime]$Since,
        [int]$Last
    )

    try {
        $events = $script:ConfigurationEventHistory

        if ($EventName) {
            $events = $events | Where-Object { $_.Name -eq $EventName }
        }

        if ($Since) {
            $events = $events | Where-Object { $_.Timestamp -ge $Since }
        }

        if ($Last) {
            $events = $events | Sort-Object Timestamp -Descending | Select-Object -First $Last
        }

        return $events

    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to get configuration event history: $_"
        throw
    }
}

# ENVIRONMENT MANAGEMENT FUNCTIONS

function New-ConfigurationEnvironment {
    <#
    .SYNOPSIS
        Creates a new configuration environment
    .PARAMETER Name
        Name of the environment
    .PARAMETER Description
        Description of the environment
    .PARAMETER SecurityPolicy
        Security policy for the environment
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,
        [string]$Description = "",
        [hashtable]$SecurityPolicy = @{}
    )

    try {
        Write-CustomLog -Level 'INFO' -Message "Creating new configuration environment: $Name"

        $newEnvironment = @{
            Name = $Name
            Description = $Description
            Settings = @{}
            SecurityPolicy = if ($SecurityPolicy.Count -gt 0) { $SecurityPolicy } else {
                @{
                    destructiveOperations = "prompt"
                    dataAccess = "restricted"
                    networkAccess = "limited"
                }
            }
            Created = Get-Date
            CreatedBy = $env:USERNAME
        }

        $script:ConfigurationStore.Environments[$Name] = $newEnvironment
        Save-ConfigurationStore

        Publish-ConfigurationEvent -EventName 'EnvironmentCreated' -EventData @{ Name = $Name }

        Write-CustomLog -Level 'SUCCESS' -Message "Configuration environment created: $Name"

        return $newEnvironment

    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to create configuration environment: $_"
        throw
    }
}

function Get-ConfigurationEnvironment {
    <#
    .SYNOPSIS
        Gets configuration environment information
    .PARAMETER Name
        Name of the environment (optional - returns current if not specified)
    #>
    [CmdletBinding()]
    param(
        [string]$Name
    )

    try {
        if (-not $Name) {
            $Name = $script:ConfigurationStore.CurrentEnvironment
        }

        if ($script:ConfigurationStore.Environments.ContainsKey($Name)) {
            return $script:ConfigurationStore.Environments[$Name]
        } else {
            throw "Environment '$Name' not found"
        }

    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to get configuration environment: $_"
        throw
    }
}

function Set-ConfigurationEnvironment {
    <#
    .SYNOPSIS
        Sets the current configuration environment
    .PARAMETER Name
        Name of the environment to set as current
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    try {
        if (-not $script:ConfigurationStore.Environments.ContainsKey($Name)) {
            throw "Environment '$Name' not found"
        }

        $previousEnvironment = $script:ConfigurationStore.CurrentEnvironment
        $script:ConfigurationStore.CurrentEnvironment = $Name

        Save-ConfigurationStore

        Publish-ConfigurationEvent -EventName 'EnvironmentChanged' -EventData @{ 
            Previous = $previousEnvironment 
            Current = $Name 
        }

        Write-CustomLog -Level 'SUCCESS' -Message "Configuration environment changed to: $Name"

    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to set configuration environment: $_"
        throw
    }
}

# BACKUP AND RESTORE FUNCTIONS

function Backup-Configuration {
    <#
    .SYNOPSIS
        Creates a backup of the configuration
    .PARAMETER BackupName
        Name for the backup
    .PARAMETER IncludeHistory
        Include event history in backup
    #>
    [CmdletBinding()]
    param(
        [string]$BackupName,
        [switch]$IncludeHistory
    )

    try {
        if (-not $BackupName) {
            $BackupName = "config-backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        }

        $backupDir = Split-Path $script:ConfigurationStore.StorePath -Parent
        $backupPath = Join-Path $backupDir "backups" "$BackupName.json"

        # Ensure backup directory exists
        $backupParent = Split-Path $backupPath -Parent
        if (-not (Test-Path $backupParent)) {
            New-Item -Path $backupParent -ItemType Directory -Force | Out-Null
        }

        # Create backup data
        $backupData = @{
            Timestamp = Get-Date
            Version = $script:MODULE_VERSION
            Configuration = $script:ConfigurationStore
        }

        if ($IncludeHistory) {
            $backupData.EventHistory = $script:ConfigurationEventHistory
        }

        # Save backup
        $backupData | ConvertTo-Json -Depth 20 | Set-Content $backupPath -Encoding UTF8

        Write-CustomLog -Level 'SUCCESS' -Message "Configuration backup created: $backupPath"

        return @{
            Success = $true
            BackupName = $BackupName
            BackupPath = $backupPath
            Timestamp = Get-Date
        }

    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to create configuration backup: $_"
        throw
    }
}

function Restore-Configuration {
    <#
    .SYNOPSIS
        Restores configuration from a backup
    .PARAMETER BackupPath
        Path to the backup file
    .PARAMETER RestoreHistory
        Restore event history from backup
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$BackupPath,
        [switch]$RestoreHistory
    )

    try {
        if (-not (Test-Path $BackupPath)) {
            throw "Backup file not found: $BackupPath"
        }

        Write-CustomLog -Level 'INFO' -Message "Restoring configuration from: $BackupPath"

        # Load backup data
        $backupData = Get-Content $BackupPath -Raw | ConvertFrom-Json -AsHashtable

        # Validate backup structure
        if (-not $backupData.Configuration) {
            throw "Invalid backup file: missing configuration data"
        }

        # Create current backup before restore
        $currentBackup = Backup-Configuration -BackupName "pre-restore-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

        # Restore configuration
        $script:ConfigurationStore = $backupData.Configuration
        $script:ConfigurationStore.StorePath = $currentBackup.BackupPath

        # Restore event history if requested
        if ($RestoreHistory -and $backupData.EventHistory) {
            $script:ConfigurationEventHistory = $backupData.EventHistory
        }

        # Save restored configuration
        Save-ConfigurationStore

        Write-CustomLog -Level 'SUCCESS' -Message "Configuration restored successfully"

        return @{
            Success = $true
            BackupPath = $BackupPath
            RestoreTimestamp = Get-Date
            PreRestoreBackup = $currentBackup.BackupPath
        }

    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to restore configuration: $_"
        throw
    }
}

# HELPER FUNCTIONS

function Test-ConfigurationAccessible {
    <#
    .SYNOPSIS
        Tests if a configuration is accessible
    .PARAMETER Configuration
        Configuration object to test
    #>
    param($Configuration)

    if ($Configuration.path) {
        return Test-Path $Configuration.path
    }
    return $false
}

function Apply-ConfigurationSet {
    <#
    .SYNOPSIS
        Applies a configuration set
    .PARAMETER ConfigurationName
        Name of configuration to apply
    .PARAMETER Environment
        Environment to apply for
    #>
    param(
        [string]$ConfigurationName,
        [string]$Environment
    )

    # This would contain logic to actually apply the configuration
    # For now, it's a placeholder that returns success
    Write-CustomLog -Level 'INFO' -Message "Applying configuration '$ConfigurationName' for environment '$Environment'"

    return @{
        Success = $true
        Message = "Configuration applied successfully"
    }
}

function New-ConfigurationFromTemplate {
    <#
    .SYNOPSIS
        Creates a configuration from a template
    .PARAMETER TemplateName
        Name of the template
    .PARAMETER Destination
        Destination path
    #>
    param(
        [string]$TemplateName,
        [string]$Destination
    )

    # Placeholder for template creation logic
    New-Item -Path $Destination -ItemType Directory -Force | Out-Null

    return @{
        Success = $true
        Message = "Template configuration created"
    }
}

# INITIALIZATION

# Initialize the configuration system
try {
    Initialize-ConfigurationCore
    Initialize-ConfigurationCarousel
    Write-CustomLog -Level 'SUCCESS' -Message "Configuration system initialized successfully"
} catch {
    Write-CustomLog -Level 'ERROR' -Message "Failed to initialize configuration system: $_"
}
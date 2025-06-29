# Configuration Carousel Module for AitherZero
# Manages multiple configuration sets and environments with easy switching

# Import required modules
. "$PSScriptRoot/../../shared/Find-ProjectRoot.ps1"
$projectRoot = Find-ProjectRoot

# Import logging if available
$loggingModule = Join-Path $projectRoot "aither-core/modules/Logging"
if (Test-Path $loggingModule) {
    Import-Module $loggingModule -Force -ErrorAction SilentlyContinue
}

# Configuration paths
$script:ConfigCarouselPath = Join-Path $projectRoot "configs/carousel"
$script:ConfigBackupPath = Join-Path $projectRoot "configs/backups"
$script:ConfigEnvironmentsPath = Join-Path $projectRoot "configs/environments"

# Initialize carousel directory structure
function Initialize-ConfigurationCarousel {
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
        if (-not $registry.configurations.PSObject.Properties[$ConfigurationName]) {
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
        
        # Validate target configuration
        $validationResult = Validate-ConfigurationSet -ConfigurationName $ConfigurationName -Environment $Environment
        if (-not $validationResult.IsValid -and -not $Force) {
            throw "Configuration validation failed: $($validationResult.Errors -join '; ')"
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
                
                # Check if configuration is accessible
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
        if ($registry.configurations.PSObject.Properties[$Name]) {
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
        
        # Validate the new configuration
        $validationResult = Validate-ConfigurationPath -Path $configPath
        if (-not $validationResult.IsValid) {
            Remove-Item -Path $configPath -Recurse -Force -ErrorAction SilentlyContinue
            throw "Configuration validation failed: $($validationResult.Errors -join '; ')"
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
            ValidationResult = $validationResult
        }
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to add configuration repository: $_"
        return @{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

function Remove-ConfigurationRepository {
    <#
    .SYNOPSIS
        Removes a configuration repository from the carousel
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,
        
        [switch]$DeleteFiles,
        
        [switch]$Force
    )
    
    try {
        $registry = Get-ConfigurationRegistry
        
        # Check if configuration exists
        if (-not $registry.configurations.PSObject.Properties[$Name]) {
            throw "Configuration '$Name' not found"
        }
        
        # Prevent removal of current configuration without force
        if ($registry.currentConfiguration -eq $Name -and -not $Force) {
            throw "Cannot remove current configuration '$Name' without -Force flag"
        }
        
        # Prevent removal of default configuration
        if ($Name -eq 'default') {
            throw "Cannot remove default configuration"
        }
        
        $config = $registry.configurations.$Name
        
        # Remove files if requested
        if ($DeleteFiles -and $config.path -and (Test-Path $config.path)) {
            Remove-Item -Path $config.path -Recurse -Force
            Write-CustomLog -Level 'INFO' -Message "Deleted configuration files: $($config.path)"
        }
        
        # Remove from registry
        $registry.configurations.PSObject.Properties.Remove($Name)
        
        # Switch to default if this was the current configuration
        if ($registry.currentConfiguration -eq $Name) {
            $registry.currentConfiguration = 'default'
            $registry.currentEnvironment = 'dev'
            Write-CustomLog -Level 'INFO' -Message "Switched to default configuration"
        }
        
        Set-ConfigurationRegistry -Registry $registry
        
        Write-CustomLog -Level 'SUCCESS' -Message "Configuration '$Name' removed successfully"
        
        return @{
            Success = $true
            RemovedConfiguration = $Name
            FilesDeleted = $DeleteFiles
        }
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to remove configuration: $_"
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
        
        if ($registry.configurations.PSObject.Properties[$currentName]) {
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
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ConfigurationName,
        
        [string]$Environment = 'dev'
    )
    
    try {
        $registry = Get-ConfigurationRegistry
        
        if (-not $registry.configurations.PSObject.Properties[$ConfigurationName]) {
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

# Helper functions
function Test-ConfigurationAccessible {
    param($Configuration)
    
    if ($Configuration.path) {
        return Test-Path $Configuration.path
    }
    return $false
}

function Apply-ConfigurationSet {
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

function Validate-ConfigurationPath {
    param([string]$Path)
    
    $errors = @()
    
    if (-not (Test-Path $Path)) {
        $errors += "Path does not exist"
    }
    
    return @{
        IsValid = ($errors.Count -eq 0)
        Errors = $errors
    }
}

function New-ConfigurationFromTemplate {
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

# Logging fallback functions
if (-not (Get-Command Write-CustomLog -ErrorAction SilentlyContinue)) {
    function Write-CustomLog {
        param(
            [string]$Level,
            [string]$Message
        )
        $color = switch ($Level) {
            'SUCCESS' { 'Green' }
            'ERROR' { 'Red' }
            'WARNING' { 'Yellow' }
            'INFO' { 'Cyan' }
            default { 'White' }
        }
        Write-Host "[$Level] $Message" -ForegroundColor $color
    }
}

# Initialize on module load
Initialize-ConfigurationCarousel

# Export functions
Export-ModuleMember -Function @(
    'Switch-ConfigurationSet',
    'Get-AvailableConfigurations', 
    'Add-ConfigurationRepository',
    'Remove-ConfigurationRepository',
    'Get-CurrentConfiguration',
    'Backup-CurrentConfiguration',
    'Validate-ConfigurationSet'
)
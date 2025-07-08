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

        # Enhanced validation for target configuration
        $validationResult = Validate-ConfigurationSet -ConfigurationName $ConfigurationName -Environment $Environment
        if (-not $validationResult.IsValid) {
            Write-CustomLog -Level 'ERROR' -Message "Configuration validation failed:"
            foreach ($error in $validationResult.Errors) {
                Write-CustomLog -Level 'ERROR' -Message "  - $error"
            }
            if (-not $Force) {
                throw "Configuration validation failed. Use -Force to override."
            } else {
                Write-CustomLog -Level 'WARNING' -Message "Validation failed but -Force specified, continuing anyway"
            }
        }

        # Additional environment-specific validation
        $envValidation = Test-EnvironmentCompatibility -ConfigurationName $ConfigurationName -Environment $Environment
        if (-not $envValidation.IsCompatible) {
            Write-CustomLog -Level 'WARNING' -Message "Environment compatibility issues detected:"
            foreach ($warning in $envValidation.Warnings) {
                Write-CustomLog -Level 'WARNING' -Message "  - $warning"
            }

            if ($envValidation.BlockingIssues.Count -gt 0 -and -not $Force) {
                Write-CustomLog -Level 'ERROR' -Message "Blocking issues found:"
                foreach ($issue in $envValidation.BlockingIssues) {
                    Write-CustomLog -Level 'ERROR' -Message "  - $issue"
                }
                throw "Environment has blocking compatibility issues. Use -Force to override."
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

function Sync-ConfigurationRepository {
    <#
    .SYNOPSIS
        Synchronizes a configuration repository with its remote source
    .DESCRIPTION
        Updates a configuration repository by pulling changes from its remote source
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ConfigurationName,

        [ValidateSet('pull', 'push', 'sync')]
        [string]$Operation = 'pull',

        [switch]$Force,

        [switch]$BackupCurrent = $true
    )

    try {
        Write-CustomLog -Level 'INFO' -Message "Synchronizing configuration repository: $ConfigurationName"

        $registry = Get-ConfigurationRegistry

        # Validate configuration exists
        if (-not $registry.configurations.PSObject.Properties[$ConfigurationName]) {
            throw "Configuration '$ConfigurationName' not found"
        }

        $config = $registry.configurations.$ConfigurationName

        # Check if configuration has a remote source
        if (-not $config.source -or $config.sourceType -ne 'git') {
            throw "Configuration '$ConfigurationName' does not have a Git remote source"
        }

        # Validate configuration path exists
        if (-not (Test-Path $config.path)) {
            throw "Configuration path does not exist: $($config.path)"
        }

        # Backup current if requested
        $backupResult = $null
        if ($BackupCurrent) {
            $backupResult = Backup-CurrentConfiguration -Reason "Before sync of $ConfigurationName"
            Write-CustomLog -Level 'INFO' -Message "Configuration backed up: $($backupResult.BackupPath)"
        }

        # Change to configuration directory
        Push-Location $config.path

        try {
            # Verify it's a Git repository
            git status 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0) {
                throw "Configuration directory is not a Git repository: $($config.path)"
            }

            $syncResult = @{
                Success = $true
                Operation = $Operation
                Changes = @()
                ConflictsDetected = $false
            }

            switch ($Operation) {
                'pull' {
                    Write-CustomLog -Level 'INFO' -Message "Pulling latest changes from remote"

                    # Fetch latest changes
                    $fetchResult = git fetch origin 2>&1
                    if ($LASTEXITCODE -ne 0) {
                        throw "Git fetch failed: $fetchResult"
                    }

                    # Check for local changes
                    $status = git status --porcelain
                    if ($status -and -not $Force) {
                        Write-CustomLog -Level 'WARNING' -Message "Local changes detected. Use -Force to override or commit changes first."
                        $syncResult.Changes += "Local changes detected - sync aborted"
                        return $syncResult
                    }

                    # Pull changes
                    $pullResult = git pull origin $config.branch 2>&1
                    if ($LASTEXITCODE -ne 0) {
                        if ($pullResult -match 'conflict|merge') {
                            $syncResult.ConflictsDetected = $true
                            $syncResult.Changes += "Merge conflicts detected - manual resolution required"
                        } else {
                            throw "Git pull failed: $pullResult"
                        }
                    } else {
                        $syncResult.Changes += "Successfully pulled changes from remote"
                    }
                }

                'push' {
                    Write-CustomLog -Level 'INFO' -Message "Pushing local changes to remote"

                    # Check for changes to commit
                    $status = git status --porcelain
                    if ($status) {
                        git add . 2>&1 | Out-Null
                        $commitResult = git commit -m "Configuration updates from AitherZero $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" 2>&1
                        if ($LASTEXITCODE -ne 0) {
                            throw "Git commit failed: $commitResult"
                        }
                        $syncResult.Changes += "Committed local changes"
                    }

                    # Push to remote
                    $pushResult = git push origin $config.branch 2>&1
                    if ($LASTEXITCODE -ne 0) {
                        throw "Git push failed: $pushResult"
                    }
                    $syncResult.Changes += "Successfully pushed changes to remote"
                }

                'sync' {
                    # Full sync: pull then push
                    Write-CustomLog -Level 'INFO' -Message "Performing full synchronization"

                    # Stash local changes if any
                    $status = git status --porcelain
                    $hasLocalChanges = [bool]$status
                    if ($hasLocalChanges) {
                        git stash push -m "Auto-stash for sync $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" 2>&1 | Out-Null
                        $syncResult.Changes += "Stashed local changes"
                    }

                    # Pull latest
                    $pullResult = git pull origin $config.branch 2>&1
                    if ($LASTEXITCODE -ne 0) {
                        throw "Git pull failed: $pullResult"
                    }
                    $syncResult.Changes += "Pulled latest changes"

                    # Restore and merge local changes
                    if ($hasLocalChanges) {
                        $stashResult = git stash pop 2>&1
                        if ($LASTEXITCODE -eq 0) {
                            $syncResult.Changes += "Restored local changes"

                            # Commit merged changes
                            git add . 2>&1 | Out-Null
                            git commit -m "Sync: Merged local and remote changes $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" 2>&1 | Out-Null

                            # Push merged changes
                            $pushResult = git push origin $config.branch 2>&1
                            if ($LASTEXITCODE -eq 0) {
                                $syncResult.Changes += "Pushed merged changes"
                            } else {
                                Write-CustomLog -Level 'WARNING' -Message "Failed to push merged changes: $pushResult"
                            }
                        } else {
                            Write-CustomLog -Level 'WARNING' -Message "Merge conflicts detected: $stashResult"
                            $syncResult.ConflictsDetected = $true
                            $syncResult.Changes += "Merge conflicts require manual resolution"
                        }
                    }
                }
            }

            # Update registry with last sync time
            $config.lastSync = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
            Set-ConfigurationRegistry -Registry $registry

            Write-CustomLog -Level 'SUCCESS' -Message "Configuration repository synchronized successfully"

            return @{
                Success = $true
                ConfigurationName = $ConfigurationName
                Operation = $Operation
                Changes = $syncResult.Changes
                ConflictsDetected = $syncResult.ConflictsDetected
                BackupPath = $backupResult.BackupPath
                LastSync = $config.lastSync
            }

        } finally {
            Pop-Location
        }

    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to sync configuration repository: $_"
        return @{
            Success = $false
            Error = $_.Exception.Message
            ConfigurationName = $ConfigurationName
            Operation = $Operation
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

function Restore-ConfigurationBackup {
    <#
    .SYNOPSIS
        Restores a configuration from a backup
    .DESCRIPTION
        Restores a previously backed up configuration, optionally setting it as the current configuration
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$BackupName,

        [string]$RestoreAsName,

        [switch]$SetAsCurrent,

        [switch]$Force
    )

    try {
        Write-CustomLog -Level 'INFO' -Message "Restoring configuration from backup: $BackupName"

        $backupPath = Join-Path $script:ConfigBackupPath $BackupName
        
        if (-not (Test-Path $backupPath)) {
            throw "Backup '$BackupName' not found at path: $backupPath"
        }

        # Read backup metadata
        $metadataPath = Join-Path $backupPath "backup-metadata.json"
        if (-not (Test-Path $metadataPath)) {
            throw "Backup metadata not found. This may not be a valid backup."
        }

        $metadata = Get-Content -Path $metadataPath | ConvertFrom-Json

        # Determine restore name
        if (-not $RestoreAsName) {
            $RestoreAsName = $metadata.originalName
        }

        # Check if configuration name already exists
        $registry = Get-ConfigurationRegistry
        if ($registry.configurations.PSObject.Properties[$RestoreAsName] -and -not $Force) {
            throw "Configuration '$RestoreAsName' already exists. Use -Force to overwrite."
        }

        # Determine restore path
        $restorePath = Join-Path $script:ConfigCarouselPath $RestoreAsName
        
        # Remove existing configuration if forcing
        if ($Force -and (Test-Path $restorePath)) {
            Remove-Item -Path $restorePath -Recurse -Force
        }

        # Copy backup to restore location
        Copy-Item -Path $backupPath -Destination $restorePath -Recurse -Force

        # Remove backup metadata from restored configuration
        $restoredMetadataPath = Join-Path $restorePath "backup-metadata.json"
        if (Test-Path $restoredMetadataPath) {
            Remove-Item -Path $restoredMetadataPath -Force
        }

        # Validate restored configuration
        $validationResult = Validate-ConfigurationPath -Path $restorePath
        if (-not $validationResult.IsValid) {
            Remove-Item -Path $restorePath -Recurse -Force -ErrorAction SilentlyContinue
            throw "Restored configuration validation failed: $($validationResult.Errors -join '; ')"
        }

        # Add/update configuration in registry
        $restoredConfig = @{
            name = $RestoreAsName
            description = "Restored from backup: $BackupName"
            path = $restorePath
            type = 'restored'
            originalName = $metadata.originalName
            restoredFrom = $BackupName
            restoredDate = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
            environments = @('dev', 'staging', 'prod')  # Default environments
            lastValidated = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        }

        if ($registry.configurations.PSObject.Properties[$RestoreAsName]) {
            $registry.configurations.$RestoreAsName = $restoredConfig
        } else {
            $registry.configurations | Add-Member -MemberType NoteProperty -Name $RestoreAsName -Value $restoredConfig
        }

        Set-ConfigurationRegistry -Registry $registry

        Write-CustomLog -Level 'SUCCESS' -Message "Configuration restored successfully as '$RestoreAsName'"

        $result = @{
            Success = $true
            BackupName = $BackupName
            RestoredName = $RestoreAsName
            RestorePath = $restorePath
            OriginalName = $metadata.originalName
            ValidationResult = $validationResult
        }

        # Set as current if requested
        if ($SetAsCurrent) {
            $switchResult = Switch-ConfigurationSet -ConfigurationName $RestoreAsName -Environment 'dev'
            $result.SwitchResult = $switchResult
        }

        return $result

    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to restore configuration from backup: $_"
        return @{
            Success = $false
            Error = $_.Exception.Message
            BackupName = $BackupName
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

function Test-EnvironmentCompatibility {
    param(
        [string]$ConfigurationName,
        [string]$Environment
    )

    $warnings = @()
    $blockingIssues = @()

    try {
        $registry = Get-ConfigurationRegistry
        $config = $registry.configurations.$ConfigurationName

        # Check if environment is supported by configuration
        if ($config.environments -and $Environment -notin $config.environments) {
            $blockingIssues += "Environment '$Environment' is not supported by configuration '$ConfigurationName'"
        }

        # Check platform compatibility
        $currentPlatform = if ($IsWindows) { 'Windows' } elseif ($IsLinux) { 'Linux' } else { 'macOS' }
        if ($config.supportedPlatforms -and $currentPlatform -notin $config.supportedPlatforms) {
            $warnings += "Configuration may not be fully compatible with platform '$currentPlatform'"
        }

        # Check version compatibility
        if ($config.requiredVersion) {
            $currentVersion = '1.0.0'  # This would be dynamic in real implementation
            if ([version]$currentVersion -lt [version]$config.requiredVersion) {
                $blockingIssues += "Configuration requires version $($config.requiredVersion) or higher, current version is $currentVersion"
            }
        }

        # Check dependencies
        if ($config.dependencies) {
            foreach ($dependency in $config.dependencies) {
                # Check if dependency is available
                if (-not (Test-ConfigurationDependency -Dependency $dependency)) {
                    $warnings += "Configuration dependency '$dependency' may not be available"
                }
            }
        }

        return @{
            IsCompatible = ($blockingIssues.Count -eq 0)
            Warnings = $warnings
            BlockingIssues = $blockingIssues
        }

    } catch {
        return @{
            IsCompatible = $false
            Warnings = @()
            BlockingIssues = @("Error checking compatibility: $($_.Exception.Message)")
        }
    }
}

function Test-ConfigurationDependency {
    param([string]$Dependency)

    # Basic dependency checking - this could be expanded
    switch ($Dependency.ToLower()) {
        'git' { return (Get-Command git -ErrorAction SilentlyContinue) -ne $null }
        'powershell' { return $true }  # Always available in this context
        'docker' { return (Get-Command docker -ErrorAction SilentlyContinue) -ne $null }
        'terraform' { return (Get-Command terraform -ErrorAction SilentlyContinue) -ne $null }
        'tofu' { return (Get-Command tofu -ErrorAction SilentlyContinue) -ne $null }
        default { return $true }  # Unknown dependencies assumed available
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

function Export-ConfigurationSet {
    <#
    .SYNOPSIS
        Exports a configuration set to a file or archive
    .DESCRIPTION
        Exports a configuration set along with its environments and settings to a portable format
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ConfigurationName,

        [Parameter(Mandatory)]
        [string]$ExportPath,

        [ValidateSet('json', 'archive', 'yaml')]
        [string]$Format = 'json',

        [string[]]$IncludeEnvironments = @(),

        [switch]$IncludeSecrets = $false,

        [switch]$Compress = $false
    )

    try {
        Write-CustomLog -Level 'INFO' -Message "Exporting configuration set: $ConfigurationName"

        $registry = Get-ConfigurationRegistry
        
        if (-not $registry.configurations.PSObject.Properties[$ConfigurationName]) {
            throw "Configuration '$ConfigurationName' not found"
        }

        $config = $registry.configurations.$ConfigurationName

        # Prepare export data
        $exportData = @{
            name = $ConfigurationName
            configuration = $config
            environments = @{}
            metadata = @{
                exportedDate = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
                exportedBy = $env:USERNAME
                format = $Format
                includeSecrets = $IncludeSecrets
            }
        }

        # Include specified environments or all if none specified
        $environmentsToInclude = if ($IncludeEnvironments.Count -gt 0) { $IncludeEnvironments } else { $config.environments }
        
        foreach ($envName in $environmentsToInclude) {
            if ($registry.environments.PSObject.Properties[$envName]) {
                $exportData.environments[$envName] = $registry.environments.$envName
            }
        }

        # Export based on format
        switch ($Format) {
            'json' {
                $exportData | ConvertTo-Json -Depth 10 | Set-Content -Path $ExportPath
            }
            'archive' {
                # Create temporary JSON file then compress
                $tempFile = [System.IO.Path]::GetTempFileName()
                $exportData | ConvertTo-Json -Depth 10 | Set-Content -Path $tempFile
                
                if ($Compress) {
                    Compress-Archive -Path $tempFile -DestinationPath $ExportPath -Force
                } else {
                    Copy-Item -Path $tempFile -Destination $ExportPath -Force
                }
                
                Remove-Item -Path $tempFile -Force
            }
            'yaml' {
                # Basic YAML export (simplified)
                $yamlContent = "# Configuration Export: $ConfigurationName`n"
                $yamlContent += "name: $ConfigurationName`n"
                $yamlContent += "exported: $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))`n"
                $yamlContent += "environments:`n"
                
                foreach ($environment in $exportData.environments.Keys) {
                    $yamlContent += "  ${environment}:`n"
                    $yamlContent += "    name: $($exportData.environments[$environment].name)`n"
                    $yamlContent += "    description: $($exportData.environments[$environment].description)`n"
                }
                
                Set-Content -Path $ExportPath -Value $yamlContent
            }
        }

        Write-CustomLog -Level 'SUCCESS' -Message "Configuration exported to: $ExportPath"

        return @{
            Success = $true
            ConfigurationName = $ConfigurationName
            ExportPath = $ExportPath
            Format = $Format
            EnvironmentsIncluded = $environmentsToInclude
            ExportSize = (Get-Item $ExportPath).Length
        }

    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to export configuration: $_"
        return @{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

function Import-ConfigurationSet {
    <#
    .SYNOPSIS
        Imports a configuration set from a file or archive
    .DESCRIPTION
        Imports a previously exported configuration set into the carousel
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ImportPath,

        [string]$ImportAsName,

        [switch]$OverwriteExisting = $false,

        [switch]$ValidateAfterImport = $true
    )

    try {
        Write-CustomLog -Level 'INFO' -Message "Importing configuration set from: $ImportPath"

        if (-not (Test-Path $ImportPath)) {
            throw "Import file not found: $ImportPath"
        }

        # Read import data
        $importData = Get-Content -Path $ImportPath -Raw | ConvertFrom-Json

        $configName = $ImportAsName ?? $importData.name
        
        $registry = Get-ConfigurationRegistry

        # Check if configuration already exists
        if ($registry.configurations.PSObject.Properties[$configName] -and -not $OverwriteExisting) {
            throw "Configuration '$configName' already exists. Use -OverwriteExisting to replace it."
        }

        # Import configuration
        $registry.configurations.$configName = $importData.configuration
        
        # Import environments
        foreach ($envName in $importData.environments.Keys) {
            $registry.environments.$envName = $importData.environments[$envName]
        }

        Set-ConfigurationRegistry -Registry $registry

        # Validate imported configuration
        if ($ValidateAfterImport) {
            $validationResult = Validate-ConfigurationSet -ConfigurationName $configName
            if (-not $validationResult.IsValid) {
                Write-CustomLog -Level 'WARNING' -Message "Imported configuration has validation warnings: $($validationResult.Warnings -join '; ')"
            }
        }

        Write-CustomLog -Level 'SUCCESS' -Message "Configuration imported successfully as: $configName"

        return @{
            Success = $true
            ConfigurationName = $configName
            ImportPath = $ImportPath
            EnvironmentsImported = $importData.environments.Keys
            ValidationResult = $validationResult
        }

    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to import configuration: $_"
        return @{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

function New-ConfigurationEnvironment {
    <#
    .SYNOPSIS
        Creates a new environment configuration
    .DESCRIPTION
        Creates a new environment with specified settings and security policies
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$EnvironmentName,

        [string]$Description,

        [hashtable]$Settings = @{},

        [hashtable]$SecurityPolicy = @{},

        [switch]$SetAsCurrent = $false
    )

    try {
        Write-CustomLog -Level 'INFO' -Message "Creating new environment: $EnvironmentName"

        $registry = Get-ConfigurationRegistry

        # Check if environment already exists
        if ($registry.environments.PSObject.Properties[$EnvironmentName]) {
            throw "Environment '$EnvironmentName' already exists"
        }

        # Create environment
        $newEnvironment = @{
            name = $EnvironmentName
            description = $Description ?? "Environment: $EnvironmentName"
            settings = $Settings
            securityPolicy = $SecurityPolicy
            created = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
            createdBy = $env:USERNAME
        }

        $registry.environments.$EnvironmentName = $newEnvironment

        # Set as current if requested
        if ($SetAsCurrent) {
            $registry.currentEnvironment = $EnvironmentName
        }

        Set-ConfigurationRegistry -Registry $registry

        Write-CustomLog -Level 'SUCCESS' -Message "Environment '$EnvironmentName' created successfully"

        return @{
            Success = $true
            EnvironmentName = $EnvironmentName
            Description = $Description
            IsCurrentEnvironment = $SetAsCurrent
        }

    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to create environment: $_"
        return @{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

function Set-ConfigurationEnvironment {
    <#
    .SYNOPSIS
        Sets the current active environment
    .DESCRIPTION
        Changes the current active environment for configuration operations
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$EnvironmentName,

        [switch]$Validate = $true
    )

    try {
        Write-CustomLog -Level 'INFO' -Message "Setting current environment to: $EnvironmentName"

        $registry = Get-ConfigurationRegistry

        # Check if environment exists
        if (-not $registry.environments.PSObject.Properties[$EnvironmentName]) {
            throw "Environment '$EnvironmentName' not found"
        }

        # Validate environment compatibility if requested
        if ($Validate) {
            $validationResult = Test-EnvironmentCompatibility -ConfigurationName $registry.currentConfiguration -Environment $EnvironmentName
            if (-not $validationResult.IsCompatible) {
                Write-CustomLog -Level 'WARNING' -Message "Environment compatibility issues detected: $($validationResult.BlockingIssues -join '; ')"
            }
        }

        # Set current environment
        $previousEnvironment = $registry.currentEnvironment
        $registry.currentEnvironment = $EnvironmentName

        Set-ConfigurationRegistry -Registry $registry

        Write-CustomLog -Level 'SUCCESS' -Message "Current environment changed from '$previousEnvironment' to '$EnvironmentName'"

        return @{
            Success = $true
            PreviousEnvironment = $previousEnvironment
            CurrentEnvironment = $EnvironmentName
        }

    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to set environment: $_"
        return @{
            Success = $false
            Error = $_.Exception.Message
        }
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
    'Sync-ConfigurationRepository',
    'Get-CurrentConfiguration',
    'Backup-CurrentConfiguration',
    'Restore-ConfigurationBackup',
    'Validate-ConfigurationSet',
    'Export-ConfigurationSet',
    'Import-ConfigurationSet',
    'New-ConfigurationEnvironment',
    'Set-ConfigurationEnvironment'
)

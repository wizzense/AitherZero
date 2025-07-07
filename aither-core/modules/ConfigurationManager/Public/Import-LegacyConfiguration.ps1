function Import-LegacyConfiguration {
    <#
    .SYNOPSIS
        Imports configurations from legacy ConfigurationCore, ConfigurationCarousel, and ConfigurationRepository modules
    .DESCRIPTION
        Migrates existing configurations from the separate modules into the unified Configuration Manager system
    .PARAMETER SourceModule
        Specific legacy module to import from (ConfigurationCore, ConfigurationCarousel, ConfigurationRepository, All)
    .PARAMETER BackupExisting
        Create backup of existing unified configuration before importing
    .PARAMETER MergeStrategy
        How to handle conflicts when merging configurations (Overwrite, Preserve, Prompt)
    .PARAMETER Force
        Force import even if compatibility issues are detected
    .EXAMPLE
        Import-LegacyConfiguration -SourceModule All -BackupExisting
        
        Imports all legacy configurations with backup
    .EXAMPLE
        Import-LegacyConfiguration -SourceModule ConfigurationCore -MergeStrategy Preserve
        
        Imports only ConfigurationCore settings, preserving existing values
    #>
    [CmdletBinding()]
    param(
        [ValidateSet('ConfigurationCore', 'ConfigurationCarousel', 'ConfigurationRepository', 'All')]
        [string]$SourceModule = 'All',
        
        [switch]$BackupExisting,
        
        [ValidateSet('Overwrite', 'Preserve', 'Prompt')]
        [string]$MergeStrategy = 'Prompt',
        
        [switch]$Force
    )
    
    try {
        Write-ConfigurationLog -Level 'INFO' -Message "Starting legacy configuration import from: $SourceModule"
        
        $importResults = @{
            Success = $true
            SourceModule = $SourceModule
            StartTime = Get-Date
            EndTime = $null
            BackupPath = $null
            ImportedModules = @()
            Conflicts = @()
            Errors = @()
            Summary = @{}
        }
        
        # Create backup if requested
        if ($BackupExisting) {
            try {
                $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
                $backupPath = "$($script:UnifiedConfigurationStore.StorePath).legacy-backup.$timestamp"
                
                if (Test-Path $script:UnifiedConfigurationStore.StorePath) {
                    Copy-Item $script:UnifiedConfigurationStore.StorePath $backupPath
                    $importResults.BackupPath = $backupPath
                    Write-ConfigurationLog -Level 'SUCCESS' -Message "Backup created: $backupPath"
                }
            } catch {
                Write-ConfigurationLog -Level 'WARNING' -Message "Failed to create backup: $_"
                if (-not $Force) {
                    throw "Backup creation failed and -Force not specified"
                }
            }
        }
        
        # Import from ConfigurationCore
        if ($SourceModule -in @('ConfigurationCore', 'All')) {
            $coreResult = Import-ConfigurationCoreSettings -MergeStrategy $MergeStrategy -Force:$Force
            $importResults.ImportedModules += 'ConfigurationCore'
            $importResults.Summary.ConfigurationCore = $coreResult
            
            if ($coreResult.Conflicts) {
                $importResults.Conflicts += $coreResult.Conflicts
            }
            if ($coreResult.Errors) {
                $importResults.Errors += $coreResult.Errors
            }
        }
        
        # Import from ConfigurationCarousel
        if ($SourceModule -in @('ConfigurationCarousel', 'All')) {
            $carouselResult = Import-ConfigurationCarouselSettings -MergeStrategy $MergeStrategy -Force:$Force
            $importResults.ImportedModules += 'ConfigurationCarousel'
            $importResults.Summary.ConfigurationCarousel = $carouselResult
            
            if ($carouselResult.Conflicts) {
                $importResults.Conflicts += $carouselResult.Conflicts
            }
            if ($carouselResult.Errors) {
                $importResults.Errors += $carouselResult.Errors
            }
        }
        
        # Import from ConfigurationRepository
        if ($SourceModule -in @('ConfigurationRepository', 'All')) {
            $repositoryResult = Import-ConfigurationRepositorySettings -MergeStrategy $MergeStrategy -Force:$Force
            $importResults.ImportedModules += 'ConfigurationRepository'
            $importResults.Summary.ConfigurationRepository = $repositoryResult
            
            if ($repositoryResult.Conflicts) {
                $importResults.Conflicts += $repositoryResult.Conflicts
            }
            if ($repositoryResult.Errors) {
                $importResults.Errors += $repositoryResult.Errors
            }
        }
        
        # Save the merged configuration
        try {
            Save-UnifiedConfiguration
            Write-ConfigurationLog -Level 'SUCCESS' -Message "Unified configuration saved after import"
        } catch {
            $importResults.Errors += "Failed to save unified configuration: $_"
            Write-ConfigurationLog -Level 'ERROR' -Message "Failed to save unified configuration: $_"
        }
        
        $importResults.EndTime = Get-Date
        $importResults.Duration = $importResults.EndTime - $importResults.StartTime
        
        # Determine overall success
        if ($importResults.Errors.Count -gt 0) {
            $importResults.Success = $false
        }
        
        # Log summary
        $summary = "Legacy import completed. Modules: $($importResults.ImportedModules -join ', ')"
        if ($importResults.Conflicts.Count -gt 0) {
            $summary += " | Conflicts: $($importResults.Conflicts.Count)"
        }
        if ($importResults.Errors.Count -gt 0) {
            $summary += " | Errors: $($importResults.Errors.Count)"
        }
        
        if ($importResults.Success) {
            Write-ConfigurationLog -Level 'SUCCESS' -Message $summary
        } else {
            Write-ConfigurationLog -Level 'WARNING' -Message $summary
        }
        
        return $importResults
        
    } catch {
        Write-ConfigurationLog -Level 'ERROR' -Message "Legacy configuration import failed: $_"
        
        return @{
            Success = $false
            Error = $_.Exception.Message
            SourceModule = $SourceModule
            StartTime = Get-Date
        }
    }
}

# Helper functions for importing from specific modules
function Import-ConfigurationCoreSettings {
    param(
        [string]$MergeStrategy,
        [switch]$Force
    )
    
    try {
        $result = @{
            Success = $true
            ImportedSettings = @()
            Conflicts = @()
            Errors = @()
        }
        
        # Try to access ConfigurationCore module data
        if (Get-Module 'ConfigurationCore' -ErrorAction SilentlyContinue) {
            
            # Import registered modules if available
            if (Get-Command 'Get-ModuleConfiguration' -ErrorAction SilentlyContinue) {
                try {
                    # This would typically enumerate all registered modules
                    # For now, we'll check for common configuration patterns
                    $coreConfigPath = if ($IsWindows) { 
                        Join-Path $env:APPDATA 'AitherZero/configuration.json' 
                    } else { 
                        Join-Path $env:HOME '.aitherzero/configuration.json' 
                    }
                    
                    if (Test-Path $coreConfigPath) {
                        $coreConfig = Get-Content $coreConfigPath -Raw | ConvertFrom-Json -AsHashtable
                        
                        # Merge modules
                        if ($coreConfig.Modules) {
                            foreach ($moduleName in $coreConfig.Modules.Keys) {
                                $existingModule = $script:UnifiedConfigurationStore.Modules[$moduleName]
                                $importedModule = $coreConfig.Modules[$moduleName]
                                
                                if ($existingModule) {
                                    $conflict = @{
                                        Type = 'Module'
                                        Name = $moduleName
                                        Source = 'ConfigurationCore'
                                        Action = $null
                                    }
                                    
                                    switch ($MergeStrategy) {
                                        'Overwrite' {
                                            $script:UnifiedConfigurationStore.Modules[$moduleName] = $importedModule
                                            $conflict.Action = 'Overwritten'
                                            $result.ImportedSettings += "Module: $moduleName (overwritten)"
                                        }
                                        'Preserve' {
                                            $conflict.Action = 'Preserved existing'
                                            $result.ImportedSettings += "Module: $moduleName (preserved existing)"
                                        }
                                        'Prompt' {
                                            $conflict.Action = 'Requires user decision'
                                            Write-ConfigurationLog -Level 'WARNING' -Message "Conflict detected for module '$moduleName' - requires user decision"
                                        }
                                    }
                                    
                                    $result.Conflicts += $conflict
                                } else {
                                    $script:UnifiedConfigurationStore.Modules[$moduleName] = $importedModule
                                    $result.ImportedSettings += "Module: $moduleName (new)"
                                }
                            }
                        }
                        
                        # Merge environments
                        if ($coreConfig.Environments) {
                            foreach ($envName in $coreConfig.Environments.Keys) {
                                if (-not $script:UnifiedConfigurationStore.Environments[$envName]) {
                                    $script:UnifiedConfigurationStore.Environments[$envName] = $coreConfig.Environments[$envName]
                                    $result.ImportedSettings += "Environment: $envName"
                                }
                            }
                        }
                        
                        # Merge schemas
                        if ($coreConfig.Schemas) {
                            foreach ($schemaName in $coreConfig.Schemas.Keys) {
                                if (-not $script:UnifiedConfigurationStore.Schemas[$schemaName]) {
                                    $script:UnifiedConfigurationStore.Schemas[$schemaName] = $coreConfig.Schemas[$schemaName]
                                    $result.ImportedSettings += "Schema: $schemaName"
                                }
                            }
                        }
                        
                        # Update security settings if more restrictive
                        if ($coreConfig.Security) {
                            $currentSecurity = $script:UnifiedConfigurationStore.Security
                            if ($coreConfig.Security.EncryptionEnabled -and -not $currentSecurity.EncryptionEnabled) {
                                $currentSecurity.EncryptionEnabled = $true
                                $result.ImportedSettings += "Security: Enabled encryption"
                            }
                            if ($coreConfig.Security.HashValidation -and -not $currentSecurity.HashValidation) {
                                $currentSecurity.HashValidation = $true
                                $result.ImportedSettings += "Security: Enabled hash validation"
                            }
                        }
                        
                        Write-ConfigurationLog -Level 'SUCCESS' -Message "ConfigurationCore settings imported successfully"
                    } else {
                        Write-ConfigurationLog -Level 'INFO' -Message "No ConfigurationCore configuration file found"
                    }
                    
                } catch {
                    $result.Errors += "Failed to import ConfigurationCore settings: $_"
                    Write-ConfigurationLog -Level 'WARNING' -Message "Failed to import ConfigurationCore settings: $_"
                }
            }
        } else {
            Write-ConfigurationLog -Level 'INFO' -Message "ConfigurationCore module not available for import"
        }
        
        return $result
        
    } catch {
        return @{
            Success = $false
            Error = $_.Exception.Message
            ImportedSettings = @()
            Conflicts = @()
            Errors = @("Import failed: $($_.Exception.Message)")
        }
    }
}

function Import-ConfigurationCarouselSettings {
    param(
        [string]$MergeStrategy,
        [switch]$Force
    )
    
    try {
        $result = @{
            Success = $true
            ImportedSettings = @()
            Conflicts = @()
            Errors = @()
        }
        
        # Try to access ConfigurationCarousel registry
        $carouselRegistryPath = Join-Path $script:ProjectRoot "configs/carousel/carousel-registry.json"
        
        if (Test-Path $carouselRegistryPath) {
            try {
                $carouselRegistry = Get-Content $carouselRegistryPath -Raw | ConvertFrom-Json -AsHashtable
                
                # Merge carousel configurations
                if ($carouselRegistry.configurations) {
                    foreach ($configName in $carouselRegistry.configurations.Keys) {
                        $existingConfig = $script:UnifiedConfigurationStore.Carousel.Configurations[$configName]
                        $importedConfig = $carouselRegistry.configurations[$configName]
                        
                        if ($existingConfig) {
                            $conflict = @{
                                Type = 'CarouselConfiguration'
                                Name = $configName
                                Source = 'ConfigurationCarousel'
                                Action = $null
                            }
                            
                            switch ($MergeStrategy) {
                                'Overwrite' {
                                    $script:UnifiedConfigurationStore.Carousel.Configurations[$configName] = $importedConfig
                                    $conflict.Action = 'Overwritten'
                                    $result.ImportedSettings += "Carousel Config: $configName (overwritten)"
                                }
                                'Preserve' {
                                    $conflict.Action = 'Preserved existing'
                                    $result.ImportedSettings += "Carousel Config: $configName (preserved existing)"
                                }
                                'Prompt' {
                                    $conflict.Action = 'Requires user decision'
                                    Write-ConfigurationLog -Level 'WARNING' -Message "Conflict detected for carousel configuration '$configName'"
                                }
                            }
                            
                            $result.Conflicts += $conflict
                        } else {
                            $script:UnifiedConfigurationStore.Carousel.Configurations[$configName] = $importedConfig
                            $result.ImportedSettings += "Carousel Config: $configName (new)"
                        }
                    }
                }
                
                # Import current configuration and environment if not set
                if ($carouselRegistry.currentConfiguration -and 
                    $script:UnifiedConfigurationStore.Carousel.CurrentConfiguration -eq 'default') {
                    $script:UnifiedConfigurationStore.Carousel.CurrentConfiguration = $carouselRegistry.currentConfiguration
                    $result.ImportedSettings += "Current Configuration: $($carouselRegistry.currentConfiguration)"
                }
                
                if ($carouselRegistry.currentEnvironment -and 
                    $script:UnifiedConfigurationStore.Carousel.CurrentEnvironment -eq 'dev') {
                    $script:UnifiedConfigurationStore.Carousel.CurrentEnvironment = $carouselRegistry.currentEnvironment
                    $result.ImportedSettings += "Current Environment: $($carouselRegistry.currentEnvironment)"
                }
                
                # Import environment definitions
                if ($carouselRegistry.environments) {
                    foreach ($envName in $carouselRegistry.environments.Keys) {
                        if (-not $script:UnifiedConfigurationStore.Environments[$envName]) {
                            $envConfig = $carouselRegistry.environments[$envName]
                            $script:UnifiedConfigurationStore.Environments[$envName] = @{
                                Name = $envName
                                Description = $envConfig.description ?? "Imported from ConfigurationCarousel"
                                Settings = $envConfig.securityPolicy ?? @{}
                                Created = Get-Date
                                CreatedBy = $env:USERNAME
                                ImportedFrom = 'ConfigurationCarousel'
                            }
                            $result.ImportedSettings += "Environment: $envName"
                        }
                    }
                }
                
                Write-ConfigurationLog -Level 'SUCCESS' -Message "ConfigurationCarousel settings imported successfully"
                
            } catch {
                $result.Errors += "Failed to parse ConfigurationCarousel registry: $_"
                Write-ConfigurationLog -Level 'WARNING' -Message "Failed to parse ConfigurationCarousel registry: $_"
            }
        } else {
            Write-ConfigurationLog -Level 'INFO' -Message "No ConfigurationCarousel registry found"
        }
        
        return $result
        
    } catch {
        return @{
            Success = $false
            Error = $_.Exception.Message
            ImportedSettings = @()
            Conflicts = @()
            Errors = @("Import failed: $($_.Exception.Message)")
        }
    }
}

function Import-ConfigurationRepositorySettings {
    param(
        [string]$MergeStrategy,
        [switch]$Force
    )
    
    try {
        $result = @{
            Success = $true
            ImportedSettings = @()
            Conflicts = @()
            Errors = @()
        }
        
        # ConfigurationRepository is typically stateless, but we can check for active repositories
        # and import any custom templates or settings
        
        if (Get-Module 'ConfigurationRepository' -ErrorAction SilentlyContinue) {
            # Look for any repository-specific configuration files
            $repoConfigPaths = @(
                (Join-Path $script:ProjectRoot "configs/repositories"),
                (Join-Path $script:ProjectRoot "configs/templates")
            )
            
            foreach ($configPath in $repoConfigPaths) {
                if (Test-Path $configPath) {
                    try {
                        $configFiles = Get-ChildItem $configPath -Filter "*.json" -ErrorAction SilentlyContinue
                        
                        foreach ($configFile in $configFiles) {
                            $config = Get-Content $configFile.FullName -Raw | ConvertFrom-Json -AsHashtable
                            
                            # Import as repository configuration
                            $repoName = [System.IO.Path]::GetFileNameWithoutExtension($configFile.Name)
                            $script:UnifiedConfigurationStore.Repository.ActiveRepositories[$repoName] = $config
                            $result.ImportedSettings += "Repository Config: $repoName"
                        }
                        
                    } catch {
                        $result.Errors += "Failed to import repository config from $configPath`: $_"
                        Write-ConfigurationLog -Level 'WARNING' -Message "Failed to import repository config: $_"
                    }
                }
            }
            
            # Import sync settings if available
            $syncConfigPath = Join-Path $script:ProjectRoot "configs/repository-sync.json"
            if (Test-Path $syncConfigPath) {
                try {
                    $syncConfig = Get-Content $syncConfigPath -Raw | ConvertFrom-Json -AsHashtable
                    
                    foreach ($setting in $syncConfig.Keys) {
                        if ($script:UnifiedConfigurationStore.Repository.SyncSettings.ContainsKey($setting)) {
                            $existingValue = $script:UnifiedConfigurationStore.Repository.SyncSettings[$setting]
                            $importedValue = $syncConfig[$setting]
                            
                            if ($existingValue -ne $importedValue) {
                                switch ($MergeStrategy) {
                                    'Overwrite' {
                                        $script:UnifiedConfigurationStore.Repository.SyncSettings[$setting] = $importedValue
                                        $result.ImportedSettings += "Sync Setting: $setting (overwritten)"
                                    }
                                    'Preserve' {
                                        $result.ImportedSettings += "Sync Setting: $setting (preserved existing)"
                                    }
                                    'Prompt' {
                                        Write-ConfigurationLog -Level 'WARNING' -Message "Conflict detected for sync setting '$setting'"
                                        $result.Conflicts += @{
                                            Type = 'SyncSetting'
                                            Name = $setting
                                            Source = 'ConfigurationRepository'
                                            Action = 'Requires user decision'
                                        }
                                    }
                                }
                            }
                        } else {
                            $script:UnifiedConfigurationStore.Repository.SyncSettings[$setting] = $syncConfig[$setting]
                            $result.ImportedSettings += "Sync Setting: $setting (new)"
                        }
                    }
                    
                } catch {
                    $result.Errors += "Failed to import sync settings: $_"
                    Write-ConfigurationLog -Level 'WARNING' -Message "Failed to import sync settings: $_"
                }
            }
            
            Write-ConfigurationLog -Level 'SUCCESS' -Message "ConfigurationRepository settings imported successfully"
            
        } else {
            Write-ConfigurationLog -Level 'INFO' -Message "ConfigurationRepository module not available for import"
        }
        
        return $result
        
    } catch {
        return @{
            Success = $false
            Error = $_.Exception.Message
            ImportedSettings = @()
            Conflicts = @()
            Errors = @("Import failed: $($_.Exception.Message)")
        }
    }
}
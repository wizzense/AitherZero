function Set-UnifiedConfiguration {
    <#
    .SYNOPSIS
        Sets unified configuration across all subsystems
    .DESCRIPTION
        Updates configuration data in ConfigurationCore, ConfigurationCarousel, and ConfigurationRepository
        with automatic conflict resolution and validation
    .PARAMETER Module
        Module name for module-specific configuration
    .PARAMETER Configuration
        Configuration data to set
    .PARAMETER Environment
        Environment to apply configuration to
    .PARAMETER ConfigurationSet
        Configuration set in carousel to update
    .PARAMETER MergeStrategy
        How to handle conflicts (Overwrite, Merge, Preserve)
    .PARAMETER Validate
        Validate configuration against registered schemas
    .PARAMETER BackupBeforeChange
        Create backup before making changes
    .EXAMPLE
        Set-UnifiedConfiguration -Module "LabRunner" -Configuration @{ MaxConcurrency = 4 }
        
        Sets LabRunner module configuration
    .EXAMPLE
        Set-UnifiedConfiguration -Environment "prod" -Configuration @{ 
            LogLevel = "Error"; 
            DebugMode = $false 
        } -BackupBeforeChange
        
        Sets production environment configuration with backup
    #>
    [CmdletBinding(DefaultParameterSetName = 'Module', SupportsShouldProcess)]
    param(
        [Parameter(ParameterSetName = 'Module', Mandatory)]
        [string]$Module,
        
        [Parameter(Mandatory)]
        [hashtable]$Configuration,
        
        [Parameter(ParameterSetName = 'Environment', Mandatory)]
        [string]$Environment,
        
        [Parameter(ParameterSetName = 'ConfigurationSet', Mandatory)]
        [string]$ConfigurationSet,
        
        [ValidateSet('Overwrite', 'Merge', 'Preserve')]
        [string]$MergeStrategy = 'Merge',
        
        [switch]$Validate,
        [switch]$BackupBeforeChange,
        [switch]$Force
    )
    
    try {
        Write-ConfigurationLog -Level 'INFO' -Message "Setting unified configuration (ParameterSet: $($PSCmdlet.ParameterSetName))"
        
        if (-not $script:ModuleInitialized) {
            throw "Configuration Manager not initialized. Run Initialize-ConfigurationManager first."
        }
        
        $result = @{
            Success = $true
            Timestamp = Get-Date
            ParameterSet = $PSCmdlet.ParameterSetName
            Changes = @()
            Conflicts = @()
            BackupPath = $null
        }
        
        # Create backup if requested
        if ($BackupBeforeChange) {
            try {
                $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
                $backupPath = "$($script:UnifiedConfigurationStore.StorePath).backup.$timestamp"
                Save-UnifiedConfiguration
                Copy-Item $script:UnifiedConfigurationStore.StorePath $backupPath
                $result.BackupPath = $backupPath
                Write-ConfigurationLog -Level 'SUCCESS' -Message "Backup created: $backupPath"
            } catch {
                Write-ConfigurationLog -Level 'WARNING' -Message "Failed to create backup: $_"
                if (-not $Force) {
                    throw "Backup creation failed and -Force not specified"
                }
            }
        }
        
        # Validate configuration if requested
        if ($Validate) {
            $validationResult = Test-ConfigurationData -Configuration $Configuration -ParameterSet $PSCmdlet.ParameterSetName -Module $Module -Environment $Environment
            if (-not $validationResult.IsValid) {
                if (-not $Force) {
                    throw "Configuration validation failed: $($validationResult.Errors -join '; ')"
                } else {
                    Write-ConfigurationLog -Level 'WARNING' -Message "Validation failed but -Force specified: $($validationResult.Errors -join '; ')"
                }
            }
        }
        
        # Process based on parameter set
        switch ($PSCmdlet.ParameterSetName) {
            'Module' {
                if ($PSCmdlet.ShouldProcess("Module '$Module'", "Set configuration")) {
                    $existingConfig = $script:UnifiedConfigurationStore.Modules[$Module] ?? @{}
                    
                    switch ($MergeStrategy) {
                        'Overwrite' {
                            $script:UnifiedConfigurationStore.Modules[$Module] = $Configuration
                            $result.Changes += "Module '$Module' configuration overwritten"
                        }
                        
                        'Merge' {
                            $mergeResult = Merge-ConfigurationData -SourceConfiguration $Configuration -TargetConfiguration $existingConfig -ConflictStrategy 'Merge' -SourceName "User-$Module" -DeepMerge
                            $script:UnifiedConfigurationStore.Modules[$Module] = $existingConfig
                            $result.Changes += "Module '$Module' configuration merged"
                            $result.Conflicts += $mergeResult.Conflicts
                        }
                        
                        'Preserve' {
                            $mergeResult = Merge-ConfigurationData -SourceConfiguration $Configuration -TargetConfiguration $existingConfig -ConflictStrategy 'Preserve' -SourceName "User-$Module"
                            $script:UnifiedConfigurationStore.Modules[$Module] = $existingConfig
                            $result.Changes += "Module '$Module' configuration preserved existing values"
                            $result.Conflicts += $mergeResult.Conflicts
                        }
                    }
                    
                    # Publish module configuration change event
                    Publish-ConfigurationEvent -EventName 'ModuleConfigurationChanged' -EventData @{
                        Module = $Module
                        MergeStrategy = $MergeStrategy
                        ChangeCount = $Configuration.Keys.Count
                    } -Priority 'Normal'
                }
            }
            
            'Environment' {
                if ($PSCmdlet.ShouldProcess("Environment '$Environment'", "Set configuration")) {
                    if (-not $script:UnifiedConfigurationStore.Environments.ContainsKey($Environment)) {
                        # Create new environment
                        $script:UnifiedConfigurationStore.Environments[$Environment] = @{
                            Name = $Environment
                            Description = "Environment created via Set-UnifiedConfiguration"
                            Settings = @{}
                            Created = Get-Date
                            CreatedBy = $env:USERNAME
                        }
                        $result.Changes += "Environment '$Environment' created"
                    }
                    
                    $existingEnvConfig = $script:UnifiedConfigurationStore.Environments[$Environment].Settings
                    
                    switch ($MergeStrategy) {
                        'Overwrite' {
                            $script:UnifiedConfigurationStore.Environments[$Environment].Settings = $Configuration
                            $result.Changes += "Environment '$Environment' settings overwritten"
                        }
                        
                        'Merge' {
                            $mergeResult = Merge-ConfigurationData -SourceConfiguration $Configuration -TargetConfiguration $existingEnvConfig -ConflictStrategy 'Merge' -SourceName "User-$Environment" -DeepMerge
                            $script:UnifiedConfigurationStore.Environments[$Environment].Settings = $existingEnvConfig
                            $result.Changes += "Environment '$Environment' settings merged"
                            $result.Conflicts += $mergeResult.Conflicts
                        }
                        
                        'Preserve' {
                            $mergeResult = Merge-ConfigurationData -SourceConfiguration $Configuration -TargetConfiguration $existingEnvConfig -ConflictStrategy 'Preserve' -SourceName "User-$Environment"
                            $script:UnifiedConfigurationStore.Environments[$Environment].Settings = $existingEnvConfig
                            $result.Changes += "Environment '$Environment' settings preserved existing values"
                            $result.Conflicts += $mergeResult.Conflicts
                        }
                    }
                    
                    # Update environment metadata
                    $script:UnifiedConfigurationStore.Environments[$Environment].LastModified = Get-Date
                    $script:UnifiedConfigurationStore.Environments[$Environment].ModifiedBy = $env:USERNAME
                    
                    # Publish environment configuration change event
                    Publish-ConfigurationEvent -EventName 'EnvironmentConfigurationChanged' -EventData @{
                        Environment = $Environment
                        MergeStrategy = $MergeStrategy
                        ChangeCount = $Configuration.Keys.Count
                    } -Priority 'Normal'
                }
            }
            
            'ConfigurationSet' {
                if ($PSCmdlet.ShouldProcess("Configuration Set '$ConfigurationSet'", "Set configuration")) {
                    if (-not $script:UnifiedConfigurationStore.Carousel.Configurations.ContainsKey($ConfigurationSet)) {
                        # Create new configuration set
                        $script:UnifiedConfigurationStore.Carousel.Configurations[$ConfigurationSet] = @{
                            name = $ConfigurationSet
                            description = "Configuration set created via Set-UnifiedConfiguration"
                            type = 'custom'
                            environments = @('dev', 'staging', 'prod')
                            created = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
                        }
                        $result.Changes += "Configuration set '$ConfigurationSet' created"
                    }
                    
                    $existingCarouselConfig = $script:UnifiedConfigurationStore.Carousel.Configurations[$ConfigurationSet]
                    
                    switch ($MergeStrategy) {
                        'Overwrite' {
                            # Preserve essential carousel properties
                            $preservedKeys = @('name', 'type', 'created')
                            foreach ($key in $preservedKeys) {
                                if ($existingCarouselConfig.ContainsKey($key)) {
                                    $Configuration[$key] = $existingCarouselConfig[$key]
                                }
                            }
                            $script:UnifiedConfigurationStore.Carousel.Configurations[$ConfigurationSet] = $Configuration
                            $result.Changes += "Configuration set '$ConfigurationSet' overwritten (preserved essential properties)"
                        }
                        
                        'Merge' {
                            $mergeResult = Merge-ConfigurationData -SourceConfiguration $Configuration -TargetConfiguration $existingCarouselConfig -ConflictStrategy 'Merge' -SourceName "User-$ConfigurationSet" -DeepMerge
                            $script:UnifiedConfigurationStore.Carousel.Configurations[$ConfigurationSet] = $existingCarouselConfig
                            $result.Changes += "Configuration set '$ConfigurationSet' merged"
                            $result.Conflicts += $mergeResult.Conflicts
                        }
                        
                        'Preserve' {
                            $mergeResult = Merge-ConfigurationData -SourceConfiguration $Configuration -TargetConfiguration $existingCarouselConfig -ConflictStrategy 'Preserve' -SourceName "User-$ConfigurationSet"
                            $script:UnifiedConfigurationStore.Carousel.Configurations[$ConfigurationSet] = $existingCarouselConfig
                            $result.Changes += "Configuration set '$ConfigurationSet' preserved existing values"
                            $result.Conflicts += $mergeResult.Conflicts
                        }
                    }
                    
                    # Update carousel metadata
                    $script:UnifiedConfigurationStore.Carousel.LastUpdated = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
                    
                    # Publish carousel configuration change event
                    Publish-ConfigurationEvent -EventName 'CarouselConfigurationChanged' -EventData @{
                        ConfigurationSet = $ConfigurationSet
                        MergeStrategy = $MergeStrategy
                        ChangeCount = $Configuration.Keys.Count
                    } -Priority 'Normal'
                }
            }
        }
        
        # Update global metadata
        $script:UnifiedConfigurationStore.Metadata.LastModified = Get-Date
        
        # Save changes to disk
        try {
            Save-UnifiedConfiguration
            $result.Changes += "Configuration saved to disk"
        } catch {
            Write-ConfigurationLog -Level 'ERROR' -Message "Failed to save configuration: $_"
            $result.Changes += "Warning: Configuration not saved to disk"
        }
        
        Write-ConfigurationLog -Level 'SUCCESS' -Message "Configuration updated successfully: $($result.Changes -join '; ')"
        
        return $result
        
    } catch {
        Write-ConfigurationLog -Level 'ERROR' -Message "Failed to set unified configuration: $_"
        
        return @{
            Success = $false
            Error = $_.Exception.Message
            Timestamp = Get-Date
            ParameterSet = $PSCmdlet.ParameterSetName
        }
    }
}

# Helper function for configuration validation
function Test-ConfigurationData {
    param(
        [hashtable]$Configuration,
        [string]$ParameterSet,
        [string]$Module,
        [string]$Environment
    )
    
    $validationResult = @{
        IsValid = $true
        Errors = @()
        Warnings = @()
    }
    
    try {
        # Basic validation - ensure it's a hashtable
        if (-not $Configuration -or $Configuration.GetType().Name -ne 'Hashtable') {
            $validationResult.IsValid = $false
            $validationResult.Errors += "Configuration must be a hashtable"
            return $validationResult
        }
        
        # JSON serialization test
        try {
            $json = $Configuration | ConvertTo-Json -Depth 10
            $restored = $json | ConvertFrom-Json -AsHashtable
            if (-not $restored) {
                $validationResult.IsValid = $false
                $validationResult.Errors += "Configuration failed JSON serialization test"
            }
        } catch {
            $validationResult.IsValid = $false
            $validationResult.Errors += "Configuration contains non-serializable data: $_"
        }
        
        # Parameter set specific validation
        switch ($ParameterSet) {
            'Module' {
                if ($Module) {
                    # Check if module has registered schema
                    if ($script:UnifiedConfigurationStore.Schemas.ContainsKey($Module)) {
                        $schema = $script:UnifiedConfigurationStore.Schemas[$Module]
                        $schemaValidation = Test-ConfigurationAgainstSchema -Configuration $Configuration -Schema $schema
                        if (-not $schemaValidation.IsValid) {
                            $validationResult.Warnings += $schemaValidation.Errors
                        }
                    }
                }
            }
            
            'Environment' {
                # Validate environment-specific constraints
                $reservedKeys = @('Name', 'Description', 'Created', 'CreatedBy', 'LastModified', 'ModifiedBy')
                foreach ($key in $Configuration.Keys) {
                    if ($key -in $reservedKeys) {
                        $validationResult.Warnings += "Configuration key '$key' is reserved for environment metadata"
                    }
                }
            }
            
            'ConfigurationSet' {
                # Validate carousel configuration constraints
                $requiredKeys = @('name', 'description')
                foreach ($key in $requiredKeys) {
                    if (-not $Configuration.ContainsKey($key)) {
                        $validationResult.Warnings += "Configuration set should include '$key' property"
                    }
                }
            }
        }
        
        return $validationResult
        
    } catch {
        return @{
            IsValid = $false
            Errors = @("Validation failed: $($_.Exception.Message)")
            Warnings = @()
        }
    }
}

# Helper function for schema validation
function Test-ConfigurationAgainstSchema {
    param(
        [hashtable]$Configuration,
        [hashtable]$Schema
    )
    
    $result = @{
        IsValid = $true
        Errors = @()
    }
    
    try {
        # Basic schema validation (simplified)
        if ($Schema.required) {
            foreach ($requiredKey in $Schema.required) {
                if (-not $Configuration.ContainsKey($requiredKey)) {
                    $result.IsValid = $false
                    $result.Errors += "Required key '$requiredKey' is missing"
                }
            }
        }
        
        if ($Schema.properties) {
            foreach ($key in $Configuration.Keys) {
                if ($Schema.properties.ContainsKey($key)) {
                    $propertySchema = $Schema.properties[$key]
                    $value = $Configuration[$key]
                    
                    # Type validation
                    if ($propertySchema.type) {
                        $expectedType = $propertySchema.type
                        $actualType = $value.GetType().Name
                        
                        if ($actualType -ne $expectedType -and -not ($expectedType -eq 'Object' -and $actualType -eq 'Hashtable')) {
                            $result.IsValid = $false
                            $result.Errors += "Property '$key' expected type '$expectedType' but got '$actualType'"
                        }
                    }
                }
            }
        }
        
        return $result
        
    } catch {
        return @{
            IsValid = $false
            Errors = @("Schema validation failed: $($_.Exception.Message)")
        }
    }
}
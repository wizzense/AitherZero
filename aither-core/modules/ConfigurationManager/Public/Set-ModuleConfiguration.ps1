function Set-ModuleConfiguration {
    <#
    .SYNOPSIS
        Sets configuration for a specific module (Legacy Compatibility Function)
    .DESCRIPTION
        Updates configuration data for a specified module in the unified configuration store.
        This function maintains compatibility with the original ConfigurationCore module.
    .PARAMETER ModuleName
        Name of the module to set configuration for
    .PARAMETER Configuration
        Configuration hashtable to set
    .PARAMETER Environment
        Environment to apply configuration to (if not specified, applies to module base configuration)
    .PARAMETER Merge
        Merge with existing configuration instead of replacing
    .PARAMETER Validate
        Validate configuration against module schema
    .EXAMPLE
        Set-ModuleConfiguration -ModuleName "LabRunner" -Configuration @{
            MaxConcurrency = 4
            TimeoutMinutes = 30
        }
        
        Sets LabRunner module configuration
    .EXAMPLE
        Set-ModuleConfiguration -ModuleName "PatchManager" -Configuration @{
            AutoMerge = $true
        } -Environment "prod" -Validate -Merge
        
        Merges PatchManager configuration for production environment with validation
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$ModuleName,
        
        [Parameter(Mandatory)]
        [hashtable]$Configuration,
        
        [Parameter()]
        [string]$Environment,
        
        [Parameter()]
        [switch]$Merge,
        
        [Parameter()]
        [switch]$Validate
    )
    
    try {
        Write-ConfigurationLog -Level 'INFO' -Message "Setting configuration for module: $ModuleName"
        
        if (-not $script:ModuleInitialized) {
            throw "Configuration Manager not initialized. Run Initialize-ConfigurationManager first."
        }
        
        if (-not $Configuration -or $Configuration.Count -eq 0) {
            throw "Configuration parameter cannot be empty"
        }
        
        $result = @{
            Success = $true
            ModuleName = $ModuleName
            Environment = $Environment
            Changes = @()
            ValidationResult = $null
            Timestamp = Get-Date
        }
        
        # Validate configuration if requested
        if ($Validate -and $script:UnifiedConfigurationStore.Schemas.ContainsKey($ModuleName)) {
            $schema = $script:UnifiedConfigurationStore.Schemas[$ModuleName]
            $validationResult = Test-ConfigurationAgainstSchema -Configuration $Configuration -Schema $schema
            $result.ValidationResult = $validationResult
            
            if (-not $validationResult.IsValid) {
                $errorMessage = "Configuration validation failed: $($validationResult.Errors -join '; ')"
                Write-ConfigurationLog -Level 'ERROR' -Message $errorMessage
                throw $errorMessage
            } else {
                Write-ConfigurationLog -Level 'SUCCESS' -Message "Configuration validation passed for module '$ModuleName'"
            }
        }
        
        if ($Environment) {
            # Set environment-specific configuration
            if (-not $script:UnifiedConfigurationStore.Environments.ContainsKey($Environment)) {
                # Create environment if it doesn't exist
                $script:UnifiedConfigurationStore.Environments[$Environment] = @{
                    Name = $Environment
                    Description = "Environment created by Set-ModuleConfiguration"
                    Settings = @{}
                    Created = Get-Date
                    CreatedBy = $env:USERNAME
                }
                $result.Changes += "Created environment '$Environment'"
                Write-ConfigurationLog -Level 'INFO' -Message "Created new environment: $Environment"
            }
            
            $envConfig = $script:UnifiedConfigurationStore.Environments[$Environment]
            if (-not $envConfig.Settings) {
                $envConfig.Settings = @{}
            }
            
            if ($PSCmdlet.ShouldProcess("Module '$ModuleName' in environment '$Environment'", "Set configuration")) {
                if ($Merge -and $envConfig.Settings.ContainsKey($ModuleName)) {
                    # Merge with existing environment configuration
                    $existingConfig = $envConfig.Settings[$ModuleName]
                    $mergeResult = Merge-ConfigurationData -SourceConfiguration $Configuration -TargetConfiguration $existingConfig -ConflictStrategy 'Overwrite' -SourceName "User-$ModuleName-$Environment" -DeepMerge
                    
                    $envConfig.Settings[$ModuleName] = $existingConfig
                    $result.Changes += "Merged configuration for '$ModuleName' in environment '$Environment'"
                    Write-ConfigurationLog -Level 'SUCCESS' -Message "Merged environment configuration for '$ModuleName' in '$Environment'"
                } else {
                    # Replace environment configuration
                    $envConfig.Settings[$ModuleName] = $Configuration
                    $result.Changes += "Set configuration for '$ModuleName' in environment '$Environment'"
                    Write-ConfigurationLog -Level 'SUCCESS' -Message "Set environment configuration for '$ModuleName' in '$Environment'"
                }
                
                # Update environment metadata
                $envConfig.LastModified = Get-Date
                $envConfig.ModifiedBy = $env:USERNAME
            }
            
        } else {
            # Set base module configuration
            if ($PSCmdlet.ShouldProcess("Module '$ModuleName'", "Set configuration")) {
                if ($Merge -and $script:UnifiedConfigurationStore.Modules.ContainsKey($ModuleName)) {
                    # Merge with existing module configuration
                    $existingConfig = $script:UnifiedConfigurationStore.Modules[$ModuleName]
                    $mergeResult = Merge-ConfigurationData -SourceConfiguration $Configuration -TargetConfiguration $existingConfig -ConflictStrategy 'Overwrite' -SourceName "User-$ModuleName" -DeepMerge
                    
                    $script:UnifiedConfigurationStore.Modules[$ModuleName] = $existingConfig
                    $result.Changes += "Merged base configuration for '$ModuleName'"
                    Write-ConfigurationLog -Level 'SUCCESS' -Message "Merged base configuration for '$ModuleName'"
                } else {
                    # Replace module configuration
                    $script:UnifiedConfigurationStore.Modules[$ModuleName] = $Configuration
                    $result.Changes += "Set base configuration for '$ModuleName'"
                    Write-ConfigurationLog -Level 'SUCCESS' -Message "Set base configuration for '$ModuleName'"
                }
            }
        }
        
        # Update global metadata
        $script:UnifiedConfigurationStore.Metadata.LastModified = Get-Date
        
        # Save configuration
        try {
            Save-UnifiedConfiguration
            $result.Changes += "Configuration saved to disk"
        } catch {
            Write-ConfigurationLog -Level 'WARNING' -Message "Failed to save configuration: $_"
            $result.Changes += "Warning: Configuration not saved to disk"
        }
        
        # Publish configuration change event
        $eventData = @{
            ModuleName = $ModuleName
            Environment = $Environment
            ConfigurationKeys = $Configuration.Keys -join ', '
            MergeMode = $Merge
            ValidationEnabled = $Validate
        }
        
        Publish-ConfigurationEvent -EventName 'ModuleConfigurationChanged' -EventData $eventData -Priority 'Normal'
        
        Write-ConfigurationLog -Level 'SUCCESS' -Message "Configuration set successfully for module '$ModuleName': $($result.Changes -join '; ')"
        
        return $result
        
    } catch {
        Write-ConfigurationLog -Level 'ERROR' -Message "Failed to set module configuration for '$ModuleName': $_"
        
        return @{
            Success = $false
            ModuleName = $ModuleName
            Environment = $Environment
            Error = $_.Exception.Message
            Timestamp = Get-Date
        }
    }
}

# Helper function for schema validation (referenced from earlier)
function Test-ConfigurationAgainstSchema {
    param(
        [hashtable]$Configuration,
        [hashtable]$Schema
    )
    
    $result = @{
        IsValid = $true
        Errors = @()
        Warnings = @()
    }
    
    try {
        # Check required properties
        if ($Schema.required) {
            foreach ($requiredKey in $Schema.required) {
                if (-not $Configuration.ContainsKey($requiredKey)) {
                    $result.IsValid = $false
                    $result.Errors += "Required property '$requiredKey' is missing"
                }
            }
        }
        
        # Validate properties
        if ($Schema.properties) {
            foreach ($key in $Configuration.Keys) {
                if ($Schema.properties.ContainsKey($key)) {
                    $propertySchema = $Schema.properties[$key]
                    $value = $Configuration[$key]
                    
                    # Type validation
                    if ($propertySchema.type) {
                        $expectedType = $propertySchema.type
                        $actualType = $value.GetType().Name.ToLower()
                        
                        $typeValid = switch ($expectedType) {
                            'string' { $actualType -eq 'string' }
                            'integer' { $actualType -in @('int32', 'int64', 'integer') }
                            'boolean' { $actualType -eq 'boolean' }
                            'object' { $actualType -eq 'hashtable' }
                            'array' { $actualType -eq 'object[]' -or $value -is [array] }
                            default { $true }
                        }
                        
                        if (-not $typeValid) {
                            $result.IsValid = $false
                            $result.Errors += "Property '$key' expected type '$expectedType' but got '$actualType'"
                        }
                    }
                    
                    # Range validation for integers
                    if ($propertySchema.minimum -ne $null -and $value -is [int] -and $value -lt $propertySchema.minimum) {
                        $result.IsValid = $false
                        $result.Errors += "Property '$key' value $value is below minimum $($propertySchema.minimum)"
                    }
                    
                    if ($propertySchema.maximum -ne $null -and $value -is [int] -and $value -gt $propertySchema.maximum) {
                        $result.IsValid = $false
                        $result.Errors += "Property '$key' value $value is above maximum $($propertySchema.maximum)"
                    }
                    
                    # Enum validation
                    if ($propertySchema.enum -and $value -notin $propertySchema.enum) {
                        $result.IsValid = $false
                        $result.Errors += "Property '$key' value '$value' is not in allowed values: $($propertySchema.enum -join ', ')"
                    }
                } else {
                    $result.Warnings += "Property '$key' is not defined in schema"
                }
            }
        }
        
        return $result
        
    } catch {
        return @{
            IsValid = $false
            Errors = @("Schema validation failed: $($_.Exception.Message)")
            Warnings = @()
        }
    }
}
#Requires -Version 7.0

<#
.SYNOPSIS
    Consolidated configuration loading system for AitherZero
.DESCRIPTION
    Provides hierarchical configuration loading with validation and caching
.PARAMETER ConfigPath
    Base configuration file path
.PARAMETER Environment
    Environment name (dev, staging, prod)
.PARAMETER Profile
    Configuration profile (minimal, developer, enterprise, full)
.PARAMETER ValidateSchema
    Whether to validate configuration against schema
.PARAMETER Force
    Force reload configuration even if cached
.EXAMPLE
    $config = Get-ConsolidatedConfiguration
.EXAMPLE
    $config = Get-ConsolidatedConfiguration -Environment "dev" -Profile "developer"
#>

function Get-ConsolidatedConfiguration {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$ConfigPath,
        
        [Parameter()]
        [ValidateSet('dev', 'staging', 'prod')]
        [string]$Environment = 'dev',
        
        [Parameter()]
        [ValidateSet('minimal', 'developer', 'enterprise', 'full', '')]
        [string]$Profile = '',
        
        [Parameter()]
        [switch]$ValidateSchema,
        
        [Parameter()]
        [switch]$Force
    )
    
    # Find project root
    $projectRoot = $env:PROJECT_ROOT
    if (-not $projectRoot) {
        $projectRoot = Find-ProjectRoot -StartPath $PSScriptRoot
    }
    
    # Initialize configuration cache if not exists
    if (-not $script:ConfigurationCache) {
        $script:ConfigurationCache = @{}
    }
    
    # Generate cache key
    $cacheKey = "$ConfigPath|$Environment|$Profile"
    
    # Return cached configuration if available and not forced
    if (-not $Force -and $script:ConfigurationCache.ContainsKey($cacheKey)) {
        Write-Verbose "Returning cached configuration for: $cacheKey"
        return $script:ConfigurationCache[$cacheKey]
    }
    
    try {
        # Determine configuration paths
        $configPaths = Get-ConfigurationPaths -ProjectRoot $projectRoot -ConfigPath $ConfigPath
        
        Write-Verbose "Configuration loading hierarchy:"
        Write-Verbose "  Project Root: $projectRoot"
        Write-Verbose "  Environment: $Environment"
        Write-Verbose "  Profile: $Profile"
        
        # Load base configuration
        $baseConfig = Get-BaseConfiguration -ConfigPaths $configPaths
        Write-Verbose "Base configuration loaded from: $($baseConfig._metadata.source)"
        
        # Load environment overrides
        $envOverrides = Get-EnvironmentOverrides -ProjectRoot $projectRoot -Environment $Environment
        if ($envOverrides) {
            Write-Verbose "Environment overrides loaded for: $Environment"
        }
        
        # Load profile configuration
        $profileConfig = Get-ProfileConfiguration -ProjectRoot $projectRoot -Profile $Profile
        if ($profileConfig) {
            Write-Verbose "Profile configuration loaded for: $Profile"
        }
        
        # Load user overrides
        $userOverrides = Get-UserOverrides -ProjectRoot $projectRoot
        if ($userOverrides) {
            Write-Verbose "User overrides loaded"
        }
        
        # Merge configurations in hierarchical order
        $mergedConfig = Merge-Configurations -BaseConfig $baseConfig -EnvironmentOverrides $envOverrides -ProfileConfig $profileConfig -UserOverrides $userOverrides
        
        # Add metadata
        $mergedConfig._metadata = @{
            version = "1.0"
            environment = $Environment
            profile = $Profile
            loadedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            sources = @{
                base = $baseConfig._metadata.source
                environment = if ($envOverrides) { $envOverrides._metadata.source } else { $null }
                profile = if ($profileConfig) { $profileConfig._metadata.source } else { $null }
                user = if ($userOverrides) { $userOverrides._metadata.source } else { $null }
            }
        }
        
        # Validate configuration if requested
        if ($ValidateSchema) {
            $validationResult = Test-ConfigurationSchema -Configuration $mergedConfig -ProjectRoot $projectRoot
            if (-not $validationResult.IsValid) {
                Write-Warning "Configuration validation failed:"
                $validationResult.Errors | ForEach-Object { Write-Warning "  $_" }
            } else {
                Write-Verbose "Configuration validation passed"
            }
        }
        
        # Cache the configuration
        $script:ConfigurationCache[$cacheKey] = $mergedConfig
        
        Write-Verbose "Configuration successfully loaded and cached"
        return $mergedConfig
        
    } catch {
        Write-Error "Failed to load consolidated configuration: $($_.Exception.Message)"
        Write-Error "Stack trace: $($_.ScriptStackTrace)"
        throw
    }
}

function Get-ConfigurationPaths {
    [CmdletBinding()]
    param(
        [string]$ProjectRoot,
        [string]$ConfigPath
    )
    
    if ($ConfigPath -and (Test-Path $ConfigPath)) {
        return @($ConfigPath)
    }
    
    # Configuration search paths (in order of preference)
    $searchPaths = @(
        (Join-Path $ProjectRoot "configs" "default-config.json"),          # Primary location
        (Join-Path $PSScriptRoot ".." "default-config.json"),              # Script-relative
        (Join-Path $ProjectRoot "aither-core" "default-config.json"),      # Legacy location
        (Join-Path $PSScriptRoot ".." "configs" "default-config.json")     # Alternative script-relative
    )
    
    return $searchPaths
}

function Get-BaseConfiguration {
    [CmdletBinding()]
    param(
        [string[]]$ConfigPaths
    )
    
    foreach ($configPath in $ConfigPaths) {
        if (Test-Path $configPath) {
            Write-Verbose "Loading base configuration from: $configPath"
            try {
                $content = Get-Content $configPath -Raw | ConvertFrom-Json
                
                # Convert to hashtable for easier manipulation
                $config = ConvertTo-Hashtable -InputObject $content
                $config._metadata = @{ source = $configPath }
                
                return $config
            } catch {
                Write-Warning "Failed to load configuration from '$configPath': $($_.Exception.Message)"
                continue
            }
        }
    }
    
    throw "No valid base configuration found in any of the search paths: $($ConfigPaths -join ', ')"
}

function Get-EnvironmentOverrides {
    [CmdletBinding()]
    param(
        [string]$ProjectRoot,
        [string]$Environment
    )
    
    $envConfigPath = Join-Path $ProjectRoot "configs" "environments" "$Environment-overrides.json"
    
    if (Test-Path $envConfigPath) {
        Write-Verbose "Loading environment overrides from: $envConfigPath"
        try {
            $content = Get-Content $envConfigPath -Raw | ConvertFrom-Json
            $config = ConvertTo-Hashtable -InputObject $content
            $config._metadata = @{ source = $envConfigPath }
            return $config
        } catch {
            Write-Warning "Failed to load environment overrides from '$envConfigPath': $($_.Exception.Message)"
        }
    }
    
    return $null
}

function Get-ProfileConfiguration {
    [CmdletBinding()]
    param(
        [string]$ProjectRoot,
        [string]$Profile
    )
    
    if (-not $Profile) {
        return $null
    }
    
    $profileConfigPath = Join-Path $ProjectRoot "configs" "profiles" $Profile "config.json"
    
    if (Test-Path $profileConfigPath) {
        Write-Verbose "Loading profile configuration from: $profileConfigPath"
        try {
            $content = Get-Content $profileConfigPath -Raw | ConvertFrom-Json
            $config = ConvertTo-Hashtable -InputObject $content
            $config._metadata = @{ source = $profileConfigPath }
            return $config
        } catch {
            Write-Warning "Failed to load profile configuration from '$profileConfigPath': $($_.Exception.Message)"
        }
    }
    
    return $null
}

function Get-UserOverrides {
    [CmdletBinding()]
    param(
        [string]$ProjectRoot
    )
    
    $userConfigPath = Join-Path $ProjectRoot "configs" "local-overrides.json"
    
    if (Test-Path $userConfigPath) {
        Write-Verbose "Loading user overrides from: $userConfigPath"
        try {
            $content = Get-Content $userConfigPath -Raw | ConvertFrom-Json
            $config = ConvertTo-Hashtable -InputObject $content
            $config._metadata = @{ source = $userConfigPath }
            return $config
        } catch {
            Write-Warning "Failed to load user overrides from '$userConfigPath': $($_.Exception.Message)"
        }
    }
    
    return $null
}

function Merge-Configurations {
    [CmdletBinding()]
    param(
        [hashtable]$BaseConfig,
        [hashtable]$EnvironmentOverrides,
        [hashtable]$ProfileConfig,
        [hashtable]$UserOverrides
    )
    
    # Start with base configuration
    $result = $BaseConfig.Clone()
    
    # Apply overrides in order
    $overrides = @($EnvironmentOverrides, $ProfileConfig, $UserOverrides)
    
    foreach ($override in $overrides) {
        if ($override) {
            $result = Merge-HashTables -Target $result -Source $override
        }
    }
    
    return $result
}

function Merge-HashTables {
    [CmdletBinding()]
    param(
        [hashtable]$Target,
        [hashtable]$Source
    )
    
    $result = $Target.Clone()
    
    foreach ($key in $Source.Keys) {
        if ($key -eq '_metadata') {
            continue  # Skip metadata during merge
        }
        
        if ($result.ContainsKey($key)) {
            if ($result[$key] -is [hashtable] -and $Source[$key] -is [hashtable]) {
                # Recursively merge nested hashtables
                $result[$key] = Merge-HashTables -Target $result[$key] -Source $Source[$key]
            } else {
                # Override with source value
                $result[$key] = $Source[$key]
            }
        } else {
            # Add new key
            $result[$key] = $Source[$key]
        }
    }
    
    return $result
}

function ConvertTo-Hashtable {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline)]
        $InputObject
    )
    
    if ($InputObject -is [hashtable]) {
        return $InputObject
    }
    
    if ($InputObject -is [PSCustomObject]) {
        $hashtable = @{}
        $InputObject.PSObject.Properties | ForEach-Object {
            $value = $_.Value
            if ($value -is [PSCustomObject]) {
                $value = ConvertTo-Hashtable $value
            }
            $hashtable[$_.Name] = $value
        }
        return $hashtable
    }
    
    return $InputObject
}

function Test-ConfigurationSchema {
    [CmdletBinding()]
    param(
        [hashtable]$Configuration,
        [string]$ProjectRoot
    )
    
    $schemaPath = Join-Path $ProjectRoot "configs" "config-schema.json"
    
    if (-not (Test-Path $schemaPath)) {
        Write-Warning "Configuration schema not found at: $schemaPath"
        return @{ IsValid = $true; Errors = @() }
    }
    
    try {
        # Basic validation - check for required structure
        $errors = @()
        
        # Check for basic structure
        $requiredSections = @('system', 'tools', 'logging')
        foreach ($section in $requiredSections) {
            if (-not $Configuration.ContainsKey($section)) {
                $errors += "Missing required section: $section"
            }
        }
        
        # More detailed validation could be added here using a JSON schema validator
        
        return @{
            IsValid = ($errors.Count -eq 0)
            Errors = $errors
        }
    } catch {
        return @{
            IsValid = $false
            Errors = @("Schema validation failed: $($_.Exception.Message)")
        }
    }
}

function Find-ProjectRoot {
    [CmdletBinding()]
    param(
        [string]$StartPath = $PSScriptRoot
    )
    
    $currentPath = $StartPath
    $rootIndicators = @('.git', 'Start-AitherZero.ps1', 'aither-core')
    
    while ($currentPath) {
        foreach ($indicator in $rootIndicators) {
            $testPath = Join-Path $currentPath $indicator
            if (Test-Path $testPath) {
                return $currentPath
            }
        }
        
        $parentPath = Split-Path $currentPath -Parent
        if ($parentPath -eq $currentPath) {
            break  # Reached root
        }
        $currentPath = $parentPath
    }
    
    # Fallback to current directory
    return $PWD.Path
}

# Export functions (remove for script usage)
# Export-ModuleMember -Function Get-ConsolidatedConfiguration
function Get-ModuleDiscovery {
    <#
    .SYNOPSIS
        Discovers all available modules and their functions with caching support
    .DESCRIPTION
        Scans the module directory and returns detailed information about each module.
        Results are cached for improved performance.
    .PARAMETER Tier
        License tier for filtering accessible modules
    .PARAMETER RefreshCache
        Force refresh of the module discovery cache
    .PARAMETER UseCache
        Use cached results if available (default: true)
    .EXAMPLE
        Get-ModuleDiscovery -Tier "pro"
    .EXAMPLE
        Get-ModuleDiscovery -RefreshCache
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Tier = 'free',
        
        [Parameter()]
        [switch]$RefreshCache,
        
        [Parameter()]
        [switch]$UseCache = $true
    )
    
    try {
        $projectRoot = Find-ProjectRoot
        $modulesPath = Join-Path $projectRoot "aither-core" "modules"
        
        if (-not (Test-Path $modulesPath)) {
            Write-Warning "Modules directory not found at: $modulesPath"
            return @()
        }
        
        # Check cache first unless refresh is requested
        $cacheResult = $null
        if ($UseCache -and -not $RefreshCache) {
            $cacheResult = Get-ModuleDiscoveryCache -ModulesPath $modulesPath
            if ($cacheResult) {
                Write-Verbose "Using cached module discovery results"
                # Apply tier filtering to cached results
                return $cacheResult | Where-Object { 
                    $_.IsLocked = -not (Test-FeatureAccess -Module $_.Name -CurrentTier $Tier)
                    $true
                }
            }
        }
        
        # Get feature registry
        $featureRegistry = if (Get-Command Get-FeatureRegistry -ErrorAction SilentlyContinue) {
            Get-FeatureRegistry
        } else {
            $null
        }
        
        $modules = @()
        
        # Scan each module directory
        Get-ChildItem $modulesPath -Directory | ForEach-Object {
            $moduleName = $_.Name
            $manifestPath = Join-Path $_.FullName "$moduleName.psd1"
            
            if (Test-Path $manifestPath) {
                try {
                    # Import manifest
                    $manifest = Import-PowerShellDataFile $manifestPath
                    
                    # Get module category from metadata
                    $category = Get-ModuleCategory -ModuleName $moduleName -FeatureRegistry $featureRegistry
                    
                    # Check if module is accessible with current tier
                    $isAccessible = Test-FeatureAccess -Module $moduleName -CurrentTier $Tier
                    $requiredTier = Get-ModuleRequiredTier -ModuleName $moduleName -FeatureRegistry $featureRegistry
                    
                    # Get exported functions
                    $functions = @()
                    if ($manifest.FunctionsToExport -and $manifest.FunctionsToExport -ne '*') {
                        foreach ($funcName in $manifest.FunctionsToExport) {
                            $funcInfo = Get-ModuleFunctionInfo -ModuleName $moduleName -FunctionName $funcName
                            if ($funcInfo) {
                                $functions += $funcInfo
                            }
                        }
                    }
                    
                    # Create module info object
                    $moduleInfo = [PSCustomObject]@{
                        Name = $moduleName
                        Description = $manifest.Description ?? "No description available"
                        Version = $manifest.ModuleVersion ?? "1.0.0"
                        Category = $category
                        RequiredTier = $requiredTier
                        IsLocked = -not $isAccessible
                        Functions = $functions
                        Path = $_.FullName
                    }
                    
                    $modules += $moduleInfo
                    
                } catch {
                    Write-Warning "Error processing module $moduleName : $_"
                }
            }
        }
        
        # Cache the results
        if ($UseCache) {
            Set-ModuleDiscoveryCache -ModulesPath $modulesPath -Modules $modules
        }
        
        return $modules | Sort-Object Category, Name
        
    } catch {
        Write-Error "Error discovering modules: $_"
        throw
    }
}

function Get-ModuleDiscoveryCache {
    <#
    .SYNOPSIS
        Retrieves cached module discovery results
    #>
    param(
        [string]$ModulesPath
    )
    
    try {
        $cacheFile = Join-Path ([System.IO.Path]::GetTempPath()) "aitherzero-module-discovery.json"
        
        if (-not (Test-Path $cacheFile)) {
            return $null
        }
        
        $cacheData = Get-Content $cacheFile -Raw | ConvertFrom-Json
        
        # Check if cache is still valid (compare timestamps)
        $modulesLastWrite = (Get-Item $ModulesPath).LastWriteTime
        $cacheTime = [DateTime]::Parse($cacheData.timestamp)
        
        # Cache is valid for 1 hour or until modules directory is modified
        if (($cacheTime.AddHours(1) -gt (Get-Date)) -and ($modulesLastWrite -le $cacheTime)) {
            Write-Verbose "Module discovery cache is valid"
            return $cacheData.modules
        } else {
            Write-Verbose "Module discovery cache is stale"
            return $null
        }
        
    } catch {
        Write-Verbose "Error reading module discovery cache: $_"
        return $null
    }
}

function Set-ModuleDiscoveryCache {
    <#
    .SYNOPSIS
        Stores module discovery results in cache
    #>
    param(
        [string]$ModulesPath,
        [array]$Modules
    )
    
    try {
        $cacheFile = Join-Path ([System.IO.Path]::GetTempPath()) "aitherzero-module-discovery.json"
        
        $cacheData = @{
            timestamp = (Get-Date).ToString("o")
            modulesPath = $ModulesPath
            modules = $Modules
        }
        
        $cacheData | ConvertTo-Json -Depth 10 | Set-Content $cacheFile -Encoding UTF8
        Write-Verbose "Module discovery results cached to: $cacheFile"
        
    } catch {
        Write-Verbose "Error writing module discovery cache: $_"
    }
}

function Clear-ModuleDiscoveryCache {
    <#
    .SYNOPSIS
        Clears the module discovery cache
    #>
    try {
        $cacheFile = Join-Path ([System.IO.Path]::GetTempPath()) "aitherzero-module-discovery.json"
        
        if (Test-Path $cacheFile) {
            Remove-Item $cacheFile -Force
            Write-Verbose "Module discovery cache cleared"
        }
        
    } catch {
        Write-Verbose "Error clearing module discovery cache: $_"
    }
}

function Get-ModuleCategory {
    param(
        [string]$ModuleName,
        $FeatureRegistry
    )
    
    # Module to category mapping
    $categoryMap = @{
        'LabRunner' = 'Infrastructure'
        'OpenTofuProvider' = 'Infrastructure'
        'CloudProviderIntegration' = 'Infrastructure'
        'ISOManager' = 'Infrastructure'
        'ISOCustomizer' = 'Infrastructure'
        
        'DevEnvironment' = 'Development'
        'PatchManager' = 'Development'
        'BackupManager' = 'Development'
        'AIToolsIntegration' = 'Development'
        
        'SecureCredentials' = 'Security'
        'RemoteConnection' = 'Security'
        
        'SystemMonitoring' = 'Monitoring'
        'RestAPIServer' = 'Monitoring'
        
        'OrchestrationEngine' = 'Automation'
        'ParallelExecution' = 'Automation'
        'ConfigurationCarousel' = 'Automation'
        'ConfigurationRepository' = 'Automation'
        
        'Logging' = 'Core'
        'TestingFramework' = 'Core'
        'ProgressTracking' = 'Core'
        'SetupWizard' = 'Core'
        'StartupExperience' = 'Core'
        'LicenseManager' = 'Core'
    }
    
    return $categoryMap[$ModuleName] ?? 'Other'
}

function Get-ModuleRequiredTier {
    param(
        [string]$ModuleName,
        $FeatureRegistry
    )
    
    if (-not $FeatureRegistry) {
        return 'free'
    }
    
    # Check module overrides first
    if ($FeatureRegistry.moduleOverrides.$ModuleName) {
        return $FeatureRegistry.moduleOverrides.$ModuleName.tier
    }
    
    # Find in features
    foreach ($feature in $FeatureRegistry.features.PSObject.Properties) {
        if ($feature.Value.modules -contains $ModuleName) {
            return $feature.Value.tier
        }
    }
    
    return 'free'
}

function Get-ModuleFunctionInfo {
    param(
        [string]$ModuleName,
        [string]$FunctionName
    )
    
    try {
        # Try to get help information for the function
        $helpInfo = Get-Help "$ModuleName\$FunctionName" -ErrorAction SilentlyContinue
        
        $description = if ($helpInfo.Synopsis) {
            $helpInfo.Synopsis
        } else {
            "No description available"
        }
        
        # Get parameters
        $parameters = @()
        if ($helpInfo.parameters.parameter) {
            foreach ($param in $helpInfo.parameters.parameter) {
                $parameters += [PSCustomObject]@{
                    Name = $param.name
                    Type = $param.type.name ?? 'object'
                    Mandatory = $param.required -eq 'true'
                    Description = $param.description.Text -join ' '
                }
            }
        }
        
        return [PSCustomObject]@{
            Name = $FunctionName
            Description = $description
            Parameters = $parameters
        }
        
    } catch {
        # Return basic info if help is not available
        return [PSCustomObject]@{
            Name = $FunctionName
            Description = "Function in $ModuleName module"
            Parameters = @()
        }
    }
}
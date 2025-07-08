function Get-AnalysisConfiguration {
    <#
    .SYNOPSIS
        Gets PSScriptAnalyzer configuration for a specific directory or module
    
    .DESCRIPTION
        Implements hierarchical configuration loading:
        1. Directory-specific (.pssa-config.json)
        2. Module-specific (PSScriptAnalyzerSettings.psd1 in module root)
        3. Global (PSScriptAnalyzerSettings.psd1 in project root)
    
    .PARAMETER Path
        Directory path to get configuration for
    
    .PARAMETER ModuleName
        Optional module name for module-specific configuration
    
    .PARAMETER UseCache
        Whether to use cached configuration (default: true)
    
    .EXAMPLE
        $config = Get-AnalysisConfiguration -Path "./aither-core/modules/PatchManager"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        
        [Parameter(Mandatory = $false)]
        [string]$ModuleName,
        
        [Parameter(Mandatory = $false)]
        [bool]$UseCache = $true
    )
    
    try {
        $resolvedPath = Resolve-Path $Path -ErrorAction Stop
        $cacheKey = "$resolvedPath|$ModuleName"
        
        # Check cache first
        if ($UseCache -and $script:ConfigurationCache.ContainsKey($cacheKey)) {
            $cached = $script:ConfigurationCache[$cacheKey]
            if ((Get-Date) - $cached.Timestamp -lt $script:DefaultSettings.MaxCacheAge) {
                if ($script:UseCustomLogging) {
                    Write-CustomLog -Level 'DEBUG' -Message "Using cached configuration for $Path"
                }
                return $cached.Configuration
            }
        }
        
        # Initialize with global configuration
        $globalConfigPath = $script:DefaultSettings.GlobalConfigPath
        $configuration = @{}
        
        if (Test-Path $globalConfigPath) {
            try {
                $globalConfig = Import-PowerShellDataFile -Path $globalConfigPath
                $configuration = $globalConfig.Clone()
                if ($script:UseCustomLogging) {
                    Write-CustomLog -Level 'DEBUG' -Message "Loaded global configuration from $globalConfigPath"
                }
            }
            catch {
                if ($script:UseCustomLogging) {
                    Write-CustomLog -Level 'WARNING' -Message "Failed to load global configuration: $($_.Exception.Message)"
                }
            }
        }
        
        # Load module-specific configuration if module name provided
        if ($ModuleName) {
            $moduleConfigPath = Join-Path $resolvedPath "PSScriptAnalyzerSettings.psd1"
            if (Test-Path $moduleConfigPath) {
                try {
                    $moduleConfig = Import-PowerShellDataFile -Path $moduleConfigPath
                    # Merge configurations (module overrides global)
                    foreach ($key in $moduleConfig.Keys) {
                        $configuration[$key] = $moduleConfig[$key]
                    }
                    if ($script:UseCustomLogging) {
                        Write-CustomLog -Level 'DEBUG' -Message "Loaded module configuration from $moduleConfigPath"
                    }
                }
                catch {
                    if ($script:UseCustomLogging) {
                        Write-CustomLog -Level 'WARNING' -Message "Failed to load module configuration: $($_.Exception.Message)"
                    }
                }
            }
        }
        
        # Load directory-specific configuration
        $dirConfigPath = Join-Path $resolvedPath $script:DefaultSettings.ConfigFileName
        if (Test-Path $dirConfigPath) {
            try {
                $dirConfig = Get-Content $dirConfigPath | ConvertFrom-Json -AsHashtable
                # Merge configurations (directory overrides module/global)
                foreach ($key in $dirConfig.Keys) {
                    $configuration[$key] = $dirConfig[$key]
                }
                if ($script:UseCustomLogging) {
                    Write-CustomLog -Level 'DEBUG' -Message "Loaded directory configuration from $dirConfigPath"
                }
            }
            catch {
                if ($script:UseCustomLogging) {
                    Write-CustomLog -Level 'WARNING' -Message "Failed to load directory configuration: $($_.Exception.Message)"
                }
            }
        }
        
        # Apply default fallbacks if needed
        if (-not $configuration.ContainsKey('Severity')) {
            $configuration.Severity = @('Error', 'Warning', 'Information')
        }
        
        if (-not $configuration.ContainsKey('IncludeDefaultRules')) {
            $configuration.IncludeDefaultRules = $true
        }
        
        if (-not $configuration.ContainsKey('Recurse')) {
            $configuration.Recurse = $true
        }
        
        # Cache the configuration
        if ($UseCache) {
            $script:ConfigurationCache[$cacheKey] = @{
                Configuration = $configuration
                Timestamp = Get-Date
            }
        }
        
        return $configuration
    }
    catch {
        if ($script:UseCustomLogging) {
            Write-CustomLog -Level 'ERROR' -Message "Failed to get analysis configuration for ${Path}: $($_.Exception.Message)"
        }
        throw
    }
}
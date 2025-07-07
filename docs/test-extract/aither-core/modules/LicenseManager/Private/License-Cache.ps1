function Initialize-LicenseCache {
    <#
    .SYNOPSIS
        Initializes the license status cache for performance optimization
    .DESCRIPTION
        Sets up caching infrastructure to avoid repeated license validation
    #>
    [CmdletBinding()]
    param()
    
    if (-not $script:LicenseCache) {
        $script:LicenseCache = @{
            LastCheck = $null
            LastStatus = $null
            CacheTimeout = (New-TimeSpan -Minutes 5)
            FeatureCache = @{}
            FeatureCacheTimeout = (New-TimeSpan -Minutes 10)
            Enabled = $true
        }
        
        if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
            Write-CustomLog -Message "License cache initialized" -Level DEBUG -Context @{
                CacheTimeout = $script:LicenseCache.CacheTimeout.TotalMinutes
                FeatureCacheTimeout = $script:LicenseCache.FeatureCacheTimeout.TotalMinutes
            }
        }
    }
}

function Get-CachedLicenseStatus {
    <#
    .SYNOPSIS
        Gets license status from cache if available and valid
    .DESCRIPTION
        Returns cached license status if within timeout, otherwise returns null
    .OUTPUTS
        Cached license status object or null if cache miss
    #>
    [CmdletBinding()]
    param()
    
    Initialize-LicenseCache
    
    if (-not $script:LicenseCache.Enabled) {
        return $null
    }
    
    $now = Get-Date
    
    # Check if cache is valid
    if ($script:LicenseCache.LastCheck -and 
        $script:LicenseCache.LastStatus -and
        ($now - $script:LicenseCache.LastCheck) -lt $script:LicenseCache.CacheTimeout) {
        
        if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
            Write-CustomLog -Message "License status cache hit" -Level TRACE -Context @{
                CacheAge = ($now - $script:LicenseCache.LastCheck).TotalSeconds
            }
        }
        
        return $script:LicenseCache.LastStatus
    }
    
    return $null
}

function Set-CachedLicenseStatus {
    <#
    .SYNOPSIS
        Stores license status in cache
    .PARAMETER Status
        License status object to cache
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Status
    )
    
    Initialize-LicenseCache
    
    if ($script:LicenseCache.Enabled) {
        $script:LicenseCache.LastCheck = Get-Date
        $script:LicenseCache.LastStatus = $Status
        
        if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
            Write-CustomLog -Message "License status cached" -Level TRACE -Context @{
                Tier = $Status.Tier
                Valid = $Status.IsValid
            }
        }
    }
}

function Get-CachedFeatureAccess {
    <#
    .SYNOPSIS
        Gets feature access result from cache
    .PARAMETER FeatureName
        Name of the feature to check cache for
    .OUTPUTS
        Cached feature access result or null if cache miss
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FeatureName
    )
    
    Initialize-LicenseCache
    
    if (-not $script:LicenseCache.Enabled) {
        return $null
    }
    
    $cacheKey = $FeatureName.ToLower()
    $now = Get-Date
    
    if ($script:LicenseCache.FeatureCache.ContainsKey($cacheKey)) {
        $cacheEntry = $script:LicenseCache.FeatureCache[$cacheKey]
        
        if (($now - $cacheEntry.Timestamp) -lt $script:LicenseCache.FeatureCacheTimeout) {
            if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
                Write-CustomLog -Message "Feature access cache hit" -Level TRACE -Context @{
                    Feature = $FeatureName
                    Access = $cacheEntry.HasAccess
                    CacheAge = ($now - $cacheEntry.Timestamp).TotalSeconds
                }
            }
            
            return $cacheEntry.HasAccess
        } else {
            # Remove expired cache entry
            $script:LicenseCache.FeatureCache.Remove($cacheKey)
        }
    }
    
    return $null
}

function Set-CachedFeatureAccess {
    <#
    .SYNOPSIS
        Stores feature access result in cache
    .PARAMETER FeatureName
        Name of the feature
    .PARAMETER HasAccess
        Whether access is granted
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FeatureName,
        
        [Parameter(Mandatory)]
        [bool]$HasAccess
    )
    
    Initialize-LicenseCache
    
    if ($script:LicenseCache.Enabled) {
        $cacheKey = $FeatureName.ToLower()
        $script:LicenseCache.FeatureCache[$cacheKey] = @{
            HasAccess = $HasAccess
            Timestamp = Get-Date
        }
        
        if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
            Write-CustomLog -Message "Feature access cached" -Level TRACE -Context @{
                Feature = $FeatureName
                Access = $HasAccess
            }
        }
    }
}

function Clear-LicenseCache {
    <#
    .SYNOPSIS
        Clears the license cache
    .DESCRIPTION
        Forces cache invalidation for license status and feature access
    .PARAMETER Type
        Type of cache to clear (Status, Features, or All)
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateSet('Status', 'Features', 'All')]
        [string]$Type = 'All'
    )
    
    Initialize-LicenseCache
    
    switch ($Type) {
        'Status' {
            $script:LicenseCache.LastCheck = $null
            $script:LicenseCache.LastStatus = $null
        }
        'Features' {
            $script:LicenseCache.FeatureCache.Clear()
        }
        'All' {
            $script:LicenseCache.LastCheck = $null
            $script:LicenseCache.LastStatus = $null
            $script:LicenseCache.FeatureCache.Clear()
        }
    }
    
    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Message "License cache cleared" -Level DEBUG -Context @{
            Type = $Type
        }
    }
}

function Set-LicenseCacheEnabled {
    <#
    .SYNOPSIS
        Enables or disables license caching
    .PARAMETER Enabled
        Whether caching should be enabled
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [bool]$Enabled
    )
    
    Initialize-LicenseCache
    
    $script:LicenseCache.Enabled = $Enabled
    
    if (-not $Enabled) {
        Clear-LicenseCache -Type All
    }
    
    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Message "License caching $($Enabled ? 'enabled' : 'disabled')" -Level INFO
    }
}

function Get-LicenseCacheStatistics {
    <#
    .SYNOPSIS
        Gets cache performance statistics
    .OUTPUTS
        Cache statistics object
    #>
    [CmdletBinding()]
    param()
    
    Initialize-LicenseCache
    
    $now = Get-Date
    $statusCacheAge = if ($script:LicenseCache.LastCheck) {
        ($now - $script:LicenseCache.LastCheck).TotalMinutes
    } else { $null }
    
    $featureCacheEntries = $script:LicenseCache.FeatureCache.Count
    $validFeatureEntries = 0
    
    foreach ($entry in $script:LicenseCache.FeatureCache.Values) {
        if (($now - $entry.Timestamp) -lt $script:LicenseCache.FeatureCacheTimeout) {
            $validFeatureEntries++
        }
    }
    
    return [PSCustomObject]@{
        Enabled = $script:LicenseCache.Enabled
        StatusCacheEnabled = $script:LicenseCache.LastStatus -ne $null
        StatusCacheAge = $statusCacheAge
        StatusCacheTimeout = $script:LicenseCache.CacheTimeout.TotalMinutes
        FeatureCacheEntries = $featureCacheEntries
        ValidFeatureCacheEntries = $validFeatureEntries
        FeatureCacheTimeout = $script:LicenseCache.FeatureCacheTimeout.TotalMinutes
    }
}
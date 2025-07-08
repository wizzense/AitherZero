function Get-LicenseCacheStatistics {
    <#
    .SYNOPSIS
        Gets cache performance statistics
    .DESCRIPTION
        Returns detailed statistics about license caching performance and efficiency
    .OUTPUTS
        Cache statistics object with performance metrics
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
        CacheHitRatio = if ($featureCacheEntries -gt 0) {
            [Math]::Round(($validFeatureEntries / $featureCacheEntries) * 100, 2)
        } else { 0 }
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

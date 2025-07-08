function Clear-ModuleDiscoveryCache {
    <#
    .SYNOPSIS
        Clears the module discovery cache
    .DESCRIPTION
        Invalidates cached module discovery results to force fresh discovery
    .PARAMETER CacheType
        Type of cache to clear (All, Modules, Performance)
    .EXAMPLE
        Clear-ModuleDiscoveryCache
        # Clears all module discovery cache
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateSet('All', 'Modules', 'Performance')]
        [string]$CacheType = 'All'
    )

    try {
        $cacheCleared = $false

        # Clear module discovery cache
        if ($CacheType -in @('All', 'Modules')) {
            if ($script:ModuleDiscoveryCache) {
                $script:ModuleDiscoveryCache = $null
                $cacheCleared = $true
                Write-Host "Module discovery cache cleared." -ForegroundColor Green
            }

            if ($script:ModuleDiscoveryCacheTime) {
                $script:ModuleDiscoveryCacheTime = $null
            }
        }

        # Clear performance cache
        if ($CacheType -in @('All', 'Performance')) {
            if ($script:StartupPerformanceCache) {
                $script:StartupPerformanceCache = $null
                $cacheCleared = $true
                Write-Host "Performance cache cleared." -ForegroundColor Green
            }
        }

        # Clear UI capabilities cache
        if ($CacheType -eq 'All') {
            if ($script:UICapabilities) {
                $script:UICapabilities = $null
                $cacheCleared = $true
                Write-Host "UI capabilities cache cleared." -ForegroundColor Green
            }
        }

        if (-not $cacheCleared) {
            Write-Host "No cache data found to clear." -ForegroundColor Yellow
        }

        # Log operation
        if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
            Write-CustomLog -Message "Module discovery cache cleared" -Level DEBUG -Context @{
                CacheType = $CacheType
                CacheCleared = $cacheCleared
            }
        }

        return $cacheCleared

    } catch {
        if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
            Write-CustomLog -Message "Error clearing module discovery cache" -Level ERROR -Exception $_.Exception
        }
        throw
    }
}

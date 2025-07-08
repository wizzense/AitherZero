function Get-ConfigurationWatcher {
    <#
    .SYNOPSIS
        Get information about configuration file watchers
    .DESCRIPTION
        Returns information about active file watchers for configuration hot reload
    .PARAMETER Name
        Specific watcher name to get information for
    .PARAMETER All
        Return information for all watchers
    .EXAMPLE
        $watchers = Get-ConfigurationWatcher -All
    .EXAMPLE
        $configWatcher = Get-ConfigurationWatcher -Name "ConfigFile"
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Name,

        [Parameter()]
        [switch]$All
    )

    try {
        if ($All) {
            $watcherInfo = @{}
            foreach ($watcherName in $script:ConfigurationStore.HotReload.Watchers.Keys) {
                $watcher = $script:ConfigurationStore.HotReload.Watchers[$watcherName]

                $watcherInfo[$watcherName] = @{
                    Name = $watcherName
                    Enabled = $watcher.EnableRaisingEvents
                    Path = $watcher.Path
                    Filter = $watcher.Filter
                    NotifyFilter = $watcher.NotifyFilter
                    IncludeSubdirectories = $watcher.IncludeSubdirectories
                    Type = $watcher.GetType().Name
                }
            }
            return $watcherInfo
        }

        if (-not $Name) {
            # Return summary information
            return @{
                HotReloadEnabled = $script:ConfigurationStore.HotReload.Enabled
                WatcherCount = $script:ConfigurationStore.HotReload.Watchers.Count
                WatcherNames = @($script:ConfigurationStore.HotReload.Watchers.Keys)
            }
        }

        if (-not $script:ConfigurationStore.HotReload.Watchers.ContainsKey($Name)) {
            Write-CustomLog -Level 'WARN' -Message "Watcher '$Name' not found"
            return $null
        }

        $watcher = $script:ConfigurationStore.HotReload.Watchers[$Name]

        return @{
            Name = $Name
            Enabled = $watcher.EnableRaisingEvents
            Path = $watcher.Path
            Filter = $watcher.Filter
            NotifyFilter = $watcher.NotifyFilter
            IncludeSubdirectories = $watcher.IncludeSubdirectories
            Type = $watcher.GetType().Name
        }

    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to get configuration watcher: $_"
        throw
    }
}

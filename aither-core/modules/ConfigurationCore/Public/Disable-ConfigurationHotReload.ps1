function Disable-ConfigurationHotReload {
    <#
    .SYNOPSIS
        Disable hot reload for configuration changes
    .DESCRIPTION
        Disables automatic configuration reload and stops file watchers
    .PARAMETER RemoveWatchers
        Remove all file watchers
    .EXAMPLE
        Disable-ConfigurationHotReload
    .EXAMPLE
        Disable-ConfigurationHotReload -RemoveWatchers
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter()]
        [switch]$RemoveWatchers
    )

    try {
        if ($PSCmdlet.ShouldProcess("Configuration Hot Reload", "Disable")) {
            # Disable hot reload in configuration store
            $script:ConfigurationStore.HotReload.Enabled = $false

            # Stop and remove watchers if requested
            if ($RemoveWatchers) {
                $watcherCount = 0
                foreach ($watcherName in $script:ConfigurationStore.HotReload.Watchers.Keys) {
                    try {
                        $watcher = $script:ConfigurationStore.HotReload.Watchers[$watcherName]
                        if ($watcher -and $watcher.EnableRaisingEvents) {
                            $watcher.EnableRaisingEvents = $false
                            $watcher.Dispose()
                            $watcherCount++
                        }
                    } catch {
                        Write-CustomLog -Level 'WARN' -Message "Failed to dispose watcher '$watcherName': $_"
                    }
                }

                # Clear watchers collection
                $script:ConfigurationStore.HotReload.Watchers.Clear()

                if ($watcherCount -gt 0) {
                    Write-CustomLog -Level 'INFO' -Message "Removed $watcherCount file watchers"
                }
            }

            # Remove any registered events
            Get-EventSubscriber | Where-Object { $_.SourceObject -is [System.IO.FileSystemWatcher] } | ForEach-Object {
                try {
                    Unregister-Event -SourceIdentifier $_.SourceIdentifier -ErrorAction SilentlyContinue
                } catch {
                    Write-CustomLog -Level 'WARN' -Message "Failed to unregister event: $_"
                }
            }

            # Save updated configuration
            Save-ConfigurationStore

            Write-CustomLog -Level 'SUCCESS' -Message "Configuration hot reload disabled"

            # Publish event
            if (Get-Command 'Publish-TestEvent' -ErrorAction SilentlyContinue) {
                Publish-TestEvent -EventType 'HotReloadDisabled' -Data @{
                    RemoveWatchers = $RemoveWatchers.IsPresent
                    Timestamp = Get-Date
                }
            }

            return $true
        }

    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to disable configuration hot reload: $_"
        throw
    }
}

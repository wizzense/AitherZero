function Enable-ConfigurationHotReload {
    <#
    .SYNOPSIS
        Enable hot reload for configuration changes
    .DESCRIPTION
        Enables automatic configuration reload when changes are detected
    .PARAMETER WatchConfigFile
        Watch the main configuration file for changes
    .PARAMETER WatchInterval
        Interval in seconds for checking file changes (default: 5)
    .PARAMETER ModuleNames
        Specific modules to enable hot reload for (default: all)
    .EXAMPLE
        Enable-ConfigurationHotReload
    .EXAMPLE
        Enable-ConfigurationHotReload -WatchConfigFile -WatchInterval 10
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter()]
        [switch]$WatchConfigFile,
        
        [Parameter()]
        [int]$WatchInterval = 5,
        
        [Parameter()]
        [string[]]$ModuleNames = @()
    )
    
    try {
        if ($PSCmdlet.ShouldProcess("Configuration Hot Reload", "Enable")) {
            # Enable hot reload in configuration store
            $script:ConfigurationStore.HotReload.Enabled = $true
            
            # Set up file watcher if requested
            if ($WatchConfigFile) {
                $configPath = $script:ConfigurationStore.StorePath
                $configDir = Split-Path $configPath -Parent
                $configFile = Split-Path $configPath -Leaf
                
                # Create FileSystemWatcher
                $watcher = New-Object System.IO.FileSystemWatcher
                $watcher.Path = $configDir
                $watcher.Filter = $configFile
                $watcher.NotifyFilter = [System.IO.NotifyFilters]::LastWrite
                $watcher.EnableRaisingEvents = $true
                
                # Register event handler
                $action = {
                    param($sender, $e)
                    
                    try {
                        Write-CustomLog -Level 'INFO' -Message "Configuration file changed, reloading..."
                        
                        # Small delay to ensure file write is complete
                        Start-Sleep -Milliseconds 500
                        
                        # Reload configuration from file
                        if (Test-Path $script:ConfigurationStore.StorePath) {
                            $storedConfig = Get-Content $script:ConfigurationStore.StorePath -Raw | ConvertFrom-Json -AsHashtable
                            if ($storedConfig) {
                                $script:ConfigurationStore = $storedConfig
                                
                                # Notify all modules
                                foreach ($moduleName in $script:ConfigurationStore.Modules.Keys) {
                                    Invoke-ConfigurationReload -ModuleName $moduleName -Environment $script:ConfigurationStore.CurrentEnvironment
                                }
                            }
                        }
                        
                    } catch {
                        Write-CustomLog -Level 'ERROR' -Message "Failed to reload configuration: $_"
                    }
                }
                
                # Register the event
                Register-ObjectEvent -InputObject $watcher -EventName "Changed" -Action $action | Out-Null
                
                # Store watcher reference
                $script:ConfigurationStore.HotReload.Watchers['ConfigFile'] = $watcher
                
                Write-CustomLog -Level 'INFO' -Message "Configuration file watcher enabled: $configPath"
            }
            
            # Save updated configuration
            Save-ConfigurationStore
            
            Write-CustomLog -Level 'SUCCESS' -Message "Configuration hot reload enabled"
            
            # Publish event
            if (Get-Command 'Publish-TestEvent' -ErrorAction SilentlyContinue) {
                Publish-TestEvent -EventName 'HotReloadEnabled' -EventData @{
                    WatchConfigFile = $WatchConfigFile.IsPresent
                    WatchInterval = $WatchInterval
                    ModuleNames = $ModuleNames
                    Timestamp = Get-Date
                }
            }
            
            return $true
        }
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to enable configuration hot reload: $_"
        throw
    }
}
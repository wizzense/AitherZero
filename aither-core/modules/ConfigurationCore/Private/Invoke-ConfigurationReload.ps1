function Invoke-ConfigurationReload {
    <#
    .SYNOPSIS
        Trigger configuration reload for a module
    .DESCRIPTION
        Notifies modules about configuration changes when hot reload is enabled
    .PARAMETER ModuleName
        Name of the module whose configuration changed
    .PARAMETER Environment
        Environment where the change occurred
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ModuleName,
        
        [Parameter(Mandatory)]
        [string]$Environment
    )
    
    try {
        # Only proceed if hot reload is enabled
        if (-not $script:ConfigurationStore.HotReload.Enabled) {
            return
        }
        
        Write-CustomLog -Level 'DEBUG' -Message "Triggering configuration reload for $ModuleName in $Environment"
        
        # Check if module is loaded
        $module = Get-Module -Name $ModuleName -ErrorAction SilentlyContinue
        if (-not $module) {
            Write-CustomLog -Level 'DEBUG' -Message "Module $ModuleName not loaded, skipping reload"
            return
        }
        
        # Look for module's reload function
        $reloadFunction = "$ModuleName\Update-ModuleConfiguration"
        if (Get-Command $reloadFunction -ErrorAction SilentlyContinue) {
            # Module has a reload function, call it
            $config = Get-ModuleConfiguration -ModuleName $ModuleName -Environment $Environment
            & $reloadFunction -Configuration $config
            Write-CustomLog -Level 'INFO' -Message "Configuration reloaded for $ModuleName"
        } else {
            Write-CustomLog -Level 'DEBUG' -Message "Module $ModuleName does not support hot reload"
        }
        
        # Publish event for other modules to react
        if (Get-Command 'Publish-TestEvent' -ErrorAction SilentlyContinue) {
            Publish-TestEvent -EventName 'ConfigurationChanged' -EventData @{
                ModuleName = $ModuleName
                Environment = $Environment
                Timestamp = Get-Date
            }
        }
        
    } catch {
        Write-CustomLog -Level 'WARNING' -Message "Failed to reload configuration for $ModuleName: $_"
    }
}
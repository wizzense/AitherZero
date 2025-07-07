function Subscribe-ConfigurationEvent {
    <#
    .SYNOPSIS
        Subscribe to configuration change events
    .DESCRIPTION
        Allows modules to subscribe to configuration events for real-time notifications
    .PARAMETER EventName
        Name of the configuration event to subscribe to
    .PARAMETER ModuleName
        Name of the module subscribing to the event
    .PARAMETER Action
        Script block to execute when the event occurs
    .PARAMETER Filter
        Optional filter for specific configuration changes
    .EXAMPLE
        Subscribe-ConfigurationEvent -EventName "ModuleConfigurationChanged" -ModuleName "LabRunner" -Action {
            param($EventData)
            Write-Host "LabRunner configuration changed: $($EventData.Changes)"
        }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$EventName,
        
        [Parameter(Mandatory)]
        [string]$ModuleName,
        
        [Parameter(Mandatory)]
        [scriptblock]$Action,
        
        [Parameter()]
        [hashtable]$Filter = @{}
    )
    
    try {
        # Initialize event system if not already done
        if (-not $script:ConfigurationStore.EventSystem) {
            $script:ConfigurationStore.EventSystem = @{
                Subscriptions = @{}
                EventHistory = @()
                MaxHistorySize = 1000
            }
        }
        
        # Create subscription
        $subscription = @{
            ModuleName = $ModuleName
            Action = $Action
            Filter = $Filter
            SubscribedAt = Get-Date
            Id = [System.Guid]::NewGuid().ToString()
        }
        
        # Add to subscriptions
        if (-not $script:ConfigurationStore.EventSystem.Subscriptions.ContainsKey($EventName)) {
            $script:ConfigurationStore.EventSystem.Subscriptions[$EventName] = @()
        }
        
        $script:ConfigurationStore.EventSystem.Subscriptions[$EventName] += $subscription
        
        Write-CustomLog -Level 'INFO' -Message "Module '$ModuleName' subscribed to event '$EventName'"
        
        # Publish subscription event
        if (Get-Command 'Publish-TestEvent' -ErrorAction SilentlyContinue) {
            Publish-TestEvent -EventName 'ConfigurationEventSubscribed' -EventData @{
                EventName = $EventName
                ModuleName = $ModuleName
                SubscriptionId = $subscription.Id
                Timestamp = Get-Date
            }
        }
        
        return $subscription.Id
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to subscribe to configuration event: $_"
        throw
    }
}
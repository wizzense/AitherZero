# Private helper function for publishing configuration events
function Publish-ConfigurationEvent {
    <#
    .SYNOPSIS
        Publishes a configuration event to the unified event system
    .DESCRIPTION
        Private function for internal event publishing within the Configuration Manager
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$EventName,
        
        [hashtable]$EventData = @{},
        
        [string]$Source = 'ConfigurationManager',
        
        [ValidateSet('Low', 'Normal', 'High', 'Critical')]
        [string]$Priority = 'Normal'
    )
    
    try {
        if (-not $script:UnifiedConfigurationStore.Events) {
            Write-ConfigurationLog -Level 'WARNING' -Message "Event system not initialized"
            return $false
        }
        
        $event = @{
            Id = [System.Guid]::NewGuid().ToString()
            Name = $EventName
            Source = $Source
            Priority = $Priority
            Timestamp = Get-Date
            Data = $EventData
            Processed = $false
        }
        
        # Add to event history
        $script:UnifiedConfigurationStore.Events.History += $event
        
        # Trim history if it exceeds maximum size
        $maxHistory = $script:UnifiedConfigurationStore.Events.MaxHistorySize
        if ($script:UnifiedConfigurationStore.Events.History.Count -gt $maxHistory) {
            $script:UnifiedConfigurationStore.Events.History = $script:UnifiedConfigurationStore.Events.History | Select-Object -Last $maxHistory
        }
        
        # Process event subscriptions
        $subscriptions = $script:UnifiedConfigurationStore.Events.Subscriptions
        foreach ($subscription in $subscriptions.Values) {
            if ($subscription.EventPattern -eq '*' -or $EventName -match $subscription.EventPattern) {
                try {
                    if ($subscription.ScriptBlock) {
                        & $subscription.ScriptBlock $event
                    }
                    
                    if ($subscription.FunctionName -and (Get-Command $subscription.FunctionName -ErrorAction SilentlyContinue)) {
                        & $subscription.FunctionName $event
                    }
                    
                } catch {
                    Write-ConfigurationLog -Level 'WARNING' -Message "Event subscription handler failed: $_"
                }
            }
        }
        
        $event.Processed = $true
        
        Write-ConfigurationLog -Level 'DEBUG' -Message "Published event: $EventName"
        return $true
        
    } catch {
        Write-ConfigurationLog -Level 'ERROR' -Message "Failed to publish event '$EventName': $_"
        return $false
    }
}
function Publish-UtilityEvent {
    <#
    .SYNOPSIS
        Publishes events for cross-service communication
    
    .DESCRIPTION
        Publishes events that can be consumed by other services or external subscribers
    
    .PARAMETER EventType
        Type of event to publish
    
    .PARAMETER Data
        Event data to include
    
    .PARAMETER Source
        Source of the event
    
    .EXAMPLE
        Publish-UtilityEvent -EventType "CustomOperation" -Data @{Status = "Completed"}
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$EventType,
        
        [hashtable]$Data = @{},
        
        [string]$Source = 'UtilityServices'
    )
    
    if (-not $script:ServiceEventSystem.Enabled) { return }
    
    $event = @{
        EventType = $EventType
        Source = $Source
        Timestamp = Get-Date
        Data = $Data
        Id = [Guid]::NewGuid().ToString()
    }
    
    # Store in history
    $script:ServiceEventSystem.EventHistory += $event
    
    # Notify subscribers
    if ($script:ServiceEventSystem.Subscribers.ContainsKey($EventType)) {
        foreach ($subscriber in $script:ServiceEventSystem.Subscribers[$EventType]) {
            try {
                & $subscriber $event
            } catch {
                Write-UtilityLog "Event subscriber error for $EventType`: $($_.Exception.Message)" -Level "ERROR"
            }
        }
    }
    
    Write-UtilityLog "📡 Published event: $EventType from $Source" -Level "DEBUG"
}
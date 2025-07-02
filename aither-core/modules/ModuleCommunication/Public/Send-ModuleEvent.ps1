function Send-ModuleEvent {
    <#
    .SYNOPSIS
        Send an event for module communication
    .DESCRIPTION
        Enhanced event sending with channel support and persistence
    .PARAMETER EventName
        Name of the event
    .PARAMETER EventData
        Event payload data
    .PARAMETER Channel
        Optional channel for the event (defaults to 'Events')
    .PARAMETER Broadcast
        Send to all channels
    .PARAMETER Persist
        Store in event history
    .EXAMPLE
        Send-ModuleEvent -EventName "ConfigurationChanged" -EventData @{
            Module = "LabRunner"
            Setting = "MaxJobs"
            OldValue = 5
            NewValue = 10
        }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$EventName,
        
        [Parameter(Mandatory)]
        [object]$EventData,
        
        [Parameter()]
        [string]$Channel = 'Events',
        
        [Parameter()]
        [switch]$Broadcast,
        
        [Parameter()]
        [switch]$Persist = $true
    )
    
    try {
        $event = @{
            Id = [Guid]::NewGuid().ToString()
            Name = $EventName
            Data = $EventData
            Channel = $Channel
            Timestamp = Get-Date
            Source = @{
                Module = $MyInvocation.MyCommand.Module.Name
                Command = $MyInvocation.MyCommand.Name
                User = $env:USERNAME
                Machine = $env:COMPUTERNAME
            }
        }
        
        # Persist to event history
        if ($Persist) {
            $script:MessageBus.EventHistory.Enqueue($event)
            
            # Maintain history size limit
            while ($script:MessageBus.EventHistory.Count -gt $script:Configuration.MaxEventHistory) {
                $discard = $null
                $script:MessageBus.EventHistory.TryDequeue([ref]$discard) | Out-Null
            }
        }
        
        if ($Broadcast) {
            # Send to all channels
            foreach ($channelName in $script:MessageBus.Channels.Keys) {
                Send-ModuleMessage -Channel $channelName -MessageType "Event:$EventName" -Data $event -Priority 'Normal'
            }
        } else {
            # Send to specific channel
            Send-ModuleMessage -Channel $Channel -MessageType "Event:$EventName" -Data $event -Priority 'Normal'
        }
        
        # Update channel activity
        if ($script:MessageBus.Channels.ContainsKey($Channel)) {
            $script:MessageBus.Channels[$Channel].LastActivity = Get-Date
            $script:MessageBus.Channels[$Channel].Statistics.TotalMessages++
        }
        
        if ($script:Configuration.EnableTracing) {
            Write-CustomLog -Level 'DEBUG' -Message "Event published: $EventName on channel $Channel"
        }
        
        return $event.Id
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to publish event: $_"
        throw
    }
}
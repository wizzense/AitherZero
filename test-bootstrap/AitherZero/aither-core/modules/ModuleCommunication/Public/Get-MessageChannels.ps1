function Get-MessageChannels {
    <#
    .SYNOPSIS
        Get information about message channels
    .DESCRIPTION
        Returns information about all or specific message channels
    .PARAMETER Name
        Get specific channel by name
    .PARAMETER IncludeStatistics
        Include detailed statistics
    .EXAMPLE
        Get-MessageChannels -IncludeStatistics
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Name,
        
        [Parameter()]
        [switch]$IncludeStatistics
    )
    
    try {
        $channels = @()
        
        if ($Name) {
            # Get specific channel
            if ($script:MessageBus.Channels.ContainsKey($Name)) {
                $channel = $script:MessageBus.Channels[$Name]
                
                $channelInfo = @{
                    Name = $channel.Name
                    Description = $channel.Description
                    CreatedAt = $channel.CreatedAt
                    MaxMessages = $channel.MaxMessages
                    MessageRetention = $channel.MessageRetention
                    MessageCount = $channel.MessageCount
                    SubscriptionCount = $channel.SubscriptionCount
                    LastActivity = $channel.LastActivity
                }
                
                if ($IncludeStatistics) {
                    $channelInfo.Statistics = $channel.Statistics
                }
                
                return $channelInfo
            } else {
                Write-CustomLog -Level 'WARNING' -Message "Channel '$Name' not found"
                return $null
            }
        } else {
            # Get all channels
            foreach ($channelName in $script:MessageBus.Channels.Keys) {
                $channel = $script:MessageBus.Channels[$channelName]
                
                $channelInfo = @{
                    Name = $channel.Name
                    Description = $channel.Description
                    CreatedAt = $channel.CreatedAt
                    MessageCount = $channel.MessageCount
                    SubscriptionCount = $channel.SubscriptionCount
                    LastActivity = $channel.LastActivity
                }
                
                if ($IncludeStatistics) {
                    $channelInfo.Statistics = $channel.Statistics
                    $channelInfo.MaxMessages = $channel.MaxMessages
                    $channelInfo.MessageRetention = $channel.MessageRetention
                }
                
                $channels += $channelInfo
            }
            
            return $channels
        }
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to get channels: $_"
        throw
    }
}
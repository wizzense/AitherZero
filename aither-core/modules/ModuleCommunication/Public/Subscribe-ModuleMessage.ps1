function Subscribe-ModuleMessage {
    <#
    .SYNOPSIS
        Subscribe to messages on a specific channel
    .DESCRIPTION
        Register a handler to receive messages from a channel with optional filtering
    .PARAMETER Channel
        Channel to subscribe to
    .PARAMETER Handler
        ScriptBlock to execute when message is received
    .PARAMETER MessageType
        Optional message type filter
    .PARAMETER SubscriberModule
        Module subscribing to messages
    .PARAMETER Filter
        Additional filter scriptblock
    .PARAMETER RunAsync
        Run handler asynchronously
    .EXAMPLE
        Subscribe-ModuleMessage -Channel "Configuration" -MessageType "ConfigChanged" -Handler {
            param($Message)
            Write-Host "Config changed: $($Message.Data.Module)"
        }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Channel,
        
        [Parameter(Mandatory)]
        [scriptblock]$Handler,
        
        [Parameter()]
        [string]$MessageType = '*',
        
        [Parameter()]
        [string]$SubscriberModule = $MyInvocation.MyCommand.Module.Name,
        
        [Parameter()]
        [scriptblock]$Filter,
        
        [Parameter()]
        [switch]$RunAsync
    )
    
    try {
        # Validate channel exists
        if (-not $script:MessageBus.Channels.ContainsKey($Channel)) {
            Write-CustomLog -Level 'WARNING' -Message "Channel '$Channel' does not exist. Creating it."
            New-MessageChannel -Name $Channel | Out-Null
        }
        
        # Create subscription
        $subscription = @{
            Id = [Guid]::NewGuid().ToString()
            Channel = $Channel
            MessageType = $MessageType
            Handler = $Handler
            Filter = $Filter
            SubscriberModule = $SubscriberModule
            RunAsync = $RunAsync
            CreatedAt = Get-Date
            MessageCount = 0
            LastMessage = $null
            Errors = @()
        }
        
        # Add to subscriptions
        $subscriptionKey = "$Channel|$($subscription.Id)"
        if (-not $script:MessageBus.Subscriptions.TryAdd($subscriptionKey, $subscription)) {
            throw "Failed to add subscription"
        }
        
        # Update channel subscription count
        $channelInfo = $script:MessageBus.Channels[$Channel]
        $channelInfo.SubscriptionCount++
        
        Write-CustomLog -Level 'INFO' -Message "Subscription created: Channel=$Channel, Type=$MessageType, ID=$($subscription.Id)"
        
        # Return subscription info for management
        return @{
            SubscriptionId = $subscription.Id
            Channel = $Channel
            MessageType = $MessageType
            SubscriberModule = $SubscriberModule
        }
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to create subscription: $_"
        throw
    }
}
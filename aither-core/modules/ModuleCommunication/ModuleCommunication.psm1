# AitherZero ModuleCommunication Module
# Provides scalable inter-module communication for the platform

#Requires -Version 7.0

# Import required types
using namespace System.Collections.Concurrent
using namespace System.Threading

# Script-level variables
$script:MessageBus = @{
    Channels = [ConcurrentDictionary[string, object]]::new()
    Subscriptions = [ConcurrentDictionary[string, object]]::new()
    MessageQueue = [ConcurrentQueue[object]]::new()
    EventHistory = [ConcurrentQueue[object]]::new()
    Processor = @{
        Running = $false
        Thread = $null
        CancellationToken = $null
    }
}

$script:APIRegistry = @{
    APIs = [ConcurrentDictionary[string, object]]::new()
    Middleware = [System.Collections.ArrayList]::new()
    Metrics = @{
        TotalCalls = 0
        SuccessfulCalls = 0
        FailedCalls = 0
        CallHistory = [ConcurrentQueue[object]]::new()
    }
}

$script:Configuration = @{
    MaxEventHistory = 1000
    MaxMessageQueueSize = 10000
    ProcessorInterval = 100  # milliseconds
    EnableTracing = $false
    RetryPolicy = @{
        MaxRetries = 3
        RetryDelay = 1000  # milliseconds
        BackoffMultiplier = 2
    }
}

# Import functions
$Public = @(Get-ChildItem -Path "$PSScriptRoot/Public" -Filter '*.ps1' -Recurse -ErrorAction SilentlyContinue)
$Private = @(Get-ChildItem -Path "$PSScriptRoot/Private" -Filter '*.ps1' -Recurse -ErrorAction SilentlyContinue)

foreach ($import in @($Private + $Public)) {
    try {
        . $import.FullName
    } catch {
        Write-Error "Failed to import function $($import.FullName): $_"
    }
}

# Initialize message processor
Initialize-MessageProcessor

# Create backward compatibility aliases
New-Alias -Name 'Publish-ModuleMessage' -Value 'Send-ModuleMessage' -Force
New-Alias -Name 'Subscribe-ModuleMessage' -Value 'Register-ModuleMessageHandler' -Force
New-Alias -Name 'Publish-ModuleEvent' -Value 'Send-ModuleEvent' -Force  
New-Alias -Name 'Subscribe-ModuleEvent' -Value 'Register-ModuleEventHandler' -Force

# Export public functions and aliases
Export-ModuleMember -Function $Public.BaseName -Alias 'Publish-ModuleMessage', 'Subscribe-ModuleMessage', 'Publish-ModuleEvent', 'Subscribe-ModuleEvent'
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

# Universal logging fallback - ensure Write-CustomLog is always available
if (-not (Get-Command Write-CustomLog -ErrorAction SilentlyContinue)) {
    function global:Write-CustomLog {
        param(
            [Parameter(Mandatory = $true)]
            [string]$Message,
            
            [Parameter(Mandatory = $false)]
            [ValidateSet('ERROR', 'WARN', 'WARNING', 'INFO', 'SUCCESS', 'DEBUG', 'TRACE', 'VERBOSE')]
            [string]$Level = 'INFO',
            
            [Parameter(Mandatory = $false)]
            [string]$Source = "ModuleCommunication",
            
            [Parameter(Mandatory = $false)]
            [hashtable]$Context = @{},
            
            [Parameter(Mandatory = $false)]
            [Exception]$Exception = $null
        )
        
        # Normalize level names
        if ($Level -eq 'WARNING') { $Level = 'WARN' }
        
        # Determine color based on level
        $color = switch ($Level) {
            'ERROR' { 'Red' }
            'WARN' { 'Yellow' }
            'SUCCESS' { 'Green' }
            'INFO' { 'Cyan' }
            'DEBUG' { 'Gray' }
            'TRACE' { 'DarkGray' }
            'VERBOSE' { 'DarkCyan' }
            default { 'White' }
        }
        
        # Build log message
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
        $logMessage = "[$timestamp] [$Level] [$Source] $Message"
        
        # Add context if provided
        if ($Context.Count -gt 0) {
            $contextStr = ($Context.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ", "
            $logMessage += " {$contextStr}"
        }
        
        # Add exception if provided
        if ($Exception) {
            $logMessage += " Exception: $($Exception.Message)"
        }
        
        # Output with color
        Write-Host $logMessage -ForegroundColor $color
        
        # Also log to file if possible (fallback file logging)
        try {
            $logPath = if ($env:TEMP) { 
                Join-Path $env:TEMP "AitherZero-Fallback.log" 
            } elseif ($env:TMPDIR) { 
                Join-Path $env:TMPDIR "AitherZero-Fallback.log" 
            } else { 
                "AitherZero-Fallback.log" 
            }
            
            Add-Content -Path $logPath -Value $logMessage -Encoding UTF8 -ErrorAction SilentlyContinue
        } catch {
            # Fail silently for fallback logging
        }
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
New-Alias -Name 'Send-ModuleMessage' -Value 'Submit-ModuleMessage' -Force
New-Alias -Name 'Send-ModuleEvent' -Value 'Submit-ModuleEvent' -Force
New-Alias -Name 'Publish-ModuleMessage' -Value 'Submit-ModuleMessage' -Force
New-Alias -Name 'Subscribe-ModuleMessage' -Value 'Register-ModuleMessageHandler' -Force
New-Alias -Name 'Publish-ModuleEvent' -Value 'Submit-ModuleEvent' -Force
New-Alias -Name 'Subscribe-ModuleEvent' -Value 'Register-ModuleEventHandler' -Force

# Export public functions and aliases
Export-ModuleMember -Function $Public.BaseName -Alias 'Send-ModuleMessage', 'Send-ModuleEvent', 'Publish-ModuleMessage', 'Subscribe-ModuleMessage', 'Publish-ModuleEvent', 'Subscribe-ModuleEvent'

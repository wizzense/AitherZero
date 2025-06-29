# ModuleCommunication Module

The ModuleCommunication module provides scalable inter-module communication for the AitherZero platform through pub/sub messaging, API registry, and event-driven architecture.

## Features

- **Message Bus**: Channel-based pub/sub messaging with filtering
- **API Registry**: Unified API gateway with middleware support
- **Event System**: Enhanced event publishing and subscription
- **Async Support**: Background message processing with retry logic
- **Performance Monitoring**: Comprehensive metrics and tracing
- **Middleware Pipeline**: Extensible request/response processing

## Architecture

### Message Bus
- Channel-based communication
- Message filtering and routing
- Priority-based delivery
- Message expiration (TTL)
- Background processor thread

### API Registry
- Centralized API registration
- Parameter validation
- Middleware pipeline
- Async execution support
- Performance tracking

### Event System
- Built on message bus
- Event history persistence
- Channel broadcasting
- Wildcard subscriptions

## Usage

### Message Bus

#### Creating Channels
```powershell
# Create a new channel
New-MessageChannel -Name "Configuration" -Description "Configuration updates" -MaxMessages 1000

# Get channel information
Get-MessageChannels
```

#### Publishing Messages
```powershell
# Publish a message
$messageId = Publish-ModuleMessage -Channel "Configuration" -MessageType "ConfigChanged" -Data @{
    Module = "LabRunner"
    Setting = "MaxJobs"
    NewValue = 10
} -SourceModule "ConfigurationCore" -Priority "High"
```

#### Subscribing to Messages
```powershell
# Subscribe to messages
$subscription = Subscribe-ModuleMessage -Channel "Configuration" -MessageType "ConfigChanged" -Handler {
    param($Message)
    Write-Host "Config changed: $($Message.Data.Module).$($Message.Data.Setting) = $($Message.Data.NewValue)"
}

# Subscribe with filtering
Subscribe-ModuleMessage -Channel "Configuration" -Handler {
    param($Message)
    # Handle message
} -Filter {
    param($Message)
    $Message.Data.Module -eq "LabRunner"
}
```

### API Registry

#### Registering APIs
```powershell
# Register a module API
Register-ModuleAPI -ModuleName "LabRunner" -APIName "ExecuteStep" -Handler {
    param($StepName, $Parameters)
    Write-Host "Executing step: $StepName"
    # Implementation
    return @{Success = $true; StepName = $StepName}
} -Parameters @{
    StepName = @{
        Type = "string"
        Required = $true
        Description = "Name of the step to execute"
    }
    Parameters = @{
        Type = "hashtable"
        Required = $false
        Description = "Step parameters"
    }
} -Description "Execute a lab automation step"
```

#### Invoking APIs
```powershell
# Synchronous invocation
$result = Invoke-ModuleAPI -Module "LabRunner" -Operation "ExecuteStep" -Parameters @{
    StepName = "DeployVM"
    Parameters = @{VMName = "TestVM"; Memory = "4GB"}
}

# Asynchronous invocation
$job = Invoke-ModuleAPI -Module "LabRunner" -Operation "ExecuteStep" -Parameters @{
    StepName = "LongRunningTask"
} -Async
```

### Event System

#### Publishing Events
```powershell
# Publish an event
Publish-ModuleEvent -EventName "ModuleInitialized" -EventData @{
    ModuleName = "LabRunner"
    Version = "1.0.0"
    InitTime = Get-Date
}

# Broadcast to all channels
Publish-ModuleEvent -EventName "SystemShutdown" -EventData @{
    Reason = "Maintenance"
    ScheduledTime = (Get-Date).AddMinutes(5)
} -Broadcast
```

#### Subscribing to Events
```powershell
# Subscribe to specific event
Subscribe-ModuleEvent -EventName "ModuleInitialized" -Handler {
    param($Event)
    Write-Host "$($Event.Data.ModuleName) initialized at $($Event.Data.InitTime)"
}

# Subscribe with wildcards
Subscribe-ModuleEvent -EventName "Module*" -Handler {
    param($Event)
    Write-Host "Module event: $($Event.Name)"
}
```

### Middleware

#### Adding Global Middleware
```powershell
# Logging middleware
Add-APIMiddleware -Name "Logging" -Priority 10 -Handler {
    param($Context, $Next)
    $start = Get-Date
    Write-CustomLog -Level 'INFO' -Message "API Start: $($Context.APIKey)"
    
    try {
        $result = & $Next $Context
        $duration = ((Get-Date) - $start).TotalMilliseconds
        Write-CustomLog -Level 'INFO' -Message "API Success: $($Context.APIKey) (${duration}ms)"
        return $result
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "API Failed: $($Context.APIKey) - $_"
        throw
    }
}

# Authentication middleware
Add-APIMiddleware -Name "Authentication" -Priority 20 -Handler {
    param($Context, $Next)
    if ($Context.Metadata.RequiresAuth -and -not $Context.User) {
        throw "Authentication required"
    }
    & $Next $Context
}
```

### Performance Monitoring

```powershell
# Get communication metrics
$metrics = Get-CommunicationMetrics

# Display summary
Write-Host "Total Channels: $($metrics.MessageBus.TotalChannels)"
Write-Host "Total APIs: $($metrics.API.TotalAPIs)"
Write-Host "API Success Rate: $($metrics.API.SuccessRate)%"
Write-Host "Average Execution Time: $($metrics.Performance.AverageAPIExecutionTime)ms"

# Get detailed metrics with history
$detailed = Get-CommunicationMetrics -IncludeHistory

# Get channel-specific metrics
$channelMetrics = Get-CommunicationMetrics -Channel "Configuration"
```

### Testing

```powershell
# Run basic tests
$results = Test-ModuleCommunication -TestType Basic

# Run stress test
$results = Test-ModuleCommunication -TestType Stress -Duration 30

# Run full test suite
$results = Test-ModuleCommunication -TestType Full

# Display results
$results.Tests | Format-Table Name, Success, Details -AutoSize
Write-Host "Pass Rate: $($results.PassRate)%"
```

## Best Practices

### Message Publishing
1. Use appropriate channels for different message types
2. Set message priority based on importance
3. Include sufficient context in message data
4. Use TTL to prevent stale message processing

### API Design
1. Define clear parameter schemas
2. Use descriptive API names
3. Implement proper error handling
4. Consider async for long-running operations

### Performance
1. Use filtering to reduce message processing overhead
2. Implement message batching for high-volume scenarios
3. Monitor metrics and adjust configuration as needed
4. Use async handlers for non-critical operations

### Error Handling
1. Implement retry logic in handlers
2. Log errors with sufficient context
3. Use middleware for cross-cutting concerns
4. Monitor failed delivery rates

## Configuration

The module uses these configuration settings:

```powershell
$script:Configuration = @{
    MaxEventHistory = 1000        # Maximum events to retain
    MaxMessageQueueSize = 10000   # Maximum queued messages
    ProcessorInterval = 100       # Message processor interval (ms)
    EnableTracing = $false        # Enable detailed tracing
    RetryPolicy = @{
        MaxRetries = 3            # Maximum retry attempts
        RetryDelay = 1000         # Initial retry delay (ms)
        BackoffMultiplier = 2     # Exponential backoff multiplier
    }
}
```

## Integration Examples

### ConfigurationCore Integration
```powershell
# Publish configuration changes
Register-ModuleAPI -ModuleName "ConfigurationCore" -APIName "NotifyChange" -Handler {
    param($ModuleName, $Setting, $OldValue, $NewValue)
    
    Publish-ModuleEvent -EventName "ConfigurationChanged" -EventData @{
        Module = $ModuleName
        Setting = $Setting
        OldValue = $OldValue
        NewValue = $NewValue
        Timestamp = Get-Date
    }
}
```

### LabRunner Integration
```powershell
# Subscribe to lab events
Subscribe-ModuleEvent -EventName "LabStep*" -Handler {
    param($Event)
    switch ($Event.Name) {
        "LabStepStarted" {
            Write-Host "Step started: $($Event.Data.StepName)"
        }
        "LabStepCompleted" {
            Write-Host "Step completed: $($Event.Data.StepName) in $($Event.Data.Duration)ms"
        }
        "LabStepFailed" {
            Write-Host "Step failed: $($Event.Data.StepName) - $($Event.Data.Error)"
        }
    }
}
```

## Troubleshooting

### Messages Not Being Delivered
1. Check if channel exists: `Get-MessageChannels`
2. Verify subscription is active: `Get-MessageSubscriptions`
3. Check message queue size: `Get-CommunicationMetrics`
4. Enable tracing: `Enable-MessageTracing`

### API Calls Failing
1. Verify API is registered: `Get-ModuleAPIs`
2. Check parameter validation
3. Review middleware pipeline
4. Check execution timeout settings

### Performance Issues
1. Monitor metrics regularly
2. Adjust processor interval for throughput
3. Implement message batching
4. Use async handlers where appropriate
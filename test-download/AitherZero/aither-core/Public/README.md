# AitherCore Public Functions

## Directory Structure

The `Public` directory contains all exported functions that form the public API surface of the AitherCore module. These functions are accessible to users and other modules, providing the primary interface for interacting with the AitherZero platform.

```
Public/
├── Get-PlatformHealth.ps1           # Platform health monitoring
├── Get-PlatformLifecycle.ps1        # Lifecycle state information
├── Get-PlatformStatus.ps1           # Current platform status
├── Initialize-AitherPlatform.ps1    # Platform initialization
├── Initialize-PlatformErrorHandling.ps1  # Error handling setup
├── New-AitherPlatformAPI.ps1        # Create platform API instances
├── Optimize-PlatformPerformance.ps1 # Performance optimization
└── Start-PlatformServices.ps1       # Service startup orchestration
```

## Overview

The Public functions directory represents the official API contract of AitherCore. These functions:

- **Provide Platform Management**: Core operations for the AitherZero platform
- **Enable Service Orchestration**: Coordinate module loading and initialization
- **Offer Health Monitoring**: Real-time platform health and status checks
- **Support Lifecycle Management**: Control platform states and transitions

### Design Philosophy

1. **Discoverable**: Clear, verb-noun naming following PowerShell conventions
2. **Documented**: Comprehensive help with examples
3. **Consistent**: Uniform parameter patterns and output formats
4. **Versioned**: Backward compatibility maintained across versions

## Core Components

### Platform Initialization

#### Initialize-AitherPlatform
Primary entry point for platform initialization:
```powershell
Initialize-AitherPlatform -ConfigPath ".\custom-config.json" -Verbose
```
- Loads core configuration
- Initializes module subsystem
- Establishes logging infrastructure
- Sets up event system

#### Initialize-PlatformErrorHandling
Configures platform-wide error handling:
```powershell
Initialize-PlatformErrorHandling -ErrorLogPath ".\logs\errors.log"
```
- Sets error action preferences
- Configures error logging
- Establishes error recovery mechanisms
- Initializes error telemetry

### Platform Monitoring

#### Get-PlatformStatus
Returns current platform operational status:
```powershell
$status = Get-PlatformStatus -Detailed
```
Returns:
- Module load states
- Service availability
- Resource utilization
- Configuration status

#### Get-PlatformHealth
Performs comprehensive health checks:
```powershell
$health = Get-PlatformHealth -IncludeModules -IncludeServices
```
Checks:
- Core service health
- Module dependencies
- Resource availability
- Performance metrics

#### Get-PlatformLifecycle
Retrieves platform lifecycle information:
```powershell
$lifecycle = Get-PlatformLifecycle
```
Provides:
- Current lifecycle state
- State transition history
- Uptime information
- Maintenance windows

### Platform Operations

#### Start-PlatformServices
Orchestrates platform service startup:
```powershell
Start-PlatformServices -Services @('Logging', 'Monitoring') -Parallel
```
- Manages service dependencies
- Handles startup sequencing
- Provides progress feedback
- Validates service health

#### New-AitherPlatformAPI
Creates platform API instances for advanced operations:
```powershell
$api = New-AitherPlatformAPI -Version "2.0" -Features @('Advanced')
```
- Constructs versioned APIs
- Enables feature flags
- Provides extension points
- Supports custom middleware

#### Optimize-PlatformPerformance
Tunes platform for optimal performance:
```powershell
Optimize-PlatformPerformance -Profile "HighThroughput" -AutoTune
```
- Adjusts resource allocation
- Optimizes module loading
- Configures caching strategies
- Tunes parallel execution

## Module System

Public functions integrate with the broader module ecosystem:

### Module Loading
```powershell
# Platform initialization loads required modules
Initialize-AitherPlatform -RequiredModules @('Logging', 'LabRunner')
```

### Event Integration
```powershell
# Public functions publish events
Start-PlatformServices -Services @('All') # Publishes ServiceStarted events
```

### Cross-Module Communication
```powershell
# Functions use ModuleCommunication for coordination
$api = New-AitherPlatformAPI
$api.SendMessage('LabRunner', 'StartLab', @{LabName='TestLab'})
```

## Usage Examples

### Basic Platform Startup
```powershell
# Initialize platform with defaults
Initialize-AitherPlatform

# Start all services
Start-PlatformServices -All

# Check health
Get-PlatformHealth | Format-Table -AutoSize
```

### Advanced Configuration
```powershell
# Custom initialization
Initialize-AitherPlatform -ConfigPath ".\production.json" `
                         -LogLevel "Verbose" `
                         -Features @('Advanced', 'Experimental')

# Selective service startup
Start-PlatformServices -Services @('Core', 'LabRunner', 'OpenTofuProvider') `
                      -StartupTimeout 300 `
                      -ValidateHealth

# Performance tuning
Optimize-PlatformPerformance -Profile "MemoryOptimized" `
                            -MaxMemoryGB 16 `
                            -EnableProfiling
```

### Monitoring and Diagnostics
```powershell
# Continuous monitoring
while ($true) {
    $status = Get-PlatformStatus -Detailed
    $health = Get-PlatformHealth -IncludePerformance
    
    if ($health.OverallHealth -ne 'Healthy') {
        Send-Alert -Message "Platform health degraded: $($health.Issues)"
    }
    
    Start-Sleep -Seconds 60
}
```

## Development Guidelines

### Function Structure
```powershell
function Verb-PlatformNoun {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]$ParameterName
    )
    
    begin {
        # Initialization
        Write-CustomLog -Level 'Verbose' -Message "Starting $($MyInvocation.MyCommand)"
    }
    
    process {
        try {
            # Main logic
            if ($PSCmdlet.ShouldProcess($Target, $Operation)) {
                # Perform operation
            }
        }
        catch {
            Write-CustomLog -Level 'Error' -Message $_.Exception.Message
            throw
        }
    }
    
    end {
        # Cleanup
        Write-CustomLog -Level 'Verbose' -Message "Completed $($MyInvocation.MyCommand)"
    }
}
```

### Parameter Guidelines

1. **Use Parameter Sets**: Group related parameters
2. **Provide Defaults**: Sensible defaults for common scenarios
3. **Validate Input**: Use validation attributes
4. **Support Pipeline**: Accept pipeline input where appropriate
5. **Use ShouldProcess**: For functions that modify state

### Output Standards

- Return structured objects (PSCustomObject)
- Include type information with [OutputType()]
- Provide consistent property names
- Support common formatting (Format-* cmdlets)

### Error Handling

```powershell
try {
    # Operation
}
catch [SpecificException] {
    # Handle specific exception
    Write-CustomLog -Level 'Warning' -Message "Handled: $_"
}
catch {
    # Log and re-throw
    Write-CustomLog -Level 'Error' -Message "Unhandled: $_"
    throw
}
```

### Help Documentation

Every public function must include:
```powershell
<#
.SYNOPSIS
    Brief description of what the function does.

.DESCRIPTION
    Detailed explanation of function behavior, use cases, and important notes.

.PARAMETER ParameterName
    Description of each parameter.

.EXAMPLE
    Verb-PlatformNoun -Parameter "Value"
    
    Description of what this example does.

.OUTPUTS
    [TypeName]
    Description of output object.

.NOTES
    Additional information, requirements, or warnings.
#>
```

## Testing Public Functions

### Unit Tests
- Test each function in isolation
- Mock dependencies
- Verify parameter validation
- Check error conditions

### Integration Tests
- Test function interactions
- Verify event publishing
- Check module communication
- Validate state changes

### Performance Tests
- Measure execution time
- Monitor resource usage
- Test under load
- Verify optimization effects

## Best Practices

1. **Backward Compatibility**: Never break existing function signatures
2. **Semantic Versioning**: Follow SemVer for API changes
3. **Deprecation Policy**: Provide migration path for deprecated functions
4. **Consistent Naming**: Follow PowerShell verb-noun conventions
5. **Comprehensive Help**: Include examples for all common scenarios
6. **Progress Feedback**: Use Write-Progress for long operations
7. **Respect Preferences**: Honor $ErrorActionPreference, $VerbosePreference
8. **Pipeline Support**: Design for pipeline usage where sensible

## API Evolution

### Adding Functions
- Follow naming conventions
- Provide comprehensive help
- Include unit tests
- Update module manifest

### Modifying Functions
- Add parameters to end of param block
- Use parameter sets for variants
- Maintain backward compatibility
- Document changes in release notes

### Deprecating Functions
- Mark with [Obsolete] attribute
- Log deprecation warnings
- Provide alternative in help
- Remove after grace period
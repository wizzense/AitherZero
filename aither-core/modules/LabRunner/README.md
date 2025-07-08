# LabRunner Module

## Test Status
- **Last Run**: 2025-07-08 17:29:43 UTC
- **Status**: ✅ PASSING (10/10 tests)
- **Coverage**: 0%
- **Platform**: ✅ Windows ✅ Linux ✅ macOS
- **Dependencies**: ✅ All resolved

## Test Results
| Test Suite | Status | Tests | Coverage | Duration |
|------------|--------|-------|----------|----------|
| Unit Tests | ✅ PASS | 10/10 | 0% | 1s |

---
*Test status updated automatically by AitherZero Testing Framework*
## Test Results
| Test Suite | Status | Tests | Coverage | Duration |
|------------|--------|-------|----------|----------|
| Unit Tests | ✅ PASS | 11/11 | 0% | 0.5s |

---
*Test status updated automatically by AitherZero Testing Framework*
## Test Results
| Test Suite | Status | Tests | Coverage | Duration |
|------------|--------|-------|----------|----------|
| Unit Tests | ✅ PASS | 11/11 | 0% | 1.5s |

---
*Test status updated automatically by AitherZero Testing Framework*
## Test Results
| Test Suite | Status | Tests | Coverage | Duration |
|------------|--------|-------|----------|----------|
| Unit Tests | ✅ PASS | 11/11 | 0% | 1.5s |

---
*Test status updated automatically by AitherZero Testing Framework*
## Test Results
| Test Suite | Status | Tests | Coverage | Duration |
|------------|--------|-------|----------|----------|
| Unit Tests | ✅ PASS | 11/11 | 0% | 1.5s |

---
*Test status updated automatically by AitherZero Testing Framework*
## Module Overview

The LabRunner module is the core automation engine for the AitherZero infrastructure framework, providing orchestrated lab deployment, 
parallel execution capabilities, and standardized parameter handling across all automation scripts. It serves as the central coordinator 
for complex multi-step infrastructure deployments.

### Core Functionality and Use Cases

- **Lab Automation Orchestration**: Coordinate complex multi-node lab deployments
- **Parallel Execution Engine**: Execute multiple operations simultaneously with progress tracking
- **Standardized Parameter Handling**: Provide consistent parameter management across all scripts
- **Cross-Platform Compatibility**: Support Windows, Linux, and macOS environments
- **Integration Hub**: Coordinate between OpenTofu, ISO management, and configuration modules
- **Progressive Enhancement**: Support for basic to advanced deployment scenarios

### Integration with Infrastructure Automation

- Orchestrates OpenTofu/Terraform deployments through OpenTofuProvider
- Manages ISO downloads and customization via ISOManager and ISOCustomizer
- Provides standardized logging through the Logging module
- Integrates with ProgressTracking for real-time deployment monitoring
- Supports configuration management through ConfigurationCore

### Key Features and Capabilities

- **Advanced Orchestration Engine**: Intelligent dependency management with critical path analysis
- **Resource-Aware Parallel Processing**: Automatic resource optimization and concurrency tuning
- **Intelligent Scheduling**: Predictive scheduling based on historical performance data
- **Comprehensive Health Monitoring**: Real-time health checks and auto-recovery mechanisms
- **Performance Analytics**: Advanced metrics collection and optimization recommendations
- **Multi-Provider Support**: Seamless integration with OpenTofu, custom providers, and PowerShell scripts
- **Enterprise Security**: Integration with SecureCredentials for enterprise-grade credential management
- **Cross-Platform Compatibility**: Full support for Windows, Linux, and macOS environments
- **Flexible Configuration**: YAML and JSON configuration support with environment-specific settings
- **Failure Recovery**: Multiple failure strategies including retry, rollback, and continuation
- **Dynamic Module Loading**: Dynamic module loading and dependency resolution
- **Comprehensive Error Handling**: Automated recovery with intelligent retry mechanisms
- **Flexible Verbosity Levels**: Different deployment scenarios with appropriate logging
- **CI/CD Integration**: Non-interactive mode support for automated pipelines
- **Validation Modes**: WhatIf mode for deployment validation and testing
- **Automation Support**: Auto mode for fully automated deployments

## Directory Structure

```
LabRunner/
├── LabRunner.psd1                                 # Module manifest
├── LabRunner.psm1                                 # Main module with initialization
├── Public/                                        # Exported functions
│   ├── Initialize-StandardParameters.ps1             # Standard parameter handling
│   ├── Invoke-ParallelLabRunner.ps1                  # Parallel execution engine
│   └── Start-AdvancedLabOrchestration.ps1            # Advanced orchestration engine
├── tests/                                         # Comprehensive test suite
│   └── LabRunner.Tests.ps1                          # Full module test coverage
├── examples/                                      # Usage examples and templates
│   ├── enterprise-lab-config.yaml                   # Enterprise lab configuration
│   └── integration-examples.ps1                     # Module integration examples
├── docs/                                          # Advanced documentation
│   └── PERFORMANCE-OPTIMIZATION-GUIDE.md            # Performance tuning guide
├── Logger.ps1                                    # Local logging fallback
├── Menu.ps1                                       # Interactive menu system
├── Network.ps1                                    # Network configuration utilities
├── Download-Archive.ps1                          # Archive download utilities
├── Expand-All.ps1                                 # Archive extraction utilities
├── Format-Config.ps1                             # Configuration formatting
├── Get-LabConfig.ps1                             # Lab configuration management
├── Get-Platform.ps1                              # Platform detection
├── InvokeOpenTofuInstaller.ps1                   # OpenTofu installation wrapper
├── OpenTofuInstaller.ps1                         # OpenTofu installer logic
├── ScriptTemplate.ps1                            # Script template for new deployments
├── Resolve-ProjectPath.psm1                      # Path resolution utilities
└── UNAPPROVED_VERBS.txt                          # PowerShell verb compliance notes
```

## Core Functions

### Initialize-StandardParameters

Provides standardized parameter handling and validation across all automation scripts.

**Parameters:**
- `ScriptName`: Name of the calling script (auto-detected if not specified)
- `Config`: Configuration object from core runner
- `InputParameters`: PowerShell bound parameters from calling script
- `RequiredParameters`: Array of required parameter names
- `DefaultConfig`: Default configuration to use if none provided

**Returns:** Standardized parameters object with script state

**Script Parameters Object:**
```powershell
@{
    ScriptName = 'MyScript.ps1'
    Verbosity = 'normal'          # silent, normal, detailed
    IsNonInteractive = $false
    IsWhatIfMode = $false
    IsAutoMode = $false
    IsForceMode = $false
    Config = @{}                  # Configuration object
    ModulesLoaded = @()           # Loaded module list
}
```

**Usage Example:**
```powershell
function Deploy-WebServer {
    [CmdletBinding()]
    param(
        [string]$ServerName,
        [string]$Environment = 'Dev',
        [switch]$WhatIf,
        [switch]$Force
    )
    
    # Initialize standardized parameters
    $scriptParams = Initialize-StandardParameters -ScriptName $MyInvocation.MyCommand.Name `
                                                  -InputParameters $PSBoundParameters `
                                                  -RequiredParameters @('ServerName')
    
    # Use standardized parameters
    if ($scriptParams.IsWhatIfMode) {
        Write-Host "Would deploy server: $ServerName" -ForegroundColor Yellow
        return
    }
    
    # Actual deployment logic
    if ($scriptParams.Verbosity -eq 'detailed') {
        Write-Host "Deploying $ServerName in $Environment environment"
    }
}
```

### Invoke-ParallelLabRunner

Executes multiple lab operations in parallel using PowerShell runspaces for improved performance.

**Parameters:**
- `Operations`: Array of operations to execute in parallel
- `MaxParallelism`: Maximum number of concurrent operations (default: CPU cores)
- `Throttle`: Custom throttle limit
- `ShowProgress`: Display progress bars for operations
- `TimeoutMinutes`: Operation timeout in minutes
- `ContinueOnError`: Continue execution if some operations fail

**Returns:** Array of operation results with status and output

**Operation Object Structure:**
```powershell
@{
    Name = 'Operation Name'
    Type = 'Deploy' | 'Configure' | 'Validate' | 'Custom'
    ScriptBlock = { # PowerShell script block to execute }
    Parameters = @{}  # Parameters to pass to script block
    Priority = 1-10   # Execution priority (optional)
    Dependencies = @() # Array of operation names this depends on
}
```

**Usage Example:**
```powershell
# Define parallel operations
$operations = @(
    @{
        Name = 'Deploy-Database'
        Type = 'Deploy'
        ScriptBlock = {
            param($ServerName, $DatabaseName)
            # Database deployment logic
            Write-Output "Deploying database $DatabaseName on $ServerName"
        }
        Parameters = @{
            ServerName = 'SQL-01'
            DatabaseName = 'AppDB'
        }
    },
    @{
        Name = 'Deploy-WebServer'
        Type = 'Deploy'
        ScriptBlock = {
            param($ServerName, $SiteName)
            # Web server deployment logic
            Write-Output "Deploying website $SiteName on $ServerName"
        }
        Parameters = @{
            ServerName = 'WEB-01'
            SiteName = 'MyApp'
        }
        Dependencies = @('Deploy-Database')  # Depends on database
    }
)

# Execute operations in parallel
$results = Invoke-ParallelLabRunner -Operations $operations `
                                   -MaxParallelism 4 `
                                   -ShowProgress `
                                   -TimeoutMinutes 30

# Check results
foreach ($result in $results) {
    if ($result.Success) {
        Write-Host "✓ $($result.Name) completed successfully" -ForegroundColor Green
    } else {
        Write-Warning "✗ $($result.Name) failed: $($result.Error)"
    }
}
```

### Test-ParallelRunnerSupport

Tests whether the current environment supports parallel execution.

**Returns:** Boolean indicating parallel support availability

**Usage Example:**
```powershell
if (Test-ParallelRunnerSupport) {
    # Use parallel execution
    $results = Invoke-ParallelLabRunner -Operations $operations
} else {
    # Fall back to sequential execution
    $results = Invoke-SequentialExecution -Operations $operations
}
```

### Start-LabAutomation

Starts a complete lab automation workflow with orchestrated deployment steps.

**Parameters:**
- `LabName`: Name of the lab to deploy
- `ConfigPath`: Path to lab configuration file
- `ValidationOnly`: Run validation checks only
- `Parallel`: Enable parallel execution where possible

**Returns:** Lab deployment result object

**Usage Example:**
```powershell
# Deploy complete lab environment
$lab = Start-LabAutomation -LabName "WebTier-Lab" `
                          -ConfigPath ".\configs\webtier.json" `
                          -Parallel

# Validation only
$validation = Start-LabAutomation -LabName "WebTier-Lab" `
                                 -ValidationOnly
```

### Get-LabStatus

Retrieves the current status of lab deployments and operations.

**Parameters:**
- `LabName`: Specific lab name to check (optional)
- `IncludeHistory`: Include deployment history

**Returns:** Lab status information

**Usage Example:**
```powershell
# Get all lab statuses
$allLabs = Get-LabStatus

# Get specific lab status
$webTierStatus = Get-LabStatus -LabName "WebTier-Lab" -IncludeHistory
```

### Advanced Lab Orchestration

#### Start-AdvancedLabOrchestration

Provides sophisticated lab deployment orchestration with intelligent dependency management, resource optimization, and failure recovery.

**Parameters:**
- `ConfigurationPath`: Path to the advanced lab configuration file
- `OrchestrationMode`: Execution mode (Sequential, Parallel, Intelligent, or Custom)
- `MaxConcurrency`: Maximum concurrent operations (auto-calculated if not specified)
- `ResourceLimits`: Resource consumption limits (memory, CPU, network)
- `FailureStrategy`: Strategy for handling failures (Stop, Continue, Retry, or Rollback)
- `HealthMonitoring`: Enable continuous health monitoring during deployment
- `PerformanceAnalytics`: Enable performance analytics and optimization recommendations
- `ShowProgress`: Enable enhanced progress tracking with detailed metrics
- `DryRun`: Perform planning and validation without executing changes
- `CustomProviders`: Array of custom provider modules to load

**Returns:** Comprehensive orchestration report with metrics and recommendations

**Usage Example:**
```powershell
# Intelligent orchestration with full monitoring
$result = Start-AdvancedLabOrchestration -ConfigurationPath "./enterprise-lab.yaml" `
    -OrchestrationMode "Intelligent" `
    -HealthMonitoring `
    -PerformanceAnalytics `
    -ShowProgress

# Dry run for validation
$validation = Start-AdvancedLabOrchestration -ConfigurationPath "./complex-deployment.yaml" `
    -DryRun `
    -ShowProgress

# Custom resource limits and failure handling
$result = Start-AdvancedLabOrchestration -ConfigurationPath "./production-lab.yaml" `
    -ResourceLimits @{MaxMemoryGB=32; MaxCPUPercent=80; MaxNetworkMbps=2000} `
    -FailureStrategy "Retry" `
    -MaxConcurrency 8
```

#### Test-ParallelRunnerSupport Function

Tests whether the current environment supports parallel execution and provides detailed capability information.

**Parameters:**
- `Detailed`: Return comprehensive information about parallel execution capabilities

**Returns:** Boolean (simple) or detailed capability report (with -Detailed)

**Usage Example:**
```powershell
# Simple support check
if (Test-ParallelRunnerSupport) {
    # Use parallel execution
    $results = Invoke-ParallelLabRunner -Operations $operations
} else {
    # Fall back to sequential execution
    Write-Warning "Parallel execution not supported, using sequential mode"
}

# Detailed capability analysis
$capabilities = Test-ParallelRunnerSupport -Detailed
Write-Host "Optimal Concurrency: $($capabilities.MaxConcurrency)"
Write-Host "PowerShell Version: $($capabilities.PowerShellVersion)"
Write-Host "ThreadJob Available: $($capabilities.ThreadJobAvailable)"
```

### Supporting Utility Functions

#### Get-Platform
Detects the current platform and returns environment information.

**Returns:** Platform information object

```powershell
$platform = Get-Platform
# Returns: 'Windows', 'Linux', 'MacOS', or 'Unknown'
```

#### Get-LabConfig
Loads and validates lab configuration files.

**Parameters:**
- `ConfigPath`: Path to configuration file
- `Environment`: Target environment (dev, test, prod)

**Returns:** Validated configuration object

```powershell
$config = Get-LabConfig -ConfigPath ".\lab-config.json" -Environment "dev"
```

#### Invoke-ArchiveDownload
Downloads and extracts archive files with progress tracking.

**Parameters:**
- `Url`: Download URL
- `Destination`: Extract destination
- `Format`: Archive format (zip, tar.gz, etc.)

```powershell
Invoke-ArchiveDownload -Url "https://example.com/tools.zip" `
                      -Destination ".\Tools" `
                      -Format "zip"
```

## Workflows

### Complete Lab Deployment Workflow

```powershell
# 1. Initialize lab deployment
$labConfig = @{
    Name = 'Enterprise-Lab'
    Environment = 'Production'
    Nodes = @(
        @{Name='DC-01'; Role='DomainController'; CPU=2; Memory=4GB; Disk=60GB},
        @{Name='SQL-01'; Role='Database'; CPU=4; Memory=8GB; Disk=100GB},
        @{Name='WEB-01'; Role='WebServer'; CPU=2; Memory=4GB; Disk=40GB},
        @{Name='WEB-02'; Role='WebServer'; CPU=2; Memory=4GB; Disk=40GB}
    )
    Network = @{
        Subnet = '192.168.100.0/24'
        Gateway = '192.168.100.1'
        DNS = @('192.168.100.10', '8.8.8.8')
    }
}

# 2. Define deployment operations
$deploymentOps = @(
    @{
        Name = 'Prepare-Infrastructure'
        Type = 'Deploy'
        ScriptBlock = {
            param($Config)
            # Create networks, storage, etc.
            New-LabInfrastructure -Config $Config
        }
        Parameters = @{Config = $labConfig}
        Priority = 1
    },
    @{
        Name = 'Deploy-DomainController'
        Type = 'Deploy'
        ScriptBlock = {
            param($NodeConfig)
            # Deploy and configure domain controller
            New-DomainController @NodeConfig
        }
        Parameters = $labConfig.Nodes[0]
        Dependencies = @('Prepare-Infrastructure')
        Priority = 2
    },
    @{
        Name = 'Deploy-Database'
        Type = 'Deploy'
        ScriptBlock = {
            param($NodeConfig)
            # Deploy SQL Server
            New-DatabaseServer @NodeConfig
        }
        Parameters = $labConfig.Nodes[1]
        Dependencies = @('Deploy-DomainController')
        Priority = 3
    },
    @{
        Name = 'Deploy-WebServers'
        Type = 'Deploy'
        ScriptBlock = {
            param($WebNodes)
            # Deploy multiple web servers in parallel
            foreach ($node in $WebNodes) {
                New-WebServer @node
            }
        }
        Parameters = @{WebNodes = $labConfig.Nodes[2..3]}
        Dependencies = @('Deploy-Database')
        Priority = 4
    }
)

# 3. Execute deployment with parallel processing
$results = Invoke-ParallelLabRunner -Operations $deploymentOps `
                                   -MaxParallelism 2 `
                                   -ShowProgress `
                                   -TimeoutMinutes 120

# 4. Validate deployment
$validation = @(
    @{
        Name = 'Test-DomainConnectivity'
        Type = 'Validate'
        ScriptBlock = { Test-DomainConnection -Domain 'lab.local' }
    },
    @{
        Name = 'Test-DatabaseConnectivity'
        Type = 'Validate'
        ScriptBlock = { Test-DatabaseConnection -Server 'SQL-01' }
    },
    @{
        Name = 'Test-WebServices'
        Type = 'Validate'
        ScriptBlock = { 
            Test-WebService -Servers @('WEB-01', 'WEB-02') 
        }
    }
)

$validationResults = Invoke-ParallelLabRunner -Operations $validation `
                                             -MaxParallelism 3
```

### CI/CD Integration Workflow

```powershell
# Pipeline script for automated lab testing
function Start-CIPipeline {
    [CmdletBinding()]
    param(
        [string]$BuildNumber,
        [string]$Environment = 'Test',
        [switch]$NonInteractive
    )
    
    # Initialize with CI-friendly parameters
    $scriptParams = Initialize-StandardParameters -ScriptName 'CI-Pipeline' `
                                                  -InputParameters $PSBoundParameters
    
    if ($scriptParams.IsNonInteractive) {
        Write-Host "Running in non-interactive mode for CI/CD"
    }
    
    # Define CI/CD operations
    $ciOperations = @(
        @{
            Name = 'Validate-Configuration'
            Type = 'Validate'
            ScriptBlock = {
                param($ConfigPath)
                Test-LabConfiguration -Path $ConfigPath
            }
            Parameters = @{ConfigPath = ".\configs\$Environment.json"}
        },
        @{
            Name = 'Deploy-TestLab'
            Type = 'Deploy'
            ScriptBlock = {
                param($BuildNum, $Env)
                Start-LabAutomation -LabName "CI-Lab-$BuildNum" `
                                   -Environment $Env `
                                   -Parallel
            }
            Parameters = @{BuildNum = $BuildNumber; Env = $Environment}
            Dependencies = @('Validate-Configuration')
        },
        @{
            Name = 'Run-IntegrationTests'
            Type = 'Validate'
            ScriptBlock = {
                param($BuildNum)
                Invoke-IntegrationTests -LabName "CI-Lab-$BuildNum"
            }
            Parameters = @{BuildNum = $BuildNumber}
            Dependencies = @('Deploy-TestLab')
        }
    )
    
    # Execute CI pipeline
    $results = Invoke-ParallelLabRunner -Operations $ciOperations `
                                       -ContinueOnError:$false `
                                       -TimeoutMinutes 60
    
    # Generate CI report
    $ciReport = @{
        BuildNumber = $BuildNumber
        Environment = $Environment
        StartTime = Get-Date
        Results = $results
        Success = ($results | Where-Object Success -eq $false).Count -eq 0
    }
    
    return $ciReport
}
```

### Disaster Recovery Workflow

```powershell
# Automated disaster recovery deployment
function Start-DisasterRecovery {
    param(
        [string]$RecoveryPlan,
        [string]$RecoveryTarget,
        [int]$RTO = 240  # Recovery Time Objective in minutes
    )
    
    # Load recovery plan
    $plan = Get-LabConfig -ConfigPath ".\recovery-plans\$RecoveryPlan.json"
    
    # Define recovery operations with priorities
    $recoveryOps = @(
        @{
            Name = 'Validate-RecoveryTarget'
            Type = 'Validate'
            ScriptBlock = {
                param($Target)
                Test-RecoveryInfrastructure -Target $Target
            }
            Parameters = @{Target = $RecoveryTarget}
            Priority = 1
        },
        @{
            Name = 'Restore-CriticalSystems'
            Type = 'Deploy'
            ScriptBlock = {
                param($Systems)
                # Restore most critical systems first
                foreach ($system in $Systems) {
                    Restore-System @system
                }
            }
            Parameters = @{Systems = $plan.CriticalSystems}
            Dependencies = @('Validate-RecoveryTarget')
            Priority = 2
        },
        @{
            Name = 'Restore-Applications'
            Type = 'Deploy'
            ScriptBlock = {
                param($Apps)
                # Restore applications in parallel
                foreach ($app in $Apps) {
                    Restore-Application @app
                }
            }
            Parameters = @{Apps = $plan.Applications}
            Dependencies = @('Restore-CriticalSystems')
            Priority = 3
        },
        @{
            Name = 'Validate-Recovery'
            Type = 'Validate'
            ScriptBlock = {
                param($Plan)
                Test-RecoveryCompletion -Plan $Plan
            }
            Parameters = @{Plan = $plan}
            Dependencies = @('Restore-Applications')
            Priority = 4
        }
    )
    
    # Execute recovery with aggressive parallelism
    $recoveryResults = Invoke-ParallelLabRunner -Operations $recoveryOps `
                                               -MaxParallelism 8 `
                                               -TimeoutMinutes $RTO `
                                               -ShowProgress
    
    # Recovery report
    $recoveryReport = @{
        Plan = $RecoveryPlan
        Target = $RecoveryTarget
        StartTime = Get-Date
        RTO = $RTO
        Results = $recoveryResults
        RecoveryTime = (Get-Date) - $recoveryResults[0].StartTime
        Success = ($recoveryResults | Where-Object Success -eq $false).Count -eq 0
    }
    
    return $recoveryReport
}
```

## Configuration

### Module Configuration

The LabRunner module supports extensive configuration for different deployment scenarios:

```powershell
# Default configuration
$labRunnerConfig = @{
    # Execution settings
    DefaultParallelism = [Environment]::ProcessorCount
    MaxParallelism = 16
    DefaultTimeout = 60  # minutes
    
    # Logging settings
    VerbosityLevel = 'normal'  # silent, normal, detailed
    LogRetention = 30  # days
    LogPath = Join-Path $env:TEMP "AitherZero\Logs"
    
    # Progress tracking
    ShowProgress = $true
    ProgressRefreshInterval = 2  # seconds
    
    # Error handling
    ContinueOnError = $false
    MaxRetries = 3
    RetryDelay = 30  # seconds
    
    # Platform settings
    PreferredShell = 'PowerShell'
    ShellTimeout = 300  # seconds
    
    # Module loading
    RequiredModules = @('Logging', 'ProgressTracking')
    OptionalModules = @('SecureCredentials', 'RemoteConnection')
}
```

### Environment-Specific Configuration

```powershell
# Development environment
$devConfig = @{
    Verbosity = 'detailed'
    ShowProgress = $true
    ContinueOnError = $true
    MaxParallelism = 2
}

# Production environment
$prodConfig = @{
    Verbosity = 'normal'
    ShowProgress = $false
    ContinueOnError = $false
    MaxParallelism = 8
    LogLevel = 'INFO'
}

# CI/CD environment
$ciConfig = @{
    Verbosity = 'silent'
    NonInteractive = $true
    ShowProgress = $false
    Timeout = 30
}
```

### Operation Templates

Create reusable operation templates:

```powershell
# Web server deployment template
$webServerTemplate = @{
    Name = 'Deploy-WebServer-{0}'
    Type = 'Deploy'
    ScriptBlock = {
        param($ServerName, $SiteName, $Port)
        
        # Standard web server deployment
        Install-IIS -ServerName $ServerName
        New-Website -Name $SiteName -Port $Port
        Start-Website -Name $SiteName
    }
    Parameters = @{}  # Filled by template processor
    Timeout = 20
}

# Database deployment template
$databaseTemplate = @{
    Name = 'Deploy-Database-{0}'
    Type = 'Deploy'
    ScriptBlock = {
        param($ServerName, $InstanceName, $DatabaseName)
        
        # Standard database deployment
        Install-SQLServer -ServerName $ServerName -InstanceName $InstanceName
        New-Database -Name $DatabaseName -Instance $InstanceName
        Initialize-Database -Name $DatabaseName
    }
    Parameters = @{}
    Timeout = 45
}
```

## Templates and Resources

### Lab Configuration Schema

```json
{
  "name": "Enterprise-Lab",
  "version": "1.0",
  "description": "Complete enterprise lab environment",
  "environment": "production",
  "metadata": {
    "created": "2025-01-06T10:00:00Z",
    "owner": "Infrastructure Team",
    "tags": ["production", "web", "database"]
  },
  "infrastructure": {
    "provider": "hyperv",
    "region": "on-premises",
    "network": {
      "subnet": "192.168.100.0/24",
      "gateway": "192.168.100.1",
      "dns": ["192.168.100.10", "8.8.8.8"]
    }
  },
  "nodes": [
    {
      "name": "DC-01",
      "role": "domain-controller",
      "os": "windows-server-2025",
      "cpu": 2,
      "memory": "4GB",
      "disk": "60GB",
      "network": {
        "ip": "192.168.100.10",
        "subnet": "255.255.255.0"
      },
      "services": ["ad-ds", "dns", "dhcp"]
    }
  ],
  "operations": [
    {
      "name": "deploy-infrastructure",
      "type": "deploy",
      "script": "Deploy-Infrastructure.ps1",
      "parameters": {
        "network": "192.168.100.0/24"
      },
      "timeout": 30,
      "priority": 1
    }
  ]
}
```

### Script Template

The module includes a script template for creating new deployment scripts:

```powershell
# Script Template Example
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$LabName,
    
    [Parameter(Mandatory = $false)]
    [string]$Environment = 'Dev',
    
    [Parameter(Mandatory = $false)]
    [ValidateSet('silent', 'normal', 'detailed')]
    [string]$Verbosity = 'normal',
    
    [switch]$WhatIf,
    [switch]$NonInteractive,
    [switch]$Force
)

# Initialize standard parameters
$scriptParams = Initialize-StandardParameters -ScriptName $MyInvocation.MyCommand.Name `
                                              -InputParameters $PSBoundParameters `
                                              -RequiredParameters @('LabName')

# Script logic here
try {
    Write-CustomLog -Level 'INFO' -Message "Starting $($scriptParams.ScriptName)"
    
    # Your deployment logic
    
    Write-CustomLog -Level 'SUCCESS' -Message "Completed $($scriptParams.ScriptName)"
} catch {
    Write-CustomLog -Level 'ERROR' -Message "Failed: $($_.Exception.Message)"
    throw
}
```

## Best Practices

### Lab Automation Guidelines

1. **Operation Design**
   - Keep operations atomic and idempotent
   - Use clear, descriptive names
   - Define proper dependencies
   - Set appropriate timeouts

2. **Parallel Execution**
   ```powershell
   # Good: Independent operations in parallel
   $parallelOps = @(
       @{Name='Deploy-DB'; ScriptBlock={...}},
       @{Name='Deploy-Web'; ScriptBlock={...}; Dependencies=@('Deploy-DB')}
   )
   
   # Avoid: Operations with hidden dependencies
   ```

3. **Error Handling**
   ```powershell
   # Comprehensive error handling
   $operation = @{
       Name = 'Deploy-Service'
       ScriptBlock = {
           try {
               # Deployment logic
               $result = Deploy-Service @args
               return @{Success=$true; Result=$result}
           } catch {
               return @{Success=$false; Error=$_.Exception.Message}
           }
       }
   }
   ```

### Performance Considerations

1. **Parallelism Tuning**
   - Start with CPU core count
   - Monitor resource usage
   - Adjust based on workload type
   - Consider I/O vs CPU bound operations

2. **Memory Management**
   ```powershell
   # Clean up runspaces
   $results = Invoke-ParallelLabRunner -Operations $ops
   
   # Force garbage collection for large deployments
   [System.GC]::Collect()
   [System.GC]::WaitForPendingFinalizers()
   ```

3. **Progress Tracking**
   - Use progress tracking for long operations
   - Batch updates to reduce overhead
   - Provide meaningful status messages

### Testing Patterns

1. **Validation First**
   ```powershell
   # Always validate before deployment
   $validationOps = @(
       @{Name='Validate-Config'; ScriptBlock={...}},
       @{Name='Test-Prerequisites'; ScriptBlock={...}}
   )
   
   $validation = Invoke-ParallelLabRunner -Operations $validationOps
   
   if ($validation | Where-Object Success -eq $false) {
       throw "Validation failed"
   }
   ```

2. **Incremental Deployment**
   ```powershell
   # Deploy in stages
   $stages = @('Infrastructure', 'Core Services', 'Applications', 'Validation')
   
   foreach ($stage in $stages) {
       $stageOps = Get-StageOperations -Stage $stage
       $results = Invoke-ParallelLabRunner -Operations $stageOps
       
       if ($results | Where-Object Success -eq $false) {
           Write-Error "Stage $stage failed"
           break
       }
   }
   ```

## Integration Examples

### With OpenTofuProvider Module

```powershell
# Integrate Terraform/OpenTofu deployments
$terraformOps = @(
    @{
        Name = 'Plan-Infrastructure'
        Type = 'Validate'
        ScriptBlock = {
            param($ConfigPath)
            Import-Module OpenTofuProvider
            New-DeploymentPlan -ConfigPath $ConfigPath -Validate
        }
        Parameters = @{ConfigPath = '.\terraform\main.tf'}
    },
    @{
        Name = 'Deploy-Infrastructure'
        Type = 'Deploy'
        ScriptBlock = {
            param($ConfigPath)
            Start-InfrastructureDeployment -ConfigPath $ConfigPath
        }
        Parameters = @{ConfigPath = '.\terraform\main.tf'}
        Dependencies = @('Plan-Infrastructure')
    }
)

$terraformResults = Invoke-ParallelLabRunner -Operations $terraformOps
```

### With Configuration Management

```powershell
# Configuration-driven deployment
function Start-ConfigDrivenDeployment {
    param([string]$ConfigPath)
    
    # Load configuration
    $config = Get-LabConfig -ConfigPath $ConfigPath
    
    # Convert config to operations
    $operations = foreach ($operation in $config.Operations) {
        @{
            Name = $operation.Name
            Type = $operation.Type
            ScriptBlock = [ScriptBlock]::Create($operation.Script)
            Parameters = $operation.Parameters
            Dependencies = $operation.Dependencies
            Timeout = $operation.Timeout
        }
    }
    
    # Execute with LabRunner
    Invoke-ParallelLabRunner -Operations $operations `
                            -MaxParallelism $config.MaxParallelism
}
```

### Health Monitoring Integration

```powershell
# Continuous health monitoring
function Start-LabWithMonitoring {
    param([string]$LabName)
    
    # Deploy lab
    $deployment = Start-LabAutomation -LabName $LabName
    
    # Start monitoring
    $monitoringOps = @(
        @{
            Name = 'Monitor-Services'
            Type = 'Monitor'
            ScriptBlock = {
                while ($true) {
                    $services = Get-LabStatus -LabName $using:LabName
                    Test-ServiceHealth -Services $services
                    Start-Sleep -Seconds 60
                }
            }
        },
        @{
            Name = 'Monitor-Performance'
            Type = 'Monitor'
            ScriptBlock = {
                while ($true) {
                    $performance = Get-LabPerformance -LabName $using:LabName
                    Test-PerformanceThresholds -Metrics $performance
                    Start-Sleep -Seconds 30
                }
            }
        }
    )
    
    # Start monitoring in background
    $monitoring = Invoke-ParallelLabRunner -Operations $monitoringOps `
                                          -Background
    
    return @{
        Deployment = $deployment
        Monitoring = $monitoring
    }
}
```

## Troubleshooting

### Common Issues

1. **Runspace Errors**
   ```powershell
   # Check runspace health
   Get-Runspace | Where-Object RunspaceStateInfo -eq 'Broken'
   
   # Clean up runspaces
   Get-Runspace | Where-Object RunspaceStateInfo -ne 'Opened' | Remove-Runspace
   ```

2. **Module Loading Issues**
   ```powershell
   # Verify module availability
   Test-ParallelRunnerSupport
   
   # Check module import paths
   $env:PSModulePath -split ';'
   
   # Force reload
   Remove-Module LabRunner -Force
   Import-Module LabRunner -Force
   ```

3. **Parameter Validation**
   ```powershell
   # Debug parameter initialization
   $scriptParams = Initialize-StandardParameters -ScriptName 'Test' `
                                                 -InputParameters @{} `
                                                 -RequiredParameters @('TestParam') `
                                                 -Verbose
   ```

4. **Timeout Issues**
   ```powershell
   # Increase timeouts for slow operations
   $operations = @(
       @{
           Name = 'Long-Operation'
           ScriptBlock = {...}
           Timeout = 120  # 2 hours
       }
   )
   ```

### Diagnostic Commands

```powershell
# Check LabRunner health
Test-LabRunnerHealth

# Get active operations
Get-ActiveLabOperations

# Check system resources
Get-SystemResourceUsage

# Validate configuration
Test-LabConfiguration -Path $configPath

# Check module dependencies
Get-LabRunnerDependencies -Check
```

## Module Dependencies

- **PowerShell 7.0+**: Required for cross-platform support and advanced features
- **Logging Module**: For centralized logging (graceful fallback if unavailable)
- **ProgressTracking Module**: For progress visualization (optional)
- **RunspacePool**: For parallel execution capabilities
- **System.Management.Automation**: For runspace management

## Performance Metrics

### Parallel Execution Benefits

- **CPU-bound operations**: 2-4x improvement with proper parallelism
- **I/O-bound operations**: 5-10x improvement
- **Network operations**: Significant improvement with concurrent connections
- **Mixed workloads**: 3-6x improvement typically observed

### Resource Usage

- **Memory overhead**: ~2-5MB per additional runspace
- **CPU usage**: Scales linearly with parallel operations
- **Network bandwidth**: May saturate with many concurrent downloads

## See Also

- [OpenTofuProvider Module](../OpenTofuProvider/README.md)
- [ISOManager Module](../ISOManager/README.md)
- [ISOCustomizer Module](../ISOCustomizer/README.md)
- [Logging Module](../Logging/README.md)
- [ProgressTracking Module](../ProgressTracking/README.md)
- [PowerShell Runspaces Documentation](https://docs.microsoft.com/en-us/powershell/scripting/developer/hosting/runspace-concepts)
# AitherCore Modules Directory

## Directory Structure

The `modules` directory contains the modular components that extend AitherCore's functionality. Each module is self-contained with its own manifest, implementation, and tests, following PowerShell module best practices.

**Module Count**: 23 active modules (reduced from 30+ through consolidation)

```
modules/
├── Core Infrastructure (4 modules - Required)
│   ├── Logging/                    # Centralized logging system
│   ├── LicenseManager/             # Feature licensing and access control
│   ├── ConfigurationCore/          # Core configuration management
│   └── ModuleCommunication/        # Inter-module messaging bus
│
├── Feature Modules (19 modules - Optional)
│   ├── LabRunner/                  # Lab automation orchestration
│   ├── PatchManager/               # Git workflow automation (v3.0)
│   ├── BackupManager/              # Backup and recovery
│   ├── DevEnvironment/             # Development environment setup
│   ├── OpenTofuProvider/           # Infrastructure deployment
│   ├── ISOManager/                 # ISO download and management
│   ├── ISOCustomizer/              # ISO customization tools
│   ├── ParallelExecution/          # Parallel task execution
│   ├── TestingFramework/           # Unified test orchestration
│   ├── SecureCredentials/          # Enterprise credential management
│   ├── RemoteConnection/           # Multi-protocol connections
│   ├── SystemMonitoring/           # Performance monitoring
│   ├── CloudProviderIntegration/   # Cloud provider abstractions
│   ├── UserExperience/             # Unified user interaction (consolidated)
│   ├── AIToolsIntegration/         # AI tool management
│   ├── ConfigurationCarousel/      # Multi-environment configs
│   ├── ConfigurationRepository/    # Git-based config management
│   ├── OrchestrationEngine/        # Workflow automation
│   └── ProgressTracking/           # Visual progress feedback
│
└── Compatibility Shims (Legacy Support)
    └── compatibility/              # Backward compatibility modules

## Overview

The AitherCore module system provides:

- **Modular Architecture**: Clean separation of concerns
- **Dependency Management**: Automatic module loading and ordering
- **Communication Bus**: Inter-module messaging and events
- **Hot Loading**: Dynamic module loading/unloading
- **Version Control**: Module versioning and compatibility

### Design Principles

1. **Single Responsibility**: Each module has one clear purpose
2. **Loose Coupling**: Modules communicate through defined interfaces
3. **High Cohesion**: Related functionality grouped together
4. **Dependency Injection**: Modules declare dependencies explicitly
5. **Progressive Enhancement**: Core functionality with optional features

## Core Components

### Module Structure

Every module follows this standard structure:
```
ModuleName/
├── ModuleName.psd1         # Module manifest (metadata)
├── ModuleName.psm1         # Module script (implementation)
├── Public/                 # Exported functions
│   └── *.ps1              # One file per public function
├── Private/               # Internal functions
│   └── *.ps1              # One file per private function
├── tests/                 # Module-specific tests
│   └── *.Tests.ps1        # Pester test files
└── README.md              # Module documentation
```

### Module Manifest (.psd1)

Example module manifest:
```powershell
@{
    # Module metadata
    RootModule = 'ModuleName.psm1'
    ModuleVersion = '1.0.0'
    GUID = 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'
    Author = 'AitherZero Team'
    Description = 'Module description'
    PowerShellVersion = '7.0'
    
    # Dependencies
    RequiredModules = @(
        @{ModuleName = 'Logging'; ModuleVersion = '1.0.0'}
        @{ModuleName = 'ModuleCommunication'; ModuleVersion = '1.0.0'}
    )
    
    # Exports
    FunctionsToExport = @('Get-*', 'Set-*', 'New-*', 'Remove-*')
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    
    # Private data
    PrivateData = @{
        PSData = @{
            Tags = @('Infrastructure', 'Automation')
            LicenseUri = 'https://github.com/AitherLabs/AitherZero/LICENSE'
            ProjectUri = 'https://github.com/AitherLabs/AitherZero'
        }
    }
}
```

### Module Script (.psm1)

Standard module script pattern:
```powershell
#Requires -Version 7.0

# Module initialization
$ErrorActionPreference = 'Stop'

# Import functions
$Public = @(Get-ChildItem -Path $PSScriptRoot\Public\*.ps1 -ErrorAction SilentlyContinue)
$Private = @(Get-ChildItem -Path $PSScriptRoot\Private\*.ps1 -ErrorAction SilentlyContinue)

foreach ($import in @($Public + $Private)) {
    try {
        . $import.FullName
    }
    catch {
        Write-Error "Failed to import function $($import.FullName): $_"
    }
}

# Export public functions
Export-ModuleMember -Function $Public.BaseName

# Module initialization code
Initialize-Module
```

## Module System Features

### Module Loading

The module system supports several loading strategies:

1. **Auto-Loading**: Modules load automatically based on configuration
2. **Lazy Loading**: Modules load on first use
3. **Explicit Loading**: Manual module import
4. **Dependency Resolution**: Automatic dependency ordering

```powershell
# Auto-loading via configuration
{
  "modules": {
    "autoLoad": true,
    "required": ["Logging", "LabRunner"],
    "optional": ["DevEnvironment", "AIToolsIntegration"]
  }
}

# Manual loading
Import-Module (Join-Path $PSScriptRoot "modules/PatchManager") -Force

# Lazy loading on function call
function Use-AdvancedFeature {
    Import-Module "OrchestrationEngine" -ErrorAction Stop
    Invoke-Workflow @args
}
```

### Module Communication

Modules communicate through the ModuleCommunication bus:

```powershell
# Register API endpoint
Register-ModuleAPI -ModuleName "MyModule" `
                  -APIName "ProcessData" `
                  -ScriptBlock { param($data) return Process-Data $data }

# Call another module's API
$result = Invoke-ModuleAPI -TargetModule "OtherModule" `
                          -APIName "GetStatus" `
                          -Parameters @{verbose = $true}

# Submit events (formerly Send-ModuleEvent)
Submit-ModuleEvent -EventName "DataProcessed" `
                  -EventData @{RecordCount = 100; Duration = "00:00:45"}

# Register event handlers
Register-ModuleEventHandler -EventName "DataProcessed" `
                           -ModuleName "MyModule" `
                           -Handler { param($data) Write-Log "Processed: $($data.RecordCount)" }
```

### Module Dependencies

Dependencies are managed through:

1. **Manifest Declaration**: RequiredModules in .psd1
2. **Runtime Checking**: Test-ModuleDependency
3. **Version Constraints**: Minimum version requirements
4. **Optional Dependencies**: Soft dependencies for features

```powershell
# Check dependencies
function Test-ModuleDependencies {
    $manifest = Import-PowerShellDataFile "$PSScriptRoot\ModuleName.psd1"
    foreach ($required in $manifest.RequiredModules) {
        if (-not (Get-Module -ListAvailable -Name $required.ModuleName)) {
            throw "Missing required module: $($required.ModuleName)"
        }
    }
}
```

## Module Categories

### Core Infrastructure Modules

These modules are required for basic platform operation:

| Module | Purpose | Dependencies |
|--------|---------|--------------|
| Logging | Centralized logging with multiple targets | None |
| LabRunner | Script execution and lab automation | Logging |
| OpenTofuProvider | Infrastructure as code deployment | Logging, LabRunner |

### Platform Service Modules

Enable advanced platform capabilities:

| Module | Purpose | Dependencies |
|--------|---------|--------------|
| ModuleCommunication | Inter-module messaging | Logging |
| ConfigurationCore | Configuration management | Logging |
| ParallelExecution | Parallel task execution | Logging |
| ProgressTracking | Visual progress feedback | Logging |

### Feature Modules

Add specific functionality:

| Module | Purpose | Dependencies |
|--------|---------|--------------|
| PatchManager | Git workflow automation | Logging, ModuleCommunication |
| DevEnvironment | Development setup | Logging, ConfigurationCore |
| SecureCredentials | Credential management | Logging |
| SystemMonitoring | Performance monitoring | Logging, ModuleCommunication |

## Usage Examples

### Basic Module Import
```powershell
# Import a module
Import-Module (Join-Path $ProjectRoot "aither-core/modules/PatchManager") -Force

# Use module functions
New-Patch -Description "Fix bug" -Changes { 
    # Make changes
}
```

### Module Discovery
```powershell
# Get available modules
$modules = Get-ChildItem -Path "./aither-core/modules" -Directory

# Get module information
foreach ($module in $modules) {
    $manifest = Import-PowerShellDataFile "$($module.FullName)\$($module.Name).psd1"
    [PSCustomObject]@{
        Name = $module.Name
        Version = $manifest.ModuleVersion
        Description = $manifest.Description
    }
}
```

### Dynamic Module Loading
```powershell
# Load modules based on feature flags
$features = Get-EnabledFeatures
foreach ($feature in $features) {
    $moduleName = Get-ModuleForFeature $feature
    if ($moduleName) {
        Import-Module "./modules/$moduleName" -Force
    }
}
```

## Development Guidelines

### Creating a New Module

1. **Create Module Structure**
   ```powershell
   New-ModuleStructure -Name "MyNewModule" -Path "./modules"
   ```

2. **Define Module Manifest**
   ```powershell
   New-ModuleManifest -Path "./modules/MyNewModule/MyNewModule.psd1" `
                      -RootModule "MyNewModule.psm1" `
                      -Author "Your Name" `
                      -Description "Module description"
   ```

3. **Implement Module Script**
   ```powershell
   # MyNewModule.psm1
   #Requires -Version 7.0
   
   # Import common functions
   . "$PSScriptRoot/../../shared/ModuleImporter.ps1"
   
   # Module implementation
   ```

4. **Add Public Functions**
   ```powershell
   # Public/Get-Something.ps1
   function Get-Something {
       [CmdletBinding()]
       param()
       # Implementation
   }
   ```

5. **Write Tests**
   ```powershell
   # tests/MyNewModule.Tests.ps1
   Describe "MyNewModule" {
       It "Should load without errors" {
           { Import-Module "./MyNewModule.psd1" -Force } | Should -Not -Throw
       }
   }
   ```

### Module Best Practices

1. **Single Responsibility**: One clear purpose per module
2. **Minimal Dependencies**: Only depend on what you need
3. **Semantic Versioning**: Follow SemVer for versions
4. **Comprehensive Tests**: Unit and integration tests
5. **Clear Documentation**: README and inline help
6. **Error Handling**: Graceful degradation
7. **Performance**: Lazy loading and caching

### Module Communication Patterns

#### Request-Response
```powershell
# Provider module
Register-ModuleAPI -ModuleName "DataProvider" -APIName "GetData" -ScriptBlock {
    param($query)
    return Get-Data -Query $query
}

# Consumer module
$data = Invoke-ModuleAPI -TargetModule "DataProvider" -APIName "GetData" -Parameters @{query = "SELECT *"}
```

#### Publish-Subscribe
```powershell
# Publisher
Submit-ModuleEvent -EventName "ConfigurationChanged" -EventData @{
    Setting = "MaxConcurrency"
    OldValue = 4
    NewValue = 8
}

# Subscriber
Register-ModuleEventHandler -EventName "ConfigurationChanged" -Handler {
    param($data)
    Update-LocalCache -Setting $data.Setting -Value $data.NewValue
}
```

#### Pipeline
```powershell
# Module pipeline
Get-ModuleData | 
    Transform-Data | 
    Validate-Data | 
    Save-Data
```

## Testing Modules

### Unit Testing
```powershell
Describe "Module Functions" {
    BeforeAll {
        Import-Module "./MyModule.psd1" -Force
    }
    
    Context "Get-Something" {
        It "Returns expected data" {
            $result = Get-Something -Name "Test"
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be "Test"
        }
    }
}
```

### Integration Testing
```powershell
Describe "Module Integration" {
    It "Works with Logging module" {
        Import-Module "./Logging" -Force
        Import-Module "./MyModule" -Force
        
        { Get-Something -Verbose } | Should -Not -Throw
    }
}
```

### Performance Testing
```powershell
Describe "Module Performance" {
    It "Loads quickly" {
        $stopwatch = [Diagnostics.Stopwatch]::StartNew()
        Import-Module "./MyModule.psd1" -Force
        $stopwatch.Stop()
        
        $stopwatch.ElapsedMilliseconds | Should -BeLessThan 1000
    }
}
```

## Module Maintenance

### Version Management

1. **Semantic Versioning**: MAJOR.MINOR.PATCH
2. **Breaking Changes**: Increment MAJOR
3. **New Features**: Increment MINOR
4. **Bug Fixes**: Increment PATCH

### Deprecation Process

```powershell
function Old-Function {
    [Obsolete("Use New-Function instead. This function will be removed in v2.0.0")]
    param()
    
    Write-Warning "Old-Function is deprecated. Use New-Function instead."
    New-Function @PSBoundParameters
}
```

### Module Health Checks

```powershell
function Test-ModuleHealth {
    param($ModuleName)
    
    $health = @{
        LoadTest = $false
        DependencyTest = $false
        FunctionTest = $false
    }
    
    # Test loading
    try {
        Import-Module $ModuleName -Force
        $health.LoadTest = $true
    } catch { }
    
    # Test dependencies
    $manifest = Import-PowerShellDataFile "$ModuleName.psd1"
    $health.DependencyTest = Test-ModuleDependencies $manifest
    
    # Test functions
    $health.FunctionTest = Test-ModuleFunctions $ModuleName
    
    return $health
}
```

## Security Considerations

1. **Input Validation**: Validate all module inputs
2. **Secure Communication**: Encrypt sensitive data in transit
3. **Access Control**: Implement module-level permissions
4. **Audit Logging**: Log security-relevant operations
5. **Dependency Scanning**: Check for vulnerable dependencies

## Performance Optimization

1. **Lazy Loading**: Load resources only when needed
2. **Caching**: Cache expensive operations
3. **Async Operations**: Use parallel execution where possible
4. **Resource Pooling**: Reuse connections and objects
5. **Profiling**: Regular performance profiling

## Troubleshooting

### Common Issues

1. **Module Not Loading**
   - Check PowerShell version
   - Verify manifest syntax
   - Check dependencies

2. **Function Not Found**
   - Verify export in manifest
   - Check function file location
   - Ensure proper dot-sourcing

3. **Performance Issues**
   - Profile module loading
   - Check for circular dependencies
   - Review initialization code

### Debug Techniques

```powershell
# Enable verbose module loading
$VerbosePreference = 'Continue'
Import-Module "./MyModule" -Force -Verbose

# Trace module execution
Set-PSDebug -Trace 2
Import-Module "./MyModule" -Force

# Check module state
Get-Module -Name "MyModule" | Select-Object -Property *
```
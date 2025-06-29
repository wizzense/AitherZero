# Phase 2: Detailed Requirements - AitherZero Platform Architecture

Based on your answers and analysis, here are the detailed requirements for transforming AitherZero into a cohesive PowerShell platform.

## Architecture Vision

Transform AitherZero from a collection of modules into a **tightly integrated PowerShell platform** with:
- Unified configuration management
- Scalable module communication
- Clear dependency management
- Consistent API surface
- Proper build/release packaging

## Core Requirements

### 1. Module Architecture & Integration

#### 1.1 Keep Modular Structure
- **Maintain** the current module-based architecture
- **Do NOT** collapse LabRunner or other modules into AitherCore
- Each module retains its specific responsibility

#### 1.2 Create Dependency & Architecture Documentation
- **New Requirement**: Create visual dependency graph showing module relationships
- Document which modules depend on which
- Define clear module categories:
  - **Core**: Logging, LabRunner, OpenTofuProvider
  - **Platform**: ConfigurationCarousel, OrchestrationEngine, ParallelExecution
  - **Features**: ISOManager, SecureCredentials, SystemMonitoring
  - **Development**: PatchManager, TestingFramework, AIToolsIntegration
  - **Infrastructure**: RestAPIServer, RemoteConnection

#### 1.3 Fix Module Integration Gaps
Update these files to include ALL modules:
- `AitherCore.psm1` - Add missing modules to `$script:CoreModules`
- `Build-Package.ps1` - Add missing modules to `$essentialModules`
- Create `ProgressTracking.psd1` manifest file

### 2. Unified Configuration System

#### 2.1 Central Configuration Store
- Create new `ConfigurationCore` module to manage all configuration
- Single configuration file/store for entire platform
- Environment-specific overlays (dev, staging, prod)
- Hot-reload capability

#### 2.2 Module Configuration API
```powershell
# Each module registers its configuration schema
Register-ModuleConfiguration -ModuleName "LabRunner" -Schema $schema

# Modules retrieve configuration through unified API
$config = Get-ModuleConfiguration -ModuleName "LabRunner"

# Central validation and type checking
Test-ModuleConfiguration -ModuleName "LabRunner" -Configuration $config
```

### 3. Module Communication Architecture

#### 3.1 Hybrid Communication Approach
Based on scalability analysis, implement:

**Phase 1**: Enhanced Event System
- Upgrade existing event system to general-purpose module communication bus
- Channel-based messaging with filtering
- Async message dispatch
- Error handling and retry logic

**Phase 2**: Internal API Gateway
- Extend RestAPIServer pattern for internal use
- Standardized operation registry
- Middleware support (logging, auth, validation)
- Performance monitoring

#### 3.2 Communication Patterns
```powershell
# Event-based for notifications
Publish-ModuleEvent -Channel "LabRunner" -Event "StepCompleted" -Data @{...}

# API-based for operations
$result = Invoke-ModuleAPI -Module "PatchManager" -Operation "CreatePatch" -Parameters @{...}

# Direct calls for tight integration (existing modules)
$status = Get-LabStatus -LabName "TestLab"
```

### 4. Build & Release Configuration

#### 4.1 Multiple Package Types
Create three package profiles:

**Minimal Package**:
- Core modules only (Logging, LabRunner, OpenTofuProvider)
- Basic functionality
- ~10MB size
- For CI/CD environments

**Standard Package**:
- Core + Platform + Features modules
- Excludes development tools
- ~50MB size
- For production deployments

**Full Package**:
- All modules including development tools
- Complete platform
- ~100MB size
- For development environments

#### 4.2 Package Configuration
```powershell
# In Build-Package.ps1
$packageProfiles = @{
    Minimal = @('Logging', 'LabRunner', 'OpenTofuProvider')
    Standard = @('Logging', 'LabRunner', 'OpenTofuProvider', 'ConfigurationCarousel', 
                 'OrchestrationEngine', 'ParallelExecution', 'ProgressTracking', ...)
    Full = @('*') # All modules
}
```

### 5. Unified Platform API

#### 5.1 AitherCore as API Gateway
Transform AitherCore into the primary API surface:
```powershell
# Users interact with AitherCore, not individual modules
$aither = Initialize-AitherPlatform -Profile "Standard"

# Unified operations through AitherCore
$aither.Lab.Execute("DeployInfrastructure")
$aither.Configuration.Switch("Production")
$aither.Orchestration.RunPlaybook("deployment-workflow")
```

#### 5.2 Module Wrapping Pattern
- AitherCore provides wrapper functions for common operations
- Maintains backward compatibility through module exports
- Adds consistent error handling and logging

### 6. Module Initialization & Lifecycle

#### 6.1 Initialization Order
Define strict initialization sequence:
1. **Foundation**: Logging, ConfigurationCore
2. **Security**: SecureCredentials, SecurityAutomation  
3. **Core Services**: LabRunner, ParallelExecution
4. **Platform Services**: ConfigurationCarousel, OrchestrationEngine
5. **Features**: All other modules
6. **API Layer**: RestAPIServer

#### 6.2 Lifecycle Management
```powershell
# Module lifecycle hooks
Register-ModuleLifecycle -ModuleName "LabRunner" -Hooks @{
    OnInitialize = { ... }
    OnShutdown = { ... }
    OnConfigChange = { ... }
}
```

### 7. Development vs Production Separation

#### 7.1 Namespace Separation
- Production modules: `AitherZero.*`
- Development modules: `AitherZero.Dev.*`
- Clear separation in folder structure

#### 7.2 Conditional Loading
```powershell
# In Start-AitherZero.ps1
if ($DeveloperMode) {
    Import-Module AitherZero.Dev.PatchManager
    Import-Module AitherZero.Dev.TestingFramework
}
```

## Implementation Roadmap

### Phase 1: Foundation (Week 1-2)
1. Update module integration in AitherCore.psm1 and Build-Package.ps1
2. Create dependency documentation and visualization
3. Implement ConfigurationCore module
4. Fix missing module manifests

### Phase 2: Communication (Week 3-4)
1. Enhance event system for module communication
2. Create ModuleCommunication module
3. Implement basic API registry pattern
4. Update modules to use new communication patterns

### Phase 3: Packaging (Week 5)
1. Implement multiple package profiles
2. Update build scripts
3. Test package creation and deployment
4. Update GitHub Actions workflow

### Phase 4: Unified API (Week 6-7)
1. Transform AitherCore into API gateway
2. Create wrapper functions for all modules
3. Implement module lifecycle management
4. Documentation and examples

### Phase 5: Polish (Week 8)
1. Performance optimization
2. Enhanced error handling
3. Comprehensive testing
4. User documentation

## Success Metrics

1. **Integration**: All modules properly registered and integrated
2. **Dependency**: Clear dependency graph with no circular dependencies
3. **Communication**: <100ms latency for module communication
4. **Packaging**: Working minimal/standard/full packages
5. **API**: 100% of module functionality accessible through unified API
6. **Testing**: 90%+ code coverage with integration tests

## Next Steps

1. Review and approve these requirements
2. Create implementation tickets/issues
3. Begin Phase 1 implementation
4. Set up progress tracking and reporting
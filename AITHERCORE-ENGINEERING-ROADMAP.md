# AitherCore Engineering Roadmap

**Vision**: Transform AitherZero into AitherCore - a reusable, standalone core engine that powers multiple independent systems and development projects.

**Goal**: Create a "just start it and it works" engine that can be used as a foundation for building derivative projects or as a template repository.

---

## Executive Summary

**Current State**: AitherZero is a monolithic automation platform with 966 functions across 11 domains, tightly coupled to infrastructure automation use cases.

**Target State**: AitherCore is a modular, extensible engine with:
- **Core engine** that "just starts up and works"
- **Plugin architecture** for extending functionality
- **Template repository** capability for derivative projects
- **Zero-configuration startup** with sensible defaults
- **Clean separation** between core and application-specific code

**Timeline**: 12-16 weeks for core transformation  
**Effort**: ~200-300 engineering hours

---

## Architecture Transformation

### Phase 1: Core Engine Extraction (Weeks 1-4)

**Goal**: Extract the essential "engine" from AitherZero into a standalone AitherCore module.

#### 1.1 Identify Core vs. Application Components

**Core Components** (Keep in AitherCore):
```
✅ Configuration System (domains/configuration/)
✅ Logging Framework (domains/utilities/Logging.psm1)
✅ Orchestration Engine (domains/automation/)
✅ Testing Framework (domains/testing/AitherTestFramework.psm1)
✅ Plugin System (NEW - to be created)
✅ Event System (NEW - to be created)
✅ State Management (NEW - to be created)
```

**Application Components** (Move to AitherZero or plugins):
```
❌ Infrastructure management (domains/infrastructure/)
❌ Lab VM automation (specific use case)
❌ OpenTofu/Terraform integration (plugin)
❌ Hyper-V management (plugin)
❌ Certificate automation (plugin)
❌ Git automation (plugin)
```

#### 1.2 Create AitherCore Module Structure

**New Repository Structure**:
```
aithercore/
├── AitherCore.psd1                 # Core manifest
├── AitherCore.psm1                 # Core initialization
├── core/
│   ├── Engine.psm1                 # Main engine controller
│   ├── Configuration.psm1          # Config system
│   ├── Logging.psm1                # Logging system
│   ├── Orchestration.psm1          # Task orchestration
│   ├── PluginManager.psm1          # Plugin loading & management
│   ├── EventBus.psm1               # Event-driven communication
│   └── StateManager.psm1           # Application state
├── plugins/
│   └── README.md                   # Plugin development guide
├── templates/
│   ├── minimal-project/            # Minimal starter template
│   ├── automation-project/         # Automation-focused template
│   └── cli-application/            # CLI app template
├── tests/
│   └── core/                       # Core engine tests
└── docs/
    ├── ENGINE-DESIGN.md
    ├── PLUGIN-DEVELOPMENT.md
    └── GETTING-STARTED.md
```

#### 1.3 Design Principles

**Engine Startup Requirements**:
1. **Zero-configuration default**: `Import-Module AitherCore` just works
2. **Self-initializing**: Creates necessary directories/files on first run
3. **Graceful degradation**: Missing components don't break core functionality
4. **Hot-reload support**: Plugins can be added/removed at runtime
5. **Minimal dependencies**: Only PowerShell 7.0+ required

**Code Example**:
```powershell
# Simple "just start it" usage
Import-Module AitherCore

# Engine auto-initializes and is ready
$core = Start-AitherEngine

# Use core services
$core.Log("Engine started")
$core.Config.Get("AppName")
$core.LoadPlugin("MyCustomPlugin")
```

---

### Phase 2: Plugin Architecture (Weeks 5-8)

**Goal**: Create a robust plugin system that allows extending AitherCore without modifying the core.

#### 2.1 Plugin System Design

**Plugin Interface**:
```powershell
# plugins/PluginInterface.psm1
class AitherPlugin {
    [string] $Name
    [string] $Version
    [string[]] $Dependencies
    [hashtable] $Metadata
    
    # Lifecycle methods
    [void] Initialize([object]$Core) { }
    [void] Start() { }
    [void] Stop() { }
    [void] Unload() { }
    
    # Command registration
    [hashtable] GetCommands() { return @{} }
    
    # Event handlers
    [hashtable] GetEventHandlers() { return @{} }
}
```

**Plugin Discovery**:
- Scan `./plugins/` directory on startup
- Support external plugin paths via config
- Manifest-based metadata (`.plugin.psd1` files)
- Dependency resolution and load ordering

**Plugin Types**:
1. **Extension Plugins**: Add new functionality (e.g., Infrastructure, Git)
2. **Provider Plugins**: Implement interfaces (e.g., CloudProvider, SourceControl)
3. **UI Plugins**: Add interface components (e.g., Dashboards, Menus)
4. **Integration Plugins**: Connect to external systems (e.g., GitHub, Azure)

#### 2.2 Core Services API

**Services Available to Plugins**:
```powershell
class AitherCore {
    [LoggingService] $Log
    [ConfigurationService] $Config
    [OrchestrationService] $Orchestrate
    [EventBus] $Events
    [StateManager] $State
    [PluginManager] $Plugins
    
    # Service access
    [object] GetService([string]$ServiceName) { }
    
    # Event system
    [void] Emit([string]$Event, [object]$Data) { }
    [void] On([string]$Event, [scriptblock]$Handler) { }
}
```

**Plugin Registration Example**:
```powershell
# plugins/InfrastructurePlugin/InfrastructurePlugin.psm1
class InfrastructurePlugin : AitherPlugin {
    InfrastructurePlugin() {
        $this.Name = "Infrastructure"
        $this.Version = "1.0.0"
        $this.Dependencies = @()
    }
    
    [void] Initialize([object]$Core) {
        # Register commands
        $Core.Plugins.RegisterCommand("Deploy-Infrastructure", {
            param($Params)
            # Implementation
        })
        
        # Subscribe to events
        $Core.Events.On("PreDeploy", {
            param($Event)
            # Handle event
        })
    }
}
```

#### 2.3 Migration Strategy

**Convert Existing Domains to Plugins**:
1. Infrastructure → `InfrastructurePlugin`
2. Git Automation → `GitPlugin`
3. Reporting → `ReportingPlugin`
4. Documentation → `DocumentationPlugin`

**Maintain Backward Compatibility**:
- Create `AitherZero` meta-package that loads AitherCore + all legacy plugins
- Existing users import `AitherZero`, new users import `AitherCore`
- Deprecation warnings for old module paths

---

### Phase 3: Template Repository System (Weeks 9-12)

**Goal**: Enable AitherCore to be used as a GitHub template for creating new projects.

#### 3.1 Template Types

**1. Minimal Project Template**:
```
minimal-project/
├── .github/
│   └── workflows/
│       └── test.yml
├── src/
│   └── MyApp.ps1
├── config/
│   └── app.config.psd1
├── plugins/
│   └── README.md
├── tests/
│   └── App.Tests.ps1
├── bootstrap.ps1
└── README.md
```

**Features**:
- AitherCore as submodule or package
- Basic logging and configuration
- Testing framework included
- CI/CD workflow template

**2. Automation Project Template**:
- Number-based script organization
- Orchestration playbooks
- Quality validation
- Report generation

**3. CLI Application Template**:
- Command-line argument parsing
- Interactive UI support
- Help system
- Error handling

#### 3.2 Template Generator

**Script**: `New-AitherProject.ps1`
```powershell
function New-AitherProject {
    param(
        [Parameter(Mandatory)]
        [string]$Name,
        
        [ValidateSet('Minimal', 'Automation', 'CLI', 'Service')]
        [string]$Template = 'Minimal',
        
        [string]$OutputPath = ".",
        
        [switch]$InitializeGit
    )
    
    # Create project from template
    # Set up AitherCore dependency
    # Initialize configuration
    # Create README with next steps
}
```

**Usage**:
```powershell
# Create new automation project
New-AitherProject -Name "MyAutomation" -Template Automation

# Creates:
# ./MyAutomation/
#   ├── Uses AitherCore engine
#   ├── Pre-configured for automation workflows
#   ├── Ready to run
#   └── Documentation included
```

#### 3.3 Dependency Management

**Options for AitherCore Integration**:

**Option A: Git Submodule**
```bash
git submodule add https://github.com/wizzense/AitherCore.git core/engine
```
- Pros: Version pinning, full source access
- Cons: Git submodule complexity

**Option B: PowerShell Module**
```powershell
# In project bootstrap
Install-Module AitherCore -Scope CurrentUser
Import-Module AitherCore
```
- Pros: Simple, uses PSGallery
- Cons: Requires internet, less control

**Option C: Vendored Copy**
```
Copy AitherCore into project tree
```
- Pros: Self-contained, no external dependencies
- Cons: Updates require manual sync

**Recommendation**: Hybrid approach
- Templates include vendored copy (for offline/air-gapped)
- Bootstrap script can update from PSGallery
- Git submodule for developers

---

### Phase 4: Core Engine Features (Weeks 13-16)

**Goal**: Implement missing core features to make the engine production-ready.

#### 4.1 State Management System

**Purpose**: Track application state across sessions

```powershell
class StateManager {
    [hashtable] $State
    [string] $StatePath
    
    [object] Get([string]$Key, [object]$Default = $null)
    [void] Set([string]$Key, [object]$Value)
    [void] Remove([string]$Key)
    [void] Save()
    [void] Load()
    [void] Clear()
}
```

**Features**:
- Persistent state storage (JSON/PSD1)
- In-memory caching
- Thread-safe operations
- Automatic save on shutdown

#### 4.2 Event Bus System

**Purpose**: Decouple components via event-driven architecture

```powershell
class EventBus {
    [hashtable] $Handlers
    
    [void] On([string]$Event, [scriptblock]$Handler)
    [void] Off([string]$Event, [scriptblock]$Handler)
    [void] Emit([string]$Event, [object]$Data)
    [void] EmitAsync([string]$Event, [object]$Data)
}
```

**Built-in Events**:
- `Engine:Starting`
- `Engine:Started`
- `Engine:Stopping`
- `Plugin:Loading`
- `Plugin:Loaded`
- `Config:Changed`
- `State:Changed`

**Usage**:
```powershell
# Plugin listens for config changes
$core.Events.On("Config:Changed", {
    param($Event)
    Write-Host "Config changed: $($Event.Data.Key)"
    # Reload plugin settings
})

# Core emits event when config changes
$core.Config.Set("Theme", "Dark")
$core.Events.Emit("Config:Changed", @{ Key = "Theme"; Value = "Dark" })
```

#### 4.3 Service Container

**Purpose**: Dependency injection for testability and flexibility

```powershell
class ServiceContainer {
    [hashtable] $Services
    
    [void] Register([string]$Name, [scriptblock]$Factory)
    [void] RegisterSingleton([string]$Name, [object]$Instance)
    [object] Resolve([string]$Name)
    [bool] Has([string]$Name)
}
```

**Usage**:
```powershell
# Register services
$core.Services.Register("Database", {
    # Factory creates new instance
    return New-DatabaseConnection -Config $core.Config
})

# Plugins resolve services
$db = $core.Services.Resolve("Database")
```

#### 4.4 Configuration Schema Validation

**Purpose**: Ensure configuration files are valid

```powershell
# Define schema
$schema = @{
    Engine = @{
        LogLevel = @{ Type = 'String'; Values = @('Debug', 'Info', 'Warning', 'Error') }
        PluginPath = @{ Type = 'String'; Required = $false }
    }
}

# Validate config
$core.Config.ValidateSchema($schema)
```

---

## Implementation Roadmap

### Week 1-2: Planning & Design
- [x] Architectural review of current AitherZero
- [ ] Define core vs. application boundaries
- [ ] Design plugin interface and API
- [ ] Create module structure prototype
- [ ] Write design documentation

### Week 3-4: Core Extraction
- [ ] Create `aithercore` repository
- [ ] Extract and refactor Configuration system
- [ ] Extract and refactor Logging system
- [ ] Extract and refactor Orchestration engine
- [ ] Implement basic initialization logic
- [ ] Unit tests for core modules

### Week 5-6: Plugin System
- [ ] Implement PluginManager
- [ ] Create plugin interface/base class
- [ ] Implement plugin discovery
- [ ] Implement dependency resolution
- [ ] Create example plugin
- [ ] Plugin system documentation

### Week 7-8: Plugin Migration
- [ ] Convert Infrastructure domain → plugin
- [ ] Convert Git automation → plugin
- [ ] Convert Reporting → plugin
- [ ] Create AitherZero compatibility layer
- [ ] Integration tests

### Week 9-10: Template System
- [ ] Create minimal project template
- [ ] Create automation project template
- [ ] Create CLI application template
- [ ] Implement New-AitherProject script
- [ ] Template documentation

### Week 11-12: Core Features
- [ ] Implement StateManager
- [ ] Implement EventBus
- [ ] Implement ServiceContainer
- [ ] Configuration schema validation
- [ ] Comprehensive testing

### Week 13-14: Integration & Testing
- [ ] End-to-end integration tests
- [ ] Performance benchmarking
- [ ] Create example projects
- [ ] Documentation review
- [ ] Security audit

### Week 15-16: Release Preparation
- [ ] Beta testing with real projects
- [ ] Bug fixes and polish
- [ ] Final documentation
- [ ] Migration guide for AitherZero users
- [ ] v1.0.0 release

---

## Success Criteria

### Technical Requirements

**Core Engine**:
- ✅ Starts up with zero configuration
- ✅ Loads in <2 seconds on average hardware
- ✅ Memory footprint <50MB without plugins
- ✅ Cross-platform (Windows, Linux, macOS)
- ✅ 100% test coverage on core modules

**Plugin System**:
- ✅ Plugins can be loaded/unloaded at runtime
- ✅ Dependency resolution works correctly
- ✅ Isolated plugin failures don't crash engine
- ✅ Plugin API is stable and versioned
- ✅ Documentation covers all plugin hooks

**Templates**:
- ✅ New project from template in <5 minutes
- ✅ Template projects run without modification
- ✅ Clear upgrade path for AitherCore updates
- ✅ Examples for common use cases
- ✅ CI/CD workflows included

### User Experience Goals

**Developer Experience**:
```powershell
# Goal: This should "just work"
Import-Module AitherCore
$core = Start-AitherEngine
# Engine is ready, no config needed
```

**Project Creation**:
```powershell
# Goal: Create new project in seconds
New-AitherProject -Name "MyApp" -Template CLI
cd MyApp
./bootstrap.ps1  # Everything works
```

**Plugin Development**:
```powershell
# Goal: Simple plugin creation
New-AitherPlugin -Name "MyFeature"
# Template created with all boilerplate
# Developer just fills in logic
```

---

## Migration Strategy

### For Existing AitherZero Users

**Phase 1: Compatibility Layer** (Weeks 1-8)
- AitherZero v2.0 uses AitherCore internally
- All existing functions still work
- No breaking changes
- Deprecation warnings for old patterns

**Phase 2: Migration Tools** (Weeks 9-12)
- Script to convert AitherZero scripts to plugins
- Automated refactoring tools
- Migration documentation
- Example migration projects

**Phase 3: Full Migration** (Weeks 13-16)
- AitherZero becomes a plugin collection on AitherCore
- Clear upgrade path
- Support for both old and new patterns
- Community migration support

### Communication Plan

**Documentation**:
- Migration guide for existing users
- "Why AitherCore?" explanation
- Benefits comparison
- Step-by-step migration tutorial

**Community Engagement**:
- Blog post announcing AitherCore
- Video walkthrough of new architecture
- Discord/Slack for migration support
- Regular progress updates

---

## Risk Assessment

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| Breaking changes alienate users | High | Medium | Maintain compatibility layer, clear migration path |
| Plugin system too complex | High | Low | Simple examples, comprehensive docs, helper tools |
| Performance regression | Medium | Low | Benchmarking, optimization, lazy loading |
| Incomplete migration | Medium | Medium | Phased approach, beta testing, rollback plan |
| Resource constraints | High | Medium | Clear prioritization, MVP approach, community contributions |

---

## Resource Requirements

### Engineering Effort

**Core Team** (2-3 engineers):
- Lead architect: 16 weeks @ 30 hrs/week = 480 hours
- Developer 1: 12 weeks @ 30 hrs/week = 360 hours
- Developer 2: 8 weeks @ 20 hrs/week = 160 hours
- **Total**: ~1000 engineering hours

**Testing & QA**:
- Manual testing: 40 hours
- Automated test development: 80 hours
- Beta testing coordination: 20 hours
- **Total**: 140 hours

**Documentation**:
- Architecture docs: 20 hours
- API reference: 30 hours
- Tutorials and guides: 40 hours
- Migration guide: 20 hours
- **Total**: 110 hours

**Grand Total**: ~1250 hours (equivalent to 2-3 engineers for 4 months)

### Infrastructure

- GitHub repository setup
- CI/CD pipelines
- Test infrastructure
- Documentation hosting
- Community forum/chat

**Cost**: Mostly free tier services, <$100/month

---

## Expected Benefits

### For Project Owner

**Reusability**:
- Use AitherCore for multiple projects without duplicating code
- Template new projects in minutes instead of hours
- Maintain core engine separately from applications

**Flexibility**:
- Build domain-specific tools on same foundation
- Experiment with new ideas using proven core
- Share common functionality across projects

**Maintainability**:
- Fix bugs once in core, benefits all projects
- Clear separation of concerns
- Easier testing and validation

### For Community

**Lower Barrier to Entry**:
- Start new projects with battle-tested foundation
- Focus on business logic, not infrastructure
- Learn from working examples

**Extensibility**:
- Create plugins without forking
- Share plugins with community
- Build ecosystem around core

**Collaboration**:
- Common foundation enables collaboration
- Shared patterns and practices
- Knowledge transfer between projects

---

## Next Steps

### Immediate Actions (This Week)

1. **Review and approve this roadmap**
   - Confirm architectural direction
   - Agree on timeline and resources
   - Identify any missing requirements

2. **Set up AitherCore repository**
   - Create new repo on GitHub
   - Set up basic structure
   - Configure CI/CD

3. **Create proof of concept**
   - Minimal working engine
   - Simple plugin example
   - Basic template

4. **Define API contracts**
   - Plugin interface
   - Core services API
   - Configuration schema

### Week 1-2 Deliverables

- [ ] AitherCore repository created
- [ ] Design documents finalized
- [ ] Proof of concept working
- [ ] API specifications written
- [ ] Team assigned and onboarded

---

## Appendix

### A. Glossary

- **AitherCore**: The reusable core engine
- **AitherZero**: The original monolithic platform (becomes a AitherCore application)
- **Plugin**: Loadable module that extends AitherCore
- **Template**: Project starter using AitherCore as foundation
- **Core Services**: Built-in services (logging, config, events, etc.)
- **Service Container**: Dependency injection system

### B. References

- Current AitherZero architecture documentation
- PowerShell module best practices
- Plugin architecture patterns
- Template repository examples

### C. Related Documents

- `ENGINE-DESIGN.md`: Detailed technical design
- `PLUGIN-DEVELOPMENT.md`: Plugin developer guide
- `MIGRATION-GUIDE.md`: AitherZero to AitherCore migration
- `API-REFERENCE.md`: Complete API documentation

---

**Document Version**: 1.0  
**Created**: October 30, 2025  
**Author**: David (Project Manager Agent)  
**Status**: Proposal - Awaiting Approval  
**Next Review**: After stakeholder feedback

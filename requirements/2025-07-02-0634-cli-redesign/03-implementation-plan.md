# Implementation Plan: AitherZero CLI Redesign

## Immediate Fixes (Week 1)

### Fix Current Quickstart Issues

1. **Fix Export-ModuleMember Error**
   - Remove `Export-ModuleMember` from `Show-DynamicMenu.ps1`
   - Convert to proper module or keep as dot-sourced script

2. **Fix Module Loading Order**
   - Modify `Start-AitherZero.ps1` to load Logging module first
   - Create dependency graph for module loading
   - Add retry logic for dependent modules

3. **Simplify Entry Points**
   - Create single `aither.ps1` entry point
   - Deprecate complex parameter handling
   - Add clear error messages

4. **Create Quick Win Script**
   ```powershell
   # Quick setup script
   ./quick-setup.ps1
   # - Detects platform
   # - Installs prerequisites  
   # - Runs minimal setup
   # - Provides clear next steps
   ```

## Short-term Bridge Solution (Weeks 2-4)

### PowerShell-based CLI Wrapper

Create a new PowerShell-based CLI that wraps existing functionality:

```powershell
# New aither.ps1 structure
param(
    [Parameter(Position=0)]
    [string]$Command,
    
    [Parameter(Position=1)]
    [string]$SubCommand,
    
    [Parameter(ValueFromRemainingArguments)]
    [string[]]$Arguments
)

# Route to appropriate module
switch ($Command) {
    "init"     { Invoke-AitherInit @Arguments }
    "deploy"   { Invoke-AitherDeploy $SubCommand @Arguments }
    "workflow" { Invoke-AitherWorkflow $SubCommand @Arguments }
    "dev"      { Invoke-AitherDev $SubCommand @Arguments }
    default    { Show-AitherHelp }
}
```

### Benefits of Bridge Solution
- Immediate improvement to UX
- Maintains existing module functionality
- Allows gradual migration
- Provides consistent interface

## Long-term Implementation (Months 2-6)

### Technology Stack Decision

**Recommended: Go**
- Excellent cross-platform support
- Easy binary distribution
- Strong CLI libraries (Cobra, Viper)
- Good PowerShell interop
- Fast compilation

**Alternative: Rust**
- Better performance
- Memory safety
- Steeper learning curve
- Longer development time

### Core Development Phases

#### Phase 1: Foundation (Month 2)
```go
// cmd/aither/main.go
package main

import (
    "github.com/spf13/cobra"
    "github.com/aitherzero/aither/internal/cli"
    "github.com/aitherzero/aither/internal/config"
    "github.com/aitherzero/aither/internal/plugin"
)

func main() {
    config.Load()
    plugin.LoadCore()
    cli.Execute()
}
```

#### Phase 2: Core Commands (Month 3)
- Implement init/setup flow
- Basic deploy commands
- Configuration management
- Help system

#### Phase 3: PowerShell Integration (Month 4)
- Call PowerShell modules from Go
- Gradually migrate logic to Go
- Maintain compatibility layer

#### Phase 4: API Server (Month 5)
- REST API implementation
- OpenAPI documentation
- Authentication system
- WebSocket support

#### Phase 5: Plugin System (Month 6)
- Plugin loader implementation
- Plugin API definition
- Core plugins migration
- Plugin marketplace

## Migration Strategy

### For Users

1. **Parallel Availability**
   - Keep old system working
   - New CLI available as `aither`
   - Gradual feature parity

2. **Migration Tools**
   ```bash
   # Convert old scripts
   aither migrate script.ps1
   
   # Import old configuration
   aither config import ~/.aitherzero/config
   ```

3. **Documentation**
   - Migration guides
   - Video tutorials
   - Command mapping reference

### For Developers

1. **Module to Plugin Conversion**
   ```yaml
   # Plugin conversion mapping
   modules:
     OpenTofuProvider:
       plugin: deploy-opentofu
       commands: [deploy]
       tier: pro
   ```

2. **API Compatibility Layer**
   - PowerShell cmdlet wrappers
   - REST API endpoints
   - Event bridge

## Quick Start Experience Design

### New User Flow
```bash
# 1. Download and run
curl -sSL https://aitherzero.io/install | bash
# or
iwr https://aitherzero.io/install.ps1 | iex

# 2. Initialize
aither init
# Interactive wizard:
# - Detect environment
# - Set up prerequisites
# - Configure defaults
# - Install core plugins

# 3. First deployment
aither deploy create my-infra
cd my-infra
aither deploy plan
aither deploy apply

# 4. Success!
```

### AI Agent Flow
```bash
# 1. Start API server
aither server start --token $TOKEN

# 2. AI makes API calls
POST /api/v1/deploy/create
{
  "name": "my-infrastructure",
  "template": "basic-vm-setup"
}

# 3. Monitor progress
GET /api/v1/deploy/status
WebSocket: /api/v1/events
```

## Development Guidelines

### Code Organization
```
aither/
├── cmd/
│   └── aither/         # CLI entry point
├── internal/
│   ├── cli/           # Command definitions
│   ├── config/        # Configuration
│   ├── plugin/        # Plugin system
│   ├── api/           # REST API
│   └── core/          # Core business logic
├── pkg/
│   ├── deploy/        # Deployment logic
│   ├── workflow/      # Orchestration
│   └── powershell/    # PS integration
├── plugins/           # Built-in plugins
├── docs/             # Documentation
└── test/             # Tests
```

### Testing Strategy
- Unit tests for all packages
- Integration tests for CLI commands
- E2E tests for workflows
- Performance benchmarks
- Cross-platform CI/CD

## Timeline Summary

**Week 1**: Fix critical issues, improve current experience
**Weeks 2-4**: Build PowerShell-based bridge CLI
**Month 2**: Start Go-based implementation
**Month 3**: Core command implementation
**Month 4**: PowerShell integration
**Month 5**: API server development
**Month 6**: Plugin system and migration tools

## Success Criteria

1. **Immediate (Week 1)**
   - Quickstart works without errors
   - Clear error messages
   - < 2 minutes to first success

2. **Short-term (Month 1)**
   - Consistent CLI interface
   - All major functions accessible
   - Improved documentation

3. **Long-term (Month 6)**
   - Single binary distribution
   - Full API availability
   - Plugin ecosystem
   - Cross-platform support
   - Sub-second response times
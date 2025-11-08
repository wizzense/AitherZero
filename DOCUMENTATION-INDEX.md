# Complete Documentation Index

## Overview

This index provides a comprehensive map of all AitherZero documentation, organized by audience and purpose.

## For New Users

**Start Here:**
1. `README.md` - Project overview and quick start
2. `library/docs/DEVELOPMENT-SETUP.md` - Environment setup
3. `library/docs/UNIFIED-MENU-DESIGN.md` - Understanding the CLI/menu system

## For Developers

### Architecture Documentation
- **`library/docs/CONFIG-DRIVEN-ARCHITECTURE.md`** - How config.psd1 drives the entire system
- **`library/docs/UNIFIED-MENU-DESIGN.md`** - CLI/menu unification design philosophy
- **`library/docs/EXTENSIONS.md`** - Extension system and plugin architecture
- **`library/docs/ARCHITECTURE-AUTOMATED-REPORTS.md`** - Reporting system architecture
- **`library/docs/COPILOT-ARCHITECTURE.md`** - Copilot integration architecture

### Development Guides
- **`library/docs/STYLE-GUIDE.md`** ⭐ - **Code style, naming conventions, templates**
- **`library/docs/INTEGRATION-TESTING-GUIDE.md`** ⭐ - **Integration test patterns and requirements**
- **`library/docs/AI-AGENT-GUIDE.md`** ⭐ - **AI agent code generation guidelines**
- **`library/docs/DEVELOPMENT-SETUP.md`** - Local development environment
- **`library/docs/CI-CD-GUIDE.md`** - CI/CD pipeline guide
- **`library/docs/TESTING-GUIDE.md`** - Testing framework (to be created)

### Configuration & Setup
- **`library/docs/CONFIGURATION.md`** - Configuration system details
- **`library/docs/Bootstrap-To-Infrastructure-Flow.md`** - Bootstrap process
- **`library/docs/COPILOT-DEV-ENVIRONMENT.md`** - VS Code + Copilot setup
- **`library/docs/COPILOT-MCP-SETUP.md`** - Model Context Protocol setup

### Infrastructure & Operations
- **`library/docs/DOCKER-CONTAINER-GUIDE.md`** - Container usage
- **`library/docs/DOCKER-USAGE.md`** - Docker integration
- **`.github/workflows/README.md`** - Workflow documentation

## For AI Agents & Copilot

### Essential Reading (in order)
1. **`.github/copilot-instructions.md`** - Main instructions for AI agents
2. **`library/docs/AI-AGENT-GUIDE.md`** ⭐ - Templates and generation patterns
3. **`library/docs/STYLE-GUIDE.md`** ⭐ - Code standards and conventions
4. **`library/docs/INTEGRATION-TESTING-GUIDE.md`** ⭐ - Testing requirements

### Quick Reference
- **`library/docs/COPILOT-QUICK-REFERENCE.md`** - Quick commands and patterns
- **`.github/prompts/`** - Reusable one-shot prompts
- **`.github/copilot.yaml`** - Custom agent routing config

## For Maintainers

### Style & Standards
- **`library/docs/STYLE-GUIDE.md`** - PowerShell standards, extension templates, UI guidelines
- **`library/docs/INTEGRATION-TESTING-GUIDE.md`** - Integration test requirements
- **`CONTRIBUTING.md`** - Contribution guidelines (if exists)

### Architecture & Design
- **`library/docs/CONFIG-DRIVEN-ARCHITECTURE.md`** - System design principles
- **`library/docs/EXTENSIONS.md`** - Extension system internals
- **`library/docs/UNIFIED-MENU-DESIGN.md`** - CLI/UI design rationale

### Operations
- **`library/docs/CI-CD-GUIDE.md`** - CI/CD management
- **`library/docs/ARCHIVE-SYSTEM.md`** - Archive management
- **`library/docs/AUTOMATED-ISSUE-TRACKING.md`** - Issue automation

## By Topic

### Configuration System
- `library/docs/CONFIG-DRIVEN-ARCHITECTURE.md` - Architecture
- `library/docs/CONFIGURATION.md` - Details
- `library/docs/STYLE-GUIDE.md` (Config section) - Standards
- Script: `0413_Validate-ConfigManifest.ps1` - Validation

### Extension System
- `library/docs/EXTENSIONS.md` - User guide
- `library/docs/STYLE-GUIDE.md` (Extension section) - Templates
- `library/docs/AI-AGENT-GUIDE.md` (Extension section) - Generation
- `domains/utilities/ExtensionManager.psm1` - Implementation

### CLI/Menu System
- `library/docs/UNIFIED-MENU-DESIGN.md` - Design philosophy
- `library/docs/STYLE-GUIDE.md` (CLI section) - Command patterns
- `library/docs/INTEGRATION-TESTING-GUIDE.md` (CLI section) - Testing
- `domains/experience/Components/CommandParser.psm1` - Implementation
- `domains/experience/Components/BreadcrumbNavigation.psm1` - Navigation

### Testing
- `library/docs/INTEGRATION-TESTING-GUIDE.md` - Integration tests
- `library/docs/STYLE-GUIDE.md` (Testing section) - Test standards
- `library/docs/AI-AGENT-GUIDE.md` (Testing section) - Test generation
- Scripts: `0402` (unit), `0403` (integration), `0409` (all)

### UI/UX
- `library/docs/UNIFIED-MENU-DESIGN.md` - Menu design
- `library/docs/STYLE-GUIDE.md` (UI section) - Rendering guidelines
- `library/docs/INTEGRATION-TESTING-GUIDE.md` (UI section) - UI tests
- `domains/experience/InteractiveUI.psm1` - Implementation

## By File Type

### Markdown Documentation (library/docs/)
```
library/docs/
├── AI-AGENT-GUIDE.md ⭐           # AI agent code generation
├── STYLE-GUIDE.md ⭐              # Code style standards
├── INTEGRATION-TESTING-GUIDE.md ⭐ # Integration tests
├── CONFIG-DRIVEN-ARCHITECTURE.md  # Config system design
├── EXTENSIONS.md                  # Extension guide
├── UNIFIED-MENU-DESIGN.md         # CLI/menu design
├── CONFIGURATION.md               # Config details
├── DEVELOPMENT-SETUP.md           # Dev environment
├── CI-CD-GUIDE.md                 # CI/CD guide
├── COPILOT-*.md                   # Copilot guides
├── DOCKER-*.md                    # Docker guides
└── archive/                       # Historical docs
```

### GitHub Configuration (.github/)
```
.github/
├── copilot-instructions.md ⭐     # Main AI instructions
├── copilot.yaml                   # Agent routing
├── mcp-servers.json               # MCP config
├── prompts/                       # Reusable prompts
│   ├── github-actions-troubleshoot.md
│   ├── use-aitherzero-workflows.md
│   └── ...
└── workflows/                     # CI/CD workflows
```

### Code Documentation
```
domains/
├── experience/
│   ├── README.md                  # Experience domain
│   └── Components/
│       ├── CommandParser.psm1     # CLI parsing
│       └── BreadcrumbNavigation.psm1 # Navigation
├── utilities/
│   └── ExtensionManager.psm1      # Extension system
└── configuration/
    └── ConfigManager.psm1         # Config management

extensions/
└── ExampleExtension/
    └── README.md                  # Extension example
```

## Common Workflows

### Adding New Feature
1. Read: `STYLE-GUIDE.md`
2. Follow templates from: `AI-AGENT-GUIDE.md`
3. Write tests per: `INTEGRATION-TESTING-GUIDE.md`
4. Update: `config.psd1` if needed
5. Validate: `./automation-scripts/0413_Validate-ConfigManifest.ps1`
6. Test: `Invoke-Pester -Path "./tests"`

### Creating Extension
1. Read: `library/docs/EXTENSIONS.md`
2. Use templates from: `library/docs/STYLE-GUIDE.md` (Extension section)
3. Generate with: `New-ExtensionTemplate`
4. Test per: `library/docs/INTEGRATION-TESTING-GUIDE.md`
5. Update: `config.psd1` EnabledExtensions
6. Validate and test

### Modifying Config
1. Read: `library/docs/CONFIG-DRIVEN-ARCHITECTURE.md`
2. Follow rules from: `library/docs/STYLE-GUIDE.md` (Config section)
3. Make changes to: `config.psd1`
4. Validate: `./automation-scripts/0413_Validate-ConfigManifest.ps1`
5. Test rendering per: `library/docs/INTEGRATION-TESTING-GUIDE.md`

### Writing Tests
1. Read: `library/docs/INTEGRATION-TESTING-GUIDE.md`
2. Follow standards from: `library/docs/STYLE-GUIDE.md` (Testing section)
3. Use templates from: `library/docs/AI-AGENT-GUIDE.md` (Testing section)
4. Run: `Invoke-Pester`
5. Verify coverage: 80%+ required

## Key Principles (Quick Reference)

### Architecture
- **Config.psd1 is the single source of truth**
- Everything is driven by manifest (modes, features, scripts)
- Extensions use 8000-8999 script range
- Menu IS the CLI (same commands, unified interface)

### Code Style
- Use approved PowerShell verbs (`Get-Verb`)
- PascalCase for functions and parameters
- Comment-based help for all public functions
- Error handling with try/catch
- Cross-platform compatible code

### Testing
- Minimum 80% code coverage
- Unit tests for all functions
- Integration tests for component interaction
- End-to-end tests for workflows
- Run `Invoke-Pester` before committing

### Configuration
- Validate with `0413` after all changes
- ScriptInventory must match actual scripts
- SupportedModes must be consistent
- Extensions must exist if enabled

### UI/CLI
- Breadcrumbs show navigation path
- Commands build from navigation
- Menu and CLI use identical structure
- UI renders from config capabilities

## Quick Links

**Most Important Documents:**
1. `.github/copilot-instructions.md` - Start here (AI agents)
2. `library/docs/STYLE-GUIDE.md` - Code standards
3. `library/docs/AI-AGENT-GUIDE.md` - Generation templates
4. `library/docs/INTEGRATION-TESTING-GUIDE.md` - Testing requirements
5. `library/docs/CONFIG-DRIVEN-ARCHITECTURE.md` - System design

**Quick Commands:**
```powershell
# Validate everything
./automation-scripts/0413_Validate-ConfigManifest.ps1
./automation-scripts/0404_Run-PSScriptAnalyzer.ps1
./automation-scripts/0407_Validate-Syntax.ps1 -All
Invoke-Pester -Path "./tests"

# Create extension
New-ExtensionTemplate -Name "MyExt" -Path "./extensions"

# Switch config
Show-ConfigurationSelector
```

## Documentation Status

### Complete ✅
- [x] Style Guide
- [x] Integration Testing Guide
- [x] AI Agent Guide
- [x] Config-Driven Architecture
- [x] Extensions Guide
- [x] Unified Menu Design
- [x] Copilot Instructions

### In Progress 🚧
- [ ] Testing Guide (general)
- [ ] Contribution Guide
- [ ] Troubleshooting Guide

### Planned 📋
- [ ] API Reference (generated)
- [ ] Video Tutorials
- [ ] Extension Marketplace Guide

## Getting Help

**Questions about:**
- **Code style?** → `library/docs/STYLE-GUIDE.md`
- **Integration tests?** → `library/docs/INTEGRATION-TESTING-GUIDE.md`
- **AI generation?** → `library/docs/AI-AGENT-GUIDE.md`
- **Config system?** → `library/docs/CONFIG-DRIVEN-ARCHITECTURE.md`
- **Extensions?** → `library/docs/EXTENSIONS.md`
- **CLI/Menu?** → `library/docs/UNIFIED-MENU-DESIGN.md`

**Still stuck?**
- Check `.github/prompts/` for troubleshooting prompts
- Review `library/docs/COPILOT-QUICK-REFERENCE.md`
- Run demo scripts: `library/docs/demos/Demo-*.ps1`

---

## Summary

AitherZero has comprehensive documentation covering:
- ✅ **Architecture** - Config-driven design, extensions, CLI/menu unification
- ✅ **Standards** - Code style, naming, structure, templates
- ✅ **Testing** - Unit, integration, end-to-end test patterns
- ✅ **AI Agents** - Code generation, templates, validation procedures
- ✅ **Operations** - CI/CD, Docker, infrastructure
- ✅ **Development** - Setup, workflows, troubleshooting

**Version:** 1.0.0  
**Last Updated:** 2025-11-05  
**Total Documentation:** 20+ guides, ~200KB  
**Maintainer:** AitherZero Team

---

## Document Change Log

**2025-11-05:**
- Added `STYLE-GUIDE.md` (21KB)
- Added `INTEGRATION-TESTING-GUIDE.md` (26KB)
- Added `AI-AGENT-GUIDE.md` (19KB)
- Updated `copilot-instructions.md` with references
- Created `DOCUMENTATION-INDEX.md` (this file)

# AitherZero v2.0 - Modern CLI Interface

Welcome to the **completely redesigned** AitherZero CLI experience! 🚀

## What's New?

### 🎯 **Clean, Modern Interface**
- Simple command structure: `aither [command] [subcommand] [options]`
- Consistent with modern tools like `docker`, `kubectl`, `gh`
- Built-in help system with examples
- Color-coded output for better readability

### 🛠 **Fixed Critical Issues**
- ✅ Resolved `Export-ModuleMember` errors
- ✅ Fixed module loading dependency issues
- ✅ Improved error handling and user feedback
- ✅ Streamlined quickstart experience

### 🎛 **Multiple Entry Points**
Choose the experience that works best for you:

1. **Modern CLI** (Recommended): `./aither.ps1` or `aither` (Windows)
2. **Quick Setup**: `./quick-setup.ps1` 
3. **Original Interface**: `./Start-AitherZero.ps1` (still works)

## Quick Start (2 minutes!)

### Option 1: Quick Setup (Recommended for new users)
```bash
# Run the streamlined setup
./quick-setup.ps1

# Start using AitherZero
./aither.ps1 help
```

### Option 2: Modern CLI Direct
```bash
# Initialize AitherZero
./aither.ps1 init

# Explore commands
./aither.ps1 help
```

### Option 3: Windows Users
```cmd
# Use the convenient batch file
aither help
aither init
```

## Command Reference

### Core Commands

```bash
aither init              # Initialize AitherZero (first-time setup)
aither deploy            # Infrastructure deployment (OpenTofu/Terraform)
aither workflow          # Orchestration and playbook execution  
aither dev               # Development workflow automation
aither config            # Configuration management
aither plugin            # Plugin management
aither server            # REST API server mode
aither help              # Show help information
```

### Examples

```bash
# Setup and initialization
aither init                                    # Interactive setup
aither init --auto --profile developer        # Automated setup

# Development workflow (WORKING NOW!)
aither dev release patch "Fix authentication bug"
aither dev release minor "Add new features"
aither dev release major "Breaking changes"

# Infrastructure (Coming soon)
aither deploy plan ./infrastructure
aither deploy apply --auto-approve
aither workflow run deployment.yaml --env production

# Configuration (Coming soon)
aither config switch production
aither config set api.timeout 30

# Help system
aither help                    # General help
aither deploy help            # Command-specific help
aither dev release help       # Subcommand help
```

## What Works Right Now?

### ✅ **Fully Functional**
- `aither init` - Interactive setup with SetupWizard
- `aither dev release` - Complete automated release workflow
- `aither help` - Comprehensive help system
- Module loading with proper dependency order
- Error-free startup experience

### 🔄 **Coming Soon** (Next Sprint)
- `aither deploy` commands (OpenTofu integration)
- `aither workflow` commands (Orchestration Engine)
- `aither config` commands (Configuration management)
- `aither plugin` system
- `aither server` API mode

## Architecture Overview

This is a **bridge solution** that provides a modern CLI interface while leveraging the existing powerful AitherZero modules:

```
aither.ps1 (New CLI Interface)
    ↓
Routes to existing modules:
    • SetupWizard for init
    • PatchManager for dev commands  
    • OpenTofuProvider for deploy
    • OrchestrationEngine for workflow
    • ConfigurationCarousel for config
```

## For Developers

### Module Integration
The new CLI routes commands to existing modules:

```powershell
# Example: aither dev release patch "Bug fix"
# Routes to:
Import-Module PatchManager -Force
Invoke-ReleaseWorkflow -ReleaseType "patch" -Description "Bug fix"
```

### Adding New Commands
1. Add command to the switch statement in `aither.ps1`
2. Create handler function that loads appropriate module
3. Add help documentation
4. Test with `./aither.ps1 [your-command] help`

### Development Commands
```bash
# Test the CLI
./aither.ps1 help
./aither.ps1 init --auto
./aither.ps1 dev release patch "Test release"

# Run validation
./tests/Run-BulletproofValidation.ps1 -ValidationLevel Quick
```

## Migration Guide

### From Old Interface
```bash
# Old way:
./Start-AitherZero.ps1 -Setup

# New way:
./aither.ps1 init
```

```bash
# Old way:
Import-Module ./aither-core/modules/PatchManager -Force
Invoke-ReleaseWorkflow -ReleaseType "patch" -Description "Fix"

# New way:
./aither.ps1 dev release patch "Fix"
```

### Configuration
- Old config locations still work
- New CLI respects existing configurations
- No breaking changes to module behavior

## Troubleshooting

### Common Issues

**"Export-ModuleMember" error?**
✅ **Fixed!** - This was resolved in the shared utility files.

**Module dependency warnings?**
✅ **Fixed!** - Modules now load in the correct order (Logging first).

**Complex setup process?**
✅ **Fixed!** - Use `./quick-setup.ps1` for streamlined experience.

### Getting Help

1. **Built-in help**: `./aither.ps1 help`
2. **Command help**: `./aither.ps1 [command] help`
3. **Quick setup**: `./quick-setup.ps1`
4. **Original method**: `./Start-AitherZero.ps1 -Help`
5. **Issues**: https://github.com/wizzense/AitherZero/issues

## Roadmap

### Phase 1: Bridge Solution (✅ **COMPLETE**)
- Modern CLI interface
- Fix critical startup issues
- Streamlined setup experience
- Core commands working

### Phase 2: Enhanced Features (Next 2-4 weeks)
- Complete deploy command implementation
- Workflow orchestration commands
- Configuration management
- Plugin system foundation

### Phase 3: Full Rewrite (Months 2-6)
- Go-based binary implementation
- REST API server
- Plugin marketplace
- Cross-platform single binary

## Feedback

We've completely redesigned the user experience based on feedback. Try the new interface and let us know what you think!

- 🎯 **Quick feedback**: `./aither.ps1 help` and explore
- 🐛 **Issues**: https://github.com/wizzense/AitherZero/issues
- 💬 **Discussions**: https://github.com/wizzense/AitherZero/discussions

---

**Ready to get started?** Run `./quick-setup.ps1` and you'll be up and running in 2 minutes! 🚀
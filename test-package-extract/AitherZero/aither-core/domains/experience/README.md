# Experience Domain

This domain handles user experience and setup for AitherCore.

## Consolidated Modules

### SetupWizard
**Original Module**: `aither-core/modules/SetupWizard/`  
**Status**: Consolidated  
**Key Functions**:
- `Start-IntelligentSetup`
- `Generate-QuickStartGuide`
- `Edit-Configuration`
- `Review-Configuration`

### StartupExperience
**Original Module**: `aither-core/modules/StartupExperience/`  
**Status**: Consolidated  
**Key Functions**:
- `Start-InteractiveMode`
- `Get-StartupMode`
- `Show-ModuleExplorer`
- `Get-ConfigurationProfile`

## User Experience Architecture

The experience domain provides unified user interaction:

```
Experience Domain
├── SetupWizard (Setup Service)
│   ├── Intelligent Setup
│   ├── Configuration Wizard
│   ├── Installation Profiles
│   └── Quick Start Guide
└── StartupExperience (Startup Service)
    ├── Interactive Mode
    ├── Module Explorer
    ├── Configuration Profiles
    └── Startup Management
```

## Implementation Structure

```
experience/
├── SetupWizard.ps1           # Setup and configuration wizard
├── StartupExperience.ps1     # Startup and interactive experience
└── README.md                # This file
```

## Usage Examples

```powershell
# Intelligent setup
$setupResult = Start-IntelligentSetup -Profile "developer"

# Generate quick start guide
Generate-QuickStartGuide -SetupState $setupResult

# Start interactive mode
Start-InteractiveMode -ShowWelcome

# Show module explorer
Show-ModuleExplorer -Category "Infrastructure"

# Get configuration profile
$profile = Get-ConfigurationProfile -ProfileName "development"
```

## Features

### Setup Wizard
- **Intelligent Setup**: Automated environment detection and configuration
- **Installation Profiles**: Minimal, developer, and full installation options
- **Configuration Wizard**: Interactive configuration management
- **Quick Start Guide**: Generated setup documentation

### Startup Experience
- **Interactive Mode**: Menu-driven interface for common tasks
- **Module Explorer**: Visual module discovery and management
- **Configuration Profiles**: Profile-based configuration management
- **Startup Management**: Customizable startup behavior

## Installation Profiles

### Minimal Profile
- Core infrastructure components only
- Essential configuration
- Basic logging and monitoring

### Developer Profile
- Full development environment
- AI tools integration (Claude Code, Gemini CLI)
- Advanced debugging and testing tools

### Full Profile
- All available modules and features
- Complete automation capabilities
- Enterprise security features

## Interactive Features

### Module Explorer
- Visual representation of available modules
- Module capabilities and dependencies
- Quick access to module functions

### Configuration Manager
- Interactive configuration editing
- Configuration validation and testing
- Profile switching and management

### Startup Modes
- **Interactive**: Menu-driven interface
- **Automated**: Script-based execution
- **Guided**: Step-by-step wizards

## Testing

Experience domain tests are located in:
- `tests/domains/experience/`
- User experience tests in `tests/integration/`

## Dependencies

- **Write-CustomLog**: Guaranteed available from AitherCore orchestration
- **Configuration Services**: Uses unified configuration management
- **All Other Domains**: Provides user interface to all AitherCore functionality
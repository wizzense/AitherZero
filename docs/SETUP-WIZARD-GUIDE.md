# Setup Wizard Guide

## Overview

The AitherZero Setup Wizard provides an intelligent, guided first-time setup experience with comprehensive platform detection, dependency validation, and progress tracking. This module replaces traditional manual setup processes with an automated, user-friendly wizard that adapts to your specific platform and environment.

## Features

### 🧠 Intelligent Platform Detection
- Automatic OS detection (Windows, Linux, macOS)
- PowerShell version validation and recommendations
- Architecture detection (x64, ARM64, etc.)
- Platform-specific guidance and instructions

### 🔍 Comprehensive Dependency Checking
- Git installation and configuration validation
- Infrastructure tools detection (OpenTofu/Terraform)
- PowerShell module availability checks
- Network connectivity testing
- Security settings validation

### 📊 Visual Progress Tracking
- Real-time progress bars with completion percentages
- Step-by-step status indicators
- Time tracking with elapsed and estimated completion times
- Error and warning collection with actionable recommendations

### ⚙️ Automated Configuration
- Platform-specific configuration file generation
- Secure credential store initialization
- Quick start guide generation
- Setup state persistence for future reference

## Quick Start

### Basic Setup
```powershell
# Run the intelligent setup wizard
./Start-AitherZero.ps1 -Setup
```

### Installation Profiles
```powershell
# Interactive profile selection (default)
./Start-AitherZero.ps1 -Setup

# Minimal setup - Core AitherZero + Infrastructure tools only
./Start-AitherZero.ps1 -Setup -InstallationProfile minimal

# Developer setup - Minimal + AI tools + Development utilities
./Start-AitherZero.ps1 -Setup -InstallationProfile developer

# Full setup - Everything including advanced integrations
./Start-AitherZero.ps1 -Setup -InstallationProfile full

# Skip optional dependencies (legacy parameter)
./Start-AitherZero.ps1 -Setup -SkipOptional

# Use the module directly
Import-Module ./aither-core/modules/SetupWizard -Force
$result = Start-IntelligentSetup -InstallationProfile developer
```

## Installation Profiles

The setup wizard now supports different installation profiles to match user needs:

### 🏃 Minimal Profile
- Core AitherZero modules only
- OpenTofu/Terraform support
- Basic configuration management
- Fastest setup time (~2-3 minutes)
- Ideal for: Production environments, CI/CD systems

### 👨‍💻 Developer Profile  
- Everything in Minimal profile
- Claude Code integration
- AI tools installation
- Development utilities
- Setup time (~5-7 minutes)
- Ideal for: Developers using AI-powered automation

### 🚀 Full Profile
- Everything in Developer profile
- Advanced AI integrations
- All optional modules
- Cloud provider CLIs detection
- Enterprise features
- Comprehensive setup (~8-12 minutes)
- Ideal for: Power users, enterprise environments

### 🤝 Interactive Profile (Default)
- Prompts user to choose between Minimal, Developer, or Full
- Provides profile descriptions and recommendations
- Adapts to user preferences and environment

## Setup Process Flow

The setup wizard follows a structured process with 10-12 steps (depending on profile):

### 1. Platform Detection
- Detects operating system and version
- Identifies PowerShell version and capabilities
- Checks system architecture
- Validates execution policy (Windows)

### 2. PowerShell Version Check
- Validates PowerShell 7.0+ for full compatibility
- Warns about PowerShell 5.1 limitations
- Provides upgrade recommendations
- Detects multiple PowerShell installations

### 3. Git Installation Validation
- Checks for Git availability
- Validates user configuration (name/email)
- Provides platform-specific installation instructions
- Tests basic Git functionality

### 4. Infrastructure Tools Assessment
- Detects OpenTofu/Terraform installations
- Recommends OpenTofu over Terraform
- Checks for Docker availability
- Validates cloud CLI tools (Azure, AWS, GCP)

### 5. Module Dependencies Check
- Verifies core AitherZero modules
- Checks for optional PowerShell modules (Pester, PSScriptAnalyzer)
- Reports missing dependencies
- Validates module manifests

### 6. Network Connectivity Testing
- Tests connectivity to GitHub API
- Validates PowerShell Gallery access
- Checks OpenTofu Registry availability
- Detects proxy configurations

### 7. Security Settings Review
- Platform-specific security checks
- Windows Defender exclusion recommendations
- SELinux/AppArmor status (Linux)
- Gatekeeper validation (macOS)

### 8. Configuration File Creation
- Creates platform-appropriate config directory
- Generates default configuration files
- Sets up logging preferences
- Saves setup state for future reference

### 9. Quick Start Guide Generation
- Creates platform-specific usage guide
- Includes detected capabilities summary
- Provides next steps and recommendations
- Documents common commands and workflows

### 8. Node.js Detection (Developer/Full Profiles)
- Validates Node.js installation for AI tools
- Checks npm availability and version
- Provides installation recommendations if missing

### 9. AI Tools Setup (Developer/Full Profiles)
- Installs Claude Code via npm
- Sets up AI tool integrations
- Validates AI tool functionality
- Configures tool-specific settings

### 10. Cloud CLIs Detection (Full Profile Only)
- Detects Azure CLI, AWS CLI, Google Cloud SDK
- Checks for Kubernetes CLI (kubectl) and Helm
- Validates Docker availability
- Provides installation recommendations

### 11. Final Validation
- Summarizes setup results
- Reports completion statistics
- Identifies any remaining issues
- Provides success confirmation and next steps

## Configuration Options

### Setup State Object
The setup wizard returns a comprehensive state object containing:

```powershell
@{
    StartTime = [DateTime]
    Platform = @{
        OS = 'Windows|Linux|macOS'
        Version = '10.0.19045.0'
        Architecture = 'X64'
        PowerShell = '7.4.0'
    }
    Steps = @(
        @{
            Name = 'Platform Detection'
            Status = 'Passed|Failed|Warning'
            Details = @('Step-specific messages')
            Data = @{} # Step-specific data
        }
    )
    Errors = @('Error messages')
    Warnings = @('Warning messages')
    Recommendations = @('Actionable recommendations')
}
```

### Configuration Directories
The wizard creates configuration in platform-appropriate locations:

- **Windows**: `%APPDATA%\AitherZero\`
- **Linux/macOS**: `~/.config/aitherzero/`

Generated files include:
- `config.json` - Default configuration settings
- `setup-state.json` - Complete setup results
- `QuickStart-{Platform}-{Date}.md` - Platform-specific guide

## Advanced Usage

### Custom Setup Scenarios

#### CI/CD Environment Setup
```powershell
# Automated setup for build environments
$result = Start-IntelligentSetup -MinimalSetup -SkipOptional

# Validate setup completion
if ($result.Steps | Where-Object { $_.Status -eq 'Failed' }) {
    throw "Setup failed with critical errors"
}
```

#### Development Environment
```powershell
# Full setup with all optional features
$result = Start-IntelligentSetup

# Generate detailed report
Generate-QuickStartGuide -SetupState $result
```

#### Headless/Unattended Setup
```powershell
# Silent setup with automatic defaults
$result = Start-IntelligentSetup -MinimalSetup -SkipOptional -Confirm:$false
```

### Integration with Other Modules

#### Progress Tracking Integration
```powershell
Import-Module ./aither-core/modules/ProgressTracking -Force

# Track setup progress with visual indicators
$operationId = Start-ProgressOperation -OperationName "AitherZero Setup" -TotalSteps 10 -ShowTime -ShowETA

# The setup wizard automatically integrates with active progress tracking
$result = Start-IntelligentSetup
```

#### Logging Integration
```powershell
Import-Module ./aither-core/modules/Logging -Force

# Setup wizard automatically uses centralized logging
$result = Start-IntelligentSetup

# Review setup logs
Get-LogEntries -Level INFO | Where-Object { $_.Message -match "Setup" }
```

## Troubleshooting

### Common Issues

#### PowerShell Execution Policy (Windows)
**Problem**: Setup fails due to restrictive execution policy
**Solution**: 
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

#### Git Configuration Missing
**Problem**: Git is installed but not configured
**Solution**:
```bash
git config --global user.name "Your Name"
git config --global user.email "your@email.com"
```

#### Network Connectivity Issues
**Problem**: Cannot reach external services
**Solution**: Check proxy settings and firewall configuration

#### Missing Dependencies
**Problem**: Required tools not installed
**Solution**: Follow platform-specific installation recommendations in the setup report

### Recovery and Restart

#### Reset Configuration
```powershell
# Remove existing configuration to restart setup
$configDir = if ($IsWindows) { 
    Join-Path $env:APPDATA "AitherZero" 
} else { 
    Join-Path $env:HOME ".config/aitherzero" 
}

Remove-Item $configDir -Recurse -Force -ErrorAction SilentlyContinue
```

#### Partial Setup Recovery
```powershell
# Re-run specific setup steps
$result = Start-IntelligentSetup -MinimalSetup

# Check which steps need attention
$failedSteps = $result.Steps | Where-Object { $_.Status -eq 'Failed' }
$failedSteps | ForEach-Object { Write-Host "Failed: $($_.Name)" }
```

## Best Practices

### For New Users
1. Run the full setup wizard on first installation
2. Review all recommendations and warnings
3. Follow the generated quick start guide
4. Validate the setup with quickstart validation

### For Experienced Users
1. Use minimal setup to skip lengthy checks
2. Leverage SkipOptional for faster setup
3. Integrate with existing CI/CD workflows
4. Customize configuration files post-setup

### For Administrators
1. Standardize setup configurations across teams
2. Use automated setup for deployment pipelines
3. Monitor setup success rates and common issues
4. Maintain documentation for organization-specific requirements

## API Reference

### Core Functions

#### Start-IntelligentSetup
Main setup wizard function with comprehensive validation and guidance.

**Parameters:**
- `-SkipOptional` - Skip non-critical validation steps
- `-MinimalSetup` - Run minimal configuration for experienced users
- `-ConfigPath` - Custom configuration file path

**Returns:** Setup state object with complete results

#### Generate-QuickStartGuide
Creates platform-specific usage documentation.

**Parameters:**
- `-SetupState` - Setup state object from wizard

**Returns:** Result object with guide generation status

#### Get-PlatformInfo
Retrieves detailed platform information.

**Returns:** Platform details object

### Integration Points

The Setup Wizard integrates seamlessly with:
- **ProgressTracking**: Visual progress indicators
- **Logging**: Centralized log management
- **PatchManager**: Git workflow preparation
- **DevEnvironment**: Development tool setup
- **TestingFramework**: Validation and testing

## Support and Resources

- **Module Source**: `/aither-core/modules/SetupWizard/`
- **Tests**: `/tests/unit/modules/SetupWizard/`
- **Examples**: See generated quick start guides
- **Integration**: Works with all AitherZero modules

For additional support, see the main [AitherZero documentation](../README.md) or create an issue on GitHub.
# UserExperience Module

The **UserExperience** module is the unified user interface and onboarding system for AitherZero. It consolidates the functionality from the original `SetupWizard` and `StartupExperience` modules into a single, comprehensive user experience platform.

## 🌟 Overview

This module provides:
- **Intelligent First-Time Setup**: Automated platform detection, dependency installation, and configuration
- **Interactive User Interface**: Rich terminal-based UI with adaptive capabilities
- **Seamless Onboarding**: Progressive disclosure from beginner to expert workflows
- **Configuration Management**: Comprehensive user profile and preference management
- **Contextual Help System**: Built-in guidance, tutorials, and troubleshooting
- **Performance Optimization**: Smart caching, adaptive UI, and system-aware configurations

## 🎯 Key Features

### 🚀 Unified User Experience
- **Single Entry Point**: `Start-UserExperience` provides access to all functionality
- **Adaptive Interface**: Automatically detects user skill level and system capabilities
- **Progressive Enhancement**: Grows with user expertise from guided setup to expert mode
- **Seamless Transitions**: Smooth flow from first-time setup to daily usage

### 🔧 Intelligent Setup System
- **Platform Detection**: Automatic detection of Windows, Linux, and macOS environments
- **Dependency Resolution**: Smart installation and configuration of required tools
- **Installation Profiles**: Minimal, Developer, and Full installation options
- **Error Recovery**: Comprehensive error handling with automatic recovery attempts
- **Progress Tracking**: Real-time progress indicators with estimated completion times

### 🎮 Interactive Interface
- **Rich Terminal UI**: Enhanced interface with fallback to basic mode
- **Theme Support**: Auto-detect system theme or user preference (Dark/Light/HighContrast)
- **Accessibility**: Support for screen readers, high contrast, and large text
- **Responsive Design**: Adapts to terminal size and capabilities

### 👤 User Profile Management
- **Multiple Profiles**: Support for different user configurations and preferences
- **Environment Switching**: Easy switching between development, testing, and production configurations
- **Preference Sync**: Optional synchronization of preferences across systems
- **Backup/Restore**: Built-in backup and restore of user configurations

## 📋 Installation Profiles

### Minimal Profile
**Target Users**: CI/CD systems, containers, minimal installations
- Core AitherZero functionality only
- Essential dependencies
- Optimized for performance and minimal footprint
- Estimated setup time: 30 seconds

### Developer Profile  
**Target Users**: Developers, DevOps engineers, power users
- Includes Minimal profile features
- AI tools integration (Claude Code, etc.)
- Development utilities and VS Code integration
- Enhanced debugging and logging capabilities
- Estimated setup time: 1-2 minutes

### Full Profile
**Target Users**: Enterprise environments, complete installations
- Includes Developer profile features
- All optional modules and integrations
- Cloud provider CLI tools
- Enterprise security features
- Advanced monitoring and analytics
- Estimated setup time: 2-5 minutes

## 🚀 Quick Start

### First-Time Setup
```powershell
# Automatic detection and setup
Start-UserExperience

# Or with specific profile
Start-UserExperience -Mode Setup
./Start-AitherZero.ps1 -Setup -InstallationProfile developer
```

### Daily Usage
```powershell
# Interactive mode (recommended)
Start-UserExperience -Mode Interactive

# Expert mode for advanced users
Start-UserExperience -Mode Expert

# Minimal mode for quick operations
Start-UserExperience -Mode Minimal
```

### Profile Management
```powershell
# Create a new profile
New-UserProfile -Name "MyProject" -Description "Custom project configuration"

# Switch profiles
Set-UserProfile -Name "MyProject"

# Export/Import profiles
Export-UserProfile -Name "MyProject" -Path "./my-config.json"
Import-UserProfile -Path "./my-config.json"
```

## 📖 Function Reference

### Core Functions

#### `Start-UserExperience`
Main entry point for the user experience system.

```powershell
Start-UserExperience [-Mode <String>] [-Profile <String>] [-SkipWelcome] [-Force]
```

**Parameters:**
- `Mode`: Auto, Setup, Interactive, Expert, Minimal, Tutorial
- `Profile`: Name of user profile to load
- `SkipWelcome`: Skip welcome screen
- `Force`: Force mode even if detection suggests otherwise

#### `Initialize-UserExperience`
Initializes the user experience system and prepares the environment.

```powershell
Initialize-UserExperience [-Force] [-SkipCapabilityDetection]
```

### Setup Functions

#### `Start-IntelligentSetup`
Intelligent setup wizard with comprehensive system analysis.

```powershell
Start-IntelligentSetup [-InstallationProfile <String>] [-SkipOptional] [-Unattended] [-Force]
```

#### `Test-SystemReadiness`
Tests system readiness for AitherZero installation.

```powershell
Test-SystemReadiness [-Detailed] [-FixIssues]
```

### Interactive Functions

#### `Start-InteractiveMode`
Starts the interactive management interface.

```powershell
Start-InteractiveMode [-Profile <String>] [-SkipLicenseCheck]
```

#### `Show-MainDashboard`
Displays the main AitherZero dashboard.

```powershell
Show-MainDashboard [-Refresh] [-Compact]
```

### Profile Management

#### `New-UserProfile`
Creates a new user profile.

```powershell
New-UserProfile -Name <String> [-Description <String>] [-BasedOn <String>] [-SetAsDefault]
```

#### `Get-UserProfile`
Retrieves user profile information.

```powershell
Get-UserProfile [-Name <String>] [-All] [-IncludeSettings]
```

#### `Set-UserProfile`
Sets the active user profile.

```powershell
Set-UserProfile -Name <String> [-Temporary] [-Quiet]
```

### UI Functions

#### `Initialize-TerminalUI`
Initializes enhanced terminal UI capabilities.

```powershell
Initialize-TerminalUI [-Theme <String>] [-ForceClassic] [-Minimal]
```

#### `Show-WelcomeScreen`
Displays adaptive welcome screen.

```powershell
Show-WelcomeScreen [-Mode <String>] [-IsFirstTime] [-Profile <String>] [-ShowSystemInfo]
```

### Configuration Functions

#### `Set-UserPreferences`
Sets user preferences and behavior options.

```powershell
Set-UserPreferences [-Theme <String>] [-DefaultMode <String>] [-ExpertMode] [-ShowTips]
```

#### `Start-ConfigurationWizard`
Launches interactive configuration wizard.

```powershell
Start-ConfigurationWizard [-Mode <String>] [-Section <String>]
```

### Help and Guidance

#### `Show-UserGuide`
Shows contextual user guide and documentation.

```powershell
Show-UserGuide [-Topic <String>] [-Interactive] [-SearchTerm <String>]
```

#### `Start-TutorialMode`
Launches interactive tutorial system.

```powershell
Start-TutorialMode [-Lesson <String>] [-SkipIntro] [-Profile <String>]
```

#### `Get-ContextualHelp`
Provides contextual help based on current state.

```powershell
Get-ContextualHelp [-Topic <String>] [-DetailLevel <String>]
```

## 🎨 Themes and Customization

### Available Themes
- **Auto**: Automatically detects system preference
- **Dark**: Dark theme optimized for low-light environments
- **Light**: Light theme for high-contrast visibility
- **HighContrast**: Maximum contrast for accessibility

### Theme Configuration
```powershell
# Set theme preference
Set-UITheme -Theme Dark

# Auto-detect based on system
Set-UITheme -Theme Auto

# Get current theme
Get-UITheme
```

### Accessibility Features
```powershell
# Enable high contrast mode
Set-UserPreferences -Accessibility @{ HighContrast = $true }

# Enable large text
Set-UserPreferences -Accessibility @{ LargeText = $true }

# Screen reader compatibility
Set-UserPreferences -Accessibility @{ ScreenReader = $true }
```

## 🔧 Advanced Usage

### Expert Mode
Expert mode provides advanced features and direct access to all functionality:

```powershell
# Enable expert mode permanently
Enable-ExpertMode

# Temporary expert mode
Start-UserExperience -Mode Expert

# Check expert mode status
Get-UserPreferences | Select-Object ExpertMode
```

### Performance Optimization
```powershell
# Test user experience performance
Test-UserExperience -IncludeMetrics

# Optimize workflow based on usage
Optimize-UserWorkflow -AnalyzePeriod 30

# Generate usage analytics
Get-UsageAnalytics -Period LastMonth -Export
```

### Custom Profiles
```powershell
# Create advanced custom profile
$profileConfig = @{
    Name = "DevOps-Advanced"
    Description = "Advanced DevOps configuration"
    Settings = @{
        DefaultMode = "Expert"
        Theme = "Dark"
        EnabledModules = @("PatchManager", "OpenTofuProvider", "SecurityAutomation")
        CustomCommands = @{
            "deploy" = "Start-InfrastructureDeployment"
            "monitor" = "Show-SystemDashboard"
        }
    }
}

New-UserProfile @profileConfig
```

## 🚨 Troubleshooting

### Common Issues

#### Setup Fails to Start
```powershell
# Check system readiness
Test-SystemReadiness -Detailed

# Force clean setup
Start-IntelligentSetup -Force -InstallationProfile minimal

# View setup logs
Get-UserExperienceState | Select-Object -ExpandProperty LastError
```

#### UI Not Working Properly
```powershell
# Check UI capabilities
Show-UIDebugInfo

# Reset terminal UI
Reset-TerminalUI -Force

# Test UI health
Test-TerminalUIHealth
```

#### Profile Issues
```powershell
# List all profiles
Get-UserProfile -All

# Reset to default profile
Set-UserProfile -Name "Default"

# Remove corrupted profile
Remove-UserProfile -Name "Corrupted" -Force
```

### Diagnostic Commands

#### System Information
```powershell
# Get comprehensive system info
Get-UserExperienceState

# Check module health
Test-UserExperience -Detailed

# View performance metrics
Get-UsageAnalytics -IncludePerformance
```

#### Log Analysis
```powershell
# View recent logs
Get-CustomLog -Source "UserExperience" -Level ERROR -Last 10

# Export diagnostic information
Export-DiagnosticInfo -Path "./ux-diagnostics.json"
```

## 🔄 Migration from Legacy Modules

### From SetupWizard
The UserExperience module provides a superset of SetupWizard functionality:

```powershell
# Old: Start-IntelligentSetup from SetupWizard
Start-IntelligentSetup -InstallationProfile developer

# New: Integrated in UserExperience
Start-UserExperience -Mode Setup
```

### From StartupExperience  
All StartupExperience functionality is preserved:

```powershell
# Old: Start-InteractiveMode from StartupExperience
Start-InteractiveMode -Profile Development

# New: Unified interface
Start-UserExperience -Mode Interactive -Profile Development
```

### Migration Script
```powershell
# Auto-migrate existing configurations
Import-Module UserExperience
Invoke-LegacyMigration -BackupExisting
```

## 📊 Analytics and Telemetry

### Usage Analytics (Optional)
When enabled, UserExperience can collect anonymous usage analytics:

```powershell
# Enable analytics (opt-in)
Set-UserPreferences -Performance @{ EnableTelemetry = $true }

# View local analytics
Get-UsageAnalytics -Local

# Generate usage report
Generate-UsageReport -Period LastMonth -Export
```

### Performance Monitoring
```powershell
# Monitor performance in real-time
Start-PerformanceMonitoring

# Get performance baseline
Set-PerformanceBaseline

# Optimize based on usage patterns
Optimize-UserWorkflow
```

## 🤝 Integration with Other Modules

### PatchManager Integration
```powershell
# Create patches through UI
Start-UserExperience -Mode Interactive
# Navigate to: Developer Tools > Patch Manager
```

### ConfigurationCore Integration
```powershell
# Unified configuration management
Start-ConfigurationWizard -Section "Global"

# Environment switching
Switch-ConfigurationSet -Environment "production"
```

### Logging Integration
```powershell
# View logs through UI
Show-LogViewer -Source "UserExperience" -Live

# Configure logging preferences
Set-LoggingPreferences -Level DEBUG -EnableFileLogging
```

## 📝 Best Practices

### For New Users
1. Start with `Start-UserExperience` for automatic detection
2. Complete the setup wizard for optimal configuration
3. Try Tutorial Mode to learn AitherZero features
4. Use Interactive Mode for daily operations

### For Developers
1. Use Developer Profile for comprehensive tooling
2. Enable Expert Mode for advanced features
3. Create custom profiles for different projects
4. Utilize contextual help and documentation

### For Enterprise
1. Use Full Profile for complete feature set
2. Configure enterprise security settings
3. Set up centralized configuration management
4. Enable usage analytics for optimization

### Performance Tips
1. Use Minimal Mode in resource-constrained environments
2. Enable caching for faster module loading
3. Optimize profiles based on actual usage patterns
4. Regular cleanup of session history and cache

## 🔗 Related Documentation

- [AitherZero Main Documentation](../../docs/)
- [Configuration Management Guide](../ConfigurationCore/README.md)
- [Module Development Guide](../../docs/module-development.md)
- [Troubleshooting Guide](../../docs/troubleshooting.md)

## 🎖️ Module Information

- **Version**: 1.0.0
- **Author**: AitherZero Contributors
- **License**: [Project License](../../../LICENSE)
- **Dependencies**: ConfigurationCore (optional), Logging (optional), LicenseManager (optional)
- **PowerShell**: 7.0+ required
- **Platforms**: Windows, Linux, macOS

---

The UserExperience module represents the evolution of AitherZero's user interface, combining the best aspects of automated setup and interactive management into a unified, intelligent system that adapts to user needs and system capabilities.
# StartupExperience Module v2.0

## Test Status
- **Last Run**: 2025-07-08 18:34:12 UTC
- **Status**: ✅ PASSING (11/11 tests)
- **Coverage**: 0%
- **Platform**: ✅ Windows ✅ Linux ✅ macOS
- **Dependencies**: ✅ All resolved

## Test Results
| Test Suite | Status | Tests | Coverage | Duration |
|------------|--------|-------|----------|----------|
| Unit Tests | ✅ PASS | 11/11 | 0% | 1.4s |

---
*Test status updated automatically by AitherZero Testing Framework*
## Test Results
| Test Suite | Status | Tests | Coverage | Duration |
|------------|--------|-------|----------|----------|
| Unit Tests | ❌ FAIL | 43/49 | 0% | 3.6s |

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

The StartupExperience module provides an **enhanced, intelligent startup experience** for AitherZero with adaptive UI capabilities, performance-optimized module discovery, comprehensive configuration management, and robust fallback support. It serves as the primary entry point for users interacting with the AitherZero framework across different terminal environments and platforms.

## 🆕 What's New in v2.0

### Enhanced UI System
- **Adaptive UI Mode Detection**: Automatically detects terminal capabilities and switches between Enhanced and Classic modes
- **Theme Support**: Dark, Light, HighContrast, and Auto themes with platform-specific defaults  
- **Fallback Compatibility**: Graceful degradation to numbered menus when advanced terminal features unavailable
- **Cross-Platform Optimization**: Optimized for Windows PowerShell, PowerShell Core, and different terminal environments

### Performance Improvements
- **Module Discovery Caching**: Intelligent caching system reduces startup time by up to 80%
- **Performance Analytics**: Built-in performance monitoring and optimization recommendations
- **Capability-Based Loading**: Only loads features supported by the current environment

### Robust Error Handling  
- **Graceful Degradation**: Continues working even when advanced features fail
- **Comprehensive Diagnostics**: Detailed error reporting and troubleshooting guidance
- **Self-Healing**: Automatic fallback to working configurations

### Core Purpose and Functionality

- **Interactive Terminal UI**: Provides a rich, menu-driven interface for system configuration
- **Profile Management**: Manages multiple configuration profiles for different environments
- **Module Discovery**: Automatically discovers and presents available AitherZero modules
- **License Integration**: Integrates with the LicenseManager for feature access control
- **GitHub Synchronization**: Enables configuration synchronization with GitHub repositories

### Architecture and Design

The module follows a modular architecture with clear separation between:
- **Public Functions**: User-facing commands for interaction
- **Private Functions**: Internal UI components and helper functions
- **Profile Storage**: Persistent storage of configuration profiles in user directory

### Integration Points

- **LicenseManager**: Feature access control and tier management
- **Logging Module**: Centralized logging through Write-CustomLog
- **ConfigurationCore**: Integration with core configuration management
- **GitHub API**: Configuration backup and synchronization

## Directory Structure

```
StartupExperience/
├── StartupExperience.psd1         # Module manifest
├── StartupExperience.psm1         # Module script with initialization logic
├── Public/                        # Exported functions
│   ├── Export-ConfigurationProfile.ps1
│   ├── Get-ModuleDiscovery.ps1
│   ├── Get-StartupMode.ps1
│   ├── New-ConfigurationProfile.ps1
│   ├── Show-ConfigurationManager.ps1
│   ├── Show-ModuleExplorer.ps1
│   ├── Start-InteractiveMode.ps1
│   └── Sync-ConfigurationToGitHub.ps1
├── Private/                       # Internal functions
│   ├── Initialize-TerminalUI.ps1
│   ├── Show-ContextMenu.ps1
│   ├── Show-LicenseManager.ps1
│   └── Show-ProfileManager.ps1
└── README.md                      # This documentation
```

## Function Documentation

### Public Functions

#### Start-InteractiveMode
Launches the main interactive menu system for AitherZero configuration and module management.

**Parameters:**
- `Profile` (string): Configuration profile to load
- `SkipLicenseCheck` (switch): Skip license validation (for testing)

**Returns:** None (interactive session)

**Example:**
```powershell
# Start interactive mode with default settings
Start-InteractiveMode

# Start with specific profile
Start-InteractiveMode -Profile "development"

# Skip license check for testing
Start-InteractiveMode -SkipLicenseCheck
```

#### Get-ModuleDiscovery
Discovers and returns information about available AitherZero modules.

**Parameters:**
- `ModulePath` (string): Path to search for modules (defaults to project modules directory)
- `IncludePrivate` (switch): Include private/internal modules

**Returns:** Array of module information objects

**Example:**
```powershell
# Discover all public modules
$modules = Get-ModuleDiscovery

# Include private modules
$allModules = Get-ModuleDiscovery -IncludePrivate
```

#### Show-ConfigurationManager
Displays the configuration management interface for viewing and editing settings.

**Parameters:**
- `Profile` (string): Profile to manage
- `ReadOnly` (switch): Open in read-only mode

**Returns:** Selected configuration or null

**Example:**
```powershell
# Open configuration manager
Show-ConfigurationManager

# Open specific profile in read-only mode
Show-ConfigurationManager -Profile "production" -ReadOnly
```

#### New-ConfigurationProfile
Creates a new configuration profile with specified settings.

**Parameters:**
- `Name` (string): Profile name (required)
- `Description` (string): Profile description
- `BaseProfile` (string): Base profile to inherit from
- `Settings` (hashtable): Initial settings

**Returns:** Created profile object

**Example:**
```powershell
# Create basic profile
$profile = New-ConfigurationProfile -Name "dev-env" -Description "Development environment"

# Create profile with settings
$profile = New-ConfigurationProfile -Name "test" -Settings @{
    DebugMode = $true
    MaxThreads = 4
}
```

#### Export-ConfigurationProfile
Exports a configuration profile to a file or stream.

**Parameters:**
- `Profile` (string): Profile name to export (required)
- `Path` (string): Export file path
- `Format` (string): Export format (JSON, XML, YAML)
- `IncludeSecrets` (switch): Include sensitive data

**Returns:** Export file path or content

**Example:**
```powershell
# Export profile to JSON
Export-ConfigurationProfile -Profile "production" -Path "./prod-config.json"

# Export without secrets
Export-ConfigurationProfile -Profile "production" -Path "./safe-config.json" -Format JSON
```

#### Show-ModuleExplorer
Displays an interactive module explorer for browsing and loading modules.

**Parameters:**
- `StartPath` (string): Initial directory to explore
- `Filter` (string): Module name filter

**Returns:** Selected module information

**Example:**
```powershell
# Open module explorer
$selected = Show-ModuleExplorer

# Start in specific directory with filter
$module = Show-ModuleExplorer -StartPath "./modules" -Filter "*Lab*"
```

#### Get-StartupMode
Determines the appropriate startup mode based on environment and configuration.

**Parameters:**
- `Force` (string): Force specific mode (Interactive, Auto, Silent)

**Returns:** Startup mode string

**Example:**
```powershell
# Get recommended startup mode
$mode = Get-StartupMode

# Force interactive mode
$mode = Get-StartupMode -Force "Interactive"
```

#### Sync-ConfigurationToGitHub
Synchronizes configuration profiles with a GitHub repository.

**Parameters:**
- `Repository` (string): GitHub repository (owner/repo format)
- `Token` (string): GitHub personal access token
- `Branch` (string): Target branch (default: main)
- `Profile` (string[]): Specific profiles to sync

**Returns:** Sync result object

**Example:**
```powershell
# Sync all profiles
Sync-ConfigurationToGitHub -Repository "myorg/configs" -Token $token

# Sync specific profiles
Sync-ConfigurationToGitHub -Repository "myorg/configs" -Token $token -Profile @("prod", "dev")
```

### Private Functions

#### Initialize-TerminalUI
Initializes the terminal UI components and sets up the display environment.

#### Show-ContextMenu
Displays context-sensitive menus based on current selection.

#### Show-LicenseManager
Shows the license management interface for viewing and updating license status.

#### Show-ProfileManager
Displays the profile management interface for creating, editing, and deleting profiles.

## Features

### Interactive Mode
- **Menu-Driven Interface**: Navigate through options using arrow keys
- **Context-Sensitive Help**: Press F1 for help at any screen
- **Quick Actions**: Keyboard shortcuts for common operations
- **Real-time Validation**: Input validation as you type

### Profile Management
- **Multiple Profiles**: Support for unlimited configuration profiles
- **Profile Inheritance**: Base profiles for common settings
- **Import/Export**: Share profiles between systems
- **Version Control**: Track profile changes over time

### Module Discovery
- **Automatic Detection**: Finds all compatible modules
- **Dependency Resolution**: Identifies module dependencies
- **Version Compatibility**: Checks module version requirements
- **Quick Load**: One-click module loading

### License Integration
- **Feature Gating**: Controls access based on license tier
- **Graceful Degradation**: Falls back when license unavailable
- **Tier Display**: Shows current license tier in UI
- **Upgrade Prompts**: Suggests upgrades for locked features

## UI Modes and Compatibility

### Enhanced Mode
**Available when**: Terminal supports RawUI, colors, ReadKey, and no output redirection
- Arrow key navigation
- Rich visual elements (borders, colors, icons)
- Real-time feedback
- Cursor control and theming

### Classic Mode  
**Available when**: Limited terminal capabilities or explicitly requested
- Numbered menu selection
- Text-based interface
- Compatible with all terminal types
- Works with output redirection

### Auto-Detection
The module automatically detects the best UI mode based on:
- Terminal capabilities (RawUI, ReadKey support)
- Platform (Windows/Linux/macOS)
- Environment (CI/CD detection)
- Output redirection status

## Performance Features

### Module Discovery Caching
```powershell
# Cache automatically enabled by default
$modules = Get-ModuleDiscovery

# Force cache refresh  
$modules = Get-ModuleDiscovery -RefreshCache

# Disable caching for debugging
$modules = Get-ModuleDiscovery -UseCache:$false

# Clear cache manually
Clear-ModuleDiscoveryCache
```

### Performance Testing
```powershell
# Test startup performance
$results = Test-StartupPerformance

# View results  
$results | ConvertTo-Json -Depth 3
```

### Startup Mode Analytics
```powershell
# Get detailed startup mode analysis
$mode = Get-StartupMode -IncludeAnalytics

# Check detected capabilities
$mode.Analytics
$mode.UICapability
```

## Theme and Customization

### Available Themes
```powershell
# Initialize with specific theme
Initialize-TerminalUI -Theme Dark
Initialize-TerminalUI -Theme Light  
Initialize-TerminalUI -Theme HighContrast
Initialize-TerminalUI -Theme Auto    # Platform-based auto-selection

# Force classic mode
Initialize-TerminalUI -ForceClassic
```

### UI Status and Diagnostics
```powershell
# Check current UI status
Get-UIStatus

# Show detailed debug information
Show-UIDebugInfo

# Get terminal capabilities
Get-TerminalCapabilities
```

## Usage Guide

### Getting Started

```powershell
# Import the module
Import-Module ./aither-core/modules/StartupExperience

# Launch interactive mode (auto-detects best UI)
Start-InteractiveMode

# Launch with specific profile
Start-InteractiveMode -Profile "development"

# Skip license checks for testing
Start-InteractiveMode -SkipLicenseCheck

# Create your first profile
$profile = New-ConfigurationProfile -Name "my-env" -Description "My environment"
```

### Common Workflows

#### Setting Up a New Environment
```powershell
# 1. Create a new profile
$profile = New-ConfigurationProfile -Name "dev" -Description "Development setup"

# 2. Configure settings interactively
Show-ConfigurationManager -Profile "dev"

# 3. Export for backup
Export-ConfigurationProfile -Profile "dev" -Path "./backups/dev-config.json"
```

#### Discovering and Loading Modules
```powershell
# 1. Discover available modules
$modules = Get-ModuleDiscovery

# 2. Explore modules interactively
$selected = Show-ModuleExplorer

# 3. Load selected module
Import-Module $selected.Path
```

#### Synchronizing with GitHub
```powershell
# 1. Set up GitHub token
$token = Read-Host "Enter GitHub token" -AsSecureString

# 2. Sync profiles
Sync-ConfigurationToGitHub -Repository "myorg/aither-configs" -Token $token

# 3. Verify sync
Get-ConfigurationProfile -Source "GitHub"
```

### Advanced Scenarios

#### Custom Profile Templates
```powershell
# Create a base template
$template = @{
    Environment = "Template"
    Settings = @{
        LogLevel = "Info"
        MaxConcurrency = 4
        EnableTelemetry = $false
    }
}

# Create profiles from template
"dev", "test", "prod" | ForEach-Object {
    New-ConfigurationProfile -Name $_ -BaseProfile "template" -Settings $template.Settings
}
```

#### Automated Profile Selection
```powershell
# Determine profile based on environment
$profile = switch ($env:COMPUTERNAME) {
    { $_ -match "DEV" } { "development" }
    { $_ -match "TEST" } { "testing" }
    { $_ -match "PROD" } { "production" }
    default { "default" }
}

Start-InteractiveMode -Profile $profile
```

## Configuration

### Module Settings

The module stores its configuration in: `~/.aitherzero/profiles/`

Default settings structure:
```json
{
    "profiles": {
        "default": {
            "description": "Default profile",
            "settings": {
                "theme": "dark",
                "autoLoadModules": true,
                "checkUpdates": true
            }
        }
    },
    "preferences": {
        "defaultProfile": "default",
        "startupMode": "interactive",
        "enableTelemetry": false
    }
}
```

### Customization Options

#### Themes
- `dark`: Dark theme (default)
- `light`: Light theme
- `highContrast`: High contrast for accessibility
- `custom`: User-defined theme

#### Startup Modes
- `interactive`: Full UI experience
- `auto`: Automatic profile selection
- `silent`: No UI, background operation

### Performance Tuning

```powershell
# Disable module discovery cache
Set-StartupOption -DisableCache

# Limit module discovery depth
Set-StartupOption -MaxDiscoveryDepth 2

# Enable parallel module loading
Set-StartupOption -ParallelLoad
```

## Integration

### With Other Modules

#### LicenseManager Integration
```powershell
# Check feature availability
if (Test-FeatureAccess -Feature "AdvancedProfiles" -Module "StartupExperience") {
    # Use advanced features
}
```

#### Logging Integration
```powershell
# All operations are logged
Write-CustomLog -Level 'INFO' -Message "Profile created: $profileName"
```

### Event System Usage

```powershell
# Subscribe to profile events
Register-ModuleEventHandler -Event "ProfileCreated" -Handler {
    param($Profile)
    Write-Host "New profile created: $($Profile.Name)"
}

# Publish custom events
Send-ModuleEvent -Event "CustomAction" -Data @{
    Action = "ProfileExport"
    Profile = $profileName
}
```

### API Endpoints

When used with RestAPIServer module:

```
GET  /api/profiles              - List all profiles
GET  /api/profiles/{name}       - Get specific profile
POST /api/profiles              - Create new profile
PUT  /api/profiles/{name}       - Update profile
DELETE /api/profiles/{name}     - Delete profile
GET  /api/modules/discover      - Discover modules
POST /api/startup/interactive   - Start interactive session
```

## Troubleshooting

### Common Issues

1. **UI not displaying correctly**
   ```powershell
   # Check UI capabilities and status
   Show-UIDebugInfo
   
   # Force classic mode if enhanced mode fails
   Start-InteractiveMode
   Initialize-TerminalUI -ForceClassic
   
   # Test terminal capabilities
   Get-TerminalCapabilities
   ```

2. **Slow module discovery**
   ```powershell
   # Clear cache and refresh
   Clear-ModuleDiscoveryCache
   Get-ModuleDiscovery -RefreshCache
   
   # Test performance
   Test-StartupPerformance
   ```

3. **Arrow key navigation not working**
   - Terminal doesn't support ReadKey - automatically falls back to classic mode
   - Check if output is redirected: `[Console]::IsOutputRedirected`
   - Try forcing classic mode: `Show-ContextMenu -ForceClassic`

4. **Module fails to load**
   - Check PowerShell version (requires 7.0+)
   - Verify module path is correct
   - Check for missing dependencies

5. **Profile not saving**
   - Verify write permissions to profile directory: `~/.aitherzero/profiles/`
   - Check disk space
   - Ensure valid JSON format

6. **License features not working**
   - Confirm LicenseManager module is loaded
   - Verify license file exists
   - Check license tier permissions

### Debug Mode

```powershell
# Enable comprehensive debugging
$DebugPreference = "Continue"
$VerbosePreference = "Continue"

# Start with full diagnostics
Start-InteractiveMode -Verbose

# Check UI status
Show-UIDebugInfo

# Test startup performance
Test-StartupPerformance

# Get startup mode analysis
Get-StartupMode -IncludeAnalytics

# Check module state
Get-Module StartupExperience | Format-List *
```

### Environment-Specific Troubleshooting

#### Windows PowerShell 5.1
- Enhanced UI may have limited capabilities
- UTF-8 support is limited
- Some arrow key combinations may not work

#### PowerShell Core 6+
- Full feature support
- Best performance and compatibility

#### Remote Sessions (SSH, WinRM)
- Automatically detects and uses classic mode
- No enhanced UI features available
- All functionality still accessible via numbered menus

#### CI/CD Environments
- Automatically detects CI environment variables
- Forces non-interactive mode
- Can be overridden with `-Interactive` parameter for testing

## Best Practices

### UI and Performance
1. **Terminal Compatibility**
   - Test in target environments before deployment
   - Use `Test-StartupPerformance` to identify bottlenecks
   - Enable caching for production environments
   - Force classic mode for automation scripts

2. **Performance Optimization**
   ```powershell
   # Enable module discovery caching (default)
   Get-ModuleDiscovery -UseCache:$true
   
   # Clear cache after module updates
   Clear-ModuleDiscoveryCache
   
   # Test performance regularly
   Test-StartupPerformance
   ```

3. **Profile Management**
   - Use descriptive profile names
   - Document profile purposes with detailed descriptions
   - Regular backups to GitHub repositories
   - Avoid storing secrets in profiles (use SecureCredentials module)
   - Use profile inheritance for common settings

4. **Module Discovery**
   - Cache results for performance (enabled by default)
   - Use filters for specific patterns when searching
   - Verify module compatibility before execution
   - Refresh cache after installing new modules

5. **UI Customization**
   - Test themes in different terminal environments
   - Use auto-detection for cross-platform compatibility
   - Provide keyboard navigation alternatives
   - Include accessibility options (HighContrast theme)

### Development and Integration
6. **For Script Automation**
   ```powershell
   # Force non-interactive mode
   Get-StartupMode -Parameters @{NonInteractive = $true}
   
   # Use classic UI for scripts
   Initialize-TerminalUI -ForceClassic
   
   # Disable caching for dynamic testing
   Get-ModuleDiscovery -UseCache:$false
   ```

7. **For CI/CD Integration**
   - Module automatically detects CI environments
   - All functions work in non-interactive mode
   - Use `Test-StartupPerformance` in build pipelines
   - Profile operations work without UI

### Security and Compliance
8. **License Management**
   - Always test with appropriate license tiers
   - Use `Test-FeatureAccess` before calling tier-restricted functions
   - Provide graceful degradation for unlicensed features
   - Document license requirements clearly

9. **Data Handling**
   - Use `Export-ConfigurationProfile` without `-IncludeSecrets` for sharing
   - Store sensitive data in SecureCredentials module
   - Regular profile backups to version control
   - Encrypt sensitive configuration data

## Integration Examples

### Integration with Other AitherZero Modules

#### LabRunner Integration
```powershell
# Use StartupExperience to configure LabRunner
Start-InteractiveMode -Profile "lab-environment"

# In configuration manager, set lab-specific settings
Show-ConfigurationManager
# Configure: InstallHyperV, InstallDockerDesktop, etc.
```

#### DevEnvironment Integration  
```powershell
# Create development-focused profile
$devProfile = New-ConfigurationProfile -Name "development" -Description "Development workstation setup"

# Configure development tools through UI
Show-ConfigurationManager
# Enable: InstallGit, InstallVSCode, InstallClaudeCode, etc.
```

#### PatchManager Integration
```powershell
# Use profiles to manage different Git configurations
New-ConfigurationProfile -Name "enterprise-git" -Description "Enterprise Git configuration"
# Configure enterprise-specific Git settings and credentials
```

### Custom Module Integration

#### Adding Your Module to Discovery
```powershell
# Your module manifest (MyModule.psd1)
@{
    ModuleVersion = '1.0.0'
    Description = 'My custom AitherZero module'
    
    # StartupExperience will auto-discover these
    FunctionsToExport = @('My-Function1', 'My-Function2')
    
    # Optional: Add licensing metadata
    PrivateData = @{
        PSData = @{
            Licensing = @{
                Tier = 'pro'
                Feature = 'custom'
                RequiresLicense = $true
            }
        }
    }
}
```

#### Integrating with Configuration Manager
```powershell
# In your module, provide configuration schema
function Get-MyModuleConfigSchema {
    return @{
        'MyModuleSetting' = @{
            Type = 'boolean'
            Category = 'MyCategory'
            Description = 'Enable my module feature'
            Default = $false
            RequiredTier = 'free'
        }
    }
}
```

### Third-Party Tool Integration

#### VS Code Integration
```powershell
# Add VS Code tasks for StartupExperience
# .vscode/tasks.json
{
    "label": "AitherZero: Test UI Performance",
    "type": "shell", 
    "command": "pwsh",
    "args": ["-Command", "Import-Module ./aither-core/modules/StartupExperience; Test-StartupPerformance"]
}
```

#### Docker Integration
```powershell
# Use profiles for containerized environments
# Create minimal profile for containers
New-ConfigurationProfile -Name "container" -Description "Minimal configuration for containers"

# In Dockerfile
RUN pwsh -Command "Import-Module /app/aither-core/modules/StartupExperience; Start-InteractiveMode -Profile container -NonInteractive"
```

## Contributing

To contribute to the StartupExperience module:

1. Follow the AitherZero coding standards
2. Add tests for new functions using the TestingFramework module
3. Update documentation with examples
4. Test across different terminal environments
5. Verify performance impact with `Test-StartupPerformance`
6. Submit PR with clear description

### Testing Your Changes
```powershell
# Test UI in different modes
Initialize-TerminalUI -ForceClassic  # Test classic mode
Initialize-TerminalUI               # Test enhanced mode

# Test performance impact
$before = Test-StartupPerformance
# Make your changes
$after = Test-StartupPerformance

# Compare results
Compare-Object $before $after
```

## License

This module is part of the AitherZero project and follows the project's licensing terms.

---

## Quick Reference Card

### Essential Commands
```powershell
# Start interactive mode
Start-InteractiveMode

# Performance testing
Test-StartupPerformance

# UI diagnostics  
Show-UIDebugInfo

# Cache management
Clear-ModuleDiscoveryCache

# Profile operations
New-ConfigurationProfile -Name "myprofile"
Export-ConfigurationProfile -Name "myprofile"
```

### Environment Detection
```powershell
# Check startup mode
Get-StartupMode -IncludeAnalytics

# Check UI capabilities
Get-TerminalCapabilities

# Force specific behavior
Start-InteractiveMode -SkipLicenseCheck
Initialize-TerminalUI -ForceClassic -Theme HighContrast
```
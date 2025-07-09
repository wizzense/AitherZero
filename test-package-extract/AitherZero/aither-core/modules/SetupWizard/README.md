# SetupWizard Module

## Test Status
- **Last Run**: 2025-07-08 18:50:21 UTC
- **Status**: ✅ PASSING (49/49 tests)
- **Coverage**: 0%
- **Platform**: ✅ Windows ✅ Linux ✅ macOS
- **Dependencies**: ✅ All resolved

## Test Results
| Test Suite | Status | Tests | Coverage | Duration |
|------------|--------|-------|----------|----------|
| Unit Tests | ✅ PASS | 49/49 | 0% | 3.5s |

---
*Test status updated automatically by AitherZero Testing Framework*
## Test Results
| Test Suite | Status | Tests | Coverage | Duration |
|------------|--------|-------|----------|----------|
| Unit Tests | ✅ PASS | 6/6 | 0% | 1.3s |

---
*Test status updated automatically by AitherZero Testing Framework*
## Test Results
| Test Suite | Status | Tests | Coverage | Duration |
|------------|--------|-------|----------|----------|
| Unit Tests | ❌ FAIL | 43/49 | 0% | 3.4s |

---
*Test status updated automatically by AitherZero Testing Framework*
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

The SetupWizard module provides an intelligent, guided setup experience for AitherZero with advanced platform detection, enhanced installation profiles, and comprehensive progress tracking. It streamlines the initial configuration process and ensures all dependencies and prerequisites are properly installed based on the user's needs and environment.

### Primary Functionality
- **Intelligent Platform Detection**: Advanced OS, hardware, and environment analysis
- **Enhanced Installation Profiles**: Minimal, developer, full, and custom profiles with metadata
- **Unified Configuration Management**: Integration with ConfigurationCore for consistent settings
- **Advanced Error Handling**: Automatic recovery, retry logic, and detailed error reporting
- **Visual Progress Tracking**: Real-time progress with status indicators and error context
- **AI Tools Integration**: Seamless setup of Claude Code, Gemini CLI, and development tools
- **Module Integration**: Deep integration with DevEnvironment, LicenseManager, and ModuleCommunication
- **Cross-Platform Support**: Full Windows, Linux, and macOS compatibility
- **Quick Start Guide Generation**: Platform-specific guides with troubleshooting information
- **First-Time User Experience**: Comprehensive onboarding with guided setup

### Use Cases and Scenarios
- Initial AitherZero installation
- Environment setup for new team members
- CI/CD pipeline configuration
- Development environment preparation
- Configuration updates and validation
- Platform-specific optimization

### Integration with AitherZero
- **Automatic Invocation**: Called by Start-AitherZero.ps1 with -Setup flag
- **ConfigurationCore Integration**: Uses unified configuration management system
- **ProgressTracking Integration**: Enhanced visual feedback with error context
- **AIToolsIntegration**: Comprehensive setup of Claude Code, Gemini CLI, and development tools
- **DevEnvironment Integration**: VS Code workspace setup and development environment configuration
- **LicenseManager Integration**: License-aware feature setup and enterprise functionality
- **ModuleCommunication Integration**: Event-driven setup notifications and module coordination
- **Cross-Module Configuration**: Configures all core and optional modules during setup
- **Intelligent Defaults**: Creates optimized configuration files based on detected environment

## Directory Structure

```
SetupWizard/
├── SetupWizard.psd1          # Module manifest
├── SetupWizard.psm1          # Main module with setup logic
└── Public/                   # Exported functions
    ├── Edit-Configuration.ps1    # Configuration editing
    └── Review-Configuration.ps1  # Configuration review
```

## Core Functions

### Start-IntelligentSetup
Main setup wizard function with intelligent detection and profile-based installation.

**Parameters:**
- `SkipOptional` (switch): Skip optional components
- `MinimalSetup` (switch): Use minimal installation profile
- `ConfigPath` (string): Custom configuration path
- `InstallationProfile` (string): Profile selection (minimal, developer, full, interactive)

**Returns:** Setup state object with results and recommendations

**Example:**
```powershell
# Interactive setup with enhanced progress tracking
$result = Start-IntelligentSetup

# Minimal setup for CI/CD with error recovery
$result = Start-IntelligentSetup -InstallationProfile minimal -SkipOptional

# Developer setup with AI tools and VS Code integration
$result = Start-IntelligentSetup -InstallationProfile developer

# Full installation with all enterprise features
$result = Start-IntelligentSetup -InstallationProfile full

# Custom profile with specific requirements
$customProfile = @{
    Name = 'QA-Testing'
    Description = 'Quality assurance and testing environment'
    TargetUse = @('Testing', 'Quality Assurance')
    EstimatedTime = '4-6 minutes'
    Steps = @(
        @{Name = 'Testing Tools Setup'; Function = 'Install-TestingTools'; Required = $true},
        @{Name = 'Report Generation'; Function = 'Setup-ReportGeneration'; Required = $false}
    )
}
$result = Start-IntelligentSetup -CustomProfile $customProfile

# Setup with ConfigurationCore integration
$result = Start-IntelligentSetup -UseConfigurationCore
```

### Generate-QuickStartGuide
Generates a platform-specific quick start guide after setup completion.

**Parameters:**
- `SetupState` (hashtable): Setup state from Start-IntelligentSetup
- `OutputPath` (string): Path for guide output
- `Format` (string): Output format (Markdown, HTML, Text)

**Returns:** Path to generated guide

**Example:**
```powershell
# Generate guide after setup
$setupResult = Start-IntelligentSetup
$guidePath = Generate-QuickStartGuide -SetupState $setupResult

# Generate HTML guide
Generate-QuickStartGuide -SetupState $setupResult -Format HTML

# Save to specific location
Generate-QuickStartGuide -SetupState $setupResult `
    -OutputPath "C:\Docs\AitherZero-QuickStart.md"
```

### Edit-Configuration
Interactive configuration editor for modifying AitherZero settings.

**Parameters:**
- `ConfigPath` (string): Path to configuration file
- `Setting` (string): Specific setting to edit
- `Value` (object): New value for setting

**Returns:** Updated configuration object

**Example:**
```powershell
# Interactive edit mode with ConfigurationCore integration
Edit-Configuration

# Use ConfigurationCore for unified configuration management
Edit-Configuration -UseConfigurationCore

# Edit specific legacy config file
Edit-Configuration -ConfigPath "C:\Custom\config.json"

# Create new configuration if missing
Edit-Configuration -CreateIfMissing

# ConfigurationCore-specific operations
Edit-Configuration -UseConfigurationCore
# This opens the enhanced ConfigurationCore editor with:
# - Environment switching
# - Schema validation
# - Configuration backup/restore
# - Import/export capabilities
```

### Review-Configuration
Reviews and validates current configuration settings.

**Parameters:**
- `ConfigPath` (string): Path to configuration file
- `ValidateOnly` (switch): Only validate without displaying
- `ShowRecommendations` (switch): Show optimization recommendations

**Returns:** Validation results object

**Example:**
```powershell
# Review current configuration
Review-Configuration

# Validate configuration
$valid = Review-Configuration -ValidateOnly

# Get recommendations
Review-Configuration -ShowRecommendations
```

## Key Features

### Enhanced Installation Profiles

#### 1. **Minimal Profile** 🏃
- **Target Use**: CI/CD, Containers, Basic Infrastructure
- **Estimated Time**: 2-3 minutes
- **Components**:
  - Core AitherZero modules (Logging, PatchManager, LabRunner)
  - OpenTofu/Terraform support
  - Basic configuration management
  - Essential security settings
- **Requirements**: PowerShell 7.0+
- **Use Cases**: Automated deployments, containerized environments, minimal setups

#### 2. **Developer Profile** 👨‍💻
- **Target Use**: Development Workstations, AI Tools, VS Code Integration
- **Estimated Time**: 5-8 minutes
- **Components**:
  - Everything in Minimal profile
  - AI tools integration (Claude Code, Gemini CLI)
  - Node.js and development tools
  - Git configuration and VS Code workspace setup
  - Development environment modules
  - Enhanced debugging and testing tools
- **Requirements**: PowerShell 7.0+, Git (auto-installed if missing)
- **Use Cases**: Developer workstations, AI-assisted development, VS Code integration

#### 3. **Full Profile** 🚀
- **Target Use**: Production, Enterprise, Complete Infrastructure
- **Estimated Time**: 8-12 minutes
- **Components**:
  - Everything in Developer profile
  - Cloud provider CLIs (Azure, AWS, GCP)
  - Kubernetes and Docker integration
  - License management and enterprise features
  - Module communication and event system
  - Advanced monitoring and performance tools
  - Complete security and compliance features
- **Requirements**: PowerShell 7.0+, Internet connectivity
- **Use Cases**: Production environments, enterprise deployments, complete feature sets

#### 4. **Custom Profile** ⚙️
- **Target Use**: User-defined custom configurations
- **Estimated Time**: Variable
- **Components**: User-specified steps and modules
- **Flexibility**: Complete control over setup process
- **Use Cases**: Specialized environments, specific requirements, team-customized setups

### Intelligent Detection

The wizard automatically detects:
- Operating system and version
- PowerShell version
- Available package managers
- Installed prerequisites
- Network connectivity
- Available resources
- Existing configurations

### Progress Tracking

Visual progress indicators show:
- Current step and total steps
- Time elapsed and ETA
- Success/failure status
- Warnings and recommendations
- Detailed logs

## Usage Workflows

### First-Time Installation

```powershell
# 1. Run AitherZero with setup flag
./Start-AitherZero.ps1 -Setup

# 2. Setup wizard starts automatically
# 3. Choose installation profile when prompted
# 4. Wizard performs all installation steps
# 5. Review summary and recommendations
# 6. Quick start guide is generated
```

### Automated Setup for CI/CD

```powershell
# Minimal unattended setup
./Start-AitherZero.ps1 -Setup -InstallationProfile minimal -SkipOptional

# Or directly use the module
Import-Module SetupWizard -Force
$result = Start-IntelligentSetup -MinimalSetup -SkipOptional

# Check results
if ($result.Errors.Count -eq 0) {
    Write-Host "Setup completed successfully"
} else {
    Write-Error "Setup failed with $($result.Errors.Count) errors"
}
```

### Developer Workstation Setup

```powershell
# Import module
Import-Module SetupWizard -Force

# Run developer setup
$setupResult = Start-IntelligentSetup -InstallationProfile developer

# Review what was installed
$setupResult.Steps | Where-Object Status -eq "Completed" | 
    Format-Table Name, Description

# Check AI tools status
if ($setupResult.AIToolsToInstall.Count -gt 0) {
    Write-Host "AI tools installed:"
    $setupResult.AIToolsToInstall
}

# Generate quick start guide
Generate-QuickStartGuide -SetupState $setupResult
```

### Configuration Update

```powershell
# Review current configuration
Review-Configuration -ShowRecommendations

# Apply recommendations
$recommendations = (Review-Configuration -ShowRecommendations).Recommendations
foreach ($rec in $recommendations) {
    if ($rec.AutoApply) {
        Edit-Configuration -Setting $rec.Setting -Value $rec.RecommendedValue
    }
}

# Validate after changes
Review-Configuration -ValidateOnly
```

## Security

### Secure Setup Practices
- No credentials stored in configuration files
- Secure download verification for tools
- Permission checks before installations
- Audit trail of all setup actions

### Configuration Security
- Sensitive settings encrypted
- Path validations to prevent traversal
- Input sanitization for all user inputs
- Secure defaults for all options

### Best Practices
1. Run setup with appropriate permissions
2. Review all changes before applying
3. Use minimal profile for production
4. Keep setup logs for audit purposes
5. Validate configurations after changes

## Configuration

### Setup Profiles Configuration

Profiles are defined in the module with these defaults:

**Minimal Profile:**
```powershell
@{
    Modules = @('Logging', 'OpenTofuProvider', 'ParallelExecution')
    Prerequisites = @('PowerShell 7.0+')
    OptionalComponents = @()
}
```

**Developer Profile:**
```powershell
@{
    Modules = @('All')
    Prerequisites = @('PowerShell 7.0+', 'Git', 'VS Code')
    OptionalComponents = @('Claude Code', 'Gemini CLI', 'GitHub CLI')
}
```

**Full Profile:**
```powershell
@{
    Modules = @('All')
    Prerequisites = @('All')
    OptionalComponents = @('All')
    AdditionalFeatures = @('Monitoring', 'Analytics', 'Reporting')
}
```

### Platform-Specific Settings

**Windows:**
- Uses Windows Package Manager (winget) when available
- Falls back to Chocolatey or manual installation
- Configures Windows Terminal integration

**Linux:**
- Detects distribution (Ubuntu, Debian, RHEL, etc.)
- Uses appropriate package manager (apt, yum, dnf)
- Configures shell integration

**macOS:**
- Uses Homebrew for package management
- Configures Terminal.app or iTerm2
- Handles macOS-specific security settings

### Configuration Files

Setup wizard creates/modifies these files:
- `configs/app-config.json` - Main configuration
- `configs/providers/` - Provider configurations
- `.env` - Environment variables
- `settings.local.json` - User preferences

## Common Scenarios

### Quick Setup for Testing

```powershell
# Fastest setup for testing
Start-IntelligentSetup -InstallationProfile minimal -SkipOptional

# Verify core functionality
Import-Module LabRunner -Force
if (Get-Module LabRunner) {
    Write-Host "Core modules installed successfully"
}
```

### Team Onboarding

```powershell
# Create onboarding script
$onboardingScript = @'
# AitherZero Team Onboarding
Import-Module SetupWizard -Force

Write-Host "Welcome to AitherZero!" -ForegroundColor Cyan
Write-Host "This wizard will set up your development environment.`n"

# Run developer setup
$result = Start-IntelligentSetup -InstallationProfile developer

# Generate personalized guide
$guide = Generate-QuickStartGuide -SetupState $result

Write-Host "`nSetup complete! Your quick start guide: $guide"
Write-Host "Please review the guide and follow next steps."
'@

$onboardingScript | Out-File "Team-Onboarding.ps1"
```

### Offline Installation

```powershell
# Prepare offline package
$offlineConfig = @{
    SkipOnlineChecks = $true
    UseLocalPackages = $true
    PackagePath = ".\offline-packages"
}

# Run offline setup
Start-IntelligentSetup -ConfigPath "offline-config.json" `
    -InstallationProfile minimal
```

### Custom Profile Creation

```powershell
# Define custom profile
$customProfile = @{
    Name = "QA-Testing"
    Modules = @('Logging', 'TestingFramework', 'ParallelExecution')
    Prerequisites = @('PowerShell 7.0+', 'Pester 5.0+')
    OptionalComponents = @('ReportGenerator')
    CustomSteps = @(
        @{
            Name = "Configure Test Environment"
            ScriptBlock = { 
                # Custom configuration logic
                Set-TestEnvironment -Mode "Integration"
            }
        }
    )
}

# Use custom profile
Start-IntelligentSetup -CustomProfile $customProfile
```

## Best Practices

1. **Profile Selection**
   - Use minimal for containers and CI/CD
   - Use developer for workstations
   - Use full only when all features needed

2. **Setup Verification**
   - Always review setup summary
   - Check error logs if issues occur
   - Run validation after setup

3. **Configuration Management**
   - Keep configurations in version control
   - Document custom settings
   - Use environment-specific configs

4. **Update Process**
   - Run setup wizard after major updates
   - Review new recommendations
   - Test in non-production first

5. **Troubleshooting**
   - Keep setup logs for debugging
   - Use -Verbose flag for details
   - Check prerequisites manually if needed

## Enhanced Troubleshooting Guide

### Automatic Error Recovery

The SetupWizard now includes automatic error recovery for common issues:

- **Node.js Installation**: Automatically attempts installation via package managers
- **Git Installation**: Auto-installs Git using platform-specific package managers
- **Directory Permissions**: Fixes configuration directory permissions automatically
- **Module Dependencies**: Resolves missing module issues
- **Network Connectivity**: Provides fallback options for offline scenarios

### Common Issues and Solutions

#### 1. **PowerShell Version Issues**
```powershell
# Check current PowerShell version
$PSVersionTable.PSVersion

# Install PowerShell 7+ (Windows)
winget install Microsoft.PowerShell

# Install PowerShell 7+ (Linux)
curl -fsSL https://aka.ms/install-powershell.sh | sudo bash

# Install PowerShell 7+ (macOS)
brew install powershell

# Verify installation
pwsh --version
```

#### 2. **Module Import and Path Issues**
```powershell
# Check current module paths
$env:PSModulePath -split [System.IO.Path]::PathSeparator

# Add AitherZero modules to path
$aitherPath = Join-Path $PWD "aither-core\modules"
$env:PSModulePath += [System.IO.Path]::PathSeparator + $aitherPath

# Test module import
Import-Module SetupWizard -Force -Verbose
```

#### 3. **Permission and Security Issues**
```powershell
# Windows: Check execution policy
Get-ExecutionPolicy
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Linux/macOS: Fix permissions
sudo chmod +x ./Start-AitherZero.ps1
sudo pwsh -Command "& './Start-AitherZero.ps1' -Setup"

# Run setup with elevated privileges if needed
Start-Process pwsh -ArgumentList "-Command", "Import-Module ./aither-core/modules/SetupWizard; Start-IntelligentSetup" -Verb RunAs
```

#### 4. **Network and Connectivity Issues**
```powershell
# Test internet connectivity
Test-NetConnection github.com -Port 443
Test-NetConnection registry.npmjs.org -Port 443

# Configure proxy if needed
$env:HTTP_PROXY = "http://proxy.company.com:8080"
$env:HTTPS_PROXY = "https://proxy.company.com:8080"

# Run setup in offline mode
Start-IntelligentSetup -SkipOptional
```

#### 5. **ConfigurationCore Integration Issues**
```powershell
# Test ConfigurationCore availability
Import-Module ./aither-core/modules/ConfigurationCore -Force
Get-Command -Module ConfigurationCore

# Initialize ConfigurationCore manually
Initialize-ConfigurationCore

# Fall back to legacy configuration
Edit-Configuration -ConfigPath "./configs/default-config.json" -CreateIfMissing
```

#### 6. **AI Tools Installation Issues**
```powershell
# Check Node.js installation
node --version
npm --version

# Install Node.js manually if auto-install fails
# Windows: winget install OpenJS.NodeJS
# Linux: curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash - && sudo apt-get install -y nodejs
# macOS: brew install node

# Test AI tools installation
Import-Module ./aither-core/modules/AIToolsIntegration -Force
Get-AIToolsStatus
```

### Advanced Debugging

#### Enable Comprehensive Logging
```powershell
# Enable all debug output
$DebugPreference = "Continue"
$VerbosePreference = "Continue"
$InformationPreference = "Continue"

# Run setup with maximum verbosity
Start-IntelligentSetup -Verbose -Debug
```

#### Analyze Setup Results
```powershell
# Run setup and capture results
$setupResult = Start-IntelligentSetup

# Analyze failed steps
$failedSteps = $setupResult.Steps | Where-Object { $_.Status -eq 'Failed' }
$failedSteps | Select-Object Name, Details, ErrorDetails | Format-List

# Check error recovery attempts
$setupResult.Steps | Where-Object { $_.RecoveryAttempted -eq $true } | 
    Select-Object Name, RecoveryMethod, RecoverySuccess

# Review recommendations
$setupResult.Recommendations | ForEach-Object { Write-Host "💡 $_" -ForegroundColor Yellow }
```

#### System Information for Support
```powershell
# Get detailed system information
$sysInfo = Get-DetailedSystemInfo
$sysInfo | ConvertTo-Json -Depth 3

# Export setup logs for support
$setupResult | Export-Clixml -Path "setup-debug-$(Get-Date -Format 'yyyyMMdd-HHmm').xml"
```

### Platform-Specific Troubleshooting

#### Windows Issues
- **Windows Defender**: Add AitherZero directory to exclusions for better performance
- **PowerShell ISE**: Not recommended, use PowerShell 7+ console or VS Code
- **Windows Terminal**: Recommended for best experience

#### Linux Issues
- **Package Managers**: Setup automatically detects apt, yum, dnf, and others
- **Permissions**: May require sudo for system-wide installations
- **Shell Integration**: Ensure PowerShell is properly integrated with your shell

#### macOS Issues
- **Homebrew**: Install Homebrew first for best package management experience
- **Gatekeeper**: May need to approve scripts on first run
- **Terminal Compatibility**: Works with Terminal.app, iTerm2, and others

### Getting Additional Help

1. **Check Setup Logs**: Review the detailed setup output for specific error messages
2. **GitHub Issues**: Report issues at https://github.com/wizzense/AitherZero/issues
3. **Community Support**: Join discussions and get help from the community
4. **Documentation**: Refer to module-specific documentation for detailed troubleshooting

### Recovery Options

If setup fails completely:

```powershell
# Reset to clean state
Remove-Module SetupWizard -Force -ErrorAction SilentlyContinue
Import-Module ./aither-core/modules/SetupWizard -Force

# Try minimal setup first
Start-IntelligentSetup -InstallationProfile minimal -SkipOptional

# Manually configure if needed
Edit-Configuration -CreateIfMissing
```
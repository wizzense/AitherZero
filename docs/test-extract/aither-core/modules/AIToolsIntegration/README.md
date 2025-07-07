# AIToolsIntegration Module

## Module Overview

The AIToolsIntegration module provides automated installation, configuration, and management of AI development tools within the AitherZero framework. It simplifies the setup process for popular AI coding assistants and ensures they are properly integrated with your development environment.

### Primary Purpose and Functionality
- Automated installation of AI development tools (Claude Code, Gemini CLI, etc.)
- Cross-platform support with platform-specific installation methods
- Configuration management for AI tool credentials and settings
- Status monitoring and health checks for installed tools
- Update and removal capabilities for lifecycle management

### Key Features and Capabilities
- **One-Command Installation**: Simple PowerShell commands to install AI tools
- **Cross-Platform Support**: Works on Windows, Linux, and macOS
- **Prerequisite Checking**: Automatically validates Node.js and npm requirements
- **Status Monitoring**: Track which AI tools are installed and their versions
- **Unified Management**: Central location for all AI tool operations

### Integration Points with Other Modules
- **Logging Module**: Uses centralized logging for consistent output
- **SetupWizard Module**: Integrates with setup profiles (minimal, developer, full)
- **DevEnvironment Module**: Works alongside development environment setup
- **ConfigurationCarousel**: Can store AI tool configurations in configuration sets

## Directory Structure

```
AIToolsIntegration/
├── AIToolsIntegration.psd1         # Module manifest with metadata
├── AIToolsIntegration.psm1         # Main module script with all functions
└── README.md                       # This documentation file
```

### File Descriptions
- **AIToolsIntegration.psd1**: PowerShell module manifest defining exported functions, version info, and licensing details
- **AIToolsIntegration.psm1**: Core module implementation containing all AI tool management functions

## Key Functions

### Install-ClaudeCode
Installs the Claude Code CLI tool using npm.

**Parameters:**
- `-Force` [switch]: Force reinstallation even if already installed
- `-Global` [switch]: Install globally (default: true)
- `-Version` [string]: Specific version to install (default: 'latest')

**Returns:** Hashtable with Success, Message, Version, and Path

**Example:**
```powershell
# Install latest version
Install-ClaudeCode

# Force reinstall with specific version
Install-ClaudeCode -Force -Version "1.2.3"

# Install locally instead of globally
Install-ClaudeCode -Global:$false
```

### Install-GeminiCLI
Installs Google's Gemini CLI tool with platform-specific installation methods.

**Parameters:**
- `-Force` [switch]: Force reinstallation
- `-InstallMethod` [string]: Installation method ('auto', 'winget', 'brew', 'curl', 'manual')

**Returns:** Hashtable with Success, Message, Path, and RequiresConfiguration

**Example:**
```powershell
# Auto-detect best installation method
Install-GeminiCLI

# Force specific installation method
Install-GeminiCLI -InstallMethod "brew" -Force
```

### Install-CodexCLI
Attempts to install OpenAI Codex CLI (currently returns availability status).

**Parameters:**
- `-Force` [switch]: Force installation attempt

**Returns:** Hashtable with Success, Message, Note, and Alternative suggestions

**Example:**
```powershell
# Check Codex CLI availability
Install-CodexCLI
```

### Test-AIToolsInstallation
Comprehensive test of all AI tools installation status.

**Parameters:** None

**Returns:** Hashtable containing status for each tool and summary statistics

**Example:**
```powershell
# Get detailed installation status
$status = Test-AIToolsInstallation
$status.ClaudeCode.Installed  # Check if Claude Code is installed
$status.Summary.InstalledCount # Get count of installed tools
```

### Get-AIToolsStatus
Displays formatted status information for all AI tools.

**Parameters:** None

**Returns:** Formatted console output and status hashtable

**Example:**
```powershell
# Display AI tools status
Get-AIToolsStatus

# Capture status for processing
$status = Get-AIToolsStatus
if ($status.Summary.OverallStatus -eq 'None') {
    Write-Host "No AI tools installed yet"
}
```

### Configure-AITools
Interactive configuration wizard for installed AI tools (placeholder for future implementation).

**Parameters:** None

**Example:**
```powershell
# Run configuration wizard
Configure-AITools
```

### Update-AITools
Updates installed AI tools to their latest versions.

**Parameters:** None

**Example:**
```powershell
# Update all installed AI tools
Update-AITools
```

### Remove-AITools
Removes installed AI tools.

**Parameters:**
- `-Tools` [string[]]: Array of tools to remove (default: 'all')
- `-Force` [switch]: Skip confirmation prompts

**Example:**
```powershell
# Remove specific tool
Remove-AITools -Tools @('claude-code')

# Remove all AI tools
Remove-AITools -Tools @('all') -Force
```

## Configuration

### Prerequisites
- **Node.js**: Required for npm-based installations (Claude Code)
- **PowerShell 7.0+**: Module requires PowerShell 7.0 or higher
- **Platform-Specific Tools**:
  - Windows: `winget` for some installations
  - macOS: `brew` (Homebrew) for some installations
  - Linux: `curl` for downloads

### Default Settings
- Claude Code installs globally by default
- Automatic prerequisite checking before installation
- Platform-specific installation method auto-detection

### Customization Options
```powershell
# Example: Custom installation configuration
$config = @{
    ClaudeCode = @{
        Global = $true
        Version = 'latest'
    }
    GeminiCLI = @{
        InstallMethod = 'brew'
    }
}
```

## Usage Examples

### Complete AI Tools Setup
```powershell
# Import the module
Import-Module ./aither-core/modules/AIToolsIntegration -Force

# Check current status
Get-AIToolsStatus

# Install Claude Code
$claudeResult = Install-ClaudeCode
if ($claudeResult.Success) {
    Write-Host "Claude Code installed at: $($claudeResult.Path)"
}

# Install Gemini CLI
$geminiResult = Install-GeminiCLI
if ($geminiResult.RequiresConfiguration) {
    Write-Host "Please configure Gemini CLI with your API credentials"
}

# Verify all installations
$status = Test-AIToolsInstallation
Write-Host "$($status.Summary.InstalledCount) tools installed successfully"
```

### Integration with SetupWizard
```powershell
# During AitherZero setup with developer profile
./Start-AitherZero.ps1 -Setup -InstallationProfile developer

# This automatically calls AI tools installation functions
```

### Maintenance Workflow
```powershell
# Regular maintenance routine
Import-Module ./aither-core/modules/AIToolsIntegration -Force

# Check for updates
Update-AITools

# Get detailed status
$status = Get-AIToolsStatus

# Remove unused tools
if (-not $status.CodexCLI.Installed) {
    Remove-AITools -Tools @('claude-code') -Force
}
```

### Cross-Platform Installation
```powershell
# The module automatically detects platform
$platform = if ($IsWindows) { 'Windows' } 
           elseif ($IsLinux) { 'Linux' } 
           elseif ($IsMacOS) { 'macOS' }

Write-Host "Installing AI tools for $platform"
Install-ClaudeCode
Install-GeminiCLI
```

## Dependencies

### Required PowerShell Modules
- **Logging Module**: For consistent output formatting (falls back to built-in if not available)

### External Tool Requirements
- **Node.js & npm**: Required for Claude Code installation
  - Minimum version: Node.js 14.x
  - Installation: https://nodejs.org/
- **Git**: Recommended for version control integration
- **GitHub CLI (gh)**: Optional, enhances integration capabilities

### Platform-Specific Requirements
- **Windows**:
  - Windows Package Manager (winget) for some installations
  - PowerShell 7.0+
- **macOS**:
  - Homebrew for package management
  - Command Line Tools for Xcode
- **Linux**:
  - curl for downloading packages
  - Standard build tools

### Version Requirements
- PowerShell: 7.0 or higher
- Module Version: 1.0.0
- License Tier: Pro (requires 'ai' feature license)

## Troubleshooting

### Common Issues

1. **Node.js Not Found**
   ```powershell
   # Check Node.js installation
   node --version
   npm --version
   
   # Install Node.js if missing
   # Windows: winget install OpenJS.NodeJS
   # macOS: brew install node
   # Linux: See https://nodejs.org/en/download/
   ```

2. **Permission Errors**
   ```powershell
   # Run with elevated permissions or use local installation
   Install-ClaudeCode -Global:$false
   ```

3. **Module Import Failures**
   ```powershell
   # Ensure you're in the project root
   $projectRoot = Find-ProjectRoot
   Import-Module "$projectRoot/aither-core/modules/AIToolsIntegration" -Force
   ```

### Debug Mode
```powershell
# Enable verbose output
$VerbosePreference = 'Continue'
Install-ClaudeCode -Verbose
```
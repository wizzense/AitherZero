# Install-DevTools.ps1

Cross-platform PowerShell script for installing essential development tools following AitherZero project standards.

## Overview

This script automates the installation of:
- Git (version control)
- GitHub CLI (gh command)
- Node.js and npm (JavaScript runtime and package manager)
- Claude Code (Anthropic AI CLI tool)
- PowerShell 7 (cross-platform shell)

## Platform Support

- **Windows**: Installs/configures WSL2 with Ubuntu, then installs tools in WSL
- **Linux**: Direct installation using native package managers
- **macOS**: Installation using Homebrew

## AitherZero Integration

The script follows AitherZero project standards:

### Module Usage
- Imports `Logging` module for standardized logging
- Imports `DevEnvironment` module for tool installation when available
- Uses `Write-CustomLog` for all logging operations
- Follows comprehensive error handling patterns

### Function Standards
- All functions use `[CmdletBinding(SupportsShouldProcess)]` where appropriate
- Cross-platform path handling with `Join-Path`
- Proper parameter validation and error handling

### Fallback Capability
- Works with or without AitherZero modules present
- Provides fallback implementations for standalone usage

## Usage Examples

```powershell
# Windows - Install everything including WSL
.\Install-DevTools.ps1 -WSLUsername "developer"

# Windows - Use existing WSL
.\Install-DevTools.ps1 -SkipWSL

# Linux/macOS - Install all tools
.\Install-DevTools.ps1

# Preview installation without changes
.\Install-DevTools.ps1 -WhatIf

# Force reinstallation
.\Install-DevTools.ps1 -Force
```

## Parameters

- `SkipWSL` - Skip WSL installation on Windows
- `WSLUsername` - Username for WSL Ubuntu installation
- `WSLPassword` - Password for WSL user (will prompt if not provided)
- `SkipHostPowerShell` - Skip PowerShell 7 installation on Windows host
- `Force` - Force reinstallation even if tools exist
- `WhatIf` - Preview changes without executing

## Requirements

### Windows
- Administrator privileges (for WSL installation)
- Windows 10 version 2004+ or Windows 11

### Linux
- sudo privileges
- curl or wget

### macOS
- Homebrew (will be installed if missing)
- Xcode Command Line Tools

## Error Handling

The script uses comprehensive error handling following AitherZero patterns:
- Try-catch blocks with detailed logging
- Graceful fallbacks when modules aren't available
- Clear error messages with troubleshooting guidance

## Integration with AitherZero DevEnvironment

When AitherZero modules are available, the script uses:
- `Install-ClaudeCodeDependencies` for Claude Code setup
- `Install-GeminiCLIDependencies` for additional tools
- `Install-CodexCLIDependencies` for development tools

## Logging

All operations are logged using the AitherZero Logging module:
- INFO: General information messages
- WARN: Warning messages
- ERROR: Error messages
- SUCCESS: Success messages

Logs are written to the standard AitherZero logging system when available.

## Testing

Run the script in WhatIf mode to preview changes:
```powershell
.\Install-DevTools.ps1 -WhatIf
```

The script integrates with AitherZero's bulletproof testing framework for validation.

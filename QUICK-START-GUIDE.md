# AitherZero Quick Start Guide

Welcome to AitherZero! This guide will get you up and running in minutes.

## Table of Contents

- [5-Minute Quick Start](#5-minute-quick-start)
- [Common Use Cases](#common-use-cases)
- [Key Features](#key-features)
- [Command Reference](#command-reference)
- [Next Steps](#next-steps)

## 5-Minute Quick Start

### Step 1: Download AitherZero

#### Windows
```powershell
# Download latest release
$url = (irm "https://api.github.com/repos/wizzense/AitherZero/releases/latest").assets | 
    ? name -like "*windows.zip" | % browser_download_url
iwr $url -OutFile "AitherZero.zip"
Expand-Archive "AitherZero.zip" -Force
cd AitherZero-*
```

#### Linux/macOS
```bash
# Download latest release
curl -s https://api.github.com/repos/wizzense/AitherZero/releases/latest | 
    grep "browser_download_url.*$(uname -s | tr '[:upper:]' '[:lower:]').tar.gz" | 
    head -1 | cut -d '"' -f 4 | xargs curl -L | tar -xz
cd AitherZero-*
```

### Step 2: Run Setup Wizard

Verify your environment is ready:

```powershell
# Windows
.\Start-AitherZero.ps1 -Setup

# Linux/macOS
./Start-AitherZero.ps1 -Setup
```

### Step 3: Launch AitherZero

```powershell
# Interactive menu (default)
.\Start-AitherZero.ps1

# Or use the platform launcher
.\AitherZero.bat      # Windows
./aitherzero.sh       # Linux/macOS
```

That's it! You're now in the AitherZero interactive menu.

## Common Use Cases

### 1. Run Automated Infrastructure Deployment

```powershell
# Deploy test environment
.\Start-AitherZero.ps1 -Scripts "OpenTofuProvider" -Auto

# Deploy with specific config
.\Start-AitherZero.ps1 -Scripts "OpenTofuProvider" -Config "prod-config"
```

### 2. Quick Testing and Validation

```powershell
# Run quick validation (30 seconds)
.\tests\Run-BulletproofValidation.ps1 -ValidationLevel Quick

# Run standard validation before commits
.\tests\Run-BulletproofValidation.ps1 -ValidationLevel Standard
```

### 3. Backup Management

```powershell
# Run backup operations
.\Start-AitherZero.ps1 -Scripts "BackupManager"

# Automated cleanup of old backups
.\Start-AitherZero.ps1 -Scripts "BackupManager" -Auto
```

### 4. Development Environment Setup

```powershell
# Set up complete dev environment
.\Start-AitherZero.ps1 -Scripts "DevEnvironment"

# Install specific tools
.\Start-AitherZero.ps1 -Scripts "DevEnvironment" -Action "InstallTools"
```

### 5. Lab Automation

```powershell
# Deploy lab environment
.\Start-AitherZero.ps1 -Scripts "LabRunner"

# Run specific lab configuration
.\Start-AitherZero.ps1 -Scripts "LabRunner" -Config "windows-lab"
```

## Key Features

### Interactive Menu System

When you run AitherZero without parameters, you get:
- **Guided navigation** through all available modules
- **Descriptions** of what each module does
- **Parameter prompts** for required inputs
- **Preview mode** to see what will happen

### Automation Modes

- **Interactive Mode** (default): Step-by-step guidance
- **Auto Mode** (`-Auto`): Run without prompts using defaults
- **WhatIf Mode** (`-WhatIf`): Preview actions without executing
- **Verbose Mode** (`-Verbosity detailed`): Detailed logging

### Available Modules

1. **Infrastructure**
   - `OpenTofuProvider` - OpenTofu/Terraform automation
   - `LabRunner` - Lab environment orchestration
   - `RemoteConnection` - Multi-protocol connections

2. **Development**
   - `PatchManager` - Git workflow automation
   - `DevEnvironment` - Development setup
   - `TestingFramework` - Comprehensive testing

3. **Operations**
   - `BackupManager` - Backup and restore
   - `MaintenanceOperations` - System maintenance
   - `ParallelExecution` - Parallel task runner

4. **Utilities**
   - `Logging` - Centralized logging
   - `SecureCredentials` - Credential management
   - `ISOManager` - ISO file operations

## Command Reference

### Basic Commands

```powershell
# Show help
.\Start-AitherZero.ps1 -Help

# List available modules
.\Start-AitherZero.ps1 -List

# Run specific modules
.\Start-AitherZero.ps1 -Scripts "Module1,Module2"

# Run all modules in auto mode
.\Start-AitherZero.ps1 -Auto
```

### Advanced Options

```powershell
# Set verbosity level
.\Start-AitherZero.ps1 -Verbosity detailed

# Use custom config
.\Start-AitherZero.ps1 -Config "custom-config"

# Preview mode
.\Start-AitherZero.ps1 -WhatIf

# Non-interactive mode
.\Start-AitherZero.ps1 -NonInteractive
```

### Testing Commands

```powershell
# Quick module check
.\Quick-ModuleCheck.ps1

# Run all tests
.\tests\Run-AllModuleTests.ps1

# Bulletproof validation levels
.\tests\Run-BulletproofValidation.ps1 -ValidationLevel Quick    # 30 seconds
.\tests\Run-BulletproofValidation.ps1 -ValidationLevel Standard # 2-5 minutes
.\tests\Run-BulletproofValidation.ps1 -ValidationLevel Complete # 10-15 minutes
```

## Claude Code MCP Integration

Enable AI-powered automation with Claude Code:

```bash
# From mcp-server directory
cd mcp-server
npm install
claude mcp add aitherzero -- node claude-code-mcp-server.js

# Or use the setup script
./setup-claude-code-mcp.sh
```

This gives Claude Code access to all 14 AitherZero modules for intelligent automation.

## VS Code Integration

AitherZero includes 100+ pre-configured VS Code tasks:

1. Press `Ctrl+Shift+P`
2. Type "Tasks: Run Task"
3. Choose from categories:
   - **Development** - Environment setup
   - **Testing** - Various validation levels
   - **PatchManager** - Git workflows
   - **Build** - Package creation

## Troubleshooting

### PowerShell Version Error
```powershell
# Check version
$PSVersionTable.PSVersion

# Install PowerShell 7+
winget install Microsoft.PowerShell
```

### Module Not Found
```powershell
# Import modules manually
Import-Module ./aither-core/modules/ModuleName -Force

# Check module path
Get-Module -ListAvailable | Where Name -like "Aither*"
```

### Permission Issues (Linux/macOS)
```bash
# Make scripts executable
chmod +x Start-AitherZero.ps1
chmod +x aitherzero.sh
```

## Next Steps

1. **Explore Modules**: Run interactive mode to see all available modules
2. **Read Documentation**: 
   - [Installation Guide](docs/INSTALLATION.md) - Detailed setup
   - [Module Reference](docs/MODULE-REFERENCE.md) - All modules explained
   - [PatchManager Guide](docs/PATCHMANAGER-COMPLETE-GUIDE.md) - Git automation
3. **Join Community**: 
   - Report issues on [GitHub](https://github.com/wizzense/AitherZero/issues)
   - Contribute improvements via pull requests
4. **Set Up Claude Code**: Enable AI-powered automation with [MCP Integration](docs/CLAUDE-CODE-MCP-INTEGRATION.md)

---

Ready to automate your infrastructure? Start with `.\Start-AitherZero.ps1` and explore!
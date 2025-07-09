# AitherZero Quick Start Guide

This directory contains quick start guides and getting started documentation for AitherZero.

## Overview

The quick start documentation provides fast-track guides for getting up and running with AitherZero quickly and efficiently. These guides are designed for users who want to start using AitherZero immediately with minimal setup time.

## Quick Start Categories

### 5-Minute Quick Start
- **Basic Setup**: Get AitherZero running in 5 minutes
- **First Deployment**: Deploy your first infrastructure
- **Basic Operations**: Perform basic operations and commands
- **Validation**: Validate your setup and configuration

### Installation Guides
- **Windows Installation**: Windows-specific installation guide
- **Linux Installation**: Linux-specific installation guide
- **macOS Installation**: macOS-specific installation guide
- **Docker Installation**: Docker-based installation guide

### Configuration Guides
- **Basic Configuration**: Essential configuration settings
- **Advanced Configuration**: Advanced configuration options
- **Environment Configuration**: Environment-specific configuration
- **Security Configuration**: Security-focused configuration

### Usage Guides
- **Basic Usage**: Basic usage patterns and commands
- **Common Tasks**: Common operational tasks
- **Best Practices**: Quick best practices guide
- **Troubleshooting**: Quick troubleshooting guide

## Available Quick Start Guides

### Core Quick Start
- `5-minute-setup.md`: Complete setup in 5 minutes
- `first-deployment.md`: Deploy your first infrastructure
- `basic-operations.md`: Basic operations and commands
- `validation-checklist.md`: Setup validation checklist

### Installation Guides
- `windows-installation.md`: Windows installation guide
- `linux-installation.md`: Linux installation guide
- `macos-installation.md`: macOS installation guide
- `docker-installation.md`: Docker installation guide

### Configuration Guides
- `basic-configuration.md`: Basic configuration setup
- `advanced-configuration.md`: Advanced configuration options
- `environment-configuration.md`: Environment-specific setup
- `security-configuration.md`: Security configuration guide

### Usage Guides
- `basic-usage.md`: Basic usage patterns
- `common-tasks.md`: Common operational tasks
- `best-practices.md`: Quick best practices
- `troubleshooting.md`: Quick troubleshooting guide

## 5-Minute Quick Start

### Prerequisites
- PowerShell 7.0+ installed
- Git installed
- Administrator/sudo privileges
- Internet connection for downloads

### Quick Setup Steps
```powershell
# 1. Clone repository
git clone https://github.com/aitherzero/AitherZero.git
cd AitherZero

# 2. Run quick setup
./Start-AitherZero.ps1 -Setup -InstallationProfile minimal

# 3. Validate installation
./tests/Run-Tests.ps1 -Setup

# 4. Start using AitherZero
./Start-AitherZero.ps1
```

### Verification
```powershell
# Verify installation
Get-Module AitherCore -ListAvailable

# Check version
Get-AitherVersion

# Test basic functionality
Test-AitherEnvironment
```

## Installation Profiles

### Minimal Profile (Recommended for Quick Start)
```powershell
./Start-AitherZero.ps1 -Setup -InstallationProfile minimal
```
- **Duration**: 2-3 minutes
- **Includes**: Core functionality only
- **Use Case**: Basic infrastructure management

### Developer Profile
```powershell
./Start-AitherZero.ps1 -Setup -InstallationProfile developer
```
- **Duration**: 5-10 minutes
- **Includes**: Development tools and AI integration
- **Use Case**: Development and customization

### Full Profile
```powershell
./Start-AitherZero.ps1 -Setup -InstallationProfile full
```
- **Duration**: 10-15 minutes
- **Includes**: All features and tools
- **Use Case**: Complete AitherZero experience

## First Deployment

### Basic Infrastructure Deployment
```powershell
# Import AitherCore
Import-Module ./aither-core/AitherCore.psm1

# Create basic VM
New-VMDeployment -Name "test-vm" -Template "basic" -Environment "dev"

# Deploy infrastructure
Start-InfrastructureDeployment -ConfigPath "./configs/basic-deployment.json"

# Verify deployment
Get-DeploymentStatus -Name "test-vm"
```

### Common First Tasks
```powershell
# List available templates
Get-DeploymentTemplates

# Check system status
Get-SystemStatus

# View logs
Get-AitherLogs -Recent

# Get help
Get-AitherHelp
```

## Basic Operations

### Essential Commands
```powershell
# Start AitherZero
./Start-AitherZero.ps1

# Interactive mode
./Start-AitherZero.ps1 -Interactive

# Automated mode
./Start-AitherZero.ps1 -Auto

# Preview mode
./Start-AitherZero.ps1 -WhatIf
```

### Common Tasks
```powershell
# Lab management
Start-LabAutomation -LabName "test-lab"

# Backup operations
Start-BackupOperation -Source "./data" -Destination "./backup"

# System monitoring
Start-SystemMonitoring -Duration 60

# Configuration management
Set-Configuration -Key "environment" -Value "development"
```

## Quick Configuration

### Basic Configuration
```powershell
# Set default environment
Set-Configuration -Key "DefaultEnvironment" -Value "development"

# Configure logging
Set-Configuration -Key "LogLevel" -Value "INFO"

# Set default paths
Set-Configuration -Key "DefaultConfigPath" -Value "./configs"
```

### Environment Configuration
```powershell
# Development environment
Set-Environment -Name "development" -Config @{
    LogLevel = "DEBUG"
    EnableTesting = $true
    AutoBackup = $false
}

# Production environment
Set-Environment -Name "production" -Config @{
    LogLevel = "ERROR"
    EnableTesting = $false
    AutoBackup = $true
}
```

## Quick Validation

### System Validation
```powershell
# Run setup validation
./tests/Run-Tests.ps1 -Setup

# Validate environment
Test-AitherEnvironment

# Check dependencies
Test-Dependencies

# Validate configuration
Test-Configuration
```

### Health Checks
```powershell
# System health check
Get-SystemHealth

# Module health check
Get-ModuleHealth

# Service health check
Get-ServiceHealth

# Overall health status
Get-OverallHealth
```

## Common Issues and Solutions

### Installation Issues
```powershell
# PowerShell execution policy
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Module import issues
Import-Module ./aither-core/AitherCore.psm1 -Force

# Permission issues (Windows)
# Run PowerShell as Administrator

# Permission issues (Linux/macOS)
# Use sudo where necessary
```

### Configuration Issues
```powershell
# Reset configuration
Reset-Configuration

# Repair configuration
Repair-Configuration

# Validate configuration
Test-Configuration -Detailed
```

### Performance Issues
```powershell
# Check system resources
Get-SystemResources

# Optimize performance
Optimize-Performance

# Clear cache
Clear-AitherCache
```

## Next Steps

### After Quick Start
1. **Explore Features**: Explore advanced features and capabilities
2. **Customize Configuration**: Customize configuration for your needs
3. **Learn Advanced Usage**: Learn advanced usage patterns
4. **Join Community**: Join the AitherZero community

### Learning Resources
- [User Guide](../user-guide/README.md): Comprehensive user documentation
- [Development Guide](../development/README.md): Development documentation
- [Examples](../examples/README.md): Usage examples and samples
- [API Reference](../api-reference/README.md): Complete API documentation

### Community Resources
- [GitHub Repository](https://github.com/aitherzero/AitherZero): Source code and issues
- [Discussions](https://github.com/aitherzero/AitherZero/discussions): Community discussions
- [Wiki](https://github.com/aitherzero/AitherZero/wiki): Community wiki
- [Contributing](../contributing/README.md): How to contribute

## Support

### Getting Help
```powershell
# Built-in help
Get-AitherHelp

# Command help
Get-Help Start-LabAutomation -Full

# Module help
Get-Help -Module AitherCore
```

### Support Resources
- **Documentation**: Comprehensive documentation
- **Examples**: Practical examples and samples
- **Community**: Community support and discussions
- **Issues**: GitHub issues for bug reports and feature requests

### Troubleshooting
```powershell
# Debug mode
./Start-AitherZero.ps1 -Debug

# Verbose logging
./Start-AitherZero.ps1 -Verbose

# Diagnostic information
Get-DiagnosticInformation
```

## Quick Reference

### Essential Commands
- `./Start-AitherZero.ps1`: Start AitherZero
- `./Start-AitherZero.ps1 -Setup`: Setup AitherZero
- `./tests/Run-Tests.ps1`: Run tests
- `Get-AitherHelp`: Get help information

### Key Directories
- `./aither-core/`: Core functionality
- `./configs/`: Configuration files
- `./tests/`: Test files
- `./docs/`: Documentation
- `./scripts/`: Utility scripts

### Important Files
- `Start-AitherZero.ps1`: Main entry point
- `aither-core/AitherCore.psm1`: Core module
- `configs/app-config.json`: Main configuration
- `tests/Run-Tests.ps1`: Test runner
- `README.md`: Project overview

## Related Documentation

- [Installation Guide](installation.md): Detailed installation instructions
- [Configuration Guide](configuration.md): Configuration documentation
- [User Guide](../user-guide/README.md): Complete user documentation
- [Development Guide](../development/README.md): Development documentation
- [API Reference](../api-reference/README.md): API documentation
- [Examples](../examples/README.md): Usage examples
- [Troubleshooting](troubleshooting.md): Detailed troubleshooting guide
# Automation Scripts

This directory contains all automated installation and configuration scripts used by the AitherZero platform.

## Script Organization

Scripts are organized by priority number (0000-9999) and follow this naming convention:
- `NNNN_ScriptName.ps1` - where NNNN is the execution priority

### Priority Ranges

- **0000-0099**: Environment preparation and prerequisites (7 scripts)
  - PowerShell 7 installation
  - Environment cleanup
  - Directory setup
  
- **0100-0199**: Core infrastructure components (7 scripts)
  - Hyper-V installation
  - Network configuration
  - Certificate authority
  
- **0200-0299**: Development tools and utilities (17 scripts)
  - Git
  - Node.js
  - Python
  - Docker
  - VS Code
  - MCP server configuration
  
- **0300-0399**: Services and applications (1 script)
  - Infrastructure deployment

- **0400-0499**: Testing and validation (23 scripts)
  - Unit tests
  - PSScriptAnalyzer
  - Syntax validation
  - Quality checks
  
- **0500-0599**: Reporting and metrics (18 scripts)
  - Project reports
  - Dashboard generation
  - Metrics collection
  
- **0700-0799**: Git automation, AI tools, and MCP servers (36 scripts)
  - Feature branch creation
  - Conventional commits
  - Pull request automation
  - Changelog generation
  - AI-powered development tools
  - MCP server management

- **0800-0899**: Issue management and PR deployment (19 scripts)
  - Automated issue creation
  - Test failure tracking
  - PR environment deployment
  - Docker validation

- **9000-9999**: Cleanup and maintenance (1 script)

## Script Metadata

Each script includes metadata in comments at the top:
```powershell
#Requires -Version 7.0
# Stage: Core|Infrastructure|Development|Services|Configuration|Validation
# Dependencies: Git, PowerShell7, etc.
# Description: Brief description of what the script does
```

## Execution Stages

Scripts are grouped into logical stages:
- **Prepare**: Environment setup and prerequisites
- **Core**: Essential components and tools
- **Infrastructure**: Virtualization and infrastructure components
- **Development**: Development tools and environments
- **Services**: Application services
- **Configuration**: System configuration and customization
- **Validation**: Testing and validation

## Migration Status

✅ **Migration Complete!** All critical scripts have been successfully migrated from the legacy LabRunner module.

### Key Improvements:
- ✅ Centralized logging integration
- ✅ PowerShell 7 requirement enforced
- ✅ Cross-platform support (Windows, Linux, macOS) where applicable
- ✅ Configuration-driven installation approach
- ✅ Proper error handling and standardized exit codes
- ✅ Idempotent operations (safe to run multiple times)
- ✅ Consistent metadata headers for all scripts
- ✅ WhatIf/ShouldProcess support for safety

### Migration Statistics:
- **Total Scripts Migrated**: 31
- **Scripts Consolidated**: 10
- **New Features Added**: Cross-platform support, API key management, update checking
- **Coverage**: All installation, configuration, and validation scripts

## Configuration

Scripts read configuration from the config.json file passed as a parameter:
```powershell
.\0207_Install-Git.ps1 -Configuration $config
```

Configuration controls:
- Which components to install
- Installation URLs and versions
- Directory paths
- Feature flags

## Usage

Scripts are executed by the DeploymentAutomation module which handles:
- Dependency resolution
- Parallel execution
- Error handling
- Progress tracking
- Logging

## Exit Codes

- 0: Success
- 1: General failure
- 3010: Success but restart required
- 200: Special code for PowerShell 7 restart needed

## Adding New Scripts

1. Follow the naming convention: `NNNN_ScriptName.ps1`
2. Include required metadata comments
3. Use centralized logging via Write-CustomLog
4. Make operations idempotent
5. Handle cross-platform scenarios
6. Return appropriate exit codes
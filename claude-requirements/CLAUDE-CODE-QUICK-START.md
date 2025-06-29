# Claude Code Quick Start Guide for AitherZero

This guide helps you quickly get started with Claude Code integration in AitherZero.

## Prerequisites

- PowerShell 7.0+
- Git
- Internet connection

## Installation

### Option 1: Automated Installation (Recommended)

```powershell
# Run the complete Claude Code setup
Import-Module './aither-core/modules/DevEnvironment' -Force
Install-ClaudeCodeDependencies
```

This command will:
- ✅ Install Node.js and npm (via nvm)
- ✅ Install Claude Code CLI
- ✅ Install PowerShell modules (Pester, PSScriptAnalyzer)
- ✅ Configure MCP server with 14 automation tools
- ✅ Create usage documentation

### Option 2: VS Code Tasks

Use `Ctrl+Shift+P → Tasks: Run Task` and select:
- **🤖 DevEnvironment: Install Claude Code Dependencies**
- **🪟 DevEnvironment: Install Claude Code (Windows + WSL)**
- **🐧 DevEnvironment: Install Claude Code (Linux)**

## Quick Validation

### Test Your Installation

```powershell
# Test Claude Code installation
claude --version

# Test MCP server
cd mcp-server
node test-claude-code.js

# Test requirements system
Test-ClaudeRequirementsSystem
```

### VS Code Test Tasks

- **✅ Claude Code: Test Requirements System**
- **🧪 Claude Code: Test MCP Server**
- **🚀 Claude Code: Run Bulletproof Validation (Quick)**

## Common Workflows

### 1. Development Workflow with Claude Code

```bash
# Start Claude Code in your project
claude-code

# The MCP server provides these tools:
# - aither_patch_workflow: Git automation
# - aither_testing_framework: Validation system
# - aither_dev_environment: Environment setup
# - aither_lab_automation: Lab orchestration
# - Plus 10 more automation modules
```

### 2. Requirements Gathering

```bash
# In Claude Code, use these commands:
/requirements-start    # Begin requirements gathering
/requirements-status   # Check progress
/requirements-current  # View current requirement
/requirements-end      # Finish gathering
/remind               # Remind AI of rules
```

### 3. Git Workflow Automation

```bash
# In Claude Code with MCP server:
# Ask Claude to: "Create a patch for fixing the login issue"
# Claude will automatically:
# - Create a branch with PatchManager
# - Apply your changes
# - Create GitHub issue and PR
# - Run validation tests
```

## Available VS Code Tasks

### Installation & Setup
- 🤖 Claude Code: Install Requirements System
- 🔧 Claude Code: Configure MCP Server

### Testing & Validation
- ✅ Claude Code: Test Requirements System
- 🧪 Claude Code: Test MCP Server
- 🚀 Claude Code: Run Bulletproof Validation (Quick)
- 📊 Claude Code: Run Complete Validation

### Development Operations
- All existing AitherZero tasks work seamlessly with Claude Code
- Claude can automatically trigger these tasks via MCP

## MCP Server Tools

The AitherZero MCP server exposes 14 automation modules:

### Core Development
- **aither_patch_workflow**: Git workflow automation with PatchManager
- **aither_testing_framework**: Bulletproof validation system
- **aither_dev_environment**: Development environment setup

### Infrastructure & Deployment
- **aither_infrastructure_deployment**: OpenTofu/Terraform automation
- **aither_lab_automation**: Lab orchestration
- **aither_iso_management**: ISO creation and customization

### System Operations
- **aither_backup_management**: File backup and consolidation
- **aither_remote_connection**: Multi-protocol connections
- **aither_credential_management**: Secure credential handling
- **aither_logging_system**: Centralized logging
- **aither_parallel_execution**: Parallel task processing
- **aither_script_management**: Script repository management
- **aither_maintenance_operations**: System maintenance
- **aither_repo_sync**: Repository synchronization

## Troubleshooting

### Common Issues

**Claude Code not found after installation:**
```bash
# Check PATH
echo $PATH

# Reload shell profile
source ~/.bashrc  # or ~/.profile
```

**MCP server connection issues:**
```bash
# Reinstall MCP server
cd mcp-server
npm install
./setup-claude-code-mcp.sh --project
```

**PowerShell module conflicts:**
```powershell
# Force reinstall modules
Install-ClaudeCodeDependencies -Force
```

### Platform-Specific Notes

**Windows:**
- Requires WSL2 for optimal Claude Code experience
- Use Windows Terminal for best results

**Linux:**
- Uses native Node.js installation via nvm
- Ensure curl/wget available for downloads

## Next Steps

1. **Explore MCP Tools**: Try asking Claude to "Show me available AitherZero tools"
2. **Run Validation**: Use Quick validation to test your setup
3. **Create Your First Patch**: Ask Claude to help with a simple change
4. **Setup IDE Integration**: Configure your preferred editor

## Getting Help

- **VS Code**: Use task `🔍 DevEnvironment: Preview Claude Code Installation (WhatIf)` to see what would be installed
- **Documentation**: Check `mcp-server/CLAUDE-CODE-USAGE.md` for detailed MCP usage
- **Testing**: Run `Test-ClaudeRequirementsSystem` to verify installation

## Advanced Configuration

### Custom MCP Server Setup

```bash
# Manual MCP server configuration
cd mcp-server
./setup-claude-code-mcp.sh --user     # User-wide installation
./setup-claude-code-mcp.sh --project  # Project-specific installation
```

### Custom Node.js Version

```powershell
# Install specific Node.js version
Install-ClaudeCodeDependencies -NodeVersion "18.17.0"
```

### Development Mode

```bash
# Run MCP server in development mode
cd mcp-server
npm run dev
```

Enjoy using Claude Code with AitherZero! 🚀
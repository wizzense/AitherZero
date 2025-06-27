# Claude Code MCP Integration Guide

## Overview

This guide explains how to integrate AitherZero's Model Context Protocol (MCP) server with Claude Code, enabling AI-powered infrastructure automation directly from your development environment.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Quick Setup](#quick-setup)
- [Detailed Configuration](#detailed-configuration)
- [Available Tools](#available-tools)
- [Usage Examples](#usage-examples)
- [Troubleshooting](#troubleshooting)
- [Architecture](#architecture)

## Prerequisites

- **Claude Code**: Install from [claude.ai/code](https://claude.ai/code)
- **Node.js**: Version 18.0.0 or higher
- **PowerShell 7**: Automatically installed by MCP server if not present
- **AitherZero**: Clone the repository and navigate to `mcp-server` directory

## Quick Setup

### One-Line Setup

From the `mcp-server` directory:

```bash
claude mcp add aitherzero -- node claude-code-mcp-server.js
```

### Using the Setup Script

```bash
# Make script executable (first time only)
chmod +x setup-claude-code-mcp.sh

# Add to local scope (default)
./setup-claude-code-mcp.sh

# Add to project scope (shared via .mcp.json)
./setup-claude-code-mcp.sh --project

# Add to user scope (available across projects)
./setup-claude-code-mcp.sh --user
```

### Verify Installation

```bash
# List configured servers
claude mcp list

# Test the MCP server
node test-mcp-working.js
```

## Detailed Configuration

### Configuration Scopes

1. **Local Scope** (default)
   - Personal configuration for current project
   - Not shared with team members
   - Stored in local Claude Code settings

2. **Project Scope**
   - Shared configuration via `.mcp.json`
   - Committed to repository
   - Team members get same configuration

3. **User Scope**
   - Personal configuration across all projects
   - Useful for frequently used servers
   - Stored in user Claude Code settings

### Manual Configuration

Add server with custom parameters:

```bash
# With environment variables
claude mcp add aitherzero -e LOG_LEVEL=DEBUG -- node claude-code-mcp-server.js

# With custom working directory
claude mcp add aitherzero -w /path/to/workdir -- node claude-code-mcp-server.js
```

### JSON Configuration

Create `.mcp.json` in project root:

```json
{
  "mcpServers": {
    "aitherzero": {
      "command": "node",
      "args": ["claude-code-mcp-server.js"],
      "cwd": "./mcp-server",
      "env": {
        "LOG_LEVEL": "INFO"
      }
    }
  }
}
```

## Available Tools

The MCP server exposes 14 AitherZero automation tools:

### Core Infrastructure Tools

| Tool | Description | Common Operations |
|------|-------------|-------------------|
| `aither_infrastructure_deployment` | OpenTofu/Terraform automation | `plan`, `apply`, `destroy`, `validate` |
| `aither_testing_framework` | Bulletproof validation system | `bulletproof`, `module-test`, `integration-test` |
| `aither_patch_workflow` | Git workflow automation | `create-patch`, `create-pr`, `rollback` |

### Development Tools

| Tool | Description | Common Operations |
|------|-------------|-------------------|
| `aither_dev_environment` | Development setup | `setup`, `install-dependencies`, `configure` |
| `aither_lab_automation` | Lab orchestration | `create`, `start`, `stop`, `destroy` |
| `aither_script_management` | Script repository | `list`, `run`, `create` |

### System Management Tools

| Tool | Description | Common Operations |
|------|-------------|-------------------|
| `aither_backup_management` | Backup operations | `create`, `restore`, `list`, `cleanup` |
| `aither_iso_management` | ISO handling | `create`, `customize`, `mount`, `extract` |
| `aither_remote_connection` | Multi-protocol connections | `connect`, `execute`, `transfer` |
| `aither_credential_management` | Secure credentials | `store`, `retrieve`, `rotate` |

### Utility Tools

| Tool | Description | Common Operations |
|------|-------------|-------------------|
| `aither_logging_system` | Centralized logging | `log`, `query`, `export` |
| `aither_parallel_execution` | Parallel task execution | `run`, `batch`, `monitor` |
| `aither_maintenance_operations` | System maintenance | `cleanup`, `optimize`, `health-check` |
| `aither_repo_sync` | Repository synchronization | `sync`, `fork-update`, `branch-sync` |

## Usage Examples

### Basic Tool Usage

```javascript
// From Claude Code context
await mcp.call('aither_testing_framework', {
  operation: 'bulletproof',
  level: 'Quick'
});

// Run infrastructure deployment
await mcp.call('aither_infrastructure_deployment', {
  operation: 'plan',
  environment: 'dev'
});
```

### Advanced Workflows

```javascript
// Create a patch with PR
await mcp.call('aither_patch_workflow', {
  operation: 'create-patch',
  description: 'Fix authentication bug',
  createPR: true
});

// Backup before major changes
await mcp.call('aither_backup_management', {
  operation: 'create',
  name: 'pre-deployment-backup'
});
```

### Parallel Operations

```javascript
// Run multiple tools in parallel
const results = await Promise.all([
  mcp.call('aither_testing_framework', { operation: 'module-test' }),
  mcp.call('aither_logging_system', { operation: 'export', format: 'json' }),
  mcp.call('aither_maintenance_operations', { operation: 'health-check' })
]);
```

## Troubleshooting

### Common Issues

1. **"claude: command not found"**
   - Ensure Claude Code is installed and in PATH
   - Restart terminal after installation

2. **"PowerShell not found"**
   - MCP server auto-installs PowerShell 7
   - Check logs in `mcp-server/logs/`

3. **"Module not found" errors**
   - Run `npm install` in mcp-server directory
   - Verify Node.js version: `node --version`

4. **Connection timeout**
   - Check if server is running: `ps aux | grep claude-code-mcp`
   - Verify no port conflicts

### Debug Mode

Enable detailed logging:

```bash
# Add with debug logging
claude mcp add aitherzero -e DEBUG=true -- node claude-code-mcp-server.js

# View logs
tail -f mcp-server/logs/mcp-server.log
```

### Reset Configuration

```bash
# Remove server
claude mcp remove aitherzero

# Clear all MCP configurations
claude mcp clear

# Reinstall
./setup-claude-code-mcp.sh
```

## Architecture

### Component Overview

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│  Claude Code    │────▶│   MCP Server     │────▶│  AitherZero     │
│  (AI Agent)     │◀────│ (Node.js Bridge) │◀────│  (PowerShell)   │
└─────────────────┘     └──────────────────┘     └─────────────────┘
         │                       │                         │
         │                       │                         │
         ▼                       ▼                         ▼
   User Requests          Tool Routing              Automation
                         PowerShell Exec           Infrastructure
                          Validation                  Testing
                                                     Deployment
```

### Key Components

1. **claude-code-mcp-server.js**
   - Main MCP server implementation
   - Handles tool registration and routing
   - Manages PowerShell 7 installation

2. **PowerShell Executor**
   - Cross-platform PowerShell 7 execution
   - Module loading and dependency management
   - Error handling and output formatting

3. **Tool Definitions**
   - Standardized tool interfaces
   - Input validation schemas
   - Operation mapping to PowerShell modules

### Security Considerations

- All operations run with user permissions
- No credentials stored in MCP server
- Secure credential management via dedicated module
- Audit logging for all operations

## Best Practices

1. **Use Project Scope** for team collaboration
2. **Enable Logging** for production environments
3. **Test Tools** individually before complex workflows
4. **Version Control** your `.mcp.json` configuration
5. **Regular Updates** via `npm update` in mcp-server

## Next Steps

- Explore individual tool documentation in `/docs/tools/`
- Review example workflows in `/examples/`
- Join the community discussions
- Contribute improvements via pull requests

---

For more information, visit the [AitherZero documentation](../README.md) or check the [MCP server README](../mcp-server/README.md).
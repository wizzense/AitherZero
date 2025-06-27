# AitherZero MCP Server

Model Context Protocol (MCP) server that exposes AitherZero's infrastructure automation framework to AI agents, with first-class support for Claude Code.

## Overview

The AitherZero MCP Server provides AI agents with access to 14 specialized PowerShell modules for comprehensive infrastructure automation:

- 🔧 **Git Workflow Automation** - PatchManager with automated PR/issue creation
- 🏗️ **Infrastructure Deployment** - OpenTofu/Terraform with security validation
- 🧪 **Testing Framework** - Bulletproof validation at multiple levels
- 📦 **ISO Management** - System deployment and customization
- 🌐 **Remote Connections** - Multi-protocol support (SSH, WinRM, RDP)
- 🔐 **Credential Management** - Enterprise-grade security
- ⚡ **Parallel Execution** - High-performance task automation
- 🔄 **Repository Sync** - Cross-fork synchronization
- 🧹 **Maintenance Operations** - Automated system maintenance

## Quick Start

### Prerequisites

- **Node.js**: Version 18.0.0 or higher
- **PowerShell 7**: Automatically installed if not present
- **Claude Code**: For AI-powered automation (optional)

### Installation

```bash
# Clone repository
git clone https://github.com/wizzense/AitherZero.git
cd AitherZero/mcp-server

# Install dependencies
npm install
```

### Claude Code Integration

#### Option 1: Quick Setup
```bash
# Add MCP server to Claude Code
claude mcp add aitherzero -- node claude-code-mcp-server.js

# Verify setup
node test-mcp-working.js
```

#### Option 2: Setup Script
```bash
# Make script executable
chmod +x setup-claude-code-mcp.sh

# Run setup
./setup-claude-code-mcp.sh
```

### Manual MCP Server Start

```bash
# Standard server
npm start

# Claude Code optimized server
node claude-code-mcp-server.js

# Development mode with debugging
npm run dev
```

## Available Tools

### Infrastructure Management

| Tool | Description | Common Operations |
|------|-------------|-------------------|
| `aither_infrastructure_deployment` | OpenTofu/Terraform automation | `plan`, `apply`, `destroy`, `validate` |
| `aither_lab_automation` | Lab environment orchestration | `create`, `start`, `stop`, `destroy` |
| `aither_remote_connection` | Multi-protocol connections | `connect`, `execute`, `transfer` |

### Development Workflow

| Tool | Description | Common Operations |
|------|-------------|-------------------|
| `aither_patch_workflow` | Git workflow automation | `create-patch`, `create-pr`, `rollback` |
| `aither_dev_environment` | Development setup | `setup`, `install-dependencies`, `configure` |
| `aither_testing_framework` | Comprehensive testing | `bulletproof`, `module-test`, `integration-test` |
| `aither_script_management` | Script repository | `list`, `run`, `create` |

### System Operations

| Tool | Description | Common Operations |
|------|-------------|-------------------|
| `aither_backup_management` | Backup operations | `create`, `restore`, `list`, `cleanup` |
| `aither_maintenance_operations` | System maintenance | `cleanup`, `optimize`, `health-check` |
| `aither_logging_system` | Centralized logging | `log`, `query`, `export` |
| `aither_parallel_execution` | Parallel task execution | `run`, `batch`, `monitor` |

### Content Management

| Tool | Description | Common Operations |
|------|-------------|-------------------|
| `aither_iso_management` | ISO file operations | `create`, `customize`, `mount`, `extract` |
| `aither_credential_management` | Secure credentials | `store`, `retrieve`, `rotate` |
| `aither_repo_sync` | Repository synchronization | `sync`, `fork-update`, `branch-sync` |

## Usage Examples

### Claude Code Usage

When using Claude Code, you can naturally describe what you want:

```
"Run quick validation tests for the project"
"Create a patch for fixing the authentication bug"
"Deploy the test environment using OpenTofu"
"Backup all configuration files"
```

### Direct Tool Invocation

```javascript
// Create a patch with PR
await mcp.call('aither_patch_workflow', {
  operation: 'create-patch',
  description: 'Fix authentication bug',
  createPR: true
});

// Run bulletproof validation
await mcp.call('aither_testing_framework', {
  operation: 'bulletproof',
  level: 'Quick'
});

// Deploy infrastructure
await mcp.call('aither_infrastructure_deployment', {
  operation: 'plan',
  environment: 'dev'
});
```

### Advanced Workflows

```javascript
// Multi-step automation
const workflow = [
  { tool: 'aither_dev_environment', args: { operation: 'setup' } },
  { tool: 'aither_testing_framework', args: { operation: 'bulletproof', level: 'Quick' } },
  { tool: 'aither_patch_workflow', args: { operation: 'create-patch', description: 'Post-test fixes' } },
  { tool: 'aither_infrastructure_deployment', args: { operation: 'deploy' } }
];

// Execute workflow
for (const step of workflow) {
  await mcp.call(step.tool, step.args);
}
```

## Configuration

### Claude Code Configuration

The MCP server can be configured at different scopes:

```bash
# Local scope (default) - personal to current project
claude mcp add aitherzero -- node claude-code-mcp-server.js

# Project scope - shared via .mcp.json
claude mcp add aitherzero --project -- node claude-code-mcp-server.js

# User scope - available across all projects
claude mcp add aitherzero --user -- node claude-code-mcp-server.js
```

### Environment Variables

```bash
# Set log level
export LOG_LEVEL=DEBUG

# Set project root (auto-detected by default)
export PROJECT_ROOT=/path/to/AitherZero

# Set PowerShell path (auto-detected by default)
export POWERSHELL_PATH=/usr/local/bin/pwsh
```

### Custom Configuration

Create `mcp-config.json`:

```json
{
  "server": {
    "port": 3000,
    "host": "localhost"
  },
  "powershell": {
    "executable": "pwsh",
    "timeout": 300000
  },
  "logging": {
    "level": "info",
    "file": "./logs/mcp-server.log"
  }
}
```

## Architecture

### Core Components

```
claude-code-mcp-server.js    # Claude Code optimized server
├── MCPTools Class           # Tool registry and execution
├── PowerShell Installer     # Auto-installs PowerShell 7
├── Tool Definitions         # 14 tool implementations
└── Error Handling          # Comprehensive error management

index.js                     # Standard MCP server
├── Tool Registry           # Tool management
├── PowerShell Executor     # Cross-platform execution
├── Validation Schemas      # Input validation
└── Logger                  # Structured logging
```

### PowerShell Integration

1. **Auto-Installation**: Detects and installs PowerShell 7 if missing
2. **Module Loading**: Dynamic loading of AitherZero modules
3. **Error Handling**: Graceful error recovery and reporting
4. **Output Formatting**: JSON serialization for AI consumption

### Security Features

- ✅ Input validation with Joi schemas
- ✅ PowerShell execution sandboxing
- ✅ Timeout protection
- ✅ Credential isolation
- ✅ Audit logging
- ✅ Cross-platform security

## Testing

### Quick Test
```bash
# Test MCP server functionality
node test-mcp-working.js

# Test Claude Code integration
node test-claude-code.js
```

### Comprehensive Testing
```bash
# Run all tests
npm test

# Test specific components
npm run test:tools
npm run test:integration

# Test with coverage
npm run test:coverage
```

## Development

### Project Structure
```
mcp-server/
├── claude-code-mcp-server.js  # Claude Code server
├── claude-code-adapter.js     # Claude Code adapter
├── index.js                   # Standard MCP server
├── package.json              # Dependencies
├── src/                      # Source files
│   ├── tool-definitions.js   # Tool implementations
│   ├── powershell-executor.js # PS execution
│   ├── validation-schema.js  # Input validation
│   └── logger.js            # Logging
├── test/                    # Test files
└── docs/                    # Documentation
```

### Adding New Tools

1. **Define tool** in `src/tool-definitions.js`
2. **Add validation** in `src/validation-schema.js`
3. **Implement execution** in PowerShell module
4. **Add tests** in `test/`
5. **Update documentation**

### Contributing

1. Fork the repository
2. Create feature branch
3. Add tests for new features
4. Ensure cross-platform compatibility
5. Submit pull request

## Troubleshooting

### Common Issues

**PowerShell Not Found**
```bash
# MCP server auto-installs PowerShell 7
# Check installation:
pwsh --version
```

**Module Import Errors**
```bash
# Verify project structure
ls ../aither-core/modules/

# Test module import
pwsh -c "Import-Module ../aither-core/modules/PatchManager"
```

**Connection Issues**
```bash
# Check MCP server status
claude mcp list

# Restart server
claude mcp remove aitherzero
claude mcp add aitherzero -- node claude-code-mcp-server.js
```

### Debug Mode

```bash
# Enable debug logging
export DEBUG=true
export LOG_LEVEL=debug

# Run with verbose output
node claude-code-mcp-server.js --verbose
```

## Advanced Features

### Cross-Fork Operations
Support for AitherZero → AitherLabs → Aitherium fork chain

### Parallel Execution
Leverage PowerShell runspaces for concurrent operations

### Enterprise Integration
- Active Directory support
- Proxy configuration
- Custom certificate stores
- Compliance reporting

## Resources

- [Claude Code Documentation](https://docs.anthropic.com/claude-code)
- [MCP Specification](https://github.com/anthropics/mcp)
- [AitherZero Documentation](../README.md)
- [PowerShell 7 Documentation](https://docs.microsoft.com/powershell)

## License

MIT License - See [LICENSE](../LICENSE) for details.

---

**Ready to automate your infrastructure with AI!** 🚀
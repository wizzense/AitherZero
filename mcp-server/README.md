# AitherZero Model Context Protocol (MCP) Server

Transform your robust AitherZero infrastructure automation framework into a comprehensive toolkit for AI agents using the Model Context Protocol (MCP).

## Overview

The AitherZero MCP Server exposes 14 specialized infrastructure automation tools that AI agents can use to:

- 🔧 **Manage Git workflows** with automated patch creation and PR management
- 🏗️ **Deploy infrastructure** using OpenTofu/Terraform with security validation
- 🧪 **Execute comprehensive testing** with bulletproof validation framework
- 📦 **Manage ISO files** for system deployment and customization
- 🌐 **Handle remote connections** across multiple protocols (SSH, WinRM, etc.)
- 🔐 **Secure credential management** for enterprise environments
- ⚡ **Run parallel operations** for performance optimization
- 🔄 **Synchronize repositories** across fork chains
- 🧹 **Perform maintenance** operations across all modules

## Quick Start

### 1. Install Dependencies

```bash
cd mcp-server
npm install
```

### 2. Start the MCP Server

```bash
npm start
```

### 3. Configure in VS Code

Add to your VS Code settings:

```json
{
  "mcp.servers": {
    "aitherzero": {
      "command": "node",
      "args": ["path/to/AitherZero/mcp-server/index.js"],
      "workingDirectory": "path/to/AitherZero"
    }
  }
}
```

## Tool Categories

### 🏗️ Infrastructure Management
- **`aither_infrastructure_deployment`**: Deploy infrastructure using OpenTofu with security validation
- **`aither_lab_automation`**: Orchestrate lab automation workflows
- **`aither_remote_connection`**: Manage multi-protocol remote connections

### 💻 Development Workflow
- **`aither_patch_workflow`**: Execute Git-controlled patch workflows with automated PR/issue creation
- **`aither_dev_environment`**: Setup and validate development environments
- **`aither_testing_framework`**: Run comprehensive testing including bulletproof validation
- **`aither_script_management`**: Manage script repositories and templates

### ⚙️ System Operations
- **`aither_backup_management`**: Handle backups, cleanup, and file consolidation
- **`aither_maintenance_operations`**: Execute unified maintenance across all modules
- **`aither_logging_system`**: Manage centralized logging
- **`aither_parallel_execution`**: Execute tasks in parallel using PowerShell runspaces

### 📦 Content Management
- **`aither_iso_management`**: Download, customize, and manage ISO files
- **`aither_credential_management`**: Securely manage credentials
- **`aither_repo_sync`**: Synchronize repositories across fork chains

## Usage Examples

### Execute a Patch Workflow

```javascript
// AI agent calls this tool
{
  "tool": "aither_patch_workflow",
  "arguments": {
    "description": "Fix module import issues in DevEnvironment",
    "operation": "Resolve-ModuleImportIssues -Force",
    "createPR": true,
    "testCommands": ["pwsh -File tests/unit/modules/DevEnvironment/DevEnvironment.Tests.ps1"]
  }
}
```

### Deploy Lab Infrastructure

```javascript
{
  "tool": "aither_infrastructure_deployment",
  "arguments": {
    "operation": "deploy",
    "configPath": "configs/lab-environment.json"
  }
}
```

### Run Bulletproof Testing

```javascript
{
  "tool": "aither_testing_framework",
  "arguments": {
    "operation": "bulletproof",
    "level": "Standard"
  }
}
```

### Manage Remote Connections

```javascript
{
  "tool": "aither_remote_connection",
  "arguments": {
    "operation": "new",
    "name": "lab-server-01",
    "hostname": "192.168.1.100",
    "endpointType": "SSH",
    "credentialName": "lab-admin"
  }
}
```

## VS Code Toolsets

The MCP server includes pre-configured toolsets for VS Code:

```json
{
  "aither-infrastructure": {
    "tools": ["aither_infrastructure_deployment", "aither_lab_automation", "aither_remote_connection"],
    "description": "Infrastructure deployment and management tools",
    "icon": "server"
  },
  "aither-development": {
    "tools": ["aither_patch_workflow", "aither_dev_environment", "aither_testing_framework", "aither_script_management"],
    "description": "Development workflow and testing tools",
    "icon": "code"
  },
  "aither-complete": {
    "tools": ["all 14 tools"],
    "description": "Complete AitherZero automation framework",
    "icon": "rocket"
  }
}
```

## Architecture

### Components

- **`index.js`**: Main MCP server implementation
- **`src/tool-definitions.js`**: Comprehensive tool definitions with input schemas
- **`src/powershell-executor.js`**: PowerShell execution handler with cross-platform support
- **`src/validation-schema.js`**: Joi-based argument validation for all tools
- **`src/logger.js`**: Structured logging system

### PowerShell Integration

The MCP server executes PowerShell scripts that:

1. **Import shared utilities** using `Find-ProjectRoot.ps1`
2. **Load AitherZero modules** dynamically based on tool requirements
3. **Execute operations** with comprehensive error handling
4. **Return structured JSON** results for AI agent consumption

### Security Features

- ✅ **Input validation** using Joi schemas
- ✅ **PowerShell execution sandboxing** with timeouts
- ✅ **Credential isolation** through SecureCredentials module
- ✅ **Cross-platform compatibility** (Windows, Linux, macOS)
- ✅ **Comprehensive logging** for audit trails

## Testing

Run the comprehensive test suite:

```bash
# Test all tools and validations
npm test

# Test individual components
npm run test:tools
npm run test:integration

# Test PowerShell integration
node test/test-tools.js
```

## Development

### Adding New Tools

1. **Define the tool** in `src/tool-definitions.js`:

```javascript
this.tools.set('new_tool_name', {
  name: 'new_tool_name',
  description: 'Tool description',
  inputSchema: {
    // Joi schema definition
  }
});
```

2. **Add validation** in `src/validation-schema.js`:

```javascript
this.schemas.set('new_tool_name', Joi.object({
  // Validation rules
}));
```

3. **Implement PowerShell generation** in `index.js`:

```javascript
case 'new_tool_name':
  return baseScript + this.generateNewToolScript(args);
```

### Extending Capabilities

The MCP server can be extended to support:

- **Additional infrastructure providers** (AWS, Azure, GCP)
- **More testing frameworks** (Jest, Pytest, etc.)
- **Advanced automation workflows**
- **Custom PowerShell modules**
- **Integration with external tools**

## Integration Patterns

### With GitHub Copilot

```javascript
// Natural language to tool execution
"Create a patch to fix the backup cleanup issue and run tests"
→ aither_patch_workflow + aither_testing_framework
```

### With Other AI Agents

```javascript
// Multi-step automation workflows
1. aither_dev_environment → Setup development environment
2. aither_patch_workflow → Create and test changes
3. aither_infrastructure_deployment → Deploy to lab
4. aither_testing_framework → Validate deployment
```

### With CI/CD Pipelines

```javascript
// Automated infrastructure management
GitHub Action → MCP Server → AitherZero → Infrastructure
```

## Advanced Features

### Cross-Fork Repository Operations

```javascript
{
  "tool": "aither_patch_workflow",
  "arguments": {
    "description": "Security improvement for upstream",
    "targetFork": "upstream", // AitherZero → AitherLabs → Aitherium
    "createPR": true
  }
}
```

### Parallel Task Execution

```javascript
{
  "tool": "aither_parallel_execution",
  "arguments": {
    "operation": "execute",
    "scriptBlocks": [
      "Test-Module ModuleA",
      "Test-Module ModuleB",
      "Test-Module ModuleC"
    ],
    "maxJobs": 4
  }
}
```

### Comprehensive Infrastructure Validation

```javascript
{
  "tool": "aither_infrastructure_deployment",
  "arguments": {
    "operation": "security",
    "configPath": "infrastructure/main.tf"
  }
}
```

## Contributing

1. **Follow the coding standards** established in the project
2. **Add comprehensive tests** for new tools
3. **Update documentation** for new capabilities
4. **Test cross-platform compatibility**
5. **Validate PowerShell integration**

## License

MIT License - See the main AitherZero project for details.

---

**Ready to supercharge your AI agents with enterprise-grade infrastructure automation!** 🚀

# AitherZero MCP Server for Claude Code

This adapter enables Claude Code to use AitherZero's powerful automation tools directly, without requiring the MCP protocol transport layer.

## What I've Created

1. **`claude-code-adapter.js`** - Core adapter that translates MCP tools to direct PowerShell execution
2. **`aither-tools.js`** - Simplified API for Claude Code to use AitherZero tools
3. **`claude-code-example.js`** - Examples showing how to use the tools
4. **`test-claude-code.js`** - Test script for the integration

## How It Works

The adapter bypasses the MCP protocol and directly executes PowerShell commands, making it perfect for Claude Code usage:

```javascript
import { AitherTools } from './mcp-server/aither-tools.js';

// Run tests
const result = await AitherTools.runTests('Quick', true);

// Create patches with Git workflow
const patch = await AitherTools.createPatch(
  "Fix documentation typo",
  "PowerShell code here",
  true  // Create PR
);

// Manage infrastructure
const plan = await AitherTools.infrastructure('plan', './configs/lab.json');
```

## Available Tools

### 1. Testing Framework
```javascript
// Quick validation (30 seconds)
await AitherTools.runTests('Quick', true);

// Standard validation (2-5 minutes)
await AitherTools.runTests('Standard', false);

// Complete validation (10-15 minutes)
await AitherTools.runTests('Complete', false);
```

### 2. Patch Management
```javascript
// Create a patch with automated Git workflow
await AitherTools.createPatch(
  "Description of changes",
  "PowerShell code to execute",
  true  // Create pull request
);
```

### 3. Development Environment
```javascript
// Check status
await AitherTools.devEnvironment('status');

// Setup environment
await AitherTools.devEnvironment('setup');

// Validate environment
await AitherTools.devEnvironment('validate');
```

### 4. Backup Management
```javascript
// Create backup
await AitherTools.backup('backup', {
  sourcePath: './data',
  destinationPath: './backups'
});

// Cleanup old backups
await AitherTools.backup('cleanup', {
  retentionDays: 30
});
```

### 5. Infrastructure Deployment
```javascript
// Plan changes
await AitherTools.infrastructure('plan', './config.json');

// Apply changes
await AitherTools.infrastructure('apply', './config.json', false);

// Destroy infrastructure
await AitherTools.infrastructure('destroy', './config.json', false);
```

### 6. Direct Tool Execution
```javascript
// Execute any of the 14 available tools directly
await AitherTools.executeTool('aither_logging_system', {
  operation: 'log',
  level: 'INFO',
  message: 'Custom log message'
});
```

## Requirements

- Node.js 18.0+
- PowerShell 7.0+ (for executing the underlying tools)
- AitherZero framework properly installed

## Usage in Claude Code

When I need to perform AitherZero operations, I can now:

1. Import the tools: `import { AitherTools } from './mcp-server/aither-tools.js'`
2. Execute any tool with appropriate parameters
3. Handle the JSON results returned

This integration enables Claude Code to:
- Run comprehensive tests
- Create patches with automated Git workflows
- Manage infrastructure deployments
- Handle backups and maintenance
- Execute any of the 14 specialized AitherZero tools

## PowerShell 7 Auto-Installation

The enhanced adapter now includes **automatic PowerShell 7 detection and installation**:

### Check PowerShell 7 Status
```bash
node aither-tools-enhanced.js check
```

### Install PowerShell 7 (Windows)
```bash
node claude-code-adapter-enhanced.js --install-pwsh
```

### Generate Bootstrap Script (All Platforms)
```bash
node claude-code-adapter-enhanced.js --bootstrap
```

The adapter will:
1. **Automatically detect** if PowerShell 7 is installed
2. **Offer to install it** on Windows platforms
3. **Provide manual installation instructions** for Linux/macOS
4. **Generate bootstrap scripts** that include PowerShell 7 installation

## Enhanced Features

### Automatic Initialization
The enhanced version (`aither-tools-enhanced.js`) automatically:
- Checks for PowerShell 7 on first use
- Offers installation if not found
- Initializes all tools after PowerShell 7 is available

### Cross-Platform Support
- **Windows**: Automatic MSI download and silent installation
- **Linux**: Instructions for package manager installation
- **macOS**: Homebrew installation guidance

### Usage with Enhanced Adapter
```javascript
import { AitherTools } from './mcp-server/aither-tools-enhanced.js';

// Check PowerShell 7 availability
const hasPwsh = await AitherTools.checkPowerShell7();

// Install if needed (Windows only)
if (!hasPwsh) {
  await AitherTools.installPowerShell7();
}

// Then use any tool
const result = await AitherTools.runTests('Quick');
```
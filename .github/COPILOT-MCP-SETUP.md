# GitHub Copilot MCP Server Setup

This document explains how GitHub Copilot is configured to use the AitherZero MCP Server for infrastructure automation.

## Overview

The AitherZero MCP (Model Context Protocol) server is automatically loaded when Copilot starts in this workspace. It provides 8 powerful tools for infrastructure automation:

1. **`run_script`** - Execute automation scripts (0000-9999)
2. **`list_scripts`** - List all available scripts
3. **`search_scripts`** - Search by keyword
4. **`execute_playbook`** - Run playbook sequences
5. **`get_configuration`** - Retrieve config values
6. **`run_tests`** - Execute Pester tests
7. **`run_quality_check`** - Run PSScriptAnalyzer
8. **`get_project_report`** - Generate project metrics

## Configuration

The MCP server is configured in `.vscode/mcp-servers.json` (workspace-level):

```json
{
  "mcpServers": {
    "aitherzero": {
      "command": "node",
      "args": ["${workspaceFolder}/integrations/mcp-server/dist/index.js"],
      "description": "AitherZero infrastructure automation platform",
      "env": {
        "AITHERZERO_ROOT": "${workspaceFolder}",
        "AITHERZERO_NONINTERACTIVE": "1"
      }
    }
  },
  "defaultServers": ["aitherzero", "filesystem", "github", "git"]
}
```

## First-Time Setup

When you open this workspace, Copilot will automatically:

1. Detect the MCP server configuration
2. Build the server if needed: `cd mcp-server && npm install && npm run build`
3. Start the server on stdio
4. Make all 8 tools available

### Manual Build (if needed)

```bash
cd mcp-server
npm install
npm run build
```

Or use the automation playbook:

```bash
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook mcp-server-setup
```

## How Copilot Uses the MCP Server

When you ask Copilot to perform infrastructure tasks, it will:

### Example 1: Running Tests
**You ask**: "Run all the E2E tests"

**Copilot executes**:
```json
{
  "tool": "run_script",
  "arguments": {
    "scriptNumber": "0402"
  }
}
```

### Example 2: Searching Scripts
**You ask**: "What scripts are available for Docker?"

**Copilot executes**:
```json
{
  "tool": "search_scripts",
  "arguments": {
    "query": "docker"
  }
}
```

### Example 3: Running Playbooks
**You ask**: "Execute the quick test playbook"

**Copilot executes**:
```json
{
  "tool": "execute_playbook",
  "arguments": {
    "playbookName": "test-quick",
    "profile": "quick"
  }
}
```

### Example 4: Quality Checks
**You ask**: "Run quality checks on the configuration domain"

**Copilot executes**:
```json
{
  "tool": "run_quality_check",
  "arguments": {
    "path": "./aithercore/configuration"
  }
}
```

## Verifying MCP Server is Active

When Copilot starts, you should see in the MCP output:

```
[MCP] Starting server: aitherzero
[MCP] AitherZero MCP Server running on stdio
[MCP] Server ready: aitherzero (8 tools available)
```

You can also test manually:

```bash
cd mcp-server
echo '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}' | node dist/index.js
```

## Available Resources

The MCP server also exposes resources:

- `aitherzero://config` - Current configuration (JSON)
- `aitherzero://scripts` - List of automation scripts
- `aitherzero://project-report` - Project status and metrics

Copilot can read these resources directly without executing commands.

## Automation Scripts Reference

The MCP server can execute any of the 0000-9999 automation scripts:

### Common Scripts
- **0402** - Run unit tests
- **0404** - Run PSScriptAnalyzer
- **0407** - Validate syntax
- **0510** - Generate project report
- **0701** - Create Git branch
- **0702** - Commit changes
- **0703** - Create PR

### Script Ranges
- **0000-0099** - Environment prep
- **0100-0199** - Infrastructure (Hyper-V, networking)
- **0200-0299** - Dev tools (Git, Docker, VS Code)
- **0400-0499** - Testing & validation
- **0500-0599** - Reporting & metrics
- **0700-0799** - Git automation & AI tools
- **9000-9999** - Maintenance & cleanup

## Playbooks Reference

The MCP server can execute these playbooks:

- **test-quick** - Fast validation (smoke tests)
- **test-full** - Complete test suite
- **test-comprehensive** - All tests with coverage
- **setup-dev** - Development environment setup
- **setup-minimal** - Minimal PowerShell 7 setup
- **mcp-server-setup** - Build and test MCP server

## Troubleshooting

### Server Not Starting

**Check Node.js**:
```bash
node --version  # Should be 18+
```

**Check PowerShell**:
```bash
pwsh --version  # Should be 7.0+
```

**Rebuild Server**:
```bash
cd mcp-server
rm -rf node_modules dist
npm install
npm run build
```

### Tools Not Available

Check Copilot MCP output panel:
1. Open Command Palette (Ctrl+Shift+P)
2. Type "MCP: Show Output"
3. Look for "aitherzero" server status

### Server Crashes

Check logs in `logs/transcript-*.log` for PowerShell execution errors.

## Security Considerations

The MCP server:
- Runs with your user permissions
- Executes PowerShell commands
- Can modify files in the repository
- Requires Node.js and PowerShell installed

**Review commands before allowing Copilot to execute them** in production environments.

## Development

To modify the MCP server:

1. Edit `mcp-server/src/index.ts`
2. Rebuild: `npm run build`
3. Test: `npm test`
4. Restart Copilot to reload

## Related Documentation

- [MCP Server README](../integrations/mcp-server/README.md)
- [Model Context Protocol Specification](https://modelcontextprotocol.io/)
- [AitherZero Automation Scripts](../automation-scripts/README.md)
- [Orchestration Playbooks](../orchestration/playbooks/README.md)

---

**Last Updated**: 2025-11-02  
**MCP Server Version**: 0.1.0  
**Copilot Integration**: Enabled by default

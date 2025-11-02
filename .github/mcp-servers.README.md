# MCP Servers Configuration Reference

**NOTE**: This directory contains reference configuration for Model Context Protocol (MCP) servers. The actual configuration used by VS Code is in `.vscode/settings.json`.

## Why Two Locations?

- **`.github/mcp-servers.json`**: Documentation and reference configuration
- **`.vscode/settings.json`**: Actual configuration used by VS Code/Copilot

## Setup

Use the automation script to configure MCP servers properly:

```bash
# Configure MCP servers in VS Code settings
./automation-scripts/0215_Configure-MCPServers.ps1

# Or using the az wrapper
az 0215

# Verify configuration
az 0215 -Verify
```

## Manual Configuration

The MCP servers are configured in `.vscode/settings.json` under:

```jsonc
{
  "github.copilot.chat.mcp.enabled": true,
  "github.copilot.chat.mcp.servers": {
    // Server configurations here
  }
}
```

See the full documentation in `/docs/COPILOT-MCP-SETUP.md`.

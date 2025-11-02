# Example MCP Client Configurations for AitherZero Server

This directory contains example configuration files for various MCP clients to connect to the AitherZero MCP server.

## Claude Desktop

**Location**: 
- macOS: `~/Library/Application Support/Claude/claude_desktop_config.json`
- Windows: `%APPDATA%/Claude/claude_desktop_config.json`
- Linux: `~/.config/Claude/claude_desktop_config.json`

**Configuration**: See `claude-desktop-config.json`

## VS Code / GitHub Copilot

**Location**: `.vscode/mcp-servers.json` in your workspace

**Configuration**: See `vscode-mcp-config.json`

## Generic MCP Client

For any MCP-compatible client that supports stdio transport.

**Configuration**: See `generic-mcp-config.json`

## Usage

1. Copy the appropriate configuration file
2. Update the paths to match your AitherZero installation
3. Restart your AI assistant application
4. Verify the server appears in your AI assistant's capabilities

## Customization

All configurations support these environment variables:

- `AITHERZERO_ROOT`: Path to your AitherZero installation
- `AITHERZERO_DISABLE_TRANSCRIPT`: Set to `1` to disable logging (optional)

## Verification

After configuration, test with your AI assistant:

```
"List available AitherZero scripts"
"What's in the AitherZero configuration?"
"Run the AitherZero test suite"
```

If the AI assistant can execute these commands, the MCP server is working correctly.

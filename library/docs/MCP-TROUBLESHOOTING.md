# Troubleshooting MCP Servers in GitHub Copilot for VS Code

## Issue RESOLVED
The MCP configuration script was using an incorrect format. The script has been updated to use the official VS Code MCP configuration format with `.vscode/mcp.json`.

## Correct Configuration Format

VS Code uses **`.vscode/mcp.json`** (not settings.json) for MCP server configuration.

### Official Format
```json
{
  "servers": {
    "filesystem": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem", "${workspaceFolder}"]
    },
    "github": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "${env:GITHUB_TOKEN}"
      }
    }
  },
  "inputs": [
    {
      "id": "github-token",
      "type": "promptString",
      "description": "GitHub Personal Access Token for API access",
      "password": true
    }
  ]
}
```

## Quick Start

The updated `0215_Configure-MCPServers.ps1` script now creates the correct format:

```bash
# Configure MCP servers in workspace
./library/automation-scripts/0215_Configure-MCPServers.ps1

# Verify configuration
./library/automation-scripts/0215_Configure-MCPServers.ps1 -Verify
```

## How It Works Now

## How It Works Now

1. **Configuration File**: Creates `.vscode/mcp.json` in your workspace
2. **Server Discovery**: VS Code automatically detects servers when you reload
3. **Trust Prompt**: VS Code prompts you to trust each MCP server on first use
4. **Tool Access**: Use `#` in Copilot Chat to see available MCP tools
5. **Agent Mode**: MCP tools are automatically invoked when relevant

## Prerequisites

### 1. VS Code Version
- **Minimum**: VS Code 1.87.0 or later (current: latest recommended)
- **Check**: `code --version`

### 2. GitHub Copilot Extension
- **Status**: MCP support is now GA (Generally Available)
- **Install**: From Extensions view or `code --install-extension GitHub.copilot`

### 3. Node.js
- **Minimum**: Node.js 18+
- **Check**: `node --version`
- **Required**: For running stdio MCP servers with npx

## Using MCP Servers in VS Code

## Using MCP Servers in VS Code

### Step 1: Run Configuration Script
```bash
cd /path/to/AitherZero
./library/automation-scripts/0215_Configure-MCPServers.ps1
```

This creates `.vscode/mcp.json` with 5 MCP servers configured.

### Step 2: Reload VS Code
- Press `Ctrl+Shift+P` / `Cmd+Shift+P`
- Type and select: **"Developer: Reload Window"**

### Step 3: Trust MCP Servers
VS Code will prompt you to trust each MCP server when it starts for the first time.
- Review the server configuration
- Click "Trust" if the source is reliable

### Step 4: Access MCP Tools in Copilot Chat
1. Open Copilot Chat: `Ctrl+Alt+I` / `Cmd+Option+I`
2. **Agent Mode**: Tools are automatically invoked
   - Example: "List my GitHub issues" → Uses GitHub MCP server
3. **Manual Tool Selection**: Type `#` to see all available MCP tools
4. **MCP Resources**: Select "Add Context" → "MCP Resources"

### Step 5: Verify MCP Servers Are Running
```bash
./library/automation-scripts/0215_Configure-MCPServers.ps1 -Verify
```

Should show:
```
✓ 5 MCP server(s) configured
  - aitherzero (type: stdio)
  - filesystem (type: stdio)
  - git (type: stdio)
  - github (type: stdio)
  - sequential-thinking (type: stdio)
```

## Current Status in AitherZero

The `0215_Configure-MCPServers.ps1` script correctly configures MCP:
- ✓ Uses correct keys: `github.copilot.chat.mcp.enabled` and `github.copilot.chat.mcp.servers`
- ✓ Configures 5 MCP servers with proper commands and arguments
- ✓ Handles JSON comments in VS Code settings files
- ✓ No debug proxy URL or incorrect configuration keys
- ✓ Graceful error handling and validation

## Alternative: Use MCP Servers Directly

If GitHub Copilot MCP support isn't available in your version yet, you can use MCP servers through alternative methods:

### Option 1: Claude Desktop (Full MCP Support)
Claude Desktop has native MCP support. Configure in `claude_desktop_config.json`:

**Windows**: `%APPDATA%\Claude\claude_desktop_config.json`
**macOS**: `~/Library/Application Support/Claude/claude_desktop_config.json`
**Linux**: `~/.config/Claude/claude_desktop_config.json`

```json
{
  "mcpServers": {
    "aitherzero": {
      "command": "node",
      "args": ["/absolute/path/to/AitherZero/integrations/mcp-server/scripts/start-with-build.mjs"],
      "env": {
        "AITHERZERO_ROOT": "/absolute/path/to/AitherZero"
      }
    },
    "filesystem": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem", "/absolute/path/to/AitherZero"]
    }
  }
}
```

### Option 2: Direct MCP Server Usage
Run MCP servers standalone for testing:
```bash
# Start the AitherZero MCP server
cd /path/to/AitherZero
node mcp-server/scripts/start-with-build.mjs

# Or use the automation scripts
./library/automation-scripts/0751_Start-MCPServer.ps1
./library/automation-scripts/0752_Demo-MCPServer.ps1
./library/automation-scripts/0753_Use-MCPServer.ps1
```

### Option 3: Use MCP Inspector
Debug MCP servers with the official inspector:
```bash
# Install MCP Inspector
npm install -g @modelcontextprotocol/inspector

# Inspect a server
npx @modelcontextprotocol/inspector npx -y @modelcontextprotocol/server-filesystem .
```

## Known Limitations

### 1. GitHub Copilot MCP Support is Experimental
- **Not GA (Generally Available)**: Feature is in preview/experimental phase
- **Version Dependent**: Not all Copilot extension versions have MCP support
- **Feature Flags**: May be behind internal feature flags or A/B testing
- **Subscription Tiers**: May require GitHub Copilot Business or Enterprise subscription
- **Region Availability**: May not be available in all regions yet

### 2. VS Code Version Compatibility
- **Older Versions**: VS Code < 1.87 doesn't support the MCP extension API
- **Extension API Changes**: MCP API is evolving, breaking changes possible
- **Platform Variations**: Implementation may differ between platforms

### 3. Platform Differences
- **Windows**: Full support with proper Node.js installation
- **Linux**: Works well with npm/npx available
- **macOS**: Similar to Linux, check Node.js version

### 4. Node.js Requirements
- **Minimum**: Node.js 18+ required for MCP servers
- **Check**: `node --version`
- **Install**: https://nodejs.org/ or use `./library/automation-scripts/0201_Install-Node.ps1`

## Verification Commands

```bash
# Check VS Code version
code --version

# List installed extensions and versions
code --list-extensions --show-versions | grep -i copilot

# Check Node.js version (required for MCP servers)
node --version

# Test if MCP servers can start
npx -y @modelcontextprotocol/server-filesystem --help
npx -y @modelcontextprotocol/server-github --help

# Verify MCP configuration
./library/automation-scripts/0215_Configure-MCPServers.ps1 -Verify

# Check for GITHUB_TOKEN (required for github MCP server)
echo $env:GITHUB_TOKEN  # Windows PowerShell
echo $GITHUB_TOKEN      # Linux/macOS
```

## Common Issues and Solutions

### Issue: "MCP servers not showing up"
**Solution**: 
1. Ensure `github.copilot.chat.mcp.enabled: true` in User Settings
2. Reload VS Code window
3. Check Copilot extension version (need v1.154.0+)

### Issue: "GitHub MCP server fails to start"
**Solution**:
```bash
# Set GITHUB_TOKEN environment variable
export GITHUB_TOKEN='your_github_personal_access_token'

# Or add to your shell profile (~/.bashrc, ~/.zshrc, etc.)
echo 'export GITHUB_TOKEN="your_token"' >> ~/.bashrc
```

### Issue: "Cannot find npx command"
**Solution**:
```bash
# Install Node.js using AitherZero automation
./library/automation-scripts/0201_Install-Node.ps1

# Or download from nodejs.org
```

### Issue: "MCP configuration menu not visible"
**Solution**: This indicates your Copilot extension version doesn't have MCP support yet. Try:
1. Update to latest Copilot extension
2. Check if you have Business/Enterprise subscription
3. Use Claude Desktop as alternative (see Option 1 above)

## Next Steps

If MCP still doesn't work after following these steps:

1. **Check GitHub Copilot subscription tier**
   - Personal tier may not have MCP support yet
   - Consider GitHub Copilot Business/Enterprise

2. **Wait for GA release**
   - Feature is in preview, not widely available yet
   - Subscribe to GitHub Copilot updates

3. **Use alternative MCP clients**
   - Claude Desktop (recommended, full MCP support)
   - Direct MCP server usage for development/testing

4. **Verify your environment**
   - Run diagnostics: `./library/automation-scripts/0500_Validate-Environment.ps1`
   - Check logs: `.vscode/settings.json` configuration

5. **File issue with GitHub Copilot**
   - If you believe you should have access but don't
   - Include: VS Code version, Copilot extension version, subscription tier

## Resources

- **GitHub Copilot Documentation**: https://docs.github.com/copilot
- **MCP Protocol Specification**: https://modelcontextprotocol.io/
- **VS Code Extension API**: https://code.visualstudio.com/api
- **AitherZero MCP Documentation**: [./COPILOT-MCP-SETUP.md](./COPILOT-MCP-SETUP.md)
- **GitHub Copilot Release Notes**: Check VS Code Extensions panel

## Quick Diagnostic Script

Run this to check your MCP readiness:

```bash
# Quick MCP diagnostic
cd /path/to/AitherZero

echo "=== MCP Readiness Check ==="
echo ""
echo "1. VS Code Version:"
code --version | head -1

echo ""
echo "2. GitHub Copilot Extension:"
code --list-extensions --show-versions | grep -i copilot

echo ""
echo "3. Node.js Version:"
node --version

echo ""
echo "4. MCP Configuration:"
./library/automation-scripts/0215_Configure-MCPServers.ps1 -Verify

echo ""
echo "5. GitHub Token:"
if [ -n "$GITHUB_TOKEN" ]; then
    echo "✓ GITHUB_TOKEN is set (${#GITHUB_TOKEN} characters)"
else
    echo "✗ GITHUB_TOKEN not set"
fi

echo ""
echo "=== Check Complete ==="
```

Save as `check-mcp.sh`, make executable (`chmod +x check-mcp.sh`), and run: `./check-mcp.sh`

## Summary

MCP support in GitHub Copilot for VS Code is experimental and may not be available to all users yet. The AitherZero configuration script (`0215_Configure-MCPServers.ps1`) correctly sets up MCP servers using the proper keys and configuration. If you can't see MCP servers in VS Code:

1. **Most Likely**: Your Copilot extension version doesn't have MCP support yet
2. **Verify**: Check extension version (need v1.154.0+) and subscription tier
3. **Alternative**: Use Claude Desktop which has full, stable MCP support
4. **Wait**: GA release of MCP support in GitHub Copilot is coming

The configuration is correct - it's a matter of feature availability in your Copilot extension version.

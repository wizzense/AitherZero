# Troubleshooting MCP Servers in GitHub Copilot for VS Code

## Issue
MCP servers are not visible in GitHub Copilot Chat in VS Code. Unable to enable or see their tools in the MCP configuration menu.

## Root Cause
The MCP (Model Context Protocol) support in GitHub Copilot for VS Code is currently in **experimental/preview** status and requires specific versions and configuration.

## Prerequisites

### 1. VS Code Version
- **Minimum**: VS Code 1.87.0 or later
- **Check**: `code --version`

### 2. GitHub Copilot Extension Version
- **Minimum**: GitHub Copilot v1.154.0 or later (with MCP support)
- **Check**: In VS Code: Extensions → GitHub Copilot → Check version
- **Note**: MCP support may not be available in all versions/regions yet

### 3. Enable Experimental Features
MCP support must be explicitly enabled in VS Code settings.

## Solution Steps

### Step 1: Update Extensions
```bash
# Update VS Code extensions
code --update-extensions
```

Or manually update:
1. Open VS Code
2. Extensions (Ctrl+Shift+X / Cmd+Shift+X)
3. Click "Update" on GitHub Copilot extension
4. Reload VS Code window

### Step 2: Enable MCP Support
Add to your VS Code **User Settings** (Ctrl+, / Cmd+,):

```jsonc
{
  // Enable MCP experimental features (may be required)
  "github.copilot.advanced.debug.useElectronMCP": true,
  
  // Enable MCP servers
  "github.copilot.chat.mcp.enabled": true,
  
  // MCP servers are configured in workspace settings
}
```

**Important**: Add these to **User Settings** (`settings.json`), not workspace settings. The MCP servers themselves are already configured in the workspace `.vscode/settings.json`.

### Step 3: Verify Workspace Configuration
The workspace already has MCP servers configured in `.vscode/settings.json`:
- ✓ `aitherzero` - AitherZero infrastructure automation
- ✓ `filesystem` - Repository file access
- ✓ `github` - GitHub API operations
- ✓ `sequential-thinking` - Complex reasoning

You can verify this by running:
```bash
./automation-scripts/0215_Configure-MCPServers.ps1 -Verify
```

### Step 4: Reload VS Code
1. Press Ctrl+Shift+P / Cmd+Shift+P
2. Type and select: "Developer: Reload Window"
3. Or completely close and reopen VS Code

### Step 5: Check MCP Status
1. Open Copilot Chat (Ctrl+Shift+I / Cmd+Shift+I or Ctrl+Alt+I / Cmd+Option+I)
2. Look for MCP indicator or context menu in the chat interface
3. Try using: `@workspace` to test workspace context
4. Check Output panel: View → Output → Select "GitHub Copilot Chat" for logs

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
      "args": ["/absolute/path/to/AitherZero/mcp-server/scripts/start-with-build.mjs"],
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
./automation-scripts/0751_Start-MCPServer.ps1
./automation-scripts/0752_Demo-MCPServer.ps1
./automation-scripts/0753_Use-MCPServer.ps1
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
- **Install**: https://nodejs.org/ or use `./automation-scripts/0201_Install-Node.ps1`

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
./automation-scripts/0215_Configure-MCPServers.ps1 -Verify

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
./automation-scripts/0201_Install-Node.ps1

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
   - Run diagnostics: `./automation-scripts/0500_Validate-Environment.ps1`
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
./automation-scripts/0215_Configure-MCPServers.ps1 -Verify

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

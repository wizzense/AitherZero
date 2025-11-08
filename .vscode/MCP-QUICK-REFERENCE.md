# MCP Server Quick Reference

## Automated Setup

MCP servers are **automatically built and configured** when you:

1. **Open dev container** - `postCreateCommand` builds MCP server
2. **Start VS Code** - `postStartCommand` runs idempotent setup script
3. **Run task** - Use VS Code task "Setup MCP Servers"

## One Command Does It All

```powershell
# Idempotent setup - safe to run anytime
./automation-scripts/0010_Setup-MCPServers.ps1

# Force rebuild
./automation-scripts/0010_Setup-MCPServers.ps1 -Force

# Auto-fix config issues (removes non-existent packages)
./automation-scripts/0010_Setup-MCPServers.ps1 -FixConfig
```

**The script is idempotent** - run it as many times as you want, it will:

- Only build if needed (or with `-Force`)
- Detect and warn about config issues
- Auto-fix known problems with `-FixConfig`
- Always show activation instructions

## VS Code Tasks

Open Command Palette (`Ctrl+Shift+P`) and run:

- **Tasks: Run Task** → **Setup MCP Servers** - Standard setup
- **Tasks: Run Task** → **Rebuild MCP Servers** - Force rebuild

## Activation Steps

After building/configuring MCP servers:

### 1. Reload VS Code Window

- Press `Ctrl+Shift+P` (or `Cmd+Shift+P` on macOS)
- Type: `Developer: Reload Window`
- Press `Enter`

### 2. Verify MCP Servers Loaded

- Open: **View > Output** (`Ctrl+Shift+U`)
- Select: **"GitHub Copilot"** from dropdown
- Look for:

  ```
  [MCP] Starting server: aitherzero
  AitherZero MCP Server running on stdio
  [MCP] Server ready: aitherzero (8 tools available)
  ```

### 3. Test in Copilot Chat

- Open Copilot Chat (`Ctrl+Shift+I`)
- Try commands:

  ```
  @workspace List all automation scripts
  @workspace Search scripts for "test"
  @workspace Execute playbook test-quick
  @workspace Run quality check
  ```

## Available MCP Servers

| Server | Description | Status |
|--------|-------------|--------|
| **aitherzero** | AitherZero automation platform | ✅ Custom server with 8 tools |
| **filesystem** | Repository file access | ✅ Standard MCP server |
| **github** | GitHub API integration | ✅ Standard MCP server |
| **sequential-thinking** | Complex problem solving | ✅ Standard MCP server |

**Removed servers** (non-existent packages that caused Sentry errors):

- ❌ `git` - Used `@modelcontextprotocol/server-git` (doesn't exist)
- ❌ `powershell-docs` - Used `@modelcontextprotocol/server-fetch` (doesn't exist)

These caused the error: `Error sending message to https://mcp.sentry.dev/sse: TypeError: Failed to fetch`

## Troubleshooting

### MCP Servers Not Appearing in Copilot Chat

1. **Verify built**: Check `mcp-server/dist/index.js` exists
2. **Check config**: `.vscode/mcp-servers.json` should exist
3. **Verify settings**: `.vscode/settings.json` should have:

   ```json
   "github.copilot.chat.mcp.enabled": true,
   "github.copilot.chat.mcp.configFile": "${workspaceFolder}/.vscode/mcp-servers.json"
   ```

4. **Reload window**: Must reload after configuration changes
5. **Check Output**: View > Output > "GitHub Copilot" for errors

### Build Failures

```powershell
# Check Node.js installation
node --version  # Should be v18+
npm --version

# Manual build
cd mcp-server
npm install
npm run build

# Check build output
ls dist/index.js
```

### Server Not Starting

```powershell
# Test server manually
cd mcp-server
node dist/index.js

# Check environment
echo $env:AITHERZERO_ROOT  # Should point to workspace
```

## Development

### Rebuild After Changes

```powershell
# Auto-rebuild (watches for changes)
cd mcp-server
npm run watch

# Manual rebuild
npm run build

# Test server
npm run test
```

### Update MCP Configuration

Edit `.vscode/mcp-servers.json` and reload VS Code window.

## References

- [MCP Setup Documentation](../docs/COPILOT-MCP-SETUP.md)
- [MCP Server Implementation](../integrations/mcp-server/README.md)
- [Custom Instructions](../.github/copilot-instructions.md)
- [Model Context Protocol](https://github.com/modelcontextprotocol/specification)

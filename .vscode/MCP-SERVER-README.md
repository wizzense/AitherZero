# AitherZero MCP Server - Auto-Start Configuration

## ✅ Configuration Complete

The AitherZero MCP server is **fully configured** in this workspace at `.vscode/mcp-servers.json`.

## 🚀 How to Activate

### For This Workspace to Load the Server:

1. **Close and reopen VS Code** OR
2. **Reload the window**: Press `Ctrl+Shift+P` → "Developer: Reload Window"

### What You'll See When It Starts:

```
[MCP] Starting server: aitherzero
🔨 Building AitherZero MCP Server... (first time only)
📦 Installing dependencies...
✅ MCP Server built successfully
AitherZero MCP Server running on stdio
[MCP] Server ready: aitherzero (8 tools available)
```

## 📋 Verify It's Running

After reloading, check the output panel:
- View → Output
- Select "MCP Servers" or "GitHub Copilot"
- You should see `aitherzero` listed alongside `github-mcp-server` and `playwright`

## 🔧 Troubleshooting

### Server Not Starting?

1. **Check Node.js**: Ensure Node.js 18+ is installed
   ```bash
   node --version
   ```

2. **Check the config file**: `.vscode/mcp-servers.json` should exist
   ```bash
   ls -la .vscode/mcp-servers.json
   ```

3. **Manual test**: Run the server manually to see errors
   ```bash
   cd mcp-server
   npm install
   npm run build
   node dist/index.js
   ```

4. **Restart VS Code**: Sometimes a full restart is needed, not just reload

### Still Not Working?

Check VS Code logs:
- Help → Toggle Developer Tools
- Console tab → Look for MCP-related errors

## 🎯 Available Tools

Once running, Copilot can use these 8 tools:

1. **`run_script`** - Execute automation scripts (0000-9999)
2. **`list_scripts`** - List all available scripts
3. **`search_scripts`** - Search by keyword
4. **`execute_playbook`** - Run playbook sequences
5. **`get_configuration`** - Retrieve config values
6. **`run_tests`** - Execute Pester tests
7. **`run_quality_check`** - Run PSScriptAnalyzer
8. **`get_project_report`** - Generate project metrics

## 📝 Usage Examples

Once the server is running, you can ask Copilot:

- "Run the E2E tests using the aitherzero server"
- "Search for Docker-related scripts"
- "Execute the test-quick playbook"
- "Get the project quality report"

Copilot will automatically use the AitherZero MCP server tools to accomplish these tasks.

## ⚙️ Configuration Location

- **Workspace Config**: `.vscode/mcp-servers.json` (used by Copilot)
- **Example Config**: `.github/mcp-servers.json` (documentation reference)
- **Auto-Build Wrapper**: `mcp-server/scripts/start-with-build.mjs`

## 🔄 Auto-Build Feature

The server automatically builds on first use:
- Detects if `dist/index.js` exists
- Runs `npm install` if needed
- Runs `npm run build` if needed
- Then starts the server

No manual build steps required!

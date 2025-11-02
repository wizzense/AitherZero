# AitherZero MCP Server - Quick Start Guide

## What You've Built

A Model Context Protocol (MCP) server that exposes AitherZero's infrastructure automation to AI assistants!

## 5-Minute Setup

### 1. Build the Server
```bash
cd mcp-server
npm install  # Already done ✓
npm run build  # Already done ✓
```

### 2. Test It Works
```bash
npm run test:manual
# Should show JSON response with 8 tools
```

### 3. Configure Your AI Assistant

#### For Claude Desktop
Edit: `~/Library/Application Support/Claude/claude_desktop_config.json`

```json
{
  "mcpServers": {
    "aitherzero": {
      "command": "node",
      "args": ["/FULL/PATH/TO/AitherZero/mcp-server/dist/index.js"],
      "env": {
        "AITHERZERO_ROOT": "/FULL/PATH/TO/AitherZero"
      }
    }
  }
}
```

**Replace `/FULL/PATH/TO/` with your actual path!**

#### For VS Code / GitHub Copilot
Create: `.vscode/mcp-servers.json` in your workspace

```json
{
  "mcpServers": {
    "aitherzero": {
      "command": "node",
      "args": ["${workspaceFolder}/mcp-server/dist/index.js"],
      "env": {
        "AITHERZERO_ROOT": "${workspaceFolder}"
      }
    }
  }
}
```

### 4. Restart Your AI Assistant
- Claude Desktop: Quit and reopen
- VS Code: Reload window (Cmd/Ctrl + Shift + P → "Reload Window")

### 5. Try It!

Ask your AI assistant:

```
"List all AitherZero automation scripts"
"Search for Docker scripts in AitherZero"
"Run AitherZero tests"
"Show me the AitherZero project report"
```

## What Can AI Assistants Do?

### 8 Tools Available

1. **run_script** - Run numbered scripts (0000-9999)
   ```
   "Run script 0402 to execute tests"
   ```

2. **list_scripts** - See all automation scripts
   ```
   "What scripts are available?"
   ```

3. **search_scripts** - Find scripts by keyword
   ```
   "Find Docker-related scripts"
   ```

4. **execute_playbook** - Run playbook sequences
   ```
   "Execute the quick test playbook"
   ```

5. **get_configuration** - Query config
   ```
   "What's the current testing profile?"
   ```

6. **run_tests** - Execute Pester tests
   ```
   "Run all unit tests"
   ```

7. **run_quality_check** - Validate code
   ```
   "Check utilities domain for issues"
   ```

8. **get_project_report** - Get metrics
   ```
   "Show project status"
   ```

### 3 Resources Available

- `aitherzero://config` - Configuration JSON
- `aitherzero://scripts` - Script listings  
- `aitherzero://project-report` - Project metrics

## Common Issues

### "Server not found"
- Check file paths are absolute (not relative)
- Verify files exist: `ls /path/to/AitherZero/mcp-server/dist/index.js`
- Restart your AI assistant

### "pwsh not found"  
- Install PowerShell 7: `brew install powershell` (macOS)
- Verify: `pwsh --version`

### "Module not found"
- Run: `cd $AITHERZERO_ROOT && ./Initialize-AitherEnvironment.ps1`

## Next Steps

- Read full docs: `docs/AITHERZERO-MCP-SERVER.md`
- See examples: `mcp-server/examples/`
- Test manually: `npm run test:manual`

## Architecture Diagram

```
┌─────────────────┐
│  AI Assistant   │  "Run AitherZero tests"
│  (Claude, etc)  │
└────────┬────────┘
         │ MCP Protocol
┌────────▼────────┐
│   MCP Server    │  Translates to PowerShell
│  (TypeScript)   │
└────────┬────────┘
         │ pwsh -Command
┌────────▼────────┐
│   AitherZero    │  Executes automation
│  (PowerShell)   │
└─────────────────┘
```

## Support

- Full docs: [docs/AITHERZERO-MCP-SERVER.md](../docs/AITHERZERO-MCP-SERVER.md)
- Server README: [mcp-server/README.md](./README.md)
- GitHub Issues: [Create an issue](https://github.com/wizzense/AitherZero/issues)

---

**🎉 You're ready! Ask your AI assistant to use AitherZero!**

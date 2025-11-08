# MCP Configuration Files in AitherZero

This document explains the different MCP configuration files and their purposes.

## Overview

AitherZero includes three MCP configuration files for different use cases:

| File | Purpose | Format | Used By |
|------|---------|--------|---------|
| `.vscode/mcp.json` | VS Code Copilot | VS Code format | VS Code extension |
| `.vscode/mcp-servers.json` | Claude Desktop (workspace) | MCP standard | Claude Desktop, docs |
| `.github/mcp-servers.json` | Claude Desktop (portable) | MCP standard | Claude Desktop, CI/CD |

## 1. VS Code Format: `.vscode/mcp.json`

**Purpose**: Used by VS Code's GitHub Copilot extension for MCP server integration.

**Format**:
```json
{
  "servers": {
    "server-name": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-name"],
      "env": {}
    }
  },
  "inputs": [
    {
      "id": "variable-id",
      "type": "promptString",
      "description": "Description",
      "password": true
    }
  ]
}
```

**Key Features**:
- Root keys: `servers` and `inputs`
- Uses `${workspaceFolder}` variables
- Supports input variables for secure data
- Schema: VS Code-specific

**Created By**: `./library/automation-scripts/0215_Configure-MCPServers.ps1`

**Documentation**: https://code.visualstudio.com/docs/copilot/customization/mcp-servers

## 2. MCP Standard Format: `.vscode/mcp-servers.json` and `.github/mcp-servers.json`

**Purpose**: Used by Claude Desktop and other MCP clients (not VS Code).

**Format**:
```json
{
  "mcpServers": {
    "server-name": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-name"],
      "env": {},
      "description": "Server description",
      "tools": ["tool1", "tool2"]
    }
  }
}
```

**Key Features**:
- Root key: `mcpServers` (ONLY valid root key)
- NO `$schema`, `defaultServers`, or `contextProviders` allowed
- Optional `description` and `tools` fields for documentation
- Can include `type: "stdio"` explicitly

**Schema Validation Rules**:
- ✅ Allowed: `mcpServers` only at root level
- ❌ NOT allowed: `$schema`, `defaultServers`, `contextProviders`, `capabilities`, `config`

### Differences Between the Two MCP Files

**`.vscode/mcp-servers.json`**:
- Uses `${workspaceFolder}` variables
- Workspace-specific paths
- For team collaboration

**`.github/mcp-servers.json`**:
- Uses relative paths (`.`, `mcp-server/...`)
- More portable across systems
- For documentation and reference

## Configured MCP Servers

All three files configure these 6 MCP servers:

### 1. aitherzero
- **Command**: `node mcp-server/scripts/start-with-build.mjs`
- **Purpose**: AitherZero infrastructure automation
- **Tools**: run_script, list_scripts, execute_playbook, run_tests, etc.

### 2. filesystem
- **Command**: `npx -y @modelcontextprotocol/server-filesystem`
- **Purpose**: File and directory operations
- **Tools**: read_file, write_file, list_directory, search_files, etc.

### 3. github
- **Command**: `npx -y @modelcontextprotocol/server-github`
- **Purpose**: GitHub API access
- **Tools**: create_issue, create_pull_request, search_repositories, etc.
- **Requires**: GITHUB_TOKEN environment variable

### 4. git
- **Command**: `npx -y @modelcontextprotocol/server-git`
- **Purpose**: Git version control operations
- **Tools**: git_status, git_diff, git_commit, git_log, etc.

### 5. powershell-docs
- **Command**: `npx -y @modelcontextprotocol/server-fetch`
- **Purpose**: PowerShell documentation fetching
- **Tools**: search_powershell_docs, get_command_help, get_about_topic
- **Domains**: docs.microsoft.com, learn.microsoft.com

### 6. sequential-thinking
- **Command**: `npx -y @modelcontextprotocol/server-sequential-thinking`
- **Purpose**: Complex problem-solving and reasoning
- **Features**: Step-by-step thinking for complex tasks

## Usage

### For VS Code

1. Run configuration script:
   ```bash
   ./library/automation-scripts/0215_Configure-MCPServers.ps1
   ```

2. Reload VS Code window:
   - `Ctrl+Shift+P` → "Developer: Reload Window"

3. Trust MCP servers when prompted

4. Use in Copilot Chat:
   - Open Chat: `Ctrl+Alt+I`
   - Type `#` to see MCP tools
   - Or use agent mode: "List my GitHub issues"

### For Claude Desktop

1. Open Claude Desktop settings

2. Find the MCP configuration file location:
   - **Windows**: `%APPDATA%\Claude\claude_desktop_config.json`
   - **macOS**: `~/Library/Application Support/Claude/claude_desktop_config.json`
   - **Linux**: `~/.config/Claude/claude_desktop_config.json`

3. Copy servers from `.github/mcp-servers.json` or `.vscode/mcp-servers.json`

4. Update paths if needed (absolute paths for Claude Desktop)

5. Restart Claude Desktop

## Troubleshooting

### Schema Validation Error: "Property 'defaultServers' is not allowed"

**Cause**: Old version of config file with extra properties

**Solution**: Ensure config only has `mcpServers` at root:
```bash
# Check your config
cat .vscode/mcp-servers.json | jq 'keys'
# Should output: ["mcpServers"]
```

### Schema Validation Error: "Property '$schema' is not allowed"

**Cause**: `$schema` property in MCP standard config

**Solution**: Remove `$schema` from `.vscode/mcp-servers.json` and `.github/mcp-servers.json`

(Note: `$schema` is allowed in `.vscode/mcp.json` for VS Code)

### VS Code Not Showing MCP Servers

**Issue**: Using wrong config file format

**Solution**: 
- VS Code reads `.vscode/mcp.json` (not `mcp-servers.json`)
- Run: `./library/automation-scripts/0215_Configure-MCPServers.ps1`
- See: `docs/MCP-TROUBLESHOOTING.md`

### Claude Desktop Not Finding Servers

**Issue**: Relative paths or wrong file

**Solution**:
- Claude needs absolute paths in its config
- Copy from `.github/mcp-servers.json` and convert paths
- Or use absolute paths: `/full/path/to/AitherZero/...`

## File Maintenance

### When to Update

Update MCP configuration files when:
- Adding new MCP servers
- Changing server commands or arguments
- Updating environment variables
- Modifying tool configurations

### How to Update

**VS Code format** (`.vscode/mcp.json`):
```bash
./library/automation-scripts/0215_Configure-MCPServers.ps1
```

**MCP standard format** (`.vscode/mcp-servers.json`, `.github/mcp-servers.json`):
- Manually edit the JSON files
- Ensure only `mcpServers` at root level
- Keep both files in sync (one with `${workspaceFolder}`, one with `.`)

### Validation

```bash
# Validate JSON syntax
jq . .vscode/mcp.json
jq . .vscode/mcp-servers.json
jq . .github/mcp-servers.json

# Check root keys
jq 'keys' .vscode/mcp-servers.json
# Should output: ["mcpServers"]

jq 'keys' .vscode/mcp.json
# Should output: ["inputs", "servers"] or ["servers", "inputs"]
```

## References

- **VS Code MCP Docs**: https://code.visualstudio.com/docs/copilot/customization/mcp-servers
- **MCP Protocol Spec**: https://modelcontextprotocol.io/
- **AitherZero MCP Troubleshooting**: [./MCP-TROUBLESHOOTING.md](./MCP-TROUBLESHOOTING.md)
- **GitHub MCP Servers Registry**: https://github.com/modelcontextprotocol/servers

## Summary

- **VS Code** uses `.vscode/mcp.json` with `servers` and `inputs` keys
- **Claude Desktop** uses config with `mcpServers` key ONLY
- **`.vscode/mcp-servers.json`** is for Claude with workspace variables
- **`.github/mcp-servers.json`** is for Claude with relative paths
- **NEVER** add `$schema`, `defaultServers`, or `contextProviders` to MCP standard format files
- Run `0215_Configure-MCPServers.ps1` to create/update VS Code config
- Manually maintain the MCP standard format files for Claude Desktop

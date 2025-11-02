# Configuring AitherZero MCP Server for Remote Copilot Agents

## Problem
The AitherZero MCP server needs to start automatically when GitHub Copilot agents work on tasks, but the configuration in `.github/mcp-servers.json` and `.vscode/mcp-servers.json` only works for local IDE environments, not for remote Copilot agent sessions.

## Solution: Repository Settings Configuration

To enable automatic MCP server startup in **remote Copilot agent environments** (the GitHub Actions runners that power Copilot tasks), you must add the configuration to **Repository Settings**.

### Step 1: Copy the Configuration

The required JSON is in `.github/copilot/mcp-config.json`:

```json
{
  "aitherzero": {
    "command": "node",
    "args": [
      "mcp-server/scripts/start-with-build.mjs"
    ],
    "env": {
      "AITHERZERO_ROOT": ".",
      "AITHERZERO_NONINTERACTIVE": "1"
    }
  },
  "filesystem": {
    "command": "npx",
    "args": [
      "-y",
      "@modelcontextprotocol/server-filesystem",
      "."
    ]
  },
  "github": {
    "command": "npx",
    "args": [
      "-y",
      "@modelcontextprotocol/server-github"
    ],
    "env": {
      "GITHUB_PERSONAL_ACCESS_TOKEN": "${GITHUB_TOKEN}"
    }
  },
  "git": {
    "command": "npx",
    "args": [
      "-y",
      "@modelcontextprotocol/server-git",
      "--repository",
      "."
    ]
  },
  "powershell-docs": {
    "command": "npx",
    "args": [
      "-y",
      "@modelcontextprotocol/server-powershell-docs"
    ]
  }
}
```

**Note**: The JSON format for Repository Settings is simplified - no `$schema` property or nested `mcpServers` object. Just the server definitions directly.

### Step 2: Add to Repository Settings

1. Go to **Repository Settings** > **Copilot** > **Coding agent**
2. In the **MCP Server Configuration (JSON)** field, paste the contents of `.github/copilot/mcp-config.json`
3. Click **Save**

### Step 3: Verify

After saving, new Copilot agent tasks will automatically start multiple MCP servers:

**AitherZero MCP Server:**
```
[MCP] Starting server: aitherzero
🔨 Building AitherZero MCP Server... (first time)
✅ MCP Server built successfully
AitherZero MCP Server running on stdio
[MCP] 8 tools available: run_script, list_scripts, search_scripts, execute_playbook, 
      get_configuration, run_tests, run_quality_check, get_project_report
```

**Additional MCP Servers:**
- **filesystem**: Repository file access and manipulation
- **github**: GitHub API operations (issues, PRs, commits)
- **git**: Git operations (status, diff, log, commit)
- **powershell-docs**: PowerShell documentation and best practices

## Why This Configuration Location?

| Configuration | Purpose | Environment |
|---------------|---------|-------------|
| `.vscode/mcp-servers.json` | Local IDE setup (VS Code users) | User's local machine |
| `.github/mcp-servers.json` | Documentation/example | N/A (reference only) |
| **Repository Settings > Copilot** | **Remote agent auto-start** | **GitHub Actions runner** |

The Repository Settings configuration is what actually launches MCP servers in the ephemeral GitHub Actions runners that power Copilot agent tasks.

## Troubleshooting

If the server doesn't start after configuration:

1. **Check Repository Settings**: Verify the JSON was saved correctly
2. **Check Node.js**: The runner must have Node.js 18+ (ubuntu-latest includes it)
3. **Check PowerShell**: The runner must have PowerShell 7+ (needs explicit setup)
4. **Check Logs**: View the Copilot agent task logs for startup errors

## Auto-Build Wrapper

The `start-with-build.mjs` script automatically:
- Checks if the server is built (`mcp-server/dist/` exists)
- Runs `npm install` if `node_modules` is missing
- Runs `npm run build` if `dist/` is missing
- Starts the MCP server

This ensures the server works even on fresh clones without manual build steps.

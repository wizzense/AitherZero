# Dev Container Troubleshooting and Fixes

## Issues Identified and Resolved

### Issue 1: VS Code Hanging on Dev Container Launch

**Root Cause:**

- Complex MCP server configurations trying to start multiple Node.js processes during container initialization
- Docker-in-Docker feature causing resource conflicts
- Too many VS Code extensions loading simultaneously
- PowerShell module installation blocking container startup

**Solutions Applied:**

1. **Simplified Dev Container Configuration** (`.devcontainer/devcontainer.json`):
   - Removed Docker-in-Docker feature (potential resource conflict)
   - Reduced extension list to essential only
   - Improved error handling in postCreateCommand
   - Added init process and proper environment variables
   - Split commands into onCreateCommand, postCreateCommand, and postStartCommand

2. **Simplified VS Code Settings** (`.vscode/settings.json`):
   - Removed complex MCP server configurations that caused startup delays
   - Updated profile paths to reflect new library/automation-scripts location
   - Kept essential PowerShell and Copilot settings only

3. **Disabled MCP Servers** (`.vscode/mcp-servers.json`):
   - Temporarily disabled all MCP servers to eliminate startup conflicts
   - Can be re-enabled after container stability is confirmed

### Key Changes Made

#### .devcontainer/devcontainer.json

```json
{
  "name": "AitherZero Development",
  "image": "mcr.microsoft.com/devcontainers/base:ubuntu",

  "features": {
    "ghcr.io/devcontainers/features/powershell:1": { "version": "7.4" },
    "ghcr.io/devcontainers/features/git:1": { "version": "latest" },
    "ghcr.io/devcontainers/features/github-cli:1": { "version": "latest" },
    "ghcr.io/devcontainers/features/node:1": { "version": "20" }
  }
}
```

#### Extensions Reduced From 10 to 6

- Removed: DavidAnson.vscode-markdownlint, eamodio.gitlens, ms-vscode.vscode-typescript-next, streetsidesoftware.code-spell-checker
- Kept: ms-vscode.powershell, GitHub.copilot, GitHub.copilot-chat, redhat.vscode-yaml, ms-azuretools.vscode-docker, GitHub.vscode-pull-request-github

#### Error Handling Improved

```bash
pwsh -Command 'try { Install-Module -Name Pester -Force -SkipPublisherCheck -Scope CurrentUser -ErrorAction Stop; Install-Module -Name PSScriptAnalyzer -Force -SkipPublisherCheck -Scope CurrentUser -ErrorAction Stop; Write-Host "PowerShell modules installed successfully" } catch { Write-Warning "Failed to install PowerShell modules: $_"; exit 0 }'
```

### Testing Instructions

1. **Close VS Code completely**
2. **Reopen the AitherZero workspace**
3. **When prompted, select "Reopen in Container"**
4. **Monitor container build process** (should complete in 2-3 minutes instead of hanging)
5. **Verify PowerShell works**: Open terminal and run `pwsh`
6. **Test basic functionality**: Run `./library/automation-scripts/0407_Validate-Syntax.ps1`

### Re-enabling MCP Servers (After Container Stability)

Once the container launches successfully, you can gradually re-enable MCP servers:

1. **Test with one server first**:

```json
{
  "mcpServers": {
    "filesystem": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem", "${workspaceFolder}"]
    }
  }
}
```

2. **If stable, add others one by one**
3. **Monitor VS Code responsiveness after each addition**

### Rollback Plan

If issues persist:

1. **Use local development** instead of containers
2. **Restore original configurations** from git history
3. **Check container logs**: `docker logs <container_id>`
4. **Report specific error messages** for further troubleshooting

### Performance Expectations

- **Container build**: 2-3 minutes (previously hanging indefinitely)
- **VS Code startup**: 30-60 seconds (previously hanging)
- **PowerShell module loading**: 10-15 seconds (improved error handling)
- **Extension activation**: 15-30 seconds (reduced extension count)

## Next Steps

1. **Test the fixed configuration**
2. **Gradually re-enable features as needed**
3. **Monitor container resource usage**
4. **Document any remaining issues**

## Emergency Fallback

If container still hangs, use local development:

```bash
cd c:\Users\alexa\AitherZero
./bootstrap.ps1 -Mode Update -InstallProfile Minimal
./Start-AitherZero.ps1
```

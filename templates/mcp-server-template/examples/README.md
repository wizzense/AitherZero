# Configuration Examples

This directory contains example configurations for integrating your MCP server with various AI assistants.

## Claude Desktop

**File**: `claude-config.json`

**Location**: 
- macOS: `~/Library/Application Support/Claude/claude_desktop_config.json`
- Windows: `%APPDATA%/Claude/claude_desktop_config.json`
- Linux: `~/.config/Claude/claude_desktop_config.json`

**Steps**:
1. Copy the example configuration
2. Replace `SERVERNAME` with your actual server name
3. Update paths to absolute paths
4. Add any additional environment variables your server needs
5. Restart Claude Desktop

## VS Code / GitHub Copilot

**File**: `copilot-config.json`

**Location**: `.github/mcp-servers.json` or `.vscode/settings.json` in your project

**Steps**:
1. Copy the example configuration
2. Replace `SERVERNAME` and `DESCRIPTION` with your values
3. Use `${workspaceFolder}` variable for relative paths
4. Add to your project's configuration file
5. Reload VS Code

## Environment Variables

Common environment variables you might need:

- `SERVERNAME_ROOT` - Root directory of your server/project
- `DEBUG` - Enable debug logging (0 or 1)
- `API_KEY` - API key for external services
- `DATABASE_URL` - Database connection string
- `TIMEOUT` - Command timeout in milliseconds

## Testing Configuration

Test your configuration manually:

```bash
# Test that the server starts
node scripts/start-with-build.mjs

# Test JSON-RPC communication
echo '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}' | node dist/index.js
```

## Troubleshooting

### Server Not Found

- Verify paths are absolute (Claude) or use `${workspaceFolder}` (VS Code)
- Check file permissions on the server directory
- Ensure Node.js is in PATH

### Server Starts But No Tools Visible

- Check JSON syntax is valid
- Verify server is built (`dist/index.js` exists)
- Check AI assistant logs for errors
- Restart the AI assistant application

### Environment Variables Not Working

- Verify variable names match what your server expects
- Check that variables are accessible in the server process
- Use `console.error()` in your server to debug values

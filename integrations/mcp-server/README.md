# AitherZero MCP Server

A Model Context Protocol (MCP) server that exposes AitherZero's infrastructure automation capabilities to AI assistants like Claude, GitHub Copilot, and other MCP-compatible clients.

## Overview

This MCP server allows AI assistants to:
- Execute automation scripts (0000-9999 number-based system)
- Run infrastructure deployments
- Manage virtual machines
- Execute playbooks and orchestration sequences
- Run tests and quality checks
- Query configuration and project status

## Features

### Tools

The server exposes the following tools:

- **`run_script`**: Execute any AitherZero automation script by number
- **`list_scripts`**: Get a list of all available automation scripts
- **`search_scripts`**: Search scripts by keyword
- **`execute_playbook`**: Run predefined playbook sequences
- **`get_configuration`**: Retrieve configuration values
- **`run_tests`**: Execute Pester tests
- **`run_quality_check`**: Run PSScriptAnalyzer and quality validation
- **`get_project_report`**: Generate comprehensive project metrics

### Resources

The server provides the following resources:

- **`aitherzero://config`**: Current configuration (JSON)
- **`aitherzero://scripts`**: List of automation scripts
- **`aitherzero://project-report`**: Project status and metrics

## Installation

### Prerequisites

- Node.js 18 or higher
- PowerShell 7.0 or higher
- AitherZero installed (via bootstrap script)

### Build the Server

```bash
cd mcp-server
npm install
npm run build
```

### Global Installation

```bash
npm install -g .
```

## Usage

### With Claude Desktop

Add to your Claude Desktop configuration (`~/Library/Application Support/Claude/claude_desktop_config.json` on macOS):

```json
{
  "mcpServers": {
    "aitherzero": {
      "command": "node",
      "args": [
        "/path/to/AitherZero/mcp-server/dist/index.js"
      ],
      "env": {
        "AITHERZERO_ROOT": "/path/to/AitherZero"
      }
    }
  }
}
```

### With VS Code / GitHub Copilot

Add to `.github/mcp-servers.json`:

```json
{
  "mcpServers": {
    "aitherzero": {
      "command": "node",
      "args": [
        "${workspaceFolder}/mcp-server/dist/index.js"
      ],
      "description": "AitherZero infrastructure automation platform",
      "capabilities": {
        "resources": true,
        "tools": true
      },
      "env": {
        "AITHERZERO_ROOT": "${workspaceFolder}"
      }
    }
  }
}
```

### With Other MCP Clients

The server uses stdio transport and follows the MCP specification, so it should work with any MCP-compatible client.

## Example Interactions

Once connected, you can ask your AI assistant to:

```
"List all available AitherZero automation scripts"
→ Uses: list_scripts tool

"Search for Docker-related scripts"
→ Uses: search_scripts with query="docker"

"Run the test suite"
→ Uses: run_script with scriptNumber="0402"

"Execute the quick test playbook"
→ Uses: execute_playbook with playbookName="test-quick"

"What's in the AitherZero configuration?"
→ Uses: get_configuration tool or aitherzero://config resource

"Run quality checks on the utilities domain"
→ Uses: run_quality_check with path="./aithercore/utilities"

"Show me the project report"
→ Uses: get_project_report tool or aitherzero://project-report resource
```

## Development

### Build and Watch

```bash
npm run watch
```

### Testing the Server

You can test the server manually using stdio:

```bash
npm run build
echo '{"jsonrpc":"2.0","id":1,"method":"tools/list"}' | node dist/index.js
```

## Architecture

```
┌─────────────────┐
│   AI Assistant  │
│  (Claude, etc)  │
└────────┬────────┘
         │ MCP Protocol (stdio)
         │
┌────────▼────────┐
│  MCP Server     │
│  (TypeScript)   │
└────────┬────────┘
         │ PowerShell Execution
         │
┌────────▼────────┐
│   AitherZero    │
│   (PowerShell)  │
└─────────────────┘
```

The server:
1. Receives MCP requests via stdio
2. Translates them to PowerShell commands
3. Executes PowerShell scripts using `pwsh`
4. Returns results to the AI assistant

## Environment Variables

- **`AITHERZERO_ROOT`**: Path to AitherZero installation (defaults to `~/AitherZero`)
- **`AITHERZERO_DISABLE_TRANSCRIPT`**: Set to `1` to disable transcript logging

## Security Considerations

- The server executes PowerShell commands with the permissions of the user running it
- Ensure proper access controls on the AitherZero installation directory
- Review commands before allowing AI assistants to execute them
- Consider running in a sandbox or container for untrusted environments

## Troubleshooting

### "pwsh not found"

Ensure PowerShell 7+ is installed and in your PATH:
```bash
pwsh --version
```

### "AITHERZERO_ROOT not set"

Set the environment variable to your AitherZero installation:
```bash
export AITHERZERO_ROOT="/path/to/AitherZero"
```

### "Module not found"

Ensure AitherZero is properly initialized:
```bash
cd $AITHERZERO_ROOT
./Initialize-AitherEnvironment.ps1
```

## Contributing

Contributions are welcome! To add new tools or resources:

1. Add the tool/resource definition in `src/index.ts`
2. Implement the handler function
3. Update this README
4. Run tests and build
5. Submit a pull request

## License

MIT License - see LICENSE file for details.

## Related Documentation

- [Model Context Protocol Specification](https://modelcontextprotocol.io/)
- [AitherZero Documentation](../docs/)
- [MCP Server Examples](https://github.com/modelcontextprotocol/servers)

# AitherZero as an MCP Server

This document explains how to use AitherZero as a Model Context Protocol (MCP) server, allowing AI assistants to interact with AitherZero's infrastructure automation capabilities.

## What is This?

AitherZero can now act as an **MCP server**, exposing its powerful automation capabilities to AI assistants like Claude, GitHub Copilot, and any other MCP-compatible client.

This is different from the existing MCP client configuration (`.github/mcp-servers.json`), which allows AitherZero developers to use external MCP servers. Now AitherZero itself becomes a server that others can use.

## Architecture

```
┌──────────────────────────────────────────────────────┐
│                   AI Assistant                       │
│            (Claude Desktop, VS Code, etc)            │
└──────────────────┬───────────────────────────────────┘
                   │
                   │ MCP Protocol (stdio)
                   │
┌──────────────────▼───────────────────────────────────┐
│              AitherZero MCP Server                   │
│                  (TypeScript/Node.js)                │
│                                                       │
│  • Receives MCP requests                             │
│  • Translates to PowerShell commands                 │
│  • Returns structured responses                      │
└──────────────────┬───────────────────────────────────┘
                   │
                   │ PowerShell Execution
                   │
┌──────────────────▼───────────────────────────────────┐
│                  AitherZero Platform                 │
│                   (PowerShell 7+)                    │
│                                                       │
│  • 200+ automation scripts (0000-9999)               │
│  • Infrastructure management                         │
│  • VM provisioning                                   │
│  • Testing & quality validation                      │
│  • Configuration management                          │
└──────────────────────────────────────────────────────┘
```

## Capabilities Exposed

### Tools (Actions AI can perform)

| Tool | Description | Example Use |
|------|-------------|-------------|
| `run_script` | Execute any numbered automation script | "Run script 0402 to execute tests" |
| `list_scripts` | Get all available scripts | "Show me all available automation scripts" |
| `search_scripts` | Find scripts by keyword | "Search for Docker-related scripts" |
| `execute_playbook` | Run playbook sequences | "Execute the quick-test playbook" |
| `get_configuration` | Retrieve config values | "What's the current testing profile?" |
| `run_tests` | Execute Pester tests | "Run all unit tests" |
| `run_quality_check` | Validate code quality | "Check the utilities domain for issues" |
| `get_project_report` | Generate metrics report | "Show me the project status" |

### Resources (Information AI can query)

| Resource | Description |
|----------|-------------|
| `aitherzero://config` | Current configuration (JSON format) |
| `aitherzero://scripts` | List of all automation scripts |
| `aitherzero://project-report` | Comprehensive project metrics |

## Quick Start

### Prerequisites

1. **Node.js 18+**: Required for running the MCP server
2. **PowerShell 7+**: Required for AitherZero execution
3. **AitherZero installed**: Via bootstrap script or git clone

### Setup

1. **Build the MCP server**:
   ```bash
   cd mcp-server
   npm install
   npm run build
   ```

2. **Configure your AI assistant** (see sections below)

3. **Start using AitherZero through AI**!

## Configuration Examples

### Claude Desktop

Edit `~/Library/Application Support/Claude/claude_desktop_config.json` (macOS) or equivalent:

```json
{
  "mcpServers": {
    "aitherzero": {
      "command": "node",
      "args": [
        "/Users/yourname/AitherZero/integrations/mcp-server/dist/index.js"
      ],
      "env": {
        "AITHERZERO_ROOT": "/Users/yourname/AitherZero"
      }
    }
  }
}
```

**Windows**: `%APPDATA%/Claude/claude_desktop_config.json`
**Linux**: `~/.config/Claude/claude_desktop_config.json`

### GitHub Copilot / VS Code

Add to your workspace's `.vscode/mcp-servers.json`:

```json
{
  "mcpServers": {
    "aitherzero": {
      "command": "node",
      "args": [
        "${workspaceFolder}/integrations/mcp-server/dist/index.js"
      ],
      "description": "AitherZero infrastructure automation",
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

### Generic MCP Client

For any MCP-compatible client that supports stdio transport:

```json
{
  "command": "node",
  "args": ["/path/to/AitherZero/integrations/mcp-server/dist/index.js"],
  "env": {
    "AITHERZERO_ROOT": "/path/to/AitherZero"
  }
}
```

## Example Conversations

Once configured, you can interact with AitherZero through natural language:

### Example 1: Running Tests
```
You: "Run the AitherZero test suite"
AI: [Uses run_tests tool]
    "The test suite executed successfully:
     - 45 tests passed
     - 0 tests failed
     - Test coverage: 87%"
```

### Example 2: Infrastructure Management
```
You: "What infrastructure scripts are available?"
AI: [Uses search_scripts with query="infrastructure"]
    "Found 12 infrastructure scripts:
     - 0100: Configure System
     - 0104: Install Certificate Authority
     - 0105: Install Hyper-V
     ..."
```

### Example 3: Quality Checks
```
You: "Check the code quality of the testing domain"
AI: [Uses run_quality_check with path="./domains/testing"]
    "Quality validation complete:
     - PSScriptAnalyzer: 0 errors, 2 warnings
     - Error handling: Compliant
     - Logging: Compliant
     - Test coverage: 89%"
```

### Example 4: Configuration Queries
```
You: "What's the current AitherZero configuration?"
AI: [Uses get_configuration tool or aitherzero://config resource]
    "Current configuration:
     - Profile: Developer
     - Testing Profile: Standard
     - Max Concurrency: 4
     - AITHERZERO_ROOT: /home/user/AitherZero"
```

## Advanced Usage

### Custom Script Execution

AI assistants can execute scripts with parameters:

```
You: "Run script 0420 to validate the utilities domain recursively"
AI: [Uses run_script with scriptNumber="0420", params={Path: "./domains/utilities", Recursive: true}]
```

### Playbook Execution

Execute complex workflows:

```
You: "Run the full test suite with the CI profile"
AI: [Uses execute_playbook with playbookName="test-full", profile="ci"]
```

### Resource Queries

Direct access to structured data:

```
You: "Show me the project report"
AI: [Reads aitherzero://project-report resource]
```

## Script Number Reference

For AI assistants (and users) to reference:

| Range | Category | Examples |
|-------|----------|----------|
| 0000-0099 | Environment Setup | 0000: Cleanup, 0001: Ensure PowerShell 7 |
| 0100-0199 | Infrastructure | 0104: Certificate Authority, 0105: Hyper-V |
| 0200-0299 | Development Tools | 0201: Install Node, 0207: Install Git |
| 0400-0499 | Testing & Validation | 0402: Run Tests, 0404: PSScriptAnalyzer |
| 0500-0599 | Reporting & Metrics | 0510: Project Report |
| 0700-0799 | Git & AI Automation | 0701: Create Branch, 0702: Commit |
| 9000-9999 | Maintenance & Cleanup | Cleanup operations |

## Available Playbooks

| Playbook | Description | Profile Options |
|----------|-------------|-----------------|
| `test-quick` | Fast validation checks | quick, standard |
| `test-full` | Complete test suite | standard, full, ci |
| `setup-minimal` | Minimal environment setup | minimal |
| `setup-dev` | Full development setup | standard, full |

## Security Considerations

### Permissions

The MCP server executes PowerShell with the permissions of the user running it. Ensure:
- Proper access controls on the AitherZero directory
- Review AI assistant requests before execution
- Use read-only mode when possible

### Isolation

Consider running the MCP server in:
- A dedicated user account
- A container or VM
- With restricted file system access

### Audit Trail

All operations are logged:
- PowerShell transcript logs: `logs/transcript-*.log`
- MCP server logs: stderr output
- Script execution logs: Individual script outputs

## Troubleshooting

### Server Not Starting

**Issue**: MCP server fails to start
**Solution**:
```bash
cd mcp-server
npm run build
node dist/index.js
# Check for errors in output
```

### PowerShell Not Found

**Issue**: "pwsh: command not found"
**Solution**:
```bash
# Verify PowerShell installation
pwsh --version

# Add to PATH if needed (example)
export PATH="$PATH:/usr/local/bin"
```

### Module Import Errors

**Issue**: "Module AitherZero not found"
**Solution**:
```bash
cd $AITHERZERO_ROOT
./Initialize-AitherEnvironment.ps1
# Verify module loads
pwsh -Command "Import-Module ./AitherZero.psd1; Get-Module AitherZero"
```

### Permission Denied

**Issue**: Scripts fail with permission errors
**Solution**:
- Check file permissions: `ls -la library/automation-scripts/`
- Set execute permissions: `chmod +x library/automation-scripts/*.ps1`
- Verify AITHERZERO_ROOT is correct

### AI Assistant Not Seeing Server

**Issue**: Claude/Copilot doesn't show AitherZero capabilities
**Solution**:
1. Verify configuration file syntax (use JSON validator)
2. Check file paths are absolute
3. Restart the AI assistant application
4. Check application logs for MCP errors

## Development

### Adding New Tools

To add new capabilities:

1. **Define the tool** in `src/index.ts`:
   ```typescript
   {
     name: 'my_new_tool',
     description: 'What it does',
     inputSchema: { /* ... */ }
   }
   ```

2. **Implement the handler**:
   ```typescript
   case 'my_new_tool':
     result = await myNewFunction(args.param);
     break;
   ```

3. **Create the function**:
   ```typescript
   async function myNewFunction(param: string): Promise<string> {
     // Implementation
   }
   ```

4. **Rebuild**: `npm run build`

### Adding New Resources

Similar process for resources:

1. Add to `ListResourcesRequestSchema` handler
2. Add to `ReadResourceRequestSchema` handler
3. Implement data retrieval function

### Testing

Manual testing with stdio:

```bash
# List tools
echo '{"jsonrpc":"2.0","id":1,"method":"tools/list"}' | node dist/index.js

# Call a tool
echo '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"list_scripts","arguments":{}}}' | node dist/index.js
```

## Performance Considerations

### Caching

Consider implementing caching for:
- Script listings (rarely change)
- Configuration values (change infrequently)
- Project metadata

### Concurrency

The server currently executes PowerShell sequentially. For production use, consider:
- Request queuing
- Parallel execution for independent operations
- Timeout handling

### Resource Usage

Monitor:
- Memory usage (PowerShell processes)
- CPU usage (script execution)
- Disk I/O (logging, artifacts)

## Comparison: MCP Client vs MCP Server

AitherZero now has both:

| Feature | MCP Client | MCP Server |
|---------|------------|------------|
| **What it is** | AitherZero uses external MCP servers | AitherZero provides MCP server |
| **Direction** | Consumes services | Provides services |
| **Config** | `.github/mcp-servers.json` | Client's config file |
| **Purpose** | Enhance AitherZero development | Let AI assistants use AitherZero |
| **Users** | AitherZero developers | Anyone with AI assistant |

## Future Enhancements

Potential additions:
- [ ] Streaming support for long-running operations
- [ ] Webhooks for async operation completion
- [ ] Authentication and authorization
- [ ] Multi-user support
- [ ] Request caching and optimization
- [ ] GraphQL-style query capabilities
- [ ] Prometheus metrics endpoint
- [ ] REST API wrapper alongside MCP

## Contributing

To contribute to the MCP server:

1. Fork the repository
2. Create a feature branch
3. Make changes to `mcp-server/`
4. Add tests
5. Update documentation
6. Submit pull request

## References

- [Model Context Protocol Specification](https://modelcontextprotocol.io/)
- [MCP SDK Documentation](https://github.com/modelcontextprotocol/sdk)
- [AitherZero Main Documentation](../docs/)
- [PowerShell 7 Documentation](https://docs.microsoft.com/powershell/)

## Support

For issues or questions:
- GitHub Issues: [AitherZero Issues](https://github.com/wizzense/AitherZero/issues)
- Discussions: [GitHub Discussions](https://github.com/wizzense/AitherZero/discussions)
- Documentation: `docs/` directory

## License

MIT License - same as AitherZero main project.

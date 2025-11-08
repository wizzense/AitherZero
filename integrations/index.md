# Integrations

This directory contains external integrations for AitherZero, allowing it to interact with various tools, services, and platforms.

## Directory Structure

```
integrations/
├── mcp-server/          # Model Context Protocol server for AI assistant integration
└── index.md             # This file
```

## Current Integrations

### MCP Server

The **Model Context Protocol (MCP) Server** enables AI assistants (like GitHub Copilot, Claude Desktop, and others) to interact with AitherZero functionality.

- **Location**: `integrations/mcp-server/`
- **Documentation**: See [MCP Server README](mcp-server/README.md)
- **Quick Start**: See [MCP Server Quick Start](mcp-server/QUICKSTART.md)
- **Type**: Node.js/TypeScript server implementing the MCP protocol
- **Features**:
  - PowerShell script execution
  - Configuration management
  - Project analysis and reporting
  - Infrastructure automation
  - Testing and quality tools

**Related Scripts:**
- `0750_Build-MCPServer.ps1` - Build the MCP server
- `0751_Start-MCPServer.ps1` - Start the MCP server
- `0752_Demo-MCPServer.ps1` - Demo MCP server capabilities
- `0753_Use-MCPServer.ps1` - Instructions for using the MCP server
- `0754_Create-MCPServer.ps1` - Create a new MCP server from template

**Configuration:**
- VS Code: `.vscode/mcp-servers.json`
- Claude Desktop: See [COPILOT-MCP-SETUP.md](../docs/COPILOT-MCP-SETUP.md)

## Future Integrations

This directory is designed to house additional integrations as they are developed:

- **Cloud Providers**: AWS, Azure, GCP integration modules
- **Container Orchestration**: Kubernetes, Docker Swarm integrations
- **CI/CD Platforms**: Jenkins, GitLab CI, CircleCI integrations
- **Monitoring Tools**: Prometheus, Grafana, DataDog integrations
- **Communication**: Slack, Teams, Discord notification integrations
- **Version Control**: Extended Git integrations beyond core functionality

## Adding New Integrations

When adding a new integration to this directory:

1. **Create a subdirectory** with a descriptive name (e.g., `integrations/slack-notifier/`)
2. **Add documentation**:
   - `README.md` - Overview and usage instructions
   - `QUICKSTART.md` - Quick start guide (if applicable)
   - `index.md` - Integration metadata and links
3. **Follow naming conventions**:
   - Use lowercase with hyphens (e.g., `azure-integration`)
   - Keep names concise but descriptive
4. **Update this index** to document the new integration
5. **Create automation scripts** in the appropriate range (typically 0200-0299 for tool setup)
6. **Add tests** in `tests/integration/` for the new integration

## Documentation

For more information about integrations:

- [MCP Configuration Files](../docs/MCP-CONFIGURATION-FILES.md)
- [Copilot MCP Setup](../docs/COPILOT-MCP-SETUP.md)
- [MCP Troubleshooting](../docs/MCP-TROUBLESHOOTING.md)
- [Integration Testing Guide](../docs/INTEGRATION-TESTING-GUIDE.md)

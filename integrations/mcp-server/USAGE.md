# AitherZero MCP Server - Complete Usage Guide

## Quick Start

### Installation
```bash
cd integrations/mcp-server
npm install
npm run build
```

### Configuration

**For GitHub Copilot (VS Code):** Already configured in `.github/mcp-servers.json`

**For Claude Desktop:**
```json
{
  "mcpServers": {
    "aitherzero": {
      "command": "node",
      "args": ["/path/to/AitherZero/integrations/mcp-server/dist/index.js"],
      "env": {
        "AITHERZERO_ROOT": "/path/to/AitherZero"
      }
    }
  }
}
```

## Available Tools (14 total)

### Script Execution
1. **run_script** - Execute automation script by number
2. **list_scripts** - List available scripts (optional category filter)
3. **search_scripts** - Search scripts by keyword

### Orchestration
4. **list_playbooks** - List available playbooks
5. **execute_playbook** - Run playbook sequence

### Configuration & Status
6. **get_configuration** - Retrieve config values
7. **get_domain_info** - Get aithercore domain information
8. **get_workflow_status** - GitHub Actions status

### Quality & Testing
9. **run_tests** - Execute Pester tests
10. **run_quality_check** - PSScriptAnalyzer validation
11. **get_project_report** - Comprehensive metrics

### Extensions & Documentation
12. **list_extensions** - Show installed extensions
13. **generate_documentation** - Create/update docs

## Resources (5 total)

- `aitherzero://config` - Configuration manifest
- `aitherzero://scripts` - Script inventory
- `aitherzero://playbooks` - Playbook list
- `aitherzero://domains` - Domain structure
- `aitherzero://project-report` - Health metrics

## Prompts (4 total)

1. **setup-dev-environment** - Guided development setup
2. **validate-code-quality** - Quality validation workflow
3. **create-pr** - PR creation workflow
4. **troubleshoot-ci** - CI/CD troubleshooting

## Example Usage

### With GitHub Copilot
```
@copilot Run all unit tests using AitherZero MCP
@copilot Search for Docker scripts
@copilot Execute the code-quality-full playbook
@copilot Use setup-dev-environment prompt with standard profile
```

### Direct API
```bash
echo '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"list_scripts"}}' | node dist/index.js
```

## Troubleshooting

**Server not starting:**
- Check Node.js version (18+)
- Ensure TypeScript compiled: `npm run build`

**PowerShell errors:**
- Verify PowerShell 7+ installed
- Check AITHERZERO_ROOT environment variable
- Run `./bootstrap.ps1 -Mode Update`

**Function not found:**
- Ensure AitherZero v2.0+
- Import module: `Import-Module ./AitherZero.psd1`

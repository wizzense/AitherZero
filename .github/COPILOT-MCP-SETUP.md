# GitHub Copilot MCP Server Setup

This document explains how GitHub Copilot is configured to use the AitherZero MCP Server v2.0 for infrastructure automation with agent mode.

## Overview

The AitherZero MCP (Model Context Protocol) server v2.0 is automatically loaded when Copilot starts in this workspace. It provides **14 powerful tools, 5 resources, and 4 guided prompts** for infrastructure automation:

### Tools (14 total)

**Script Execution:**
1. **`run_script`** - Execute 880+ automation scripts (0000-9999)
2. **`list_scripts`** - List available scripts with category filter
3. **`search_scripts`** - Search by keyword

**Orchestration:**
4. **`list_playbooks`** - List orchestration playbooks
5. **`execute_playbook`** - Run multi-script workflows

**Configuration & Status:**
6. **`get_configuration`** - Retrieve config.psd1 values (by section/key)
7. **`get_domain_info`** - Get aithercore domain information
8. **`get_workflow_status`** - GitHub Actions workflow status

**Quality & Testing:**
9. **`run_tests`** - Execute Pester tests (with tag filter)
10. **`run_quality_check`** - PSScriptAnalyzer validation
11. **`get_project_report`** - Comprehensive project metrics

**Extensions & Documentation:**
12. **`list_extensions`** - Show installed extensions
13. **`generate_documentation`** - Create/update documentation

### Resources (5 total)

Resources provide extended context for agent mode:

- **`aitherzero://config`** - Complete configuration manifest (JSON)
- **`aitherzero://scripts`** - 880+ automation script inventory
- **`aitherzero://playbooks`** - Orchestration playbook list
- **`aitherzero://domains`** - 11 aithercore domain structure
- **`aitherzero://project-report`** - Project health metrics

### Prompts (4 total)

Guided workflows for multi-step operations:

- **`setup-dev-environment`** - Complete development environment setup
- **`validate-code-quality`** - Step-by-step quality validation
- **`create-pr`** - Pull request creation workflow
- **`troubleshoot-ci`** - CI/CD failure diagnosis

## Configuration

The MCP server is configured in `.github/mcp-servers.json` (repository-level):

```json
{
  "mcpServers": {
    "aitherzero": {
      "command": "node",
      "args": ["${workspaceFolder}/integrations/mcp-server/dist/index.js"],
      "description": "AitherZero infrastructure automation - 14 tools, 5 resources, 4 prompts",
      "capabilities": {
        "resources": true,
        "tools": true,
        "prompts": true
      },
      "env": {
        "AITHERZERO_ROOT": "${workspaceFolder}",
        "AITHERZERO_NONINTERACTIVE": "1"
      }
    }
  },
  "defaultServers": ["aitherzero", "filesystem", "github", "git"]
}
```

## First-Time Setup

When you open this workspace, Copilot will automatically:

1. Detect the MCP server configuration
2. Build the server if needed: `cd integrations/mcp-server && npm install && npm run build`
3. Start the server on stdio
4. Make all 14 tools, 5 resources, and 4 prompts available

### Manual Build (if needed)

```bash
cd integrations/mcp-server
npm install
npm run build
```

Or use the automation script:

```bash
pwsh -NoProfile -Command "Import-Module ./AitherZero.psd1; Invoke-AitherScript -ScriptNumber 0010"
```

## How Copilot Uses the MCP Server v2.0

When you ask Copilot to perform infrastructure tasks in agent mode, it will:

### Example 1: Running Tests
**You ask**: "Run all unit tests"

**Copilot executes**:
```json
{
  "tool": "run_script",
  "arguments": {
    "scriptNumber": "0402"
  }
}
```

### Example 2: Searching Scripts
**You ask**: "What scripts are available for Docker?"

**Copilot executes**:
```json
{
  "tool": "search_scripts",
  "arguments": {
    "query": "docker"
  }
}
```

### Example 3: Running Playbooks
**You ask**: "Execute the code quality validation playbook"

**Copilot executes**:
```json
{
  "tool": "execute_playbook",
  "arguments": {
    "playbookName": "code-quality-full",
    "profile": "full"
  }
}
```

### Example 4: Quality Checks
**You ask**: "Run quality checks on the configuration domain"

**Copilot executes**:
```json
{
  "tool": "run_quality_check",
  "arguments": {
    "path": "./aithercore/configuration"
  }
}
```

### Example 5: Using Prompts (NEW in v2.0)
**You ask**: "Help me set up my development environment"

**Copilot executes**:
```json
{
  "prompt": "setup-dev-environment",
  "arguments": {
    "profile": "standard"
  }
}
```

This starts a guided multi-step workflow that:
1. Checks prerequisites (PowerShell 7+, Git, Node.js)
2. Runs bootstrap script
3. Installs development tools
4. Configures Git and GitHub CLI
5. Sets up MCP servers
6. Validates installation

### Example 6: Accessing Resources (NEW in v2.0)
**You ask**: "Show me the list of available playbooks"

**Copilot reads resource**:
```
aitherzero://playbooks
```

Returns structured list of all playbooks with descriptions.

## Verifying MCP Server is Active

When Copilot starts, you should see in the MCP output:

```
[MCP] Starting server: aitherzero
[MCP] AitherZero MCP Server v2.0 running on stdio
[MCP] 14 tools, 5 resources, 4 prompts available
[MCP] Server ready: aitherzero
```

You can also test manually:

```bash
cd integrations/mcp-server
echo '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}' | node dist/index.js
```

## Available Resources (v2.0)

The MCP server exposes 5 resources for extended context:

- **`aitherzero://config`** - Complete configuration manifest from config.psd1 (JSON)
- **`aitherzero://scripts`** - Inventory of 880+ automation scripts from library/
- **`aitherzero://playbooks`** - Available orchestration playbooks
- **`aitherzero://domains`** - Information about 11 aithercore functional domains
- **`aitherzero://project-report`** - Comprehensive project status and health metrics

Copilot can read these resources directly without executing commands, providing rich context for decision-making.

## Automation Scripts Reference

The MCP server can execute any of the 880+ automation scripts from `library/automation-scripts/`:

### Common Scripts
- **0402** - Run unit tests (with optional path and tag filters)
- **0404** - Run PSScriptAnalyzer (code quality linting)
- **0407** - Validate PowerShell syntax
- **0510** - Generate comprehensive project report
- **0530** - Generate documentation
- **0701** - Create Git branch
- **0702** - Commit changes with conventional format
- **0703** - Create pull request
- **0010** - Setup MCP servers

### Script Ranges
- **0000-0099** - Environment preparation (PowerShell 7, directories, MCP setup)
- **0100-0199** - Infrastructure (Hyper-V, certificates, networking)
- **0200-0299** - Development tools (Git, Node, Docker, VS Code, Python)
- **0400-0499** - Testing & validation (Pester, PSScriptAnalyzer, quality checks)
- **0500-0599** - Reporting & metrics (project reports, documentation)
- **0700-0799** - Git automation & AI tools (branches, commits, PRs)
- **0800-0899** - Issue management (GitHub issues, labels)
- **8000-8999** - Extensions (custom extensions via extension system)
- **9000-9999** - Maintenance & cleanup

## Playbooks Reference

The MCP server can execute these orchestrated playbooks from `library/playbooks/`:

### Testing Playbooks
- **code-quality-fast** - Quick quality validation (syntax + PSScriptAnalyzer)
- **code-quality-full** - Complete quality workflow (syntax + linting + tests)
- **comprehensive-validation** - Full validation suite with coverage
- **pr-validation** - PR validation checks
- **integration-tests-full** - Full integration test suite

### Setup Playbooks
- **dev-environment-setup** - Complete development environment
- **aitherium-org-setup** - Organization-level setup

### Diagnostic Playbooks
- **diagnose-ci** - CI/CD failure diagnosis
- **fix-ci-validation** - Fix common CI issues
- **project-health-check** - System health analysis

### Documentation Playbooks
- **generate-documentation** - Create documentation
- **generate-indexes** - Update index files

Use `list_playbooks` tool to see all available playbooks with descriptions.

## Troubleshooting

### Server Not Starting

**Check Node.js**:
```bash
node --version  # Should be 18+
```

**Check PowerShell**:
```bash
pwsh --version  # Should be 7.0+
```

**Rebuild Server**:
```bash
cd integrations/mcp-server
rm -rf node_modules dist
npm install
npm run build
```

### Tools Not Available

Check Copilot MCP output panel:
1. Open Command Palette (Ctrl+Shift+P)
2. Type "MCP: Show Output"
3. Look for "aitherzero" server status
4. Verify "14 tools, 5 resources, 4 prompts available" message

### Server Crashes

Check logs in `logs/transcript-*.log` for PowerShell execution errors.

**Common issues:**
- **Function not found**: Ensure AitherZero v2.0+ with new CLI cmdlets
- **Module not loaded**: Run `./bootstrap.ps1 -Mode Update`
- **Path errors**: Check AITHERZERO_ROOT environment variable

## Security Considerations

The MCP server:
- Runs with your user permissions
- Executes PowerShell commands via `pwsh`
- Can modify files in the repository
- Requires Node.js 18+ and PowerShell 7+
- Uses non-interactive mode to prevent blocking on prompts

**Review commands before allowing Copilot to execute them** in production environments.

**Security features:**
- OAuth support for GitHub operations (via `gh` CLI)
- Minimal permissions by default
- Non-interactive mode prevents prompt-based attacks
- Execution limited to user permissions

## Best Practices for Agent Mode

When using the MCP server with GitHub Copilot agent mode:

1. **Be specific about goals**: Clearly define what you want to accomplish
2. **Provide context**: Include links to relevant files or documentation
3. **Set boundaries**: Specify constraints (e.g., "only validate, don't modify")
4. **Request confirmations**: Ask Copilot to confirm before significant changes
5. **Use prompts**: Leverage guided workflows for complex multi-step tasks
6. **Monitor activity**: Review what actions Copilot performs through the MCP server

## Development

To modify the MCP server:

1. Edit `integrations/mcp-server/src/index.ts`
2. Rebuild: `npm run build`
3. Test: `npm test`
4. Restart Copilot to reload

**Adding new tools:**
1. Define tool in `ListToolsRequestSchema` handler
2. Implement handler function
3. Add case in `CallToolRequestSchema` switch statement
4. Update documentation

**Adding new resources:**
1. Define resource in `ListResourcesRequestSchema` handler
2. Add case in `ReadResourceRequestSchema` switch statement
3. Update documentation

**Adding new prompts:**
1. Define prompt in `ListPromptsRequestSchema` handler
2. Add case in `GetPromptRequestSchema` switch statement
3. Create multi-step workflow messages

## Related Documentation

- [MCP Server README](../integrations/mcp-server/README.md)
- [MCP Server Usage Guide](../integrations/mcp-server/USAGE.md)
- [Model Context Protocol Specification](https://modelcontextprotocol.io/)
- [GitHub Copilot MCP Integration](https://docs.github.com/en/copilot/using-github-copilot/using-extensions/using-mcp-servers)
- [AitherZero Automation Scripts](../library/automation-scripts/)
- [Orchestration Playbooks](../library/playbooks/)
- [Aithercore Domains](../aithercore/README.md)

---

**Last Updated**: 2025-11-09  
**MCP Server Version**: 2.0.0  
**Copilot Integration**: Enabled by default with agent mode support

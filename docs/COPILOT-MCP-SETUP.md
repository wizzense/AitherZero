# GitHub Copilot MCP Server Configuration

This document explains the Model Context Protocol (MCP) server configuration for AitherZero, which enhances GitHub Copilot's understanding of the codebase and provides additional capabilities.

## What are MCP Servers?

Model Context Protocol (MCP) servers provide AI coding assistants like GitHub Copilot with additional context and capabilities beyond the code itself. They can:

- Access the filesystem and repository structure
- Interact with GitHub APIs
- Fetch documentation and references
- Execute Git operations
- Enable advanced reasoning for complex tasks

## Configured MCP Servers

AitherZero includes the following MCP servers in `.github/mcp-servers.json`:

### 1. Filesystem Server
**Purpose**: Provides read/write access to the repository filesystem

**Capabilities**:
- Navigate directory structure
- Read and analyze files
- Create, update, and delete files
- Search across the codebase

**Configuration**:
```json
{
  "allowedDirectories": [
    "domains", "automation-scripts", "tests", 
    "docs", "infrastructure", "orchestration"
  ],
  "readOnly": false
}
```

### 2. GitHub Server
**Purpose**: Enables GitHub API operations

**Capabilities**:
- Read issues, pull requests, and discussions
- Create and update issues
- Manage labels and milestones
- Access repository metadata
- Search code and commits

**Requirements**:
- GitHub Personal Access Token in `GITHUB_TOKEN` environment variable
- Token needs `repo` scope for full functionality

**Setup**:
```bash
# Set your GitHub token
export GITHUB_TOKEN="your_github_token_here"

# Or add to .env file (excluded from git)
echo "GITHUB_TOKEN=your_token" >> .env
```

### 3. Git Server
**Purpose**: Provides Git version control operations

**Capabilities**:
- View commit history
- Check branch status
- Show diffs and changes
- Analyze repository structure

### 4. PowerShell Documentation Server
**Purpose**: Fetches PowerShell documentation and best practices

**Capabilities**:
- Retrieve PowerShell cmdlet documentation
- Access Microsoft Learn articles
- Get PowerShell GitHub repository information

**Allowed Domains**:
- `docs.microsoft.com`
- `learn.microsoft.com`
- `github.com/PowerShell`

### 5. Sequential Thinking Server
**Purpose**: Enables detailed reasoning for complex infrastructure tasks

**Capabilities**:
- Break down complex problems
- Structured problem-solving approach
- Infrastructure design thinking
- Multi-step planning

## Using MCP Servers with GitHub Copilot

### Prerequisites

1. **VS Code with GitHub Copilot Extensions**:
   - Install `GitHub.copilot` extension
   - Install `GitHub.copilot-chat` extension

2. **Node.js**: Required for running MCP servers
   ```bash
   # Check if Node.js is installed
   node --version  # Should be v18+ or higher
   ```

3. **GitHub Token**: For GitHub API access
   ```bash
   # Create a personal access token at:
   # https://github.com/settings/tokens
   # Required scopes: repo, read:org
   
   export GITHUB_TOKEN="your_token"
   ```

### Enabling MCP Servers

MCP servers are automatically discovered by GitHub Copilot when configured in `.github/mcp-servers.json`. The configuration file follows the MCP specification.

#### Manual Activation (if needed)

If MCP servers don't activate automatically:

1. Open VS Code Command Palette (`Ctrl+Shift+P` or `Cmd+Shift+P`)
2. Search for "Copilot: Open MCP Settings"
3. Verify that `.github/mcp-servers.json` is recognized
4. Restart VS Code

### Using MCP Servers in Copilot Chat

Once configured, you can leverage MCP servers in Copilot Chat:

**Example prompts that use MCP servers**:

```
@workspace How is the infrastructure module organized?
# Uses filesystem server to analyze /domains/infrastructure/

@workspace Show me recent changes to the testing domain
# Uses git server to show commit history

@workspace Create an issue for improving error handling in LabVM.psm1
# Uses github server to create issue

@workspace What's the best practice for parameter validation in PowerShell?
# Uses powershell-docs server to fetch documentation

@workspace Help me design a complex VM deployment workflow
# Uses sequential-thinking server for structured problem-solving
```

## Context Providers

The configuration also includes context providers that help Copilot understand different parts of the codebase:

### Codebase Provider
Focuses Copilot on PowerShell modules and scripts:
- Domain modules (`domains/**/*.psm1`)
- Automation scripts (`automation-scripts/**/*.ps1`)
- Test files (`tests/**/*.Tests.ps1`)

### Documentation Provider
Provides access to project documentation:
- Documentation files (`docs/**/*.md`)
- README files (`*.md`)
- GitHub configuration (`/.github/**/*.md`)

### Configuration Provider
Exposes configuration and settings:
- Main configuration (`config.psd1`)
- Script analyzer settings
- Copilot instructions and routing

## Default Servers

By default, these servers are always active:
- `filesystem` - Core repository access
- `github` - GitHub API integration
- `git` - Version control operations

Additional servers can be activated on-demand through Copilot Chat.

## Troubleshooting

### MCP Servers Not Loading

1. **Check Node.js installation**:
   ```bash
   node --version
   npm --version
   ```

2. **Verify configuration syntax**:
   ```bash
   cat .github/mcp-servers.json | jq .
   ```

3. **Check VS Code Output**:
   - Open VS Code Output panel
   - Select "GitHub Copilot" from dropdown
   - Look for MCP-related messages

4. **Restart VS Code**:
   - Completely close and reopen VS Code
   - Reload window: `Ctrl+Shift+P` → "Reload Window"

### GitHub Server Authentication Issues

1. **Verify token is set**:
   ```bash
   echo $GITHUB_TOKEN
   ```

2. **Check token permissions**:
   - Visit https://github.com/settings/tokens
   - Ensure token has `repo` scope
   - Token should not be expired

3. **Update environment**:
   ```bash
   # Add to shell profile (~/.bashrc, ~/.zshrc)
   export GITHUB_TOKEN="your_token"
   
   # Or use .env file
   echo "GITHUB_TOKEN=your_token" >> .env
   ```

### Permission Errors

If you get permission errors with filesystem operations:

1. **Check allowed directories** in `mcp-servers.json`
2. **Verify file permissions** on the repository
3. **Ensure `readOnly` is set to `false`** for write operations

## Security Considerations

### Sensitive Data

- **Never commit tokens**: The `.env` file is excluded from git
- **Use environment variables**: Tokens should be in env vars, not config
- **Rotate tokens regularly**: Update GitHub tokens periodically

### Filesystem Access

- **Allowed directories only**: MCP servers can only access configured paths
- **Review changes**: Always review MCP-suggested file changes
- **Version control**: All changes are tracked by Git

### Network Access

- **Allowed domains**: PowerShell docs server is restricted to Microsoft and GitHub domains
- **No arbitrary URLs**: Servers cannot access random websites
- **Audit trail**: All API calls are logged

## Integration with Custom Agents

MCP servers complement the custom agent routing in `.github/copilot.yaml`:

1. **MCP Servers**: Provide context and capabilities
2. **Custom Agents**: Provide domain expertise and routing
3. **Custom Instructions**: Provide architectural guidance

Together, they create a comprehensive AI-assisted development environment:

```
User Request
     ↓
Custom Instructions (.github/copilot-instructions.md)
     ↓
Agent Router (.github/copilot.yaml) → Custom Agent
     ↓
MCP Servers (.github/mcp-servers.json) → Context
     ↓
Copilot Response with Full Context
```

## Further Reading

- [Model Context Protocol Specification](https://github.com/modelcontextprotocol/specification)
- [GitHub Copilot Documentation](https://docs.github.com/en/copilot)
- [MCP Server Examples](https://github.com/modelcontextprotocol/servers)
- [Custom Instructions Guide](https://docs.github.com/en/copilot/customizing-copilot/adding-custom-instructions-for-github-copilot)

## Getting Help

If you encounter issues with MCP servers:

1. Check the [Troubleshooting](#troubleshooting) section
2. Review VS Code Output panel for errors
3. Consult GitHub Copilot documentation
4. Open an issue in the AitherZero repository

## Contributing

To improve MCP server configuration:

1. Test changes in your development environment
2. Document any new servers or capabilities
3. Update this guide with examples
4. Submit a PR with your improvements

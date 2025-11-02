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

AitherZero configures the following MCP servers in VS Code settings. The `.github/mcp-servers.json` file serves as documentation and reference but is not automatically loaded by VS Code.

**Note**: MCP servers are configured in `.vscode/settings.json` (workspace) or user `settings.json` (global), not from `.github/mcp-servers.json`.

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
   - Install `GitHub.copilot` extension (required)
   - Install `GitHub.copilot-chat` extension (required)
   - Verify extensions are active in VS Code

2. **Node.js 18+**: Required for running MCP servers
   ```bash
   # Check if Node.js is installed
   node --version  # Should be version 18.0.0+ (outputs as "v18.0.0")
   npm --version   # Should be version 9.0.0+ (outputs as "9.0.0")
   # Note: node outputs a 'v' prefix (e.g., "v18.0.0"), npm does not.
   
   # Install Node.js if needed
   # Windows: Download from https://nodejs.org/
   # Linux: sudo apt install nodejs npm
   # macOS: brew install node
   ```

3. **PowerShell 7+**: Required for AitherZero operations
   ```bash
   # Check PowerShell version
   pwsh --version  # Should be 7.0 or higher
   
   # AitherZero requires PowerShell 7+ for cross-platform support
   ```

4. **GitHub Token**: For GitHub API access
   ```bash
   # Create a personal access token at:
   # https://github.com/settings/tokens
   # Required scopes: repo, read:org; recommended: read:project (for project boards)
   
   export GITHUB_TOKEN="your_token"
   
   # Or add to your shell profile for persistence
   echo 'export GITHUB_TOKEN="your_token"' >> ~/.bashrc  # Linux
   echo 'export GITHUB_TOKEN="your_token"' >> ~/.zshrc   # macOS
   
   # Windows PowerShell
   [Environment]::SetEnvironmentVariable("GITHUB_TOKEN", "your_token", "User")
   ```

### Enabling MCP Servers

MCP servers are configured in VS Code settings (`.vscode/settings.json` for workspace or user `settings.json` for global). AitherZero provides an automation script to set this up properly.

#### Automated Setup (Recommended)

Use the automation script to configure MCP servers:

```bash
# Configure for current workspace (recommended)
./automation-scripts/0215_Configure-MCPServers.ps1

# Or using the az wrapper
az 0215

# Configure globally for all projects
./automation-scripts/0215_Configure-MCPServers.ps1 -Scope User

# Verify configuration
./automation-scripts/0215_Configure-MCPServers.ps1 -Verify
```

The script will:

1. Check prerequisites (Node.js 18+, GITHUB_TOKEN)
2. Configure MCP servers in VS Code settings
3. Validate the configuration
4. Provide next steps

#### Manual Setup (if needed)

If MCP servers don't activate automatically:

1. Open VS Code Command Palette (`Ctrl+Shift+P` or `Cmd+Shift+P`)
2. Search for "Copilot: Open MCP Settings"
3. Verify that `.github/mcp-servers.json` is recognized
4. Restart VS Code

### Using MCP Servers in Copilot Chat

Once configured, you can leverage MCP servers in Copilot Chat. Here are AitherZero-specific examples:

#### Working with AitherZero Architecture

**Understand domain organization:**
```
@workspace How is the infrastructure module organized?
# Uses filesystem server to analyze /domains/infrastructure/

@workspace Show me all functions in the OrchestrationEngine.psm1
# Uses filesystem + code analysis

@workspace What are the dependencies between automation and testing domains?
# Uses filesystem to analyze imports and relationships
```

**Track changes and history:**
```
@workspace Show me recent changes to the testing domain
# Uses git server to show commit history

@workspace Who modified LabVM.psm1 and why?
# Uses git server with blame/log information

@workspace Compare the current OrchestrationEngine with version from last week
# Uses git server for historical comparison
```

**Issue and PR management:**
```
@workspace Create an issue for improving error handling in LabVM.psm1
# Uses github server to create issue with context

@workspace Show me open issues related to testing infrastructure
# Uses github server to search and filter issues

@workspace What PRs are waiting for review?
# Uses github server to list PR status
```

**PowerShell best practices:**
```
@workspace What's the best practice for parameter validation in PowerShell?
# Uses powershell-docs server to fetch documentation

@workspace How should I implement error handling in a PowerShell module?
# Uses powershell-docs for official guidance

@workspace What's the recommended way to handle cross-platform paths?
# Uses powershell-docs + searches Microsoft Learn
```

**Complex planning and design:**
```
@workspace Help me design a complex VM deployment workflow
# Uses sequential-thinking server for structured problem-solving

@workspace Break down the steps needed to add a new orchestration playbook
# Uses sequential-thinking for multi-step planning

@workspace Design a parallel test execution system for Pester
# Uses sequential-thinking + filesystem for architecture design
```

#### Number-Based Script Integration

**Understanding automation scripts:**
```
@workspace Explain what script 0402 does
# Uses filesystem to read and analyze the script

@workspace Show me all testing scripts (0400-0499 range)
# Uses filesystem to list and categorize

@workspace What's the difference between az 0402 and az 0407?
# Uses filesystem to compare scripts
```

**Execution context and troubleshooting:**
```
@workspace Script 0404 failed - show me recent changes
# Uses git + filesystem to diagnose

@workspace Why is az 0510 taking so long to complete?
# Uses filesystem to analyze script logic

@workspace Create a new script in the 0700-0799 range for Git automation
# Uses filesystem + sequential-thinking for guided creation
```

#### Orchestration and Playbooks

**Playbook management:**
```
@workspace Show me the structure of the test-quick playbook
# Uses filesystem to read orchestration/playbooks/

@workspace Compare test-quick and test-full playbooks
# Uses filesystem for comparison

@workspace Create a new playbook for infrastructure validation
# Uses filesystem + sequential-thinking for creation
```

**Workflow optimization:**
```
@workspace Analyze the orchestration engine for performance bottlenecks
# Uses filesystem + sequential-thinking

@workspace Suggest improvements to parallel execution in playbooks
# Uses filesystem + powershell-docs for recommendations
```

#### Testing and Quality

**Test analysis:**
```
@workspace Show me test coverage for the infrastructure domain
# Uses filesystem to analyze test files

@workspace Which modules are missing Pester tests?
# Uses filesystem to compare domains vs tests

@workspace Help me write tests for the new Security.psm1 functions
# Uses filesystem + powershell-docs for test patterns
```

**Quality checks:**
```
@workspace Run PSScriptAnalyzer rules on recent changes
# Can integrate with filesystem + git

@workspace Show me all TODO comments in the codebase
# Uses filesystem to search

@workspace Check if all public functions have comment-based help
# Uses filesystem to validate documentation
```

#### Combining Multiple Servers

**Full context analysis:**
```
@workspace Analyze OrchestrationEngine.psm1: show recent changes, 
check PowerShell best practices, and suggest improvements
# Uses: git (history) + filesystem (code) + powershell-docs (practices)

@workspace Review the testing domain: list all functions, show coverage,
check for open issues, and create a quality improvement plan
# Uses: filesystem + github + sequential-thinking

@workspace I want to refactor LabVM.psm1 for better error handling.
Show me the current code, relevant PowerShell patterns, and create
an issue to track the work
# Uses: filesystem + powershell-docs + github
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
   node --version  # v18+ required
   npm --version   # v9+ required
   ```

2. **Verify configuration syntax**:

   ```bash
   # Validate JSON syntax
   cat .github/mcp-servers.json | jq .
   
   # If jq not installed, install with:
   #   brew install jq      # macOS
   #   sudo apt install jq  # Linux
   #   choco install jq     # Windows
   ```

3. **Check VS Code Output**:
   - Open VS Code Output panel (`Ctrl+Shift+U` or `Cmd+Shift+U`)
   - Select "GitHub Copilot" from dropdown
   - Look for MCP-related messages
   - Check for connection errors or initialization failures

4. **Restart VS Code**:
   - Completely close and reopen VS Code
   - Or reload window: `Ctrl+Shift+P` → "Reload Window"
   - Ensure MCP servers initialize on startup

5. **Verify PowerShell availability**:
   ```bash
   # MCP servers need PowerShell for some operations
   pwsh --version
   
   # Should be 7.0+
   ```

### GitHub Server Authentication Issues

1. **Verify token is set**:

   ```bash
   # Linux/macOS
   echo $GITHUB_TOKEN
   
   # Windows PowerShell
   $env:GITHUB_TOKEN
   
   # Should output your token (not empty)
   ```

2. **Check token permissions**:
   - Visit https://github.com/settings/tokens
   - Ensure token has required scopes:
     - `repo` (required for private repos)
     - `read:org` (required for organization access)
     - `read:project` (recommended for project boards)
   - Token should not be expired

3. **Update environment**:

   ```bash
   # Linux - Add to shell profile
   echo 'export GITHUB_TOKEN="your_token"' >> ~/.bashrc
   source ~/.bashrc
   
   # macOS - Add to shell profile
   echo 'export GITHUB_TOKEN="your_token"' >> ~/.zshrc
   source ~/.zshrc
   
   # Windows - Set user environment variable
   [Environment]::SetEnvironmentVariable("GITHUB_TOKEN", "your_token", "User")
   
   # Restart VS Code after setting
   ```

4. **Test GitHub API access**:
   ```bash
   # Test token
   curl -H "Authorization: token $GITHUB_TOKEN" \
     https://api.github.com/repos/wizzense/AitherZero
   
   # Should return repository information
   ```

### Permission Errors

If you get permission errors with filesystem operations:

1. **Check allowed directories** in `mcp-servers.json`
   - Verify paths exist: `domains`, `automation-scripts`, `tests`, etc.
   - Ensure paths use correct separators for your OS

2. **Verify file permissions** on the repository
   ```bash
   # Check repository permissions
   ls -la /path/to/AitherZero
   
   # Should be readable/writable by your user
   ```

3. **Ensure `readOnly` is set to `false`** for write operations
   - Check `.github/mcp-servers.json`
   - `filesystem.config.readOnly` should be `false`

### AitherZero-Specific Issues

1. **MCP servers can't find PowerShell modules**:
   ```bash
   # Ensure AitherZero is initialized
   ./Initialize-AitherEnvironment.ps1
   
   # Check module paths
   pwsh -c '$env:PSModulePath'
   
   # Should include AitherZero domains
   ```

2. **Filesystem server can't access automation scripts**:
   ```bash
   # Verify scripts are in PATH
   echo $PATH | grep automation-scripts
   
   # Manually add if needed
   export PATH="$PWD/automation-scripts:$PATH"
   ```

3. **Sequential-thinking timeouts on complex tasks**:
   - Break down requests into smaller steps
   - Use intermediate prompts to guide thinking
   - Sequential-thinking works best with focused questions

4. **PowerShell-docs server returns outdated information**:
   - Microsoft Learn is cached by the server
   - Restart VS Code to refresh cache
   - Specify version in queries: "PowerShell 7.4 best practices"

### Common Error Messages

**"MCP server 'X' failed to start"**:
- Check that Node.js/PowerShell is in PATH
- Verify the command in mcp-servers.json is correct
- Check VS Code output for specific error

**"Context too large" errors**:
- MCP servers may provide too much context
- Be more specific in your queries
- Use filters: "Show only .psm1 files" instead of "Show all files"

**"Rate limit exceeded" (GitHub server)**:
- GitHub API has rate limits
- Authenticated requests: 5000/hour
- Wait or use token with higher limits
- Check: curl -H "Authorization: Bearer $GITHUB_TOKEN" https://api.github.com/rate_limit

**"Command not found: pwsh"**:
- PowerShell 7+ not installed or not in PATH
- Install: https://aka.ms/powershell
- Add to PATH after installation

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

1. **MCP Servers**: Provide context and capabilities (data access layer)
2. **Custom Agents**: Provide domain expertise and routing (specialized intelligence)
3. **Custom Instructions**: Provide architectural guidance (project patterns)

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

### AitherZero-Specific Integration Patterns

#### Pattern 1: Domain-Aware Development

When working on a specific domain (e.g., infrastructure, testing, security):

```
@maya Show me the infrastructure domain structure
# Custom agent (Maya) + filesystem MCP server

@maya Design a new Hyper-V VM deployment function
# Maya's expertise + filesystem (existing code) + sequential-thinking (design)
```

#### Pattern 2: Quality-Focused Workflows

Combining testing expertise with MCP capabilities:

```
@jessica Analyze test coverage for OrchestrationEngine
# Custom agent (Jessica) + filesystem (code) + git (changes)

@jessica Create tests for recent security module changes
# Jessica's expertise + git (changes) + powershell-docs (patterns)
```

#### Pattern 3: Documentation and Knowledge

Using documentation expertise with context:

```
@olivia Generate documentation for the new automation functions
# Custom agent (Olivia) + filesystem (code) + powershell-docs (standards)

@olivia Update README with latest playbook examples
# Olivia's expertise + filesystem (playbooks) + github (existing docs)
```

#### Pattern 4: Security-Aware Development

Leveraging security expertise with full context:

```
@sarah Review certificate management code for vulnerabilities
# Custom agent (Sarah) + filesystem (code) + git (history) + github (issues)

@sarah Audit the security domain for compliance with best practices
# Sarah's expertise + filesystem + powershell-docs
```

### MCP Server + Agent Workflow Examples

**Example 1: Adding a New Feature**

```
1. @david Plan a new VM snapshot orchestration feature
   # David (project manager) uses sequential-thinking + filesystem

2. @maya Implement the snapshot functionality in infrastructure domain
   # Maya uses filesystem (existing code) + powershell-docs (patterns)

3. @jessica Create comprehensive tests for snapshot feature
   # Jessica uses filesystem (implementation) + existing test patterns

4. @sarah Review snapshot code for security issues
   # Sarah uses filesystem + git (changes) + security knowledge

5. @olivia Document the new snapshot feature
   # Olivia uses filesystem (code) + examples + standards
```

**Example 2: Debugging a Test Failure**

```
1. @workspace Show me failing test logs from az 0402
   # Filesystem server retrieves logs

2. @jessica Analyze the test failure and identify root cause
   # Jessica's expertise + filesystem (test code) + git (recent changes)

3. @marcus Fix the underlying issue in the module
   # Marcus uses filesystem + powershell-docs

4. @jessica Verify fix and add regression tests
   # Jessica validates with test expertise
```

**Example 3: Improving Infrastructure**

```
1. @workspace Analyze infrastructure domain performance
   # Sequential-thinking + filesystem

2. @maya Identify optimization opportunities
   # Maya's infrastructure expertise + code analysis

3. @workspace Check PowerShell best practices for async operations
   # PowerShell-docs server

4. @maya Implement optimizations following best practices
   # Maya combines expertise with docs

5. @jessica Validate performance improvements with tests
   # Jessica ensures quality
```

## Schema Versioning and Updates

The MCP configuration uses a versioned JSON schema to validate the configuration file.

### Current Schema Version

The schema is currently set to `2025-06-18` version:

```json
{
  "$schema": "https://raw.githubusercontent.com/modelcontextprotocol/modelcontextprotocol/main/schema/2025-06-18/schema.json"
}
```

### Checking for Schema Updates

To check if a new schema version is available:

1. **Visit the schema repository**: <https://github.com/modelcontextprotocol/modelcontextprotocol/tree/main/schema>
2. **Look for newer dated folders** (format: YYYY-MM-DD)
3. **Review the changelog** for breaking changes

### Updating to a New Schema

When a new schema version is released:

1. **Update the schema URL** in `.github/mcp-servers.json`:

   ```json
   {
     "$schema": "https://raw.githubusercontent.com/modelcontextprotocol/modelcontextprotocol/main/schema/YYYY-MM-DD/schema.json"
   }
   ```

2. **Validate configuration**:

   ```bash
   cat .github/mcp-servers.json | jq .
   ```

3. **Review schema changes** to ensure compatibility with your MCP server configurations

4. **Test MCP servers** in VS Code to verify they still work correctly

### Automation Considerations

For future automation of schema updates:

- **GitHub Actions workflow** could periodically check for new schema versions
- **Dependabot-style alerts** when new schemas are released
- **Automated PR creation** with schema updates and validation
- **Version pinning** ensures stability until manual review

**Note**: Schema updates should be reviewed and tested before applying to prevent configuration breakage.

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

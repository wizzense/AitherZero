# GitHub Copilot Development Environment Setup

This guide explains how to set up a fully-configured development environment for AitherZero that maximizes GitHub Copilot's effectiveness.

## Overview

AitherZero includes comprehensive GitHub Copilot integration:

1. **Custom Instructions** (`.github/copilot-instructions.md`) - Project-specific guidance
2. **Agent Routing** (`.github/copilot.yaml`) - Specialized expert agents
3. **MCP Servers** (`.github/mcp-servers.json`) - Enhanced context and capabilities
4. **Dev Containers** (`.devcontainer/`) - Consistent development environment
5. **VS Code Settings** (`.vscode/`) - Optimized editor configuration

## Quick Start

### Option 1: Using Dev Containers (Recommended)

Dev Containers provide a fully-configured environment with all tools pre-installed.

**Prerequisites**:
- Docker Desktop installed
- VS Code with "Remote - Containers" extension

**Steps**:
1. Open the repository in VS Code
2. Press `F1` and select "Remote-Containers: Reopen in Container"
3. Wait for container to build (first time only)
4. Start coding with full Copilot integration!

### Option 2: Local Setup

**Prerequisites**:
- PowerShell 7+ installed
- Git installed
- Node.js 18+ installed (for MCP servers)
- VS Code with GitHub Copilot extensions

**Steps**:
```bash
# 1. Clone the repository
git clone https://github.com/wizzense/AitherZero.git
cd AitherZero

# 2. Install PowerShell dependencies
pwsh -Command "Install-Module -Name Pester -Force -SkipPublisherCheck -Scope CurrentUser"
pwsh -Command "Install-Module -Name PSScriptAnalyzer -Force -SkipPublisherCheck -Scope CurrentUser"

# 3. Set up GitHub token for MCP servers (optional but recommended)
export GITHUB_TOKEN="your_github_token_here"

# 4. Open in VS Code
code .
```

## GitHub Copilot Extensions

Install these VS Code extensions for the complete experience:

### Required
- **GitHub Copilot** (`GitHub.copilot`) - AI pair programmer
- **GitHub Copilot Chat** (`GitHub.copilot-chat`) - AI assistant in sidebar

### Recommended
- **PowerShell** (`ms-vscode.powershell`) - PowerShell language support
- **YAML** (`redhat.vscode-yaml`) - YAML editing and validation
- **Markdown All in One** (`yzhang.markdown-all-in-one`) - Enhanced markdown
- **GitLens** (`eamodio.gitlens`) - Git supercharged
- **Docker** (`ms-azuretools.vscode-docker`) - Container support

VS Code will prompt to install recommended extensions when you open the workspace.

## Feature Highlights

### 1. Custom Instructions

Located at `.github/copilot-instructions.md`, these provide Copilot with:

- **Architecture Overview**: Number-based orchestration, domain structure
- **Development Patterns**: Module loading, cross-platform paths, logging
- **Key Commands**: Testing, validation, orchestration workflows
- **Common Issues**: Solutions to frequently encountered problems
- **Best Practices**: Security, testing, code quality standards

**How to use**: Copilot automatically reads these instructions. Reference them in prompts:

```
@workspace Following the custom instructions, how should I structure a new domain module?
```

### 2. Custom Agent Routing

Located at `.github/copilot.yaml`, this routes work to specialized agents:

- **Maya**: Infrastructure & DevOps (Hyper-V, OpenTofu, networking)
- **Sarah**: Security & Compliance (certificates, credentials)
- **Jessica**: Testing & QA (Pester, test automation)
- **Emma**: Frontend & UX (console UI, menus)
- **Marcus**: Backend & API (PowerShell modules)
- **Olivia**: Documentation (technical writing)
- **Rachel**: PowerShell & Automation (scripting, orchestration)
- **David**: Project Management (planning, coordination)

**How to use**: Agents are auto-suggested based on file patterns and keywords. Invoke manually:

```
/infrastructure Help me set up a new Hyper-V VM configuration
@sarah Review this credential storage implementation
```

### 3. MCP Servers

Located at `.github/mcp-servers.json`, these provide enhanced capabilities:

- **Filesystem**: Repository navigation and file operations
- **GitHub**: Issues, PRs, repository metadata
- **Git**: Version control operations
- **PowerShell Docs**: Best practices and documentation
- **Sequential Thinking**: Complex problem-solving

**See**: [COPILOT-MCP-SETUP.md](COPILOT-MCP-SETUP.md) for detailed configuration.

### 4. Development Container

Located at `.devcontainer/devcontainer.json`, provides:

- **Pre-installed Tools**: PowerShell 7, Git, GitHub CLI, Docker, Node.js
- **Auto-configured Extensions**: All recommended extensions
- **Environment Variables**: `AITHERZERO_ROOT`, etc.
- **Post-creation Scripts**: Pester and PSScriptAnalyzer installation

**Benefits**:
- Consistent environment across team members
- No conflicts with local setup
- Isolated from host system
- Ready to code immediately

### 5. VS Code Configuration

Located in `.vscode/`, includes:

#### Settings (`settings.json`)
- PowerShell formatting and analysis
- GitHub Copilot enablement
- Custom terminal profiles
- File associations and exclusions

#### Tasks (`tasks.json`)
Pre-configured tasks for common operations:
- `Run Unit Tests` - Execute test suite
- `Run PSScriptAnalyzer` - Lint PowerShell code
- `Validate Syntax` - Check syntax errors
- `Generate Project Report` - Create status report
- `Quality Check` - Validate component quality

**Usage**: Press `Ctrl+Shift+B` (Windows/Linux) or `Cmd+Shift+B` (macOS)

#### Launch Configurations (`launch.json`)
Debug configurations for:
- Current PowerShell file
- Start-AitherZero.ps1
- Unit tests
- Interactive debugging

**Usage**: Press `F5` to start debugging

#### Recommended Extensions (`extensions.json`)
Auto-prompts for installation of essential extensions.

## Using GitHub Copilot Effectively

### Chat Interface

Open Copilot Chat with `Ctrl+Shift+I` (Windows/Linux) or `Cmd+Shift+I` (macOS).

**Effective prompts**:

```
# Get architecture guidance
@workspace Explain the domain structure and module loading flow

# Generate code following patterns
@workspace Create a new function in the utilities domain that follows the logging pattern

# Leverage agent expertise
/infrastructure Design a network topology for a 3-VM lab environment
@sarah Review this certificate generation code for security issues

# Use MCP servers
@workspace Show me recent commits affecting the testing domain
@workspace What's PowerShell best practice for parameter validation?
@workspace Create a GitHub issue for improving error handling
```

### Inline Suggestions

Copilot provides suggestions as you type:

1. **Accept suggestion**: Press `Tab`
2. **See alternatives**: Press `Alt+]` (next) or `Alt+[` (previous)
3. **Reject suggestion**: Press `Esc` or keep typing

### Code Comments as Prompts

Write detailed comments to guide Copilot:

```powershell
# Function to deploy a Hyper-V VM using the LabVM module
# Parameters:
#   - VMName: Name of the VM to create
#   - Memory: RAM in GB (default 4)
#   - CPUs: Number of virtual CPUs (default 2)
# Returns: VM object on success, null on failure
# Includes error handling and logging using Write-CustomLog
function Deploy-LabVM {
    # Copilot will generate function based on this comment
}
```

### Multi-file Edits

For changes across multiple files:

```
@workspace I need to add a new parameter to all VM deployment functions. 
Show me which files need to be updated and propose the changes.
```

## Workspace-Specific Features

### AitherZero Terminal Profile

A custom terminal profile that auto-loads the AitherZero environment:

```json
"AitherZero": {
  "path": "pwsh",
  "args": ["-NoExit", "-NoLogo", "-Command", 
           "if (Test-Path ./.azprofile.ps1) { . ./.azprofile.ps1 }"]
}
```

**Usage**: Select "AitherZero" from terminal dropdown

### Keyboard Shortcuts

Recommended shortcuts (add to `keybindings.json`):

```json
[
  {
    "key": "ctrl+shift+t",
    "command": "workbench.action.tasks.runTask",
    "args": "Run Unit Tests"
  },
  {
    "key": "ctrl+shift+b",
    "command": "workbench.action.tasks.build"
  },
  {
    "key": "ctrl+shift+c",
    "command": "github.copilot.generate"
  }
]
```

## Best Practices

### 1. Provide Context

Always give Copilot enough context:

```
# Good
@workspace Following the AitherZero architecture patterns, 
create a new security domain function for certificate validation 
that uses Write-CustomLog for logging and includes Pester tests.

# Less effective
@workspace Make a function to check certificates
```

### 2. Leverage Custom Instructions

Reference the custom instructions explicitly:

```
@workspace According to the custom instructions, what's the 
correct way to handle cross-platform paths in PowerShell?
```

### 3. Use Appropriate Agents

Route work to the right specialist:

```
# Infrastructure work
/infrastructure I need to automate VM snapshot management

# Security review
@sarah Does this credential storage follow best practices?

# Test creation
@jessica Help me write Pester tests for this module
```

### 4. Iterate with Copilot

Refine suggestions through conversation:

```
User: Create a function to list all VMs
Copilot: [generates function]

User: Add error handling and logging
Copilot: [updates with error handling]

User: Make it work cross-platform
Copilot: [adds platform checks]
```

### 5. Validate Suggestions

Always review and test Copilot's suggestions:

1. Read the generated code carefully
2. Run PSScriptAnalyzer: Task → "Run PSScriptAnalyzer"
3. Execute tests: Task → "Run Unit Tests"
4. Test manually if needed

## Troubleshooting

### Copilot Not Providing Suggestions

1. **Check license**: Ensure Copilot subscription is active
2. **Verify extension**: Look for Copilot icon in status bar
3. **Reload window**: `Ctrl+Shift+P` → "Reload Window"
4. **Check file type**: Copilot must be enabled for the language

### Custom Instructions Not Working

1. **Verify file location**: `.github/copilot-instructions.md`
2. **Check syntax**: Ensure valid Markdown
3. **Restart VS Code**: Close and reopen
4. **Explicitly reference**: Use `@workspace` in prompts

### Agent Routing Not Working

1. **Verify configuration**: `.github/copilot.yaml` syntax
2. **Check file patterns**: Ensure editing relevant files
3. **Use manual invocation**: `/agent-name` or `@agent-name`
4. **Review routing rules**: Check keywords and labels match

### MCP Servers Not Loading

1. **Install Node.js**: MCP servers require Node.js 18+
2. **Check configuration**: Validate `mcp-servers.json` syntax
3. **Set GitHub token**: `export GITHUB_TOKEN=...`
4. **Review VS Code output**: Check for MCP errors

**See**: [COPILOT-MCP-SETUP.md](COPILOT-MCP-SETUP.md) for detailed MCP troubleshooting.

### Dev Container Issues

1. **Install Docker**: Ensure Docker Desktop is running
2. **Install extension**: "Remote - Containers" extension
3. **Rebuild container**: `Ctrl+Shift+P` → "Rebuild Container"
4. **Check logs**: View container build output

## Environment Variables

Key environment variables for the development environment:

```bash
# Required
AITHERZERO_ROOT=/path/to/repository

# Optional but recommended
GITHUB_TOKEN=your_github_token        # For MCP GitHub server
AITHERZERO_ENVIRONMENT=development    # Development mode
```

Add to shell profile (`~/.bashrc`, `~/.zshrc`):

```bash
export AITHERZERO_ROOT=~/projects/AitherZero
export GITHUB_TOKEN="ghp_your_token_here"
export AITHERZERO_ENVIRONMENT=development
```

## Additional Resources

### Documentation
- [Custom Instructions](.github/copilot-instructions.md) - Project guidance
- [Agent Routing](.github/copilot.yaml) - Specialist agents
- [MCP Setup](COPILOT-MCP-SETUP.md) - Context servers
- [Development Setup](DEVELOPMENT-SETUP.md) - Environment setup
- [Quality Standards](QUALITY-STANDARDS.md) - Code quality

### External Resources
- [GitHub Copilot Docs](https://docs.github.com/en/copilot)
- [Custom Instructions Guide](https://docs.github.com/en/copilot/customizing-copilot)
- [MCP Specification](https://github.com/modelcontextprotocol/specification)
- [PowerShell Best Practices](https://learn.microsoft.com/en-us/powershell/scripting/developer/cmdlet/strongly-encouraged-development-guidelines)

## Getting Help

If you need assistance:

1. **Chat with Copilot**: `@workspace How do I...?`
2. **Check documentation**: Browse `docs/` directory
3. **Review examples**: Look at existing code
4. **Ask an agent**: Use `/agent-name` for specialist help
5. **Open an issue**: Create GitHub issue for bugs or features

## Contributing

To improve the development environment setup:

1. Test changes in dev container and local setup
2. Update relevant documentation
3. Add examples and troubleshooting tips
4. Submit PR with clear description

---

**Happy coding with AI assistance!** 🚀🤖

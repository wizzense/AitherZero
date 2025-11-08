# Profile-Based Development Environment Setup

## Overview

AitherZero provides a comprehensive profile-based system for setting up complete development, deployment, and CI/CD environments. Choose a profile, run bootstrap, and get a fully configured environment tailored to your needs.

## Features

- **9 Profiles** - From minimal to full-stack, deployment-only to AI-enhanced
- **Granular Scripts** - Individual scripts for each tool (Git, VS Code, Docker, AI CLIs, etc.)
- **Unified Execution** - Playbooks work identically locally and in GitHub Actions
- **Bootstrap Integration** - Profile-based setup during installation
- **Self-Hosted Runners** - Complete automation for GitHub Actions runners
- **Cross-Platform** - Windows, Linux, and macOS support

## Profiles

### Development Profiles

#### Minimal
- **Tools**: PowerShell 7, Git
- **Time**: 2-5 minutes
- **Use**: Bare minimum for basic operation
- **Scripts**: 0000-0099

```powershell
./bootstrap.ps1 -InstallProfile Minimal
```

#### Standard
- **Tools**: PowerShell, Git, Node, Docker, Pester
- **Time**: 5-15 minutes
- **Use**: Common development environment
- **Scripts**: 0000-0299, 0400-0499

```powershell
./bootstrap.ps1 -InstallProfile Standard
```

#### Developer
- **Tools**: Core + Node + Python + Docker + VS Code + GitHub CLI
- **Time**: 15-30 minutes
- **Use**: Full development toolkit
- **Scripts**: 0000-0499

```powershell
./bootstrap.ps1 -InstallProfile Developer
```

#### Development (New!)
- **Tools**: PowerShell, Git, GitHub CLI, Node, Python, Go, VS Code, Docker, OpenTofu, AI CLIs
- **Time**: 20-40 minutes
- **Use**: Complete development with IDE, AI tools, and workflows
- **Features**: 
  - Environment configuration
  - AI integrations (Copilot, Claude, Gemini, Codex)
  - IDE setup with extensions
  - Infrastructure tools

```powershell
./bootstrap.ps1 -InstallProfile Development
```

#### AI-Development (New!)
- **Tools**: VS Code, Node, GitHub CLI, AI CLIs (Claude, Gemini, Codex), MCP Servers
- **Time**: 15-25 minutes
- **Use**: AI-enhanced development workflow
- **Features**:
  - All major AI CLI tools
  - MCP server integration
  - Optimized for AI-assisted coding

```powershell
./bootstrap.ps1 -InstallProfile AI-Development
```

#### Full-Stack (New!)
- **Tools**: All languages (PowerShell, Node, Python, Go, .NET), VS Code, Docker, Kubernetes, OpenTofu, Databases
- **Time**: 30-50 minutes
- **Use**: Complete full-stack development
- **Features**:
  - Multiple language runtimes
  - Database clients (PostgreSQL, Redis, MongoDB)
  - Container orchestration (K8s)
  - Infrastructure as Code

```powershell
./bootstrap.ps1 -InstallProfile Full-Stack
```

### Deployment Profiles

#### Deployment (New!)
- **Tools**: PowerShell, Git, Docker, OpenTofu (no dev tools)
- **Time**: 5-10 minutes
- **Use**: Production/staging deployment servers
- **Features**:
  - Skips IDEs, testing, AI tools
  - Optimized for deployment workflows
  - Infrastructure automation only

```powershell
./bootstrap.ps1 -InstallProfile Deployment -NonInteractive
```

### CI/CD Profiles

#### CI
- **Tools**: PowerShell, Git, Node, Docker, Testing frameworks
- **Time**: 3-8 minutes
- **Use**: GitHub Actions and other CI systems
- **Features**:
  - Parallel execution
  - Non-interactive
  - Cached dependencies

```powershell
./bootstrap.ps1 -InstallProfile CI
```

#### Self-Hosted-Runner (New!)
- **Tools**: Core tools + Docker + Testing + GitHub Runner service
- **Time**: 10-20 minutes
- **Use**: GitHub Actions self-hosted runners
- **Features**:
  - Runner service installation
  - Auto-start on boot
  - Complete CI/CD toolchain

```powershell
./bootstrap.ps1 -InstallProfile Self-Hosted-Runner
```

#### Full
- **Tools**: Everything (all scripts, all features)
- **Time**: 30-60 minutes
- **Use**: Maximum capabilities
- **Scripts**: All (0000-9999)

```powershell
./bootstrap.ps1 -InstallProfile Full
```

## Automation Scripts

### New Scripts

#### 0211_Install-GitHubCLI.ps1
Install GitHub CLI (gh) for GitHub interactions.

```powershell
# Install
./automation-scripts/0211_Install-GitHubCLI.ps1

# Install and configure
./automation-scripts/0211_Install-GitHubCLI.ps1 -Configure

# Or use wrapper
aitherzero 0211 -Configure
```

**Features**:
- Cross-platform (Windows, Linux, macOS)
- Package manager support (winget, choco, apt, yum, brew)
- Optional authentication setup

#### 0212_Install-Go.ps1
Install Go programming language and tools.

```powershell
# Install latest
./automation-scripts/0212_Install-Go.ps1

# Specific version
./automation-scripts/0212_Install-Go.ps1 -Version "1.21.5"

# Or use wrapper
aitherzero 0212
```

**Features**:
- GOPATH configuration
- gopls installation (Language Server)
- PATH updates
- Shell profile integration (Unix)

#### 0220_Install-AI-CLIs.ps1
Install AI CLI tools (Claude, Gemini, Codex).

```powershell
# Install all AI CLIs
./automation-scripts/0220_Install-AI-CLIs.ps1 -Tool All

# Install specific tool
./automation-scripts/0220_Install-AI-CLIs.ps1 -Tool Claude

# Or use wrapper
aitherzero 0220 -Tool All
```

**Supported Tools**:
- **Claude CLI** - Anthropic Claude API
- **Gemini CLI** - Google Gemini API
- **Codex CLI** - OpenAI Codex/GPT API

**Requirements**:
- Node.js/npm
- API keys (set as environment variables)

#### 0850_Install-GitHub-Runner.ps1
Install and configure GitHub Actions self-hosted runner.

```powershell
# Install runner
./automation-scripts/0850_Install-GitHub-Runner.ps1 `
  -Repository "wizzense/AitherZero" `
  -Token "YOUR_REGISTRATION_TOKEN" `
  -InstallAsService

# With custom labels
./automation-scripts/0850_Install-GitHub-Runner.ps1 `
  -Repository "owner/repo" `
  -Token "TOKEN" `
  -Labels "docker,opentofu,custom" `
  -InstallAsService

# Or use wrapper
aitherzero 0850
```

**Features**:
- Service installation (auto-start)
- Custom labels
- Runner groups
- Cross-platform

**Get Registration Token**:
1. Go to `https://github.com/OWNER/REPO/settings/actions/runners/new`
2. Copy the token from the registration command

## Orchestration Playbooks

### dev-environment-setup.psd1
Complete development environment setup.

```powershell
# Run playbook locally
Invoke-AitherPlaybook -Name dev-environment-setup

# Or via wrapper
aitherzero playbook dev-environment-setup
```

**Phases**:
1. Environment Configuration (0001)
2. Core Tools (Git, Node)
3. Programming Languages (Python, Go)
4. Development Environment (VS Code, GitHub CLI)
5. Infrastructure Tools (Docker, OpenTofu)
6. AI Tools (AI CLIs, MCP Servers)
7. Testing Tools (Pester, frameworks)

**Execution**:
- **Local**: Interactive, prompts for optional components
- **CI**: Non-interactive, auto-detected, JSON output

### deployment-environment.psd1
Deployment-only environment (no dev tools).

```powershell
Invoke-AitherPlaybook -Name deployment-environment
```

**Phases**:
1. System Setup (0001, 0002)
2. Version Control (Git only)
3. Container Runtime (Docker)
4. Infrastructure Tools (OpenTofu)
5. Orchestration Validation

**Skips**:
- IDEs and editors
- Testing frameworks
- AI tools
- Language SDKs (except PowerShell)

### self-hosted-runner-setup.psd1
GitHub Actions runner environment.

```powershell
Invoke-AitherPlaybook -Name self-hosted-runner-setup
```

**Phases**:
1. System Setup
2. Core Development Tools
3. Container Support
4. Testing Frameworks
5. Infrastructure Tools
6. Runner Installation

**Features**:
- Installs runner as service
- Configures auto-start
- Validates connectivity

## Bootstrap Integration

Enhanced bootstrap with profile awareness:

```powershell
# Validate profile
./bootstrap.ps1 -InstallProfile Development -WhatIf

# Apply profile-based setup
./bootstrap.ps1 -InstallProfile Development

# Non-interactive (CI/automation)
./bootstrap.ps1 -InstallProfile Deployment -NonInteractive

# Force reinstall
./bootstrap.ps1 -InstallProfile Development -Mode Update
```

**Bootstrap Flow**:
1. Validate profile (9 valid options)
2. Clone/update repository
3. Apply environment configuration (0001)
4. Suggest profile-specific playbook
5. Setup PowerShell integration
6. Setup VS Code integration

## Configuration

All tools configured in `config.psd1`:

### GitHub CLI
```powershell
GitHubCLI = @{
    Enabled = $false
    Version = 'latest'
    InstallScript = '0211'
    Configuration = @{
        AuthMethod = 'browser'  # browser, token
        DefaultEditor = 'vim'
        Protocol = 'https'
    }
}
```

### Go
```powershell
Go = @{
    Enabled = $false
    Version = '1.21+'
    InstallScript = '0212'
    Configuration = @{
        GOPATH = '$HOME/go'
        InstallTools = @('gopls', 'golangci-lint')
    }
}
```

### AI Tools
```powershell
AI = @{
    ClaudeCLI = @{
        Enabled = $false
        InstallScript = '0220'
        Configuration = @{
            APIKeySource = 'environment'
            DefaultModel = 'claude-3-sonnet-20240229'
        }
    }
    GeminiCLI = @{
        Enabled = $false
        InstallScript = '0221'
        Configuration = @{
            DefaultModel = 'gemini-pro'
        }
    }
    CodexCLI = @{
        Enabled = $false
        InstallScript = '0222'
        Configuration = @{
            DefaultModel = 'gpt-4'
        }
    }
}
```

### GitHub Runner
```powershell
GitHubRunner = @{
    Enabled = $false
    InstallScript = '0850'
    Configuration = @{
        RunnerName = '$env:COMPUTERNAME-runner'
        RunnerGroup = 'Default'
        Labels = @('self-hosted', '$OS', '$ARCH')
        InstallAsService = $true
        StartOnBoot = $true
    }
}
```

## Unified Local/CI Execution

Playbooks detect environment and adapt:

### Local Execution
```powershell
# Interactive mode
Invoke-AitherPlaybook -Name dev-environment-setup

# Features:
# - Prompts for optional components
# - Shows progress
# - Colorized output
# - Interactive confirmations
```

### CI Execution
```yaml
# GitHub Actions
- name: Setup Environment
  run: |
    pwsh -Command "Invoke-AitherPlaybook -Name dev-environment-setup"

# Auto-detects CI and adapts:
# - NonInteractive = true
# - JSON output
# - Parallel where safe
# - Cache support
```

## Usage Examples

### Quick Development Setup
```powershell
# Clone repository
git clone https://github.com/wizzense/AitherZero
cd AitherZero

# Bootstrap with development profile
./bootstrap.ps1 -InstallProfile Development

# This applies:
# - Environment configuration
# - PowerShell 7
# - Git + GitHub CLI
# - Node.js
# - Python + Go
# - VS Code with extensions
# - Docker
# - OpenTofu
# - AI CLI tools
# - Testing frameworks
```

### Deployment Server Setup
```powershell
# Minimal deployment environment
./bootstrap.sh -InstallProfile Deployment -NonInteractive

# Only installs:
# - PowerShell 7
# - Git (for pulling code)
# - Docker (for containers)
# - OpenTofu (for infrastructure)

# Skips all dev tools
```

### Self-Hosted Runner Setup
```powershell
# 1. Bootstrap with runner profile
./bootstrap.ps1 -InstallProfile Self-Hosted-Runner

# 2. Get registration token from GitHub
# https://github.com/OWNER/REPO/settings/actions/runners/new

# 3. Configure runner
./automation-scripts/0850_Install-GitHub-Runner.ps1 \
  -Repository "wizzense/AitherZero" \
  -Token "YOUR_TOKEN" \
  -InstallAsService \
  -Labels "docker,opentofu,powershell"

# Runner starts automatically on boot
```

### Individual Tool Installation
```powershell
# GitHub CLI
aitherzero 0211
gh auth login

# Go language
aitherzero 0212
go version

# AI CLIs
aitherzero 0220 -Tool All

# Set API keys
$env:ANTHROPIC_API_KEY = "your-key"
$env:GOOGLE_API_KEY = "your-key"
$env:OPENAI_API_KEY = "your-key"

# Test AI CLIs
claude "Hello from Claude"
genai "Hello from Gemini"
openai chat "Hello from GPT"
```

## GitHub Actions Integration

### Using Playbooks in Workflows
```yaml
name: Setup Development Environment

on:
  push:
    branches: [main]

jobs:
  setup:
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Bootstrap AitherZero
        run: |
          pwsh ./bootstrap.ps1 -InstallProfile Development -NonInteractive
      
      - name: Run Development Playbook
        run: |
          pwsh -Command "Invoke-AitherPlaybook -Name dev-environment-setup"
      
      - name: Verify Installation
        run: |
          gh --version
          go version
          docker --version
          tofu --version
```

### Caching
```yaml
- name: Cache Dependencies
  uses: actions/cache@v4
  with:
    path: |
      ~/.npm
      ~/.cache/go-build
      ~/.cache/pip
    key: ${{ runner.os }}-dev-${{ hashFiles('**/package-lock.json') }}
```

## Troubleshooting

### Profile Not Found
```powershell
# List valid profiles
./bootstrap.ps1 -InstallProfile InvalidProfile
# Shows: Valid profiles: Minimal, Standard, Developer, Development, ...
```

### Script Not Found
```powershell
# Check script exists
ls automation-scripts/0211*.ps1

# Verify with wrapper
aitherzero 0211 -WhatIf
```

### API Keys Not Set
```powershell
# Check environment variables
$env:ANTHROPIC_API_KEY
$env:GOOGLE_API_KEY
$env:OPENAI_API_KEY

# Set persistently (Windows)
[Environment]::SetEnvironmentVariable('ANTHROPIC_API_KEY', 'your-key', 'User')

# Set persistently (Unix)
echo 'export ANTHROPIC_API_KEY=your-key' >> ~/.bashrc
source ~/.bashrc
```

### Runner Registration Failed
```powershell
# Get fresh token from GitHub
# Tokens expire after 1 hour!
# https://github.com/OWNER/REPO/settings/actions/runners/new

# Verify connectivity
Test-NetConnection github.com -Port 443
Test-NetConnection api.github.com -Port 443
```

## See Also

- [Environment Configuration](./ENVIRONMENT-CONFIGURATION.md)
- [Orchestration Playbooks](../orchestration/playbooks/README.md)
- [Bootstrap Guide](../bootstrap.ps1)
- [Configuration System](./CONFIG-DRIVEN-ARCHITECTURE.md)

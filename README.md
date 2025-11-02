<p align="center">
  <img src="aitherium_logo.jpg" alt="Aitherium Logo" width="200"/>
</p>

<h1 align="center">AitherZero</h1>

<p align="center">
  <strong>Aitherium™ Enterprise Infrastructure Automation Platform</strong><br>
  Infrastructure automation platform with AI-powered orchestration
</p>

<p align="center">
  <a href="#quick-install">Quick Install</a> •
  <a href="#features">Features</a> •
  <a href="#documentation">Documentation</a> •
  <a href="#license">License</a>
</p>

---

## 🚀 Quick Install

### One-Liner Installation (Recommended)

**Windows/Linux/macOS (PowerShell 5.1+)**
```powershell
iwr -useb https://raw.githubusercontent.com/wizzense/AitherZero/main/bootstrap.ps1 | iex
```

**Linux/macOS (Bash)**
```bash
curl -sSL https://raw.githubusercontent.com/wizzense/AitherZero/main/bootstrap.sh | bash
```

### Download Latest Release Package

**Option 1: Direct Download (Latest Release)**
```powershell
# Download latest release ZIP
$latest = (Invoke-RestMethod "https://api.github.com/repos/wizzense/AitherZero/releases/latest").assets | Where-Object {$_.name -like "*.zip"}
Invoke-WebRequest -Uri $latest.browser_download_url -OutFile "AitherZero-latest.zip"
Expand-Archive -Path "AitherZero-latest.zip" -DestinationPath ./
cd AitherZero-*
./bootstrap.ps1 -Mode New -NonInteractive
```

**Option 2: GitHub CLI**
```bash
# Using GitHub CLI (gh)
gh repo clone wizzense/AitherZero
cd AitherZero
bash tools/setup-git-merge.sh  # Configure merge strategy for auto-generated files
./bootstrap.sh
```

**Note**: After cloning, run `bash tools/setup-git-merge.sh` to configure Git to handle auto-generated `index.md` files correctly. This prevents merge conflicts. See [Git Merge Setup Guide](./docs/GIT-MERGE-SETUP.md) for details.

**Option 3: Git Clone**
```bash
# Traditional git clone
git clone https://github.com/wizzense/AitherZero.git
cd AitherZero
./bootstrap.ps1  # Windows/PowerShell
# OR
./bootstrap.sh   # Linux/macOS
```

## 📋 Requirements

**Automatically Installed:**
- PowerShell 7.0+ (auto-installed if missing)
- Git (auto-installed if missing)

**Optional:**
- OpenTofu or Terraform (for infrastructure automation)
- Docker (for containerized workflows) - [See Docker Guide](DOCKER.md)

### 🐳 Docker Quick Start

Run AitherZero in an isolated container:

```bash
# Pull the latest image from GitHub Container Registry
docker pull ghcr.io/wizzense/aitherzero:latest

# Run interactively
docker run -it --rm ghcr.io/wizzense/aitherzero:latest

# Or use docker-compose for persistent storage
docker-compose up -d
```

**Available Docker images:**
- `ghcr.io/wizzense/aitherzero:latest` - Latest stable release
- `ghcr.io/wizzense/aitherzero:1.0.0` - Specific version
- Multi-platform support: `linux/amd64`, `linux/arm64`

See [Docker Documentation](DOCKER.md) for complete container usage guide.

### 🤖 MCP Server Quick Start

Use AitherZero with AI assistants (Claude, GitHub Copilot, etc.):

```bash
# Install from GitHub Packages
npm install @aitherzero/mcp-server

# Or install globally
npm install -g @aitherzero/mcp-server
```

**Configure with Claude Desktop** (`~/Library/Application Support/Claude/claude_desktop_config.json`):
```json
{
  "mcpServers": {
    "aitherzero": {
      "command": "npx",
      "args": ["@aitherzero/mcp-server"]
    }
  }
}
```

**Configure with VS Code / GitHub Copilot** (`.github/mcp-servers.json`):
```json
{
  "mcpServers": {
    "aitherzero": {
      "command": "npx",
      "args": ["@aitherzero/mcp-server"],
      "description": "AitherZero infrastructure automation"
    }
  }
}
```

See [MCP Server Documentation](mcp-server/README.md) for complete setup and usage guide.

```bash
# Quick start with Docker Compose
git clone https://github.com/wizzense/AitherZero.git
cd AitherZero
docker-compose up -d
docker-compose exec aitherzero pwsh

# Or build and run with Docker
docker build -t aitherzero:latest .
docker run -it --rm aitherzero:latest pwsh
```

📖 **[Complete Docker Documentation](DOCKER.md)** - Building, running, CI/CD integration, and production deployment

## 🎯 Quick Start

```powershell
# After installation, AitherZero is available globally as 'aitherzero'
aitherzero              # Start interactive mode

# Or run from the installation directory
./Start-AitherZero.ps1

# Modern CLI - Simplified syntax
aitherzero -Mode List -Target scripts              # List all automation scripts
aitherzero -Mode Run -Target 0402                  # Run specific script (shortcut)
aitherzero -Mode Run -Target script -ScriptNumber 0402  # Run specific script (verbose)

# The global command works from anywhere
cd /any/directory
./Start-AitherZero.ps1 -Mode Search -Query test    # Find test-related scripts
```

### Global Command

After installation via `bootstrap.ps1`, the `aitherzero` command is automatically available from anywhere on your system:

- **Linux/macOS**: Installed to `~/.local/bin/aitherzero`
- **Windows**: Installed to `%LocalAppData%\AitherZero\bin\aitherzero.cmd`

The global command:
- Automatically locates your AitherZero installation
- Forwards all arguments to `Start-AitherZero.ps1`
- Works from any directory
- Supports all parameters and modes

**Note**: Open a new terminal or run `source ~/.bashrc` (Linux/macOS) for the command to be available after installation.

## 📦 What's Included

The AitherZero package includes:
- **Complete PowerShell module** with all domains and functions
- **200+ automation scripts** (numbered 0000-9999) for systematic execution
- **Cross-platform bootstrap scripts** for automatic dependency installation  
- **Comprehensive test suite** with validation tools
- **Quality validation system** for code standards enforcement
- **CI/CD workflow templates** for GitHub Actions
- **Documentation and examples** for all features
- **Docker support** for containerized workflows and testing

## 🐳 Using Docker

AitherZero can run in Docker containers for consistent, isolated environments:

```bash
# Quick start with Docker Compose
docker-compose up -d
docker-compose exec aitherzero pwsh

# Or build and run manually
docker build -t aitherzero:latest .
docker run -it --rm aitherzero:latest pwsh
```

**Benefits:**
- ✅ Consistent environment across platforms
- ✅ No dependency conflicts
- ✅ Perfect for CI/CD pipelines
- ✅ Quick testing and validation

**📖 Full Documentation**: [Docker Guide](DOCKER.md) - Complete instructions for building, running, and using the Docker container.

## 🔧 Verify Installation

```powershell
# Test basic functionality
Import-Module ./AitherZero.psd1
Get-Module AitherZero

# Run syntax validation
./az.ps1 0407

# Run quality checks
./aitherzero 0420 -Path ./domains/utilities/Logging.psm1

# Generate and view project report
./az.ps1 0510 -ShowAll
```

## 📊 Quality Standards

AitherZero maintains high code quality standards through automated validation:

```powershell
# Validate component quality
./aitherzero 0420 -Path ./MyModule.psm1

# Validate entire domain
./aitherzero 0420 -Path ./domains/testing -Recursive
```

**Quality checks include:**
- ✅ Error handling validation
- ✅ Logging implementation
- ✅ Test coverage verification
- ✅ UI/CLI integration
- ✅ PSScriptAnalyzer compliance

**Documentation:**
- [Quality Standards](docs/QUALITY-STANDARDS.md) - Complete quality guidelines
- [Quick Reference](docs/QUALITY-QUICK-REFERENCE.md) - Quick reference guide
- [Docker Usage Guide](DOCKER.md) - Container deployment and workflows

## Features

- **Infrastructure Deployment**: Plan, apply, and destroy infrastructure using OpenTofu/Terraform
- **Lab VM Management**: Create and manage virtual machines
- **Configuration**: Simple configuration management

## Core Modules

- **LabRunner**: Lab automation and VM management
- **OpenTofuProvider**: Infrastructure deployment
- **Logging**: Centralized logging
- **ConfigurationCore**: Configuration management
- **SecureCredentials**: Credential handling

## Project Structure

```
```

## Usage

1. Run `./Start-AitherZero.ps1`
2. Select from the menu:
   - Deploy Infrastructure
   - Manage Lab VMs
   - Configure Settings
3. Follow the prompts

## Configuration

The main configuration file is `config.psd1` in the project root.

## 🤖 AI-Assisted Development

AitherZero includes comprehensive GitHub Copilot integration to enhance developer productivity:

### Features
- **Custom Instructions**: Project-specific guidance for AI coding assistants
- **Agent Routing**: 8 specialized expert agents for different domains
- **MCP Client**: Model Context Protocol integration for enhanced context (uses external MCP servers)
- **MCP Server**: AitherZero can BE an MCP server - expose automation capabilities to AI assistants! 🆕
  - **Published to GitHub Packages**: `npm install @aitherzero/mcp-server`
  - **Available as Release Asset**: Download tarball from releases
  - **Multi-platform Support**: Works with Claude, GitHub Copilot, and other MCP clients
- **Dev Containers**: Pre-configured development environment
- **VS Code Integration**: Optimized settings, tasks, and debugging

### Distribution Formats

AitherZero is available in multiple formats for different use cases:

1. **Platform Package** (`.zip`, `.tar.gz`):
   - Complete PowerShell module with all domains
   - 100+ automation scripts
   - Released via GitHub Releases

2. **Docker Image** (`ghcr.io/wizzense/aitherzero`):
   - Pre-configured container environment
   - Multi-platform: `linux/amd64`, `linux/arm64`
   - Published to GitHub Container Registry
   - Perfect for CI/CD and isolated environments

3. **MCP Server** (`@aitherzero/mcp-server`):
   - npm package for AI assistant integration
   - Published to GitHub Packages
   - Enables natural language infrastructure management

### Quick Setup
1. **Install GitHub Copilot** extensions in VS Code
2. **Open in Dev Container** (recommended) or install recommended extensions
3. **Set GitHub Token** for MCP servers: `export GITHUB_TOKEN="your_token"`
4. **Start coding** with AI assistance!

### Using Copilot Effectively
```
# Leverage specialized agents
/infrastructure Design a VM network topology
@sarah Review certificate security
@jessica Create Pester tests

# Use context from MCP servers
@workspace Show recent commits to testing domain
@workspace Create issue for feature request

# Follow architecture patterns
@workspace Create a new utility function following AitherZero patterns
```

### 🆕 Use AitherZero as an MCP Server

Let AI assistants control AitherZero's infrastructure automation:

```bash
# Build the MCP server
cd mcp-server && npm install && npm run build

# Configure your AI assistant (Claude, Copilot, etc.)
# Add to your MCP client config:
{
  "aitherzero": {
    "command": "node",
    "args": ["/path/to/AitherZero/mcp-server/dist/index.js"]
  }
}

# Then ask your AI assistant:
"Run AitherZero tests"
"Search for Docker scripts"
"Execute the quick test playbook"
"Show me the project report"
```

AI assistants can now:
- Execute automation scripts (0000-9999)
- Run playbooks and orchestration sequences
- Query configuration and project status
- Run tests and quality checks
- Manage infrastructure deployments

**Learn more**: See [docs/AITHERZERO-MCP-SERVER.md](docs/AITHERZERO-MCP-SERVER.md) for complete MCP server setup and usage.

### Documentation
- [Development Environment Setup](docs/COPILOT-DEV-ENVIRONMENT.md) - Complete guide
- [MCP Client Configuration](docs/COPILOT-MCP-SETUP.md) - Using external MCP servers
- [AitherZero as MCP Server](docs/AITHERZERO-MCP-SERVER.md) - Expose AitherZero to AI 🆕
- [Custom Instructions](.github/copilot-instructions.md) - AI coding guidance
- [Agent Routing](.github/copilot.yaml) - Specialized experts

## Uninstallation

To remove AitherZero from your system:

```powershell
# Remove the installation
./bootstrap.ps1 -Mode Remove

# Or manually remove the global command
./tools/Install-GlobalCommand.ps1 -Action Uninstall

# Manual cleanup (if needed)
# Remove installation directory
rm -rf ~/AitherZero  # or your custom installation path

# Remove global command (Linux/macOS)
rm ~/.local/bin/aitherzero

# Remove environment variable from shell profiles
# Edit ~/.bashrc, ~/.zshrc, ~/.profile and remove AITHERZERO_ROOT lines
```

## License

MIT License - see LICENSE file for details.

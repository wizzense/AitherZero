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
./bootstrap.sh
```

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

### Core Capabilities

- **🔢 Number-Based Orchestration**: Systematic script execution using numbered ranges (0000-9999) for predictable automation workflows
- **🏗️ Infrastructure Deployment**: Plan, apply, and destroy infrastructure using OpenTofu/Terraform with lab automation
- **💻 Lab VM Management**: Create, configure, and manage Hyper-V virtual machines with networking and storage
- **🔧 Development Tools**: Automated installation and configuration of Git, Node.js, Python, Docker, VS Code, and more
- **🧪 Testing Framework**: Comprehensive testing with Pester, PSScriptAnalyzer, and automated quality validation
- **📊 Reporting & Analytics**: Interactive dashboards, project metrics, technical debt analysis, and GitHub Pages integration
- **⚙️ Configuration Management**: Hierarchical config system with automatic CI/CD detection and environment switching
- **🔒 Security Management**: Credential handling, certificate management, and secure secret storage
- **📚 Documentation Generation**: Automated documentation with templates and markdown generation
- **🎨 Interactive UI**: Rich console menus, wizards, and progress indicators for user-friendly operation
- **🤖 AI Integration**: Claude Code and Gemini CLI integration for AI-assisted development workflows

### Cross-Platform Support

- **Windows**: Full support with Hyper-V, WSL2, and Windows-specific features
- **Linux**: Native support with all core functionality
- **macOS**: Native support with all core functionality
- **Docker**: Containerized workflows for consistent environments

### Automation & Orchestration

- **Playbook System**: Predefined sequences for common workflows (testing, setup, validation)
- **Parallel Execution**: Configurable concurrency for faster script execution
- **Dependency Management**: Automatic detection and installation of required tools
- **CI/CD Integration**: Zero-configuration operation in GitHub Actions, Azure DevOps, and other CI systems

### Quality Assurance

- **Automated Testing**: Unit tests, integration tests, and domain-specific test suites
- **Code Quality**: PSScriptAnalyzer integration with customizable rules
- **Test Coverage**: Code coverage tracking and reporting
- **Quality Validation**: Script 0420 validates components against quality standards

### 🤖 GitHub Copilot Agent Routing

AitherZero includes an **automatic agent routing system** with 8 specialized AI agents that provide expert reviews on pull requests:

**Available Agents:**
- 🏗️ **Maya** - Infrastructure & DevOps (Hyper-V, Terraform, networking)
- 🔒 **Sarah** - Security & Compliance (certificates, credentials, vulnerabilities)
- 🧪 **Jessica** - Testing & QA (Pester tests, coverage, quality)
- 🎨 **Emma** - Frontend & UX (console UI, menus, accessibility)
- ⚙️ **Marcus** - Backend & API (PowerShell modules, performance)
- 📚 **Olivia** - Documentation (guides, README, technical writing)
- ⚡ **Rachel** - PowerShell & Automation (advanced scripting, orchestration)
- 📋 **David** - Project Management (coordination, planning, releases)

**How it works:**
1. Open a PR → System analyzes files and suggests relevant agents
2. Use `@agent-name` or `/command` in comments to engage specific agents
3. Agents provide specialized expertise for their domain
4. Multiple agents can collaborate on complex tasks

**Learn more:** [.github/AGENT-ROUTING-GUIDE.md](.github/AGENT-ROUTING-GUIDE.md)

## Core Modules

AitherZero uses a consolidated **domain-based module architecture** (v2.0):

- **infrastructure/**: Lab automation, OpenTofu/Terraform, VM management, Hyper-V
- **configuration/**: Configuration management with environment switching
- **security/**: Credential management, certificate handling
- **utilities/**: Logging, maintenance, cross-platform helpers
- **experience/**: UI components, interactive menus, wizards
- **automation/**: Orchestration engine, workflow management
- **testing/**: Testing framework, code quality validation
- **reporting/**: Analytics, dashboards, metrics
- **development/**: Git automation, dev tools integration
- **documentation/**: Documentation generation and management

All modules load through a single entry point (`AitherZero.psm1`) and are accessible after running:
```powershell
./Initialize-AitherEnvironment.ps1
```

## Project Structure

```
AitherZero/
├── AitherZero.psd1              # Module manifest
├── AitherZero.psm1              # Root module loader
├── Start-AitherZero.ps1         # Main entry point
├── bootstrap.ps1 / .sh          # Cross-platform installers
├── config.psd1                  # Configuration file
│
├── domains/                     # Domain-based module architecture
│   ├── infrastructure/          # Lab automation, VM management
│   ├── configuration/           # Config management
│   ├── security/                # Credentials, certificates
│   ├── utilities/               # Logging, maintenance
│   ├── experience/              # UI components, menus
│   ├── automation/              # Orchestration engine
│   ├── testing/                 # Testing framework
│   ├── reporting/               # Analytics, dashboards
│   ├── development/             # Dev tools, Git automation
│   └── documentation/           # Documentation generation
│
├── automation-scripts/          # Number-based orchestration (0000-9999)
│   ├── 0000-0099/              # Environment preparation
│   ├── 0100-0199/              # Infrastructure setup
│   ├── 0200-0299/              # Development tools
│   ├── 0400-0499/              # Testing & validation
│   ├── 0500-0599/              # Reporting & metrics
│   ├── 0700-0799/              # Git automation & AI
│   └── 9000-9999/              # Maintenance & cleanup
│
├── orchestration/               # Playbooks and workflows
│   └── playbooks/              # Predefined automation sequences
│
├── infrastructure/              # Infrastructure-as-Code
│   ├── terraform/              # Terraform configurations
│   └── examples/               # Example configurations
│
├── tests/                       # Comprehensive test suite
│   ├── unit/                   # Unit tests
│   ├── integration/            # Integration tests
│   └── domains/                # Domain-specific tests
│
├── docs/                        # Documentation
└── reports/                     # Generated reports
```

## Usage

### Interactive Mode

Launch the interactive menu system:

```powershell
./Start-AitherZero.ps1
# Or use the global command
aitherzero
```

Navigate through menus to:
- Deploy infrastructure with OpenTofu/Terraform
- Manage Hyper-V lab VMs
- Configure system settings
- Run automation scripts
- View reports and metrics

### CLI Mode

Run specific scripts by number:

```powershell
# Using the az wrapper (recommended)
./az.ps1 0402                   # Run unit tests
./az.ps1 0404                   # Run PSScriptAnalyzer
./az.ps1 0510 -ShowAll          # Generate project report

# Using the global command
aitherzero -Mode Run -Target 0402
```

### Orchestration Mode

Execute predefined playbooks:

```powershell
# Quick validation
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook test-quick

# Full test suite
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook test-full

# Environment setup
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook environment-setup
```

### Script Number Ranges

- **0000-0099**: Environment preparation (PowerShell 7, directories)
- **0100-0199**: Infrastructure (Hyper-V, certificates, networking)
- **0200-0299**: Development tools (Git, Node, Python, Docker, VS Code)
- **0400-0499**: Testing & validation
- **0500-0599**: Reporting & metrics
- **0700-0799**: Git automation & AI tools
- **9000-9999**: Maintenance & cleanup

## Configuration

### Configuration Hierarchy

AitherZero uses a hierarchical configuration system with automatic CI/CD detection:

1. **Command-line parameters** (highest priority)
2. **Environment variables** (`AITHERZERO_*` prefixed)
3. **config.local.psd1** (local overrides, gitignored)
4. **config.psd1** (main configuration file)
5. **CI defaults** (automatic in CI environments)
6. **Script defaults** (fallback values)

### Configuration Files

| File | Purpose | Version Control |
|------|---------|-----------------|
| `config.example.psd1` | Documented template | Yes |
| `config.psd1` | Main configuration | Yes |
| `config.local.psd1` | Local overrides | No (gitignored) |
| `.env` | Environment variables | No (gitignored) |

### Quick Configuration

```powershell
# Use defaults (recommended for CI/CD)
./bootstrap.ps1
./Start-AitherZero.ps1

# Customize installation profile
./bootstrap.ps1 -InstallProfile Developer

# Create local configuration
Copy-Item config.example.psd1 config.local.psd1
# Edit config.local.psd1 as needed
```

### Key Configuration Options

- **Core.Profile**: Installation profile (Minimal, Standard, Developer, Full)
- **Core.Environment**: Environment type (Development, Testing, Production, CI)
- **Automation.MaxConcurrency**: Parallel execution limit
- **Testing.Profile**: Test execution profile (Quick, Standard, Full, CI)

**Full documentation**: [docs/CONFIGURATION.md](docs/CONFIGURATION.md)

## 📚 Documentation

### Getting Started
- **[Quick Install](#quick-install)** - Get up and running in minutes
- **[Docker Guide](DOCKER.md)** - Containerized deployment
- **[Cross-Platform Validation](CROSS-PLATFORM-VALIDATION.md)** - Multi-OS testing

### Core Documentation
- **[Functionality Index](FUNCTIONALITY-INDEX.md)** - Complete feature catalog
- **[Implementation Summary](IMPLEMENTATION-SUMMARY.md)** - Architecture overview
- **[Build & Release](BUILD-AND-RELEASE-SUMMARY.md)** - Release process

### GitHub Integration
- **[Agent Routing Guide](.github/AGENT-ROUTING-GUIDE.md)** - AI-powered PR reviews
- **[Agent Quick Start](.github/AGENT-QUICK-START.md)** - Fast reference
- **[Agent Examples](.github/AGENT-EXAMPLES.md)** - Real-world scenarios
- **[.github/README.md](.github/README.md)** - GitHub configuration hub

### Development
- **[Copilot Instructions](.github/copilot-instructions.md)** - AI agent guidelines
- **[Workflow Coordination](.github/WORKFLOW-COORDINATION.md)** - CI/CD pipelines
- **[Troubleshooting](TROUBLESHOOTING-WORKFLOW-FAILURES.md)** - Common issues

### Contributing
Want to contribute? Check out:
- **[Agent Profiles](.github/agents/)** - Meet the AI team
- **[Pull Request Template](.github/pull_request_template.md)** - PR guidelines
- Project follows semantic versioning and conventional commits

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

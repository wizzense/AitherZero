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

# The global command works from anywhere
cd /any/directory
aitherzero -Mode List -Target scripts    # List all automation scripts
aitherzero -Mode Run -Target script -ScriptNumber 0402  # Run specific script
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

Configuration files are stored in the `configs/` directory.

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

<p align="center">
  <img src="assets/branding/aitherium-logo.png" alt="Aitherium Logo" width="200"/>
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

## Quick Install

### Windows/Linux/macOS (PowerShell 7+)
```powershell
irm https://raw.githubusercontent.com/wizzense/AitherZero/main/bootstrap.ps1 | iex
```

### Linux/macOS (Bash)
```bash
curl -sSL https://raw.githubusercontent.com/wizzense/AitherZero/main/bootstrap.sh | bash
```

## Requirements

- PowerShell 7.0+
- OpenTofu or Terraform

## Quick Start

```bash
# Run the application
./Start-AitherZero.ps1

# Get help
./Start-AitherZero.ps1 -Help

# Check version
./Start-AitherZero.ps1 -Version
```

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

## License

MIT License - see LICENSE file for details.

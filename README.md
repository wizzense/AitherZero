# AitherZero

Infrastructure automation platform with AI-powered orchestration.

## Quick Install

### Windows (PowerShell)
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
AitherZero/
├── Start-AitherZero.ps1    # Main entry point
├── README.md               # This file
├── VERSION                 # Version info
├── aither-core/
│   └── modules/           # Core modules
│       ├── ConfigurationCore/
│       ├── LabRunner/
│       ├── Logging/
│       ├── OpenTofuProvider/
│       └── SecureCredentials/
├── configs/               # Configuration files
├── opentofu/             # OpenTofu/Terraform templates
└── tests/                # Test files
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
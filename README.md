# AitherZero Infrastructure Automation

Cross-platform PowerShell automation framework for OpenTofu/Terraform infrastructure management with comprehensive testing and modular architecture.

## Quick Start - Bootstrap Installation

### 🚀 One-Line Installation

**✅ WORKING METHOD #1** (Direct Download - No Git Required):

```powershell
# Windows PowerShell/PowerShell 7
Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/wizzense/AitherZero/main/aither-core/aither-core.ps1' -OutFile 'aither-core.ps1'; pwsh -File ./aither-core.ps1
```

```bash
# Linux/macOS
curl -sSL https://raw.githubusercontent.com/wizzense/AitherZero/main/aither-core/aither-core.ps1 -o aither-core.ps1 && pwsh -File ./aither-core.ps1
```

**✅ WORKING METHOD #2** (Git Clone - Full Repository):

```powershell
git clone https://github.com/wizzense/AitherZero.git; cd AitherZero; pwsh -File ./aither-core/aither-core.ps1
```

**✅ WORKING METHOD #3** (Cross-platform One-liner):

```powershell
pwsh -Command "git clone https://github.com/wizzense/AitherZero.git; cd AitherZero; pwsh -File ./aither-core/aither-core.ps1"
```

**✅ WORKING METHOD #4** (Step-by-step):

```powershell
# 1. Clone the repository
git clone https://github.com/wizzense/AitherZero.git

# 2. Enter directory
cd AitherZero

# 3. Run AitherCore
pwsh -File ./aither-core/aither-core.ps1
```

**✅ WORKING METHOD #5** (Direct Download and Bootstrap - No Git Required):

```powershell
# Windows PowerShell/PowerShell 7
Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/wizzense/AitherZero/main/bootstrap.ps1' -OutFile 'bootstrap.ps1'; pwsh -File ./bootstrap.ps1
```

```bash
# Linux/macOS
curl -sSL https://raw.githubusercontent.com/wizzense/AitherZero/main/bootstrap.ps1 -o bootstrap.ps1 && pwsh -File ./bootstrap.ps1
```

### 📋 Bootstrap Options

The **AitherCore** framework is your **single entry point** for all automation scenarios:

#### **aither-core.ps1** Features

- ✅ Full modular architecture with 14+ specialized modules
- ✅ Cross-platform support (Windows, Linux, macOS)
- ✅ PowerShell 5.1 and 7.x compatibility
- ✅ Self-updating capabilities via PatchManager
- ✅ Comprehensive health checks and validation
- ✅ Advanced error handling and logging
- ✅ Non-interactive mode for automation
- ✅ Bulletproof testing framework integration

```powershell
# Run AitherCore with options
./aither-core/aither-core.ps1 -Verbosity detailed -NonInteractive
./aither-core/aither-core.ps1 -Scripts "LabRunner,BackupManager" -Auto
./aither-core/aither-core.ps1 -WhatIf  # See what would be done
```

### 🔧 Manual Installation

If you prefer manual control:

```powershell
# 1. Clone the repository
git clone https://github.com/wizzense/AitherZero.git

# 2. Enter the directory
cd AitherZero

# 3. Run AitherCore with your preferred options
./aither-core/aither-core.ps1 -Verbosity detailed
```

## Environment Setup

The AitherCore framework automatically sets up:

- **Environment Variables:**
  - `$env:PROJECT_ROOT` - Project root directory
  - `$env:PWSH_MODULES_PATH` - Module search path

- **Module Import Paths:**

  ```powershell
  Import-Module "$env:PROJECT_ROOT/aither-core/modules/Logging" -Force
  Import-Module "$env:PROJECT_ROOT/aither-core/modules/PatchManager" -Force
  ```

## Architecture Overview

```
AitherZero/
├── aither-core/                   # Main automation framework
│   ├── aither-core.ps1            # Main entry point script
│   ├── AitherCore.psd1            # Module manifest
│   ├── AitherCore.psm1            # Core module
│   ├── default-config.json        # Default configuration
│   ├── scripts/                   # Automation scripts (0000_*.ps1)
│   ├── shared/                    # Shared utilities
│   └── modules/                   # PowerShell modules
│       ├── BackupManager/         # File backup and cleanup
│       ├── DevEnvironment/        # Development setup
│       ├── ISOCustomizer/         # ISO customization
│       ├── ISOManager/            # ISO management
│       ├── LabRunner/             # Lab automation orchestration
│       ├── Logging/               # Centralized logging
│       ├── OpenTofuProvider/      # OpenTofu integration
│       ├── ParallelExecution/     # Runspace-based parallelism
│       ├── PatchManager/          # Git-controlled patch workflows
│       ├── ScriptManager/         # Script repository management
│       ├── TestingFramework/      # Pester test wrapper
│       └── UnifiedMaintenance/    # Unified maintenance operations
├── configs/                       # Configuration files
├── docs/                          # Comprehensive documentation
├── tests/                         # Bulletproof testing framework
├── tools/                         # Utility tools
└── opentofu/                      # OpenTofu infrastructure
```

## What AitherCore Does

1. **Environment Setup**: Automatically configures PROJECT_ROOT and module paths
2. **Module Loading**: Imports all 14+ specialized PowerShell modules
3. **Health Checks**: Validates system requirements and dependencies
4. **Script Execution**: Runs automation scripts with proper error handling

## Essential Setup Scripts

When AitherCore launches, you can run these essential scripts:

### Required Scripts: 0006, 0007, 0008, 0009, 0010

- **0006_Install-ValidationTools.ps1** - Downloads cosign for verification
- **0007_Install-Go.ps1** - Downloads and installs Go
- **0008_Install-OpenTofu.ps1** - Downloads and installs OpenTofu (verified with cosign)
- **0009_Initialize-OpenTofu.ps1** - Sets up OpenTofu and infrastructure repo
- **0010_Prepare-HyperVProvider.ps1** - Configures Hyper-V host

**Example Infrastructure Repository**: [tofu-base-lab](https://github.com/wizzense/tofu-base-lab.git)

**Example Config File**: [bootstrap-config.json](https://raw.githubusercontent.com/wizzense/tofu-base-lab/refs/heads/main/configs/bootstrap-config.json)

## Available Runner Scripts

The runner script can execute the following automation scripts:

### Core Infrastructure Scripts

- **0000_Cleanup-Files.ps1** - Removes lab-infra OpenTofu infrastructure repo
- **0001_Reset-Git.ps1** - Resets lab-infra OpenTofu infrastructure repo (re-pulls files/resets if you modify any files)
- **0006_Install-ValidationTools.ps1** - Downloads the cosign exe to C:\temp\cosign
- **0007_Install-Go.ps1** - Downloads and installs Go
- **0008_Install-OpenTofu.ps1** - Downloads and installs OpenTofu standalone (verified with cosign)
- **0009_Initialize-OpenTofu.ps1** - Sets up OpenTofu and the lab-infra repo in C:\temp\base-infra
- **0010_Prepare-HyperVHost.ps1** - Comprehensive Hyper-V host configuration

### 0010_Prepare-HyperVHost.ps1 Details

This script performs extensive Hyper-V host preparation:

**Hyper-V Configuration:**

- Enables Hyper-V if not enabled
- Enables WinRM if not enabled
  - Sets WinRS MaxMemoryPerShellMB to 1024
  - Sets WinRM MaxTimeoutms to 1800000
  - Sets TrustedHosts to '*'
  - Sets Negotiate to True

**Certificate Management:**

- Creates a self-signed RootCA Certificate (prompts for password)
- Creates self-signed host certificate (prompts for password)
- Configures WinRM HTTPS Listener
- Allows HTTPS 5986 through firewall

**Go Workspace & Provider Setup:**

- Creates a Go workspace in C:\GoWorkspace
- Builds the hyperv-provider for OpenTofu from Taliesins git
- Copies the provider to the lab-infra

> **Note**: Certificate validation for the hyperv provider is currently disabled by default. I am still working out how to get it to use the certificates properly (they may need to be converted to .pem first).

### Optional Administrative Scripts

- **0100_Enable-WinRM.ps1** - Basic WinRM enablement
- **0101_Enable-RemoteDesktop.ps1** - Remote Desktop configuration
- **0102_Configure-Firewall.ps1** - Firewall rule management
- **0103_Change-ComputerName.ps1** - Computer name configuration
- **0104_Install-CA.ps1** - Certificate Authority installation
- **0105_Install-HyperV.ps1** - Hyper-V feature installation
- **0106_Install-WAC.ps1** - Windows Admin Center installation
- **0111_Disable-TCPIP6.ps1** - IPv6 configuration
- **0112_Enable-PXE.ps1** - PXE boot configuration
- **0113_Config-DNS.ps1** - DNS configuration
- **0114_Config-TrustedHosts.ps1** - Trusted hosts configuration

## Usage Instructions

**Run ALL scripts**: Type `all`
**Run specific scripts**: Provide comma-separated 4-digit prefixes (e.g., `0001,0003,0006,0007,0008,0009,0010`)
**Exit**: Type `exit` to quit the script

## Configuration Requirements

### OpenTofu Provider Configuration

Make sure to modify the `main.tf` so it uses your admin credentials and hostname/IP of the host machine if you don't have a customized config.json or choose not to customize:

```hcl
provider "hyperv" {
  user            = "ad\\administrator"
  password        = ""
  host            = "192.168.1.121"
  port            = 5986
  https           = true
  insecure        = true  # This skips SSL validation
  use_ntlm        = true  # Use NTLM as it's enabled on the WinRM service
  tls_server_name = ""
  cacert_path     = ""    # Leave empty if skipping SSL validation
  cert_path       = ""    # Leave empty if skipping SSL validation
  key_path        = ""    # Leave empty if skipping SSL validation
  script_path     = "C:/Temp/terraform_%RAND%.cmd"
  timeout         = "30s"
}

variable "hyperv_host_name" {
  type    = string
  default = "192.168.1.121"
}

variable "hyperv_user" {
  type    = string
  default = "ad\\administrator"
}

variable "hyperv_password" {
  type    = string
  default = ""
}
```

### VHD Configuration

You will also need to modify the VHD configuration to create multiple VHD objects with distinct paths:

```hcl
resource "hyperv_vhd" "control_node_vhd" {
  count = var.number_of_vms

  depends_on = [hyperv_network_switch.Lan]

  # Unique path for each VHD (e.g. ...-0.vhdx, ...-1.vhdx, etc.)
  path = "B:\\hyper-v\\PrimaryControlNode\\PrimaryControlNode-Server2025-${count.index}.vhdx"
  size = 60737421312
}
```

### DVD Drive Configuration

```hcl
dvd_drives {
  controller_number   = "0"
  controller_location = "1"
  path                = "B:\\share\\isos\\2_auto_unattend_en-us_windows_server_2025_updated_feb_2025_x64_dvd_3733c10e.iso"
}
```

## Advanced Features

### Cross-Platform Support

- **Windows, Linux, macOS** deployment capability
- **PowerShell 7.4+** cross-platform compatibility
- **Advanced PowerShell Modules**: PatchManager, LabRunner, BackupManager

### Automation & Maintenance

- **Real-time validation** and error correction
- **CI/CD Integration**: GitHub Actions workflows with comprehensive testing
- **Infrastructure as Code**: OpenTofu/Terraform configurations for lab environments

### Module Usage

```powershell
# Import and use individual modules
Import-Module "./aither-core/modules/PatchManager" -Force
Import-Module "./aither-core/modules/LabRunner" -Force

# Create patches with the new v2.1 workflow
Invoke-PatchWorkflow -PatchDescription "My changes" -CreatePR

# Run lab automation
Start-LabEnvironment -ConfigPath "./configs/lab_config.json"

# Perform maintenance
Invoke-UnifiedMaintenance -Mode "All" -AutoFix
```

## Current Architecture

- **/aither-core/modules/**: 14+ PowerShell modules (PatchManager, LabRunner, etc.)
- **/aither-core/scripts/**: Core automation scripts (0000-0114 series)
- **/configs/**: Configuration files and templates
- **/opentofu/**: Infrastructure as Code configurations
- **/tests/**: Bulletproof testing framework with Pester
- **/.github/workflows/**: CI/CD automation

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🔄 After Initial Setup

After running `aither-core.ps1`, you'll have several options:

### **Quick Usage Examples**

```powershell
# Import AitherCore module
Import-Module "./aither-core/AitherCore.psm1" -Force

# Run automated setup
./aither-core/aither-core.ps1 -Auto -Verbosity detailed

# Run specific modules
./aither-core/aither-core.ps1 -Scripts "LabRunner,BackupManager"

# Development mode
./aither-core/aither-core.ps1 -NonInteractive -WhatIf
```

### **Module Usage**

```powershell
# Import and use individual modules
Import-Module "./aither-core/modules/PatchManager" -Force
Import-Module "./aither-core/modules/LabRunner" -Force

# Create patches with the new v2.1 workflow
Invoke-PatchWorkflow -PatchDescription "My changes" -CreatePR

# Run lab automation
Start-LabEnvironment -ConfigPath "./configs/lab_config.json"

# Perform maintenance
Invoke-UnifiedMaintenance -Mode "All" -AutoFix
```

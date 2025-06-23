# OpenTofu Lab Automation

Cross-platform PowerShell automation framework for OpenTofu/Terraform infrastructure management with comprehensive testing and modular architecture.

## Quick Start - Bootstrap Installation

### 🚀 One-Line Installation

**Bootstrap with kicker-git.ps1** (Main Entry Point):

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/wizzense/opentofu-lab-automation/main/kicker-git.ps1' -OutFile '.\kicker-git.ps1'; .\kicker-git.ps1"
```

**PowerShell 7.x** (Cross-platform):

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -Command "Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/wizzense/opentofu-lab-automation/main/kicker-git.ps1' -OutFile '.\kicker-git.ps1'; .\kicker-git.ps1"
```

[kicker-git.ps1](https://github.com/wizzense/opentofu-lab-automation/blob/main/kicker-git.ps1)

### 📋 Bootstrap Options

The `kicker-git.ps1` script is your **single entry point** for all bootstrap scenarios:

#### **kicker-git.ps1** Features

- ✅ Full CoreApp orchestration integration
- ✅ Cross-platform support (Windows, Linux, macOS)
- ✅ PowerShell 5.1 and 7.x compatibility
- ✅ Self-updating capabilities
- ✅ Comprehensive health checks
- ✅ Advanced error handling and logging
- ✅ Non-interactive mode for automation
- ✅ Enhanced GitHub authentication handling

```powershell
# Download and run with options
.\kicker-git.ps1 -Verbosity detailed -NonInteractive
.\kicker-git.ps1 -ConfigFile "my-config.json" -TargetBranch "develop"
.\kicker-git.ps1 -SkipGitHubAuth -SkipPrerequisites
.\kicker-git.ps1 -WhatIf  # See what would be done
```
.\kicker-git.ps1 -Force -Verbosity detailed
```

#### 3. **Legacy Bootstrap** (`kicker-bootstrap.ps1`)

- ✅ Original bootstrap script
- ✅ Maintained for compatibility
- ⚠️ Limited to original feature set

### 🔧 Manual Installation

If you prefer manual control:

```powershell
# 1. Download the modern bootstrap script
Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/wizzense/opentofu-lab-automation/main/kicker-git.ps1' -OutFile '.\kicker-git.ps1'

# 2. Run with your preferred options
.\kicker-git.ps1

# 3. Available parameters:
#    -ConfigFile      : Custom configuration file
#    -Quiet          : Minimal output
#    -NonInteractive : No prompts (automation-friendly)
#    -Verbosity      : silent|normal|detailed
#    -SkipPrerequisites : Skip auto-installation
#    -TargetBranch   : Git branch to use
#    -LocalPath      : Custom clone location
#    -WhatIf         : Show what would be done
#    -Force          : Force re-clone
```

### ⚡ Quick Examples

```powershell
# Silent automation-friendly setup
.\kicker-git.ps1 -NonInteractive -Verbosity silent

# Development setup with detailed logging
.\kicker-git.ps1 -TargetBranch "develop" -Verbosity detailed

# Custom configuration with specific location
.\kicker-git.ps1 -ConfigFile "prod-config.json" -LocalPath "C:\Labs"

# Test what would happen without making changes
.\kicker-git.ps1 -WhatIf
```

## Environment Setup

The bootstrap script automatically sets up:

- **Environment Variables:**
  - `$env:PROJECT_ROOT` - Project root directory
  - `$env:PWSH_MODULES_PATH` - Module search path

- **Module Import Paths:**

  ```powershell
  Import-Module "$env:PROJECT_ROOT\core-runner\modules\Logging" -Force
  Import-Module "$env:PROJECT_ROOT\core-runner\modules\PatchManager" -Force
  ```

## Project Structure

```
opentofu-lab-automation/
├── core-runner/                    # Main automation framework
│   ├── kicker-bootstrap.ps1       # Legacy bootstrap (being phased out)
│   ├── kicker-bootstrap-clean.ps1 # Clean bootstrap implementation
│   ├── setup-test-env.ps1         # Environment setup script
│   ├── core_app/                  # Core application
│   │   ├── core-runner.ps1        # Main runner script
│   │   ├── default-config.json    # Default configuration
│   │   └── scripts/               # Automation scripts (0000_*.ps1)
│   └── modules/                   # PowerShell modules
│       ├── Logging/               # Centralized logging
│       ├── PatchManager/          # Git operations and patching
│       ├── LabRunner/             # Lab management
│       ├── BackupManager/         # Backup operations
│       ├── DevEnvironment/        # Development setup
│       ├── ParallelExecution/     # Parallel processing
│       ├── ScriptManager/         # Script management
│       ├── TestingFramework/      # Testing utilities
│       └── UnifiedMaintenance/    # Maintenance operations
├── configs/                       # Configuration files
├── docs/                          # Documentation
├── tests/                         # Comprehensive test suite
├── tools/                         # Utility tools
└── opentofu/                      # OpenTofu infrastructure
```

## What the Bootstrap Does

1. **Git Setup**: Checks if command-line Git is installed and in PATH.
   - Installs a minimal version if missing.
   - Updates PATH if installed but not found in PATH.

2. **Configuration**: Downloads and loads default configuration file.
   - Uses `core-runner/core_app/default-config.json` by default
   - Override with `-ConfigFile` parameter

3. **Repository Clone**: Clones this repository to local workspace.
   - Default location: `%TEMP%/opentofu-lab-automation`
   - Configurable via configuration file

4. **Core Runner Execution**: Invokes `core-runner.ps1` from the repository.
   - Loads modules and sets up environment
   - Can be run with parameters for automation

## Essential OpenTofu Setup Scripts

To get OpenTofu working, specify these scripts when `core-runner.ps1` is called:

**Required Scripts: 0006, 0007, 0008, 0009, 0010**

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
# Import core modules
Import-Module "./core-runner/modules/PatchManager"
Import-Module "./core-runner/modules/LabRunner"

# Run lab automation
Invoke-ParallelLabRunner -ConfigPath "./configs/lab_config.yaml"

# Perform maintenance
./scripts/maintenance/unified-maintenance.ps1 -Mode "All" -AutoFix
```

## Project Structure

- **/core-runner/modules/**: PowerShell modules (PatchManager, LabRunner, BackupManager)
- **/core-runner/core_app/scripts/**: Core automation scripts (0000-0114 series)
- **/scripts/**: Additional automation and maintenance scripts
- **/opentofu/**: Infrastructure as Code configurations
- **/tests/**: Pester test files for validation
- **/.github/workflows/**: CI/CD automation
- **/configs/**: Configuration files and templates

## Future Plans

Will probably change repo name to just 'lab-automation'.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🔄 After Initial Bootstrap

After `kicker-git.ps1` completes, you'll be in the project directory with several relaunch options:

### **Quick Relaunch Options** (Choose Your Preference)

```powershell
# Option 1: Generated relaunch script (recommended)
.\Relaunch-CoreApp.ps1           # Auto-generated by kicker-git.ps1

# Option 2: Existing launcher
.\Start-CoreApp.ps1              # Manual CoreApp initialization

# Option 3: Super quick launcher
.\go.ps1                         # Minimal typing required

# Option 4: Quick development setup
.\Quick-Setup.ps1                # Environment + modules
```

### **Manual CoreApp Start**

```powershell
# If you prefer manual control:
Import-Module "./core-runner/core_app/CoreApp.psm1" -Force
Initialize-CoreApplication
```

### **Development Workflow**

```powershell
# After any relaunch script:
Get-CoreModuleStatus             # Check module health
Invoke-UnifiedMaintenance        # Run maintenance
Start-DevEnvironmentSetup        # Setup dev environment
Test-CoreApplicationHealth       # Health check
```

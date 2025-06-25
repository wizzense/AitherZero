# AitherZero Installation Guide

This guide provides detailed installation instructions and troubleshooting for AitherZero across all platforms.

## 🚀 Quick Start

### One-Command Install (Recommended)

**Windows (PowerShell):**
```powershell
$url = (irm "https://api.github.com/repos/wizzense/AitherZero/releases/latest").assets | ? name -like "*windows.zip" | % browser_download_url; iwr $url -OutFile "AitherZero.zip"; Expand-Archive "AitherZero.zip" -Force; $folder = (gci -Directory | ? Name -like "AitherZero*")[0].Name; cd $folder; .\AitherZero.bat
```

**Linux/macOS (Bash):**
```bash
url=$(curl -s https://api.github.com/repos/wizzense/AitherZero/releases/latest | jq -r '.assets[] | select(.name | contains("linux")) | .browser_download_url'); curl -L "$url" -o AitherZero.tar.gz; tar -xzf AitherZero.tar.gz; cd AitherZero-*; ./aitherzero.sh
```

### Manual Installation

1. **Download**: Go to [GitHub Releases](https://github.com/wizzense/AitherZero/releases/latest)
2. **Choose your platform**:
   - **Windows**: `AitherZero-[version]-windows.zip`
   - **Linux**: `AitherZero-[version]-linux.tar.gz`
   - **macOS**: `AitherZero-[version]-macos.tar.gz`
3. **Extract and run**:
   - **Windows**: `AitherZero.bat` or `Start-AitherZero-Windows.ps1`
   - **Linux/macOS**: `./aitherzero.sh` or `pwsh Start-AitherZero.ps1`

## 🛠️ Platform-Specific Instructions

### Windows

#### Recommended Approach
Use `Start-AitherZero-Windows.ps1` - this script automatically handles execution policy and file blocking issues.

#### Alternative Launchers
- **Batch file**: `AitherZero.bat` (works with any Windows version)
- **PowerShell**: `Start-AitherZero.ps1` (requires execution policy setup)

#### Common Windows Issues

**1. "File is blocked" or security warnings:**

- **Automatic Fix**: Use `Start-AitherZero-Windows.ps1` (handles this automatically)
- **Manual Fix**: Right-click the extracted folder → Properties → Unblock → Apply
- **PowerShell Command**:
  ```powershell
  Get-ChildItem -Path . -Recurse | Unblock-File
  ```

**2. PowerShell Execution Policy errors:**

- **Quick Fix**: Use the provided batch file or Windows launcher
- **Permanent Fix**: Run as Administrator:
  ```powershell
  Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
  ```
- **Temporary Fix** (per session):
  ```powershell
  Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
  ```

**3. PowerShell version issues:**

- **Install PowerShell 7** (recommended):
  ```powershell
  winget install Microsoft.PowerShell
  ```
- **Or download**: [PowerShell Releases](https://github.com/PowerShell/PowerShell/releases)

### Linux

#### Prerequisites
```bash
# Install PowerShell 7
sudo snap install powershell --classic
# Or use your distribution's package manager

# Ensure permissions
chmod +x aitherzero.sh
```

#### Ubuntu/Debian
```bash
# Install PowerShell
wget -q https://packages.microsoft.com/config/ubuntu/20.04/packages-microsoft-prod.deb
sudo dpkg -i packages-microsoft-prod.deb
sudo apt-get update
sudo apt-get install -y powershell
```

#### Red Hat/CentOS/Fedora
```bash
# Install PowerShell
sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
sudo curl -o /etc/yum.repos.d/microsoft.repo https://packages.microsoft.com/config/rhel/7/prod.repo
sudo yum install -y powershell
```

### macOS

#### Prerequisites
```bash
# Install PowerShell via Homebrew
brew install --cask powershell

# Or via direct download
# Download from https://github.com/PowerShell/PowerShell/releases
```

#### Permissions
```bash
# Make launcher executable
chmod +x aitherzero.sh

# If you get security warnings
sudo spctl --master-disable  # Temporarily disable Gatekeeper (not recommended)
# Or: System Preferences → Security & Privacy → Allow apps downloaded from: Anywhere
```

## 📋 System Requirements

### Minimum Requirements
- **PowerShell**: 7.0+ (PowerShell 5.1 minimum, but 7.0+ strongly recommended)
- **Operating System**: Windows 10+, Linux (modern distributions), macOS 10.15+
- **Memory**: 512 MB RAM
- **Storage**: 100 MB free space

### Recommended Requirements
- **PowerShell**: 7.4+ (latest stable)
- **Git**: 2.30+ (for repository operations)
- **OpenTofu**: 1.6+ or **Terraform**: 1.0+ (for infrastructure automation)
- **Memory**: 2 GB RAM
- **Storage**: 1 GB free space

### Optional Dependencies
- **Docker**: For containerized lab environments
- **Azure CLI**: For Azure-based infrastructure
- **AWS CLI**: For AWS-based infrastructure
- **GitHub CLI**: For enhanced Git operations

## 🔧 First-Time Setup

### Setup Wizard
```bash
# Run the interactive setup wizard
./Start-AitherZero.ps1 -Setup
```

The setup wizard will:
- Check system requirements
- Install missing dependencies (with permission)
- Configure default settings
- Validate the installation

### Manual Configuration

1. **Check PowerShell version**:
   ```powershell
   $PSVersionTable.PSVersion
   ```

2. **Install Git** (if not already installed):
   - **Windows**: `winget install Git.Git`
   - **Linux**: `sudo apt install git` (Ubuntu) or use your package manager
   - **macOS**: `brew install git`

3. **Install OpenTofu or Terraform**:
   - **OpenTofu**: [Installation Guide](https://opentofu.org/docs/intro/install/)
   - **Terraform**: [Installation Guide](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli)

## 🚨 Troubleshooting

### 🔒 Windows Security Issues (Most Common)

**"File is blocked" or "execution policy" errors:**

1. **✅ Best Solution**: Use `AitherZero.bat` - automatically handles security
2. **🔧 Manual unblock**: Right-click folder → Properties → General → Unblock → Apply → OK
3. **💻 PowerShell fix**:
   ```powershell
   # Unblock all files in the extracted folder
   Get-ChildItem -Recurse | Unblock-File
   
   # Launch with safe execution policy bypass
   pwsh -ExecutionPolicy Bypass -File Start-AitherZero.ps1
   ```

**"Set-ExecutionPolicy" requires Admin privileges:**
- This is expected behavior - use the launchers instead:
  - **Recommended**: `AitherZero.bat` (no admin needed)
  - **Alternative**: `pwsh -ExecutionPolicy Bypass -File Start-AitherZero.ps1`

### ⚡ Launcher Selection Guide

**Windows (in order of preference):**
1. **🏆 `AitherZero.bat`** - Safest, handles all security automatically
2. **🔧 `Start-AitherZero-Windows.ps1`** - PowerShell-native with auto-unblock
3. **🚀 Direct**: `pwsh -ExecutionPolicy Bypass -File Start-AitherZero.ps1`

**Linux/macOS:**
1. **🐧 `./aitherzero.sh`** - Native shell script
2. **🚀 Direct**: `pwsh Start-AitherZero.ps1`

### 🔍 Common Issues

**1. "PowerShell 7 not found":**
```bash
# Windows
winget install Microsoft.PowerShell

# Linux (Ubuntu/Debian)
wget https://aka.ms/install-powershell.sh
sudo bash install-powershell.sh

# macOS
brew install powershell
```

**2. "Command not found" or module errors:**
- Run setup first: `./Start-AitherZero.ps1 -Setup`
- Check versions: `pwsh --version` and `git --version`
- Clear PowerShell cache: `Remove-Module -Name * -Force`

**3. Permission errors:**

**Windows:**
- Use provided launchers (they handle permissions automatically)
- If using direct PowerShell: `pwsh -ExecutionPolicy Bypass -File ...`

**Linux/macOS:**
```bash
# Make scripts executable
chmod +x aitherzero.sh Start-AitherZero.ps1

# If permission denied on system operations, use sudo when prompted
```

**4. Network or download issues:**
- Check internet connection and firewall settings
- Try manual download from [GitHub Releases](https://github.com/wizzense/AitherZero/releases)
- Verify file integrity (check file size matches release info)

### Advanced Troubleshooting

**Enable verbose logging:**
```powershell
./Start-AitherZero.ps1 -Verbosity detailed
```

**Check system compatibility:**
```powershell
./Start-AitherZero.ps1 -SystemCheck
```

**Reset configuration:**
```powershell
./Start-AitherZero.ps1 -ResetConfig
```

### Getting Help

1. **Built-in help**: `./Start-AitherZero.ps1 -Help`
2. **System check**: `./Start-AitherZero.ps1 -Setup`
3. **GitHub Issues**: [Report a problem](https://github.com/wizzense/AitherZero/issues)
4. **GitHub Discussions**: [Ask questions](https://github.com/wizzense/AitherZero/discussions)

## 🏗️ Development Installation

For development work (contributors and advanced users):

```bash
# Clone the full repository
git clone https://github.com/wizzense/AitherZero.git
cd AitherZero

# Run development setup
pwsh -File ./aither-core/aither-core.ps1 -Setup

# Run tests to verify installation
pwsh -File ./tests/Run-BulletproofValidation.ps1 -ValidationLevel Quick
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for detailed development setup.

## 📝 Configuration

### Config File Support

AitherZero supports custom configuration files:

```powershell
# Use custom config
./Start-AitherZero.ps1 -ConfigFile "my-config.json"

# Create config from template
./Start-AitherZero.ps1 -CreateConfig
```

### Environment Variables

Set these environment variables for advanced configuration:

- `AITHERZERO_CONFIG_PATH`: Custom config file location
- `AITHERZERO_LOG_LEVEL`: Logging level (INFO, WARN, ERROR, DEBUG)
- `AITHERZERO_AUTO_UPDATE`: Enable/disable automatic updates
- `AITHERZERO_WORK_DIR`: Custom working directory

## 🔄 Updates

### Automatic Updates
AitherZero can check for updates automatically:

```powershell
./Start-AitherZero.ps1 -CheckUpdates
```

### Manual Updates
1. Download the latest release
2. Extract to a new folder
3. Copy your config files from the old installation
4. Run the new version

---

**Need more help?** Check the [main README](README.md) or [report an issue](https://github.com/wizzense/AitherZero/issues).

# Platform Compatibility Matrix

## Overview

AitherZero is designed to run seamlessly across Windows, Linux, and macOS platforms. This matrix details the compatibility, requirements, and feature availability for each platform.

## Supported Platforms

| Platform | Minimum Version | Recommended Version | Architecture | Status |
|----------|----------------|-------------------|--------------|---------|
| **Windows** | Windows 10 (1809) | Windows 11 22H2+ | x64, ARM64 | ✅ Fully Supported |
| | Windows Server 2016 | Windows Server 2022 | x64 | ✅ Fully Supported |
| **Linux** | Ubuntu 18.04 LTS | Ubuntu 22.04 LTS | x64, ARM64 | ✅ Fully Supported |
| | RHEL/CentOS 7 | RHEL/Rocky 9 | x64 | ✅ Fully Supported |
| | Debian 10 | Debian 12 | x64, ARM64 | ✅ Fully Supported |
| | Alpine 3.12 | Alpine 3.18+ | x64, ARM64 | ✅ Fully Supported |
| **macOS** | macOS 10.14 (Mojave) | macOS 14 (Sonoma) | x64, ARM64 | ✅ Fully Supported |

## PowerShell Version Requirements

| PowerShell Version | Windows | Linux | macOS | Support Level |
|-------------------|---------|--------|--------|---------------|
| 5.1 | ✅ Built-in | ❌ N/A | ❌ N/A | ⚠️ Limited Support |
| 7.0 | ✅ | ✅ | ✅ | ✅ Minimum Required |
| 7.1 | ✅ | ✅ | ✅ | ✅ Fully Supported |
| 7.2 | ✅ | ✅ | ✅ | ✅ Fully Supported |
| 7.3 | ✅ | ✅ | ✅ | ✅ Fully Supported |
| 7.4 | ✅ | ✅ | ✅ | ✅ Recommended |

## Feature Availability Matrix

| Feature | Windows | Linux | macOS | Notes |
|---------|---------|-------|-------|-------|
| **Core Features** |
| AitherZero Core | ✅ | ✅ | ✅ | Full functionality |
| Module System | ✅ | ✅ | ✅ | All modules supported |
| Parallel Execution | ✅ | ✅ | ✅ | Runspace-based |
| Logging System | ✅ | ✅ | ✅ | Cross-platform paths |
| **Package Management** |
| Build-Package.ps1 | ✅ | ✅ | ✅ | Platform-specific packages |
| ZIP Archives | ✅ | ✅ | ✅ | Universal format |
| TAR.GZ Archives | ⚠️ | ✅ | ✅ | Requires tools on Windows |
| MSI Installer | ✅ | ❌ | ❌ | Windows only |
| PKG Installer | ❌ | ❌ | ✅ | macOS only |
| **Launchers** |
| PowerShell Script | ✅ | ✅ | ✅ | Start-AitherZero.ps1 |
| Batch File | ✅ | ❌ | ❌ | AitherZero.bat |
| Shell Script | ❌ | ✅ | ✅ | aitherzero.sh |
| App Bundle | ❌ | ❌ | ✅ | .app format |
| **Git Integration** |
| PatchManager | ✅ | ✅ | ✅ | Full functionality |
| Fork Chain Detection | ✅ | ✅ | ✅ | Dynamic repository detection |
| GitHub CLI | ✅ | ✅ | ✅ | If installed |
| **Infrastructure** |
| OpenTofu/Terraform | ✅ | ✅ | ✅ | Provider-dependent |
| Hyper-V Provider | ✅ | ❌ | ❌ | Windows only |
| Docker Provider | ✅ | ✅ | ✅ | Requires Docker |
| Cloud Providers | ✅ | ✅ | ✅ | Full support |
| **Security Features** |
| SecureCredentials | ✅ | ✅ | ✅ | Platform-specific storage |
| Certificate Handling | ✅ | ✅ | ✅ | OS certificate stores |
| Execution Policies | ✅ | ❌ | ❌ | Windows concept |
| Code Signing | ✅ | ⚠️ | ✅ | Platform-specific |

## Installation Methods

| Method | Windows | Linux | macOS | Description |
|--------|---------|-------|-------|-------------|
| **Direct Download** | ✅ | ✅ | ✅ | ZIP/TAR.GZ from releases |
| **Package Managers** |
| Chocolatey | ✅ | ❌ | ❌ | `choco install aitherzero` |
| Scoop | ✅ | ❌ | ❌ | `scoop install aitherzero` |
| Homebrew | ❌ | ⚠️ | ✅ | `brew install aitherzero` |
| APT | ❌ | ✅ | ❌ | Debian/Ubuntu |
| YUM/DNF | ❌ | ✅ | ❌ | RHEL/Fedora |
| Snap | ⚠️ | ✅ | ⚠️ | `snap install aitherzero` |
| **Installers** |
| MSI | ✅ | ❌ | ❌ | Windows Installer |
| PKG | ❌ | ❌ | ✅ | macOS Installer |
| Script | ✅ | ✅ | ✅ | PowerShell/Shell scripts |

## Path and File System

| Aspect | Windows | Linux | macOS |
|--------|---------|-------|-------|
| **Path Separator** | `\` | `/` | `/` |
| **Temp Directory** | `%TEMP%` | `/tmp` | `/tmp` or `$TMPDIR` |
| **Home Directory** | `%USERPROFILE%` | `$HOME` | `$HOME` |
| **System Install** | `C:\Program Files\` | `/opt/` | `/Applications/` |
| **User Install** | `%APPDATA%` | `~/.local/share/` | `~/Applications/` |
| **Config Location** | `%APPDATA%\AitherZero` | `~/.config/aitherzero` | `~/Library/Application Support/AitherZero` |
| **Case Sensitivity** | No | Yes | Usually No |
| **Max Path Length** | 260 (32,767 with LongPath) | 4096 | 1024 |

## Performance Characteristics

| Operation | Windows | Linux | macOS | Target |
|-----------|---------|-------|-------|---------|
| **Startup Time** | ~500ms | ~300ms | ~400ms | < 1s |
| **Module Load** | ~200ms | ~150ms | ~180ms | < 500ms |
| **Repository Detection** | ~50ms | ~30ms | ~40ms | < 100ms |
| **Package Build** | ~30s | ~25s | ~28s | < 60s |
| **Test Suite (Quick)** | ~45s | ~35s | ~40s | < 60s |

## Known Limitations

### Windows
- Long path support requires Windows 10 1607+ and registry configuration
- Some antivirus software may flag PowerShell scripts
- Execution policy must be configured for script execution

### Linux
- Requires PowerShell Core installation (not included in most distributions)
- Some distributions may have older versions of required tools
- SELinux may require additional configuration

### macOS
- Gatekeeper may block unsigned scripts on first run
- Requires PowerShell Core installation via Homebrew or direct download
- Some features require Full Disk Access permissions

## Testing Coverage

| Test Category | Windows | Linux | macOS |
|---------------|---------|-------|-------|
| Unit Tests | ✅ 100% | ✅ 100% | ✅ 100% |
| Integration Tests | ✅ 100% | ✅ 100% | ✅ 100% |
| Platform Tests | ✅ Full | ✅ Full | ✅ Full |
| Package Tests | ✅ Full | ✅ Full | ✅ Full |
| Deployment Tests | ✅ Full | ✅ Full | ✅ Full |

## Recommended Configurations

### Windows
```powershell
# Enable long path support
Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' -Name 'LongPathsEnabled' -Value 1

# Set execution policy
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Linux
```bash
# Install PowerShell
wget -q https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/packages-microsoft-prod.deb
sudo dpkg -i packages-microsoft-prod.deb
sudo apt-get update
sudo apt-get install -y powershell

# Set permissions
chmod +x aitherzero.sh
```

### macOS
```bash
# Install PowerShell via Homebrew
brew install --cask powershell

# Allow script execution
xattr -d com.apple.quarantine Start-AitherZero.ps1
```

## Support Matrix Legend

- ✅ **Fully Supported**: Feature works without limitations
- ⚠️ **Partial Support**: Feature works with some limitations or requires additional setup
- ❌ **Not Supported**: Feature is not available on this platform
- N/A: Not applicable to this platform
# Environment Configuration System

## Overview

AitherZero provides a comprehensive environment configuration system that allows you to manage system settings across Windows, Linux, and macOS through configuration files and CLI commands. The system can also generate deployment artifacts for automated system provisioning.

## Features

- **OS-Specific Configuration**: Separate config files for Windows, Linux, and macOS
- **Hierarchical Configuration Loading**: Base → OS-specific → Local → Custom
- **Environment Variable Management**: System, User, and Process scopes
- **Windows Features**: Long path support, Developer Mode, registry settings
- **Linux System Configuration**: Kernel parameters, packages, firewall, SSH
- **macOS System Preferences**: Defaults, Homebrew, LaunchAgents
- **Deployment Artifacts**: Generate Unattend.xml, cloud-init, Kickstart, Brewfiles, Dockerfiles
- **CLI Interface**: On-the-fly configuration changes
- **Idempotent**: Safe to run multiple times

## Configuration Files

### File Hierarchy

Configuration files are loaded in the following order (higher priority overrides lower):

1. **config.psd1** - Base configuration (version controlled)
2. **config.windows.psd1** - Windows-specific settings (auto-loaded on Windows)
3. **config.linux.psd1** - Linux-specific settings (auto-loaded on Linux)
4. **config.macos.psd1** - macOS-specific settings (auto-loaded on macOS)
5. **config.local.psd1** - Local overrides (gitignored, create from config.local.template.psd1)
6. **custom.psd1** - Custom config file via `-ConfigFile` parameter

### config.psd1 (Base Configuration)

The base config file includes the `EnvironmentConfiguration` section:

```powershell
@{
    EnvironmentConfiguration = @{
        ApplyOnBootstrap = $true
        ApplyOnStart = $false
        
        Windows = @{
            LongPathSupport = @{
                Enabled = $true
                AutoApply = $true
            }
        }
        
        EnvironmentVariables = @{
            User = @{
                AITHERZERO_PROFILE = 'Developer'
            }
        }
        
        PathConfiguration = @{
            AddToPath = $true
            Paths = @{
                User = @('$HOME/.local/bin')
            }
        }
    }
}
```

### config.windows.psd1 (Windows Settings)

Comprehensive Windows configuration including:

- **Registry Settings**: File system, Explorer, Dock, Performance
- **Windows Features**: WSL, Hyper-V, Containers, OpenSSH
- **Services**: Enable/disable system services
- **Scheduled Tasks**: Disable telemetry tasks
- **Firewall Rules**: SSH, WinRM, RDP
- **Power Settings**: High performance mode
- **Deployment**: Unattend.xml generation settings

Example:

```powershell
@{
    Windows = @{
        Registry = @{
            FileSystem = @{
                LongPathsEnabled = @{
                    Enabled = $true
                    Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem'
                    Name = 'LongPathsEnabled'
                    Value = 1
                }
            }
        }
        
        Features = @{
            Core = @{
                'Microsoft-Windows-Subsystem-Linux' = @{
                    Enabled = $true
                    RequiresRestart = $true
                }
            }
        }
    }
}
```

### config.linux.psd1 (Linux Settings)

Comprehensive Linux configuration including:

- **Kernel Parameters**: sysctl settings for network, filesystem, security
- **Package Management**: Essential packages, repositories
- **Services**: systemd service configuration
- **Firewall**: UFW rules
- **SSH Configuration**: Security hardening
- **Docker**: Daemon configuration
- **Security**: SELinux, AppArmor, fail2ban
- **Deployment**: Cloud-init, Kickstart, Preseed generation

Example:

```powershell
@{
    Linux = @{
        KernelParameters = @{
            AutoApply = $true
            Parameters = @{
                'fs.file-max' = 2097152
                'vm.swappiness' = 10
            }
        }
        
        Packages = @{
            Essential = @(
                'git', 'curl', 'wget', 'vim', 'htop'
            )
        }
    }
}
```

### config.macos.psd1 (macOS Settings)

Comprehensive macOS configuration including:

- **System Preferences**: Finder, Dock, Keyboard, Trackpad defaults
- **Homebrew**: Formulae, Casks, Taps
- **LaunchAgents**: Startup automation
- **Shell Configuration**: zsh, bash profiles
- **Development Tools**: Xcode CLI tools, Git config
- **Deployment**: Brewfile, shell script generation

Example:

```powershell
@{
    macOS = @{
        SystemPreferences = @{
            Finder = @{
                'NSGlobalDomain AppleShowAllExtensions' = @{
                    Value = $true
                    Type = 'bool'
                }
            }
        }
        
        Homebrew = @{
            Formulae = @('git', 'node', 'python@3.11')
            Casks = @('visual-studio-code', 'iterm2', 'docker')
        }
    }
}
```

## CLI Commands

### Environment Configuration

#### Get-AitherEnvironment

Get current environment configuration status.

```powershell
# Get all environment info
Get-AitherEnvironment

# Get Windows-specific info
Get-AitherEnvironment -Category Windows

# Get environment variables
Get-AitherEnvironment -Category EnvironmentVariables
```

#### Set-AitherEnvironment

Apply environment configuration from config files.

```powershell
# Preview changes (dry run)
Set-AitherEnvironment -DryRun

# Apply all configuration
Set-AitherEnvironment

# Apply without prompts
Set-AitherEnvironment -Force

# Apply Windows-specific only
Set-AitherEnvironment -Category Windows
```

#### Set-AitherEnvVariable

Set a single environment variable on-the-fly.

```powershell
# Set user variable
Set-AitherEnvVariable -Name 'MY_VAR' -Value 'test' -Scope User

# Set process variable (current session)
Set-AitherEnvVariable -Name 'DEBUG' -Value '1' -Scope Process -Force

# Set system variable (requires admin)
Set-AitherEnvVariable -Name 'JAVA_HOME' -Value 'C:\Java' -Scope Machine
```

### Deployment Artifacts

#### New-AitherDeploymentArtifact

Generate all deployment artifacts for specified platforms.

```powershell
# Generate all artifacts
New-AitherDeploymentArtifact -Platform All

# Generate Windows artifacts only
New-AitherDeploymentArtifact -Platform Windows

# Generate with custom output path
New-AitherDeploymentArtifact -Platform All -OutputPath ./build/artifacts
```

#### Platform-Specific Artifact Generation

```powershell
# Windows Unattend.xml
New-AitherUnattendXml -ConfigPath ./config.windows.psd1

# macOS Brewfile
New-AitherBrewfile -ConfigPath ./config.macos.psd1
```

## Automation Script

### 0001_Configure-Environment.ps1

The automation script provides an easy way to apply environment configuration.

```powershell
# Apply all configuration
./automation-scripts/0001_Configure-Environment.ps1

# Preview changes
./automation-scripts/0001_Configure-Environment.ps1 -DryRun

# Apply without prompts
./automation-scripts/0001_Configure-Environment.ps1 -Force

# Apply and generate artifacts
./automation-scripts/0001_Configure-Environment.ps1 -GenerateArtifacts

# Apply Windows configuration only
./automation-scripts/0001_Configure-Environment.ps1 -Category Windows
```

## Deployment Artifacts

### Windows

- **Unattend.xml**: Automated Windows installation file
- **Registry Files (.reg)**: Registry settings for import
- **PowerShell DSC**: Desired State Configuration (future)

### Linux

- **Cloud-init**: YAML/JSON configuration for cloud VMs
- **Kickstart**: Automated RHEL/CentOS installation
- **Preseed**: Automated Debian/Ubuntu installation
- **Shell Scripts**: Standalone configuration scripts
- **Dockerfiles**: Container images based on config

### macOS

- **Brewfile**: Homebrew package installation
- **Shell Scripts**: System configuration automation
- **Configuration Profiles (.mobileconfig)**: Settings deployment

## Usage Examples

### Basic Setup

```powershell
# 1. Bootstrap AitherZero (if not already done)
./bootstrap.ps1

# 2. Optionally customize settings
Copy-Item config.local.template.psd1 config.local.psd1
# Edit config.local.psd1 with your preferences

# 3. Apply environment configuration
./automation-scripts/0001_Configure-Environment.ps1

# 4. Verify configuration
Get-AitherEnvironment
```

### Windows Development Environment

```powershell
# Enable development features
Set-AitherEnvironment -Category Windows -Force

# This enables:
# - Long path support (> 260 characters)
# - Shows file extensions
# - Shows hidden files
# - Developer-friendly Explorer settings
```

### Linux Server Setup

```powershell
# Generate cloud-init configuration
New-LinuxCloudInitConfig -ConfigPath ./config.linux.psd1

# Upload cloud-init.yaml to cloud provider
# VM will auto-configure on first boot
```

### macOS Development Setup

```powershell
# Generate Brewfile
New-MacOSBrewfile

# Install all packages
brew bundle install --file=./artifacts/macos/Brewfile
```

### Generate ISO/Deployment Images

```powershell
# Generate all artifacts
New-AitherDeploymentArtifact -Platform All -OutputPath ./iso-build/artifacts

# Windows: Use Unattend.xml in ISO
# Linux: Use cloud-init or Kickstart in ISO
# Docker: Build images from generated Dockerfiles
```

## Integration with Bootstrap

The environment configuration system integrates with the bootstrap process:

```powershell
# Bootstrap applies environment config by default
./bootstrap.ps1

# Skip environment config during bootstrap
./bootstrap.ps1 -SkipEnvironmentConfig

# Apply later manually
./automation-scripts/0001_Configure-Environment.ps1
```

## Security Considerations

- **Sensitive Data**: Never commit passwords or secrets to config files
- **Admin Rights**: System-level changes require Administrator/root privileges
- **Registry Changes**: Windows registry modifications can affect system stability
- **Backup**: Config files should backup registry before changes
- **Firewall**: Be careful with firewall rules in production
- **SSH**: Hardened SSH config may lock you out if misconfigured

## Customization

### Local Overrides

Create `config.local.psd1` for local customizations:

```powershell
@{
    EnvironmentConfiguration = @{
        Windows = @{
            LongPathSupport = @{
                Enabled = $true    # Override base setting
            }
        }
        
        EnvironmentVariables = @{
            User = @{
                MY_CUSTOM_VAR = 'value'
            }
        }
    }
}
```

### Custom Deployment Configs

Create custom config files for different environments:

```powershell
# config.production.psd1
@{
    EnvironmentConfiguration = @{
        Linux = @{
            Firewall = @{
                Enabled = $true
                # Strict firewall for production
            }
        }
    }
}

# Use it
Set-AitherEnvironment -ConfigFile ./config.production.psd1
```

## Troubleshooting

### Module Not Found

```powershell
# Ensure modules are loaded
Import-Module ./AitherZero.psd1 -Force

# Or run bootstrap
./bootstrap.ps1
```

### Permission Denied

```powershell
# Windows: Run PowerShell as Administrator
Start-Process pwsh -Verb RunAs

# Linux/macOS: Use sudo
sudo pwsh ./automation-scripts/0001_Configure-Environment.ps1
```

### Configuration Not Applied

```powershell
# Check current status
Get-AitherEnvironment

# Preview what would be applied
Set-AitherEnvironment -DryRun

# Force apply
Set-AitherEnvironment -Force
```

## Future Enhancements

- ISO generation integration
- Packer template generation
- Terraform/OpenTofu variable files
- Ansible playbook generation
- Windows Group Policy Object (GPO) export
- Docker Compose file generation
- Kubernetes ConfigMap generation

## See Also

- [Configuration System Documentation](../docs/CONFIG-DRIVEN-ARCHITECTURE.md)
- [Bootstrap Guide](../bootstrap.ps1)
- [Deployment Guide](../docs/DEPLOYMENT.md)
- [Infrastructure Automation](../docs/INFRASTRUCTURE.md)

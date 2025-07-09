# AitherZero Quick Start Guide
Generated: 2025-07-09 00:48
Platform: Linux 24.04.2 LTS (Noble Numbat)

## 🚀 Getting Started

### 1. Basic Usage
```powershell
# Interactive mode (recommended for beginners)
./Start-AitherZero.ps1

# Run specific module
./Start-AitherZero.ps1 -Scripts 'LabRunner'

# Automated mode
./Start-AitherZero.ps1 -Auto
```

### 2. Common Tasks

#### Deploy Infrastructure
```powershell
# Initialize OpenTofu provider
Import-Module ./aither-core/modules/OpenTofuProvider
Initialize-OpenTofuProvider

# Deploy a lab
New-LabInfrastructure -ConfigFile ./configs/lab-configs/dev-lab.json
```

#### Manage Patches
```powershell
# Create a patch with PR
Import-Module ./aither-core/modules/PatchManager
Invoke-PatchWorkflow -PatchDescription "Fix issue #123" -PatchOperation {
    # Your changes here
} -CreatePR
```

#### Backup Operations
```powershell
# Run backup
Import-Module ./aither-core/modules/BackupManager
Start-Backup -SourcePath ./important-data -DestinationPath ./backups
```

## 📋 Your Setup Summary

### ✅ What's Ready:
- Configuration Files
- Configuration Review
- Git Installation
- Network Connectivity
- Platform Detection
- PowerShell Version

### 💡 Recommendations:
- Configure Git: git config --global user.name 'Your Name'
- Configure Git: git config --global user.email 'your@email.com'
- Install OpenTofu: https://opentofu.org/docs/intro/install/
## 🔗 Resources

- Documentation: ./docs/
- Examples: ./opentofu/examples/
- Module Help: Get-Help <ModuleName> -Full
- Issues: https://github.com/wizzense/AitherZero/issues

## 🎯 Next Steps

1. Review the generated configuration in:
   ~/.config/aitherzero

2. Try the interactive menu:
   ./Start-AitherZero.ps1

3. Explore available modules:
   Get-Module -ListAvailable -Name *AitherZero*

Happy automating! 🚀

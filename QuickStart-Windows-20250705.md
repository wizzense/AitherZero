# AitherZero Quick Start Guide
Generated: 2025-07-05 08:44
Platform: Windows 10.0.26120.0

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
- Platform Detection
- PowerShell Version
- Git Installation
- Network Connectivity
- Security Settings
- Configuration Files

### 💡 Recommendations:
- Install OpenTofu: https://opentofu.org/docs/intro/install/
## 🔗 Resources

- Documentation: ./docs/
- Examples: ./opentofu/examples/
- Module Help: Get-Help <ModuleName> -Full
- Issues: https://github.com/wizzense/AitherZero/issues

## 🎯 Next Steps

1. Review the generated configuration in:
   C:\Users\alexa\AppData\Roaming\AitherZero

2. Try the interactive menu:
   ./Start-AitherZero.ps1

3. Explore available modules:
   Get-Module -ListAvailable -Name *AitherZero*

Happy automating! 🚀

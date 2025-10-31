# Script Execution Order Guide

This document provides the recommended execution order for AitherZero automation scripts.

## 🎯 Quick Start Sequences

### Minimal Development Environment
```powershell
# Essential tools only
./0001_Ensure-PowerShell7.ps1
./0002_Setup-Directories.ps1
./0207_Install-Git.ps1
./0210_Install-VSCode.ps1
```

### Full Development Environment
```powershell
# Complete developer setup
./0000_Cleanup-Environment.ps1
./0001_Ensure-PowerShell7.ps1
./0002_Setup-Directories.ps1
./0006_Install-ValidationTools.ps1
./0207_Install-Git.ps1
./0206_Install-Python.ps1
./0201_Install-Node.ps1
./0210_Install-VSCode.ps1
./0208_Install-Docker.ps1
./0216_Set-PowerShellProfile.ps1
```

### Infrastructure Lab Setup
```powershell
# For OpenTofu/Terraform infrastructure
./0000_Cleanup-Environment.ps1
./0001_Ensure-PowerShell7.ps1
./0002_Setup-Directories.ps1
./0007_Install-Go.ps1
./0008_Install-OpenTofu.ps1
./0009_Initialize-OpenTofu.ps1
./0105_Install-HyperV.ps1
./0300_Deploy-Infrastructure.ps1
```

## 📋 Complete Execution Order by Stage

### Stage 1: Prepare (0000-0099)
Environment setup and prerequisites

1. **0000_Cleanup-Environment.ps1** - Clean temporary files
2. **0001_Ensure-PowerShell7.ps1** - Install/verify PowerShell 7
3. **0002_Setup-Directories.ps1** - Create project structure
4. **0006_Install-ValidationTools.ps1** - PSScriptAnalyzer, Pester
5. **0007_Install-Go.ps1** - Go programming language
6. **0008_Install-OpenTofu.ps1** - OpenTofu (Terraform)
7. **0009_Initialize-OpenTofu.ps1** - Configure OpenTofu

### Stage 2: Infrastructure (0100-0199)
Core infrastructure components

1. **0100_Configure-System.ps1** - System-wide settings
2. **0104_Install-CertificateAuthority.ps1** - Windows CA
3. **0105_Install-HyperV.ps1** - Virtualization
4. **0106_Install-WSL2.ps1** - Windows Subsystem for Linux
5. **0106_Install-WindowsAdminCenter.ps1** - Windows Admin Center
6. **0112_Enable-PXE.ps1** - PXE boot configuration

### Stage 3: Development (0200-0299)
Development tools and environments

1. **0201_Install-Node.ps1** - Node.js and npm
2. **0204_Install-Poetry.ps1** - Python Poetry
3. **0205_Install-Sysinternals.ps1** - Windows utilities
4. **0206_Install-Python.ps1** - Python
5. **0207_Install-Git.ps1** - Version control
6. **0208_Install-Docker.ps1** - Containerization
7. **0209_Install-7Zip.ps1** - Archive utility
8. **0210_Install-VSCode.ps1** - Code editor
9. **0211_Install-VSBuildTools.ps1** - Build tools
10. **0212_Install-AzureCLI.ps1** - Azure CLI
11. **0213_Install-AWSCLI.ps1** - AWS CLI
12. **0214_Install-Packer.ps1** - Image builder
13. **0215_Install-Chocolatey.ps1** - Package manager
14. **0216_Set-PowerShellProfile.ps1** - PS profile
15. **0217_Install-ClaudeCode.ps1** - AI assistant
16. **0218_Install-GeminiCLI.ps1** - Google AI
17. **0225_Generate-TestCoverage.ps1** - Test generation

### Stage 4: Services (0300-0399)
Service deployment and configuration

1. **0300_Deploy-Infrastructure.ps1** - Deploy with OpenTofu

### Stage 5: Validation (0500-0599)
Testing and verification

1. **0500_Validate-Environment.ps1** - Environment checks
2. **0501_Get-SystemInfo.ps1** - System information

### Stage 6: Maintenance (9000-9999)
Cleanup and maintenance

1. **9999_Reset-Machine.ps1** - System reset/sysprep

## 🔗 Script Dependencies

### Dependency Tree
```
0001_Ensure-PowerShell7.ps1
├── 0000_Cleanup-Environment.ps1
├── 0002_Setup-Directories.ps1
│   ├── 0006_Install-ValidationTools.ps1
│   ├── 0201_Install-Node.ps1
│   │   ├── 0217_Install-ClaudeCode.ps1
│   │   └── 0218_Install-GeminiCLI.ps1
│   ├── 0206_Install-Python.ps1
│   │   └── 0204_Install-Poetry.ps1
│   ├── 0207_Install-Git.ps1
│   └── 0008_Install-OpenTofu.ps1
│       ├── 0007_Install-Go.ps1
│       └── 0009_Initialize-OpenTofu.ps1
│           └── 0300_Deploy-Infrastructure.ps1
```

### Key Dependencies
- **PowerShell 7**: Required by all scripts (except 0001)
- **Node.js**: Required by Claude Code, Gemini CLI
- **Python**: Required by Poetry, some cloud tools
- **Go**: Required by OpenTofu
- **Git**: Recommended before most development tools

## 🚀 Execution Examples

### Using Configuration File
```powershell
# Single script with config
$config = Get-Content -Path "./config.json" | ConvertFrom-Json -AsHashtable
./0207_Install-Git.ps1 -Configuration $config

# Multiple scripts
$scripts = @(
    "0001_Ensure-PowerShell7.ps1",
    "0002_Setup-Directories.ps1",
    "0207_Install-Git.ps1"
)
foreach ($script in $scripts) {
    & "./$script" -Configuration $config
}
```

### WhatIf Mode
```powershell
# Test what would happen
./0105_Install-HyperV.ps1 -Configuration $config -WhatIf
```

### Parallel Execution (Independent Scripts)
```powershell
# These can run in parallel as they have no dependencies on each other
$jobs = @(
    { ./0205_Install-Sysinternals.ps1 -Configuration $config },
    { ./0209_Install-7Zip.ps1 -Configuration $config },
    { ./0215_Install-Chocolatey.ps1 -Configuration $config }
) | ForEach-Object { Start-Job -ScriptBlock $_ }

# Wait for all jobs
$jobs | Wait-Job | Receive-Job
```

## 📊 Platform Compatibility

| Script | Windows | Linux | macOS |
|--------|---------|-------|-------|
| PowerShell 7 | ✅ | ✅ | ✅ |
| Git | ✅ | ✅ | ✅ |
| Node.js | ✅ | ✅ | ✅ |
| Python | ✅ | ✅ | ✅ |
| Docker | ✅ | ✅ | ✅ |
| VSCode | ✅ | ✅ | ✅ |
| Hyper-V | ✅ | ❌ | ❌ |
| WSL2 | ✅ | ❌ | ❌ |
| Certificate Authority | ✅ | ❌ | ❌ |

## 🔄 Restart Requirements

Some scripts require system restart:
- **0105_Install-HyperV.ps1** - Returns exit code 3010
- **0100_Configure-System.ps1** - When changing computer name
- **9999_Reset-Machine.ps1** - Always restarts/shuts down

## 💡 Best Practices

1. **Always run PowerShell 7 script first** if not already on PS7
2. **Use configuration file** for consistent deployments
3. **Run validation scripts** after major installations
4. **Check exit codes** - 0 = success, 1 = error, 3010 = restart required
5. **Use WhatIf** for testing before actual execution
6. **Review logs** in the configured logging directory

## 🛠️ Troubleshooting

If scripts fail:
1. Check PowerShell version: `$PSVersionTable.PSVersion`
2. Verify administrator privileges (for system scripts)
3. Review script logs
4. Ensure dependencies are met
5. Check network connectivity for downloads
6. Verify configuration file syntax
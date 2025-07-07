# AitherCore Scripts Directory

## Directory Structure

The `scripts` directory contains numbered automation scripts that provide systematic setup, configuration, and management capabilities for the AitherZero platform. Scripts follow a numeric naming convention for ordered execution.

```
scripts/
├── 0000-0099/              # Core Setup & Cleanup
├── 0100-0199/              # System Configuration
├── 0200-0299/              # Software Installation
├── 9999/                   # Special Operations
└── Invoke-CoreApplication.ps1  # Script orchestrator
```

## Overview

The scripts system provides:

- **Ordered Execution**: Numeric prefixes ensure proper sequencing
- **Modular Operations**: Each script handles a specific task
- **Idempotent Design**: Scripts can be run multiple times safely
- **Cross-Platform Support**: Works on Windows, Linux, and macOS
- **Comprehensive Logging**: All operations are logged for audit

### Script Categories

1. **0000-0099**: Foundation and cleanup operations
2. **0100-0199**: System and network configuration
3. **0200-0299**: Software and tool installation
4. **9999**: Special operations and system reset

## Core Components

### Foundation Scripts (0000-0099)

| Script | Purpose | Platform |
|--------|---------|----------|
| 0000_Cleanup-Files.ps1 | Clean temporary files and logs | All |
| 0001_Reset-Git.ps1 | Reset git repository to clean state | All |
| 0002_Setup-Directories.ps1 | Create required directory structure | All |
| 0006_Install-ValidationTools.ps1 | Install testing and validation tools | All |
| 0007_Install-Go.ps1 | Install Go programming language | All |
| 0008_Install-OpenTofu.ps1 | Install OpenTofu/Terraform | All |
| 0009_Initialize-OpenTofu.ps1 | Initialize OpenTofu providers | All |
| 0010_Prepare-HyperVProvider.ps1 | Setup Hyper-V provider | Windows |

### System Configuration (0100-0199)

| Script | Purpose | Platform |
|--------|---------|----------|
| 0100_Enable-WinRM.ps1 | Enable Windows Remote Management | Windows |
| 0101_Enable-RemoteDesktop.ps1 | Configure Remote Desktop | Windows |
| 0102_Configure-Firewall.ps1 | Setup firewall rules | Windows |
| 0103_Change-ComputerName.ps1 | Set computer name | Windows |
| 0104_Install-CA.ps1 | Install Certificate Authority | Windows |
| 0105_Install-HyperV.ps1 | Install Hyper-V role | Windows |
| 0106_Install-WAC.ps1 | Install Windows Admin Center | Windows |
| 0111_Disable-TCPIP6.ps1 | Disable IPv6 | Windows |
| 0112_Enable-PXE.ps1 | Enable PXE boot services | Windows |
| 0113_Config-DNS.ps1 | Configure DNS settings | Windows |
| 0114_Config-TrustedHosts.ps1 | Setup trusted hosts | Windows |

### Software Installation (0200-0299)

| Script | Purpose | Platform |
|--------|---------|----------|
| 0200_Get-SystemInfo.ps1 | Gather system information | All |
| 0201_Install-NodeCore.ps1 | Install Node.js core | All |
| 0202_Install-NodeGlobalPackages.ps1 | Install npm global packages | All |
| 0203_Install-npm.ps1 | Install npm package manager | All |
| 0204_Install-Poetry.ps1 | Install Python Poetry | All |
| 0205_Install-Sysinternals.ps1 | Install Sysinternals Suite | Windows |
| 0206_Install-Python.ps1 | Install Python | All |
| 0207_Install-Git.ps1 | Install Git version control | All |
| 0208_Install-DockerDesktop.ps1 | Install Docker Desktop | Windows/macOS |
| 0209_Install-7Zip.ps1 | Install 7-Zip | Windows |
| 0210_Install-VSCode.ps1 | Install Visual Studio Code | All |
| 0211_Install-VSBuildTools.ps1 | Install VS Build Tools | Windows |
| 0212_Install-AzureCLI.ps1 | Install Azure CLI | All |
| 0213_Install-AWSCLI.ps1 | Install AWS CLI | All |
| 0214_Install-Packer.ps1 | Install HashiCorp Packer | All |
| 0215_Install-Chocolatey.ps1 | Install Chocolatey | Windows |
| 0216_Set-LabProfile.ps1 | Configure lab PowerShell profile | All |
| 0217_Install-ClaudeCode.ps1 | Install Claude Code CLI | All |
| 0218_Install-GeminiCLI.ps1 | Install Gemini CLI | All |
| 0219_Install-Codex.ps1 | Install Codex CLI | All |
| 0220_Setup-ClaudeRequirements.ps1 | Setup Claude requirements | All |
| 0225_Generate-TestCoverage.ps1 | Generate test coverage reports | All |

### Special Operations (9999)

| Script | Purpose | Platform |
|--------|---------|----------|
| 9999_Reset-Machine.ps1 | Factory reset machine state | All |

### Orchestration

| Script | Purpose |
|--------|---------|
| Invoke-CoreApplication.ps1 | Main script execution orchestrator |

## Script Execution Model

### Individual Script Structure
```powershell
#Requires -Version 7.0
[CmdletBinding()]
param(
    [switch]$Force,
    [switch]$SkipValidation
)

# Script metadata
$scriptInfo = @{
    Name = "Install-Something"
    Description = "Installs something important"
    Version = "1.0.0"
    RequiresElevation = $true
    Platform = @("Windows", "Linux")
}

# Validation
if (-not $SkipValidation) {
    # Check prerequisites
}

# Main execution
try {
    Write-CustomLog -Level 'Info' -Message "Starting $($scriptInfo.Name)"
    
    # Core logic here
    
    Write-CustomLog -Level 'Success' -Message "Completed $($scriptInfo.Name)"
}
catch {
    Write-CustomLog -Level 'Error' -Message $_.Exception.Message
    throw
}
```

### Orchestrator Pattern
```powershell
# Invoke-CoreApplication.ps1 orchestrates script execution
$scripts = Get-ChildItem -Path ".\scripts" -Filter "*.ps1" | 
    Where-Object { $_.Name -match '^\d{4}_' } |
    Sort-Object Name

foreach ($script in $scripts) {
    Invoke-ScriptExecution -Path $script.FullName -Parameters $parameters
}
```

## Usage

### Running Individual Scripts
```powershell
# Run a specific script
.\scripts\0207_Install-Git.ps1 -Force

# Run with validation skip
.\scripts\0210_Install-VSCode.ps1 -SkipValidation
```

### Running Script Collections
```powershell
# Run all foundation scripts
Get-ChildItem ".\scripts\00*.ps1" | ForEach-Object {
    & $_.FullName
}

# Run installation scripts for development
$devScripts = @(
    "0206_Install-Python.ps1",
    "0207_Install-Git.ps1", 
    "0210_Install-VSCode.ps1",
    "0217_Install-ClaudeCode.ps1"
)
$devScripts | ForEach-Object {
    & ".\scripts\$_"
}
```

### Using the Orchestrator
```powershell
# Run all scripts in order
.\scripts\Invoke-CoreApplication.ps1 -RunAll

# Run specific category
.\scripts\Invoke-CoreApplication.ps1 -Category "Installation"

# Dry run to see what would execute
.\scripts\Invoke-CoreApplication.ps1 -WhatIf
```

## Development Guidelines

### Script Naming Convention
- **Format**: `NNNN_Verb-Noun.ps1`
- **NNNN**: 4-digit number for ordering
- **Verb**: PowerShell approved verb
- **Noun**: Descriptive noun

### Numbering Scheme
```
0000-0099: Core setup and cleanup
0100-0199: System configuration
0200-0299: Software installation
0300-0399: Network configuration
0400-0499: Security configuration
0500-0599: Development tools
0600-0699: Monitoring setup
0700-0799: Integration setup
0800-0899: Testing tools
0900-0999: Utilities
9000-9999: Special operations
```

### Script Requirements

1. **Idempotency**: Must be safe to run multiple times
2. **Logging**: Use Write-CustomLog for all output
3. **Error Handling**: Comprehensive try-catch blocks
4. **Validation**: Check prerequisites before execution
5. **Documentation**: Include synopsis and examples

### Cross-Platform Considerations
```powershell
# Platform detection
if ($IsWindows) {
    # Windows-specific logic
} elseif ($IsLinux) {
    # Linux-specific logic
} elseif ($IsMacOS) {
    # macOS-specific logic
}

# Path handling
$configPath = Join-Path $PSScriptRoot "config" "settings.json"

# Command availability
if (Get-Command "docker" -ErrorAction SilentlyContinue) {
    # Docker is available
}
```

### Error Handling Pattern
```powershell
function Install-Component {
    try {
        # Pre-flight checks
        if (-not (Test-Prerequisites)) {
            throw "Prerequisites not met"
        }
        
        # Main operation
        $result = Start-Installation
        
        # Validation
        if (-not (Test-Installation)) {
            throw "Installation validation failed"
        }
    }
    catch {
        Write-CustomLog -Level 'Error' -Message "Failed to install: $_"
        
        # Cleanup on failure
        Remove-PartialInstallation -ErrorAction SilentlyContinue
        
        throw
    }
}
```

## Best Practices

### 1. Prerequisite Checking
```powershell
function Test-Prerequisites {
    $prereqs = @{
        'PowerShell7' = $PSVersionTable.PSVersion.Major -ge 7
        'DotNet' = Get-Command 'dotnet' -ErrorAction SilentlyContinue
        'AdminRights' = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    
    $missing = $prereqs.GetEnumerator() | Where-Object { -not $_.Value }
    if ($missing) {
        throw "Missing prerequisites: $($missing.Key -join ', ')"
    }
}
```

### 2. Progress Reporting
```powershell
$steps = @(
    "Downloading package",
    "Extracting files",
    "Installing components",
    "Configuring settings",
    "Running tests"
)

for ($i = 0; $i -lt $steps.Count; $i++) {
    Write-Progress -Activity "Installation" `
                  -Status $steps[$i] `
                  -PercentComplete (($i / $steps.Count) * 100)
    
    # Perform step
}
```

### 3. Rollback Support
```powershell
$rollbackActions = @()

try {
    # Action 1
    Copy-Item $source $destination
    $rollbackActions += { Remove-Item $destination -Force }
    
    # Action 2
    New-Item -Path $path -ItemType Directory
    $rollbackActions += { Remove-Item $path -Recurse -Force }
    
    # If we get here, success
}
catch {
    # Rollback in reverse order
    $rollbackActions | ForEach-Object { & $_ }
    throw
}
```

### 4. Configuration Management
```powershell
# Load script-specific config
$configFile = $PSScriptRoot -replace '\.ps1$', '.json'
if (Test-Path $configFile) {
    $config = Get-Content $configFile | ConvertFrom-Json
} else {
    $config = @{
        DefaultUrl = "https://example.com/download"
        InstallPath = "$env:ProgramFiles\Tool"
        Version = "latest"
    }
}
```

## Testing Scripts

### Unit Testing
```powershell
Describe "Install-Git" {
    It "Should detect existing Git installation" {
        Mock Get-Command { return $true } -ParameterFilter { $Name -eq 'git' }
        
        $result = Test-GitInstalled
        $result | Should -Be $true
    }
    
    It "Should handle download failures gracefully" {
        Mock Invoke-WebRequest { throw "Network error" }
        
        { Install-Git } | Should -Throw "Failed to download"
    }
}
```

### Integration Testing
```powershell
# Test script execution in isolated environment
$container = New-TestContainer -Image "mcr.microsoft.com/powershell"
$result = Invoke-Command -Container $container -ScriptBlock {
    & /scripts/0207_Install-Git.ps1
}

$result.ExitCode | Should -Be 0
```

## Maintenance

### Version Management
- Scripts include version in metadata
- Changes tracked in git history
- Breaking changes require new script number

### Deprecation Process
1. Mark script with deprecation warning
2. Create replacement script
3. Update documentation
4. Remove after grace period

### Performance Optimization
- Cache downloaded files
- Parallelize independent operations
- Skip unnecessary validations with flags
- Use native tools when available

## Security Considerations

1. **Validation**: Always validate downloaded files
2. **Permissions**: Check and request elevation as needed
3. **Secrets**: Never hardcode credentials
4. **Sources**: Use official download sources
5. **Logging**: Don't log sensitive information

## Troubleshooting

### Common Issues

1. **Permission Denied**
   - Run as administrator/sudo
   - Check file system permissions
   - Verify execution policy

2. **Network Failures**
   - Check proxy settings
   - Verify DNS resolution
   - Test connectivity to sources

3. **Path Issues**
   - Use full paths
   - Check environment variables
   - Verify working directory

### Debug Mode
```powershell
# Enable debug output
$DebugPreference = 'Continue'

# Run script with verbose output
.\scripts\0210_Install-VSCode.ps1 -Verbose -Debug

# Trace execution
Set-PSDebug -Trace 1
```
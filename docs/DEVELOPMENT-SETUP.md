# AitherZero Development Environment Setup

## Quick Start

### 1. One-Time Setup

```bash
# Clone the repository
git clone https://github.com/yourusername/AitherZero.git
cd AitherZero

# Run bootstrap (installs dependencies and sets up environment)
./bootstrap.ps1 -AutoInstallDeps

# Make environment persistent (adds to PowerShell profile)
./Initialize-AitherEnvironment.ps1 -Persistent
```

### 2. Daily Development

When you start working on AitherZero:

```bash
cd /path/to/AitherZero

# Option 1: Source the project profile
. ./.azprofile.ps1

# Option 2: Just run any command - it auto-loads!
./az.ps1 0511  # Show dashboard
```

## Environment Features

### Auto-Loading Modules

All AitherZero modules are automatically available:
- No need for `Import-Module`
- All functions are globally accessible
- Works cross-platform (Windows/Linux/macOS)

### Command Shortcuts

| Command | Description | Example |
|---------|-------------|---------|
| `az <num>` | Run automation script by number | `az 0402` |
| `seq <pattern>` | Run orchestration sequence | `seq 0400-0406` |
| `./aither` | Launch interactive UI | `./aither` |

### Available Functions

After environment initialization, these functions are globally available:

```powershell
# Logging
Write-CustomLog -Message "Test" -Level Information
Enable-AuditLogging
Get-AuditLogs

# Testing
New-TestReport -Format HTML
Invoke-TestSuite -Profile Quick

# UI
Show-UIMenu -Title "Options" -Items @("One", "Two")
Show-UIProgress -Activity "Loading" -PercentComplete 50

# Configuration
Get-AitherConfiguration
Get-ConfigurationValue -Path "Core.Version"
```

## AI Agent-Friendly Features

### 1. Predictable Paths
- All scripts in `automation-scripts/` with numeric prefixes
- All modules in `domains/<category>/<ModuleName>.psm1`
- Configuration always at `config.json`

### 2. Self-Documenting
```powershell
# Get help for any command
Get-Help Write-CustomLog -Full

# List all available AitherZero commands
Get-Command -Module @(Get-Module -Name "*" | Where-Object { $_.Path -like "*AitherZero*" })
```

### 3. Standardized Patterns
- All scripts support `-WhatIf` for dry runs
- All functions have comment-based help
- Consistent parameter naming across modules

## VS Code Integration

Add to `.vscode/settings.json`:

```json
{
    "terminal.integrated.profiles.windows": {
        "AitherZero PowerShell": {
            "source": "PowerShell",
            "args": ["-NoExit", "-File", "${workspaceFolder}/.azprofile.ps1"]
        }
    },
    "terminal.integrated.defaultProfile.windows": "AitherZero PowerShell",
    
    "terminal.integrated.profiles.linux": {
        "AitherZero PowerShell": {
            "path": "pwsh",
            "args": ["-NoExit", "-File", "${workspaceFolder}/.azprofile.ps1"]
        }
    },
    "terminal.integrated.defaultProfile.linux": "AitherZero PowerShell"
}
```

## Troubleshooting

### Modules Not Loading

```powershell
# Force reload
./Initialize-AitherEnvironment.ps1 -Force

# Check what's loaded
Get-Module | Where-Object { $_.Path -like "*AitherZero*" }
```

### Command Not Found

```powershell
# Verify environment is initialized
$env:AITHERZERO_INITIALIZED

# Check PATH
$env:PATH -split [IO.Path]::PathSeparator | Select-String "AitherZero"

# Manually run initialization
. ./Initialize-AitherEnvironment.ps1
```

### Cross-Platform Issues

```powershell
# Check platform
$PSVersionTable.Platform

# Verify PowerShell version (must be 7+)
$PSVersionTable.PSVersion
```

## Best Practices for AI Agents

1. **Always use absolute paths from AITHERZERO_ROOT**
   ```powershell
   $scriptPath = Join-Path $env:AITHERZERO_ROOT "automation-scripts/0402_Run-UnitTests.ps1"
   ```

2. **Check if environment is loaded**
   ```powershell
   if (-not $env:AITHERZERO_INITIALIZED) {
       & "$env:AITHERZERO_ROOT/Initialize-AitherEnvironment.ps1"
   }
   ```

3. **Use the az wrapper for running scripts**
   ```powershell
   # Instead of: ./automation-scripts/0402_Run-UnitTests.ps1
   # Use: az 0402
   ```

4. **Log all actions for audit trail**
   ```powershell
   Write-CustomLog -Message "Starting operation X" -Level Information -Source "AIAgent"
   ```
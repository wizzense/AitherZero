# Config-Driven Architecture Guide

## Overview

AitherZero Core is **100% config-driven**. The `config.psd1` manifest is the single source of truth that determines:
- Available CLI modes
- Enabled features
- Script inventory
- Extension configuration
- UI capabilities

## Architecture Flow

```
┌──────────────────────────────────────────────────────────────┐
│                     config.psd1                              │
│  ┌────────────────────────────────────────────────────────┐  │
│  │ Manifest                                               │  │
│  │  ├─ Version                                            │  │
│  │  ├─ SupportedModes: [Run, Test, Deploy...]            │  │
│  │  └─ ScriptInventory                                    │  │
│  │                                                         │  │
│  │ Features                                               │  │
│  │  ├─ Git: Enabled                                       │  │
│  │  ├─ Docker: Enabled                                    │  │
│  │  └─ Node: Disabled                                     │  │
│  │                                                         │  │
│  │ Extensions                                             │  │
│  │  └─ EnabledExtensions: [ExampleExtension]             │  │
│  └────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────┘
                          │
                          ↓
           ┌──────────────────────────────┐
           │   ConfigManager.psm1         │
           │  ├─ Load config              │
           │  ├─ Extract capabilities     │
           │  └─ Build feature map        │
           └──────────────────────────────┘
                          │
                ┌─────────┼─────────┐
                │                   │
                ↓                   ↓
    ┌──────────────────┐  ┌──────────────────┐
    │ CLI              │  │ Interactive UI   │
    │  ├─ Modes        │  │  ├─ Menu items   │
    │  ├─ Parameters   │  │  ├─ Options      │
    │  └─ Validation   │  │  └─ Navigation   │
    └──────────────────┘  └──────────────────┘
                │                   │
                └─────────┬─────────┘
                          ↓
                ┌──────────────────┐
                │  CommandParser   │
                │   └─ Execute     │
                └──────────────────┘
```

## Example: How Modes Work

### 1. Config Defines Modes

```powershell
# config.psd1
@{
    Manifest = @{
        SupportedModes = @('Interactive', 'Run', 'Test', 'Deploy')
    }
}
```

### 2. ConfigManager Extracts

```powershell
Initialize-ConfigManager
$capabilities = Get-ManifestCapabilities

# $capabilities.Modes = ['Interactive', 'Run', 'Test', 'Deploy']
```

### 3. UI Auto-Generates Menu

```
╔════════════════════════════════════════╗
║         Select Mode                    ║
╚════════════════════════════════════════╝

 [1] 🎯 Run
 [2] ✅ Test  
 [3] 🚀 Deploy
 [4] 🎮 Interactive

Menu automatically generated from config!
```

### 4. CLI Validates

```powershell
# CommandParser uses same capabilities
Parse-AitherCommand "-Mode Run"  # ✅ Valid
Parse-AitherCommand "-Mode Build" # ❌ Not in config
```

## Example: How Extensions Work

### 1. Extension Manifest

```powershell
# ExampleExtension.extension.psd1
@{
    Name = 'ExampleExtension'
    CLIModes = @(
        @{ Name = 'Example'; Handler = 'Invoke-ExampleMode' }
    )
}
```

### 2. Config Enables Extension

```powershell
# config.psd1
@{
    Extensions = @{
        EnabledExtensions = @('ExampleExtension')
    }
}
```

### 3. Extension Loads

```powershell
Initialize-ExtensionSystem
# ExampleExtension loaded
# Modes registered: ['Example']
```

### 4. UI Includes Extension Mode

```
╔════════════════════════════════════════╗
║         Select Mode                    ║
╚════════════════════════════════════════╝

 [1] 🎯 Run
 [2] ✅ Test
 [3] 🚀 Deploy
 [4] 📦 Example          ← From extension!

Extension modes seamlessly integrated!
```

## Config Switching

### Multiple Configs

```
project/
├── config.psd1          # Default (Standard profile)
├── config.example.psd1  # Example config
├── config.dev.psd1      # Developer profile
├── config.ci.psd1       # CI/CD profile
└── configs/
    ├── production.psd1  # Production
    └── staging.psd1     # Staging
```

### Switch Easily

```powershell
# Interactive selector
Show-ConfigurationSelector

# Output:
# ╔════════════════════════════════════════╗
# ║    Configuration Selector              ║
# ╚════════════════════════════════════════╝
#
# Current: config (Standard, Development)
#
# Available:
#  ► [1] config (current)
#    [2] config.example
#    [3] config.dev
#    [4] configs/production
#
# Select: 3

# Direct switch
Switch-Configuration -ConfigName "config.dev"

# ✅ Switched to config.dev
#    Profile: Developer
#    Environment: Development
```

### Config Affects Everything

**config.psd1** (Standard Profile):
```powershell
@{
    Features = @{
        Git = @{ Enabled = $true }
        Docker = @{ Enabled = $false }
    }
}
```

**config.dev.psd1** (Developer Profile):
```powershell
@{
    Features = @{
        Git = @{ Enabled = $true }
        Docker = @{ Enabled = $true }  # ← Different!
    }
}
```

**Result:**
- Standard: Docker features hidden in UI
- Developer: Docker features visible in UI

## Config-Driven UI Example

### Before (Hardcoded):
```powershell
# ❌ Bad: Hardcoded in UI
function Show-Menu {
    $items = @(
        "Run Script"
        "Test Code"
        "Deploy App"
    )
}
```

### After (Config-Driven):
```powershell
# ✅ Good: Driven by config
function Show-Menu {
    $capabilities = Get-ManifestCapabilities
    $items = $capabilities.Modes | ForEach-Object {
        Get-ModeDisplayInfo $_
    }
}
```

## Benefits

### 1. Single Source of Truth
- Edit `config.psd1` → Everything updates
- No scattered hardcoded values
- Consistent across CLI/UI

### 2. Easy Customization
```powershell
# Want different profile?
Switch-Configuration -ConfigName "config.full"

# Want to edit?
Edit-Configuration

# Want new environment?
Export-ConfigurationTemplate -OutputPath "./config.prod.psd1"
```

### 3. Extensibility
```powershell
# Add extension → Config updates
Import-Extension -Name "MyExtension"

# Extension modes appear in UI automatically
./Start-AitherZero.ps1 -Mode MyExtensionMode
```

### 4. Environment-Specific
```bash
# Development
./Start-AitherZero.ps1 -ConfigPath config.dev.psd1

# CI/CD
./Start-AitherZero.ps1 -ConfigPath config.ci.psd1

# Production
./Start-AitherZero.ps1 -ConfigPath config.prod.psd1
```

## API Reference

### Configuration Management

```powershell
# Initialize
Initialize-ConfigManager

# Discover configs
Discover-Configurations -ProjectRoot $PWD

# Get available
Get-AvailableConfigurations

# Get current
Get-CurrentConfiguration -Full

# Switch
Switch-Configuration -ConfigName "config.dev"

# Edit
Edit-Configuration -ConfigName "config.dev" -Editor "code"

# Validate
Test-ConfigurationValidity -Path "./config.psd1"

# Export template
Export-ConfigurationTemplate -OutputPath "./config.new.psd1" -Profile "Full"
```

### Capability Extraction

```powershell
# Get all capabilities
Get-ManifestCapabilities

# Get specific type
Get-ManifestCapabilities -Type Modes
Get-ManifestCapabilities -Type Features
Get-ManifestCapabilities -Type Scripts
Get-ManifestCapabilities -Type Extensions
```

### Interactive UI

```powershell
# Show config selector
Show-ConfigurationSelector

# Shows:
# - Current config
# - Available configs with profiles
# - Interactive selection
# - Reload option
```

## Real-World Example

### Scenario: Different Environments

**Development (config.dev.psd1):**
```powershell
@{
    Core = @{
        Profile = 'Developer'
        Environment = 'Development'
    }
    Features = @{
        Git = @{ Enabled = $true }
        Docker = @{ Enabled = $true }
        Kubernetes = @{ Enabled = $false }
        DebugMode = @{ Enabled = $true }
    }
    Automation = @{
        MaxConcurrency = 2
        Verbose = $true
    }
}
```

**Production (config.prod.psd1):**
```powershell
@{
    Core = @{
        Profile = 'Minimal'
        Environment = 'Production'
    }
    Features = @{
        Git = @{ Enabled = $true }
        Docker = @{ Enabled = $true }
        Kubernetes = @{ Enabled = $true }
        DebugMode = @{ Enabled = $false }
    }
    Automation = @{
        MaxConcurrency = 8
        Verbose = $false
    }
}
```

**Usage:**
```bash
# Development - more features, verbose
./Start-AitherZero.ps1 -ConfigPath config.dev.psd1

# Production - minimal, optimized
./Start-AitherZero.ps1 -ConfigPath config.prod.psd1
```

UI automatically adapts to show/hide features based on config!

## Summary

✅ **Config-driven** - `config.psd1` controls everything  
✅ **Easy switching** - Multiple configs, easy switch  
✅ **Auto-generated UI** - Menu from manifest  
✅ **Extensible** - Extensions integrate seamlessly  
✅ **Environment-specific** - Different configs per environment  
✅ **No hardcoding** - All values from config  

**The config.psd1 manifest IS the system definition!**

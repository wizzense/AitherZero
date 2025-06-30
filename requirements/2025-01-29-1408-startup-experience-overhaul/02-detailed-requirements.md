# Phase 2: Detailed Requirements Analysis

## Summary of Discovery Answers

1. **Configuration UI Integration**: YES - But default to non-interactive mode, interactive only with flags
2. **Module Discovery Display**: YES - With intelligent context-aware menus and submenus
3. **Configuration Persistence**: YES - With local storage and GitHub repo integration
4. **Terminal UI Enhancement**: YES - Rich terminal UI with navigation
5. **Module Preloading**: NO - Load on-demand for fast startup

## Core Requirements

### 1. Startup Mode Control
- **Default behavior**: Non-interactive/CI mode that consumes existing configurations
- **Interactive mode**: Triggered by specific flags (e.g., `-Interactive`, `-Setup`)
- **Quickstart commands**: Should automatically use interactive flags

### 2. Configuration Management System
- **Visibility**: Show current configuration with syntax highlighting
- **Editing**: In-line configuration editor with validation
- **Profiles**: Named configuration profiles with quick switching
- **Storage**:
  - Local profile storage in `~/.aitherzero/profiles/`
  - GitHub integration for backup/sharing
  - Support for creating new config repos
- **Import/Export**: JSON, YAML, and environment variable formats

### 3. Intelligent Module Discovery
- **Auto-discovery**: Scan all modules and their public functions
- **Context-aware menus**:
  - Group modules by category (Infrastructure, Development, Security, etc.)
  - Show module descriptions and dependencies
  - Display function signatures and examples
- **Submenu navigation**:
  - Module → Functions → Parameters
  - Search/filter capabilities
  - Recently used functions
- **Smart suggestions**: Based on current context and previous usage

### 4. Rich Terminal UI Framework
- **Components needed**:
  - Menu system with arrow key navigation
  - Multi-select lists for batch operations
  - Progress bars for long operations
  - Syntax-highlighted code display
  - Form inputs with validation
- **Features**:
  - Keyboard shortcuts (Ctrl+S to save, etc.)
  - Mouse support where available
  - Responsive layout
  - Theme support (light/dark)

### 5. Module Access Improvements
- **Direct function access**: Execute any public module function from startup
- **Parameter handling**: Interactive parameter input with validation
- **Pipeline support**: Chain multiple module functions
- **Help integration**: F1 or ? for context-sensitive help

## Technical Implementation Details

### File Structure
```
aither-core/
├── modules/
│   └── StartupExperience/
│       ├── StartupExperience.psd1
│       ├── StartupExperience.psm1
│       ├── Public/
│       │   ├── Start-InteractiveMode.ps1
│       │   ├── Show-ConfigurationManager.ps1
│       │   ├── Get-ModuleDiscovery.ps1
│       │   ├── New-ConfigurationProfile.ps1
│       │   └── Sync-ConfigurationToGitHub.ps1
│       └── Private/
│           ├── Initialize-TerminalUI.ps1
│           ├── Show-ContextMenu.ps1
│           └── Get-ModuleMetadata.ps1
configs/
├── profiles/
│   ├── default.json
│   ├── development.json
│   └── production.json
└── .profile-metadata.json
```

### Configuration Schema Extension
```json
{
  "profile": {
    "name": "development",
    "description": "Development environment setup",
    "created": "2025-01-29T14:00:00Z",
    "lastModified": "2025-01-29T14:00:00Z",
    "gitRepo": "https://github.com/user/aitherzero-configs.git"
  },
  "startup": {
    "defaultMode": "noninteractive",
    "preloadModules": [],
    "defaultScripts": ["DevEnvironment"],
    "theme": "dark"
  },
  // ... existing config continues
}
```

### Command Line Changes
```powershell
# Default - non-interactive
./Start-AitherZero.ps1

# Interactive configuration mode
./Start-AitherZero.ps1 -Interactive

# Quickstart (implies -Interactive)
./Start-AitherZero.ps1 -Quickstart

# Load specific profile
./Start-AitherZero.ps1 -Profile "development"

# Create new profile
./Start-AitherZero.ps1 -NewProfile "staging"
```

## User Experience Flow

### 1. Non-Interactive Mode (Default)
```
AitherZero v1.0.0
Loading configuration from: default-config.json
Initializing modules...
Running scripts: LabRunner, BackupManager
[Progress indicators]
Complete.
```

### 2. Interactive Mode
```
AitherZero v1.0.0 - Interactive Mode

┌─ Main Menu ─────────────────────────────────┐
│ > Configuration Manager                      │
│   Module Explorer                           │
│   Run Scripts                               │
│   Profile Management                        │
│   Settings                                  │
│   Exit                                      │
└─────────────────────────────────────────────┘

[↑↓] Navigate  [Enter] Select  [Esc] Back  [?] Help
```

### 3. Configuration Manager View
```
┌─ Configuration Manager ──────────────────────┐
│ Current Profile: development                 │
│                                             │
│ [General Settings]                          │
│   ComputerName: dev-lab          [Edit]     │
│   DNSServers: 8.8.8.8,1.1.1.1   [Edit]     │
│                                             │
│ [Modules]                                   │
│   ✓ Git                                     │
│   ✓ PowerShell 7                           │
│   ✓ OpenTofu                               │
│   ☐ Docker Desktop                         │
│                                             │
│ [Actions]                                   │
│   [Save] [Save As] [Export] [Upload to Git] │
└─────────────────────────────────────────────┘
```

### 4. Module Explorer View
```
┌─ Module Explorer ───────────────────────────┐
│ Search: [____________________] 🔍           │
│                                             │
│ ▼ Infrastructure (5 modules)                │
│   ├─ OpenTofuProvider                      │
│   ├─ CloudProviderIntegration             │
│   └─ RemoteConnection                      │
│                                             │
│ ▼ Development (4 modules)                   │
│   ├─ DevEnvironment                        │
│   │  └─ Functions:                         │
│   │     • Initialize-DevEnvironment        │
│   │     • Install-DevTools                 │
│   │     • Configure-GitSettings            │
│   ├─ PatchManager                          │
│   └─ AIToolsIntegration                    │
│                                             │
│ ▶ Security (3 modules)                      │
│ ▶ Monitoring (2 modules)                    │
└─────────────────────────────────────────────┘
```

## Next Steps

1. Create the StartupExperience module
2. Implement the Terminal UI framework
3. Create LicenseManager module for feature control
4. Extend configuration schema
5. Update Start-AitherZero.ps1 to support new modes
6. Create profile management functionality
7. Add GitHub integration for configurations
8. Update build process for feature tiers
9. Update documentation and quickstart guides

## Success Criteria

- [ ] Users can view and edit configurations during startup
- [ ] All module functions are discoverable through menus
- [ ] Configuration profiles can be saved and shared
- [ ] Rich terminal UI provides modern experience
- [ ] Default behavior remains non-interactive for CI/CD
- [ ] Quickstart automatically uses interactive mode
- [ ] GitHub integration works for config backup/sharing
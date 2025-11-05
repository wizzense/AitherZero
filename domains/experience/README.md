# AitherZero Experience Domain - Interactive UI System

## 🎯 Core Philosophy: Menu IS CLI

The Experience domain implements a **unified interface** where the interactive menu and command-line interface are the same thing. Using the menu naturally teaches you the CLI because they use identical command structures.

```
┌────────────────────────────────────────────────────────────┐
│  AitherZero > Run > Testing > _                            │
│    Current Command: -Mode Run -Target 0402                 │
│                                                             │
│    [1] [0402] Run Unit Tests         ← You are here        │
│    [2] [0404] Run PSScriptAnalyzer                         │
│    [3] [0407] Validate Syntax                              │
│                                                             │
│  Type: -Mode Run -Target 0402   OR use ↑↓ arrows          │
└────────────────────────────────────────────────────────────┘
```

**Key Insight:** Menu navigation builds CLI commands. Users graduate from menu → CLI → automation scripts.

## 🚀 Quick Start

### Interactive Menu (New Users)
```powershell
# Start unified interactive menu
./Start-AitherZero.ps1 -Mode Interactive

# Navigate with arrows, see command being built
# Select items with Enter
# Type commands directly with 'C' key
```

### Direct CLI (Power Users)
```bash
# Run script directly
./Start-AitherZero.ps1 -Mode Run -Target 0402

# Run playbook
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook test-quick

# Use shortcuts
./Start-AitherZero.ps1 test    # Runs test suite
./Start-AitherZero.ps1 lint    # Runs linter
```

## 📦 Core Components

### 1. **UnifiedMenu.psm1** - Main Interactive Interface
The core system that combines breadcrumb navigation and command parsing.

**Features:**
- Breadcrumb navigation (AitherZero > Run > Testing)
- Shows command being built as you navigate
- Arrow key navigation OR typed commands
- Auto-discovers scripts and playbooks from filesystem

**Usage:**
```powershell
Import-Module ./domains/experience/UnifiedMenu.psm1
Start-UnifiedMenu -ProjectRoot $PWD
```

### 2. **CommandParser.psm1** - CLI Parser
Parses and validates CLI command syntax.

**Key Functions:**
```powershell
# Parse command
$cmd = Parse-AitherCommand "-Mode Run -Target 0402"
# Returns: @{ IsValid=$true; Mode='Run'; Parameters=@{Target='0402'} }

# Build command
Build-AitherCommand -Mode 'Run' -Parameters @{ Target = '0402' }
# Returns: "-Mode Run -Target 0402"

# Shortcuts
Parse-AitherCommand "test"    # → test suite
Parse-AitherCommand "lint"    # → linter
Parse-AitherCommand "0402"    # → run script 0402
```

### 3. **BreadcrumbNavigation.psm1** - Path Tracking
Stack-based navigation showing where you are.

**Functions:**
```powershell
$stack = New-BreadcrumbStack
Push-Breadcrumb -Stack $stack -Name "Run"
Push-Breadcrumb -Stack $stack -Name "Testing"
Show-Breadcrumb -Stack $stack -IncludeRoot
# Output: AitherZero > Run > Testing
```

### 4. **BetterMenu.psm1** - Keyboard Navigation
Arrow key menu system with fallback to simple numbered menus.

**Features:**
- ↑↓ Arrow keys, PageUp/PageDown, Home/End
- Number jump (type "3" to select item 3)
- Letter jump (type "t" for first item starting with 't')
- Vim-style (j/k for down/up)
- Auto-detects terminal capabilities

### 5. **UserInterface.psm1** - Core UI Utilities
Base UI utilities including text formatting, themes, and cross-platform helpers.

## 🎓 User Journey

### Phase 1: New User (Learning)
```
Uses arrow keys in menu → Sees "-Mode Run -Target 0402" → Learns command structure
```

### Phase 2: Mixed Mode
```
Types "-Mode Run" → Menu shows matching options → Faster navigation
```

### Phase 3: Power User
```
Skips menu entirely → Uses CLI directly → Creates automation scripts
```

## 📚 Documentation

- **[UNIFIED-MENU-DESIGN.md](../../docs/UNIFIED-MENU-DESIGN.md)** - Full design philosophy
- **[Tests](../../tests/unit/domains/experience/)** - Comprehensive test suite (43 tests ✅)

## 🧪 Testing

```bash
# Run all experience domain tests
pwsh -Command "Invoke-Pester -Path './tests/unit/domains/experience' -Output Detailed"

# Specific components
pwsh -Command "Invoke-Pester -Path './tests/unit/domains/experience/CommandParser.Tests.ps1'"
pwsh -Command "Invoke-Pester -Path './tests/unit/domains/experience/BreadcrumbNavigation.Tests.ps1'"
```

**Test Coverage:**
- CommandParser: 28 tests ✅
- BreadcrumbNavigation: 15 tests ✅
- BetterMenu: Existing tests ✅

## 🔮 Future: Foundation for GUI/Web UI

The unified command structure provides the foundation for future graphical interfaces. The same command parser and structure will power GUI buttons, web forms, and dashboards.

## Requirements

- PowerShell 7.0+
- Terminal with ANSI color support (automatic fallback to simple mode)
- UTF-8 encoding support for box drawing characters

## License

Part of the AitherZero project - MIT License

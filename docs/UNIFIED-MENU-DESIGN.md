# Unified Interactive Menu System - Design Document

## Overview

The unified interactive menu system makes the CLI and the interactive menu **the same thing**. Using the menu naturally teaches you the CLI because they use identical command structures.

## Core Concept: Menu IS CLI

```
┌────────────────────────────────────────────────────────────┐
│                Traditional Approach (BAD)                   │
├────────────────────────────────────────────────────────────┤
│  Interactive Menu        │  Command Line                   │
│  ├─ 1) Run Tests        │  .\Start-AitherZero.ps1         │
│  ├─ 2) Run Linter       │    -Mode Run -Target 0402       │
│  └─ 3) Generate Report  │                                  │
│                          │                                  │
│  Two separate systems!   │  Users must learn both!         │
└────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────┐
│               Unified Approach (GOOD - THIS!)               │
├────────────────────────────────────────────────────────────┤
│  AitherZero > Run > _                                      │
│    -Mode Run -Target 0402                                  │
│                                                             │
│    [1] 🔧 Environment Setup (8 scripts)                    │
│    [2] 🏗️ Infrastructure (12 scripts)                      │
│    [3] ✅ Testing & Validation (15 scripts)  ←             │
│                                                             │
│  Type: -Mode Run -Target 0402   OR use ↑↓ arrows          │
│                                                             │
│  Menu shows the CLI command you're building!               │
└────────────────────────────────────────────────────────────┘
```

## User Journey

### Phase 1: New User (Needs Menu)
```
$ ./Start-AitherZero.ps1 -Mode Interactive

AitherZero > _
  Current Command: (none)
  
  [1] 🎯 Run - Execute scripts
  [2] 📚 Orchestrate - Run playbooks
  [3] 🔍 Search - Find resources
  
  Use ↑↓ arrows or type: -Mode Run
```

User presses Down arrow, selects "Run"...

```
AitherZero > Run > _
  Current Command: -Mode Run
  
  [1] 🔧 Environment Setup (8 scripts)
  [2] 🏗️ Infrastructure (12 scripts)
  [3] ✅ Testing & Validation (15 scripts)
  
  Equivalent: -Mode Run -Target 0402
```

User selects "Testing & Validation"...

```
AitherZero > Run > Testing & Validation > _
  Current Command: -Mode Run
  
  [1] [0402] Run Unit Tests
  [2] [0404] Run PSScriptAnalyzer
  [3] [0407] Validate Syntax
  
  Equivalent: -Mode Run -Target 0402
```

User selects "[0402] Run Unit Tests"...

```
✅ Command built: -Mode Run -Target 0402

Execute this command? (Y/N): y

🚀 Executing: -Mode Run -Target 0402
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Running unit tests...
✅ All tests passed!
```

**User has now learned:** `-Mode Run -Target 0402`

### Phase 2: Learning User (Half-Menu, Half-CLI)
```
$ ./Start-AitherZero.ps1 -Mode Interactive

AitherZero > _

  Type: -Mode Run   [User types this]
  
  Suggestion: -Mode Run -Target <script_number>
  
  Shortcuts: 
    test       = -Mode Run -Target "0402,0404,0407"
    lint       = -Mode Run -Target 0404
    quick-test = -Mode Orchestrate -Playbook test-quick
```

### Phase 3: CLI User (No Menu Needed)
```bash
# User graduates to pure CLI
$ ./Start-AitherZero.ps1 -Mode Run -Target 0402
$ ./Start-AitherZero.ps1 -Mode Orchestrate -Playbook test-quick
$ ./Start-AitherZero.ps1 -Mode Search -Query security

# Or even better - shortcuts!
$ ./Start-AitherZero.ps1 test
$ ./Start-AitherZero.ps1 lint
$ ./Start-AitherZero.ps1 quick-test
```

## Architecture

### Components

1. **CommandParser** - Understands CLI syntax
   ```powershell
   Parse-AitherCommand "-Mode Run -Target 0402"
   # Returns: @{ Mode = 'Run'; Parameters = @{ Target = '0402' } }
   ```

2. **BreadcrumbNavigation** - Tracks where you are
   ```powershell
   AitherZero > Run > Testing > Unit Tests
   ```

3. **UnifiedMenu** - Combines everything
   - Shows breadcrumb trail
   - Shows command being built
   - Accepts arrow keys OR typed commands
   - Executes via same command structure

### Data Flow

```
User Input
    ↓
┌─────────────────┐
│  Arrow Keys?    │ → BetterMenu → Select Item → Build Command
└─────────────────┘
    ↓
┌─────────────────┐
│  Typed Command? │ → CommandParser → Validate → Execute
└─────────────────┘
    ↓
Execute Command (Same Path!)
    ↓
Show Output
```

## CLI Parameter Structure

Based on `Start-AitherZero.ps1`:

### Modes
- `Interactive` - Start interactive menu
- `Run` - Execute scripts
- `Orchestrate` - Run playbooks
- `Search` - Search resources
- `List` - List available items
- `Test` - Run tests
- `Validate` - Run validation
- `Deploy` - Deploy infrastructure

### Mode-Specific Parameters

#### Run Mode
```powershell
-Mode Run -Target <script_number>
-Mode Run -Target <sequence>
-Mode Run -ScriptNumber <number>
```

#### Orchestrate Mode
```powershell
-Mode Orchestrate -Playbook <name>
-Mode Orchestrate -Playbook <name> -PlaybookProfile <profile>
-Mode Orchestrate -Sequence <numbers>
```

#### Search Mode
```powershell
-Mode Search -Query <term>
```

#### List Mode
```powershell
-Mode List -Target scripts
-Mode List -Target playbooks
-Mode List -Target all
```

## Menu Generation

The menu is **automatically generated** from:

1. **Available modes** - From `Start-AitherZero.ps1` ValidateSet
2. **Available scripts** - From `automation-scripts/` directory
3. **Available playbooks** - From `orchestration/playbooks/` directory
4. **Script categories** - From `config.psd1` ScriptInventory

This ensures the menu always matches the CLI!

## Future: GUI/Web UI

The same command structure will power the GUI:

```
┌──────────────────────────────────────────────┐
│  AitherZero Web UI                           │
├──────────────────────────────────────────────┤
│  [Run ▼] [Script: 0402 ▼] [Execute]         │
│                                              │
│  Equivalent Command:                         │
│  -Mode Run -Target 0402                      │
│                                              │
│  [Copy to Clipboard] [Add to Script]        │
└──────────────────────────────────────────────┘
```

## Benefits

1. **One System to Learn** - Menu and CLI use same commands
2. **Natural Progression** - Menu → Mixed → Pure CLI
3. **Always in Sync** - Menu auto-generated from CLI structure
4. **Future-Proof** - Foundation for GUI/Web UI
5. **Testable** - CLI commands are API, easy to test
6. **Discoverable** - Menu shows all available options
7. **Efficient** - Power users skip menu, use CLI directly

## Implementation Status

### Completed ✅
- [x] CommandParser component
- [x] BreadcrumbNavigation component
- [x] UnifiedMenu framework
- [x] Run mode navigation
- [x] Command building and display
- [x] Script execution
- [x] Comprehensive tests (43 tests passing)

### In Progress 🚧
- [ ] Complete all mode menus (Orchestrate, Search, List, Test, Validate)
- [ ] Integration with Start-AitherZero.ps1
- [ ] Command history and favorites
- [ ] Advanced search and filtering

### Future 🔮
- [ ] GUI/Web UI using same command structure
- [ ] Dashboard views (reports, metrics)
- [ ] Interactive playbook builder
- [ ] Command recording and script generation

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

## 📦 Components

### Unified Menu System (New Architecture)

#### 1. **UnifiedMenu.psm1** - Main Interface
The core interactive system that combines all components.

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

#### 2. **CommandParser.psm1** - CLI Parser
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

#### 3. **BreadcrumbNavigation.psm1** - Path Tracking
Stack-based navigation showing where you are.

**Functions:**
```powershell
$stack = New-BreadcrumbStack
Push-Breadcrumb -Stack $stack -Name "Run"
Push-Breadcrumb -Stack $stack -Name "Testing"
Show-Breadcrumb -Stack $stack -IncludeRoot
# Output: AitherZero > Run > Testing
```

#### 4. **BetterMenu.psm1** - Keyboard Navigation
Arrow key menu system with fallback to simple numbered menus.

**Features:**
- ↑↓ Arrow keys, PageUp/PageDown, Home/End
- Number jump (type "3" to select item 3)
- Letter jump (type "t" for first item starting with 't')
- Vim-style (j/k for down/up)
- Auto-detects terminal capabilities

### Legacy Components (Backward Compatibility)

The following components remain for backward compatibility:

- **InteractiveUI.psm1** - Original interactive UI
- **UserInterface.psm1** - Core UI utilities
- **CLIHelper.psm1** - CLI helper functions

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

---

# AitherZero Interactive UI System

## Overview

A modern, component-based, truly interactive CLI UI system for PowerShell 7+ that provides real keyboard navigation, modular architecture, and comprehensive testing.

## Key Features

### ✅ Real Interactivity
- **Arrow Key Navigation**: Up/Down/Left/Right arrow keys for navigation
- **Page Navigation**: PageUp/PageDown, Home/End keys
- **Multi-Select**: Space key to select/deselect items
- **Search/Filter**: Type to filter items in real-time
- **Escape/Enter**: Standard keyboard shortcuts
- **Custom Hotkeys**: Register any key combination

### ✅ Component Architecture
- **Base Component Class**: All UI elements inherit from `UIComponent`
- **Lifecycle Management**: Initialize, Mount, Render, Unmount phases
- **Event System**: Full event propagation and bubbling
- **State Management**: Component state with automatic re-rendering
- **Style Inheritance**: CSS-like style inheritance from parent components

### ✅ Modular & Extensible
- **Plugin System**: Register custom components dynamically
- **Theme Support**: Multiple built-in themes, custom theme creation
- **Layout Engine**: Grid, Flow, and custom layout managers
- **Component Registry**: Dynamic component discovery and registration

### ✅ Test-Driven Development
- **Mock Terminal**: Full terminal emulation for testing
- **Mock Keyboard**: Simulate any keyboard input sequence
- **Component Testing**: Test components in isolation
- **Event Testing**: Verify event propagation
- **Layout Testing**: Test responsive layouts

## Architecture

```
domains/experience/
├── Core/                      # Core system components
│   ├── UIComponent.psm1       # Base component class
│   ├── UIContext.psm1         # Application context
│   ├── UIEventSystem.psm1     # Event bus (planned)
│   └── UIRenderer.psm1        # Rendering engine (planned)
├── Components/                # Built-in components
│   ├── InteractiveMenu.psm1   # Interactive menu with arrow keys
│   ├── SelectList.psm1        # Multi-select list (planned)
│   ├── TextField.psm1         # Text input field (planned)
│   ├── ProgressBar.psm1       # Progress indicator (planned)
│   ├── Table.psm1             # Data table (planned)
│   └── Dialog.psm1            # Modal dialog (planned)
├── Layout/                    # Layout managers (planned)
│   ├── LayoutManager.psm1
│   ├── Container.psm1
│   └── ResponsiveLayout.psm1
├── Registry/                  # Component registry (planned)
│   ├── ComponentRegistry.psm1
│   ├── ThemeRegistry.psm1
│   └── PluginLoader.psm1
└── UserInterface.psm1         # Backward compatibility layer

tests/unit/domains/experience/
├── UITestFramework.psm1       # Testing utilities
├── UITestFramework.Tests.ps1  # Framework tests
├── UIComponent.Tests.ps1      # Component tests
└── InteractiveMenu.Tests.ps1  # Menu tests
```

## Usage

### Basic Menu
```powershell
# Using backward-compatible wrapper
$selection = Show-UIMenu -Title "Select Option" -Items @("Option 1", "Option 2", "Option 3") -UseInteractive

# Using new component directly
$menu = New-InteractiveMenu -Items $items -Title "My Menu"
# ... handle menu in custom loop
```

### Multi-Select Menu
```powershell
$selected = Show-UIMenu -Title "Select Features" -Items $features -MultiSelect -UseInteractive
# Returns array of selected items
```

### Complex Objects
```powershell
$services = @(
    [PSCustomObject]@{ Name = "Web"; Status = "Running"; Port = 80 }
    [PSCustomObject]@{ Name = "Database"; Status = "Stopped"; Port = 5432 }
)
$selected = Show-UIMenu -Title "Services" -Items $services -UseInteractive
```

### Enable Globally
```powershell
# Enable interactive UI for entire session
$env:AITHERZERO_USE_INTERACTIVE_UI = 'true'

# Now all Show-UIMenu calls use interactive system
$selection = Show-UIMenu -Title "Menu" -Items $items
```

## Component Development

### Creating a Custom Component
```powershell
# Create base component
$component = New-UIComponent -Name "MyCustomComponent"

# Set properties
$component.Properties = @{
    Text = "Hello World"
    Color = "Green"
}

# Define render logic
$component.OnRender = {
    param($self)
    # Custom rendering logic
    Write-Host $self.Properties.Text -ForegroundColor $self.Properties.Color
}

# Handle input
$component.OnKeyPress = {
    param($inputValue)
    if ($inputValue.Key -eq "Enter") {
        # Handle enter key
        return $true  # Handled
    }
    return $false  # Not handled
}
```

### Component Lifecycle
```powershell
# 1. Create
$component = New-UIComponent -Name "MyComponent"

# 2. Initialize
Initialize-UIComponent -Component $component -Context $context

# 3. Mount
Mount-UIComponent -Component $component -Context $context

# 4. Render (called automatically or manually)
Invoke-UIComponentRender -Component $component

# 5. Handle events
Invoke-UIComponentEvent -Component $component -EventName "Click"

# 6. Unmount
Unmount-UIComponent -Component $component
```

## Testing

### Test Framework Usage
```powershell
# Import test framework
Import-Module ./tests/unit/domains/experience/UITestFramework.psm1

# Create test context
$context = New-UITestContext

# Create mock terminal
$terminal = New-MockTerminal -Width 80 -Height 24

# Simulate keyboard input
$keyboard = New-MockKeyboard
Add-MockKeySequence -Keyboard $keyboard -Sequence @("DownArrow", "DownArrow", "Enter")

# Test menu navigation
$result = Test-UIMenuNavigation -Context $context -Items @("A", "B", "C")
$result.SelectedIndex | Should -Be 2
```

### Running Tests
```powershell
# Run all UI tests
Invoke-Pester ./tests/unit/domains/experience/*.Tests.ps1

# Run specific test
Invoke-Pester ./tests/unit/domains/experience/UIComponent.Tests.ps1
```

## Migration from Classic UI

The system maintains full backward compatibility:

1. **Automatic Fallback**: If interactive system fails, falls back to classic Read-Host
2. **Same API**: Show-UIMenu maintains same parameters and return values
3. **Opt-in**: Use `-UseInteractive` flag or set environment variable
4. **Gradual Migration**: Migrate one menu at a time

## Performance

- **Lazy Loading**: Components load only when needed
- **Dirty Region Tracking**: Only re-render changed areas
- **Event Batching**: Batch multiple state updates
- **Optimized Rendering**: Minimal terminal operations

## Roadmap

### Completed ✅
- [x] Test framework with mocks
- [x] Core component system (UIComponent, UIContext)
- [x] Interactive input system
- [x] InteractiveMenu component
- [x] Backward compatibility layer

### In Progress 🚧
- [ ] Additional components (SelectList, TextField, etc.)
- [ ] Component registry system
- [ ] Layout engine

### Planned 📋
- [ ] More built-in components
- [ ] Advanced theming
- [ ] Animation support
- [ ] Accessibility features
- [ ] Terminal capability detection
- [ ] Cross-platform testing

## Contributing

To add new components:

1. Create component in `Components/` directory
2. Write tests in `tests/unit/domains/experience/`
3. Update backward compatibility if needed
4. Add examples to `examples/`
5. Update this documentation

## Examples

Run the interactive demo:
```powershell
./examples/interactive-ui-demo.ps1
```

This demonstrates:
- Simple menus
- Multi-select menus
- Complex object menus
- Large scrollable menus
- Custom actions and hotkeys

## Requirements

- PowerShell 7.0+
- Terminal with ANSI color support
- UTF-8 encoding support (for box drawing characters)

## License

Part of the AitherZero project.
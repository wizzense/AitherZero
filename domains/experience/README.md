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
    param($input)
    if ($input.Key -eq "Enter") {
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
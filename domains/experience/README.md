# AitherZero UI System

## Overview

A clean, unified CLI UI system for PowerShell 7+ that provides interactive menus, notifications, progress tracking, and other UI components with automatic text formatting fixes.

## Key Features

### ✅ Interactive Menus
- **Arrow Key Navigation**: Up/Down arrow keys for navigation
- **Multi-Select**: Space key to select/deselect items  
- **Escape/Enter**: Standard keyboard shortcuts
- **Custom Actions**: Register hotkeys for custom operations
- **Auto Text Fixing**: Automatically fixes character spacing issues in menu text

### ✅ Comprehensive UI Components  
- **Interactive Menus**: Full keyboard navigation with scrolling
- **Notifications**: Success, warning, error, and info notifications
- **Progress Tracking**: Progress bars and spinners
- **Tables**: Data table display with formatting
- **Prompts**: Input prompts with validation
- **Borders**: Decorative borders and separators
- **Wizards**: Multi-step user workflows

### ✅ Smart Text Processing
- **Automatic Spacing Fix**: Fixes fragmented text like "O rc he st ra ti on" → "Orchestration"
- **Fallback Safety**: Graceful degradation if advanced features unavailable
- **Cross-Platform**: Works on Windows, Linux, and macOS

## Architecture

```
domains/experience/
├── Components/
│   └── InteractiveMenu.psm1   # Advanced menu component
└── UserInterface.psm1         # Main UI system with all functions

tests/unit/domains/experience/
├── UITestFramework.psm1       # Testing utilities
└── *.Tests.ps1               # Component tests
```

## Usage

### Interactive Menu
```powershell
# Basic menu
$selection = Show-UIMenu -Title "Select Option" -Items @("Option 1", "Option 2", "Option 3")

# Menu with complex objects
$services = @(
    [PSCustomObject]@{ Name = "Web Server"; Description = "HTTP service" }
    [PSCustomObject]@{ Name = "Database"; Description = "Data storage" }
)
$selected = Show-UIMenu -Title "Services" -Items $services -ShowNumbers
```

### Multi-Select Menu
```powershell
$selected = Show-UIMenu -Title "Select Features" -Items $features -MultiSelect
# Returns array of selected items
```

### Other UI Functions
```powershell
# Notifications
Show-UINotification -Message "Task completed!" -Type 'Success'
Show-UINotification -Message "Warning: Check configuration" -Type 'Warning'

# Progress tracking
Show-UIProgress -Activity "Processing" -Status "Step 1 of 3" -PercentComplete 33

# Input prompts
$name = Show-UIPrompt -Message "Enter name"
$choice = Show-UIPrompt -Message "Continue?" -ValidateSet @('Yes', 'No')

# Tables
Show-UITable -Data $processes -Title "Running Processes"
```

## Text Spacing Fix

The UI system automatically fixes common text spacing issues:

```powershell
# Before: Fragmented text
$problematicText = "O rc he st ra ti on En gi ne"

# After: Automatically fixed when displayed in menus
# Output: "Orchestration Engine"

# The fix handles:
# - Fragment spacing: "C on fi gu ra ti on" → "Configuration"  
# - Multiple word spacing: "R e p o s i t o r y  M a n a g e r" → "Repository Manager"
# - Preserves normal text unchanged
```

## Non-Interactive Mode

For CI/CD and automation scenarios:

```powershell
# Force non-interactive mode
$env:AITHERZERO_NONINTERACTIVE = '1'
$selection = Show-UIMenu -Title "Options" -Items $items

# Or use parameter
$selection = Show-UIMenu -Title "Options" -Items $items -NonInteractive
```

## Testing

```powershell
# Run UI tests
Invoke-Pester ./tests/unit/domains/experience/*.Tests.ps1

# Test menu functionality 
$testItems = @("Option A", "Option B", "Option C")
$result = Show-UIMenu -Title "Test Menu" -Items $testItems -NonInteractive
```

## Backward Compatibility

The system maintains full compatibility with existing code:

- **Same API**: All existing `Show-UIMenu` calls work unchanged
- **Automatic Fallback**: Gracefully falls back to simple prompts if interactive mode fails  
- **Environment Detection**: Automatically uses non-interactive mode in CI/CD environments
- **Progressive Enhancement**: Interactive features are added without breaking existing functionality

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
# Interactive demo
./examples/interactive-ui-demo.ps1

# Test the UI system  
./examples/test-better-menu.ps1
```

## Requirements

- PowerShell 7.0+
- Terminal with ANSI color support

## Architecture Benefits

This simplified architecture provides:

- **Single Source of Truth**: One main UI module instead of multiple competing systems
- **Integrated Text Fixes**: Built-in handling of text spacing issues
- **Clean API**: Consistent function names and parameters
- **Backward Compatibility**: Existing code continues to work
- **Maintainability**: Easier to understand and modify than complex component hierarchies

## License

Part of the AitherZero project.
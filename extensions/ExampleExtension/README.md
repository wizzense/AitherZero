# Example Extension

Demonstrates how to create an extension for AitherZero Core.

## Features

- **Custom CLI Mode**: `Example` mode for custom operations
- **Commands**: `Get-ExampleData`, `Invoke-ExampleTask`
- **Scripts**: 8000 (Setup), 8001 (Status)

## Installation

1. Extension is already in `extensions/ExampleExtension/`
2. Enable in `config.psd1`:
   ```powershell
   Extensions = @{
       EnabledExtensions = @('ExampleExtension')
   }
   ```
3. Restart AitherZero or run:
   ```powershell
   Import-Extension -Name 'ExampleExtension'
   ```

## Usage

### CLI Mode

```bash
# Run example task
./Start-AitherZero.ps1 -Mode Example -Target demo -Action run

# Check status
./Start-AitherZero.ps1 -Mode Example -Target demo -Action status

# Get info
./Start-AitherZero.ps1 -Mode Example -Target demo -Action info
```

### Commands

```powershell
# Get example data
Get-ExampleData -Source "test"

# Run example task
Invoke-ExampleTask -TaskName "demo"

# Dry run
Invoke-ExampleTask -TaskName "demo" -DryRun
```

### Automation Scripts

```bash
# Run setup script
./Start-AitherZero.ps1 -Mode Run -Target 8000

# Check status
./Start-AitherZero.ps1 -Mode Run -Target 8001
```

## Structure

```
ExampleExtension/
├── ExampleExtension.extension.psd1  # Manifest
├── modules/
│   └── ExampleExtension.psm1        # PowerShell module
├── scripts/
│   ├── 8000_Example-Setup.ps1       # Setup script
│   └── 8001_Example-Status.ps1      # Status script
├── tests/                            # (Tests would go here)
├── Initialize.ps1                    # Initialization
├── Cleanup.ps1                       # Cleanup
└── README.md                         # This file
```

## Extension Points

This example demonstrates:
- ✅ Custom CLI modes
- ✅ Custom PowerShell commands
- ✅ Numbered automation scripts (8000-8999)
- ✅ Initialization/cleanup scripts
- ✅ Extension manifest format

## Author

AitherZero Team

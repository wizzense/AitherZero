# AitherCore Quick Start Guide

Get started with AitherCore in 5 minutes!

## What is AitherCore?

AitherCore is the essential module collection from AitherZero, containing only the critical foundation needed for basic operations. It's perfect for:
- Lightweight deployments
- Quick testing
- Learning the platform
- Minimal installations

## Installation

AitherCore is included with AitherZero. No separate installation needed!

```bash
# Clone AitherZero (includes aithercore)
git clone https://github.com/wizzense/AitherZero.git
cd AitherZero
```

## Quick Start

### 1. Load AitherCore

```powershell
# Import the module
Import-Module ./aithercore/AitherCore.psd1

# Verify it loaded
Get-Module AitherCore
```

### 2. Your First Script

```powershell
# Initialize logging
Initialize-Logging -Path "./logs" -Level 'Information'

# Write a log message
Write-CustomLog -Message "Hello from AitherCore!" -Level 'Information' -Source "QuickStart"

# Show a menu
$items = @("Option 1", "Option 2", "Exit")
$choice = Show-UIMenu -Title "My First Menu" -Items $items
Write-Host "You selected: $choice"
```

### 3. Try the Interactive Example

```powershell
# Copy this script to test.ps1
@'
Import-Module ./aithercore/AitherCore.psd1

# Initialize systems
Initialize-Logging -Path "./logs" -Level 'Information'
Write-CustomLog "Starting demo" -Source "Demo"

# Show welcome
Write-UISection -Title "AitherCore Demo" -Message "Welcome to the quick start!"

# Interactive menu
$running = $true
while ($running) {
    $items = @(
        "Show System Info",
        "Test Configuration",
        "View Logs",
        "Exit"
    )
    
    $choice = Show-BetterMenu -Title "Demo Menu" -Items $items
    
    switch ($choice) {
        "Show System Info" {
            Write-UIInfo "PowerShell Version: $($PSVersionTable.PSVersion)"
            Write-UIInfo "OS: $($PSVersionTable.OS)"
            Read-Host "Press Enter to continue"
        }
        "Test Configuration" {
            $config = Get-Configuration
            Write-UISuccess "Configuration loaded successfully"
            Read-Host "Press Enter to continue"
        }
        "View Logs" {
            $logs = Get-Logs -Last 5
            Write-UISection -Title "Recent Logs"
            $logs | ForEach-Object { Write-Host "$($_.Timestamp): $($_.Message)" }
            Read-Host "Press Enter to continue"
        }
        "Exit" {
            Write-UISuccess "Goodbye!"
            $running = $false
        }
    }
}
'@ | Set-Content test.ps1

# Run it
./test.ps1
```

## What's Included?

### Core Functions You'll Use Most

**Logging:**
```powershell
Write-CustomLog -Message "Something happened" -Level 'Information' -Source "MyApp"
```

**Configuration:**
```powershell
$config = Get-Configuration
$value = Get-ConfigValue -Key "MyApp.Setting"
```

**UI/Menus:**
```powershell
$choice = Show-UIMenu -Title "Main Menu" -Items @("A", "B", "C")
Show-UIProgress -Activity "Processing" -PercentComplete 50
```

**Messages:**
```powershell
Write-UISuccess "It worked!"
Write-UIError "Something went wrong"
Write-UIWarning "Be careful"
Write-UIInfo "FYI: This is interesting"
```

## Common Patterns

### Pattern 1: Simple Script with Logging
```powershell
Import-Module ./aithercore/AitherCore.psd1
Initialize-Logging -Path "./logs" -Level 'Information'

try {
    Write-CustomLog "Starting task" -Source "MyScript"
    # Do work here
    Write-CustomLog "Task completed" -Source "MyScript"
} catch {
    Write-CustomLog "Error: $_" -Level 'Error' -Source "MyScript"
}
```

### Pattern 2: Interactive Application
```powershell
Import-Module ./aithercore/AitherCore.psd1
Initialize-Logging

$running = $true
while ($running) {
    $choice = Show-UIMenu -Title "App" -Items @("Action 1", "Action 2", "Exit")
    
    if ($choice -eq "Exit") {
        $running = $false
    } else {
        Write-UIInfo "You selected: $choice"
        # Handle the action
    }
}
```

### Pattern 3: Progress Tracking
```powershell
Import-Module ./aithercore/AitherCore.psd1

$items = 1..100
$total = $items.Count

foreach ($i in 0..($total-1)) {
    Show-UIProgress -Activity "Processing" -Status "Item $($i+1) of $total" -PercentComplete (($i+1)/$total*100)
    # Process item
    Start-Sleep -Milliseconds 50
}

Write-UISuccess "All items processed!"
```

## Differences from Full AitherZero

| Feature | AitherCore | Full AitherZero |
|---------|-----------|----------------|
| **Size** | ~5,500 lines | ~24,000 lines |
| **Modules** | 8 core | 39+ modules |
| **Loading Time** | Fast | Slower |
| **Logging** | ✅ | ✅ |
| **Configuration** | ✅ | ✅ |
| **UI/Menus** | ✅ | ✅ Advanced |
| **Infrastructure** | ✅ Basic | ✅ Full |
| **Security** | ✅ SSH | ✅ Full |
| **Orchestration** | ✅ | ✅ |
| **Git Automation** | ❌ | ✅ |
| **Documentation Gen** | ❌ | ✅ |
| **Testing Framework** | ❌ | ✅ |
| **Reporting** | ❌ | ✅ |
| **AI Agents** | ❌ | ✅ |

## Upgrading to Full AitherZero

When you need more features:

```powershell
# Unload AitherCore
Remove-Module AitherCore

# Load full AitherZero
Import-Module ./AitherZero.psd1

# All AitherCore functions still available, plus many more!
```

## Troubleshooting

**Module won't load?**
```powershell
# Check PowerShell version (requires 7.0+)
$PSVersionTable.PSVersion

# Try with verbose output
Import-Module ./aithercore/AitherCore.psd1 -Verbose
```

**Functions not found?**
```powershell
# List all available functions
Get-Command -Module AitherCore

# Check specific function
Get-Command Write-CustomLog -Module AitherCore
```

**Logging not working?**
```powershell
# Make sure logs directory exists
New-Item -ItemType Directory -Path "./logs" -Force

# Initialize logging explicitly
Initialize-Logging -Path "./logs" -Level 'Information' -Targets 'Console', 'File'
```

## Next Steps

1. **Read the documentation**: See `README.md` for full details
2. **Try the examples**: Check `USAGE-EXAMPLES.md` for more patterns
3. **Run the tests**: `Invoke-Pester ./tests/integration/AitherCore.Tests.ps1`
4. **Build something**: Create your own script using AitherCore!

## Get Help

- **Documentation**: See `/aithercore/README.md`
- **Examples**: See `/aithercore/USAGE-EXAMPLES.md`
- **Tests**: See `/tests/integration/AitherCore.Tests.ps1`
- **Full Platform**: Use `Import-Module ./AitherZero.psd1` instead

## Summary

AitherCore gives you:
- ✅ Logging system
- ✅ Configuration management
- ✅ Interactive UI and menus
- ✅ Basic infrastructure tools
- ✅ SSH operations
- ✅ Script orchestration

All in a lightweight, fast-loading package!

---

**Ready to start?**
```powershell
Import-Module ./aithercore/AitherCore.psd1
Write-CustomLog "I'm using AitherCore!" -Source "Me"
```

Happy coding! 🚀

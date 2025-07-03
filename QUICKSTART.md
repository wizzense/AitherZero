# AitherZero Quick Start

## Ultra-Simple One-Liners

### PowerShell 5.1+ Compatible (Recommended)

```powershell
# Clean, readable bootstrap (50 lines)
iex (irm "https://raw.githubusercontent.com/wizzense/AitherZero/main/bootstrap.ps1")
```

### Optimized One-Liner (Advanced)

```powershell
# Compact version for experienced users
iex (irm "https://raw.githubusercontent.com/wizzense/AitherZero/main/get-aither.ps1")
```

## Manual Installation

If you prefer manual installation:

1. **Download**: Get the latest release from [GitHub](https://github.com/wizzense/AitherZero/releases)
2. **Extract**: Unzip to your desired location
3. **Run**: Execute `.\Start-AitherZero.ps1` or `.\quick-setup-simple.ps1`

## What These Scripts Do

1. **Download** the latest AitherZero Windows release
2. **Extract** it to your current directory
3. **Auto-start** the setup process
4. **PowerShell 5.1 Compatible** - works on older Windows systems

## Comparison

| Method | Length | Readability | Use Case |
|--------|--------|-------------|----------|
| bootstrap.ps1 | 50 lines | High | First-time users, learning |
| get-aither.ps1 | 20 lines | Medium | Experienced users, automation |
| Manual | N/A | Highest | Offline environments |

## Troubleshooting

If the one-liner fails:
1. Check internet connection
2. Ensure PowerShell execution policy allows remote scripts
3. Try manual download instead

For more help: https://github.com/wizzense/AitherZero/issues
# AitherZero Application Package vtest

## 🚀 Quick Start (30 Seconds)

### Windows Users:
1. **Double-click `AitherZero.bat`** - that's it!
2. Or run: `Start-AitherZero-Windows.ps1` in PowerShell
3. Or run: `pwsh -ExecutionPolicy Bypass -File Start-AitherZero.ps1`

### Linux/macOS Users:
1. **Run: `./aitherzero.sh`** - that's it!
2. Or run: `pwsh Start-AitherZero.ps1`

## 🔧 First Time Setup

Run setup wizard to check your environment:
`ash
# Windows
pwsh -ExecutionPolicy Bypass -File Start-AitherZero.ps1 -Setup

# Linux/macOS
./aitherzero.sh -Setup
`

## 📖 Usage Examples

`ash
# Interactive menu (default)
./Start-AitherZero.ps1

# Run all automation scripts
./Start-AitherZero.ps1 -Auto

# Run specific scripts
./Start-AitherZero.ps1 -Scripts 'LabRunner,BackupManager'

# Detailed output mode
./Start-AitherZero.ps1 -Verbosity detailed

# Get help
./Start-AitherZero.ps1 -Help
`

## ⚡ Requirements

- **PowerShell 7.0+** (required)
- **Git** (recommended for PatchManager and repository operations)
- **OpenTofu/Terraform** (recommended for infrastructure automation)

## 🔍 Troubleshooting

**Windows Execution Policy Issues:**
- Use `AitherZero.bat` (recommended)
- Or: `pwsh -ExecutionPolicy Bypass -File Start-AitherZero.ps1`

**Module Loading Issues:**
- Run the setup: `./Start-AitherZero.ps1 -Setup`
- Check PowerShell version: `pwsh --version`

**Permission Issues (Linux/macOS):**
- Make executable: `chmod +x aitherzero.sh`
- Or run directly: `pwsh Start-AitherZero.ps1`

## 🌐 Support

- **Repository**: https://github.com/wizzense/AitherZero
- **Issues**: https://github.com/wizzense/AitherZero/issues
- **Documentation**: See repository docs/ folder for advanced usage

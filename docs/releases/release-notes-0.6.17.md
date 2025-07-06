## 🚨 Critical Hotfix - PowerShell 7 Installation Fixed

### 🐛 Issue Fixed
- **Fixed PowerShell 7 installation failure** - Resolved WebClient.DownloadFile path issue in PowerShell 5.1
- **Added winget fallback** - Winget is now tried first for more reliable PowerShell 7 installation

### 🔧 What Changed
- Fixed WebClient download path handling for absolute vs relative paths
- Added winget as primary installation method with MSI as fallback
- Improved error handling and user feedback

### 🚀 Now Works Perfectly
The bootstrap one-liner now installs PowerShell 7 reliably:

```powershell
iex (irm "https://raw.githubusercontent.com/wizzense/AitherZero/main/bootstrap.ps1")
```

**Sorry for the inconvenience - this hotfix resolves the installation issue immediately!**
# AitherZero v1.2.2 Release

## 🎉 Finally - A Working Quickstart Experience!

This release fixes all the critical issues preventing the enhanced setup wizard from working properly.

## 🔧 What's Fixed

### ✅ Quickstart Now Works
- The -Quickstart parameter now properly launches the enhanced SetupWizard
- No more seeing the old numbered menu - you get the interactive UI
- One command setup experience as promised in the README

### ✅ Build Process Fixed  
- GitHub Actions now uses the proper Build-Package.ps1 script
- Packages include only the modules for each profile (minimal/standard/full)
- SetupWizard is included in standard and full profiles

### ✅ All Merge Conflicts Resolved
- Start-AitherZero.ps1 no longer has merge conflict markers
- PatchManager module manifest is clean
- All files properly sanitized

## 📦 Installation

### Windows One-Click (THIS WORKS NOW!)
`powershell
# Download and run - you'll get the enhanced UI!
$url = (irm "https://api.github.com/repos/wizzense/AitherZero/releases/latest").assets | ? name -like "*-windows-*.zip" | Select -First 1 | % browser_download_url; iwr $url -OutFile "AitherZero.zip"; Expand-Archive "AitherZero.zip" -Force; $folder = (gci -Directory | ? Name -like "AitherZero*")[0].Name; cd $folder; .\Start-AitherZero.ps1 -Quickstart
`

### First-Time Setup Options
`powershell
# Interactive quickstart (recommended)
./Start-AitherZero.ps1 -Quickstart

# Traditional setup wizard
./Start-AitherZero.ps1 -Setup

# Setup with specific profile
./Start-AitherZero.ps1 -Setup -InstallationProfile developer
`

## 🚀 What You Get

- **Enhanced Setup Wizard** with visual progress tracking
- **Installation Profiles**: Choose minimal, developer, or full
- **Smart Platform Detection**: Works on Windows, Linux, and macOS
- **AI Tools Integration**: Claude Code and MCP server setup (developer/full profiles)
- **No More Confusion**: Clear, guided setup process

## 📋 Version Details
- Version: 1.2.2
- Type: Hotfix Release
- Priority: Critical
- Tested: Windows, Linux, macOS

---
*This release supersedes v1.2.0 and v1.2.1 which had critical issues.*
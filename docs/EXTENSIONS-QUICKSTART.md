# AitherZero Extensions Quick Start Guide

Get started with AitherZero extensions in minutes!

## 🚀 Quick Install

### VS Code Extension

**Option 1: From Workspace** (Recommended for Development)
```bash
# Open AitherZero in VS Code
code /path/to/AitherZero

# Extension auto-activates when it detects AitherZero.psd1
```

**Option 2: Build and Install**
```bash
cd vscode-extension
npm install
npm run compile

# Install in VS Code
code --install-extension $(pwd)
```

### Windows Admin Center Extension

**Option 1: Upload Package** (Coming Soon)
1. Build the extension: `cd windows-admin-center && npm run package`
2. Open Windows Admin Center
3. Go to Settings → Extensions
4. Click "Upload" and select `.nupkg` file

**Option 2: Side-load for Development**
```bash
cd windows-admin-center
npm install
npm run build
npm run sideload -- --gateway https://localhost:6516
```

## 📝 First Steps

### VS Code Extension

1. **Open AitherZero Project**
   - File → Open Folder → Select AitherZero directory
   - Extension icon appears in Activity Bar

2. **Browse Scripts**
   - Click AitherZero icon (left sidebar)
   - Expand "Automation Scripts"
   - Browse by category (0000-0099, 0100-0199, etc.)

3. **Run Your First Script**
   - Navigate to "Testing" category
   - Click "0402 - Run Unit Tests"
   - Script executes in integrated terminal

4. **Open Dashboard**
   - Press `Ctrl+Shift+P`
   - Type "AitherZero: Open Dashboard"
   - View project statistics

### Windows Admin Center Extension

1. **Connect to Server**
   - Open Windows Admin Center
   - Add server with AitherZero installed
   - Connect to server

2. **Access AitherZero Tools**
   - Click "AitherZero" in Tools menu
   - View dashboard with server info

3. **Run Remote Script**
   - Navigate to "Automation Scripts" tab
   - Select script from list
   - Click "Run" button
   - View results in output panel

## 🎯 Common Tasks

### VS Code

**Run Tests Before Commit**
```
Command Palette → AitherZero: Run Tests
```

**Validate Syntax**
```
Command Palette → AitherZero: Validate Syntax
```

**Execute Playbook**
```
Command Palette → AitherZero: Open Playbook → Select playbook
```

### Windows Admin Center

**Check Multiple Servers**
1. Connect to first server
2. Run script
3. Switch to next server
4. Run same script
5. Compare results

**Schedule Automation**
1. Navigate to server
2. Select script
3. Click "Schedule" (future feature)
4. Set schedule parameters

## ⚙️ Configuration

### VS Code Settings

```json
{
  // Auto-detect or specify installation path
  "aitherzero.installationPath": "",
  
  // PowerShell executable
  "aitherzero.powerShellPath": "pwsh",
  
  // Auto-refresh when files change
  "aitherzero.autoRefresh": true,
  
  // Show execution notifications
  "aitherzero.showNotifications": true,
  
  // Clear terminal before running
  "aitherzero.terminal.clearBeforeRun": false
}
```

### Windows Admin Center

**Gateway Configuration:**
```powershell
# On WAC gateway server
Enable-PSRemoting -Force
Set-Item WSMan:\localhost\Client\TrustedHosts -Value "*" -Force
Restart-Service WinRM
```

**Target Server Configuration:**
```powershell
# On each managed server
Enable-PSRemoting -Force
Install-Module -Name AitherZero
```

## 🔧 Troubleshooting

### VS Code: Extension Not Activating

**Check:**
- AitherZero.psd1 exists in workspace
- Extension installed correctly
- View → Output → Select "Log (Extension Host)"

**Fix:**
```bash
# Reload VS Code
Ctrl+Shift+P → Developer: Reload Window
```

### VS Code: Scripts Not Found

**Check:**
- Installation path in settings
- AITHERZERO_ROOT environment variable
- automation-scripts directory exists

**Fix:**
```json
// Set explicit path in settings
"aitherzero.installationPath": "/full/path/to/AitherZero"
```

### WAC: Cannot Connect to Server

**Check:**
- PowerShell remoting enabled
- Firewall allows WinRM (ports 5985/5986)
- Server in TrustedHosts

**Fix:**
```powershell
# Test connection
Test-WSMan -ComputerName ServerName

# Enable remoting
Enable-PSRemoting -Force

# Add to trusted hosts
Set-Item WSMan:\localhost\Client\TrustedHosts -Value "ServerName" -Force
```

### WAC: AitherZero Not Detected

**Check:**
- AitherZero installed on target server
- AITHERZERO_ROOT environment variable set
- Module manifest exists

**Fix:**
```powershell
# Install AitherZero
Install-Module -Name AitherZero

# Or run bootstrap
cd C:\AitherZero
.\bootstrap.ps1 -Mode Update
```

## 📚 Next Steps

### Learn More
- [Full Extension Guide](./EXTENSIONS-INTEGRATION-GUIDE.md)
- [VS Code Extension README](../vscode-extension/README.md)
- [WAC Extension README](../windows-admin-center/README.md)

### Customize
- Add keyboard shortcuts for common commands
- Configure auto-execution on events
- Create custom playbooks for your workflow

### Contribute
- Report issues on GitHub
- Suggest features
- Submit pull requests

## 💡 Tips & Tricks

### VS Code

**Keyboard Shortcuts:**
```json
// Add to keybindings.json
{
  "key": "ctrl+alt+a r",
  "command": "aitherzero.runScript"
},
{
  "key": "ctrl+alt+a d",
  "command": "aitherzero.openDashboard"
},
{
  "key": "ctrl+alt+a t",
  "command": "aitherzero.runTests"
}
```

**Custom Tasks:**
```json
// Add to tasks.json
{
  "label": "AitherZero: Bootstrap",
  "type": "shell",
  "command": "pwsh -File bootstrap.ps1 -Mode Update"
}
```

### Windows Admin Center

**Multi-Server Operations:**
1. Open multiple browser tabs
2. Connect each tab to different server
3. Execute same script across all tabs
4. Compare results side-by-side

**Bookmark Common Scripts:**
- Add frequently used scripts to browser bookmarks
- Quick access to common operations

## 🎓 Tutorials

### Tutorial 1: Development Workflow with VS Code

1. Open AitherZero in VS Code
2. Make changes to a module
3. Run syntax validation (0407)
4. Run unit tests (0402)
5. View results in dashboard
6. Commit changes with Git integration

### Tutorial 2: Remote Server Management with WAC

1. Add server to Windows Admin Center
2. Open AitherZero extension
3. View server information
4. Run infrastructure check (0100)
5. Review results
6. Schedule regular checks

### Tutorial 3: Creating Custom Playbook

1. Create playbook in VS Code
2. Test locally with extension
3. Deploy to server via WAC
4. Execute remotely
5. Monitor execution
6. Review logs

## 📞 Support

- **Documentation**: [Full Docs](https://github.com/wizzense/AitherZero/tree/main/docs)
- **Issues**: [GitHub Issues](https://github.com/wizzense/AitherZero/issues)
- **Discussions**: [GitHub Discussions](https://github.com/wizzense/AitherZero/discussions)

## 🔗 Related Links

- [AitherZero Main README](../README.md)
- [VS Code API Documentation](https://code.visualstudio.com/api)
- [Windows Admin Center Docs](https://docs.microsoft.com/windows-server/manage/windows-admin-center/)
- [PowerShell Documentation](https://docs.microsoft.com/powershell/)

---

**Ready to get started?** Pick an extension and dive in! 🚀

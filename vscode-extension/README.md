# AitherZero VS Code Extension

Infrastructure automation platform integration for Visual Studio Code.

## Features

### 🎯 Automation Scripts Explorer
- Browse all automation scripts organized by category (0000-9999)
- Run scripts directly from the VS Code UI
- Quick access to common operations

### 📚 Playbooks Management
- View and execute orchestration playbooks
- Run pre-configured automation workflows
- Create custom playbook sequences

### 🧩 Domain Browser
- Explore AitherZero domains and modules
- View function counts and module statistics
- Quick navigation to domain code

### 📊 Dashboard
- Real-time project statistics
- Quick action buttons for common tasks
- Script execution monitoring

### 💻 Integrated Terminal
- Run scripts in integrated PowerShell terminal
- Automatic environment detection
- Configurable terminal behavior

## Requirements

- PowerShell 7.0 or later
- AitherZero installation (auto-detected or configurable)
- VS Code 1.80.0 or later

## Installation

### From VSIX Package
1. Download the `.vsix` file from the releases
2. Open VS Code
3. Go to Extensions (Ctrl+Shift+X)
4. Click the `...` menu
5. Select "Install from VSIX..."
6. Choose the downloaded file

### From Source
```bash
cd vscode-extension
npm install
npm run compile
```

## Usage

### Opening AitherZero
1. Open a workspace containing AitherZero or configure the installation path
2. Click the AitherZero icon in the Activity Bar
3. Browse scripts, playbooks, and domains

### Running Scripts
**Method 1: Tree View**
- Navigate to "Automation Scripts"
- Click on a script to run it

**Method 2: Command Palette**
- Press `Ctrl+Shift+P` (Cmd+Shift+P on Mac)
- Type "AitherZero: Run Script"
- Enter the script number (e.g., 0402)

**Method 3: Dashboard**
- Run `AitherZero: Open Dashboard` command
- Click quick action buttons

### Configuration

Open VS Code settings and search for "AitherZero":

```json
{
  "aitherzero.installationPath": "",  // Auto-detects if empty
  "aitherzero.powerShellPath": "pwsh",
  "aitherzero.autoRefresh": true,
  "aitherzero.showNotifications": true,
  "aitherzero.terminal.clearBeforeRun": false
}
```

### Available Commands

| Command | Description |
|---------|-------------|
| `AitherZero: Run Script` | Execute an automation script |
| `AitherZero: Open Dashboard` | Open the dashboard webview |
| `AitherZero: Refresh Scripts` | Reload the script list |
| `AitherZero: Run Bootstrap` | Run the bootstrap setup |
| `AitherZero: Validate Syntax` | Run syntax validation (0407) |
| `AitherZero: Run Tests` | Execute unit tests (0402) |
| `AitherZero: Open Playbook` | Run an orchestration playbook |

## Extension Settings

### `aitherzero.installationPath`
Path to your AitherZero installation. Leave empty for auto-detection.

**Auto-detection order:**
1. Current workspace (checks for `AitherZero.psd1`)
2. `AITHERZERO_ROOT` environment variable
3. Manual configuration

### `aitherzero.powerShellPath`
Path to the PowerShell executable. Default: `pwsh`

### `aitherzero.autoRefresh`
Automatically refresh script list when files change. Default: `true`

### `aitherzero.showNotifications`
Show notifications for script execution results. Default: `true`

### `aitherzero.terminal.clearBeforeRun`
Clear terminal before running scripts. Default: `false`

## Keyboard Shortcuts

You can add custom keyboard shortcuts in VS Code:

```json
{
  "key": "ctrl+alt+a r",
  "command": "aitherzero.runScript"
},
{
  "key": "ctrl+alt+a d",
  "command": "aitherzero.openDashboard"
}
```

## Troubleshooting

### Extension not detecting AitherZero
1. Check that `AitherZero.psd1` exists in your workspace
2. Set `aitherzero.installationPath` manually in settings
3. Ensure `AITHERZERO_ROOT` environment variable is set

### Scripts not appearing
1. Click the refresh button in the scripts view
2. Check that the `automation-scripts` directory exists
3. Verify PowerShell 7+ is installed and in PATH

### Commands not working
1. Verify PowerShell path in settings
2. Check terminal output for errors
3. Run `pwsh --version` to confirm PowerShell 7+

## Contributing

Contributions are welcome! Please see the main [AitherZero repository](https://github.com/wizzense/AitherZero) for contribution guidelines.

## License

MIT License - see LICENSE file for details.

## Related Links

- [AitherZero GitHub Repository](https://github.com/wizzense/AitherZero)
- [AitherZero Documentation](https://github.com/wizzense/AitherZero/tree/main/docs)
- [PowerShell Documentation](https://docs.microsoft.com/powershell/)

## Release Notes

### 0.1.0
- Initial release
- Automation scripts explorer
- Playbooks management
- Domain browser
- Interactive dashboard
- Integrated terminal support
- Configuration management

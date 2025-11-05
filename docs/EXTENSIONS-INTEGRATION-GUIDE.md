# AitherZero Extensions and Integration Guide

This guide covers the development and usage of AitherZero extensions for VS Code and Windows Admin Center.

## Overview

AitherZero can be extended through:
1. **VS Code Extension** - Development environment integration
2. **Windows Admin Center Extension** - Web-based server management
3. **MCP Server** - AI assistant integration (already implemented)

## VS Code Extension

### Features

The VS Code extension provides:
- **Automation Scripts Explorer**: Browse and run numbered scripts (0000-9999)
- **Playbooks Management**: Execute orchestration workflows
- **Domain Browser**: Explore PowerShell modules and functions
- **Interactive Dashboard**: Real-time project statistics
- **Integrated Terminal**: Run scripts directly from VS Code

### Installation

**From Source:**
```bash
cd vscode-extension
npm install
npm run compile
```

**From VSIX:**
```bash
code --install-extension aitherzero-vscode-0.1.0.vsix
```

### Usage

1. **Open AitherZero Project**
   - Open workspace containing AitherZero
   - Extension auto-detects `AitherZero.psd1`

2. **Browse Scripts**
   - Click AitherZero icon in Activity Bar
   - Navigate script categories
   - Click scripts to run

3. **Use Command Palette**
   - Press `Ctrl+Shift+P`
   - Type "AitherZero"
   - Select desired command

### Configuration

```json
{
  "aitherzero.installationPath": "",
  "aitherzero.powerShellPath": "pwsh",
  "aitherzero.autoRefresh": true,
  "aitherzero.showNotifications": true
}
```

### Development

See [vscode-extension/README.md](../vscode-extension/README.md) for development guide.

## Windows Admin Center Extension

### Features

The Windows Admin Center extension provides:
- **Server Management**: Remote script execution
- **Infrastructure Dashboard**: VM and certificate monitoring
- **Playbook Orchestration**: Multi-server workflows
- **Configuration Management**: Centralized configuration

### Architecture

```
Browser (Angular) → WAC Gateway (PowerShell) → Target Servers (AitherZero)
```

### Requirements

- Windows Admin Center 2103+
- PowerShell 7.0+ on target servers
- AitherZero installed on managed servers
- PowerShell Remoting enabled

### Installation

**For Users:**
1. Download `.nupkg` from releases
2. Upload to Windows Admin Center
3. Configure target servers

**For Developers:**
```bash
cd windows-admin-center
npm install
npm run build
npm run sideload -- --gateway https://localhost:6516
```

### Usage

1. **Access Extension**
   - Open Windows Admin Center
   - Connect to server
   - Navigate to "AitherZero" tool

2. **Run Scripts**
   - Browse automation scripts
   - Select and execute
   - View results in output panel

3. **Manage Infrastructure**
   - Monitor VM status
   - Check certificates
   - Execute playbooks

### Development

See [windows-admin-center/README.md](../windows-admin-center/README.md) for details.

## Integration Patterns

### Common Use Cases

#### 1. Development Workflow (VS Code)
```typescript
// Run tests before commit
aitherzero.runScript('0402');  // Unit tests
aitherzero.runScript('0407');  // Syntax validation
```

#### 2. Server Management (WAC)
```powershell
# Execute on multiple servers
Invoke-AitherZeroScript -ServerName "Server1","Server2" -ScriptNumber "0100"
```

#### 3. AI-Assisted Development (MCP)
```javascript
// Already implemented - see mcp-server/
const mcpServer = require('@aitherzero/mcp-server');
```

### Extension Communication

#### VS Code → PowerShell
```typescript
// Terminal integration
terminal.sendText(`pwsh -File "automation-scripts/0402_Run-UnitTests.ps1"`);
```

#### WAC → Remote Server
```powershell
# Gateway module
Invoke-Command -ComputerName $ServerName -ScriptBlock {
    Import-Module AitherZero
    Invoke-AitherScript -ScriptNumber $ScriptNumber
}
```

## Building and Packaging

### VS Code Extension

```bash
cd vscode-extension
npm install
npm run compile
npm run package  # Creates .vsix file
```

**Output**: `aitherzero-vscode-0.1.0.vsix`

### Windows Admin Center Extension

```bash
cd windows-admin-center
npm install
npm run build
npm run package  # Creates .nupkg file
```

**Output**: `aitherzero-wac-0.1.0.nupkg`

## Distribution

### VS Code Marketplace

1. **Create Publisher**
   ```bash
   vsce create-publisher aitherium
   ```

2. **Publish Extension**
   ```bash
   vsce publish
   ```

3. **Update Version**
   ```bash
   vsce publish minor
   ```

### Windows Admin Center

1. **Package Extension**
   ```bash
   gulp package
   ```

2. **Upload to NuGet**
   ```powershell
   nuget push aitherzero-wac.0.1.0.nupkg -Source https://api.nuget.org/v3/index.json
   ```

3. **Submit to Microsoft**
   - Create submission on [Windows Admin Center feed](https://aka.ms/wac-feed)

## Testing

### VS Code Extension

```bash
# Unit tests
npm run test

# Integration tests
npm run test:integration

# Manual testing
code --extensionDevelopmentPath=$(pwd)
```

### Windows Admin Center Extension

```bash
# Unit tests
npm run test

# E2E tests
npm run e2e

# Side-load for testing
npm run sideload
```

## Security

### VS Code Extension
- Runs in sandboxed environment
- No network access by default
- Uses VS Code's authentication

### Windows Admin Center Extension
- Uses WAC authentication
- PowerShell remoting over WinRM
- HTTPS communication only
- RBAC integration

## Troubleshooting

### VS Code Extension

**Extension not activating:**
```bash
# Check logs
code --log trace --extensionDevelopmentPath=$(pwd)
```

**Scripts not found:**
```json
// Set installation path explicitly
"aitherzero.installationPath": "/path/to/AitherZero"
```

### Windows Admin Center Extension

**Cannot connect to servers:**
```powershell
# Test PowerShell remoting
Test-WSMan -ComputerName ServerName
Enable-PSRemoting -Force
```

**Extension not loading:**
```powershell
# Restart WAC service
Restart-Service ServerManagementGateway
```

## Roadmap

### VS Code Extension
- [ ] IntelliSense for config.psd1
- [ ] Debugging support for scripts
- [ ] Code snippets for common patterns
- [ ] Test result visualization
- [ ] Git integration enhancements

### Windows Admin Center Extension
- [ ] Real-time execution streaming
- [ ] Multi-server bulk operations
- [ ] Azure Monitor integration
- [ ] Configuration templates
- [ ] Advanced dashboard widgets

## Contributing

Contributions welcome! Areas to contribute:

1. **VS Code Extension**
   - New tree view providers
   - Additional commands
   - UI improvements
   - Testing enhancements

2. **Windows Admin Center Extension**
   - Gateway modules
   - Angular components
   - API endpoints
   - Documentation

See [CONTRIBUTING.md](../CONTRIBUTING.md) for guidelines.

## Resources

### VS Code Extension
- [VS Code Extension API](https://code.visualstudio.com/api)
- [Extension Guidelines](https://code.visualstudio.com/api/references/extension-guidelines)
- [Publishing Extensions](https://code.visualstudio.com/api/working-with-extensions/publishing-extension)

### Windows Admin Center
- [WAC Documentation](https://docs.microsoft.com/windows-server/manage/windows-admin-center/)
- [WAC SDK](https://docs.microsoft.com/windows-server/manage/windows-admin-center/extend/extensibility-overview)
- [Develop Extensions](https://docs.microsoft.com/windows-server/manage/windows-admin-center/extend/develop-gateway-plugin)

### AitherZero
- [Main Documentation](./README.md)
- [Architecture Guide](./ARCHITECTURE.md)
- [Development Setup](./COPILOT-DEV-ENVIRONMENT.md)

## Support

- **Issues**: [GitHub Issues](https://github.com/wizzense/AitherZero/issues)
- **Discussions**: [GitHub Discussions](https://github.com/wizzense/AitherZero/discussions)
- **Email**: support@aitherium.com

## License

MIT License - see [LICENSE](../LICENSE) file for details.

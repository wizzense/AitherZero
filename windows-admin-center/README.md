# AitherZero Windows Admin Center Extension

## Overview

The AitherZero Windows Admin Center (WAC) extension provides a web-based interface for managing infrastructure automation directly from Windows Admin Center. This extension enables administrators to leverage AitherZero's automation capabilities within the familiar Windows Admin Center interface.

## Features

### 🖥️ Server Management
- View AitherZero-managed servers
- Execute automation scripts on remote servers
- Monitor script execution status
- View execution history and logs

### 🚀 Automation Workflows
- Browse and execute automation scripts (0000-9999)
- Run orchestration playbooks
- Schedule automated tasks
- Create custom workflows

### 📊 Infrastructure Monitoring
- Real-time server status
- VM inventory and management
- Certificate status monitoring
- Infrastructure health checks

### 🔧 Configuration Management
- Manage server configurations
- Deploy configuration changes
- View configuration drift
- Rollback capabilities

## Architecture

### Extension Components

```
windows-admin-center/
├── manifest.json           # Extension manifest
├── src/
│   ├── gateway/           # PowerShell gateway modules
│   │   ├── AitherZero.psm1
│   │   └── Scripts/       # Gateway scripts
│   ├── app/               # Angular application
│   │   ├── components/
│   │   ├── services/
│   │   └── models/
│   └── assets/            # Static resources
└── README.md
```

### Communication Flow

```
Browser (Angular)
    ↓ HTTP/REST
Windows Admin Center Gateway
    ↓ PowerShell Remoting
Target Server (AitherZero)
```

## Prerequisites

### Windows Admin Center
- Windows Admin Center 2103 or later
- Windows Server 2019 or later (for target servers)
- PowerShell 7.0 or later on target servers

### AitherZero
- AitherZero 1.0.0 or later installed on target servers
- PowerShell Remoting enabled
- Appropriate firewall rules configured

### Development Requirements
- Node.js 14.x or later
- Angular CLI 12.x or later
- Windows Admin Center SDK
- PowerShell 7.0+

## Installation

### For Users

1. **Download the Extension Package**
   ```powershell
   # Download from releases
   $release = "https://github.com/wizzense/AitherZero/releases/latest"
   Invoke-WebRequest -Uri "$release/aitherzero-wac.nupkg" -OutFile "aitherzero-wac.nupkg"
   ```

2. **Install in Windows Admin Center**
   - Open Windows Admin Center
   - Go to Settings → Extensions
   - Click "Upload" or "Install"
   - Select the downloaded `.nupkg` file
   - Restart Windows Admin Center

3. **Configure Target Servers**
   ```powershell
   # On each target server
   Enable-PSRemoting -Force
   Install-Module -Name AitherZero
   ```

### For Developers

1. **Clone the Repository**
   ```bash
   git clone https://github.com/wizzense/AitherZero.git
   cd AitherZero/windows-admin-center
   ```

2. **Install Dependencies**
   ```bash
   npm install
   ```

3. **Build the Extension**
   ```bash
   npm run build
   ```

4. **Side-load for Testing**
   ```bash
   npm run sideload -- --gateway https://localhost:6516
   ```

## Usage

### Accessing the Extension

1. Open Windows Admin Center
2. Connect to a server with AitherZero installed
3. Navigate to "AitherZero" in the Tools menu

### Running Automation Scripts

**Via Script Browser:**
1. Click "Automation Scripts" tab
2. Browse scripts by category (0000-0099, 0100-0199, etc.)
3. Select a script
4. Click "Run" button
5. View results in the output panel

**Via Command Panel:**
1. Click the command palette icon
2. Type script number (e.g., "0402")
3. Press Enter to execute

### Managing Playbooks

1. Navigate to "Playbooks" tab
2. View available playbooks
3. Click "Run" to execute a playbook
4. Monitor progress in real-time
5. View execution logs and results

### Infrastructure Dashboard

1. Click "Dashboard" tab
2. View server inventory
3. Check VM status
4. Monitor certificate expiration
5. Review infrastructure health

## Configuration

### Extension Settings

Configure in Windows Admin Center:

**Settings → Extensions → AitherZero**

| Setting | Description | Default |
|---------|-------------|---------|
| Default PowerShell Version | PowerShell version for remoting | 7.4 |
| Script Timeout | Maximum script execution time (seconds) | 300 |
| Enable Logging | Log script executions | true |
| Log Path | Path for log files | C:\AitherZero\Logs |

### Gateway Configuration

On the Windows Admin Center gateway server:

```powershell
# Configure PowerShell remoting
Set-Item WSMan:\localhost\Client\TrustedHosts -Value "*" -Force
Restart-Service WinRM

# Enable CredSSP (if needed)
Enable-WSManCredSSP -Role Client -DelegateComputer "*" -Force
```

### Target Server Configuration

On servers managed by AitherZero:

```powershell
# Install AitherZero
Install-Module -Name AitherZero

# Configure PowerShell remoting
Enable-PSRemoting -Force

# Allow Windows Admin Center gateway
Set-Item WSMan:\localhost\Client\TrustedHosts -Value "WAC-GATEWAY-HOSTNAME" -Force
```

## Development Guide

### Building the Extension

```bash
# Install dependencies
npm install

# Development build (with watch)
npm run dev

# Production build
npm run build

# Create package
npm run package
```

### Project Structure

```
windows-admin-center/
├── manifest.json              # Extension metadata
├── package.json               # npm configuration
├── tsconfig.json             # TypeScript configuration
├── angular.json              # Angular configuration
├── src/
│   ├── main.ts               # Application entry point
│   ├── app/
│   │   ├── app.module.ts     # Main module
│   │   ├── app.component.ts  # Root component
│   │   ├── components/       # UI components
│   │   │   ├── script-browser/
│   │   │   ├── playbook-manager/
│   │   │   ├── dashboard/
│   │   │   └── settings/
│   │   ├── services/         # Angular services
│   │   │   ├── aitherzero.service.ts
│   │   │   ├── gateway.service.ts
│   │   │   └── logging.service.ts
│   │   └── models/           # TypeScript models
│   ├── gateway/              # PowerShell gateway
│   │   ├── AitherZero.psm1
│   │   └── Scripts/
│   │       ├── Get-Scripts.ps1
│   │       ├── Invoke-Script.ps1
│   │       └── Get-ServerInfo.ps1
│   └── assets/               # Images, icons
├── tests/
│   ├── unit/
│   └── e2e/
└── docs/
    ├── API.md
    └── CONTRIBUTING.md
```

### Adding New Features

1. **Add Gateway PowerShell Module**
   ```powershell
   # src/gateway/Scripts/New-Feature.ps1
   function Invoke-NewFeature {
       param([string]$ServerName)
       # Implementation
   }
   ```

2. **Create Angular Service**
   ```typescript
   // src/app/services/new-feature.service.ts
   export class NewFeatureService {
       constructor(private gateway: GatewayService) {}
       
       invoke(serverName: string): Observable<any> {
           return this.gateway.invoke('Invoke-NewFeature', { ServerName: serverName });
       }
   }
   ```

3. **Add UI Component**
   ```typescript
   // src/app/components/new-feature/new-feature.component.ts
   @Component({
       selector: 'app-new-feature',
       templateUrl: './new-feature.component.html'
   })
   export class NewFeatureComponent {
       constructor(private service: NewFeatureService) {}
   }
   ```

4. **Update Manifest**
   ```json
   {
       "entryPoints": [
           {
               "name": "newFeature",
               "displayName": "New Feature",
               "icon": "icon-path"
           }
       ]
   }
   ```

## API Reference

### Gateway PowerShell Modules

#### Get-AitherZeroScripts
```powershell
Get-AitherZeroScripts [-ServerName <string>] [-Category <string>]
```
Returns list of available automation scripts.

#### Invoke-AitherZeroScript
```powershell
Invoke-AitherZeroScript -ServerName <string> -ScriptNumber <string> [-Parameters <hashtable>]
```
Executes an automation script on the target server.

#### Get-AitherZeroPlaybooks
```powershell
Get-AitherZeroPlaybooks [-ServerName <string>]
```
Returns available orchestration playbooks.

#### Invoke-AitherZeroPlaybook
```powershell
Invoke-AitherZeroPlaybook -ServerName <string> -PlaybookName <string>
```
Runs an orchestration playbook.

### Angular Services

#### AitherZeroService
```typescript
class AitherZeroService {
    getScripts(category?: string): Observable<Script[]>
    runScript(scriptNumber: string, params?: any): Observable<ScriptResult>
    getPlaybooks(): Observable<Playbook[]>
    runPlaybook(name: string): Observable<PlaybookResult>
}
```

#### GatewayService
```typescript
class GatewayService {
    invoke(method: string, params: any): Observable<any>
    invokeAsync(method: string, params: any): Observable<any>
}
```

## Testing

### Unit Tests
```bash
npm run test
```

### E2E Tests
```bash
npm run e2e
```

### Manual Testing
1. Side-load extension in Windows Admin Center
2. Connect to test server
3. Execute test scenarios
4. Verify functionality

## Security Considerations

### Authentication
- Uses Windows Admin Center's built-in authentication
- Supports Windows authentication and Azure AD
- No separate credentials required

### Authorization
- Leverages Windows Admin Center RBAC
- Respects PowerShell remoting permissions
- Audit logging for all operations

### Communication
- All communication over HTTPS
- Uses Windows Admin Center gateway
- PowerShell remoting over WinRM

### Best Practices
1. Use least-privilege accounts
2. Enable audit logging
3. Restrict gateway access
4. Keep extensions updated
5. Monitor execution logs

## Troubleshooting

### Extension Not Loading
- Verify Windows Admin Center version (2103+)
- Check browser console for errors
- Restart Windows Admin Center service
- Clear browser cache

### Cannot Connect to Servers
- Verify PowerShell remoting is enabled
- Check firewall rules (port 5985/5986)
- Verify TrustedHosts configuration
- Test with `Test-WSMan`

### Scripts Failing to Execute
- Check target server has AitherZero installed
- Verify script permissions
- Review execution logs
- Check PowerShell version (7.0+)

### Performance Issues
- Reduce script timeout value
- Limit concurrent executions
- Check network latency
- Review gateway resources

## Roadmap

### Planned Features
- [ ] Real-time script execution streaming
- [ ] Multi-server bulk operations
- [ ] Custom dashboard widgets
- [ ] Integration with Azure Monitor
- [ ] Schedule task automation
- [ ] Configuration templates library
- [ ] Advanced filtering and search
- [ ] Export/import configurations

### Version History

**0.1.0 (Planned)**
- Initial release
- Basic script execution
- Playbook management
- Infrastructure dashboard
- Server inventory

## Contributing

Contributions are welcome! Please see:
- [Contributing Guide](../../CONTRIBUTING.md)
- [Code of Conduct](../../CODE_OF_CONDUCT.md)
- [Development Setup](./docs/CONTRIBUTING.md)

## Support

- **Issues**: [GitHub Issues](https://github.com/wizzense/AitherZero/issues)
- **Documentation**: [AitherZero Docs](https://github.com/wizzense/AitherZero/docs)
- **Community**: [Discussions](https://github.com/wizzense/AitherZero/discussions)

## License

MIT License - see [LICENSE](../../LICENSE) file for details.

## Related Resources

- [Windows Admin Center Documentation](https://docs.microsoft.com/windows-server/manage/windows-admin-center/)
- [Windows Admin Center SDK](https://docs.microsoft.com/windows-server/manage/windows-admin-center/extend/extensibility-overview)
- [AitherZero Documentation](https://github.com/wizzense/AitherZero/tree/main/docs)
- [PowerShell Remoting](https://docs.microsoft.com/powershell/scripting/learn/remoting/running-remote-commands)

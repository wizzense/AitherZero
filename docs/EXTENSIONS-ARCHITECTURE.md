# AitherZero Extensions Architecture

## Overview

AitherZero extensions provide multiple interfaces for infrastructure automation:

```
┌─────────────────────────────────────────────────────────────────┐
│                     AitherZero Platform                          │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │              Core PowerShell Modules                      │  │
│  │  • 11 Domains • 192+ Functions • 125+ Scripts            │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                              ▲
                              │
        ┌─────────────────────┼─────────────────────┐
        │                     │                     │
┌───────▼──────────┐  ┌──────▼────────┐  ┌────────▼──────────┐
│  VS Code         │  │   Windows     │  │   MCP Server      │
│  Extension       │  │   Admin       │  │   (AI Agents)     │
│                  │  │   Center      │  │                   │
│  • Script Tree   │  │                │  │  • Claude         │
│  • Dashboard     │  │  • Web UI      │  │  • Copilot        │
│  • Terminal      │  │  • Remote Exec │  │  • Natural Lang   │
└──────────────────┘  └────────────────┘  └───────────────────┘
```

## Extension Types

### 1. VS Code Extension (Development Interface)

**Purpose**: Integrate AitherZero into the development environment

**Architecture**:
```
┌─────────────────────────────────────────────────┐
│             VS Code Extension                    │
├─────────────────────────────────────────────────┤
│  Extension Host (TypeScript)                    │
│  ├── Tree Data Providers                        │
│  │   ├── ScriptTreeProvider                     │
│  │   ├── PlaybookTreeProvider                   │
│  │   └── DomainTreeProvider                     │
│  ├── Commands                                   │
│  │   ├── runScript()                            │
│  │   ├── openDashboard()                        │
│  │   └── refreshScripts()                       │
│  ├── Webview Panels                             │
│  │   └── DashboardPanel                         │
│  └── Terminal Integration                       │
│      └── AitherZeroTerminal                     │
├─────────────────────────────────────────────────┤
│  VS Code API                                    │
├─────────────────────────────────────────────────┤
│  PowerShell Terminal                            │
│  └── Execute: pwsh -File script.ps1            │
├─────────────────────────────────────────────────┤
│  AitherZero Module                              │
└─────────────────────────────────────────────────┘
```

**Communication Flow**:
1. User clicks script in tree view
2. Extension calls `terminal.sendText()`
3. PowerShell terminal executes script
4. Output displayed in terminal
5. Extension updates dashboard if needed

**Key Files**:
- `vscode-extension/src/extension.ts` - Main activation
- `vscode-extension/src/scriptTreeProvider.ts` - Script browser
- `vscode-extension/src/dashboardPanel.ts` - Dashboard UI
- `vscode-extension/src/terminal.ts` - Terminal integration

### 2. Windows Admin Center Extension (Server Management)

**Purpose**: Remote infrastructure management through web interface

**Architecture**:
```
┌─────────────────────────────────────────────────────────┐
│                   Browser (Client)                       │
│  ┌───────────────────────────────────────────────────┐  │
│  │         Angular Application                        │  │
│  │  ├── Dashboard Component                          │  │
│  │  ├── Script Browser Component                     │  │
│  │  ├── Playbook Manager Component                   │  │
│  │  └── AitherZero Service (REST calls)              │  │
│  └───────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
                          │ HTTP/REST
                          ▼
┌─────────────────────────────────────────────────────────┐
│         Windows Admin Center Gateway                     │
│  ┌───────────────────────────────────────────────────┐  │
│  │      PowerShell Gateway Module                    │  │
│  │  ├── Get-AitherZeroScripts()                      │  │
│  │  ├── Invoke-AitherZeroScript()                    │  │
│  │  ├── Get-AitherZeroPlaybooks()                    │  │
│  │  └── Get-AitherZeroServerInfo()                   │  │
│  └───────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
                          │ WinRM/PSRemoting
                          ▼
┌─────────────────────────────────────────────────────────┐
│              Target Server(s)                            │
│  ┌───────────────────────────────────────────────────┐  │
│  │         AitherZero Module                         │  │
│  │  ├── automation-scripts/                          │  │
│  │  ├── domains/                                     │  │
│  │  └── orchestration/playbooks/                     │  │
│  └───────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

**Communication Flow**:
1. User clicks "Run Script" in web UI
2. Angular app sends POST to `/api/aitherzero/invoke-script`
3. Gateway invokes `Invoke-AitherZeroScript -ServerName X -ScriptNumber Y`
4. Gateway uses `Invoke-Command` for remote execution
5. Target server runs script via AitherZero module
6. Results returned through gateway to browser
7. UI displays output and status

**Key Files**:
- `windows-admin-center/manifest.json` - Extension manifest
- `windows-admin-center/src/gateway/AitherZero.psm1` - Gateway module
- `windows-admin-center/src/app/` - Angular application (future)

### 3. MCP Server (AI Assistant Integration)

**Purpose**: Enable AI assistants to interact with AitherZero

**Architecture**:
```
┌─────────────────────────────────────────────────┐
│         AI Assistant (Claude, Copilot)          │
│  ├── User: "Run unit tests on AitherZero"      │
│  └── AI interprets and calls MCP tools         │
└─────────────────────────────────────────────────┘
                     │ JSON-RPC
                     ▼
┌─────────────────────────────────────────────────┐
│           MCP Server (Node.js)                  │
│  ├── Tool: run_script                           │
│  ├── Tool: list_scripts                         │
│  ├── Tool: get_status                           │
│  └── Executes: pwsh -File script.ps1           │
└─────────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────┐
│           AitherZero Module                     │
└─────────────────────────────────────────────────┘
```

**Already Implemented**: See `mcp-server/` directory

## Data Flow Patterns

### Local Execution (VS Code)

```
User Input → VS Code Extension → Terminal → PowerShell → AitherZero Module → Result
```

**Example**:
```typescript
// User clicks "0402 - Run Unit Tests"
terminal.sendText('pwsh -File automation-scripts/0402_Run-UnitTests.ps1');
```

### Remote Execution (WAC)

```
Browser UI → HTTP Request → Gateway → PSRemoting → Target Server → AitherZero → Result
```

**Example**:
```powershell
# Gateway receives request
Invoke-AitherZeroScript -ServerName "Server01" -ScriptNumber "0402"

# Gateway executes via remoting
Invoke-Command -ComputerName "Server01" -ScriptBlock {
    Import-Module AitherZero
    & "C:\AitherZero\automation-scripts\0402_Run-UnitTests.ps1"
}
```

### AI-Driven Execution (MCP)

```
Natural Language → AI → MCP Protocol → MCP Server → PowerShell → AitherZero → Result
```

**Example**:
```
User: "Check the syntax of all PowerShell files"
AI calls: run_script(scriptNumber: "0407", parameters: {All: true})
MCP executes: pwsh -File automation-scripts/0407_Validate-Syntax.ps1 -All
```

## Security Architecture

### VS Code Extension

**Sandboxing**:
- Runs in VS Code's extension host process
- No network access by default
- File system access limited to workspace
- Uses VS Code's authentication for remote features

**Trust**:
- User must trust workspace to execute scripts
- Extension respects workspace trust settings
- Terminal execution requires user confirmation

### Windows Admin Center Extension

**Authentication**:
```
Browser → HTTPS → WAC Gateway (Auth) → WinRM (Kerberos/NTLM) → Target Server
```

**Authorization**:
- Uses Windows Admin Center RBAC
- Respects PowerShell remoting permissions
- Gateway runs with least privilege
- Target server enforces script execution policy

**Audit**:
- All operations logged by WAC
- PowerShell transcript logging on target
- Can integrate with SIEM systems

### MCP Server

**Isolation**:
- Runs as separate Node.js process
- Communicates via stdio (no network)
- Limited to configured tools only
- Cannot access arbitrary files

**Control**:
- AI can only call defined tools
- Parameters validated before execution
- Results sanitized before return
- User approval for sensitive operations

## Performance Considerations

### VS Code Extension

**Optimization**:
- Lazy loading of tree data
- Caching script metadata
- Async operations for file I/O
- Debounced file system watchers

**Expected Performance**:
- Tree view load: <100ms for 125 scripts
- Dashboard render: <200ms
- Script execution: Depends on script (1s - 5min)

### Windows Admin Center Extension

**Optimization**:
- Connection pooling for PSRemoting sessions
- Result caching for frequently accessed data
- Parallel execution for multi-server operations
- Progressive loading for large result sets

**Expected Performance**:
- Initial page load: 1-2 seconds
- Script list fetch: <500ms
- Script execution: Network latency + script time
- Multi-server (10 servers): 2x single server time (parallel)

### MCP Server

**Optimization**:
- Already implemented and optimized
- Async tool execution
- Streaming output for long operations
- Process reuse for multiple requests

**Expected Performance**:
- Tool discovery: <50ms
- Script execution: Same as direct execution
- Result serialization: <100ms

## Scalability

### VS Code Extension

**Limits**:
- Single workspace per window
- Local execution only (by design)
- Terminal output buffer limits

**Scaling**:
- Multiple VS Code windows for multiple projects
- Use Remote-SSH for remote development
- Offload heavy operations to separate terminals

### Windows Admin Center Extension

**Limits**:
- Concurrent PSRemoting sessions: ~100 per gateway
- Browser WebSocket connections: ~20 per browser
- Script execution timeout: Configurable (default 5 min)

**Scaling**:
- Load balancing across multiple WAC gateways
- Queue system for large-scale operations
- Background job processing for long-running scripts
- Distributed execution across multiple gateways

### MCP Server

**Limits**:
- One MCP server per AI assistant session
- Single operation at a time (sequential)
- Memory limited by Node.js process

**Scaling**:
- Multiple MCP server instances for multiple assistants
- Use async operations for I/O bound tasks
- Offload compute to AitherZero module

## Extension Comparison

| Feature | VS Code | Windows Admin Center | MCP Server |
|---------|---------|----------------------|------------|
| **Target User** | Developers | Administrators | AI Assistants |
| **Execution** | Local | Remote | Local/Remote |
| **UI Type** | Native | Web | None (API) |
| **Multi-Server** | No | Yes | Possible |
| **Real-Time** | Terminal | WebSocket | Streaming |
| **Authentication** | VS Code | WAC + Windows | stdio |
| **Best For** | Development | Operations | Automation |

## Future Enhancements

### VS Code Extension
- [ ] IntelliSense for config.psd1
- [ ] Debugging integration
- [ ] Test result visualization
- [ ] Code snippets
- [ ] Git commit hooks integration

### Windows Admin Center Extension
- [ ] Real-time execution streaming
- [ ] Multi-server bulk operations
- [ ] Azure Monitor integration
- [ ] Custom dashboard widgets
- [ ] Configuration templates

### Cross-Extension Features
- [ ] Unified logging across extensions
- [ ] Shared execution history
- [ ] Common authentication
- [ ] Synchronized settings
- [ ] Extension marketplace

## Development Workflow

### Adding New Features

**VS Code Extension**:
```typescript
// 1. Add command to package.json
{
  "command": "aitherzero.newFeature",
  "title": "New Feature"
}

// 2. Register command in extension.ts
context.subscriptions.push(
  vscode.commands.registerCommand('aitherzero.newFeature', () => {
    // Implementation
  })
);

// 3. Add to tree view or menu if needed
```

**Windows Admin Center Extension**:
```powershell
# 1. Add gateway function
function Invoke-NewFeature {
    param([string]$ServerName)
    # Implementation
}

# 2. Export function
Export-ModuleMember -Function 'Invoke-NewFeature'

# 3. Add Angular component (future)
# 4. Wire up REST endpoint
```

## Testing Strategy

### VS Code Extension
- Unit tests with Mocha
- Integration tests with VS Code Test API
- Manual testing with extension development host

### Windows Admin Center Extension
- Gateway module: Pester tests
- Angular app: Jasmine/Karma tests
- E2E tests with Protractor
- Manual testing with side-loaded extension

### Integration Testing
- Test VS Code with actual AitherZero workspace
- Test WAC with remote servers
- Validate all communication paths
- Performance testing under load

## Deployment

### VS Code Extension
```bash
# Build
npm run compile

# Package
vsce package

# Publish
vsce publish
```

### Windows Admin Center Extension
```bash
# Build
npm run build

# Package
gulp package

# Publish
nuget push aitherzero-wac.nupkg
```

## Monitoring & Diagnostics

### VS Code Extension
- Use VS Code Output panel
- Extension logs in Output → Log (Extension Host)
- Debug with F5 (Extension Development Host)

### Windows Admin Center Extension
- Browser DevTools for frontend
- Windows Event Log for gateway
- PowerShell transcript logs on targets
- WAC built-in diagnostics

### MCP Server
- Already has logging to stderr
- JSON-RPC protocol debugging
- AI assistant debug logs

## Resources

- [VS Code Extension API](https://code.visualstudio.com/api)
- [Windows Admin Center SDK](https://docs.microsoft.com/windows-server/manage/windows-admin-center/extend/extensibility-overview)
- [Model Context Protocol](https://modelcontextprotocol.io/)
- [AitherZero Documentation](https://github.com/wizzense/AitherZero/tree/main/docs)

---

**Last Updated**: 2025-11-05
**Version**: 1.0.0
**Status**: Architecture defined, VS Code implemented, WAC gateway implemented, Angular UI pending

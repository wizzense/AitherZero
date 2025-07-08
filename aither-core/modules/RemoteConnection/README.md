# RemoteConnection Module

## Test Status
- **Last Run**: 2025-07-08 17:29:43 UTC
- **Status**: ✅ PASSING (10/10 tests)
- **Coverage**: 0%
- **Platform**: ✅ Windows ✅ Linux ✅ macOS
- **Dependencies**: ✅ All resolved

## Test Results
| Test Suite | Status | Tests | Coverage | Duration |
|------------|--------|-------|----------|----------|
| Unit Tests | ✅ PASS | 10/10 | 0% | 1s |

---
*Test status updated automatically by AitherZero Testing Framework*
## Test Results
| Test Suite | Status | Tests | Coverage | Duration |
|------------|--------|-------|----------|----------|
| Unit Tests | ✅ PASS | 11/11 | 0% | 0.5s |

---
*Test status updated automatically by AitherZero Testing Framework*
## Test Results
| Test Suite | Status | Tests | Coverage | Duration |
|------------|--------|-------|----------|----------|
| Unit Tests | ✅ PASS | 11/11 | 0% | 1.5s |

---
*Test status updated automatically by AitherZero Testing Framework*
## Test Results
| Test Suite | Status | Tests | Coverage | Duration |
|------------|--------|-------|----------|----------|
| Unit Tests | ✅ PASS | 11/11 | 0% | 1.5s |

---
*Test status updated automatically by AitherZero Testing Framework*
## Test Results
| Test Suite | Status | Tests | Coverage | Duration |
|------------|--------|-------|----------|----------|
| Unit Tests | ✅ PASS | 11/11 | 0% | 1.5s |

---
*Test status updated automatically by AitherZero Testing Framework*
## Module Overview

The **RemoteConnection** module provides comprehensive remote connection capabilities for the entire AitherZero infrastructure automation project. It supports multiple connection types, secure authentication, and integration with credential management systems, enabling seamless management of diverse infrastructure endpoints.

### Core Functionality and Purpose

- **Multi-Protocol Support**: SSH, WinRM, VMware vSphere, Hyper-V, Docker, and Kubernetes connections
- **Secure Authentication**: Integration with SecureCredentials module for credential management
- **Connection Management**: Create, store, retrieve, and manage connection configurations
- **Cross-Platform**: Works seamlessly on Windows, Linux, and macOS
- **Enterprise-Grade**: Built for managing large-scale infrastructure with multiple endpoints

### Architecture and Design Patterns

The module implements a **connection factory pattern** with protocol-specific adapters for each connection type. It uses a **configuration repository pattern** to persist connection settings securely, and integrates with the AitherZero logging system for comprehensive audit trails.

### Key Features

- **Protocol Abstraction**: Unified interface for different connection types
- **Connection Pooling**: Reuse connections for improved performance
- **Automatic Reconnection**: Handle network interruptions gracefully
- **Credential Integration**: Seamless integration with SecureCredentials module
- **Connection Health Monitoring**: Test and validate connections
- **Bulk Operations**: Execute commands across multiple endpoints

## Directory Structure

```
RemoteConnection/
├── RemoteConnection.psd1       # Module manifest
├── RemoteConnection.psm1       # Main module loader
├── Public/                     # Exported functions
│   ├── Connect-RemoteEndpoint.ps1
│   ├── Disconnect-RemoteEndpoint.ps1
│   ├── Get-RemoteConnection.ps1
│   ├── Invoke-RemoteCommand.ps1
│   └── New-RemoteConnection.ps1
├── Private/                    # Internal functions
│   └── ConnectionHelpers.ps1
└── README.md                   # This documentation
```

### Module Files and Organization

#### Public Functions
- **New-RemoteConnection.ps1**: Creates new connection configurations
- **Get-RemoteConnection.ps1**: Retrieves existing connection configurations
- **Connect-RemoteEndpoint.ps1**: Establishes connections to remote endpoints
- **Disconnect-RemoteEndpoint.ps1**: Closes active connections
- **Invoke-RemoteCommand.ps1**: Executes commands on remote endpoints

#### Private Functions
- **ConnectionHelpers.ps1**: Internal helper functions for connection management

## Function Reference

### New-RemoteConnection

Creates a new remote connection configuration for enterprise-wide use.

#### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| ConnectionName | string | Yes | Unique name for the connection configuration |
| EndpointType | string | Yes | Type of remote endpoint: SSH, WinRM, VMware, Hyper-V, Docker, Kubernetes |
| HostName | string | Yes | Hostname or IP address of the remote endpoint |
| Port | int | No | Port number for the connection (uses standard ports if not specified) |
| CredentialName | string | No | Name of the stored credential to use for authentication |
| ConnectionTimeout | int | No | Timeout in seconds for connection attempts (default: 30) |
| EnableSSL | switch | No | Enable SSL/TLS encryption for supported connection types |
| Force | switch | No | Overwrite existing connection configuration |

#### Returns

- **hashtable**: Connection creation result with properties:
  - Success: Boolean indicating success
  - ConnectionName: Name of the created connection
  - EndpointType: Type of endpoint
  - HostName: Target hostname
  - Port: Connection port
  - ConfigFile: Path to configuration file
  - CreatedDate: Creation timestamp

#### Examples

```powershell
# Create Hyper-V connection
New-RemoteConnection -ConnectionName "HyperV-Lab-01" `
    -EndpointType "Hyper-V" `
    -HostName "hyperv.lab.local" `
    -CredentialName "HyperV-Admin"

# Create Docker connection with SSL
New-RemoteConnection -ConnectionName "Docker-Dev" `
    -EndpointType "Docker" `
    -HostName "docker.dev.local" `
    -Port 2376 `
    -EnableSSL

# Create SSH connection with custom port
New-RemoteConnection -ConnectionName "Linux-Web-01" `
    -EndpointType "SSH" `
    -HostName "web01.example.com" `
    -Port 2222 `
    -CredentialName "LinuxAdmin"
```

### Get-RemoteConnection

Retrieves existing connection configurations.

#### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| ConnectionName | string | No | Name of specific connection to retrieve |
| EndpointType | string | No | Filter by endpoint type |
| HostName | string | No | Filter by hostname |

#### Returns

- **PSCustomObject[]**: Array of connection configurations

#### Examples

```powershell
# Get all connections
$connections = Get-RemoteConnection

# Get specific connection
$hyperVConnection = Get-RemoteConnection -ConnectionName "HyperV-Lab-01"

# Get all SSH connections
$sshConnections = Get-RemoteConnection -EndpointType "SSH"

# Get connections for specific host
$hostConnections = Get-RemoteConnection -HostName "hyperv.lab.local"
```

### Connect-RemoteEndpoint

Establishes a connection to a remote endpoint.

#### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| ConnectionName | string | Yes* | Name of the connection configuration |
| HostName | string | Yes* | Direct hostname (if not using ConnectionName) |
| EndpointType | string | No | Type of endpoint (required if using HostName) |
| Credential | PSCredential | No | Credential object for authentication |
| PassThru | switch | No | Return the connection object |

*Either ConnectionName or HostName is required

#### Returns

- **object**: Connection object (if PassThru is specified)

#### Examples

```powershell
# Connect using saved configuration
Connect-RemoteEndpoint -ConnectionName "HyperV-Lab-01"

# Direct connection with credentials
$cred = Get-Credential
Connect-RemoteEndpoint -HostName "server.example.com" `
    -EndpointType "WinRM" `
    -Credential $cred

# Connect and get connection object
$connection = Connect-RemoteEndpoint -ConnectionName "Docker-Dev" -PassThru
```

### Disconnect-RemoteEndpoint

Closes an active connection to a remote endpoint.

#### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| ConnectionName | string | Yes* | Name of the connection |
| Connection | object | Yes* | Connection object to close |
| Force | switch | No | Force disconnection without cleanup |

*Either ConnectionName or Connection is required

#### Examples

```powershell
# Disconnect by name
Disconnect-RemoteEndpoint -ConnectionName "HyperV-Lab-01"

# Disconnect using connection object
Disconnect-RemoteEndpoint -Connection $connection

# Force disconnect
Disconnect-RemoteEndpoint -ConnectionName "Docker-Dev" -Force
```

### Invoke-RemoteCommand

Executes commands on remote endpoints.

#### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| ConnectionName | string | Yes* | Name of the connection |
| Connection | object | Yes* | Active connection object |
| Command | string | Yes | Command to execute |
| ScriptBlock | scriptblock | No | ScriptBlock for PowerShell endpoints |
| ArgumentList | object[] | No | Arguments for ScriptBlock |
| AsJob | switch | No | Run command as background job |
| TimeoutSeconds | int | No | Command execution timeout |

*Either ConnectionName or Connection is required

#### Returns

- **object**: Command execution result

#### Examples

```powershell
# Execute simple command
$result = Invoke-RemoteCommand -ConnectionName "Linux-Web-01" `
    -Command "df -h"

# Execute PowerShell ScriptBlock
$result = Invoke-RemoteCommand -ConnectionName "HyperV-Lab-01" `
    -ScriptBlock { Get-VM | Select-Object Name, State }

# Execute with parameters
$result = Invoke-RemoteCommand -ConnectionName "Windows-DC-01" `
    -ScriptBlock { param($ServiceName) Get-Service -Name $ServiceName } `
    -ArgumentList "Spooler"

# Execute as job
$job = Invoke-RemoteCommand -ConnectionName "Docker-Dev" `
    -Command "docker ps -a" `
    -AsJob
```

### Additional Functions

- **Remove-RemoteConnection**: Delete a connection configuration
- **Test-RemoteConnection**: Test connectivity to an endpoint

## Key Features

### Protocol Support

#### SSH Connections
- Support for key-based and password authentication
- Configurable SSH options (StrictHostKeyChecking, etc.)
- Compatible with OpenSSH and most SSH implementations

```powershell
# SSH with key authentication
New-RemoteConnection -ConnectionName "Ubuntu-Server" `
    -EndpointType "SSH" `
    -HostName "ubuntu.example.com" `
    -CredentialName "SSH-Key-Ubuntu"

# Execute Linux commands
Invoke-RemoteCommand -ConnectionName "Ubuntu-Server" `
    -Command "sudo apt update && sudo apt upgrade -y"
```

#### WinRM Connections
- Support for HTTP/HTTPS connections
- Kerberos, NTLM, and Basic authentication
- PowerShell remoting capabilities

```powershell
# WinRM over HTTPS
New-RemoteConnection -ConnectionName "Windows-Server" `
    -EndpointType "WinRM" `
    -HostName "win-server.domain.local" `
    -EnableSSL `
    -CredentialName "DomainAdmin"

# Execute PowerShell remotely
Invoke-RemoteCommand -ConnectionName "Windows-Server" `
    -ScriptBlock { Get-WindowsFeature | Where-Object Installed }
```

#### VMware vSphere
- Direct connection to vCenter or ESXi hosts
- Full PowerCLI command support
- Certificate validation options

```powershell
# VMware vCenter connection
New-RemoteConnection -ConnectionName "vCenter-Prod" `
    -EndpointType "VMware" `
    -HostName "vcenter.datacenter.local" `
    -CredentialName "vCenterAdmin"

# Manage VMware infrastructure
Invoke-RemoteCommand -ConnectionName "vCenter-Prod" `
    -ScriptBlock { 
        Get-VM | Where-Object PowerState -eq "PoweredOff" | 
        Select-Object Name, NumCpu, MemoryGB 
    }
```

#### Hyper-V
- Direct or remote Hyper-V host management
- Support for clustered environments
- Integration with Windows authentication

```powershell
# Hyper-V host connection
New-RemoteConnection -ConnectionName "HyperV-Cluster-01" `
    -EndpointType "Hyper-V" `
    -HostName "hyperv01.local" `
    -CredentialName "HyperVAdmin"

# Manage Hyper-V VMs
Invoke-RemoteCommand -ConnectionName "HyperV-Cluster-01" `
    -ScriptBlock { 
        Get-VM | Start-VM -Passthru | 
        Select-Object Name, State, Uptime 
    }
```

#### Docker
- Docker daemon API connections
- Support for TLS authentication
- Container and image management

```powershell
# Docker with TLS
New-RemoteConnection -ConnectionName "Docker-Swarm" `
    -EndpointType "Docker" `
    -HostName "docker-manager.local" `
    -Port 2376 `
    -EnableSSL

# Docker operations
Invoke-RemoteCommand -ConnectionName "Docker-Swarm" `
    -Command "docker service ls"
```

#### Kubernetes
- kubectl compatible connections
- Support for multiple authentication methods
- Namespace-aware operations

```powershell
# Kubernetes cluster connection
New-RemoteConnection -ConnectionName "K8s-Production" `
    -EndpointType "Kubernetes" `
    -HostName "k8s-api.cluster.local" `
    -Port 6443 `
    -CredentialName "K8s-Admin"

# Kubernetes operations
Invoke-RemoteCommand -ConnectionName "K8s-Production" `
    -Command "kubectl get pods --all-namespaces"
```

## Usage Examples

### Real-World Scenarios

#### Multi-Environment Deployment
```powershell
# Define environments
$environments = @(
    @{Name = "Dev"; Type = "SSH"; Host = "dev.example.com"},
    @{Name = "Test"; Type = "WinRM"; Host = "test.example.com"},
    @{Name = "Prod"; Type = "SSH"; Host = "prod.example.com"}
)

# Create connections for all environments
foreach ($env in $environments) {
    New-RemoteConnection -ConnectionName "Deploy-$($env.Name)" `
        -EndpointType $env.Type `
        -HostName $env.Host `
        -CredentialName "DeploymentCreds"
}

# Deploy to all environments
function Deploy-Application {
    param($Version)
    
    $environments | ForEach-Object {
        $connName = "Deploy-$($_.Name)"
        Write-Host "Deploying to $($_.Name) environment..."
        
        if ($_.Type -eq "SSH") {
            Invoke-RemoteCommand -ConnectionName $connName `
                -Command "cd /opt/app && git pull && docker-compose up -d --build"
        } else {
            Invoke-RemoteCommand -ConnectionName $connName `
                -ScriptBlock {
                    Set-Location C:\Apps\MyApp
                    git pull
                    .\Deploy.ps1 -Version $using:Version
                }
        }
    }
}
```

#### Infrastructure Health Check
```powershell
function Get-InfrastructureHealth {
    $results = @()
    
    # Check all Hyper-V hosts
    Get-RemoteConnection -EndpointType "Hyper-V" | ForEach-Object {
        $health = Invoke-RemoteCommand -ConnectionName $_.Name `
            -ScriptBlock {
                @{
                    Host = $env:COMPUTERNAME
                    VMs = (Get-VM).Count
                    RunningVMs = (Get-VM | Where-Object State -eq 'Running').Count
                    Memory = Get-VMHost | Select-Object -ExpandProperty MemoryCapacity
                    CPUUsage = (Get-Counter "\Processor(_Total)\% Processor Time").CounterSamples.CookedValue
                }
            }
        $results += $health
    }
    
    # Check Docker hosts
    Get-RemoteConnection -EndpointType "Docker" | ForEach-Object {
        $health = Invoke-RemoteCommand -ConnectionName $_.Name `
            -Command "docker system df --format json"
        $results += @{
            Host = $_.HostName
            Type = "Docker"
            Health = $health | ConvertFrom-Json
        }
    }
    
    return $results
}
```

### Integration Patterns

#### With SecureCredentials Module
```powershell
# Store credentials securely
Import-Module SecureCredentials
New-SecureCredential -CredentialName "ProdAdmin" -Username "admin@prod.local"

# Use stored credentials for connections
New-RemoteConnection -ConnectionName "Prod-Server-01" `
    -EndpointType "WinRM" `
    -HostName "server01.prod.local" `
    -CredentialName "ProdAdmin" `
    -EnableSSL

# Connection automatically retrieves and uses stored credentials
Connect-RemoteEndpoint -ConnectionName "Prod-Server-01"
```

#### Bulk Operations
```powershell
function Invoke-BulkCommand {
    param(
        [string[]]$ConnectionNames,
        [scriptblock]$ScriptBlock,
        [switch]$Parallel
    )
    
    if ($Parallel) {
        $jobs = $ConnectionNames | ForEach-Object {
            Start-Job -Name $_ -ScriptBlock {
                param($ConnName, $Script)
                Import-Module RemoteConnection
                Invoke-RemoteCommand -ConnectionName $ConnName -ScriptBlock $Script
            } -ArgumentList $_, $ScriptBlock
        }
        
        $jobs | Wait-Job | Receive-Job
        $jobs | Remove-Job
    } else {
        $ConnectionNames | ForEach-Object {
            Write-Host "Executing on $_..." -ForegroundColor Cyan
            Invoke-RemoteCommand -ConnectionName $_ -ScriptBlock $ScriptBlock
        }
    }
}

# Usage
$servers = Get-RemoteConnection -EndpointType "WinRM" | Select-Object -ExpandProperty Name
Invoke-BulkCommand -ConnectionNames $servers -ScriptBlock {
    Get-Service | Where-Object Status -eq 'Stopped' | 
    Select-Object Name, StartType
} -Parallel
```

### Code Snippets

#### Connection Pool Manager
```powershell
class ConnectionPool {
    [hashtable]$ActiveConnections = @{}
    [int]$MaxConnections = 10
    [timespan]$ConnectionTimeout = [timespan]::FromMinutes(5)
    
    [object] GetConnection([string]$ConnectionName) {
        # Check if connection exists and is valid
        if ($this.ActiveConnections.ContainsKey($ConnectionName)) {
            $conn = $this.ActiveConnections[$ConnectionName]
            if ((Get-Date) - $conn.LastUsed -lt $this.ConnectionTimeout) {
                $conn.LastUsed = Get-Date
                return $conn.Connection
            } else {
                # Connection expired, remove it
                $this.CloseConnection($ConnectionName)
            }
        }
        
        # Create new connection
        if ($this.ActiveConnections.Count -ge $this.MaxConnections) {
            # Remove oldest connection
            $oldest = $this.ActiveConnections.GetEnumerator() | 
                Sort-Object { $_.Value.LastUsed } | 
                Select-Object -First 1
            $this.CloseConnection($oldest.Key)
        }
        
        $connection = Connect-RemoteEndpoint -ConnectionName $ConnectionName -PassThru
        $this.ActiveConnections[$ConnectionName] = @{
            Connection = $connection
            Created = Get-Date
            LastUsed = Get-Date
        }
        
        return $connection
    }
    
    [void] CloseConnection([string]$ConnectionName) {
        if ($this.ActiveConnections.ContainsKey($ConnectionName)) {
            Disconnect-RemoteEndpoint -Connection $this.ActiveConnections[$ConnectionName].Connection
            $this.ActiveConnections.Remove($ConnectionName)
        }
    }
    
    [void] CloseAll() {
        $this.ActiveConnections.Keys | ForEach-Object {
            $this.CloseConnection($_)
        }
    }
}

# Usage
$pool = [ConnectionPool]::new()
$conn = $pool.GetConnection("HyperV-Lab-01")
```

## Configuration

### Connection Settings

#### Default Ports by Protocol
- SSH: 22
- WinRM (HTTP): 5985
- WinRM (HTTPS): 5986
- VMware: 443
- Hyper-V: 5985
- Docker (HTTP): 2375
- Docker (HTTPS): 2376
- Kubernetes: 6443

#### Connection Metadata Storage
Connections are stored in JSON format at:
- Windows: `$env:APPDATA\AitherZero\Connections\`
- Linux/macOS: `~/.aitherzero/connections/`

### Protocol-Specific Options

#### SSH Options
```powershell
$connectionConfig.SSHOptions = @{
    StrictHostKeyChecking = $false
    UserKnownHostsFile = '/dev/null'
    ServerAliveInterval = 60
    IdentityFile = '~/.ssh/id_rsa'
    Port = 22
    Compression = $true
}
```

#### WinRM Options
```powershell
$connectionConfig.WinRMOptions = @{
    Authentication = 'Default'  # Default, Basic, Negotiate, Kerberos, CredSSP
    AllowUnencrypted = $false
    MaxEnvelopeSizeKB = 500
    MaxTimeoutMS = 60000
    UseSSL = $true
    SkipCACheck = $false
    SkipCNCheck = $false
}
```

## Security Considerations

### Authentication Methods

#### SSH Key-Based Authentication
```powershell
# Store SSH private key as secure credential
$sshKey = Get-Content ~/.ssh/id_rsa -Raw
New-SecureCredential -CredentialName "SSH-Key-Prod" `
    -Username "sshuser" `
    -Password (ConvertTo-SecureString $sshKey -AsPlainText -Force)

# Use key for connection
New-RemoteConnection -ConnectionName "Linux-Prod" `
    -EndpointType "SSH" `
    -HostName "prod.example.com" `
    -CredentialName "SSH-Key-Prod"
```

#### Certificate-Based Authentication
```powershell
# WinRM with certificate
New-RemoteConnection -ConnectionName "Secure-Windows" `
    -EndpointType "WinRM" `
    -HostName "secure.domain.local" `
    -EnableSSL

# Configure certificate in connection
$conn = Get-RemoteConnection -ConnectionName "Secure-Windows"
$conn.WinRMOptions.CertificateThumbprint = "1234567890ABCDEF"
$conn | Export-RemoteConnection
```

### Encryption Options

- **SSH**: Always encrypted by default
- **WinRM**: Use -EnableSSL for HTTPS encryption
- **VMware**: SSL/TLS enabled by default
- **Docker**: Use port 2376 with -EnableSSL for TLS
- **Kubernetes**: TLS encryption standard

### Best Practices

1. **Always use encrypted connections** when possible
2. **Store credentials securely** using SecureCredentials module
3. **Implement least privilege** - use specific service accounts
4. **Audit connection usage** through logging
5. **Rotate credentials regularly**
6. **Use certificate-based authentication** for automation

### Security Example
```powershell
# Secure connection setup
function New-SecureConnection {
    param(
        [string]$Name,
        [string]$Type,
        [string]$Host,
        [string]$ServiceAccount
    )
    
    # Create service account credential
    $securePassword = Read-Host "Enter password for $ServiceAccount" -AsSecureString
    New-SecureCredential -CredentialName "$Name-Cred" `
        -Username $ServiceAccount `
        -Password $securePassword
    
    # Create connection with encryption
    $params = @{
        ConnectionName = $Name
        EndpointType = $Type
        HostName = $Host
        CredentialName = "$Name-Cred"
        ConnectionTimeout = 30
    }
    
    # Enable encryption based on type
    if ($Type -in 'WinRM', 'Docker') {
        $params['EnableSSL'] = $true
    }
    
    New-RemoteConnection @params
    
    # Test connection
    if (Test-RemoteConnection -ConnectionName $Name) {
        Write-Host "Secure connection '$Name' created successfully" -ForegroundColor Green
    } else {
        Write-Warning "Connection created but test failed"
    }
}
```

## Troubleshooting

### Common Issues

#### Connection Timeouts
```powershell
# Increase timeout for slow networks
New-RemoteConnection -ConnectionName "SlowLink" `
    -EndpointType "SSH" `
    -HostName "remote.site.com" `
    -ConnectionTimeout 120

# Test with extended timeout
Test-RemoteConnection -ConnectionName "SlowLink" -Timeout 60
```

#### Authentication Failures
```powershell
# Debug authentication issues
$VerbosePreference = 'Continue'
Connect-RemoteEndpoint -ConnectionName "Problem-Server" -Verbose

# Check stored credentials
Get-SecureCredential -CredentialName "ServerCreds" | 
    Select-Object Username, LastModified
```

#### Protocol-Specific Issues

**WinRM Not Configured**
```powershell
# Enable WinRM on target (run locally)
winrm quickconfig -q
Enable-PSRemoting -Force

# Configure for HTTPS
New-SelfSignedCertificate -DnsName $env:COMPUTERNAME -CertStoreLocation Cert:\LocalMachine\My
winrm create winrm/config/Listener?Address=*+Transport=HTTPS @{Hostname="$env:COMPUTERNAME"; CertificateThumbprint="THUMBPRINT"}
```

**SSH Key Permissions**
```bash
# Fix SSH key permissions on Linux/macOS
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_rsa
chmod 644 ~/.ssh/id_rsa.pub
```

### Diagnostic Commands

```powershell
# Test basic connectivity
Test-NetConnection -ComputerName "server.example.com" -Port 5985

# Check WinRM service
Get-Service WinRM -ComputerName "server.example.com"

# Verify SSH connectivity
ssh -v user@server.example.com

# Docker API test
Invoke-RestMethod -Uri "https://docker.host:2376/version" -Certificate $cert

# List all connections with status
Get-RemoteConnection | ForEach-Object {
    [PSCustomObject]@{
        Name = $_.Name
        Type = $_.EndpointType
        Host = $_.HostName
        Port = $_.Port
        LastUsed = $_.LastUsed
        Status = if (Test-RemoteConnection -ConnectionName $_.Name -Quiet) { "OK" } else { "Failed" }
    }
} | Format-Table -AutoSize
```
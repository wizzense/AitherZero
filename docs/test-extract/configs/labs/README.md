# Lab Configurations

This directory is designated for lab-specific configuration files. Lab configurations allow you to define infrastructure setups, testing environments, and experimental deployments separate from your main configurations.

## Directory Structure

```
labs/
├── (Currently empty - ready for lab configurations)
├── Example structure when populated:
│   ├── hyperv-lab/           # Hyper-V lab configurations
│   ├── azure-lab/            # Azure lab configurations
│   ├── aws-lab/              # AWS lab configurations
│   └── hybrid-lab/           # Hybrid cloud lab configurations
```

## Overview

Lab configurations provide:

1. **Isolated Environments**: Test infrastructure changes without affecting production
2. **Reproducible Labs**: Version-controlled lab definitions
3. **Multi-Provider Support**: Configure labs across different infrastructure providers
4. **Integration Testing**: Test AitherZero modules in controlled environments

## Usage

### Creating Lab Configurations

1. **Basic Lab Configuration**

Create a new lab configuration file:

```json
{
  "labName": "dev-hyperv-lab",
  "description": "Development Hyper-V lab for testing",
  "provider": "hyperv",
  "labConfig": {
    "vmPrefix": "LAB-DEV",
    "networkName": "Lab-Dev-Network",
    "domain": "dev.lab.local",
    "defaultMemory": "4GB",
    "defaultCpu": 2
  },
  "machines": [
    {
      "name": "DC01",
      "role": "DomainController",
      "os": "WindowsServer2022",
      "memory": "8GB",
      "cpu": 4
    },
    {
      "name": "WEB01",
      "role": "WebServer",
      "os": "WindowsServer2022",
      "memory": "4GB",
      "cpu": 2
    }
  ]
}
```

2. **Using Lab Configurations**

```powershell
# Import LabRunner module
Import-Module ./aither-core/modules/LabRunner -Force

# Load lab configuration
$labConfig = Get-Content "configs/labs/dev-hyperv-lab.json" | ConvertFrom-Json

# Deploy lab
Deploy-Lab -Configuration $labConfig

# Start lab
Start-Lab -LabName "dev-hyperv-lab"

# Stop lab
Stop-Lab -LabName "dev-hyperv-lab"

# Remove lab
Remove-Lab -LabName "dev-hyperv-lab" -Confirm
```

## Configuration Options

### Lab Definition Schema

```json
{
  "labName": "string",              # Unique lab identifier
  "description": "string",          # Lab description
  "provider": "string",             # Infrastructure provider
  "version": "string",              # Configuration version
  "author": "string",               # Lab author
  "created": "datetime",            # Creation timestamp
  "lastModified": "datetime",       # Last modification
  "labConfig": {                    # Provider-specific configuration
    "vmPrefix": "string",
    "networkConfig": {},
    "storageConfig": {},
    "securityConfig": {}
  },
  "machines": [],                   # Machine definitions
  "networks": [],                   # Network definitions
  "storage": [],                    # Storage definitions
  "scripts": [],                    # Automation scripts
  "dependencies": []                # External dependencies
}
```

### Provider-Specific Configurations

#### Hyper-V Lab Configuration

```json
{
  "provider": "hyperv",
  "labConfig": {
    "host": "hyperv-host.domain.com",
    "vmPath": "C:\\VMs",
    "vhdPath": "C:\\VHDs",
    "switchType": "Internal",
    "enableNestedVirtualization": true,
    "checkpointType": "Production"
  }
}
```

#### Azure Lab Configuration

```json
{
  "provider": "azure",
  "labConfig": {
    "subscriptionId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
    "resourceGroup": "lab-rg",
    "location": "eastus",
    "virtualNetwork": {
      "name": "lab-vnet",
      "addressSpace": "10.0.0.0/16"
    },
    "tags": {
      "Environment": "Lab",
      "ManagedBy": "AitherZero"
    }
  }
}
```

#### AWS Lab Configuration

```json
{
  "provider": "aws",
  "labConfig": {
    "region": "us-east-1",
    "vpcCidr": "10.0.0.0/16",
    "availabilityZones": ["us-east-1a", "us-east-1b"],
    "instanceTypes": {
      "default": "t3.medium",
      "controller": "t3.large"
    },
    "keyPair": "lab-keypair"
  }
}
```

## Best Practices

### Lab Naming Conventions

Use descriptive, hierarchical names:
```
<purpose>-<provider>-<environment>-lab

Examples:
- testing-hyperv-dev-lab
- production-azure-staging-lab
- demo-aws-sales-lab
```

### Version Control

1. **Track Changes**: Always version your lab configurations
   ```json
   {
     "version": "1.2.0",
     "changelog": [
       {
         "version": "1.2.0",
         "date": "2025-07-06",
         "changes": ["Added web server tier", "Updated network config"]
       }
     ]
   }
   ```

2. **Use Git Tags**: Tag stable lab configurations
   ```bash
   git tag -a "lab-v1.2.0" -m "Stable lab configuration with web tier"
   ```

### Resource Management

1. **Resource Limits**: Define maximum resources
   ```json
   {
     "resourceLimits": {
       "maxVMs": 10,
       "maxMemoryGB": 64,
       "maxStorageGB": 500,
       "maxCPUs": 32
     }
   }
   ```

2. **Cleanup Policies**: Configure automatic cleanup
   ```json
   {
     "cleanup": {
       "autoShutdown": true,
       "shutdownTime": "18:00",
       "maxRuntime": "8h",
       "deleteAfterDays": 7
     }
   }
   ```

## Lab Templates

### Basic Testing Lab

```json
{
  "labName": "basic-test-lab",
  "description": "Minimal lab for basic testing",
  "provider": "hyperv",
  "machines": [
    {
      "name": "TEST01",
      "os": "Windows11",
      "memory": "4GB",
      "cpu": 2,
      "disks": [
        {
          "size": "60GB",
          "type": "Dynamic"
        }
      ]
    }
  ]
}
```

### Domain Lab

```json
{
  "labName": "domain-lab",
  "description": "Active Directory domain lab",
  "provider": "hyperv",
  "labConfig": {
    "domain": {
      "name": "lab.local",
      "netbiosName": "LAB",
      "forestLevel": "2016",
      "domainLevel": "2016"
    }
  },
  "machines": [
    {
      "name": "DC01",
      "role": "DomainController",
      "os": "WindowsServer2022",
      "memory": "8GB",
      "features": ["AD-Domain-Services", "DNS", "DHCP"]
    },
    {
      "name": "MEMBER01",
      "role": "MemberServer",
      "os": "WindowsServer2022",
      "memory": "4GB",
      "joinDomain": true
    }
  ]
}
```

### Kubernetes Lab

```json
{
  "labName": "k8s-lab",
  "description": "Kubernetes cluster lab",
  "provider": "azure",
  "machines": [
    {
      "name": "k8s-master",
      "os": "Ubuntu2204",
      "size": "Standard_D2s_v3",
      "role": "k8s-master",
      "scripts": ["install-k8s-master.sh"]
    },
    {
      "name": "k8s-worker",
      "os": "Ubuntu2204",
      "size": "Standard_D2s_v3",
      "count": 3,
      "role": "k8s-worker",
      "scripts": ["install-k8s-worker.sh"]
    }
  ]
}
```

## Integration with AitherZero Modules

### LabRunner Integration

The LabRunner module is the primary consumer of lab configurations:

```powershell
# Deploy complete lab from configuration
Deploy-LabFromConfig -ConfigPath "configs/labs/my-lab.json"

# Validate lab configuration
Test-LabConfiguration -ConfigPath "configs/labs/my-lab.json"

# Export lab state
Export-LabState -LabName "my-lab" -Path "configs/labs/my-lab-state.json"
```

### OpenTofuProvider Integration

Generate OpenTofu/Terraform configurations from lab definitions:

```powershell
# Convert lab config to OpenTofu
Convert-LabToOpenTofu -LabConfig "configs/labs/my-lab.json" -OutputPath "opentofu/labs/my-lab"

# Deploy using OpenTofu
Deploy-LabWithOpenTofu -LabName "my-lab"
```

### ISOManager Integration

Manage ISOs for lab deployments:

```json
{
  "isoManagement": {
    "isoRepository": "\\\\fileserver\\ISOs",
    "requiredISOs": [
      {
        "name": "WindowsServer2022",
        "path": "Windows/Server2022.iso"
      }
    ],
    "autoDownload": true
  }
}
```

## Security Considerations

### Credential Management

Never store credentials in lab configurations:

```json
{
  "credentials": {
    "method": "SecureCredentials",  # Use SecureCredentials module
    "credentialName": "LabAdmin",   # Reference to stored credential
    "fallback": "prompt"            # Prompt if not found
  }
}
```

### Network Isolation

Define network security policies:

```json
{
  "networkSecurity": {
    "isolation": "full",             # full, partial, none
    "allowedPorts": [3389, 5985],
    "blockedPorts": [445, 139],
    "firewallRules": [
      {
        "name": "AllowRDP",
        "direction": "Inbound",
        "port": 3389,
        "protocol": "TCP",
        "source": "10.0.0.0/8"
      }
    ]
  }
}
```

## Examples

### Example: Multi-Tier Application Lab

```json
{
  "labName": "three-tier-app-lab",
  "description": "Three-tier application testing lab",
  "provider": "hyperv",
  "networks": [
    {
      "name": "Frontend-Network",
      "subnet": "192.168.1.0/24",
      "vlan": 10
    },
    {
      "name": "Backend-Network",
      "subnet": "192.168.2.0/24",
      "vlan": 20
    },
    {
      "name": "Database-Network",
      "subnet": "192.168.3.0/24",
      "vlan": 30
    }
  ],
  "machines": [
    {
      "name": "WEB01",
      "tier": "frontend",
      "network": "Frontend-Network",
      "os": "WindowsServer2022",
      "roles": ["IIS", "ASP.NET"]
    },
    {
      "name": "APP01",
      "tier": "application",
      "network": "Backend-Network",
      "os": "WindowsServer2022",
      "software": ["dotnet-runtime-6.0"]
    },
    {
      "name": "DB01",
      "tier": "database",
      "network": "Database-Network",
      "os": "WindowsServer2022",
      "roles": ["SQL-Server"]
    }
  ]
}
```

### Example: Disaster Recovery Lab

```json
{
  "labName": "dr-testing-lab",
  "description": "Disaster recovery testing environment",
  "provider": "azure",
  "sites": [
    {
      "name": "primary",
      "region": "eastus",
      "resourceGroup": "lab-primary-rg"
    },
    {
      "name": "secondary",
      "region": "westus",
      "resourceGroup": "lab-secondary-rg"
    }
  ],
  "replication": {
    "enabled": true,
    "rpo": "15m",
    "testSchedule": "weekly"
  }
}
```

## Troubleshooting

### Common Issues

1. **Lab Deployment Failures**
   ```powershell
   # Check lab prerequisites
   Test-LabPrerequisites -ConfigPath "configs/labs/my-lab.json"
   
   # Validate provider connectivity
   Test-ProviderConnection -Provider "hyperv" -Host "hyperv-host"
   ```

2. **Resource Conflicts**
   ```powershell
   # Check existing resources
   Get-LabResources -LabName "my-lab"
   
   # Clean up orphaned resources
   Remove-OrphanedLabResources -LabName "my-lab"
   ```

3. **Configuration Errors**
   ```powershell
   # Validate JSON syntax
   Test-Json -Path "configs/labs/my-lab.json"
   
   # Validate against schema
   Test-LabConfigSchema -ConfigPath "configs/labs/my-lab.json"
   ```

## See Also

- [Main Configuration Documentation](../README.md)
- [Configuration Carousel Documentation](../carousel/README.md)
- [LabRunner Module](../../aither-core/modules/LabRunner/README.md)
- [OpenTofuProvider Module](../../aither-core/modules/OpenTofuProvider/README.md)
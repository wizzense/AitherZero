# RemoteConnection Module

**Version:** 1.0.0  
**Description:** Generalized remote connection management module for enterprise-wide use across AitherZero infrastructure automation

## Overview

Generalized remote connection management module for enterprise-wide use across AitherZero infrastructure automation

## Functions

### Connect-RemoteEndpoint

**Synopsis:** 

**Description:**


#### Syntax
```powershell
param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ConnectionName,

        [Parameter()]
        [ValidateRange(1, 300)]
        [int]$Timeout = 30
    )
```

#### Parameters

- **ConnectionName** [String] *(Required)*

- **Timeout** [Int32] *(Default: 30)*


### Disconnect-RemoteEndpoint

**Synopsis:** 

**Description:**


#### Syntax
```powershell
param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ConnectionName
    )
```

#### Parameters

- **ConnectionName** [String] *(Required)*


### Get-RemoteConnection

**Synopsis:** 

**Description:**


#### Syntax
```powershell
param(
        [Parameter()]
        [string]$ConnectionName,

        [Parameter()]
        [ValidateSet('SSH', 'WinRM', 'VMware', 'Hyper-V', 'Docker', 'Kubernetes')]
        [string]$EndpointType,

        [Parameter()]
        [switch]$IncludeCredentials
    )
```

#### Parameters

- **ConnectionName** [String]

- **EndpointType** [String]
  Valid values: SSH, WinRM, VMware, Hyper-V, Docker, Kubernetes

- **IncludeCredentials** [SwitchParameter]


### Invoke-RemoteCommand

**Synopsis:** 

**Description:**


#### Syntax
```powershell
param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ConnectionName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Command,

        [Parameter(Mandatory = $false)]
        [hashtable]$Parameters = @{},

        [Parameter(Mandatory = $false)]
        [int]$TimeoutSeconds = 300,

        [Parameter(Mandatory = $false)]
        [switch]$AsJob
    )
```

#### Parameters

- **ConnectionName** [String] *(Required)*

- **Command** [String] *(Required)*

- **Parameters** [Hashtable] *(Required)* *(Default: @{})*

- **TimeoutSeconds** [Int32] *(Required)* *(Default: 300)*

- **AsJob** [SwitchParameter] *(Required)*


### New-RemoteConnection

**Synopsis:** 

**Description:**


#### Syntax
```powershell
param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ConnectionName,

        [Parameter(Mandatory)]
        [ValidateSet('SSH', 'WinRM', 'VMware', 'Hyper-V', 'Docker', 'Kubernetes')]
        [string]$EndpointType,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$HostName,

        [Parameter()]
        [ValidateRange(1, 65535)]
        [int]$Port,

        [Parameter()]
        [string]$CredentialName,

        [Parameter()]
        [ValidateRange(5, 300)]
        [int]$ConnectionTimeout = 30,

        [Parameter()]
        [switch]$EnableSSL,

        [Parameter()]
        [switch]$Force
    )
```

#### Parameters

- **ConnectionName** [String] *(Required)*

- **EndpointType** [String] *(Required)*
  Valid values: SSH, WinRM, VMware, Hyper-V, Docker, Kubernetes

- **HostName** [String] *(Required)*

- **Port** [Int32]

- **CredentialName** [String]

- **ConnectionTimeout** [Int32] *(Default: 30)*

- **EnableSSL** [SwitchParameter]

- **Force** [SwitchParameter]



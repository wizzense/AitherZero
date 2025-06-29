# SecureCredentials Module

**Version:** 1.0.0  
**Description:** Generalized secure credential management module for enterprise-wide use across AitherZero infrastructure automation

## Overview

Generalized secure credential management module for enterprise-wide use across AitherZero infrastructure automation

## Functions

### Export-SecureCredential

**Synopsis:** 

**Description:**


#### Syntax
```powershell
param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$CredentialName,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ExportPath,

        [Parameter()]
        [switch]$IncludeSecrets
    )
```

#### Parameters

- **CredentialName** [String] *(Required)*

- **ExportPath** [String] *(Required)*

- **IncludeSecrets** [SwitchParameter]


### Get-SecureCredential

**Synopsis:** 

**Description:**


#### Syntax
```powershell
param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$CredentialName
    )
```

#### Parameters

- **CredentialName** [String] *(Required)*


### Import-SecureCredential

**Synopsis:** 

**Description:**


#### Syntax
```powershell
param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ImportPath,

        [Parameter()]
        [switch]$Force,

        [Parameter()]
        [switch]$SkipSecrets
    )
```

#### Parameters

- **ImportPath** [String] *(Required)*

- **Force** [SwitchParameter]

- **SkipSecrets** [SwitchParameter]


### New-SecureCredential

**Synopsis:** 

**Description:**


#### Syntax
```powershell
param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$CredentialName,

        [Parameter(Mandatory = $true)]
        [ValidateSet('UserPassword', 'ServiceAccount', 'APIKey', 'Certificate')]
        [string]$CredentialType,

        [Parameter(Mandatory = $false)]
        [string]$Username,

        [Parameter(Mandatory = $false)]
        [SecureString]$Password,

        [Parameter(Mandatory = $false)]
        [string]$APIKey,

        [Parameter(Mandatory = $false)]
        [string]$CertificatePath,

        [Parameter(Mandatory = $false)]
        [string]$Description,

        [Parameter(Mandatory = $false)]
        [hashtable]$Metadata = @{}
    )
```

#### Parameters

- **CredentialName** [String] *(Required)*

- **CredentialType** [String] *(Required)*
  Valid values: UserPassword, ServiceAccount, APIKey, Certificate

- **Username** [String] *(Required)*

- **Password** [SecureString] *(Required)*

- **APIKey** [String] *(Required)*

- **CertificatePath** [String] *(Required)*

- **Description** [String] *(Required)*

- **Metadata** [Hashtable] *(Required)* *(Default: @{})*



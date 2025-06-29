# OpenTofuProvider Module

**Version:** 1.0.0  
**Description:** PowerShell module for secure OpenTofu infrastructure automation with Taliesins Hyper-V provider integration

## Overview

PowerShell module for secure OpenTofu infrastructure automation with Taliesins Hyper-V provider integration

## Functions

### Export-LabTemplate

**Synopsis:** 

**Description:**


#### Syntax
```powershell
param(
        [Parameter(Mandatory)]
        [ValidateScript({ Test-Path $_ })]
        [string]$SourcePath,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$TemplateName,

        [Parameter()]
        [string]$OutputPath = "./templates",

        [Parameter()]
        [switch]$IncludeDocumentation
    )
```

#### Parameters

- **SourcePath** [String] *(Required)*

- **TemplateName** [String] *(Required)*

- **OutputPath** [String] *(Default: "./templates")*

- **IncludeDocumentation** [SwitchParameter]


### Get-TaliesinsProviderConfig

**Synopsis:** 

**Description:**


#### Syntax
```powershell
param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$HypervHost,

        [Parameter()]
        [System.Management.Automation.PSCredential]$Credentials,

        [Parameter()]
        [string]$CertificatePath,

        [Parameter()]
        [ValidateRange(1, 65535)]
        [int]$Port = 5986,

        [Parameter()]
        [bool]$UseNTLM = $true,

        [Parameter()]
        [ValidateSet('HCL', 'JSON', 'Object')]
        [string]$OutputFormat = 'HCL'
    )
```

#### Parameters

- **HypervHost** [String] *(Required)*

- **Credentials** [PSCredential]

- **CertificatePath** [String]

- **Port** [Int32] *(Default: 5986)*

- **UseNTLM** [Boolean] *(Default: $true)*

- **OutputFormat** [String] *(Default: 'HCL')*
  Valid values: HCL, JSON, Object


### Import-LabConfiguration

**Synopsis:** 

**Description:**


#### Syntax
```powershell
param(
        [Parameter(Mandatory)]
        [ValidateScript({ Test-Path $_ })]
        [string]$ConfigPath,

        [Parameter()]
        [ValidateSet('YAML', 'JSON', 'Auto')]
        [string]$ConfigFormat = 'Auto',

        [Parameter()]
        [switch]$ValidateConfiguration,

        [Parameter()]
        [string]$MergeWith
    )
```

#### Parameters

- **ConfigPath** [String] *(Required)*

- **ConfigFormat** [String] *(Default: 'Auto')*
  Valid values: YAML, JSON, Auto

- **ValidateConfiguration** [SwitchParameter]

- **MergeWith** [String]


### Initialize-OpenTofuProvider

**Synopsis:** 

**Description:**


#### Syntax
```powershell
param(
        [Parameter(Mandatory)]
        [ValidateScript({ Test-Path $_ })]
        [string]$ConfigPath,

        [Parameter()]
        [string]$ProviderVersion = "1.2.1",

        [Parameter()]
        [string]$CertificatePath,

        [Parameter()]
        [switch]$Force
    )
```

#### Parameters

- **ConfigPath** [String] *(Required)*

- **ProviderVersion** [String] *(Default: "1.2.1")*

- **CertificatePath** [String]

- **Force** [SwitchParameter]


### Install-OpenTofuSecure

**Synopsis:** 

**Description:**


#### Syntax
```powershell
param(
        [Parameter()]
        [string]$Version = "latest",

        [Parameter()]
        [string]$InstallPath,

        [Parameter()]
        [switch]$SkipVerification,

        [Parameter()]
        [switch]$Force
    )
```

#### Parameters

- **Version** [String] *(Default: "latest")*

- **InstallPath** [String]

- **SkipVerification** [SwitchParameter]

- **Force** [SwitchParameter]


### New-LabInfrastructure

**Synopsis:** 

**Description:**


#### Syntax
```powershell
param(
        [Parameter(Mandatory)]
        [ValidateScript({ Test-Path $_ })]
        [string]$ConfigPath,

        [Parameter()]
        [switch]$PlanOnly,

        [Parameter()]
        [switch]$AutoApprove,

        [Parameter()]
        [switch]$Force
    )
```

#### Parameters

- **ConfigPath** [String] *(Required)*

- **PlanOnly** [SwitchParameter]

- **AutoApprove** [SwitchParameter]

- **Force** [SwitchParameter]


### Set-SecureCredentials

**Synopsis:** 

**Description:**


#### Syntax
```powershell
param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Target,

        [Parameter()]
        [System.Management.Automation.PSCredential]$Credentials,

        [Parameter()]
        [string]$CertificatePath,

        [Parameter()]
        [ValidateSet('UserPassword', 'Certificate', 'Both')]
        [string]$CredentialType = 'UserPassword',

        [Parameter()]
        [switch]$Force
    )
```

#### Parameters

- **Target** [String] *(Required)*

- **Credentials** [PSCredential]

- **CertificatePath** [String]

- **CredentialType** [String] *(Default: 'UserPassword')*
  Valid values: UserPassword, Certificate, Both

- **Force** [SwitchParameter]


### Test-InfrastructureCompliance

**Synopsis:** 

**Description:**


#### Syntax
```powershell
param(
        [Parameter(Mandatory = $true)]
        [ValidateScript({ Test-Path $_ })]
        [string]$ConfigPath,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("CIS", "NIST", "SOC2", "Custom", "Security", "Operational", "All")]
        [string]$ComplianceStandard = "CIS",
        
        [Parameter(Mandatory = $false)]
        [switch]$IncludeResourceValidation,
        
        [Parameter(Mandatory = $false)]
        [switch]$GenerateReport
    )
```

#### Parameters

- **ConfigPath** [String] *(Required)*

- **ComplianceStandard** [String] *(Required)* *(Default: "CIS")*
  Valid values: CIS, NIST, SOC2, Custom, Security, Operational, All

- **IncludeResourceValidation** [SwitchParameter] *(Required)*

- **GenerateReport** [SwitchParameter] *(Required)*


### Test-ResourceCompliance

**Synopsis:** 

**Description:**


#### Syntax
```powershell
param([string]$Path, [string]$Standard)
```

#### Parameters

- **Path** [String]

- **Standard** [String]


### Test-NetworkCompliance

**Synopsis:** 

**Description:**


#### Syntax
```powershell
param([string]$Path, [string]$Standard)
```

#### Parameters

- **Path** [String]

- **Standard** [String]


### Test-AccessControlCompliance

**Synopsis:** 

**Description:**


#### Syntax
```powershell
param([string]$Path, [string]$Standard)
```

#### Parameters

- **Path** [String]

- **Standard** [String]


### Test-DataProtectionCompliance

**Synopsis:** 

**Description:**


#### Syntax
```powershell
param([string]$Path, [string]$Standard)
```

#### Parameters

- **Path** [String]

- **Standard** [String]


### Test-MonitoringCompliance

**Synopsis:** 

**Description:**


#### Syntax
```powershell
param([string]$Path, [string]$Standard)
```

#### Parameters

- **Path** [String]

- **Standard** [String]


### Test-OpenTofuSecurity

**Synopsis:** 

**Description:**


#### Syntax
```powershell
param(
        [Parameter(Mandatory = $true)]
        [ValidateScript({ Test-Path $_ })]
        [string]$ConfigPath,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("CIS", "NIST", "Custom", "All")]
        [string]$SecurityStandard = "CIS",
        
        [Parameter(Mandatory = $false)]
        [switch]$IncludeProviderValidation,
        
        [Parameter(Mandatory = $false)]
        [switch]$CheckStateFileSecurity
    )
```

#### Parameters

- **ConfigPath** [String] *(Required)*

- **SecurityStandard** [String] *(Required)* *(Default: "CIS")*
  Valid values: CIS, NIST, Custom, All

- **IncludeProviderValidation** [SwitchParameter] *(Required)*

- **CheckStateFileSecurity** [SwitchParameter] *(Required)*


### Test-ConfigurationSecurity

**Synopsis:** 

**Description:**


#### Syntax
```powershell
param([string]$Path)
```

#### Parameters

- **Path** [String]


### Test-ProviderSecurity

**Synopsis:** 

**Description:**


#### Syntax
```powershell
param([string]$Path, [string]$Standard)
```

#### Parameters

- **Path** [String]

- **Standard** [String]


### Test-StateFileSecurity

**Synopsis:** 

**Description:**


#### Syntax
```powershell
param([string]$Path)
```

#### Parameters

- **Path** [String]


### Test-SecretsValidation

**Synopsis:** 

**Description:**


#### Syntax
```powershell
param([string]$Path)
```

#### Parameters

- **Path** [String]



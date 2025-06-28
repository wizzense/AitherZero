# ISOCustomizer Module

**Version:** 1.0.0  
**Description:** Enterprise-grade ISO customization and autounattend file generation module for automated lab deployments

## Overview

Enterprise-grade ISO customization and autounattend file generation module for automated lab deployments

## Functions

### New-AutounattendFile

**Synopsis:** 

**Description:**


#### Syntax
```powershell
param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Configuration,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$OutputPath,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Server2025', 'Server2022', 'Server2019', 'Windows11', 'Windows10', 'Generic')]
        [string]$OSType = 'Server2025',

        [Parameter(Mandatory = $false)]
        [ValidateSet('Standard', 'Datacenter', 'Core', 'Desktop')]
        [string]$Edition = 'Datacenter',

        [Parameter(Mandatory = $false)]
        [string]$TemplatePath,

        [Parameter(Mandatory = $false)]
        [switch]$HeadlessMode,

        [Parameter(Mandatory = $false)]
        [switch]$Force
    )
```

#### Parameters

- **Configuration** [Hashtable] *(Required)*

- **OutputPath** [String] *(Required)*

- **OSType** [String] *(Required)* *(Default: 'Server2025')*
  Valid values: Server2025, Server2022, Server2019, Windows11, Windows10, Generic

- **Edition** [String] *(Required)* *(Default: 'Datacenter')*
  Valid values: Standard, Datacenter, Core, Desktop

- **TemplatePath** [String] *(Required)*

- **HeadlessMode** [SwitchParameter] *(Required)*

- **Force** [SwitchParameter] *(Required)*


### Escape-XmlContent

**Synopsis:** 

**Description:**


#### Syntax
```powershell
param([string]$Text)
```

#### Parameters

- **Text** [String]


### New-CustomISO

**Synopsis:** 

**Description:**


#### Syntax
```powershell
param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$SourceISOPath,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$OutputISOPath,

        [Parameter(Mandatory = $false)]
        [string]$ExtractPath,

        [Parameter(Mandatory = $false)]
        [string]$MountPath,

        [Parameter(Mandatory = $false)]
        [string]$BootstrapScript,

        [Parameter(Mandatory = $false)]
        [string]$AutounattendFile,

        [Parameter(Mandatory = $false)]
        [hashtable]$AutounattendConfig,

        [Parameter(Mandatory = $false)]
        [int]$WIMIndex = 3,

        [Parameter(Mandatory = $false)]
        [string[]]$AdditionalFiles = @(),

        [Parameter(Mandatory = $false)]
        [string[]]$DriversPath = @(),

        [Parameter(Mandatory = $false)]
        [hashtable]$RegistryChanges = @{},

        [Parameter(Mandatory = $false)]
        [string]$OscdimgPath,

        [Parameter(Mandatory = $false)]
        [switch]$Force,

        [Parameter(Mandatory = $false)]
        [switch]$KeepTempFiles,

        [Parameter(Mandatory = $false)]
        [switch]$ValidateOnly
    )
```

#### Parameters

- **SourceISOPath** [String] *(Required)*

- **OutputISOPath** [String] *(Required)*

- **ExtractPath** [String] *(Required)*

- **MountPath** [String] *(Required)*

- **BootstrapScript** [String] *(Required)*

- **AutounattendFile** [String] *(Required)*

- **AutounattendConfig** [Hashtable] *(Required)*

- **WIMIndex** [Int32] *(Required)* *(Default: 3)*

- **AdditionalFiles** [String[]] *(Required)* *(Default: @())*

- **DriversPath** [String[]] *(Required)* *(Default: @())*

- **RegistryChanges** [Hashtable] *(Required)* *(Default: @{})*

- **OscdimgPath** [String] *(Required)*

- **Force** [SwitchParameter] *(Required)*

- **KeepTempFiles** [SwitchParameter] *(Required)*

- **ValidateOnly** [SwitchParameter] *(Required)*



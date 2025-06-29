# ISOManager Module

**Version:** 1.0.0  
**Description:** Enterprise-grade ISO download, management, and organization module for automated lab infrastructure deployment

## Overview

Enterprise-grade ISO download, management, and organization module for automated lab infrastructure deployment

## Functions

### Export-ISOInventory

**Synopsis:** 

**Description:**


#### Syntax
```powershell
param(
        [Parameter(Mandatory = $false)]
        [string]$RepositoryPath,

        [Parameter(Mandatory = $true)]
        [string]$ExportPath,

        [Parameter(Mandatory = $false)]
        [ValidateSet('JSON', 'CSV', 'XML')]
        [string]$Format = 'JSON',

        [Parameter(Mandatory = $false)]
        [switch]$IncludeMetadata,

        [Parameter(Mandatory = $false)]
        [switch]$IncludeIntegrity
    )
```

#### Parameters

- **RepositoryPath** [String] *(Required)*

- **ExportPath** [String] *(Required)*

- **Format** [String] *(Required)* *(Default: 'JSON')*
  Valid values: JSON, CSV, XML

- **IncludeMetadata** [SwitchParameter] *(Required)*

- **IncludeIntegrity** [SwitchParameter] *(Required)*


### Get-ISODownload

**Synopsis:** 

**Description:**


#### Syntax
```powershell
param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ISOName,

        [Parameter(Mandatory = $false)]
        [string]$Version = "latest",

        [Parameter(Mandatory = $false)]
        [string]$Architecture = "x64",

        [Parameter(Mandatory = $false)]
        [string]$Language = "en-US",

        [Parameter(Mandatory = $false)]
        [ValidateSet('Windows', 'Linux', 'Custom')]
        [string]$ISOType = 'Windows',

        [Parameter(Mandatory = $false)]
        [string]$CustomURL,

        [Parameter(Mandatory = $false)]
        [string]$DownloadPath,

        [Parameter(Mandatory = $false)]
        [switch]$VerifyIntegrity,

        [Parameter(Mandatory = $false)]
        [switch]$Force
    )
```

#### Parameters

- **ISOName** [String] *(Required)*

- **Version** [String] *(Required)* *(Default: "latest")*

- **Architecture** [String] *(Required)* *(Default: "x64")*

- **Language** [String] *(Required)* *(Default: "en-US")*

- **ISOType** [String] *(Required)* *(Default: 'Windows')*
  Valid values: Windows, Linux, Custom

- **CustomURL** [String] *(Required)*

- **DownloadPath** [String] *(Required)*

- **VerifyIntegrity** [SwitchParameter] *(Required)*

- **Force** [SwitchParameter] *(Required)*


### Get-ISOInventory

**Synopsis:** 

**Description:**


#### Syntax
```powershell
param(
        [Parameter(Mandatory = $false)]
        [string]$RepositoryPath,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Windows', 'Linux', 'All')]
        [string]$ISOType = 'All',

        [Parameter(Mandatory = $false)]
        [switch]$IncludeMetadata,

        [Parameter(Mandatory = $false)]
        [switch]$VerifyIntegrity
    )
```

#### Parameters

- **RepositoryPath** [String] *(Required)*

- **ISOType** [String] *(Required)* *(Default: 'All')*
  Valid values: Windows, Linux, All

- **IncludeMetadata** [SwitchParameter] *(Required)*

- **VerifyIntegrity** [SwitchParameter] *(Required)*


### Get-ISOMetadata

**Synopsis:** 

**Description:**


#### Syntax
```powershell
param(
        [Parameter(Mandatory = $true)]
        [ValidateScript({Test-Path $_ -PathType Leaf})]
        [string]$FilePath,

        [Parameter(Mandatory = $false)]
        [switch]$IncludeVolumeInfo,

        [Parameter(Mandatory = $false)]
        [switch]$IncludeFileList
    )
```

#### Parameters

- **FilePath** [String] *(Required)*

- **IncludeVolumeInfo** [SwitchParameter] *(Required)*

- **IncludeFileList** [SwitchParameter] *(Required)*


### Import-ISOInventory

**Synopsis:** 

**Description:**


#### Syntax
```powershell
param(
        [Parameter(Mandatory = $true)]
        [ValidateScript({Test-Path $_ -PathType Leaf})]
        [string]$ImportPath,

        [Parameter(Mandatory = $false)]
        [string]$TargetRepositoryPath,

        [Parameter(Mandatory = $false)]
        [switch]$ValidateFiles,

        [Parameter(Mandatory = $false)]
        [switch]$CreateMissingDirectories
    )
```

#### Parameters

- **ImportPath** [String] *(Required)*

- **TargetRepositoryPath** [String] *(Required)*

- **ValidateFiles** [SwitchParameter] *(Required)*

- **CreateMissingDirectories** [SwitchParameter] *(Required)*


### New-ISORepository

**Synopsis:** 

**Description:**


#### Syntax
```powershell
param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RepositoryPath,

        [Parameter(Mandatory = $false)]
        [string]$Name = "AitherZero-ISORepository",

        [Parameter(Mandatory = $false)]
        [string]$Description = "AitherZero Infrastructure Automation ISO Repository",

        [Parameter(Mandatory = $false)]
        [hashtable]$Configuration = @{},

        [Parameter(Mandatory = $false)]
        [switch]$Force
    )
```

#### Parameters

- **RepositoryPath** [String] *(Required)*

- **Name** [String] *(Required)* *(Default: "AitherZero-ISORepository")*

- **Description** [String] *(Required)* *(Default: "AitherZero Infrastructure Automation ISO Repository")*

- **Configuration** [Hashtable] *(Required)* *(Default: @{})*

- **Force** [SwitchParameter] *(Required)*


### Remove-ISOFile

**Synopsis:** 

**Description:**


#### Syntax
```powershell
param(
        [Parameter(Mandatory = $true)]
        [ValidateScript({ Test-Path $_ })]
        [string]$Path,
        
        [Parameter(Mandatory = $false)]
        [switch]$Force,
        
        [Parameter(Mandatory = $false)]
        [switch]$CreateBackup,
        
        [Parameter(Mandatory = $false)]
        [switch]$UpdateInventory
    )
```

#### Parameters

- **Path** [String] *(Required)*

- **Force** [SwitchParameter] *(Required)*

- **CreateBackup** [SwitchParameter] *(Required)*

- **UpdateInventory** [SwitchParameter] *(Required)*


### Sync-ISORepository

**Synopsis:** 

**Description:**


#### Syntax
```powershell
param(
        [Parameter(Mandatory = $true)]
        [string]$RepositoryPath,

        [Parameter(Mandatory = $false)]
        [string]$ConfigPath,

        [Parameter(Mandatory = $false)]
        [switch]$UpdateMetadata,

        [Parameter(Mandatory = $false)]
        [switch]$ValidateIntegrity,

        [Parameter(Mandatory = $false)]
        [switch]$CleanupOrphaned
    )
```

#### Parameters

- **RepositoryPath** [String] *(Required)*

- **ConfigPath** [String] *(Required)*

- **UpdateMetadata** [SwitchParameter] *(Required)*

- **ValidateIntegrity** [SwitchParameter] *(Required)*

- **CleanupOrphaned** [SwitchParameter] *(Required)*


### Test-ISOIntegrity

**Synopsis:** 

**Description:**


#### Syntax
```powershell
param(
        [Parameter(Mandatory = $true)]
        [ValidateScript({ Test-Path $_ })]
        [string]$Path,
        
        [Parameter(Mandatory = $false)]
        [string]$ExpectedHash,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet('MD5', 'SHA1', 'SHA256', 'SHA512')]
        [string]$Algorithm = 'SHA256'
    )
```

#### Parameters

- **Path** [String] *(Required)*

- **ExpectedHash** [String] *(Required)*

- **Algorithm** [String] *(Required)* *(Default: 'SHA256')*
  Valid values: MD5, SHA1, SHA256, SHA512



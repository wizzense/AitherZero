# BackupManager Module

**Version:** 1.0.0  
**Description:** Comprehensive backup management and maintenance capabilities for the AitherZero project

## Overview

Comprehensive backup management and maintenance capabilities for the AitherZero project

## Functions

### Get-BackupStatistics

**Synopsis:** 

**Description:**


#### Syntax
```powershell
param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectRoot,

        [switch]$IncludeDetails
    )
```

#### Parameters

- **ProjectRoot** [String] *(Required)*

- **IncludeDetails** [SwitchParameter]


### Invoke-BackupMaintenance

**Synopsis:** 

**Description:**


#### Syntax
```powershell
param(
        [Parameter(Mandatory=$false)]
        [ValidateSet("Quick", "Full", "Cleanup", "Statistics", "All")]
        [string]$Mode = "Quick",

        [Parameter(Mandatory=$false)]
        [switch]$AutoFix,

        [Parameter(Mandatory=$false)]
        [ValidateSet("Standard", "CI", "JSON")]
        [string]$OutputFormat = "Standard"
    )
```

#### Parameters

- **Mode** [String] *(Required)* *(Default: "Quick")*
  Valid values: Quick, Full, Cleanup, Statistics, All

- **AutoFix** [SwitchParameter] *(Required)*

- **OutputFormat** [String] *(Required)* *(Default: "Standard")*
  Valid values: Standard, CI, JSON


### Invoke-QuickBackupMaintenance

**Synopsis:** 

**Description:**


#### Syntax
```powershell
param($Results, [switch]$AutoFix)
```

#### Parameters

- **Results** [Object]

- **AutoFix** [SwitchParameter]


### Invoke-FullBackupMaintenance

**Synopsis:** 

**Description:**


#### Syntax
```powershell
param($Results, [switch]$AutoFix)
```

#### Parameters

- **Results** [Object]

- **AutoFix** [SwitchParameter]


### Invoke-CleanupBackupMaintenance

**Synopsis:** 

**Description:**


#### Syntax
```powershell
param($Results, [switch]$AutoFix)
```

#### Parameters

- **Results** [Object]

- **AutoFix** [SwitchParameter]


### Invoke-StatisticsBackupMaintenance

**Synopsis:** 

**Description:**


#### Syntax
```powershell
param($Results)
```

#### Parameters

- **Results** [Object]


### Invoke-AllBackupMaintenance

**Synopsis:** 

**Description:**


#### Syntax
```powershell
param($Results, [switch]$AutoFix)
```

#### Parameters

- **Results** [Object]

- **AutoFix** [SwitchParameter]


### Write-BackupMaintenanceResults

**Synopsis:** 

**Description:**


#### Syntax
```powershell
param($Results, $OutputFormat)
```

#### Parameters

- **Results** [Object]

- **OutputFormat** [Object]


### Invoke-PermanentCleanup

**Synopsis:** 

**Description:**


#### Syntax
```powershell
param(
        [Parameter(Mandatory = $true, ParameterSetName = 'ProjectCleanup')]
        [string]$ProjectRoot,
        
        [Parameter(ParameterSetName = 'ProjectCleanup')]
        [string[]]$ProblematicPatterns = @(),
        
        [Parameter(ParameterSetName = 'ProjectCleanup')]
        [switch]$CreatePreventionRules,
        
        [Parameter(Mandatory = $true, ParameterSetName = 'BackupCleanup')]
        [string]$BackupPath,
        
        [Parameter(ParameterSetName = 'BackupCleanup')]
        [int]$MaxAge = 30,
        
        [Parameter(ParameterSetName = 'BackupCleanup')]
        [string]$ArchivePath,
        
        [switch]$Force
    )
```

#### Parameters

- **ProjectRoot** [String] *(Required)*

- **ProblematicPatterns** [String[]] *(Default: @())*

- **CreatePreventionRules** [SwitchParameter]

- **BackupPath** [String] *(Required)*

- **MaxAge** [Int32] *(Default: 30)*

- **ArchivePath** [String]

- **Force** [SwitchParameter]



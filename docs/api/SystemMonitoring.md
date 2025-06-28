# SystemMonitoring Module

**Version:** 1.0.0  
**Description:** Comprehensive system monitoring and health management for AitherZero infrastructure

## Overview

Comprehensive system monitoring and health management for AitherZero infrastructure

## Functions

### Invoke-HealthCheck

**Synopsis:** 

**Description:**


#### Syntax
```powershell
param(
        [Parameter()]
        [switch]$Comprehensive,
        
        [Parameter()]
        [ValidateSet('minor', 'major', 'all')]
        [string]$AutoFix,
        
        [Parameter()]
        [switch]$Report,
        
        [Parameter()]
        [string]$Schedule,
        
        [Parameter()]
        [ValidateSet('System', 'Services', 'Security', 'Performance', 'Storage')]
        [string[]]$Categories = @('System', 'Services', 'Performance', 'Storage'),
        
        [Parameter()]
        [string]$ExportPath
    )
```

#### Parameters

- **Comprehensive** [SwitchParameter]

- **AutoFix** [String]
  Valid values: minor, major, all

- **Report** [SwitchParameter]

- **Schedule** [String]

- **Categories** [String[]] *(Default: @('System', 'Services', 'Performance', 'Storage'))*
  Valid values: System, Services, Security, Performance, Storage

- **ExportPath** [String]


### Test-SystemHealth

**Synopsis:** 

**Description:**


#### Syntax
```powershell
param([bool]$AutoFix, [string]$FixLevel)
```

#### Parameters

- **AutoFix** [Boolean]

- **FixLevel** [String]


### Test-ServicesHealth

**Synopsis:** 

**Description:**


#### Syntax
```powershell
param([bool]$AutoFix, [string]$FixLevel)
```

#### Parameters

- **AutoFix** [Boolean]

- **FixLevel** [String]


### Test-PerformanceHealth

**Synopsis:** 

**Description:**


#### Syntax
```powershell
param([bool]$AutoFix, [string]$FixLevel)
```

#### Parameters

- **AutoFix** [Boolean]

- **FixLevel** [String]


### Test-StorageHealth

**Synopsis:** 

**Description:**


#### Syntax
```powershell
param([bool]$AutoFix, [string]$FixLevel)
```

#### Parameters

- **AutoFix** [Boolean]

- **FixLevel** [String]


### Test-SecurityHealth

**Synopsis:** 

**Description:**


#### Syntax
```powershell
param([bool]$AutoFix, [string]$FixLevel)
```

#### Parameters

- **AutoFix** [Boolean]

- **FixLevel** [String]


### Get-HealthStatus

**Synopsis:** 

**Description:**


#### Syntax
```powershell
param($Percentage)
```

#### Parameters

- **Percentage** [Object]


### Show-HealthSummary

**Synopsis:** 

**Description:**


#### Syntax
```powershell
param($Results)
```

#### Parameters

- **Results** [Object]


### Set-HealthCheckSchedule

**Synopsis:** 

**Description:**


#### Syntax
```powershell
param($Schedule, $Categories, $AutoFix)
```

#### Parameters

- **Schedule** [Object]

- **Categories** [Object]

- **AutoFix** [Object]



# ScriptManager Module

**Version:** 1.0.0  
**Description:** Module for ScriptManager functionality in Aitherium Infrastructure Automation

## Overview

Module for ScriptManager functionality in Aitherium Infrastructure Automation

## Functions

### Get-ScriptRepository

**Synopsis:** 

**Description:**


#### Syntax
```powershell
param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )
```

#### Parameters

- **Path** [String]


### Get-ScriptTemplate

**Synopsis:** 

**Description:**


#### Syntax
```powershell
param(
        [Parameter()]
        [string]$TemplateName,

        [Parameter()]
        [string]$Category
    )
```

#### Parameters

- **TemplateName** [String]

- **Category** [String]


### Invoke-OneOffScript

**Synopsis:** 

**Description:**


#### Syntax
```powershell
param(
        [Parameter(Mandatory)]
        [string]$ScriptPath,

        [hashtable]$Parameters = @{},

        [switch]$Force
    )
```

#### Parameters

- **ScriptPath** [String] *(Required)*

- **Parameters** [Hashtable] *(Default: @{})*

- **Force** [SwitchParameter]


### Start-ScriptExecution

**Synopsis:** 

**Description:**


#### Syntax
```powershell
param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ScriptName,

        [Parameter()]
        [string[]]$Arguments = @(),

        [Parameter()]
        [string]$WorkingDirectory
    )
```

#### Parameters

- **ScriptName** [String] *(Required)*

- **Arguments** [String[]] *(Default: @())*

- **WorkingDirectory** [String]



# LabRunner Module

**Version:** 0.1.0  
**Description:** LabRunner module for Aitherium Infrastructure Automation

## Overview

LabRunner module for Aitherium Infrastructure Automation

## Functions

### Initialize-StandardParameters

**Synopsis:** 

**Description:**


#### Syntax
```powershell
param(
        [Parameter()]
        [string]$ScriptName = (Split-Path -Leaf $MyInvocation.PSCommandPath),
        
        [Parameter()]
        [object]$Config,
        
        [Parameter()]
        [hashtable]$InputParameters = @{},
        
        [Parameter()]
        [string[]]$RequiredParameters = @(),
        
        [Parameter()]
        [hashtable]$DefaultConfig = @{}
    )
```

#### Parameters

- **ScriptName** [String] *(Default: (Split-Path -Leaf $MyInvocation.PSCommandPath))*

- **Config** [Object]

- **InputParameters** [Hashtable] *(Default: @{})*

- **RequiredParameters** [String[]] *(Default: @())*

- **DefaultConfig** [Hashtable] *(Default: @{})*


### Invoke-ParallelLabRunner

**Synopsis:** 

**Description:**


#### Syntax
```powershell
param(
        [Parameter(Mandatory=$true)]
        [array]$Scripts,
        
        [Parameter()]
        [int]$MaxConcurrency = [Environment]::ProcessorCount,
        
        [Parameter()]
        [int]$TimeoutMinutes = 30,
        
        [Parameter()]
        [switch]$SafeMode
    )
```

#### Parameters

- **Scripts** [Array] *(Required)*

- **MaxConcurrency** [Int32] *(Default: [Environment]::ProcessorCount)*

- **TimeoutMinutes** [Int32] *(Default: 30)*

- **SafeMode** [SwitchParameter]



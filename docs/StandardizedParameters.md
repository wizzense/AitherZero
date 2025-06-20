# Standardized Parameter Handling

This document describes the standardized parameter handling system implemented across the Aitherium Infrastructure Automation project.

## Overview

The standardized parameter system ensures consistent behavior across all scripts within the project. It provides a centralized mechanism for handling common parameters like `Verbosity`, `WhatIf`, `Auto`, and `Force`.

## Using the System

### For Script Authors

1. Import the required modules first:

```powershell
Import-Module "$env:PWSH_MODULES_PATH/LabRunner" -Force
Import-Module "$env:PWSH_MODULES_PATH/Logging" -Force
```

2. Define a standard parameter block in your script:

```powershell
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter()]
    [object]$Config,

    [Parameter()]
    [ValidateSet('silent', 'normal', 'detailed')]
    [string]$Verbosity = 'normal',
    
    [Parameter()]
    [switch]$Auto,
    
    [Parameter()]
    [switch]$Force
)
```

3. Initialize the standardized parameter handling:

```powershell
$params = Initialize-StandardParameters -InputParameters $PSBoundParameters -ScriptName $MyInvocation.MyCommand.Name
```

4. Use the standardized parameter values in your script:

```powershell
if ($params.Verbosity -eq 'detailed') {
    Write-CustomLog "Detailed mode enabled" -Level DEBUG
}

if ($params.IsAutoMode) {
    # Skip interactive prompts
}

if ($params.IsForceMode) {
    # Skip validations
}

if (-not $params.IsWhatIfMode -and $PSCmdlet.ShouldProcess("Target", "Operation")) {
    # Perform actual operations
}
```

### Parameter Reference

The `$params` object returned by `Initialize-StandardParameters` contains the following properties:

| Property | Type | Description |
|----------|------|-------------|
| `ScriptName` | string | The name of the script being executed |
| `Verbosity` | string | The verbosity level ('silent', 'normal', 'detailed') |
| `IsNonInteractive` | bool | Whether the script is running in non-interactive mode |
| `IsWhatIfMode` | bool | Whether the script is running in WhatIf mode |
| `IsAutoMode` | bool | Whether the script is running in automatic mode |
| `IsForceMode` | bool | Whether the script is running with Force parameter |
| `Config` | object | The configuration object passed to the script |

## Benefits

1. **Consistency**: All scripts behave the same way with respect to common parameters
2. **Maintainability**: Parameter handling logic is centralized and can be updated in one place
3. **Discoverability**: Standard parameters are documented and work the same across all scripts
4. **Extensibility**: New common parameters can be added to the central handling system

## Example Script

See `StandardizedTemplate.ps1` for a complete example of how to use the standardized parameter system.

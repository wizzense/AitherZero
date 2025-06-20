# Standardized Parameter System

Aitherium Infrastructure Automation now features a standardized parameter handling system across all scripts, ensuring consistent behavior and improved reliability.

## Key Features

- **Standard Parameters**: All scripts use the same parameter set (Config, Verbosity, WhatIf, Auto, Force)
- **Centralized Logic**: Parameter validation and handling is centralized for easy maintenance
- **Consistent Behavior**: WhatIf mode, verbosity levels, and other parameters work the same across all scripts

## Using Standardized Parameters

Import required modules and initialize parameters:

```powershell
Import-Module "$env:PWSH_MODULES_PATH/Logging" -Force
Import-Module "$env:PWSH_MODULES_PATH/LabRunner" -Force

# Initialize standardized parameters
$params = Initialize-StandardParameters -InputParameters $PSBoundParameters -ScriptName $MyInvocation.MyCommand.Name
```

Then use the parameter values:

```powershell
if ($params.Verbosity -eq 'detailed') {
    # Show detailed output
}

if ($params.IsWhatIfMode) {
    # Handle WhatIf mode
}
```

## Converting Existing Scripts

Use the provided utility script:

```powershell
.\tools\Update-ScriptParameters.ps1 -Path "aither-core/scripts" -WhatIf
```

For more information, see the [Standardized Parameters Documentation](docs/StandardizedParameters.md).

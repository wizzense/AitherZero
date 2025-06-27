<#
.SYNOPSIS
Executes a one-off script with optional parameters.

.DESCRIPTION
This function executes a registered one-off script. If the script is not registered, it will auto-register it for execution.

.PARAMETER ScriptPath
Path to the script to execute.

.PARAMETER Parameters
Hashtable of parameters to pass to the script.

.PARAMETER Force
Force re-execution of an already executed script.

.EXAMPLE
Invoke-OneOffScript -ScriptPath "C:\scripts\test.ps1"

.EXAMPLE
Invoke-OneOffScript -ScriptPath "C:\scripts\test.ps1" -Parameters @{Name="Test"; Count=5}
#>

function Invoke-OneOffScript {
    param(
        [Parameter(Mandatory)]
        [string]$ScriptPath,

        [hashtable]$Parameters = @{},

        [switch]$Force
    )

    # This function is actually implemented in the main module file
    # This file exists for discovery and help purposes
    throw "This function should be called from the ScriptManager module context"
}

#Requires -Version 7.0

<#
.SYNOPSIS
    Script template with standardized parameter handling
.DESCRIPTION
    Uses the Initialize-StandardParameters function to implement consistent
    parameter handling across all OpenTofu Lab Automation scripts.
.PARAMETER Config
    Configuration object passed from the lab runner
.PARAMETER Verbosity
    Set verbosity level: silent, normal, detailed
.PARAMETER WhatIf
    Show what would happen if the script runs
.PARAMETER Auto
    Run in automatic mode without prompts
.PARAMETER Force
    Force operations even if validations fail
.EXAMPLE
    .\Standardized-Template.ps1 -Config $config -Verbosity detailed
#>

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

# Import required modules - Make sure module imports come after the param block
Import-Module "$env:PWSH_MODULES_PATH/Logging" -Force
Import-Module "$env:PWSH_MODULES_PATH/LabRunner" -Force

# Set error handling preferences
$ErrorActionPreference = 'Stop'

try {
    # Initialize standardized parameter handling
    $params = Initialize-StandardParameters -InputParameters $PSBoundParameters -ScriptName $MyInvocation.MyCommand.Name
    
    # Use $params values for script execution
    # $params.Verbosity - Verbosity level (silent, normal, detailed)
    # $params.IsWhatIfMode - True if running in WhatIf mode
    # $params.IsNonInteractive - True if running in non-interactive mode
    # $params.IsAutoMode - True if running in automatic mode
    # $params.IsForceMode - True if running with Force parameter
    # $params.Config - Configuration object
    
    # Handle WhatIf mode with ShouldProcess
    if (-not $params.IsWhatIfMode -and $PSCmdlet.ShouldProcess("Target", "Operation")) {
        # Main script execution
        Write-CustomLog "Executing script with standard parameters" -Level INFO
        
        # Execute your script logic inside a LabStep for consistent execution
        Invoke-LabStep -Config $params.Config -Body {
            # Your script implementation here
            Write-CustomLog "Script is running with:" -Level INFO
            Write-CustomLog " - Verbosity: $($params.Verbosity)" -Level INFO
            Write-CustomLog " - Auto: $($params.IsAutoMode)" -Level INFO
            Write-CustomLog " - Force: $($params.IsForceMode)" -Level INFO
            
            # Example logic with verbosity control
            if ($params.Verbosity -eq 'detailed') {
                Write-CustomLog "Running with detailed output" -Level DEBUG
                # Add detailed diagnostics here
            }
            
            # Example logic with auto mode
            if ($params.IsAutoMode) {
                Write-CustomLog "Running in automatic mode - skipping prompts" -Level INFO
                # Skip interactive prompts
            }
            
            # Example logic with Force
            if ($params.IsForceMode) {
                Write-CustomLog "Force mode enabled - skipping validations" -Level WARN
                # Skip validation steps
            }
        }
        
        Write-CustomLog "Script completed successfully" -Level SUCCESS
    }
    else {
        Write-CustomLog "WhatIf: Script would execute with these parameters:" -Level INFO
        Write-CustomLog " - Verbosity: $($params.Verbosity)" -Level INFO
        Write-CustomLog " - Non-Interactive: $($params.IsNonInteractive)" -Level INFO
        Write-CustomLog " - Auto: $($params.IsAutoMode)" -Level INFO
        Write-CustomLog " - Force: $($params.IsForceMode)" -Level INFO
    }
}
catch {
    Write-CustomLog "Script failed: $($_.Exception.Message)" -Level ERROR
    
    if ($params -and $params.Verbosity -eq 'detailed') {
        Write-CustomLog "Stack trace: $($_.ScriptStackTrace)" -Level DEBUG
    }
    
    throw
}

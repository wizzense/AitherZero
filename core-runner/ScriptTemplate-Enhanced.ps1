# pwsh/ScriptTemplate-Enhanced.ps1
<#
.SYNOPSIS
 Enhanced template for PowerShell scripts with full parameter support
.DESCRIPTION
 This updated template ensures correct PowerShell syntax by placing Param blocks
 before Import-Module statements, includes proper error handling, consistent
 parameter usage, and follows OpenTofu Lab Automation conventions.
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
 .\ScriptTemplate-Enhanced.ps1 -Config $labConfig
.NOTES
 Always place Param() block BEFORE Import-Module statements
 This template standardizes parameters across all automation scripts
#>

#Requires -Version 7.0

# CORRECT ORDER: Param block comes FIRST
[CmdletBinding(SupportsShouldProcess)]
Param(
    [Parameter(Mandatory = $true)]
    [object]$Config,
 
    [Parameter()]
    [ValidateSet('silent', 'normal', 'detailed')]
    [string]$Verbosity = 'normal',
    
    [Parameter()]
    [switch]$Auto,
    
    [Parameter()]
    [switch]$Force
)

# Import standard modules
Import-Module "$env:PWSH_MODULES_PATH/Logging" -Force
Import-Module "$env:PWSH_MODULES_PATH/LabRunner" -Force

# Set error handling
$ErrorActionPreference = 'Stop'

try {
    # Initialize logging and show script details
    Write-CustomLog "Starting $($MyInvocation.MyCommand.Name)" -Level INFO
    
    # Handle WhatIf mode explicitly
    if ($PSCmdlet.ShouldProcess("Target", "Operation")) {
        Write-CustomLog "Running script in execution mode" -Level INFO
    }
    else {
        Write-CustomLog "Running script in WhatIf mode - no changes will be made" -Level INFO
        return
    }
    
    # Validate configuration
    if (-not $Config) {
        throw 'Configuration object is required'
    }
 
    # Main script logic goes here - wrapped in LabStep for consistent execution
    Invoke-LabStep -Config $Config -Body {
        Write-CustomLog "Template script executing with config: $($Config.GetType().Name)" -Level INFO
        
        # Example of handling verbosity parameter
        if ($Verbosity -eq 'detailed') {
            Write-CustomLog "Running with detailed verbosity" -Level DEBUG
            # Show more diagnostic information
        }
        
        # Example of handling Auto mode
        if ($Auto) {
            Write-CustomLog "Running in automatic mode" -Level INFO
            # Skip interactive prompts
        }
        
        # Example of handling Force parameter
        if ($Force) {
            Write-CustomLog "Force mode enabled - skipping validations" -Level WARN
            # Skip validations
        }
        
        # Your script implementation here
        # ...
    }
    
    Write-CustomLog "Script $($MyInvocation.MyCommand.Name) completed successfully" -Level SUCCESS
} 
catch {
    Write-CustomLog "Script failed: $($_.Exception.Message)" -Level ERROR
    Write-CustomLog "Stack trace: $($_.ScriptStackTrace)" -Level DEBUG
    throw
}

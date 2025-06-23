# pwsh/ScriptTemplate.ps1
<#
.SYNOPSIS
 Template for PowerShell scripts with proper parameter/import ordering
.DESCRIPTION
 This template ensures correct PowerShell syntax by placing Param blocks
 before Import-Module statements, includes proper error handling, and
 follows project conventions.
.PARAMETER Config
 Configuration object passed from the lab runner
.PARAMETER ExampleParam
 Example parameter - replace with actual parameters needed
.EXAMPLE
 .\ScriptTemplate.ps1 -Config $labConfig
.NOTES
 Always place Param() block BEFORE Import-Module statements
 This template prevents the parameter ordering syntax errors
#>

# CORRECT ORDER: Param block comes FIRST
Param(
    Parameter(Mandatory = $true)
    object$Config,
 
    Parameter(Mandatory = $false)
    string$ExampleParam = 'DefaultValue'
)

# Import-Module statements go AFTER Param block
Import-Module '/$env:PROJECT_ROOT/pwsh/modules/LabRunner/' -Force # Set error handling
$ErrorActionPreference = 'Stop'

try {
    # Initialize logging
    Write-LabLog 'Starting script execution' -Level Info
 
    # Validate configuration
    if (-not $Config) {
        throw 'Configuration object is required'
    }
 
    # Main script logic goes here
    Write-LabLog "Template script executing with config: $($Config.GetType().Name)" -Level Info
 
    # Example of accessing lab utilities
    $labState = Get-LabState
    Write-LabLog "Current lab state: $($labState.Status)" -Level Info
 
    # Your script implementation here
    # ...
 
    Write-LabLog 'Script completed successfully' -Level Success
 
} catch {
    Write-LabLog "Script failed: $($_.Exception.Message)" -Level Error
    Write-LabLog "Stack trace: $($_.ScriptStackTrace)" -Level Debug
    throw
}

# Best practices included in this template:
# PASS Param block before Import-Module (prevents syntax errors)
# PASS Comment-based help
# PASS Error handling with try/catch
# PASS Proper logging using lab utilities
# PASS Configuration validation
# PASS Consistent formatting and style



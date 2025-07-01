# Initialize-StandardParameters.ps1
# Provides standardized parameter handling across all OpenTofu Lab Automation scripts

function Initialize-StandardParameters {
    <#
    .SYNOPSIS
        Provides standardized parameter handling across OpenTofu Lab Automation scripts
    .DESCRIPTION
        Initializes and validates standard parameters, ensures consistent behavior,
        and provides central configuration for all scripts in the project.
    .PARAMETER ScriptName
        Name of the script being executed (defaults to caller's name)
    .PARAMETER Config
        Configuration object passed from core-runner
    .PARAMETER InputParameters
        PowerShell Bound Parameters from calling script ($PSBoundParameters)
    .PARAMETER RequiredParameters
        Array of parameter names that are required for this script
    .PARAMETER DefaultConfig
        Default configuration to use if none is provided
    .EXAMPLE
        Initialize-StandardParameters -ScriptName $MyInvocation.MyCommand.Name -InputParameters $PSBoundParameters
    .NOTES
        This ensures consistent parameter handling across all automation scripts
    #>    [CmdletBinding()]
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

    # Local parameters structure to maintain script state
    $scriptParams = @{
        ScriptName = $ScriptName
        Verbosity = 'normal'
        IsNonInteractive = $false
        IsWhatIfMode = $false
        IsAutoMode = $false
        IsForceMode = $false
        Config = $null
        ModulesLoaded = @()
    }

    # Set up logging first if the module is available
    Import-Module "$env:PWSH_MODULES_PATH/Logging" -ErrorAction SilentlyContinue
    $scriptParams.ModulesLoaded += 'Logging'
    
    # Log script initialization
    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog "Initializing script: $ScriptName" -Level INFO
    }
    else {
        Write-Host "Initializing script: $ScriptName" -ForegroundColor Cyan
    }

    # Process standard parameters
    # ----------------------------
    
    # Handle Verbosity parameter
    if ($InputParameters.ContainsKey('Verbosity')) {
        $scriptParams.Verbosity = $InputParameters.Verbosity
    }
    elseif ($env:LAB_CONSOLE_LEVEL) {
        # Map numeric level back to string
        $scriptParams.Verbosity = switch ($env:LAB_CONSOLE_LEVEL) {
            '0' { 'silent' }
            '1' { 'normal' }
            '2' { 'detailed' }
            default { 'normal' }
        }
    }
    
    # Handle WhatIf parameter
    $scriptParams.IsWhatIfMode = $WhatIfPreference -or ($InputParameters.ContainsKey('WhatIf') -and $InputParameters.WhatIf)
    
    # Handle NonInteractive
    $scriptParams.IsNonInteractive = $false
    if ($InputParameters.ContainsKey('NonInteractive')) {
        $scriptParams.IsNonInteractive = $InputParameters.NonInteractive
    }
    else {
        # Auto-detect non-interactive mode if not explicitly set
        $scriptParams.IsNonInteractive = ($Host.Name -eq 'Default Host') -or 
                                        ([Environment]::UserInteractive -eq $false) -or
                                        ($env:PESTER_RUN -eq 'true') -or
                                        $scriptParams.IsWhatIfMode
    }
    
    # Handle Auto parameter
    if ($InputParameters.ContainsKey('Auto')) {
        $scriptParams.IsAutoMode = $InputParameters.Auto
        if ($scriptParams.IsAutoMode) {
            $scriptParams.IsNonInteractive = $true
        }
    }
    
    # Handle Force parameter
    if ($InputParameters.ContainsKey('Force')) {
        $scriptParams.IsForceMode = $InputParameters.Force
    }
    
    # Handle Config parameter
    if ($null -ne $Config) {
        $scriptParams.Config = $Config
    }
    elseif ($InputParameters.ContainsKey('Config') -and $null -ne $InputParameters.Config) {
        $scriptParams.Config = $InputParameters.Config
    }
    else {
        # Use default config if no config was provided
        $scriptParams.Config = $DefaultConfig
        
        if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
            Write-CustomLog "No configuration provided, using default configuration" -Level WARN
        }
    }
    
    # Handle required parameters
    foreach ($param in $RequiredParameters) {
        if (-not $InputParameters.ContainsKey($param) -or $null -eq $InputParameters[$param]) {
            $errorMessage = "Required parameter '$param' missing for script: $ScriptName"
            if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
                Write-CustomLog $errorMessage -Level ERROR
            }
            throw $errorMessage
        }
    }
    
    # Configure environment based on parameters
    # -----------------------------------------
    
    # Configure verbosity level
    if ($env:LAB_CONSOLE_LEVEL -ne $scriptParams.Verbosity) {
        $env:LAB_CONSOLE_LEVEL = switch ($scriptParams.Verbosity) {
            'silent' { 0 }
            'normal' { 1 }
            'detailed' { 2 }
            default { 1 }
        }
    }
    
    # Summary output
    # --------------
    $logLevel = if ($scriptParams.Verbosity -eq 'detailed') { 'INFO' } else { 'DEBUG' }
    
    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog "Script parameters initialized:" -Level $logLevel
        Write-CustomLog " - Verbosity: $($scriptParams.Verbosity)" -Level $logLevel
        Write-CustomLog " - WhatIf mode: $($scriptParams.IsWhatIfMode)" -Level $logLevel
        Write-CustomLog " - NonInteractive mode: $($scriptParams.IsNonInteractive)" -Level $logLevel
        Write-CustomLog " - Auto mode: $($scriptParams.IsAutoMode)" -Level $logLevel
        Write-CustomLog " - Force mode: $($scriptParams.IsForceMode)" -Level $logLevel
        
        # Output configuration summary in detailed mode
        if ($scriptParams.Verbosity -eq 'detailed') {
            Write-CustomLog "Configuration:" -Level DEBUG
            $configType = if ($null -ne $scriptParams.Config) { $scriptParams.Config.GetType().Name } else { "None" }
            Write-CustomLog " - Type: $configType" -Level DEBUG
        }
    }
    
    # Return the standardized parameters
    return $scriptParams
}

Export-ModuleMember -Function Initialize-StandardParameters

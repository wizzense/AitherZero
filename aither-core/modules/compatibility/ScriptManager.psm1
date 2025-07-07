# ScriptManager Backward Compatibility Shim
# This module provides backward compatibility for the deprecated ScriptManager module
# All functionality has been moved to the new unified UtilityServices module

# Find the new UtilityServices module
. "$PSScriptRoot/../../shared/Find-ProjectRoot.ps1"
$projectRoot = Find-ProjectRoot
$utilityServicesPath = Join-Path $projectRoot "aither-core/modules/UtilityServices"

# Import the new unified module if available
$script:UtilityServicesLoaded = $false
if (Test-Path $utilityServicesPath) {
    try {
        Import-Module $utilityServicesPath -Force -ErrorAction Stop
        $script:UtilityServicesLoaded = $true
        Write-Warning "[DEPRECATED] ScriptManager module is deprecated. Functions are forwarded to UtilityServices. Please update your scripts to use 'Import-Module UtilityServices' instead."
    } catch {
        Write-Error "Failed to load UtilityManager module: $_"
    }
} else {
    # Fallback to original module if new one doesn't exist yet
    $originalModulePath = Join-Path $projectRoot "aither-core/modules/ScriptManager"
    if (Test-Path $originalModulePath) {
        try {
            Import-Module $originalModulePath -Force -ErrorAction Stop
            $script:UtilityServicesLoaded = $true
            Write-Warning "[COMPATIBILITY] Using legacy ScriptManager module. Please migrate to UtilityServices when available."
        } catch {
            Write-Error "Failed to load legacy ScriptManager module: $_"
        }
    }
}

# Deprecation warning function
function Show-DeprecationWarning {
    param(
        [string]$FunctionName,
        [string]$NewFunction = $null,
        [string]$NewModule = "UtilityServices"
    )
    
    $migrationMessage = if ($NewFunction) {
        "Use '$NewFunction' from the '$NewModule' module instead."
    } else {
        "Use the equivalent function from the '$NewModule' module instead."
    }
    
    Write-Warning "[DEPRECATED] $FunctionName is deprecated and will be removed in a future version. $migrationMessage"
    Write-Host "Migration Guide: https://github.com/AitherLabs/AitherZero/docs/migration/script-manager.md" -ForegroundColor Yellow
}

function Get-ScriptRepository {
    <#
    .SYNOPSIS
        [DEPRECATED] Get script repository information
    .DESCRIPTION
        This function is deprecated. Use Get-ScriptRepository from UtilityManager instead.
    #>
    [CmdletBinding()]
    param(
        [string]$RepositoryName,
        [switch]$ListAll
    )
    
    Show-DeprecationWarning -FunctionName "Get-ScriptRepository" -NewFunction "Get-ScriptRepository"
    
    if ($script:UtilityServicesLoaded) {
        if (Get-Command Get-ScriptRepository -ErrorAction SilentlyContinue) {
            return Get-ScriptRepository @PSBoundParameters
        }
    }
    
    throw "UtilityServices module not available. Please ensure the module is installed."
}

function Get-ScriptTemplate {
    <#
    .SYNOPSIS
        [DEPRECATED] Get script template
    .DESCRIPTION
        This function is deprecated. Use Get-ScriptTemplate from UtilityManager instead.
    #>
    [CmdletBinding()]
    param(
        [string]$TemplateName,
        [string]$Category,
        [switch]$ListAll
    )
    
    Show-DeprecationWarning -FunctionName "Get-ScriptTemplate" -NewFunction "Get-ScriptTemplate"
    
    if ($script:UtilityServicesLoaded) {
        if (Get-Command Get-ScriptTemplate -ErrorAction SilentlyContinue) {
            return Get-ScriptTemplate @PSBoundParameters
        }
    }
    
    throw "UtilityServices module not available. Please ensure the module is installed."
}

function Invoke-OneOffScript {
    <#
    .SYNOPSIS
        [DEPRECATED] Execute one-off script
    .DESCRIPTION
        This function is deprecated. Use Invoke-OneOffScript from UtilityManager instead.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ScriptName,
        [hashtable]$Parameters = @{},
        [switch]$WhatIf
    )
    
    Show-DeprecationWarning -FunctionName "Invoke-OneOffScript" -NewFunction "Invoke-OneOffScript"
    
    if ($script:UtilityServicesLoaded) {
        if (Get-Command Invoke-OneOffScript -ErrorAction SilentlyContinue) {
            return Invoke-OneOffScript @PSBoundParameters
        }
    }
    
    throw "UtilityServices module not available. Please ensure the module is installed."
}

function Start-ScriptExecution {
    <#
    .SYNOPSIS
        [DEPRECATED] Start script execution
    .DESCRIPTION
        This function is deprecated. Use Start-ScriptExecution from UtilityManager instead.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ScriptPath,
        [hashtable]$Parameters = @{},
        [string]$WorkingDirectory,
        [switch]$NoOutput,
        [switch]$Background
    )
    
    Show-DeprecationWarning -FunctionName "Start-ScriptExecution" -NewFunction "Start-ScriptExecution"
    
    if ($script:UtilityServicesLoaded) {
        if (Get-Command Start-ScriptExecution -ErrorAction SilentlyContinue) {
            return Start-ScriptExecution @PSBoundParameters
        }
    }
    
    throw "UtilityServices module not available. Please ensure the module is installed."
}

# Module initialization message
Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Yellow
Write-Host "║                    DEPRECATION NOTICE                       ║" -ForegroundColor Yellow
Write-Host "╠══════════════════════════════════════════════════════════════╣" -ForegroundColor Yellow
Write-Host "║ ScriptManager module has been DEPRECATED                    ║" -ForegroundColor Red
Write-Host "║ This compatibility shim forwards calls to UtilityServices   ║" -ForegroundColor Yellow
Write-Host "║                                                              ║" -ForegroundColor Yellow
Write-Host "║ Migration required:                                          ║" -ForegroundColor Cyan
Write-Host "║   Old: Import-Module ScriptManager                           ║" -ForegroundColor Gray
Write-Host "║   New: Import-Module UtilityServices                         ║" -ForegroundColor Green
Write-Host "║                                                              ║" -ForegroundColor Yellow
Write-Host "║ Migration Guide:                                             ║" -ForegroundColor Cyan
Write-Host "║ https://github.com/AitherLabs/AitherZero/docs/migration/     ║" -ForegroundColor Blue
Write-Host "║   script-manager.md                                         ║" -ForegroundColor Blue
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Yellow
Write-Host ""

# Export all functions for backward compatibility
Export-ModuleMember -Function @(
    'Get-ScriptRepository',
    'Get-ScriptTemplate',
    'Invoke-OneOffScript',
    'Start-ScriptExecution'
)
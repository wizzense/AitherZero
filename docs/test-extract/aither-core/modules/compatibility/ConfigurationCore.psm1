# ConfigurationCore Backward Compatibility Shim
# This module provides backward compatibility for the deprecated ConfigurationCore module
# All functionality has been moved to the new unified ConfigurationManager module

# Find the new ConfigurationManager module
. "$PSScriptRoot/../../shared/Find-ProjectRoot.ps1"
$projectRoot = Find-ProjectRoot
$configManagerPath = Join-Path $projectRoot "aither-core/modules/ConfigurationManager"

# Import the new unified module if available
$script:ConfigManagerLoaded = $false
if (Test-Path $configManagerPath) {
    try {
        Import-Module $configManagerPath -Force -ErrorAction Stop
        $script:ConfigManagerLoaded = $true
        Write-Warning "[DEPRECATED] ConfigurationCore module is deprecated. Functions are forwarded to ConfigurationManager. Please update your scripts to use 'Import-Module ConfigurationManager' instead."
    } catch {
        Write-Error "Failed to load ConfigurationManager module: $_"
    }
} else {
    # Fallback to original module if new one doesn't exist yet
    $originalModulePath = Join-Path $projectRoot "aither-core/modules/ConfigurationCore"
    if (Test-Path $originalModulePath) {
        try {
            Import-Module $originalModulePath -Force -ErrorAction Stop
            $script:ConfigManagerLoaded = $true
            Write-Warning "[COMPATIBILITY] Using legacy ConfigurationCore module. Please migrate to ConfigurationManager when available."
        } catch {
            Write-Error "Failed to load legacy ConfigurationCore module: $_"
        }
    }
}

# Deprecation warning function
function Show-DeprecationWarning {
    param(
        [string]$FunctionName,
        [string]$NewFunction = $null,
        [string]$NewModule = "ConfigurationManager"
    )
    
    $migrationMessage = if ($NewFunction) {
        "Use '$NewFunction' from the '$NewModule' module instead."
    } else {
        "Use the equivalent function from the '$NewModule' module instead."
    }
    
    Write-Warning "[DEPRECATED] $FunctionName is deprecated and will be removed in a future version. $migrationMessage"
    Write-Host "Migration Guide: https://github.com/AitherLabs/AitherZero/docs/migration/configuration-core.md" -ForegroundColor Yellow
}

# Core Configuration Management Functions
function Initialize-ConfigurationCore {
    <#
    .SYNOPSIS
        [DEPRECATED] Initialize the configuration core system
    .DESCRIPTION
        This function is deprecated. Use Initialize-ConfigurationManager instead.
    #>
    [CmdletBinding()]
    param(
        [string]$ConfigPath,
        [hashtable]$DefaultSettings = @{},
        [switch]$Force
    )
    
    Show-DeprecationWarning -FunctionName "Initialize-ConfigurationCore" -NewFunction "Initialize-ConfigurationManager"
    
    if ($script:ConfigManagerLoaded) {
        # Forward to new function if available
        if (Get-Command Initialize-ConfigurationManager -ErrorAction SilentlyContinue) {
            return Initialize-ConfigurationManager @PSBoundParameters
        } elseif (Get-Command Initialize-ConfigurationCore -ErrorAction SilentlyContinue) {
            # Use original function from imported module
            return & (Get-Command Initialize-ConfigurationCore -Module ConfigurationCore) @PSBoundParameters
        }
    }
    
    throw "ConfigurationManager module not available. Please ensure the module is installed."
}

function Get-ModuleConfiguration {
    <#
    .SYNOPSIS
        [DEPRECATED] Get module configuration
    .DESCRIPTION
        This function is deprecated. Use Get-ModuleConfiguration from ConfigurationManager instead.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ModuleName,
        [string]$ConfigKey,
        [string]$Environment,
        [switch]$IncludeDefaults
    )
    
    Show-DeprecationWarning -FunctionName "Get-ModuleConfiguration" -NewFunction "Get-ModuleConfiguration"
    
    if ($script:ConfigManagerLoaded) {
        if (Get-Command Get-ModuleConfiguration -ErrorAction SilentlyContinue) {
            return Get-ModuleConfiguration @PSBoundParameters
        }
    }
    
    throw "ConfigurationManager module not available. Please ensure the module is installed."
}

function Set-ModuleConfiguration {
    <#
    .SYNOPSIS
        [DEPRECATED] Set module configuration
    .DESCRIPTION
        This function is deprecated. Use Set-ModuleConfiguration from ConfigurationManager instead.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ModuleName,
        [Parameter(Mandatory)]
        $Configuration,
        [string]$Environment,
        [switch]$Merge,
        [switch]$Validate
    )
    
    Show-DeprecationWarning -FunctionName "Set-ModuleConfiguration" -NewFunction "Set-ModuleConfiguration"
    
    if ($script:ConfigManagerLoaded) {
        if (Get-Command Set-ModuleConfiguration -ErrorAction SilentlyContinue) {
            return Set-ModuleConfiguration @PSBoundParameters
        }
    }
    
    throw "ConfigurationManager module not available. Please ensure the module is installed."
}

function Test-ModuleConfiguration {
    <#
    .SYNOPSIS
        [DEPRECATED] Test module configuration validity
    .DESCRIPTION
        This function is deprecated. Use Test-ModuleConfiguration from ConfigurationManager instead.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ModuleName,
        [string]$Environment,
        [switch]$Detailed
    )
    
    Show-DeprecationWarning -FunctionName "Test-ModuleConfiguration" -NewFunction "Test-ModuleConfiguration"
    
    if ($script:ConfigManagerLoaded) {
        if (Get-Command Test-ModuleConfiguration -ErrorAction SilentlyContinue) {
            return Test-ModuleConfiguration @PSBoundParameters
        }
    }
    
    throw "ConfigurationManager module not available. Please ensure the module is installed."
}

function Register-ModuleConfiguration {
    <#
    .SYNOPSIS
        [DEPRECATED] Register a module's configuration schema
    .DESCRIPTION
        This function is deprecated. Use Register-ModuleConfiguration from ConfigurationManager instead.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ModuleName,
        [Parameter(Mandatory)]
        [hashtable]$Schema,
        [hashtable]$DefaultValues = @{},
        [switch]$Force
    )
    
    Show-DeprecationWarning -FunctionName "Register-ModuleConfiguration" -NewFunction "Register-ModuleConfiguration"
    
    if ($script:ConfigManagerLoaded) {
        if (Get-Command Register-ModuleConfiguration -ErrorAction SilentlyContinue) {
            return Register-ModuleConfiguration @PSBoundParameters
        }
    }
    
    throw "ConfigurationManager module not available. Please ensure the module is installed."
}

# Configuration Storage Functions
function Get-ConfigurationStore {
    <#
    .SYNOPSIS
        [DEPRECATED] Get the entire configuration store
    .DESCRIPTION
        This function is deprecated. Use Get-ConfigurationStore from ConfigurationManager instead.
    #>
    [CmdletBinding()]
    param(
        [string]$Environment,
        [switch]$IncludeMetadata
    )
    
    Show-DeprecationWarning -FunctionName "Get-ConfigurationStore" -NewFunction "Get-ConfigurationStore"
    
    if ($script:ConfigManagerLoaded) {
        if (Get-Command Get-ConfigurationStore -ErrorAction SilentlyContinue) {
            return Get-ConfigurationStore @PSBoundParameters
        }
    }
    
    throw "ConfigurationManager module not available. Please ensure the module is installed."
}

function Set-ConfigurationStore {
    <#
    .SYNOPSIS
        [DEPRECATED] Set configuration store data
    .DESCRIPTION
        This function is deprecated. Use Set-ConfigurationStore from ConfigurationManager instead.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Configuration,
        [string]$Environment,
        [switch]$Merge,
        [switch]$Backup
    )
    
    Show-DeprecationWarning -FunctionName "Set-ConfigurationStore" -NewFunction "Set-ConfigurationStore"
    
    if ($script:ConfigManagerLoaded) {
        if (Get-Command Set-ConfigurationStore -ErrorAction SilentlyContinue) {
            return Set-ConfigurationStore @PSBoundParameters
        }
    }
    
    throw "ConfigurationManager module not available. Please ensure the module is installed."
}

function Export-ConfigurationStore {
    <#
    .SYNOPSIS
        [DEPRECATED] Export configuration store to file
    .DESCRIPTION
        This function is deprecated. Use Export-ConfigurationStore from ConfigurationManager instead.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        [string]$Environment,
        [ValidateSet('JSON', 'YAML', 'XML')]
        [string]$Format = 'JSON',
        [switch]$IncludeMetadata
    )
    
    Show-DeprecationWarning -FunctionName "Export-ConfigurationStore" -NewFunction "Export-ConfigurationStore"
    
    if ($script:ConfigManagerLoaded) {
        if (Get-Command Export-ConfigurationStore -ErrorAction SilentlyContinue) {
            return Export-ConfigurationStore @PSBoundParameters
        }
    }
    
    throw "ConfigurationManager module not available. Please ensure the module is installed."
}

function Import-ConfigurationStore {
    <#
    .SYNOPSIS
        [DEPRECATED] Import configuration store from file
    .DESCRIPTION
        This function is deprecated. Use Import-ConfigurationStore from ConfigurationManager instead.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        [string]$Environment,
        [switch]$Merge,
        [switch]$Validate
    )
    
    Show-DeprecationWarning -FunctionName "Import-ConfigurationStore" -NewFunction "Import-ConfigurationStore"
    
    if ($script:ConfigManagerLoaded) {
        if (Get-Command Import-ConfigurationStore -ErrorAction SilentlyContinue) {
            return Import-ConfigurationStore @PSBoundParameters
        }
    }
    
    throw "ConfigurationManager module not available. Please ensure the module is installed."
}

# Environment Management Functions
function Get-ConfigurationEnvironment {
    <#
    .SYNOPSIS
        [DEPRECATED] Get current or all configuration environments
    .DESCRIPTION
        This function is deprecated. Use Get-ConfigurationEnvironment from ConfigurationManager instead.
    #>
    [CmdletBinding()]
    param(
        [string]$EnvironmentName,
        [switch]$All
    )
    
    Show-DeprecationWarning -FunctionName "Get-ConfigurationEnvironment" -NewFunction "Get-ConfigurationEnvironment"
    
    if ($script:ConfigManagerLoaded) {
        if (Get-Command Get-ConfigurationEnvironment -ErrorAction SilentlyContinue) {
            return Get-ConfigurationEnvironment @PSBoundParameters
        }
    }
    
    throw "ConfigurationManager module not available. Please ensure the module is installed."
}

function Set-ConfigurationEnvironment {
    <#
    .SYNOPSIS
        [DEPRECATED] Set the active configuration environment
    .DESCRIPTION
        This function is deprecated. Use Set-ConfigurationEnvironment from ConfigurationManager instead.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$EnvironmentName,
        [switch]$Force
    )
    
    Show-DeprecationWarning -FunctionName "Set-ConfigurationEnvironment" -NewFunction "Set-ConfigurationEnvironment"
    
    if ($script:ConfigManagerLoaded) {
        if (Get-Command Set-ConfigurationEnvironment -ErrorAction SilentlyContinue) {
            return Set-ConfigurationEnvironment @PSBoundParameters
        }
    }
    
    throw "ConfigurationManager module not available. Please ensure the module is installed."
}

function New-ConfigurationEnvironment {
    <#
    .SYNOPSIS
        [DEPRECATED] Create a new configuration environment
    .DESCRIPTION
        This function is deprecated. Use New-ConfigurationEnvironment from ConfigurationManager instead.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$EnvironmentName,
        [string]$Description,
        [hashtable]$Settings = @{},
        [switch]$SetAsCurrent
    )
    
    Show-DeprecationWarning -FunctionName "New-ConfigurationEnvironment" -NewFunction "New-ConfigurationEnvironment"
    
    if ($script:ConfigManagerLoaded) {
        if (Get-Command New-ConfigurationEnvironment -ErrorAction SilentlyContinue) {
            return New-ConfigurationEnvironment @PSBoundParameters
        }
    }
    
    throw "ConfigurationManager module not available. Please ensure the module is installed."
}

function Remove-ConfigurationEnvironment {
    <#
    .SYNOPSIS
        [DEPRECATED] Remove a configuration environment
    .DESCRIPTION
        This function is deprecated. Use Remove-ConfigurationEnvironment from ConfigurationManager instead.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$EnvironmentName,
        [switch]$Force
    )
    
    Show-DeprecationWarning -FunctionName "Remove-ConfigurationEnvironment" -NewFunction "Remove-ConfigurationEnvironment"
    
    if ($script:ConfigManagerLoaded) {
        if (Get-Command Remove-ConfigurationEnvironment -ErrorAction SilentlyContinue) {
            return Remove-ConfigurationEnvironment @PSBoundParameters
        }
    }
    
    throw "ConfigurationManager module not available. Please ensure the module is installed."
}

# Configuration Validation Functions
function Register-ConfigurationSchema {
    <#
    .SYNOPSIS
        [DEPRECATED] Register a configuration schema
    .DESCRIPTION
        This function is deprecated. Use Register-ConfigurationSchema from ConfigurationManager instead.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ModuleName,
        [Parameter(Mandatory)]
        [hashtable]$Schema,
        [switch]$Force
    )
    
    Show-DeprecationWarning -FunctionName "Register-ConfigurationSchema" -NewFunction "Register-ConfigurationSchema"
    
    if ($script:ConfigManagerLoaded) {
        if (Get-Command Register-ConfigurationSchema -ErrorAction SilentlyContinue) {
            return Register-ConfigurationSchema @PSBoundParameters
        }
    }
    
    throw "ConfigurationManager module not available. Please ensure the module is installed."
}

function Validate-Configuration {
    <#
    .SYNOPSIS
        [DEPRECATED] Validate configuration against schema
    .DESCRIPTION
        This function is deprecated. Use Validate-Configuration from ConfigurationManager instead.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ModuleName,
        [hashtable]$Configuration,
        [string]$Environment,
        [switch]$Detailed
    )
    
    Show-DeprecationWarning -FunctionName "Validate-Configuration" -NewFunction "Validate-Configuration"
    
    if ($script:ConfigManagerLoaded) {
        if (Get-Command Validate-Configuration -ErrorAction SilentlyContinue) {
            return Validate-Configuration @PSBoundParameters
        }
    }
    
    throw "ConfigurationManager module not available. Please ensure the module is installed."
}

function Get-ConfigurationSchema {
    <#
    .SYNOPSIS
        [DEPRECATED] Get configuration schema
    .DESCRIPTION
        This function is deprecated. Use Get-ConfigurationSchema from ConfigurationManager instead.
    #>
    [CmdletBinding()]
    param(
        [string]$ModuleName,
        [switch]$All
    )
    
    Show-DeprecationWarning -FunctionName "Get-ConfigurationSchema" -NewFunction "Get-ConfigurationSchema"
    
    if ($script:ConfigManagerLoaded) {
        if (Get-Command Get-ConfigurationSchema -ErrorAction SilentlyContinue) {
            return Get-ConfigurationSchema @PSBoundParameters
        }
    }
    
    throw "ConfigurationManager module not available. Please ensure the module is installed."
}

# Hot Reload Functions
function Enable-ConfigurationHotReload {
    <#
    .SYNOPSIS
        [DEPRECATED] Enable hot reload for configuration changes
    .DESCRIPTION
        This function is deprecated. Use Enable-ConfigurationHotReload from ConfigurationManager instead.
    #>
    [CmdletBinding()]
    param(
        [string[]]$WatchPaths,
        [int]$PollingInterval = 5000
    )
    
    Show-DeprecationWarning -FunctionName "Enable-ConfigurationHotReload" -NewFunction "Enable-ConfigurationHotReload"
    
    if ($script:ConfigManagerLoaded) {
        if (Get-Command Enable-ConfigurationHotReload -ErrorAction SilentlyContinue) {
            return Enable-ConfigurationHotReload @PSBoundParameters
        }
    }
    
    throw "ConfigurationManager module not available. Please ensure the module is installed."
}

function Disable-ConfigurationHotReload {
    <#
    .SYNOPSIS
        [DEPRECATED] Disable configuration hot reload
    .DESCRIPTION
        This function is deprecated. Use Disable-ConfigurationHotReload from ConfigurationManager instead.
    #>
    [CmdletBinding()]
    param()
    
    Show-DeprecationWarning -FunctionName "Disable-ConfigurationHotReload" -NewFunction "Disable-ConfigurationHotReload"
    
    if ($script:ConfigManagerLoaded) {
        if (Get-Command Disable-ConfigurationHotReload -ErrorAction SilentlyContinue) {
            return Disable-ConfigurationHotReload @PSBoundParameters
        }
    }
    
    throw "ConfigurationManager module not available. Please ensure the module is installed."
}

function Get-ConfigurationWatcher {
    <#
    .SYNOPSIS
        [DEPRECATED] Get configuration file watcher status
    .DESCRIPTION
        This function is deprecated. Use Get-ConfigurationWatcher from ConfigurationManager instead.
    #>
    [CmdletBinding()]
    param()
    
    Show-DeprecationWarning -FunctionName "Get-ConfigurationWatcher" -NewFunction "Get-ConfigurationWatcher"
    
    if ($script:ConfigManagerLoaded) {
        if (Get-Command Get-ConfigurationWatcher -ErrorAction SilentlyContinue) {
            return Get-ConfigurationWatcher @PSBoundParameters
        }
    }
    
    throw "ConfigurationManager module not available. Please ensure the module is installed."
}

# Event System Functions
function Publish-ConfigurationEvent {
    <#
    .SYNOPSIS
        [DEPRECATED] Publish a configuration event
    .DESCRIPTION
        This function is deprecated. Use Publish-ConfigurationEvent from ConfigurationManager instead.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$EventName,
        [hashtable]$EventData = @{},
        [string]$Source = 'ConfigurationCore'
    )
    
    Show-DeprecationWarning -FunctionName "Publish-ConfigurationEvent" -NewFunction "Publish-ConfigurationEvent"
    
    if ($script:ConfigManagerLoaded) {
        if (Get-Command Publish-ConfigurationEvent -ErrorAction SilentlyContinue) {
            return Publish-ConfigurationEvent @PSBoundParameters
        }
    }
    
    throw "ConfigurationManager module not available. Please ensure the module is installed."
}

function Subscribe-ConfigurationEvent {
    <#
    .SYNOPSIS
        [DEPRECATED] Subscribe to configuration events
    .DESCRIPTION
        This function is deprecated. Use Subscribe-ConfigurationEvent from ConfigurationManager instead.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$EventName,
        [Parameter(Mandatory)]
        [scriptblock]$Action,
        [string]$SubscriberName
    )
    
    Show-DeprecationWarning -FunctionName "Subscribe-ConfigurationEvent" -NewFunction "Subscribe-ConfigurationEvent"
    
    if ($script:ConfigManagerLoaded) {
        if (Get-Command Subscribe-ConfigurationEvent -ErrorAction SilentlyContinue) {
            return Subscribe-ConfigurationEvent @PSBoundParameters
        }
    }
    
    throw "ConfigurationManager module not available. Please ensure the module is installed."
}

function Unsubscribe-ConfigurationEvent {
    <#
    .SYNOPSIS
        [DEPRECATED] Unsubscribe from configuration events
    .DESCRIPTION
        This function is deprecated. Use Unsubscribe-ConfigurationEvent from ConfigurationManager instead.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$EventName,
        [string]$SubscriberName
    )
    
    Show-DeprecationWarning -FunctionName "Unsubscribe-ConfigurationEvent" -NewFunction "Unsubscribe-ConfigurationEvent"
    
    if ($script:ConfigManagerLoaded) {
        if (Get-Command Unsubscribe-ConfigurationEvent -ErrorAction SilentlyContinue) {
            return Unsubscribe-ConfigurationEvent @PSBoundParameters
        }
    }
    
    throw "ConfigurationManager module not available. Please ensure the module is installed."
}

function Get-ConfigurationEventHistory {
    <#
    .SYNOPSIS
        [DEPRECATED] Get configuration event history
    .DESCRIPTION
        This function is deprecated. Use Get-ConfigurationEventHistory from ConfigurationManager instead.
    #>
    [CmdletBinding()]
    param(
        [string]$EventName,
        [int]$Last = 100,
        [datetime]$Since
    )
    
    Show-DeprecationWarning -FunctionName "Get-ConfigurationEventHistory" -NewFunction "Get-ConfigurationEventHistory"
    
    if ($script:ConfigManagerLoaded) {
        if (Get-Command Get-ConfigurationEventHistory -ErrorAction SilentlyContinue) {
            return Get-ConfigurationEventHistory @PSBoundParameters
        }
    }
    
    throw "ConfigurationManager module not available. Please ensure the module is installed."
}

# Utility Functions
function Backup-Configuration {
    <#
    .SYNOPSIS
        [DEPRECATED] Backup current configuration
    .DESCRIPTION
        This function is deprecated. Use Backup-Configuration from ConfigurationManager instead.
    #>
    [CmdletBinding()]
    param(
        [string]$BackupPath,
        [string]$Description,
        [string]$Environment
    )
    
    Show-DeprecationWarning -FunctionName "Backup-Configuration" -NewFunction "Backup-Configuration"
    
    if ($script:ConfigManagerLoaded) {
        if (Get-Command Backup-Configuration -ErrorAction SilentlyContinue) {
            return Backup-Configuration @PSBoundParameters
        }
    }
    
    throw "ConfigurationManager module not available. Please ensure the module is installed."
}

function Restore-Configuration {
    <#
    .SYNOPSIS
        [DEPRECATED] Restore configuration from backup
    .DESCRIPTION
        This function is deprecated. Use Restore-Configuration from ConfigurationManager instead.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$BackupPath,
        [string]$Environment,
        [switch]$Force
    )
    
    Show-DeprecationWarning -FunctionName "Restore-Configuration" -NewFunction "Restore-Configuration"
    
    if ($script:ConfigManagerLoaded) {
        if (Get-Command Restore-Configuration -ErrorAction SilentlyContinue) {
            return Restore-Configuration @PSBoundParameters
        }
    }
    
    throw "ConfigurationManager module not available. Please ensure the module is installed."
}

function Compare-Configuration {
    <#
    .SYNOPSIS
        [DEPRECATED] Compare configurations
    .DESCRIPTION
        This function is deprecated. Use Compare-Configuration from ConfigurationManager instead.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Configuration1,
        [Parameter(Mandatory)]
        [hashtable]$Configuration2,
        [switch]$IgnoreOrder,
        [switch]$Detailed
    )
    
    Show-DeprecationWarning -FunctionName "Compare-Configuration" -NewFunction "Compare-Configuration"
    
    if ($script:ConfigManagerLoaded) {
        if (Get-Command Compare-Configuration -ErrorAction SilentlyContinue) {
            return Compare-Configuration @PSBoundParameters
        }
    }
    
    throw "ConfigurationManager module not available. Please ensure the module is installed."
}

# Module initialization message
Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Yellow
Write-Host "║                    DEPRECATION NOTICE                       ║" -ForegroundColor Yellow
Write-Host "╠══════════════════════════════════════════════════════════════╣" -ForegroundColor Yellow
Write-Host "║ ConfigurationCore module has been DEPRECATED                ║" -ForegroundColor Red
Write-Host "║ This compatibility shim forwards calls to ConfigurationManager║" -ForegroundColor Yellow
Write-Host "║                                                              ║" -ForegroundColor Yellow
Write-Host "║ Migration required:                                          ║" -ForegroundColor Cyan
Write-Host "║   Old: Import-Module ConfigurationCore                       ║" -ForegroundColor Gray
Write-Host "║   New: Import-Module ConfigurationManager                    ║" -ForegroundColor Green
Write-Host "║                                                              ║" -ForegroundColor Yellow
Write-Host "║ Migration Guide:                                             ║" -ForegroundColor Cyan
Write-Host "║ https://github.com/AitherLabs/AitherZero/docs/migration/     ║" -ForegroundColor Blue
Write-Host "║   configuration-core.md                                     ║" -ForegroundColor Blue
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Yellow
Write-Host ""

# Export all functions for backward compatibility
Export-ModuleMember -Function @(
    'Initialize-ConfigurationCore',
    'Get-ModuleConfiguration',
    'Set-ModuleConfiguration',
    'Test-ModuleConfiguration',
    'Register-ModuleConfiguration',
    'Get-ConfigurationStore',
    'Set-ConfigurationStore',
    'Export-ConfigurationStore',
    'Import-ConfigurationStore',
    'Get-ConfigurationEnvironment',
    'Set-ConfigurationEnvironment',
    'New-ConfigurationEnvironment',
    'Remove-ConfigurationEnvironment',
    'Register-ConfigurationSchema',
    'Validate-Configuration',
    'Get-ConfigurationSchema',
    'Enable-ConfigurationHotReload',
    'Disable-ConfigurationHotReload',
    'Get-ConfigurationWatcher',
    'Publish-ConfigurationEvent',
    'Subscribe-ConfigurationEvent',
    'Unsubscribe-ConfigurationEvent',
    'Get-ConfigurationEventHistory',
    'Backup-Configuration',
    'Restore-Configuration',
    'Compare-Configuration'
)
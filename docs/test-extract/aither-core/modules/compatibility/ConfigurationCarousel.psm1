# ConfigurationCarousel Backward Compatibility Shim
# This module provides backward compatibility for the deprecated ConfigurationCarousel module
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
        Write-Warning "[DEPRECATED] ConfigurationCarousel module is deprecated. Functions are forwarded to ConfigurationManager. Please update your scripts to use 'Import-Module ConfigurationManager' instead."
    } catch {
        Write-Error "Failed to load ConfigurationManager module: $_"
    }
} else {
    # Fallback to original module if new one doesn't exist yet
    $originalModulePath = Join-Path $projectRoot "aither-core/modules/ConfigurationCarousel"
    if (Test-Path $originalModulePath) {
        try {
            Import-Module $originalModulePath -Force -ErrorAction Stop
            $script:ConfigManagerLoaded = $true
            Write-Warning "[COMPATIBILITY] Using legacy ConfigurationCarousel module. Please migrate to ConfigurationManager when available."
        } catch {
            Write-Error "Failed to load legacy ConfigurationCarousel module: $_"
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
    Write-Host "Migration Guide: https://github.com/AitherLabs/AitherZero/docs/migration/configuration-carousel.md" -ForegroundColor Yellow
}

function Switch-ConfigurationSet {
    <#
    .SYNOPSIS
        [DEPRECATED] Switches to a different configuration set
    .DESCRIPTION
        This function is deprecated. Use Switch-ConfigurationSet from ConfigurationManager instead.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ConfigurationName,
        [string]$Environment,
        [switch]$BackupCurrent,
        [switch]$Force
    )
    
    Show-DeprecationWarning -FunctionName "Switch-ConfigurationSet" -NewFunction "Switch-ConfigurationSet"
    
    if ($script:ConfigManagerLoaded) {
        if (Get-Command Switch-ConfigurationSet -ErrorAction SilentlyContinue) {
            return Switch-ConfigurationSet @PSBoundParameters
        }
    }
    
    throw "ConfigurationManager module not available. Please ensure the module is installed."
}

function Get-AvailableConfigurations {
    <#
    .SYNOPSIS
        [DEPRECATED] Lists all available configuration sets
    .DESCRIPTION
        This function is deprecated. Use Get-AvailableConfigurations from ConfigurationManager instead.
    #>
    [CmdletBinding()]
    param(
        [switch]$IncludeDetails
    )
    
    Show-DeprecationWarning -FunctionName "Get-AvailableConfigurations" -NewFunction "Get-AvailableConfigurations"
    
    if ($script:ConfigManagerLoaded) {
        if (Get-Command Get-AvailableConfigurations -ErrorAction SilentlyContinue) {
            return Get-AvailableConfigurations @PSBoundParameters
        }
    }
    
    throw "ConfigurationManager module not available. Please ensure the module is installed."
}

function Add-ConfigurationRepository {
    <#
    .SYNOPSIS
        [DEPRECATED] Adds a new configuration repository to the carousel
    .DESCRIPTION
        This function is deprecated. Use Add-ConfigurationRepository from ConfigurationManager instead.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,
        [Parameter(Mandatory)]
        [string]$Source,
        [string]$Description,
        [string[]]$Environments = @('dev', 'staging', 'prod'),
        [ValidateSet('git', 'local', 'template')]
        [string]$SourceType = 'auto',
        [string]$Branch = 'main',
        [switch]$SetAsCurrent
    )
    
    Show-DeprecationWarning -FunctionName "Add-ConfigurationRepository" -NewFunction "Add-ConfigurationRepository"
    
    if ($script:ConfigManagerLoaded) {
        if (Get-Command Add-ConfigurationRepository -ErrorAction SilentlyContinue) {
            return Add-ConfigurationRepository @PSBoundParameters
        }
    }
    
    throw "ConfigurationManager module not available. Please ensure the module is installed."
}

function Remove-ConfigurationRepository {
    <#
    .SYNOPSIS
        [DEPRECATED] Removes a configuration repository from the carousel
    .DESCRIPTION
        This function is deprecated. Use Remove-ConfigurationRepository from ConfigurationManager instead.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,
        [switch]$DeleteFiles,
        [switch]$Force
    )
    
    Show-DeprecationWarning -FunctionName "Remove-ConfigurationRepository" -NewFunction "Remove-ConfigurationRepository"
    
    if ($script:ConfigManagerLoaded) {
        if (Get-Command Remove-ConfigurationRepository -ErrorAction SilentlyContinue) {
            return Remove-ConfigurationRepository @PSBoundParameters
        }
    }
    
    throw "ConfigurationManager module not available. Please ensure the module is installed."
}

function Sync-ConfigurationRepository {
    <#
    .SYNOPSIS
        [DEPRECATED] Synchronizes a configuration repository with its remote source
    .DESCRIPTION
        This function is deprecated. Use Sync-ConfigurationRepository from ConfigurationManager instead.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ConfigurationName,
        [ValidateSet('pull', 'push', 'sync')]
        [string]$Operation = 'pull',
        [switch]$Force,
        [switch]$BackupCurrent = $true
    )
    
    Show-DeprecationWarning -FunctionName "Sync-ConfigurationRepository" -NewFunction "Sync-ConfigurationRepository"
    
    if ($script:ConfigManagerLoaded) {
        if (Get-Command Sync-ConfigurationRepository -ErrorAction SilentlyContinue) {
            return Sync-ConfigurationRepository @PSBoundParameters
        }
    }
    
    throw "ConfigurationManager module not available. Please ensure the module is installed."
}

function Get-CurrentConfiguration {
    <#
    .SYNOPSIS
        [DEPRECATED] Gets information about the currently active configuration
    .DESCRIPTION
        This function is deprecated. Use Get-CurrentConfiguration from ConfigurationManager instead.
    #>
    [CmdletBinding()]
    param()
    
    Show-DeprecationWarning -FunctionName "Get-CurrentConfiguration" -NewFunction "Get-CurrentConfiguration"
    
    if ($script:ConfigManagerLoaded) {
        if (Get-Command Get-CurrentConfiguration -ErrorAction SilentlyContinue) {
            return Get-CurrentConfiguration @PSBoundParameters
        }
    }
    
    throw "ConfigurationManager module not available. Please ensure the module is installed."
}

function Backup-CurrentConfiguration {
    <#
    .SYNOPSIS
        [DEPRECATED] Creates a backup of the current configuration
    .DESCRIPTION
        This function is deprecated. Use Backup-CurrentConfiguration from ConfigurationManager instead.
    #>
    [CmdletBinding()]
    param(
        [string]$Reason = "Manual backup",
        [string]$BackupName
    )
    
    Show-DeprecationWarning -FunctionName "Backup-CurrentConfiguration" -NewFunction "Backup-CurrentConfiguration"
    
    if ($script:ConfigManagerLoaded) {
        if (Get-Command Backup-CurrentConfiguration -ErrorAction SilentlyContinue) {
            return Backup-CurrentConfiguration @PSBoundParameters
        }
    }
    
    throw "ConfigurationManager module not available. Please ensure the module is installed."
}

function Restore-ConfigurationBackup {
    <#
    .SYNOPSIS
        [DEPRECATED] Restores a configuration from backup
    .DESCRIPTION
        This function is deprecated. Use Restore-ConfigurationBackup from ConfigurationManager instead.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$BackupName,
        [switch]$Force
    )
    
    Show-DeprecationWarning -FunctionName "Restore-ConfigurationBackup" -NewFunction "Restore-ConfigurationBackup"
    
    if ($script:ConfigManagerLoaded) {
        if (Get-Command Restore-ConfigurationBackup -ErrorAction SilentlyContinue) {
            return Restore-ConfigurationBackup @PSBoundParameters
        }
    }
    
    throw "ConfigurationManager module not available. Please ensure the module is installed."
}

function Validate-ConfigurationSet {
    <#
    .SYNOPSIS
        [DEPRECATED] Validates a configuration set for completeness and correctness
    .DESCRIPTION
        This function is deprecated. Use Validate-ConfigurationSet from ConfigurationManager instead.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ConfigurationName,
        [string]$Environment = 'dev'
    )
    
    Show-DeprecationWarning -FunctionName "Validate-ConfigurationSet" -NewFunction "Validate-ConfigurationSet"
    
    if ($script:ConfigManagerLoaded) {
        if (Get-Command Validate-ConfigurationSet -ErrorAction SilentlyContinue) {
            return Validate-ConfigurationSet @PSBoundParameters
        }
    }
    
    throw "ConfigurationManager module not available. Please ensure the module is installed."
}

function Export-ConfigurationSet {
    <#
    .SYNOPSIS
        [DEPRECATED] Exports a configuration set to a file
    .DESCRIPTION
        This function is deprecated. Use Export-ConfigurationSet from ConfigurationManager instead.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ConfigurationName,
        [Parameter(Mandatory)]
        [string]$Path,
        [ValidateSet('JSON', 'YAML', 'XML')]
        [string]$Format = 'JSON',
        [switch]$IncludeEnvironments
    )
    
    Show-DeprecationWarning -FunctionName "Export-ConfigurationSet" -NewFunction "Export-ConfigurationSet"
    
    if ($script:ConfigManagerLoaded) {
        if (Get-Command Export-ConfigurationSet -ErrorAction SilentlyContinue) {
            return Export-ConfigurationSet @PSBoundParameters
        }
    }
    
    throw "ConfigurationManager module not available. Please ensure the module is installed."
}

function Import-ConfigurationSet {
    <#
    .SYNOPSIS
        [DEPRECATED] Imports a configuration set from a file
    .DESCRIPTION
        This function is deprecated. Use Import-ConfigurationSet from ConfigurationManager instead.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        [string]$ConfigurationName,
        [switch]$Overwrite,
        [switch]$SetAsCurrent
    )
    
    Show-DeprecationWarning -FunctionName "Import-ConfigurationSet" -NewFunction "Import-ConfigurationSet"
    
    if ($script:ConfigManagerLoaded) {
        if (Get-Command Import-ConfigurationSet -ErrorAction SilentlyContinue) {
            return Import-ConfigurationSet @PSBoundParameters
        }
    }
    
    throw "ConfigurationManager module not available. Please ensure the module is installed."
}

function New-ConfigurationEnvironment {
    <#
    .SYNOPSIS
        [DEPRECATED] Creates a new configuration environment
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

function Set-ConfigurationEnvironment {
    <#
    .SYNOPSIS
        [DEPRECATED] Sets the active configuration environment
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

# Module initialization message
Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Yellow
Write-Host "║                    DEPRECATION NOTICE                       ║" -ForegroundColor Yellow
Write-Host "╠══════════════════════════════════════════════════════════════╣" -ForegroundColor Yellow
Write-Host "║ ConfigurationCarousel module has been DEPRECATED            ║" -ForegroundColor Red
Write-Host "║ This compatibility shim forwards calls to ConfigurationManager║" -ForegroundColor Yellow
Write-Host "║                                                              ║" -ForegroundColor Yellow
Write-Host "║ Migration required:                                          ║" -ForegroundColor Cyan
Write-Host "║   Old: Import-Module ConfigurationCarousel                   ║" -ForegroundColor Gray
Write-Host "║   New: Import-Module ConfigurationManager                    ║" -ForegroundColor Green
Write-Host "║                                                              ║" -ForegroundColor Yellow
Write-Host "║ Migration Guide:                                             ║" -ForegroundColor Cyan
Write-Host "║ https://github.com/AitherLabs/AitherZero/docs/migration/     ║" -ForegroundColor Blue
Write-Host "║   configuration-carousel.md                                 ║" -ForegroundColor Blue
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Yellow
Write-Host ""

# Export all functions for backward compatibility
Export-ModuleMember -Function @(
    'Switch-ConfigurationSet',
    'Get-AvailableConfigurations',
    'Add-ConfigurationRepository',
    'Remove-ConfigurationRepository',
    'Sync-ConfigurationRepository',
    'Get-CurrentConfiguration',
    'Backup-CurrentConfiguration',
    'Restore-ConfigurationBackup',
    'Validate-ConfigurationSet',
    'Export-ConfigurationSet',
    'Import-ConfigurationSet',
    'New-ConfigurationEnvironment',
    'Set-ConfigurationEnvironment'
)
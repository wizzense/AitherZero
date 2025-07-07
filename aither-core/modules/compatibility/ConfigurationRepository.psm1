# ConfigurationRepository Backward Compatibility Shim
# This module provides backward compatibility for the deprecated ConfigurationRepository module
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
        Write-Warning "[DEPRECATED] ConfigurationRepository module is deprecated. Functions are forwarded to ConfigurationManager. Please update your scripts to use 'Import-Module ConfigurationManager' instead."
    } catch {
        Write-Error "Failed to load ConfigurationManager module: $_"
    }
} else {
    # Fallback to original module if new one doesn't exist yet
    $originalModulePath = Join-Path $projectRoot "aither-core/modules/ConfigurationRepository"
    if (Test-Path $originalModulePath) {
        try {
            Import-Module $originalModulePath -Force -ErrorAction Stop
            $script:ConfigManagerLoaded = $true
            Write-Warning "[COMPATIBILITY] Using legacy ConfigurationRepository module. Please migrate to ConfigurationManager when available."
        } catch {
            Write-Error "Failed to load legacy ConfigurationRepository module: $_"
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
    Write-Host "Migration Guide: https://github.com/AitherLabs/AitherZero/docs/migration/configuration-repository.md" -ForegroundColor Yellow
}

function New-ConfigurationRepository {
    <#
    .SYNOPSIS
        [DEPRECATED] Creates a new Git repository for custom configurations
    .DESCRIPTION
        This function is deprecated. Use New-ConfigurationRepository from ConfigurationManager instead.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$RepositoryName,
        [Parameter(Mandatory)]
        [string]$LocalPath,
        [ValidateSet('github', 'gitlab', 'local')]
        [string]$Provider = 'github',
        [ValidateSet('default', 'minimal', 'enterprise', 'custom')]
        [string]$Template = 'default',
        [switch]$Private = $true,
        [string]$Description,
        [string]$GitHubOrg,
        [string[]]$Environments = @('dev', 'staging', 'prod'),
        [hashtable]$CustomSettings = @{}
    )
    
    Show-DeprecationWarning -FunctionName "New-ConfigurationRepository" -NewFunction "New-ConfigurationRepository"
    
    if ($script:ConfigManagerLoaded) {
        if (Get-Command New-ConfigurationRepository -ErrorAction SilentlyContinue) {
            return New-ConfigurationRepository @PSBoundParameters
        }
    }
    
    throw "ConfigurationManager module not available. Please ensure the module is installed."
}

function Clone-ConfigurationRepository {
    <#
    .SYNOPSIS
        [DEPRECATED] Clones an existing configuration repository
    .DESCRIPTION
        This function is deprecated. Use Clone-ConfigurationRepository from ConfigurationManager instead.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$RepositoryUrl,
        [Parameter(Mandatory)]
        [string]$LocalPath,
        [string]$Branch = 'main',
        [switch]$Validate = $true,
        [switch]$SetupLocalSettings
    )
    
    Show-DeprecationWarning -FunctionName "Clone-ConfigurationRepository" -NewFunction "Clone-ConfigurationRepository"
    
    if ($script:ConfigManagerLoaded) {
        if (Get-Command Clone-ConfigurationRepository -ErrorAction SilentlyContinue) {
            return Clone-ConfigurationRepository @PSBoundParameters
        }
    }
    
    throw "ConfigurationManager module not available. Please ensure the module is installed."
}

function Sync-ConfigurationRepository {
    <#
    .SYNOPSIS
        [DEPRECATED] Synchronizes a configuration repository with its remote
    .DESCRIPTION
        This function is deprecated. Use Sync-ConfigurationRepository from ConfigurationManager instead.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        [ValidateSet('pull', 'push', 'sync')]
        [string]$Operation = 'sync',
        [string]$Branch = 'main',
        [switch]$Force,
        [switch]$CreateBackup = $true
    )
    
    Show-DeprecationWarning -FunctionName "Sync-ConfigurationRepository" -NewFunction "Sync-ConfigurationRepository"
    
    if ($script:ConfigManagerLoaded) {
        if (Get-Command Sync-ConfigurationRepository -ErrorAction SilentlyContinue) {
            return Sync-ConfigurationRepository @PSBoundParameters
        }
    }
    
    throw "ConfigurationManager module not available. Please ensure the module is installed."
}

function Validate-ConfigurationRepository {
    <#
    .SYNOPSIS
        [DEPRECATED] Validates the structure and content of a configuration repository
    .DESCRIPTION
        This function is deprecated. Use Validate-ConfigurationRepository from ConfigurationManager instead.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )
    
    Show-DeprecationWarning -FunctionName "Validate-ConfigurationRepository" -NewFunction "Validate-ConfigurationRepository"
    
    if ($script:ConfigManagerLoaded) {
        if (Get-Command Validate-ConfigurationRepository -ErrorAction SilentlyContinue) {
            return Validate-ConfigurationRepository @PSBoundParameters
        }
    }
    
    throw "ConfigurationManager module not available. Please ensure the module is installed."
}

# Module initialization message
Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Yellow
Write-Host "║                    DEPRECATION NOTICE                       ║" -ForegroundColor Yellow
Write-Host "╠══════════════════════════════════════════════════════════════╣" -ForegroundColor Yellow
Write-Host "║ ConfigurationRepository module has been DEPRECATED          ║" -ForegroundColor Red
Write-Host "║ This compatibility shim forwards calls to ConfigurationManager║" -ForegroundColor Yellow
Write-Host "║                                                              ║" -ForegroundColor Yellow
Write-Host "║ Migration required:                                          ║" -ForegroundColor Cyan
Write-Host "║   Old: Import-Module ConfigurationRepository                 ║" -ForegroundColor Gray
Write-Host "║   New: Import-Module ConfigurationManager                    ║" -ForegroundColor Green
Write-Host "║                                                              ║" -ForegroundColor Yellow
Write-Host "║ Migration Guide:                                             ║" -ForegroundColor Cyan
Write-Host "║ https://github.com/AitherLabs/AitherZero/docs/migration/     ║" -ForegroundColor Blue
Write-Host "║   configuration-repository.md                               ║" -ForegroundColor Blue
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Yellow
Write-Host ""

# Export all functions for backward compatibility
Export-ModuleMember -Function @(
    'New-ConfigurationRepository',
    'Clone-ConfigurationRepository',
    'Sync-ConfigurationRepository',
    'Validate-ConfigurationRepository'
)
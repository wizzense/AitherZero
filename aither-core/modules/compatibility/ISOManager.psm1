# ISOManager Backward Compatibility Shim
# This module provides backward compatibility for the deprecated ISOManager module
# All functionality has been moved to the new unified ISOManagement module

# Find the new ISOManagement module
. "$PSScriptRoot/../../shared/Find-ProjectRoot.ps1"
$projectRoot = Find-ProjectRoot
$isoManagementPath = Join-Path $projectRoot "aither-core/modules/ISOManagement"

# Import the new unified module if available
$script:ISOManagementLoaded = $false
if (Test-Path $isoManagementPath) {
    try {
        Import-Module $isoManagementPath -Force -ErrorAction Stop
        $script:ISOManagementLoaded = $true
        Write-Warning "[DEPRECATED] ISOManager module is deprecated. Functions are forwarded to ISOManagement. Please update your scripts to use 'Import-Module ISOManagement' instead."
    } catch {
        Write-Error "Failed to load ISOManagement module: $_"
    }
} else {
    # Fallback to original module if new one doesn't exist yet
    $originalModulePath = Join-Path $projectRoot "aither-core/modules/ISOManager"
    if (Test-Path $originalModulePath) {
        try {
            Import-Module $originalModulePath -Force -ErrorAction Stop
            $script:ISOManagementLoaded = $true
            Write-Warning "[COMPATIBILITY] Using legacy ISOManager module. Please migrate to ISOManagement when available."
        } catch {
            Write-Error "Failed to load legacy ISOManager module: $_"
        }
    }
}

# Deprecation warning function
function Show-DeprecationWarning {
    param(
        [string]$FunctionName,
        [string]$NewFunction = $null,
        [string]$NewModule = "ISOManagement"
    )
    
    $migrationMessage = if ($NewFunction) {
        "Use '$NewFunction' from the '$NewModule' module instead."
    } else {
        "Use the equivalent function from the '$NewModule' module instead."
    }
    
    Write-Warning "[DEPRECATED] $FunctionName is deprecated and will be removed in a future version. $migrationMessage"
    Write-Host "Migration Guide: https://github.com/AitherLabs/AitherZero/docs/migration/iso-manager.md" -ForegroundColor Yellow
}

function Get-ISODownload {
    <#
    .SYNOPSIS
        [DEPRECATED] Download ISO files
    .DESCRIPTION
        This function is deprecated. Use Get-ISODownload from ISOManagement instead.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Url,
        [string]$Destination,
        [string]$FileName,
        [switch]$Force,
        [switch]$Verify,
        [string]$ExpectedHash,
        [ValidateSet('MD5', 'SHA1', 'SHA256', 'SHA512')]
        [string]$HashAlgorithm = 'SHA256'
    )
    
    Show-DeprecationWarning -FunctionName "Get-ISODownload" -NewFunction "Get-ISODownload"
    
    if ($script:ISOManagementLoaded) {
        if (Get-Command Get-ISODownload -ErrorAction SilentlyContinue) {
            return Get-ISODownload @PSBoundParameters
        }
    }
    
    throw "ISOManagement module not available. Please ensure the module is installed."
}

function Get-ISOInventory {
    <#
    .SYNOPSIS
        [DEPRECATED] Get ISO file inventory
    .DESCRIPTION
        This function is deprecated. Use Get-ISOInventory from ISOManagement instead.
    #>
    [CmdletBinding()]
    param(
        [string]$Path,
        [switch]$Detailed,
        [switch]$IncludeHashes,
        [string]$Filter
    )
    
    Show-DeprecationWarning -FunctionName "Get-ISOInventory" -NewFunction "Get-ISOInventory"
    
    if ($script:ISOManagementLoaded) {
        if (Get-Command Get-ISOInventory -ErrorAction SilentlyContinue) {
            return Get-ISOInventory @PSBoundParameters
        }
    }
    
    throw "ISOManagement module not available. Please ensure the module is installed."
}

function Get-ISOMetadata {
    <#
    .SYNOPSIS
        [DEPRECATED] Get ISO file metadata
    .DESCRIPTION
        This function is deprecated. Use Get-ISOMetadata from ISOManagement instead.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )
    
    Show-DeprecationWarning -FunctionName "Get-ISOMetadata" -NewFunction "Get-ISOMetadata"
    
    if ($script:ISOManagementLoaded) {
        if (Get-Command Get-ISOMetadata -ErrorAction SilentlyContinue) {
            return Get-ISOMetadata @PSBoundParameters
        }
    }
    
    throw "ISOManagement module not available. Please ensure the module is installed."
}

function Test-ISOIntegrity {
    <#
    .SYNOPSIS
        [DEPRECATED] Test ISO file integrity
    .DESCRIPTION
        This function is deprecated. Use Test-ISOIntegrity from ISOManagement instead.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        [string]$ExpectedHash,
        [ValidateSet('MD5', 'SHA1', 'SHA256', 'SHA512')]
        [string]$HashAlgorithm = 'SHA256'
    )
    
    Show-DeprecationWarning -FunctionName "Test-ISOIntegrity" -NewFunction "Test-ISOIntegrity"
    
    if ($script:ISOManagementLoaded) {
        if (Get-Command Test-ISOIntegrity -ErrorAction SilentlyContinue) {
            return Test-ISOIntegrity @PSBoundParameters
        }
    }
    
    throw "ISOManagement module not available. Please ensure the module is installed."
}

function New-ISORepository {
    <#
    .SYNOPSIS
        [DEPRECATED] Create a new ISO repository
    .DESCRIPTION
        This function is deprecated. Use New-ISORepository from ISOManagement instead.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        [string]$Name,
        [string]$Description,
        [hashtable]$Configuration = @{}
    )
    
    Show-DeprecationWarning -FunctionName "New-ISORepository" -NewFunction "New-ISORepository"
    
    if ($script:ISOManagementLoaded) {
        if (Get-Command New-ISORepository -ErrorAction SilentlyContinue) {
            return New-ISORepository @PSBoundParameters
        }
    }
    
    throw "ISOManagement module not available. Please ensure the module is installed."
}

function Remove-ISOFile {
    <#
    .SYNOPSIS
        [DEPRECATED] Remove ISO files
    .DESCRIPTION
        This function is deprecated. Use Remove-ISOFile from ISOManagement instead.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        [switch]$Force,
        [switch]$Backup
    )
    
    Show-DeprecationWarning -FunctionName "Remove-ISOFile" -NewFunction "Remove-ISOFile"
    
    if ($script:ISOManagementLoaded) {
        if (Get-Command Remove-ISOFile -ErrorAction SilentlyContinue) {
            return Remove-ISOFile @PSBoundParameters
        }
    }
    
    throw "ISOManagement module not available. Please ensure the module is installed."
}

function Export-ISOInventory {
    <#
    .SYNOPSIS
        [DEPRECATED] Export ISO inventory
    .DESCRIPTION
        This function is deprecated. Use Export-ISOInventory from ISOManagement instead.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        [string]$Repository,
        [ValidateSet('JSON', 'CSV', 'XML')]
        [string]$Format = 'JSON'
    )
    
    Show-DeprecationWarning -FunctionName "Export-ISOInventory" -NewFunction "Export-ISOInventory"
    
    if ($script:ISOManagementLoaded) {
        if (Get-Command Export-ISOInventory -ErrorAction SilentlyContinue) {
            return Export-ISOInventory @PSBoundParameters
        }
    }
    
    throw "ISOManagement module not available. Please ensure the module is installed."
}

function Import-ISOInventory {
    <#
    .SYNOPSIS
        [DEPRECATED] Import ISO inventory
    .DESCRIPTION
        This function is deprecated. Use Import-ISOInventory from ISOManagement instead.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        [string]$Repository,
        [switch]$Merge
    )
    
    Show-DeprecationWarning -FunctionName "Import-ISOInventory" -NewFunction "Import-ISOInventory"
    
    if ($script:ISOManagementLoaded) {
        if (Get-Command Import-ISOInventory -ErrorAction SilentlyContinue) {
            return Import-ISOInventory @PSBoundParameters
        }
    }
    
    throw "ISOManagement module not available. Please ensure the module is installed."
}

function Sync-ISORepository {
    <#
    .SYNOPSIS
        [DEPRECATED] Synchronize ISO repository
    .DESCRIPTION
        This function is deprecated. Use Sync-ISORepository from ISOManagement instead.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Repository,
        [string]$RemoteUrl,
        [switch]$Force
    )
    
    Show-DeprecationWarning -FunctionName "Sync-ISORepository" -NewFunction "Sync-ISORepository"
    
    if ($script:ISOManagementLoaded) {
        if (Get-Command Sync-ISORepository -ErrorAction SilentlyContinue) {
            return Sync-ISORepository @PSBoundParameters
        }
    }
    
    throw "ISOManagement module not available. Please ensure the module is installed."
}

function Optimize-ISOStorage {
    <#
    .SYNOPSIS
        [DEPRECATED] Optimize ISO storage
    .DESCRIPTION
        This function is deprecated. Use Optimize-ISOStorage from ISOManagement instead.
    #>
    [CmdletBinding()]
    param(
        [string]$Repository,
        [switch]$RemoveDuplicates,
        [switch]$Compress,
        [switch]$WhatIf
    )
    
    Show-DeprecationWarning -FunctionName "Optimize-ISOStorage" -NewFunction "Optimize-ISOStorage"
    
    if ($script:ISOManagementLoaded) {
        if (Get-Command Optimize-ISOStorage -ErrorAction SilentlyContinue) {
            return Optimize-ISOStorage @PSBoundParameters
        }
    }
    
    throw "ISOManagement module not available. Please ensure the module is installed."
}

# Module initialization message
Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Yellow
Write-Host "║                    DEPRECATION NOTICE                       ║" -ForegroundColor Yellow
Write-Host "╠══════════════════════════════════════════════════════════════╣" -ForegroundColor Yellow
Write-Host "║ ISOManager module has been DEPRECATED                       ║" -ForegroundColor Red
Write-Host "║ This compatibility shim forwards calls to ISOManagement     ║" -ForegroundColor Yellow
Write-Host "║                                                              ║" -ForegroundColor Yellow
Write-Host "║ Migration required:                                          ║" -ForegroundColor Cyan
Write-Host "║   Old: Import-Module ISOManager                              ║" -ForegroundColor Gray
Write-Host "║   New: Import-Module ISOManagement                           ║" -ForegroundColor Green
Write-Host "║                                                              ║" -ForegroundColor Yellow
Write-Host "║ Migration Guide:                                             ║" -ForegroundColor Cyan
Write-Host "║ https://github.com/AitherLabs/AitherZero/docs/migration/     ║" -ForegroundColor Blue
Write-Host "║   iso-manager.md                                            ║" -ForegroundColor Blue
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Yellow
Write-Host ""

# Export all functions for backward compatibility
Export-ModuleMember -Function @(
    'Get-ISODownload',
    'Get-ISOInventory',
    'Get-ISOMetadata',
    'Test-ISOIntegrity',
    'New-ISORepository',
    'Remove-ISOFile',
    'Export-ISOInventory',
    'Import-ISOInventory',
    'Sync-ISORepository',
    'Optimize-ISOStorage'
)
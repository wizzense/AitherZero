# ProgressTracking Backward Compatibility Shim
# This module provides backward compatibility for the deprecated ProgressTracking module
# All functionality has been moved to the new unified UtilityServices module

# Find the new UtilityServices module
. "$PSScriptRoot/../../shared/Find-ProjectRoot.ps1"
$projectRoot = Find-ProjectRoot
$utilityManagerPath = Join-Path $projectRoot "aither-core/modules/UtilityServices"

# Import the new unified module if available
$script:UtilityServicesLoaded = $false
if (Test-Path $utilityManagerPath) {
    try {
        Import-Module $utilityManagerPath -Force -ErrorAction Stop
        $script:UtilityServicesLoaded = $true
        Write-Warning "[DEPRECATED] ProgressTracking module is deprecated. Functions are forwarded to UtilityServices. Please update your scripts to use 'Import-Module UtilityServices' instead."
    } catch {
        Write-Error "Failed to load UtilityServices module: $_"
    }
} else {
    # Fallback to original module if new one doesn't exist yet
    $originalModulePath = Join-Path $projectRoot "aither-core/modules/ProgressTracking"
    if (Test-Path $originalModulePath) {
        try {
            Import-Module $originalModulePath -Force -ErrorAction Stop
            $script:UtilityServicesLoaded = $true
            Write-Warning "[COMPATIBILITY] Using legacy ProgressTracking module. Please migrate to UtilityServices when available."
        } catch {
            Write-Error "Failed to load legacy ProgressTracking module: $_"
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
    Write-Host "Migration Guide: https://github.com/AitherLabs/AitherZero/docs/migration/progress-tracking.md" -ForegroundColor Yellow
}

function Start-ProgressOperation {
    <#
    .SYNOPSIS
        [DEPRECATED] Start a progress operation
    .DESCRIPTION
        This function is deprecated. Use Start-ProgressOperation from UtilityServices instead.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$OperationName,
        [int]$TotalSteps = 100,
        [string]$Activity,
        [switch]$ShowTime,
        [switch]$ShowETA
    )
    
    Show-DeprecationWarning -FunctionName "Start-ProgressOperation" -NewFunction "Start-ProgressOperation"
    
    if ($script:UtilityServicesLoaded) {
        if (Get-Command Start-ProgressOperation -ErrorAction SilentlyContinue) {
            return Start-ProgressOperation @PSBoundParameters
        }
    }
    
    throw "UtilityServices module not available. Please ensure the module is installed."
}

function Update-ProgressOperation {
    <#
    .SYNOPSIS
        [DEPRECATED] Update progress operation
    .DESCRIPTION
        This function is deprecated. Use Update-ProgressOperation from UtilityServices instead.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$OperationId,
        [int]$CurrentStep,
        [string]$StepName,
        [switch]$IncrementStep
    )
    
    Show-DeprecationWarning -FunctionName "Update-ProgressOperation" -NewFunction "Update-ProgressOperation"
    
    if ($script:UtilityServicesLoaded) {
        if (Get-Command Update-ProgressOperation -ErrorAction SilentlyContinue) {
            return Update-ProgressOperation @PSBoundParameters
        }
    }
    
    throw "UtilityServices module not available. Please ensure the module is installed."
}

function Complete-ProgressOperation {
    <#
    .SYNOPSIS
        [DEPRECATED] Complete progress operation
    .DESCRIPTION
        This function is deprecated. Use Complete-ProgressOperation from UtilityServices instead.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$OperationId,
        [string]$Message,
        [switch]$ShowSummary
    )
    
    Show-DeprecationWarning -FunctionName "Complete-ProgressOperation" -NewFunction "Complete-ProgressOperation"
    
    if ($script:UtilityServicesLoaded) {
        if (Get-Command Complete-ProgressOperation -ErrorAction SilentlyContinue) {
            return Complete-ProgressOperation @PSBoundParameters
        }
    }
    
    throw "UtilityServices module not available. Please ensure the module is installed."
}

function Get-ProgressStatus {
    <#
    .SYNOPSIS
        [DEPRECATED] Get progress status
    .DESCRIPTION
        This function is deprecated. Use Get-ProgressStatus from UtilityServices instead.
    #>
    [CmdletBinding()]
    param(
        [string]$OperationId
    )
    
    Show-DeprecationWarning -FunctionName "Get-ProgressStatus" -NewFunction "Get-ProgressStatus"
    
    if ($script:UtilityServicesLoaded) {
        if (Get-Command Get-ProgressStatus -ErrorAction SilentlyContinue) {
            return Get-ProgressStatus @PSBoundParameters
        }
    }
    
    throw "UtilityServices module not available. Please ensure the module is installed."
}

function Stop-ProgressOperation {
    <#
    .SYNOPSIS
        [DEPRECATED] Stop progress operation
    .DESCRIPTION
        This function is deprecated. Use Stop-ProgressOperation from UtilityServices instead.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$OperationId,
        [string]$Reason
    )
    
    Show-DeprecationWarning -FunctionName "Stop-ProgressOperation" -NewFunction "Stop-ProgressOperation"
    
    if ($script:UtilityServicesLoaded) {
        if (Get-Command Stop-ProgressOperation -ErrorAction SilentlyContinue) {
            return Stop-ProgressOperation @PSBoundParameters
        }
    }
    
    throw "UtilityServices module not available. Please ensure the module is installed."
}

function Add-ProgressWarning {
    <#
    .SYNOPSIS
        [DEPRECATED] Add progress warning
    .DESCRIPTION
        This function is deprecated. Use Add-ProgressWarning from UtilityServices instead.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$OperationId,
        [Parameter(Mandatory)]
        [string]$Message
    )
    
    Show-DeprecationWarning -FunctionName "Add-ProgressWarning" -NewFunction "Add-ProgressWarning"
    
    if ($script:UtilityServicesLoaded) {
        if (Get-Command Add-ProgressWarning -ErrorAction SilentlyContinue) {
            return Add-ProgressWarning @PSBoundParameters
        }
    }
    
    throw "UtilityServices module not available. Please ensure the module is installed."
}

function Add-ProgressError {
    <#
    .SYNOPSIS
        [DEPRECATED] Add progress error
    .DESCRIPTION
        This function is deprecated. Use Add-ProgressError from UtilityServices instead.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$OperationId,
        [Parameter(Mandatory)]
        [string]$Message,
        [string]$Exception
    )
    
    Show-DeprecationWarning -FunctionName "Add-ProgressError" -NewFunction "Add-ProgressError"
    
    if ($script:UtilityServicesLoaded) {
        if (Get-Command Add-ProgressError -ErrorAction SilentlyContinue) {
            return Add-ProgressError @PSBoundParameters
        }
    }
    
    throw "UtilityServices module not available. Please ensure the module is installed."
}

function Start-MultiProgress {
    <#
    .SYNOPSIS
        [DEPRECATED] Start multi-progress operation
    .DESCRIPTION
        This function is deprecated. Use Start-MultiProgress from UtilityServices instead.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Title,
        [Parameter(Mandatory)]
        [array]$Operations
    )
    
    Show-DeprecationWarning -FunctionName "Start-MultiProgress" -NewFunction "Start-MultiProgress"
    
    if ($script:UtilityServicesLoaded) {
        if (Get-Command Start-MultiProgress -ErrorAction SilentlyContinue) {
            return Start-MultiProgress @PSBoundParameters
        }
    }
    
    throw "UtilityServices module not available. Please ensure the module is installed."
}

function Update-MultiProgress {
    <#
    .SYNOPSIS
        [DEPRECATED] Update multi-progress operation
    .DESCRIPTION
        This function is deprecated. Use Update-MultiProgress from UtilityServices instead.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$MultiProgressId,
        [Parameter(Mandatory)]
        [string]$OperationName,
        [int]$CurrentStep
    )
    
    Show-DeprecationWarning -FunctionName "Update-MultiProgress" -NewFunction "Update-MultiProgress"
    
    if ($script:UtilityServicesLoaded) {
        if (Get-Command Update-MultiProgress -ErrorAction SilentlyContinue) {
            return Update-MultiProgress @PSBoundParameters
        }
    }
    
    throw "UtilityServices module not available. Please ensure the module is installed."
}

function Complete-MultiProgress {
    <#
    .SYNOPSIS
        [DEPRECATED] Complete multi-progress operation
    .DESCRIPTION
        This function is deprecated. Use Complete-MultiProgress from UtilityServices instead.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$MultiProgressId,
        [switch]$ShowSummary
    )
    
    Show-DeprecationWarning -FunctionName "Complete-MultiProgress" -NewFunction "Complete-MultiProgress"
    
    if ($script:UtilityServicesLoaded) {
        if (Get-Command Complete-MultiProgress -ErrorAction SilentlyContinue) {
            return Complete-MultiProgress @PSBoundParameters
        }
    }
    
    throw "UtilityServices module not available. Please ensure the module is installed."
}

function Show-ProgressSummary {
    <#
    .SYNOPSIS
        [DEPRECATED] Show progress summary
    .DESCRIPTION
        This function is deprecated. Use Show-ProgressSummary from UtilityServices instead.
    #>
    [CmdletBinding()]
    param(
        [string]$OperationId
    )
    
    Show-DeprecationWarning -FunctionName "Show-ProgressSummary" -NewFunction "Show-ProgressSummary"
    
    if ($script:UtilityServicesLoaded) {
        if (Get-Command Show-ProgressSummary -ErrorAction SilentlyContinue) {
            return Show-ProgressSummary @PSBoundParameters
        }
    }
    
    throw "UtilityServices module not available. Please ensure the module is installed."
}

function Get-ProgressHistory {
    <#
    .SYNOPSIS
        [DEPRECATED] Get progress history
    .DESCRIPTION
        This function is deprecated. Use Get-ProgressHistory from UtilityServices instead.
    #>
    [CmdletBinding()]
    param(
        [int]$Last = 10,
        [string]$OperationFilter
    )
    
    Show-DeprecationWarning -FunctionName "Get-ProgressHistory" -NewFunction "Get-ProgressHistory"
    
    if ($script:UtilityServicesLoaded) {
        if (Get-Command Get-ProgressHistory -ErrorAction SilentlyContinue) {
            return Get-ProgressHistory @PSBoundParameters
        }
    }
    
    throw "UtilityServices module not available. Please ensure the module is installed."
}

function Clear-ProgressHistory {
    <#
    .SYNOPSIS
        [DEPRECATED] Clear progress history
    .DESCRIPTION
        This function is deprecated. Use Clear-ProgressHistory from UtilityServices instead.
    #>
    [CmdletBinding()]
    param(
        [switch]$Force
    )
    
    Show-DeprecationWarning -FunctionName "Clear-ProgressHistory" -NewFunction "Clear-ProgressHistory"
    
    if ($script:UtilityServicesLoaded) {
        if (Get-Command Clear-ProgressHistory -ErrorAction SilentlyContinue) {
            return Clear-ProgressHistory @PSBoundParameters
        }
    }
    
    throw "UtilityServices module not available. Please ensure the module is installed."
}

function Export-ProgressReport {
    <#
    .SYNOPSIS
        [DEPRECATED] Export progress report
    .DESCRIPTION
        This function is deprecated. Use Export-ProgressReport from UtilityServices instead.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$OutputPath,
        [ValidateSet('JSON', 'CSV', 'HTML')]
        [string]$Format = 'JSON'
    )
    
    Show-DeprecationWarning -FunctionName "Export-ProgressReport" -NewFunction "Export-ProgressReport"
    
    if ($script:UtilityServicesLoaded) {
        if (Get-Command Export-ProgressReport -ErrorAction SilentlyContinue) {
            return Export-ProgressReport @PSBoundParameters
        }
    }
    
    throw "UtilityServices module not available. Please ensure the module is installed."
}

function Test-ProgressOperationActive {
    <#
    .SYNOPSIS
        [DEPRECATED] Test if progress operation is active
    .DESCRIPTION
        This function is deprecated. Use Test-ProgressOperationActive from UtilityServices instead.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$OperationId
    )
    
    Show-DeprecationWarning -FunctionName "Test-ProgressOperationActive" -NewFunction "Test-ProgressOperationActive"
    
    if ($script:UtilityServicesLoaded) {
        if (Get-Command Test-ProgressOperationActive -ErrorAction SilentlyContinue) {
            return Test-ProgressOperationActive @PSBoundParameters
        }
    }
    
    throw "UtilityServices module not available. Please ensure the module is installed."
}

# Module initialization message
Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Yellow
Write-Host "║                    DEPRECATION NOTICE                       ║" -ForegroundColor Yellow
Write-Host "╠══════════════════════════════════════════════════════════════╣" -ForegroundColor Yellow
Write-Host "║ ProgressTracking module has been DEPRECATED                 ║" -ForegroundColor Red
Write-Host "║ This compatibility shim forwards calls to UtilityServices    ║" -ForegroundColor Yellow
Write-Host "║                                                              ║" -ForegroundColor Yellow
Write-Host "║ Migration required:                                          ║" -ForegroundColor Cyan
Write-Host "║   Old: Import-Module ProgressTracking                        ║" -ForegroundColor Gray
Write-Host "║   New: Import-Module UtilityServices                          ║" -ForegroundColor Green
Write-Host "║                                                              ║" -ForegroundColor Yellow
Write-Host "║ Migration Guide:                                             ║" -ForegroundColor Cyan
Write-Host "║ https://github.com/AitherLabs/AitherZero/docs/migration/     ║" -ForegroundColor Blue
Write-Host "║   progress-tracking.md                                      ║" -ForegroundColor Blue
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Yellow
Write-Host ""

# Export all functions for backward compatibility
Export-ModuleMember -Function @(
    'Start-ProgressOperation',
    'Update-ProgressOperation',
    'Complete-ProgressOperation',
    'Get-ProgressStatus',
    'Stop-ProgressOperation',
    'Add-ProgressWarning',
    'Add-ProgressError',
    'Start-MultiProgress',
    'Update-MultiProgress',
    'Complete-MultiProgress',
    'Show-ProgressSummary',
    'Get-ProgressHistory',
    'Clear-ProgressHistory',
    'Export-ProgressReport',
    'Test-ProgressOperationActive'
)
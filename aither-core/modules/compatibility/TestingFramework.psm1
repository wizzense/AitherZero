# TestingFramework Backward Compatibility Shim
# This module provides backward compatibility for the deprecated TestingFramework module
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
        Write-Warning "[DEPRECATED] TestingFramework module is deprecated. Functions are forwarded to UtilityServices. Please update your scripts to use 'Import-Module UtilityServices' instead."
    } catch {
        Write-Error "Failed to load UtilityServices module: $_"
    }
} else {
    # Fallback to original module if new one doesn't exist yet
    $originalModulePath = Join-Path $projectRoot "aither-core/modules/TestingFramework"
    if (Test-Path $originalModulePath) {
        try {
            Import-Module $originalModulePath -Force -ErrorAction Stop
            $script:UtilityServicesLoaded = $true
            Write-Warning "[COMPATIBILITY] Using legacy TestingFramework module. Please migrate to UtilityServices when available."
        } catch {
            Write-Error "Failed to load legacy TestingFramework module: $_"
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
    Write-Host "Migration Guide: https://github.com/AitherLabs/AitherZero/docs/migration/testing-framework.md" -ForegroundColor Yellow
}

function Invoke-TestSuite {
    <#
    .SYNOPSIS
        [DEPRECATED] Invoke test suite
    .DESCRIPTION
        This function is deprecated. Use Invoke-TestSuite from UtilityServices instead.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$TestSuiteName,
        [string[]]$TestFiles,
        [string]$OutputPath,
        [switch]$Parallel
    )
    
    Show-DeprecationWarning -FunctionName "Invoke-TestSuite" -NewFunction "Invoke-TestSuite"
    
    if ($script:UtilityServicesLoaded) {
        if (Get-Command Invoke-TestSuite -ErrorAction SilentlyContinue) {
            return Invoke-TestSuite @PSBoundParameters
        }
    }
    
    throw "UtilityServices module not available. Please ensure the module is installed."
}

function New-TestCase {
    <#
    .SYNOPSIS
        [DEPRECATED] Create new test case
    .DESCRIPTION
        This function is deprecated. Use New-TestCase from UtilityServices instead.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,
        [Parameter(Mandatory)]
        [scriptblock]$TestScript,
        [string]$Description,
        [hashtable]$Setup = @{},
        [hashtable]$Teardown = @{}
    )
    
    Show-DeprecationWarning -FunctionName "New-TestCase" -NewFunction "New-TestCase"
    
    if ($script:UtilityServicesLoaded) {
        if (Get-Command New-TestCase -ErrorAction SilentlyContinue) {
            return New-TestCase @PSBoundParameters
        }
    }
    
    throw "UtilityServices module not available. Please ensure the module is installed."
}

function Assert-Equal {
    <#
    .SYNOPSIS
        [DEPRECATED] Assert equal values
    .DESCRIPTION
        This function is deprecated. Use Assert-Equal from UtilityServices instead.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Expected,
        [Parameter(Mandatory)]
        $Actual,
        [string]$Message
    )
    
    Show-DeprecationWarning -FunctionName "Assert-Equal" -NewFunction "Assert-Equal"
    
    if ($script:UtilityServicesLoaded) {
        if (Get-Command Assert-Equal -ErrorAction SilentlyContinue) {
            return Assert-Equal @PSBoundParameters
        }
    }
    
    throw "UtilityServices module not available. Please ensure the module is installed."
}

function Assert-True {
    <#
    .SYNOPSIS
        [DEPRECATED] Assert true condition
    .DESCRIPTION
        This function is deprecated. Use Assert-True from UtilityServices instead.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Condition,
        [string]$Message
    )
    
    Show-DeprecationWarning -FunctionName "Assert-True" -NewFunction "Assert-True"
    
    if ($script:UtilityServicesLoaded) {
        if (Get-Command Assert-True -ErrorAction SilentlyContinue) {
            return Assert-True @PSBoundParameters
        }
    }
    
    throw "UtilityServices module not available. Please ensure the module is installed."
}

function Assert-False {
    <#
    .SYNOPSIS
        [DEPRECATED] Assert false condition
    .DESCRIPTION
        This function is deprecated. Use Assert-False from UtilityServices instead.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Condition,
        [string]$Message
    )
    
    Show-DeprecationWarning -FunctionName "Assert-False" -NewFunction "Assert-False"
    
    if ($script:UtilityServicesLoaded) {
        if (Get-Command Assert-False -ErrorAction SilentlyContinue) {
            return Assert-False @PSBoundParameters
        }
    }
    
    throw "UtilityServices module not available. Please ensure the module is installed."
}

function Assert-Null {
    <#
    .SYNOPSIS
        [DEPRECATED] Assert null value
    .DESCRIPTION
        This function is deprecated. Use Assert-Null from UtilityServices instead.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Value,
        [string]$Message
    )
    
    Show-DeprecationWarning -FunctionName "Assert-Null" -NewFunction "Assert-Null"
    
    if ($script:UtilityServicesLoaded) {
        if (Get-Command Assert-Null -ErrorAction SilentlyContinue) {
            return Assert-Null @PSBoundParameters
        }
    }
    
    throw "UtilityServices module not available. Please ensure the module is installed."
}

function Assert-NotNull {
    <#
    .SYNOPSIS
        [DEPRECATED] Assert not null value
    .DESCRIPTION
        This function is deprecated. Use Assert-NotNull from UtilityServices instead.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Value,
        [string]$Message
    )
    
    Show-DeprecationWarning -FunctionName "Assert-NotNull" -NewFunction "Assert-NotNull"
    
    if ($script:UtilityServicesLoaded) {
        if (Get-Command Assert-NotNull -ErrorAction SilentlyContinue) {
            return Assert-NotNull @PSBoundParameters
        }
    }
    
    throw "UtilityServices module not available. Please ensure the module is installed."
}

function Assert-Throws {
    <#
    .SYNOPSIS
        [DEPRECATED] Assert exception is thrown
    .DESCRIPTION
        This function is deprecated. Use Assert-Throws from UtilityServices instead.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock,
        [string]$ExpectedExceptionType,
        [string]$Message
    )
    
    Show-DeprecationWarning -FunctionName "Assert-Throws" -NewFunction "Assert-Throws"
    
    if ($script:UtilityServicesLoaded) {
        if (Get-Command Assert-Throws -ErrorAction SilentlyContinue) {
            return Assert-Throws @PSBoundParameters
        }
    }
    
    throw "UtilityServices module not available. Please ensure the module is installed."
}

function Get-TestResults {
    <#
    .SYNOPSIS
        [DEPRECATED] Get test results
    .DESCRIPTION
        This function is deprecated. Use Get-TestResults from UtilityServices instead.
    #>
    [CmdletBinding()]
    param(
        [string]$TestSuiteName,
        [switch]$Summary
    )
    
    Show-DeprecationWarning -FunctionName "Get-TestResults" -NewFunction "Get-TestResults"
    
    if ($script:UtilityServicesLoaded) {
        if (Get-Command Get-TestResults -ErrorAction SilentlyContinue) {
            return Get-TestResults @PSBoundParameters
        }
    }
    
    throw "UtilityServices module not available. Please ensure the module is installed."
}

function Export-TestResults {
    <#
    .SYNOPSIS
        [DEPRECATED] Export test results
    .DESCRIPTION
        This function is deprecated. Use Export-TestResults from UtilityServices instead.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$OutputPath,
        [ValidateSet('JSON', 'XML', 'HTML', 'CSV')]
        [string]$Format = 'JSON',
        [string]$TestSuiteName
    )
    
    Show-DeprecationWarning -FunctionName "Export-TestResults" -NewFunction "Export-TestResults"
    
    if ($script:UtilityServicesLoaded) {
        if (Get-Command Export-TestResults -ErrorAction SilentlyContinue) {
            return Export-TestResults @PSBoundParameters
        }
    }
    
    throw "UtilityServices module not available. Please ensure the module is installed."
}

# Module initialization message
Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Yellow
Write-Host "║                    DEPRECATION NOTICE                       ║" -ForegroundColor Yellow
Write-Host "╠══════════════════════════════════════════════════════════════╣" -ForegroundColor Yellow
Write-Host "║ TestingFramework module has been DEPRECATED                 ║" -ForegroundColor Red
Write-Host "║ This compatibility shim forwards calls to UtilityServices    ║" -ForegroundColor Yellow
Write-Host "║                                                              ║" -ForegroundColor Yellow
Write-Host "║ Migration required:                                          ║" -ForegroundColor Cyan
Write-Host "║   Old: Import-Module TestingFramework                        ║" -ForegroundColor Gray
Write-Host "║   New: Import-Module UtilityServices                          ║" -ForegroundColor Green
Write-Host "║                                                              ║" -ForegroundColor Yellow
Write-Host "║ Migration Guide:                                             ║" -ForegroundColor Cyan
Write-Host "║ https://github.com/AitherLabs/AitherZero/docs/migration/     ║" -ForegroundColor Blue
Write-Host "║   testing-framework.md                                      ║" -ForegroundColor Blue
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Yellow
Write-Host ""

# Export all functions for backward compatibility
Export-ModuleMember -Function @(
    'Invoke-TestSuite',
    'New-TestCase',
    'Assert-Equal',
    'Assert-True',
    'Assert-False',
    'Assert-Null',
    'Assert-NotNull',
    'Assert-Throws',
    'Get-TestResults',
    'Export-TestResults'
)
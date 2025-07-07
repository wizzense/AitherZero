# SemanticVersioning Backward Compatibility Shim
# This module provides backward compatibility for the deprecated SemanticVersioning module
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
        Write-Warning "[DEPRECATED] SemanticVersioning module is deprecated. Functions are forwarded to UtilityServices. Please update your scripts to use 'Import-Module UtilityServices' instead."
    } catch {
        Write-Error "Failed to load UtilityServices module: $_"
    }
} else {
    # Fallback to original module if new one doesn't exist yet
    $originalModulePath = Join-Path $projectRoot "aither-core/modules/SemanticVersioning"
    if (Test-Path $originalModulePath) {
        try {
            Import-Module $originalModulePath -Force -ErrorAction Stop
            $script:UtilityServicesLoaded = $true
            Write-Warning "[COMPATIBILITY] Using legacy SemanticVersioning module. Please migrate to UtilityServices when available."
        } catch {
            Write-Error "Failed to load legacy SemanticVersioning module: $_"
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
    Write-Host "Migration Guide: https://github.com/AitherLabs/AitherZero/docs/migration/semantic-versioning.md" -ForegroundColor Yellow
}

function Get-NextSemanticVersion {
    <#
    .SYNOPSIS
        [DEPRECATED] Get next semantic version
    .DESCRIPTION
        This function is deprecated. Use Get-NextSemanticVersion from UtilityServices instead.
    #>
    [CmdletBinding()]
    param(
        [string]$CurrentVersion,
        [ValidateSet('major', 'minor', 'patch')]
        [string]$BumpType = 'patch',
        [string]$PreRelease,
        [string]$BuildMetadata
    )
    
    Show-DeprecationWarning -FunctionName "Get-NextSemanticVersion" -NewFunction "Get-NextSemanticVersion"
    
    if ($script:UtilityServicesLoaded) {
        if (Get-Command Get-NextSemanticVersion -ErrorAction SilentlyContinue) {
            return Get-NextSemanticVersion @PSBoundParameters
        }
    }
    
    throw "UtilityServices module not available. Please ensure the module is installed."
}

function Parse-ConventionalCommits {
    <#
    .SYNOPSIS
        [DEPRECATED] Parse conventional commits
    .DESCRIPTION
        This function is deprecated. Use Parse-ConventionalCommits from UtilityServices instead.
    #>
    [CmdletBinding()]
    param(
        [string[]]$CommitMessages,
        [string]$Since,
        [string]$Until
    )
    
    Show-DeprecationWarning -FunctionName "Parse-ConventionalCommits" -NewFunction "Parse-ConventionalCommits"
    
    if ($script:UtilityServicesLoaded) {
        if (Get-Command Parse-ConventionalCommits -ErrorAction SilentlyContinue) {
            return Parse-ConventionalCommits @PSBoundParameters
        }
    }
    
    throw "UtilityServices module not available. Please ensure the module is installed."
}

function Get-CommitTypeImpact {
    <#
    .SYNOPSIS
        [DEPRECATED] Get commit type impact
    .DESCRIPTION
        This function is deprecated. Use Get-CommitTypeImpact from UtilityServices instead.
    #>
    [CmdletBinding()]
    param(
        [string]$CommitType,
        [switch]$IsBreaking
    )
    
    Show-DeprecationWarning -FunctionName "Get-CommitTypeImpact" -NewFunction "Get-CommitTypeImpact"
    
    if ($script:UtilityServicesLoaded) {
        if (Get-Command Get-CommitTypeImpact -ErrorAction SilentlyContinue) {
            return Get-CommitTypeImpact @PSBoundParameters
        }
    }
    
    throw "UtilityServices module not available. Please ensure the module is installed."
}

function New-VersionTag {
    <#
    .SYNOPSIS
        [DEPRECATED] Create version tag
    .DESCRIPTION
        This function is deprecated. Use New-VersionTag from UtilityServices instead.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Version,
        [string]$Message,
        [switch]$Annotated
    )
    
    Show-DeprecationWarning -FunctionName "New-VersionTag" -NewFunction "New-VersionTag"
    
    if ($script:UtilityServicesLoaded) {
        if (Get-Command New-VersionTag -ErrorAction SilentlyContinue) {
            return New-VersionTag @PSBoundParameters
        }
    }
    
    throw "UtilityServices module not available. Please ensure the module is installed."
}

function Get-VersionHistory {
    <#
    .SYNOPSIS
        [DEPRECATED] Get version history
    .DESCRIPTION
        This function is deprecated. Use Get-VersionHistory from UtilityServices instead.
    #>
    [CmdletBinding()]
    param(
        [int]$Count = 10,
        [string]$Since
    )
    
    Show-DeprecationWarning -FunctionName "Get-VersionHistory" -NewFunction "Get-VersionHistory"
    
    if ($script:UtilityServicesLoaded) {
        if (Get-Command Get-VersionHistory -ErrorAction SilentlyContinue) {
            return Get-VersionHistory @PSBoundParameters
        }
    }
    
    throw "UtilityServices module not available. Please ensure the module is installed."
}

function Update-ProjectVersion {
    <#
    .SYNOPSIS
        [DEPRECATED] Update project version
    .DESCRIPTION
        This function is deprecated. Use Update-ProjectVersion from UtilityServices instead.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$NewVersion,
        [string[]]$Files,
        [switch]$CreateBackup
    )
    
    Show-DeprecationWarning -FunctionName "Update-ProjectVersion" -NewFunction "Update-ProjectVersion"
    
    if ($script:UtilityServicesLoaded) {
        if (Get-Command Update-ProjectVersion -ErrorAction SilentlyContinue) {
            return Update-ProjectVersion @PSBoundParameters
        }
    }
    
    throw "UtilityServices module not available. Please ensure the module is installed."
}

function Get-ReleaseNotes {
    <#
    .SYNOPSIS
        [DEPRECATED] Get release notes
    .DESCRIPTION
        This function is deprecated. Use Get-ReleaseNotes from UtilityServices instead.
    #>
    [CmdletBinding()]
    param(
        [string]$FromVersion,
        [string]$ToVersion,
        [ValidateSet('markdown', 'plain', 'json')]
        [string]$Format = 'markdown'
    )
    
    Show-DeprecationWarning -FunctionName "Get-ReleaseNotes" -NewFunction "Get-ReleaseNotes"
    
    if ($script:UtilityServicesLoaded) {
        if (Get-Command Get-ReleaseNotes -ErrorAction SilentlyContinue) {
            return Get-ReleaseNotes @PSBoundParameters
        }
    }
    
    throw "UtilityServices module not available. Please ensure the module is installed."
}

function Test-SemanticVersion {
    <#
    .SYNOPSIS
        [DEPRECATED] Test semantic version
    .DESCRIPTION
        This function is deprecated. Use Test-SemanticVersion from UtilityServices instead.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Version
    )
    
    Show-DeprecationWarning -FunctionName "Test-SemanticVersion" -NewFunction "Test-SemanticVersion"
    
    if ($script:UtilityServicesLoaded) {
        if (Get-Command Test-SemanticVersion -ErrorAction SilentlyContinue) {
            return Test-SemanticVersion @PSBoundParameters
        }
    }
    
    throw "UtilityServices module not available. Please ensure the module is installed."
}

function Compare-SemanticVersions {
    <#
    .SYNOPSIS
        [DEPRECATED] Compare semantic versions
    .DESCRIPTION
        This function is deprecated. Use Compare-SemanticVersions from UtilityServices instead.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Version1,
        [Parameter(Mandatory)]
        [string]$Version2
    )
    
    Show-DeprecationWarning -FunctionName "Compare-SemanticVersions" -NewFunction "Compare-SemanticVersions"
    
    if ($script:UtilityServicesLoaded) {
        if (Get-Command Compare-SemanticVersions -ErrorAction SilentlyContinue) {
            return Compare-SemanticVersions @PSBoundParameters
        }
    }
    
    throw "UtilityServices module not available. Please ensure the module is installed."
}

function Get-VersionBump {
    <#
    .SYNOPSIS
        [DEPRECATED] Get version bump type
    .DESCRIPTION
        This function is deprecated. Use Get-VersionBump from UtilityServices instead.
    #>
    [CmdletBinding()]
    param(
        [string[]]$CommitMessages,
        [switch]$IncludeReason
    )
    
    Show-DeprecationWarning -FunctionName "Get-VersionBump" -NewFunction "Get-VersionBump"
    
    if ($script:UtilityServicesLoaded) {
        if (Get-Command Get-VersionBump -ErrorAction SilentlyContinue) {
            return Get-VersionBump @PSBoundParameters
        }
    }
    
    throw "UtilityServices module not available. Please ensure the module is installed."
}

# Module initialization message
Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Yellow
Write-Host "║                    DEPRECATION NOTICE                       ║" -ForegroundColor Yellow
Write-Host "╠══════════════════════════════════════════════════════════════╣" -ForegroundColor Yellow
Write-Host "║ SemanticVersioning module has been DEPRECATED               ║" -ForegroundColor Red
Write-Host "║ This compatibility shim forwards calls to UtilityServices    ║" -ForegroundColor Yellow
Write-Host "║                                                              ║" -ForegroundColor Yellow
Write-Host "║ Migration required:                                          ║" -ForegroundColor Cyan
Write-Host "║   Old: Import-Module SemanticVersioning                      ║" -ForegroundColor Gray
Write-Host "║   New: Import-Module UtilityServices                          ║" -ForegroundColor Green
Write-Host "║                                                              ║" -ForegroundColor Yellow
Write-Host "║ Migration Guide:                                             ║" -ForegroundColor Cyan
Write-Host "║ https://github.com/AitherLabs/AitherZero/docs/migration/     ║" -ForegroundColor Blue
Write-Host "║   semantic-versioning.md                                    ║" -ForegroundColor Blue
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Yellow
Write-Host ""

# Export all functions for backward compatibility
Export-ModuleMember -Function @(
    'Get-NextSemanticVersion',
    'Parse-ConventionalCommits',
    'Get-CommitTypeImpact',
    'New-VersionTag',
    'Get-VersionHistory',
    'Update-ProjectVersion',
    'Get-ReleaseNotes',
    'Test-SemanticVersion',
    'Compare-SemanticVersions',
    'Get-VersionBump'
)
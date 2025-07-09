#Requires -Version 7.0

<#
# Initialize logging system with fallback support
. "$PSScriptRoot/../../shared/Initialize-Logging.ps1"
Initialize-Logging

.SYNOPSIS
    PatchManager Module v3.0 - Atomic, Reliable Patch Management

.DESCRIPTION
    This module provides atomic patch operations that eliminate git stashing issues:

    Main Functions:
    - New-Patch: Smart, atomic patch creation (replaces Invoke-PatchWorkflow)
    - New-QuickFix: Simple fixes without branch overhead
    - New-Feature: Full feature development workflow
    - New-Hotfix: Emergency critical fixes

    Modes:
    - Simple: Direct changes without branches (for minor fixes)
    - Standard: Full branch workflow (recommended)
    - Advanced: Cross-fork and enterprise features

    Key Features:
    - Atomic operations with automatic rollback
    - Smart mode detection and recommendations
    - No more git stashing conflicts
    - Multi-mode operation system
    - Backward compatibility with legacy functions

.NOTES
    Version: 3.0.0 (Atomic Operations)
    Author: Aitherium Contributors
    Breaking Changes: Eliminates git stashing to prevent merge conflicts
#>

# Initialize cross-platform environment
try {
    # Import shared utilities
    $sharedUtilsPath = Join-Path $PSScriptRoot '../../shared'
    if (Test-Path $sharedUtilsPath) {
        $findProjectRootPath = Join-Path $sharedUtilsPath 'Find-ProjectRoot.ps1'
        if (Test-Path $findProjectRootPath) {
            . $findProjectRootPath
        }
    }

    # Import Logging module dependency
    $loggingModulePath = Join-Path $PSScriptRoot '../Logging'
    if (Test-Path $loggingModulePath) {
        Import-Module $loggingModulePath -Force -ErrorAction SilentlyContinue
    }
} catch {
    Write-Warning "Failed to import dependencies: $($_.Exception.Message)"
}

# Load Private Functions
$privateFunctions = Get-ChildItem -Path (Join-Path $PSScriptRoot 'Private') -Filter '*.ps1' -ErrorAction SilentlyContinue
foreach ($function in $privateFunctions) {
    try {
        . $function.FullName
        Write-Verbose "Loaded private function: $($function.BaseName)"
    } catch {
        Write-Warning "Failed to load private function $($function.Name): $_"
    }
}

# Load Public Functions
$publicFuncPath = Join-Path $PSScriptRoot 'Public'
Write-Verbose "DEBUG: Looking for public functions in: $publicFuncPath"
$publicFunctions = Get-ChildItem -Path $publicFuncPath -Filter '*.ps1' -ErrorAction SilentlyContinue
Write-Verbose "DEBUG: Found $($publicFunctions.Count) public function files"
foreach ($function in $publicFunctions) {
    try {
        . $function.FullName
        Write-Verbose "Loaded public function: $($function.BaseName)"

        # Debug: Check if Get-GitCommand was loaded
        if ($function.BaseName -eq 'Get-GitCommand') {
            Write-Verbose "DEBUG: Get-GitCommand file loaded, checking if function exists..."
            if (Get-Command Get-GitCommand -ErrorAction SilentlyContinue) {
                Write-Verbose "DEBUG: Get-GitCommand function is available"
            } else {
                Write-Warning "DEBUG: Get-GitCommand function NOT available after loading file"
            }
        }
    } catch {
        Write-Warning "Failed to load public function $($function.Name): $_"
    }
}

# Intelligence Functions - Enhanced PR creation logic
function Test-ShouldCreatePR {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [string]$PatchDescription,
        [bool]$Force = $false
    )

    if ($Force) {
        return $true
    }

    # Check if this is a minor change that doesn't need PR review
    $minorChangePatterns = @(
        'typo', 'formatting', 'whitespace', 'comment', 'documentation update',
        'log message', 'minor fix', 'cleanup', 'lint fix', 'style fix'
    )

    foreach ($pattern in $minorChangePatterns) {
        if ($PatchDescription -like "*$pattern*") {
            if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
                Write-CustomLog -Level 'INFO' -Message "Minor change detected, skipping PR creation: $pattern"
            } else {
                Write-Verbose "Minor change detected, skipping PR creation: $pattern"
            }
            return $false
        }
    }

    return $true
}

function Test-SimilarPRExists {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [string]$PatchDescription,
        [string]$Repository = ''
    )

    try {
        # Get recent PRs and check for similar titles
        $recentPRs = gh pr list --limit 10 --json title 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue

        if ($recentPRs) {
            foreach ($pr in $recentPRs) {
                # Simple similarity check - same keywords
                $descWords = $PatchDescription.Split(' ', [StringSplitOptions]::RemoveEmptyEntries)
                $prWords = $pr.title.Split(' ', [StringSplitOptions]::RemoveEmptyEntries)

                $commonWords = $descWords | Where-Object { $prWords -contains $_ }
                $similarity = ($commonWords.Count / [Math]::Max($descWords.Count, 1)) * 100

                if ($similarity -gt 60) {
                    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
                        Write-CustomLog -Level 'WARN' -Message "Similar PR exists: '$($pr.title)' (${similarity}% similarity)"
                    } else {
                        Write-Warning "Similar PR exists: '$($pr.title)' (${similarity}% similarity)"
                    }
                    return $true
                }
            }
        }
    } catch {
        # If GitHub CLI fails, continue without similarity check
        Write-Verbose "Could not check for similar PRs: $($_.Exception.Message)"
    }

    return $false
}

# Initialize cross-platform environment on module load
try {
    if (Get-Command Initialize-CrossPlatformEnvironment -ErrorAction SilentlyContinue) {
        Initialize-CrossPlatformEnvironment
    }
} catch {
    Write-Verbose "Cross-platform environment initialization skipped: $($_.Exception.Message)"
}

# Export v3.0 functions with legacy compatibility
Export-ModuleMember -Function @(
    # V3.0 Main Functions
    'New-Patch',
    'New-QuickFix',
    'New-Feature',
    'New-Hotfix',

    # V3.0 Core Functions
    'Invoke-MultiModeOperation',
    'Invoke-AtomicOperation',
    'Get-SmartOperationMode',

    # Legacy Functions (for backward compatibility)
    'Invoke-PatchWorkflow',
    'New-PatchIssue',
    'New-PatchPR',
    'Invoke-PatchRollback',
    'Invoke-PostMergeCleanup',
    'Start-PostMergeMonitor',
    'Update-RepositoryDocumentation',
    'New-CrossForkPR',
    'Show-GitStatusGuidance',
    'Sync-GitBranch',
    'Invoke-ReleaseWorkflow',
    'Watch-ReleasePR',
    'Invoke-PostMergeTagging',
    'Find-MissingReleaseTags'
) -Alias @(
    'Invoke-PatchWorkflow'  # Alias for New-Patch for backward compatibility
)

# Module initialization message
if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
    Write-CustomLog -Level 'INFO' -Message 'PatchManager v3.0 loaded - Atomic Operations Ready'
    Write-CustomLog -Level 'INFO' -Message 'New functions: New-Patch, New-QuickFix, New-Feature, New-Hotfix'
    Write-CustomLog -Level 'INFO' -Message 'Legacy functions available for backward compatibility'
} else {
    Write-Host '[INFO] PatchManager v3.0 loaded - Atomic Operations Ready'
    Write-Host '[INFO] New functions: New-Patch, New-QuickFix, New-Feature, New-Hotfix'
    Write-Host '[INFO] Legacy functions available for backward compatibility'
}

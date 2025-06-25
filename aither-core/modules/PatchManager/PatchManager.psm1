#Requires -Version 7.0

<#
.SYNOPSIS
    PatchManager Module - Simplified and Reliable Patch Management

.DESCRIPTION
    This module provides 4 core functions for patch management:
    1. Invoke-PatchWorkflow - Main entry point for all patch operations
    2. New-PatchIssue - Create GitHub issues for patches
    3. New-PatchPR - Create GitHub pull requests
    4. Invoke-PatchRollback - Rollback patch operations

    All legacy functions have been moved to the Legacy folder.

.NOTES
    Version: 2.1 (Enhanced Intelligence)
    Author: Aitherium Contributors
#>

# Initialize cross-platform environment
try {
    # Import shared utilities
    $sharedUtilsPath = Join-Path $PSScriptRoot "../../shared"
    if (Test-Path $sharedUtilsPath) {
        $findProjectRootPath = Join-Path $sharedUtilsPath "Find-ProjectRoot.ps1"
        if (Test-Path $findProjectRootPath) {
            . $findProjectRootPath
        }
    }
    
    # Import Logging module dependency
    $loggingModulePath = Join-Path $PSScriptRoot "../Logging"
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
$publicFunctions = Get-ChildItem -Path (Join-Path $PSScriptRoot 'Public') -Filter '*.ps1' -ErrorAction SilentlyContinue
foreach ($function in $publicFunctions) {
    try {
        . $function.FullName
        Write-Verbose "Loaded public function: $($function.BaseName)"
    } catch {
        Write-Warning "Failed to load public function $($function.Name): $_"
    }
}

# Intelligence Functions - Enhanced PR creation logic
function Test-ShouldCreatePR {
    [CmdletBinding()]
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
    param(
        [string]$PatchDescription,
        [string]$Repository = ""
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

# Export only the core functions
Export-ModuleMember -Function @(
    'Invoke-PatchWorkflow',
    'New-PatchIssue', 
    'New-PatchPR',
    'Invoke-PatchRollback',
    'Update-RepositoryDocumentation',
    'New-CrossForkPR',
    'Show-GitStatusGuidance'
)

# Module initialization message
if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
    Write-CustomLog -Level 'INFO' -Message "PatchManager v2.1 loaded - 4 core functions available"
} else {
    Write-Verbose "PatchManager v2.1 loaded - 4 core functions available"
}

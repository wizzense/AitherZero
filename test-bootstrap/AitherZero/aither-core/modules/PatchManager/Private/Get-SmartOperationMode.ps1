#Requires -Version 7.0

<#
.SYNOPSIS
    Smart operation detection to automatically choose the best approach

.DESCRIPTION
    Analyzes the context and automatically determines:
    - Whether to create PRs/issues
    - Which operation mode to use (Simple/Standard/Advanced)
    - Whether cross-fork operations are needed
    - Risk level and safety recommendations

.PARAMETER PatchDescription
    Description of the patch operation

.PARAMETER HasPatchOperation
    Whether a patch operation script block is provided

.PARAMETER CreatePR
    User's explicit PR creation preference

.PARAMETER CreateIssue
    User's explicit issue creation preference

.PARAMETER TargetFork
    User's explicit target fork preference
#>

function Get-SmartOperationMode {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PatchDescription,

        [Parameter(Mandatory = $false)]
        [bool]$HasPatchOperation = $false,

        [Parameter(Mandatory = $false)]
        [object]$CreatePR = $null,

        [Parameter(Mandatory = $false)]
        [object]$CreateIssue = $null,

        [Parameter(Mandatory = $false)]
        [string]$TargetFork = "current"
    )

    begin {
        # Initialize logging
        if (-not (Get-Command Write-CustomLog -ErrorAction SilentlyContinue)) {
            function Write-CustomLog {
                param($Message, $Level = "INFO")
                Write-Host "[$Level] $Message"
            }
        }

        Write-CustomLog "Analyzing operation context for smart mode detection..." -Level "INFO"
    }

    process {
        try {
            # Initialize analysis result
            $analysis = @{
                RecommendedMode = "Standard"
                ShouldCreatePR = $false
                ShouldCreateIssue = $true
                RiskLevel = "Medium"
                Confidence = 0.8
                Reasoning = @()
                Warnings = @()
                RequiresBranchStrategy = $true
            }

            # Analyze patch description for complexity and risk indicators
            $analysis = Add-DescriptionAnalysis -Analysis $analysis -PatchDescription $PatchDescription

            # Analyze git repository state
            $analysis = Add-GitStateAnalysis -Analysis $analysis

            # Analyze user preferences vs smart recommendations
            $analysis = Add-UserPreferenceAnalysis -Analysis $analysis -CreatePR $CreatePR -CreateIssue $CreateIssue -TargetFork $TargetFork

            # Analyze patch operation complexity
            $analysis = Add-OperationComplexityAnalysis -Analysis $analysis -HasPatchOperation $HasPatchOperation

            # Final mode determination
            $analysis = Resolve-FinalRecommendation -Analysis $analysis

            Write-CustomLog "Smart analysis complete. Recommended mode: $($analysis.RecommendedMode)" -Level "INFO"
            Write-CustomLog "Risk level: $($analysis.RiskLevel), Confidence: $($analysis.Confidence * 100)%" -Level "INFO"

            return $analysis

        } catch {
            Write-CustomLog "Smart operation analysis failed: $($_.Exception.Message)" -Level "ERROR"
            
            # Return safe defaults
            return @{
                RecommendedMode = "Standard"
                ShouldCreatePR = $false
                ShouldCreateIssue = $true
                RiskLevel = "High"
                Confidence = 0.3
                Reasoning = @("Analysis failed - using safe defaults")
                Warnings = @("Smart analysis failed, using conservative settings")
                RequiresBranchStrategy = $true
            }
        }
    }
}

function Add-DescriptionAnalysis {
    param($Analysis, $PatchDescription)

    # Low risk patterns (suggest Simple mode)
    $lowRiskPatterns = @(
        'typo', 'comment', 'documentation', 'readme', 'log message', 'formatting',
        'whitespace', 'lint', 'style', 'cleanup', 'minor fix'
    )

    # High risk patterns (suggest Standard/Advanced with PR)
    $highRiskPatterns = @(
        'security', 'authentication', 'authorization', 'password', 'token', 'key',
        'database', 'migration', 'schema', 'api', 'breaking', 'major', 'refactor',
        'architecture', 'performance', 'critical', 'hotfix', 'production'
    )

    # PR-worthy patterns
    $prWorthyPatterns = @(
        'feature', 'enhancement', 'improvement', 'optimization', 'upgrade',
        'integration', 'functionality', 'capability', 'module', 'component'
    )

    $lowRiskMatches = $lowRiskPatterns | Where-Object { $PatchDescription -like "*$_*" }
    $highRiskMatches = $highRiskPatterns | Where-Object { $PatchDescription -like "*$_*" }
    $prWorthyMatches = $prWorthyPatterns | Where-Object { $PatchDescription -like "*$_*" }

    if ($lowRiskMatches.Count -gt 0) {
        $Analysis.RecommendedMode = "Simple"
        $Analysis.RiskLevel = "Low"
        $Analysis.ShouldCreateIssue = $false
        $Analysis.RequiresBranchStrategy = $false
        $Analysis.Reasoning += "Low-risk operation detected: $($lowRiskMatches -join ', ')"
        $Analysis.Confidence += 0.1
    }

    if ($highRiskMatches.Count -gt 0) {
        $Analysis.RecommendedMode = "Standard"
        $Analysis.RiskLevel = "High"
        $Analysis.ShouldCreatePR = $true
        $Analysis.ShouldCreateIssue = $true
        $Analysis.Reasoning += "High-risk operation detected: $($highRiskMatches -join ', ')"
        $Analysis.Warnings += "High-risk changes detected - PR review strongly recommended"
        $Analysis.Confidence += 0.2
    }

    if ($prWorthyMatches.Count -gt 0) {
        $Analysis.ShouldCreatePR = $true
        $Analysis.Reasoning += "PR-worthy operation detected: $($prWorthyMatches -join ', ')"
        $Analysis.Confidence += 0.1
    }

    return $Analysis
}

function Add-GitStateAnalysis {
    param($Analysis)

    try {
        # Check if we're in a git repository
        $gitDir = git rev-parse --git-dir 2>&1
        if ($LASTEXITCODE -ne 0) {
            $Analysis.Warnings += "Not in a git repository - Simple mode only"
            $Analysis.RecommendedMode = "Simple"
            $Analysis.RequiresBranchStrategy = $false
            return $Analysis
        }

        # Check current branch
        $currentBranch = git branch --show-current 2>&1 | Out-String | ForEach-Object Trim
        if ($currentBranch -eq "main" -or $currentBranch -eq "master") {
            $Analysis.Reasoning += "On main branch - branch strategy recommended"
            $Analysis.RequiresBranchStrategy = $true
        } else {
            $Analysis.Reasoning += "On feature branch ($currentBranch) - can use current branch"
            $Analysis.RequiresBranchStrategy = $false
        }

        # Check for uncommitted changes
        $gitStatus = git status --porcelain 2>&1
        $hasChanges = $gitStatus -and ($gitStatus | Where-Object { $_ -match '\S' })
        if ($hasChanges) {
            $Analysis.Warnings += "Uncommitted changes detected - will be included in patch"
            $Analysis.RiskLevel = "Medium"
        }

        # Check for merge conflicts
        $conflicts = git grep -l "^<<<<<<< HEAD" 2>$null
        if ($conflicts) {
            $Analysis.Warnings += "CRITICAL: Merge conflicts detected - resolve before proceeding"
            $Analysis.RiskLevel = "Critical"
            $Analysis.Confidence = 0.1
        }

        # Check remote status
        try {
            $behind = git rev-list --count HEAD..origin/main 2>&1
            if ($behind -and $behind -gt 0) {
                $Analysis.Warnings += "Branch is $behind commits behind origin/main - consider syncing first"
                $Analysis.RiskLevel = "Medium"
            }
        } catch {
            $Analysis.Reasoning += "Could not check remote status"
        }

    } catch {
        $Analysis.Warnings += "Git state analysis failed: $($_.Exception.Message)"
    }

    return $Analysis
}

function Add-UserPreferenceAnalysis {
    param($Analysis, $CreatePR, $CreateIssue, $TargetFork)

    # Handle explicit user preferences
    if ($CreatePR -is [bool]) {
        if ($CreatePR) {
            $Analysis.ShouldCreatePR = $true
            $Analysis.Reasoning += "User explicitly requested PR creation"
            if ($Analysis.RecommendedMode -eq "Simple") {
                $Analysis.RecommendedMode = "Standard"
                $Analysis.Reasoning += "Upgraded to Standard mode for PR creation"
            }
        } else {
            $Analysis.ShouldCreatePR = $false
            $Analysis.Reasoning += "User explicitly disabled PR creation"
        }
    }

    if ($CreateIssue -is [bool]) {
        $Analysis.ShouldCreateIssue = $CreateIssue
        $Analysis.Reasoning += "User explicitly set issue creation to $CreateIssue"
    }

    if ($TargetFork -ne "current") {
        $Analysis.RecommendedMode = "Advanced"
        $Analysis.ShouldCreatePR = $true
        $Analysis.Reasoning += "Cross-fork operation requested - Advanced mode required"
        $Analysis.Confidence += 0.2
    }

    return $Analysis
}

function Add-OperationComplexityAnalysis {
    param($Analysis, $HasPatchOperation)

    if (-not $HasPatchOperation) {
        $Analysis.Reasoning += "No patch operation provided - git-only workflow"
        if ($Analysis.RecommendedMode -eq "Simple") {
            $Analysis.Warnings += "Simple mode with no operation may have limited value"
        }
    } else {
        $Analysis.Reasoning += "Patch operation provided - full workflow recommended"
    }

    return $Analysis
}

function Resolve-FinalRecommendation {
    param($Analysis)

    # Ensure confidence is within bounds
    $Analysis.Confidence = [Math]::Min(1.0, [Math]::Max(0.1, $Analysis.Confidence))

    # Final safety checks
    if ($Analysis.RiskLevel -eq "Critical") {
        $Analysis.Warnings += "CRITICAL ISSUES DETECTED - Manual intervention recommended"
        $Analysis.RecommendedMode = "Standard"
        $Analysis.ShouldCreatePR = $true
        $Analysis.ShouldCreateIssue = $true
    }

    # Log final reasoning
    Write-CustomLog "Smart analysis reasoning:" -Level "INFO"
    foreach ($reason in $Analysis.Reasoning) {
        Write-CustomLog "  - $reason" -Level "INFO"
    }

    if ($Analysis.Warnings.Count -gt 0) {
        Write-CustomLog "Warnings detected:" -Level "WARN"
        foreach ($warning in $Analysis.Warnings) {
            Write-CustomLog "  ! $warning" -Level "WARN"
        }
    }

    return $Analysis
}

Export-ModuleMember -Function Get-SmartOperationMode
#Requires -Version 7.0

<#
.SYNOPSIS
    Simple, reliable patch creation - the main entry point for PatchManager v3.0

.DESCRIPTION
    This function replaces the complex Invoke-PatchWorkflow with a simplified, atomic approach
    that eliminates git stashing issues and provides predictable behavior.

    Features:
    - Automatic smart mode detection (Simple/Standard/Advanced)
    - Atomic operations with automatic rollback
    - No more git stashing conflicts
    - Clear, predictable behavior
    - Safe defaults with intelligent recommendations

.PARAMETER Description
    Clear description of what this patch does

.PARAMETER Changes
    Script block containing the changes to apply

.PARAMETER Mode
    Operation mode (auto-detected if not specified):
    - Simple: Direct changes without branches (for minor fixes)
    - Standard: Full branch workflow (recommended)
    - Advanced: Cross-fork and enterprise features

.PARAMETER CreatePR
    Create a pull request (auto-determined if not specified)

.PARAMETER CreateIssue
    Create a GitHub issue for tracking (default: auto-determined)

.PARAMETER TargetFork
    For cross-fork PRs: 'current', 'upstream', or 'root'

.PARAMETER ReleaseType
    Type of release this patch represents (patch, minor, major)
    Default: patch

.PARAMETER DryRun
    Preview what would be done without making changes

.PARAMETER Force
    Override safety checks and recommendations

.EXAMPLE
    New-Patch -Description "Fix typo in README" -Changes {
        $content = Get-Content "README.md"
        $content = $content -replace "teh", "the"
        Set-Content "README.md" -Value $content
    }
    # Smart mode will detect this as Simple mode (no PR/issue needed)

.EXAMPLE
    New-Patch -Description "Add user authentication feature" -Changes {
        # Implementation here
        Add-AuthenticationModule
    }
    # Smart mode will detect this as Standard mode with PR creation

.EXAMPLE
    New-Patch -Description "Security fix" -CreatePR -Mode "Standard"
    # Explicitly request Standard mode with PR

.EXAMPLE
    New-Patch -Description "Cross-fork feature" -TargetFork "upstream" -CreatePR
    # Advanced mode for cross-fork operations

.NOTES
    PatchManager v3.0 - Eliminates stashing issues and provides atomic operations
#>

function New-Patch {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [Alias("PatchDescription")]
        [ValidateNotNullOrEmpty()]
        [string]$Description,

        [Parameter(Mandatory = $false)]
        [Alias("PatchOperation")]
        [scriptblock]$Changes,

        [Parameter(Mandatory = $false)]
        [ValidateSet("Simple", "Standard", "Advanced", "Auto")]
        [string]$Mode = "Auto",

        [Parameter(Mandatory = $false)]
        [switch]$CreatePR,

        [Parameter(Mandatory = $false)]
        [object]$CreateIssue = $null,

        [Parameter(Mandatory = $false)]
        [ValidateSet("current", "upstream", "root")]
        [string]$TargetFork = "current",

        [Parameter(Mandatory = $false)]
        [ValidateSet("patch", "minor", "major")]
        [string]$ReleaseType = "patch",

        [Parameter(Mandatory = $false)]
        [ValidateSet("SinglePR", "Stacked", "Replace", "Auto")]
        [string]$WorkflowMode = "Auto",

        [Parameter(Mandatory = $false)]
        [switch]$ReturnToMain,

        [Parameter(Mandatory = $false)]
        [switch]$DryRun,

        [Parameter(Mandatory = $false)]
        [switch]$Force
    )

    begin {
        # Initialize logging
        if (-not (Get-Command Write-CustomLog -ErrorAction SilentlyContinue)) {
            function Write-CustomLog {
                param($Message, $Level = "INFO")
                Write-Host "[$Level] $Message"
            }
        }

        Write-CustomLog "PatchManager v3.1: Starting patch creation" -Level "INFO"
        Write-CustomLog "Description: $Description" -Level "INFO"

        if ($DryRun) {
            Write-CustomLog "DRY RUN MODE: No actual changes will be made" -Level "WARN"
        }
        
        # v3.1: Check for existing open PRs
        $openPRs = @()
        try {
            $openPRs = @(Get-OpenPatchPRs)
            if ($openPRs.Count -gt 0) {
                Write-CustomLog "Found $($openPRs.Count) open PR(s)" -Level "WARNING"
                
                # Determine workflow mode
                if ($WorkflowMode -eq "Auto") {
                    $WorkflowMode = if ($openPRs.Count -ge 3) { "SinglePR" } else { "Stacked" }
                    Write-CustomLog "Auto-selected workflow mode: $WorkflowMode" -Level "INFO"
                }
                
                # Display open PRs
                switch ($WorkflowMode) {
                    "SinglePR" {
                        Write-CustomLog "SinglePR mode: Consider updating existing PR instead" -Level "WARNING"
                        foreach ($pr in $openPRs | Select-Object -First 5) {
                            Write-CustomLog "  - PR #$($pr.number): $($pr.title)" -Level "INFO"
                        }
                        if (-not $Force -and -not $DryRun) {
                            $continue = Read-Host "Continue creating new PR? (y/N)"
                            if ($continue -ne 'y') {
                                return @{ Success = $false; Message = "Operation cancelled - resolve existing PRs first" }
                            }
                        }
                    }
                    "Replace" {
                        Write-CustomLog "Replace mode: Will close old PRs after creating new one" -Level "INFO"
                    }
                    "Stacked" {
                        Write-CustomLog "Stacked mode: Creating additional PR" -Level "INFO"
                    }
                }
            }
        } catch {
            Write-CustomLog "Unable to check for open PRs: $_" -Level "DEBUG"
        }
    }

    process {
        try {
            # Step 1: Smart mode detection if needed
            if ($Mode -eq "Auto") {
                Write-CustomLog "Performing smart analysis to determine optimal approach..." -Level "INFO"
                
                $smartAnalysis = Get-SmartOperationMode -PatchDescription $Description -HasPatchOperation ($null -ne $Changes) -CreatePR $CreatePR -CreateIssue $CreateIssue -TargetFork $TargetFork
                
                $Mode = $smartAnalysis.RecommendedMode
                
                # Apply smart recommendations if user didn't explicitly set them
                if (-not $CreatePR.IsPresent) {
                    $CreatePR = $smartAnalysis.ShouldCreatePR
                }
                if ($null -eq $CreateIssue) {
                    $CreateIssue = $smartAnalysis.ShouldCreateIssue
                }

                Write-CustomLog "Smart analysis recommends: $Mode mode" -Level "INFO"
                Write-CustomLog "Confidence: $($smartAnalysis.Confidence * 100)%, Risk: $($smartAnalysis.RiskLevel)" -Level "INFO"

                # Show warnings if any
                foreach ($warning in $smartAnalysis.Warnings) {
                    Write-CustomLog $warning -Level "WARN"
                }

                # Ask for confirmation if high risk and not forced
                if ($smartAnalysis.RiskLevel -eq "High" -and -not $Force -and -not $DryRun) {
                    Write-CustomLog "High-risk operation detected. Recommended: Create PR for review" -Level "WARN"
                    if (-not $CreatePR) {
                        Write-CustomLog "Consider using -CreatePR flag for safer operation" -Level "WARN"
                    }
                }
            }

            Write-CustomLog "Using $Mode mode (CreatePR: $CreatePR, CreateIssue: $CreateIssue)" -Level "INFO"

            # Step 2: Execute multi-mode operation
            $multiModeParams = @{
                Mode = $Mode
                PatchDescription = $Description
                CreatePR = $CreatePR
                TargetFork = $TargetFork
                ReleaseType = $ReleaseType
                DryRun = $DryRun
            }
            
            if ($Changes) {
                $multiModeParams.PatchOperation = $Changes
            }
            
            if ($null -ne $CreateIssue) {
                $multiModeParams.CreateIssue = $CreateIssue
            }
            
            $result = Invoke-MultiModeOperation @multiModeParams

            if ($result.Success) {
                Write-CustomLog "Patch creation completed successfully!" -Level "SUCCESS"
                
                # Provide user guidance based on what was created
                if ($result.Result.BranchCreated) {
                    Write-CustomLog "Branch created: $($result.Result.BranchCreated)" -Level "INFO"
                }
                
                if ($CreatePR -and -not $DryRun) {
                    Write-CustomLog "Next steps: PR will be created for review and merge" -Level "INFO"
                    
                    # v3.1: Auto-return to main after PR creation
                    if (($ReturnToMain -or $WorkflowMode -eq "SinglePR") -and $result.Result.BranchCreated) {
                        Write-CustomLog "Returning to main branch..." -Level "INFO"
                        try {
                            $checkoutResult = Invoke-GitCommand "checkout main" -AllowFailure
                            if ($checkoutResult.Success) {
                                Write-CustomLog "Switched back to main branch" -Level "SUCCESS"
                                $result.ReturnedToMain = $true
                            }
                        } catch {
                            Write-CustomLog "Failed to return to main: $_" -Level "WARNING"
                        }
                    }
                    
                    # v3.1: Handle Replace mode
                    if ($WorkflowMode -eq "Replace" -and $result.PullRequestNumber -and $openPRs.Count -gt 0) {
                        Write-CustomLog "Replace mode: Closing old PRs..." -Level "INFO"
                        foreach ($pr in $openPRs) {
                            try {
                                $closeCmd = "gh pr close $($pr.number) --comment `"Replaced by PR #$($result.PullRequestNumber)`""
                                $closeResult = Invoke-Expression $closeCmd 2>&1
                                Write-CustomLog "Closed PR #$($pr.number)" -Level "SUCCESS"
                            } catch {
                                Write-CustomLog "Failed to close PR #$($pr.number): $_" -Level "WARNING"
                            }
                        }
                    }
                } elseif ($result.Result.CommittedDirectly) {
                    Write-CustomLog "Changes have been committed directly" -Level "INFO"
                } else {
                    Write-CustomLog "Changes are ready in branch for manual review" -Level "INFO"
                }

                return @{
                    Success = $true
                    Mode = $Mode
                    Description = $Description
                    DryRun = $DryRun.IsPresent
                    Result = $result.Result
                    Duration = $result.Duration
                    Message = "Patch created successfully"
                }
            } else {
                throw "Operation failed: $($result.Error)"
            }

        } catch {
            $errorMessage = "Patch creation failed: $($_.Exception.Message)"
            Write-CustomLog $errorMessage -Level "ERROR"

            return @{
                Success = $false
                Mode = $Mode
                Description = $Description
                DryRun = $DryRun.IsPresent
                Error = $_.Exception.Message
                Message = $errorMessage
            }
        }
    }

    end {
        Write-CustomLog "Patch operation completed" -Level "INFO"
        
        # v3.1: Suggest next steps based on workflow
        if (-not $DryRun) {
            Write-CustomLog "Tip: Use 'Get-PatchStatus' to see your current patch workflow state" -Level "INFO"
        }
    }
}

# Provide legacy compatibility alias
Set-Alias -Name "Invoke-PatchWorkflow" -Value "New-Patch"

Export-ModuleMember -Function New-Patch -Alias Invoke-PatchWorkflow
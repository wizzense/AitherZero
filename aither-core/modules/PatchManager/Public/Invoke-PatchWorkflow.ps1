#Requires -Version 7.0

<#
.SYNOPSIS
    The ONLY entry point for all patch operations in the OpenTofu Lab Automation project.

.DESCRIPTION
    This is the single, unified function for creating patches. It replaces all the overlapping
    patch functions and provides consistent, predictable behavior.

    No emoji/Unicode output - follows project standards.

.PARAMETER PatchDescription
    Description of what the patch does

.PARAMETER PatchOperation
    Script block containing the changes to make

.PARAMETER TestCommands
    Optional array of commands to run for validation

.PARAMETER CreateIssue
    Create a GitHub issue to track this patch (default: true, use -CreateIssue:$false to disable)

.PARAMETER CreatePR
    Create a pull request for this patch (default: false, use -CreatePR to enable)

.PARAMETER TargetFork
    Target fork for pull request creation:
    - 'current' (default): Create PR in current repository
    - 'upstream': Create cross-fork PR to upstream (AitherZero → AitherLabs)
    - 'root': Create cross-fork PR to root repository (AitherLabs → Aitherium)

.PARAMETER Priority
    Priority level for issue tracking (Low, Medium, High, Critical)

.PARAMETER DryRun
    Preview what would be done without making changes

.PARAMETER Force
    Force operation even if working tree is not clean

.PARAMETER AutoConsolidate
    Automatically consolidate open PRs after creating this PR (default: false)

.PARAMETER ConsolidationStrategy
    Strategy for PR consolidation when AutoConsolidate is enabled:
    - 'Compatible' (default): Only combine PRs with no conflicts
    - 'RelatedFiles': Combine PRs that modify related file areas
    - 'SameAuthor': Combine PRs from the same author
    - 'ByPriority': Combine based on priority levels
    - 'All': Attempt to combine all possible PRs

.PARAMETER MaxPRsToConsolidate
    Maximum number of PRs to include in consolidation (default: 5)

.EXAMPLE
    Invoke-PatchWorkflow -PatchDescription "Fix module loading issue" -PatchOperation {
        # Your changes here
        $content = Get-Content "module.ps1"
        $content = $content -replace "old pattern", "new pattern"
        Set-Content "module.ps1" -Value $content
    }
    # Creates issue by default, applies changes, commits to new branch

.EXAMPLE
    Invoke-PatchWorkflow -PatchDescription "Update configuration" -CreatePR -Priority "High" -TestCommands @("Test-Config")
    # Creates issue AND PR, includes testing

.EXAMPLE
    Invoke-PatchWorkflow -PatchDescription "Quick local fix" -CreateIssue:$false -PatchOperation {
        # Quick local change
    }
    # No issue created, just branch + commit

.EXAMPLE
    Invoke-PatchWorkflow -PatchDescription "Promote feature to public staging" -CreatePR -TargetFork "upstream" -PatchOperation {
        # Feature ready for public release
        Update-PublicFeature
    }
    # Creates cross-fork PR from AitherZero to AitherLabs

.EXAMPLE
    Invoke-PatchWorkflow -PatchDescription "Add enterprise feature" -CreatePR -TargetFork "root" -Priority "High" -PatchOperation {
        # Enterprise-specific enhancement
        Add-EnterpriseFeature
    }
    # Creates cross-fork PR from AitherLabs to Aitherium

.EXAMPLE
    Invoke-PatchWorkflow -PatchDescription "Multiple bug fixes" -CreatePR -AutoConsolidate -ConsolidationStrategy "Compatible" -PatchOperation {
        # Apply multiple related fixes
        Fix-ModuleLoadingBug
        Fix-ConfigurationIssue
    }
    # Creates PR and automatically consolidates with other compatible open PRs

.EXAMPLE
    Invoke-PatchWorkflow -PatchDescription "Author's fixes" -CreatePR -AutoConsolidate -ConsolidationStrategy "SameAuthor" -MaxPRsToConsolidate 3 -PatchOperation {
        # Another fix from same author
        Fix-AdditionalIssue
    }
    # Creates PR and consolidates up to 3 PRs from the same author

.NOTES
    This function replaces:
    - Invoke-GitControlledPatch
    - Invoke-EnhancedPatchManager
    - Invoke-SimplifiedPatchWorkflow
    - And 10+ other overlapping functions
#>

function Invoke-PatchWorkflow {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$PatchDescription,

        [Parameter(Mandatory = $false)]
        [scriptblock]$PatchOperation,

        [Parameter(Mandatory = $false)]
        [string[]]$TestCommands = @(),

        [Parameter(Mandatory = $false)]
        [bool]$CreateIssue = $true,

        [Parameter(Mandatory = $false)]
        [switch]$CreatePR,

        [Parameter(Mandatory = $false)]
        [ValidateSet("current", "upstream", "root")]
        [string]$TargetFork = "current",

        [Parameter(Mandatory = $false)]
        [ValidateSet("Low", "Medium", "High", "Critical")]
        [string]$Priority = "Medium",

        [Parameter(Mandatory = $false)]
        [switch]$DryRun,

        [Parameter(Mandatory = $false)]
        [switch]$Force,

        [Parameter(Mandatory = $false)]
        [switch]$AutoConsolidate,

        [Parameter(Mandatory = $false)]
        [ValidateSet("Compatible", "RelatedFiles", "SameAuthor", "ByPriority", "All")]
        [string]$ConsolidationStrategy = "Compatible",

        [Parameter(Mandatory = $false)]
        [int]$MaxPRsToConsolidate = 5,

        [Parameter(Mandatory = $false)]
        [switch]$AutoMerge,

        [Parameter(Mandatory = $false)]
        [ValidateSet("Squash", "Merge", "Rebase")]
        [string]$MergeMethod = "Squash",

        [Parameter(Mandatory = $false)]
        [int]$AutoMergeDelayMinutes = 5,

        [Parameter(Mandatory = $false)]
        [string[]]$RequiredChecks = @("ci-cd")
    )

    begin {
        # Import required modules
        if (-not (Get-Module -Name Logging -ListAvailable)) {
            Import-Module (Join-Path $PSScriptRoot "../../../Logging") -Force -ErrorAction SilentlyContinue
        }

        function Write-PatchLog {
            param($Message, $Level = "INFO")
            if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
                Write-CustomLog -Message $Message -Level $Level
            } else {
                Write-Host "[$Level] $Message"
            }
        }

        Write-PatchLog "Starting patch workflow: $PatchDescription" -Level "INFO"

        if ($DryRun) {
            Write-PatchLog "DRY RUN MODE: No actual changes will be made" -Level "WARN"
        }
    }

    process {
        try {
            # Initialize test capture variables
            $testOutput = @()
            $testErrors = @()
            $testContext = @{}

            # Step 1: Handle existing changes (auto-commit or stash)
            $gitStatus = git status --porcelain 2>&1
            $hasUncommittedChanges = $gitStatus -and ($gitStatus | Where-Object { $_ -match '\S' })

            if ($hasUncommittedChanges) {
                # CRITICAL FIX: Check for merge conflict markers before auto-committing
                Write-PatchLog "Checking for merge conflict markers before auto-commit..." -Level "INFO"
                $conflictMarkers = git grep -l "^<<<<<<< HEAD" 2>$null
                if ($conflictMarkers) {
                    $errorMsg = "MERGE CONFLICTS DETECTED! Cannot auto-commit files with unresolved conflict markers:`n" +
                               ($conflictMarkers -join "`n") +
                               "`n`nPlease resolve conflicts manually first, then run the patch workflow again."
                    Write-PatchLog $errorMsg -Level "ERROR"
                    throw $errorMsg
                }

                Write-PatchLog "Working tree has uncommitted changes. Auto-committing them first..." -Level "INFO"

                if (-not $DryRun) {
                    # Sanitize files before committing existing changes
                    try {
                        $changedFiles = git diff --name-only HEAD 2>&1 | Where-Object { $_ -and $_.Trim() }
                        if ($changedFiles) {
                            $sanitizeResult = Invoke-UnicodeSanitizer -FilePaths $changedFiles -ProjectRoot (Get-Location).Path
                            if ($sanitizeResult.FilesModified -gt 0) {
                                Write-PatchLog "Sanitized $($sanitizeResult.FilesModified) files before committing" -Level "INFO"
                            }
                        }
                    } catch {
                        Write-PatchLog "Warning: Unicode sanitization failed: $($_.Exception.Message)" -Level "WARN"
                    }

                    git add . 2>&1 | Out-Null
                    git commit -m "Auto-commit: Changes before patch workflow for '$PatchDescription'" 2>&1 | Out-Null

                    if ($LASTEXITCODE -ne 0) {
                        Write-PatchLog "Warning: Auto-commit may have had issues" -Level "WARN"
                    } else {
                        Write-PatchLog "Successfully auto-committed existing changes" -Level "SUCCESS"
                    }
                } else {
                    Write-PatchLog "DRY RUN: Would auto-commit existing changes" -Level "INFO"
                }
            } else {
                Write-PatchLog "Working tree is clean - proceeding with patch workflow" -Level "INFO"
            }

            # Step 2: Create patch branch
            $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
            $safeName = $PatchDescription -replace '[^a-zA-Z0-9\-_]', '-' -replace '-+', '-'
            $branchName = "patch/$timestamp-$safeName"

            Write-PatchLog "Creating branch: $branchName" -Level "INFO"

            if (-not $DryRun) {
                git checkout -b $branchName 2>&1 | Out-Null
                if ($LASTEXITCODE -ne 0) {
                    throw "Failed to create branch $branchName"
                }
            }

            # Step 3: Run test commands with enhanced output capture FIRST (before issue creation)
            if ($TestCommands.Count -gt 0) {
                Write-PatchLog "Running $($TestCommands.Count) test command(s) with output capture..." -Level "INFO"

                foreach ($cmd in $TestCommands) {
                    Write-PatchLog "Running test: $cmd" -Level "INFO"

                    if (-not $DryRun) {
                        try {
                            # Capture both stdout and stderr
                            $output = Invoke-Expression $cmd 2>&1

                            # Separate output and errors
                            $cmdOutput = @()
                            $cmdErrors = @()

                            foreach ($line in $output) {
                                if ($line -is [System.Management.Automation.ErrorRecord]) {
                                    $cmdErrors += $line.ToString()
                                    $testErrors += $line.ToString()
                                } else {
                                    $cmdOutput += $line.ToString()
                                    $testOutput += $line.ToString()
                                }
                            }

                            # Check exit code
                            if ($LASTEXITCODE -ne 0) {
                                $errorMsg = "Test command failed with exit code $LASTEXITCODE : $cmd"
                                Write-PatchLog $errorMsg -Level "WARN"
                                $testErrors += $errorMsg
                            }

                            # Store test context
                            $testContext[$cmd] = @{
                                ExitCode = $LASTEXITCODE
                                OutputLines = $cmdOutput.Count
                                ErrorLines = $cmdErrors.Count
                                ExecutionTime = Get-Date
                            }

                        } catch {
                            $errorMsg = "Test command failed: $cmd - $($_.Exception.Message)"
                            Write-PatchLog $errorMsg -Level "WARN"
                            $testErrors += $errorMsg
                            $testErrors += $_.Exception.Message

                            $testContext[$cmd] = @{
                                ExitCode = -1
                                OutputLines = 0
                                ErrorLines = 1
                                ExecutionTime = Get-Date
                                Exception = $_.Exception.Message
                            }
                        }
                    } else {
                        Write-PatchLog "DRY RUN: Would run test command: $cmd" -Level "INFO"
                    }
                }

                # Log test summary
                Write-PatchLog "Test execution complete. Output lines: $($testOutput.Count), Error lines: $($testErrors.Count)" -Level "INFO"
            }            # Step 4: Create tracking issue with enhanced context (NOW with test data available)
            $issueResult = $null
            if ($CreateIssue) {
                # Determine target repository for issue creation based on PR target
                $repoInfo = Get-GitRepositoryInfo
                $issueTargetRepo = $repoInfo.GitHubRepo  # Default to current repo

                if ($CreatePR -and $TargetFork -ne "current") {
                    # If creating a cross-fork PR, create the issue in the target repository
                    $targetForkInfo = $repoInfo.ForkChain | Where-Object { $_.Name -eq $TargetFork }
                    if ($targetForkInfo) {
                        $issueTargetRepo = $targetForkInfo.GitHubRepo
                        Write-PatchLog "Creating issue in target repository: $issueTargetRepo (for cross-fork PR)" -Level "INFO"
                    }
                } else {
                    Write-PatchLog "Creating issue in current repository: $issueTargetRepo" -Level "INFO"
                }

                Write-PatchLog "Creating tracking issue with intelligent analysis (with test data from previous step)..." -Level "INFO"

                if (-not $DryRun) {
                    $issueParams = @{
                        Description = $PatchDescription
                        Priority = $Priority
                        TargetRepository = $issueTargetRepo
                    }

                    # Include test data if available for intelligent analysis
                    if ($testOutput.Count -gt 0 -or $testErrors.Count -gt 0) {
                        $issueParams.TestOutput = $testOutput
                        $issueParams.ErrorDetails = $testErrors
                        $issueParams.TestType = "PatchWorkflow"
                        $issueParams.TestContext = $testContext
                        Write-PatchLog "Including test analysis data: $($testOutput.Count) output lines, $($testErrors.Count) error lines" -Level "INFO"
                    } else {
                        Write-PatchLog "No test data captured for analysis" -Level "INFO"
                    }

                    $issueResult = New-PatchIssue @issueParams
                    if ($issueResult.Success) {
                        Write-PatchLog "Issue created: $($issueResult.IssueUrl)" -Level "SUCCESS"
                    } else {
                        Write-PatchLog "Issue creation failed: $($issueResult.Message)" -Level "WARN"
                    }
                } else {
                    Write-PatchLog "DRY RUN: Would create GitHub issue with test analysis in $issueTargetRepo" -Level "INFO"
                }
            } else {
                Write-PatchLog "Skipping issue creation (disabled by -CreateIssue:`$false)" -Level "INFO"
            }

            # Step 5: Apply patch operation
            if ($PatchOperation) {
                Write-PatchLog "Applying patch operation..." -Level "INFO"

                if (-not $DryRun) {
                    & $PatchOperation
                } else {
                    Write-PatchLog "DRY RUN: Would execute patch operation" -Level "INFO"
                }
            }

            # Step 6: Sanitize files and commit patch changes
            if (-not $DryRun) {
                $gitStatus = git status --porcelain 2>&1
                if ($gitStatus -and ($gitStatus | Where-Object { $_ -match '\S' })) {
                    # CRITICAL FIX: Check for merge conflict markers before committing patch changes
                    Write-PatchLog "Checking for merge conflict markers before patch commit..." -Level "INFO"
                    $conflictMarkers = git grep -l "^<<<<<<< HEAD" 2>$null
                    if ($conflictMarkers) {
                        $errorMsg = "MERGE CONFLICTS DETECTED! Cannot commit patch changes with unresolved conflict markers:`n" +
                                   ($conflictMarkers -join "`n") +
                                   "`n`nPlease resolve conflicts manually first, then run the patch workflow again."
                        Write-PatchLog $errorMsg -Level "ERROR"
                        throw $errorMsg
                    }

                    # First, sanitize all changed files of Unicode/emoji
                    Write-PatchLog "Sanitizing files before commit..." -Level "INFO"
                    try {
                        $changedFiles = git diff --name-only HEAD 2>&1 | Where-Object { $_ -and $_.Trim() }
                        if ($changedFiles) {
                            $sanitizeResult = Invoke-UnicodeSanitizer -FilePaths $changedFiles -ProjectRoot (Get-Location).Path
                            if ($sanitizeResult.FilesModified -gt 0) {
                                Write-PatchLog "Sanitized $($sanitizeResult.FilesModified) files, removed $($sanitizeResult.CharactersRemoved) problematic characters" -Level "INFO"
                            }
                        }
                    } catch {
                        Write-PatchLog "Warning: Unicode sanitization failed: $($_.Exception.Message)" -Level "WARN"
                    }

                    Write-PatchLog "Committing changes..." -Level "INFO"
                    git add . 2>&1 | Out-Null
                    git commit -m "PatchManager: $PatchDescription" 2>&1 | Out-Null

                    if ($LASTEXITCODE -ne 0) {
                        Write-PatchLog "Warning: Git commit may have had issues" -Level "WARN"
                    }
                } else {
                    Write-PatchLog "No changes to commit" -Level "INFO"
                }
            } else {
                Write-PatchLog "DRY RUN: Would sanitize files and commit changes" -Level "INFO"
            }            # Step 7: Create PR if requested
            if ($CreatePR) {
                if (-not $DryRun) {
                    Write-PatchLog "Creating pull request..." -Level "INFO"
                    $prParams = @{
                        Description = $PatchDescription
                        BranchName = $branchName
                    }

                    if ($issueResult -and $issueResult.Success) {
                        $prParams.IssueNumber = $issueResult.IssueNumber
                    }

                    # Use cross-fork PR if target is not current repository
                    if ($TargetFork -ne "current") {
                        $prParams.TargetFork = $TargetFork
                        $prResult = New-CrossForkPR @prParams
                        if ($prResult.Success) {
                            Write-PatchLog "Cross-fork pull request created successfully!" -Level "SUCCESS"
                            Write-PatchLog "  Source: $($prResult.Source)" -Level "SUCCESS"
                            Write-PatchLog "  Target: $($prResult.Target)" -Level "SUCCESS"
                            Write-PatchLog "  URL: $($prResult.PullRequestUrl)" -Level "SUCCESS"
                        } else {
                            Write-PatchLog "Cross-fork PR creation failed: $($prResult.Message)" -Level "ERROR"
                            throw "Failed to create cross-fork pull request: $($prResult.Message)"
                        }
                    } else {
                        # Standard PR within current repository
                        $prResult = New-PatchPR @prParams
                        if ($prResult.Success) {
                            Write-PatchLog "Pull request created: $($prResult.PullRequestUrl)" -Level "SUCCESS"
                        } else {
                            Write-PatchLog "PR creation failed: $($prResult.Message)" -Level "ERROR"
                            throw "Failed to create pull request: $($prResult.Message)"
                        }
                    }

                    # Step 7a: Enable Auto-Merge if requested
                    if ($AutoMerge -and $prResult.Success -and $prResult.PullRequestNumber) {
                        Write-PatchLog "Enabling auto-merge for PR #$($prResult.PullRequestNumber)..." -Level "INFO"
                        try {
                            $autoMergeResult = Enable-AutoMerge -PRNumber $prResult.PullRequestNumber -MergeMethod $MergeMethod -DelayMinutes $AutoMergeDelayMinutes -RequiredChecks $RequiredChecks
                            if ($autoMergeResult.Success) {
                                Write-PatchLog "Auto-merge enabled successfully!" -Level "SUCCESS"
                                Write-PatchLog "  Method: $MergeMethod" -Level "INFO"
                                Write-PatchLog "  Delay: $AutoMergeDelayMinutes minutes" -Level "INFO"
                                Write-PatchLog "  Required checks: $($RequiredChecks -join ', ')" -Level "INFO"
                            } else {
                                Write-PatchLog "Auto-merge setup failed: $($autoMergeResult.Message)" -Level "WARN"
                            }
                        } catch {
                            Write-PatchLog "Auto-merge configuration failed: $($_.Exception.Message)" -Level "WARN"
                        }
                    }
                } else {
                    # DRY RUN: Show what would be created
                    if ($TargetFork -ne "current") {
                        Write-PatchLog "DRY RUN: Would create cross-fork pull request to $TargetFork repository" -Level "INFO"
                        $repoInfo = Get-GitRepositoryInfo
                        $targetRepo = ($repoInfo.ForkChain | Where-Object { $_.Name -eq $TargetFork }).GitHubRepo
                        Write-PatchLog "  Source: $($repoInfo.GitHubRepo)" -Level "INFO"
                        Write-PatchLog "  Target: $targetRepo" -Level "INFO"
                        Write-PatchLog "  Branch: $branchName" -Level "INFO"
                    } else {
                        Write-PatchLog "DRY RUN: Would create pull request within current repository" -Level "INFO"
                        $repoInfo = Get-GitRepositoryInfo
                        Write-PatchLog "  Repository: $($repoInfo.GitHubRepo)" -Level "INFO"
                        Write-PatchLog "  Branch: $branchName" -Level "INFO"
                    }
                }
            }

            # Step 8: Auto-consolidate PRs if requested
            if ($AutoConsolidate -and $CreatePR -and -not $DryRun) {
                Write-PatchLog "Auto-consolidation requested, analyzing open PRs..." -Level "INFO"
                try {
                    $consolidationResult = Invoke-PRConsolidation -ConsolidationStrategy $ConsolidationStrategy -MaxPRsToConsolidate $MaxPRsToConsolidate
                    if ($consolidationResult.Success) {
                        Write-PatchLog "PR consolidation completed successfully" -Level "SUCCESS"
                        Write-PatchLog "  PRs consolidated: $($consolidationResult.PRsConsolidated)" -Level "INFO"
                        Write-PatchLog "  Final PR: $($consolidationResult.ConsolidatedPRUrl)" -Level "INFO"
                    } else {
                        Write-PatchLog "PR consolidation skipped: $($consolidationResult.Message)" -Level "WARN"
                    }
                } catch {
                    Write-PatchLog "PR consolidation failed: $($_.Exception.Message)" -Level "WARN"
                    Write-PatchLog "Continuing with individual PR..." -Level "INFO"
                }
            } elseif ($AutoConsolidate -and $DryRun) {
                Write-PatchLog "DRY RUN: Would attempt PR consolidation with strategy: $ConsolidationStrategy" -Level "INFO"
            }

            # Success
            Write-PatchLog "Patch workflow completed successfully" -Level "SUCCESS"

            return @{
                Success = $true
                BranchName = $branchName
                DryRun = $DryRun.IsPresent
                Message = "Patch workflow completed successfully"
                IssueNumber = if ($issueResult) { $issueResult.IssueNumber } else { $null }
                IssueUrl = if ($issueResult) { $issueResult.IssueUrl } else { $null }
                PullRequestUrl = if ($prResult) { $prResult.PullRequestUrl } else { $null }
            }

        } catch {
            $errorMessage = "Patch workflow failed: $($_.Exception.Message)"
            Write-PatchLog $errorMessage -Level "ERROR"

            # Cleanup on failure
            if (-not $DryRun -and $branchName) {
                try {
                    Write-PatchLog "Cleaning up failed patch branch..." -Level "INFO"
                    git checkout main 2>&1 | Out-Null
                    git branch -D $branchName 2>&1 | Out-Null
                } catch {
                    Write-PatchLog "Cleanup failed: $($_.Exception.Message)" -Level "WARN"
                }
            }

            return @{
                Success = $false
                Message = $errorMessage
                BranchName = $branchName
                DryRun = $DryRun.IsPresent
            }
        }
    }
}

Export-ModuleMember -Function Invoke-PatchWorkflow

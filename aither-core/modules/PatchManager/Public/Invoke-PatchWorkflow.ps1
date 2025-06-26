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

.PARAMETER CreateRelease
    Automatically create a release after PR is merged (for critical fixes and version updates)

.PARAMETER ReleaseType
    Type of release to create: patch (default), minor, or major

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
    Invoke-PatchWorkflow -PatchDescription "CRITICAL SECURITY FIX: Patch authentication vulnerability" -CreatePR -CreateRelease -Priority "Critical" -ReleaseType "patch"
    # Creates issue, PR, and immediately triggers a patch release due to Critical priority

.EXAMPLE
    Invoke-PatchWorkflow -PatchDescription "VERSION UPDATE: Bump to v2.0.0 for new features" -CreatePR -CreateRelease -ReleaseType "major"
    # Detects version keywords and creates major release

.EXAMPLE
    Invoke-PatchWorkflow -PatchDescription "Add enterprise feature" -CreatePR -TargetFork "root" -Priority "High" -PatchOperation {
        # Enterprise-specific enhancement
        Add-EnterpriseFeature
    }
    # Creates cross-fork PR from AitherLabs to Aitherium

.NOTES
    This function replaces:
    - Invoke-GitControlledPatch
    - Invoke-EnhancedPatchManager
    - Invoke-SimplifiedPatchWorkflow
    - And 10+ other overlapping functions
#>

function Invoke-PatchWorkflow {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$PatchDescription,

        [Parameter(Mandatory = $false)]
        [scriptblock]$PatchOperation,

        [Parameter(Mandatory = $false)]
        [string[]]$TestCommands = @(),

        [Parameter(Mandatory = $false)]
        [bool]$CreateIssue = $true,        [Parameter(Mandatory = $false)]
        [switch]$CreatePR,

        [Parameter(Mandatory = $false)]
        [switch]$CreateRelease,

        [Parameter(Mandatory = $false)]
        [ValidateSet("patch", "minor", "major")]
        [string]$ReleaseType = "patch",

        [Parameter(Mandatory = $false)]
        [ValidateSet("current", "upstream", "root")]
        [string]$TargetFork = "current",

        [Parameter(Mandatory = $false)]
        [ValidateSet("Low", "Medium", "High", "Critical")]
        [string]$Priority = "Medium",

        [Parameter(Mandatory = $false)]
        [switch]$DryRun,

        [Parameter(Mandatory = $false)]
        [switch]$Force
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

            # Step 9: Create release if requested (intelligent release automation)
            if ($CreateRelease) {
                Write-PatchLog "Creating intelligent release..." -Level "INFO"
                
                if (-not $DryRun) {
                    # Determine if this should trigger an immediate release or wait for PR merge
                    $shouldCreateImmediateRelease = $false
                    $releaseReason = ""
                    
                    # Check for critical fixes that need immediate release
                    if ($Priority -eq "Critical") {
                        $shouldCreateImmediateRelease = $true
                        $releaseReason = "Critical priority fix requires immediate release"
                    }
                    
                    # Check for version-related changes that indicate a release
                    $versionFiles = @("*.psd1", "package.json", "version.txt", "**/version.json")
                    $changedFiles = git diff --name-only HEAD~1 HEAD 2>&1 | Where-Object { $_ -and $_.Trim() }
                    
                    foreach ($file in $changedFiles) {
                        foreach ($pattern in $versionFiles) {
                            if ($file -like $pattern) {
                                $shouldCreateImmediateRelease = $true
                                $releaseReason = "Version file changes detected: $file"
                                break
                            }
                        }
                        if ($shouldCreateImmediateRelease) { break }
                    }
                    
                    # Check for release-triggering keywords in description
                    $releaseKeywords = @("RELEASE", "VERSION", "HOTFIX", "CRITICAL", "SECURITY", "BREAKING")
                    foreach ($keyword in $releaseKeywords) {
                        if ($PatchDescription.ToUpper() -match $keyword) {
                            $shouldCreateImmediateRelease = $true
                            $releaseReason = "Release keyword detected: $keyword"
                            break
                        }
                    }
                    
                    if ($shouldCreateImmediateRelease) {
                        Write-PatchLog "Triggering immediate release: $releaseReason" -Level "INFO"
                        
                        try {
                            # Switch to main and pull latest (in case PR was already merged)
                            git checkout main 2>&1 | Out-Null
                            git pull origin main 2>&1 | Out-Null
                            
                            # Use Quick-Release script for automated release creation
                            $releaseScript = Join-Path $PSScriptRoot "Quick-Release.ps1"
                            if (Test-Path $releaseScript) {
                                Write-PatchLog "Using Quick-Release script for $ReleaseType release..." -Level "INFO"
                                
                                # Execute release with appropriate type
                                $releaseArgs = @("-Type", $ReleaseType)
                                if ($DryRun) {
                                    $releaseArgs += "-NoPush"  # Don't actually push in dry run
                                }
                                
                                $releaseResult = & $releaseScript @releaseArgs
                                
                                if ($LASTEXITCODE -eq 0) {
                                    Write-PatchLog "Release created successfully!" -Level "SUCCESS"
                                    
                                    # Get the created release info
                                    $latestTag = git describe --tags --abbrev=0 2>&1
                                    if ($latestTag) {
                                        Write-PatchLog "New release: $latestTag" -Level "SUCCESS"
                                        
                                        # Trigger GitHub Actions for build and deployment
                                        Write-PatchLog "Triggering GitHub Actions for release build..." -Level "INFO"
                                        
                                        try {
                                            # Trigger the release workflow
                                            $workflowTrigger = gh workflow run "build-release.yml" --ref $latestTag 2>&1
                                            if ($LASTEXITCODE -eq 0) {
                                                Write-PatchLog "GitHub Actions release workflow triggered successfully" -Level "SUCCESS"
                                            } else {
                                                Write-PatchLog "Warning: Failed to trigger GitHub Actions workflow: $workflowTrigger" -Level "WARN"
                                            }
                                        } catch {
                                            Write-PatchLog "Warning: Could not trigger GitHub Actions: $($_.Exception.Message)" -Level "WARN"
                                        }
                                    }
                                } else {
                                    Write-PatchLog "Release creation failed with exit code: $LASTEXITCODE" -Level "WARN"
                                    Write-PatchLog "Release output: $releaseResult" -Level "WARN"
                                }
                            } else {
                                # Fallback: Use git tag and gh release create
                                Write-PatchLog "Quick-Release script not found, using fallback release method..." -Level "WARN"
                                
                                # Get current version and increment
                                $currentTag = git describe --tags --abbrev=0 2>&1
                                if ($currentTag -and $currentTag -match '^v?(\d+)\.(\d+)\.(\d+)') {
                                    $major = [int]$matches[1]
                                    $minor = [int]$matches[2]
                                    $patch = [int]$matches[3]
                                    
                                    switch ($ReleaseType) {
                                        "major" { $major++; $minor = 0; $patch = 0 }
                                        "minor" { $minor++; $patch = 0 }
                                        default { $patch++ }
                                    }
                                    
                                    $newVersion = "v$major.$minor.$patch"
                                    
                                    # Create tag and release
                                    git tag $newVersion 2>&1 | Out-Null
                                    git push origin $newVersion 2>&1 | Out-Null
                                    
                                    # Create GitHub release
                                    $releaseBody = "Automated release created by PatchManager`n`n$PatchDescription"
                                    gh release create $newVersion --title $newVersion --notes $releaseBody 2>&1 | Out-Null
                                    
                                    if ($LASTEXITCODE -eq 0) {
                                        Write-PatchLog "Fallback release created: $newVersion" -Level "SUCCESS"
                                    } else {
                                        Write-PatchLog "Fallback release creation failed" -Level "WARN"
                                    }
                                } else {
                                    Write-PatchLog "Could not determine current version for release" -Level "WARN"
                                }
                            }
                        } catch {
                            Write-PatchLog "Release creation failed: $($_.Exception.Message)" -Level "ERROR"
                            # Don't fail the entire workflow for release issues
                        }
                        
                        # Switch back to the patch branch if it still exists
                        git show-ref --verify --quiet "refs/heads/$branchName" 2>&1 | Out-Null
                        if ($LASTEXITCODE -eq 0) {
                            git checkout $branchName 2>&1 | Out-Null
                        }
                    } else {
                        Write-PatchLog "Release creation scheduled for after PR merge (no immediate triggers found)" -Level "INFO"
                        Write-PatchLog "To force immediate release, use -Priority Critical or include release keywords" -Level "INFO"
                    }
                } else {
                    Write-PatchLog "DRY RUN: Would analyze patch for release triggers and potentially create $ReleaseType release" -Level "INFO"
                    Write-PatchLog "DRY RUN: Would check for: Critical priority, version file changes, release keywords" -Level "INFO"
                }
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

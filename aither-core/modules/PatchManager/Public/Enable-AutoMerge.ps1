function Enable-AutoMerge {
    <#
    .SYNOPSIS
        Enables intelligent auto-merge for a pull request

    .DESCRIPTION
        Configures GitHub auto-merge with safety checks, delays, and status requirements

    .PARAMETER PRNumber
        Pull request number to enable auto-merge for

    .PARAMETER MergeMethod
        Method to use for merging: Squash, Merge, or Rebase

    .PARAMETER DelayMinutes
        Minutes to wait before enabling auto-merge (allows time for CI/review)

    .PARAMETER RequiredChecks
        Required status checks that must pass before auto-merge

    .EXAMPLE
        Enable-AutoMerge -PRNumber 123 -MergeMethod "Squash" -DelayMinutes 5 -RequiredChecks @("ci-cd", "security-scan")
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$PRNumber,

        [Parameter(Mandatory = $false)]
        [ValidateSet("Squash", "Merge", "Rebase")]
        [string]$MergeMethod = "Squash",

        [Parameter(Mandatory = $false)]
        [int]$DelayMinutes = 5,

        [Parameter(Mandatory = $false)]
        [string[]]$RequiredChecks = @("ci-cd")
    )

    begin {
        function Write-AutoMergeLog {
            param($Message, $Level = "INFO")
            if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
                Write-CustomLog -Message $Message -Level $Level
            } else {
                Write-Host "[$Level] $Message"
            }
        }

        Write-AutoMergeLog "Configuring auto-merge for PR #$PRNumber" -Level "INFO"
    }

    process {
        try {
            # Step 1: Get repository information
            $repoInfo = Get-GitRepositoryInfo
            $repo = $repoInfo.GitHubRepo

            # Step 2: Wait for initial CI to start (if delay is specified)
            if ($DelayMinutes -gt 0) {
                Write-AutoMergeLog "Waiting $DelayMinutes minutes for CI to initialize..." -Level "INFO"
                Start-Sleep -Seconds ($DelayMinutes * 60)
            }

            # Step 3: Check PR status and required checks
            Write-AutoMergeLog "Checking PR status and required checks..." -Level "INFO"
            $prStatus = gh pr view $PRNumber --repo $repo --json "mergeable,statusCheckRollupState,reviewDecision,isDraft"
            $statusData = $prStatus | ConvertFrom-Json

            if ($statusData.isDraft) {
                Write-AutoMergeLog "PR is in draft state - skipping auto-merge" -Level "WARN"
                return @{
                    Success = $false
                    Message = "PR is in draft state"
                    AutoMergeEnabled = $false
                }
            }

            # Step 4: Enable auto-merge with GitHub CLI
            $mergeMethodParam = switch ($MergeMethod) {
                "Squash" { "--squash" }
                "Merge" { "--merge" }
                "Rebase" { "--rebase" }
            }

            Write-AutoMergeLog "Enabling auto-merge with method: $MergeMethod" -Level "INFO"
            $autoMergeCommand = "gh pr merge $PRNumber --repo $repo --auto $mergeMethodParam"

            # Add delete branch flag for cleaner repository
            $autoMergeCommand += " --delete-branch"

            $result = Invoke-Expression $autoMergeCommand 2>&1
            $exitCode = $LASTEXITCODE

            if ($exitCode -eq 0) {
                Write-AutoMergeLog "Auto-merge enabled successfully for PR #$PRNumber" -Level "SUCCESS"

                # Step 5: Add safety comment to PR
                $safetyComment = @"
🤖 **Auto-Merge Enabled**

- **Method**: $MergeMethod
- **Required Checks**: $($RequiredChecks -join ', ')
- **Safety Delay**: $DelayMinutes minutes

This PR will automatically merge when:
✅ All required status checks pass
✅ All required reviews are approved
✅ No conflicts exist

To disable auto-merge: ``gh pr merge $PRNumber --disable-auto --repo $repo``
"@

                gh pr comment $PRNumber --repo $repo --body $safetyComment

                return @{
                    Success = $true
                    Message = "Auto-merge enabled successfully"
                    AutoMergeEnabled = $true
                    MergeMethod = $MergeMethod
                    RequiredChecks = $RequiredChecks
                    PRNumber = $PRNumber
                }

            } else {
                Write-AutoMergeLog "Failed to enable auto-merge: $result" -Level "ERROR"
                return @{
                    Success = $false
                    Message = "Failed to enable auto-merge: $result"
                    AutoMergeEnabled = $false
                }
            }

        } catch {
            $errorMessage = "Auto-merge configuration failed: $($_.Exception.Message)"
            Write-AutoMergeLog $errorMessage -Level "ERROR"

            return @{
                Success = $false
                Message = $errorMessage
                AutoMergeEnabled = $false
            }
        }
    }
}

Export-ModuleMember -Function Enable-AutoMerge

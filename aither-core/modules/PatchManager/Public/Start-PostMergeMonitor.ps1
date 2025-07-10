#Requires -Version 7.0

<#
.SYNOPSIS
    Monitors a PR for merge completion and automatically runs cleanup

.DESCRIPTION
    This function creates a background monitoring process that:
    - Periodically checks if a PR has been merged
    - Automatically runs post-merge cleanup when merge is detected
    - Provides optional notifications when cleanup completes
    - Supports timeout and retry limits

.PARAMETER PullRequestNumber
    The PR number to monitor

.PARAMETER BranchName
    The local branch name to clean up after merge

.PARAMETER CheckIntervalSeconds
    How often to check for merge status (default: 30 seconds)

.PARAMETER TimeoutMinutes
    Maximum time to monitor before giving up (default: 60 minutes)

.PARAMETER NotificationCallback
    Optional script block to run when cleanup completes

.PARAMETER DryRun
    Preview monitoring actions without actual monitoring

.EXAMPLE
    Start-PostMergeMonitor -PullRequestNumber 123 -BranchName "patch/fix-module"
    # Start monitoring PR #123 with default settings

.EXAMPLE
    Start-PostMergeMonitor -PullRequestNumber 456 -BranchName "patch/feature" -CheckIntervalSeconds 60 -TimeoutMinutes 120
    # Monitor with custom intervals and timeout

.EXAMPLE
    Start-PostMergeMonitor -PullRequestNumber 789 -BranchName "patch/critical" -NotificationCallback {
        Write-Host "PR #789 has been merged and cleaned up!" -ForegroundColor Green
    }
    # Monitor with custom notification
#>

function Start-PostMergeMonitor {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true)]
        [int]$PullRequestNumber,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$BranchName,

        [Parameter(Mandatory = $false)]
        [int]$CheckIntervalSeconds = 30,

        [Parameter(Mandatory = $false)]
        [int]$TimeoutMinutes = 60,

        [Parameter(Mandatory = $false)]
        [scriptblock]$NotificationCallback,

        [Parameter(Mandatory = $false)]
        [switch]$DryRun
    )

    begin {
        # Write-CustomLog is guaranteed to be available from AitherCore orchestration
        # No explicit Logging import needed - trust the orchestration system

        function Write-MonitorLog {
            param($Message, $Level = 'INFO')
            if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
                Write-CustomLog -Message $Message -Level $Level
            } else {
                Write-Host "[$Level] $Message"
            }
        }

        Write-MonitorLog "Starting post-merge monitor for PR #$PullRequestNumber (branch: $BranchName)" -Level 'INFO'

        if ($DryRun) {
            Write-MonitorLog 'DRY RUN MODE: Monitoring preview only' -Level 'WARN'
        }
    }

    process {
        try {
            if ($DryRun) {
                Write-MonitorLog "DRY RUN: Would monitor PR #$PullRequestNumber every $CheckIntervalSeconds seconds for $TimeoutMinutes minutes" -Level 'INFO'
                Write-MonitorLog "DRY RUN: Would clean up branch '$BranchName' when merge is detected" -Level 'INFO'
                if ($NotificationCallback) {
                    Write-MonitorLog "DRY RUN: Would run notification callback when cleanup completes" -Level 'INFO'
                }
                return @{
                    Success = $true
                    Message = 'Dry run completed'
                    Monitoring = $false
                    DryRun = $true
                }
            }

            # Verify GitHub CLI is available
            if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
                throw "GitHub CLI (gh) is required for PR monitoring"
            }

            # Get repository info
            $repoInfo = Get-GitRepositoryInfo
            if (-not $repoInfo) {
                throw "Could not determine repository information"
            }

            Write-MonitorLog "Repository: $($repoInfo.GitHubRepo)" -Level 'INFO'
            Write-MonitorLog "Check interval: $CheckIntervalSeconds seconds" -Level 'INFO'
            Write-MonitorLog "Timeout: $TimeoutMinutes minutes" -Level 'INFO'

            # Create monitoring script block
            $monitoringScript = {
                param($PRNumber, $BranchName, $RepoInfo, $CheckInterval, $TimeoutMinutes, $NotificationCallback)

                $startTime = Get-Date
                $timeoutTime = $startTime.AddMinutes($TimeoutMinutes)
                $cleanupCompleted = $false

                while ((Get-Date) -lt $timeoutTime -and -not $cleanupCompleted) {
                    try {
                        # Check PR status
                        $prStatus = gh pr view $PRNumber --repo $RepoInfo.GitHubRepo --json "state,merged" 2>&1

                        if ($LASTEXITCODE -eq 0) {
                            $prData = $prStatus | ConvertFrom-Json

                            if ($prData.merged) {
                                # PR has been merged! Run cleanup
                                Write-Host "✓ PR #$PRNumber has been merged, starting cleanup..." -ForegroundColor Green

                                # Import PatchManager module in the job context
                                $moduleBase = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
                                Import-Module (Join-Path $moduleBase 'PatchManager.psm1') -Force

                                # Run cleanup (includes automatic version tagging)
                                $cleanupResult = Invoke-PostMergeCleanup -BranchName $BranchName -PullRequestNumber $PRNumber -ValidateMerge

                                if ($cleanupResult.Success) {
                                    Write-Host "✓ Post-merge cleanup completed successfully" -ForegroundColor Green
                                    
                                    # Additional automatic version tagging check (fallback)
                                    try {
                                        if (Get-Command Invoke-AutomaticVersionTagging -ErrorAction SilentlyContinue) {
                                            $taggingResult = Invoke-AutomaticVersionTagging -Silent
                                            if ($taggingResult.Success -and $taggingResult.TagCreated) {
                                                Write-Host "✅ Automatic version tag created: $($taggingResult.TagName)" -ForegroundColor Green
                                                Write-Host "🚀 Release workflow should now trigger automatically" -ForegroundColor Cyan
                                            }
                                        }
                                    } catch {
                                        Write-Host "Warning: Automatic version tagging check failed: $($_.Exception.Message)" -ForegroundColor Yellow
                                    }

                                    # Run notification callback if provided
                                    if ($NotificationCallback) {
                                        try {
                                            & $NotificationCallback
                                        } catch {
                                            Write-Host "Warning: Notification callback failed: $($_.Exception.Message)" -ForegroundColor Yellow
                                        }
                                    }
                                } else {
                                    Write-Host "✗ Post-merge cleanup failed: $($cleanupResult.Message)" -ForegroundColor Red
                                }

                                $cleanupCompleted = $true
                                break

                            } elseif ($prData.state -eq 'CLOSED') {
                                Write-Host "⚠ PR #$PRNumber was closed without merging, stopping monitor" -ForegroundColor Yellow
                                break

                            } else {
                                # Still open, continue monitoring
                                Start-Sleep -Seconds $CheckInterval
                            }
                        } else {
                            Write-Host "Warning: Could not check PR status: $prStatus" -ForegroundColor Yellow
                            Start-Sleep -Seconds $CheckInterval
                        }

                    } catch {
                        Write-Host "Error checking PR status: $($_.Exception.Message)" -ForegroundColor Red
                        Start-Sleep -Seconds $CheckInterval
                    }
                }

                if (-not $cleanupCompleted) {
                    Write-Host "⚠ Monitoring timed out after $TimeoutMinutes minutes" -ForegroundColor Yellow
                    Write-Host "You can manually run: Invoke-PostMergeCleanup -BranchName '$BranchName' -PullRequestNumber $PRNumber" -ForegroundColor Cyan
                }
            }

            # Start the monitoring job
            if ($PSCmdlet.ShouldProcess("PR #$PullRequestNumber", "Start background monitoring")) {
                $job = Start-Job -ScriptBlock $monitoringScript -ArgumentList $PullRequestNumber, $BranchName, $repoInfo, $CheckIntervalSeconds, $TimeoutMinutes, $NotificationCallback

                Write-MonitorLog "Background monitoring started (Job ID: $($job.Id))" -Level 'SUCCESS'
                Write-MonitorLog "Use 'Get-Job $($job.Id)' to check status, 'Receive-Job $($job.Id)' for output" -Level 'INFO'
                Write-MonitorLog "Or manually run cleanup later: Invoke-PostMergeCleanup -BranchName '$BranchName' -PullRequestNumber $PullRequestNumber" -Level 'INFO'

                return @{
                    Success = $true
                    Message = 'Post-merge monitoring started'
                    JobId = $job.Id
                    PullRequestNumber = $PullRequestNumber
                    BranchName = $BranchName
                    Monitoring = $true
                    TimeoutAt = (Get-Date).AddMinutes($TimeoutMinutes)
                    DryRun = $false
                }
            }

        } catch {
            $errorMessage = "Failed to start post-merge monitor: $($_.Exception.Message)"
            Write-MonitorLog $errorMessage -Level 'ERROR'

            return @{
                Success = $false
                Message = $errorMessage
                Monitoring = $false
                DryRun = $DryRun.IsPresent
            }
        }
    }
}

Export-ModuleMember -Function Start-PostMergeMonitor

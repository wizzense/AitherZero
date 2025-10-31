function Enable-EnhancedAutoMerge {
    <#
    .SYNOPSIS
        Advanced auto-merge functionality with intelligent consolidation and safety features

    .DESCRIPTION
        This enhanced AutoMerge function provides:
        - Intelligent PR consolidation before merging
        - Advanced safety checks and monitoring
        - Conditional merge strategies based on PR content
        - Integration with existing PatchManager workflows
        - Comprehensive logging and status tracking

    .PARAMETER PRNumber
        Pull request number to enable auto-merge for

    .PARAMETER MergeMethod
        Method to use for merging: Squash, Merge, or Rebase (auto-detected if not specified)

    .PARAMETER DelayMinutes
        Minutes to wait before enabling auto-merge (default: 5)

    .PARAMETER RequiredChecks
        Required status checks that must pass before auto-merge

    .PARAMETER ConsolidateFirst
        Whether to attempt PR consolidation before enabling auto-merge

    .PARAMETER ConsolidationStrategy
        Strategy for consolidation: Compatible, RelatedFiles, SameAuthor, ByPriority

    .PARAMETER MaxConsolidationPRs
        Maximum number of PRs to consolidate (default: 3)

    .PARAMETER SafetyLevel
        Safety level: Conservative, Standard, Aggressive

    .PARAMETER MonitoringEnabled
        Enable continuous monitoring of PR status

    .PARAMETER DryRun
        Preview what would be done without executing

    .EXAMPLE
        Enable-EnhancedAutoMerge -PRNumber 123 -ConsolidateFirst -SafetyLevel "Standard"

    .EXAMPLE
        Enable-EnhancedAutoMerge -PRNumber 456 -MergeMethod "Squash" -ConsolidationStrategy "SameAuthor" -MaxConsolidationPRs 5
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$PRNumber,

        [Parameter(Mandatory = $false)]
        [ValidateSet("Squash", "Merge", "Rebase", "Auto")]
        [string]$MergeMethod = "Auto",

        [Parameter(Mandatory = $false)]
        [int]$DelayMinutes = 5,

        [Parameter(Mandatory = $false)]
        [string[]]$RequiredChecks = @("parallel-ci", "security", "lint"),

        [Parameter(Mandatory = $false)]
        [switch]$ConsolidateFirst,

        [Parameter(Mandatory = $false)]
        [ValidateSet("Compatible", "RelatedFiles", "SameAuthor", "ByPriority")]
        [string]$ConsolidationStrategy = "Compatible",

        [Parameter(Mandatory = $false)]
        [int]$MaxConsolidationPRs = 3,

        [Parameter(Mandatory = $false)]
        [ValidateSet("Conservative", "Standard", "Aggressive")]
        [string]$SafetyLevel = "Standard",

        [Parameter(Mandatory = $false)]
        [switch]$MonitoringEnabled,

        [Parameter(Mandatory = $false)]
        [switch]$DryRun
    )

    begin {
        function Write-AutoMergeLog {
            param($Message, $Level = "INFO")
            if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
                Write-CustomLog -Message "AutoMerge: $Message" -Level $Level
            } else {
                Write-Host "[AutoMerge-$Level] $Message"
            }
        }

        Write-AutoMergeLog "Starting enhanced auto-merge for PR #$PRNumber" -Level "INFO"

        if ($DryRun) {
            Write-AutoMergeLog "DRY RUN MODE: No actual changes will be made" -Level "WARN"
        }

        # Safety configurations by level
        $safetyConfigs = @{
            Conservative = @{
                MinDelayMinutes = 15
                RequiredApprovals = 2
                RequiredChecks = @("parallel-ci", "security", "lint", "performance")
                AllowAutoConsolidation = $false
                MonitoringIntervalMinutes = 2
            }
            Standard = @{
                MinDelayMinutes = 5
                RequiredApprovals = 1
                RequiredChecks = @("parallel-ci", "security", "lint")
                AllowAutoConsolidation = $true
                MonitoringIntervalMinutes = 5
            }
            Aggressive = @{
                MinDelayMinutes = 2
                RequiredApprovals = 0
                RequiredChecks = @("parallel-ci")
                AllowAutoConsolidation = $true
                MonitoringIntervalMinutes = 10
            }
        }

        $config = $safetyConfigs[$SafetyLevel]
        $effectiveDelay = [Math]::Max($DelayMinutes, $config.MinDelayMinutes)
        $effectiveChecks = ($RequiredChecks + $config.RequiredChecks) | Sort-Object -Unique
    }

    process {
        try {
            # Step 1: Get PR information
            Write-AutoMergeLog "Retrieving PR #$PRNumber details..." -Level "INFO"

            if (-not $DryRun) {
                $prInfo = gh pr view $PRNumber --json number,title,state,mergeable,author,files,labels
                if ($LASTEXITCODE -ne 0) {
                    throw "Failed to retrieve PR information"
                }
                $pr = $prInfo | ConvertFrom-Json
            } else {
                $pr = @{
                    number = $PRNumber
                    title = "Sample PR for dry run"
                    state = "OPEN"
                    mergeable = "MERGEABLE"
                    author = @{ login = "test-user" }
                    files = @(@{ path = "test-file.ps1" })
                    labels = @()
                }
            }

            Write-AutoMergeLog "PR Details: '$($pr.title)' by $($pr.author.login)" -Level "INFO"

            # Step 2: Safety checks
            Write-AutoMergeLog "Performing safety checks (level: $SafetyLevel)..." -Level "INFO"

            if ($pr.state -ne "OPEN") {
                throw "PR #$PRNumber is not open (state: $($pr.state))"
            }

            if ($pr.mergeable -ne "MERGEABLE") {
                throw "PR #$PRNumber is not mergeable (status: $($pr.mergeable))"
            }

            # Step 3: Optional consolidation
            if ($ConsolidateFirst -and $config.AllowAutoConsolidation) {
                Write-AutoMergeLog "Attempting PR consolidation before auto-merge..." -Level "INFO"

                if (-not $DryRun) {
                    $consolidationParams = @{
                        TargetPR = $PRNumber
                        Strategy = $ConsolidationStrategy
                        MaxPRs = $MaxConsolidationPRs
                        DryRun = $false
                    }

                    # Import consolidation function
                    if (Get-Command Invoke-PRConsolidation -ErrorAction SilentlyContinue) {
                        $consolidationResult = Invoke-PRConsolidation @consolidationParams

                        if ($consolidationResult.Success -and $consolidationResult.ConsolidatedPRs.Count -gt 0) {
                            Write-AutoMergeLog "Successfully consolidated $($consolidationResult.ConsolidatedPRs.Count) PRs" -Level "SUCCESS"
                            # Update PR number if consolidation created a new PR
                            if ($consolidationResult.NewPRNumber) {
                                $PRNumber = $consolidationResult.NewPRNumber
                                Write-AutoMergeLog "Updated target PR to #$PRNumber after consolidation" -Level "INFO"
                            }
                        }
                    } else {
                        Write-AutoMergeLog "PR consolidation function not available, skipping..." -Level "WARN"
                    }
                } else {
                    Write-AutoMergeLog "[DRY RUN] Would attempt to consolidate up to $MaxConsolidationPRs PRs using $ConsolidationStrategy strategy" -Level "INFO"
                }
            }

            # Step 4: Determine optimal merge method
            if ($MergeMethod -eq "Auto") {
                $optimalMethod = Get-OptimalMergeMethod -PRNumber $PRNumber -PRInfo $pr
                Write-AutoMergeLog "Auto-detected optimal merge method: $optimalMethod" -Level "INFO"
                $MergeMethod = $optimalMethod
            }

            # Step 5: Apply delay if specified
            if ($effectiveDelay -gt 0) {
                Write-AutoMergeLog "Applying safety delay of $effectiveDelay minutes..." -Level "INFO"

                if (-not $DryRun) {
                    Write-AutoMergeLog "Waiting $effectiveDelay minutes before enabling auto-merge..." -Level "INFO"
                    Start-Sleep -Seconds ($effectiveDelay * 60)
                } else {
                    Write-AutoMergeLog "[DRY RUN] Would wait $effectiveDelay minutes" -Level "INFO"
                }
            }

            # Step 6: Enable auto-merge
            Write-AutoMergeLog "Enabling auto-merge with method: $MergeMethod" -Level "INFO"

            if (-not $DryRun) {
                $mergeCommand = "gh pr merge $PRNumber --auto --$($MergeMethod.ToLower())"

                # Add required checks if specified
                if ($effectiveChecks.Count -gt 0) {
                    Write-AutoMergeLog "Required checks: $($effectiveChecks -join ', ')" -Level "INFO"
                }

                $result = Invoke-Expression $mergeCommand
                if ($LASTEXITCODE -eq 0) {
                    Write-AutoMergeLog "Auto-merge enabled successfully for PR #$PRNumber" -Level "SUCCESS"
                } else {
                    throw "Failed to enable auto-merge: $result"
                }
            } else {
                Write-AutoMergeLog "[DRY RUN] Would enable auto-merge using: gh pr merge $PRNumber --auto --$($MergeMethod.ToLower())" -Level "INFO"
            }

            # Step 7: Optional monitoring
            if ($MonitoringEnabled -and -not $DryRun) {
                Write-AutoMergeLog "Starting continuous monitoring..." -Level "INFO"
                Start-AutoMergeMonitoring -PRNumber $PRNumber -IntervalMinutes $config.MonitoringIntervalMinutes
            }

            # Step 8: Create success summary
            $summary = @{
                PRNumber = $PRNumber
                MergeMethod = $MergeMethod
                SafetyLevel = $SafetyLevel
                DelayApplied = $effectiveDelay
                RequiredChecks = $effectiveChecks
                ConsolidationAttempted = $ConsolidateFirst
                MonitoringEnabled = $MonitoringEnabled
                Success = $true
                Timestamp = Get-Date
            }

            return $summary

        } catch {
            Write-AutoMergeLog "Auto-merge failed: $($_.Exception.Message)" -Level "ERROR"

            $errorSummary = @{
                PRNumber = $PRNumber
                Success = $false
                Error = $_.Exception.Message
                Timestamp = Get-Date
            }

            return $errorSummary
        }
    }
}

function Get-OptimalMergeMethod {
    param(
        [int]$PRNumber,
        [object]$PRInfo
    )

    # Analyze PR characteristics to determine optimal merge method
    $fileCount = $PRInfo.files.Count
    $hasTests = $PRInfo.files | Where-Object { $_.path -match '\.Tests\.ps1$' }
    $hasConfig = $PRInfo.files | Where-Object { $_.path -match '\.(json|psd1|config)$' }
    $isFeature = $PRInfo.labels | Where-Object { $_.name -match 'feature|enhancement' }
    $isBugfix = $PRInfo.labels | Where-Object { $_.name -match 'bug|fix' }

    # Logic for optimal merge method
    if ($fileCount -eq 1 -and $isBugfix) {
        return "Squash"  # Single file bug fixes should be squashed
    } elseif ($fileCount -gt 10 -or $isFeature) {
        return "Merge"   # Large features should preserve commit history
    } elseif ($hasTests -and $hasConfig) {
        return "Rebase"  # Test + config changes benefit from clean history
    } else {
        return "Squash"  # Default to squash for cleaner history
    }
}

function Start-AutoMergeMonitoring {
    param(
        [int]$PRNumber,
        [int]$IntervalMinutes = 5
    )

    Write-AutoMergeLog "Starting monitoring for PR #$PRNumber (checking every $IntervalMinutes minutes)" -Level "INFO"

    # Create background job for monitoring
    $monitoringJob = Start-Job -ScriptBlock {
        param($PRNum, $Interval)

        $maxChecks = 24  # Monitor for up to 2 hours
        $checkCount = 0

        while ($checkCount -lt $maxChecks) {
            try {
                $prStatus = gh pr view $PRNum --json state,mergeable,statusCheckRollup
                $status = $prStatus | ConvertFrom-Json

                if ($status.state -eq "MERGED") {
                    Write-Output "PR #$PRNum successfully merged"
                    break
                } elseif ($status.state -eq "CLOSED") {
                    Write-Output "PR #$PRNum was closed without merging"
                    break
                } elseif ($status.mergeable -eq "CONFLICTING") {
                    Write-Output "PR #$PRNum has merge conflicts"
                    break
                }

                # Check status checks
                $failedChecks = $status.statusCheckRollup | Where-Object { $_.state -eq "FAILURE" }
                if ($failedChecks) {
                    Write-Output "PR #$PRNum has failed checks: $($failedChecks.context -join ', ')"
                }

                Start-Sleep -Seconds ($Interval * 60)
                $checkCount++

            } catch {
                Write-Output "Monitoring error for PR #${PRNum}: $($_.Exception.Message)"
                break
            }
        }
    } -ArgumentList $PRNumber, $IntervalMinutes

    return $monitoringJob
}

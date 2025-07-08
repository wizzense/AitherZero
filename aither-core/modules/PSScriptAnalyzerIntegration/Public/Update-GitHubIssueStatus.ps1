function Update-GitHubIssueStatus {
    <#
    .SYNOPSIS
        Updates GitHub Issues status based on PSScriptAnalyzer findings and .bugz file changes

    .DESCRIPTION
        This function synchronizes GitHub Issues with the current state of PSScriptAnalyzer findings,
        updating issue status, adding comments, and managing the issue lifecycle.

    .PARAMETER Path
        Directory path to scan for .bugz files and current findings

    .PARAMETER RepositoryOwner
        GitHub repository owner (defaults to current repository)

    .PARAMETER RepositoryName
        GitHub repository name (defaults to current repository)

    .PARAMETER DryRun
        If specified, shows what updates would be made without actually making them

    .PARAMETER AutoClose
        Automatically close issues when findings are no longer detected

    .PARAMETER GitHubToken
        GitHub personal access token (uses GITHUB_TOKEN environment variable if not specified)

    .EXAMPLE
        Update-GitHubIssueStatus -Path "./aither-core/modules" -AutoClose

        Updates all PSScriptAnalyzer-related GitHub Issues based on current findings

    .EXAMPLE
        Update-GitHubIssueStatus -Path "./aither-core/modules/PatchManager" -DryRun

        Shows what issue updates would be made without actually making them
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $false)]
        [string]$RepositoryOwner,

        [Parameter(Mandatory = $false)]
        [string]$RepositoryName,

        [Parameter(Mandatory = $false)]
        [switch]$DryRun,

        [Parameter(Mandatory = $false)]
        [switch]$AutoClose,

        [Parameter(Mandatory = $false)]
        [string]$GitHubToken
    )

    try {
        $resolvedPath = Resolve-Path $Path -ErrorAction Stop

        # Initialize GitHub CLI availability check
        if (-not (Get-Command 'gh' -ErrorAction SilentlyContinue)) {
            throw "GitHub CLI (gh) not available. Please install GitHub CLI to manage issues."
        }

        # Get repository information
        if (-not $RepositoryOwner -or -not $RepositoryName) {
            try {
                $repoInfo = & gh repo view --json owner,name | ConvertFrom-Json
                if (-not $RepositoryOwner) { $RepositoryOwner = $repoInfo.owner.login }
                if (-not $RepositoryName) { $RepositoryName = $repoInfo.name }
            }
            catch {
                throw "Failed to determine repository information: $($_.Exception.Message)"
            }
        }

        # Set up GitHub token if provided
        if ($GitHubToken) {
            $env:GITHUB_TOKEN = $GitHubToken
        }

        if ($script:UseCustomLogging) {
            Write-CustomLog -Level 'INFO' -Message "Starting GitHub Issues status update for: $resolvedPath"
        } else {
            Write-Host "🔄 Updating GitHub Issues status for: $resolvedPath" -ForegroundColor Cyan
        }

        # Get all existing PSScriptAnalyzer issues
        $existingIssues = @()
        try {
            $searchQuery = "repo:$RepositoryOwner/$RepositoryName is:issue label:psscriptanalyzer"
            $allIssues = & gh issue list --search $searchQuery --json number,title,labels,state,body,assignees --limit 100 | ConvertFrom-Json
            $existingIssues = $allIssues | Where-Object { $_.labels | Where-Object { $_.name -eq 'psscriptanalyzer' } }

            if ($script:UseCustomLogging) {
                Write-CustomLog -Level 'INFO' -Message "Found $($existingIssues.Count) existing PSScriptAnalyzer issues"
            } else {
                Write-Host "📋 Found $($existingIssues.Count) existing PSScriptAnalyzer issues" -ForegroundColor White
            }
        }
        catch {
            if ($script:UseCustomLogging) {
                Write-CustomLog -Level 'WARNING' -Message "Failed to retrieve existing issues: $($_.Exception.Message)"
            } else {
                Write-Warning "Failed to retrieve existing issues: $($_.Exception.Message)"
            }
        }

        # Get current PSScriptAnalyzer findings
        $currentFindings = @()
        try {
            if (Get-Command 'Start-DirectoryAudit' -ErrorAction SilentlyContinue) {
                $auditResult = Start-DirectoryAudit -Path $resolvedPath -UpdateDocumentation:$false
                foreach ($dirResult in $auditResult.DirectoryResults) {
                    $currentFindings += $dirResult.Results
                }
            } else {
                # Fallback to direct PSScriptAnalyzer
                $settingsPath = Join-Path $script:ProjectRoot "PSScriptAnalyzerSettings.psd1"
                $analyzerParams = @{
                    Path = $resolvedPath
                    Recurse = $true
                }

                if (Test-Path $settingsPath) {
                    $analyzerParams.Settings = $settingsPath
                }

                $currentFindings = Invoke-ScriptAnalyzer @analyzerParams
            }
        }
        catch {
            if ($script:UseCustomLogging) {
                Write-CustomLog -Level 'ERROR' -Message "Failed to get current PSScriptAnalyzer findings: $($_.Exception.Message)"
            } else {
                Write-Error "Failed to get current PSScriptAnalyzer findings: $($_.Exception.Message)"
            }
            throw
        }

        # Load .bugz files for additional context
        $bugzData = @{}
        $bugzFiles = Get-ChildItem -Path $resolvedPath -Name ".bugz" -Recurse -ErrorAction SilentlyContinue
        foreach ($bugzFile in $bugzFiles) {
            try {
                $bugzPath = Join-Path $resolvedPath $bugzFile.FullName
                $bugzContent = Get-Content $bugzPath | ConvertFrom-Json
                $bugzData[$bugzContent.directory] = $bugzContent
            }
            catch {
                if ($script:UseCustomLogging) {
                    Write-CustomLog -Level 'WARNING' -Message "Failed to load .bugz file $($bugzFile.FullName): $($_.Exception.Message)"
                }
            }
        }

        # Process each existing issue
        $updatedIssues = @()
        $closedIssues = @()
        $commentedIssues = @()
        $errors = @()

        foreach ($issue in $existingIssues) {
            try {
                # Extract issue metadata from title and body
                $issueRuleName = $null
                $issueFileName = $null
                $issueLine = $null

                # Parse title: [SEVERITY] RuleName in FileName
                if ($issue.title -match '\[(?:ERROR|WARNING|INFO)\]\s+(\w+)\s+in\s+(.+)') {
                    $issueRuleName = $matches[1]
                    $issueFileName = $matches[2]
                }

                # Parse body for line number
                if ($issue.body -match 'Line (\d+)') {
                    $issueLine = [int]$matches[1]
                }

                if (-not $issueRuleName) {
                    if ($script:UseCustomLogging) {
                        Write-CustomLog -Level 'WARNING' -Message "Could not parse rule name from issue #$($issue.number): $($issue.title)"
                    }
                    continue
                }

                # Find corresponding current finding
                $correspondingFinding = $currentFindings | Where-Object {
                    $_.RuleName -eq $issueRuleName -and
                    (Split-Path $_.ScriptPath -Leaf) -eq $issueFileName -and
                    ($issueLine -eq $null -or $_.Line -eq $issueLine)
                } | Select-Object -First 1

                # Check .bugz data for additional context
                $bugzEntry = $null
                foreach ($bugzDir in $bugzData.Keys) {
                    $bugzEntry = $bugzData[$bugzDir].findings | Where-Object {
                        $_.ruleName -eq $issueRuleName -and
                        $_.file -eq $issueFileName -and
                        ($issueLine -eq $null -or $_.line -eq $issueLine)
                    } | Select-Object -First 1

                    if ($bugzEntry) { break }
                }

                # Determine action based on current state
                $actionNeeded = $null
                $actionReason = $null
                $newStatus = $issue.state

                if (-not $correspondingFinding) {
                    # Finding no longer exists
                    if ($bugzEntry -and $bugzEntry.status -eq 'resolved') {
                        $actionNeeded = 'close-resolved'
                        $actionReason = 'Finding has been resolved and is no longer detected'
                    } elseif ($AutoClose) {
                        $actionNeeded = 'close-auto'
                        $actionReason = 'Finding is no longer detected by PSScriptAnalyzer'
                    } else {
                        $actionNeeded = 'comment-missing'
                        $actionReason = 'Finding is no longer detected - consider closing this issue'
                    }
                } elseif ($bugzEntry) {
                    # Finding exists and has .bugz entry
                    switch ($bugzEntry.status) {
                        'resolved' {
                            if ($issue.state -eq 'open') {
                                $actionNeeded = 'close-resolved'
                                $actionReason = 'Finding has been marked as resolved in .bugz file'
                            }
                        }
                        'ignored' {
                            if ($issue.state -eq 'open') {
                                $actionNeeded = 'close-ignored'
                                $actionReason = "Finding has been ignored: $($bugzEntry.ignoreReason)"
                            }
                        }
                        'open' {
                            # Check if issue needs status update comment
                            if ($bugzEntry.notes -and $bugzEntry.notes.Count -gt 0) {
                                $actionNeeded = 'comment-update'
                                $actionReason = "Status update from .bugz file: $($bugzEntry.notes[-1])"
                            }
                        }
                    }
                } else {
                    # Finding exists but no .bugz entry - might need comment about tracking
                    if ((Get-Date) - [DateTime]::Parse($issue.created_at) -gt (New-TimeSpan -Days 7)) {
                        $actionNeeded = 'comment-stale'
                        $actionReason = 'This issue has been open for over a week without .bugz tracking'
                    }
                }

                # Perform the action
                if ($actionNeeded -and -not $DryRun) {
                    switch ($actionNeeded) {
                        'close-resolved' {
                            & gh issue close $issue.number --comment "✅ Closing issue: $actionReason"
                            $closedIssues += @{
                                Number = $issue.number
                                Title = $issue.title
                                Reason = $actionReason
                                Action = 'closed-resolved'
                            }
                        }
                        'close-auto' {
                            & gh issue close $issue.number --comment "🤖 Auto-closing: $actionReason"
                            $closedIssues += @{
                                Number = $issue.number
                                Title = $issue.title
                                Reason = $actionReason
                                Action = 'closed-auto'
                            }
                        }
                        'close-ignored' {
                            & gh issue close $issue.number --comment "🚫 Closing issue: $actionReason"
                            $closedIssues += @{
                                Number = $issue.number
                                Title = $issue.title
                                Reason = $actionReason
                                Action = 'closed-ignored'
                            }
                        }
                        'comment-missing' {
                            & gh issue comment $issue.number --body "🔍 **Status Update**: This finding is no longer detected by PSScriptAnalyzer. Consider closing this issue if it has been resolved.`n`n*Automated update from PSScriptAnalyzerIntegration*"
                            $commentedIssues += @{
                                Number = $issue.number
                                Title = $issue.title
                                Comment = 'finding-missing'
                            }
                        }
                        'comment-update' {
                            & gh issue comment $issue.number --body "📋 **Status Update**: $actionReason`n`n*Automated update from PSScriptAnalyzerIntegration*"
                            $commentedIssues += @{
                                Number = $issue.number
                                Title = $issue.title
                                Comment = 'status-update'
                            }
                        }
                        'comment-stale' {
                            & gh issue comment $issue.number --body "⏰ **Stale Issue Notice**: $actionReason. Please update the .bugz file with current status or close this issue if resolved.`n`n*Automated update from PSScriptAnalyzerIntegration*"
                            $commentedIssues += @{
                                Number = $issue.number
                                Title = $issue.title
                                Comment = 'stale-warning'
                            }
                        }
                    }
                } elseif ($actionNeeded -and $DryRun) {
                    $updatedIssues += @{
                        Number = $issue.number
                        Title = $issue.title
                        CurrentState = $issue.state
                        Action = $actionNeeded
                        Reason = $actionReason
                    }
                }

                if ($script:UseCustomLogging) {
                    Write-CustomLog -Level 'DEBUG' -Message "Processed issue #$($issue.number): $actionNeeded"
                }

            }
            catch {
                $error = "Failed to process issue #$($issue.number): $($_.Exception.Message)"
                $errors += $error

                if ($script:UseCustomLogging) {
                    Write-CustomLog -Level 'ERROR' -Message $error
                } else {
                    Write-Error $error
                }
            }
        }

        # Generate summary
        $summary = @{
            ExistingIssues = $existingIssues.Count
            UpdatedIssues = $updatedIssues.Count
            ClosedIssues = $closedIssues.Count
            CommentedIssues = $commentedIssues.Count
            Errors = $errors.Count
            Details = @{
                Updated = $updatedIssues
                Closed = $closedIssues
                Commented = $commentedIssues
                Errors = $errors
            }
            Repository = "$RepositoryOwner/$RepositoryName"
            DryRun = $DryRun.IsPresent
            AutoClose = $AutoClose.IsPresent
        }

        # Display summary
        if ($script:UseCustomLogging) {
            Write-CustomLog -Level 'SUCCESS' -Message "GitHub Issues status update completed: $($closedIssues.Count) closed, $($commentedIssues.Count) commented, $($errors.Count) errors"
        } else {
            Write-Host "`n📊 GitHub Issues Update Summary:" -ForegroundColor Cyan
            Write-Host "  📋 Existing issues: $($summary.ExistingIssues)" -ForegroundColor White

            if ($DryRun) {
                Write-Host "  🔍 Would update: $($summary.UpdatedIssues)" -ForegroundColor Yellow
            } else {
                Write-Host "  ✅ Closed: $($summary.ClosedIssues)" -ForegroundColor Green
                Write-Host "  💬 Commented: $($summary.CommentedIssues)" -ForegroundColor Blue
            }

            Write-Host "  ❌ Errors: $($summary.Errors)" -ForegroundColor Red

            if ($DryRun -and $updatedIssues.Count -gt 0) {
                Write-Host "`n🔍 Planned Updates:" -ForegroundColor Yellow
                foreach ($update in $updatedIssues) {
                    Write-Host "  #$($update.Number): $($update.Action) - $($update.Reason)" -ForegroundColor Gray
                }
            }
        }

        return $summary
    }
    catch {
        if ($script:UseCustomLogging) {
            Write-CustomLog -Level 'ERROR' -Message "Failed to update GitHub Issues status: $($_.Exception.Message)"
        } else {
            Write-Error "Failed to update GitHub Issues status: $($_.Exception.Message)"
        }
        throw
    }
}

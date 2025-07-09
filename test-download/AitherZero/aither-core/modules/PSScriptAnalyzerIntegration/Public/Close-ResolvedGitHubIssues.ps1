function Close-ResolvedGitHubIssues {
    <#
    .SYNOPSIS
        Closes GitHub Issues for PSScriptAnalyzer findings that have been resolved

    .DESCRIPTION
        This function identifies and closes GitHub Issues for PSScriptAnalyzer findings that are
        no longer present in the codebase or have been marked as resolved in .bugz files.
        It provides comprehensive lifecycle management for automated issue resolution.

    .PARAMETER Path
        Directory path to scan for resolved findings

    .PARAMETER RepositoryOwner
        GitHub repository owner (defaults to current repository)

    .PARAMETER RepositoryName
        GitHub repository name (defaults to current repository)

    .PARAMETER DryRun
        If specified, shows what issues would be closed without actually closing them

    .PARAMETER Force
        Force closure of issues even if they have recent activity

    .PARAMETER GitHubToken
        GitHub personal access token (uses GITHUB_TOKEN environment variable if not specified)

    .PARAMETER MaxAge
        Maximum age in days for issues to be considered for auto-closure (default: 30)

    .EXAMPLE
        Close-ResolvedGitHubIssues -Path "./aither-core/modules" -DryRun

        Shows what PSScriptAnalyzer issues would be closed without actually closing them

    .EXAMPLE
        Close-ResolvedGitHubIssues -Path "./aither-core/modules/PatchManager" -Force

        Closes all resolved issues in the PatchManager module, even if they have recent activity
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
        [switch]$Force,

        [Parameter(Mandatory = $false)]
        [string]$GitHubToken,

        [Parameter(Mandatory = $false)]
        [int]$MaxAge = 30
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
            Write-CustomLog -Level 'INFO' -Message "Starting automated closure of resolved PSScriptAnalyzer issues for: $resolvedPath"
        } else {
            Write-Host "🔄 Closing resolved PSScriptAnalyzer issues for: $resolvedPath" -ForegroundColor Cyan
        }

        # Get all open PSScriptAnalyzer issues
        $openIssues = @()
        try {
            $searchQuery = "repo:$RepositoryOwner/$RepositoryName is:issue is:open label:psscriptanalyzer"
            $allIssues = & gh issue list --search $searchQuery --json number,title,labels,state,body,createdAt,updatedAt --limit 200 | ConvertFrom-Json
            $openIssues = $allIssues | Where-Object {
                $_.labels | Where-Object { $_.name -eq 'psscriptanalyzer' }
            }

            if ($script:UseCustomLogging) {
                Write-CustomLog -Level 'INFO' -Message "Found $($openIssues.Count) open PSScriptAnalyzer issues to evaluate"
            } else {
                Write-Host "📋 Found $($openIssues.Count) open PSScriptAnalyzer issues to evaluate" -ForegroundColor White
            }
        }
        catch {
            if ($script:UseCustomLogging) {
                Write-CustomLog -Level 'ERROR' -Message "Failed to retrieve open issues: $($_.Exception.Message)"
            } else {
                Write-Error "Failed to retrieve open issues: $($_.Exception.Message)"
            }
            throw
        }

        if ($openIssues.Count -eq 0) {
            if ($script:UseCustomLogging) {
                Write-CustomLog -Level 'INFO' -Message "No open PSScriptAnalyzer issues found to process"
            } else {
                Write-Host "✅ No open PSScriptAnalyzer issues found to process" -ForegroundColor Green
            }
            return @{
                ProcessedIssues = 0
                ClosedIssues = 0
                SkippedIssues = 0
                Errors = 0
                Details = @{
                    Closed = @()
                    Skipped = @()
                    Errors = @()
                }
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

        # Load .bugz files for resolved status
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

        # Process each open issue
        $closedIssues = @()
        $skippedIssues = @()
        $errors = @()

        foreach ($issue in $openIssues) {
            try {
                # Extract issue metadata
                $issueRuleName = $null
                $issueFileName = $null
                $issueLine = $null
                $issueModule = $null

                # Parse title: [SEVERITY] RuleName in FileName
                if ($issue.title -match '\[(?:ERROR|WARNING|INFO)\]\s+(\w+)\s+in\s+(.+)') {
                    $issueRuleName = $matches[1]
                    $issueFileName = $matches[2]
                }

                # Parse body for line number and module
                if ($issue.body -match 'Line (\d+)') {
                    $issueLine = [int]$matches[1]
                }

                if ($issue.body -match '\*\*Module:\*\*\s+(\w+)') {
                    $issueModule = $matches[1]
                }

                if (-not $issueRuleName) {
                    $skippedIssues += @{
                        Number = $issue.number
                        Title = $issue.title
                        Reason = "Could not parse rule name from issue title"
                        Action = 'skipped-unparseable'
                    }
                    continue
                }

                # Check if issue is within scope of current path
                $issueInScope = $false
                if ($issueModule) {
                    $modulePath = Join-Path $resolvedPath $issueModule -ErrorAction SilentlyContinue
                    $issueInScope = Test-Path $modulePath
                } else {
                    # Check if any current findings match this issue's path pattern
                    $issueInScope = $currentFindings | Where-Object {
                        (Split-Path $_.ScriptPath -Leaf) -eq $issueFileName
                    }
                }

                if (-not $issueInScope) {
                    $skippedIssues += @{
                        Number = $issue.number
                        Title = $issue.title
                        Reason = "Issue is outside the scope of the specified path"
                        Action = 'skipped-out-of-scope'
                    }
                    continue
                }

                # Check if corresponding finding still exists
                $correspondingFinding = $currentFindings | Where-Object {
                    $_.RuleName -eq $issueRuleName -and
                    (Split-Path $_.ScriptPath -Leaf) -eq $issueFileName -and
                    ($issueLine -eq $null -or $_.Line -eq $issueLine)
                } | Select-Object -First 1

                # Check .bugz data for resolution status
                $bugzEntry = $null
                $isMarkedResolved = $false
                foreach ($bugzDir in $bugzData.Keys) {
                    $bugzEntry = $bugzData[$bugzDir].findings | Where-Object {
                        $_.ruleName -eq $issueRuleName -and
                        $_.file -eq $issueFileName -and
                        ($issueLine -eq $null -or $_.line -eq $issueLine)
                    } | Select-Object -First 1

                    if ($bugzEntry) {
                        $isMarkedResolved = $bugzEntry.status -eq 'resolved'
                        break
                    }
                }

                # Determine if issue should be closed
                $shouldClose = $false
                $closeReason = ""
                $closeType = ""

                if (-not $correspondingFinding -and -not $isMarkedResolved) {
                    # Finding no longer exists and not marked as resolved
                    $shouldClose = $true
                    $closeReason = "Finding is no longer detected by PSScriptAnalyzer"
                    $closeType = "auto-resolved"
                } elseif ($isMarkedResolved) {
                    # Finding is marked as resolved in .bugz file
                    $shouldClose = $true
                    $closeReason = "Finding has been marked as resolved in .bugz file"
                    $closeType = "manually-resolved"
                } elseif (-not $correspondingFinding) {
                    # Finding doesn't exist but no .bugz entry - might be a false positive
                    $issueAge = (Get-Date) - [DateTime]::Parse($issue.createdAt)
                    if ($issueAge.Days -gt $MaxAge -or $Force) {
                        $shouldClose = $true
                        $closeReason = "Finding has been absent for $([math]::Round($issueAge.Days)) days"
                        $closeType = "aged-out"
                    } else {
                        $skippedIssues += @{
                            Number = $issue.number
                            Title = $issue.title
                            Reason = "Finding absent but issue too recent (age: $([math]::Round($issueAge.Days)) days)"
                            Action = 'skipped-too-recent'
                        }
                        continue
                    }
                } else {
                    # Finding still exists - don't close
                    $skippedIssues += @{
                        Number = $issue.number
                        Title = $issue.title
                        Reason = "Finding still exists in codebase"
                        Action = 'skipped-still-exists'
                    }
                    continue
                }

                # Close the issue
                if ($shouldClose) {
                    if ($DryRun) {
                        $closedIssues += @{
                            Number = $issue.number
                            Title = $issue.title
                            Reason = $closeReason
                            Action = "dry-run-$closeType"
                            WouldClose = $true
                        }

                        if ($script:UseCustomLogging) {
                            Write-CustomLog -Level 'INFO' -Message "DRY RUN: Would close issue #$($issue.number) - $closeReason"
                        } else {
                            Write-Host "  🔍 DRY RUN: Would close #$($issue.number) - $closeReason" -ForegroundColor Yellow
                        }
                    } else {
                        $closeComment = switch ($closeType) {
                            "auto-resolved" { "✅ Auto-closing: $closeReason`n`n*This issue was automatically closed by PSScriptAnalyzerIntegration because the finding is no longer detected.*" }
                            "manually-resolved" { "✅ Closing: $closeReason`n`n*This issue was closed because it has been marked as resolved in the .bugz tracking file.*" }
                            "aged-out" { "⏰ Auto-closing: $closeReason`n`n*This issue was automatically closed because the finding has been absent for an extended period.*" }
                            default { "✅ Closing: $closeReason" }
                        }

                        try {
                            & gh issue close $issue.number --comment $closeComment

                            $closedIssues += @{
                                Number = $issue.number
                                Title = $issue.title
                                Reason = $closeReason
                                Action = $closeType
                                ClosedAt = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ssZ')
                            }

                            if ($script:UseCustomLogging) {
                                Write-CustomLog -Level 'SUCCESS' -Message "Closed issue #$($issue.number): $($issue.title)"
                            } else {
                                Write-Host "  ✅ Closed #$($issue.number): $($issue.title)" -ForegroundColor Green
                            }
                        }
                        catch {
                            $error = "Failed to close issue #$($issue.number): $($_.Exception.Message)"
                            $errors += $error

                            if ($script:UseCustomLogging) {
                                Write-CustomLog -Level 'ERROR' -Message $error
                            } else {
                                Write-Error $error
                            }
                        }
                    }
                }
            }
            catch {
                $error = "Error processing issue #$($issue.number): $($_.Exception.Message)"
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
            ProcessedIssues = $openIssues.Count
            ClosedIssues = $closedIssues.Count
            SkippedIssues = $skippedIssues.Count
            Errors = $errors.Count
            Details = @{
                Closed = $closedIssues
                Skipped = $skippedIssues
                Errors = $errors
            }
            Repository = "$RepositoryOwner/$RepositoryName"
            DryRun = $DryRun.IsPresent
            Force = $Force.IsPresent
            MaxAge = $MaxAge
        }

        # Display summary
        if ($script:UseCustomLogging) {
            Write-CustomLog -Level 'SUCCESS' -Message "Issue closure completed: $($closedIssues.Count) closed, $($skippedIssues.Count) skipped, $($errors.Count) errors"
        } else {
            Write-Host "`n📊 Issue Closure Summary:" -ForegroundColor Cyan
            Write-Host "  📋 Issues processed: $($summary.ProcessedIssues)" -ForegroundColor White

            if ($DryRun) {
                Write-Host "  🔍 Would close: $($summary.ClosedIssues)" -ForegroundColor Yellow
            } else {
                Write-Host "  ✅ Closed: $($summary.ClosedIssues)" -ForegroundColor Green
            }

            Write-Host "  ⏭️  Skipped: $($summary.SkippedIssues)" -ForegroundColor Gray
            Write-Host "  ❌ Errors: $($summary.Errors)" -ForegroundColor Red

            if ($closedIssues.Count -gt 0) {
                Write-Host "`n🎯 Closed Issues:" -ForegroundColor Green
                foreach ($closed in $closedIssues | Select-Object -First 10) {
                    Write-Host "  #$($closed.Number): $($closed.Action) - $($closed.Reason)" -ForegroundColor Gray
                }
                if ($closedIssues.Count -gt 10) {
                    Write-Host "  ... and $($closedIssues.Count - 10) more" -ForegroundColor Gray
                }
            }
        }

        return $summary
    }
    catch {
        if ($script:UseCustomLogging) {
            Write-CustomLog -Level 'ERROR' -Message "Failed to close resolved GitHub Issues: $($_.Exception.Message)"
        } else {
            Write-Error "Failed to close resolved GitHub Issues: $($_.Exception.Message)"
        }
        throw
    }
}

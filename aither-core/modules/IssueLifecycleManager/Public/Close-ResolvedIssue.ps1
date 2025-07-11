function Close-ResolvedIssue {
    <#
    .SYNOPSIS
        Automatically closes resolved issues based on validation results
        
    .DESCRIPTION
        Checks if issues have been resolved by examining:
        - Commit messages that reference the issue
        - Validation results showing the issue is fixed
        - Test results confirming resolution
        - Manual resolution confirmation
        
    .PARAMETER IssueNumber
        Issue number to check and potentially close
        
    .PARAMETER ValidationResults
        Validation results confirming issue resolution
        
    .PARAMETER CommitSHA
        Commit SHA that resolved the issue
        
    .PARAMETER Force
        Force close without validation checks
        
    .EXAMPLE
        Close-ResolvedIssue -IssueNumber 123 -ValidationResults $results
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$IssueNumber,
        
        [Parameter()]
        [hashtable]$ValidationResults,
        
        [Parameter()]
        [string]$CommitSHA,
        
        [Parameter()]
        [switch]$Force
    )
    
    try {
        Write-CustomLog -Level INFO -Message "Checking issue #$IssueNumber for resolution"
        
        # Get issue details
        $issue = Get-IssueDetails -IssueNumber $IssueNumber
        
        if ($issue.state -eq 'closed') {
            Write-CustomLog -Level INFO -Message "Issue #$IssueNumber is already closed"
            return @{
                Success = $true
                AlreadyClosed = $true
                IssueNumber = $IssueNumber
            }
        }
        
        # Check if issue should be closed
        $shouldClose = $false
        $closeReason = ""
        
        if ($Force) {
            $shouldClose = $true
            $closeReason = "Forced closure"
        } elseif ($ValidationResults) {
            # Check if validation shows issue is resolved
            $resolved = Test-IssueResolution -Issue $issue -ValidationResults $ValidationResults
            if ($resolved.IsResolved) {
                $shouldClose = $true
                $closeReason = "Validation confirmed resolution: $($resolved.Reason)"
            }
        } elseif ($CommitSHA) {
            # Check if commit resolves the issue
            $commitResolves = Test-CommitResolvesIssue -CommitSHA $CommitSHA -IssueNumber $IssueNumber
            if ($commitResolves) {
                $shouldClose = $true
                $closeReason = "Resolved by commit $CommitSHA"
            }
        } else {
            # Check for resolution patterns in recent commits
            $resolutionCommit = Find-ResolutionCommit -IssueNumber $IssueNumber
            if ($resolutionCommit) {
                $shouldClose = $true
                $closeReason = "Resolved by commit $($resolutionCommit.SHA): $($resolutionCommit.Message)"
            }
        }
        
        if ($shouldClose) {
            # Add resolution comment
            $comment = @"
### Issue Resolved ✅

**Reason**: $closeReason
**Resolved**: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
**Resolution Time**: $(Get-ResolutionTime -Issue $issue)

$(if ($ValidationResults) {
@"

#### Validation Results
- Files Validated: $($ValidationResults.Summary.TotalFiles)
- All Checks Passed: ✅
"@
})

This issue is being automatically closed by the Issue Lifecycle Manager.
"@
            
            & gh issue comment $IssueNumber --body $comment
            
            # Close the issue
            & gh issue close $IssueNumber
            
            # Update audit trail
            $auditEntry = @{
                Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
                Action = 'Closed'
                IssueNumber = $IssueNumber
                Reason = $closeReason
                ResolutionTime = Get-ResolutionTime -Issue $issue
                ClosedBy = 'IssueLifecycleManager'
            }
            
            Add-AuditEntry -Entry $auditEntry
            
            # Update metrics
            $script:Metrics.IssuesClosed++
            $script:Metrics.ActiveIssues = $script:Metrics.ActiveIssues | Where-Object { $_ -ne $IssueNumber }
            
            # Update resolution time metrics
            Update-ResolutionMetrics -Issue $issue
            
            Write-CustomLog -Level SUCCESS -Message "Closed issue #$IssueNumber: $closeReason"
            
            return @{
                Success = $true
                IssueNumber = $IssueNumber
                CloseReason = $closeReason
                ResolutionTime = Get-ResolutionTime -Issue $issue
            }
        } else {
            Write-CustomLog -Level INFO -Message "Issue #$IssueNumber not ready for closure"
            
            return @{
                Success = $true
                IssueNumber = $IssueNumber
                Closed = $false
                Reason = "No resolution criteria met"
            }
        }
        
    } catch {
        Write-CustomLog -Level ERROR -Message "Failed to close issue #$IssueNumber: $_"
        
        return @{
            Success = $false
            IssueNumber = $IssueNumber
            Error = $_.Exception.Message
        }
    }
}

function Get-IssueDetails {
    param([int]$IssueNumber)
    
    $issueJson = & gh issue view $IssueNumber --json number,title,state,createdAt,labels,assignees,body
    return $issueJson | ConvertFrom-Json
}

function Test-IssueResolution {
    param(
        [object]$Issue,
        [hashtable]$ValidationResults
    )
    
    # Extract lifecycle metadata from issue body
    $metadata = Extract-LifecycleMetadata -Body $Issue.body
    
    if (-not $metadata) {
        return @{ IsResolved = $false; Reason = "No lifecycle metadata found" }
    }
    
    # Check based on issue source
    switch ($metadata.source) {
        'Validation' {
            # Check if validation errors are resolved
            if ($ValidationResults.Validators.Values | Where-Object { -not $_.Passed }) {
                return @{ IsResolved = $false; Reason = "Validation still failing" }
            } else {
                return @{ IsResolved = $true; Reason = "All validation checks passing" }
            }
        }
        
        'ErrorTracking' {
            # Check if specific error is resolved
            if ($metadata.sourceData.ErrorType -and $ValidationResults.Errors) {
                $matchingErrors = $ValidationResults.Errors | Where-Object {
                    $_.Type -eq $metadata.sourceData.ErrorType
                }
                if ($matchingErrors) {
                    return @{ IsResolved = $false; Reason = "Error still occurring" }
                }
            }
            return @{ IsResolved = $true; Reason = "Error no longer detected" }
        }
        
        'CodeAnalysis' {
            # Check if code analysis issues are resolved
            if ($metadata.sourceData.Rule -and $ValidationResults.Validators.CodeAnalysis) {
                $matchingFindings = $ValidationResults.Validators.CodeAnalysis.Findings |
                    Where-Object { $_.Rule -eq $metadata.sourceData.Rule }
                
                if ($matchingFindings) {
                    return @{ IsResolved = $false; Reason = "Code analysis rule still violated" }
                }
            }
            return @{ IsResolved = $true; Reason = "Code analysis issues resolved" }
        }
        
        default {
            return @{ IsResolved = $false; Reason = "Unknown issue source" }
        }
    }
}

function Test-CommitResolvesIssue {
    param(
        [string]$CommitSHA,
        [int]$IssueNumber
    )
    
    try {
        $commitMessage = & git log -1 --format=%B $CommitSHA
        
        $resolutionPatterns = $script:Config.autoClose.resolutionPatterns
        
        foreach ($pattern in $resolutionPatterns) {
            if ($commitMessage -match $pattern) {
                $resolvedIssue = [int]$matches[1]
                if ($resolvedIssue -eq $IssueNumber) {
                    return $true
                }
            }
        }
        
        return $false
    } catch {
        return $false
    }
}

function Find-ResolutionCommit {
    param([int]$IssueNumber)
    
    try {
        # Search recent commits for resolution patterns
        $recentCommits = & git log --oneline -n 100
        
        foreach ($commit in $recentCommits) {
            $sha = ($commit -split ' ')[0]
            $message = $commit.Substring($sha.Length + 1)
            
            foreach ($pattern in $script:Config.autoClose.resolutionPatterns) {
                if ($message -match $pattern) {
                    $resolvedIssue = [int]$matches[1]
                    if ($resolvedIssue -eq $IssueNumber) {
                        return @{
                            SHA = $sha
                            Message = $message
                        }
                    }
                }
            }
        }
        
        return $null
    } catch {
        return $null
    }
}

function Extract-LifecycleMetadata {
    param([string]$Body)
    
    if ($Body -match '<!-- LIFECYCLE_METADATA\s*(.+?)\s*-->') {
        try {
            return $matches[1] | ConvertFrom-Json
        } catch {
            return $null
        }
    }
    
    return $null
}

function Get-ResolutionTime {
    param([object]$Issue)
    
    $created = [DateTime]::Parse($Issue.createdAt)
    $resolved = Get-Date
    $duration = $resolved - $created
    
    if ($duration.TotalDays -gt 1) {
        return "$([Math]::Round($duration.TotalDays, 1)) days"
    } elseif ($duration.TotalHours -gt 1) {
        return "$([Math]::Round($duration.TotalHours, 1)) hours"
    } else {
        return "$([Math]::Round($duration.TotalMinutes, 0)) minutes"
    }
}

function Update-ResolutionMetrics {
    param([object]$Issue)
    
    $created = [DateTime]::Parse($Issue.createdAt)
    $resolved = Get-Date
    $resolutionHours = ($resolved - $created).TotalHours
    
    # Update average resolution time
    if ($script:Metrics.AverageResolutionTime -eq 0) {
        $script:Metrics.AverageResolutionTime = $resolutionHours
    } else {
        $totalIssues = $script:Metrics.IssuesClosed
        $currentAverage = $script:Metrics.AverageResolutionTime
        $script:Metrics.AverageResolutionTime = (($currentAverage * ($totalIssues - 1)) + $resolutionHours) / $totalIssues
    }
    
    # Save metrics
    Save-Metrics
}

function Save-Metrics {
    try {
        $script:Metrics | ConvertTo-Json -Depth 10 | Set-Content $script:MetricsPath
    } catch {
        Write-CustomLog -Level WARNING -Message "Failed to save metrics: $_"
    }
}
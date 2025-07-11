function New-AutomatedIssue {
    <#
    .SYNOPSIS
        Creates a new GitHub issue with automated lifecycle management
        
    .DESCRIPTION
        Creates GitHub issues with full lifecycle tracking, automatic assignment,
        labeling, and audit trail. Integrates with validation systems and error tracking.
        
    .PARAMETER Title
        Issue title
        
    .PARAMETER Body
        Issue body content (markdown supported)
        
    .PARAMETER Labels
        Array of labels to apply
        
    .PARAMETER Assignees
        Array of assignees (auto-detected if not specified)
        
    .PARAMETER Milestone
        Milestone to assign
        
    .PARAMETER Source
        Source system (Validation, ErrorTracking, Manual, etc.)
        
    .PARAMETER SourceData
        Additional data from source system
        
    .PARAMETER Priority
        Priority level (Critical, High, Medium, Low)
        
    .PARAMETER Dependencies
        Array of issue numbers this issue depends on
        
    .EXAMPLE
        New-AutomatedIssue -Title "Test failures in module X" -Body "..." -Source "TestValidation" -Priority "High"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Title,
        
        [Parameter(Mandatory = $true)]
        [string]$Body,
        
        [Parameter()]
        [string[]]$Labels = @(),
        
        [Parameter()]
        [string[]]$Assignees = @(),
        
        [Parameter()]
        [string]$Milestone,
        
        [Parameter()]
        [ValidateSet('Validation', 'ErrorTracking', 'Security', 'Performance', 'Manual', 'CI', 'CodeAnalysis')]
        [string]$Source = 'Manual',
        
        [Parameter()]
        [hashtable]$SourceData = @{},
        
        [Parameter()]
        [ValidateSet('Critical', 'High', 'Medium', 'Low')]
        [string]$Priority = 'Medium',
        
        [Parameter()]
        [int[]]$Dependencies = @()
    )
    
    try {
        Write-CustomLog -Level INFO -Message "Creating automated issue: $Title"
        
        # Auto-detect repository
        $repoInfo = Get-GitHubRepoInfo
        
        # Apply automatic labeling
        $autoLabels = Get-AutomaticLabels -Source $Source -Priority $Priority -SourceData $SourceData
        $allLabels = @($Labels) + $autoLabels | Select-Object -Unique
        
        # Auto-assign if configured
        if ($Assignees.Count -eq 0 -and $script:Config.assignment.autoAssign) {
            $Assignees = Get-AutomaticAssignees -Title $Title -Body $Body -SourceData $SourceData
        }
        
        # Add lifecycle metadata to body
        $enhancedBody = Add-LifecycleMetadata -Body $Body -Source $Source -SourceData $SourceData -Dependencies $Dependencies
        
        # Create the issue
        $issueArgs = @(
            'issue', 'create',
            '--repo', "$($repoInfo.Owner)/$($repoInfo.Name)",
            '--title', $Title,
            '--body', $enhancedBody
        )
        
        if ($allLabels.Count -gt 0) {
            $issueArgs += '--label'
            $issueArgs += ($allLabels -join ',')
        }
        
        if ($Assignees.Count -gt 0) {
            $issueArgs += '--assignee'
            $issueArgs += ($Assignees -join ',')
        }
        
        if ($Milestone) {
            $issueArgs += '--milestone'
            $issueArgs += $Milestone
        }
        
        $result = & gh @issueArgs
        $issueNumber = if ($result -match '#(\d+)') { $matches[1] } else { $null }
        
        if ($issueNumber) {
            # Create audit entry
            $auditEntry = @{
                Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
                Action = 'Created'
                IssueNumber = $issueNumber
                Title = $Title
                Source = $Source
                Priority = $Priority
                Labels = $allLabels
                Assignees = $Assignees
                Dependencies = $Dependencies
                Creator = $env:USER
            }
            
            Add-AuditEntry -Entry $auditEntry
            
            # Update metrics
            $script:Metrics.IssuesCreated++
            $script:Metrics.IssuesByCategory[$Source]++
            $script:Metrics.IssuesBySeverity[$Priority]++
            $script:Metrics.ActiveIssues += $issueNumber
            
            # Set up dependency tracking
            if ($Dependencies.Count -gt 0) {
                Set-IssueDependencies -IssueNumber $issueNumber -Dependencies $Dependencies
            }
            
            # Return issue details
            return @{
                Success = $true
                IssueNumber = $issueNumber
                IssueUrl = "https://github.com/$($repoInfo.Owner)/$($repoInfo.Name)/issues/$issueNumber"
                Title = $Title
                Labels = $allLabels
                Assignees = $Assignees
                Priority = $Priority
                Source = $Source
            }
        } else {
            throw "Failed to extract issue number from GitHub response"
        }
        
    } catch {
        Write-CustomLog -Level ERROR -Message "Failed to create issue: $_"
        
        return @{
            Success = $false
            Error = $_.Exception.Message
            Title = $Title
        }
    }
}

function Get-AutomaticLabels {
    param(
        [string]$Source,
        [string]$Priority,
        [hashtable]$SourceData
    )
    
    $labels = @()
    
    # Source-based labels
    $sourceLabels = @{
        'Validation' = 'validation-failure'
        'ErrorTracking' = 'automated-error'
        'Security' = 'security'
        'Performance' = 'performance'
        'CI' = 'ci-failure'
        'CodeAnalysis' = 'code-quality'
    }
    
    if ($sourceLabels.ContainsKey($Source)) {
        $labels += $sourceLabels[$Source]
    }
    
    # Priority labels
    $labels += "priority:$($Priority.ToLower())"
    
    # Automated label
    $labels += 'automated'
    
    # State label
    $labels += 'needs-triage'
    
    # Additional labels from source data
    if ($SourceData.ContainsKey('Module')) {
        $labels += "module:$($SourceData.Module.ToLower())"
    }
    
    if ($SourceData.ContainsKey('TestType')) {
        $labels += "test:$($SourceData.TestType.ToLower())"
    }
    
    if ($SourceData.ContainsKey('ErrorType')) {
        $labels += "error:$($SourceData.ErrorType.ToLower())"
    }
    
    return $labels
}

function Get-AutomaticAssignees {
    param(
        [string]$Title,
        [string]$Body,
        [hashtable]$SourceData
    )
    
    $assignees = @()
    
    # Check CODEOWNERS if enabled
    if ($script:Config.assignment.useCodeOwners -and $SourceData.ContainsKey('AffectedFiles')) {
        $codeownersPath = Join-Path $script:ProjectRoot ".github/CODEOWNERS"
        if (Test-Path $codeownersPath) {
            $codeowners = Get-Content $codeownersPath
            
            foreach ($file in $SourceData.AffectedFiles) {
                $matchingRule = $codeowners | Where-Object {
                    $_ -notmatch '^#' -and $_ -match '\S' -and
                    ($file -like ($_ -split '\s+')[0])
                } | Select-Object -First 1
                
                if ($matchingRule) {
                    $owners = ($matchingRule -split '\s+')[1..100] | Where-Object { $_ -match '^@' }
                    $assignees += $owners -replace '^@', ''
                }
            }
        }
    }
    
    # Use default assignee if no one found
    if ($assignees.Count -eq 0 -and $script:Config.assignment.defaultAssignee) {
        $assignees += $script:Config.assignment.defaultAssignee
    }
    
    return $assignees | Select-Object -Unique
}

function Add-LifecycleMetadata {
    param(
        [string]$Body,
        [string]$Source,
        [hashtable]$SourceData,
        [int[]]$Dependencies
    )
    
    $metadata = @{
        source = $Source
        timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        automationId = [guid]::NewGuid().ToString()
        sourceData = $SourceData
        dependencies = $Dependencies
    }
    
    $metadataJson = $metadata | ConvertTo-Json -Compress
    
    return @"
$Body

<!-- LIFECYCLE_METADATA
$metadataJson
-->

---
*This issue was automatically created by the Issue Lifecycle Manager*
*Source: $Source | ID: $($metadata.automationId)*
"@
}

function Get-GitHubRepoInfo {
    try {
        $repoInfo = & gh repo view --json owner,name | ConvertFrom-Json
        return @{
            Owner = $repoInfo.owner.login
            Name = $repoInfo.name
        }
    } catch {
        throw "Failed to get repository information: $_"
    }
}

function Add-AuditEntry {
    param([hashtable]$Entry)
    
    try {
        # Ensure log directory exists
        $logDir = Split-Path $script:AuditLogPath -Parent
        if (-not (Test-Path $logDir)) {
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        }
        
        # Load existing audit log
        $auditLog = if (Test-Path $script:AuditLogPath) {
            Get-Content $script:AuditLogPath | ConvertFrom-Json
        } else {
            @()
        }
        
        # Add new entry
        $auditLog += $Entry
        
        # Save audit log
        $auditLog | ConvertTo-Json -Depth 10 | Set-Content $script:AuditLogPath
        
    } catch {
        Write-CustomLog -Level WARNING -Message "Failed to add audit entry: $_"
    }
}

function Set-IssueDependencies {
    param(
        [int]$IssueNumber,
        [int[]]$Dependencies
    )
    
    # Add comment to issue documenting dependencies
    $dependencyList = $Dependencies | ForEach-Object { "#$_" }
    $comment = @"
### Dependencies

This issue depends on the following issues:
$(foreach ($dep in $dependencyList) { "- $dep" })

The issue will be automatically updated when dependencies are resolved.
"@
    
    & gh issue comment $IssueNumber --body $comment
}
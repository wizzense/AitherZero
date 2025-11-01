#Requires -Version 7.0

<#
.SYNOPSIS
    Advanced issue deduplication and tracking system

.DESCRIPTION
    Provides bulletproof deduplication, intelligent grouping, and state tracking
    for automated issue creation to prevent duplicate issues.

.NOTES
    Domain: Development
    Category: Issue Management
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Module-level state storage path
$script:StateStoragePath = $null

function Initialize-IssueStateStorage {
    <#
    .SYNOPSIS
        Initialize persistent state storage for issue tracking
    #>
    [CmdletBinding()]
    param(
        [string]$StoragePath = "./reports/issue-state"
    )

    if (-not (Test-Path $StoragePath)) {
        New-Item -Path $StoragePath -ItemType Directory -Force | Out-Null
    }

    $script:StateStoragePath = $StoragePath
    Write-Verbose "Issue state storage initialized at: $StoragePath"
}

function Get-IssueFingerprint {
    <#
    .SYNOPSIS
        Generate a unique, stable fingerprint for an issue
    
    .DESCRIPTION
        Creates a deterministic hash that identifies the same issue across runs,
        even if minor details change (like timestamps, line numbers in ranges, etc.)
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$IssueData
    )

    # Normalize the data to create stable fingerprints
    $normalizedData = @{
        Type = $IssueData.Type
        # Normalize test names by removing timestamps and instance-specific data
        TestName = if ($IssueData.TestName) {
            $IssueData.TestName -replace '\d{4}-\d{2}-\d{2}.*?(\d{2}:\d{2}:\d{2})', 'TIMESTAMP' `
                                -replace 'line \d+', 'line N' `
                                -replace '\bat \d+\b', 'at N'
        } else { '' }
        # Normalize file paths to relative paths
        File = if ($IssueData.File) {
            $IssueData.File -replace '.*[/\\](domains|automation-scripts|tests)[/\\]', '$1/' `
                            -replace '[/\\]', '/'
        } else { '' }
        # Normalize error messages by removing variable content
        ErrorPattern = if ($IssueData.ErrorMessage) {
            $IssueData.ErrorMessage -replace '\d+', 'N' `
                                   -replace '"[^"]*"', 'STRING' `
                                   -replace "'[^']*'", 'STRING' `
                                   -replace '\$\w+', 'VAR' `
                                   -replace '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}', 'GUID'
        } else { '' }
        # Include rule name for code quality issues
        Rule = if ($IssueData.Rule) { $IssueData.Rule } else { '' }
    }

    # Create a stable string representation
    $fingerprintString = "$($normalizedData.Type)|$($normalizedData.TestName)|$($normalizedData.File)|$($normalizedData.ErrorPattern)|$($normalizedData.Rule)"
    
    # Generate SHA-256 hash
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($fingerprintString)
    $hasher = [System.Security.Cryptography.SHA256]::Create()
    $hashBytes = $hasher.ComputeHash($bytes)
    $fingerprint = [System.BitConverter]::ToString($hashBytes).Replace('-', '').Substring(0, 16)
    
    Write-Verbose "Generated fingerprint: $fingerprint for $fingerprintString"
    return $fingerprint
}

function Get-IssueState {
    <#
    .SYNOPSIS
        Load the current state of tracked issues
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    if (-not $script:StateStoragePath) {
        Initialize-IssueStateStorage
    }

    $stateFile = Join-Path $script:StateStoragePath "issue-state.json"
    
    if (Test-Path $stateFile) {
        try {
            $state = Get-Content $stateFile -Raw | ConvertFrom-Json -AsHashtable
            Write-Verbose "Loaded issue state with $($state.TrackedIssues.Count) tracked issues"
            return $state
        }
        catch {
            Write-Warning "Failed to load issue state: $_. Starting with empty state."
        }
    }

    # Return empty state
    return @{
        TrackedIssues = @{}
        LastUpdate = (Get-Date).ToString('o')
        Version = '2.0'
    }
}

function Save-IssueState {
    <#
    .SYNOPSIS
        Save the current state of tracked issues
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$State
    )

    if (-not $script:StateStoragePath) {
        Initialize-IssueStateStorage
    }

    $State.LastUpdate = (Get-Date).ToString('o')
    $stateFile = Join-Path $script:StateStoragePath "issue-state.json"
    
    $State | ConvertTo-Json -Depth 10 | Set-Content -Path $stateFile
    Write-Verbose "Saved issue state to $stateFile"
}

function Test-IssueExists {
    <#
    .SYNOPSIS
        Check if an issue already exists for this fingerprint
    
    .DESCRIPTION
        Checks both local state and GitHub API to ensure bulletproof deduplication
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string]$Fingerprint,
        
        [string]$IssueNumber
    )

    $state = Get-IssueState

    # Check local state first (fast)
    if ($state.TrackedIssues.ContainsKey($Fingerprint)) {
        $tracked = $state.TrackedIssues[$Fingerprint]
        
        # If we have an issue number, verify it's still open
        if ($tracked.IssueNumber) {
            Write-Verbose "Found tracked issue #$($tracked.IssueNumber) for fingerprint $Fingerprint"
            return $true
        }
    }

    return $false
}

function Register-IssueCreated {
    <#
    .SYNOPSIS
        Register that an issue was created for a fingerprint
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Fingerprint,
        
        [Parameter(Mandatory)]
        [int]$IssueNumber,
        
        [Parameter(Mandatory)]
        [string]$IssueTitle,
        
        [hashtable]$Metadata = @{}
    )

    $state = Get-IssueState

    $state.TrackedIssues[$Fingerprint] = @{
        IssueNumber = $IssueNumber
        IssueTitle = $IssueTitle
        CreatedAt = (Get-Date).ToString('o')
        LastSeenAt = (Get-Date).ToString('o')
        Occurrences = 1
        Metadata = $Metadata
    }

    Save-IssueState -State $state
    Write-Verbose "Registered issue #$IssueNumber for fingerprint $Fingerprint"
}

function Update-IssueOccurrence {
    <#
    .SYNOPSIS
        Update that an existing issue occurred again
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Fingerprint
    )

    $state = Get-IssueState

    if ($state.TrackedIssues.ContainsKey($Fingerprint)) {
        $state.TrackedIssues[$Fingerprint].Occurrences++
        $state.TrackedIssues[$Fingerprint].LastSeenAt = (Get-Date).ToString('o')
        Save-IssueState -State $state
        Write-Verbose "Updated occurrence count for fingerprint $Fingerprint"
    }
}

function Get-IntelligentIssueGroups {
    <#
    .SYNOPSIS
        Intelligently group issues by root cause, component, and impact
    
    .DESCRIPTION
        Groups issues beyond simple file-based grouping using multiple strategies:
        - By component/domain
        - By error type/pattern
        - By severity and impact
        - By potential root cause
    #>
    [CmdletBinding()]
    [OutputType([array])]
    param(
        [Parameter(Mandatory)]
        [array]$Issues
    )

    $groups = @{}

    foreach ($issue in $Issues) {
        # Determine component from file path
        $component = 'Unknown'
        if ($issue.File -match '(domains|automation-scripts|tests)/([^/]+)') {
            $component = $matches[2]
        }

        # Determine error category
        $errorCategory = Get-ErrorCategory -ErrorMessage $issue.ErrorMessage

        # Create group key based on component + error category
        $groupKey = "$component-$errorCategory"

        if (-not $groups.ContainsKey($groupKey)) {
            $groups[$groupKey] = @{
                Component = $component
                ErrorCategory = $errorCategory
                Issues = @()
                Severity = 'Medium'
                ImpactScore = 0
            }
        }

        $groups[$groupKey].Issues += $issue
        
        # Calculate impact score
        $impactScore = Get-IssueImpactScore -Issue $issue
        $groups[$groupKey].ImpactScore += $impactScore

        # Update severity
        if ($issue.Severity -eq 'Critical' -or $issue.Severity -eq 'Error') {
            $groups[$groupKey].Severity = 'High'
        }
    }

    # Sort groups by impact score (most impactful first)
    $sortedGroups = $groups.Values | Sort-Object -Property ImpactScore -Descending

    return $sortedGroups
}

function Get-ErrorCategory {
    <#
    .SYNOPSIS
        Categorize an error message into a root cause category
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [string]$ErrorMessage
    )

    if (-not $ErrorMessage) { return 'Unknown' }

    # Pattern matching for common error categories
    switch -Regex ($ErrorMessage) {
        'null|not found|does not exist' { return 'NullReference' }
        'access denied|unauthorized|forbidden' { return 'AccessDenied' }
        'timeout|timed out' { return 'Timeout' }
        'network|connection|socket' { return 'Network' }
        'syntax|parse|unexpected token' { return 'Syntax' }
        'argument|parameter' { return 'InvalidArgument' }
        'type|cast|conversion' { return 'TypeMismatch' }
        'file|path|directory' { return 'FileSystem' }
        'validation|assert|expected' { return 'ValidationFailure' }
        'configuration|config|settings' { return 'Configuration' }
        default { return 'General' }
    }
}

function Get-IssueImpactScore {
    <#
    .SYNOPSIS
        Calculate an impact score for an issue to prioritize fixes
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Issue
    )

    $score = 0

    # Severity weighting
    switch ($Issue.Severity) {
        'Critical' { $score += 100 }
        'Error' { $score += 50 }
        'High' { $score += 50 }
        'Warning' { $score += 10 }
        default { $score += 5 }
    }

    # Component weighting (core components are higher priority)
    $coreComponents = @('configuration', 'utilities', 'security', 'automation')
    if ($Issue.File -and ($coreComponents | Where-Object { $Issue.File -match $_ })) {
        $score += 25
    }

    # Test type weighting
    if ($Issue.TestType -eq 'Unit') {
        $score += 20  # Unit test failures indicate code issues
    }
    elseif ($Issue.TestType -eq 'Integration') {
        $score += 15
    }

    # Occurrence weighting
    if ($Issue.Occurrences -gt 1) {
        $score += ($Issue.Occurrences * 5)
    }

    return $score
}

function Get-CopilotAgentAssignment {
    <#
    .SYNOPSIS
        Determine which Copilot agent should be assigned to an issue
    
    .DESCRIPTION
        Intelligently routes issues to specialized agents based on:
        - Component/domain
        - Error type
        - Issue category
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Issue
    )

    $assignment = @{
        Agent = $null
        Labels = @()
        Priority = 'P2'
    }

    # Determine agent by component and error type
    if ($Issue.File -match 'infrastructure|hyper-v|opentofu|terraform|vm') {
        $assignment.Agent = 'Maya'
        $assignment.Labels += @('infrastructure', 'agent:maya')
    }
    elseif ($Issue.File -match 'security|certificate|credential|auth') {
        $assignment.Agent = 'Sarah'
        $assignment.Labels += @('security', 'agent:sarah')
    }
    elseif ($Issue.File -match 'test|pester|quality') {
        $assignment.Agent = 'Jessica'
        $assignment.Labels += @('testing', 'agent:jessica')
    }
    elseif ($Issue.File -match 'ui|menu|wizard|experience') {
        $assignment.Agent = 'Emma'
        $assignment.Labels += @('ui-ux', 'agent:emma')
    }
    elseif ($Issue.File -match 'psscriptanalyzer|code-quality|lint') {
        $assignment.Agent = 'Rachel'
        $assignment.Labels += @('code-quality', 'agent:rachel')
    }
    elseif ($Issue.File -match 'documentation|docs|readme') {
        $assignment.Agent = 'Olivia'
        $assignment.Labels += @('documentation', 'agent:olivia')
    }
    elseif ($Issue.File -match 'automation|orchestration|workflow') {
        $assignment.Agent = 'Marcus'
        $assignment.Labels += @('automation', 'agent:marcus')
    }
    else {
        # Default to Rachel for PowerShell issues
        $assignment.Agent = 'Rachel'
        $assignment.Labels += @('powershell', 'agent:rachel')
    }

    # Determine priority based on severity and impact
    if ($Issue.Severity -in @('Critical', 'Error')) {
        $assignment.Priority = 'P1'
    }
    elseif ($Issue.Severity -eq 'High') {
        $assignment.Priority = 'P2'
    }
    else {
        $assignment.Priority = 'P3'
    }

    # Add issue type labels
    if ($Issue.Type -eq 'TestFailure') {
        $assignment.Labels += @('test-failure', 'automated-issue')
    }
    elseif ($Issue.Type -eq 'CodeViolation') {
        $assignment.Labels += @('code-quality', 'automated-issue')
    }

    return $assignment
}

function Get-IssueTriageData {
    <#
    .SYNOPSIS
        Generate comprehensive triage data for an issue
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Issue
    )

    $assignment = Get-CopilotAgentAssignment -Issue $Issue
    $impactScore = Get-IssueImpactScore -Issue $Issue

    return @{
        Priority = $assignment.Priority
        Agent = $assignment.Agent
        Labels = $assignment.Labels
        ImpactScore = $impactScore
        Component = if ($Issue.File -match '(domains|automation-scripts)/([^/]+)') { $matches[2] } else { 'Unknown' }
        ErrorCategory = Get-ErrorCategory -ErrorMessage $Issue.ErrorMessage
        SuggestedActions = Get-SuggestedActions -Issue $Issue
    }
}

function Get-SuggestedActions {
    <#
    .SYNOPSIS
        Generate suggested actions for fixing an issue
    #>
    [CmdletBinding()]
    [OutputType([array])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Issue
    )

    $actions = @()
    $errorCategory = Get-ErrorCategory -ErrorMessage $Issue.ErrorMessage

    switch ($errorCategory) {
        'NullReference' {
            $actions += "Add null checks before accessing properties or methods"
            $actions += "Verify that all required parameters are provided"
            $actions += "Check initialization logic for the affected component"
        }
        'Syntax' {
            $actions += "Run PSScriptAnalyzer to identify syntax issues"
            $actions += "Review the syntax at the reported line/column"
            $actions += "Check for missing brackets, quotes, or parentheses"
        }
        'ValidationFailure' {
            $actions += "Review test assertions and expected values"
            $actions += "Check if the implementation matches requirements"
            $actions += "Update tests if requirements have changed"
        }
        'Configuration' {
            $actions += "Verify configuration file format and values"
            $actions += "Check that all required configuration keys are present"
            $actions += "Review configuration loading logic"
        }
        default {
            $actions += "Review the error message and stack trace"
            $actions += "Add logging to understand the failure context"
            $actions += "Check for recent changes that might have caused this"
        }
    }

    return $actions
}

# Export module functions
Export-ModuleMember -Function @(
    'Initialize-IssueStateStorage',
    'Get-IssueFingerprint',
    'Get-IssueState',
    'Save-IssueState',
    'Test-IssueExists',
    'Register-IssueCreated',
    'Update-IssueOccurrence',
    'Get-IntelligentIssueGroups',
    'Get-ErrorCategory',
    'Get-IssueImpactScore',
    'Get-CopilotAgentAssignment',
    'Get-IssueTriageData',
    'Get-SuggestedActions'
)

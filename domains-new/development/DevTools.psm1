#Requires -Version 7.0

<#
.SYNOPSIS
    Consolidated Development Tools for AitherZero
.DESCRIPTION
    Unified development tools providing Git automation, testing framework, CI/CD integration,
    and AI-powered development assistance.
.NOTES
    Consolidated from:
    - domains/development/GitAutomation.psm1
    - domains/development/DeveloperTools.psm1
    - domains/development/IssueTracker.psm1
    - domains/testing/AitherTestFramework.psm1
    - domains/testing/TestingFramework.psm1
    - domains/ai-agents/ClaudeCodeIntegration.psm1
#>

# Script variables
$script:GitConfig = @{}
$script:TestFramework = $null
$script:AIEnabled = $false

#region Git Automation Functions

function Get-GitRepository {
    <#
    .SYNOPSIS
        Get information about the current Git repository
    #>
    [CmdletBinding()]
    param([string]$Path = ".")

    Push-Location $Path
    try {
        $isRepo = git rev-parse --is-inside-work-tree 2>$null
        if ($isRepo -ne 'true') {
            return $null
        }

        $branch = git rev-parse --abbrev-ref HEAD 2>$null
        $remoteUrl = git config --get remote.origin.url 2>$null
        $status = git status --porcelain 2>$null
        $lastCommit = git log -1 --format="%H|%s|%an|%ad" --date=iso 2>$null

        return [PSCustomObject]@{
            Path = (Resolve-Path $Path).Path
            Branch = $branch
            RemoteUrl = $remoteUrl
            HasChanges = ($status.Count -gt 0)
            Status = $status
            LastCommit = if ($lastCommit) {
                $parts = $lastCommit -split '\|'
                @{
                    Hash = $parts[0]
                    Message = $parts[1]
                    Author = $parts[2]
                    Date = $parts[3]
                }
            } else { $null }
        }
    }
    finally {
        Pop-Location
    }
}

function New-GitBranch {
    <#
    .SYNOPSIS
        Create and optionally checkout a new Git branch
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$BranchName,
        
        [string]$BaseBranch = "main",
        [switch]$Checkout,
        [switch]$Push
    )

    if ($PSCmdlet.ShouldProcess($BranchName, "Create Git branch")) {
        # Ensure we're on the base branch first
        git checkout $BaseBranch
        
        # Create new branch
        git checkout -b $BranchName
        
        if ($Push) {
            git push -u origin $BranchName
        }
        
        Write-Host "Created branch: $BranchName" -ForegroundColor Green
        return $BranchName
    }
}

function Invoke-GitCommit {
    <#
    .SYNOPSIS
        Create a Git commit with conventional commit format
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('feat', 'fix', 'docs', 'style', 'refactor', 'test', 'chore', 'ci', 'build')]
        [string]$Type,
        
        [Parameter(Mandatory)]
        [string]$Description,
        
        [string]$Scope,
        [string]$Body,
        [string]$Footer,
        [switch]$Breaking,
        [switch]$Stage
    )

    if ($Stage) {
        git add .
    }

    # Build conventional commit message
    $commitMsg = $Type
    if ($Scope) {
        $commitMsg += "($Scope)"
    }
    if ($Breaking) {
        $commitMsg += "!"
    }
    $commitMsg += ": $Description"

    if ($Body) {
        $commitMsg += "`n`n$Body"
    }

    if ($Footer) {
        $commitMsg += "`n`n$Footer"
    }

    if ($PSCmdlet.ShouldProcess($commitMsg, "Create Git commit")) {
        git commit -m $commitMsg
        Write-Host "Committed: $commitMsg" -ForegroundColor Green
        return $commitMsg
    }
}

function Sync-GitRepository {
    <#
    .SYNOPSIS
        Synchronize repository with remote
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [switch]$Pull,
        [switch]$Push,
        [switch]$Force
    )

    if ($Pull -or (-not $Push)) {
        if ($PSCmdlet.ShouldProcess("repository", "Pull changes")) {
            git fetch origin
            git pull origin (git rev-parse --abbrev-ref HEAD)
            Write-Host "Pulled latest changes" -ForegroundColor Green
        }
    }

    if ($Push) {
        if ($PSCmdlet.ShouldProcess("repository", "Push changes")) {
            $pushArgs = @("origin", (git rev-parse --abbrev-ref HEAD))
            if ($Force) { $pushArgs += "--force" }
            
            git push @pushArgs
            Write-Host "Pushed changes to remote" -ForegroundColor Green
        }
    }
}

function Get-GitStatus {
    <#
    .SYNOPSIS
        Get detailed Git repository status
    #>
    [CmdletBinding()]
    param()

    $status = git status --porcelain=v1 2>$null
    $branch = git rev-parse --abbrev-ref HEAD 2>$null
    
    $parsed = @{
        Branch = $branch
        Modified = @()
        Added = @()
        Deleted = @()
        Renamed = @()
        Untracked = @()
    }

    foreach ($line in $status) {
        $statusCode = $line.Substring(0, 2)
        $fileName = $line.Substring(3)
        
        switch ($statusCode[0]) {
            'M' { $parsed.Modified += $fileName }
            'A' { $parsed.Added += $fileName }
            'D' { $parsed.Deleted += $fileName }
            'R' { $parsed.Renamed += $fileName }
            '?' { $parsed.Untracked += $fileName }
        }
    }

    return $parsed
}

#endregion

#region Testing Framework Functions

function Initialize-TestFramework {
    <#
    .SYNOPSIS
        Initialize the AitherZero testing framework
    #>
    [CmdletBinding()]
    param(
        [hashtable]$Configuration = @{},
        [switch]$EnableCache,
        [int]$ParallelJobs = 4
    )

    $script:TestFramework = @{
        Version = "2.0.0"
        StartTime = Get-Date
        Config = $Configuration
        TestSuites = @{}
        Results = @{}
        Cache = @{}
        ParallelJobs = @{}
    }

    if (Get-Command Write-TestingLog -ErrorAction SilentlyContinue) {
        Write-TestingLog -Message "Initializing AitherZero Testing Framework v2.0.0" -Level Information
        Write-TestingLog -Message "Framework initialized" -Level Information
    }

    return $script:TestFramework
}

function Register-TestSuite {
    <#
    .SYNOPSIS
        Register a test suite with the framework
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,
        
        [Parameter(Mandatory)]
        [scriptblock]$TestScript,
        
        [string[]]$Categories = @('Unit'),
        [string[]]$Tags = @(),
        [string[]]$Dependencies = @(),
        [int]$Priority = 50,
        [hashtable]$Configuration = @{}
    )

    $cacheKey = Get-Random -Maximum 999999 | ForEach-Object { [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($_)).Substring(0, 16) }

    $testSuite = [PSCustomObject]@{
        Name = $Name
        TestScript = $TestScript
        Categories = $Categories
        Tags = $Tags
        Dependencies = $Dependencies
        Priority = $Priority
        Configuration = $Configuration
        RegisteredAt = Get-Date
        LastRun = $null
        LastResult = $null
        CacheKey = $cacheKey
        Description = ""
    }

    $script:TestFramework.TestSuites[$Name] = $testSuite

    if (Get-Command Write-TestingLog -ErrorAction SilentlyContinue) {
        Write-TestingLog -Message "Registered test suite: $Name" -Level Information
    }

    return $testSuite
}

function Invoke-TestCategory {
    <#
    .SYNOPSIS
        Execute tests by category
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Smoke', 'Unit', 'Integration', 'Full')]
        [string]$Category,
        
        [string[]]$Tags = @(),
        [string[]]$ExcludeTags = @(),
        [switch]$Parallel,
        [switch]$UseCache,
        [hashtable]$Variables = @{}
    )

    if (-not $script:TestFramework) {
        Initialize-TestFramework
    }

    $suitesToRun = $script:TestFramework.TestSuites.Values | 
        Where-Object { $_.Categories -contains $Category }

    if ($Tags.Count -gt 0) {
        $suitesToRun = $suitesToRun | Where-Object { 
            ($_.Tags | Where-Object { $_ -in $Tags }).Count -gt 0 
        }
    }

    if ($ExcludeTags.Count -gt 0) {
        $suitesToRun = $suitesToRun | Where-Object { 
            ($_.Tags | Where-Object { $_ -in $ExcludeTags }).Count -eq 0 
        }
    }

    $results = @{}
    
    foreach ($suite in ($suitesToRun | Sort-Object Priority)) {
        Write-Host "Running test suite: $($suite.Name)" -ForegroundColor Cyan
        
        try {
            $testResult = & $suite.TestScript
            $results[$suite.Name] = @{
                Status = 'Passed'
                Result = $testResult
                Duration = (Get-Date) - $suite.RegisteredAt
            }
        }
        catch {
            $results[$suite.Name] = @{
                Status = 'Failed'
                Error = $_.Exception.Message
                Duration = (Get-Date) - $suite.RegisteredAt
            }
        }
        
        $suite.LastRun = Get-Date
        $suite.LastResult = $results[$suite.Name]
    }

    return $results
}

function Clear-TestCache {
    <#
    .SYNOPSIS
        Clear the test cache
    #>
    [CmdletBinding()]
    param([string[]]$SuiteNames)

    if ($SuiteNames) {
        foreach ($name in $SuiteNames) {
            $script:TestFramework.Cache.Remove($name)
        }
    } else {
        $script:TestFramework.Cache.Clear()
    }

    Write-Host "Test cache cleared" -ForegroundColor Green
}

#endregion

#region AI Integration Functions

function Enable-AIIntegration {
    <#
    .SYNOPSIS
        Enable AI-powered development features
    #>
    [CmdletBinding()]
    param(
        [string]$ApiKey,
        [ValidateSet('Claude', 'GPT-4', 'Gemini')]
        [string]$Provider = 'Claude'
    )

    $script:AIEnabled = $true
    Write-Host "AI integration enabled with $Provider" -ForegroundColor Green
}

function Invoke-AICodeReview {
    <#
    .SYNOPSIS
        Use AI to review code changes
    #>
    [CmdletBinding()]
    param(
        [string]$FilePath,
        [string]$CommitHash,
        [switch]$Interactive
    )

    if (-not $script:AIEnabled) {
        Write-Warning "AI integration not enabled. Use Enable-AIIntegration first."
        return
    }

    Write-Host "Running AI code review..." -ForegroundColor Cyan
    
    # Simulated AI review (would integrate with actual AI service)
    return @{
        Status = 'Completed'
        Suggestions = @(
            "Consider adding error handling to line 45"
            "Variable naming could be improved for clarity"
            "Function complexity is acceptable"
        )
        Rating = 'Good'
    }
}

function New-AICommitMessage {
    <#
    .SYNOPSIS
        Generate commit message using AI
    #>
    [CmdletBinding()]
    param([string[]]$ChangedFiles)

    if (-not $script:AIEnabled) {
        Write-Warning "AI integration not enabled. Use Enable-AIIntegration first."
        return
    }

    # Analyze git diff and generate conventional commit message
    $diff = git diff --cached
    
    # Simulated AI analysis (would integrate with actual AI service)
    return "feat: add consolidated development tools module

- Merge Git automation, testing, and AI features
- Implement unified development workflow
- Add AI-powered code review capabilities"
}

#endregion

#region Issue Tracking Functions

function New-DevelopmentIssue {
    <#
    .SYNOPSIS
        Create a development issue
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Title,
        
        [string]$Description,
        [ValidateSet('bug', 'feature', 'enhancement', 'task')]
        [string]$Type = 'task',
        [ValidateSet('low', 'medium', 'high', 'critical')]
        [string]$Priority = 'medium',
        [string[]]$Labels = @()
    )

    $issue = [PSCustomObject]@{
        Id = [Guid]::NewGuid().ToString()
        Title = $Title
        Description = $Description
        Type = $Type
        Priority = $Priority
        Labels = $Labels
        CreatedDate = Get-Date
        Status = 'Open'
        Assignee = $env:USERNAME
    }

    Write-Host "Created issue: $Title" -ForegroundColor Green
    return $issue
}

function Get-DevelopmentMetrics {
    <#
    .SYNOPSIS
        Get development metrics and statistics
    #>
    [CmdletBinding()]
    param(
        [int]$Days = 30
    )

    $repo = Get-GitRepository
    if (-not $repo) {
        Write-Warning "Not in a Git repository"
        return
    }

    $since = (Get-Date).AddDays(-$Days).ToString('yyyy-MM-dd')
    $commits = git log --since=$since --pretty=format:"%H|%s|%an|%ad" --date=short | ConvertFrom-Csv -Delimiter '|' -Header 'Hash', 'Message', 'Author', 'Date'
    
    $metrics = @{
        Period = "$Days days"
        TotalCommits = $commits.Count
        Authors = ($commits | Group-Object Author | Measure-Object).Count
        CommitsByAuthor = $commits | Group-Object Author | ForEach-Object { 
            @{ Author = $_.Name; Commits = $_.Count }
        }
        CommitsByDay = $commits | Group-Object Date | ForEach-Object { 
            @{ Date = $_.Name; Commits = $_.Count }
        }
    }

    return $metrics
}

#endregion

# Export functions
Export-ModuleMember -Function @(
    # Git Functions
    'Get-GitRepository',
    'New-GitBranch',
    'Invoke-GitCommit',
    'Sync-GitRepository',
    'Get-GitStatus',
    
    # Testing Functions
    'Initialize-TestFramework',
    'Register-TestSuite',
    'Invoke-TestCategory',
    'Clear-TestCache',
    
    # AI Integration
    'Enable-AIIntegration',
    'Invoke-AICodeReview',
    'New-AICommitMessage',
    
    # Issue Tracking
    'New-DevelopmentIssue',
    'Get-DevelopmentMetrics'
)
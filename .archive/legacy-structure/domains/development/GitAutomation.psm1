#Requires -Version 7.0

<#
.SYNOPSIS
    AitherZero Git Automation Module
.DESCRIPTION
    Provides comprehensive Git automation capabilities including branch management,
    commit operations, and repository synchronization.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Module state
$script:GitState = @{
    CurrentBranch = $null
    Repository = @{}
    Configuration = @{}
}

# Import dependencies
$script:ProjectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$script:LoggingModule = Join-Path $script:ProjectRoot "domains/utilities/Logging.psm1"

if (Test-Path $script:LoggingModule) {
    Import-Module $script:LoggingModule -Force
    $script:LoggingAvailable = $true
} else {
    $script:LoggingAvailable = $false
}

function Write-GitLog {
    param(
        [string]$Message,
        [string]$Level = 'Information',
        [hashtable]$Data = @{}
    )

    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Level $Level -Message $Message -Source "GitAutomation" -Data $Data
    } else {
        Write-Host "[$Level] $Message"
    }
}

#region Core Git Functions

function Get-GitRepository {
    <#
    .SYNOPSIS
        Get current Git repository information
    .DESCRIPTION
        Retrieves comprehensive information about the current Git repository
        including branch, remotes, and status.
    #>
    [CmdletBinding()]
    param(
        [string]$Path = (Get-Location)
    )

    try {
        Push-Location $Path
        
        # Check if in a git repository
        $gitDir = git rev-parse --git-dir 2>$null
        if ($LASTEXITCODE -ne 0) {
            throw "Not in a Git repository"
        }
        
        $repoInfo = @{
            Path = $Path
            GitDir = $gitDir
            Branch = git branch --show-current
            RemoteUrl = git config --get remote.origin.url
            Status = git status --porcelain
            LastCommit = git log -1 --format="%H|%s|%an|%ae|%ad" --date=iso
            Remotes = @(git remote -v | ForEach-Object { 
                if ($_ -match '^(\S+)\s+(\S+)\s+\((\w+)\)$') {
                    @{ Name = $Matches[1]; Url = $Matches[2]; Type = $Matches[3] }
                }
            })
        }
        
        # Parse last commit
        if ($repoInfo.LastCommit) {
            $parts = $repoInfo.LastCommit -split '\|'
            $repoInfo.LastCommit = @{
                Hash = $parts[0]
                Message = $parts[1]
                Author = $parts[2]
                Email = $parts[3]
                Date = $parts[4]
            }
        }
        
        Write-GitLog "Retrieved repository information" -Data @{ Branch = $repoInfo.Branch }
        return $repoInfo
        
    } finally {
        Pop-Location
    }
}

function New-GitBranch {
    <#
    .SYNOPSIS
        Create a new Git branch
    .DESCRIPTION
        Creates a new Git branch with optional upstream tracking and
        checkout capabilities.
    .PARAMETER Name
        Name of the new branch
    .PARAMETER From
        Base branch or commit to create from (default: current branch)
    .PARAMETER Checkout
        Switch to the new branch after creation
    .PARAMETER Push
        Push the new branch to remote
    .PARAMETER Force
        Overwrite existing branch if it exists
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$Name,
        
        [string]$From,
        
        [switch]$Checkout,
        
        [switch]$Push,
        
        [switch]$Force
    )

    try {
        # Validate branch name
        if ($Name -match '[^a-zA-Z0-9/_-]') {
            throw "Invalid branch name. Use only letters, numbers, /, _, and -"
        }
        
        # Get current state
        $currentBranch = git branch --show-current
        
        # Check if branch already exists
        $existingBranch = git branch --list $Name 2>$null
        $remoteBranch = git branch -r --list "origin/$Name" 2>$null
        
        if ($existingBranch -or $remoteBranch) {
            if ($Force) {
                Write-GitLog "Branch '$Name' exists, force overwriting" -Level Warning
                
                # Delete existing branch
                if ($currentBranch -eq $Name) {
                    git checkout main 2>$null || git checkout master 2>$null
                }
                git branch -D $Name 2>$null
                
                if ($remoteBranch) {
                    git push origin --delete $Name 2>$null
                }
            } else {
                # Branch exists but not forcing - just checkout
                Write-GitLog "Branch '$Name' already exists, checking out"
                
                if ($Checkout) {
                    git checkout $Name
                    if ($LASTEXITCODE -ne 0) {
                        throw "Failed to checkout existing branch"
                    }
                }
                
                return @{
                    Name = $Name
                    Created = $false
                    Existed = $true
                    CheckedOut = $Checkout
                    Pushed = $false
                }
            }
        }
        
        # Create branch
        $createArgs = @('branch', $Name)
        if ($From) {
            $createArgs += $From
        }
        
        if ($PSCmdlet.ShouldProcess("Create branch '$Name'")) {
            git @createArgs
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to create branch"
            }
            
            Write-GitLog "Created branch: $Name" -Data @{ From = $From; Current = $currentBranch }
        }
        
        # Checkout if requested
        if ($Checkout) {
            git checkout $Name
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to checkout branch"
            }
            Write-GitLog "Checked out branch: $Name"
        }
        
        # Push if requested
        if ($Push) {
            git push -u origin $Name
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to push branch"
            }
            Write-GitLog "Pushed branch to remote: $Name"
        }
        
        return @{
            Name = $Name
            Created = $true
            CheckedOut = $Checkout
            Pushed = $Push
        }
        
    } catch {
        Write-GitLog "Failed to create branch: $_" -Level Error
        throw
    }
}

function Invoke-GitCommit {
    <#
    .SYNOPSIS
        Create a Git commit with enhanced options
    .DESCRIPTION
        Creates a Git commit with support for conventional commits,
        auto-staging, and commit signing.
    .PARAMETER Message
        Commit message
    .PARAMETER Body
        Extended commit body
    .PARAMETER Type
        Conventional commit type (feat, fix, docs, etc.)
    .PARAMETER Scope
        Commit scope for conventional commits
    .PARAMETER AutoStage
        Automatically stage all changes before committing
    .PARAMETER SignOff
        Add Signed-off-by line
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        
        [string]$Body,
        
        [ValidateSet('feat', 'fix', 'docs', 'style', 'refactor', 'test', 'chore', 'perf', 'ci', 'build', 'revert')]
        [string]$Type,
        
        [string]$Scope,
        
        [switch]$AutoStage,
        
        [switch]$SignOff,
        
        [string[]]$CoAuthors
    )

    try {
        # Check for changes
        $status = git status --porcelain
        if (-not $status -and -not $AutoStage) {
            Write-Warning "No changes to commit"
            return
        }
        
        # Auto-stage if requested
        if ($AutoStage) {
            git add -A
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to stage changes"
            }
            Write-GitLog "Auto-staged all changes"
        }
        
        # Build commit message
        $fullMessage = $Message
        if ($Type) {
            $fullMessage = "$Type"
            if ($Scope) {
                $fullMessage += "($Scope)"
            }
            $fullMessage += ": $Message"
        }
        
        # Build commit command
        $commitArgs = @('commit', '-m', $fullMessage)
        
        if ($Body) {
            $commitArgs += '-m', $Body
        }
        
        if ($SignOff) {
            $commitArgs += '--signoff'
        }
        
        # Add co-authors
        if ($CoAuthors) {
            $coAuthorLines = $CoAuthors | ForEach-Object { "Co-authored-by: $_" }
            $commitArgs += '-m', ($coAuthorLines -join "`n")
        }
        
        if ($PSCmdlet.ShouldProcess("Commit with message: $fullMessage")) {
            git @commitArgs
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to create commit"
            }

            # Get commit hash
            $commitHash = git rev-parse HEAD
            
            Write-GitLog "Created commit: $commitHash" -Data @{
                Message = $fullMessage
                Type = $Type
                Scope = $Scope
                Hash = $commitHash
            }

            if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
                Write-AuditLog -EventType "GitCommit" -Action "CreateCommit" -Target $commitHash -Result "Success" -Details @{
                    Message = $fullMessage
                    AutoStaged = $AutoStage
                }
            }
            
            return @{
                Hash = $commitHash
                Message = $fullMessage
                Success = $true
            }
        }
        
    } catch {
        Write-GitLog "Failed to create commit: $_" -Level Error
        throw
    }
}

function Sync-GitRepository {
    <#
    .SYNOPSIS
        Synchronize Git repository with remote
    .DESCRIPTION
        Performs various sync operations including fetch, pull, push,
        and rebase operations.
    .PARAMETER Operation
        Type of sync operation to perform
    .PARAMETER Remote
        Remote name (default: origin)
    .PARAMETER Branch
        Branch to sync (default: current branch)
    .PARAMETER Force
        Force push (use with caution)
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [ValidateSet('Fetch', 'Pull', 'Push', 'FetchPrune', 'PullRebase', 'SyncAll')]
        [string]$Operation = 'Pull',
        
        [string]$Remote = 'origin',
        
        [string]$Branch,
        
        [switch]$Force
    )

    try {
        if (-not $Branch) {
            $Branch = git branch --show-current
        }
        
        switch ($Operation) {
            'Fetch' {
                if ($PSCmdlet.ShouldProcess("Fetch from $Remote")) {
                    git fetch $Remote
                    Write-GitLog "Fetched from remote: $Remote"
                }
            }
            
            'FetchPrune' {
                if ($PSCmdlet.ShouldProcess("Fetch and prune from $Remote")) {
                    git fetch --prune $Remote
                    Write-GitLog "Fetched and pruned from remote: $Remote"
                }
            }
            
            'Pull' {
                if ($PSCmdlet.ShouldProcess("Pull from $Remote/$Branch")) {
                    git pull $Remote $Branch
                    Write-GitLog "Pulled from remote: $Remote/$Branch"
                }
            }
            
            'PullRebase' {
                if ($PSCmdlet.ShouldProcess("Pull with rebase from $Remote/$Branch")) {
                    git pull --rebase $Remote $Branch
                    Write-GitLog "Pulled with rebase from remote: $Remote/$Branch"
                }
            }
            
            'Push' {
                $pushArgs = @('push', $Remote, $Branch)
                if ($Force) {
                    $pushArgs += '--force-with-lease'
                }
                
                if ($PSCmdlet.ShouldProcess("Push to $Remote/$Branch" + $(if ($Force) { " (force)" } else { "" }))) {
                    git @pushArgs
                    Write-GitLog "Pushed to remote: $Remote/$Branch" -Data @{ Forced = $Force }
                }
            }
            
            'SyncAll' {
                if ($PSCmdlet.ShouldProcess("Full sync with $Remote")) {
                    # Fetch all
                    git fetch --all --prune
                    
                    # Pull current branch
                    git pull --rebase $Remote $Branch
                    
                    # Push current branch
                    git push $Remote $Branch
                    
                    Write-GitLog "Completed full sync with remote: $Remote"
                }
            }
        }
        
        if ($LASTEXITCODE -ne 0) {
            throw "Git operation failed"
        }
        
    } catch {
        Write-GitLog "Sync operation failed: $_" -Level Error
        throw
    }
}

function Get-GitStatus {
    <#
    .SYNOPSIS
        Get enhanced Git status information
    .DESCRIPTION
        Provides detailed Git status including staged, unstaged,
        and untracked files with additional metadata.
    #>
    [CmdletBinding()]
    param()
    
    try {
        $status = @{
            Branch = git branch --show-current
            UpstreamBranch = git rev-parse --abbrev-ref '@{upstream}' 2>$null
            Staged = @()
            Modified = @()
            Untracked = @()
            Deleted = @()
            Conflicts = @()
            Clean = $true
        }
        
        # Get detailed status
        $statusOutput = git status --porcelain=v1
        
        foreach ($line in $statusOutput) {
            if ($line) {
                $status.Clean = $false
                $indexStatus = $line[0]
                $workTreeStatus = $line[1]
                $file = $line.Substring(3)
                
                $fileInfo = @{
                    Path = $file
                    IndexStatus = $indexStatus
                    WorkTreeStatus = $workTreeStatus
                }
                
                # Categorize files
                switch -Regex ($line.Substring(0, 2)) {
                    '^[AMD]' { $status.Staged += $fileInfo }
                    '^.[MD]' { $status.Modified += $fileInfo }
                    '^\?\?' { $status.Untracked += $fileInfo }
                    '^.D' { $status.Deleted += $fileInfo }
                    '^(DD|AU|UD|UA|DU|AA|UU)' { $status.Conflicts += $fileInfo }
                }
            }
        }
        
        # Get ahead/behind info
        if ($status.UpstreamBranch) {
            $aheadBehind = git rev-list --left-right --count "HEAD...$($status.UpstreamBranch)" 2>$null
            if ($aheadBehind) {
                $parts = $aheadBehind -split '\s+'
                $status.Ahead = [int]$parts[0]
                $status.Behind = [int]$parts[1]
            }
        }
        
        Write-GitLog "Retrieved Git status" -Data @{
            Branch = $status.Branch
            Clean = $status.Clean
            FileCount = $statusOutput.Count
        }
        
        return $status
        
    } catch {
        Write-GitLog "Failed to get Git status: $_" -Level Error
        throw
    }
}

#endregion

#region Git Configuration

function Set-GitConfiguration {
    <#
    .SYNOPSIS
        Set Git configuration values
    .DESCRIPTION
        Sets Git configuration at various levels (local, global, system)
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$Key,
        
        [Parameter(Mandatory)]
        [string]$Value,
        
        [ValidateSet('Local', 'Global', 'System')]
        [string]$Level = 'Local'
    )

    try {
        $levelFlag = switch ($Level) {
            'Local' { '--local' }
            'Global' { '--global' }
            'System' { '--system' }
        }
        
        if ($PSCmdlet.ShouldProcess("Set Git config $Key = $Value at $Level level")) {
            git config $levelFlag $Key $Value
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to set Git configuration"
            }
            
            Write-GitLog "Set Git configuration" -Data @{
                Key = $Key
                Value = $Value
                Level = $Level
            }
        }
        
    } catch {
        Write-GitLog "Failed to set Git configuration: $_" -Level Error
        throw
    }
}

#endregion

# Export functions
Export-ModuleMember -Function @(
    'Get-GitRepository',
    'New-GitBranch',
    'Invoke-GitCommit',
    'Sync-GitRepository',
    'Get-GitStatus',
    'Set-GitConfiguration'
)
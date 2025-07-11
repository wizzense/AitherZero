#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Configures Git worktrees for Claude Code to use multiple working directories for different tasks
    
.DESCRIPTION
    This script sets up Git worktrees to allow Claude Code to work on multiple tasks simultaneously:
    - Each sub-agent/task gets its own worktree
    - Prevents conflicts between parallel operations
    - Maintains clean separation of concerns
    - Enables true parallel development
    
.PARAMETER Action
    Action to perform: Setup, List, Remove, Clean
    
.PARAMETER TaskName
    Name of the task/sub-agent (used as worktree name)
    
.PARAMETER Branch
    Branch name for the worktree (auto-generated if not specified)
    
.PARAMETER BaseBranch
    Base branch to create new branch from (default: main)
    
.EXAMPLE
    ./Configure-GitWorktrees.ps1 -Action Setup -TaskName "validation-fixes"
    # Creates a new worktree for validation fixes
    
.EXAMPLE
    ./Configure-GitWorktrees.ps1 -Action List
    # Lists all active worktrees
    
.NOTES
    This enables Claude Code to work like multiple developers on the same project
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Setup', 'List', 'Remove', 'Clean', 'Status')]
    [string]$Action,
    
    [Parameter()]
    [string]$TaskName,
    
    [Parameter()]
    [string]$Branch,
    
    [Parameter()]
    [string]$BaseBranch = 'main',
    
    [Parameter()]
    [switch]$Force
)

# Initialize
$ErrorActionPreference = "Stop"
$script:ProjectRoot = git rev-parse --show-toplevel
$script:WorktreesRoot = Join-Path (Split-Path $script:ProjectRoot -Parent) "aitherzero-worktrees"
$script:WorktreeConfig = Join-Path $script:ProjectRoot ".claude/worktree-config.json"

# Import logging
Import-Module "$script:ProjectRoot/aither-core/modules/Logging" -Force -ErrorAction SilentlyContinue

function Write-Message {
    param(
        [string]$Message,
        [string]$Level = 'INFO'
    )
    
    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Level $Level -Message $Message
    } else {
        $color = switch ($Level) {
            'ERROR' { 'Red' }
            'WARNING' { 'Yellow' }
            'SUCCESS' { 'Green' }
            'INFO' { 'Cyan' }
            default { 'White' }
        }
        Write-Host "[$Level] $Message" -ForegroundColor $color
    }
}

function Get-WorktreeConfig {
    if (Test-Path $script:WorktreeConfig) {
        return Get-Content $script:WorktreeConfig | ConvertFrom-Json
    } else {
        return @{
            worktrees = @()
            settings = @{
                maxWorktrees = 10
                autoCleanDays = 30
                namingPattern = "task/{taskname}/{date}"
            }
        }
    }
}

function Save-WorktreeConfig {
    param($Config)
    
    $dir = Split-Path $script:WorktreeConfig -Parent
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    
    $Config | ConvertTo-Json -Depth 10 | Set-Content $script:WorktreeConfig
}

function Setup-Worktree {
    if (-not $TaskName) {
        throw "TaskName is required for Setup action"
    }
    
    Write-Message "Setting up worktree for task: $TaskName" -Level INFO
    
    # Ensure worktrees root exists
    if (-not (Test-Path $script:WorktreesRoot)) {
        New-Item -ItemType Directory -Path $script:WorktreesRoot -Force | Out-Null
    }
    
    # Generate branch name if not specified
    if (-not $Branch) {
        $date = Get-Date -Format "yyyyMMdd-HHmmss"
        $Branch = "task/$TaskName/$date"
    }
    
    # Create worktree path
    $worktreePath = Join-Path $script:WorktreesRoot $TaskName
    
    # Check if worktree already exists
    if (Test-Path $worktreePath) {
        if ($Force) {
            Write-Message "Removing existing worktree: $worktreePath" -Level WARNING
            git worktree remove --force $worktreePath
        } else {
            throw "Worktree already exists at: $worktreePath. Use -Force to replace."
        }
    }
    
    try {
        # Create new branch from base
        Write-Message "Creating branch: $Branch from $BaseBranch" -Level INFO
        git branch $Branch $BaseBranch 2>$null || Write-Message "Branch already exists" -Level WARNING
        
        # Add worktree
        Write-Message "Adding worktree at: $worktreePath" -Level INFO
        git worktree add $worktreePath $Branch
        
        # Update configuration
        $config = Get-WorktreeConfig
        $config.worktrees += @{
            name = $TaskName
            path = $worktreePath
            branch = $Branch
            created = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            lastAccessed = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            purpose = "Task: $TaskName"
            status = "active"
        }
        Save-WorktreeConfig -Config $config
        
        # Create task-specific configuration
        $taskConfig = @{
            task = $TaskName
            branch = $Branch
            baseBranch = $BaseBranch
            created = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            claudeInstructions = @"
This is a dedicated worktree for task: $TaskName

Important:
- Work only in this directory: $worktreePath
- Branch: $Branch
- All changes should be related to: $TaskName
- Use PatchManager for commits in this worktree
- Do not switch branches in this worktree
"@
        }
        
        $taskConfigPath = Join-Path $worktreePath ".claude-task.json"
        $taskConfig | ConvertTo-Json -Depth 10 | Set-Content $taskConfigPath
        
        Write-Message "Worktree setup complete!" -Level SUCCESS
        Write-Message "Path: $worktreePath" -Level INFO
        Write-Message "Branch: $Branch" -Level INFO
        
        # Display Claude instructions
        Write-Host "`n" + ("=" * 60) -ForegroundColor Cyan
        Write-Host "INSTRUCTIONS FOR CLAUDE CODE:" -ForegroundColor Cyan
        Write-Host ("=" * 60) -ForegroundColor Cyan
        Write-Host $taskConfig.claudeInstructions -ForegroundColor Yellow
        Write-Host ("=" * 60) -ForegroundColor Cyan
        
        return @{
            Success = $true
            WorktreePath = $worktreePath
            Branch = $Branch
            TaskName = $TaskName
        }
        
    } catch {
        Write-Message "Failed to setup worktree: $_" -Level ERROR
        throw
    }
}

function List-Worktrees {
    Write-Message "Listing all worktrees..." -Level INFO
    
    # Get git worktree list
    $gitWorktrees = git worktree list --porcelain | Out-String
    
    # Get configuration
    $config = Get-WorktreeConfig
    
    # Parse git output
    $worktrees = @()
    $currentWorktree = @{}
    
    foreach ($line in $gitWorktrees -split "`n") {
        if ($line -match '^worktree (.+)') {
            if ($currentWorktree.Count -gt 0) {
                $worktrees += $currentWorktree
            }
            $currentWorktree = @{ Path = $matches[1] }
        }
        elseif ($line -match '^HEAD (.+)') {
            $currentWorktree.HEAD = $matches[1]
        }
        elseif ($line -match '^branch (.+)') {
            $currentWorktree.Branch = $matches[1]
        }
    }
    if ($currentWorktree.Count -gt 0) {
        $worktrees += $currentWorktree
    }
    
    # Display worktrees
    Write-Host "`n" + ("=" * 80) -ForegroundColor Cyan
    Write-Host "ACTIVE WORKTREES" -ForegroundColor Cyan
    Write-Host ("=" * 80) -ForegroundColor Cyan
    
    foreach ($wt in $worktrees) {
        $configEntry = $config.worktrees | Where-Object { $_.path -eq $wt.Path } | Select-Object -First 1
        
        Write-Host "`nPath: $($wt.Path)" -ForegroundColor White
        Write-Host "Branch: $($wt.Branch)" -ForegroundColor Yellow
        Write-Host "HEAD: $($wt.HEAD)" -ForegroundColor Gray
        
        if ($configEntry) {
            Write-Host "Task: $($configEntry.name)" -ForegroundColor Green
            Write-Host "Created: $($configEntry.created)" -ForegroundColor Gray
            Write-Host "Purpose: $($configEntry.purpose)" -ForegroundColor Gray
            Write-Host "Status: $($configEntry.status)" -ForegroundColor $(if ($configEntry.status -eq 'active') { 'Green' } else { 'Yellow' })
        }
    }
    
    Write-Host "`n" + ("=" * 80) -ForegroundColor Cyan
    Write-Host "Total worktrees: $($worktrees.Count)" -ForegroundColor White
    
    return $worktrees
}

function Remove-Worktree {
    if (-not $TaskName) {
        throw "TaskName is required for Remove action"
    }
    
    Write-Message "Removing worktree for task: $TaskName" -Level WARNING
    
    $config = Get-WorktreeConfig
    $worktreeEntry = $config.worktrees | Where-Object { $_.name -eq $TaskName } | Select-Object -First 1
    
    if (-not $worktreeEntry) {
        throw "No worktree found for task: $TaskName"
    }
    
    try {
        # Remove git worktree
        if ($Force) {
            git worktree remove --force $worktreeEntry.path
        } else {
            git worktree remove $worktreeEntry.path
        }
        
        # Remove branch if it exists
        $branchExists = git branch --list $worktreeEntry.branch
        if ($branchExists -and $Force) {
            git branch -D $worktreeEntry.branch
        }
        
        # Update configuration
        $config.worktrees = $config.worktrees | Where-Object { $_.name -ne $TaskName }
        Save-WorktreeConfig -Config $config
        
        Write-Message "Worktree removed successfully" -Level SUCCESS
        
    } catch {
        Write-Message "Failed to remove worktree: $_" -Level ERROR
        throw
    }
}

function Clean-Worktrees {
    Write-Message "Cleaning up worktrees..." -Level INFO
    
    # Prune worktrees
    git worktree prune
    
    $config = Get-WorktreeConfig
    $cleaned = 0
    
    # Check each configured worktree
    $activeWorktrees = @()
    foreach ($wt in $config.worktrees) {
        if (Test-Path $wt.path) {
            # Check if it's stale
            $lastAccessed = [DateTime]::Parse($wt.lastAccessed)
            $daysSinceAccess = (Get-Date - $lastAccessed).TotalDays
            
            if ($daysSinceAccess -gt $config.settings.autoCleanDays -and $wt.status -ne 'permanent') {
                Write-Message "Removing stale worktree: $($wt.name) (unused for $([int]$daysSinceAccess) days)" -Level WARNING
                
                if ($Force -or (Read-Host "Remove worktree '$($wt.name)'? [y/N]") -eq 'y') {
                    try {
                        git worktree remove --force $wt.path
                        $cleaned++
                    } catch {
                        Write-Message "Failed to remove: $_" -Level ERROR
                    }
                } else {
                    $activeWorktrees += $wt
                }
            } else {
                $activeWorktrees += $wt
            }
        } else {
            Write-Message "Worktree path missing, removing from config: $($wt.name)" -Level WARNING
            $cleaned++
        }
    }
    
    # Update configuration
    $config.worktrees = $activeWorktrees
    Save-WorktreeConfig -Config $config
    
    Write-Message "Cleaned up $cleaned worktrees" -Level SUCCESS
}

function Get-WorktreeStatus {
    Write-Message "Getting worktree status..." -Level INFO
    
    $config = Get-WorktreeConfig
    $status = @{
        TotalWorktrees = $config.worktrees.Count
        ActiveWorktrees = @($config.worktrees | Where-Object { $_.status -eq 'active' }).Count
        WorktreeDetails = @()
    }
    
    foreach ($wt in $config.worktrees) {
        $details = @{
            Name = $wt.name
            Branch = $wt.branch
            Path = $wt.path
            Exists = Test-Path $wt.path
            Status = $wt.status
            Created = $wt.created
            DaysSinceCreation = [int]((Get-Date) - [DateTime]::Parse($wt.created)).TotalDays
        }
        
        if ($details.Exists) {
            Push-Location $wt.path
            try {
                # Get git status
                $gitStatus = git status --porcelain
                $details.HasChanges = $gitStatus.Count -gt 0
                $details.ChangedFiles = $gitStatus.Count
                
                # Get ahead/behind
                $tracking = git status -sb | Select-Object -First 1
                if ($tracking -match '\[ahead (\d+)\]') {
                    $details.Ahead = [int]$matches[1]
                } else {
                    $details.Ahead = 0
                }
                
                if ($tracking -match '\[behind (\d+)\]') {
                    $details.Behind = [int]$matches[1]
                } else {
                    $details.Behind = 0
                }
            } finally {
                Pop-Location
            }
        }
        
        $status.WorktreeDetails += $details
    }
    
    # Display status
    Write-Host "`n" + ("=" * 80) -ForegroundColor Cyan
    Write-Host "WORKTREE STATUS SUMMARY" -ForegroundColor Cyan
    Write-Host ("=" * 80) -ForegroundColor Cyan
    Write-Host "Total Worktrees: $($status.TotalWorktrees)" -ForegroundColor White
    Write-Host "Active Worktrees: $($status.ActiveWorktrees)" -ForegroundColor Green
    
    foreach ($wt in $status.WorktreeDetails) {
        Write-Host "`n[$($wt.Name)]" -ForegroundColor Yellow
        Write-Host "  Branch: $($wt.Branch)" -ForegroundColor White
        Write-Host "  Status: $($wt.Status)" -ForegroundColor $(if ($wt.Status -eq 'active') { 'Green' } else { 'Gray' })
        Write-Host "  Exists: $($wt.Exists)" -ForegroundColor $(if ($wt.Exists) { 'Green' } else { 'Red' })
        
        if ($wt.Exists) {
            Write-Host "  Changes: $($wt.ChangedFiles) files" -ForegroundColor $(if ($wt.HasChanges) { 'Yellow' } else { 'Green' })
            if ($wt.Ahead -gt 0) {
                Write-Host "  Ahead: $($wt.Ahead) commits" -ForegroundColor Yellow
            }
            if ($wt.Behind -gt 0) {
                Write-Host "  Behind: $($wt.Behind) commits" -ForegroundColor Red
            }
        }
        
        Write-Host "  Age: $($wt.DaysSinceCreation) days" -ForegroundColor Gray
    }
    
    return $status
}

# Main execution
try {
    switch ($Action) {
        'Setup' {
            Setup-Worktree
        }
        'List' {
            List-Worktrees
        }
        'Remove' {
            Remove-Worktree
        }
        'Clean' {
            Clean-Worktrees
        }
        'Status' {
            Get-WorktreeStatus
        }
    }
} catch {
    Write-Message "Operation failed: $_" -Level ERROR
    exit 1
}
#Requires -Version 7.0
<#
.SYNOPSIS
    Branch strategy module for PatchManager
    
.DESCRIPTION
    Provides intelligent branch strategy functions for PatchManager
    to prevent recursive branching and ensure consistent Git workflows.
    
.NOTES
    - Prevents branch explosion with anti-recursive logic
    - Safe for use with protected branches
    - Branch naming follows project standards
    - Clear messaging for branch decisions
#>

function Get-IntelligentBranchStrategy {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PatchDescription,
        
        [Parameter(Mandatory = $false)]
        [string]$CurrentBranch = "main",
        
        [Parameter(Mandatory = $false)]
        [switch]$ForceNewBranch = $false
    )
    
    try {
        Write-Verbose "Analyzing branch strategy for: $PatchDescription"
        
        # Get current branch if not provided
        if ($CurrentBranch -eq "main") {
            $CurrentBranch = git rev-parse --abbrev-ref HEAD 2>$null
            if (-not $CurrentBranch) { $CurrentBranch = "main" }
        }
        
        Write-Verbose "Current branch detected: $CurrentBranch"
        
        # Determine strategy based on current branch
        $strategy = @{
            Success = $true
            CurrentBranch = $CurrentBranch
            SkipBranchCreation = $false
            NewBranchName = $null
            Message = "Branch strategy determined"
        }
        
        # If ForceNewBranch is specified, always create a new branch
        if ($ForceNewBranch) {
            $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
            $cleanDesc = $PatchDescription -replace '[^\w\-]', '-' -replace '-+', '-' -replace '^-|-$', ''
            $strategy.NewBranchName = "patch/$timestamp-$cleanDesc"
            $strategy.SkipBranchCreation = $false
            $strategy.Message = "Force creating new branch: $($strategy.NewBranchName)"
            Write-Verbose "Force creating new patch branch: $($strategy.NewBranchName)"
            return $strategy
        }
        
        # Anti-recursive logic: if already on a feature branch, work in place
        if ($CurrentBranch -match "^(patch|feature|fix|hotfix)/" -and $CurrentBranch -ne "main") {
            $strategy.SkipBranchCreation = $true
            $strategy.NewBranchName = $CurrentBranch
            $strategy.Message = "Working from current feature branch: $CurrentBranch"
            Write-Verbose "Anti-recursive protection: Using current branch $CurrentBranch"
        } 
        # Create new branch if on main branch
        elseif ($CurrentBranch -eq "main" -or $CurrentBranch -eq "master") {
            $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
            $cleanDesc = $PatchDescription -replace '[^\w\-]', '-' -replace '-+', '-' -replace '^-|-$', ''
            $strategy.NewBranchName = "patch/$timestamp-$cleanDesc"
            $strategy.SkipBranchCreation = $false
            $strategy.Message = "Creating new branch from main: $($strategy.NewBranchName)"
            Write-Verbose "Creating new patch branch: $($strategy.NewBranchName)"
        }
        # Default to creating a new branch for any unrecognized branch
        else {
            $timestamp = Get-Date -Format "yyyyMMdd-HHmms"
            $cleanDesc = $PatchDescription -replace '[^\w\-]', '-' -replace '-+', '-' -replace '^-|-$', ''
            $strategy.NewBranchName = "patch/$timestamp-$cleanDesc"
            $strategy.SkipBranchCreation = $false
            $strategy.Message = "Creating new branch: $($strategy.NewBranchName)"
            Write-Verbose "Creating new patch branch from unknown branch: $($strategy.NewBranchName)"
        }
        
        return $strategy
    } catch {
        return @{
            Success = $false
            Message = "Failed to determine branch strategy: $($_.Exception.Message)"
            CurrentBranch = $CurrentBranch
            SkipBranchCreation = $true
            NewBranchName = $CurrentBranch
        }
    }
}

function Test-BranchProtection {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$BranchName,
        
        [Parameter(Mandatory = $false)]
        [string[]]$ProtectedBranches = @("main", "master", "develop", "release/*")
    )
    
    foreach ($protectedPattern in $ProtectedBranches) {
        if ($BranchName -like $protectedPattern) {
            return $true
        }
    }
    
    return $false
}

function Get-SanitizedBranchName {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Description,
        
        [Parameter(Mandatory = $false)]
        [string]$Prefix = "patch",
          [Parameter(Mandatory = $false)]
        [switch]$IncludeTimestamp
    )
    
    # Replace invalid characters and standardize
    $sanitized = $Description -replace '[^a-zA-Z0-9]', '-' -replace '-+', '-' -replace '^-|-$', ''
    
    if ($sanitized.Length -gt 40) {
        $sanitized = $sanitized.Substring(0, 40)
    }
    
    # Default to including timestamp unless explicitly set to false
    if ($PSBoundParameters.ContainsKey('IncludeTimestamp') -eq $false -or $IncludeTimestamp) {
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        return "$Prefix/$timestamp-$sanitized"
    } else {
        return "$Prefix/$sanitized"
    }
}



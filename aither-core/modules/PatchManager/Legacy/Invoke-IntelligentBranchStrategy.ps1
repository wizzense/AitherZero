function Invoke-IntelligentBranchStrategy {
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
        
        # Get current branch
        $currentBranch = git rev-parse --abbrev-ref HEAD 2>$null
        if (-not $currentBranch) { $currentBranch = "main" }
        
        Write-Verbose "Current branch detected: $currentBranch"
        
        # Determine strategy based on current branch
        $strategy = @{
            Success = $true
            CurrentBranch = $currentBranch
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
        if ($currentBranch -match "^(patch|feature|fix|hotfix)/" -and $currentBranch -ne "main") {
            $strategy.SkipBranchCreation = $true
            $strategy.NewBranchName = $currentBranch
            $strategy.Message = "Working from current feature branch: $currentBranch"
            Write-Verbose "Anti-recursive protection: Using current branch $currentBranch"
        } 
        # Create new branch if on main branch
        elseif ($currentBranch -eq "main" -or $currentBranch -eq "master") {
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
            CurrentBranch = $currentBranch
            SkipBranchCreation = $true
            NewBranchName = $currentBranch
        }
    }
}

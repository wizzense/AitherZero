function Show-GitStatusGuidance {
    <#
    .SYNOPSIS
    Provides clear guidance about git status and suggests actions for PatchManager workflows
    
    .DESCRIPTION
    Analyzes the current git status and provides actionable guidance for users when
    git operations fail or when there are uncommitted changes that need attention.
    
    .PARAMETER AutoStage
    Automatically stage all files when working on patch/feature branches
    
    .PARAMETER BranchName
    The current branch name to determine if auto-staging is safe
    
    .EXAMPLE
    Show-GitStatusGuidance -AutoStage -BranchName "patch/fix-something"
    #>
    [CmdletBinding()]
    param(
        [switch]$AutoStage,
        [string]$BranchName = (git branch --show-current 2>$null)
    )

    Write-Host "`n🔍 GIT STATUS ANALYSIS" -ForegroundColor Cyan
    Write-Host "=" * 50 -ForegroundColor Cyan

    # Get detailed git status
    $gitStatus = git status --porcelain 2>$null
    $currentBranch = git branch --show-current 2>$null
    $isPatchBranch = $currentBranch -match '^(patch|feature|fix|hotfix)/'

    if (-not $gitStatus) {
        Write-Host "✅ Working tree is clean - no changes to commit" -ForegroundColor Green
        return $true
    }

    # Categorize changes
    $staged = @()
    $modified = @()
    $untracked = @()
    
    foreach ($line in $gitStatus) {
        $status = $line.Substring(0, 2)
        $file = $line.Substring(3)
        
        switch ($status[0]) {
            'A' { $staged += $file }
            'M' { if ($status[1] -eq ' ') { $staged += $file } else { $modified += $file } }
            'D' { $staged += $file }
            ' ' { $modified += $file }
            '?' { $untracked += $file }
            default { $modified += $file }
        }
    }

    # Display categorized changes
    Write-Host "`n📊 CHANGE SUMMARY:" -ForegroundColor Yellow
    Write-Host "  Current Branch: $currentBranch" -ForegroundColor Gray
    Write-Host "  Is Patch Branch: $(if ($isPatchBranch) { 'Yes ✅' } else { 'No ❌' })" -ForegroundColor Gray

    if ($staged.Count -gt 0) {
        Write-Host "`n✅ STAGED CHANGES ($($staged.Count) files):" -ForegroundColor Green
        $staged | Sort-Object | ForEach-Object { Write-Host "  + $_" -ForegroundColor Green }
    }

    if ($modified.Count -gt 0) {
        Write-Host "`n📝 MODIFIED FILES ($($modified.Count) files):" -ForegroundColor Yellow
        $modified | Sort-Object | ForEach-Object { Write-Host "  M $_" -ForegroundColor Yellow }
    }

    if ($untracked.Count -gt 0) {
        Write-Host "`n📄 UNTRACKED FILES ($($untracked.Count) files):" -ForegroundColor Magenta
        $untracked | Sort-Object | ForEach-Object { Write-Host "  ? $_" -ForegroundColor Magenta }
    }

    # Provide actionable guidance
    Write-Host "`n💡 RECOMMENDED ACTIONS:" -ForegroundColor Cyan

    if ($isPatchBranch -and $AutoStage) {
        Write-Host "  🔧 Auto-staging enabled for patch branch..." -ForegroundColor Green
        
        if ($modified.Count -gt 0 -or $untracked.Count -gt 0) {
            Write-Host "  📝 Staging all changes..." -ForegroundColor Yellow
            
            try {
                git add . 2>&1 | Out-Null
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "  ✅ All changes staged successfully" -ForegroundColor Green
                    return $true
                } else {
                    Write-Host "  ❌ Auto-staging failed. Manual intervention required." -ForegroundColor Red
                    return $false
                }
            } catch {
                Write-Host "  ❌ Auto-staging error: $($_.Exception.Message)" -ForegroundColor Red
                return $false
            }
        }
    } else {
        # Manual guidance
        if ($modified.Count -gt 0) {
            Write-Host "  1️⃣  Stage modified files: git add ." -ForegroundColor White
            Write-Host "     Or stage specific files: git add <filename>" -ForegroundColor Gray
        }
        
        if ($untracked.Count -gt 0) {
            Write-Host "  2️⃣  Add untracked files: git add ." -ForegroundColor White
            Write-Host "     Or ignore them: echo 'filename' >> .gitignore" -ForegroundColor Gray
        }
        
        if ($staged.Count -gt 0 -and ($modified.Count -gt 0 -or $untracked.Count -gt 0)) {
            Write-Host "  3️⃣  Commit staged changes: git commit -m 'Your message'" -ForegroundColor White
        } elseif ($staged.Count -gt 0) {
            Write-Host "  3️⃣  Commit ready! Run: git commit -m 'Your message'" -ForegroundColor White
        }

        if (-not $isPatchBranch) {
            Write-Host "`n⚠️  WARNING: Not on a patch/feature branch!" -ForegroundColor Red
            Write-Host "     Consider creating a branch: git checkout -b patch/your-feature-name" -ForegroundColor Yellow
        }
    }

    Write-Host "`n🔧 PATCHMANAGER INTEGRATION:" -ForegroundColor Cyan
    Write-Host "  To enable auto-staging on patch branches, use:" -ForegroundColor White
    Write-Host "  Invoke-PatchWorkflow -AutoStage -PatchDescription 'Your description' ..." -ForegroundColor Gray

    Write-Host "=" * 50 -ForegroundColor Cyan

    return ($staged.Count -gt 0 -and $modified.Count -eq 0 -and $untracked.Count -eq 0)
}

function Invoke-PatchWorkflowEnhanced {
    <#
    .SYNOPSIS
    Enhanced PatchManager workflow with improved git status handling
    
    .DESCRIPTION
    Wrapper around Invoke-PatchWorkflow that provides better git status reporting
    and guidance when operations fail.
    
    .PARAMETER AutoStage
    Automatically stage files when working on patch/feature branches
    
    .PARAMETER ShowGitGuidance
    Show detailed git status and guidance before proceeding
    #>
    [CmdletBinding()]
    param(
        [switch]$AutoStage,
        [switch]$ShowGitGuidance = $true,
        [Parameter(Mandatory)]
        [string]$PatchDescription,
        [Parameter(Mandatory)]
        [scriptblock]$PatchOperation,
        [switch]$CreatePR,
        [switch]$CreateIssue = $true,
        [string]$Priority = "Medium"
    )

    if ($ShowGitGuidance) {
        $currentBranch = git branch --show-current 2>$null
        $gitStatus = Show-GitStatusGuidance -AutoStage:$AutoStage -BranchName $currentBranch
        
        if (-not $gitStatus -and -not $AutoStage) {
            Write-Host "`n❌ Git working tree needs attention before proceeding." -ForegroundColor Red
            Write-Host "   Use the guidance above or run with -AutoStage to handle automatically." -ForegroundColor Yellow
            return @{ Success = $false; Message = "Git working tree requires attention" }
        }
    }

    # Call the original PatchManager workflow
    try {
        Import-Module (Join-Path $env:PWSH_MODULES_PATH "PatchManager/PatchManager.psm1") -Force
        
        $result = Invoke-PatchWorkflow -PatchDescription $PatchDescription -PatchOperation $PatchOperation -CreatePR:$CreatePR -CreateIssue:$CreateIssue -Priority $Priority
        
        if (-not $result.Success) {
            Write-Host "`n❌ PatchManager workflow failed!" -ForegroundColor Red
            Write-Host "📋 Checking git status for troubleshooting..." -ForegroundColor Yellow
            Show-GitStatusGuidance -BranchName (git branch --show-current 2>$null)
        }
        
        return $result
    } catch {
        Write-Host "`n❌ PatchManager workflow error: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "📋 Current git status:" -ForegroundColor Yellow
        Show-GitStatusGuidance -BranchName (git branch --show-current 2>$null)
        throw
    }
}

# Functions are exported by the main module file


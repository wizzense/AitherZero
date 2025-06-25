#Requires -Version 7.0

<#
.SYNOPSIS
    Convert AitherZero from fork to standalone public repository
.DESCRIPTION
    Breaks fork relationship and sets up bidirectional sync with aitherlab
.EXAMPLE
    .\convert-to-standalone.ps1 -NewOrigin "https://github.com/yourusername/AitherZero.git"
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string]$NewOrigin,
    
    [string]$AitherLabRepo = "https://github.com/yourusername/aitherlab.git",
    
    [switch]$Force
)

begin {
    Import-Module './aither-core/modules/Logging' -Force
    Write-CustomLog -Level 'INFO' -Message "Starting AitherZero standalone conversion"
}

process {
    try {
        # Verify we're in a git repository
        if (-not (Test-Path '.git')) {
            throw "Not in a git repository"
        }
        
        # Check for uncommitted changes
        $status = git status --porcelain
        if ($status -and -not $Force) {
            Write-CustomLog -Level 'WARN' -Message "Uncommitted changes detected:"
            $status | ForEach-Object { Write-Host "  $_" }
            throw "Working directory has uncommitted changes. Use -Force to override."
        }
        
        # Save current branch
        $currentBranch = git branch --show-current
        Write-CustomLog -Level 'INFO' -Message "Current branch: $currentBranch"
        
        if ($PSCmdlet.ShouldProcess("Repository", "Convert to standalone")) {
            # Remove existing remotes
            Write-CustomLog -Level 'INFO' -Message "Removing existing remotes"
            $remotes = git remote
            foreach ($remote in $remotes) {
                git remote remove $remote
                Write-CustomLog -Level 'INFO' -Message "Removed remote: $remote"
            }
            
            # Add new origin (standalone repo)
            Write-CustomLog -Level 'INFO' -Message "Adding new origin: $NewOrigin"
            git remote add origin $NewOrigin
            
            # Add aitherlab as upstream for syncing
            Write-CustomLog -Level 'INFO' -Message "Adding aitherlab upstream: $AitherLabRepo"
            git remote add aitherlab $AitherLabRepo
            
            # Push to new origin
            Write-CustomLog -Level 'INFO' -Message "Pushing to new origin"
            git push -u origin $currentBranch
            git push origin --all
            git push origin --tags
            
            Write-CustomLog -Level 'SUCCESS' -Message "Repository converted successfully!"
            Write-Host "`nConfigured remotes:" -ForegroundColor Green
            git remote -v
        }
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Conversion failed: $($_.Exception.Message)"
        throw
    }
}

end {
    Write-CustomLog -Level 'INFO' -Message "Conversion process completed"
}

#Requires -Version 7.0

<#
.SYNOPSIS
    Repository synchronization management script
.DESCRIPTION
    Manages sync operations between AitherZero (public) and aitherlab (private)
.EXAMPLE
    .\sync-repos.ps1 -Action ToAitherLab -Message "Add new feature"
.EXAMPLE
    .\sync-repos.ps1 -Action FromAitherLab -DryRun
.EXAMPLE
    .\sync-repos.ps1 -Action Status
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('ToAitherLab', 'FromAitherLab', 'Status')]
    [string]$Action,
    
    [string]$Message = "Manual sync",
    
    [string[]]$Files = @(),
    
    [switch]$DryRun,
    
    [switch]$Force
)

begin {
    # Import required modules
    Import-Module './aither-core/modules/RepoSync' -Force
    Import-Module './aither-core/modules/Logging' -Force
    
    Write-CustomLog -Level 'INFO' -Message "Repository sync operation: $Action"
}

process {
    try {
        switch ($Action) {
            'ToAitherLab' {
                Write-CustomLog -Level 'INFO' -Message "Syncing changes to aitherlab"
                
                if ($DryRun) {
                    Write-Host "DRY RUN: Would sync to aitherlab with message: '$Message'" -ForegroundColor Yellow
                    if ($Files.Count -gt 0) {
                        Write-Host "Files to sync: $($Files -join ', ')" -ForegroundColor Yellow
                    }
                    return
                }
                
                Sync-ToAitherLab -CommitMessage $Message -FilesToSync $Files -Force:$Force -CreatePR
            }
            
            'FromAitherLab' {
                Write-CustomLog -Level 'INFO' -Message "Pulling changes from aitherlab"
                Sync-FromAitherLab -DryRun:$DryRun
            }
            
            'Status' {
                Get-SyncStatus
            }
        }
        
        Write-CustomLog -Level 'SUCCESS' -Message "Sync operation '$Action' completed successfully"
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Sync operation failed: $($_.Exception.Message)"
        throw
    }
}

end {
    Write-CustomLog -Level 'INFO' -Message "Sync operation finished"
}

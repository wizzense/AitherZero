#Requires -Version 7.0

<#
.SYNOPSIS
    Emergency hotfix function for critical issues

.DESCRIPTION
    Specialized function for emergency hotfixes that:
    - Forces High priority
    - Always creates PR for safety review
    - Creates critical tracking issue
    - Uses Standard mode with extra safety checks
    - Provides clear warnings and guidance

.PARAMETER Description
    Description of the critical issue being fixed

.PARAMETER Changes
    Script block containing the hotfix

.PARAMETER SkipPR
    Skip PR creation for truly emergency situations (not recommended)

.PARAMETER DryRun
    Preview the hotfix without applying it

.EXAMPLE
    New-Hotfix -Description "Fix critical security vulnerability in auth module" -Changes {
        # Apply security fix
        Update-AuthenticationSecurity
    }

.EXAMPLE
    New-Hotfix -Description "Emergency production fix" -DryRun -Changes {
        # Preview critical fix
        Fix-ProductionIssue
    }
#>

function New-Hotfix {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Description,

        [Parameter(Mandatory = $true)]
        [scriptblock]$Changes,

        [Parameter(Mandatory = $false)]
        [switch]$SkipPR,

        [Parameter(Mandatory = $false)]
        [switch]$DryRun
    )

    Write-Host "[HOTFIX] CRITICAL: $Description" -ForegroundColor Red

    # Warning for hotfixes
    if (-not $DryRun) {
        Write-Host "WARNING: Creating emergency hotfix. This will:" -ForegroundColor Yellow
        Write-Host "  - Create high-priority tracking issue" -ForegroundColor Yellow
        if (-not $SkipPR) {
            Write-Host "  - Create PR for emergency review" -ForegroundColor Yellow
        } else {
            Write-Host "  - Apply changes directly (PR skipped)" -ForegroundColor Red
        }
        
        # Brief pause for awareness
        Start-Sleep -Seconds 2
    }

    $createPR = -not $SkipPR

    return New-Patch -Description "HOTFIX: $Description" -Changes $Changes -Mode "Standard" -CreatePR:$createPR -CreateIssue $true -DryRun:$DryRun -Force
}

Export-ModuleMember -Function New-Hotfix
#Requires -Version 7.0

<#
.SYNOPSIS
    Quick fix function for simple, low-risk changes

.DESCRIPTION
    Simplified function for making quick fixes without the overhead of branch management.
    Perfect for typos, formatting, minor documentation updates, etc.

    This function:
    - Forces Simple mode operation
    - Applies changes directly to current branch
    - No PR or issue creation
    - Minimal overhead and complexity

.PARAMETER Description
    Brief description of the fix

.PARAMETER Changes
    Script block containing the changes

.PARAMETER DryRun
    Preview changes without applying them

.EXAMPLE
    New-QuickFix -Description "Fix typo in comment" -Changes {
        $file = Get-Content "script.ps1"
        $file = $file -replace "teh", "the"
        Set-Content "script.ps1" -Value $file
    }

.EXAMPLE
    New-QuickFix -Description "Update log message" -Changes {
        $content = Get-Content "module.ps1"
        $content = $content -replace "Starting process", "Initializing process"
        Set-Content "module.ps1" -Value $content
    }
#>

function New-QuickFix {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Description,

        [Parameter(Mandatory = $true)]
        [scriptblock]$Changes,

        [Parameter(Mandatory = $false)]
        [switch]$DryRun
    )

    Write-Host "[QUICK FIX] $Description" -ForegroundColor Cyan

    return New-Patch -Description $Description -Changes $Changes -Mode "Simple" -CreatePR:$false -CreateIssue $false -OperationType 'QuickFix' -DryRun:$DryRun
}

Export-ModuleMember -Function New-QuickFix
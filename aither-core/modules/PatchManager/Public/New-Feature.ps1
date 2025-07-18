#Requires -Version 7.0

<#
.SYNOPSIS
    Feature development function with full workflow automation

.DESCRIPTION
    Optimized function for feature development that automatically:
    - Creates a new branch
    - Applies changes
    - Creates GitHub issue for tracking
    - Creates pull request for review
    - Uses Standard mode with full safety checks

.PARAMETER Description
    Description of the feature being developed

.PARAMETER Changes
    Script block containing the feature implementation

.PARAMETER Priority
    Priority level for the GitHub issue (Low, Medium, High, Critical)

.PARAMETER TargetFork
    Target fork for cross-repository features

.PARAMETER DryRun
    Preview the workflow without making changes

.EXAMPLE
    New-Feature -Description "Add user authentication module" -Changes {
        # Implement authentication
        New-Item "auth-module.ps1"
        # ... implementation code
    }

.EXAMPLE
    New-Feature -Description "Enterprise logging integration" -Priority "High" -Changes {
        # Implement enterprise features
        Update-LoggingSystem
    }

.EXAMPLE
    New-Feature -Description "Cross-fork enhancement" -TargetFork "upstream" -Changes {
        # Feature for upstream repository
        Add-PublicFeature
    }
#>

function New-Feature {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Description,

        [Parameter(Mandatory = $true)]
        [scriptblock]$Changes,

        [Parameter(Mandatory = $false)]
        [ValidateSet("Low", "Medium", "High", "Critical")]
        [string]$Priority = "Medium",

        [Parameter(Mandatory = $false)]
        [ValidateSet("current", "upstream", "root")]
        [string]$TargetFork = "current",

        [Parameter(Mandatory = $false)]
        [switch]$DryRun,

        [Parameter(Mandatory = $false)]
        [switch]$AutoTag,

        [Parameter(Mandatory = $false)]
        [switch]$FastTrack
    )

    Write-Host "[FEATURE] $Description" -ForegroundColor Green

    # Determine mode based on target fork
    $mode = if ($TargetFork -ne "current") { "Advanced" } else { "Standard" }

    return New-Patch -Description $Description -Changes $Changes -Mode $mode -CreatePR:$true -CreateIssue:$true -TargetFork $TargetFork -OperationType 'Feature' -DryRun:$DryRun -AutoTag:$AutoTag -FastTrack:$FastTrack
}

Export-ModuleMember -Function New-Feature

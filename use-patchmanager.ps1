#!/usr/bin/env pwsh
# Helper script to use PatchManager properly

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('QuickFix', 'Feature', 'Patch', 'Hotfix')]
    [string]$Type,
    
    [Parameter(Mandatory=$true)]
    [string]$Description,
    
    [switch]$CreatePR,
    [switch]$DryRun
)

Import-Module ./aither-core/modules/PatchManager -Force

switch ($Type) {
    'QuickFix' {
        New-QuickFix -Description $Description -DryRun:$DryRun
    }
    'Feature' {
        New-Feature -Description $Description -CreatePR:$CreatePR -DryRun:$DryRun
    }
    'Patch' {
        New-Patch -Description $Description -CreatePR:$CreatePR -DryRun:$DryRun
    }
    'Hotfix' {
        New-Hotfix -Description $Description -CreatePR:$CreatePR -DryRun:$DryRun
    }
}
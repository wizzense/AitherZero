#Requires -Version 7.0

<#
.SYNOPSIS
    Set the active workspace project context
.DESCRIPTION
    Switches the active project context, allowing AitherZero tools to operate
    on the specified project instead of AitherZero itself.

    Exit Codes:
    0   - Success
    1   - Error

.NOTES
    Stage: Workspace
    Order: 0602
    Category: OSS Projects
    Tags: workspace, oss, context
#>

[CmdletBinding(DefaultParameterSetName = 'SetProject')]
param(
    [Parameter(Mandatory, ParameterSetName = 'SetProject', Position = 0)]
    [string]$Project,

    [Parameter(Mandatory, ParameterSetName = 'Reset')]
    [switch]$Reset
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Import workspace module
$projectRoot = Split-Path $PSScriptRoot -Parent
$workspaceModule = Join-Path $projectRoot "domains/workspace/WorkspaceManager.psm1"

if (-not (Test-Path $workspaceModule)) {
    Write-Error "Workspace module not found at: $workspaceModule"
    exit 1
}

Import-Module $workspaceModule -Force

Write-Host "`n=== AitherZero Workspace Context ===" -ForegroundColor Cyan
Write-Host ""

try {
    if ($Reset) {
        Set-WorkspaceContext -Reset
    } else {
        Set-WorkspaceContext -Project $Project
    }
    
    Write-Host ""
    Write-Host "You can now use AitherZero tools on this project:" -ForegroundColor Yellow
    Write-Host "  - az 0402  (Run tests)" -ForegroundColor Gray
    Write-Host "  - az 0404  (PSScriptAnalyzer)" -ForegroundColor Gray
    Write-Host "  - az 0510  (Generate report)" -ForegroundColor Gray
    Write-Host "  - az 0701  (Create branch)" -ForegroundColor Gray
    Write-Host ""
    
    exit 0
} catch {
    Write-Error "Failed to set workspace context: $_"
    exit 1
}

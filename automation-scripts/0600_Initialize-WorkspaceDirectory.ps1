#Requires -Version 7.0

<#
.SYNOPSIS
    Initialize the OSS workspace directory
.DESCRIPTION
    Creates the workspace directory structure for managing external open-source projects.
    This is the first step in setting up the OSS directory feature.

    Exit Codes:
    0   - Success
    1   - Error

.NOTES
    Stage: Workspace
    Order: 0600
    Category: OSS Projects
    Tags: workspace, oss, initialization
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$Force
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

Write-Host "`n=== AitherZero OSS Workspace Initialization ===" -ForegroundColor Cyan
Write-Host ""

try {
    $workspaceRoot = Initialize-WorkspaceDirectory -Force:$Force
    
    Write-Host "✓ Workspace initialized successfully!" -ForegroundColor Green
    Write-Host "  Location: " -NoNewline
    Write-Host $workspaceRoot -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "  1. Create a new project:  " -NoNewline; Write-Host "az 0601 -Name 'my-project'" -ForegroundColor White
    Write-Host "  2. Clone a repository:    " -NoNewline; Write-Host "az 0601 -Name 'project' -Clone 'https://...'" -ForegroundColor White
    Write-Host "  3. List projects:         " -NoNewline; Write-Host "az 0603" -ForegroundColor White
    Write-Host "  4. Switch to a project:   " -NoNewline; Write-Host "az 0602 -Project 'my-project'" -ForegroundColor White
    Write-Host ""
    
    exit 0
} catch {
    Write-Error "Failed to initialize workspace: $_"
    exit 1
}

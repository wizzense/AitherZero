#Requires -Version 7.0

<#
.SYNOPSIS
    List all projects in the workspace
.DESCRIPTION
    Displays information about all projects in the OSS workspace directory.

    Exit Codes:
    0   - Success
    1   - Error

.NOTES
    Stage: Workspace
    Order: 0603
    Category: OSS Projects
    Tags: workspace, oss, projects
#>

[CmdletBinding()]
param()

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

Write-Host "`n=== AitherZero Workspace Projects ===" -ForegroundColor Cyan
Write-Host ""

try {
    $projects = @(Get-WorkspaceProjects)
    $workspaceRoot = Get-WorkspaceRoot
    $context = Get-WorkspaceContext
    
    if ($projects.Count -eq 0) {
        Write-Host "No projects found in workspace." -ForegroundColor Yellow
        Write-Host "  Workspace: $workspaceRoot" -ForegroundColor Gray
        Write-Host ""
        Write-Host "Create a new project with: " -NoNewline
        Write-Host "az 0601 -Name 'my-project'" -ForegroundColor White
        Write-Host ""
    } else {
        Write-Host "Workspace: " -NoNewline -ForegroundColor Gray
        Write-Host $workspaceRoot -ForegroundColor White
        
        if ($context.IsActive) {
            Write-Host "Active Project: " -NoNewline -ForegroundColor Yellow
            Write-Host $context.Project -ForegroundColor Cyan
        } else {
            Write-Host "Active Project: " -NoNewline -ForegroundColor Gray
            Write-Host "(none - using AitherZero context)" -ForegroundColor White
        }
        
        Write-Host ""
        Write-Host "Projects:" -ForegroundColor Cyan
        Write-Host ("=" * 80) -ForegroundColor Gray
        
        foreach ($project in $projects) {
            $marker = if ($context.Project -eq $project.Name) { "→" } else { " " }
            $gitIcon = if ($project.IsGitRepo) { "[Git]" } else { "     " }
            
            Write-Host " $marker " -NoNewline -ForegroundColor $(if ($marker -eq "→") { "Cyan" } else { "Gray" })
            Write-Host $gitIcon -NoNewline -ForegroundColor Green
            Write-Host " " -NoNewline
            Write-Host $project.Name -ForegroundColor $(if ($marker -eq "→") { "Cyan" } else { "White" })
            Write-Host "      Path: $($project.Path)" -ForegroundColor Gray
            Write-Host "      Modified: $($project.LastModified)" -ForegroundColor Gray
            
            if ($project.HasAitherZero) {
                Write-Host "      AitherZero: ✓ Configured" -ForegroundColor Green
            } else {
                Write-Host "      AitherZero: Not configured" -ForegroundColor Yellow
            }
            Write-Host ""
        }
        
        Write-Host ("=" * 80) -ForegroundColor Gray
        Write-Host "Total: $($projects.Count) project(s)" -ForegroundColor White
        Write-Host ""
        
        if (-not $context.IsActive) {
            Write-Host "To switch to a project: " -NoNewline -ForegroundColor Yellow
            Write-Host "az 0602 -Project '<name>'" -ForegroundColor White
        } else {
            Write-Host "To reset context: " -NoNewline -ForegroundColor Yellow
            Write-Host "az 0602 -Reset" -ForegroundColor White
        }
        Write-Host ""
    }
    
    exit 0
} catch {
    Write-Error "Failed to list workspace projects: $_"
    exit 1
}

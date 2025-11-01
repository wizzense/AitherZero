#Requires -Version 7.0

<#
.SYNOPSIS
    Workspace Management for AitherZero OSS Projects
.DESCRIPTION
    Manages external open-source projects in a dedicated workspace directory,
    enabling AitherZero capabilities to be used across multiple projects.
.NOTES
    Copyright © 2025 Aitherium Corporation
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Module state
$script:ProjectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$script:WorkspaceState = @{
    ActiveProject = $null
    WorkspaceRoot = $null
    Projects = @{}
}

# Logging helper
function Write-WorkspaceLog {
    param(
        [string]$Message,
        [string]$Level = 'Information',
        [hashtable]$Data = @{}
    )

    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Level $Level -Message $Message -Source "WorkspaceManager" -Data $Data
    } else {
        Write-Host "[$Level] [WorkspaceManager] $Message"
    }
}

function Get-WorkspaceRoot {
    <#
    .SYNOPSIS
        Get the workspace root directory path
    .DESCRIPTION
        Returns the configured workspace directory path, creating it if necessary.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    # Check if already cached
    if ($script:WorkspaceState.WorkspaceRoot) {
        return $script:WorkspaceState.WorkspaceRoot
    }

    # Get from configuration
    $config = if (Get-Command Get-AitherConfiguration -ErrorAction SilentlyContinue) {
        Get-AitherConfiguration
    } else {
        @{ Workspace = @{ Directory = './oss-projects' } }
    }

    $workspaceDir = $config.Workspace?.Directory ?? './oss-projects'
    
    # Resolve relative to AitherZero root
    if (-not [System.IO.Path]::IsPathRooted($workspaceDir)) {
        $workspaceDir = Join-Path $script:ProjectRoot $workspaceDir
    }

    # Normalize path
    $workspaceDir = [System.IO.Path]::GetFullPath($workspaceDir)
    
    $script:WorkspaceState.WorkspaceRoot = $workspaceDir
    return $workspaceDir
}

function Initialize-WorkspaceDirectory {
    <#
    .SYNOPSIS
        Initialize the OSS workspace directory
    .DESCRIPTION
        Creates the workspace directory structure and configuration files.
    .PARAMETER Force
        Recreate directory if it already exists
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [switch]$Force
    )

    $workspaceRoot = Get-WorkspaceRoot
    
    if (Test-Path $workspaceRoot) {
        if ($Force) {
            Write-WorkspaceLog "Workspace directory exists, recreating due to -Force" -Level 'Warning'
        } else {
            Write-WorkspaceLog "Workspace directory already exists" -Level 'Information'
            return $workspaceRoot
        }
    }

    if ($PSCmdlet.ShouldProcess($workspaceRoot, "Create workspace directory")) {
        New-Item -ItemType Directory -Path $workspaceRoot -Force | Out-Null
        Write-WorkspaceLog "Created workspace directory" -Data @{ Path = $workspaceRoot }

        # Create README
        $readmePath = Join-Path $workspaceRoot 'README.md'
        $readme = @"
# AitherZero OSS Projects Workspace

This directory contains external open-source projects managed by AitherZero.

## Directory Structure

Each project in this workspace has:
- Project files (source code, tests, documentation)
- ``.aitherzero/`` directory with:
  - ``config.psd1`` - Project-specific configuration
  - ``workspace.psd1`` - Workspace metadata

## Usage

````powershell
# List all workspace projects
az 0603

# Switch to a project
az 0602 -Project "project-name"

# Use AitherZero tools on the active project
az 0402  # Run tests
az 0404  # PSScriptAnalyzer
az 0510  # Generate report
````

## Managed by AitherZero

This workspace is managed by AitherZero.
See https://github.com/wizzense/AitherZero for more information.
"@
        $readme | Set-Content -Path $readmePath
    }

    return $workspaceRoot
}

function Get-WorkspaceProjects {
    <#
    .SYNOPSIS
        List all projects in the workspace
    .DESCRIPTION
        Returns information about all projects in the workspace directory.
    #>
    [CmdletBinding()]
    [OutputType([hashtable[]])]
    param()

    $workspaceRoot = Get-WorkspaceRoot
    
    if (-not (Test-Path $workspaceRoot)) {
        Write-WorkspaceLog "Workspace not initialized" -Level 'Warning'
        return @()
    }

    $projects = @()
    $projectDirs = Get-ChildItem -Path $workspaceRoot -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne '.git' }

    foreach ($dir in $projectDirs) {
        $aitherDir = Join-Path $dir.FullName '.aitherzero'
        $hasAitherConfig = Test-Path $aitherDir

        $projectInfo = @{
            Name = $dir.Name
            Path = $dir.FullName
            HasAitherZero = $hasAitherConfig
            LastModified = $dir.LastWriteTime
        }

        # Check if it's a git repository
        $gitDir = Join-Path $dir.FullName '.git'
        $projectInfo.IsGitRepo = Test-Path $gitDir

        $projects += $projectInfo
    }

    return $projects
}

function Set-WorkspaceContext {
    <#
    .SYNOPSIS
        Set the active workspace project context
    .DESCRIPTION
        Switches the active project context, allowing AitherZero tools to operate
        on the specified project.
    .PARAMETER Project
        Name of the project to activate
    .PARAMETER Reset
        Reset to AitherZero context (no active project)
    #>
    [CmdletBinding(DefaultParameterSetName = 'SetProject')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'SetProject', Position = 0)]
        [string]$Project,

        [Parameter(Mandatory, ParameterSetName = 'Reset')]
        [switch]$Reset
    )

    if ($Reset) {
        $script:WorkspaceState.ActiveProject = $null
        $env:AITHERZERO_WORKSPACE_ACTIVE = 'false'
        $env:AITHERZERO_WORKSPACE_PROJECT = $null
        $env:AITHERZERO_WORKSPACE_ROOT = $null
        
        Write-WorkspaceLog "Reset to AitherZero context"
        Write-Host "✓ Workspace context reset" -ForegroundColor Green
        return
    }

    $workspaceRoot = Get-WorkspaceRoot
    $projectPath = Join-Path $workspaceRoot $Project

    if (-not (Test-Path $projectPath)) {
        throw "Project '$Project' not found in workspace"
    }

    $script:WorkspaceState.ActiveProject = $Project
    $env:AITHERZERO_WORKSPACE_ACTIVE = 'true'
    $env:AITHERZERO_WORKSPACE_PROJECT = $Project
    $env:AITHERZERO_WORKSPACE_ROOT = $projectPath

    Write-WorkspaceLog "Activated workspace project" -Data @{ Project = $Project; Path = $projectPath }
    Write-Host "✓ Workspace context set to: " -ForegroundColor Green -NoNewline
    Write-Host $Project -ForegroundColor Cyan
    Write-Host "  Path: $projectPath" -ForegroundColor Gray
}

function Get-WorkspaceContext {
    <#
    .SYNOPSIS
        Get the current workspace context
    .DESCRIPTION
        Returns information about the currently active workspace project.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    $context = @{
        IsActive = $env:AITHERZERO_WORKSPACE_ACTIVE -eq 'true'
        Project = $env:AITHERZERO_WORKSPACE_PROJECT
        ProjectRoot = $env:AITHERZERO_WORKSPACE_ROOT
        WorkspaceRoot = Get-WorkspaceRoot
    }

    return $context
}

function Test-IsWorkspaceProject {
    <#
    .SYNOPSIS
        Check if currently in a workspace project context
    .DESCRIPTION
        Returns true if a workspace project is currently active.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    return $env:AITHERZERO_WORKSPACE_ACTIVE -eq 'true'
}

# Module initialization
Write-WorkspaceLog "Workspace Manager module initialized"

# Export functions
Export-ModuleMember -Function @(
    'Get-WorkspaceRoot',
    'Initialize-WorkspaceDirectory',
    'Get-WorkspaceProjects',
    'Set-WorkspaceContext',
    'Get-WorkspaceContext',
    'Test-IsWorkspaceProject'
)

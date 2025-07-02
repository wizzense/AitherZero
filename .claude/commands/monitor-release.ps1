#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Monitors the release build pipeline
.DESCRIPTION
    Watches the GitHub Actions build pipeline after creating a release tag
.PARAMETER Version
    The version to monitor. If not provided, reads from VERSION file.
.EXAMPLE
    ./monitor-release.ps1
    Monitors current version build
#>

[CmdletBinding()]
param(
    [string]$Version
)

$ErrorActionPreference = 'Stop'

function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = 'White'
    )
    Write-Host $Message -ForegroundColor $Color
}

try {
    Write-ColorOutput "🔍 AitherZero Release Monitor" -Color 'Cyan'
    Write-ColorOutput "=============================" -Color 'Cyan'
    
    # Get version if not provided
    if (-not $Version) {
        $projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        $versionFile = Join-Path $projectRoot "VERSION"
        if (Test-Path $versionFile) {
            $Version = (Get-Content $versionFile -Raw).Trim()
        } else {
            throw "VERSION file not found and no version specified!"
        }
    }
    
    Write-ColorOutput "`nMonitoring release v$Version" -Color 'Yellow'
    
    # Check if gh CLI is available
    $ghAvailable = Get-Command gh -ErrorAction SilentlyContinue
    
    if ($ghAvailable) {
        Write-ColorOutput "`nFetching workflow runs..." -Color 'Green'
        
        # Get the latest workflow run
        $runs = gh run list --workflow="Build & Release Pipeline" --limit 5 --json headBranch,status,conclusion,createdAt,databaseId,name
        $runData = $runs | ConvertFrom-Json
        
        # Find run for our tag
        $ourRun = $runData | Where-Object { $_.headBranch -eq "v$Version" } | Select-Object -First 1
        
        if ($ourRun) {
            Write-ColorOutput "`nFound build for v$Version!" -Color 'Green'
            Write-ColorOutput "Status: $($ourRun.status)" -Color 'Yellow'
            Write-ColorOutput "Run ID: $($ourRun.databaseId)" -Color 'White'
            
            if ($ourRun.status -eq "in_progress") {
                Write-ColorOutput "`nWatching build progress..." -Color 'Yellow'
                Write-ColorOutput "Press Ctrl+C to stop monitoring" -Color 'Gray'
                
                # Watch the run
                gh run watch $ourRun.databaseId
            } elseif ($ourRun.status -eq "completed") {
                if ($ourRun.conclusion -eq "success") {
                    Write-ColorOutput "`n✅ Build completed successfully!" -Color 'Green'
                } else {
                    Write-ColorOutput "`n❌ Build failed with status: $($ourRun.conclusion)" -Color 'Red'
                }
                
                # Show run details
                gh run view $ourRun.databaseId
            }
        } else {
            Write-ColorOutput "`n⏳ Build for v$Version not found yet." -Color 'Yellow'
            Write-ColorOutput "It may take a minute for GitHub Actions to start." -Color 'Gray'
            
            # Show recent runs
            Write-ColorOutput "`nRecent workflow runs:" -Color 'Cyan'
            gh run list --workflow="Build & Release Pipeline" --limit 5
        }
        
        Write-ColorOutput "`nView all runs at:" -Color 'Cyan'
        Write-ColorOutput "https://github.com/wizzense/AitherZero/actions/workflows/build-release.yml" -Color 'White'
        
    } else {
        Write-ColorOutput "`n⚠️  GitHub CLI (gh) not found!" -Color 'Yellow'
        Write-ColorOutput "Install it from: https://cli.github.com/" -Color 'White'
        Write-ColorOutput "`nManually monitor at:" -Color 'Cyan'
        Write-ColorOutput "https://github.com/wizzense/AitherZero/actions" -Color 'White'
    }
    
    Write-ColorOutput "`nRelease page:" -Color 'Cyan'
    Write-ColorOutput "https://github.com/wizzense/AitherZero/releases/tag/v$Version" -Color 'White'
    
} catch {
    Write-ColorOutput "`n❌ Error: $_" -Color 'Red'
    exit 1
}
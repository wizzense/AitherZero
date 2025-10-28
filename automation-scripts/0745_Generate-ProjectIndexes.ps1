#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Generate navigable index.md files for entire project structure
.DESCRIPTION
    Automatically generates index.md files for all directories in the project,
    creating a fully navigable documentation structure. Features:
    - Hierarchical breadcrumb navigation (parent ← current → children)
    - Change detection - only updates when content changes
    - Bidirectional navigation between directories
    - Automatic README.md generation for empty directories
    - Integration with Git workflows
.PARAMETER Mode
    Generation mode:
    - Full: Regenerate all indexes regardless of changes
    - Incremental: Only update directories with changes (default)
    - Verify: Check which directories need updates without generating
.PARAMETER RootPath
    Root path to start indexing from (defaults to project root)
.PARAMETER Force
    Force regeneration even if content hasn't changed
.PARAMETER UpdateManifest
    Update AitherZero.psd1 manifest with new functions
.EXAMPLE
    ./0745_Generate-ProjectIndexes.ps1
    Generate indexes incrementally (only changed directories)
.EXAMPLE
    ./0745_Generate-ProjectIndexes.ps1 -Mode Full -Force
    Regenerate all indexes regardless of changes
.EXAMPLE
    ./0745_Generate-ProjectIndexes.ps1 -Mode Verify
    Check which directories need index updates
#>

# Script metadata
# Stage: AI & Documentation
# Dependencies: 0744 (Auto Documentation)
# Description: Automated project indexing with intelligent navigation
# Tags: documentation, indexing, navigation, automation

[CmdletBinding(SupportsShouldProcess)]
param(
    [ValidateSet('Full', 'Incremental', 'Verify')]
    [string]$Mode = 'Incremental',
    
    [string]$RootPath = $null,
    
    [switch]$Force,
    
    [switch]$UpdateManifest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Initialize
$script:ProjectRoot = Split-Path $PSScriptRoot -Parent
$script:StartTime = Get-Date

# Banner
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "    AitherZero Project Indexer - Automated Navigation" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Import required modules
$loggingModule = Join-Path $script:ProjectRoot "domains/utilities/Logging.psm1"
$indexerModule = Join-Path $script:ProjectRoot "domains/documentation/ProjectIndexer.psm1"

if (Test-Path $loggingModule) {
    Import-Module $loggingModule -Force -ErrorAction SilentlyContinue
}

if (-not (Test-Path $indexerModule)) {
    Write-Error "ProjectIndexer module not found: $indexerModule"
    exit 1
}

Import-Module $indexerModule -Force

function Write-IndexLog {
    param([string]$Message, [string]$Level = 'Information')
    
    $color = switch ($Level) {
        'Information' { 'White' }
        'Warning' { 'Yellow' }
        'Error' { 'Red' }
        'Success' { 'Green' }
        default { 'White' }
    }
    
    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Level $Level -Message $Message -Source "ProjectIndexer"
    }
    
    Write-Host "  $Message" -ForegroundColor $color
}

function Show-Statistics {
    param([hashtable]$Results)
    
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  Indexing Statistics" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Total Directories:   $($Results.TotalDirectories)" -ForegroundColor White
    Write-Host "  Updated Indexes:     $($Results.UpdatedIndexes)" -ForegroundColor Green
    Write-Host "  Skipped (No Change): $($Results.SkippedIndexes)" -ForegroundColor Gray
    Write-Host "  Failed:              $($Results.FailedIndexes)" -ForegroundColor $(if ($Results.FailedIndexes -gt 0) { 'Red' } else { 'Gray' })
    Write-Host ""
    
    $duration = (Get-Date) - $script:StartTime
    Write-Host "  Duration: $($duration.TotalSeconds.ToString('F2')) seconds" -ForegroundColor White
    Write-Host ""
}

function Show-UpdatedFiles {
    param([hashtable]$Results)
    
    if ($Results.UpdatedIndexes -gt 0 -and $Results.IndexedPaths.Count -gt 0) {
        Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host "  Updated Index Files" -ForegroundColor Cyan
        Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host ""
        
        foreach ($path in $Results.IndexedPaths) {
            $relativePath = [System.IO.Path]::GetRelativePath($script:ProjectRoot, $path)
            Write-Host "  ✓ $relativePath" -ForegroundColor Green
        }
        Write-Host ""
    }
}

function Export-IndexReport {
    param(
        [hashtable]$Results,
        [string]$Mode,
        [timespan]$Duration
    )
    
    $reportPath = Join-Path $script:ProjectRoot ".aitherzero-index-report.json"
    
    $report = @{
        Timestamp = (Get-Date).ToString('o')
        Mode = $Mode
        Duration = @{
            TotalSeconds = [math]::Round($Duration.TotalSeconds, 2)
            Formatted = $Duration.ToString('mm\m\ ss\s')
        }
        Statistics = @{
            TotalDirectories = $Results.TotalDirectories
            UpdatedIndexes = $Results.UpdatedIndexes
            SkippedIndexes = $Results.SkippedIndexes
            FailedIndexes = $Results.FailedIndexes
            UpdateRate = if ($Results.TotalDirectories -gt 0) {
                [math]::Round(($Results.UpdatedIndexes / $Results.TotalDirectories) * 100, 1)
            } else { 0 }
        }
        UpdatedPaths = @($Results.IndexedPaths | ForEach-Object {
            [System.IO.Path]::GetRelativePath($script:ProjectRoot, $_)
        })
    }
    
    try {
        $report | ConvertTo-Json -Depth 10 | Set-Content -Path $reportPath -Encoding UTF8 -Force
        Write-IndexLog "Index report exported to: $reportPath" -Level Success
    } catch {
        Write-IndexLog "Failed to export index report: $_" -Level Warning
    }
}

#region Main Execution

try {
    # Determine root path
    if (-not $RootPath) {
        $RootPath = $script:ProjectRoot
    }
    
    Write-Host "Configuration:" -ForegroundColor Yellow
    Write-Host "  Mode:      $Mode" -ForegroundColor White
    Write-Host "  Root Path: $RootPath" -ForegroundColor White
    Write-Host "  Force:     $($Force.IsPresent)" -ForegroundColor White
    Write-Host ""
    
    # Initialize indexer
    Write-IndexLog "Initializing Project Indexer..." -Level Information
    Initialize-ProjectIndexer -RootPath $RootPath
    Write-IndexLog "Indexer initialized successfully" -Level Success
    Write-Host ""
    
    # Execute based on mode
    switch ($Mode) {
        'Full' {
            Write-IndexLog "Running FULL index generation..." -Level Information
            Write-Host ""
            
            $results = New-ProjectIndexes -RootPath $RootPath -Recursive -Force:$Force
            
            Show-Statistics -Results $results
            Show-UpdatedFiles -Results $results
            
            # Export report for CI/CD
            $duration = (Get-Date) - $script:StartTime
            Export-IndexReport -Results $results -Mode $Mode -Duration $duration
            
            if ($results.UpdatedIndexes -gt 0) {
                Write-Host "✓ Full project indexing completed successfully!" -ForegroundColor Green
            } else {
                Write-Host "ℹ No updates needed - all indexes are current" -ForegroundColor Yellow
            }
        }
        
        'Incremental' {
            Write-IndexLog "Running INCREMENTAL index generation..." -Level Information
            Write-Host ""
            
            $results = New-ProjectIndexes -RootPath $RootPath -Recursive
            
            Show-Statistics -Results $results
            Show-UpdatedFiles -Results $results
            
            # Export report for CI/CD
            $duration = (Get-Date) - $script:StartTime
            Export-IndexReport -Results $results -Mode $Mode -Duration $duration
            
            if ($results.UpdatedIndexes -gt 0) {
                Write-Host "✓ Incremental indexing completed - $($results.UpdatedIndexes) indexes updated!" -ForegroundColor Green
            } else {
                Write-Host "ℹ No updates needed - all indexes are current" -ForegroundColor Yellow
            }
        }
        
        'Verify' {
            Write-IndexLog "Running verification mode..." -Level Information
            Write-Host ""
            
            # Get config from module
            $config = Get-IndexerConfig
            
            # Find directories that need updates
            $directories = @($RootPath)
            $allDirs = Get-ChildItem -Path $RootPath -Directory -Recurse -Force | Where-Object {
                $dirName = $_.Name
                $fullPath = $_.FullName
                -not ($config.ExcludePaths | Where-Object { $dirName -like $_ -or $dirName -eq $_ -or $fullPath -like "*$_*" })
            }
            $directories += $allDirs.FullName
            
            $needsUpdate = @()
            foreach ($dir in $directories) {
                if (Test-ContentChanged -Path $dir) {
                    $relativePath = [System.IO.Path]::GetRelativePath($RootPath, $dir)
                    $needsUpdate += $relativePath
                }
            }
            
            Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
            Write-Host "  Verification Results" -ForegroundColor Cyan
            Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
            Write-Host ""
            Write-Host "  Total Directories: $($directories.Count)" -ForegroundColor White
            Write-Host "  Need Updates:      $($needsUpdate.Count)" -ForegroundColor $(if ($needsUpdate.Count -gt 0) { 'Yellow' } else { 'Green' })
            Write-Host ""
            
            if ($needsUpdate.Count -gt 0) {
                Write-Host "Directories requiring index updates:" -ForegroundColor Yellow
                foreach ($path in $needsUpdate) {
                    Write-Host "  • $path" -ForegroundColor White
                }
                Write-Host ""
                Write-Host "Run with -Mode Incremental to update these directories" -ForegroundColor Cyan
            } else {
                Write-Host "✓ All indexes are up to date!" -ForegroundColor Green
            }
        }
    }
    
    # Update manifest if requested
    if ($UpdateManifest) {
        Write-Host ""
        Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host "  Manifest Update" -ForegroundColor Cyan
        Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host ""
        
        $manifestPath = Join-Path $script:ProjectRoot "AitherZero.psd1"
        Update-ProjectManifest -ManifestPath $manifestPath
    }
    
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    
    exit 0
    
} catch {
    Write-Host ""
    Write-Host "ERROR: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    Write-Host ""
    exit 1
}

#endregion

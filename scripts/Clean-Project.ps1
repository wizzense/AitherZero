#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Clean up AitherZero project - remove old test results, backups, and temporary files
    
.DESCRIPTION
    This script removes:
    - Old test results (keeping only the latest)
    - Backup directories
    - Temporary files
    - Build artifacts
    
.PARAMETER KeepDays
    Number of days to keep test results (default: 7)
    
.PARAMETER DryRun
    Preview what would be deleted without actually deleting
    
.PARAMETER Force
    Skip confirmation prompts
#>

[CmdletBinding()]
param(
    [int]$KeepDays = 7,
    [switch]$DryRun,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

# Get project root
$projectRoot = Split-Path $PSScriptRoot -Parent

Write-Host "🧹 AitherZero Project Cleanup" -ForegroundColor Cyan
Write-Host "Project Root: $projectRoot" -ForegroundColor Gray

if ($DryRun) {
    Write-Host "DRY RUN MODE - No files will be deleted" -ForegroundColor Yellow
}

$totalSize = 0
$fileCount = 0

# Function to get human-readable size
function Get-HumanReadableSize {
    param([long]$Bytes)
    
    if ($Bytes -gt 1GB) {
        return "{0:N2} GB" -f ($Bytes / 1GB)
    } elseif ($Bytes -gt 1MB) {
        return "{0:N2} MB" -f ($Bytes / 1MB)
    } elseif ($Bytes -gt 1KB) {
        return "{0:N2} KB" -f ($Bytes / 1KB)
    } else {
        return "$Bytes bytes"
    }
}

# 1. Clean up backup directories
Write-Host "`n📁 Cleaning backup directories..." -ForegroundColor Yellow

$backupDirs = @(
    Get-ChildItem -Path $projectRoot -Directory -Recurse | Where-Object { 
        $_.Name -match '^backup-.*' -or 
        $_.Name -match '.*-backup$' -or
        $_.Name -match '^\.backup.*'
    }
)

if ($backupDirs.Count -gt 0) {
    Write-Host "Found $($backupDirs.Count) backup directories:" -ForegroundColor Gray
    foreach ($dir in $backupDirs) {
        $size = (Get-ChildItem $dir.FullName -Recurse -File | Measure-Object -Property Length -Sum).Sum
        $totalSize += $size
        $fileCount += (Get-ChildItem $dir.FullName -Recurse -File).Count
        
        Write-Host "  - $($dir.Name) ($(Get-HumanReadableSize $size))" -ForegroundColor Red
        
        if (-not $DryRun) {
            Remove-Item $dir.FullName -Recurse -Force
        }
    }
} else {
    Write-Host "No backup directories found" -ForegroundColor Green
}

# 2. Clean up old test results
Write-Host "`n📊 Cleaning old test results..." -ForegroundColor Yellow

$cutoffDate = (Get-Date).AddDays(-$KeepDays)
$testResultsPath = Join-Path $projectRoot "tests/results"

if (Test-Path $testResultsPath) {
    $oldTestFiles = Get-ChildItem -Path $testResultsPath -Recurse -File | Where-Object {
        $_.LastWriteTime -lt $cutoffDate -and (
            $_.Name -match 'test-results-\d{4}-\d{2}-\d{2}' -or
            $_.Name -match 'test-report-\d{4}-\d{2}-\d{2}' -or
            $_.Extension -in @('.xml', '.json', '.csv', '.html')
        )
    }
    
    if ($oldTestFiles.Count -gt 0) {
        Write-Host "Found $($oldTestFiles.Count) old test files (older than $KeepDays days):" -ForegroundColor Gray
        
        $testFilesByType = $oldTestFiles | Group-Object Extension
        foreach ($group in $testFilesByType) {
            $size = ($group.Group | Measure-Object -Property Length -Sum).Sum
            $totalSize += $size
            $fileCount += $group.Count
            
            Write-Host "  - $($group.Count) $($group.Name) files ($(Get-HumanReadableSize $size))" -ForegroundColor Red
        }
        
        if (-not $DryRun) {
            $oldTestFiles | Remove-Item -Force
        }
    } else {
        Write-Host "No old test results found" -ForegroundColor Green
    }
}

# 3. Clean up temporary files
Write-Host "`n🗑️ Cleaning temporary files..." -ForegroundColor Yellow

$tempPatterns = @(
    '*.tmp',
    '*.temp',
    '*.log',
    '*.bak',
    '.DS_Store',
    'Thumbs.db',
    '~*'
)

$tempFiles = @()
foreach ($pattern in $tempPatterns) {
    $tempFiles += Get-ChildItem -Path $projectRoot -Recurse -File -Filter $pattern -ErrorAction SilentlyContinue | Where-Object {
        $_.FullName -notmatch '\.git' -and
        $_.FullName -notmatch 'node_modules'
    }
}

if ($tempFiles.Count -gt 0) {
    Write-Host "Found $($tempFiles.Count) temporary files:" -ForegroundColor Gray
    
    $tempFilesByExt = $tempFiles | Group-Object Extension
    foreach ($group in $tempFilesByExt) {
        $size = ($group.Group | Measure-Object -Property Length -Sum).Sum
        $totalSize += $size
        $fileCount += $group.Count
        
        Write-Host "  - $($group.Count) $($group.Name) files ($(Get-HumanReadableSize $size))" -ForegroundColor Red
    }
    
    if (-not $DryRun) {
        $tempFiles | Remove-Item -Force
    }
} else {
    Write-Host "No temporary files found" -ForegroundColor Green
}

# 4. Clean up empty directories
Write-Host "`n📂 Cleaning empty directories..." -ForegroundColor Yellow

$emptyDirs = Get-ChildItem -Path $projectRoot -Directory -Recurse | Where-Object {
    $_.FullName -notmatch '\.git' -and
    (Get-ChildItem $_.FullName -Force).Count -eq 0
} | Sort-Object FullName -Descending

if ($emptyDirs.Count -gt 0) {
    Write-Host "Found $($emptyDirs.Count) empty directories" -ForegroundColor Red
    
    if (-not $DryRun) {
        $emptyDirs | Remove-Item -Force
    }
} else {
    Write-Host "No empty directories found" -ForegroundColor Green
}

# Summary
Write-Host "`n📈 Cleanup Summary" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════" -ForegroundColor Gray
Write-Host "Files to be deleted: $fileCount" -ForegroundColor White
Write-Host "Space to be freed: $(Get-HumanReadableSize $totalSize)" -ForegroundColor White

if ($DryRun) {
    Write-Host "`n⚠️ This was a dry run. No files were deleted." -ForegroundColor Yellow
    Write-Host "Run without -DryRun to actually clean up." -ForegroundColor Yellow
} elseif ($fileCount -gt 0) {
    Write-Host "`n✅ Cleanup completed successfully!" -ForegroundColor Green
} else {
    Write-Host "`n✅ Project is already clean!" -ForegroundColor Green
}
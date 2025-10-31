#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Clean up old and development tags from the repository.

.DESCRIPTION
    This script removes old version tags and development tags to maintain a clean tag history.
    It preserves major releases and recent versions while removing:
    - Development tags (vdev-*)
    - Pre-v0.7 version tags
    - Duplicate or unnecessary tags

.PARAMETER DryRun
    Show what would be deleted without actually deleting tags.

.PARAMETER KeepMajorVersions
    Keep at least one tag per major version (e.g., v0.8.0, v1.0.0).

.EXAMPLE
    ./0799_cleanup-old-tags.ps1 -DryRun
    Show what tags would be deleted

.EXAMPLE
    ./0799_cleanup-old-tags.ps1
    Actually delete the old tags

.NOTES
    Script Number: 0799
    Category: Git Automation & Maintenance
    Requires: Git, GitHub CLI (gh) or push permissions
#>

[CmdletBinding()]
param(
    [Parameter()]
    [switch]$DryRun,

    [Parameter()]
    [switch]$KeepMajorVersions
)

$ErrorActionPreference = 'Stop'

# Set up logging
$ScriptName = "CleanupOldTags"
if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
    Write-CustomLog -Message "Starting tag cleanup process" -Level 'Information'
}

Write-Host "`n🏷️  AitherZero Tag Cleanup Utility" -ForegroundColor Magenta
Write-Host "═══════════════════════════════════════════════════════════════`n" -ForegroundColor Magenta

# Verify we're in a git repository
if (-not (Test-Path .git)) {
    Write-Host "❌ Error: Not in a git repository" -ForegroundColor Red
    exit 1
}

# Get all remote tags
Write-Host "📊 Analyzing repository tags..." -ForegroundColor Cyan
$remoteTags = git ls-remote --tags origin | ForEach-Object {
    if ($_ -match 'refs/tags/(.+?)(\^\{\})?$') {
        $matches[1]
    }
} | Select-Object -Unique | Sort-Object

$totalTags = $remoteTags.Count
Write-Host "   Found $totalTags total tags`n" -ForegroundColor White

# Categorize tags
$devTags = $remoteTags | Where-Object { $_ -match '^vdev-' }
$oldVersionTags = $remoteTags | Where-Object { $_ -match '^v0\.[0-6]\.' }
$v07Tags = $remoteTags | Where-Object { $_ -match '^v0\.7\.' }
$v08Tags = $remoteTags | Where-Object { $_ -match '^v0\.8\.' }
$v10Tags = $remoteTags | Where-Object { $_ -match '^v1\.0\.' }

Write-Host "📋 Tag Categories:" -ForegroundColor Yellow
Write-Host "   Development tags (vdev-*): $($devTags.Count)" -ForegroundColor White
Write-Host "   Old versions (v0.0-v0.6): $($oldVersionTags.Count)" -ForegroundColor White
Write-Host "   Version 0.7.x: $($v07Tags.Count)" -ForegroundColor White
Write-Host "   Version 0.8.x: $($v08Tags.Count)" -ForegroundColor White
Write-Host "   Version 1.0.x: $($v10Tags.Count)" -ForegroundColor White

# Determine tags to delete
$tagsToDelete = @()

# Always delete development tags
$tagsToDelete += $devTags

# Delete old pre-0.7 versions
$tagsToDelete += $oldVersionTags

# Optionally keep one tag per major version
if ($KeepMajorVersions) {
    # Keep v0.7.6 as the last 0.7.x
    $tagsToDelete += $v07Tags | Where-Object { $_ -ne 'v0.7.6' }
    # Keep v0.8.0 as the representative 0.8.x
    $tagsToDelete += $v08Tags | Where-Object { $_ -ne 'v0.8.0' }
} else {
    # Delete all 0.7.x and 0.8.x since we're on 1.0.x now
    $tagsToDelete += $v07Tags
    $tagsToDelete += $v08Tags
}

$tagsToDelete = $tagsToDelete | Select-Object -Unique | Sort-Object

Write-Host "`n🗑️  Tags Marked for Deletion: $($tagsToDelete.Count)" -ForegroundColor Yellow

if ($tagsToDelete.Count -eq 0) {
    Write-Host "✅ No tags to delete. Repository is clean!" -ForegroundColor Green
    exit 0
}

# Display tags to be deleted
Write-Host "`nTags to be deleted:" -ForegroundColor Cyan
$tagsToDelete | ForEach-Object {
    $category = if ($_ -match '^vdev-') { "[DEV]" } 
                elseif ($_ -match '^v0\.[0-6]\.') { "[OLD]" }
                elseif ($_ -match '^v0\.7\.') { "[0.7.x]" }
                elseif ($_ -match '^v0\.8\.') { "[0.8.x]" }
                else { "[OTHER]" }
    Write-Host "   $category $_" -ForegroundColor Gray
}

if ($DryRun) {
    Write-Host "`n🔍 DRY RUN MODE - No tags were deleted" -ForegroundColor Yellow
    Write-Host "   Run without -DryRun to actually delete these tags`n" -ForegroundColor Cyan
    
    # Show what will be kept
    $tagsToKeep = $remoteTags | Where-Object { $_ -notin $tagsToDelete }
    Write-Host "📌 Tags that will be kept: $($tagsToKeep.Count)" -ForegroundColor Green
    $tagsToKeep | Sort-Object | ForEach-Object {
        Write-Host "   $_" -ForegroundColor Green
    }
    exit 0
}

# Confirm deletion
Write-Host "`n⚠️  WARNING: This will permanently delete $($tagsToDelete.Count) tags from the remote repository!" -ForegroundColor Red
Write-Host "   This action cannot be undone.`n" -ForegroundColor Yellow

$confirmation = Read-Host "Type 'DELETE' to confirm"
if ($confirmation -ne 'DELETE') {
    Write-Host "❌ Deletion cancelled" -ForegroundColor Yellow
    exit 0
}

# Delete tags from remote
Write-Host "`n🗑️  Deleting tags from remote repository..." -ForegroundColor Yellow

$deletedCount = 0
$failedCount = 0
$failedTags = @()

foreach ($tag in $tagsToDelete) {
    try {
        Write-Host "   Deleting: $tag" -ForegroundColor Gray
        git push origin --delete "refs/tags/$tag" 2>&1 | Out-Null
        
        if ($LASTEXITCODE -eq 0) {
            $deletedCount++
        } else {
            $failedCount++
            $failedTags += $tag
            Write-Host "   ⚠️  Failed to delete: $tag" -ForegroundColor Yellow
        }
    }
    catch {
        $failedCount++
        $failedTags += $tag
        Write-Host "   ❌ Error deleting $tag : $_" -ForegroundColor Red
    }
}

# Summary
Write-Host "`n📊 Tag Cleanup Summary:" -ForegroundColor Magenta
Write-Host "   Total tags before: $totalTags" -ForegroundColor White
Write-Host "   Tags deleted: $deletedCount" -ForegroundColor Green
Write-Host "   Tags failed: $failedCount" -ForegroundColor $(if ($failedCount -gt 0) { 'Yellow' } else { 'Green' })
Write-Host "   Tags remaining: $($totalTags - $deletedCount)" -ForegroundColor Cyan

if ($failedTags.Count -gt 0) {
    Write-Host "`n⚠️  Failed to delete the following tags:" -ForegroundColor Yellow
    $failedTags | ForEach-Object { Write-Host "   $_" -ForegroundColor Red }
}

Write-Host "`n✅ Tag cleanup completed!`n" -ForegroundColor Green

if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
    Write-CustomLog -Message "Tag cleanup completed: $deletedCount deleted, $failedCount failed" -Level 'Information'
}

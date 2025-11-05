<#
.SYNOPSIS
    Cleanup script to make v1.0.0.0 the official release by removing all other tags and releases.

.DESCRIPTION
    This script removes all GitHub releases and tags except v1.0.0.0, making it the official 1.0.0 release.
    
    IMPORTANT: This script requires GitHub CLI (gh) to be authenticated with appropriate permissions.
    
.PARAMETER DryRun
    If specified, only shows what would be deleted without making changes.

.EXAMPLE
    ./Invoke-ReleaseCleanup.ps1 -DryRun
    Shows what would be deleted without making changes.

.EXAMPLE
    ./Invoke-ReleaseCleanup.ps1
    Deletes all releases and tags except v1.0.0.0
#>

param(
    [switch]$DryRun
)

#Requires -Version 7.0

$ErrorActionPreference = 'Stop'

# Target release to keep
$KeepTag = 'v1.0.0.0'

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "  AitherZero Release and Tag Cleanup Script" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "This script will:" -ForegroundColor Yellow
Write-Host "  - Keep ONLY: $KeepTag" -ForegroundColor Green
Write-Host "  - Delete ALL other releases and tags" -ForegroundColor Red
Write-Host ""

if ($DryRun) {
    Write-Host "DRY RUN MODE: No changes will be made" -ForegroundColor Magenta
    Write-Host ""
}

# Check if gh is available
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: GitHub CLI (gh) is not installed or not in PATH" -ForegroundColor Red
    Write-Host "Please install gh from: https://cli.github.com/" -ForegroundColor Yellow
    exit 1
}

# Check if gh is authenticated
$authStatus = gh auth status 2>&1 | Out-String
if ($authStatus -notmatch 'Logged in to github.com') {
    Write-Host "ERROR: GitHub CLI is not authenticated" -ForegroundColor Red
    Write-Host "Please run: gh auth login" -ForegroundColor Yellow
    exit 1
}

# Get repository info
$repo = "wizzense/AitherZero"
Write-Host "Repository: $repo" -ForegroundColor Cyan
Write-Host ""

# Get all tags
Write-Host "Fetching all tags..." -ForegroundColor Cyan
$allTags = git tag --list | Where-Object { $_ -ne $KeepTag }
$tagCount = $allTags.Count

Write-Host "Found $tagCount tags to delete (keeping $KeepTag)" -ForegroundColor Yellow
Write-Host ""

# Get all releases
Write-Host "Fetching all releases..." -ForegroundColor Cyan
$allReleases = gh release list --repo $repo --limit 1000 --json tagName,name,isPrerelease,isDraft | ConvertFrom-Json
$releasesToDelete = $allReleases | Where-Object { $_.tagName -ne $KeepTag }
$releaseCount = $releasesToDelete.Count

Write-Host "Found $releaseCount releases to delete (keeping $KeepTag)" -ForegroundColor Yellow
Write-Host ""

# Summary
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "  SUMMARY" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "Tags to keep:    1 ($KeepTag)" -ForegroundColor Green
Write-Host "Tags to delete:  $tagCount" -ForegroundColor Red
Write-Host "Releases to delete: $releaseCount" -ForegroundColor Red
Write-Host ""

if ($DryRun) {
    Write-Host "Tags that would be deleted:" -ForegroundColor Yellow
    $allTags | ForEach-Object { Write-Host "  - $_" -ForegroundColor Gray }
    Write-Host ""
    Write-Host "Releases that would be deleted:" -ForegroundColor Yellow
    $releasesToDelete | ForEach-Object { Write-Host "  - $($_.tagName) ($($_.name))" -ForegroundColor Gray }
    Write-Host ""
    Write-Host "DRY RUN COMPLETE - No changes were made" -ForegroundColor Magenta
    exit 0
}

# Confirm before proceeding
Write-Host "WARNING: This action cannot be undone!" -ForegroundColor Red
Write-Host ""
$confirmation = Read-Host "Type 'DELETE' to proceed with deletion"

if ($confirmation -ne 'DELETE') {
    Write-Host "Cancelled by user" -ForegroundColor Yellow
    exit 0
}

Write-Host ""
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "  DELETION IN PROGRESS" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""

# Delete releases
Write-Host "Deleting releases..." -ForegroundColor Cyan
$deletedReleases = 0
$failedReleases = 0

foreach ($release in $releasesToDelete) {
    try {
        Write-Host "  Deleting release: $($release.tagName)" -ForegroundColor Gray
        gh release delete $release.tagName --repo $repo --yes --cleanup-tag
        $deletedReleases++
    }
    catch {
        Write-Host "  FAILED to delete release: $($release.tagName)" -ForegroundColor Red
        Write-Host "    Error: $_" -ForegroundColor Red
        $failedReleases++
    }
}

Write-Host ""
Write-Host "Deleted $deletedReleases releases" -ForegroundColor Green
if ($failedReleases -gt 0) {
    Write-Host "Failed to delete $failedReleases releases" -ForegroundColor Red
}
Write-Host ""

# Delete remaining local tags
Write-Host "Deleting local tags..." -ForegroundColor Cyan
$deletedTags = 0
$failedTags = 0

foreach ($tag in $allTags) {
    try {
        Write-Host "  Deleting local tag: $tag" -ForegroundColor Gray
        git tag -d $tag 2>&1 | Out-Null
        $deletedTags++
    }
    catch {
        Write-Host "  FAILED to delete local tag: $tag" -ForegroundColor Red
        Write-Host "    Error: $_" -ForegroundColor Red
        $failedTags++
    }
}

Write-Host ""
Write-Host "Deleted $deletedTags local tags" -ForegroundColor Green
if ($failedTags -gt 0) {
    Write-Host "Failed to delete $failedTags local tags" -ForegroundColor Red
}
Write-Host ""

# Push tag deletions to remote
Write-Host "Pushing tag deletions to remote..." -ForegroundColor Cyan
$pushedTags = 0
$failedPushes = 0

foreach ($tag in $allTags) {
    try {
        Write-Host "  Deleting remote tag: $tag" -ForegroundColor Gray
        git push origin --delete $tag 2>&1 | Out-Null
        $pushedTags++
    }
    catch {
        Write-Host "  FAILED to delete remote tag: $tag" -ForegroundColor Red
        Write-Host "    Error: $_" -ForegroundColor Red
        $failedPushes++
    }
}

Write-Host ""
Write-Host "Deleted $pushedTags remote tags" -ForegroundColor Green
if ($failedPushes -gt 0) {
    Write-Host "Failed to delete $failedPushes remote tags" -ForegroundColor Red
}
Write-Host ""

# Final summary
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "  CLEANUP COMPLETE" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Results:" -ForegroundColor Green
Write-Host "  Releases deleted: $deletedReleases" -ForegroundColor Green
Write-Host "  Local tags deleted: $deletedTags" -ForegroundColor Green
Write-Host "  Remote tags deleted: $pushedTags" -ForegroundColor Green

if ($failedReleases -gt 0 -or $failedTags -gt 0 -or $failedPushes -gt 0) {
    Write-Host ""
    Write-Host "Failures:" -ForegroundColor Red
    if ($failedReleases -gt 0) {
        Write-Host "  Releases failed: $failedReleases" -ForegroundColor Red
    }
    if ($failedTags -gt 0) {
        Write-Host "  Local tags failed: $failedTags" -ForegroundColor Red
    }
    if ($failedPushes -gt 0) {
        Write-Host "  Remote tags failed: $failedPushes" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "The repository now has only v1.0.0.0 as the official release!" -ForegroundColor Green

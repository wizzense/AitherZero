#!/usr/bin/env pwsh
#Requires -Version 5.1

<#
.SYNOPSIS
    Smart release management script that handles VERSION updates and tagging
.DESCRIPTION
    Ensures releases are properly tagged even when auto-tagging fails
.PARAMETER CheckOnly
    Only check release status without creating tags
#>

param(
    [switch]$CheckOnly
)

Write-Host "`n🚀 AitherZero Smart Release Manager" -ForegroundColor Green
Write-Host "=" * 50 -ForegroundColor Cyan

try {
    # Get current VERSION
    $versionFile = Join-Path $PSScriptRoot ".." "VERSION"
    if (-not (Test-Path $versionFile)) {
        throw "VERSION file not found at: $versionFile"
    }
    
    $currentVersion = (Get-Content $versionFile -Raw).Trim()
    Write-Host "`n📌 Current VERSION: $currentVersion" -ForegroundColor Yellow
    
    # Check if tag exists
    $tagName = "v$currentVersion"
    $tagExists = $false
    
    try {
        git rev-parse $tagName 2>&1 | Out-Null
        $tagExists = $LASTEXITCODE -eq 0
    } catch {
        $tagExists = $false
    }
    
    if ($tagExists) {
        Write-Host "✅ Tag $tagName already exists" -ForegroundColor Green
        
        # Check if build ran
        Write-Host "`n🔍 Checking build status..." -ForegroundColor Cyan
        $buildRuns = gh run list --workflow="📦 Build & Release Pipeline" --limit 5 2>&1
        
        if ($buildRuns -match $tagName) {
            Write-Host "✅ Build pipeline has run for $tagName" -ForegroundColor Green
        } else {
            Write-Host "⚠️  No build found for $tagName" -ForegroundColor Yellow
            Write-Host "   Run: gh workflow run '📦 Build & Release Pipeline'" -ForegroundColor Gray
        }
    } else {
        Write-Host "❌ Tag $tagName does not exist" -ForegroundColor Red
        
        if ($CheckOnly) {
            Write-Host "`n💡 To create the tag, run without -CheckOnly flag" -ForegroundColor Yellow
            exit 0
        }
        
        # Get last commit message for context
        $lastCommitMsg = git log -1 --pretty=%B
        Write-Host "`nLast commit: $($lastCommitMsg.Split("`n")[0])" -ForegroundColor Gray
        
        # Create tag
        Write-Host "`n🏷️  Creating tag $tagName..." -ForegroundColor Yellow
        git tag -a $tagName -m "Release $tagName`n`n$lastCommitMsg"
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Tag created locally" -ForegroundColor Green
            
            # Push tag
            Write-Host "📤 Pushing tag to remote..." -ForegroundColor Yellow
            git push origin $tagName
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "✅ Tag pushed successfully!" -ForegroundColor Green
                Write-Host "`n🎉 Build pipeline will trigger automatically" -ForegroundColor Cyan
                Write-Host "   Monitor at: https://github.com/wizzense/AitherZero/actions" -ForegroundColor Gray
            } else {
                throw "Failed to push tag"
            }
        } else {
            throw "Failed to create tag"
        }
    }
    
    # Check for VERSION/tag mismatches
    Write-Host "`n🔍 Checking for version consistency..." -ForegroundColor Cyan
    $allTags = git tag --sort=-version:refname | Select-Object -First 10
    $latestTag = $allTags | Select-Object -First 1
    
    if ($latestTag -and $latestTag -ne $tagName) {
        Write-Host "⚠️  Latest tag ($latestTag) doesn't match VERSION ($tagName)" -ForegroundColor Yellow
        Write-Host "   This might indicate a missed release or version mismatch" -ForegroundColor Gray
    }
    
} catch {
    Write-Host "`n❌ Error: $_" -ForegroundColor Red
    exit 1
}

Write-Host "`n✅ Release check complete!" -ForegroundColor Green
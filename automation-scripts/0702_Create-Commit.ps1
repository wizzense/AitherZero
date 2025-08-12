#Requires -Version 7.0

<#
.SYNOPSIS
    Create a conventional commit with validation
.DESCRIPTION
    Creates a Git commit following conventional commit standards with
    automatic formatting and validation.
.NOTES
    Stage: Development
    Category: Git
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory, Position = 0)]
    [ValidateSet('feat', 'fix', 'docs', 'style', 'refactor', 'test', 'chore', 'perf', 'ci', 'build', 'revert')]
    [string]$Type,
    
    [Parameter(Mandatory, Position = 1)]
    [string]$Message,
    
    [string]$Scope,
    
    [string]$Body,
    
    [string[]]$CoAuthors,
    
    [switch]$Breaking,
    
    [int[]]$Closes,
    
    [int[]]$Refs,
    
    [switch]$AutoStage,
    
    [switch]$Push,
    
    [switch]$SignOff,
    
    [switch]$NonInteractive,
    
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Import Git module
$devModulePath = Join-Path (Split-Path $PSScriptRoot -Parent) "domains/development"
Import-Module (Join-Path $devModulePath "GitAutomation.psm1") -Force

Write-Host "Creating conventional commit..." -ForegroundColor Cyan

# Check for changes
$status = Get-GitStatus
if ($status.Clean -and -not $AutoStage) {
    if (-not $NonInteractive -and -not $Force) {
        Write-Warning "No changes to commit. Use -AutoStage to stage all changes."
        exit 0
    } else {
        Write-Host "No changes to commit." -ForegroundColor Yellow
        exit 0
    }
}

# Show what will be committed
if ($AutoStage) {
    Write-Host "Files to be staged:" -ForegroundColor Yellow
    $status.Modified + $status.Untracked | ForEach-Object { 
        Write-Host "  $($_.Path)" -ForegroundColor Gray
    }
} else {
    if ($status.Staged.Count -eq 0) {
        if (-not $NonInteractive -and -not $Force) {
            Write-Warning "No files staged for commit. Stage files with 'git add' or use -AutoStage"
            exit 0
        } else {
            Write-Warning "No files staged for commit. Exiting."
            exit 0
        }
    }
    
    Write-Host "Staged files:" -ForegroundColor Yellow
    $status.Staged | ForEach-Object { 
        Write-Host "  $($_.Path)" -ForegroundColor Green
    }
}

# Build commit message
$commitMessage = $Message

# Add body if provided
$fullBody = $Body

# Add breaking change indicator
if ($Breaking) {
    $commitMessage = "$commitMessage!"
    if (-not $fullBody) {
        $fullBody = "BREAKING CHANGE: "
    } else {
        $fullBody = "$fullBody`n`nBREAKING CHANGE: "
    }
}

# Add issue references
$footer = @()
if ($Closes) {
    $footer += $Closes | ForEach-Object { "Closes #$_" }
}
if ($Refs) {
    $footer += $Refs | ForEach-Object { "Refs #$_" }
}

if ($footer) {
    if ($fullBody) {
        $fullBody = "$fullBody`n`n$($footer -join "`n")"
    } else {
        $fullBody = $footer -join "`n"
    }
}

# Validate message length
if ($commitMessage.Length -gt 72) {
    if (-not $NonInteractive -and -not $Force) {
        Write-Warning "Commit subject is $($commitMessage.Length) chars (recommended: <72)"
        $response = Read-Host "Continue anyway? (y/N)"
        if ($response -ne 'y') {
            exit 0
        }
    } else {
        Write-Warning "Commit subject is $($commitMessage.Length) chars (recommended: <72). Proceeding in non-interactive mode."
    }
}

# Create the commit
try {
    $commitParams = @{
        Message = $commitMessage
        Type = $Type
        AutoStage = $AutoStage
        SignOff = $SignOff
    }

    if ($Scope) {
        $commitParams.Scope = $Scope
    }

    if ($fullBody) {
        $commitParams.Body = $fullBody
    }

    if ($CoAuthors) {
        $commitParams.CoAuthors = $CoAuthors
    }
    
    if ($PSCmdlet.ShouldProcess("Git repository", "Create commit: $commitMessage")) {
        $result = Invoke-GitCommit @commitParams
        
        Write-Host "✓ Created commit: $($result.Hash.Substring(0, 7))" -ForegroundColor Green
        Write-Host "  $($result.Message)" -ForegroundColor Gray
    } else {
        Write-Host "WhatIf: Would create commit: $commitMessage" -ForegroundColor Yellow
        return
    }
    
} catch {
    Write-Error "Failed to create commit: $_"
    exit 1
}

# Push if requested
if ($Push) {
    Write-Host "Pushing to remote..." -ForegroundColor Yellow
    try {
        if ($PSCmdlet.ShouldProcess("Remote repository", "Push commit")) {
            Sync-GitRepository -Operation Push
            Write-Host "✓ Pushed to remote" -ForegroundColor Green
        }
    } catch {
        Write-Warning "Failed to push: $_"
        Write-Host "You can push manually with: git push" -ForegroundColor Yellow
    }
}

# Show commit details
Write-Host "`nCommit created successfully!" -ForegroundColor Green
git log -1 --stat
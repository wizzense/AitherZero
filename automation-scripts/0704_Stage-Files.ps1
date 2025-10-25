#Requires -Version 7.0

<#
.SYNOPSIS
    Stage files for Git commit using patterns
.DESCRIPTION
    Stages files to Git index using file patterns, globs, or specific paths.
    Supports interactive selection and pattern validation.
.NOTES
    Stage: Development
    Category: Git
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Position = 0, ValueFromRemainingArguments)]
    [string[]]$Patterns,

    [ValidateSet('All', 'Modified', 'Untracked', 'Deleted')]
    [string]$Type = 'All',

    [switch]$Interactive,

    [switch]$DryRun,

    [switch]$Force,

    [switch]$ShowStatus
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Import Git module
$devModulePath = Join-Path (Split-Path $PSScriptRoot -Parent) "domains/development"
Import-Module (Join-Path $devModulePath "GitAutomation.psm1") -Force

Write-Host "Staging files for commit..." -ForegroundColor Cyan

# Get current git status
$status = Get-GitStatus

if ($status.Clean -and -not $Force) {
    Write-Host "No changes to stage." -ForegroundColor Yellow
    exit 0
}

# Build file list based on parameters
$filesToStage = @()

if ($Patterns) {
    # Process each pattern
    foreach ($pattern in $Patterns) {
        if ($pattern -eq '.') {
            # Stage all in current directory
            $filesToStage += $status.Modified + $status.Untracked + $status.Deleted
        }
        elseif (Test-Path $pattern) {
            # Specific file or directory - create a file info object
            $item = Get-Item $pattern -ErrorAction SilentlyContinue
            if ($item) {
                $filesToStage += @{
                    Path = $item.FullName
                    IndexStatus = ' '
                    WorkTreeStatus = 'M'
                }
            }
        }
        else {
            # Treat as glob pattern
            $matchedFiles = @()

            # Check modified files
            if ($status.Modified) {
                $matchedFiles += $status.Modified | Where-Object { $_ -and $_.Path -like $pattern }
            }

            # Check untracked files
            if ($status.Untracked) {
                $matchedFiles += $status.Untracked | Where-Object { $_ -and $_.Path -like $pattern }
            }

            # Check deleted files
            if ($status.Deleted) {
                $matchedFiles += $status.Deleted | Where-Object { $_ -and $_.Path -like $pattern }
            }

            if (@($matchedFiles).Count -eq 0 -and $PSCmdlet.MyInvocation.BoundParameters["Verbose"]) {
                Write-Warning "No files match pattern: $pattern"
            }

            $filesToStage += $matchedFiles
        }
    }
} else {
    # No patterns specified, use Type parameter
    switch ($Type) {
        'All' {
            $filesToStage = $status.Modified + $status.Untracked + $status.Deleted
        }
        'Modified' {
            $filesToStage = $status.Modified
        }
        'Untracked' {
            $filesToStage = $status.Untracked
        }
        'Deleted' {
            $filesToStage = $status.Deleted
        }
    }
}

# Remove duplicates
$filesToStage = $filesToStage | Select-Object -Unique

if (@($filesToStage).Count -eq 0) {
    Write-Host "No files to stage matching criteria." -ForegroundColor Yellow
    exit 0
}

# Interactive selection
if ($Interactive -and -not $DryRun) {
    Write-Host "`nSelect files to stage:" -ForegroundColor Yellow
    $selectedFiles = @()

    for ($i = 0; $i -lt @($filesToStage).Count; $i++) {
        $file = $filesToStage[$i]
        $status = if ($file -in $status.Deleted) { "deleted" }
                  elseif ($file -in $status.Modified) { "modified" }
                  elseif ($file -in $status.Untracked) { "new" }
                  else { "unknown" }

        $filePath = if ($file.Path) { $file.Path } elseif ($file -is [string]) { $file } else { $file.ToString() }
        Write-Host "[$($i + 1)] $filePath ($status)"
    }

    Write-Host "`nEnter file numbers to stage (comma-separated, or 'all'):" -NoNewline
    $selection = Read-Host

    if ($selection -eq 'all') {
        $selectedFiles = $filesToStage
    } else {
        $indices = $selection -split ',' | ForEach-Object { [int]$_.Trim() - 1 }
        $selectedFiles = $indices | ForEach-Object { $filesToStage[$_] }
    }

    $filesToStage = $selectedFiles
}

# Display files to be staged
Write-Host "`nFiles to stage:" -ForegroundColor Yellow
$filesByStatus = @{
    Modified = @()
    Untracked = @()
    Deleted = @()
}

foreach ($file in $filesToStage) {
    $filePath = if ($file.Path) { $file.Path } elseif ($file -is [string]) { $file } else { $file.ToString() }

    if ($file -in $status.Deleted) {
        $filesByStatus.Deleted += $file
        Write-Host "  - $filePath" -ForegroundColor Red
    }
    elseif ($file -in $status.Modified) {
        $filesByStatus.Modified += $file
        Write-Host "  M $filePath" -ForegroundColor Yellow
    }
    elseif ($file -in $status.Untracked) {
        $filesByStatus.Untracked += $file
        Write-Host "  + $filePath" -ForegroundColor Green
    }
}

# Summary
$summary = @()
if ($filesByStatus.Modified.Count -gt 0) { $summary += "$($filesByStatus.Modified.Count) modified" }
if ($filesByStatus.Untracked.Count -gt 0) { $summary += "$($filesByStatus.Untracked.Count) new" }
if ($filesByStatus.Deleted.Count -gt 0) { $summary += "$($filesByStatus.Deleted.Count) deleted" }

Write-Host "`nTotal: $(@($filesToStage).Count) files ($($summary -join ', '))" -ForegroundColor Cyan

# Stage files unless dry run
if (-not $DryRun) {
    try {
        foreach ($file in $filesToStage) {
            $filePath = if ($file.Path) { $file.Path } elseif ($file -is [string]) { $file } else { $file.ToString() }

            if ($VerbosePreference -ne 'SilentlyContinue') {
                Write-Host "Staging: $filePath" -ForegroundColor Gray
            }
            git add $filePath 2>$null
        }

        Write-Host "✓ Successfully staged $(@($filesToStage).Count) files" -ForegroundColor Green

        # Show git status if requested
        if ($ShowStatus) {
            Write-Host "`nGit status after staging:" -ForegroundColor Yellow
            git status --short
        }

    } catch {
        Write-Error "Failed to stage files: $_"
        exit 1
    }
} else {
    Write-Host "`n[DRY RUN] No files were actually staged" -ForegroundColor Magenta
}

# Output for pipeline
if ($VerbosePreference -ne 'SilentlyContinue') {
    Write-Output $filesToStage
}
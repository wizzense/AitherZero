#Requires -Version 7.0
# Stage: Development
# Dependencies: Git
# Description: Generate AI-enhanced commit messages from staged changes

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter()]
    [ValidateSet('feat', 'fix', 'docs', 'style', 'refactor', 'test', 'chore', 'perf', 'ci', 'build', 'revert')]
    [string]$Type,

    [Parameter()]
    [string]$Scope,

    [Parameter()]
    [switch]$IncludeBody,

    [Parameter()]
    [switch]$IncludeStats,

    [Parameter()]
    [switch]$BreakingChange,

    [Parameter()]
    [switch]$ShowDiff,

    [Parameter()]
    [switch]$CopyToClipboard,

    [Parameter()]
    [switch]$ApplyDirectly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Initialize logging
$loggingPath = Join-Path (Split-Path $PSScriptRoot -Parent) "domains/core/Logging.psm1"
if (Test-Path $loggingPath) {
    Import-Module $loggingPath -Force -ErrorAction SilentlyContinue
}

function Write-ScriptLog {
    param(
        [string]$Message,
        [string]$Level = 'Information'
    )

    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Message "[AICommit] $Message" -Level $Level
    } else {
        Write-Host "[$Level] $Message" -ForegroundColor $(
            switch ($Level) {
                'Error' { 'Red' }
                'Warning' { 'Yellow' }
                'Debug' { 'Gray' }
                default { 'White' }
            }
        )
    }
}

function Get-StagedChanges {
    <#
    .SYNOPSIS
        Get information about staged changes
    #>
    [CmdletBinding()]
    param()

    $staged = git diff --cached --name-status
    if (-not $staged) {
        return $null
    }

    $changes = @{
        Added = @()
        Modified = @()
        Deleted = @()
        Renamed = @()
        Total = 0
    }

    foreach ($line in $staged) {
        if ($line -match '^([AMDR])\s+(.+)') {
            $status = $Matches[1]
            $file = $Matches[2]

            switch ($status) {
                'A' { $changes.Added += $file }
                'M' { $changes.Modified += $file }
                'D' { $changes.Deleted += $file }
                'R' { $changes.Renamed += $file }
            }
            $changes.Total++
        }
    }

    return $changes
}

function Analyze-Changes {
    <#
    .SYNOPSIS
        Analyze staged changes to determine commit type and scope
    #>
    [CmdletBinding()]
    param(
        [hashtable]$Changes
    )

    $analysis = @{
        Type = 'chore'
        Scope = ''
        Breaking = $false
        Components = @()
    }

    # Analyze all changed files
    $allFiles = $Changes.Added + $Changes.Modified + $Changes.Deleted + $Changes.Renamed

    foreach ($file in $allFiles) {
        # Determine component/scope
        $component = switch -Regex ($file) {
            '^\.github/workflows' { 'ci' }
            '^tests/' { 'test' }
            '^docs/|README' { 'docs' }
            '^domains/([^/]+)' { $Matches[1] }
            '^automation-scripts/' { 'automation' }
            '^modules/([^/]+)' { $Matches[1] }
            '^orchestration/' { 'orchestration' }
            '^infrastructure/' { 'infra' }
            default { 'core' }
        }

        if ($component -and $component -notin $analysis.Components) {
            $analysis.Components += $component
        }
    }

    # Determine type based on changes
    if ($Changes.Added.Count -gt $Changes.Modified.Count) {
        $analysis.Type = 'feat'
    } elseif ($Changes.Modified.Count -gt 0) {
        # Check if it's a fix or refactor
        $diff = git diff --cached --unified=0
        if ($diff -match 'fix|bug|error|issue') {
            $analysis.Type = 'fix'
        } elseif ($diff -match 'refactor|clean|improve|optimize') {
            $analysis.Type = 'refactor'
        } elseif ($diff -match 'test|spec|should|expect|assert') {
            $analysis.Type = 'test'
        }
    }

    # Special case for CI/CD files
    if ($allFiles | Where-Object { $_ -match '\.yml$|\.yaml$|workflow' }) {
        $analysis.Type = 'ci'
    }

    # Special case for documentation
    if ($allFiles | Where-Object { $_ -match '\.md$|docs/' }) {
        if ($Changes.Total -eq ($allFiles | Where-Object { $_ -match '\.md$|docs/' }).Count) {
            $analysis.Type = 'docs'
        }
    }

    # Check for breaking changes
    $diff = git diff --cached
    if ($diff -match 'BREAKING CHANGE:|BREAKING:|BC:' -or
        $diff -match 'Remove-|Delete-|Deprecated') {
        $analysis.Breaking = $true
    }

    # Set scope
    if ($analysis.Components.Count -eq 1) {
        $analysis.Scope = $analysis.Components[0]
    } elseif ($analysis.Components.Count -le 3) {
        $analysis.Scope = $analysis.Components -join ','
    } else {
        $analysis.Scope = 'multiple'
    }

    return $analysis
}

function Generate-CommitMessage {
    <#
    .SYNOPSIS
        Generate an AI-enhanced commit message
    #>
    [CmdletBinding()]
    param(
        [hashtable]$Changes,
        [hashtable]$Analysis,
        [string]$Type,
        [string]$Scope,
        [switch]$IncludeBody,
        [switch]$IncludeStats,
        [switch]$BreakingChange
    )

    # Use provided type/scope or auto-detected
    $commitType = if ($Type) { $Type } else { $Analysis.Type }
    $commitScope = if ($Scope) { $Scope } else { $Analysis.Scope }

    # Generate summary based on changes
    $summary = switch ($commitType) {
        'feat' {
            if ($Changes.Added.Count -gt 0) {
                "add $(($Changes.Added | Select-Object -First 1 | Split-Path -Leaf)) and related functionality"
            } else {
                "enhance $commitScope functionality"
            }
        }
        'fix' {
            "resolve issues in $commitScope"
        }
        'docs' {
            "update documentation"
        }
        'test' {
            "add/update tests for $commitScope"
        }
        'ci' {
            "update CI/CD workflows"
        }
        'refactor' {
            "improve $commitScope implementation"
        }
        'chore' {
            "update $commitScope configuration"
        }
        default {
            "update $commitScope"
        }
    }

    # Build commit message
    $message = if ($commitScope) {
        "$commitType($commitScope): $summary"
    } else {
        "${commitType}: $summary"
    }

    # Add breaking change indicator
    if ($BreakingChange -or $Analysis.Breaking) {
        $message = "$message [BREAKING]"
    }

    # Add body if requested
    if ($IncludeBody) {
        $body = @()

        # Add file changes summary
        if ($Changes.Added.Count -gt 0) {
            $body += "Added:"
            $Changes.Added | Select-Object -First 3 | ForEach-Object {
                $body += "- $_"
            }
            if ($Changes.Added.Count -gt 3) {
                $body += "- ... and $($Changes.Added.Count - 3) more"
            }
        }

        if ($Changes.Modified.Count -gt 0) {
            $body += "`nModified:"
            $Changes.Modified | Select-Object -First 3 | ForEach-Object {
                $body += "- $_"
            }
            if ($Changes.Modified.Count -gt 3) {
                $body += "- ... and $($Changes.Modified.Count - 3) more"
            }
        }

        if ($Changes.Deleted.Count -gt 0) {
            $body += "`nDeleted:"
            $Changes.Deleted | Select-Object -First 3 | ForEach-Object {
                $body += "- $_"
            }
        }

        if ($body) {
            $message += "`n`n" + ($body -join "`n")
        }
    }

    # Add statistics if requested
    if ($IncludeStats) {
        $stats = git diff --cached --shortstat
        if ($stats) {
            $message += "`n`n📊 Statistics: $stats"
        }
    }

    # Add AI attribution
    $message += "`n`n🤖 Generated by AitherZero AI Commit Assistant"

    return $message
}

# Main execution
Write-ScriptLog "Starting AI commit message generation"

try {
    # Check if we're in a git repository
    if (-not (Test-Path .git)) {
        throw "Not in a git repository"
    }

    # Get staged changes
    $changes = Get-StagedChanges
    if (-not $changes -or $changes.Total -eq 0) {
        Write-Warning "No staged changes found. Stage files first with 'git add' or use 'az 0704'"
        exit 0
    }

    Write-Host "`n📊 Analyzing staged changes..." -ForegroundColor Cyan
    Write-Host "  Added: $($changes.Added.Count) files" -ForegroundColor Green
    Write-Host "  Modified: $($changes.Modified.Count) files" -ForegroundColor Yellow
    Write-Host "  Deleted: $($changes.Deleted.Count) files" -ForegroundColor Red
    Write-Host "  Total: $($changes.Total) changes" -ForegroundColor White

    # Analyze changes
    $analysis = Analyze-Changes -Changes $changes

    Write-Host "`n🤖 AI Analysis Results:" -ForegroundColor Cyan
    Write-Host "  Type: $($analysis.Type)" -ForegroundColor White
    Write-Host "  Scope: $($analysis.Scope)" -ForegroundColor White
    Write-Host "  Components: $($analysis.Components -join ', ')" -ForegroundColor Gray
    if ($analysis.Breaking) {
        Write-Host "  ⚠️  BREAKING CHANGES DETECTED" -ForegroundColor Red
    }

    # Generate commit message
    $commitMessage = Generate-CommitMessage `
        -Changes $changes `
        -Analysis $analysis `
        -Type $Type `
        -Scope $Scope `
        -IncludeBody:$IncludeBody `
        -IncludeStats:$IncludeStats `
        -BreakingChange:$BreakingChange

    # Display the message
    Write-Host "`n📝 Generated Commit Message:" -ForegroundColor Green
    Write-Host "────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host $commitMessage -ForegroundColor White
    Write-Host "────────────────────────────────────────" -ForegroundColor DarkGray

    # Show diff if requested
    if ($ShowDiff) {
        Write-Host "`n📄 Staged Changes:" -ForegroundColor Cyan
        git diff --cached --stat
    }

    # Copy to clipboard if requested
    if ($CopyToClipboard) {
        if ($PSCmdlet.ShouldProcess("clipboard", "Copy commit message")) {
            if ($IsWindows) {
                $commitMessage | Set-Clipboard
                Write-Host "`n✅ Commit message copied to clipboard!" -ForegroundColor Green
            } elseif ($IsMacOS) {
                $commitMessage | pbcopy
                Write-Host "`n✅ Commit message copied to clipboard!" -ForegroundColor Green
            } elseif ($IsLinux) {
                if (Get-Command xclip -ErrorAction SilentlyContinue) {
                    $commitMessage | xclip -selection clipboard
                    Write-Host "`n✅ Commit message copied to clipboard!" -ForegroundColor Green
                } else {
                    Write-Warning "xclip not installed - cannot copy to clipboard"
                }
            }
        }
    }

    # Apply directly if requested
    if ($ApplyDirectly) {
        if ($PSCmdlet.ShouldProcess("repository", "Create git commit with generated message")) {
            Write-Host "`n🚀 Creating commit..." -ForegroundColor Yellow

            $tempFile = [System.IO.Path]::GetTempFileName()
            $commitMessage | Set-Content -Path $tempFile -Encoding UTF8

            git commit -F $tempFile
            Remove-Item $tempFile -Force

            if ($LASTEXITCODE -eq 0) {
                Write-Host "✅ Commit created successfully!" -ForegroundColor Green

                # Show the commit
                git log -1 --oneline
            } else {
                Write-Error "Failed to create commit"
            }
        }
    } else {
        Write-Host "`nTo use this message:" -ForegroundColor Cyan
        Write-Host "  1. Copy the message above" -ForegroundColor Gray
        Write-Host "  2. Run: git commit -m `"<paste message>`"" -ForegroundColor Gray
        Write-Host "  Or use: az 0741 -ApplyDirectly" -ForegroundColor Gray
    }

    Write-ScriptLog "AI commit message generation completed successfully"

} catch {
    Write-ScriptLog "Error generating commit message: $_" -Level 'Error'
    Write-Error $_
    exit 1
}

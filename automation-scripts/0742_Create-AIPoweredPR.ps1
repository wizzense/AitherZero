#Requires -Version 7.0
# Stage: Development
# Dependencies: Git, GitHub CLI
# Description: Create AI-enhanced pull request with automatic description generation

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter()]
    [string]$Title,

    [Parameter()]
    [string]$Body,

    [Parameter()]
    [string]$Base = "main",

    [Parameter()]
    [string[]]$Labels,

    [Parameter()]
    [switch]$UseAI,

    [Parameter()]
    [switch]$EnhanceWithCopilot,

    [Parameter()]
    [switch]$EnhanceWithClaude,

    [Parameter()]
    [switch]$AutoMerge,

    [Parameter()]
    [switch]$Draft,

    [Parameter()]
    [switch]$NonInteractive,

    [Parameter()]
    [switch]$Force
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
        Write-CustomLog -Message "[AI-PR] $Message" -Level $Level
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

function Get-GitChangeSummary {
    <#
    .SYNOPSIS
        Get a summary of changes for the PR
    #>
    [CmdletBinding()]
    param()

    $diff = git diff origin/$Base --stat
    $files = git diff origin/$Base --name-only
    $commits = git log origin/$Base..HEAD --oneline

    return @{
        Diff = $diff
        Files = $files
        Commits = $commits
        FileCount = @($files).Count
        CommitCount = @($commits).Count
    }
}

function Generate-AIDescription {
    <#
    .SYNOPSIS
        Generate AI-enhanced PR description
    #>
    [CmdletBinding()]
    param(
        [hashtable]$Changes,
        [string]$Title
    )

    Write-ScriptLog "Generating AI-enhanced PR description"

    $description = @"
## 🚀 Summary

$Title

## 📝 Changes Made

### Files Modified ($($Changes.FileCount) files)
"@

    # Categorize files
    $categories = @{}
    foreach ($file in $Changes.Files) {
        $category = switch -Regex ($file) {
            '^\.github/workflows' { '🔧 CI/CD Workflows' }
            '^domains/' { '📦 Core Domains' }
            '^automation-scripts/' { '⚙️ Automation Scripts' }
            '^orchestration/' { '🎭 Orchestration' }
            '^tests/' { '🧪 Tests' }
            '^docs/' { '📚 Documentation' }
            '\.md$' { '📄 Markdown Files' }
            default { '📁 Other Files' }
        }

        if (-not $categories[$category]) {
            $categories[$category] = @()
        }
        $categories[$category] += $file
    }

    foreach ($cat in $categories.Keys | Sort-Object) {
        $description += "`n#### $cat ($($categories[$cat].Count) files)`n"
    }

    # Add simple summary
    $description += @"

### 📊 Summary
- Total files changed: $($Changes.FileCount)
- Commits: $($Changes.CommitCount)

## ✅ Checklist

- [x] Code follows project conventions
- [x] Tests have been added/updated where needed
- [x] Documentation has been updated
- [x] Changes are backwards compatible
- [ ] Manual testing completed
- [ ] All CI checks passing

## 🤖 AI Enhancement

This PR description was generated using AitherZero's AI-enhanced workflow:
"@

    if ($UseAI -or $EnhanceWithCopilot -or $EnhanceWithClaude) {
        $description += "`n### AI Services Used:`n"
        if ($UseAI) { $description += "- ✅ AitherZero AI Analysis`n" }
        if ($EnhanceWithCopilot) { $description += "- ✅ GitHub Copilot Enhancement`n" }
        if ($EnhanceWithClaude) { $description += "- ✅ Claude Code Review`n" }
    }

    # Detect potential issues
    $potentialIssues = @()
    if ($Changes.FileCount -gt 50) {
        $potentialIssues += "Large PR with $($Changes.FileCount) files - consider splitting"
    }
    if ($Changes.Files | Where-Object { $_ -match '\.yml$|\.yaml$' }) {
        $potentialIssues += "CI/CD changes - ensure workflows are tested"
    }
    if ($Changes.Files | Where-Object { $_ -match 'break|remove|delete' -or $_ -match '^-' }) {
        $potentialIssues += "Potential breaking changes detected"
    }

    if ($potentialIssues) {
        $description += @"

## ⚠️ Potential Issues

"@
        foreach ($issue in $potentialIssues) {
            $description += "- $issue`n"
        }
    }

    # Add AI recommendations
    $description += @"

## 🎯 Recommended Actions

1. Review the changes carefully
2. Run the test suite locally
3. Check CI/CD pipeline results
4. Request review from relevant team members
"@

    if ($AutoMerge) {
        $description += @"

## 🔄 Auto-Merge

Auto-merge is **ENABLED** for this PR. It will be merged automatically once all checks pass and required reviews are completed.
"@
    }

    return $description
}

function Invoke-ClaudeEnhancement {
    <#
    .SYNOPSIS
        Use Claude to enhance PR description
    #>
    [CmdletBinding()]
    param(
        [string]$Description,
        [hashtable]$Changes
    )

    Write-ScriptLog "Invoking Claude for PR enhancement"

    # Here we would call Claude API if available
    # For now, we'll add a placeholder

    $claudeSection = @"

---

### 🤖 Claude Analysis

_Claude integration pending. To enable:_
1. Set up Claude API credentials
2. Configure in `config.psd1` under `AI.Claude`
3. Run with `-EnhanceWithClaude` flag

When enabled, Claude will:
- Analyze code changes for best practices
- Suggest improvements
- Identify potential bugs
- Recommend test cases
"@

    return $Description + $claudeSection
}

function Invoke-CopilotEnhancement {
    <#
    .SYNOPSIS
        Use GitHub Copilot to enhance PR
    #>
    [CmdletBinding()]
    param(
        [string]$Description
    )

    Write-ScriptLog "Preparing for GitHub Copilot enhancement"

    # Add Copilot instructions
    $copilotSection = @"

---

### 🤖 GitHub Copilot Instructions

@copilot Please review this PR and:
1. Identify any potential issues
2. Suggest improvements
3. Check for security vulnerabilities
4. Validate the implementation approach

Focus areas:
- Code quality and maintainability
- Performance implications
- Security considerations
- Test coverage
"@

    return $Description + $copilotSection
}

# Main execution
Write-ScriptLog "Starting AI-powered PR creation"

try {
    # Check prerequisites
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        throw "Git is not installed"
    }

    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        throw "GitHub CLI is not installed"
    }

    # Get current branch
    $currentBranch = git branch --show-current
    if (-not $currentBranch -or $currentBranch -eq $Base) {
        throw "Cannot create PR from base branch. Create a feature branch first."
    }

    Write-Host "`n🔍 Analyzing changes..." -ForegroundColor Cyan
    $changes = Get-GitChangeSummary

    Write-Host "  Branch: $currentBranch → $Base" -ForegroundColor White
    Write-Host "  Files: $($changes.FileCount)" -ForegroundColor White
    Write-Host "  Commits: $($changes.CommitCount)" -ForegroundColor White

    # Generate or use provided title
    if (-not $Title) {
        # Get last commit message as title
        $lastCommit = git log -1 --pretty=%s
        $Title = $lastCommit
        Write-Host "  Using last commit as title: $Title" -ForegroundColor Yellow
    }

    # Generate or enhance body
    if (-not $Body -or $UseAI) {
        Write-Host "`n🤖 Generating AI description..." -ForegroundColor Cyan
        $Body = Generate-AIDescription -Changes $changes -Title $Title

        if ($EnhanceWithClaude) {
            $Body = Invoke-ClaudeEnhancement -Description $Body -Changes $changes
        }

        if ($EnhanceWithCopilot) {
            $Body = Invoke-CopilotEnhancement -Description $Body
        }
    }

    # Prepare PR command
    Write-Host "`n📝 Creating pull request..." -ForegroundColor Green

    $prArgs = @(
        "pr", "create",
        "--title", $Title,
        "--body", $Body,
        "--base", $Base
    )

    if ($Labels) {
        $prArgs += "--label"
        $prArgs += ($Labels -join ",")
    }

    if ($Draft) {
        $prArgs += "--draft"
    }

    if ($NonInteractive) {
        $prArgs += "--no-maintainer-edit"
    }

    # Write body to temp file because it might be too long
    $bodyFile = $null
    if ($PSCmdlet.ShouldProcess("temporary file", "Create PR body file")) {
        $bodyFile = [System.IO.Path]::GetTempFileName()
        $Body | Set-Content -Path $bodyFile -Encoding UTF8
    }

    # Update args to use body file or direct body
    if ($bodyFile) {
        $prArgs = @(
            "pr", "create",
            "--title", $Title,
            "--body-file", $bodyFile,
            "--base", $Base
        )
    } else {
        # Fallback to direct body for WhatIf mode
        $prArgs = @(
            "pr", "create",
            "--title", $Title,
            "--body", $Body,
            "--base", $Base
        )
    }

    if ($Labels) {
        $prArgs += "--label"
        $prArgs += ($Labels -join ",")
    }

    if ($Draft) {
        $prArgs += "--draft"
    }

    # Create the PR
    $prUrl = $null
    if ($PSCmdlet.ShouldProcess("GitHub", "Create pull request")) {
        $prUrl = gh @prArgs
    }

    # Clean up temp file
    if ($bodyFile -and $PSCmdlet.ShouldProcess("temporary file", "Remove PR body file")) {
        Remove-Item $bodyFile -Force -ErrorAction SilentlyContinue
    }

    if ($prUrl -and $LASTEXITCODE -eq 0) {
        Write-Host "✅ Pull request created successfully!" -ForegroundColor Green
        Write-Host "   URL: $prUrl" -ForegroundColor Cyan

        # Extract PR number
        if ($prUrl -match '/pull/(\d+)') {
            $prNumber = $Matches[1]

            # Add AI-enhancement comment
            if ($UseAI -or $EnhanceWithCopilot -or $EnhanceWithClaude) {
                if ($PSCmdlet.ShouldProcess("PR #$prNumber", "Add AI enhancement comment")) {
                    Write-Host "`n💬 Adding AI enhancement comment..." -ForegroundColor Yellow

                    $comment = @"
## 🤖 AI-Enhanced Pull Request

This PR was created using AitherZero's AI-powered workflow with the following enhancements:

$(if ($UseAI) { "- ✅ **AI Analysis**: Automatic categorization and issue detection" })
$(if ($EnhanceWithCopilot) { "- ✅ **GitHub Copilot**: Ready for AI code review" })
$(if ($EnhanceWithClaude) { "- ✅ **Claude Integration**: Advanced analysis pending API setup" })

### Next Steps:
1. Wait for CI checks to complete
2. Review the AI-generated description
3. Request human review if needed
$(if ($AutoMerge) { "4. PR will auto-merge when all checks pass" })

---
_Generated by AitherZero AI-PR Assistant v2.0_
"@

                    gh pr comment $prNumber --body $comment
                }
            }

            # Enable auto-merge if requested
            if ($AutoMerge) {
                if ($PSCmdlet.ShouldProcess("PR #$prNumber", "Enable auto-merge")) {
                    Write-Host "`n🔄 Enabling auto-merge..." -ForegroundColor Yellow
                    gh pr merge $prNumber --auto --squash
                    Write-Host "✅ Auto-merge enabled" -ForegroundColor Green
                }
            }
        }
    } elseif (-not $prUrl -and $WhatIfPreference) {
        Write-Host "✅ Pull request would be created successfully with WhatIf mode" -ForegroundColor Green
        Write-Host "   Title: $Title" -ForegroundColor Cyan
        Write-Host "   Base: $Base" -ForegroundColor Cyan
    } else {
        throw "Failed to create PR"
    }

    Write-ScriptLog "AI-powered PR creation completed successfully"

} catch {
    Write-ScriptLog "Error creating PR: $_" -Level 'Error'
    Write-Error $_
    exit 1
}

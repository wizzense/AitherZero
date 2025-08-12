#Requires -Version 7.0
<#
.SYNOPSIS
    Generates AI-ready continuation prompts from saved context
.DESCRIPTION
    Creates comprehensive prompts for AI assistants to continue work seamlessly
    Includes current state, errors, and next steps
.PARAMETER ContextPath
    Path to saved context file
.PARAMETER OutputPath
    Path to save the continuation prompt
.PARAMETER MaxTokens
    Maximum tokens for the prompt (for compression)
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ContextPath = "./.claude/session-context.json",
    
    [Parameter(Mandatory = $false)]
    [string]$OutputPath = "./.claude/continuation-prompt.md",
    
    [int]$MaxTokens = 4000,
    
    [switch]$CopyToClipboard,
    
    [switch]$ShowPrompt
)

# Script metadata
$scriptInfo = @{
    Stage = 'Development'
    Number = '0821'
    Name = 'Generate-ContinuationPrompt'
    Description = 'Generates AI continuation prompts from saved context'
    Dependencies = @()
    Tags = @('ai', 'continuation', 'context', 'prompt')
    RequiresAdmin = $false
}

# Import required modules
$modulePath = Join-Path $PSScriptRoot ".." "Initialize-AitherModules.ps1"
if (Test-Path $modulePath) {
    . $modulePath
}

# Helper function to estimate token count
function Get-TokenEstimate {
    param([string]$Text)
    # Rough estimate: 1 token ≈ 4 characters
    return [math]::Ceiling($Text.Length / 4)
}

# Helper function to prioritize context
function Get-PrioritizedContext {
    param(
        [hashtable]$Context,
        [int]$MaxTokens
    )
    
    $prioritized = @{
        Critical = @()
        Important = @()
        Nice = @()
    }
    
    # Critical: Current errors and failures
    if ($Context.PowerShell.RecentErrors) {
        $prioritized.Critical += @{
            Type = "Errors"
            Content = $Context.PowerShell.RecentErrors
        }
    }
    
    if ($Context.Test.TestResults -and $Context.Test.TestResults -ne "Failed to parse test results") {
        if ($Context.Test.TestResults.Failed -gt 0) {
            $prioritized.Critical += @{
                Type = "Test Failures"
                Content = $Context.Test.TestResults
            }
        }
    }
    
    # Critical: Modified files
    if ($Context.Git.ModifiedFiles) {
        $prioritized.Critical += @{
            Type = "Modified Files"
            Content = $Context.Git.ModifiedFiles
        }
    }
    
    # Important: Git status and branch
    $prioritized.Important += @{
        Type = "Git Context"
        Content = @{
            Branch = $Context.Git.Branch
            LastCommit = $Context.Git.LastCommit
            Status = $Context.Git.Status
        }
    }
    
    # Important: TODO items
    if ($Context.Project.TodoList) {
        $prioritized.Important += @{
            Type = "TODO Items"
            Content = $Context.Project.TodoList | Select-Object -First 10
        }
    }
    
    # Nice: Command history
    if ($Context.PowerShell.CommandHistory) {
        $prioritized.Nice += @{
            Type = "Recent Commands"
            Content = $Context.PowerShell.CommandHistory | Select-Object -Last 10
        }
    }
    
    return $prioritized
}

# Generate prompt sections
function New-PromptSection {
    param(
        [string]$Title,
        [object]$Content,
        [int]$MaxLength = 1000
    )
    
    $section = @()
    $section += "## $Title"
    $section += ""
    
    if ($Content -is [string]) {
        $section += $Content
    }
    elseif ($Content -is [array]) {
        foreach ($item in $Content) {
            if ($item -is [string]) {
                $section += "- $item"
            }
            else {
                $section += "- $(ConvertTo-Json $item -Compress)"
            }
        }
    }
    elseif ($Content -is [hashtable] -or $Content -is [PSCustomObject]) {
        $json = ConvertTo-Json $Content -Depth 3 -Compress
        if ($json.Length -gt $MaxLength) {
            $json = $json.Substring(0, $MaxLength) + "... [truncated]"
        }
        $section += '```json'
        $section += $json
        $section += '```'
    }
    
    $section += ""
    return $section -join "`n"
}

# Main execution
try {
    Write-Host "🤖 Generating AI continuation prompt..." -ForegroundColor Cyan
    
    # Load saved context
    if (-not (Test-Path $ContextPath)) {
        Write-Error "Context file not found. Run 0820_Save-WorkContext.ps1 first."
        exit 1
    }
    
    $context = Get-Content $ContextPath | ConvertFrom-Json -AsHashtable
    
    # Build prompt
    $prompt = @()
    
    # Header
    $prompt += "# AitherZero Session Continuation"
    $prompt += ""
    $prompt += "Please continue the work from the previous session. Here's the current context:"
    $prompt += ""
    $prompt += "**Session ID:** $($context.SessionId)"
    $prompt += "**Timestamp:** $($context.Timestamp)"
    $prompt += "**Project Version:** $($context.Project.Version)"
    $prompt += ""
    
    # Current state
    $prompt += "## Current State"
    $prompt += ""
    $prompt += "### Git Status"
    $prompt += "- **Branch:** $($context.Git.Branch)"
    $prompt += "- **Last Commit:** $($context.Git.LastCommit)"
    $prompt += "- **Modified Files:** $($context.Git.ModifiedFiles.Count)"
    $prompt += ""
    
    if ($context.Git.ModifiedFiles -and $context.Git.ModifiedFiles.Count -gt 0) {
        $prompt += "### Files Being Worked On"
        foreach ($file in $context.Git.ModifiedFiles.Keys | Select-Object -First 10) {
            $info = $context.Git.ModifiedFiles[$file]
            $prompt += "- `$file` ($($info.Status)) - $($info.Lines) lines"
        }
        $prompt += ""
    }
    
    # Errors and issues
    if ($context.PowerShell.RecentErrors -and $context.PowerShell.RecentErrors.Count -gt 0) {
        $prompt += "## ⚠️ Recent Errors"
        $prompt += ""
        foreach ($errorItem in $context.PowerShell.RecentErrors | Select-Object -First 3) {
            $prompt += "### Error in $($errorItem.Script):$($errorItem.Line)"
            $prompt += "**Message:** $($errorItem.Message)"
            $prompt += "**Category:** $($errorItem.Category)"
            $prompt += ""
        }
    }
    
    # Test results
    if ($context.Test.TestResults) {
        $prompt += "## Test Status"
        $prompt += ""
        if ($context.Test.TestResults -ne "Failed to parse test results") {
            $prompt += "- **Total Tests:** $($context.Test.TestResults.TotalCount ?? 'Unknown')"
            $prompt += "- **Passed:** $($context.Test.TestResults.PassedCount ?? 'Unknown')"
            $prompt += "- **Failed:** $($context.Test.TestResults.FailedCount ?? 'Unknown')"
        }
        
        if ($context.Test.AnalyzerResults) {
            $prompt += ""
            $prompt += "### PSScriptAnalyzer Results"
            $prompt += "- **Total Issues:** $($context.Test.AnalyzerResults.TotalIssues)"
            if ($context.Test.AnalyzerResults.BySeverity) {
                foreach ($severity in $context.Test.AnalyzerResults.BySeverity) {
                    foreach ($key in $severity.Keys) {
                        $prompt += "- **$($key):** $($severity[$key])"
                    }
                }
            }
        }
        $prompt += ""
    }
    
    # TODO items
    if ($context.Project.TodoList -and $context.Project.TodoList.Count -gt 0) {
        $prompt += "## Outstanding TODO Items"
        $prompt += ""
        foreach ($todo in $context.Project.TodoList | Select-Object -First 5) {
            $prompt += "- [ ] $($todo.File):$($todo.Line) - $($todo.Text)"
        }
        if ($context.Project.TodoList.Count -gt 5) {
            $prompt += "- ... and $($context.Project.TodoList.Count - 5) more"
        }
        $prompt += ""
    }
    
    # Recent commands (for context)
    if ($context.PowerShell.CommandHistory -and $context.PowerShell.CommandHistory.Count -gt 0) {
        $prompt += "## Recent Commands"
        $prompt += ""
        $prompt += '```powershell'
        foreach ($cmd in $context.PowerShell.CommandHistory | Select-Object -Last 5) {
            $prompt += $cmd.CommandLine
        }
        $prompt += '```'
        $prompt += ""
    }
    
    # Next steps section
    $prompt += "## Suggested Next Steps"
    $prompt += ""
    
    $nextSteps = @()
    
    # Based on errors
    if ($context.PowerShell.RecentErrors -and $context.PowerShell.RecentErrors.Count -gt 0) {
        $nextSteps += "1. Fix the errors reported above"
    }
    
    # Based on test failures
    if ($context.Test.TestResults -and $context.Test.TestResults.FailedCount -gt 0) {
        $nextSteps += "2. Fix failing tests"
    }
    
    # Based on analyzer results
    if ($context.Test.AnalyzerResults -and $context.Test.AnalyzerResults.TotalIssues -gt 0) {
        $nextSteps += "3. Address PSScriptAnalyzer violations"
    }
    
    # Based on modified files
    if ($context.Git.ModifiedFiles -and $context.Git.ModifiedFiles.Count -gt 0) {
        $nextSteps += "4. Complete changes to modified files"
        $nextSteps += "5. Run tests on modified code"
        $nextSteps += "6. Commit changes with descriptive message"
    }
    
    # Based on TODO items
    if ($context.Project.TodoList -and $context.Project.TodoList.Count -gt 0) {
        $nextSteps += "7. Address TODO items in code"
    }
    
    if ($nextSteps.Count -eq 0) {
        $nextSteps += "No specific issues detected. Continue with planned development."
    }
    
    foreach ($step in $nextSteps) {
        $prompt += $step
    }
    $prompt += ""
    
    # Instructions
    $prompt += "## Instructions"
    $prompt += ""
    $prompt += "Please continue working on this project with the following priorities:"
    $prompt += "1. Fix any critical errors first"
    $prompt += "2. Ensure all tests pass"
    $prompt += "3. Address code quality issues"
    $prompt += "4. Complete any in-progress features"
    $prompt += "5. Update documentation as needed"
    $prompt += ""
    $prompt += "Use the established patterns and conventions in the codebase."
    $prompt += "Run tests frequently to ensure changes don't break existing functionality."
    $prompt += ""
    
    # Footer with quick commands
    $prompt += "## Quick Commands"
    $prompt += '```powershell'
    $prompt += '# Initialize environment'
    $prompt += './Initialize-AitherModules.ps1'
    $prompt += ''
    $prompt += '# Run tests'
    $prompt += 'seq 0402  # Unit tests'
    $prompt += 'seq 0404  # PSScriptAnalyzer'
    $prompt += ''
    $prompt += '# Save progress'
    $prompt += 'seq 0820  # Save work context'
    $prompt += '```'
    
    $promptText = $prompt -join "`n"
    
    # Check token count and compress if needed
    $tokenCount = Get-TokenEstimate -Text $promptText
    if ($tokenCount -gt $MaxTokens) {
        Write-Warning "Prompt exceeds token limit ($tokenCount > $MaxTokens). Compressing..."
        
        # Remove less important sections
        $promptText = $promptText -replace '## Recent Commands[\s\S]*?(?=##|$)', ''
        $promptText = $promptText -replace '## Quick Commands[\s\S]*?$', ''
        
        $newTokenCount = Get-TokenEstimate -Text $promptText
        Write-Host "   Compressed from $tokenCount to $newTokenCount tokens" -ForegroundColor Gray
    }
    
    # Save prompt
    $outputDir = Split-Path $OutputPath -Parent
    if ($outputDir -and -not (Test-Path $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    }
    
    $promptText | Set-Content $OutputPath -Encoding UTF8
    
    Write-Host "✅ Continuation prompt generated!" -ForegroundColor Green
    Write-Host "   File: $OutputPath" -ForegroundColor Gray
    Write-Host "   Tokens: ~$(Get-TokenEstimate -Text $promptText)" -ForegroundColor Gray
    
    # Copy to clipboard if requested
    if ($CopyToClipboard) {
        if ($IsWindows) {
            $promptText | Set-Clipboard
            Write-Host "   📋 Copied to clipboard!" -ForegroundColor Green
        }
        elseif ($IsMacOS) {
            $promptText | pbcopy
            Write-Host "   📋 Copied to clipboard!" -ForegroundColor Green
        }
        elseif ($IsLinux) {
            if (Get-Command xclip -ErrorAction SilentlyContinue) {
                $promptText | xclip -selection clipboard
                Write-Host "   📋 Copied to clipboard!" -ForegroundColor Green
            }
        }
    }
    
    # Show prompt if requested
    if ($ShowPrompt) {
        Write-Host ""
        Write-Host "=" * 80 -ForegroundColor Cyan
        Write-Host $promptText
        Write-Host "=" * 80 -ForegroundColor Cyan
    }
    
    exit 0
}
catch {
    Write-Error "Failed to generate continuation prompt: $_"
    exit 1
}
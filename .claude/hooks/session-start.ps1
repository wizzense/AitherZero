#!/usr/bin/env pwsh
#requires -version 7

<#
.SYNOPSIS
    Claude Code Session Start Hook
.DESCRIPTION
    Executed when a new Claude Code session starts. Initializes environment and provides context.
.NOTES
    This hook receives JSON input via stdin and can add context about the project.
#>

param()

# Read JSON input from stdin (may be empty for session start)
$input = @()
$inputStream = [Console]::In
while ($null -ne ($line = $inputStream.ReadLine())) {
    $input += $line
}

try {
    # Initialize logging
    $logPath = "$env:CLAUDE_PROJECT_DIR/logs/claude-hooks.log"
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
    function Write-HookLog {
        param([string]$Message, [string]$Level = "INFO")
        $logEntry = "[$timestamp] [$Level] SessionStart: $Message"
        if ($env:CLAUDE_PROJECT_DIR -and (Test-Path (Split-Path $logPath -Parent))) {
            $logEntry | Add-Content -Path $logPath -Force
        }
        Write-Host $logEntry
    }
    
    Write-HookLog "Claude Code session starting for AitherZero project"
    
    # Initialize project context
    $contextSections = @()
    
    # Project overview
    $contextSections += @"
# AitherZero Project Overview

AitherZero is a comprehensive infrastructure automation platform with AI-native DevOps capabilities.

## Key Components
- **Cross-platform bootstrap system** (bootstrap.ps1/sh)
- **Domain-driven architecture** (domains/ directory)
- **Number-based orchestration** (0000-9999 automation scripts)
- **GitHub Actions integration** (self-hosted runners, CI/CD)
- **AI agent integration** (Claude Code hooks, multi-AI support)
- **Comprehensive testing** (Pester, PSScriptAnalyzer, coverage)
- **Real-time monitoring** (dashboards, metrics, performance)

## Quick Commands
- ``az <number>`` - Run automation script (e.g., az 0402 for tests)
- ``seq <pattern>`` - Run orchestration sequence
- ``./Start-AitherZero.ps1`` - Main interactive UI
- ``Initialize-AitherModules.ps1`` - Initialize environment
"@
    
    # Environment status
    if ($env:CLAUDE_PROJECT_DIR) {
        try {
            Push-Location $env:CLAUDE_PROJECT_DIR
            
            # Check AitherZero initialization
            $envStatus = if ($env:AITHERZERO_INITIALIZED) { 
                "✅ Initialized" 
            } elseif (Test-Path "./Initialize-AitherModules.ps1") {
                "⚠️ Not initialized (run Initialize-AitherModules.ps1)"
            } else {
                "❌ Scripts not found"
            }
            
            # Git information
            $gitInfo = ""
            try {
                $currentBranch = git rev-parse --abbrev-ref HEAD 2>$null
                $lastCommit = git log -1 --pretty=format:"%h %s" 2>$null
                $gitStatus = git status --porcelain 2>$null
                $changedFiles = if ($gitStatus) { ($gitStatus | Measure-Object).Count } else { 0 }
                
                $gitInfo = @"
- **Branch:** $currentBranch
- **Last commit:** $lastCommit
- **Uncommitted changes:** $changedFiles files
"@
            } catch {
                $gitInfo = "- Git information unavailable"
            }
            
            # Recent activity
            $recentActivity = ""
            $activityLog = "./logs/activity.json"
            if (Test-Path $activityLog) {
                try {
                    $recentEntries = Get-Content $activityLog -Tail 5 | ForEach-Object {
                        $entry = $_ | ConvertFrom-Json
                        "- $($entry.timestamp): $($entry.tool)"
                    }
                    $recentActivity = "**Recent Activity:**`n" + ($recentEntries -join "`n")
                } catch {
                    $recentActivity = "Recent activity log unavailable"
                }
            }
            
            $contextSections += @"

## Current Environment Status
- **AitherZero Environment:** $envStatus
- **Project Directory:** $env:CLAUDE_PROJECT_DIR
- **PowerShell Version:** $($PSVersionTable.PSVersion)
- **Platform:** $(if ($IsWindows) { 'Windows' } elseif ($IsLinux) { 'Linux' } elseif ($IsMacOS) { 'macOS' } else { 'Unknown' })

## Git Status
$gitInfo

$recentActivity
"@
            
            Pop-Location
        } catch {
            $contextSections += @"

## Environment Status
- **Project Directory:** $env:CLAUDE_PROJECT_DIR
- **Status:** Error reading project information
"@
        }
    } else {
        $contextSections += @"

## Environment Status
- **CLAUDE_PROJECT_DIR not set** - Some features may be limited
- Consider setting CLAUDE_PROJECT_DIR environment variable
"@
    }
    
    # Available automation scripts
    if ($env:CLAUDE_PROJECT_DIR -and (Test-Path "$env:CLAUDE_PROJECT_DIR/automation-scripts")) {
        try {
            Push-Location "$env:CLAUDE_PROJECT_DIR/automation-scripts"
            $scriptCategories = @{
                "Environment & Dependencies (0000-0099)" = @(0..99)
                "Infrastructure & System (0100-0199)" = @(100..199) 
                "Development Tools (0200-0299)" = @(200..299)
                "Deployment & Services (0300-0399)" = @(300..399)
                "Testing & Validation (0400-0499)" = @(400..499)
                "Reporting & Analytics (0500-0599)" = @(500..599)
                "Development Workflow (0700-0799)" = @(700..799)
            }
            
            $availableScripts = @()
            foreach ($category in $scriptCategories.Keys) {
                $range = $scriptCategories[$category]
                $scripts = Get-ChildItem -Filter "*.ps1" | Where-Object { 
                    $name = $_.BaseName
                    if ($name -match '^(\d{4})') {
                        $num = [int]$matches[1]
                        $num -in $range
                    }
                } | Select-Object -First 5
                
                if ($scripts.Count -gt 0) {
                    $scriptList = $scripts | ForEach-Object { 
                        $num = $_.BaseName.Substring(0,4)
                        $desc = $_.BaseName.Substring(5) -replace '_', ' '
                        "  - ``az $num`` - $desc"
                    }
                    $availableScripts += "**$category**`n" + ($scriptList -join "`n")
                }
            }
            
            if ($availableScripts.Count -gt 0) {
                $contextSections += @"

## Available Automation Scripts (Sample)
$($availableScripts -join "`n`n")

*Use ``az <number>`` to run any script, or ``seq <pattern>`` for sequences*
"@
            }
            
            Pop-Location
        } catch {
            # Ignore automation script discovery errors
        }
    }
    
    # Available orchestration playbooks
    if ($env:CLAUDE_PROJECT_DIR -and (Test-Path "$env:CLAUDE_PROJECT_DIR/orchestration/playbooks")) {
        try {
            $playbooks = Get-ChildItem "$env:CLAUDE_PROJECT_DIR/orchestration/playbooks" -Filter "*.json" | 
                        Select-Object -First 10
            
            if ($playbooks.Count -gt 0) {
                $playbookList = $playbooks | ForEach-Object {
                    $name = $_.BaseName
                    try {
                        $content = Get-Content $_.FullName -Raw | ConvertFrom-Json
                        "  - ``$name`` - $($content.Description ?? 'No description')"
                    } catch {
                        "  - ``$name`` - Playbook configuration"
                    }
                }
                
                $contextSections += @"

## Available Orchestration Playbooks
$($playbookList -join "`n")

*Use ``./Start-AitherZero.ps1 -Mode Orchestrate -Playbook <name>`` to run*
"@
            }
        } catch {
            # Ignore playbook discovery errors
        }
    }
    
    # Development tips based on current context
    $tips = @()
    
    if (-not $env:AITHERZERO_INITIALIZED) {
        $tips += "🚀 **Get Started:** Run ``Initialize-AitherModules.ps1`` to set up the environment"
    }
    
    if ($env:CLAUDE_PROJECT_DIR) {
        $tips += "📊 **Project Dashboard:** Use ``az 0511`` for real-time project status"
        $tips += "🧪 **Quick Test:** Use ``az 0402`` for unit tests or ``seq test-quick`` for full validation"
        $tips += "🔍 **Code Quality:** Use ``az 0404`` for PSScriptAnalyzer or ``az 0407`` for syntax validation"
        $tips += "📈 **Tech Debt:** Use ``seq 0520-0524`` for comprehensive analysis"
    }
    
    if ($tips.Count -gt 0) {
        $contextSections += @"

## Quick Tips
$($tips -join "`n")
"@
    }
    
    # Add current development focus (if any active todos)
    if ($env:CLAUDE_PROJECT_DIR) {
        try {
            # This would check for active todos or in-progress work
            # For now, we'll provide general development guidance
            $contextSections += @"

## Development Best Practices
- ✅ **Test First:** Run validation before making changes (``az 0404``, ``az 0407``)
- 📝 **Document Changes:** Update documentation for public functions
- 🔄 **Use Orchestration:** Prefer ``seq`` commands for multi-step operations
- 🛡️ **Security:** Regular security scans with ``az 0523``
- 📊 **Monitor:** Use ``az 0511`` for real-time project health

## AI Development Assistance
This project includes Claude Code hooks that provide context-aware assistance:
- **Pre/Post-tool hooks** for validation and automation
- **Intelligent suggestions** based on your current task
- **Project-aware context** for better AI assistance
- **Automated follow-up actions** for common development workflows
"@
        } catch {
            # Ignore if we can't read project state
        }
    }
    
    # Generate the response
    $fullContext = $contextSections -join "`n"
    
    $response = @{
        action = "add_context" 
        context = $fullContext
    } | ConvertTo-Json -Compress
    
    Write-Host $response
    Write-HookLog "Session context provided to Claude Code"
    
    # Optional: Auto-initialize environment if not initialized
    if ($env:CLAUDE_PROJECT_DIR -and -not $env:AITHERZERO_INITIALIZED) {
        if (Test-Path "$env:CLAUDE_PROJECT_DIR/Initialize-AitherModules.ps1") {
            Write-HookLog "Auto-initializing AitherZero environment"
            try {
                Push-Location $env:CLAUDE_PROJECT_DIR
                & ./Initialize-AitherModules.ps1 -Silent -CI | Out-Null
                Write-HookLog "Environment auto-initialization completed"
                Pop-Location
            } catch {
                Write-HookLog "Auto-initialization failed: $_" "ERROR"
                Pop-Location
            }
        }
    }
    
    exit 0
    
} catch {
    Write-Error "Session start hook execution failed: $_"
    # On error, don't block the session
    exit 0
}
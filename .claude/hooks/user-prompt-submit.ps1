#!/usr/bin/env pwsh
#requires -version 7

<#
.SYNOPSIS
    Claude Code User Prompt Submit Hook
.DESCRIPTION
    Executed when user submits a prompt. Analyzes intent and provides context.
.NOTES
    This hook receives JSON input via stdin and can add context or modify the prompt.
#>

param()

# Read JSON input from stdin
$input = @()
$inputStream = [Console]::In
while ($null -ne ($line = $inputStream.ReadLine())) {
    $input += $line
}

if ($input.Count -eq 0) {
    exit 0
}

try {
    $hookData = $input -join "`n" | ConvertFrom-Json
    
    # Initialize logging
    $logPath = "$env:CLAUDE_PROJECT_DIR/logs/claude-hooks.log"
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
    function Write-HookLog {
        param([string]$Message, [string]$Level = "INFO")
        $logEntry = "[$timestamp] [$Level] UserPromptSubmit: $Message"
        if ($env:CLAUDE_PROJECT_DIR -and (Test-Path (Split-Path $logPath -Parent))) {
            $logEntry | Add-Content -Path $logPath -Force
        }
        Write-Host $logEntry
    }
    
    # Get prompt information
    $userPrompt = $hookData.prompt ?? $hookData.user_message ?? ""
    $promptLower = $userPrompt.ToLower()
    
    Write-HookLog "User prompt received (length: $($userPrompt.Length))"
    
    # Analyze prompt intent and provide context
    $contextToAdd = @()
    $suggestions = @()
    
    # Development workflow patterns
    if ($promptLower -match '\b(create|add|implement|build)\b.*\b(feature|function|module|script)\b') {
        Write-HookLog "Development task detected: feature/function creation"
        $contextToAdd += @"
**AitherZero Development Context:**
- Use existing patterns from automation-scripts/ and domains/
- Follow PowerShell best practices and include comment-based help
- Consider adding tests in tests/ directory
- Update documentation if creating public functions
- Run validation: ``az 0404`` (PSScriptAnalyzer) and ``az 0407`` (syntax check)
"@
        
        $suggestions += "Consider using the development automation scripts (0700-0703 series) for Git workflow"
    }
    
    # Testing and validation
    if ($promptLower -match '\b(test|validate|check|analyze|lint)\b') {
        Write-HookLog "Testing/validation task detected"
        $contextToAdd += @"
**AitherZero Testing Context:**
Available test commands:
- ``az 0402`` - Run unit tests with coverage
- ``az 0403`` - Run integration tests  
- ``az 0404`` - Run PSScriptAnalyzer
- ``az 0407`` - Validate PowerShell syntax
- ``seq 0402-0406`` - Run comprehensive test suite

Test profiles available: quick, standard, full, ci
Use orchestration: ``./Start-AitherZero.ps1 -Mode Orchestrate -Playbook test-quick``
"@
    }
    
    # Infrastructure and deployment
    if ($promptLower -match '\b(deploy|infrastructure|terraform|opentofu|provision)\b') {
        Write-HookLog "Infrastructure task detected"
        $contextToAdd += @"
**AitherZero Infrastructure Context:**
- Infrastructure templates in infrastructure/ directory
- Use OpenTofu (not Terraform) as the preferred IaC tool
- Deployment scripts in 0300 series
- Consider using deployment playbooks: infrastructure-lab, hyperv-lab
- Environment-specific configurations in config.json
- Run ``az 0500`` to validate environment before deployment
"@
        
        $suggestions += "Use GitHub Actions deployment workflow for automated infrastructure management"
    }
    
    # CI/CD and automation
    if ($promptLower -match '\b(ci|cd|pipeline|github\s+actions|runner|workflow)\b') {
        Write-HookLog "CI/CD task detected"
        $contextToAdd += @"
**AitherZero CI/CD Context:**
- Self-hosted runner setup: scripts 0720-0723
- GitHub Actions workflows in .github/workflows/
- Use bootstrap system for runner environment setup
- Cross-platform support (Windows, Linux, macOS)
- Test orchestration with playbooks: test-quick, test-full, test-ci
- Build and release automation available
"@
        
        $suggestions += "Consider setting up self-hosted runners with ``az 0720`` for better performance"
    }
    
    # Configuration and setup
    if ($promptLower -match '\b(configure|setup|install|initialize|bootstrap)\b') {
        Write-HookLog "Setup/configuration task detected"
        $contextToAdd += @"
**AitherZero Setup Context:**
- Main initialization: ``Initialize-AitherModules.ps1`` or ``Initialize-AitherEnvironment.ps1``
- Cross-platform bootstrap: ``bootstrap.ps1`` (PowerShell) or ``bootstrap.sh`` (bash)
- Configuration in config.json with hierarchical settings
- Module discovery from domains/ directory
- Environment validation: ``az 0500``
"@
    }
    
    # Git and version control
    if ($promptLower -match '\b(git|commit|branch|pull\s+request|pr|merge)\b') {
        Write-HookLog "Git workflow task detected"
        $contextToAdd += @"
**AitherZero Git Workflow Context:**
Available Git automation:
- ``az 0700`` - Setup Git environment
- ``az 0701`` - Create feature branch
- ``az 0702`` - Create conventional commit
- ``az 0703`` - Create pull request

Git hooks and automation available for development workflow.
Consider using conventional commit format for better CI/CD integration.
"@
    }
    
    # Performance and optimization
    if ($promptLower -match '\b(performance|optimize|speed|slow|fast)\b') {
        Write-HookLog "Performance task detected"
        $contextToAdd += @"
**AitherZero Performance Context:**
- Performance monitoring built into module loading system
- Metrics available in logs/
- Performance budgets and regression detection
- Use ``az 0511`` for real-time project dashboard
- Parallel execution available with ThreadJob module
"@
    }
    
    # Security and compliance
    if ($promptLower -match '\b(security|secure|vulnerability|compliance|audit)\b') {
        Write-HookLog "Security task detected"
        $contextToAdd += @"
**AitherZero Security Context:**
- Security analysis: ``az 0523``
- Audit logging enabled with 90-day retention
- Credential management with SecureCredentials module
- Cross-platform security best practices
- Compliance mode available in configuration
"@
        
        $suggestions += "Use security-scanner agent for comprehensive vulnerability assessment"
    }
    
    # Documentation
    if ($promptLower -match '\b(document|documentation|readme|help|guide)\b') {
        Write-HookLog "Documentation task detected"
        $contextToAdd += @"
**AitherZero Documentation Context:**
- Main documentation in README.md and CLAUDE.md
- Module-specific documentation in domains/*/README.md
- Auto-generated docs: ``az 0521``
- Comment-based help for PowerShell functions
- Examples in examples/ directory
"@
    }
    
    # Add project status context
    if ($env:CLAUDE_PROJECT_DIR) {
        try {
            Push-Location $env:CLAUDE_PROJECT_DIR
            
            # Git status
            $gitStatus = git status --porcelain 2>$null
            if ($gitStatus) {
                $changedFiles = ($gitStatus | Measure-Object).Count
                $contextToAdd += "`n**Current Git Status:** $changedFiles uncommitted changes"
            }
            
            # Branch info
            $currentBranch = git rev-parse --abbrev-ref HEAD 2>$null
            if ($currentBranch) {
                $contextToAdd += "`n**Current Branch:** $currentBranch"
            }
            
            # Environment status
            if ($env:AITHERZERO_INITIALIZED) {
                $contextToAdd += "`n**AitherZero Environment:** Initialized ✅"
            } else {
                $contextToAdd += "`n**AitherZero Environment:** Not initialized - run ``Initialize-AitherModules.ps1``"
            }
            
            Pop-Location
        } catch {
            # Ignore git errors
        }
    }
    
    # Check for common issues and provide warnings
    if ($promptLower -match '\b(delete|remove|rm)\b.*\b(all|everything|\*)\b') {
        Write-HookLog "Potentially destructive operation detected" "WARN"
        $contextToAdd += @"

⚠️ **CAUTION:** This appears to be a potentially destructive operation.
Please ensure you have backups and understand the consequences.
Consider using ``-WhatIf`` or ``-DryRun`` parameters where available.
"@
    }
    
    # AI development assistance
    if ($promptLower -match '\b(ai|claude|gemini|codex|llm)\b') {
        Write-HookLog "AI development assistance detected"
        $contextToAdd += @"
**AitherZero AI Integration Context:**
- Claude Code hooks system configured
- AI development playbook available
- Multi-AI integration planned (Claude, Gemini, Codex)
- Development automation with AI assistance
- Code review, test generation, and documentation AI capabilities
"@
    }
    
    # Generate response
    if ($contextToAdd.Count -gt 0 -or $suggestions.Count -gt 0) {
        $fullContext = $contextToAdd -join "`n`n"
        
        if ($suggestions.Count -gt 0) {
            $fullContext += "`n`n**Suggestions:**`n" + ($suggestions | ForEach-Object { "- $_" }) -join "`n"
        }
        
        $response = @{
            action = "add_context"
            context = $fullContext
        } | ConvertTo-Json -Compress
        
        Write-Host $response
        Write-HookLog "Context added to user prompt"
        
    } else {
        Write-HookLog "No additional context needed"
    }
    
    exit 0
    
} catch {
    Write-Error "User prompt submit hook execution failed: $_"
    # On error, don't block the prompt
    exit 0
}
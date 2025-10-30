#Requires -Version 7.0
<#
.SYNOPSIS
    AitherZero Capabilities Discovery Module
.DESCRIPTION
    Helps users discover what AitherZero can accomplish and how to use its features.
    Provides interactive guidance, capability search, and task-to-script mapping.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Capability categories and their descriptions
$script:CapabilityCategories = @{
    Infrastructure = @{
        Description = 'Infrastructure automation, VM management, networking, and lab setup'
        Keywords = @('vm', 'hyper-v', 'network', 'certificate', 'infrastructure', 'lab', 'wsl', 'pxe')
        Scripts = @('0100', '0104', '0105', '0106', '0112')
        Examples = @(
            'Set up a Hyper-V lab environment'
            'Configure certificate authority'
            'Install and configure WSL2'
            'Enable PXE boot server'
        )
    }
    Development = @{
        Description = 'Development tools, version control, and coding environment setup'
        Keywords = @('git', 'node', 'python', 'docker', 'vscode', 'development', 'coding', 'ide')
        Scripts = @('0201', '0206', '0207', '0208', '0210', '0700-0709')
        Examples = @(
            'Install Node.js development environment'
            'Set up Git with automated workflows'
            'Configure VS Code for PowerShell development'
            'Install Docker for containerized development'
        )
    }
    Testing = @{
        Description = 'Automated testing, validation, and quality assurance'
        Keywords = @('test', 'pester', 'validation', 'coverage', 'quality', 'analyzer', 'syntax')
        Scripts = @('0402', '0403', '0404', '0407', '0409', '0411')
        Examples = @(
            'Run unit tests with Pester'
            'Perform code quality analysis'
            'Generate test coverage reports'
            'Validate PowerShell syntax'
        )
    }
    Reporting = @{
        Description = 'Analytics, reports, and system monitoring'
        Keywords = @('report', 'analytics', 'monitoring', 'dashboard', 'metrics', 'logs')
        Scripts = @('0510', '0511', '0520', '0522', '0530')
        Examples = @(
            'Generate project status report'
            'Analyze code quality metrics'
            'View system logs and diagnostics'
            'Create technical debt analysis'
        )
    }
    Automation = @{
        Description = 'Workflow orchestration, CI/CD, and process automation'
        Keywords = @('orchestration', 'workflow', 'automation', 'ci', 'cd', 'pipeline', 'playbook')
        Scripts = @('0700-0799')
        Examples = @(
            'Create automated Git workflows'
            'Set up CI/CD pipelines'
            'Run orchestrated playbooks'
            'Automate deployment processes'
        )
    }
    AITools = @{
        Description = 'AI-powered code review, generation, and assistance'
        Keywords = @('ai', 'claude', 'gemini', 'code review', 'generation', 'assistant')
        Scripts = @('0217', '0218', '0730-0742')
        Examples = @(
            'Perform AI-powered code review'
            'Generate code with AI assistance'
            'Use Claude Code for development'
            'Integrate AI into workflows'
        )
    }
}

function Show-AitherCapabilities {
    <#
    .SYNOPSIS
        Display AitherZero capabilities overview
    .DESCRIPTION
        Shows an interactive overview of what AitherZero can accomplish
    .PARAMETER Category
        Optionally filter by specific capability category
    .EXAMPLE
        Show-AitherCapabilities
        Show-AitherCapabilities -Category Development
    #>
    [CmdletBinding()]
    param(
        [ValidateSet('Infrastructure', 'Development', 'Testing', 'Reporting', 'Automation', 'AITools', 'All')]
        [string]$Category = 'All'
    )

    Write-Host "`n╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║    " -NoNewline -ForegroundColor Cyan
    Write-Host "AitherZero Capabilities Discovery" -NoNewline -ForegroundColor White
    Write-Host "                    ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

    if ($Category -eq 'All') {
        Write-Host "AitherZero is a comprehensive automation platform that helps you:" -ForegroundColor White
        Write-Host ""
        
        foreach ($cat in $script:CapabilityCategories.Keys | Sort-Object) {
            $info = $script:CapabilityCategories[$cat]
            Write-Host "  • " -NoNewline -ForegroundColor Green
            Write-Host "$cat`: " -NoNewline -ForegroundColor Cyan
            Write-Host $info.Description -ForegroundColor Gray
        }

        Write-Host "`n💡 Tip: Use " -NoNewline -ForegroundColor Yellow
        Write-Host "Show-AitherCapabilities -Category <name>" -NoNewline -ForegroundColor White
        Write-Host " for detailed info" -ForegroundColor Yellow
        Write-Host "💡 Tip: Use " -NoNewline -ForegroundColor Yellow
        Write-Host "Find-AitherCapability -Task 'your task'" -NoNewline -ForegroundColor White
        Write-Host " to find relevant scripts" -ForegroundColor Yellow
    }
    else {
        $info = $script:CapabilityCategories[$Category]
        if (-not $info) {
            Write-Warning "Category '$Category' not found"
            return
        }

        Write-Host "Category: " -NoNewline -ForegroundColor White
        Write-Host $Category -ForegroundColor Cyan
        Write-Host "Description: " -NoNewline -ForegroundColor White
        Write-Host $info.Description -ForegroundColor Gray
        Write-Host ""

        Write-Host "Common Tasks:" -ForegroundColor White
        foreach ($example in $info.Examples) {
            Write-Host "  • $example" -ForegroundColor Gray
        }
        Write-Host ""

        Write-Host "Related Scripts: " -NoNewline -ForegroundColor White
        Write-Host ($info.Scripts -join ', ') -ForegroundColor Cyan
        Write-Host ""

        Write-Host "Keywords: " -NoNewline -ForegroundColor White
        Write-Host ($info.Keywords -join ', ') -ForegroundColor DarkGray
    }

    Write-Host ""
}

function Find-AitherCapability {
    <#
    .SYNOPSIS
        Find AitherZero capabilities by task description
    .DESCRIPTION
        Searches capabilities and scripts based on what you want to accomplish
    .PARAMETER Task
        Description of what you want to accomplish
    .EXAMPLE
        Find-AitherCapability -Task "set up development environment"
        Find-AitherCapability -Task "run tests"
        Find-AitherCapability -Task "create reports"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Task
    )

    Write-Host "`n🔍 Searching for capabilities matching: " -NoNewline -ForegroundColor Cyan
    Write-Host "'$Task'" -ForegroundColor White
    Write-Host ""

    $taskLower = $Task.ToLower()
    $matches = @()

    # Search through categories
    foreach ($catName in $script:CapabilityCategories.Keys) {
        $category = $script:CapabilityCategories[$catName]
        $score = 0

        # Check if task matches keywords
        foreach ($keyword in $category.Keywords) {
            if ($taskLower -like "*$keyword*") {
                $score += 10
            }
        }

        # Check if task matches examples
        foreach ($example in $category.Examples) {
            if ($example.ToLower() -like "*$taskLower*" -or $taskLower -like "*$($example.ToLower())*") {
                $score += 20
            }
        }

        # Check if task matches description
        if ($category.Description.ToLower() -like "*$taskLower*") {
            $score += 5
        }

        if ($score -gt 0) {
            $matches += [PSCustomObject]@{
                Category = $catName
                Score = $score
                Description = $category.Description
                Scripts = $category.Scripts
                Examples = $category.Examples
            }
        }
    }

    if ($matches.Count -eq 0) {
        Write-Host "❌ No direct matches found. Try these suggestions:" -ForegroundColor Yellow
        Write-Host "  • Use broader keywords (e.g., 'test' instead of 'unit testing')" -ForegroundColor Gray
        Write-Host "  • Check available categories with: " -NoNewline -ForegroundColor Gray
        Write-Host "Show-AitherCapabilities" -ForegroundColor White
        Write-Host "  • Search scripts directly with: " -NoNewline -ForegroundColor Gray
        Write-Host "Start-AitherZero -Mode Search -Query 'your term'" -ForegroundColor White
        return
    }

    # Sort by relevance score
    $matches = $matches | Sort-Object -Property Score -Descending

    Write-Host "✅ Found $($matches.Count) relevant " -NoNewline -ForegroundColor Green
    Write-Host "capabilit$(if ($matches.Count -ne 1) { 'ies' } else { 'y' })" -NoNewline -ForegroundColor Green
    Write-Host " (sorted by relevance):`n" -ForegroundColor Green

    foreach ($match in $matches) {
        Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
        Write-Host "  Category: " -NoNewline -ForegroundColor White
        Write-Host $match.Category -ForegroundColor Cyan
        Write-Host "  Description: " -NoNewline -ForegroundColor White
        Write-Host $match.Description -ForegroundColor Gray
        Write-Host "  Relevant Scripts: " -NoNewline -ForegroundColor White
        Write-Host ($match.Scripts -join ', ') -ForegroundColor Yellow
        
        Write-Host "  Example Tasks:" -ForegroundColor White
        $relevantExamples = $match.Examples | Select-Object -First 3
        foreach ($example in $relevantExamples) {
            Write-Host "    • $example" -ForegroundColor Gray
        }
        Write-Host ""
    }

    Write-Host "💡 Next Steps:" -ForegroundColor Cyan
    Write-Host "  • Run a script with: " -NoNewline -ForegroundColor Gray
    Write-Host "az <script-number>" -ForegroundColor White
    Write-Host "  • List all scripts: " -NoNewline -ForegroundColor Gray
    Write-Host "Start-AitherZero -Mode List -Target scripts" -ForegroundColor White
    Write-Host "  • Get detailed help: " -NoNewline -ForegroundColor Gray
    Write-Host "Show-AitherCapabilities -Category <name>" -ForegroundColor White
    Write-Host ""
}

function Get-AitherQuickStart {
    <#
    .SYNOPSIS
        Show quick start guide for common tasks
    .DESCRIPTION
        Displays a quick reference for accomplishing common tasks in AitherZero
    .EXAMPLE
        Get-AitherQuickStart
    #>
    [CmdletBinding()]
    param()

    $quickStart = @"

╔════════════════════════════════════════════════════════════════╗
║           AitherZero Quick Start Guide                          ║
╚════════════════════════════════════════════════════════════════╝

📋 COMMON TASKS

  1. Set up development environment:
     az 0207  # Install Git
     az 0210  # Install VS Code
     az 0201  # Install Node.js
     az 0206  # Install Python

  2. Run tests and validation:
     az 0402  # Run unit tests
     az 0404  # Run PSScriptAnalyzer
     az 0409  # Run all tests

  3. Generate reports:
     az 0510  # Generate project report
     az 0522  # Analyze code quality
     az 0530  # View logs

  4. Infrastructure setup:
     az 0105  # Install Hyper-V
     az 0104  # Install Certificate Authority
     az 0106  # Install WSL2

  5. CI/CD and automation:
     Start-AitherZero -Mode Orchestrate -Playbook test-quick
     az 0700  # Git environment setup
     az 0599  # CI progress reporting

🔍 DISCOVERY COMMANDS

  • Find what you can do:        Show-AitherCapabilities
  • Search by task:               Find-AitherCapability -Task "your task"
  • List all scripts:             Start-AitherZero -Mode List -Target scripts
  • Search scripts:               Start-AitherZero -Mode Search -Query "keyword"

📚 LEARNING RESOURCES

  • Main README:                  README.md
  • Docker guide:                 DOCKER.md
  • Quality standards:            docs/QUALITY-STANDARDS.md
  • CI/CD guide:                  docs/CI-CD-GUIDE.md

💡 TIPS

  • Use 'az' as a shortcut for running numbered scripts
  • Interactive mode starts with:  Start-AitherZero (or 'aitherzero')
  • Get help for any command:      Get-Help <command-name> -Full
  • Check system status:           az 0500

"@

    Write-Host $quickStart -ForegroundColor White
}

function Show-AitherHowDoI {
    <#
    .SYNOPSIS
        Interactive "How do I..." assistant
    .DESCRIPTION
        Provides an interactive way to ask "how do I" questions and get guidance
    .EXAMPLE
        Show-AitherHowDoI
    #>
    [CmdletBinding()]
    param()

    Write-Host "`n╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║    " -NoNewline -ForegroundColor Cyan
    Write-Host "AitherZero 'How Do I...' Assistant" -NoNewline -ForegroundColor White
    Write-Host "                     ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

    $commonQuestions = @(
        @{ Question = "Set up my development environment?"; Answer = "Run these scripts: az 0207 (Git), az 0210 (VS Code), az 0201 (Node.js)" }
        @{ Question = "Run tests on my code?"; Answer = "Use: az 0402 (unit tests), az 0404 (linting), az 0409 (all tests)" }
        @{ Question = "Create a report?"; Answer = "Use: az 0510 (project report), az 0511 (scheduled reports), az 0522 (code quality)" }
        @{ Question = "Set up infrastructure?"; Answer = "Use: az 0105 (Hyper-V), az 0104 (Certificates), az 0100 (System config)" }
        @{ Question = "Automate Git workflows?"; Answer = "Use: az 0700 (Git setup), az 0701 (create branch), az 0702 (commit), az 0703 (create PR)" }
        @{ Question = "Install development tools?"; Answer = "Browse scripts 0200-0299 or use: Start-AitherZero -Mode List -Target scripts" }
        @{ Question = "Use AI assistance?"; Answer = "Install: az 0217 (Claude Code), az 0218 (Gemini CLI), then use scripts 0730-0742" }
        @{ Question = "Find a specific capability?"; Answer = "Use: Find-AitherCapability -Task 'describe what you want to do'" }
    )

    Write-Host "Common questions answered:`n" -ForegroundColor White

    for ($i = 0; $i -lt $commonQuestions.Count; $i++) {
        $q = $commonQuestions[$i]
        Write-Host "  $($i + 1). " -NoNewline -ForegroundColor Cyan
        Write-Host "How do I $($q.Question)" -ForegroundColor Yellow
        Write-Host "     → " -NoNewline -ForegroundColor Green
        Write-Host $q.Answer -ForegroundColor Gray
        Write-Host ""
    }

    Write-Host "💡 For custom questions, use: " -NoNewline -ForegroundColor Cyan
    Write-Host "Find-AitherCapability -Task 'your question'" -ForegroundColor White
    Write-Host ""
}

# Export functions
Export-ModuleMember -Function @(
    'Show-AitherCapabilities'
    'Find-AitherCapability'
    'Get-AitherQuickStart'
    'Show-AitherHowDoI'
)

#Requires -Version 7.0
<#
.SYNOPSIS
    Modern CLI helper module for enhanced command-line experience
.DESCRIPTION
    Provides rich help, command suggestions, aliases, and modern CLI features
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# CLI state and configuration
$script:CLIState = @{
    CommandHistory = @()
    LastCommand = $null
    Aliases = @{
        'test' = @{ Mode = 'Run'; Target = 'sequence'; Sequence = '0402,0404,0407' }
        'lint' = @{ Mode = 'Run'; Target = 'script'; ScriptNumber = '0404' }
        'validate' = @{ Mode = 'Run'; Target = 'script'; ScriptNumber = '0407' }
        'report' = @{ Mode = 'Run'; Target = 'script'; ScriptNumber = '0510' }
        'status' = @{ Mode = 'Run'; Target = 'script'; ScriptNumber = '0550' }
        'dashboard' = @{ Mode = 'Run'; Target = 'script'; ScriptNumber = '0550' }
        'deploy' = @{ Mode = 'Orchestrate'; Playbook = 'infrastructure-lab' }
        'quick-test' = @{ Mode = 'Orchestrate'; Playbook = 'test-quick' }
        'full-test' = @{ Mode = 'Orchestrate'; Playbook = 'test-full' }
    }
    Categories = @{
        '0000-0099' = @{ Name = 'Environment Setup'; Icon = '🔧'; Color = 'Cyan' }
        '0100-0199' = @{ Name = 'Infrastructure'; Icon = '🏗️'; Color = 'Blue' }
        '0200-0299' = @{ Name = 'Development Tools'; Icon = '💻'; Color = 'Green' }
        '0300-0399' = @{ Name = 'Deployment & IaC'; Icon = '🚀'; Color = 'Magenta' }
        '0400-0499' = @{ Name = 'Testing & Validation'; Icon = '✅'; Color = 'Yellow' }
        '0500-0599' = @{ Name = 'Reports & Metrics'; Icon = '📊'; Color = 'Cyan' }
        '0700-0799' = @{ Name = 'Git & Dev Automation'; Icon = '🔀'; Color = 'Blue' }
        '9000-9999' = @{ Name = 'Maintenance'; Icon = '🧹'; Color = 'Gray' }
    }
}

function Show-ModernHelp {
    <#
    .SYNOPSIS
        Display modern, comprehensive help with examples and tips
    #>
    [CmdletBinding()]
    param(
        [ValidateSet('full', 'quick', 'commands', 'examples', 'scripts')]
        [string]$HelpType = 'full'
    )

    Clear-Host
    
    # Header
    Write-Host ""
    Write-Host "╔═══════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║            " -NoNewline -ForegroundColor Cyan
    Write-Host "AitherZero - PowerShell Automation Platform" -NoNewline -ForegroundColor White
    Write-Host "             ║" -ForegroundColor Cyan
    Write-Host "║                    " -NoNewline -ForegroundColor Cyan
    Write-Host "Version 1.0.0.0" -NoNewline -ForegroundColor Yellow
    Write-Host "                         ║" -ForegroundColor Cyan
    Write-Host "╚═══════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""

    switch ($HelpType) {
        'quick' {
            Show-QuickHelp
        }
        'commands' {
            Show-CommandHelp
        }
        'examples' {
            Show-ExampleHelp
        }
        'scripts' {
            Show-ScriptCategories
        }
        default {
            Show-FullHelp
        }
    }

    # Footer
    Write-Host ""
    Write-Host "💡 " -NoNewline -ForegroundColor Yellow
    Write-Host "TIP: Use " -NoNewline -ForegroundColor Gray
    Write-Host "Tab" -NoNewline -ForegroundColor Cyan
    Write-Host " to auto-complete parameters and script numbers" -ForegroundColor Gray
    Write-Host ""
    Write-Host "📚 " -NoNewline -ForegroundColor Blue
    Write-Host "For detailed help: " -NoNewline -ForegroundColor Gray
    Write-Host "Get-Help .\Start-AitherZero.ps1 -Full" -ForegroundColor White
    Write-Host ""
}

function Show-QuickHelp {
    Write-Host "QUICK START:" -ForegroundColor Green
    Write-Host ""
    Write-Host "  🎯 Interactive Menu" -ForegroundColor Cyan
    Write-Host "     .\Start-AitherZero.ps1 -Mode Interactive" -ForegroundColor White
    Write-Host ""
    Write-Host "  🚀 Run a Script" -ForegroundColor Cyan
    Write-Host "     .\Start-AitherZero.ps1 -Mode Run -Target 0402" -ForegroundColor White
    Write-Host "     (Runs unit tests)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  📋 List Available Scripts" -ForegroundColor Cyan
    Write-Host "     .\Start-AitherZero.ps1 -Mode List -Target scripts" -ForegroundColor White
    Write-Host ""
    Write-Host "  🔍 Search Scripts" -ForegroundColor Cyan
    Write-Host "     .\Start-AitherZero.ps1 -Mode Search -Query test" -ForegroundColor White
    Write-Host ""
}

function Show-CommandHelp {
    Write-Host "AVAILABLE COMMANDS:" -ForegroundColor Green
    Write-Host ""
    
    $commands = @(
        @{ Name = 'Interactive'; Desc = 'Launch full-featured interactive menu'; Icon = '🎯' }
        @{ Name = 'Run'; Desc = 'Execute a specific script or playbook'; Icon = '🚀' }
        @{ Name = 'Orchestrate'; Desc = 'Run automation sequences and workflows'; Icon = '⚙️' }
        @{ Name = 'List'; Desc = 'Browse available scripts and resources'; Icon = '📋' }
        @{ Name = 'Search'; Desc = 'Find scripts by keyword'; Icon = '🔍' }
        @{ Name = 'Test'; Desc = 'Run test suites and validation'; Icon = '✅' }
        @{ Name = 'Validate'; Desc = 'Check environment and dependencies'; Icon = '🔎' }
    )

    foreach ($cmd in $commands) {
        Write-Host "  $($cmd.Icon) " -NoNewline -ForegroundColor Yellow
        Write-Host "$($cmd.Name)" -NoNewline -ForegroundColor Cyan
        Write-Host " - " -NoNewline -ForegroundColor Gray
        Write-Host $cmd.Desc -ForegroundColor White
    }
    Write-Host ""
}

function Show-ExampleHelp {
    Write-Host "COMMON EXAMPLES:" -ForegroundColor Green
    Write-Host ""

    $examples = @(
        @{
            Title = "Run unit tests"
            Command = ".\Start-AitherZero.ps1 -Mode Run -Target 0402"
            Category = "Testing"
        }
        @{
            Title = "Run PSScriptAnalyzer"
            Command = ".\Start-AitherZero.ps1 -Mode Run -Target 0404"
            Category = "Testing"
        }
        @{
            Title = "Generate project report"
            Command = ".\Start-AitherZero.ps1 -Mode Run -Target 0510 -ShowAll"
            Category = "Reporting"
        }
        @{
            Title = "View health dashboard"
            Command = ".\Start-AitherZero.ps1 -Mode Run -Target 0550"
            Category = "Reporting"
        }
        @{
            Title = "Run quick test playbook"
            Command = ".\Start-AitherZero.ps1 -Mode Orchestrate -Playbook test-quick"
            Category = "Workflows"
        }
        @{
            Title = "Run sequence of scripts"
            Command = ".\Start-AitherZero.ps1 -Mode Orchestrate -Sequence '0400-0499'"
            Category = "Workflows"
        }
        @{
            Title = "Create Git feature branch"
            Command = ".\Start-AitherZero.ps1 -Mode Run -Target 0701 -Type feature -Name 'my-feature'"
            Category = "Git Automation"
        }
        @{
            Title = "List all available scripts"
            Command = ".\Start-AitherZero.ps1 -Mode List -Target scripts"
            Category = "Discovery"
        }
    )

    $groupedExamples = $examples | Group-Object -Property Category

    foreach ($group in $groupedExamples) {
        Write-Host "  $($group.Name):" -ForegroundColor Cyan
        foreach ($example in $group.Group) {
            Write-Host "    • " -NoNewline -ForegroundColor Gray
            Write-Host $example.Title -ForegroundColor White
            Write-Host "      " -NoNewline
            Write-Host $example.Command -ForegroundColor Yellow
        }
        Write-Host ""
    }
}

function Show-ScriptCategories {
    Write-Host "SCRIPT CATEGORIES:" -ForegroundColor Green
    Write-Host ""

    $categories = @(
        @{ Range = '0000-0099'; Name = 'Environment Setup'; Desc = 'PowerShell 7, directories, validation tools' }
        @{ Range = '0100-0199'; Name = 'Infrastructure'; Desc = 'Hyper-V, WSL, certificates, networking' }
        @{ Range = '0200-0299'; Name = 'Development Tools'; Desc = 'Git, Node, Docker, VS Code, Python' }
        @{ Range = '0300-0399'; Name = 'Deployment & IaC'; Desc = 'OpenTofu, infrastructure automation' }
        @{ Range = '0400-0499'; Name = 'Testing & Validation'; Desc = 'Unit tests, integration tests, linting' }
        @{ Range = '0500-0599'; Name = 'Reports & Metrics'; Desc = 'Dashboards, analytics, project reports' }
        @{ Range = '0700-0799'; Name = 'Git Automation'; Desc = 'Branches, commits, PRs, AI coding tools' }
        @{ Range = '9000-9999'; Name = 'Maintenance'; Desc = 'Cleanup, system maintenance' }
    )

    foreach ($cat in $categories) {
        $icon = $script:CLIState.Categories[$cat.Range].Icon
        Write-Host "  $icon " -NoNewline
        Write-Host "$($cat.Range) " -NoNewline -ForegroundColor Cyan
        Write-Host "- " -NoNewline -ForegroundColor Gray
        Write-Host $cat.Name -NoNewline -ForegroundColor Yellow
        Write-Host ""
        Write-Host "     $($cat.Desc)" -ForegroundColor Gray
        Write-Host ""
    }
}

function Show-FullHelp {
    Show-QuickHelp
    Write-Host ""
    Show-CommandHelp
    Write-Host ""
    
    Write-Host "QUICK COMMAND SHORTCUTS:" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Instead of full syntax, you can use these common patterns:" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  .\Start-AitherZero.ps1 -Mode Run -Target <number>" -ForegroundColor White
    Write-Host "  Examples:" -ForegroundColor Gray
    Write-Host "    • -Mode Run -Target 0402    (Run unit tests)" -ForegroundColor Yellow
    Write-Host "    • -Mode Run -Target 0404    (Run PSScriptAnalyzer)" -ForegroundColor Yellow
    Write-Host "    • -Mode Run -Target 0510    (Generate report)" -ForegroundColor Yellow
    Write-Host ""
}

function Get-CommandSuggestion {
    <#
    .SYNOPSIS
        Suggest commands based on partial input or typos
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$InputText,
        
        [int]$MaxSuggestions = 5
    )

    # Internal helper for Levenshtein distance
    function Get-Distance {
        param([string]$s1, [string]$s2)
        
        $s1 = $s1.ToLower()
        $s2 = $s2.ToLower()
        
        $len1 = $s1.Length
        $len2 = $s2.Length
        
        if ($len1 -eq 0) { return $len2 }
        if ($len2 -eq 0) { return $len1 }
        
        $matrix = New-Object 'int[,]' ($len1 + 1), ($len2 + 1)
        
        for ($i = 0; $i -le $len1; $i++) { $matrix[$i, 0] = $i }
        for ($j = 0; $j -le $len2; $j++) { $matrix[0, $j] = $j }
        
        for ($i = 1; $i -le $len1; $i++) {
            for ($j = 1; $j -le $len2; $j++) {
                $cost = if ($s1[$i-1] -eq $s2[$j-1]) { 0 } else { 1 }
                $matrix[$i, $j] = [Math]::Min(
                    [Math]::Min($matrix[$i-1, $j] + 1, $matrix[$i, $j-1] + 1),
                    $matrix[$i-1, $j-1] + $cost
                )
            }
        }
        
        return $matrix[$len1, $len2]
    }

    $validCommands = @('Interactive', 'Run', 'Orchestrate', 'List', 'Search', 'Test', 'Validate', 'Deploy')
    $validTargets = @('script', 'playbook', 'sequence', 'scripts', 'playbooks')
    
    # Calculate Levenshtein distance for fuzzy matching
    $suggestions = [System.Collections.ArrayList]::new()
    
    foreach ($cmd in $validCommands) {
        $distance = Get-Distance -s1 $InputText -s2 $cmd
        if ($distance -le 2) {  # Max 2 character difference
            [void]$suggestions.Add([PSCustomObject]@{
                Command = $cmd
                Distance = $distance
                Type = 'Mode'
            })
        }
    }
    
    foreach ($target in $validTargets) {
        $distance = Get-Distance -s1 $InputText -s2 $target
        if ($distance -le 2) {
            [void]$suggestions.Add([PSCustomObject]@{
                Command = $target
                Distance = $distance
                Type = 'Target'
            })
        }
    }
    
    # Sort by distance and return top suggestions
    if ($suggestions.Count -gt 0) {
        return $suggestions | Sort-Object Distance | Select-Object -First $MaxSuggestions
    }
    
    return @()
}

function Get-LevenshteinDistance {
    <#
    .SYNOPSIS
        Calculate Levenshtein distance between two strings for fuzzy matching
    #>
    param(
        [string]$String1,
        [string]$String2
    )
    
    $s1 = $String1.ToLower()
    $s2 = $String2.ToLower()
    
    $len1 = $s1.Length
    $len2 = $s2.Length
    
    if ($len1 -eq 0) { return $len2 }
    if ($len2 -eq 0) { return $len1 }
    
    $matrix = New-Object 'int[,]' ($len1 + 1), ($len2 + 1)
    
    for ($i = 0; $i -le $len1; $i++) { $matrix[$i, 0] = $i }
    for ($j = 0; $j -le $len2; $j++) { $matrix[0, $j] = $j }
    
    for ($i = 1; $i -le $len1; $i++) {
        for ($j = 1; $j -le $len2; $j++) {
            $cost = if ($s1[$i-1] -eq $s2[$j-1]) { 0 } else { 1 }
            $matrix[$i, $j] = [Math]::Min(
                [Math]::Min($matrix[$i-1, $j] + 1, $matrix[$i, $j-1] + 1),
                $matrix[$i-1, $j-1] + $cost
            )
        }
    }
    
    return $matrix[$len1, $len2]
}

function Show-CommandCard {
    <#
    .SYNOPSIS
        Show a quick reference card for specific command type
    #>
    [CmdletBinding()]
    param(
        [ValidateSet('testing', 'deployment', 'git', 'reporting', 'all')]
        [string]$CardType = 'all'
    )

    Clear-Host
    Write-Host ""
    Write-Host "╔═══════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║                    Quick Reference Card                           ║" -ForegroundColor Cyan
    Write-Host "╚═══════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""

    switch ($CardType) {
        'testing' {
            Write-Host "TESTING COMMANDS:" -ForegroundColor Green
            Write-Host ""
            Write-Host "  0402 - Run unit tests" -ForegroundColor White
            Write-Host "  0404 - Run PSScriptAnalyzer (linting)" -ForegroundColor White
            Write-Host "  0407 - Validate PowerShell syntax" -ForegroundColor White
            Write-Host "  0408 - Run integration tests" -ForegroundColor White
            Write-Host ""
            Write-Host "  Quick: " -NoNewline -ForegroundColor Cyan
            Write-Host ".\Start-AitherZero.ps1 -Mode Orchestrate -Playbook test-quick" -ForegroundColor Yellow
            Write-Host ""
        }
        'deployment' {
            Write-Host "DEPLOYMENT COMMANDS:" -ForegroundColor Green
            Write-Host ""
            Write-Host "  0100-0199 - Infrastructure scripts" -ForegroundColor White
            Write-Host "  0300-0399 - Deployment & IaC" -ForegroundColor White
            Write-Host ""
            Write-Host "  Playbook: " -NoNewline -ForegroundColor Cyan
            Write-Host ".\Start-AitherZero.ps1 -Mode Orchestrate -Playbook infrastructure-lab" -ForegroundColor Yellow
            Write-Host ""
        }
        'git' {
            Write-Host "GIT AUTOMATION COMMANDS:" -ForegroundColor Green
            Write-Host ""
            Write-Host "  0701 - Create feature/fix/docs branch" -ForegroundColor White
            Write-Host "  0702 - Stage and commit changes" -ForegroundColor White
            Write-Host "  0703 - Create pull request" -ForegroundColor White
            Write-Host ""
        }
        'reporting' {
            Write-Host "REPORTING COMMANDS:" -ForegroundColor Green
            Write-Host ""
            Write-Host "  0510 - Generate project report" -ForegroundColor White
            Write-Host "  0550 - View health dashboard" -ForegroundColor White
            Write-Host ""
        }
        default {
            Show-CommandCard -CardType 'testing'
            Show-CommandCard -CardType 'git'
            Show-CommandCard -CardType 'reporting'
        }
    }
}

function Format-CLIOutput {
    <#
    .SYNOPSIS
        Format CLI output with consistent styling
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        
        [ValidateSet('Success', 'Error', 'Warning', 'Info', 'Accent', 'Muted')]
        [string]$Type = 'Info',
        
        [switch]$NoNewline
    )

    $colorMap = @{
        'Success' = 'Green'
        'Error' = 'Red'
        'Warning' = 'Yellow'
        'Info' = 'White'
        'Accent' = 'Cyan'
        'Muted' = 'Gray'
    }

    $params = @{
        Object = $Message
        ForegroundColor = $colorMap[$Type]
    }
    
    if ($NoNewline) {
        $params['NoNewline'] = $true
    }

    Write-Host @params
}

function Show-VersionInfo {
    <#
    .SYNOPSIS
        Display version information with system details
    #>
    [CmdletBinding()]
    param()

    $versionFile = Join-Path $PSScriptRoot "../../VERSION"
    $version = if (Test-Path $versionFile) {
        Get-Content $versionFile -Raw | ForEach-Object { $_.Trim() }
    } else {
        "1.0.0.0"
    }

    Clear-Host
    Write-Host ""
    Write-Host "╔═══════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║                        AitherZero                                 ║" -ForegroundColor Cyan
    Write-Host "║              PowerShell Automation Platform                       ║" -ForegroundColor Cyan
    Write-Host "╚═══════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Version:           " -NoNewline -ForegroundColor Gray
    Write-Host $version -ForegroundColor Yellow
    Write-Host "  PowerShell:        " -NoNewline -ForegroundColor Gray
    Write-Host "$($PSVersionTable.PSVersion)" -ForegroundColor White
    Write-Host "  Platform:          " -NoNewline -ForegroundColor Gray
    Write-Host "$($PSVersionTable.Platform)" -ForegroundColor White
    Write-Host "  OS:                " -NoNewline -ForegroundColor Gray
    Write-Host "$($PSVersionTable.OS)" -ForegroundColor White
    Write-Host ""
    Write-Host "  Repository:        " -NoNewline -ForegroundColor Gray
    Write-Host "https://github.com/wizzense/AitherZero" -ForegroundColor Cyan
    Write-Host "  Documentation:     " -NoNewline -ForegroundColor Gray
    Write-Host "https://wizzense.github.io/AitherZero" -ForegroundColor Cyan
    Write-Host ""
}

function Show-CLICommand {
    <#
    .SYNOPSIS
        Display the CLI command equivalent for an interactive action
    .DESCRIPTION
        Shows a formatted command bar that teaches users the CLI equivalent
        of what they're doing interactively, similar to AD Admin Center
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Command,
        
        [string]$Description,
        
        [switch]$Compact,
        
        [switch]$CopyToClipboard
    )

    if ($Compact) {
        # Compact mode - single line at bottom of screen
        Write-Host ""
        Write-Host "  💡 CLI: " -NoNewline -ForegroundColor DarkGray
        Write-Host $Command -ForegroundColor Cyan
    } else {
        # Full mode - prominent display
        Write-Host ""
        Write-Host "╔═══════════════════════════════════════════════════════════════════╗" -ForegroundColor DarkCyan
        Write-Host "║ " -NoNewline -ForegroundColor DarkCyan
        Write-Host "💡 CLI Command Equivalent" -NoNewline -ForegroundColor Yellow
        Write-Host (" " * (62 - "💡 CLI Command Equivalent".Length)) -NoNewline
        Write-Host " ║" -ForegroundColor DarkCyan
        
        if ($Description) {
            Write-Host "║ " -NoNewline -ForegroundColor DarkCyan
            Write-Host $Description -NoNewline -ForegroundColor Gray
            Write-Host (" " * (66 - $Description.Length)) -NoNewline
            Write-Host "║" -ForegroundColor DarkCyan
            Write-Host "╠═══════════════════════════════════════════════════════════════════╣" -ForegroundColor DarkCyan
        }
        
        Write-Host "║ " -NoNewline -ForegroundColor DarkCyan
        Write-Host $Command -NoNewline -ForegroundColor Cyan
        
        # Calculate padding
        $padding = 66 - $Command.Length
        if ($padding -gt 0) {
            Write-Host (" " * $padding) -NoNewline
        }
        Write-Host "║" -ForegroundColor DarkCyan
        Write-Host "╚═══════════════════════════════════════════════════════════════════╝" -ForegroundColor DarkCyan
    }
    
    # Copy to clipboard if requested (cross-platform)
    if ($CopyToClipboard) {
        try {
            if ($IsWindows) {
                $Command | Set-Clipboard
            } elseif ($IsMacOS) {
                $Command | pbcopy
            } elseif ($IsLinux) {
                if (Get-Command xclip -ErrorAction SilentlyContinue) {
                    $Command | xclip -selection clipboard
                }
            }
            Write-Host "  ✓ Copied to clipboard" -ForegroundColor Green
        } catch {
            # Silently ignore clipboard errors
        }
    }
    
    Write-Host ""
}

function Show-ExecutionBar {
    <#
    .SYNOPSIS
        Show a persistent bar at the top showing current execution
    .DESCRIPTION
        Creates a status bar similar to IDE debuggers showing what's running
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Action,
        
        [string]$Command,
        
        [ValidateSet('Running', 'Success', 'Error', 'Info')]
        [string]$Status = 'Running'
    )

    $statusIcon = @{
        'Running' = '⚙️'
        'Success' = '✅'
        'Error' = '❌'
        'Info' = 'ℹ️'
    }[$Status]
    
    $statusColor = @{
        'Running' = 'Yellow'
        'Success' = 'Green'
        'Error' = 'Red'
        'Info' = 'Cyan'
    }[$Status]

    # Save cursor position
    Write-Host "`n" -NoNewline
    
    # Draw bar
    Write-Host "┌─────────────────────────────────────────────────────────────────────┐" -ForegroundColor DarkGray
    Write-Host "│ " -NoNewline -ForegroundColor DarkGray
    Write-Host "$statusIcon $Action" -NoNewline -ForegroundColor $statusColor
    Write-Host (" " * (68 - $Action.Length - 3)) -NoNewline
    Write-Host "│" -ForegroundColor DarkGray
    
    if ($Command) {
        Write-Host "│ " -NoNewline -ForegroundColor DarkGray
        Write-Host "CLI: " -NoNewline -ForegroundColor DarkGray
        Write-Host $Command -NoNewline -ForegroundColor Cyan
        $padding = 63 - $Command.Length
        if ($padding -gt 0) {
            Write-Host (" " * $padding) -NoNewline
        }
        Write-Host "│" -ForegroundColor DarkGray
    }
    
    Write-Host "└─────────────────────────────────────────────────────────────────────┘" -ForegroundColor DarkGray
    Write-Host ""
}

function Get-CLIEquivalent {
    <#
    .SYNOPSIS
        Generate the CLI command equivalent for menu actions
    .DESCRIPTION
        Translates interactive menu selections into their CLI equivalents
    #>
    [CmdletBinding()]
    param(
        [string]$Sequence,
        [string]$Playbook,
        [string]$ScriptNumber,
        [hashtable]$Parameters = @{}
    )

    $baseCommand = "./Start-AitherZero.ps1"
    
    if ($Sequence) {
        $cmd = "$baseCommand -Mode Orchestrate -Sequence '$Sequence'"
    } elseif ($Playbook) {
        $cmd = "$baseCommand -Mode Orchestrate -Playbook '$Playbook'"
    } elseif ($ScriptNumber) {
        $cmd = "$baseCommand -Mode Run -Target $ScriptNumber"
    } else {
        return $null
    }
    
    # Add additional parameters
    foreach ($param in $Parameters.GetEnumerator()) {
        if ($param.Value -is [bool] -or $param.Value -is [switch]) {
            if ($param.Value) {
                $cmd += " -$($param.Key)"
            }
        } else {
            $cmd += " -$($param.Key) '$($param.Value)'"
        }
    }
    
    return $cmd
}

function Enable-CLILearningMode {
    <#
    .SYNOPSIS
        Enable CLI learning mode to show commands for all actions
    #>
    [CmdletBinding()]
    param()
    
    $global:AITHERZERO_CLI_LEARNING_MODE = $true
    $env:AITHERZERO_CLI_LEARNING_MODE = '1'
    
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Green
    Write-Host "  🎓 CLI Learning Mode Enabled!" -ForegroundColor Yellow
    Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Green
    Write-Host ""
    Write-Host "  You'll now see the CLI command for every action you take." -ForegroundColor White
    Write-Host "  This helps you learn how to use AitherZero from the command line!" -ForegroundColor White
    Write-Host ""
    Write-Host "  💡 Tip: Copy the commands to build your own automation scripts" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  To disable: " -NoNewline -ForegroundColor Gray
    Write-Host "Disable-CLILearningMode" -ForegroundColor Yellow
    Write-Host ""
}

function Disable-CLILearningMode {
    <#
    .SYNOPSIS
        Disable CLI learning mode
    #>
    [CmdletBinding()]
    param()
    
    $global:AITHERZERO_CLI_LEARNING_MODE = $false
    $env:AITHERZERO_CLI_LEARNING_MODE = '0'
    
    Write-Host ""
    Write-Host "  🎓 CLI Learning Mode Disabled" -ForegroundColor Yellow
    Write-Host ""
}

function Test-CLILearningMode {
    <#
    .SYNOPSIS
        Check if CLI learning mode is enabled
    #>
    [CmdletBinding()]
    param()
    
    return ($global:AITHERZERO_CLI_LEARNING_MODE -eq $true) -or 
           ($env:AITHERZERO_CLI_LEARNING_MODE -eq '1')
}

#region Quality of Life Features

# Feature 1: Smart Search - Fuzzy search across scripts and playbooks
function Search-AitherZeroResources {
    <#
    .SYNOPSIS
        Smart search across scripts, playbooks, and functions with fuzzy matching
    .DESCRIPTION
        Provides interactive search with preview and filtering capabilities
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Query,
        
        [ValidateSet('All', 'Scripts', 'Playbooks', 'Functions')]
        [string]$Type = 'All',
        
        [int]$MaxResults = 20,
        
        [switch]$ShowPreview
    )
    
    $results = @()
    $projectRoot = if ($env:AITHERZERO_ROOT) { $env:AITHERZERO_ROOT } else { Split-Path $PSScriptRoot -Parent | Split-Path -Parent }
    
    # Search scripts
    if ($Type -in @('All', 'Scripts')) {
        $scriptPath = Join-Path $projectRoot "automation-scripts"
        if (Test-Path $scriptPath) {
            Get-ChildItem -Path $scriptPath -Filter "*.ps1" | ForEach-Object {
                $fileName = $_.Name
                $number = if ($fileName -match '^\d{4}') { $matches[0] } else { $null }
                
                # Fuzzy match on name
                if ($fileName -match [regex]::Escape($Query) -or 
                    ($number -and $number -match $Query)) {
                    
                    # Extract description from file
                    $description = ""
                    try {
                        $content = Get-Content $_.FullName -TotalCount 20 -ErrorAction SilentlyContinue
                        $synopsisLine = $content | Where-Object { $_ -match '\.SYNOPSIS' }
                        if ($synopsisLine) {
                            $idx = [array]::IndexOf($content, $synopsisLine)
                            if ($idx -ge 0 -and $idx + 1 -lt $content.Count) {
                                $description = $content[$idx + 1].Trim()
                            }
                        }
                    } catch {}
                    
                    $results += [PSCustomObject]@{
                        Type = 'Script'
                        Number = $number
                        Name = $fileName
                        Description = $description
                        Path = $_.FullName
                        Score = if ($fileName -match "^$Query") { 100 } else { 50 }
                    }
                }
            }
        }
    }
    
    # Search playbooks
    if ($Type -in @('All', 'Playbooks')) {
        $playbookPath = Join-Path $projectRoot "orchestration/playbooks"
        if (Test-Path $playbookPath) {
            Get-ChildItem -Path $playbookPath -Filter "*.json" -Recurse | ForEach-Object {
                try {
                    $pbContent = Get-Content $_.FullName -Raw | ConvertFrom-Json -ErrorAction SilentlyContinue
                    $pbName = if ($pbContent.PSObject.Properties['Name']) { $pbContent.Name } 
                             elseif ($pbContent.PSObject.Properties['name']) { $pbContent.name } 
                             else { $_.BaseName }
                    $pbDesc = if ($pbContent.PSObject.Properties['Description']) { $pbContent.Description } 
                             elseif ($pbContent.PSObject.Properties['description']) { $pbContent.description } 
                             else { "" }
                    
                    if ($pbName -match [regex]::Escape($Query) -or $pbDesc -match [regex]::Escape($Query)) {
                        $results += [PSCustomObject]@{
                            Type = 'Playbook'
                            Number = $null
                            Name = $pbName
                            Description = $pbDesc
                            Path = $_.FullName
                            Score = if ($pbName -match "^$Query") { 100 } else { 50 }
                        }
                    }
                } catch {
                    # Skip invalid JSON files
                }
            }
        }
    }
    
    # Return top results
    $results | Sort-Object -Property Score, Name -Descending | Select-Object -First $MaxResults
}

# Feature 2: Recent Actions - Track and quick-access recent commands
function Get-RecentActions {
    <#
    .SYNOPSIS
        Get recently executed actions for quick re-run
    #>
    [CmdletBinding()]
    param(
        [int]$Count = 10
    )
    
    $historyFile = Join-Path $env:HOME ".aitherzero_history.json"
    
    if (Test-Path $historyFile) {
        try {
            $history = Get-Content $historyFile -Raw | ConvertFrom-Json
            return $history | Select-Object -Last $Count
        } catch {
            return @()
        }
    }
    
    return @()
}

function Add-RecentAction {
    <#
    .SYNOPSIS
        Add an action to recent history
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,
        
        [Parameter(Mandatory)]
        [string]$Command,
        
        [string]$Type,
        
        [string]$Status = 'Success'
    )
    
    $historyFile = Join-Path $env:HOME ".aitherzero_history.json"
    $maxHistory = 50
    
    $history = @()
    if (Test-Path $historyFile) {
        try {
            $history = Get-Content $historyFile -Raw | ConvertFrom-Json
        } catch {
            $history = @()
        }
    }
    
    $newEntry = [PSCustomObject]@{
        Timestamp = (Get-Date).ToString('o')
        Name = $Name
        Command = $Command
        Type = $Type
        Status = $Status
    }
    
    $history = @($history) + @($newEntry) | Select-Object -Last $maxHistory
    
    try {
        $history | ConvertTo-Json -Depth 10 | Set-Content $historyFile -ErrorAction SilentlyContinue
    } catch {
        # Silently ignore history save errors
    }
}

# Feature 3: Script Metadata - Get detailed information about scripts
function Get-ScriptMetadata {
    <#
    .SYNOPSIS
        Get detailed metadata about automation scripts
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ScriptNumber
    )
    
    $projectRoot = if ($env:AITHERZERO_ROOT) { $env:AITHERZERO_ROOT } else { Split-Path $PSScriptRoot -Parent | Split-Path -Parent }
    $scriptPath = Join-Path $projectRoot "automation-scripts"
    
    $scriptFile = Get-ChildItem -Path $scriptPath -Filter "${ScriptNumber}_*.ps1" | Select-Object -First 1
    
    if (-not $scriptFile) {
        return $null
    }
    
    $metadata = @{
        Number = $ScriptNumber
        Name = $scriptFile.Name
        Path = $scriptFile.FullName
        Size = $scriptFile.Length
        LastModified = $scriptFile.LastWriteTime
        Synopsis = ""
        Description = ""
        Parameters = @()
        Dependencies = @()
        EstimatedTime = "Unknown"
        RequiresAdmin = $false
        Category = ""
    }
    
    # Parse script content for metadata
    try {
        $content = Get-Content $scriptFile.FullName
        
        # Get help content
        $inHelp = $false
        $currentSection = ""
        foreach ($line in $content) {
            if ($line -match '<#') { $inHelp = $true }
            if ($line -match '#>') { $inHelp = $false }
            
            if ($inHelp) {
                if ($line -match '\.SYNOPSIS') { $currentSection = 'Synopsis' }
                elseif ($line -match '\.DESCRIPTION') { $currentSection = 'Description' }
                elseif ($line -match '\.PARAMETER') {
                    if ($line -match '\.PARAMETER\s+(\w+)') {
                        $metadata.Parameters += $matches[1]
                    }
                }
                elseif ($currentSection -and $line -notmatch '^\s*\.') {
                    $metadata[$currentSection] += $line.Trim() + " "
                }
            }
            
            # Check for requires admin
            if ($line -match '#Requires\s+-RunAsAdministrator') {
                $metadata.RequiresAdmin = $true
            }
        }
        
        # Determine category from number
        $num = [int]$ScriptNumber
        if ($num -lt 100) { $metadata.Category = "Environment Setup" }
        elseif ($num -lt 200) { $metadata.Category = "Infrastructure" }
        elseif ($num -lt 300) { $metadata.Category = "Development Tools" }
        elseif ($num -lt 400) { $metadata.Category = "Deployment & IaC" }
        elseif ($num -lt 500) { $metadata.Category = "Testing & Validation" }
        elseif ($num -lt 600) { $metadata.Category = "Reports & Metrics" }
        elseif ($num -lt 800) { $metadata.Category = "Git & Dev Automation" }
        else { $metadata.Category = "Maintenance" }
        
    } catch {
        # Return basic metadata if parsing fails
    }
    
    return [PSCustomObject]$metadata
}

# Feature 4: Quick Jump - Direct navigation to script by number
function Invoke-QuickJump {
    <#
    .SYNOPSIS
        Quick jump to and optionally execute a script by number
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ScriptNumber,
        
        [switch]$Execute,
        
        [switch]$ShowInfo
    )
    
    if ($ShowInfo) {
        $metadata = Get-ScriptMetadata -ScriptNumber $ScriptNumber
        if ($metadata) {
            Write-Host ""
            Write-Host "╔═══════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
            Write-Host "║ Script $ScriptNumber Information" -NoNewline -ForegroundColor Cyan
            Write-Host (" " * (55 - "Script $ScriptNumber Information".Length)) -NoNewline
            Write-Host "║" -ForegroundColor Cyan
            Write-Host "╚═══════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
            Write-Host ""
            Write-Host "  Name:        " -NoNewline -ForegroundColor Gray
            Write-Host $metadata.Name -ForegroundColor White
            Write-Host "  Category:    " -NoNewline -ForegroundColor Gray
            Write-Host $metadata.Category -ForegroundColor Cyan
            Write-Host "  Synopsis:    " -NoNewline -ForegroundColor Gray
            Write-Host $metadata.Synopsis.Trim() -ForegroundColor White
            
            if ($metadata.RequiresAdmin) {
                Write-Host "  ⚠️  Requires:  " -NoNewline -ForegroundColor Yellow
                Write-Host "Administrator privileges" -ForegroundColor Red
            }
            
            if ($metadata.Parameters.Count -gt 0) {
                Write-Host "  Parameters:  " -NoNewline -ForegroundColor Gray
                Write-Host ($metadata.Parameters -join ", ") -ForegroundColor White
            }
            
            Write-Host ""
            Write-Host "  CLI Command: " -NoNewline -ForegroundColor Gray
            Write-Host "./Start-AitherZero.ps1 -Mode Run -Target $ScriptNumber" -ForegroundColor Cyan
            Write-Host ""
            
            return $metadata
        } else {
            Write-Host "  ❌ Script $ScriptNumber not found" -ForegroundColor Red
            return $null
        }
    }
    
    if ($Execute) {
        $cliCommand = "./Start-AitherZero.ps1 -Mode Run -Target $ScriptNumber"
        Write-Host "  Executing: " -NoNewline -ForegroundColor Gray
        Write-Host $cliCommand -ForegroundColor Cyan
        
        # Track in history
        $metadata = Get-ScriptMetadata -ScriptNumber $ScriptNumber
        if ($metadata) {
            Add-RecentAction -Name $metadata.Name -Command $cliCommand -Type 'Script'
        }
        
        return $cliCommand
    }
}

# Feature 5: Inline Help - Context-sensitive help for menu items
function Show-InlineHelp {
    <#
    .SYNOPSIS
        Display inline help for menu items and commands
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Topic,
        
        [ValidateSet('Script', 'Playbook', 'Command', 'Menu')]
        [string]$Type = 'Menu'
    )
    
    Write-Host ""
    Write-Host "╔═══════════════════════════════════════════════════════════════════╗" -ForegroundColor Blue
    Write-Host "║ " -NoNewline -ForegroundColor Blue
    Write-Host "❓ Quick Help: $Topic" -NoNewline -ForegroundColor Yellow
    Write-Host (" " * (64 - "❓ Quick Help: $Topic".Length)) -NoNewline
    Write-Host "║" -ForegroundColor Blue
    Write-Host "╚═══════════════════════════════════════════════════════════════════╝" -ForegroundColor Blue
    Write-Host ""
    
    switch ($Type) {
        'Script' {
            $metadata = Get-ScriptMetadata -ScriptNumber $Topic
            if ($metadata) {
                Write-Host "  📝 " -NoNewline -ForegroundColor Cyan
                Write-Host $metadata.Synopsis.Trim() -ForegroundColor White
                Write-Host ""
                if ($metadata.Description) {
                    Write-Host "  " -NoNewline
                    Write-Host $metadata.Description.Trim().Substring(0, [Math]::Min(200, $metadata.Description.Length)) -ForegroundColor Gray
                    Write-Host ""
                }
                Write-Host "  Category: " -NoNewline -ForegroundColor Gray
                Write-Host $metadata.Category -ForegroundColor Cyan
                Write-Host "  CLI: " -NoNewline -ForegroundColor Gray
                Write-Host "./Start-AitherZero.ps1 -Mode Run -Target $Topic" -ForegroundColor Yellow
            }
        }
        
        'Playbook' {
            $projectRoot = if ($env:AITHERZERO_ROOT) { $env:AITHERZERO_ROOT } else { Split-Path $PSScriptRoot -Parent | Split-Path -Parent }
            $playbookPath = Join-Path $projectRoot "orchestration/playbooks"
            $playbookFile = Get-ChildItem -Path $playbookPath -Filter "*$Topic*.json" -Recurse | Select-Object -First 1
            
            if ($playbookFile) {
                $pb = Get-Content $playbookFile.FullName -Raw | ConvertFrom-Json
                Write-Host "  📋 " -NoNewline -ForegroundColor Cyan
                Write-Host ($pb.Description ?? $pb.description) -ForegroundColor White
                Write-Host ""
                Write-Host "  CLI: " -NoNewline -ForegroundColor Gray
                Write-Host "./Start-AitherZero.ps1 -Mode Orchestrate -Playbook '$Topic'" -ForegroundColor Yellow
            }
        }
        
        'Command' {
            # Show help for general commands
            $helpText = @{
                'Interactive' = "Launch the interactive menu system for guided workflows"
                'Orchestrate' = "Run automation sequences or playbooks non-interactively"
                'List' = "Browse available scripts, playbooks, and resources"
                'Search' = "Find scripts and playbooks by keyword"
                'Test' = "Run test suites and validation checks"
                'Run' = "Execute a specific script by number"
            }
            
            if ($helpText.ContainsKey($Topic)) {
                Write-Host "  💡 " -NoNewline -ForegroundColor Cyan
                Write-Host $helpText[$Topic] -ForegroundColor White
            }
        }
        
        'Menu' {
            # General menu help
            Write-Host "  💡 Navigation Tips:" -ForegroundColor Cyan
            Write-Host "     • Use arrow keys to navigate" -ForegroundColor Gray
            Write-Host "     • Press Enter to select" -ForegroundColor Gray
            Write-Host "     • Press 'L' to toggle CLI Learning Mode" -ForegroundColor Gray
            Write-Host "     • Press '?' for item-specific help" -ForegroundColor Gray
            Write-Host "     • Press 'H' for full help" -ForegroundColor Gray
            Write-Host "     • Press 'Q' to quit" -ForegroundColor Gray
        }
    }
    
    Write-Host ""
}

#endregion

# Export functions
Export-ModuleMember -Function @(
    'Show-ModernHelp'
    'Show-CommandCard'
    'Get-CommandSuggestion'
    'Format-CLIOutput'
    'Show-VersionInfo'
    'Show-CLICommand'
    'Show-ExecutionBar'
    'Get-CLIEquivalent'
    'Enable-CLILearningMode'
    'Disable-CLILearningMode'
    'Test-CLILearningMode'
    'Search-AitherZeroResources'
    'Get-RecentActions'
    'Add-RecentAction'
    'Get-ScriptMetadata'
    'Invoke-QuickJump'
    'Show-InlineHelp'
)

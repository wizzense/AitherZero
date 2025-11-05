#Requires -Version 7.0
<#
.SYNOPSIS
    Unified Interactive Menu System - Menu IS the CLI
.DESCRIPTION
    Interactive menu that mirrors the CLI structure exactly.
    Menu navigation builds CLI commands, teaching users the CLI naturally.
    
    Key Features:
    - Menu structure auto-generated from CLI parameters
    - Shows command being built as you navigate
    - Accept typed commands directly (-Mode Run -Target 0402)
    - Breadcrumb navigation showing current path
    - Arrow keys + command mode seamlessly integrated
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Import required modules
$script:ModuleRoot = Split-Path $PSScriptRoot -Parent
Import-Module (Join-Path $PSScriptRoot "BetterMenu.psm1") -Force -ErrorAction SilentlyContinue
Import-Module (Join-Path $PSScriptRoot "Components/BreadcrumbNavigation.psm1") -Force -ErrorAction SilentlyContinue
Import-Module (Join-Path $PSScriptRoot "Components/CommandParser.psm1") -Force -ErrorAction SilentlyContinue

# Module state
$script:UnifiedMenuState = @{
    BreadcrumbStack = $null
    Config = $null
    CurrentCommand = @{
        Mode = $null
        Parameters = @{}
    }
    CommandHistory = @()
    AvailableModes = @('Interactive', 'Orchestrate', 'Validate', 'Deploy', 'Test', 'List', 'Search', 'Run')
    ScriptCache = @{}
    PlaybookCache = @{}
}

<#
.SYNOPSIS
    Starts the unified interactive menu system
#>
function Start-UnifiedMenu {
    [CmdletBinding()]
    param(
        [Parameter()]
        [hashtable]$Config = @{},
        
        [string]$ProjectRoot = $PWD
    )
    
    # Initialize state
    $script:UnifiedMenuState.BreadcrumbStack = New-BreadcrumbStack
    $script:UnifiedMenuState.Config = $Config
    
    # Discover available scripts and playbooks
    Initialize-ResourceCache -ProjectRoot $ProjectRoot
    
    # Show welcome and start main menu
    Show-WelcomeBanner
    Show-ModeSelectionMenu
}

<#
.SYNOPSIS
    Shows the welcome banner
#>
function Show-WelcomeBanner {
    Clear-Host
    
    $banner = @"

    ╔══════════════════════════════════════════════════════════════╗
    ║              AitherZero - Unified CLI/Menu Interface         ║
    ║         Navigate with arrows OR type commands directly       ║
    ╚══════════════════════════════════════════════════════════════╝

    💡 Tip: Menu selections = CLI commands
    
    Example: Selecting "Run > Script 0402" = typing "-Mode Run -Target 0402"
    
"@
    
    Write-Host $banner -ForegroundColor Cyan
    Write-Host "    Press any key to continue..." -ForegroundColor DarkGray
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
}

<#
.SYNOPSIS
    Shows the mode selection menu (main menu)
#>
function Show-ModeSelectionMenu {
    $running = $true
    
    while ($running) {
        Clear-Host
        
        # Show breadcrumb
        Show-Breadcrumb -Stack $script:UnifiedMenuState.BreadcrumbStack -IncludeRoot -Color Cyan -CurrentColor Yellow
        Write-Host ""
        
        # Show current command being built
        Show-CurrentCommand
        Write-Host ""
        
        # Build mode menu items
        $items = @(
            [PSCustomObject]@{ Name = "🎯 Run - Execute scripts or sequences"; Mode = 'Run' }
            [PSCustomObject]@{ Name = "📚 Orchestrate - Run playbooks"; Mode = 'Orchestrate' }
            [PSCustomObject]@{ Name = "🔍 Search - Find scripts and resources"; Mode = 'Search' }
            [PSCustomObject]@{ Name = "📋 List - Show available resources"; Mode = 'List' }
            [PSCustomObject]@{ Name = "✅ Test - Run test suites"; Mode = 'Test' }
            [PSCustomObject]@{ Name = "🔧 Validate - Validation checks"; Mode = 'Validate' }
        )
        
        Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
        Write-Host "║                    Select Mode (-Mode)                     ║" -ForegroundColor Cyan
        Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  Type command: " -ForegroundColor DarkGray -NoNewline
        Write-Host "-Mode Run -Target 0402" -ForegroundColor Yellow -NoNewline
        Write-Host "  OR use ↑↓ arrows" -ForegroundColor DarkGray
        Write-Host ""
        
        $result = Show-BetterMenu -Title "AitherZero Modes" -Items $items -ShowNumbers -CustomActions @{
            'C' = 'Type Command Directly'
            'H' = 'Show Help'
            'Q' = 'Quit'
        }
        
        if (-not $result) {
            $running = $false
            continue
        }
        
        # Handle custom actions
        if ($result -is [hashtable] -and $result.Action) {
            switch ($result.Action) {
                'C' {
                    $command = Read-CommandInput
                    if ($command) {
                        $parsed = Parse-AitherCommand -CommandText $command
                        if ($parsed.IsValid) {
                            Execute-ParsedCommand -ParsedCommand $parsed
                        } else {
                            Write-Host "`n❌ Error: $($parsed.Error)" -ForegroundColor Red
                            Write-Host "Press any key to continue..." -ForegroundColor DarkGray
                            $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
                        }
                    }
                }
                'H' {
                    Show-CommandHelp
                }
                'Q' {
                    $running = $false
                }
            }
            continue
        }
        
        # User selected a mode
        $selectedMode = $result.Mode
        $script:UnifiedMenuState.CurrentCommand.Mode = $selectedMode
        
        # Push breadcrumb
        Push-Breadcrumb -Stack $script:UnifiedMenuState.BreadcrumbStack -Name $selectedMode
        
        # Show mode-specific menu
        switch ($selectedMode) {
            'Run' { Show-RunMenu }
            'Orchestrate' { Show-OrchestrateMenu }
            'Search' { Show-SearchMenu }
            'List' { Show-ListMenu }
            'Test' { Show-TestMenu }
            'Validate' { Show-ValidateMenu }
        }
        
        # Pop breadcrumb when returning
        Pop-Breadcrumb -Stack $script:UnifiedMenuState.BreadcrumbStack
        $script:UnifiedMenuState.CurrentCommand.Mode = $null
        $script:UnifiedMenuState.CurrentCommand.Parameters = @{}
    }
    
    Write-Host "`n✨ Goodbye!" -ForegroundColor Cyan
}

<#
.SYNOPSIS
    Shows current command being built
#>
function Show-CurrentCommand {
    $cmd = $script:UnifiedMenuState.CurrentCommand
    
    if (-not $cmd.Mode) {
        Write-Host "  Current Command: " -ForegroundColor DarkGray -NoNewline
        Write-Host "(none)" -ForegroundColor DarkGray
        return
    }
    
    # Build command string
    $cmdText = "-Mode $($cmd.Mode)"
    foreach ($key in $cmd.Parameters.Keys) {
        $value = $cmd.Parameters[$key]
        if ($value -match '\s') {
            $cmdText += " -$key `"$value`""
        } else {
            $cmdText += " -$key $value"
        }
    }
    
    Write-Host "  Current Command: " -ForegroundColor DarkGray -NoNewline
    Write-Host $cmdText -ForegroundColor Yellow
}

<#
.SYNOPSIS
    Shows Run mode menu - select Target
#>
function Show-RunMenu {
    $running = $true
    
    while ($running) {
        Clear-Host
        
        # Show breadcrumb
        Show-Breadcrumb -Stack $script:UnifiedMenuState.BreadcrumbStack -IncludeRoot -Color Cyan -CurrentColor Yellow
        Write-Host ""
        
        # Show current command
        Show-CurrentCommand
        Write-Host ""
        
        # Build menu from available scripts
        $categories = Get-ScriptCategories
        
        $items = @()
        foreach ($cat in $categories) {
            $items += [PSCustomObject]@{
                Name = "$($cat.Icon) $($cat.Name) - $($cat.Count) scripts"
                Category = $cat
            }
        }
        
        # Add direct script number entry
        $items += [PSCustomObject]@{
            Name = "🔢 Enter Script Number Directly"
            Category = $null
        }
        
        Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
        Write-Host "║                Select Target (-Target)                     ║" -ForegroundColor Cyan
        Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  Equivalent: " -ForegroundColor DarkGray -NoNewline
        Write-Host "-Mode Run -Target 0402" -ForegroundColor Yellow
        Write-Host ""
        
        $result = Show-BetterMenu -Title "Select Script Category" -Items $items -ShowNumbers -CustomActions @{
            'B' = 'Back'
            'Q' = 'Quit to Main Menu'
        }
        
        if (-not $result) {
            $running = $false
            continue
        }
        
        if ($result -is [hashtable]) {
            if ($result.Action -eq 'B') {
                $running = $false
            } elseif ($result.Action -eq 'Q') {
                $running = $false
                Clear-BreadcrumbStack -Stack $script:UnifiedMenuState.BreadcrumbStack
            }
            continue
        }
        
        if ($result.Category) {
            # Show scripts in category
            Push-Breadcrumb -Stack $script:UnifiedMenuState.BreadcrumbStack -Name $result.Category.Name
            Show-ScriptSelectionMenu -Category $result.Category
            Pop-Breadcrumb -Stack $script:UnifiedMenuState.BreadcrumbStack
        } else {
            # Direct script entry
            $scriptNum = Read-ScriptNumber
            if ($scriptNum) {
                $script:UnifiedMenuState.CurrentCommand.Parameters.Target = $scriptNum
                $command = Build-AitherCommand -Mode $script:UnifiedMenuState.CurrentCommand.Mode -Parameters $script:UnifiedMenuState.CurrentCommand.Parameters
                
                Write-Host "`n✅ Command built: " -ForegroundColor Green -NoNewline
                Write-Host $command -ForegroundColor Yellow
                Write-Host "`nExecute this command? (Y/N): " -ForegroundColor Cyan -NoNewline
                
                $confirm = Read-Host
                if ($confirm -eq 'Y' -or $confirm -eq 'y') {
                    # Execute the command
                    Write-Host "`n🚀 Executing: $command" -ForegroundColor Green
                    Start-Sleep -Seconds 2
                    # TODO: Actually execute the command
                }
                
                $script:UnifiedMenuState.CurrentCommand.Parameters.Remove('Target')
            }
        }
    }
}

<#
.SYNOPSIS
    Shows script selection menu for a category
#>
function Show-ScriptSelectionMenu {
    param($Category)
    
    $running = $true
    
    while ($running) {
        Clear-Host
        
        # Show breadcrumb
        Show-Breadcrumb -Stack $script:UnifiedMenuState.BreadcrumbStack -IncludeRoot -Color Cyan -CurrentColor Yellow
        Write-Host ""
        
        # Show current command
        Show-CurrentCommand
        Write-Host ""
        
        # Get scripts in range
        $scripts = Get-ScriptsInRange -Range $Category.Range
        
        if ($scripts.Count -eq 0) {
            Write-Host "  No scripts found in this category" -ForegroundColor Yellow
            Write-Host "`n  Press any key to go back..." -ForegroundColor DarkGray
            $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
            return
        }
        
        $items = $scripts | ForEach-Object {
            [PSCustomObject]@{
                Name = "[$($_.Number)] $($_.Name)"
                Script = $_
            }
        }
        
        Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
        Write-Host "║          $($Category.Name) Scripts                    " -ForegroundColor Cyan
        Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
        Write-Host ""
        
        $result = Show-BetterMenu -Title "$($Category.Icon) $($Category.Name)" -Items $items -ShowNumbers -CustomActions @{
            'B' = 'Back'
        }
        
        if (-not $result) {
            $running = $false
            continue
        }
        
        if ($result -is [hashtable] -and $result.Action -eq 'B') {
            $running = $false
            continue
        }
        
        # Script selected
        $scriptNum = $result.Script.Number
        $script:UnifiedMenuState.CurrentCommand.Parameters.Target = $scriptNum
        
        $command = Build-AitherCommand -Mode $script:UnifiedMenuState.CurrentCommand.Mode -Parameters $script:UnifiedMenuState.CurrentCommand.Parameters
        
        Write-Host "`n✅ Command built: " -ForegroundColor Green -NoNewline
        Write-Host $command -ForegroundColor Yellow
        Write-Host "`nExecute this command? (Y/N): " -ForegroundColor Cyan -NoNewline
        
        $confirm = Read-Host
        if ($confirm -eq 'Y' -or $confirm -eq 'y') {
            Write-Host "`n🚀 Executing: $command" -ForegroundColor Green
            Execute-Script -ScriptNumber $scriptNum
        }
        
        $script:UnifiedMenuState.CurrentCommand.Parameters.Remove('Target')
        $running = $false
    }
}

<#
.SYNOPSIS
    Execute a script
#>
function Execute-Script {
    param([string]$ScriptNumber)
    
    # Find script file
    $projectRoot = if ($env:AITHERZERO_ROOT) { $env:AITHERZERO_ROOT } else { $PWD }
    $scriptPath = Join-Path $projectRoot "automation-scripts"
    $scriptFile = Get-ChildItem -Path $scriptPath -Filter "$ScriptNumber`_*.ps1" -ErrorAction SilentlyContinue | Select-Object -First 1
    
    if (-not $scriptFile) {
        Write-Host "`n❌ Script not found: $ScriptNumber" -ForegroundColor Red
        Write-Host "`nPress any key to continue..." -ForegroundColor DarkGray
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
        return
    }
    
    Write-Host "`nExecuting: $($scriptFile.Name)" -ForegroundColor Cyan
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
    Write-Host ""
    
    try {
        & $scriptFile.FullName
        Write-Host ""
        Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
        Write-Host "✅ Script completed" -ForegroundColor Green
    } catch {
        Write-Host ""
        Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
        Write-Host "❌ Script failed: $_" -ForegroundColor Red
    }
    
    Write-Host "`nPress any key to continue..." -ForegroundColor DarkGray
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
}

<#
.SYNOPSIS
    Shows Orchestrate menu - select playbook
#>
function Show-OrchestrateMenu {
    Write-Host "`n📚 Orchestrate Mode - Coming soon!" -ForegroundColor Yellow
    Write-Host "This would show available playbooks" -ForegroundColor DarkGray
    Write-Host "`nPress any key to go back..." -ForegroundColor DarkGray
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
}

<#
.SYNOPSIS
    Shows Search menu
#>
function Show-SearchMenu {
    Write-Host "`n🔍 Search Mode - Coming soon!" -ForegroundColor Yellow
    Write-Host "This would allow searching scripts and resources" -ForegroundColor DarkGray
    Write-Host "`nPress any key to go back..." -ForegroundColor DarkGray
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
}

<#
.SYNOPSIS
    Shows List menu
#>
function Show-ListMenu {
    Write-Host "`n📋 List Mode - Coming soon!" -ForegroundColor Yellow
    Write-Host "This would list available resources" -ForegroundColor DarkGray
    Write-Host "`nPress any key to go back..." -ForegroundColor DarkGray
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
}

<#
.SYNOPSIS
    Shows Test menu
#>
function Show-TestMenu {
    Write-Host "`n✅ Test Mode - Coming soon!" -ForegroundColor Yellow
    Write-Host "This would show test suites" -ForegroundColor DarkGray
    Write-Host "`nPress any key to go back..." -ForegroundColor DarkGray
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
}

<#
.SYNOPSIS
    Shows Validate menu
#>
function Show-ValidateMenu {
    Write-Host "`n🔧 Validate Mode - Coming soon!" -ForegroundColor Yellow
    Write-Host "This would show validation checks" -ForegroundColor DarkGray
    Write-Host "`nPress any key to go back..." -ForegroundColor DarkGray
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
}

<#
.SYNOPSIS
    Helper functions for resource discovery
#>
function Initialize-ResourceCache {
    param([string]$ProjectRoot)
    
    # Discover scripts
    $scriptPath = Join-Path $ProjectRoot "automation-scripts"
    if (Test-Path $scriptPath) {
        $scripts = Get-ChildItem -Path $scriptPath -Filter "*.ps1" | ForEach-Object {
            if ($_.Name -match '^(\d{4})_(.+)\.ps1$') {
                $script:UnifiedMenuState.ScriptCache[$matches[1]] = @{
                    Number = $matches[1]
                    Name = $matches[2] -replace '_', ' '
                    FileName = $_.Name
                    FullPath = $_.FullName
                }
            }
        }
    }
}

function Get-ScriptCategories {
    return @(
        @{ Range = '0000-0099'; Name = 'Environment Setup'; Icon = '🔧'; Count = ($script:UnifiedMenuState.ScriptCache.Keys | Where-Object { [int]$_ -ge 0 -and [int]$_ -le 99 }).Count }
        @{ Range = '0100-0199'; Name = 'Infrastructure'; Icon = '🏗️'; Count = ($script:UnifiedMenuState.ScriptCache.Keys | Where-Object { [int]$_ -ge 100 -and [int]$_ -le 199 }).Count }
        @{ Range = '0200-0299'; Name = 'Development Tools'; Icon = '💻'; Count = ($script:UnifiedMenuState.ScriptCache.Keys | Where-Object { [int]$_ -ge 200 -and [int]$_ -le 299 }).Count }
        @{ Range = '0400-0499'; Name = 'Testing & Validation'; Icon = '✅'; Count = ($script:UnifiedMenuState.ScriptCache.Keys | Where-Object { [int]$_ -ge 400 -and [int]$_ -le 499 }).Count }
        @{ Range = '0500-0599'; Name = 'Reports & Metrics'; Icon = '📊'; Count = ($script:UnifiedMenuState.ScriptCache.Keys | Where-Object { [int]$_ -ge 500 -and [int]$_ -le 599 }).Count }
        @{ Range = '0700-0799'; Name = 'Git & Dev Automation'; Icon = '🔀'; Count = ($script:UnifiedMenuState.ScriptCache.Keys | Where-Object { [int]$_ -ge 700 -and [int]$_ -le 799 }).Count }
        @{ Range = '9000-9999'; Name = 'Maintenance'; Icon = '🧹'; Count = ($script:UnifiedMenuState.ScriptCache.Keys | Where-Object { [int]$_ -ge 9000 -and [int]$_ -le 9999 }).Count }
    ) | Where-Object { $_.Count -gt 0 }
}

function Get-ScriptsInRange {
    param([string]$Range)
    
    $parts = $Range -split '-'
    $min = [int]$parts[0]
    $max = [int]$parts[1]
    
    return $script:UnifiedMenuState.ScriptCache.Keys | 
        Where-Object { [int]$_ -ge $min -and [int]$_ -le $max } |
        Sort-Object { [int]$_ } |
        ForEach-Object { $script:UnifiedMenuState.ScriptCache[$_] }
}

function Read-ScriptNumber {
    Write-Host "`nEnter script number (e.g., 0402): " -ForegroundColor Cyan -NoNewline
    $num = Read-Host
    
    if ($num -match '^\d{4}$') {
        return $num
    }
    
    Write-Host "Invalid script number format" -ForegroundColor Red
    return $null
}

function Read-CommandInput {
    Write-Host "`n╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║                  Type Command Directly                     ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Example: -Mode Run -Target 0402" -ForegroundColor DarkGray
    Write-Host "  Example: -Mode Orchestrate -Playbook test-quick" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Command: " -ForegroundColor Cyan -NoNewline
    return Read-Host
}

function Execute-ParsedCommand {
    param([hashtable]$ParsedCommand)
    
    Write-Host "`n✅ Valid command: " -ForegroundColor Green -NoNewline
    Write-Host (Format-ParsedCommand -ParsedCommand $ParsedCommand) -ForegroundColor Yellow
    Write-Host "`nExecute? (Y/N): " -ForegroundColor Cyan -NoNewline
    
    $confirm = Read-Host
    if ($confirm -eq 'Y' -or $confirm -eq 'y') {
        Write-Host "`n🚀 Executing..." -ForegroundColor Green
        Start-Sleep -Seconds 2
        # TODO: Execute command
    }
}

function Show-CommandHelp {
    Clear-Host
    Write-Host "`n╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║                    Command Help                            ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Available Modes:" -ForegroundColor Yellow
    Write-Host "    -Mode Run         Run scripts or sequences" -ForegroundColor White
    Write-Host "    -Mode Orchestrate Run playbooks" -ForegroundColor White
    Write-Host "    -Mode Search      Search resources" -ForegroundColor White
    Write-Host "    -Mode List        List resources" -ForegroundColor White
    Write-Host "    -Mode Test        Run tests" -ForegroundColor White
    Write-Host "    -Mode Validate    Run validation" -ForegroundColor White
    Write-Host ""
    Write-Host "  Run Mode Parameters:" -ForegroundColor Yellow
    Write-Host "    -Target <number>  Script number (e.g., 0402)" -ForegroundColor White
    Write-Host ""
    Write-Host "  Orchestrate Mode Parameters:" -ForegroundColor Yellow
    Write-Host "    -Playbook <name>  Playbook name" -ForegroundColor White
    Write-Host ""
    Write-Host "  Examples:" -ForegroundColor Yellow
    Write-Host "    -Mode Run -Target 0402" -ForegroundColor Cyan
    Write-Host "    -Mode Orchestrate -Playbook test-quick" -ForegroundColor Cyan
    Write-Host "    -Mode Search -Query security" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Press any key to continue..." -ForegroundColor DarkGray
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
}

# Export functions
Export-ModuleMember -Function @(
    'Start-UnifiedMenu'
)

# Create alias for compatibility
New-Alias -Name 'Show-UnifiedMenu' -Value 'Start-UnifiedMenu' -Force
Export-ModuleMember -Alias 'Show-UnifiedMenu'


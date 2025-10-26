#Requires -Version 7.0
<#
.SYNOPSIS
    Modern CLI Interface for AitherZero - Smooth, Interactive, and Scriptable
.DESCRIPTION
    A completely redesigned CLI interface that provides:
    - Intuitive command patterns (az <action> <target> --options)
    - Smooth interactive navigation with fuzzy search
    - Full scriptability for CI/CD workflows
    - Consistent UX across all operations
    - Real-time feedback and progress
    - Zero-config setup
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Module state
$script:ModernCLIState = @{
    CurrentContext = 'main'
    History = @()
    Favorites = @()
    Settings = @{
        Theme = 'auto'  # auto, light, dark
        ShowHints = $true
        EnableFuzzySearch = $true
        AutoComplete = $true
        LogCommands = $true
    }
    Cache = @{}
}

# Core CLI Actions - matches modern CLI patterns
$script:CLIActions = @{
    'run' = @{
        Description = 'Execute scripts, playbooks, or sequences'
        Examples = @(
            'az run script 0402',
            'az run playbook tech-debt-analysis',
            'az run sequence 0400-0499'
        )
        Handler = 'Invoke-RunAction'
    }
    'list' = @{
        Description = 'List available resources'
        Examples = @(
            'az list scripts',
            'az list playbooks',
            'az list sequences'
        )
        Handler = 'Invoke-ListAction'
    }
    'show' = @{
        Description = 'Display detailed information'
        Examples = @(
            'az show script 0402',
            'az show playbook tech-debt-analysis',
            'az show config'
        )
        Handler = 'Invoke-ShowAction'
    }
    'config' = @{
        Description = 'Configure settings'
        Examples = @(
            'az config set theme dark',
            'az config get',
            'az config reset'
        )
        Handler = 'Invoke-ConfigAction'
    }
    'search' = @{
        Description = 'Find resources by name or description'
        Examples = @(
            'az search test',
            'az search security'
        )
        Handler = 'Invoke-SearchAction'
    }
    'menu' = @{
        Description = 'Interactive menu mode (legacy compatibility)'
        Examples = @('az menu')
        Handler = 'Invoke-MenuAction'
    }
}

function Initialize-ModernCLI {
    <#
    .SYNOPSIS
        Initialize the modern CLI system
    #>
    [CmdletBinding()]
    param()
    
    # Detect environment capabilities
    $script:ModernCLIState.Environment = @{
        IsInteractive = [Environment]::UserInteractive -and (-not $env:CI)
        SupportsColor = $Host.UI.SupportsVirtualTerminal -or $env:TERM_PROGRAM
        TerminalWidth = try { $Host.UI.RawUI.WindowSize.Width } catch { 80 }
        TerminalHeight = try { $Host.UI.RawUI.WindowSize.Height } catch { 24 }
    }
    
    # Auto-detect theme
    if ($script:ModernCLIState.Settings.Theme -eq 'auto') {
        $script:ModernCLIState.Settings.Theme = if ($env:AITHERZERO_THEME) { 
            $env:AITHERZERO_THEME 
        } elseif ($PSVersionTable.Platform -eq 'Unix') { 
            'dark' 
        } else { 
            'light' 
        }
    }
    
    Write-Verbose "Modern CLI initialized: Interactive=$($script:ModernCLIState.Environment.IsInteractive), Theme=$($script:ModernCLIState.Settings.Theme)"
}

function Write-CLIOutput {
    <#
    .SYNOPSIS
        Consistent output formatting for CLI
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        
        [ValidateSet('Info', 'Success', 'Warning', 'Error', 'Accent', 'Muted')]
        [string]$Type = 'Info',
        
        [string]$Icon = '',
        
        [switch]$NoNewline
    )
    
    # Color mapping based on theme
    $colors = if ($script:ModernCLIState.Settings.Theme -eq 'dark') {
        @{
            Info = 'White'
            Success = 'Green'  
            Warning = 'Yellow'
            Error = 'Red'
            Accent = 'Cyan'
            Muted = 'DarkGray'
        }
    } else {
        @{
            Info = 'Black'
            Success = 'DarkGreen'
            Warning = 'DarkYellow' 
            Error = 'DarkRed'
            Accent = 'DarkCyan'
            Muted = 'Gray'
        }
    }
    
    # Icons for different message types
    if (-not $Icon) {
        $Icon = switch ($Type) {
            'Success' { '✓' }
            'Warning' { '⚠' }
            'Error' { '✗' }
            'Accent' { '➤' }
            default { '' }
        }
    }
    
    $prefix = if ($Icon) { "$Icon " } else { '' }
    $output = "$prefix$Message"
    
    if ($script:ModernCLIState.Environment.SupportsColor) {
        Write-Host $output -ForegroundColor $colors[$Type] -NoNewline:$NoNewline
    } else {
        Write-Host $output -NoNewline:$NoNewline
    }
}

function Show-CLIHelp {
    <#
    .SYNOPSIS
        Display modern CLI help
    #>
    [CmdletBinding()]
    param(
        [string]$Action = $null
    )
    
    if ($Action -and $script:CLIActions.ContainsKey($Action)) {
        $actionInfo = $script:CLIActions[$Action]
        Write-CLIOutput "az $Action - $($actionInfo.Description)" -Type 'Accent'
        Write-CLIOutput ""
        Write-CLIOutput "Examples:" -Type 'Info'
        foreach ($example in $actionInfo.Examples) {
            Write-CLIOutput "  $example" -Type 'Muted'
        }
    } else {
        Write-CLIOutput "AitherZero Modern CLI" -Type 'Accent'
        Write-CLIOutput "Usage: az <action> <target> [options]" -Type 'Info'
        Write-CLIOutput ""
        
        Write-CLIOutput "Available Actions:" -Type 'Info'
        foreach ($actionKey in $script:CLIActions.Keys | Sort-Object) {
            $actionInfo = $script:CLIActions[$actionKey]
            Write-CLIOutput "  $actionKey" -Type 'Accent' -NoNewline
            Write-CLIOutput " - $($actionInfo.Description)" -Type 'Muted'
        }
        
        Write-CLIOutput ""
        Write-CLIOutput "Examples:" -Type 'Info'
        Write-CLIOutput "  az run script 0402                    # Run unit tests" -Type 'Muted'
        Write-CLIOutput "  az list playbooks                     # List all playbooks" -Type 'Muted'
        Write-CLIOutput "  az search security                    # Find security-related items" -Type 'Muted'
        Write-CLIOutput "  az show config                        # Show current configuration" -Type 'Muted'
        Write-CLIOutput "  az menu                               # Interactive menu mode" -Type 'Muted'
        Write-CLIOutput ""
        Write-CLIOutput "For action-specific help: az help <action>" -Type 'Info'
    }
}

function Invoke-FuzzySearch {
    <#
    .SYNOPSIS
        Fuzzy search implementation for interactive selection
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$Items,
        
        [string]$Prompt = "Search",
        
        [string]$PropertyName = 'Name'
    )
    
    if (-not $script:ModernCLIState.Environment.IsInteractive) {
        # Non-interactive fallback - return first item or prompt for selection
        if ($Items.Count -eq 1) {
            return $Items[0]
        }
        
        Write-CLIOutput "Multiple options available:" -Type 'Info'
        for ($i = 0; $i -lt $Items.Count; $i++) {
            $item = $Items[$i]
            $displayText = if ($item -is [string]) { $item } else { $item.$PropertyName }
            Write-CLIOutput "  [$($i + 1)] $displayText" -Type 'Muted'
        }
        
        do {
            Write-CLIOutput "$Prompt [1-$($Items.Count)]: " -Type 'Info' -NoNewline
            $selection = Read-Host
            
            if ($selection -match '^\d+$') {
                $index = [int]$selection - 1
                if ($index -ge 0 -and $index -lt $Items.Count) {
                    return $Items[$index]
                }
            }
            
            Write-CLIOutput "Invalid selection. Please enter a number between 1 and $($Items.Count)." -Type 'Warning'
        } while ($true)
    }
    
    # Interactive fuzzy search
    $filteredItems = $Items
    $searchTerm = ''
    $selectedIndex = 0
    
    while ($true) {
        Clear-Host
        
        Write-CLIOutput "$Prompt" -Type 'Accent'
        Write-CLIOutput "Type to search, ↑↓ to navigate, Enter to select, Esc to cancel" -Type 'Muted'
        Write-CLIOutput ""
        Write-CLIOutput "Search: $searchTerm" -Type 'Info' -NoNewline
        
        if ($searchTerm) {
            Write-CLIOutput "_" -Type 'Accent'
        } else {
            Write-CLIOutput ""
        }
        Write-CLIOutput ""
        
        # Show filtered results
        $maxDisplay = [Math]::Min(10, $script:ModernCLIState.Environment.TerminalHeight - 8)
        $startIndex = [Math]::Max(0, $selectedIndex - $maxDisplay + 1)
        $endIndex = [Math]::Min($filteredItems.Count - 1, $startIndex + $maxDisplay - 1)
        
        for ($i = $startIndex; $i -le $endIndex; $i++) {
            $item = $filteredItems[$i]
            $displayText = if ($item -is [string]) { $item } else { $item.$PropertyName }
            
            if ($i -eq $selectedIndex) {
                Write-CLIOutput "➤ $displayText" -Type 'Accent'
            } else {
                Write-CLIOutput "  $displayText" -Type 'Muted'
            }
        }
        
        if ($filteredItems.Count -eq 0) {
            Write-CLIOutput "  No matches found" -Type 'Warning'
        }
        
        # Get key input
        $key = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
        
        switch ($key.VirtualKeyCode) {
            13 { # Enter
                if ($filteredItems.Count -gt 0) {
                    return $filteredItems[$selectedIndex]
                }
            }
            27 { # Escape
                return $null
            }
            38 { # Up arrow
                if ($selectedIndex -gt 0) {
                    $selectedIndex--
                }
            }
            40 { # Down arrow
                if ($selectedIndex -lt $filteredItems.Count - 1) {
                    $selectedIndex++
                }
            }
            8 { # Backspace
                if ($searchTerm.Length -gt 0) {
                    $searchTerm = $searchTerm.Substring(0, $searchTerm.Length - 1)
                    
                    # Re-filter items
                    if ($searchTerm) {
                        $filteredItems = $Items | Where-Object {
                            $itemText = if ($_ -is [string]) { $_ } else { $_.$PropertyName }
                            $itemText -like "*$searchTerm*"
                        }
                    } else {
                        $filteredItems = $Items
                    }
                    
                    $selectedIndex = 0
                }
            }
            default {
                # Regular character input
                if ($key.Character -and [char]::IsLetterOrDigit($key.Character) -or $key.Character -eq ' ' -or $key.Character -eq '-' -or $key.Character -eq '_') {
                    $searchTerm += $key.Character
                    
                    # Filter items
                    $filteredItems = $Items | Where-Object {
                        $itemText = if ($_ -is [string]) { $_ } else { $_.$PropertyName }
                        $itemText -like "*$searchTerm*"
                    }
                    
                    $selectedIndex = 0
                }
            }
        }
    }
}

function Invoke-RunAction {
    <#
    .SYNOPSIS
        Handle 'run' actions
    #>
    [CmdletBinding()]
    param(
        [string]$Target,
        [string[]]$Arguments = @()
    )
    
    if (-not $Target) {
        Write-CLIOutput "Usage: az run <script|playbook|sequence> <name> [options]" -Type 'Info'
        Write-CLIOutput "Examples:" -Type 'Muted'
        Write-CLIOutput "  az run script 0402" -Type 'Muted'
        Write-CLIOutput "  az run playbook tech-debt-analysis" -Type 'Muted'
        Write-CLIOutput "  az run sequence 0400-0499" -Type 'Muted'
        return
    }
    
    switch ($Target.ToLower()) {
        'script' {
            if ($Arguments.Count -eq 0) {
                Write-CLIOutput "Script number required: az run script <number>" -Type 'Error'
                return
            }
            
            $scriptNumber = $Arguments[0]
            $scriptArgs = $Arguments[1..($Arguments.Count-1)]
            
            # Use the existing az.ps1 functionality
            $azPath = Join-Path $script:ProjectRoot "az.ps1"
            if (Test-Path $azPath) {
                Write-CLIOutput "Running script $scriptNumber..." -Type 'Info'
                & $azPath $scriptNumber @scriptArgs
            } else {
                Write-CLIOutput "Script runner not found: $azPath" -Type 'Error'
            }
        }
        'playbook' {
            if ($Arguments.Count -eq 0) {
                # Interactive playbook selection
                $playbookDir = Join-Path $script:ProjectRoot "orchestration/playbooks"
                $playbooks = Get-ChildItem $playbookDir -Filter "*.json" -Recurse | ForEach-Object {
                    try {
                        $pb = Get-Content $_.FullName | ConvertFrom-Json
                        $name = if ($pb.Name) { $pb.Name } else { $pb.name }
                        [PSCustomObject]@{
                            Name = $name
                            Description = if ($pb.Description) { $pb.Description } else { $pb.description }
                            Path = $_.FullName
                        }
                    } catch {
                        $null
                    }
                } | Where-Object { $_ }
                
                if ($playbooks.Count -eq 0) {
                    Write-CLIOutput "No playbooks found" -Type 'Warning'
                    return
                }
                
                $selected = Invoke-FuzzySearch -Items $playbooks -Prompt "Select playbook"
                if ($selected) {
                    Write-CLIOutput "Running playbook: $($selected.Name)" -Type 'Success'
                    # Execute playbook using existing orchestration
                    if (Get-Command Invoke-OrchestrationSequence -ErrorAction SilentlyContinue) {
                        Invoke-OrchestrationSequence -LoadPlaybook $selected.Name
                    } else {
                        Write-CLIOutput "Orchestration engine not available" -Type 'Error'
                    }
                }
            } else {
                $playbookName = $Arguments[0]
                Write-CLIOutput "Running playbook: $playbookName" -Type 'Info'
                if (Get-Command Invoke-OrchestrationSequence -ErrorAction SilentlyContinue) {
                    Invoke-OrchestrationSequence -LoadPlaybook $playbookName
                } else {
                    Write-CLIOutput "Orchestration engine not available" -Type 'Error'
                }
            }
        }
        'sequence' {
            if ($Arguments.Count -eq 0) {
                Write-CLIOutput "Sequence required: az run sequence <range>" -Type 'Error'
                return
            }
            
            $sequence = $Arguments[0]
            Write-CLIOutput "Running sequence: $sequence" -Type 'Info'
            if (Get-Command Invoke-OrchestrationSequence -ErrorAction SilentlyContinue) {
                Invoke-OrchestrationSequence -Sequence $sequence
            } else {
                Write-CLIOutput "Orchestration engine not available" -Type 'Error'
            }
        }
        default {
            Write-CLIOutput "Unknown target: $Target" -Type 'Error'
            Write-CLIOutput "Valid targets: script, playbook, sequence" -Type 'Info'
        }
    }
}

function Invoke-ListAction {
    <#
    .SYNOPSIS
        Handle 'list' actions
    #>
    [CmdletBinding()]
    param(
        [string]$Target = 'all'
    )
    
    switch ($Target.ToLower()) {
        'scripts' {
            $scriptsPath = Join-Path $script:ProjectRoot "automation-scripts"
            if (Test-Path $scriptsPath) {
                $scripts = Get-ChildItem $scriptsPath -Filter "*.ps1" | Sort-Object Name
                
                Write-CLIOutput "Available Scripts ($($scripts.Count)):" -Type 'Accent'
                Write-CLIOutput ""
                
                foreach ($script in $scripts) {
                    if ($script.Name -match '^(\d{4})_(.+)\.ps1$') {
                        $number = $matches[1]
                        $name = $matches[2].Replace('_', ' ').Replace('-', ' ')
                        Write-CLIOutput "  $number" -Type 'Accent' -NoNewline
                        Write-CLIOutput " - $name" -Type 'Info'
                    }
                }
            } else {
                Write-CLIOutput "Scripts directory not found: $scriptsPath" -Type 'Warning'
            }
        }
        'playbooks' {
            $playbookDir = Join-Path $script:ProjectRoot "orchestration/playbooks"
            if (Test-Path $playbookDir) {
                $playbooks = Get-ChildItem $playbookDir -Filter "*.json" -Recurse | ForEach-Object {
                    try {
                        $pb = Get-Content $_.FullName | ConvertFrom-Json
                        [PSCustomObject]@{
                            Name = if ($pb.Name) { $pb.Name } else { $pb.name }
                            Description = if ($pb.Description) { $pb.Description } else { $pb.description }
                            Category = $_.Directory.Name
                        }
                    } catch {
                        $null
                    }
                } | Where-Object { $_ } | Sort-Object Category, Name
                
                Write-CLIOutput "Available Playbooks ($($playbooks.Count)):" -Type 'Accent'
                Write-CLIOutput ""
                
                $currentCategory = ""
                foreach ($playbook in $playbooks) {
                    if ($playbook.Category -ne $currentCategory) {
                        if ($currentCategory) { Write-CLIOutput "" }
                        Write-CLIOutput "[$($playbook.Category.ToUpper())]" -Type 'Accent'
                        $currentCategory = $playbook.Category
                    }
                    Write-CLIOutput "  $($playbook.Name)" -Type 'Info' -NoNewline
                    if ($playbook.Description) {
                        Write-CLIOutput " - $($playbook.Description)" -Type 'Muted'
                    } else {
                        Write-CLIOutput ""
                    }
                }
            } else {
                Write-CLIOutput "Playbooks directory not found: $playbookDir" -Type 'Warning'
            }
        }
        'all' {
            Invoke-ListAction -Target 'scripts'
            Write-CLIOutput ""
            Invoke-ListAction -Target 'playbooks'
        }
        default {
            Write-CLIOutput "Unknown target: $Target" -Type 'Error'
            Write-CLIOutput "Valid targets: scripts, playbooks, all" -Type 'Info'
        }
    }
}

function Invoke-SearchAction {
    <#
    .SYNOPSIS
        Handle 'search' actions
    #>
    [CmdletBinding()]
    param(
        [string]$Query
    )
    
    if (-not $Query) {
        Write-CLIOutput "Search query required: az search <term>" -Type 'Error'
        return
    }
    
    Write-CLIOutput "Searching for: $Query" -Type 'Info'
    Write-CLIOutput ""
    
    # Search scripts
    $scriptsPath = Join-Path $script:ProjectRoot "automation-scripts"
    if (Test-Path $scriptsPath) {
        $matchingScripts = Get-ChildItem $scriptsPath -Filter "*.ps1" | Where-Object {
            $_.Name -like "*$Query*"
        } | Sort-Object Name
        
        if ($matchingScripts) {
            Write-CLIOutput "Scripts:" -Type 'Accent'
            foreach ($script in $matchingScripts) {
                if ($script.Name -match '^(\d{4})_(.+)\.ps1$') {
                    $number = $matches[1]
                    $name = $matches[2].Replace('_', ' ').Replace('-', ' ')
                    Write-CLIOutput "  $number - $name" -Type 'Info'
                }
            }
            Write-CLIOutput ""
        }
    }
    
    # Search playbooks
    $playbookDir = Join-Path $script:ProjectRoot "orchestration/playbooks"
    if (Test-Path $playbookDir) {
        $matchingPlaybooks = Get-ChildItem $playbookDir -Filter "*.json" -Recurse | ForEach-Object {
            try {
                $pb = Get-Content $_.FullName | ConvertFrom-Json
                $name = if ($pb.Name) { $pb.Name } else { $pb.name }
                $desc = if ($pb.Description) { $pb.Description } else { $pb.description }
                
                if ($name -like "*$Query*" -or $desc -like "*$Query*") {
                    [PSCustomObject]@{
                        Name = $name
                        Description = $desc
                        Category = $_.Directory.Name
                    }
                }
            } catch {
                $null
            }
        } | Where-Object { $_ }
        
        if ($matchingPlaybooks) {
            Write-CLIOutput "Playbooks:" -Type 'Accent'
            foreach ($playbook in $matchingPlaybooks) {
                Write-CLIOutput "  [$($playbook.Category)] $($playbook.Name)" -Type 'Info'
                if ($playbook.Description) {
                    Write-CLIOutput "    $($playbook.Description)" -Type 'Muted'
                }
            }
        }
    }
    
    if (-not $matchingScripts -and -not $matchingPlaybooks) {
        Write-CLIOutput "No results found for: $Query" -Type 'Warning'
    }
}

function Invoke-ConfigAction {
    <#
    .SYNOPSIS
        Handle 'config' actions
    #>
    [CmdletBinding()]
    param(
        [string]$SubAction,
        [string[]]$Arguments = @()
    )
    
    switch ($SubAction.ToLower()) {
        'get' {
            Write-CLIOutput "Current Configuration:" -Type 'Accent'
            Write-CLIOutput ""
            Write-CLIOutput "Theme: $($script:ModernCLIState.Settings.Theme)" -Type 'Info'
            Write-CLIOutput "Show Hints: $($script:ModernCLIState.Settings.ShowHints)" -Type 'Info'
            Write-CLIOutput "Fuzzy Search: $($script:ModernCLIState.Settings.EnableFuzzySearch)" -Type 'Info'
            Write-CLIOutput "Auto Complete: $($script:ModernCLIState.Settings.AutoComplete)" -Type 'Info'
            Write-CLIOutput "Log Commands: $($script:ModernCLIState.Settings.LogCommands)" -Type 'Info'
        }
        'set' {
            if ($Arguments.Count -lt 2) {
                Write-CLIOutput "Usage: az config set <key> <value>" -Type 'Error'
                return
            }
            
            $key = $Arguments[0]
            $value = $Arguments[1]
            
            switch ($key.ToLower()) {
                'theme' {
                    if ($value -in @('auto', 'light', 'dark')) {
                        $script:ModernCLIState.Settings.Theme = $value
                        Write-CLIOutput "Theme set to: $value" -Type 'Success'
                    } else {
                        Write-CLIOutput "Invalid theme. Valid options: auto, light, dark" -Type 'Error'
                    }
                }
                'hints' {
                    $script:ModernCLIState.Settings.ShowHints = $value -eq 'true'
                    Write-CLIOutput "Show hints set to: $($script:ModernCLIState.Settings.ShowHints)" -Type 'Success'
                }
                default {
                    Write-CLIOutput "Unknown configuration key: $key" -Type 'Error'
                }
            }
        }
        'reset' {
            $script:ModernCLIState.Settings = @{
                Theme = 'auto'
                ShowHints = $true
                EnableFuzzySearch = $true
                AutoComplete = $true
                LogCommands = $true
            }
            Write-CLIOutput "Configuration reset to defaults" -Type 'Success'
        }
        default {
            Write-CLIOutput "Usage: az config <get|set|reset> [options]" -Type 'Info'
        }
    }
}

function Invoke-MenuAction {
    <#
    .SYNOPSIS
        Legacy menu compatibility
    #>
    [CmdletBinding()]
    param()
    
    Write-CLIOutput "Starting legacy interactive menu..." -Type 'Info'
    
    # Import and call the original Start-AitherZero interactive mode
    $startScript = Join-Path $script:ProjectRoot "Start-AitherZero.ps1"
    if (Test-Path $startScript) {
        & $startScript -Mode Interactive
    } else {
        Write-CLIOutput "Legacy menu not available" -Type 'Error'
    }
}

function Invoke-ModernCLI {
    <#
    .SYNOPSIS
        Main entry point for the modern CLI
    #>
    [CmdletBinding()]
    param(
        [string[]]$Arguments = @()
    )
    
    # Initialize CLI
    Initialize-ModernCLI
    
    # Parse arguments
    if ($Arguments.Count -eq 0) {
        Show-CLIHelp
        return
    }
    
    $action = $Arguments[0].ToLower()
    $target = if ($Arguments.Count -gt 1) { $Arguments[1] } else { '' }
    $remainingArgs = if ($Arguments.Count -gt 2) { $Arguments[2..($Arguments.Count-1)] } else { @() }
    
    # Handle special cases
    if ($action -eq 'help') {
        Show-CLIHelp -Action $target
        return
    }
    
    if ($action -eq '--version' -or $action -eq '-v') {
        $version = if (Test-Path (Join-Path $script:ProjectRoot "VERSION")) {
            Get-Content (Join-Path $script:ProjectRoot "VERSION") -Raw
        } else {
            "unknown"
        }
        Write-CLIOutput "AitherZero CLI v$version" -Type 'Info'
        return
    }
    
    # Execute action
    if ($script:CLIActions.ContainsKey($action)) {
        $handler = $script:CLIActions[$action].Handler
        
        try {
            & $handler -Target $target -Arguments $remainingArgs
        } catch {
            Write-CLIOutput "Error executing $action`: $_" -Type 'Error'
            if ($VerbosePreference -eq 'Continue') {
                Write-CLIOutput $_.ScriptStackTrace -Type 'Muted'
            }
        }
    } else {
        Write-CLIOutput "Unknown action: $action" -Type 'Error'
        Write-CLIOutput "Use 'az help' to see available actions" -Type 'Info'
    }
}

# Initialize project root
$script:ProjectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent

# Export functions
Export-ModuleMember -Function @(
    'Initialize-ModernCLI'
    'Invoke-ModernCLI'
    'Show-CLIHelp'
    'Invoke-FuzzySearch'
)
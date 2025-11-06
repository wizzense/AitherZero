#Requires -Version 7.0
<#
.SYNOPSIS
    Modal UI Integration Layer - VIM-like enhancement for existing menus
.DESCRIPTION
    This module wraps existing menu systems (InteractiveUI, UnifiedMenu, BetterMenu)
    with VIM-like modal interaction while preserving all dynamic menu generation.
    
    Key Design Principles:
    - NON-BREAKING: Works as enhancement layer, not replacement
    - INTEGRATION: Uses existing menu generation (Build-MainMenuItems, Get-ManifestCapabilities)
    - PRESERVATION: All existing functionality remains accessible
    - ENHANCEMENT: Adds Normal/Command/Search modes on top
    
    The modal layer:
    - Takes dynamically generated menu items
    - Adds VIM-like navigation (h,j,k,l, g, G, etc.)
    - Adds Command mode (`:run 0402`)
    - Adds Search mode (`/pattern`)
    - Returns results back to existing menu handlers
    
.NOTES
    This is the glue that connects ModalUIEngine with existing UI systems.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Import required modules
$modulesToImport = @(
    (Join-Path $PSScriptRoot "ModalUIEngine.psm1")
    (Join-Path $PSScriptRoot "KeyBindingManager.psm1")
    (Join-Path $PSScriptRoot "Commands/ModalCommandParser.psm1")
    (Join-Path $PSScriptRoot "BetterMenu.psm1")
)

foreach ($modulePath in $modulesToImport) {
    if (Test-Path $modulePath) {
        Import-Module $modulePath -Force -ErrorAction SilentlyContinue
    }
}

<#
.SYNOPSIS
    Shows a menu with modal UI enhancements
.DESCRIPTION
    Wraps existing menu display with modal UI capabilities.
    Accepts dynamically generated items from Build-MainMenuItems, etc.
    
.PARAMETER Items
    Array of menu items (from existing menu generation functions)
    
.PARAMETER Title
    Menu title
    
.PARAMETER Context
    Context information (breadcrumb, current command, etc.)
    
.PARAMETER Config
    Configuration hashtable (UI settings, keybindings, etc.)
    
.OUTPUTS
    Selected item or action result (compatible with existing menu handlers)
#>
function Show-ModalMenu {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$Items,
        
        [Parameter(Mandatory)]
        [string]$Title,
        
        [hashtable]$Context = @{},
        
        [hashtable]$Config = @{}
    )
    
    # Initialize modal engine if not already done
    Initialize-ModalUIEngine -ErrorAction SilentlyContinue
    
    # Ensure we start in Normal mode
    Reset-ModalUIEngine
    
    $running = $true
    $selectedIndex = 0
    $displayItems = $Items  # Will be filtered in Search mode
    
    while ($running) {
        # Get current modal state
        $modalState = Get-ModalState
        $currentMode = $modalState.CurrentMode
        
        # Clear and redraw
        Clear-Host
        
        # Show title with mode indicator
        Show-ModalHeader -Title $Title -Mode $currentMode -Context $Context
        
        # Show items (filtered if in search mode)
        if ($currentMode -eq 'Search' -and $modalState.KeyBuffer) {
            $searchPattern = $modalState.KeyBuffer
            $displayItems = $Items | Where-Object {
                $_.Name -like "*$searchPattern*" -or
                $_.Description -like "*$searchPattern*" -or
                $_.Mode -like "*$searchPattern*"
            }
            Set-SearchResults -Results $displayItems
        } else {
            $displayItems = $Items
        }
        
        # Ensure selected index is in bounds
        if ($selectedIndex -ge $displayItems.Count) {
            $selectedIndex = [Math]::Max(0, $displayItems.Count - 1)
        }
        Set-SelectedIndex -Index $selectedIndex
        
        # Display menu items
        Show-ModalItems -Items $displayItems -SelectedIndex $selectedIndex -Mode $currentMode
        
        # Show mode-specific footer
        Show-ModalFooter -Mode $currentMode -KeyBuffer $modalState.KeyBuffer -SearchCount $displayItems.Count
        
        # Read key and process
        $key = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
        $keyName = ConvertTo-KeyName -KeyInfo $key
        
        # Handle based on current mode
        $result = switch ($currentMode) {
            'Normal' {
                Handle-NormalModeKey -Key $key -KeyName $keyName `
                    -Items $displayItems -SelectedIndex ([ref]$selectedIndex) `
                    -Context $Context
            }
            'Command' {
                Handle-CommandModeKey -Key $key -KeyName $keyName `
                    -Items $displayItems -Context $Context
            }
            'Search' {
                Handle-SearchModeKey -Key $key -KeyName $keyName `
                    -Items $displayItems -SelectedIndex ([ref]$selectedIndex)
            }
        }
        
        # Check if we should exit or return result
        if ($result) {
            if ($result.Action -eq 'Exit') {
                return $null
            } elseif ($result.Action -eq 'Select') {
                return $result.Item
            } elseif ($result.Action -eq 'Command') {
                return $result  # Return command result to caller
            }
        }
    }
}

<#
.SYNOPSIS
    Shows the modal menu header with title and mode indicator
#>
function Show-ModalHeader {
    [CmdletBinding()]
    param(
        [string]$Title,
        [string]$Mode,
        [hashtable]$Context
    )
    
    $width = 70
    $modeColors = @{
        'Normal' = 'Cyan'
        'Command' = 'Yellow'
        'Search' = 'Green'
    }
    $modeColor = $modeColors[$Mode]
    
    # Top border
    Write-Host ("┌" + ("─" * ($width - 2)) + "┐") -ForegroundColor Cyan
    
    # Title with mode indicator
    $titleLine = " $Title"
    $modeLine = "[$Mode MODE] "
    $padding = $width - $titleLine.Length - $modeLine.Length - 2
    $fullLine = "│$titleLine" + (" " * $padding) + $modeLine + "│"
    
    Write-Host $fullLine -ForegroundColor $modeColor
    
    # Context line (breadcrumb, current command, etc.)
    if ($Context.Breadcrumb) {
        $breadcrumbLine = " Path: $($Context.Breadcrumb)"
        $paddedLine = $breadcrumbLine.PadRight($width - 2)
        Write-Host "│$paddedLine│" -ForegroundColor DarkGray
    }
    
    # Separator
    Write-Host ("├" + ("─" * ($width - 2)) + "┤") -ForegroundColor Cyan
}

<#
.SYNOPSIS
    Shows menu items with selection highlight
#>
function Show-ModalItems {
    [CmdletBinding()]
    param(
        [array]$Items,
        [int]$SelectedIndex,
        [string]$Mode
    )
    
    if ($Items.Count -eq 0) {
        Write-Host "  No items to display" -ForegroundColor DarkGray
        Write-Host ""
        return
    }
    
    Write-Host ""
    
    for ($i = 0; $i -lt [Math]::Min($Items.Count, 20); $i++) {  # Show max 20 items
        $item = $Items[$i]
        $number = ($i + 1) % 10  # 1-9, 0 for 10
        
        # Selection indicator
        $indicator = if ($i -eq $SelectedIndex) { "►" } else { " " }
        
        # Item display
        $itemText = if ($item.Name) {
            $item.Name
        } elseif ($item.Description) {
            $item.Description
        } else {
            $item.ToString()
        }
        
        # Highlight selected
        if ($i -eq $SelectedIndex) {
            Write-Host "  $indicator [$number] $itemText" -ForegroundColor Yellow
        } else {
            Write-Host "  $indicator [$number] $itemText" -ForegroundColor White
        }
    }
    
    if ($Items.Count -gt 20) {
        Write-Host "  ... and $($Items.Count - 20) more items" -ForegroundColor DarkGray
    }
    
    Write-Host ""
}

<#
.SYNOPSIS
    Shows mode-specific footer with key hints
#>
function Show-ModalFooter {
    [CmdletBinding()]
    param(
        [string]$Mode,
        [string]$KeyBuffer,
        [int]$SearchCount
    )
    
    $width = 70
    
    # Separator
    Write-Host ("├" + ("─" * ($width - 2)) + "┤") -ForegroundColor Cyan
    
    # Mode-specific footer
    switch ($Mode) {
        'Normal' {
            $hint = " :cmd  /search  ?help  q=quit  r=run  Enter=select"
            Write-Host "│$($hint.PadRight($width - 2))│" -ForegroundColor DarkGray
        }
        'Command' {
            $cmdLine = " :$KeyBuffer"
            if ($cmdLine.Length -gt $width - 20) {
                $cmdLine = $cmdLine.Substring(0, $width - 23) + "..."
            }
            $hint = "Enter=execute  ESC=cancel"
            $padding = $width - $cmdLine.Length - $hint.Length - 2
            Write-Host "│$cmdLine$(' ' * $padding)$hint│" -ForegroundColor Yellow
        }
        'Search' {
            $searchLine = " /$KeyBuffer"
            if ($searchLine.Length -gt $width - 25) {
                $searchLine = $searchLine.Substring(0, $width - 28) + "..."
            }
            $hint = "Found: $SearchCount  ESC=clear"
            $padding = $width - $searchLine.Length - $hint.Length - 2
            Write-Host "│$searchLine$(' ' * $padding)$hint│" -ForegroundColor Green
        }
    }
    
    # Bottom border
    Write-Host ("└" + ("─" * ($width - 2)) + "┘") -ForegroundColor Cyan
}

<#
.SYNOPSIS
    Handles key press in Normal mode
#>
function Handle-NormalModeKey {
    [CmdletBinding()]
    param(
        $Key,
        [string]$KeyName,
        [array]$Items,
        [ref]$SelectedIndex,
        [hashtable]$Context
    )
    
    # Get binding for this key
    $binding = Get-KeyBinding -Mode 'Normal' -Key $KeyName
    
    if ($binding) {
        $action = $binding.Action
        
        switch ($action) {
            'Navigate-Up' {
                $SelectedIndex.Value = [Math]::Max(0, $SelectedIndex.Value - 1)
            }
            'Navigate-Down' {
                $SelectedIndex.Value = [Math]::Min($Items.Count - 1, $SelectedIndex.Value + 1)
            }
            'Go-ToTop' {
                $SelectedIndex.Value = 0
            }
            'Go-ToBottom' {
                $SelectedIndex.Value = $Items.Count - 1
            }
            'Page-Up' {
                $SelectedIndex.Value = [Math]::Max(0, $SelectedIndex.Value - 10)
            }
            'Page-Down' {
                $SelectedIndex.Value = [Math]::Min($Items.Count - 1, $SelectedIndex.Value + 10)
            }
            'Enter-CommandMode' {
                Enter-Mode -Mode 'Command'
            }
            'Enter-SearchMode' {
                Enter-Mode -Mode 'Search'
            }
            'Select-Item' {
                if ($Items.Count -gt 0) {
                    return @{ Action = 'Select'; Item = $Items[$SelectedIndex.Value] }
                }
            }
            'Quit-Menu' {
                return @{ Action = 'Exit' }
            }
            'Cancel' {
                return @{ Action = 'Exit' }
            }
            'Show-Help' {
                Show-ModalHelp
                Start-Sleep -Seconds 3
            }
            'Select-Number' {
                $num = $binding.Number
                if ($num -le $Items.Count) {
                    return @{ Action = 'Select'; Item = $Items[$num - 1] }
                }
            }
        }
    }
    
    return $null
}

<#
.SYNOPSIS
    Handles key press in Command mode
#>
function Handle-CommandModeKey {
    [CmdletBinding()]
    param(
        $Key,
        [string]$KeyName,
        [array]$Items,
        [hashtable]$Context
    )
    
    $binding = Get-KeyBinding -Mode 'Command' -Key $KeyName
    
    if ($binding) {
        switch ($binding.Action) {
            'Execute-Command' {
                $commandText = Get-KeyBuffer
                $parsed = Parse-ModalCommand -CommandText $commandText
                
                if ($parsed.IsValid) {
                    Add-ToCommandHistory -Command $commandText
                    Exit-Mode  # Return to Normal
                    return @{ Action = 'Command'; ParsedCommand = $parsed }
                } else {
                    # Show error briefly
                    Write-Host "`n❌ Error: $($parsed.Error)" -ForegroundColor Red
                    Start-Sleep -Milliseconds 1500
                }
            }
            'Cancel-Command' {
                Exit-Mode
            }
            'Backspace' {
                Remove-FromKeyBuffer
            }
            'History-Previous' {
                $cmd = Get-CommandFromHistory -Direction 'Up'
                Clear-KeyBuffer
                if ($cmd) { Add-ToKeyBuffer -Text $cmd }
            }
            'History-Next' {
                $cmd = Get-CommandFromHistory -Direction 'Down'
                Clear-KeyBuffer
                if ($cmd) { Add-ToKeyBuffer -Text $cmd }
            }
        }
    } else {
        # Regular character - add to buffer
        if ($Key.Character -match '[\w\s\-_]') {
            Add-ToKeyBuffer -Text $Key.Character.ToString()
        }
    }
    
    return $null
}

<#
.SYNOPSIS
    Handles key press in Search mode
#>
function Handle-SearchModeKey {
    [CmdletBinding()]
    param(
        $Key,
        [string]$KeyName,
        [array]$Items,
        [ref]$SelectedIndex
    )
    
    $binding = Get-KeyBinding -Mode 'Search' -Key $KeyName
    
    if ($binding) {
        switch ($binding.Action) {
            'Cancel-Search' {
                Clear-KeyBuffer
                Exit-Mode
            }
            'Backspace' {
                Remove-FromKeyBuffer
                $SelectedIndex.Value = 0  # Reset selection when search changes
            }
            'Navigate-Up' {
                $SelectedIndex.Value = [Math]::Max(0, $SelectedIndex.Value - 1)
            }
            'Navigate-Down' {
                $SelectedIndex.Value = [Math]::Min($Items.Count - 1, $SelectedIndex.Value + 1)
            }
            'Select-SearchResult' {
                if ($Items.Count -gt 0) {
                    Exit-Mode
                    return @{ Action = 'Select'; Item = $Items[$SelectedIndex.Value] }
                }
            }
        }
    } else {
        # Regular character - add to search buffer
        if ($Key.Character -match '[\w\s\-_]') {
            Add-ToKeyBuffer -Text $Key.Character.ToString()
            $SelectedIndex.Value = 0  # Reset to first result
        }
    }
    
    return $null
}

<#
.SYNOPSIS
    Shows modal UI help screen
#>
function Show-ModalHelp {
    Clear-Host
    
    Write-Host @"

╔══════════════════════════════════════════════════════════════╗
║                    MODAL UI HELP                            ║
╚══════════════════════════════════════════════════════════════╝

NORMAL MODE (Default)
  Navigation:
    ↑/k       Move up
    ↓/j       Move down
    g         Go to top
    G         Go to bottom
    1-9, 0    Quick select items
    Enter     Select item
    
  Mode Switching:
    :         Enter Command mode
    /         Enter Search mode
    ?         Show this help
    q, ESC    Quit/back

COMMAND MODE (: prefix)
  Commands:
    :run 0402              Run script
    :orchestrate test      Run playbook
    :search pattern        Search
    :quit                  Exit
    
  Shortcuts:
    :r 0402     (run)
    :o test     (orchestrate)
    :s pattern  (search)
    :q          (quit)
    
  Controls:
    Enter      Execute command
    ↑/↓        Command history
    ESC        Cancel

SEARCH MODE (/ prefix)
  Type to filter items in real-time
  ↑/↓        Navigate results
  Enter      Select result
  ESC        Clear search

"@ -ForegroundColor Cyan
    
    Write-Host "Press any key to return..." -ForegroundColor DarkGray
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
}

# Export module members
Export-ModuleMember -Function @(
    'Show-ModalMenu',
    'Show-ModalHeader',
    'Show-ModalItems',
    'Show-ModalFooter',
    'Show-ModalHelp'
)

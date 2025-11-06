# VIM-Like Interactive UI - Design & Implementation Plan

**Objective:** Transform AitherZero interactive UI to support VIM-like modal interaction  
**Status:** 🟡 PLANNING (Recommend separate PR due to scope)  
**Priority:** HIGH - Major UX enhancement  
**Complexity:** HIGH - Core UI architectural change

---

## User Requirement

> "I need the UI to basically kind of work like VIM right where you can just enter command mode or type in or you know"

**Key Concept:** Modal interface inspired by VIM's design:
- **Normal Mode** - Navigate with arrows, single-key commands
- **Command Mode** - Type `:command` for CLI-style commands
- **Search Mode** - Type `/pattern` for search
- **Visual Mode** - Select multiple items (future)

---

## Current vs Desired State

### Current State ❌
```
┌────────────────────────────────────────┐
│  AitherZero Interactive Menu           │
├────────────────────────────────────────┤
│  [1] Run Scripts                       │
│  [2] Orchestrate                       │
│  [3] Search                            │
│                                        │
│  Use arrows or type full commands     │
└────────────────────────────────────────┘

Limitations:
- Full command required: -Mode Run -Target 0402
- No quick single-key actions
- No search-as-you-type
- Mode mixing (arrows OR typing, not both)
```

### Desired State ✅
```
┌────────────────────────────────────────┐
│  AitherZero Interactive Menu  [NORMAL] │
├────────────────────────────────────────┤
│  [1] Run Scripts                       │
│  [2] Orchestrate                       │
│  [3] Search                    <─ cursor│
│                                        │
│  :  Command  /  Search  ?  Help       │
└────────────────────────────────────────┘

Press: 
  :   Enter command mode (type commands)
  /   Enter search mode (filter items)
  h,j,k,l  VIM navigation (optional)
  Home  Go to top
  End   Go to bottom
  n   Next search result
  p   Previous search result
  q   Quit/back
  ?   Show help
```

---

## Modal Interface Design

### Mode 1: NORMAL Mode (Navigation) 🎯

**Purpose:** Browse and select items using keyboard

**Key Bindings:**
```
Navigation:
  ↑/k       - Move up
  ↓/j       - Move down
  ←/h       - Go back / previous menu
  →/l/Enter - Select / next menu
  g         - Go to top (first item)
  G         - Go to bottom (last item)
  Ctrl+u    - Page up
  Ctrl+d    - Page down

Actions:
  /         - Enter search mode
  :         - Enter command mode
  ?         - Show help
  q         - Quit current menu
  ESC       - Cancel / go back
  
Quick Actions:
  r         - Run selected script
  o         - Open in details
  s         - Save to bookmarks
  d         - Delete/remove
  e         - Edit
  
Numbers:
  1-9       - Quick select items 1-9
  0         - Go to item 10
```

**Visual Feedback:**
```
┌──────────────────────────────────────────────────┐
│  AitherZero - Run Scripts          [NORMAL MODE] │
├──────────────────────────────────────────────────┤
│                                                  │
│  Environment Setup (0000-0099)                   │
│  Infrastructure (0100-0199)                      │
│  Testing & Validation (0400-0499)  ◄─ cursor    │
│  Reports & Metrics (0500-0599)                   │
│                                                  │
├──────────────────────────────────────────────────┤
│  :cmd  /search  ?help  q=quit  r=run  s=save    │
└──────────────────────────────────────────────────┘
```

### Mode 2: COMMAND Mode (CLI) ⌨️

**Purpose:** Type commands directly (like VIM's `:`)

**Entry:** Press `:` from Normal mode

**Syntax:**
```
:run 0402              Run script 0402
:orchestrate test      Run playbook
:search error          Search logs
:bookmark add          Add bookmark
:session save          Save session
:health                Show health dashboard
:quit                  Exit

Shortcuts:
:r 0402                Same as :run 0402
:o test                Same as :orchestrate test  
:s error               Same as :search error
:b                     Show bookmarks
:h                     Show health
:q                     Quit
```

**Visual:**
```
┌──────────────────────────────────────────────────┐
│  AitherZero - Run Scripts         [COMMAND MODE] │
├──────────────────────────────────────────────────┤
│                                                  │
│  Environment Setup (0000-0099)                   │
│  Infrastructure (0100-0199)                      │
│  Testing & Validation (0400-0499)                │
│  Reports & Metrics (0500-0599)                   │
│                                                  │
├──────────────────────────────────────────────────┤
│  :run 0402_                       ◄─ typing here │
└──────────────────────────────────────────────────┘
```

**Autocomplete:**
```
:run <TAB>
  Suggests: 0402, 0404, 0407, 0510...

:orchestrate <TAB>
  Suggests: test-quick, test-full, infrastructure-lab...
```

### Mode 3: SEARCH Mode (Filter) 🔍

**Purpose:** Filter/search items in current view

**Entry:** Press `/` from Normal mode

**Behavior:**
- Real-time filtering as you type
- Highlights matches
- Press `n` for next match, `N` for previous
- Press ESC to clear search, return to Normal

**Visual:**
```
┌──────────────────────────────────────────────────┐
│  AitherZero - Run Scripts          [SEARCH MODE] │
├──────────────────────────────────────────────────┤
│  Filtered: 3 of 8 items                          │
│                                                  │
│  Testing & Validation (0400-0499)  ◄─ match     │
│  Reports & Metrics (0500-0599)                   │
│                                                  │
│                                                  │
│                                                  │
├──────────────────────────────────────────────────┤
│  /test_                n=next  N=prev  ESC=clear│
└──────────────────────────────────────────────────┘
```

### Mode 4: VISUAL Mode (Future) 👁️

**Purpose:** Multi-select items for batch operations

**Entry:** Press `v` from Normal mode

**Behavior:**
- Select multiple items with space
- Perform batch operations (run all, bookmark all)

---

## Implementation Architecture

### Phase 1: Core Modal System (3-4 days)

**1. Create ModalUIEngine.psm1**
```powershell
# File: domains/experience/ModalUIEngine.psm1

$script:ModalState = @{
    CurrentMode = 'Normal'      # Normal, Command, Search, Visual
    ModeHistory = @()           # Stack of previous modes
    KeyBuffer = ''              # For command/search input
    SearchResults = @()         # Filtered items
    SelectedItems = @()         # For Visual mode
    LastCommand = $null         # Command history
}

function Enter-Mode {
    param([string]$Mode)
    # Switch to new mode, save previous
}

function Exit-Mode {
    # Return to previous mode
}

function Read-ModalKey {
    # Read single key and route to appropriate handler
}

function Invoke-ModalAction {
    param([string]$Action, [hashtable]$Context)
    # Execute action based on current mode
}
```

**2. Create KeyBindingManager.psm1**
```powershell
# File: domains/experience/KeyBindingManager.psm1

# Key binding registry
$script:KeyBindings = @{
    Normal = @{
        ':' = { Enter-Mode 'Command' }
        '/' = { Enter-Mode 'Search' }
        '?' = { Show-Help }
        'q' = { Exit-CurrentMenu }
        'g' = { Go-ToTop }
        'G' = { Go-ToBottom }
        'r' = { Run-SelectedItem }
        's' = { Save-ToBookmarks }
        'n' = { Next-SearchResult }
        'N' = { Previous-SearchResult }
    }
    Command = @{
        'Enter' = { Execute-Command }
        'Escape' = { Enter-Mode 'Normal' }
        'Tab' = { Show-Autocomplete }
    }
    Search = @{
        'Enter' = { Select-SearchResult }
        'Escape' = { Clear-Search; Enter-Mode 'Normal' }
        'n' = { Next-SearchResult }
        'N' = { Previous-SearchResult }
    }
}

function Register-KeyBinding {
    param([string]$Mode, [string]$Key, [scriptblock]$Action)
}

function Invoke-KeyBinding {
    param([string]$Mode, [string]$Key)
}
```

**3. Create CommandParser for `:` commands**
```powershell
# File: domains/experience/Commands/ModalCommandParser.psm1

function Parse-ModalCommand {
    param([string]$Command)
    
    # Parse commands like:
    # :run 0402
    # :r 0402
    # :orchestrate test-quick
    # :o test
    # :search error
    # :s error
    
    $parts = $Command.Trim() -split '\s+', 2
    $cmd = $parts[0].TrimStart(':')
    $args = if ($parts.Count -gt 1) { $parts[1] } else { '' }
    
    # Command aliases
    $aliases = @{
        'r' = 'run'
        'o' = 'orchestrate'
        's' = 'search'
        'b' = 'bookmarks'
        'h' = 'health'
        'q' = 'quit'
    }
    
    if ($aliases.ContainsKey($cmd)) {
        $cmd = $aliases[$cmd]
    }
    
    return @{
        Command = $cmd
        Arguments = $args
    }
}

function Invoke-ModalCommand {
    param([string]$CommandText)
    
    $parsed = Parse-ModalCommand -Command $CommandText
    
    switch ($parsed.Command) {
        'run' {
            Invoke-RunScript -ScriptNumber $parsed.Arguments
        }
        'orchestrate' {
            Invoke-Orchestrate -Playbook $parsed.Arguments
        }
        'search' {
            Invoke-LogSearch -Pattern $parsed.Arguments
        }
        'bookmarks' {
            Show-Bookmarks
        }
        'health' {
            Show-HealthDashboard
        }
        'quit' {
            Exit-Application
        }
    }
}
```

**4. Enhance UnifiedMenu with Modal Support**
```powershell
# Modify: domains/experience/UnifiedMenu.psm1

function Show-ModalMenu {
    param([array]$Items, [string]$Title)
    
    $currentMode = 'Normal'
    $selectedIndex = 0
    $searchFilter = ''
    $commandBuffer = ''
    
    while ($true) {
        Clear-Host
        
        # Show header with mode indicator
        Write-Host "┌$('─' * 60)┐" -ForegroundColor Cyan
        Write-Host "│  $Title".PadRight(60) + "[$currentMode MODE]│" -ForegroundColor Cyan
        Write-Host "├$('─' * 60)┤" -ForegroundColor Cyan
        
        # Show items (filtered if in search mode)
        $displayItems = if ($currentMode -eq 'Search' -and $searchFilter) {
            $Items | Where-Object { $_.Name -like "*$searchFilter*" }
        } else {
            $Items
        }
        
        for ($i = 0; $i -lt $displayItems.Count; $i++) {
            $item = $displayItems[$i]
            $prefix = if ($i -eq $selectedIndex) { "► " } else { "  " }
            $line = "$prefix$($item.Name)"
            
            if ($i -eq $selectedIndex) {
                Write-Host $line -ForegroundColor Yellow
            } else {
                Write-Host $line
            }
        }
        
        # Show mode-specific footer
        Write-Host "├$('─' * 60)┤" -ForegroundColor Cyan
        switch ($currentMode) {
            'Normal' {
                Write-Host "│  :cmd  /search  ?help  q=quit  r=run  s=save      │" -ForegroundColor DarkGray
            }
            'Command' {
                Write-Host "│  :$commandBuffer".PadRight(60) + "│" -ForegroundColor Yellow
            }
            'Search' {
                Write-Host "│  /$searchFilter".PadRight(40) + "  n=next  ESC=clear│" -ForegroundColor Yellow
            }
        }
        Write-Host "└$('─' * 60)┘" -ForegroundColor Cyan
        
        # Read key and handle based on mode
        $key = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
        
        switch ($currentMode) {
            'Normal' {
                switch ($key.Character) {
                    ':' {
                        $currentMode = 'Command'
                        $commandBuffer = ''
                    }
                    '/' {
                        $currentMode = 'Search'
                        $searchFilter = ''
                    }
                    '?' {
                        Show-Help
                    }
                    'q' {
                        return $null
                    }
                    'r' {
                        return @{ Action = 'Run'; Item = $displayItems[$selectedIndex] }
                    }
                    's' {
                        Add-ToBookmarks -Item $displayItems[$selectedIndex]
                    }
                    'g' {
                        $selectedIndex = 0
                    }
                    'G' {
                        $selectedIndex = $displayItems.Count - 1
                    }
                }
                
                # Arrow key handling
                switch ($key.VirtualKeyCode) {
                    38 { $selectedIndex = [Math]::Max(0, $selectedIndex - 1) }  # Up
                    40 { $selectedIndex = [Math]::Min($displayItems.Count - 1, $selectedIndex + 1) }  # Down
                    13 { return $displayItems[$selectedIndex] }  # Enter
                    27 { return $null }  # ESC
                }
            }
            
            'Command' {
                if ($key.VirtualKeyCode -eq 13) {  # Enter
                    Invoke-ModalCommand -CommandText ":$commandBuffer"
                    $currentMode = 'Normal'
                } elseif ($key.VirtualKeyCode -eq 27) {  # ESC
                    $currentMode = 'Normal'
                    $commandBuffer = ''
                } elseif ($key.VirtualKeyCode -eq 8) {  # Backspace
                    if ($commandBuffer.Length -gt 0) {
                        $commandBuffer = $commandBuffer.Substring(0, $commandBuffer.Length - 1)
                    }
                } elseif ($key.Character -match '\w|\s') {
                    $commandBuffer += $key.Character
                }
            }
            
            'Search' {
                if ($key.VirtualKeyCode -eq 27) {  # ESC
                    $currentMode = 'Normal'
                    $searchFilter = ''
                } elseif ($key.VirtualKeyCode -eq 8) {  # Backspace
                    if ($searchFilter.Length -gt 0) {
                        $searchFilter = $searchFilter.Substring(0, $searchFilter.Length - 1)
                    }
                } elseif ($key.Character -match '\w|\s') {
                    $searchFilter += $key.Character
                }
            }
        }
    }
}
```

---

## Implementation Plan

### Recommended Approach: **Separate PR**

**Reasons:**
1. **Major architectural change** - Touches core UI system
2. **High risk** - Changes fundamental user interaction model
3. **Extensive testing needed** - Each mode needs validation
4. **User training** - Requires documentation and examples
5. **Backward compatibility** - Need to maintain old menu as option

### Phase 1: Foundation (New PR - Week 1)
- Create ModalUIEngine.psm1
- Create KeyBindingManager.psm1
- Create ModalCommandParser.psm1
- Add basic Normal/Command/Search modes

### Phase 2: Integration (Week 2)
- Integrate with UnifiedMenu
- Add vim-style key bindings
- Command autocomplete
- Search filtering

### Phase 3: Polish (Week 3)
- Help system (`:help`, `?`)
- Command history (↑/↓ in command mode)
- Visual mode (multi-select)
- Customizable key bindings

---

## Configuration

```powershell
# config.psd1
Experience = @{
    ModalUI = @{
        Enabled = $true
        DefaultMode = 'Normal'
        VimBindings = $true  # Use h,j,k,l for navigation
        ShowModeIndicator = $true
        CommandHistory = $true
        MaxHistoryItems = 50
        KeyBindings = @{
            # Custom key bindings
            Normal = @{
                'r' = 'Run-SelectedItem'
                's' = 'Save-ToBookmarks'
                # ...
            }
        }
    }
}
```

---

## User Experience Example

```
# User starts AitherZero
$ ./Start-AitherZero.ps1 -Mode Interactive

┌──────────────────────────────────────────────────────────┐
│  AitherZero - Main Menu                    [NORMAL MODE] │
├──────────────────────────────────────────────────────────┤
│                                                          │
│  ► Run Scripts                                           │
│    Orchestrate Playbooks                                 │
│    Search & Browse                                       │
│    Health & Status                                       │
│    Bookmarks                                             │
│                                                          │
├──────────────────────────────────────────────────────────┤
│  :cmd  /search  ?help  q=quit  r=run  s=save            │
└──────────────────────────────────────────────────────────┘

# User presses ':' to enter command mode
┌──────────────────────────────────────────────────────────┐
│  AitherZero - Main Menu                   [COMMAND MODE] │
├──────────────────────────────────────────────────────────┤
│                                                          │
│    Run Scripts                                           │
│    Orchestrate Playbooks                                 │
│    Search & Browse                                       │
│    Health & Status                                       │
│    Bookmarks                                             │
│                                                          │
├──────────────────────────────────────────────────────────┤
│  :run 0402_                         <TAB>=autocomplete   │
└──────────────────────────────────────────────────────────┘

# User types ':run 0402' and presses Enter
# Script executes, returns to menu

# User presses '/' to search
┌──────────────────────────────────────────────────────────┐
│  AitherZero - Scripts (0400-0499)          [SEARCH MODE] │
├──────────────────────────────────────────────────────────┤
│  Filtered: 2 of 15 items                                 │
│                                                          │
│  ► [0402] Run Unit Tests                                 │
│    [0420] Validate Component Quality                     │
│                                                          │
│                                                          │
│                                                          │
├──────────────────────────────────────────────────────────┤
│  /test_                          n=next  N=prev  ESC=clear│
└──────────────────────────────────────────────────────────┘
```

---

## Benefits

1. **Faster Navigation** - Single-key commands vs typing full parameters
2. **Power User Friendly** - VIM users feel at home
3. **Discoverability** - Help always visible (press `?`)
4. **Consistency** - Same keybindings across all menus
5. **Efficiency** - No need to leave keyboard for mouse
6. **Flexibility** - Command mode for complex operations, normal mode for browsing

---

## Risks & Mitigation

**Risks:**
1. Learning curve for non-VIM users
2. Conflicts with existing shortcuts
3. Complexity in implementation
4. Testing all key combinations

**Mitigation:**
1. Keep old menu as fallback option
2. Show help on startup
3. Clear mode indicators
4. Comprehensive testing
5. User feedback beta period

---

## Recommendation

**Create separate PR** for VIM-like UI:
- Title: "feat: VIM-inspired modal interactive UI"
- Implements: ModalUIEngine, KeyBindings, Command mode
- Does NOT break: Existing menu functionality
- Adds: Config flag to enable/disable modal UI

**This PR should focus on:**
- Completing Phase 0 (Log Search + Health Dashboard)
- Completing Phase 1 (Sessions + Bookmarks + Filtering)

**Next PR will add:**
- VIM-like modal UI system
- Command mode (`:`)
- Search mode (`/`)
- Enhanced key bindings

---

**Status:** 📋 DOCUMENTED - READY FOR SEPARATE PR  
**Estimated Effort:** 2-3 weeks (full implementation)  
**User Impact:** VERY HIGH - Revolutionary UX improvement

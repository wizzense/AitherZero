#Requires -Version 7.0
<#
.SYNOPSIS
    Better interactive menu system that actually works
.DESCRIPTION
    Uses $host.UI.RawUI.ReadKey() for proper keyboard input
#>

function Show-BetterMenu {
    <#
    .SYNOPSIS
        Display an interactive menu with real keyboard navigation
    .PARAMETER Title
        Menu title
    .PARAMETER Items
        Array of menu items
    .PARAMETER MultiSelect
        Allow multiple selections
    .PARAMETER ShowNumbers
        Show item numbers
    #>
    [CmdletBinding()]
    param(
        [string]$Title = "Menu",
        
        [Parameter(Mandatory)]
        [array]$Items,
        
        [switch]$MultiSelect,
        
        [switch]$ShowNumbers,
        
        [hashtable]$CustomActions = @{}
    )
    
    # Check if we can use interactive mode
    $canUseInteractive = $false
    try {
        # Test if we can read keys
        if ($host.UI.RawUI.KeyAvailable) {}  # Just test the property
        $canUseInteractive = $true
    } catch {
        $canUseInteractive = $false
    }
    
    # If we can't use interactive mode, fall back to simple prompt
    if (-not $canUseInteractive -or $env:AITHERZERO_NONINTERACTIVE) {
        # Simple numbered menu
        if ($Title) {
            Write-Host "`n$Title" -ForegroundColor Cyan
            Write-Host ("=" * $Title.Length) -ForegroundColor DarkCyan
        }
        
        for ($i = 0; $i -lt $Items.Count; $i++) {
            $item = $Items[$i]
            $displayText = if ($item -is [string]) { $item } else { $item.Name }
            Write-Host "[$($i + 1)] $displayText" -ForegroundColor White
            
            if ($item -isnot [string] -and $item.PSObject.Properties['Description'] -and $item.Description) {
                Write-Host "    $($item.Description)" -ForegroundColor DarkGray
            }
        }
        
        if ($CustomActions.Count -gt 0) {
            Write-Host ""
            foreach ($action in $CustomActions.GetEnumerator()) {
                Write-Host "[$($action.Key)] $($action.Value)" -ForegroundColor Cyan
            }
        }
        
        Write-Host "`nSelect an option: " -ForegroundColor Yellow -NoNewline
        $selection = Read-Host
        
        if ($CustomActions -and $selection -and $CustomActions.ContainsKey($selection.ToUpper())) {
            return @{ Action = $selection.ToUpper() }
        }
        
        if ($selection -match '^\d+$') {
            $index = [int]$selection - 1
            if ($index -ge 0 -and $index -lt $Items.Count) {
                return $Items[$index]
            }
        }
        
        return $null
    }
    
    # Initialize state for interactive mode
    $selectedIndex = 0
    $selectedItems = @()
    
    # Calculate page size based on terminal height
    $terminalHeight = 25  # Default
    try {
        if ($host.UI.RawUI -and $host.UI.RawUI.WindowSize -and $host.UI.RawUI.WindowSize.Height) {
            $terminalHeight = $host.UI.RawUI.WindowSize.Height
        }
    } catch {}
    
    # Leave room for title, help text, and scroll indicators (about 10 lines)
    $maxPageSize = [Math]::Max(5, $terminalHeight - 10)
    $pageSize = [Math]::Min($maxPageSize, $Items.Count)
    $scrollOffset = 0
    
    # Initial setup
    $lastSelectedIndex = -1
    $firstDraw = $true
    
    # Check if we can actually use interactive mode
    $canInteract = $true
    try {
        # Test if we can actually read keys in this environment
        if ([Console]::IsInputRedirected -or -not [Environment]::UserInteractive) {
            $canInteract = $false
        }
    } catch {
        $canInteract = $false
    }
    
    # If we can't interact, use simple menu
    if (-not $canInteract) {
        # Simple numbered menu
        if ($Title) {
            Write-Host "`n$Title" -ForegroundColor Cyan
            Write-Host ("=" * $Title.Length) -ForegroundColor DarkCyan
        }
        
        for ($i = 0; $i -lt $Items.Count; $i++) {
            $item = $Items[$i]
            $displayText = if ($item -is [string]) { $item } else { $item.Name }
            Write-Host "[$($i + 1)] $displayText" -ForegroundColor White
            
            if ($item -isnot [string] -and $item.PSObject.Properties['Description'] -and $item.Description) {
                Write-Host "    $($item.Description)" -ForegroundColor DarkGray
            }
        }
        
        if ($CustomActions.Count -gt 0) {
            Write-Host ""
            foreach ($action in $CustomActions.GetEnumerator()) {
                Write-Host "[$($action.Key)] $($action.Value)" -ForegroundColor Cyan
            }
        }
        
        Write-Host "`nSelect an option: " -ForegroundColor Yellow -NoNewline
        $selection = Read-Host
        
        if ($CustomActions -and $selection -and $CustomActions.ContainsKey($selection.ToUpper())) {
            return @{ Action = $selection.ToUpper() }
        }
        
        if ($selection -match '^\d+$') {
            $index = [int]$selection - 1
            if ($index -ge 0 -and $index -lt $Items.Count) {
                return $Items[$index]
            }
        }
        
        return $null
    }
    
    # Main menu loop  
    while ($true) {
        # Only clear screen on first draw or when explicitly needed
        if ($firstDraw) {
            # Skip Clear-Host in CI/non-interactive environments
            if (-not $env:CI -and -not $env:GITHUB_ACTIONS) {
                try { Clear-Host } catch { }
            }
            $firstDraw = $false
        } else {
            # Clear screen properly for Linux/Unix terminals
            if (-not $env:CI -and -not $env:GITHUB_ACTIONS) {
                if ($IsLinux -or $IsMacOS) {
                    # Use ANSI escape sequences for Unix-like systems
                    Write-Host "`e[H`e[2J" -NoNewline
                } else {
                    # Windows - use SetCursorPosition
                    try { [Console]::SetCursorPosition(0, 0) } catch { }
                }
            }
        }
        
        # Draw title
        if ($Title) {
            Write-Host "`n  $Title" -ForegroundColor Cyan
            Write-Host ("  " + "=" * $Title.Length) -ForegroundColor DarkCyan
            Write-Host ""
        }
        
        # Calculate visible range
        $startIdx = $scrollOffset
        $endIdx = [Math]::Min($scrollOffset + $pageSize, $Items.Count) - 1
        
        # Draw items
        for ($i = $startIdx; $i -le $endIdx; $i++) {
            $item = $Items[$i]
            $displayText = if ($item -is [string]) { $item } else { $item.Name }
            
            # Build prefix
            $prefix = ""
            if ($ShowNumbers) {
                $num = $i + 1
                $prefix = if ($num -lt 10) { " $num. " } else { "$num. " }
            } else {
                $prefix = "    "
            }
            
            # Multi-select checkbox
            if ($MultiSelect) {
                $checked = if ($i -in $selectedItems) { "[✓]" } else { "[ ]" }
                $prefix = "$prefix$checked "
            }
            
            # Highlight selected item
            if ($i -eq $selectedIndex) {
                Write-Host "  ► $prefix$displayText" -ForegroundColor Cyan
                
                # Show description on next line if available
                if ($item -isnot [string] -and $item.PSObject.Properties['Description'] -and $item.Description) {
                    Write-Host "      $($item.Description)" -ForegroundColor DarkGray
                }
            } else {
                Write-Host "    $prefix$displayText" -ForegroundColor White
                
                if ($item -isnot [string] -and $item.PSObject.Properties['Description'] -and $item.Description) {
                    Write-Host "      $($item.Description)" -ForegroundColor DarkGray
                }
            }
        }
        
        # Show scroll indicators
        if ($scrollOffset -gt 0) {
            Write-Host "`n  ↑ More above" -ForegroundColor DarkGray
        }
        if ($endIdx -lt $Items.Count - 1) {
            Write-Host "  ↓ More below" -ForegroundColor DarkGray
        }
        
        # Show position
        Write-Host "`n  [$($selectedIndex + 1) of $($Items.Count)]" -ForegroundColor DarkCyan
        
        # Show help
        Write-Host "`n  Navigate: ↑/↓ or j/k | Select: Enter" -ForegroundColor DarkGray -NoNewline
        if ($MultiSelect) {
            Write-Host " | Toggle: Space" -ForegroundColor DarkGray -NoNewline
        }
        Write-Host " | Cancel: Esc/q" -ForegroundColor DarkGray
        
        # Show number jump help if applicable
        if ($ShowNumbers -and $Items.Count -le 99) {
            Write-Host "  Jump: Type number (1-$($Items.Count))" -ForegroundColor DarkGray
        }
        
        # Show custom actions
        if ($CustomActions.Count -gt 0) {
            Write-Host ""
            foreach ($action in $CustomActions.GetEnumerator()) {
                Write-Host "  [$($action.Key)] $($action.Value)" -ForegroundColor Cyan
            }
        }
        
        # Read key - blocking is actually better for menus
        $keyInfo = $null
        $virtualKeyCode = 0
        $keyChar = ''
        
        try {
            $key = $host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
            $virtualKeyCode = $key.VirtualKeyCode
            $keyChar = $key.Character
        } catch {
            # If ReadKey fails, try alternative method
            $consoleKey = [Console]::ReadKey($true)
            # Map ConsoleKey to VirtualKeyCode equivalents
            switch ($consoleKey.Key) {
                'UpArrow' { $virtualKeyCode = 38 }
                'DownArrow' { $virtualKeyCode = 40 }
                'PageUp' { $virtualKeyCode = 33 }
                'PageDown' { $virtualKeyCode = 34 }
                'Home' { $virtualKeyCode = 36 }
                'End' { $virtualKeyCode = 35 }
                'Enter' { $virtualKeyCode = 13 }
                'Spacebar' { $virtualKeyCode = 32 }
                'Escape' { $virtualKeyCode = 27 }
                default { $keyChar = $consoleKey.KeyChar }
            }
        }
        
        # Process key
        switch ($virtualKeyCode) {
            38 { # Up arrow
                if ($selectedIndex -gt 0) {
                    $selectedIndex--
                    # Adjust scroll if needed
                    if ($selectedIndex -lt $scrollOffset) {
                        $scrollOffset = $selectedIndex
                    }
                }
            }
            
            40 { # Down arrow
                if ($selectedIndex -lt $Items.Count - 1) {
                    $selectedIndex++
                    # Adjust scroll if needed
                    if ($selectedIndex -gt $scrollOffset + $pageSize - 1) {
                        $scrollOffset = $selectedIndex - $pageSize + 1
                    }
                }
            }
            
            33 { # Page Up
                $selectedIndex = [Math]::Max(0, $selectedIndex - $pageSize)
                $scrollOffset = [Math]::Max(0, $scrollOffset - $pageSize)
            }
            
            34 { # Page Down
                $selectedIndex = [Math]::Min($Items.Count - 1, $selectedIndex + $pageSize)
                $scrollOffset = [Math]::Min([Math]::Max(0, $Items.Count - $pageSize), $scrollOffset + $pageSize)
            }
            
            36 { # Home
                $selectedIndex = 0
                $scrollOffset = 0
            }
            
            35 { # End
                $selectedIndex = $Items.Count - 1
                $scrollOffset = [Math]::Max(0, $Items.Count - $pageSize)
            }
            
            13 { # Enter
                if ($MultiSelect) {
                    if ($selectedItems.Count -gt 0) {
                        return $selectedItems | ForEach-Object { $Items[$_] }
                    }
                } else {
                    return $Items[$selectedIndex]
                }
            }
            
            32 { # Space
                if ($MultiSelect) {
                    if ($selectedIndex -in $selectedItems) {
                        $selectedItems = $selectedItems | Where-Object { $_ -ne $selectedIndex }
                    } else {
                        $selectedItems += $selectedIndex
                    }
                }
            }
            
            27 { # Escape
                return $null
            }
            
            default {
                # Check for character input
                $char = if ($keyChar) { $keyChar } else { $key.Character }
                
                # Handle vim-style navigation
                if ($char -eq 'j') {
                    # Move down
                    if ($selectedIndex -lt $Items.Count - 1) {
                        $selectedIndex++
                        if ($selectedIndex -gt $scrollOffset + $pageSize - 1) {
                            $scrollOffset = $selectedIndex - $pageSize + 1
                        }
                    }
                } elseif ($char -eq 'k') {
                    # Move up
                    if ($selectedIndex -gt 0) {
                        $selectedIndex--
                        if ($selectedIndex -lt $scrollOffset) {
                            $scrollOffset = $selectedIndex
                        }
                    }
                } elseif ($char -eq 'q' -or $char -eq 'Q') {
                    # Check if Q is a custom action first
                    if ($CustomActions -and $CustomActions.ContainsKey('Q')) {
                        return @{ Action = 'Q' }
                    }
                    # Otherwise quit
                    return $null
                } elseif ($char -match '[0-9]') {
                    # Number jump - collect digits
                    $number = $char
                    Write-Host "  Jump to: $number" -ForegroundColor Yellow -NoNewline
                    
                    # Try to read another digit for two-digit numbers
                    try {
                        $nextKey = $host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown,AllowCtrlC')
                        if ($nextKey.Character -match '[0-9]') {
                            $number += $nextKey.Character
                            Write-Host $nextKey.Character -ForegroundColor Yellow -NoNewline
                        } elseif ($nextKey.VirtualKeyCode -eq 13) {
                            # Enter pressed, process number
                        } else {
                            # Not a digit, process single digit
                        }
                    } catch {}
                    
                    $index = [int]$number - 1
                    if ($index -ge 0 -and $index -lt $Items.Count) {
                        $selectedIndex = $index
                        # Adjust scroll to show selected item
                        if ($selectedIndex -lt $scrollOffset) {
                            $scrollOffset = $selectedIndex
                        } elseif ($selectedIndex -gt $scrollOffset + $pageSize - 1) {
                            $scrollOffset = [Math]::Max(0, $selectedIndex - $pageSize + 1)
                        }
                    }
                } elseif ($CustomActions -and ($CustomActions.ContainsKey($char.ToString().ToUpper()) -or $CustomActions.ContainsKey($char.ToString()))) {
                    # Custom action - always return uppercase key
                    $actionKey = if ($CustomActions.ContainsKey($char.ToString().ToUpper())) { 
                        $char.ToString().ToUpper() 
                    } else { 
                        $char.ToString() 
                    }
                    return @{ Action = $actionKey }
                } elseif ($char -match '[a-zA-Z]') {
                    # Jump to first item starting with this letter
                    $targetChar = $char.ToString().ToLower()
                    for ($i = 0; $i -lt $Items.Count; $i++) {
                        $itemText = if ($Items[$i] -is [string]) { $Items[$i] } else { $Items[$i].Name }
                        if ($itemText.ToLower().StartsWith($targetChar)) {
                            $selectedIndex = $i
                            # Adjust scroll to show selected item
                            if ($selectedIndex -lt $scrollOffset) {
                                $scrollOffset = $selectedIndex
                            } elseif ($selectedIndex -gt $scrollOffset + $pageSize - 1) {
                                $scrollOffset = [Math]::Max(0, $selectedIndex - $pageSize + 1)
                            }
                            break
                        }
                    }
                }
            }
        }
    }
}

# Export the function
Export-ModuleMember -Function 'Show-BetterMenu'
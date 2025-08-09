#Requires -Version 7.0
<#
.SYNOPSIS
    Interactive menu component with keyboard navigation
.DESCRIPTION
    Provides a menu with arrow key navigation, search, and customizable rendering
#>

# Import core modules
$script:CorePath = Join-Path (Split-Path $PSScriptRoot -Parent) "Core"
Import-Module (Join-Path $script:CorePath "UIComponent.psm1") -Force -ErrorAction SilentlyContinue
Import-Module (Join-Path $script:CorePath "UIContext.psm1") -Force -ErrorAction SilentlyContinue

function New-InteractiveMenu {
    <#
    .SYNOPSIS
        Create an interactive menu component
    .PARAMETER Items
        Array of menu items (strings or objects with Name/Description)
    .PARAMETER Title
        Menu title
    .PARAMETER MultiSelect
        Allow multiple selections
    .PARAMETER ShowSearch
        Show search box
    .PARAMETER ShowNumbers
        Show item numbers
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$Items,
        
        [string]$Title = "Menu",
        
        [switch]$MultiSelect,
        
        [switch]$ShowSearch,
        
        [switch]$ShowNumbers,
        
        [int]$X = 0,
        [int]$Y = 0,
        [int]$Width = 0,
        [int]$Height = 0
    )
    
    # Create base component
    $menu = New-UIComponent -Name "InteractiveMenu" -X $X -Y $Y -Width $Width -Height $Height
    $menu.Type = "InteractiveMenu"
    
    # Menu-specific properties
    $menu.Properties = @{
        Title = $Title
        Items = $Items
        FilteredItems = $Items
        SelectedIndex = 0
        SelectedIndices = @()
        MultiSelect = $MultiSelect.IsPresent
        ShowSearch = $ShowSearch.IsPresent
        ShowNumbers = $ShowNumbers.IsPresent
        SearchText = ""
        ScrollOffset = 0
        MaxVisibleItems = if ($Height -gt 0) { $Height - 4 } else { 10 }
        HighlightColor = "Yellow"
        NormalColor = "White"
        DisabledColor = "DarkGray"
        BorderStyle = "Single"
    }
    
    # Override render method
    $menu.OnRender = {
        param($self)
        
        if (-not $self.Context -or -not $self.Context.Terminal) {
            return
        }
        
        $terminal = $self.Context.Terminal
        $props = $self.Properties
        
        # Calculate dimensions
        $startY = $self.Y
        $startX = $self.X
        $width = if ($self.Width -gt 0) { $self.Width } else { 40 }
        
        # Draw border and title
        Draw-MenuBorder -Terminal $terminal -X $startX -Y $startY -Width $width -Title $props.Title -Style $props.BorderStyle
        
        $contentY = $startY + 2
        
        # Draw search box if enabled
        if ($props.ShowSearch) {
            Draw-MenuSearch -Terminal $terminal -X ($startX + 2) -Y $contentY -Width ($width - 4) -Text $props.SearchText
            $contentY += 2
        }
        
        # Draw menu items
        $visibleItems = Get-VisibleMenuItems -Items $props.FilteredItems -ScrollOffset $props.ScrollOffset -MaxVisible $props.MaxVisibleItems
        
        for ($i = 0; $i -lt $visibleItems.Count; $i++) {
            $itemIndex = $props.ScrollOffset + $i
            $item = $visibleItems[$i]
            
            # Determine if item is selected
            $isSelected = $itemIndex -eq $props.SelectedIndex
            $isChecked = $props.MultiSelect -and $itemIndex -in $props.SelectedIndices
            
            # Build item text
            $itemText = Build-MenuItemText -Item $item -Index $itemIndex -ShowNumbers $props.ShowNumbers -IsChecked $isChecked
            
            # Determine color
            $color = if ($isSelected) { $props.HighlightColor } else { $props.NormalColor }
            
            # Draw item
            if ($terminal.SetCursor) {
                $terminal.SetCursor($startX + 2, $contentY + $i)
            }
            
            if ($isSelected) {
                # Draw selection indicator
                if ($terminal.Write) {
                    $terminal.Write("> ", $props.HighlightColor)
                    $terminal.Write($itemText, $color)
                }
            } else {
                if ($terminal.Write) {
                    $terminal.Write("  ", $props.NormalColor)
                    $terminal.Write($itemText, $color)
                }
            }
        }
        
        # Draw scrollbar if needed
        if ($props.FilteredItems.Count -gt $props.MaxVisibleItems) {
            Draw-MenuScrollbar -Terminal $terminal -X ($startX + $width - 2) -Y $contentY `
                             -Height $props.MaxVisibleItems -TotalItems $props.FilteredItems.Count `
                             -ScrollOffset $props.ScrollOffset
        }
        
        # Draw help text
        $helpY = $contentY + $props.MaxVisibleItems + 1
        if ($terminal.SetCursor) {
            $terminal.SetCursor($startX + 2, $helpY)
        }
        if ($terminal.Write) {
            $terminal.Write("↑↓:Navigate", "DarkGray")
            if ($props.MultiSelect) {
                $terminal.Write(" Space:Select", "DarkGray")
            }
            $terminal.Write(" Enter:Confirm ESC:Cancel", "DarkGray")
        }
    }
    
    # Handle keyboard input
    $menu.OnKeyPress = {
        param($input)
        
        $props = $this.Properties
        $handled = $true
        
        switch ($input.Key) {
            "UpArrow" {
                # Move selection up
                if ($props.SelectedIndex -gt 0) {
                    $props.SelectedIndex--
                    Ensure-MenuItemVisible -Menu $this
                    Queue-UIRender -Component $this -Context $this.Context
                }
            }
            
            "DownArrow" {
                # Move selection down
                if ($props.SelectedIndex -lt ($props.FilteredItems.Count - 1)) {
                    $props.SelectedIndex++
                    Ensure-MenuItemVisible -Menu $this
                    Queue-UIRender -Component $this -Context $this.Context
                }
            }
            
            "PageUp" {
                # Move up by page
                $props.SelectedIndex = [Math]::Max(0, $props.SelectedIndex - $props.MaxVisibleItems)
                Ensure-MenuItemVisible -Menu $this
                Queue-UIRender -Component $this -Context $this.Context
            }
            
            "PageDown" {
                # Move down by page
                $props.SelectedIndex = [Math]::Min($props.FilteredItems.Count - 1, $props.SelectedIndex + $props.MaxVisibleItems)
                Ensure-MenuItemVisible -Menu $this
                Queue-UIRender -Component $this -Context $this.Context
            }
            
            "Home" {
                # Move to first item
                $props.SelectedIndex = 0
                Ensure-MenuItemVisible -Menu $this
                Queue-UIRender -Component $this -Context $this.Context
            }
            
            "End" {
                # Move to last item
                $props.SelectedIndex = $props.FilteredItems.Count - 1
                Ensure-MenuItemVisible -Menu $this
                Queue-UIRender -Component $this -Context $this.Context
            }
            
            "Spacebar" {
                # Toggle selection in multi-select mode
                if ($props.MultiSelect) {
                    if ($props.SelectedIndex -in $props.SelectedIndices) {
                        $props.SelectedIndices = $props.SelectedIndices | Where-Object { $_ -ne $props.SelectedIndex }
                    } else {
                        $props.SelectedIndices += $props.SelectedIndex
                    }
                    Queue-UIRender -Component $this -Context $this.Context
                }
            }
            
            "Enter" {
                # Confirm selection
                Invoke-UIComponentEvent -Component $this -EventName "ItemSelected" -Data @{
                    SelectedIndex = $props.SelectedIndex
                    SelectedItem = $props.FilteredItems[$props.SelectedIndex]
                    SelectedIndices = $props.SelectedIndices
                    SelectedItems = $props.SelectedIndices | ForEach-Object { $props.FilteredItems[$_] }
                }
            }
            
            "Escape" {
                # Cancel menu
                Invoke-UIComponentEvent -Component $this -EventName "Cancelled"
            }
            
            default {
                # Handle search input
                if ($props.ShowSearch -and $input.Char) {
                    if ($input.Key -eq "Backspace") {
                        if ($props.SearchText.Length -gt 0) {
                            $props.SearchText = $props.SearchText.Substring(0, $props.SearchText.Length - 1)
                            Update-MenuFilter -Menu $this
                            Queue-UIRender -Component $this -Context $this.Context
                        }
                    } elseif ($input.Char -match '[\w\s]') {
                        $props.SearchText += $input.Char
                        Update-MenuFilter -Menu $this
                        Queue-UIRender -Component $this -Context $this.Context
                    }
                } else {
                    $handled = $false
                }
            }
        }
        
        return $handled
    }
    
    return $menu
}

function Draw-MenuBorder {
    param($Terminal, $X, $Y, $Width, $Title, $Style = "Single")
    
    $borders = @{
        Single = @{ TL = '┌'; TR = '┐'; BL = '└'; BR = '┘'; H = '─'; V = '│' }
        Double = @{ TL = '╔'; TR = '╗'; BL = '╚'; BR = '╝'; H = '═'; V = '║' }
        Rounded = @{ TL = '╭'; TR = '╮'; BL = '╰'; BR = '╯'; H = '─'; V = '│' }
    }
    
    $b = $borders[$Style]
    
    # Top border
    if ($Terminal.SetCursor) { $Terminal.SetCursor($X, $Y) }
    if ($Terminal.Write) {
        $topLine = $b.TL + ($b.H * ($Width - 2)) + $b.TR
        
        # Insert title if provided
        if ($Title) {
            $titleText = " $Title "
            $titlePos = [Math]::Floor(($Width - $titleText.Length) / 2)
            if ($titlePos -gt 0) {
                $topLine = $b.TL + ($b.H * ($titlePos - 1)) + $titleText + ($b.H * ($Width - $titlePos - $titleText.Length - 1)) + $b.TR
            }
        }
        
        $Terminal.Write($topLine, "Cyan")
    }
}

function Draw-MenuSearch {
    param($Terminal, $X, $Y, $Width, $Text)
    
    if ($Terminal.SetCursor) { $Terminal.SetCursor($X, $Y) }
    if ($Terminal.Write) {
        $Terminal.Write("Search: ", "DarkGray")
        $Terminal.Write($Text, "White")
        $Terminal.Write("_", "DarkGray")  # Cursor
    }
}

function Build-MenuItemText {
    param($Item, $Index, $ShowNumbers, $IsChecked)
    
    $text = ""
    
    # Add number if requested
    if ($ShowNumbers) {
        $text += "[$($Index + 1)] "
    }
    
    # Add checkbox for multi-select
    if ($IsChecked -ne $null) {
        $text += if ($IsChecked) { "[✓] " } else { "[ ] " }
    }
    
    # Add item text
    if ($Item -is [string]) {
        $text += $Item
    } elseif ($Item.Name) {
        $text += $Item.Name
        if ($Item.Description) {
            $text += " - $($Item.Description)"
        }
    } else {
        $text += $Item.ToString()
    }
    
    return $text
}

function Get-VisibleMenuItems {
    param($Items, $ScrollOffset, $MaxVisible)
    
    $endIndex = [Math]::Min($ScrollOffset + $MaxVisible, $Items.Count)
    return $Items[$ScrollOffset..($endIndex - 1)]
}

function Ensure-MenuItemVisible {
    param($Menu)
    
    $props = $Menu.Properties
    
    # Scroll up if needed
    if ($props.SelectedIndex -lt $props.ScrollOffset) {
        $props.ScrollOffset = $props.SelectedIndex
    }
    
    # Scroll down if needed
    if ($props.SelectedIndex -ge ($props.ScrollOffset + $props.MaxVisibleItems)) {
        $props.ScrollOffset = $props.SelectedIndex - $props.MaxVisibleItems + 1
    }
}

function Update-MenuFilter {
    param($Menu)
    
    $props = $Menu.Properties
    
    if ([string]::IsNullOrEmpty($props.SearchText)) {
        $props.FilteredItems = $props.Items
    } else {
        $searchPattern = "*$($props.SearchText)*"
        $props.FilteredItems = $props.Items | Where-Object {
            if ($_ -is [string]) {
                $_ -like $searchPattern
            } elseif ($_.Name) {
                $_.Name -like $searchPattern -or ($_.Description -and $_.Description -like $searchPattern)
            } else {
                $_.ToString() -like $searchPattern
            }
        }
    }
    
    # Reset selection
    $props.SelectedIndex = 0
    $props.ScrollOffset = 0
}

function Draw-MenuScrollbar {
    param($Terminal, $X, $Y, $Height, $TotalItems, $ScrollOffset)
    
    $scrollbarHeight = [Math]::Max(1, [Math]::Floor($Height * $Height / $TotalItems))
    $scrollbarPosition = [Math]::Floor($ScrollOffset * ($Height - $scrollbarHeight) / ($TotalItems - $Height))
    
    for ($i = 0; $i -lt $Height; $i++) {
        if ($Terminal.SetCursor) { $Terminal.SetCursor($X, $Y + $i) }
        
        if ($i -ge $scrollbarPosition -and $i -lt ($scrollbarPosition + $scrollbarHeight)) {
            if ($Terminal.Write) { $Terminal.Write("█", "DarkGray") }
        } else {
            if ($Terminal.Write) { $Terminal.Write("│", "DarkGray") }
        }
    }
}

# Export functions
Export-ModuleMember -Function @(
    'New-InteractiveMenu'
)
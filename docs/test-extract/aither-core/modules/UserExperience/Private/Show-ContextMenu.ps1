function Show-ContextMenu {
    <#
    .SYNOPSIS
        Displays an interactive context menu with enhanced features
    .DESCRIPTION
        Enhanced context menu system that combines and improves upon the original
        implementations from SetupWizard and StartupExperience modules
    .PARAMETER Title
        Menu title to display
    .PARAMETER Options
        Array of menu options (can be strings or hashtables with extended properties)
    .PARAMETER ShowHelp
        Show help text for options
    .PARAMETER ReturnAction
        Return the action value instead of the option object
    .PARAMETER AllowSearch
        Enable search/filter functionality
    .PARAMETER ShowCategories
        Group options by category
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Title = "Menu",
        
        [Parameter(Mandatory)]
        [array]$Options,
        
        [Parameter()]
        [switch]$ShowHelp,
        
        [Parameter()]
        [switch]$ReturnAction,
        
        [Parameter()]
        [switch]$AllowSearch,
        
        [Parameter()]
        [switch]$ShowCategories
    )
    
    try {
        # Normalize options to consistent format
        $normalizedOptions = Normalize-MenuOptions -Options $Options
        
        # Check if we have enhanced UI capabilities
        $capabilities = $script:UICapabilities ?? (Get-TerminalCapabilities)
        $useEnhancedMenu = $capabilities.SupportsEnhancedUI -and $capabilities.SupportsReadKey
        
        if ($useEnhancedMenu -and $normalizedOptions.Count -gt 3) {
            return Show-EnhancedContextMenu -Title $Title -Options $normalizedOptions -ShowHelp:$ShowHelp -ReturnAction:$ReturnAction -AllowSearch:$AllowSearch -ShowCategories:$ShowCategories
        } else {
            return Show-BasicContextMenu -Title $Title -Options $normalizedOptions -ShowHelp:$ShowHelp -ReturnAction:$ReturnAction
        }
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Error displaying context menu: $_" -Source 'UserExperience'
        
        # Fallback to simple selection
        return Show-FallbackMenu -Title $Title -Options $Options -ReturnAction:$ReturnAction
    }
}

function Normalize-MenuOptions {
    <#
    .SYNOPSIS
        Normalizes menu options to consistent format
    #>
    param([array]$Options)
    
    $normalized = @()
    
    for ($i = 0; $i -lt $Options.Count; $i++) {
        $option = $Options[$i]
        
        if ($option -is [string]) {
            # Simple string option
            $normalized += @{
                Index = $i + 1
                Text = $option
                Action = $option
                Description = ""
                Icon = ""
                Category = "General"
                Enabled = $true
                Tier = "free"
                ExpertOnly = $false
            }
        } elseif ($option -is [hashtable]) {
            # Extended option object
            $normalized += @{
                Index = $i + 1
                Text = $option.Text ?? $option.Name ?? "Option $($i + 1)"
                Action = $option.Action ?? $option.Text ?? $option.Name ?? "Option$($i + 1)"
                Description = $option.Description ?? ""
                Icon = $option.Icon ?? ""
                Category = $option.Category ?? "General"
                Enabled = $option.Enabled ?? $true
                Tier = $option.Tier ?? "free"
                ExpertOnly = $option.ExpertOnly ?? $false
            }
        } else {
            # Try to convert to string
            $normalized += @{
                Index = $i + 1
                Text = $option.ToString()
                Action = $option.ToString()
                Description = ""
                Icon = ""
                Category = "General"
                Enabled = $true
                Tier = "free"
                ExpertOnly = $false
            }
        }
    }
    
    return $normalized
}

function Show-EnhancedContextMenu {
    <#
    .SYNOPSIS
        Shows enhanced context menu with keyboard navigation
    #>
    param(
        [string]$Title,
        [array]$Options,
        [switch]$ShowHelp,
        [switch]$ReturnAction,
        [switch]$AllowSearch,
        [switch]$ShowCategories
    )
    
    $selectedIndex = 0
    $searchFilter = ""
    $filteredOptions = $Options
    $showingHelp = $false
    $currentCategory = $null
    
    # Group by category if requested
    if ($ShowCategories) {
        $categories = $Options | Group-Object Category | Sort-Object Name
    }
    
    while ($true) {
        # Clear screen and show menu
        Clear-Host
        
        # Show title
        Show-MenuTitle -Title $Title -SearchFilter $searchFilter
        
        # Show categories if enabled
        if ($ShowCategories -and $categories) {
            Show-MenuCategories -Categories $categories -CurrentCategory $currentCategory -SelectedIndex $selectedIndex
        } else {
            Show-MenuOptions -Options $filteredOptions -SelectedIndex $selectedIndex -ShowHelp:$ShowHelp -ShowingHelp:$showingHelp
        }
        
        # Show help panel if enabled
        if ($ShowHelp -and $selectedIndex -ge 0 -and $selectedIndex -lt $filteredOptions.Count) {
            Show-MenuHelpPanel -Option $filteredOptions[$selectedIndex] -ShowingHelp:$showingHelp
        }
        
        # Show footer with instructions
        Show-MenuFooter -AllowSearch:$AllowSearch -ShowHelp:$ShowHelp
        
        # Get user input
        $key = Read-MenuKey
        
        # Handle key input
        $action = Handle-MenuKeyInput -Key $key -SelectedIndex ([ref]$selectedIndex) -Options $filteredOptions -SearchFilter ([ref]$searchFilter) -AllowSearch:$AllowSearch -ShowingHelp ([ref]$showingHelp)
        
        switch ($action.Type) {
            'Select' {
                if ($selectedIndex -ge 0 -and $selectedIndex -lt $filteredOptions.Count) {
                    $selectedOption = $filteredOptions[$selectedIndex]
                    if ($selectedOption.Enabled) {
                        return if ($ReturnAction) { $selectedOption.Action } else { $selectedOption }
                    } else {
                        Show-DisabledOptionMessage -Option $selectedOption
                        Start-Sleep -Seconds 1
                    }
                }
            }
            'Exit' {
                return $null
            }
            'Refresh' {
                $filteredOptions = Filter-MenuOptions -Options $Options -SearchFilter $searchFilter
                $selectedIndex = [Math]::Min($selectedIndex, $filteredOptions.Count - 1)
            }
            'Help' {
                $showingHelp = -not $showingHelp
            }
        }
    }
}

function Show-BasicContextMenu {
    <#
    .SYNOPSIS
        Shows basic context menu for limited terminals
    #>
    param(
        [string]$Title,
        [array]$Options,
        [switch]$ShowHelp,
        [switch]$ReturnAction
    )
    
    while ($true) {
        Write-Host ""
        Write-Host "═══ $Title ═══" -ForegroundColor Cyan
        Write-Host ""
        
        # Show options
        for ($i = 0; $i -lt $Options.Count; $i++) {
            $option = $Options[$i]
            $prefix = "[$($i + 1)]"
            $icon = if ($option.Icon) { "$($option.Icon) " } else { "" }
            $status = if (-not $option.Enabled) { " (disabled)" } else { "" }
            
            if ($option.Enabled) {
                Write-Host "  $prefix $icon$($option.Text)$status" -ForegroundColor White
            } else {
                Write-Host "  $prefix $icon$($option.Text)$status" -ForegroundColor Gray
            }
            
            if ($ShowHelp -and $option.Description) {
                Write-Host "      $($option.Description)" -ForegroundColor Gray
            }
        }
        
        Write-Host ""
        Write-Host "Enter your choice (1-$($Options.Count)) or 'q' to quit: " -NoNewline -ForegroundColor Yellow
        
        $input = Read-Host
        
        # Handle quit
        if ($input -eq 'q' -or $input -eq 'quit' -or $input -eq 'exit') {
            return $null
        }
        
        # Handle numeric selection
        if ($input -match '^\d+$') {
            $index = [int]$input - 1
            if ($index -ge 0 -and $index -lt $Options.Count) {
                $selectedOption = $Options[$index]
                if ($selectedOption.Enabled) {
                    return if ($ReturnAction) { $selectedOption.Action } else { $selectedOption }
                } else {
                    Write-Host "That option is currently disabled." -ForegroundColor Red
                    Start-Sleep -Seconds 1
                }
            } else {
                Write-Host "Invalid selection. Please try again." -ForegroundColor Red
                Start-Sleep -Seconds 1
            }
        } else {
            Write-Host "Invalid input. Please enter a number or 'q' to quit." -ForegroundColor Red
            Start-Sleep -Seconds 1
        }
    }
}

function Show-FallbackMenu {
    <#
    .SYNOPSIS
        Shows minimal fallback menu for error conditions
    #>
    param(
        [string]$Title,
        [array]$Options,
        [switch]$ReturnAction
    )
    
    Write-Host "`n$Title" -ForegroundColor Cyan
    
    for ($i = 0; $i -lt $Options.Count; $i++) {
        $optionText = if ($Options[$i] -is [string]) { $Options[$i] } else { $Options[$i].Text ?? $Options[$i].ToString() }
        Write-Host "$($i + 1). $optionText"
    }
    
    do {
        $selection = Read-Host "`nSelect (1-$($Options.Count))"
        $index = $selection -as [int]
    } while ($index -lt 1 -or $index -gt $Options.Count)
    
    $selectedOption = $Options[$index - 1]
    
    if ($ReturnAction) {
        return if ($selectedOption -is [string]) { $selectedOption } else { $selectedOption.Action ?? $selectedOption.Text ?? $selectedOption.ToString() }
    } else {
        return $selectedOption
    }
}

function Show-MenuTitle {
    <#
    .SYNOPSIS
        Shows the menu title with optional search filter
    #>
    param([string]$Title, [string]$SearchFilter)
    
    $titleLine = "╔═══ $Title"
    if ($SearchFilter) {
        $titleLine += " (Filter: '$SearchFilter')"
    }
    $titleLine += " ═══╗"
    
    Write-Host $titleLine -ForegroundColor Cyan
    Write-Host ""
}

function Show-MenuOptions {
    <#
    .SYNOPSIS
        Shows menu options with selection highlighting
    #>
    param(
        [array]$Options,
        [int]$SelectedIndex,
        [switch]$ShowHelp,
        [bool]$ShowingHelp
    )
    
    for ($i = 0; $i -lt $Options.Count; $i++) {
        $option = $Options[$i]
        $isSelected = $i -eq $SelectedIndex
        
        # Build option display
        $prefix = if ($isSelected) { "►" } else { " " }
        $icon = if ($option.Icon) { "$($option.Icon) " } else { "" }
        $number = "[$($i + 1)]"
        
        # Color coding
        $color = if (-not $option.Enabled) {
            'DarkGray'
        } elseif ($isSelected) {
            'Yellow'
        } elseif ($option.ExpertOnly) {
            'Magenta'
        } else {
            'White'
        }
        
        # Show option
        Write-Host "  $prefix $number $icon$($option.Text)" -ForegroundColor $color
        
        # Show description if selected and help is enabled
        if ($isSelected -and $ShowHelp -and $option.Description -and -not $ShowingHelp) {
            Write-Host "      → $($option.Description)" -ForegroundColor Gray
        }
    }
}

function Show-MenuHelpPanel {
    <#
    .SYNOPSIS
        Shows detailed help panel for selected option
    #>
    param([hashtable]$Option, [bool]$ShowingHelp)
    
    if (-not $ShowingHelp) { return }
    
    Write-Host ""
    Write-Host "╔═══ Help ═══╗" -ForegroundColor Green
    Write-Host "Option: $($Option.Text)" -ForegroundColor White
    
    if ($Option.Description) {
        Write-Host "Description: $($Option.Description)" -ForegroundColor Gray
    }
    
    if ($Option.Category -ne "General") {
        Write-Host "Category: $($Option.Category)" -ForegroundColor Gray
    }
    
    if ($Option.Tier -ne "free") {
        Write-Host "Required Tier: $($Option.Tier)" -ForegroundColor Gray
    }
    
    if ($Option.ExpertOnly) {
        Write-Host "Expert Mode Required: Yes" -ForegroundColor Magenta
    }
    
    if (-not $Option.Enabled) {
        Write-Host "Status: Disabled" -ForegroundColor Red
    }
}

function Show-MenuFooter {
    <#
    .SYNOPSIS
        Shows menu footer with navigation instructions
    #>
    param([switch]$AllowSearch, [switch]$ShowHelp)
    
    Write-Host ""
    Write-Host "Navigation: ↑↓ Select, Enter Confirm, Esc Exit" -ForegroundColor DarkGray
    
    if ($ShowHelp) {
        Write-Host "Help: F1 Toggle Help Panel" -ForegroundColor DarkGray
    }
    
    if ($AllowSearch) {
        Write-Host "Search: / Start Search, Backspace Clear Filter" -ForegroundColor DarkGray
    }
}

function Read-MenuKey {
    <#
    .SYNOPSIS
        Reads a key press for menu navigation
    #>
    
    try {
        if ($Host.UI.RawUI -and (Get-Member -InputObject $Host.UI.RawUI -Name ReadKey -MemberType Method)) {
            return $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        } else {
            # Fallback to Read-Host for basic input
            $input = Read-Host "`nEnter selection"
            return @{ Character = $input; VirtualKeyCode = 0 }
        }
    } catch {
        # Ultimate fallback
        $input = Read-Host "`nEnter selection"
        return @{ Character = $input; VirtualKeyCode = 0 }
    }
}

function Handle-MenuKeyInput {
    <#
    .SYNOPSIS
        Handles keyboard input for menu navigation
    #>
    param(
        [object]$Key,
        [ref]$SelectedIndex,
        [array]$Options,
        [ref]$SearchFilter,
        [switch]$AllowSearch,
        [ref]$ShowingHelp
    )
    
    $action = @{ Type = 'None' }
    
    if ($Key.VirtualKeyCode) {
        # Enhanced key handling
        switch ($Key.VirtualKeyCode) {
            38 { # Up Arrow
                $SelectedIndex.Value = [Math]::Max(0, $SelectedIndex.Value - 1)
            }
            40 { # Down Arrow  
                $SelectedIndex.Value = [Math]::Min($Options.Count - 1, $SelectedIndex.Value + 1)
            }
            13 { # Enter
                $action.Type = 'Select'
            }
            27 { # Escape
                $action.Type = 'Exit'
            }
            112 { # F1
                $action.Type = 'Help'
            }
            47 { # / (slash)
                if ($AllowSearch) {
                    $action.Type = 'StartSearch'
                }
            }
            8 { # Backspace
                if ($AllowSearch -and $SearchFilter.Value) {
                    $SearchFilter.Value = $SearchFilter.Value.Substring(0, $SearchFilter.Value.Length - 1)
                    $action.Type = 'Refresh'
                }
            }
        }
    } else {
        # Basic character handling
        $char = $Key.Character
        
        if ($char -match '\d') {
            # Number selection
            $num = [int]$char
            if ($num -ge 1 -and $num -le $Options.Count) {
                $SelectedIndex.Value = $num - 1
                $action.Type = 'Select'
            }
        } elseif ($char -eq 'q' -or $char -eq 'x') {
            $action.Type = 'Exit'
        } elseif ($AllowSearch -and $char -match '[a-zA-Z ]') {
            $SearchFilter.Value += $char
            $action.Type = 'Refresh'
        }
    }
    
    return $action
}

function Filter-MenuOptions {
    <#
    .SYNOPSIS
        Filters menu options based on search criteria
    #>
    param([array]$Options, [string]$SearchFilter)
    
    if (-not $SearchFilter) {
        return $Options
    }
    
    return $Options | Where-Object {
        $_.Text -like "*$SearchFilter*" -or $_.Description -like "*$SearchFilter*" -or $_.Category -like "*$SearchFilter*"
    }
}

function Show-DisabledOptionMessage {
    <#
    .SYNOPSIS
        Shows message for disabled options
    #>
    param([hashtable]$Option)
    
    Write-Host ""
    Write-Host "⚠️ Option '$($Option.Text)' is currently disabled." -ForegroundColor Yellow
    
    if ($Option.Tier -ne "free") {
        Write-Host "This feature requires '$($Option.Tier)' license tier." -ForegroundColor Gray
    }
    
    if ($Option.ExpertOnly) {
        Write-Host "This feature requires Expert Mode to be enabled." -ForegroundColor Gray
    }
}
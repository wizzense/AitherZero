function Show-ContextMenu {
    <#
    .SYNOPSIS
        Shows an interactive context menu with fallback support
    .DESCRIPTION
        Displays a menu with arrow key navigation, falls back to numbered menu if terminal doesn't support it
    .PARAMETER Title
        Menu title
    .PARAMETER Options
        Array of menu options
    .PARAMETER ReturnAction
        Return the action instead of index
    .PARAMETER ForceClassic
        Force classic numbered menu mode
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Title,
        
        [Parameter(Mandatory)]
        [array]$Options,
        
        [Parameter()]
        [switch]$ReturnAction,
        
        [Parameter()]
        [switch]$ForceClassic
    )
    
    # Handle simple array or object array
    $displayOptions = @()
    $actions = @()
    
    foreach ($option in $Options) {
        if ($option -is [string]) {
            $displayOptions += $option
            $actions += $option
        } else {
            $displayOptions += $option.Text
            $actions += $option.Action ?? $option.Text
        }
    }
    
    # Determine UI mode - use classic if forced or if enhanced UI not available
    $useClassicUI = $ForceClassic -or -not (Test-EnhancedUICapability)
    
    if ($useClassicUI) {
        return Show-ClassicMenu -Title $Title -DisplayOptions $displayOptions -Actions $actions -ReturnAction:$ReturnAction
    } else {
        try {
            return Show-EnhancedMenu -Title $Title -DisplayOptions $displayOptions -Actions $actions -ReturnAction:$ReturnAction
        } catch {
            Write-Verbose "Enhanced menu failed, falling back to classic: $_"
            return Show-ClassicMenu -Title $Title -DisplayOptions $displayOptions -Actions $actions -ReturnAction:$ReturnAction
        }
    }
}

function Test-EnhancedUICapability {
    <#
    .SYNOPSIS
        Tests if the current terminal supports enhanced UI features
    #>
    try {
        # Test if we can access RawUI
        $null = $Host.UI.RawUI.WindowTitle
        $null = $Host.UI.RawUI.BackgroundColor
        
        # Test if ReadKey is available
        if (-not $Host.UI.RawUI.ReadKey) {
            return $false
        }
        
        # Check if we're in a non-interactive environment
        if (-not [Environment]::UserInteractive) {
            return $false
        }
        
        # Check for output redirection
        if ([Console]::IsOutputRedirected -or [Console]::IsInputRedirected) {
            return $false
        }
        
        return $true
    } catch {
        return $false
    }
}

function Show-EnhancedMenu {
    <#
    .SYNOPSIS
        Shows enhanced menu with arrow key navigation
    #>
    param(
        [string]$Title,
        [array]$DisplayOptions,
        [array]$Actions,
        [switch]$ReturnAction
    )
    
    $selectedIndex = 0
    $done = $false
    
    while (-not $done) {
        Clear-Host
        
        # Draw enhanced menu
        Write-Host "┌─ $Title ─────────────────────────────────────┐" -ForegroundColor Cyan
        
        for ($i = 0; $i -lt $DisplayOptions.Count; $i++) {
            if ($i -eq $selectedIndex) {
                Write-Host "│ " -NoNewline -ForegroundColor Cyan
                Write-Host "> $($DisplayOptions[$i])" -NoNewline -ForegroundColor Yellow -BackgroundColor DarkGray
                Write-Host (" " * (43 - $DisplayOptions[$i].Length)) -NoNewline -BackgroundColor DarkGray
                Write-Host " │" -ForegroundColor Cyan
            } else {
                Write-Host "│   $($DisplayOptions[$i])" -NoNewline -ForegroundColor White
                Write-Host (" " * (43 - $DisplayOptions[$i].Length)) -NoNewline
                Write-Host " │" -ForegroundColor Cyan
            }
        }
        
        Write-Host "└─────────────────────────────────────────────┘" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "[↑↓] Navigate  [Enter] Select  [Esc] Cancel" -ForegroundColor DarkGray
        
        # Get user input
        $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        
        switch ($key.VirtualKeyCode) {
            38 { # Up arrow
                $selectedIndex = ($selectedIndex - 1 + $DisplayOptions.Count) % $DisplayOptions.Count
            }
            40 { # Down arrow
                $selectedIndex = ($selectedIndex + 1) % $DisplayOptions.Count
            }
            13 { # Enter
                $done = $true
            }
            27 { # Escape
                return $null
            }
        }
    }
    
    if ($ReturnAction) {
        return $Actions[$selectedIndex]
    } else {
        return $selectedIndex
    }
}

function Show-ClassicMenu {
    <#
    .SYNOPSIS
        Shows classic numbered menu for limited terminals
    #>
    param(
        [string]$Title,
        [array]$DisplayOptions,
        [array]$Actions,
        [switch]$ReturnAction
    )
    
    do {
        Clear-Host
        
        # Draw classic menu
        Write-Host "" 
        Write-Host "=== $Title ===" -ForegroundColor Cyan
        Write-Host ""
        
        for ($i = 0; $i -lt $DisplayOptions.Count; $i++) {
            Write-Host "$($i + 1). $($DisplayOptions[$i])" -ForegroundColor White
        }
        
        Write-Host ""
        Write-Host "Enter your choice (1-$($DisplayOptions.Count), 0 to cancel): " -NoNewline -ForegroundColor Yellow
        
        $input = Read-Host
        
        if ($input -eq '0' -or $input -eq '') {
            return $null
        }
        
        if ($input -match '^\d+$') {
            $selection = [int]$input - 1
            if ($selection -ge 0 -and $selection -lt $DisplayOptions.Count) {
                if ($ReturnAction) {
                    return $Actions[$selection]
                } else {
                    return $selection
                }
            }
        }
        
        Write-Host "Invalid selection. Press any key to try again..." -ForegroundColor Red
        $null = Read-Host
        
    } while ($true)
}

function Confirm-Action {
    <#
    .SYNOPSIS
        Shows a confirmation prompt
    .DESCRIPTION
        Displays a yes/no confirmation dialog
    .PARAMETER Message
        Confirmation message
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message
    )
    
    Write-Host ""
    Write-Host $Message -ForegroundColor Yellow
    Write-Host "[Y]es  [N]o : " -NoNewline -ForegroundColor Cyan
    
    $response = Read-Host
    return $response -match '^[Yy]'
}
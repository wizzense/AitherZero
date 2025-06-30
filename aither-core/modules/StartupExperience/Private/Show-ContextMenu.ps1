function Show-ContextMenu {
    <#
    .SYNOPSIS
        Shows an interactive context menu
    .DESCRIPTION
        Displays a menu with arrow key navigation
    .PARAMETER Title
        Menu title
    .PARAMETER Options
        Array of menu options
    .PARAMETER ReturnAction
        Return the action instead of index
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Title,
        
        [Parameter(Mandatory)]
        [array]$Options,
        
        [Parameter()]
        [switch]$ReturnAction
    )
    
    $selectedIndex = 0
    $done = $false
    
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
    
    while (-not $done) {
        Clear-Host
        
        # Draw menu
        Write-Host "┌─ $Title ─────────────────────────────────────┐" -ForegroundColor Cyan
        
        for ($i = 0; $i -lt $displayOptions.Count; $i++) {
            if ($i -eq $selectedIndex) {
                Write-Host "│ " -NoNewline -ForegroundColor Cyan
                Write-Host "> $($displayOptions[$i])" -NoNewline -ForegroundColor Yellow -BackgroundColor DarkGray
                Write-Host (" " * (43 - $displayOptions[$i].Length)) -NoNewline -BackgroundColor DarkGray
                Write-Host " │" -ForegroundColor Cyan
            } else {
                Write-Host "│   $($displayOptions[$i])" -NoNewline -ForegroundColor White
                Write-Host (" " * (43 - $displayOptions[$i].Length)) -NoNewline
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
                $selectedIndex = ($selectedIndex - 1 + $displayOptions.Count) % $displayOptions.Count
            }
            40 { # Down arrow
                $selectedIndex = ($selectedIndex + 1) % $displayOptions.Count
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
        return $actions[$selectedIndex]
    } else {
        return $selectedIndex
    }
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
function Initialize-TerminalUI {
    <#
    .SYNOPSIS
        Initializes the terminal UI environment
    .DESCRIPTION
        Sets up the terminal for rich UI experience
    #>
    [CmdletBinding()]
    param()
    
    try {
        # Save current state (with error handling)
        try {
            $script:OriginalWindowTitle = $Host.UI.RawUI.WindowTitle
        } catch {
            Write-Verbose "Could not access WindowTitle: $_"
            $script:OriginalWindowTitle = $null
        }
        
        try {
            $script:OriginalBackgroundColor = $Host.UI.RawUI.BackgroundColor
            $script:OriginalForegroundColor = $Host.UI.RawUI.ForegroundColor
        } catch {
            Write-Verbose "Could not access terminal colors: $_"
        }
        
        # Set new window title (with error handling)
        try {
            if ($script:OriginalWindowTitle -ne $null) {
                $Host.UI.RawUI.WindowTitle = "AitherZero Interactive Mode"
            }
        } catch {
            Write-Verbose "Could not set WindowTitle: $_"
        }
        
        # Enable UTF-8 for better character support
        if ($IsWindows) {
            try {
                $null = [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
            } catch {
                Write-Verbose "Could not set console encoding: $_"
            }
        }
        
        # Clear screen for fresh start
        try {
            Clear-Host
        } catch {
            Write-Verbose "Could not clear host: $_"
        }
        
        $script:TerminalUIEnabled = $true
        
    } catch {
        Write-Warning "Could not initialize terminal UI: $_"
    }
}

function Reset-TerminalUI {
    <#
    .SYNOPSIS
        Resets the terminal to original state
    .DESCRIPTION
        Restores terminal settings to their original values
    #>
    [CmdletBinding()]
    param()
    
    try {
        if ($script:TerminalUIEnabled) {
            # Restore original settings (with error handling)
            if ($script:OriginalWindowTitle) {
                try {
                    $Host.UI.RawUI.WindowTitle = $script:OriginalWindowTitle
                } catch {
                    Write-Verbose "Could not restore WindowTitle: $_"
                }
            }
            if ($script:OriginalBackgroundColor) {
                try {
                    $Host.UI.RawUI.BackgroundColor = $script:OriginalBackgroundColor
                } catch {
                    Write-Verbose "Could not restore BackgroundColor: $_"
                }
            }
            if ($script:OriginalForegroundColor) {
                try {
                    $Host.UI.RawUI.ForegroundColor = $script:OriginalForegroundColor
                } catch {
                    Write-Verbose "Could not restore ForegroundColor: $_"
                }
            }
            
            $script:TerminalUIEnabled = $false
        }
    } catch {
        Write-Warning "Could not reset terminal UI: $_"
    }
}
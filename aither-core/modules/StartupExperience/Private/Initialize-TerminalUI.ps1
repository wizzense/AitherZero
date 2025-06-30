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
        # Save current state
        $script:OriginalWindowTitle = $Host.UI.RawUI.WindowTitle
        $script:OriginalBackgroundColor = $Host.UI.RawUI.BackgroundColor
        $script:OriginalForegroundColor = $Host.UI.RawUI.ForegroundColor
        
        # Set new window title
        $Host.UI.RawUI.WindowTitle = "AitherZero Interactive Mode"
        
        # Enable UTF-8 for better character support
        if ($IsWindows) {
            $null = [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
        }
        
        # Clear screen for fresh start
        Clear-Host
        
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
            # Restore original settings
            if ($script:OriginalWindowTitle) {
                $Host.UI.RawUI.WindowTitle = $script:OriginalWindowTitle
            }
            if ($script:OriginalBackgroundColor) {
                $Host.UI.RawUI.BackgroundColor = $script:OriginalBackgroundColor
            }
            if ($script:OriginalForegroundColor) {
                $Host.UI.RawUI.ForegroundColor = $script:OriginalForegroundColor
            }
            
            $script:TerminalUIEnabled = $false
        }
    } catch {
        Write-Warning "Could not reset terminal UI: $_"
    }
}
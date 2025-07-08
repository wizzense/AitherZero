function Initialize-TerminalUI {
    <#
    .SYNOPSIS
        Initializes the terminal UI environment with enhanced capabilities
    .DESCRIPTION
        Sets up the terminal for rich UI experience with fallback support and theme options
    .PARAMETER Theme
        UI theme to apply (Dark, Light, HighContrast, Auto)
    .PARAMETER ForceClassic
        Force classic mode regardless of terminal capabilities
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateSet('Dark', 'Light', 'HighContrast', 'Auto')]
        [string]$Theme = 'Auto',

        [Parameter()]
        [switch]$ForceClassic
    )

    try {
        # Detect UI capabilities
        $uiCapabilities = Get-TerminalCapabilities
        $script:UICapabilities = $uiCapabilities

        # Determine UI mode
        if ($ForceClassic -or -not $uiCapabilities.SupportsEnhancedUI) {
            $script:UIMode = 'Classic'
            Write-Verbose "Using classic UI mode"
        } else {
            $script:UIMode = 'Enhanced'
            Write-Verbose "Using enhanced UI mode"
        }

        # Save current state (with comprehensive error handling)
        $script:OriginalState = @{}

        try {
            $script:OriginalState.WindowTitle = $Host.UI.RawUI.WindowTitle
        } catch {
            Write-Verbose "Could not access WindowTitle: $_"
            $script:OriginalState.WindowTitle = $null
        }

        try {
            $script:OriginalState.BackgroundColor = $Host.UI.RawUI.BackgroundColor
            $script:OriginalState.ForegroundColor = $Host.UI.RawUI.ForegroundColor
        } catch {
            Write-Verbose "Could not access terminal colors: $_"
        }

        try {
            $script:OriginalState.CursorSize = $Host.UI.RawUI.CursorSize
        } catch {
            Write-Verbose "Could not access cursor size: $_"
        }

        # Apply theme if enhanced UI is supported
        if ($script:UIMode -eq 'Enhanced') {
            Apply-UITheme -Theme $Theme -Capabilities $uiCapabilities
        }

        # Set window title
        try {
            if ($script:OriginalState.WindowTitle -ne $null) {
                $Host.UI.RawUI.WindowTitle = "AitherZero Interactive Mode - $($script:UIMode)"
            }
        } catch {
            Write-Verbose "Could not set WindowTitle: $_"
        }

        # Configure console encoding for better character support
        if ($IsWindows -and $uiCapabilities.SupportsUTF8) {
            try {
                $null = [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
                $null = [Console]::InputEncoding = [System.Text.Encoding]::UTF8
                Write-Verbose "UTF-8 encoding enabled"
            } catch {
                Write-Verbose "Could not set console encoding: $_"
            }
        }

        # Initialize cursor (hide in enhanced mode)
        if ($script:UIMode -eq 'Enhanced' -and $uiCapabilities.SupportsCursorControl) {
            try {
                $Host.UI.RawUI.CursorSize = 0
            } catch {
                Write-Verbose "Could not hide cursor: $_"
            }
        }

        # Clear screen for fresh start
        try {
            Clear-Host
        } catch {
            Write-Verbose "Could not clear host: $_"
        }

        $script:TerminalUIEnabled = $true

        # Store initialization info
        $script:UIInitInfo = @{
            Mode = $script:UIMode
            Theme = $Theme
            Capabilities = $uiCapabilities
            InitTime = Get-Date
        }

        Write-Verbose "Terminal UI initialized successfully in $($script:UIMode) mode"

    } catch {
        Write-Warning "Could not initialize terminal UI: $_"
        $script:TerminalUIEnabled = $false
        $script:UIMode = 'Classic'
    }
}

function Get-TerminalCapabilities {
    <#
    .SYNOPSIS
        Detects terminal capabilities for UI optimization
    #>
    [CmdletBinding()]
    param()

    $capabilities = @{
        SupportsEnhancedUI = $false
        SupportsColors = $false
        SupportsUTF8 = $false
        SupportsCursorControl = $false
        SupportsReadKey = $false
        Width = 80
        Height = 25
        Platform = 'Unknown'
    }

    try {
        # Platform detection
        if ($IsWindows) { $capabilities.Platform = 'Windows' }
        elseif ($IsLinux) { $capabilities.Platform = 'Linux' }
        elseif ($IsMacOS) { $capabilities.Platform = 'macOS' }

        # Test RawUI access
        try {
            $null = $Host.UI.RawUI.WindowTitle
            $capabilities.SupportsEnhancedUI = $true
        } catch {
            Write-Verbose "RawUI not available: $_"
        }

        # Test color support
        try {
            $null = $Host.UI.RawUI.BackgroundColor
            $null = $Host.UI.RawUI.ForegroundColor
            $capabilities.SupportsColors = $true
        } catch {
            Write-Verbose "Color support not available: $_"
        }

        # Test cursor control
        try {
            $null = $Host.UI.RawUI.CursorSize
            $capabilities.SupportsCursorControl = $true
        } catch {
            Write-Verbose "Cursor control not available: $_"
        }

        # Test ReadKey capability
        try {
            $readKeyMethod = $Host.UI.RawUI.GetType().GetMethod('ReadKey')
            $capabilities.SupportsReadKey = $null -ne $readKeyMethod
        } catch {
            Write-Verbose "ReadKey not available: $_"
        }

        # Get terminal dimensions
        try {
            $capabilities.Width = $Host.UI.RawUI.WindowSize.Width
            $capabilities.Height = $Host.UI.RawUI.WindowSize.Height
        } catch {
            Write-Verbose "Could not get terminal dimensions: $_"
        }

        # UTF-8 support check
        $capabilities.SupportsUTF8 = $capabilities.Platform -in @('Linux', 'macOS') -or
                                     ($capabilities.Platform -eq 'Windows' -and $PSVersionTable.PSVersion.Major -ge 6)

        # Overall enhanced UI support requires multiple capabilities
        $capabilities.SupportsEnhancedUI = $capabilities.SupportsEnhancedUI -and
                                          $capabilities.SupportsColors -and
                                          $capabilities.SupportsReadKey -and
                                          -not [Console]::IsInputRedirected -and
                                          -not [Console]::IsOutputRedirected

    } catch {
        Write-Verbose "Error detecting capabilities: $_"
    }

    return $capabilities
}

function Apply-UITheme {
    <#
    .SYNOPSIS
        Applies a UI theme based on terminal capabilities
    #>
    param(
        [string]$Theme,
        [hashtable]$Capabilities
    )

    if (-not $Capabilities.SupportsColors) {
        Write-Verbose "Colors not supported, skipping theme application"
        return
    }

    try {
        # Auto-detect theme based on system
        if ($Theme -eq 'Auto') {
            $Theme = if ($Capabilities.Platform -eq 'Windows') { 'Dark' } else { 'Dark' }
        }

        switch ($Theme) {
            'Dark' {
                # Dark theme is default for most terminals
                Write-Verbose "Applied Dark theme"
            }
            'Light' {
                try {
                    $Host.UI.RawUI.BackgroundColor = 'White'
                    $Host.UI.RawUI.ForegroundColor = 'Black'
                    Write-Verbose "Applied Light theme"
                } catch {
                    Write-Verbose "Could not apply Light theme: $_"
                }
            }
            'HighContrast' {
                try {
                    $Host.UI.RawUI.BackgroundColor = 'Black'
                    $Host.UI.RawUI.ForegroundColor = 'White'
                    Write-Verbose "Applied HighContrast theme"
                } catch {
                    Write-Verbose "Could not apply HighContrast theme: $_"
                }
            }
        }

        $script:CurrentTheme = $Theme

    } catch {
        Write-Verbose "Error applying theme: $_"
    }
}

function Reset-TerminalUI {
    <#
    .SYNOPSIS
        Resets the terminal to original state
    .DESCRIPTION
        Restores terminal settings to their original values with comprehensive cleanup
    #>
    [CmdletBinding()]
    param()

    try {
        if ($script:TerminalUIEnabled -and $script:OriginalState) {
            Write-Verbose "Resetting terminal UI to original state"

            # Restore window title
            if ($script:OriginalState.WindowTitle) {
                try {
                    $Host.UI.RawUI.WindowTitle = $script:OriginalState.WindowTitle
                    Write-Verbose "Window title restored"
                } catch {
                    Write-Verbose "Could not restore WindowTitle: $_"
                }
            }

            # Restore colors
            if ($script:OriginalState.BackgroundColor) {
                try {
                    $Host.UI.RawUI.BackgroundColor = $script:OriginalState.BackgroundColor
                    Write-Verbose "Background color restored"
                } catch {
                    Write-Verbose "Could not restore BackgroundColor: $_"
                }
            }

            if ($script:OriginalState.ForegroundColor) {
                try {
                    $Host.UI.RawUI.ForegroundColor = $script:OriginalState.ForegroundColor
                    Write-Verbose "Foreground color restored"
                } catch {
                    Write-Verbose "Could not restore ForegroundColor: $_"
                }
            }

            # Restore cursor
            if ($script:OriginalState.CursorSize) {
                try {
                    $Host.UI.RawUI.CursorSize = $script:OriginalState.CursorSize
                    Write-Verbose "Cursor size restored"
                } catch {
                    Write-Verbose "Could not restore CursorSize: $_"
                }
            }

            # Clear script variables
            $script:TerminalUIEnabled = $false
            $script:OriginalState = $null
            $script:UICapabilities = $null
            $script:UIMode = $null
            $script:CurrentTheme = $null
            $script:UIInitInfo = $null

            Write-Verbose "Terminal UI reset complete"
        }
    } catch {
        Write-Warning "Could not reset terminal UI: $_"
    }
}

function Get-UIStatus {
    <#
    .SYNOPSIS
        Gets current UI status and capabilities
    #>
    [CmdletBinding()]
    param()

    return [PSCustomObject]@{
        Enabled = $script:TerminalUIEnabled ?? $false
        Mode = $script:UIMode ?? 'Unknown'
        Theme = $script:CurrentTheme ?? 'Unknown'
        Capabilities = $script:UICapabilities ?? @{}
        InitInfo = $script:UIInitInfo ?? @{}
    }
}

function Show-UIDebugInfo {
    <#
    .SYNOPSIS
        Shows detailed UI debug information
    #>
    [CmdletBinding()]
    param()

    $status = Get-UIStatus

    Write-Host ""
    Write-Host "=== Terminal UI Debug Information ===" -ForegroundColor Cyan
    Write-Host "Enabled: $($status.Enabled)" -ForegroundColor White
    Write-Host "Mode: $($status.Mode)" -ForegroundColor White
    Write-Host "Theme: $($status.Theme)" -ForegroundColor White
    Write-Host ""

    if ($status.Capabilities) {
        Write-Host "Capabilities:" -ForegroundColor Yellow
        $status.Capabilities.GetEnumerator() | Sort-Object Key | ForEach-Object {
            Write-Host "  $($_.Key): $($_.Value)" -ForegroundColor Gray
        }
    }

    Write-Host ""

    if ($status.InitInfo.InitTime) {
        $uptime = (Get-Date) - $status.InitInfo.InitTime
        Write-Host "UI Uptime: $($uptime.ToString('hh\:mm\:ss'))" -ForegroundColor Green
    }

    Write-Host ""
}

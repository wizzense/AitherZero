function Initialize-TerminalUI {
    <#
    .SYNOPSIS
        Initializes the terminal UI environment with enhanced capabilities
    .DESCRIPTION
        Sets up the terminal for rich UI experience with fallback support and theme options.
        This is an enhanced version combining capabilities from both SetupWizard and StartupExperience.
    .PARAMETER Theme
        UI theme to apply (Dark, Light, HighContrast, Auto)
    .PARAMETER ForceClassic
        Force classic mode regardless of terminal capabilities
    .PARAMETER Minimal
        Use minimal UI setup for performance
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateSet('Dark', 'Light', 'HighContrast', 'Auto')]
        [string]$Theme = 'Auto',
        
        [Parameter()]
        [switch]$ForceClassic,
        
        [Parameter()]
        [switch]$Minimal
    )
    
    try {
        Write-CustomLog -Level 'INFO' -Message "Initializing Terminal UI (Theme: $Theme)" -Source 'UserExperience'
        
        # Detect UI capabilities
        $uiCapabilities = Get-TerminalCapabilities
        $script:UICapabilities = $uiCapabilities
        
        # Store in module state
        $script:UserExperienceState.UICapabilities = $uiCapabilities
        
        # Determine UI mode based on capabilities and preferences
        if ($ForceClassic -or $Minimal -or -not $uiCapabilities.SupportsEnhancedUI) {
            $script:UIMode = if ($Minimal) { 'Minimal' } else { 'Classic' }
            Write-Verbose "Using $($script:UIMode) UI mode"
        } else {
            $script:UIMode = 'Enhanced'
            Write-Verbose "Using Enhanced UI mode"
        }
        
        # Save current terminal state for restoration
        $script:OriginalState = Save-TerminalState
        
        # Apply theme if enhanced UI is supported
        if ($script:UIMode -eq 'Enhanced') {
            Apply-UITheme -Theme $Theme -Capabilities $uiCapabilities
        }
        
        # Set window title with session information
        Set-WindowTitle -Mode $script:UIMode
        
        # Configure console encoding for better character support
        Configure-ConsoleEncoding -Capabilities $uiCapabilities
        
        # Initialize cursor settings
        Initialize-CursorSettings -Mode $script:UIMode -Capabilities $uiCapabilities
        
        # Set up keyboard handling
        Initialize-KeyboardHandling -Capabilities $uiCapabilities
        
        # Clear screen for fresh start unless minimal mode
        if (-not $Minimal) {
            Clear-TerminalDisplay
        }
        
        # Mark UI as enabled
        $script:TerminalUIEnabled = $true
        
        # Store initialization info for diagnostics
        $script:UIInitInfo = @{
            Mode = $script:UIMode
            Theme = $Theme
            Capabilities = $uiCapabilities
            InitTime = Get-Date
            Minimal = $Minimal
            SessionId = $script:UserExperienceState.SessionId
        }
        
        Write-CustomLog -Level 'INFO' -Message "Terminal UI initialized successfully in $($script:UIMode) mode" -Source 'UserExperience'
        
        return @{
            Success = $true
            Mode = $script:UIMode
            Capabilities = $uiCapabilities
            Theme = $Theme
        }
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to initialize terminal UI: $_" -Source 'UserExperience'
        
        # Fallback to basic mode
        $script:TerminalUIEnabled = $false
        $script:UIMode = 'Fallback'
        
        return @{
            Success = $false
            Mode = 'Fallback'
            Error = $_.Exception.Message
        }
    }
}

function Get-TerminalCapabilities {
    <#
    .SYNOPSIS
        Detects comprehensive terminal capabilities for UI optimization
    .DESCRIPTION
        Enhanced capability detection that combines and improves upon the original
        implementations from both SetupWizard and StartupExperience
    #>
    [CmdletBinding()]
    param()
    
    $capabilities = @{
        SupportsEnhancedUI = $false
        SupportsColors = $false
        SupportsUTF8 = $false
        SupportsCursorControl = $false
        SupportsReadKey = $false
        SupportsWindowTitle = $false
        SupportsClearing = $false
        SupportsPositioning = $false
        Width = 80
        Height = 25
        Platform = 'Unknown'
        TerminalType = 'Unknown'
        ColorDepth = 'Unknown'
        IsInteractive = $false
        HasMouse = $false
    }
    
    try {
        # Platform detection
        if ($IsWindows) { $capabilities.Platform = 'Windows' }
        elseif ($IsLinux) { $capabilities.Platform = 'Linux' }
        elseif ($IsMacOS) { $capabilities.Platform = 'macOS' }
        
        # Check if running interactively
        $capabilities.IsInteractive = -not [Console]::IsInputRedirected -and 
                                      -not [Console]::IsOutputRedirected -and
                                      -not [Console]::IsErrorRedirected
        
        # Terminal type detection
        $capabilities.TerminalType = Get-TerminalType
        
        # Test RawUI access
        try {
            $null = $Host.UI.RawUI.WindowTitle
            $capabilities.SupportsWindowTitle = $true
            $capabilities.SupportsEnhancedUI = $true
        } catch {
            Write-Verbose "RawUI WindowTitle not available: $_"
        }
        
        # Test color support
        try {
            $null = $Host.UI.RawUI.BackgroundColor
            $null = $Host.UI.RawUI.ForegroundColor
            $capabilities.SupportsColors = $true
            
            # Detect color depth
            $capabilities.ColorDepth = Get-ColorDepth
        } catch {
            Write-Verbose "Color support not available: $_"
        }
        
        # Test cursor control
        try {
            $currentSize = $Host.UI.RawUI.CursorSize
            $capabilities.SupportsCursorControl = $true
        } catch {
            Write-Verbose "Cursor control not available: $_"
        }
        
        # Test positioning capabilities
        try {
            $null = $Host.UI.RawUI.CursorPosition
            $capabilities.SupportsPositioning = $true
        } catch {
            Write-Verbose "Cursor positioning not available: $_"
        }
        
        # Test ReadKey capability
        try {
            $readKeyMethod = $Host.UI.RawUI.GetType().GetMethod('ReadKey')
            $capabilities.SupportsReadKey = $null -ne $readKeyMethod
        } catch {
            Write-Verbose "ReadKey not available: $_"
        }
        
        # Test clearing capability
        try {
            $clearMethod = $Host.GetType().GetMethod('Clear') ?? 
                          $Host.UI.GetType().GetMethod('Clear')
            $capabilities.SupportsClearing = $null -ne $clearMethod
        } catch {
            Write-Verbose "Screen clearing not available: $_"
        }
        
        # Get terminal dimensions
        try {
            $size = $Host.UI.RawUI.WindowSize
            $capabilities.Width = $size.Width
            $capabilities.Height = $size.Height
            
            # Validate dimensions
            if ($capabilities.Width -le 0 -or $capabilities.Width -gt 500) {
                $capabilities.Width = 80
            }
            if ($capabilities.Height -le 0 -or $capabilities.Height -gt 200) {
                $capabilities.Height = 25
            }
        } catch {
            Write-Verbose "Could not get terminal dimensions: $_"
        }
        
        # UTF-8 support detection
        $capabilities.SupportsUTF8 = Test-UTF8Support -Platform $capabilities.Platform
        
        # Mouse support detection (basic)
        $capabilities.HasMouse = Test-MouseSupport -TerminalType $capabilities.TerminalType
        
        # Overall enhanced UI support requires multiple capabilities
        $capabilities.SupportsEnhancedUI = $capabilities.SupportsEnhancedUI -and 
                                          $capabilities.SupportsColors -and 
                                          $capabilities.SupportsReadKey -and 
                                          $capabilities.IsInteractive -and
                                          $capabilities.Width -gt 40 -and
                                          $capabilities.Height -gt 10
        
        Write-Verbose "Terminal capabilities detected: Enhanced=$($capabilities.SupportsEnhancedUI), Colors=$($capabilities.SupportsColors), Interactive=$($capabilities.IsInteractive)"
        
    } catch {
        Write-Verbose "Error detecting terminal capabilities: $_"
    }
    
    return $capabilities
}

function Get-TerminalType {
    <#
    .SYNOPSIS
        Detects the type of terminal being used
    #>
    
    # Check environment variables
    $termType = $env:TERM
    if ($termType) {
        return $termType
    }
    
    # Check for specific terminal indicators
    if ($env:WT_SESSION) {
        return 'Windows Terminal'
    }
    
    if ($env:VSCODE_INJECTION) {
        return 'VS Code Terminal'
    }
    
    if ($env:TERM_PROGRAM) {
        return $env:TERM_PROGRAM
    }
    
    # Platform-specific defaults
    if ($IsWindows) {
        if ($Host.Name -eq 'Windows PowerShell ISE Host') {
            return 'PowerShell ISE'
        }
        return 'PowerShell Console'
    } elseif ($IsLinux) {
        return 'Linux Terminal'
    } elseif ($IsMacOS) {
        return 'macOS Terminal'
    }
    
    return 'Unknown'
}

function Get-ColorDepth {
    <#
    .SYNOPSIS
        Detects terminal color depth
    #>
    
    # Check for 24-bit color support
    if ($env:COLORTERM -eq 'truecolor' -or $env:COLORTERM -eq '24bit') {
        return '24-bit'
    }
    
    # Check TERM environment variable
    $term = $env:TERM
    if ($term -like '*256color*' -or $term -like '*256*') {
        return '256-color'
    }
    
    if ($term -like '*color*') {
        return '16-color'
    }
    
    # Basic fallback
    try {
        $null = $Host.UI.RawUI.BackgroundColor
        return '16-color'
    } catch {
        return 'Monochrome'
    }
}

function Test-UTF8Support {
    <#
    .SYNOPSIS
        Tests UTF-8 support in the terminal
    #>
    param([string]$Platform)
    
    # Modern terminals generally support UTF-8
    if ($Platform -in @('Linux', 'macOS')) {
        return $true
    }
    
    # Windows UTF-8 support depends on version and terminal
    if ($Platform -eq 'Windows') {
        # PowerShell 6+ has better UTF-8 support
        if ($PSVersionTable.PSVersion.Major -ge 6) {
            return $true
        }
        
        # Windows Terminal supports UTF-8
        if ($env:WT_SESSION) {
            return $true
        }
        
        # Check console code page
        try {
            $codePage = [Console]::OutputEncoding.CodePage
            return $codePage -eq 65001  # UTF-8 code page
        } catch {
            return $false
        }
    }
    
    return $false
}

function Test-MouseSupport {
    <#
    .SYNOPSIS
        Tests basic mouse support detection
    #>
    param([string]$TerminalType)
    
    # Mouse support is limited in PowerShell console applications
    # Most PowerShell hosts don't expose mouse events
    
    $mouseCapableTerminals = @(
        'Windows Terminal',
        'VS Code Terminal',
        'xterm',
        'gnome-terminal',
        'Terminal.app'
    )
    
    return $TerminalType -in $mouseCapableTerminals
}

function Save-TerminalState {
    <#
    .SYNOPSIS
        Saves current terminal state for restoration
    #>
    
    $state = @{}
    
    try {
        $state.WindowTitle = $Host.UI.RawUI.WindowTitle
    } catch {
        Write-Verbose "Could not access WindowTitle: $_"
        $state.WindowTitle = $null
    }
    
    try {
        $state.BackgroundColor = $Host.UI.RawUI.BackgroundColor
        $state.ForegroundColor = $Host.UI.RawUI.ForegroundColor
    } catch {
        Write-Verbose "Could not access terminal colors: $_"
    }
    
    try {
        $state.CursorSize = $Host.UI.RawUI.CursorSize
    } catch {
        Write-Verbose "Could not access cursor size: $_"
    }
    
    try {
        $state.BufferSize = $Host.UI.RawUI.BufferSize
    } catch {
        Write-Verbose "Could not access buffer size: $_"
    }
    
    return $state
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
        # Auto-detect theme based on system preferences
        if ($Theme -eq 'Auto') {
            $Theme = Get-AutoTheme -Capabilities $Capabilities
        }
        
        # Apply theme
        switch ($Theme) {
            'Dark' {
                # Dark theme is typically the default
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

function Get-AutoTheme {
    <#
    .SYNOPSIS
        Auto-detects the best theme for the current environment
    #>
    param([hashtable]$Capabilities)
    
    # Check user preferences first
    $userPrefs = $script:UserExperienceState.UserPreferences
    if ($userPrefs -and $userPrefs.Theme -and $userPrefs.Theme -ne 'Auto') {
        return $userPrefs.Theme
    }
    
    # Check accessibility settings
    if ($userPrefs -and $userPrefs.Accessibility.HighContrast) {
        return 'HighContrast'
    }
    
    # Platform-specific defaults
    if ($Capabilities.Platform -eq 'Windows') {
        # Check Windows theme (basic detection)
        try {
            $registryPath = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize'
            $appsUseLightTheme = Get-ItemProperty -Path $registryPath -Name 'AppsUseLightTheme' -ErrorAction SilentlyContinue
            if ($appsUseLightTheme -and $appsUseLightTheme.AppsUseLightTheme -eq 1) {
                return 'Light'
            }
        } catch {
            Write-Verbose "Could not detect Windows theme: $_"
        }
    }
    
    # Default to dark theme
    return 'Dark'
}

function Set-WindowTitle {
    <#
    .SYNOPSIS
        Sets the window title with session information
    #>
    param([string]$Mode)
    
    try {
        if ($script:OriginalState.WindowTitle -ne $null) {
            $sessionId = $script:UserExperienceState.SessionId.Substring(0, 8)
            $title = "AitherZero - $Mode Mode - Session: $sessionId"
            $Host.UI.RawUI.WindowTitle = $title
            Write-Verbose "Window title set to: $title"
        }
    } catch {
        Write-Verbose "Could not set window title: $_"
    }
}

function Configure-ConsoleEncoding {
    <#
    .SYNOPSIS
        Configures console encoding for better character support
    #>
    param([hashtable]$Capabilities)
    
    if ($Capabilities.Platform -eq 'Windows' -and $Capabilities.SupportsUTF8) {
        try {
            [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
            [Console]::InputEncoding = [System.Text.Encoding]::UTF8
            Write-Verbose "UTF-8 encoding enabled"
        } catch {
            Write-Verbose "Could not set console encoding: $_"
        }
    }
}

function Initialize-CursorSettings {
    <#
    .SYNOPSIS
        Initializes cursor settings based on UI mode
    #>
    param([string]$Mode, [hashtable]$Capabilities)
    
    if ($Mode -eq 'Enhanced' -and $Capabilities.SupportsCursorControl) {
        try {
            # Hide cursor for enhanced UI
            $Host.UI.RawUI.CursorSize = 0
            Write-Verbose "Cursor hidden for enhanced UI"
        } catch {
            Write-Verbose "Could not modify cursor: $_"
        }
    }
}

function Initialize-KeyboardHandling {
    <#
    .SYNOPSIS
        Sets up keyboard handling for enhanced UI
    #>
    param([hashtable]$Capabilities)
    
    # Basic keyboard handling setup
    # More advanced keyboard handling would be implemented here
    # for specific UI scenarios
    
    if ($Capabilities.SupportsReadKey) {
        Write-Verbose "Advanced keyboard handling available"
        $script:KeyboardHandlingEnabled = $true
    } else {
        Write-Verbose "Basic keyboard handling only"
        $script:KeyboardHandlingEnabled = $false
    }
}

function Clear-TerminalDisplay {
    <#
    .SYNOPSIS
        Clears the terminal display safely
    #>
    
    try {
        if (-not [System.Console]::IsInputRedirected) {
            Clear-Host
        }
    } catch {
        Write-Verbose "Could not clear terminal display: $_"
    }
}
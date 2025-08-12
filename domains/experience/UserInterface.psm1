#Requires -Version 7.0
<#
.SYNOPSIS
    AitherZero Core UI Module
.DESCRIPTION
    Provides a unified, modular UI system for all AitherZero components.
    Supports interactive menus, progress tracking, notifications, and more.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Module state
$script:UIState = @{
    Theme = 'Default'
    Colors = @{}
    CurrentMenu = $null
    History = @()
    ProgressJobs = @{}
    EnableEmoji = $true
    SupportsEmoji = $false
    MenuStyle = 'Interactive'
    ProgressBarStyle = 'Classic'
}

# Default color themes
$script:Themes = @{
    Default = @{
        Primary = 'Cyan'
        Secondary = 'Blue'
        Success = 'Green'
        Warning = 'Yellow'
        Error = 'Red'
        Info = 'White'
        Muted = 'DarkGray'
        Highlight = 'Magenta'
        MenuBorder = 'Cyan'  # Changed from DarkCyan
        MenuText = 'White'
        MenuSelected = 'Yellow'
        ProgressBar = 'Green'
        ProgressBackground = 'DarkGray'
    }
    Dark = @{
        Primary = 'DarkCyan'
        Secondary = 'DarkBlue'
        Success = 'DarkGreen'
        Warning = 'DarkYellow'
        Error = 'DarkRed'
        Info = 'Gray'
        Muted = 'DarkGray'
        Highlight = 'DarkMagenta'
        MenuBorder = 'DarkGray'
        MenuText = 'Gray'
        MenuSelected = 'White'
        ProgressBar = 'DarkGreen'
        ProgressBackground = 'Black'
    }
    Light = @{
        Primary = 'Blue'
        Secondary = 'Cyan'
        Success = 'Green'
        Warning = 'Yellow'
        Error = 'Red'
        Info = 'Black'
        Muted = 'Gray'
        Highlight = 'Magenta'
        MenuBorder = 'Blue'
        MenuText = 'Black'
        MenuSelected = 'Blue'
        ProgressBar = 'Blue'
        ProgressBackground = 'Gray'
    }
}

# Initialize with default theme
$script:UIState.Colors = $script:Themes.Default

# Logging helper for UserInterface module
function Write-UILog {
    param(
        [string]$Level = 'Information',
        [string]$Message,
        [hashtable]$Data = @{}
    )

    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Level $Level -Message $Message -Source "UserInterface" -Data $Data
    } else {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $color = @{
            'Error' = 'Red'
            'Warning' = 'Yellow'
            'Information' = 'White'
            'Debug' = 'Gray'
        }[$Level]
        Write-Host "[$timestamp] [$Level] [UserInterface] $Message" -ForegroundColor $color
    }
}

# Log module initialization (only once per session)
if (-not (Get-Variable -Name 'AitherZeroUIInitialized' -Scope Global -ErrorAction SilentlyContinue)) {
    Write-UILog -Message "User interface module initialized" -Data @{
        Theme = $script:UIState.Theme
        EnableEmoji = $script:UIState.EnableEmoji
        MenuStyle = $script:UIState.MenuStyle
        ProgressBarStyle = $script:UIState.ProgressBarStyle
        Features = @('Emoji', 'Spinners', 'ProgressBars', 'Menus', 'Prompts')
    }
    $global:AitherZeroUIInitialized = $true
}

# Import configuration module (lazy-loaded)
$script:ProjectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$script:ConfigModule = Join-Path $script:ProjectRoot "domains/configuration/Configuration.psm1"
$script:ConfigModuleLoaded = $false
$script:UIInitialized = $false

# New interactive UI system modules
$script:InteractiveUIAvailable = $false
$script:CoreUIPath = Join-Path $PSScriptRoot "Core"
$script:ComponentsPath = Join-Path $PSScriptRoot "Components"

function Import-ConfigurationModule {
    <#
    .SYNOPSIS
        Lazy-load the configuration module only when needed
    #>
    if (-not $script:ConfigModuleLoaded -and (Test-Path $script:ConfigModule)) {
        Import-Module $script:ConfigModule -Force -ErrorAction SilentlyContinue
        $script:ConfigModuleLoaded = $true
    }
}

function Ensure-UIInitialized {
    <#
    .SYNOPSIS
        Ensure UI is initialized before use
    #>
    if (-not $script:UIInitialized) {
        # Initialize colors if not already done
        if (-not $script:UIState.Colors -or $script:UIState.Colors.Count -eq 0) {
            $script:UIState.Colors = $script:Themes.Default
        }
        $script:UIInitialized = $true
    }
}

function Initialize-AitherUI {
    <#
    .SYNOPSIS
        Initialize the AitherUI system
    .PARAMETER Theme
        Color theme to use (Default, Dark, Light, or custom theme hashtable)
    .PARAMETER DisableColors
        Disable all colors (for terminals that don't support it)
    .PARAMETER Configuration
        Configuration object or path to config file
    #>
    [CmdletBinding()]
    param(
        [object]$Theme = 'Default',
        [switch]$DisableColors,
        [object]$Configuration
    )

    # Load configuration (lazy-load configuration module first)
    Import-ConfigurationModule
    
    $uiConfig = $null
    if ($Configuration) {
        $uiConfig = if ($Configuration.UI) { $Configuration.UI } else { $null }
    } elseif (Get-Command Get-Configuration -ErrorAction SilentlyContinue) {
        $uiConfig = Get-Configuration -Section 'UI'
    }

    # Apply configuration settings
    if ($uiConfig) {
        # Override parameters with config values
        if (-not $PSBoundParameters.ContainsKey('Theme') -and $uiConfig.Theme) {
            $Theme = $uiConfig.Theme
        }
        if (-not $PSBoundParameters.ContainsKey('DisableColors') -and $uiConfig.EnableColors -eq $false) {
            $DisableColors = $true
        }
        
        # Store UI configuration in state
        $script:UIState.Config = $uiConfig
        $script:UIState.EnableEmoji = if ($null -ne $uiConfig.EnableEmoji) { $uiConfig.EnableEmoji } else { $true }
        $script:UIState.MenuStyle = if ($uiConfig.MenuStyle) { $uiConfig.MenuStyle } else { 'Interactive' }
        $script:UIState.ProgressBarStyle = if ($uiConfig.ProgressBarStyle) { $uiConfig.ProgressBarStyle } else { 'Classic' }
        $script:UIState.NotificationPosition = if ($uiConfig.NotificationPosition) { $uiConfig.NotificationPosition } else { 'TopRight' }
        $script:UIState.AutoRefreshInterval = if ($null -ne $uiConfig.AutoRefreshInterval) { $uiConfig.AutoRefreshInterval } else { 5 }
        $script:UIState.ShowWelcomeMessage = if ($null -ne $uiConfig.ShowWelcomeMessage) { $uiConfig.ShowWelcomeMessage } else { $true }
        $script:UIState.ShowHints = if ($null -ne $uiConfig.ShowHints) { $uiConfig.ShowHints } else { $true }
        $script:UIState.EnableAnimations = if ($null -ne $uiConfig.EnableAnimations) { $uiConfig.EnableAnimations } else { $false }
        # Don't set TerminalWidth during initialization - let it be lazy-loaded
        if ($uiConfig.TerminalWidth -and $uiConfig.TerminalWidth -ne 'auto') {
            $script:UIState.TerminalWidth = $uiConfig.TerminalWidth
        }
        $script:UIState.ClearScreenOnStart = if ($null -ne $uiConfig.ClearScreenOnStart) { $uiConfig.ClearScreenOnStart } else { $true }
        $script:UIState.ShowExecutionTime = if ($null -ne $uiConfig.ShowExecutionTime) { $uiConfig.ShowExecutionTime } else { $true }
        $script:UIState.ShowMemoryUsage = if ($null -ne $uiConfig.ShowMemoryUsage) { $uiConfig.ShowMemoryUsage } else { $false }
        
        # Load custom themes from config
        if ($uiConfig.Themes -and $uiConfig.Themes.PSObject -and $uiConfig.Themes.PSObject.Properties) {
            foreach ($themeProp in $uiConfig.Themes.PSObject.Properties) {
                $themeName = $themeProp.Name
                $themeData = $themeProp.Value
                $script:Themes[$themeName] = @{}
                if ($themeData.PSObject -and $themeData.PSObject.Properties) {
                    foreach ($colorProp in $themeData.PSObject.Properties) {
                        $script:Themes[$themeName][$colorProp.Name] = $colorProp.Value
                    }
                }
            }
        }
    }

    if ($DisableColors) {
        # Create a no-color theme
        $script:UIState.Colors = @{}
        $script:Themes.Default.Keys | ForEach-Object {
            $script:UIState.Colors[$_] = 'White'
        }
    }
    elseif ($Theme -is [string] -and $script:Themes.ContainsKey($Theme)) {
        $script:UIState.Colors = $script:Themes[$Theme]
        $script:UIState.Theme = $Theme
    }
    elseif ($Theme -is [hashtable]) {
        # Custom theme
        $script:UIState.Colors = $Theme
        $script:UIState.Theme = 'Custom'
    }

    # Clear screen if configured (skip in CI/non-interactive environments)
    if ($script:UIState.ClearScreenOnStart -and -not $env:CI -and -not $env:GITHUB_ACTIONS) {
        try { Clear-Host } catch { }
    }

    # Show welcome message if configured
    if ($script:UIState.ShowWelcomeMessage) {
        Show-UIWelcome
    }

    # Test terminal capabilities (lazy-loaded on first use)
    $script:UIState.SupportsEmoji = $null  # Will be tested when first needed
    $script:UIState.TerminalWidth = $null  # Will be calculated when first needed
}

function Write-UIText {
    <#
    .SYNOPSIS
        Write colored text with UI styling
    .PARAMETER Message
        Text to display
    .PARAMETER Color
        Color key from theme (Primary, Secondary, Success, etc.) or direct color name
    .PARAMETER NoNewline
        Don't add newline after text
    .PARAMETER Indent
        Number of spaces to indent
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [AllowEmptyString()]
        [string]$Message,
        
        [string]$Color = 'Info',
        
        [switch]$NoNewline,
        
        [int]$Indent = 0
    )

    Ensure-UIInitialized

    # Ensure Color is not null
    if ([string]::IsNullOrEmpty($Color)) {
        $Color = 'Info'
    }

    # Resolve color from theme
    $resolvedColor = 'White'  # Safe default
    
    try {
        # Debug output
        if ($Color -eq 'MenuBorder' -or $Color -eq 'MenuText' -or $Color -eq 'MenuSelected') {
            Write-Debug "Resolving color: $Color"
            Write-Debug "Colors available: $($script:UIState.Colors.Keys -join ', ')"
        }
        
        if ($script:UIState.Colors -and $script:UIState.Colors.ContainsKey($Color)) {
            $colorValue = $script:UIState.Colors[$Color]
            Write-Debug "Found color mapping: $Color -> $colorValue"
            
            # Validate it's a valid ConsoleColor
            if ([System.Enum]::GetNames([System.ConsoleColor]) -contains $colorValue) {
                $resolvedColor = $colorValue
            } else {
                Write-Debug "Color value '$colorValue' is not a valid ConsoleColor"
            }
        } elseif ([System.Enum]::GetNames([System.ConsoleColor]) -contains $Color) {
            # Direct color name provided
            $resolvedColor = $Color
        }
    }
    catch {
        # If any error, just use white
        Write-Debug "Error resolving color: $_"
        $resolvedColor = 'White'
    }

    # Apply indentation
    if ($Indent -gt 0) {
        $Message = (' ' * $Indent) + $Message
    }
    
    try {
        Write-Host $Message -ForegroundColor $resolvedColor -NoNewline:$NoNewline
    }
    catch {
        # Final fallback - just write without color
        Write-Host $Message -NoNewline:$NoNewline
    }
}

function Show-UIMenu {
    <#
    .SYNOPSIS
        Display an interactive menu
    .PARAMETER Title
        Menu title
    .PARAMETER Items
        Array of menu items (strings or objects with Name/Description properties)
    .PARAMETER MultiSelect
        Allow multiple selections
    .PARAMETER ShowNumbers
        Show item numbers
    .PARAMETER ReturnIndex
        Return selected index instead of item
    .PARAMETER NonInteractive
        Force non-interactive mode (for CI/automation)
    .EXAMPLE
        $selection = Show-UIMenu -Title "Select Environment" -Items @("Development", "Staging", "Production")
    #>
    [CmdletBinding()]
    param(
        [string]$Title,
        
        [Parameter(Mandatory)]
        [array]$Items,
        
        [switch]$MultiSelect,
        
        [switch]$ShowNumbers,
        
        [switch]$ReturnIndex,
        
        [string]$Prompt = "Select an option",
        
        [hashtable]$CustomActions = @{},
        
        [switch]$NonInteractive
    )
    
    # Always use better menu system unless in non-interactive mode
    $betterMenuModule = Join-Path $PSScriptRoot "BetterMenu.psm1"
    
    # Check if we're in non-interactive mode
    $isNonInteractive = $NonInteractive -or $env:CI -or $env:GITHUB_ACTIONS -or $env:TF_BUILD -or $env:AITHERZERO_NONINTERACTIVE
    
    if (-not $isNonInteractive) {
        if (Test-Path $betterMenuModule) {
            # Import BetterMenu module if not already loaded
            if (-not (Get-Module -Name BetterMenu)) {
                Import-Module $betterMenuModule -Force -Global -ErrorAction Stop
            }
            
            $result = Show-BetterMenu -Title $Title -Items $Items `
                -MultiSelect:$MultiSelect -ShowNumbers:$ShowNumbers `
                -CustomActions $CustomActions
            
            if ($ReturnIndex -and $result -and $result -isnot [hashtable]) {
                # Convert item back to index
                for ($i = 0; $i -lt $Items.Count; $i++) {
                    if ($Items[$i] -eq $result) {
                        return $i
                    }
                }
            }
            
            return $result
        } else {
            throw "BetterMenu.psm1 not found at $betterMenuModule. Interactive menu system is required."
        }
    }
    
    # Non-interactive mode - simple numbered prompt for automation/CI
    if ($isNonInteractive) {
        Write-UILog -Level Debug -Message "Using non-interactive mode"
        
        # Display menu items
        if ($Title) {
            Write-Host "`n$Title" -ForegroundColor Cyan
            Write-Host ("=" * $Title.Length) -ForegroundColor DarkCyan
        }
        
        for ($i = 0; $i -lt $Items.Count; $i++) {
            $item = $Items[$i]
            $displayText = if ($item -is [string]) { $item } else { $item.Name }
            $prefix = "[$($i + 1)]"
            
            Write-Host "$prefix $displayText" -ForegroundColor White
            
            if ($item -isnot [string] -and $item.PSObject.Properties['Description'] -and $item.Description) {
                Write-Host "    $($item.Description)" -ForegroundColor DarkGray
            }
        }
        
        # Show custom actions
        if ($CustomActions.Count -gt 0) {
            Write-Host ""
            foreach ($action in $CustomActions.GetEnumerator()) {
                Write-Host "[$($action.Key)] $($action.Value)" -ForegroundColor Cyan
            }
        }
        
        Write-Host "`n$Prompt" -ForegroundColor Yellow -NoNewline
        Write-Host ": " -NoNewline
        $selection = Read-Host
        
        # Process selection
        if ($CustomActions -and $selection -and $CustomActions.ContainsKey($selection.ToUpper())) {
            return @{ Action = $selection.ToUpper() }
        }
        
        if ($selection -match '^\d+$') {
            $index = [int]$selection - 1
            if ($index -ge 0 -and $index -lt $Items.Count) {
                if ($ReturnIndex) {
                    return $index
                } else {
                    return $Items[$index]
                }
            }
        }
        
        return $null
    }
}

function Show-UIBorder {
    <#
    .SYNOPSIS
        Display a bordered text box
    .PARAMETER Title
        Title to display in border
    .PARAMETER Width
        Border width (defaults to terminal width)
    .PARAMETER Style
        Border style (Single, Double, Rounded, ASCII)
    #>
    [CmdletBinding()]
    param(
        [string]$Title,
        [int]$Width,
        [ValidateSet('Single', 'Double', 'Rounded', 'ASCII')]
        [string]$Style = 'Single'
    )

    if (-not $Width) {
        $Width = Get-TerminalWidth
    }
    
    $borders = @{
        Single = @{
            TopLeft = '┌'
            TopRight = '┐'
            BottomLeft = '└'
            BottomRight = '┘'
            Horizontal = '─'
            Vertical = '│'
        }
        Double = @{
            TopLeft = '╔'
            TopRight = '╗'
            BottomLeft = '╚'
            BottomRight = '╝'
            Horizontal = '═'
            Vertical = '║'
        }
        Rounded = @{
            TopLeft = '╭'
            TopRight = '╮'
            BottomLeft = '╰'
            BottomRight = '╯'
            Horizontal = '─'
            Vertical = '│'
        }
        ASCII = @{
            TopLeft = '+'
            TopRight = '+'
            BottomLeft = '+'
            BottomRight = '+'
            Horizontal = '-'
            Vertical = '|'
        }
    }
    
    $b = $borders[$Style]
    $innerWidth = $Width - 2

    # Top border
    $top = $b.TopLeft + ($b.Horizontal * $innerWidth) + $b.TopRight

    if ($Title) {
        $titlePadded = " $Title "
        $titleStart = [Math]::Floor(($innerWidth - $titlePadded.Length) / 2)
        if ($titleStart -gt 0) {
            $top = $b.TopLeft + 
                   ($b.Horizontal * $titleStart) + 
                   $titlePadded + 
                   ($b.Horizontal * ($innerWidth - $titleStart - $titlePadded.Length)) + 
                   $b.TopRight
        }
    }
    
    # Always use Cyan for borders to avoid issues
    Write-Host $top -ForegroundColor Cyan
}

function Show-UIProgress {
    <#
    .SYNOPSIS
        Display a progress bar
    .PARAMETER Activity
        Activity description
    .PARAMETER Status
        Current status
    .PARAMETER PercentComplete
        Percentage complete (0-100)
    .PARAMETER Id
        Progress ID for tracking multiple progress bars
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Activity,
        
        [string]$Status = '',
        
        [Parameter(Mandatory)]
        [ValidateRange(0, 100)]
        [int]$PercentComplete,
        
        [int]$Id = 1,
        
        [switch]$Completed
    )

    if ($Completed) {
        if ($script:UIState.ProgressJobs.ContainsKey($Id)) {
            $script:UIState.ProgressJobs.Remove($Id)
        }
        Write-Progress -Activity $Activity -Status "Complete" -Id $Id -Completed
        return
    }

    # Store progress state
    $script:UIState.ProgressJobs[$Id] = @{
        Activity = $Activity
        Status = $Status
        PercentComplete = $PercentComplete
        StartTime = if ($script:UIState.ProgressJobs.ContainsKey($Id)) {
            $script:UIState.ProgressJobs[$Id].StartTime
        } else {
            Get-Date
        }
    }

    # Calculate time remaining
    $elapsed = New-TimeSpan -Start $script:UIState.ProgressJobs[$Id].StartTime -End (Get-Date)
    $estimatedTotal = if ($PercentComplete -gt 0) {
        $elapsed.TotalSeconds * (100 / $PercentComplete)
    } else { 0 }
    $remaining = $estimatedTotal - $elapsed.TotalSeconds
    
    $statusText = $Status
    if ($remaining -gt 0 -and $PercentComplete -gt 0) {
        $remainingTime = [TimeSpan]::FromSeconds($remaining)
        $statusText += " (ETA: $($remainingTime.ToString('mm\:ss')))"
    }
    
    Write-Progress -Activity $Activity -Status $statusText -PercentComplete $PercentComplete -Id $Id
}

function Show-UINotification {
    <#
    .SYNOPSIS
        Display a notification message
    .PARAMETER Message
        Notification message
    .PARAMETER Type
        Notification type (Info, Success, Warning, Error)
    .PARAMETER Title
        Optional title
    .PARAMETER Duration
        How long to display (in seconds, 0 = until dismissed)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        
        [ValidateSet('Info', 'Success', 'Warning', 'Error')]
        [string]$Type = 'Info',
        
        [string]$Title,
        
        [int]$Duration = 0
    )

    $icons = @{
        Info = 'ℹ️ '
        Success = '✅'
        Warning = '⚠️ '
        Error = '❌'
    }
    
    $icon = if ($script:UIState.EnableEmoji -and (Test-EmojiSupport)) { $icons[$Type] } else { "[$Type]" }
    $color = $Type

    if ($Title) {
        Write-UIText "`n$icon $Title" -Color $color
        Write-UIText $Message -Color 'Info' -Indent 3
    } else {
        Write-UIText "`n$icon $Message" -Color $color
    }

    if ($Duration -gt 0) {
        Start-Sleep -Seconds $Duration
    }
}

function Show-UIPrompt {
    <#
    .SYNOPSIS
        Display an interactive prompt
    .PARAMETER Message
        Prompt message
    .PARAMETER DefaultValue
        Default value if user presses Enter
    .PARAMETER ValidateSet
        Valid values
    .PARAMETER Secret
        Hide input (for passwords)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        
        [string]$DefaultValue,
        
        [string[]]$ValidateSet,
        
        [switch]$Secret,
        
        [switch]$Required
    )

    $promptText = $Message
    if ($DefaultValue) {
        $promptText += " [$DefaultValue]"
    }
    if ($ValidateSet) {
        $promptText += " ($(($ValidateSet -join '/'))))"
    }
    
    do {
        Write-UIText "$promptText" -Color 'Primary' -NoNewline
        Write-Host ": " -NoNewline
        
        if ($Secret) {
            $response = Read-Host -AsSecureString
            $response = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
                [Runtime.InteropServices.Marshal]::SecureStringToBSTR($response)
            )
    } else {
            $response = Read-Host
        }
        
        if (-not $response -and $DefaultValue) {
            $response = $DefaultValue
        }
        
        if ($ValidateSet -and $response -and $response -notin $ValidateSet) {
            Write-UIText "Invalid value. Please choose from: $($ValidateSet -join ', ')" -Color 'Error'
            continue
        }
        
        if ($Required -and -not $response) {
            Write-UIText "This field is required." -Color 'Error'
            continue
        }
        
        break
    } while ($true)
    
    return $response
}

function Show-UITable {
    <#
    .SYNOPSIS
        Display data in a formatted table
    .PARAMETER Data
        Data to display
    .PARAMETER Properties
        Properties to display
    .PARAMETER Title
        Table title
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$Data,
        
        [string[]]$Properties,
        
        [string]$Title
    )

    if ($Title) {
        Write-UIText "`n$Title" -Color 'Primary'
        Write-UIText ("-" * $Title.Length) -Color 'Primary'
    }

    if ($Properties) {
        $Data | Format-Table -Property $Properties -AutoSize | Out-String | Write-Host
    } else {
        $Data | Format-Table -AutoSize | Out-String | Write-Host
    }
}

function Show-UISpinner {
    <#
    .SYNOPSIS
        Display a spinner while an operation is running
    .PARAMETER ScriptBlock
        Code to execute while showing spinner
    .PARAMETER Message
        Message to display with spinner
    .PARAMETER ArgumentList
        Arguments to pass to the script block
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock,
        
        [string]$Message = "Processing",
        
        [object[]]$ArgumentList = @()
    )

    $spinChars = '|/-\'
    $i = 0
    
    # Pass arguments to the job if provided
    $jobParams = @{
        ScriptBlock = $ScriptBlock
    }
    if ($ArgumentList.Count -gt 0) {
        $jobParams['ArgumentList'] = $ArgumentList
    }
    
    $job = Start-Job @jobParams
    
    while ($job.State -eq 'Running') {
        $spinner = $spinChars[$i % $spinChars.Length]
        Write-Host "`r$Message $spinner" -NoNewline -ForegroundColor $script:UIState.Colors.Primary
        Start-Sleep -Milliseconds 100
        $i++
    }
    
    Write-Host "`r$Message Done" -ForegroundColor $script:UIState.Colors.Success
    
    $result = Receive-Job -Job $job
    Remove-Job -Job $job
    
    return $result
}

function Get-TerminalWidth {
    <#
    .SYNOPSIS
        Get the terminal width
    #>
    # Ensure UIState is initialized
    if (-not $script:UIState) {
        Initialize-UIState
    }
    
    # Use cached value if available
    if ($script:UIState -and $script:UIState.ContainsKey('TerminalWidth') -and $null -ne $script:UIState.TerminalWidth) {
        return $script:UIState.TerminalWidth
    }

    # Calculate and cache
    try {
        if ($Host.UI.RawUI -and $Host.UI.RawUI.WindowSize -and $Host.UI.RawUI.WindowSize.Width) {
            $script:UIState.TerminalWidth = $Host.UI.RawUI.WindowSize.Width
            return $script:UIState.TerminalWidth
        }
    } catch {}
    
    $script:UIState.TerminalWidth = 80  # Default fallback
    return $script:UIState.TerminalWidth
}

function Test-EmojiSupport {
    <#
    .SYNOPSIS
        Test if the terminal supports emoji
    #>
    # Ensure UIState is initialized
    if (-not $script:UIState) {
        Initialize-UIState
    }
    
    # Use cached value if available
    if ($script:UIState -and $script:UIState.ContainsKey('SupportsEmoji') -and $null -ne $script:UIState.SupportsEmoji) {
        return $script:UIState.SupportsEmoji
    }

    # Test and cache
    try {
        # Simple test - try to measure an emoji
        $testEmoji = "✅"
        $measure = $testEmoji | Measure-Object -Character
        $script:UIState.SupportsEmoji = $measure.Characters -eq 1
        return $script:UIState.SupportsEmoji
    } catch {
        $script:UIState.SupportsEmoji = $false
        return $script:UIState.SupportsEmoji
    }
}

function Show-UIWizard {
    <#
    .SYNOPSIS
        Display a multi-step wizard interface
    .PARAMETER Steps
        Array of wizard steps
    .PARAMETER Title
        Wizard title
    .EXAMPLE
        $steps = @(
            @{
                Name = "Welcome"
                Script = { 
                    Show-UINotification -Message "Welcome to the setup wizard" -Type Info
                    return $true
                }
            },
            @{
                Name = "Configuration"
                Script = {
                    $name = Show-UIPrompt -Message "Enter your name" -Required
                    return @{ Name = $name }
                }
            }
        )
    $result = Show-UIWizard -Steps $steps -Title "Setup Wizard"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$Steps,
        
        [string]$Title = "Wizard"
    )

    $wizardState = @{
        CurrentStep = 0
        Results = @{}
        Cancelled = $false
    }
    
    while ($wizardState.CurrentStep -lt $Steps.Count -and -not $wizardState.Cancelled) {
        $step = $Steps[$wizardState.CurrentStep]
        
        if (-not $env:CI -and -not $env:GITHUB_ACTIONS) {
            try { Clear-Host } catch { }
        }
        Show-UIBorder -Title "$Title - Step $($wizardState.CurrentStep + 1) of $($Steps.Count): $($step.Name)" -Style 'Double'
        
        # Show progress
        $percentComplete = ($wizardState.CurrentStep / $Steps.Count) * 100
        Show-UIProgress -Activity $Title -Status $step.Name -PercentComplete $percentComplete
        
        # Execute step
        $stepResult = & $step.Script
        
        if ($stepResult -eq $false) {
            # Step failed or user cancelled
            $wizardState.Cancelled = $true
            break
        }
        
        # Store result if it's a hashtable
        if ($stepResult -is [hashtable]) {
            foreach ($key in $stepResult.Keys) {
                $wizardState.Results[$key] = $stepResult[$key]
            }
        }
        
        # Navigation
        if ($wizardState.CurrentStep -lt ($Steps.Count - 1)) {
            Write-UIText "`n" -Color 'Info'
            $nav = Show-UIPrompt -Message "Continue to next step?" -ValidateSet @('Yes', 'No', 'Back') -DefaultValue 'Yes'
            
            switch ($nav) {
                'Yes' { $wizardState.CurrentStep++ }
                'Back' { if ($wizardState.CurrentStep -gt 0) { $wizardState.CurrentStep-- } }
                'No' { $wizardState.Cancelled = $true }
            }
        } else {
            $wizardState.CurrentStep++
        }
    }
    
    Show-UIProgress -Activity $Title -Status "Complete" -PercentComplete 100 -Completed

    if ($wizardState.Cancelled) {
        Show-UINotification -Message "Wizard cancelled" -Type Warning
        return $null
    }
    
    return $wizardState.Results
}

function Show-UIWelcome {
    <#
    .SYNOPSIS
        Show welcome message
    .DESCRIPTION
        Displays a welcome message based on configuration
    #>
    [CmdletBinding()]
    param()

    if (-not $script:UIState.ShowWelcomeMessage) {
        return
    }
    
    $emoji = if ($script:UIState.EnableEmoji -and (Test-EmojiSupport)) { "🚀 " } else { "" }
    
    Write-UIText "$($emoji)Welcome to AitherZero!" -Color 'Primary'

    # Load version info if available
    Import-ConfigurationModule
    if (Get-Command Get-ConfigValue -ErrorAction SilentlyContinue) {
        $version = Get-ConfigValue -Path 'Core.Version' -ErrorAction SilentlyContinue
        $environment = Get-ConfigValue -Path 'Core.Environment' -ErrorAction SilentlyContinue
        
        if ($version) { Write-UIText "Version: $version" -Color 'Muted' }
        if ($environment) { Write-UIText "Environment: $environment" -Color 'Muted' }
    }

    if ($script:UIState.ShowHints) {
        Write-UIText "`nHint: Use arrow keys to navigate menus" -Color 'Info'
    }
}

# Note: Initialize-AitherUI is called lazily when first UI function is used
# This improves module load performance significantly

# Export functions
Export-ModuleMember -Function @(
    'Initialize-AitherUI'
    'Write-UIText'
    'Show-UIMenu'
    'Show-UIBorder'
    'Show-UIProgress'
    'Show-UINotification'
    'Show-UIPrompt'
    'Show-UITable'
    'Show-UISpinner'
    'Show-UIWizard'
)
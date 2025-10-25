#Requires -Version 7.0
<#
.SYNOPSIS
    Theme registry for UI component styling
.DESCRIPTION
    Manages themes, color schemes, and styling for UI components
#>

# Theme storage
$script:RegisteredThemes = @{}
$script:ActiveTheme = $null
$script:DefaultTheme = "Default"

# Built-in themes
$script:BuiltInThemes = @{
    Default = @{
        Name = "Default"
        Colors = @{
            Primary = "Cyan"
            Secondary = "Blue"
            Success = "Green"
            Warning = "Yellow"
            Error = "Red"
            Info = "White"
            Muted = "DarkGray"
            Highlight = "Magenta"

            # Component specific
            MenuBorder = "Cyan"
            MenuText = "White"
            MenuSelected = "Yellow"
            MenuDisabled = "DarkGray"

            ProgressBar = "Green"
            ProgressBackground = "DarkGray"

            InputBorder = "Blue"
            InputText = "White"
            InputPlaceholder = "DarkGray"
            InputFocus = "Cyan"

            ButtonNormal = "Blue"
            ButtonHover = "Cyan"
            ButtonPressed = "DarkCyan"
            ButtonDisabled = "DarkGray"
        }
        Styles = @{
            BorderStyle = "Single"  # Single, Double, Rounded, ASCII
            ProgressStyle = "Block"  # Block, Bar, Dots
            SelectionIndicator = ">"
            CheckedIndicator = "[✓]"
            UncheckedIndicator = "[ ]"
        }
        Typography = @{
            TitleCase = "Upper"  # Upper, Lower, Title, None
            MenuNumberFormat = "[{0}]"
            ProgressFormat = "{0}% [{1}] {2}/{3}"
        }
    }

    Dark = @{
        Name = "Dark"
        Colors = @{
            Primary = "DarkCyan"
            Secondary = "DarkBlue"
            Success = "DarkGreen"
            Warning = "DarkYellow"
            Error = "DarkRed"
            Info = "Gray"
            Muted = "DarkGray"
            Highlight = "DarkMagenta"

            MenuBorder = "DarkGray"
            MenuText = "Gray"
            MenuSelected = "White"
            MenuDisabled = "Black"

            ProgressBar = "DarkGreen"
            ProgressBackground = "Black"

            InputBorder = "DarkGray"
            InputText = "Gray"
            InputPlaceholder = "DarkGray"
            InputFocus = "White"

            ButtonNormal = "DarkBlue"
            ButtonHover = "Blue"
            ButtonPressed = "DarkBlue"
            ButtonDisabled = "Black"
        }
        Styles = @{
            BorderStyle = "Single"
            ProgressStyle = "Bar"
            SelectionIndicator = "→"
            CheckedIndicator = "[X]"
            UncheckedIndicator = "[ ]"
        }
        Typography = @{
            TitleCase = "None"
            MenuNumberFormat = "{0}."
            ProgressFormat = "[{1}] {0}%"
        }
    }

    Light = @{
        Name = "Light"
        Colors = @{
            Primary = "Blue"
            Secondary = "Cyan"
            Success = "Green"
            Warning = "Yellow"
            Error = "Red"
            Info = "Black"
            Muted = "Gray"
            Highlight = "Magenta"

            MenuBorder = "Blue"
            MenuText = "Black"
            MenuSelected = "Blue"
            MenuDisabled = "Gray"

            ProgressBar = "Blue"
            ProgressBackground = "Gray"

            InputBorder = "Black"
            InputText = "Black"
            InputPlaceholder = "Gray"
            InputFocus = "Blue"

            ButtonNormal = "White"
            ButtonHover = "Cyan"
            ButtonPressed = "Blue"
            ButtonDisabled = "Gray"
        }
        Styles = @{
            BorderStyle = "Double"
            ProgressStyle = "Dots"
            SelectionIndicator = "●"
            CheckedIndicator = "(✓)"
            UncheckedIndicator = "( )"
        }
        Typography = @{
            TitleCase = "Title"
            MenuNumberFormat = "{0})"
            ProgressFormat = "{2} of {3} ({0}%)"
        }
    }

    Matrix = @{
        Name = "Matrix"
        Colors = @{
            Primary = "Green"
            Secondary = "DarkGreen"
            Success = "Green"
            Warning = "Green"
            Error = "Green"
            Info = "Green"
            Muted = "DarkGreen"
            Highlight = "Green"

            MenuBorder = "Green"
            MenuText = "Green"
            MenuSelected = "Green"
            MenuDisabled = "DarkGreen"

            ProgressBar = "Green"
            ProgressBackground = "DarkGreen"

            InputBorder = "Green"
            InputText = "Green"
            InputPlaceholder = "DarkGreen"
            InputFocus = "Green"

            ButtonNormal = "DarkGreen"
            ButtonHover = "Green"
            ButtonPressed = "Green"
            ButtonDisabled = "DarkGreen"
        }
        Styles = @{
            BorderStyle = "ASCII"
            ProgressStyle = "Block"
            SelectionIndicator = ">"
            CheckedIndicator = "[1]"
            UncheckedIndicator = "[0]"
        }
        Typography = @{
            TitleCase = "Upper"
            MenuNumberFormat = "[{0:X2}]"
            ProgressFormat = "LOADING... {0}%"
        }
    }
}

function Register-UITheme {
    <#
    .SYNOPSIS
        Register a new theme
    .PARAMETER Name
        Theme name
    .PARAMETER Theme
        Theme definition hashtable
    .PARAMETER SetActive
        Set as active theme after registration
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [hashtable]$Theme,

        [switch]$SetActive
    )

    # Validate theme structure
    $requiredKeys = @("Colors", "Styles")
    foreach ($key in $requiredKeys) {
        if (-not $Theme.ContainsKey($key)) {
            throw "Theme must contain '$key' section"
        }
    }

    # Add theme name if not present
    if (-not $Theme.ContainsKey("Name")) {
        $Theme.Name = $Name
    }

    # Register theme
    $script:RegisteredThemes[$Name] = $Theme

    if ($SetActive) {
        Set-UITheme -Name $Name
    }

    Write-Verbose "Registered theme: $Name"
}

function Get-UITheme {
    <#
    .SYNOPSIS
        Get a theme by name or get active theme
    .PARAMETER Name
        Theme name (optional, returns active theme if not specified)
    #>
    [CmdletBinding()]
    param(
        [string]$Name
    )

    if ($Name) {
        # Check registered themes first
        if ($script:RegisteredThemes.ContainsKey($Name)) {
            return $script:RegisteredThemes[$Name]
        }

        # Check built-in themes
        if ($script:BuiltInThemes.ContainsKey($Name)) {
            return $script:BuiltInThemes[$Name]
        }

        return $null
    }
    else {
        # Return active theme
        if ($script:ActiveTheme) {
            return $script:ActiveTheme
        }

        # Return default theme
        return $script:BuiltInThemes[$script:DefaultTheme]
    }
}

function Set-UITheme {
    <#
    .SYNOPSIS
        Set the active theme
    .PARAMETER Name
        Theme name
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    $theme = Get-UITheme -Name $Name

    if (-not $theme) {
        throw "Theme '$Name' not found"
    }

    $script:ActiveTheme = $theme

    # Notify all components of theme change
    if (Get-Command Invoke-UIEvent -ErrorAction SilentlyContinue) {
        Invoke-UIEvent -EventName "ThemeChanged" -Data @{ Theme = $theme }
    }

    Write-Verbose "Set active theme: $Name"
}

function Get-UIThemeList {
    <#
    .SYNOPSIS
        Get list of all available themes
    .PARAMETER IncludeBuiltIn
        Include built-in themes
    #>
    [CmdletBinding()]
    param(
        [switch]$IncludeBuiltIn = $true
    )

    $themes = @()

    # Add registered themes
    $themes += $script:RegisteredThemes.Values

    # Add built-in themes
    if ($IncludeBuiltIn) {
        $themes += $script:BuiltInThemes.Values
    }

    return $themes
}

function Get-UIThemeColor {
    <#
    .SYNOPSIS
        Get a color from the active theme
    .PARAMETER ColorKey
        Color key (e.g., "Primary", "MenuBorder")
    .PARAMETER Default
        Default color if key not found
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ColorKey,

        [string]$Default = "White"
    )

    $theme = Get-UITheme

    if ($theme -and $theme.Colors -and $theme.Colors.ContainsKey($ColorKey)) {
        return $theme.Colors[$ColorKey]
    }

    return $Default
}

function Get-UIThemeStyle {
    <#
    .SYNOPSIS
        Get a style from the active theme
    .PARAMETER StyleKey
        Style key (e.g., "BorderStyle", "SelectionIndicator")
    .PARAMETER Default
        Default style if key not found
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$StyleKey,

        [string]$Default = ""
    )

    $theme = Get-UITheme

    if ($theme -and $theme.Styles -and $theme.Styles.ContainsKey($StyleKey)) {
        return $theme.Styles[$StyleKey]
    }

    return $Default
}

function Export-UITheme {
    <#
    .SYNOPSIS
        Export a theme to JSON
    .PARAMETER Name
        Theme name
    .PARAMETER Path
        Path to save the theme
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$Path
    )

    $theme = Get-UITheme -Name $Name

    if (-not $theme) {
        throw "Theme '$Name' not found"
    }

    $theme | ConvertTo-Json -Depth 10 | Set-Content -Path $Path
    Write-Verbose "Exported theme '$Name' to: $Path"
}

function Import-UITheme {
    <#
    .SYNOPSIS
        Import a theme from JSON
    .PARAMETER Path
        Path to the theme file
    .PARAMETER Name
        Optional name override
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [string]$Name
    )

    if (-not (Test-Path $Path)) {
        throw "Theme file not found: $Path"
    }

    $theme = Get-Content $Path -Raw | ConvertFrom-Json -AsHashtable

    if ($Name) {
        $theme.Name = $Name
    }
    elseif (-not $theme.Name) {
        $theme.Name = [System.IO.Path]::GetFileNameWithoutExtension($Path)
    }

    Register-UITheme -Name $theme.Name -Theme $theme

    Write-Verbose "Imported theme '$($theme.Name)' from: $Path"
}

function New-UITheme {
    <#
    .SYNOPSIS
        Create a new theme based on an existing theme
    .PARAMETER Name
        New theme name
    .PARAMETER BasedOn
        Base theme name
    .PARAMETER Colors
        Color overrides
    .PARAMETER Styles
        Style overrides
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [string]$BasedOn = "Default",

        [hashtable]$Colors = @{},

        [hashtable]$Styles = @{}
    )

    # Get base theme
    $baseTheme = Get-UITheme -Name $BasedOn

    if (-not $baseTheme) {
        throw "Base theme '$BasedOn' not found"
    }

    # Clone base theme
    $newTheme = @{
        Name = $Name
        Colors = $baseTheme.Colors.Clone()
        Styles = $baseTheme.Styles.Clone()
    }

    if ($baseTheme.Typography) {
        $newTheme.Typography = $baseTheme.Typography.Clone()
    }

    # Apply overrides
    foreach ($key in $Colors.Keys) {
        $newTheme.Colors[$key] = $Colors[$key]
    }

    foreach ($key in $Styles.Keys) {
        $newTheme.Styles[$key] = $Styles[$key]
    }

    # Register new theme
    Register-UITheme -Name $Name -Theme $newTheme

    return $newTheme
}

function Initialize-UIThemeRegistry {
    <#
    .SYNOPSIS
        Initialize the theme registry
    #>
    [CmdletBinding()]
    param()

    # Set default theme
    $script:ActiveTheme = $script:BuiltInThemes[$script:DefaultTheme]

    Write-Verbose "Theme registry initialized with $($script:BuiltInThemes.Count) built-in themes"
}

# Export functions
Export-ModuleMember -Function @(
    'Register-UITheme'
    'Get-UITheme'
    'Set-UITheme'
    'Get-UIThemeList'
    'Get-UIThemeColor'
    'Get-UIThemeStyle'
    'Export-UITheme'
    'Import-UITheme'
    'New-UITheme'
    'Initialize-UIThemeRegistry'
)
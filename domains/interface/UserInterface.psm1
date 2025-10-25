#Requires -Version 7.0

<#
.SYNOPSIS
    Consolidated User Interface module for AitherZero
.DESCRIPTION
    Unified UI components providing menus, prompts, progress indicators, and interactive elements.
    Consolidates all UI functionality from the experience domain.
.NOTES
    Consolidated from:
    - domains/experience/UserInterface.psm1
    - domains/experience/BetterMenu.psm1
    - domains/experience/Core/UIContext.psm1
    - domains/experience/Core/UIComponent.psm1
    - domains/experience/Components/InteractiveMenu.psm1
    - domains/experience/Layout/LayoutManager.psm1
    - domains/experience/Registry/*
#>

# Script variables for UI state
$script:UIInitialized = $false
$script:UITheme = 'Default'
$script:EnableEmoji = $true
$script:EnableColors = $true
$script:MenuStyle = 'Interactive'

function Initialize-AitherUI {
    <#
    .SYNOPSIS
        Initialize the UI system with configuration
    #>
    [CmdletBinding()]
    param(
        [ValidateSet('Default', 'Dark', 'Light', 'Minimal')]
        [string]$Theme = 'Default',
        
        [switch]$DisableEmoji,
        [switch]$DisableColors,
        
        [ValidateSet('Interactive', 'Simple', 'Classic')]
        [string]$MenuStyle = 'Interactive'
    )

    $script:UITheme = $Theme
    $script:EnableEmoji = -not $DisableEmoji.IsPresent
    $script:EnableColors = -not $DisableColors.IsPresent
    $script:MenuStyle = $MenuStyle
    $script:UIInitialized = $true

    if (Get-Command Write-UILog -ErrorAction SilentlyContinue) {
        Write-UILog -Message "User interface module initialized" -Data @{
            Theme = $Theme
            MenuStyle = $MenuStyle
            EnableEmoji = $script:EnableEmoji
            EnableColors = $script:EnableColors
            Features = @('Emoji', 'Spinners', 'ProgressBars', 'Menus', 'Prompts')
            ProgressBarStyle = 'Classic'
        }
    }
}

function Show-BetterMenu {
    <#
    .SYNOPSIS
        Display an interactive menu with keyboard navigation
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$Items,
        
        [string]$Title = "Select an option",
        [string]$Prompt = "Use arrow keys to navigate, Enter to select, or 'q' to quit:",
        [string]$DefaultChoice,
        [int]$PageSize = 10,
        [switch]$ShowIndex,
        [switch]$ReturnIndex,
        [switch]$AllowMultiple
    )

    if (-not $script:UIInitialized) {
        Initialize-AitherUI
    }

    # Clear screen for better presentation
    Clear-Host
    
    # Display title
    if ($Title) {
        Write-Host "`n$Title" -ForegroundColor Cyan
        Write-Host ("=" * $Title.Length) -ForegroundColor Cyan
        Write-Host
    }

    $selectedIndex = 0
    $scrollOffset = 0
    $quit = $false
    $selected = @()

    # Find default choice index
    if ($DefaultChoice) {
        for ($i = 0; $i -lt $Items.Count; $i++) {
            $itemText = if ($Items[$i] -is [string]) { $Items[$i] } else { $Items[$i].Name }
            if ($itemText -eq $DefaultChoice) {
                $selectedIndex = $i
                break
            }
        }
    }

    while (-not $quit) {
        # Calculate visible range
        $startIndex = $scrollOffset
        $endIndex = [Math]::Min($Items.Count - 1, $scrollOffset + $PageSize - 1)
        
        # Clear previous menu (preserve title)
        $cursorTop = [Console]::CursorTop
        [Console]::SetCursorPosition(0, $cursorTop - $PageSize - 2)
        
        # Display menu items
        for ($i = $startIndex; $i -le $endIndex; $i++) {
            $item = $Items[$i]
            $itemText = if ($item -is [string]) { $item } else { $item.Name }
            
            $prefix = " "
            $color = "White"
            
            if ($AllowMultiple -and $selected -contains $i) {
                $prefix = if ($script:EnableEmoji) { "✓" } else { "[X]" }
                $color = "Green"
            }
            
            if ($i -eq $selectedIndex) {
                $prefix = if ($script:EnableEmoji) { "▶" } else { ">" }
                $color = "Yellow"
            }
            
            $displayText = if ($ShowIndex) { "$($i + 1). $itemText" } else { $itemText }
            
            if ($script:EnableColors) {
                Write-Host " $prefix $displayText" -ForegroundColor $color
            } else {
                Write-Host " $prefix $displayText"
            }
        }
        
        # Show pagination info
        if ($Items.Count -gt $PageSize) {
            $pageInfo = "Page $([Math]::Floor($scrollOffset / $PageSize) + 1)/$([Math]::Ceiling($Items.Count / $PageSize))"
            Write-Host "`n$pageInfo" -ForegroundColor Gray
        }
        
        # Show prompt
        Write-Host "`n$Prompt" -ForegroundColor Gray
        
        # Handle input
        $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        
        switch ($key.VirtualKeyCode) {
            38 { # Up arrow
                $selectedIndex = [Math]::Max(0, $selectedIndex - 1)
                if ($selectedIndex -lt $scrollOffset) {
                    $scrollOffset = [Math]::Max(0, $scrollOffset - 1)
                }
            }
            40 { # Down arrow
                $selectedIndex = [Math]::Min($Items.Count - 1, $selectedIndex + 1)
                if ($selectedIndex -gt $scrollOffset + $PageSize - 1) {
                    $scrollOffset = [Math]::Min($Items.Count - $PageSize, $scrollOffset + 1)
                }
            }
            33 { # Page Up
                $scrollOffset = [Math]::Max(0, $scrollOffset - $PageSize)
                $selectedIndex = [Math]::Max(0, $selectedIndex - $PageSize)
            }
            34 { # Page Down
                $scrollOffset = [Math]::Min($Items.Count - $PageSize, $scrollOffset + $PageSize)
                $selectedIndex = [Math]::Min($Items.Count - 1, $selectedIndex + $PageSize)
            }
            13 { # Enter
                if ($AllowMultiple) {
                    if ($selected -contains $selectedIndex) {
                        $selected = $selected | Where-Object { $_ -ne $selectedIndex }
                    } else {
                        $selected += $selectedIndex
                    }
                } else {
                    $quit = $true
                }
            }
            32 { # Spacebar (for multiple selection)
                if ($AllowMultiple) {
                    if ($selected -contains $selectedIndex) {
                        $selected = $selected | Where-Object { $_ -ne $selectedIndex }
                    } else {
                        $selected += $selectedIndex
                    }
                }
            }
            81 { # Q key
                return $null
            }
            27 { # Escape
                return $null
            }
            default {
                # Handle letter shortcuts
                $char = [char]$key.Character
                if ($char -match '[a-zA-Z0-9]') {
                    $targetChar = $char.ToLower()
                    for ($i = 0; $i -lt $Items.Count; $i++) {
                        $itemText = if ($Items[$i] -is [string]) { $Items[$i] } else { $Items[$i].Name }
                        if ($itemText.ToLower().StartsWith($targetChar)) {
                            $selectedIndex = $i
                            if ($selectedIndex -lt $scrollOffset) {
                                $scrollOffset = $selectedIndex
                            } elseif ($selectedIndex -gt $scrollOffset + $PageSize - 1) {
                                $scrollOffset = [Math]::Max(0, $selectedIndex - $PageSize + 1)
                            }
                            break
                        }
                    }
                }
            }
        }
    }

    # Return results
    if ($AllowMultiple) {
        if ($ReturnIndex) {
            return $selected
        } else {
            return $selected | ForEach-Object { $Items[$_] }
        }
    } else {
        if ($ReturnIndex) {
            return $selectedIndex
        } else {
            return $Items[$selectedIndex]
        }
    }
}

function Show-UIMenu {
    <#
    .SYNOPSIS
        Display a simple menu interface
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Options,
        
        [string]$Title = "Main Menu",
        [string]$DefaultOption,
        [switch]$ClearScreen = $true
    )

    if ($ClearScreen) { Clear-Host }
    
    if ($Title) {
        Write-UIHeader -Text $Title
    }

    $choices = @()
    $keys = $Options.Keys | Sort-Object
    
    foreach ($key in $keys) {
        $choices += [PSCustomObject]@{
            Key = $key
            Name = $Options[$key]
        }
    }

    $selected = Show-BetterMenu -Items $choices -Title "" -ShowIndex
    
    if ($selected) {
        return $selected.Key
    }
    return $null
}

function Write-UIText {
    <#
    .SYNOPSIS
        Write formatted text with optional styling
    #>
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline)]
        [AllowEmptyString()]
        [string]$Text,
        
        [ValidateSet('Black', 'DarkBlue', 'DarkGreen', 'DarkCyan', 'DarkRed', 'DarkMagenta', 'DarkYellow', 'Gray', 'DarkGray', 'Blue', 'Green', 'Cyan', 'Red', 'Magenta', 'Yellow', 'White')]
        [string]$ForegroundColor,
        
        [ValidateSet('Black', 'DarkBlue', 'DarkGreen', 'DarkCyan', 'DarkRed', 'DarkMagenta', 'DarkYellow', 'Gray', 'DarkGray', 'Blue', 'Green', 'Cyan', 'Red', 'Magenta', 'Yellow', 'White')]
        [string]$BackgroundColor,
        
        [switch]$NoNewline,
        [switch]$Bold
    )

    $params = @{}
    
    if ($ForegroundColor -and $script:EnableColors) {
        $params.ForegroundColor = $ForegroundColor
    }
    
    if ($BackgroundColor -and $script:EnableColors) {
        $params.BackgroundColor = $BackgroundColor
    }
    
    if ($NoNewline) {
        $params.NoNewline = $true
    }

    Write-Host $Text @params
}

function Show-UIHeader {
    <#
    .SYNOPSIS
        Display a formatted header
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Text,
        
        [ValidateSet('=', '-', '*', '#')]
        [string]$BorderChar = '=',
        
        [ValidateSet('Cyan', 'Yellow', 'Green', 'White')]
        [string]$Color = 'Cyan'
    )

    Write-Host "`n$Text" -ForegroundColor $Color
    Write-Host ($BorderChar * $Text.Length) -ForegroundColor $Color
    Write-Host
}

function Show-UIProgress {
    <#
    .SYNOPSIS
        Display a progress bar or spinner
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ParameterSetName = 'Progress')]
        [int]$Percent,
        
        [Parameter(Mandatory, ParameterSetName = 'Spinner')]
        [switch]$Spinner,
        
        [string]$Activity = "Processing",
        [string]$Status = "",
        [int]$Width = 50,
        [int]$Id = 0
    )

    if ($Spinner) {
        $spinChars = @('|', '/', '-', '\')
        $spinIndex = (Get-Date).Millisecond % 4
        Write-Host "`r$Activity $($spinChars[$spinIndex]) $Status" -NoNewline -ForegroundColor Yellow
    } else {
        Write-Progress -Activity $Activity -Status $Status -PercentComplete $Percent -Id $Id
    }
}

function Show-UINotification {
    <#
    .SYNOPSIS
        Display a notification message
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        
        [ValidateSet('Info', 'Success', 'Warning', 'Error')]
        [string]$Type = 'Info',
        
        [int]$Duration = 0
    )

    $icons = @{
        'Info' = if ($script:EnableEmoji) { '📘' } else { '[INFO]' }
        'Success' = if ($script:EnableEmoji) { '✅' } else { '[SUCCESS]' }
        'Warning' = if ($script:EnableEmoji) { '⚠️' } else { '[WARNING]' }
        'Error' = if ($script:EnableEmoji) { '❌' } else { '[ERROR]' }
    }

    $colors = @{
        'Info' = 'Cyan'
        'Success' = 'Green'
        'Warning' = 'Yellow'
        'Error' = 'Red'
    }

    $fullMessage = "$($icons[$Type]) $Message"
    
    if ($script:EnableColors) {
        Write-Host $fullMessage -ForegroundColor $colors[$Type]
    } else {
        Write-Host $fullMessage
    }

    if ($Duration -gt 0) {
        Start-Sleep -Seconds $Duration
    }
}

function Show-UIPrompt {
    <#
    .SYNOPSIS
        Display an interactive prompt
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        
        [string]$DefaultValue,
        [switch]$SecureString,
        [string[]]$ValidValues,
        [switch]$Required
    )

    do {
        $promptText = $Message
        if ($DefaultValue) {
            $promptText += " [$DefaultValue]"
        }
        $promptText += ": "

        Write-Host $promptText -NoNewline -ForegroundColor Cyan

        if ($SecureString) {
            $response = Read-Host -AsSecureString
            $response = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($response))
        } else {
            $response = Read-Host
        }

        if ([string]::IsNullOrWhiteSpace($response) -and $DefaultValue) {
            $response = $DefaultValue
        }

        if ($ValidValues -and $ValidValues.Count -gt 0) {
            if ($response -notin $ValidValues) {
                Write-Host "Invalid choice. Please select from: $($ValidValues -join ', ')" -ForegroundColor Red
                continue
            }
        }

        if ($Required -and [string]::IsNullOrWhiteSpace($response)) {
            Write-Host "This field is required." -ForegroundColor Red
            continue
        }

        return $response
    } while ($true)
}

function Show-UISpinner {
    <#
    .SYNOPSIS
        Execute a script block with spinner animation
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock,
        
        [string]$Message = "Processing"
    )

    $spinChars = @('⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏')
    $job = Start-Job -ScriptBlock $ScriptBlock
    $i = 0

    try {
        while ($job.State -eq 'Running') {
            $char = if ($script:EnableEmoji) { $spinChars[$i % $spinChars.Length] } else { '|' }
            Write-Host "`r$Message $char" -NoNewline -ForegroundColor Yellow
            Start-Sleep -Milliseconds 100
            $i++
        }

        Write-Host "`r$Message ✅" -ForegroundColor Green
        return Receive-Job -Job $job -Wait
    }
    finally {
        Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
    }
}

function Show-UITable {
    <#
    .SYNOPSIS
        Display data in a formatted table
    #>
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline)]
        [object[]]$Data,
        
        [string[]]$Properties,
        [string]$Title,
        [switch]$AutoSize
    )

    begin {
        $allData = @()
    }

    process {
        $allData += $Data
    }

    end {
        if ($Title) {
            Show-UIHeader -Text $Title
        }

        if ($Properties) {
            $allData | Format-Table -Property $Properties -AutoSize:$AutoSize
        } else {
            $allData | Format-Table -AutoSize:$AutoSize
        }
    }
}

function Show-UIWizard {
    <#
    .SYNOPSIS
        Display a step-by-step wizard interface
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable[]]$Steps,
        
        [string]$Title = "Setup Wizard",
        [hashtable]$InitialData = @{}
    )

    $results = $InitialData.Clone()
    $currentStep = 0

    Clear-Host
    Show-UIHeader -Text $Title

    while ($currentStep -lt $Steps.Count) {
        $step = $Steps[$currentStep]
        
        Write-Host "`nStep $($currentStep + 1) of $($Steps.Count): $($step.Title)" -ForegroundColor Cyan
        
        if ($step.Description) {
            Write-Host $step.Description -ForegroundColor Gray
            Write-Host
        }

        switch ($step.Type) {
            'Input' {
                $value = Show-UIPrompt -Message $step.Prompt -DefaultValue $step.Default -Required:$step.Required
                $results[$step.Key] = $value
            }
            'Choice' {
                $selected = Show-BetterMenu -Items $step.Choices -Title $step.Prompt
                $results[$step.Key] = $selected
            }
            'Confirm' {
                $response = Show-UIPrompt -Message "$($step.Prompt) (y/n)" -ValidValues @('y', 'n', 'yes', 'no') -DefaultValue 'y'
                $results[$step.Key] = $response -in @('y', 'yes')
            }
        }

        $currentStep++
    }

    return $results
}

# Initialize UI on module load
if (-not $script:UIInitialized) {
    Initialize-AitherUI
}

# Export functions
Export-ModuleMember -Function @(
    'Initialize-AitherUI',
    'Show-BetterMenu',
    'Show-UIMenu',
    'Write-UIText',
    'Show-UIHeader',
    'Show-UIProgress',
    'Show-UINotification',
    'Show-UIPrompt',
    'Show-UISpinner',
    'Show-UITable',
    'Show-UIWizard'
)
#Requires -Version 7.0
<#
.SYNOPSIS
    Key Binding Manager for Modal UI
.DESCRIPTION
    Manages key bindings for different modal UI modes (Normal, Command, Search).
    Provides registration, lookup, and execution of key-bound actions.
    
    Supports:
    - Mode-specific key bindings
    - Default key bindings
    - Custom user-defined bindings
    - Key binding conflicts detection
    
.NOTES
    Key bindings are stored per-mode and can be customized via configuration.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Default key bindings for each mode
$script:DefaultKeyBindings = @{
    Normal = @{
        # Navigation
        'UpArrow' = @{ Action = 'Navigate-Up'; Description = 'Move selection up' }
        'DownArrow' = @{ Action = 'Navigate-Down'; Description = 'Move selection down' }
        'LeftArrow' = @{ Action = 'Navigate-Back'; Description = 'Go back / previous menu' }
        'RightArrow' = @{ Action = 'Navigate-Forward'; Description = 'Select / next menu' }
        'Enter' = @{ Action = 'Select-Item'; Description = 'Select current item' }
        
        # VIM-style navigation (optional)
        'k' = @{ Action = 'Navigate-Up'; Description = 'Move up (VIM)' }
        'j' = @{ Action = 'Navigate-Down'; Description = 'Move down (VIM)' }
        'h' = @{ Action = 'Navigate-Back'; Description = 'Go back (VIM)' }
        'l' = @{ Action = 'Navigate-Forward'; Description = 'Go forward (VIM)' }
        
        # Quick navigation
        'g' = @{ Action = 'Go-ToTop'; Description = 'Go to first item' }
        'G' = @{ Action = 'Go-ToBottom'; Description = 'Go to last item' }
        'PageUp' = @{ Action = 'Page-Up'; Description = 'Page up' }
        'PageDown' = @{ Action = 'Page-Down'; Description = 'Page down' }
        
        # Mode switching
        ':' = @{ Action = 'Enter-CommandMode'; Description = 'Enter command mode' }
        '/' = @{ Action = 'Enter-SearchMode'; Description = 'Enter search mode' }
        
        # Quick actions
        'r' = @{ Action = 'Run-Selected'; Description = 'Run selected item' }
        's' = @{ Action = 'Save-ToBookmarks'; Description = 'Save to bookmarks' }
        'o' = @{ Action = 'Open-Details'; Description = 'Open details view' }
        'd' = @{ Action = 'Delete-Item'; Description = 'Delete/remove item' }
        'e' = @{ Action = 'Edit-Item'; Description = 'Edit item' }
        
        # Search navigation
        'n' = @{ Action = 'Next-SearchResult'; Description = 'Next search result' }
        'N' = @{ Action = 'Previous-SearchResult'; Description = 'Previous search result' }
        
        # Other
        '?' = @{ Action = 'Show-Help'; Description = 'Show help' }
        'q' = @{ Action = 'Quit-Menu'; Description = 'Quit/back' }
        'Escape' = @{ Action = 'Cancel'; Description = 'Cancel/back' }
        
        # Number selection (1-9, 0 for 10)
        '1' = @{ Action = 'Select-Number'; Number = 1; Description = 'Select item 1' }
        '2' = @{ Action = 'Select-Number'; Number = 2; Description = 'Select item 2' }
        '3' = @{ Action = 'Select-Number'; Number = 3; Description = 'Select item 3' }
        '4' = @{ Action = 'Select-Number'; Number = 4; Description = 'Select item 4' }
        '5' = @{ Action = 'Select-Number'; Number = 5; Description = 'Select item 5' }
        '6' = @{ Action = 'Select-Number'; Number = 6; Description = 'Select item 6' }
        '7' = @{ Action = 'Select-Number'; Number = 7; Description = 'Select item 7' }
        '8' = @{ Action = 'Select-Number'; Number = 8; Description = 'Select item 8' }
        '9' = @{ Action = 'Select-Number'; Number = 9; Description = 'Select item 9' }
        '0' = @{ Action = 'Select-Number'; Number = 10; Description = 'Select item 10' }
    }
    
    Command = @{
        'Enter' = @{ Action = 'Execute-Command'; Description = 'Execute command' }
        'Escape' = @{ Action = 'Cancel-Command'; Description = 'Cancel command mode' }
        'Backspace' = @{ Action = 'Backspace'; Description = 'Delete character' }
        'Tab' = @{ Action = 'Autocomplete'; Description = 'Show autocomplete' }
        'UpArrow' = @{ Action = 'History-Previous'; Description = 'Previous command' }
        'DownArrow' = @{ Action = 'History-Next'; Description = 'Next command' }
    }
    
    Search = @{
        'Enter' = @{ Action = 'Select-SearchResult'; Description = 'Select result' }
        'Escape' = @{ Action = 'Cancel-Search'; Description = 'Cancel search' }
        'Backspace' = @{ Action = 'Backspace'; Description = 'Delete character' }
        'UpArrow' = @{ Action = 'Navigate-Up'; Description = 'Previous result' }
        'DownArrow' = @{ Action = 'Navigate-Down'; Description = 'Next result' }
        'n' = @{ Action = 'Next-SearchResult'; Description = 'Next match' }
        'N' = @{ Action = 'Previous-SearchResult'; Description = 'Previous match' }
    }
}

# Current key bindings (starts as copy of defaults, can be customized)
$script:KeyBindings = @{}

<#
.SYNOPSIS
    Initializes the key binding manager
.DESCRIPTION
    Sets up default key bindings. Can optionally load custom bindings.
    
.PARAMETER CustomBindings
    Optional hashtable of custom key bindings to merge with defaults
#>
function Initialize-KeyBindingManager {
    [CmdletBinding()]
    param(
        [hashtable]$CustomBindings = @{}
    )
    
    # Start with default bindings
    $script:KeyBindings = @{}
    foreach ($mode in $script:DefaultKeyBindings.Keys) {
        $script:KeyBindings[$mode] = @{}
        foreach ($key in $script:DefaultKeyBindings[$mode].Keys) {
            $script:KeyBindings[$mode][$key] = $script:DefaultKeyBindings[$mode][$key].Clone()
        }
    }
    
    # Merge custom bindings if provided
    if ($CustomBindings.Count -gt 0) {
        foreach ($mode in $CustomBindings.Keys) {
            if (-not $script:KeyBindings.ContainsKey($mode)) {
                $script:KeyBindings[$mode] = @{}
            }
            
            foreach ($key in $CustomBindings[$mode].Keys) {
                $script:KeyBindings[$mode][$key] = $CustomBindings[$mode][$key]
            }
        }
    }
    
    Write-Verbose "Key Binding Manager initialized"
}

<#
.SYNOPSIS
    Registers a custom key binding
.DESCRIPTION
    Adds or overrides a key binding for a specific mode.
    
.PARAMETER Mode
    The mode for this binding (Normal, Command, Search)
    
.PARAMETER Key
    The key to bind (e.g., 'r', 'Enter', 'UpArrow')
    
.PARAMETER Action
    The action to perform when key is pressed
    
.PARAMETER Description
    Optional description of the binding
#>
function Register-KeyBinding {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Normal', 'Command', 'Search')]
        [string]$Mode,
        
        [Parameter(Mandatory)]
        [string]$Key,
        
        [Parameter(Mandatory)]
        [string]$Action,
        
        [string]$Description = '',
        
        [hashtable]$Metadata = @{}
    )
    
    if (-not $script:KeyBindings.ContainsKey($Mode)) {
        $script:KeyBindings[$Mode] = @{}
    }
    
    $script:KeyBindings[$Mode][$Key] = @{
        Action = $Action
        Description = $Description
    }
    
    # Merge any additional metadata
    foreach ($key in $Metadata.Keys) {
        $script:KeyBindings[$Mode][$Key][$key] = $Metadata[$key]
    }
    
    Write-Verbose "Registered key binding: $Mode.$Key -> $Action"
}

<#
.SYNOPSIS
    Gets the binding for a key in a specific mode
.DESCRIPTION
    Looks up what action is bound to a key in the given mode.
    
.PARAMETER Mode
    The mode to check
    
.PARAMETER Key
    The key to look up
    
.OUTPUTS
    Hashtable with Action, Description, and any metadata, or $null if not found
#>
function Get-KeyBinding {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Normal', 'Command', 'Search')]
        [string]$Mode,
        
        [Parameter(Mandatory)]
        [string]$Key
    )
    
    if ($script:KeyBindings.ContainsKey($Mode) -and 
        $script:KeyBindings[$Mode].ContainsKey($Key)) {
        return $script:KeyBindings[$Mode][$Key]
    }
    
    return $null
}

<#
.SYNOPSIS
    Gets all key bindings for a mode
.DESCRIPTION
    Returns all registered key bindings for the specified mode.
    
.PARAMETER Mode
    The mode to get bindings for
    
.OUTPUTS
    Hashtable of key -> binding information
#>
function Get-AllKeyBindings {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Normal', 'Command', 'Search')]
        [string]$Mode
    )
    
    if ($script:KeyBindings.ContainsKey($Mode)) {
        return $script:KeyBindings[$Mode]
    }
    
    return @{}
}

<#
.SYNOPSIS
    Removes a key binding
.PARAMETER Mode
    The mode to remove binding from
    
.PARAMETER Key
    The key to unbind
#>
function Unregister-KeyBinding {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Normal', 'Command', 'Search')]
        [string]$Mode,
        
        [Parameter(Mandatory)]
        [string]$Key
    )
    
    if ($script:KeyBindings.ContainsKey($Mode) -and 
        $script:KeyBindings[$Mode].ContainsKey($Key)) {
        $script:KeyBindings[$Mode].Remove($Key)
        Write-Verbose "Unregistered key binding: $Mode.$Key"
    }
}

<#
.SYNOPSIS
    Converts a ReadKey result to a key name
.DESCRIPTION
    Translates ConsoleKeyInfo to a string key name for binding lookup.
    
.PARAMETER KeyInfo
    The ConsoleKeyInfo from $Host.UI.RawUI.ReadKey()
    
.OUTPUTS
    String key name (e.g., 'Enter', 'a', 'UpArrow')
#>
function ConvertTo-KeyName {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Management.Automation.Host.KeyInfo]$KeyInfo
    )
    
    # Handle special keys by VirtualKeyCode
    $specialKeys = @{
        13 = 'Enter'
        27 = 'Escape'
        8 = 'Backspace'
        9 = 'Tab'
        38 = 'UpArrow'
        40 = 'DownArrow'
        37 = 'LeftArrow'
        39 = 'RightArrow'
        33 = 'PageUp'
        34 = 'PageDown'
        36 = 'Home'
        35 = 'End'
        46 = 'Delete'
    }
    
    if ($specialKeys.ContainsKey($KeyInfo.VirtualKeyCode)) {
        return $specialKeys[$KeyInfo.VirtualKeyCode]
    }
    
    # Handle printable characters
    if ($KeyInfo.Character -match '[a-zA-Z0-9!@#$%^&*()_+\-=\[\]{};:''",.<>?/\\|`~]') {
        return $KeyInfo.Character.ToString()
    }
    
    # Handle space
    if ($KeyInfo.VirtualKeyCode -eq 32) {
        return 'Space'
    }
    
    # Default: return the character or empty
    if ($KeyInfo.Character -ne "`0") {
        return $KeyInfo.Character.ToString()
    }
    
    return ''
}

<#
.SYNOPSIS
    Gets help text for a mode's key bindings
.DESCRIPTION
    Returns formatted help text showing all key bindings for a mode.
    
.PARAMETER Mode
    The mode to get help for
    
.OUTPUTS
    Formatted string with key bindings
#>
function Get-KeyBindingHelp {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Normal', 'Command', 'Search')]
        [string]$Mode
    )
    
    $bindings = Get-AllKeyBindings -Mode $Mode
    
    if ($bindings.Count -eq 0) {
        return "No key bindings defined for $Mode mode."
    }
    
    $helpText = "=== $Mode Mode Key Bindings ===`n`n"
    
    # Group by category (inferred from action name)
    $categories = @{
        'Navigation' = @()
        'Actions' = @()
        'Mode' = @()
        'Other' = @()
    }
    
    foreach ($key in $bindings.Keys | Sort-Object) {
        $binding = $bindings[$key]
        $line = "  {0,-15} {1}" -f $key, $binding.Description
        
        # Categorize
        if ($binding.Action -match '^Navigate-|^Go-To|^Page-') {
            $categories['Navigation'] += $line
        } elseif ($binding.Action -match '^Enter-|^Exit-|^Cancel-') {
            $categories['Mode'] += $line
        } elseif ($binding.Action -match '^Run-|^Save-|^Open-|^Delete-|^Edit-|^Select-') {
            $categories['Actions'] += $line
        } else {
            $categories['Other'] += $line
        }
    }
    
    # Build output
    foreach ($category in @('Navigation', 'Actions', 'Mode', 'Other')) {
        if ($categories[$category].Count -gt 0) {
            $helpText += "$category`:`n"
            $helpText += ($categories[$category] -join "`n")
            $helpText += "`n`n"
        }
    }
    
    return $helpText
}

<#
.SYNOPSIS
    Resets key bindings to defaults
.DESCRIPTION
    Removes all custom bindings and restores default bindings.
#>
function Reset-KeyBindings {
    [CmdletBinding()]
    param()
    
    Initialize-KeyBindingManager
    Write-Verbose "Key bindings reset to defaults"
}

# Initialize with defaults on module load
Initialize-KeyBindingManager

# Export module members
Export-ModuleMember -Function @(
    'Initialize-KeyBindingManager',
    'Register-KeyBinding',
    'Get-KeyBinding',
    'Get-AllKeyBindings',
    'Unregister-KeyBinding',
    'ConvertTo-KeyName',
    'Get-KeyBindingHelp',
    'Reset-KeyBindings'
)

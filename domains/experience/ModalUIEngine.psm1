#Requires -Version 7.0
<#
.SYNOPSIS
    Modal UI Engine for VIM-like interactive interface
.DESCRIPTION
    Core modal state management system inspired by VIM's modal editing.
    Supports Normal, Command, and Search modes with mode switching logic.
    
    Modes:
    - Normal: Navigate with arrows/vim keys, single-key commands
    - Command: Type commands (`:run 0402`, `:search error`)
    - Search: Filter items in real-time (`/pattern`)
    
.NOTES
    This is a major architectural component that provides the foundation
    for VIM-like interaction patterns across the entire UI.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Module state
$script:ModalState = @{
    CurrentMode = 'Normal'          # Normal, Command, Search
    PreviousMode = $null            # For ESC/cancel operations
    ModeHistory = @()               # Stack of previous modes
    KeyBuffer = ''                  # Input buffer for Command/Search modes
    SearchResults = @()             # Filtered items in Search mode
    SelectedIndex = 0               # Current selection cursor
    LastCommand = $null             # Last executed command
    CommandHistory = @()            # History of commands (for ↑/↓)
    HistoryIndex = -1               # Current position in history
    IsInitialized = $false
}

<#
.SYNOPSIS
    Initializes the modal UI engine
.DESCRIPTION
    Sets up initial state and prepares the engine for use.
    Must be called before using other functions.
    
.PARAMETER Force
    Force re-initialization even if already initialized
#>
function Initialize-ModalUIEngine {
    [CmdletBinding()]
    param(
        [switch]$Force
    )
    
    if ($script:ModalState.IsInitialized -and -not $Force) {
        Write-Verbose "Modal UI Engine already initialized"
        return
    }
    
    # Reset to clean state
    $script:ModalState.CurrentMode = 'Normal'
    $script:ModalState.PreviousMode = $null
    $script:ModalState.ModeHistory = @()
    $script:ModalState.KeyBuffer = ''
    $script:ModalState.SearchResults = @()
    $script:ModalState.SelectedIndex = 0
    $script:ModalState.LastCommand = $null
    $script:ModalState.CommandHistory = @()
    $script:ModalState.HistoryIndex = -1
    $script:ModalState.IsInitialized = $true
    
    Write-Verbose "Modal UI Engine initialized in Normal mode"
}

<#
.SYNOPSIS
    Gets the current modal state
.DESCRIPTION
    Returns a copy of the current modal state for inspection.
#>
function Get-ModalState {
    [CmdletBinding()]
    param()
    
    return [PSCustomObject]@{
        CurrentMode = $script:ModalState.CurrentMode
        PreviousMode = $script:ModalState.PreviousMode
        KeyBuffer = $script:ModalState.KeyBuffer
        SelectedIndex = $script:ModalState.SelectedIndex
        SearchResultCount = $script:ModalState.SearchResults.Count
        CommandHistoryCount = $script:ModalState.CommandHistory.Count
        IsInitialized = $script:ModalState.IsInitialized
    }
}

<#
.SYNOPSIS
    Enters a specified mode
.DESCRIPTION
    Switches to a new mode, saving the previous mode for cancel/ESC operations.
    
.PARAMETER Mode
    The mode to enter: Normal, Command, or Search
    
.PARAMETER PreserveBuffer
    If true, preserves the key buffer when switching modes
#>
function Enter-Mode {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Normal', 'Command', 'Search')]
        [string]$Mode,
        
        [switch]$PreserveBuffer
    )
    
    # Validate mode transition
    $validTransitions = @{
        'Normal' = @('Command', 'Search')
        'Command' = @('Normal')
        'Search' = @('Normal')
    }
    
    if ($script:ModalState.CurrentMode -eq $Mode) {
        Write-Verbose "Already in $Mode mode"
        return
    }
    
    # Save previous mode for history
    $script:ModalState.PreviousMode = $script:ModalState.CurrentMode
    $script:ModalState.ModeHistory += $script:ModalState.CurrentMode
    
    # Clear buffer unless explicitly preserved
    if (-not $PreserveBuffer) {
        $script:ModalState.KeyBuffer = ''
    }
    
    # Reset history index when entering command mode
    if ($Mode -eq 'Command') {
        $script:ModalState.HistoryIndex = -1
    }
    
    # Switch mode
    $oldMode = $script:ModalState.CurrentMode
    $script:ModalState.CurrentMode = $Mode
    
    Write-Verbose "Mode changed: $oldMode -> $Mode"
}

<#
.SYNOPSIS
    Exits current mode and returns to previous mode
.DESCRIPTION
    Typically used for ESC/cancel operations. Returns to Normal mode
    if no previous mode exists.
#>
function Exit-Mode {
    [CmdletBinding()]
    param()
    
    if ($script:ModalState.CurrentMode -eq 'Normal') {
        Write-Verbose "Already in Normal mode, cannot exit further"
        return
    }
    
    # Clear buffer when exiting
    $script:ModalState.KeyBuffer = ''
    
    # Pop from history if available
    if ($script:ModalState.ModeHistory.Count -gt 0) {
        $lastIndex = $script:ModalState.ModeHistory.Count - 1
        $previousMode = $script:ModalState.ModeHistory[$lastIndex]
        $script:ModalState.ModeHistory = $script:ModalState.ModeHistory[0..($lastIndex - 1)]
        
        $oldMode = $script:ModalState.CurrentMode
        $script:ModalState.CurrentMode = $previousMode
        $script:ModalState.PreviousMode = $oldMode
        
        Write-Verbose "Exited to mode: $previousMode"
    } else {
        # Fallback to Normal mode
        $oldMode = $script:ModalState.CurrentMode
        $script:ModalState.CurrentMode = 'Normal'
        $script:ModalState.PreviousMode = $oldMode
        
        Write-Verbose "Exited to Normal mode (default)"
    }
}

<#
.SYNOPSIS
    Appends text to the key buffer
.DESCRIPTION
    Used in Command and Search modes to build up the input string.
    
.PARAMETER Text
    Text to append to the buffer
#>
function Add-ToKeyBuffer {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Text
    )
    
    $script:ModalState.KeyBuffer += $Text
    Write-Verbose "Key buffer: '$($script:ModalState.KeyBuffer)'"
}

<#
.SYNOPSIS
    Removes the last character from the key buffer
.DESCRIPTION
    Implements backspace functionality in Command and Search modes.
#>
function Remove-FromKeyBuffer {
    [CmdletBinding()]
    param()
    
    if ($script:ModalState.KeyBuffer.Length -gt 0) {
        $script:ModalState.KeyBuffer = $script:ModalState.KeyBuffer.Substring(
            0, 
            $script:ModalState.KeyBuffer.Length - 1
        )
        Write-Verbose "Key buffer after backspace: '$($script:ModalState.KeyBuffer)'"
    }
}

<#
.SYNOPSIS
    Gets the current key buffer content
.DESCRIPTION
    Returns the current command or search text being typed.
#>
function Get-KeyBuffer {
    [CmdletBinding()]
    param()
    
    return $script:ModalState.KeyBuffer
}

<#
.SYNOPSIS
    Clears the key buffer
.DESCRIPTION
    Empties the command or search input buffer.
#>
function Clear-KeyBuffer {
    [CmdletBinding()]
    param()
    
    $script:ModalState.KeyBuffer = ''
    Write-Verbose "Key buffer cleared"
}

<#
.SYNOPSIS
    Adds a command to the history
.DESCRIPTION
    Stores executed commands for recall with ↑/↓ in Command mode.
    
.PARAMETER Command
    The command text to store in history
#>
function Add-ToCommandHistory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Command
    )
    
    if ([string]::IsNullOrWhiteSpace($Command)) {
        Write-Verbose "Skipping empty command"
        return
    }
    
    # Add to history (most recent at end)
    $script:ModalState.CommandHistory += $Command
    $script:ModalState.LastCommand = $Command
    
    # Limit history size to 50 items
    if ($script:ModalState.CommandHistory.Count -gt 50) {
        $script:ModalState.CommandHistory = $script:ModalState.CommandHistory[-50..-1]
    }
    
    Write-Verbose "Added to command history: $Command"
}

<#
.SYNOPSIS
    Navigates through command history
.DESCRIPTION
    Implements ↑/↓ navigation in Command mode history.
    
.PARAMETER Direction
    'Up' for previous command, 'Down' for next command
    
.OUTPUTS
    The command from history, or empty string if at bounds
#>
function Get-CommandFromHistory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Up', 'Down')]
        [string]$Direction
    )
    
    if ($script:ModalState.CommandHistory.Count -eq 0) {
        return ''
    }
    
    if ($Direction -eq 'Up') {
        # Move back in history (older commands)
        if ($script:ModalState.HistoryIndex -lt $script:ModalState.CommandHistory.Count - 1) {
            $script:ModalState.HistoryIndex++
        }
    } else {
        # Move forward in history (newer commands)
        if ($script:ModalState.HistoryIndex -gt -1) {
            $script:ModalState.HistoryIndex--
        }
    }
    
    # Return command at current index
    if ($script:ModalState.HistoryIndex -eq -1) {
        return ''
    } else {
        $index = $script:ModalState.CommandHistory.Count - 1 - $script:ModalState.HistoryIndex
        return $script:ModalState.CommandHistory[$index]
    }
}

<#
.SYNOPSIS
    Gets the current selection index
#>
function Get-SelectedIndex {
    [CmdletBinding()]
    param()
    
    return $script:ModalState.SelectedIndex
}

<#
.SYNOPSIS
    Sets the current selection index
.PARAMETER Index
    The new selection index
#>
function Set-SelectedIndex {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [int]$Index
    )
    
    $script:ModalState.SelectedIndex = [Math]::Max(0, $Index)
    Write-Verbose "Selection index: $($script:ModalState.SelectedIndex)"
}

<#
.SYNOPSIS
    Stores search results for the current filter
.PARAMETER Results
    Array of items matching the search criteria
#>
function Set-SearchResults {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [array]$Results
    )
    
    $script:ModalState.SearchResults = $Results
    Write-Verbose "Search results: $($Results.Count) items"
}

<#
.SYNOPSIS
    Gets the current search results
#>
function Get-SearchResults {
    [CmdletBinding()]
    param()
    
    return $script:ModalState.SearchResults
}

<#
.SYNOPSIS
    Resets the modal engine to initial state
.DESCRIPTION
    Clears all state and returns to Normal mode.
#>
function Reset-ModalUIEngine {
    [CmdletBinding()]
    param()
    
    $script:ModalState.CurrentMode = 'Normal'
    $script:ModalState.PreviousMode = $null
    $script:ModalState.ModeHistory = @()
    $script:ModalState.KeyBuffer = ''
    $script:ModalState.SearchResults = @()
    $script:ModalState.SelectedIndex = 0
    $script:ModalState.HistoryIndex = -1
    # Preserve LastCommand and CommandHistory across resets
    
    Write-Verbose "Modal UI Engine reset to Normal mode"
}

# Export module members
Export-ModuleMember -Function @(
    'Initialize-ModalUIEngine',
    'Get-ModalState',
    'Enter-Mode',
    'Exit-Mode',
    'Add-ToKeyBuffer',
    'Remove-FromKeyBuffer',
    'Get-KeyBuffer',
    'Clear-KeyBuffer',
    'Add-ToCommandHistory',
    'Get-CommandFromHistory',
    'Get-SelectedIndex',
    'Set-SelectedIndex',
    'Set-SearchResults',
    'Get-SearchResults',
    'Reset-ModalUIEngine'
)

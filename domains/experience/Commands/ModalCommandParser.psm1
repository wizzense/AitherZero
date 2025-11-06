#Requires -Version 7.0
<#
.SYNOPSIS
    Modal Command Parser for VIM-like command mode
.DESCRIPTION
    Parses and executes commands entered in Command mode (`:` prefix).
    
    Supports commands like:
    - :run 0402
    - :orchestrate test-quick
    - :search error
    - :bookmark add
    - :session save
    - :health
    - :quit
    
    Also supports shortcuts:
    - :r 0402 (run)
    - :o test (orchestrate)
    - :s error (search)
    - :b (bookmarks)
    - :h (health)
    - :q (quit)
    
.NOTES
    Commands are executed in the context of the current menu/view.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Command aliases and shortcuts
$script:CommandAliases = @{
    'r' = 'run'
    'o' = 'orchestrate'
    's' = 'search'
    'b' = 'bookmarks'
    'bookmark' = 'bookmarks'
    'h' = 'health'
    'q' = 'quit'
    'exit' = 'quit'
    'x' = 'quit'
    'help' = 'show-help'
    'session' = 'session'
    'history' = 'show-history'
}

<#
.SYNOPSIS
    Parses a modal command string
.DESCRIPTION
    Parses command text entered in Command mode and returns structured result.
    
.PARAMETER CommandText
    The command text (with or without leading ':')
    
.OUTPUTS
    Hashtable with parsed command information:
    - IsValid: Boolean indicating if parse succeeded
    - Command: The main command name
    - Arguments: Array of arguments
    - RawText: Original command text
    - Error: Error message if parsing failed
    
.EXAMPLE
    Parse-ModalCommand ":run 0402"
    Returns: @{ IsValid=$true; Command='run'; Arguments=@('0402'); ... }
    
.EXAMPLE
    Parse-ModalCommand ":r 0402"
    Returns: @{ IsValid=$true; Command='run'; Arguments=@('0402'); ... }
#>
function Parse-ModalCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$CommandText
    )
    
    $result = @{
        IsValid = $false
        Command = $null
        Arguments = @()
        RawText = $CommandText
        Error = $null
    }
    
    # Trim whitespace and remove leading :
    $CommandText = $CommandText.Trim()
    if ($CommandText.StartsWith(':')) {
        $CommandText = $CommandText.Substring(1).Trim()
    }
    
    # Empty command
    if ([string]::IsNullOrWhiteSpace($CommandText)) {
        $result.Error = "Empty command"
        return $result
    }
    
    # Split into command and arguments
    $parts = $CommandText -split '\s+', 2
    $cmd = $parts[0].ToLower()
    $args = if ($parts.Count -gt 1) { $parts[1] } else { '' }
    
    # Resolve aliases
    if ($script:CommandAliases.ContainsKey($cmd)) {
        $cmd = $script:CommandAliases[$cmd]
    }
    
    # Parse arguments
    $argList = @()
    if (-not [string]::IsNullOrWhiteSpace($args)) {
        # Simple space-separated for now
        # Could enhance to handle quoted strings in future
        $argList = $args -split '\s+'
    }
    
    $result.IsValid = $true
    $result.Command = $cmd
    $result.Arguments = $argList
    
    return $result
}

<#
.SYNOPSIS
    Validates if a command is recognized
.DESCRIPTION
    Checks if the command is in the list of known commands.
    
.PARAMETER CommandName
    The command name to validate
    
.OUTPUTS
    Boolean indicating if command is valid
#>
function Test-ModalCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$CommandName
    )
    
    $validCommands = @(
        'run',
        'orchestrate',
        'search',
        'bookmarks',
        'health',
        'quit',
        'show-help',
        'session',
        'show-history'
    )
    
    return $CommandName -in $validCommands
}

<#
.SYNOPSIS
    Gets help text for a command
.DESCRIPTION
    Returns usage information for a specific command.
    
.PARAMETER CommandName
    The command to get help for
    
.OUTPUTS
    String with command help text
#>
function Get-ModalCommandHelp {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$CommandName
    )
    
    $helpText = @{
        'run' = @"
:run <script-number>
    
    Run an automation script by number.
    
    Examples:
        :run 0402       Run unit tests
        :r 0404         Run PSScriptAnalyzer (shortcut)
        :r 0510         Generate project report
"@
        'orchestrate' = @"
:orchestrate <playbook-name>
    
    Execute an orchestration playbook.
    
    Examples:
        :orchestrate test-quick
        :o test-full            (shortcut)
        :o infrastructure-lab
"@
        'search' = @"
:search <pattern>
    
    Search logs or content for a pattern.
    
    Examples:
        :search error
        :s warning      (shortcut)
        :s "failed test"
"@
        'bookmarks' = @"
:bookmarks
    
    Show saved bookmarks.
    
    Shortcuts: :b, :bookmark
"@
        'health' = @"
:health
    
    Show system health dashboard.
    
    Shortcuts: :h
"@
        'quit' = @"
:quit
    
    Exit current menu or application.
    
    Shortcuts: :q, :exit, :x
"@
        'session' = @"
:session <action> [name]
    
    Manage sessions.
    
    Actions:
        save [name]     Save current session
        restore <name>  Restore saved session
        list            List all sessions
        delete <name>   Delete a session
    
    Examples:
        :session save my-work
        :session restore my-work
        :session list
"@
        'show-help' = @"
:help
    
    Show help for commands.
    
    Examples:
        :help           Show all commands
        :help run       Show help for 'run' command
"@
    }
    
    if ($helpText.ContainsKey($CommandName)) {
        return $helpText[$CommandName]
    }
    
    return "No help available for command: $CommandName"
}

<#
.SYNOPSIS
    Gets all available commands with descriptions
.DESCRIPTION
    Returns a list of all modal commands and their descriptions.
    
.OUTPUTS
    Array of hashtables with Command and Description
#>
function Get-ModalCommands {
    [CmdletBinding()]
    param()
    
    return @(
        @{ Command = 'run'; Shortcuts = @('r'); Description = 'Run automation script' }
        @{ Command = 'orchestrate'; Shortcuts = @('o'); Description = 'Execute playbook' }
        @{ Command = 'search'; Shortcuts = @('s'); Description = 'Search logs/content' }
        @{ Command = 'bookmarks'; Shortcuts = @('b', 'bookmark'); Description = 'Show bookmarks' }
        @{ Command = 'health'; Shortcuts = @('h'); Description = 'Show health dashboard' }
        @{ Command = 'quit'; Shortcuts = @('q', 'exit', 'x'); Description = 'Exit/quit' }
        @{ Command = 'session'; Shortcuts = @(); Description = 'Manage sessions' }
        @{ Command = 'show-help'; Shortcuts = @('help'); Description = 'Show help' }
        @{ Command = 'show-history'; Shortcuts = @('history'); Description = 'Show command history' }
    )
}

<#
.SYNOPSIS
    Gets command suggestions for autocomplete
.DESCRIPTION
    Returns matching commands for autocomplete based on partial input.
    
.PARAMETER Partial
    Partial command text to match
    
.OUTPUTS
    Array of matching command names
#>
function Get-ModalCommandSuggestions {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Partial
    )
    
    if ([string]::IsNullOrWhiteSpace($Partial)) {
        # Return all commands
        $commands = Get-ModalCommands
        return $commands.Command
    }
    
    $Partial = $Partial.ToLower()
    
    # Get all commands and aliases
    $allCommands = @()
    $commands = Get-ModalCommands
    foreach ($cmd in $commands) {
        $allCommands += $cmd.Command
        $allCommands += $cmd.Shortcuts
    }
    
    # Filter by partial match
    $matches = $allCommands | Where-Object { $_ -like "$Partial*" } | Sort-Object -Unique
    
    return $matches
}

<#
.SYNOPSIS
    Formats a command for display
.DESCRIPTION
    Returns a nicely formatted string representation of a parsed command.
    
.PARAMETER ParsedCommand
    The parsed command hashtable from Parse-ModalCommand
    
.OUTPUTS
    Formatted string
#>
function Format-ModalCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$ParsedCommand
    )
    
    if (-not $ParsedCommand.IsValid) {
        return "Invalid: $($ParsedCommand.RawText) - $($ParsedCommand.Error)"
    }
    
    $formatted = ":$($ParsedCommand.Command)"
    
    if ($ParsedCommand.Arguments.Count -gt 0) {
        $formatted += " " + ($ParsedCommand.Arguments -join ' ')
    }
    
    return $formatted
}

<#
.SYNOPSIS
    Validates command arguments
.DESCRIPTION
    Checks if the command has valid arguments for its type.
    
.PARAMETER ParsedCommand
    The parsed command to validate
    
.OUTPUTS
    Hashtable with IsValid (bool) and Error (string)
#>
function Test-ModalCommandArguments {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$ParsedCommand
    )
    
    $result = @{
        IsValid = $true
        Error = $null
    }
    
    if (-not $ParsedCommand.IsValid) {
        $result.IsValid = $false
        $result.Error = $ParsedCommand.Error
        return $result
    }
    
    switch ($ParsedCommand.Command) {
        'run' {
            if ($ParsedCommand.Arguments.Count -eq 0) {
                $result.IsValid = $false
                $result.Error = "run command requires a script number"
            } elseif ($ParsedCommand.Arguments[0] -notmatch '^\d{4}$') {
                $result.IsValid = $false
                $result.Error = "Script number must be 4 digits (e.g., 0402)"
            }
        }
        'orchestrate' {
            if ($ParsedCommand.Arguments.Count -eq 0) {
                $result.IsValid = $false
                $result.Error = "orchestrate command requires a playbook name"
            }
        }
        'search' {
            if ($ParsedCommand.Arguments.Count -eq 0) {
                $result.IsValid = $false
                $result.Error = "search command requires a search pattern"
            }
        }
        'session' {
            if ($ParsedCommand.Arguments.Count -eq 0) {
                $result.IsValid = $false
                $result.Error = "session command requires an action (save, restore, list, delete)"
            }
        }
        # Other commands don't require arguments
    }
    
    return $result
}

# Export module members
Export-ModuleMember -Function @(
    'Parse-ModalCommand',
    'Test-ModalCommand',
    'Get-ModalCommandHelp',
    'Get-ModalCommands',
    'Get-ModalCommandSuggestions',
    'Format-ModalCommand',
    'Test-ModalCommandArguments'
)

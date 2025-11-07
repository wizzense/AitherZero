#Requires -Version 7.0
<#
.SYNOPSIS
    Command parser for unified CLI/menu interface
.DESCRIPTION
    Parses commands like "-Mode Run -Target 0402" or "-Mode Orchestrate -Playbook test-quick"
    Supports both full commands and shortcuts
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Parses a command string into structured parameters
.EXAMPLE
    Parse-AitherCommand "-Mode Run -Target 0402"
    Returns: @{ Mode = 'Run'; Target = '0402' }
#>
function Parse-AitherCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$CommandText
    )
    
    $result = @{
        IsValid = $false
        Mode = $null
        Parameters = @{}
        Error = $null
        RawText = $CommandText
    }
    
    # Trim whitespace
    $CommandText = $CommandText.Trim()
    
    # Empty command
    if ([string]::IsNullOrWhiteSpace($CommandText)) {
        $result.Error = "Empty command"
        return $result
    }
    
    # Check if it starts with a dash (parameter syntax)
    if (-not $CommandText.StartsWith('-')) {
        # Maybe it's a shortcut like "0402" or "test"
        $shortcut = Resolve-CommandShortcut -Shortcut $CommandText
        if ($shortcut) {
            return $shortcut
        }
        
        # Try to parse as just a script number
        if ($CommandText -match '^\d{4}$') {
            $result.IsValid = $true
            $result.Mode = 'Run'
            $result.Parameters.Target = $CommandText
            return $result
        }
        
        $result.Error = "Command must start with '-' or be a valid shortcut"
        return $result
    }
    
    # Parse parameters using a simple regex approach
    # Match patterns like -Name Value or -Name "Value with spaces"
    $paramPattern = '-(\w+)\s+(?:"([^"]+)"|(\S+))'
    $matches = [regex]::Matches($CommandText, $paramPattern)
    
    if ($matches.Count -eq 0) {
        $result.Error = "No valid parameters found"
        return $result
    }
    
    # Extract parameters
    foreach ($match in $matches) {
        $paramName = $match.Groups[1].Value
        $paramValue = if ($match.Groups[2].Success) {
            $match.Groups[2].Value  # Quoted value
        } else {
            $match.Groups[3].Value  # Unquoted value
        }
        
        # Handle Mode specially
        if ($paramName -eq 'Mode') {
            $result.Mode = $paramValue
        } else {
            $result.Parameters[$paramName] = $paramValue
        }
    }
    
    # Validate required parameters
    if (-not $result.Mode) {
        $result.Error = "Mode parameter is required"
        return $result
    }
    
    # Validate mode value (including extension modes)
    $validModes = @('Interactive', 'Orchestrate', 'Validate', 'Deploy', 'Test', 'List', 'Search', 'Run')
    
    # Initialize extension modes registry if not already set
    if (-not (Test-Path variable:global:AitherZeroExtensionModes)) {
        $global:AitherZeroExtensionModes = @{}
    }
    
    # Add extension modes if available
    if ($global:AitherZeroExtensionModes -and $global:AitherZeroExtensionModes.Count -gt 0) {
        $validModes += $global:AitherZeroExtensionModes.Keys
    }
    
    if ($result.Mode -notin $validModes) {
        $result.Error = "Invalid mode '$($result.Mode)'. Valid modes: $($validModes -join ', ')"
        return $result
    }
    
    # Check if this is an extension mode
    if ($global:AitherZeroExtensionModes -and $global:AitherZeroExtensionModes.ContainsKey($result.Mode)) {
        $result.IsExtensionMode = $true
        $result.ExtensionInfo = $global:AitherZeroExtensionModes[$result.Mode]
    }
    
    # Validate mode-specific parameters
    switch ($result.Mode) {
        'Run' {
            if (-not $result.Parameters.ContainsKey('Target') -and -not $result.Parameters.ContainsKey('ScriptNumber')) {
                $result.Error = "Run mode requires -Target or -ScriptNumber parameter"
                return $result
            }
        }
        'Orchestrate' {
            if (-not $result.Parameters.ContainsKey('Playbook')) {
                $result.Error = "Orchestrate mode requires -Playbook parameter"
                return $result
            }
        }
        'Search' {
            if (-not $result.Parameters.ContainsKey('Query')) {
                $result.Error = "Search mode requires -Query parameter"
                return $result
            }
        }
    }
    
    $result.IsValid = $true
    return $result
}

<#
.SYNOPSIS
    Resolves command shortcuts to full commands
.EXAMPLE
    Resolve-CommandShortcut "0402"
    Returns parsed command for running script 0402
#>
function Resolve-CommandShortcut {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Shortcut
    )
    
    # Built-in shortcuts
    $shortcuts = @{
        'test' = '-Mode Run -Target "0402,0404,0407"'
        'lint' = '-Mode Run -Target 0404'
        'validate' = '-Mode Run -Target 0407'
        'report' = '-Mode Run -Target 0510'
        'status' = '-Mode Run -Target 0550'
        'dashboard' = '-Mode Run -Target 0550'
        'quick-test' = '-Mode Orchestrate -Playbook test-quick'
        'full-test' = '-Mode Orchestrate -Playbook test-full'
    }
    
    if ($shortcuts.ContainsKey($Shortcut.ToLower())) {
        return Parse-AitherCommand -CommandText $shortcuts[$Shortcut.ToLower()]
    }
    
    return $null
}

<#
.SYNOPSIS
    Builds a command string from parameters
.EXAMPLE
    Build-AitherCommand -Mode Run -Parameters @{ Target = '0402' }
    Returns: "-Mode Run -Target 0402"
#>
function Build-AitherCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Mode,
        
        [hashtable]$Parameters = @{}
    )
    
    $parts = @("-Mode $Mode")
    
    foreach ($key in $Parameters.Keys) {
        $value = $Parameters[$key]
        
        # Quote values with spaces
        if ($value -match '\s') {
            $parts += "-$key `"$value`""
        } else {
            $parts += "-$key $value"
        }
    }
    
    return $parts -join ' '
}

<#
.SYNOPSIS
    Validates if a command is complete and ready to execute
#>
function Test-CommandComplete {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$ParsedCommand
    )
    
    return $ParsedCommand.IsValid -eq $true
}

<#
.SYNOPSIS
    Gets command suggestions based on partial input
.EXAMPLE
    Get-CommandSuggestions "-Mode R"
    Returns: @('Run')
#>
function Get-CommandSuggestions {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$PartialCommand
    )
    
    $suggestions = @()
    
    # If empty or just whitespace, suggest modes
    if ([string]::IsNullOrWhiteSpace($PartialCommand) -or $PartialCommand -eq '-') {
        return @('-Mode')
    }
    
    # If typing -Mode, suggest mode values
    if ($PartialCommand -match '-Mode\s+(\w*)$') {
        $partial = $matches[1]
        $validModes = @('Interactive', 'Orchestrate', 'Validate', 'Deploy', 'Test', 'List', 'Search', 'Run')
        $suggestions = $validModes | Where-Object { $_ -like "$partial*" }
        return $suggestions
    }
    
    # If mode is complete, suggest next parameter
    if ($PartialCommand -match '-Mode\s+(\w+)\s*-?(\w*)$') {
        $mode = $matches[1]
        $partial = $matches[2]
        
        $nextParams = switch ($mode) {
            'Run' { @('Target', 'ScriptNumber') }
            'Orchestrate' { @('Playbook', 'PlaybookProfile') }
            'Search' { @('Query') }
            'List' { @('Target') }
            default { @() }
        }
        
        if ($partial) {
            $suggestions = $nextParams | Where-Object { $_ -like "$partial*" } | ForEach-Object { "-$_" }
        } else {
            $suggestions = $nextParams | ForEach-Object { "-$_" }
        }
        
        return $suggestions
    }
    
    # If typing a parameter, suggest parameter names
    if ($PartialCommand -match '-(\w+)$') {
        $partial = $matches[1]
        $allParams = @('Mode', 'Target', 'ScriptNumber', 'Playbook', 'PlaybookProfile', 'Query', 'Sequence')
        $suggestions = $allParams | Where-Object { $_ -like "$partial*" } | ForEach-Object { "-$_" }
        return $suggestions
    }
    
    return $suggestions
}

<#
.SYNOPSIS
    Formats a parsed command for display
#>
function Format-ParsedCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$ParsedCommand
    )
    
    if (-not $ParsedCommand.IsValid) {
        return "Invalid: $($ParsedCommand.Error)"
    }
    
    $parts = @("Mode: $($ParsedCommand.Mode)")
    
    foreach ($key in $ParsedCommand.Parameters.Keys) {
        $parts += "$key=$($ParsedCommand.Parameters[$key])"
    }
    
    return $parts -join ', '
}

# Export functions
Export-ModuleMember -Function @(
    'Parse-AitherCommand'
    'Resolve-CommandShortcut'
    'Build-AitherCommand'
    'Test-CommandComplete'
    'Get-CommandSuggestions'
    'Format-ParsedCommand'
)

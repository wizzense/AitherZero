#Requires -Version 7.0
<#
.SYNOPSIS
    Text processing utilities to prevent character spacing issues
.DESCRIPTION
    Provides safe text processing functions that avoid common pitfalls
    that can cause text to be spaced out character by character.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Format-SafeDisplayText {
    <#
    .SYNOPSIS
        Safely format display text to prevent character spacing issues
    .PARAMETER Text
        The text to format
    .PARAMETER MaxLength
        Maximum length to truncate to (optional)
    .EXAMPLE
        Format-SafeDisplayText -Text "Orchestration Engine"
        Returns: "Orchestration Engine"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [string]$Text,
        
        [int]$MaxLength = 0
    )
    
    process {
        if ([string]::IsNullOrWhiteSpace($Text)) {
            return ""
        }
        
        # Ensure we're working with a proper string, not a character array
        $safeText = $Text.ToString().Trim()
        
        # Normalize whitespace (remove extra spaces, but keep words intact)
        $safeText = $safeText -replace '\s+', ' '
        
        # Truncate if requested
        if ($MaxLength -gt 0 -and $safeText.Length -gt $MaxLength) {
            $safeText = $safeText.Substring(0, $MaxLength - 3) + "..."
        }
        
        return $safeText
    }
}

function Format-ComponentName {
    <#
    .SYNOPSIS
        Format component names consistently and safely
    .PARAMETER Name
        The component name to format
    .PARAMETER RemovePrefixes
        Prefixes to remove (like "New-", "UI", etc.)
    .EXAMPLE
        Format-ComponentName -Name "New-UIOrchestrationEngineComponent"
        Returns: "Orchestration Engine"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,
        
        [string[]]$RemovePrefixes = @('New-', 'UI', 'Component')
    )
    
    if ([string]::IsNullOrWhiteSpace($Name)) {
        return ""
    }
    
    $formattedName = $Name.ToString()
    
    # Remove specified prefixes
    foreach ($prefix in $RemovePrefixes) {
        if ($formattedName.StartsWith($prefix)) {
            $formattedName = $formattedName.Substring($prefix.Length)
        }
    }
    
    # Remove suffix
    if ($formattedName.EndsWith('Component')) {
        $formattedName = $formattedName.Substring(0, $formattedName.Length - 9)
    }
    
    # Convert CamelCase to spaced text
    $formattedName = $formattedName -replace '([a-z])([A-Z])', '$1 $2'
    
    # Clean up any extra spaces
    $formattedName = $formattedName.Trim() -replace '\s+', ' '
    
    return $formattedName
}

function Test-TextProcessingSafety {
    <#
    .SYNOPSIS
        Test text processing functions to ensure they don't create character spacing
    .PARAMETER TestStrings
        Array of test strings to verify
    #>
    [CmdletBinding()]
    param(
        [string[]]$TestStrings = @(
            "Orchestration Engine",
            "Configuration Carousel", 
            "Configuration Repository Manager",
            "RemoteConnection"
        )
    )
    
    $results = @()
    
    foreach ($testString in $TestStrings) {
        $formatted = Format-SafeDisplayText -Text $testString
        $componentFormatted = Format-ComponentName -Name $testString
        
        $results += [PSCustomObject]@{
            Original = $testString
            SafeDisplay = $formatted
            ComponentFormat = $componentFormatted
            HasSpacingIssue = ($formatted -match '\s[a-zA-Z]\s') -or ($componentFormatted -match '\s[a-zA-Z]\s')
        }
    }
    
    return $results
}

# Export functions
Export-ModuleMember -Function @(
    'Format-SafeDisplayText',
    'Format-ComponentName',
    'Test-TextProcessingSafety'
)
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
        Format-SafeDisplayText -Text "O r c h e s t r a t i o n E n g i n e"
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
        
        $text = $Text.ToString().Trim()
        
        # Smart fix for both character and fragment spacing issues
        $text = $text -replace '\s+', ' '
        $words = $text -split '\s+'
        $totalWords = $words.Count
        
        # Check for single character spacing (e.g., "O r c h e s t r a t i o n")
        $singleCharWordsArray = @($words | Where-Object { $_.Length -eq 1 })
        $singleCharWords = $singleCharWordsArray.Count
        $hasSingleCharSpacing = $totalWords -gt 3 -and $singleCharWords / $totalWords -gt 0.5
        
        # Check for fragment spacing (e.g., "O rc he st ra ti on")  
        $shortWordsArray = @($words | Where-Object { $_.Length -le 2 })
        $shortWords = $shortWordsArray.Count
        $hasFragmentSpacing = $totalWords -gt 5 -and $shortWords / $totalWords -gt 0.6
        
        if ($hasSingleCharSpacing -or $hasFragmentSpacing) {
            $fragments = $words | Where-Object { $_ }
            $rebuiltWords = @()
            $currentWord = ""
            
            foreach ($fragment in $fragments) {
                if ($fragment -cmatch '^[A-Z]' -and $currentWord -ne "" -and $currentWord.Length -gt 1) {
                    # New word starting with uppercase
                    $rebuiltWords += $currentWord
                    $currentWord = $fragment
                } else {
                    # Continue building current word
                    $currentWord += $fragment
                }
                
                # Check if we should end current word (for fragment spacing)
                if ($hasFragmentSpacing -and $currentWord.Length -ge 6 -and $fragment -notmatch '^[A-Z]') {
                    $nextIndex = [array]::IndexOf($fragments, $fragment) + 1
                    if ($nextIndex -lt $fragments.Count -and $fragments[$nextIndex] -cmatch '^[A-Z]') {
                        $rebuiltWords += $currentWord
                        $currentWord = ""
                    }
                }
            }
            
            if ($currentWord -ne "") {
                $rebuiltWords += $currentWord
            }
            
            $text = $rebuiltWords -join ' '
        }
        
        # Truncate if requested
        if ($MaxLength -gt 0 -and $text.Length -gt $MaxLength) {
            $text = $text.Substring(0, $MaxLength - 3) + "..."
        }
        
        return $text
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
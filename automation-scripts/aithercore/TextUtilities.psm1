#Requires -Version 7.0

<#
.SYNOPSIS
    Text processing utilities for AitherZero
.DESCRIPTION
    Provides text manipulation functions including character spacing repair
#>

function Repair-TextSpacing {
    <#
    .SYNOPSIS
        Repairs character-spaced text by intelligently reconstructing words
    .DESCRIPTION
        Detects text with excessive character spacing (e.g., "O rc he st ra ti on")
        and reconstructs it into properly formatted text (e.g., "Orchestration")
    .PARAMETER Text
        The text to repair
    .EXAMPLE
        Repair-TextSpacing "O rc he st ra ti on En gi ne"
        Returns: "Orchestration Engine"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Text
    )

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return $Text
    }

    # Split into words
    $words = $Text -split '\s+'
    
    # Check if text has excessive single-character or short fragments
    $shortWords = $words | Where-Object { $_.Length -le 2 }
    $shortWordRatio = if ($words.Count -gt 0) { $shortWords.Count / $words.Count } else { 0 }
    
    # If more than 60% of words are 2 chars or less, likely character-spaced
    if ($shortWordRatio -gt 0.6 -and $words.Count -gt 3) {
        # Reconstruct by joining characters intelligently
        $result = ""
        $currentWord = ""
        
        foreach ($fragment in $words) {
            # If fragment starts with uppercase and we have a current word, start new word
            if ($fragment -cmatch '^[A-Z]' -and $currentWord.Length -gt 0) {
                $result += $currentWord + " "
                $currentWord = $fragment
            } else {
                $currentWord += $fragment
            }
        }
        
        # Add the last word
        if ($currentWord) {
            $result += $currentWord
        }
        
        return $result.Trim()
    }
    
    # Return original text if no spacing issues detected
    return $Text
}

Export-ModuleMember -Function Repair-TextSpacing

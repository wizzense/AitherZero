function Confirm-Action {
    <#
    .SYNOPSIS
        Prompts user for confirmation of an action
    .DESCRIPTION
        Displays a confirmation prompt and returns user response
    .PARAMETER Message
        The confirmation message to display
    .PARAMETER Title
        Optional title for the confirmation dialog
    .PARAMETER DefaultChoice
        Default choice if user presses Enter (0 for Yes, 1 for No)
    .OUTPUTS
        Boolean indicating user choice (True for Yes, False for No)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        
        [Parameter()]
        [string]$Title = "Confirm Action",
        
        [Parameter()]
        [int]$DefaultChoice = 1  # Default to No for safety
    )
    
    try {
        # Use PowerShell's built-in confirmation if available
        if (Get-Command -Name 'Get-Host' -ErrorAction SilentlyContinue) {
            $choices = @(
                (New-Object System.Management.Automation.Host.ChoiceDescription '&Yes', 'Confirm the action')
                (New-Object System.Management.Automation.Host.ChoiceDescription '&No', 'Cancel the action')
            )
            
            $result = $Host.UI.PromptForChoice($Title, $Message, $choices, $DefaultChoice)
            return $result -eq 0
        }
        
        # Fallback to simple Read-Host
        Write-Host ""
        Write-Host $Title -ForegroundColor Yellow
        Write-Host $Message -ForegroundColor White
        Write-Host ""
        
        do {
            $response = Read-Host "Continue? (y/N)"
            if ([string]::IsNullOrWhiteSpace($response)) {
                return $DefaultChoice -eq 0
            }
            
            $response = $response.ToLower().Trim()
            
            if ($response -in @('y', 'yes', 'true', '1')) {
                return $true
            } elseif ($response -in @('n', 'no', 'false', '0')) {
                return $false
            } else {
                Write-Host "Please enter 'y' for Yes or 'n' for No" -ForegroundColor Yellow
            }
        } while ($true)
        
    } catch {
        Write-Warning "Error in confirmation prompt: $($_.Exception.Message)"
        return $false
    }
}
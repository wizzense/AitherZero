function Show-SetupPrompt {
    <#
    .SYNOPSIS
        Show interactive prompt during setup with fallback for non-interactive environments
    .DESCRIPTION
        Provides consistent prompting behavior across different environments
    .PARAMETER Message
        Message to display to user
    .PARAMETER DefaultYes
        Whether to default to Yes (true) or No (false)
    .EXAMPLE
        $response = Show-SetupPrompt -Message "Continue with setup?" -DefaultYes
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        [switch]$DefaultYes
    )

    # In non-interactive mode or when host doesn't support prompts, use default
    if ([System.Console]::IsInputRedirected -or $env:NO_PROMPT -or $global:WhatIfPreference) {
        Write-Host "$Message [$(if ($DefaultYes) { 'Y' } else { 'N' })]" -ForegroundColor Yellow
        return $DefaultYes
    }

    try {
        $choices = '&Yes', '&No'
        $decision = $Host.UI.PromptForChoice('', $Message, $choices, $(if ($DefaultYes) { 0 } else { 1 }))
        return $decision -eq 0
    } catch {
        # Fallback to default if prompt fails
        Write-Host "$Message [$(if ($DefaultYes) { 'Y' } else { 'N' })] (auto-selected)" -ForegroundColor Yellow
        return $DefaultYes
    }
}
function Get-StartupMode {
    <#
    .SYNOPSIS
        Determines the appropriate startup mode
    .DESCRIPTION
        Analyzes parameters and environment to determine whether to use interactive or non-interactive mode
    .PARAMETER Parameters
        Hashtable of parameters passed to Start-AitherZero
    .EXAMPLE
        $mode = Get-StartupMode -Parameters $PSBoundParameters
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [hashtable]$Parameters = @{}
    )
    
    try {
        # Check for explicit mode parameters
        if ($Parameters.ContainsKey('NonInteractive') -or $Parameters.ContainsKey('Auto')) {
            return [PSCustomObject]@{
                Mode = 'NonInteractive'
                Reason = 'Explicit non-interactive parameter'
                UseEnhancedUI = $false
            }
        }
        
        if ($Parameters.ContainsKey('Interactive') -or $Parameters.ContainsKey('Quickstart')) {
            return [PSCustomObject]@{
                Mode = 'Interactive'
                Reason = 'Explicit interactive parameter'
                UseEnhancedUI = $true
            }
        }
        
        # Check if running in CI/CD environment
        $ciVariables = @(
            'CI',
            'TF_BUILD',
            'GITHUB_ACTIONS',
            'GITLAB_CI',
            'JENKINS_URL',
            'TEAMCITY_VERSION',
            'TRAVIS',
            'CIRCLECI',
            'APPVEYOR',
            'CODEBUILD_BUILD_ID'
        )
        
        foreach ($var in $ciVariables) {
            if (Get-Item "Env:$var" -ErrorAction SilentlyContinue) {
                return [PSCustomObject]@{
                    Mode = 'NonInteractive'
                    Reason = "CI/CD environment detected ($var)"
                    UseEnhancedUI = $false
                }
            }
        }
        
        # Check if running in non-interactive shell
        if (-not [Environment]::UserInteractive) {
            return [PSCustomObject]@{
                Mode = 'NonInteractive'
                Reason = 'Non-interactive shell detected'
                UseEnhancedUI = $false
            }
        }
        
        # Check if stdout is redirected
        if (-not [Console]::IsOutputRedirected) {
            # Interactive terminal available
            return [PSCustomObject]@{
                Mode = 'Interactive'
                Reason = 'Interactive terminal detected'
                UseEnhancedUI = $true
            }
        }
        
        # Default to non-interactive
        return [PSCustomObject]@{
            Mode = 'NonInteractive'
            Reason = 'Default mode'
            UseEnhancedUI = $false
        }
        
    } catch {
        # If we can't determine, default to non-interactive
        return [PSCustomObject]@{
            Mode = 'NonInteractive'
            Reason = "Error determining mode: $_"
            UseEnhancedUI = $false
        }
    }
}
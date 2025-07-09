function Get-StartupMode {
    <#
    .SYNOPSIS
        Determines the appropriate startup mode with performance analytics
    .DESCRIPTION
        Analyzes parameters and environment to determine whether to use interactive or non-interactive mode.
        Includes performance metrics and UI capability detection.
    .PARAMETER Parameters
        Hashtable of parameters passed to Start-AitherZero
    .PARAMETER IncludeAnalytics
        Include detailed performance and capability analytics
    .EXAMPLE
        $mode = Get-StartupMode -Parameters $PSBoundParameters
    .EXAMPLE
        $mode = Get-StartupMode -IncludeAnalytics
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [hashtable]$Parameters = @{},

        [Parameter()]
        [switch]$IncludeAnalytics
    )

    try {
        $startTime = Get-Date
        $analytics = @{}

        # Check for explicit mode parameters
        if ($Parameters.ContainsKey('NonInteractive') -or $Parameters.ContainsKey('Auto')) {
            $result = [PSCustomObject]@{
                Mode = 'NonInteractive'
                Reason = 'Explicit non-interactive parameter'
                UseEnhancedUI = $false
                UICapability = 'Disabled'
            }

            if ($IncludeAnalytics) {
                $result | Add-Member -MemberType NoteProperty -Name 'Analytics' -Value @{
                    DetectionTime = ((Get-Date) - $startTime).TotalMilliseconds
                    Method = 'Parameter'
                }
            }

            return $result
        }

        if ($Parameters.ContainsKey('Interactive') -or $Parameters.ContainsKey('Quickstart')) {
            $uiCapability = Test-EnhancedUICapability

            $result = [PSCustomObject]@{
                Mode = 'Interactive'
                Reason = 'Explicit interactive parameter'
                UseEnhancedUI = $uiCapability
                UICapability = if ($uiCapability) { 'Enhanced' } else { 'Classic' }
            }

            if ($IncludeAnalytics) {
                $result | Add-Member -MemberType NoteProperty -Name 'Analytics' -Value @{
                    DetectionTime = ((Get-Date) - $startTime).TotalMilliseconds
                    Method = 'Parameter'
                    UITest = $uiCapability
                }
            }

            return $result
        }

        # Performance: Check environment variables
        $envCheckStart = Get-Date
        $ciVariables = @(
            'CI', 'TF_BUILD', 'GITHUB_ACTIONS', 'GITLAB_CI', 'JENKINS_URL',
            'TEAMCITY_VERSION', 'TRAVIS', 'CIRCLECI', 'APPVEYOR', 'CODEBUILD_BUILD_ID'
        )

        foreach ($var in $ciVariables) {
            if (Get-Item "Env:$var" -ErrorAction SilentlyContinue) {
                $result = [PSCustomObject]@{
                    Mode = 'NonInteractive'
                    Reason = "CI/CD environment detected ($var)"
                    UseEnhancedUI = $false
                    UICapability = 'Unavailable'
                }

                if ($IncludeAnalytics) {
                    $result | Add-Member -MemberType NoteProperty -Name 'Analytics' -Value @{
                        DetectionTime = ((Get-Date) - $startTime).TotalMilliseconds
                        Method = 'Environment'
                        DetectedVariable = $var
                        EnvCheckTime = ((Get-Date) - $envCheckStart).TotalMilliseconds
                    }
                }

                return $result
            }
        }

        # Performance: Check terminal capabilities
        $terminalCheckStart = Get-Date

        # Check if running in non-interactive shell
        if (-not [Environment]::UserInteractive) {
            $result = [PSCustomObject]@{
                Mode = 'NonInteractive'
                Reason = 'Non-interactive shell detected'
                UseEnhancedUI = $false
                UICapability = 'Unavailable'
            }

            if ($IncludeAnalytics) {
                $result | Add-Member -MemberType NoteProperty -Name 'Analytics' -Value @{
                    DetectionTime = ((Get-Date) - $startTime).TotalMilliseconds
                    Method = 'Shell'
                    TerminalCheckTime = ((Get-Date) - $terminalCheckStart).TotalMilliseconds
                }
            }

            return $result
        }

        # Check terminal capabilities
        $uiCapability = Test-EnhancedUICapability
        $isOutputRedirected = [Console]::IsOutputRedirected

        if (-not $isOutputRedirected -and $uiCapability) {
            # Interactive terminal with enhanced capabilities
            $result = [PSCustomObject]@{
                Mode = 'Interactive'
                Reason = 'Enhanced interactive terminal detected'
                UseEnhancedUI = $true
                UICapability = 'Enhanced'
            }
        } elseif (-not $isOutputRedirected) {
            # Interactive terminal with limited capabilities
            $result = [PSCustomObject]@{
                Mode = 'Interactive'
                Reason = 'Basic interactive terminal detected'
                UseEnhancedUI = $false
                UICapability = 'Classic'
            }
        } else {
            # Output redirected - non-interactive
            $result = [PSCustomObject]@{
                Mode = 'NonInteractive'
                Reason = 'Output redirection detected'
                UseEnhancedUI = $false
                UICapability = 'Unavailable'
            }
        }

        if ($IncludeAnalytics) {
            $result | Add-Member -MemberType NoteProperty -Name 'Analytics' -Value @{
                DetectionTime = ((Get-Date) - $startTime).TotalMilliseconds
                Method = 'Terminal'
                TerminalCheckTime = ((Get-Date) - $terminalCheckStart).TotalMilliseconds
                OutputRedirected = $isOutputRedirected
                UICapabilityTest = $uiCapability
            }
        }

        return $result

    } catch {
        # If we can't determine, default to non-interactive
        $result = [PSCustomObject]@{
            Mode = 'NonInteractive'
            Reason = "Error determining mode: $_"
            UseEnhancedUI = $false
            UICapability = 'Error'
        }

        if ($IncludeAnalytics) {
            $result | Add-Member -MemberType NoteProperty -Name 'Analytics' -Value @{
                DetectionTime = ((Get-Date) - $startTime).TotalMilliseconds
                Method = 'Error'
                Error = $_.Exception.Message
            }
        }

        return $result
    }
}

function Test-StartupPerformance {
    <#
    .SYNOPSIS
        Tests startup performance and provides optimization recommendations
    #>
    [CmdletBinding()]
    param()

    $results = @{}

    # Test mode detection performance
    $modeTestStart = Get-Date
    $mode = Get-StartupMode -IncludeAnalytics
    $results.ModeDetection = @{
        Time = ((Get-Date) - $modeTestStart).TotalMilliseconds
        Result = $mode
    }

    # Test module discovery performance
    $discoveryTestStart = Get-Date
    $modules = Get-ModuleDiscovery -UseCache:$false
    $results.ModuleDiscovery = @{
        Time = ((Get-Date) - $discoveryTestStart).TotalMilliseconds
        ModulesFound = $modules.Count
    }

    # Test cached module discovery
    $cachedTestStart = Get-Date
    $cachedModules = Get-ModuleDiscovery -UseCache:$true
    $results.CachedModuleDiscovery = @{
        Time = ((Get-Date) - $cachedTestStart).TotalMilliseconds
        ModulesFound = $cachedModules.Count
    }

    # Test UI capability
    $uiTestStart = Get-Date
    $uiCapability = Test-EnhancedUICapability
    $results.UICapabilityTest = @{
        Time = ((Get-Date) - $uiTestStart).TotalMilliseconds
        Result = $uiCapability
    }

    return [PSCustomObject]$results
}

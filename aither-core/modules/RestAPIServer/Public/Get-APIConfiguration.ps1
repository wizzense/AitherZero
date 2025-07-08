<#
.SYNOPSIS
    Retrieves the current API server configuration.

.DESCRIPTION
    Get-APIConfiguration returns the current configuration settings for the
    API server including port, authentication, CORS, rate limiting, and more.

.PARAMETER Section
    Specific configuration section to retrieve (e.g., 'WebhookConfig', 'RateLimit', 'Security').

.PARAMETER Format
    Output format: Table, List, or JSON.

.PARAMETER IncludeSecrets
    Include sensitive configuration values like API keys and secrets.

.EXAMPLE
    Get-APIConfiguration
    Retrieves the complete API server configuration.

.EXAMPLE
    Get-APIConfiguration -Section "WebhookConfig" -Format JSON
    Retrieves only the webhook configuration in JSON format.

.EXAMPLE
    Get-APIConfiguration -IncludeSecrets -Format List
    Retrieves the configuration including sensitive values.
#>
function Get-APIConfiguration {
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateSet('WebhookConfig', 'RateLimit', 'Security', 'Authentication', 'CORS', 'Logging')]
        [string]$Section,

        [Parameter()]
        [ValidateSet('Table', 'List', 'JSON')]
        [string]$Format = 'List',

        [Parameter()]
        [switch]$IncludeSecrets
    )

    begin {
        Write-CustomLog -Message "Retrieving API server configuration" -Level "DEBUG"
    }

    process {
        try {
            # Initialize configuration if not present
            Initialize-APIConfiguration

            # Get configuration copy
            $config = $script:APIConfiguration.Clone()

            # Add runtime information
            $config.RuntimeInfo = @{
                ServerRunning = Test-APIServerRunning
                StartTime = $script:APIStartTime
                TotalEndpoints = $script:RegisteredEndpoints.Count
                TotalWebhooks = $script:WebhookSubscriptions.Count
                RequestCount = $script:APIMetrics.RequestCount
                ErrorCount = $script:APIMetrics.ErrorCount
                UpTime = if ($script:APIStartTime) {
                    (Get-Date) - $script:APIStartTime
                } else {
                    $null
                }
            }

            # Remove secrets if not requested
            if (-not $IncludeSecrets) {
                if ($config.ContainsKey('ApiKey')) {
                    $config.ApiKey = '[HIDDEN]'
                }
                if ($config.ContainsKey('SSLCertificate')) {
                    $config.SSLCertificate = '[HIDDEN]'
                }
                if ($config.Security -and $config.Security.ContainsKey('Secrets')) {
                    $config.Security.Secrets = '[HIDDEN]'
                }
            }

            # Filter by section if requested
            if ($Section) {
                if ($config.ContainsKey($Section)) {
                    $config = @{
                        $Section = $config[$Section]
                    }
                } else {
                    throw "Configuration section '$Section' not found"
                }
            }

            # Format output
            switch ($Format) {
                'JSON' {
                    return $config | ConvertTo-Json -Depth 10
                }
                'Table' {
                    if ($Section) {
                        # For single section, flatten the structure
                        $tableData = @()
                        foreach ($key in $config[$Section].Keys) {
                            $tableData += @{
                                Setting = $key
                                Value = $config[$Section][$key]
                            }
                        }
                        return $tableData | Format-Table -Property Setting, Value -AutoSize
                    } else {
                        # For full config, show top-level settings
                        $tableData = @()
                        foreach ($key in $config.Keys) {
                            $value = $config[$key]
                            if ($value -is [hashtable]) {
                                $value = "[Object: $($value.Keys.Count) properties]"
                            }
                            $tableData += @{
                                Setting = $key
                                Value = $value
                            }
                        }
                        return $tableData | Format-Table -Property Setting, Value -AutoSize
                    }
                }
                'List' {
                    return $config
                }
            }

        } catch {
            $errorMessage = "Failed to retrieve API configuration: $($_.Exception.Message)"
            Write-CustomLog -Message $errorMessage -Level "ERROR"
            throw
        }
    }
}

Export-ModuleMember -Function Get-APIConfiguration

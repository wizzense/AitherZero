<#
.SYNOPSIS
    Updates the API server configuration.

.DESCRIPTION
    Set-APIConfiguration allows updating various aspects of the API server
    configuration including port, authentication, CORS, rate limiting, and more.

.PARAMETER Port
    The port number for the API server.

.PARAMETER Protocol
    The protocol to use (HTTP or HTTPS).

.PARAMETER SSLEnabled
    Enable SSL/TLS encryption.

.PARAMETER Authentication
    Authentication method (None, ApiKey, Bearer, Basic).

.PARAMETER CorsEnabled
    Enable Cross-Origin Resource Sharing.

.PARAMETER RateLimitEnabled
    Enable rate limiting.

.PARAMETER LoggingEnabled
    Enable request logging.

.PARAMETER MaxRequestSize
    Maximum request size in bytes.

.PARAMETER RequestTimeout
    Request timeout in seconds.

.PARAMETER Configuration
    A hashtable containing complete configuration settings.

.PARAMETER RestartServer
    Restart the server if it's currently running to apply changes.

.EXAMPLE
    Set-APIConfiguration -Port 8081 -Authentication "Bearer" -RestartServer
    Updates the port and authentication method, then restarts the server.

.EXAMPLE
    Set-APIConfiguration -Configuration @{
        Port = 9000
        SSLEnabled = $true
        Authentication = 'Bearer'
        CorsEnabled = $true
    }
    Updates multiple configuration settings at once.
#>
function Set-APIConfiguration {
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateRange(1, 65535)]
        [int]$Port,
        
        [Parameter()]
        [ValidateSet('HTTP', 'HTTPS')]
        [string]$Protocol,
        
        [Parameter()]
        [switch]$SSLEnabled,
        
        [Parameter()]
        [ValidateSet('None', 'ApiKey', 'Bearer', 'Basic')]
        [string]$Authentication,
        
        [Parameter()]
        [switch]$CorsEnabled,
        
        [Parameter()]
        [switch]$RateLimitEnabled,
        
        [Parameter()]
        [switch]$LoggingEnabled,
        
        [Parameter()]
        [ValidateRange(1KB, 100MB)]
        [int]$MaxRequestSize,
        
        [Parameter()]
        [ValidateRange(1, 3600)]
        [int]$RequestTimeout,
        
        [Parameter()]
        [hashtable]$Configuration,
        
        [Parameter()]
        [switch]$RestartServer
    )

    begin {
        Write-CustomLog -Message "Updating API server configuration" -Level "INFO"
    }

    process {
        try {
            $wasRunning = Test-APIServerRunning
            $changes = @()
            
            # If Configuration hashtable is provided, merge it
            if ($Configuration) {
                foreach ($key in $Configuration.Keys) {
                    if ($script:APIConfiguration.ContainsKey($key)) {
                        $oldValue = $script:APIConfiguration[$key]
                        $script:APIConfiguration[$key] = $Configuration[$key]
                        $changes += "Changed $key from $oldValue to $($Configuration[$key])"
                    } else {
                        $script:APIConfiguration[$key] = $Configuration[$key]
                        $changes += "Added $key = $($Configuration[$key])"
                    }
                }
            }
            
            # Apply individual parameter changes
            if ($PSBoundParameters.ContainsKey('Port')) {
                $oldPort = $script:APIConfiguration.Port
                $script:APIConfiguration.Port = $Port
                $changes += "Changed Port from $oldPort to $Port"
            }
            
            if ($PSBoundParameters.ContainsKey('Protocol')) {
                $oldProtocol = $script:APIConfiguration.Protocol
                $script:APIConfiguration.Protocol = $Protocol
                $changes += "Changed Protocol from $oldProtocol to $Protocol"
            }
            
            if ($PSBoundParameters.ContainsKey('SSLEnabled')) {
                $oldSSL = $script:APIConfiguration.SSLEnabled
                $script:APIConfiguration.SSLEnabled = $SSLEnabled.IsPresent
                $changes += "Changed SSLEnabled from $oldSSL to $($SSLEnabled.IsPresent)"
            }
            
            if ($PSBoundParameters.ContainsKey('Authentication')) {
                $oldAuth = $script:APIConfiguration.Authentication
                $script:APIConfiguration.Authentication = $Authentication
                $changes += "Changed Authentication from $oldAuth to $Authentication"
            }
            
            if ($PSBoundParameters.ContainsKey('CorsEnabled')) {
                $oldCors = $script:APIConfiguration.CorsEnabled
                $script:APIConfiguration.CorsEnabled = $CorsEnabled.IsPresent
                $changes += "Changed CorsEnabled from $oldCors to $($CorsEnabled.IsPresent)"
            }
            
            if ($PSBoundParameters.ContainsKey('RateLimitEnabled')) {
                $oldRateLimit = $script:APIConfiguration.RateLimiting
                $script:APIConfiguration.RateLimiting = $RateLimitEnabled.IsPresent
                $changes += "Changed RateLimiting from $oldRateLimit to $($RateLimitEnabled.IsPresent)"
            }
            
            if ($PSBoundParameters.ContainsKey('LoggingEnabled')) {
                $oldLogging = $script:APIConfiguration.LoggingEnabled
                $script:APIConfiguration.LoggingEnabled = $LoggingEnabled.IsPresent
                $changes += "Changed LoggingEnabled from $oldLogging to $($LoggingEnabled.IsPresent)"
            }
            
            if ($PSBoundParameters.ContainsKey('MaxRequestSize')) {
                $oldMaxSize = $script:APIConfiguration.MaxRequestSize
                $script:APIConfiguration.MaxRequestSize = $MaxRequestSize
                $changes += "Changed MaxRequestSize from $oldMaxSize to $MaxRequestSize"
            }
            
            if ($PSBoundParameters.ContainsKey('RequestTimeout')) {
                $oldTimeout = $script:APIConfiguration.RequestTimeout
                $script:APIConfiguration.RequestTimeout = $RequestTimeout
                $changes += "Changed RequestTimeout from $oldTimeout to $RequestTimeout"
            }
            
            # Initialize extended configuration if not present
            Initialize-APIConfiguration
            
            # Log changes
            foreach ($change in $changes) {
                Write-CustomLog -Message $change -Level "INFO"
            }
            
            # Restart server if requested and was running
            if ($RestartServer -and $wasRunning) {
                Write-CustomLog -Message "Restarting API server to apply configuration changes" -Level "INFO"
                Stop-AitherZeroAPI
                Start-Sleep -Seconds 2
                Start-AitherZeroAPI
            }
            
            Write-CustomLog -Message "API configuration updated successfully" -Level "SUCCESS"
            
            return @{
                Success = $true
                Changes = $changes
                Configuration = $script:APIConfiguration.Clone()
                ServerRestarted = ($RestartServer -and $wasRunning)
                Message = "Configuration updated with $($changes.Count) changes"
            }

        } catch {
            $errorMessage = "Failed to update API configuration: $($_.Exception.Message)"
            Write-CustomLog -Message $errorMessage -Level "ERROR"
            
            return @{
                Success = $false
                Error = $_.Exception.Message
                Message = $errorMessage
            }
        }
    }
}

Export-ModuleMember -Function Set-APIConfiguration
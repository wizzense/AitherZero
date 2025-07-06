function Test-APIServerRunning {
    <#
    .SYNOPSIS
        Test if the API server is currently running
    .DESCRIPTION
        Checks if the API server is running and responding
    #>
    [CmdletBinding()]
    param()
    
    try {
        return ($null -ne $script:APIServer -and $script:APIServer.IsListening)
    } catch {
        return $false
    }
}

function Get-APIServerConfiguration {
    <#
    .SYNOPSIS
        Get the current API server configuration
    .DESCRIPTION
        Returns the current configuration object for the API server
    #>
    [CmdletBinding()]
    param()
    
    return $script:APIConfiguration.Clone()
}

function Set-APIServerConfiguration {
    <#
    .SYNOPSIS
        Set API server configuration
    .DESCRIPTION
        Updates the API server configuration
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Configuration
    )
    
    $script:APIConfiguration = $Configuration
}

function Invoke-APIEndpointHandler {
    <#
    .SYNOPSIS
        Invoke an API endpoint handler
    .DESCRIPTION
        Executes the handler for a registered API endpoint
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Request,
        
        [Parameter(Mandatory)]
        [object]$Response,
        
        [Parameter(Mandatory)]
        [object]$EndpointConfig
    )
    
    try {
        # Extract parameters from request
        $parameters = @{}
        
        # Get query parameters
        foreach ($key in $Request.QueryString.AllKeys) {
            $parameters[$key] = $Request.QueryString[$key]
        }
        
        # Get body parameters for POST/PUT/PATCH
        if ($Request.HttpMethod -in @('POST', 'PUT', 'PATCH')) {
            $reader = New-Object System.IO.StreamReader($Request.InputStream)
            $body = $reader.ReadToEnd()
            $reader.Close()
            
            if ($body) {
                try {
                    $bodyData = $body | ConvertFrom-Json
                    foreach ($property in $bodyData.PSObject.Properties) {
                        $parameters[$property.Name] = $property.Value
                    }
                } catch {
                    # If not JSON, treat as form data
                    $parameters['Body'] = $body
                }
            }
        }
        
        # Execute handler
        $handlerResult = $null
        if ($EndpointConfig.HandlerType -eq 'ScriptBlock') {
            $handlerResult = & $EndpointConfig.Handler -Request $Request -Parameters $parameters
        } else {
            $handlerResult = & $EndpointConfig.Handler -Request $Request -Parameters $parameters
        }
        
        # Return result
        return $handlerResult
        
    } catch {
        Write-CustomLog -Message "Error executing endpoint handler: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

function Send-APIResponse {
    <#
    .SYNOPSIS
        Send a response to an API request
    .DESCRIPTION
        Formats and sends a response to an API request
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Response,
        
        [Parameter()]
        [object]$Data,
        
        [Parameter()]
        [int]$StatusCode = 200,
        
        [Parameter()]
        [string]$ContentType = 'application/json'
    )
    
    try {
        $Response.StatusCode = $StatusCode
        $Response.ContentType = $ContentType
        
        if ($Data) {
            $jsonResponse = $Data | ConvertTo-Json -Depth 10
            $buffer = [System.Text.Encoding]::UTF8.GetBytes($jsonResponse)
            $Response.ContentLength64 = $buffer.Length
            $Response.OutputStream.Write($buffer, 0, $buffer.Length)
        }
        
        $Response.Close()
        
    } catch {
        Write-CustomLog -Message "Error sending API response: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

function Test-APIAuthentication {
    <#
    .SYNOPSIS
        Test API authentication
    .DESCRIPTION
        Validates API authentication for a request
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Request,
        
        [Parameter()]
        [string[]]$RequiredRoles = @()
    )
    
    try {
        # Get authorization header
        $authHeader = $Request.Headers['Authorization']
        if (-not $authHeader) {
            return @{
                IsAuthenticated = $false
                Error = 'No authorization header provided'
            }
        }
        
        # Parse bearer token
        if ($authHeader -match '^Bearer\s+(.+)$') {
            $token = $Matches[1]
            
            # Validate token (placeholder - implement actual token validation)
            if ($token -eq 'test-token') {
                return @{
                    IsAuthenticated = $true
                    User = 'test-user'
                    Roles = @('admin')
                }
            } else {
                return @{
                    IsAuthenticated = $false
                    Error = 'Invalid token'
                }
            }
        } else {
            return @{
                IsAuthenticated = $false
                Error = 'Invalid authorization header format'
            }
        }
        
    } catch {
        Write-CustomLog -Message "Error validating API authentication: $($_.Exception.Message)" -Level "ERROR"
        return @{
            IsAuthenticated = $false
            Error = $_.Exception.Message
        }
    }
}

function Initialize-APIConfiguration {
    <#
    .SYNOPSIS
        Initialize API configuration with defaults
    .DESCRIPTION
        Sets up default API configuration if not already configured
    #>
    [CmdletBinding()]
    param()
    
    if (-not $script:APIConfiguration.WebhookConfig) {
        $script:APIConfiguration.WebhookConfig = @{
            Enabled = $false
            Events = @('test.completed', 'deployment.finished', 'error.occurred', 'module.loaded', 'configuration.changed')
            RetryAttempts = 3
            Timeout = 30
            MaxSubscriptions = 100
            DeliveryHistory = @()
        }
    }
    
    if (-not $script:APIConfiguration.RateLimit) {
        $script:APIConfiguration.RateLimit = @{
            Enabled = $true
            RequestsPerMinute = 100
            BurstLimit = 20
            WindowSize = 60
            Clients = @{}
        }
    }
    
    if (-not $script:APIConfiguration.Security) {
        $script:APIConfiguration.Security = @{
            RequireHTTPS = $false
            AllowedOrigins = @('*')
            MaxRequestSize = 1MB
            EnableLogging = $true
            LogLevel = 'INFO'
        }
    }
}
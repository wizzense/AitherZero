<#
.SYNOPSIS
    Starts the AitherZero REST API server for external integrations.

.DESCRIPTION
    Start-AitherZeroAPI launches a REST API server that exposes AitherZero
    automation capabilities through HTTP endpoints, enabling third-party
    system integration and remote automation control.

.PARAMETER Port
    The port number for the API server. Default is 8080.

.PARAMETER Protocol
    The protocol to use (HTTP or HTTPS). Default is HTTP.

.PARAMETER EnableSSL
    Enable SSL/TLS encryption for HTTPS connections.

.PARAMETER CertificatePath
    Path to SSL certificate for HTTPS (required if EnableSSL is true).

.PARAMETER AuthenticationMethod
    Authentication method: None, ApiKey, Basic, Bearer. Default is ApiKey.

.PARAMETER EnableCORS
    Enable Cross-Origin Resource Sharing (CORS). Default is true.

.PARAMETER EnableRateLimit
    Enable request rate limiting. Default is true.

.PARAMETER BackgroundMode
    Run the API server in background mode (as a job).

.EXAMPLE
    Start-AitherZeroAPI
    Starts the API server with default settings on port 8080.

.EXAMPLE
    Start-AitherZeroAPI -Port 443 -EnableSSL -CertificatePath "C:\certs\api.pfx"
    Starts an HTTPS API server on port 443 with SSL certificate.

.EXAMPLE
    Start-AitherZeroAPI -AuthenticationMethod Bearer -EnableRateLimit:$false
    Starts API server with Bearer token authentication and no rate limiting.
#>
function Start-AitherZeroAPI {
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateRange(1, 65535)]
        [int]$Port = 8080,

        [Parameter()]
        [ValidateSet('HTTP', 'HTTPS')]
        [string]$Protocol = 'HTTP',

        [Parameter()]
        [switch]$EnableSSL,

        [Parameter()]
        [string]$CertificatePath,

        [Parameter()]
        [ValidateSet('None', 'ApiKey', 'Basic', 'Bearer')]
        [string]$AuthenticationMethod = 'ApiKey',

        [Parameter()]
        [switch]$EnableCORS = $true,

        [Parameter()]
        [switch]$EnableRateLimit = $true,

        [Parameter()]
        [switch]$BackgroundMode = $true
    )

    begin {
        Write-CustomLog -Message "Starting AitherZero REST API server" -Level "INFO"

        # Validate SSL configuration
        if ($EnableSSL -and -not $CertificatePath) {
            throw "CertificatePath is required when EnableSSL is specified"
        }

        if ($EnableSSL) {
            $Protocol = 'HTTPS'
        }

        # Check if API server is already running
        if ($script:APIServer -and $script:APIServerJob -and $script:APIServerJob.State -eq 'Running') {
            Write-CustomLog -Message "API server is already running on port $($script:APIConfiguration.Port)" -Level "WARNING"
            return Get-APIStatus
        }

        # Update configuration
        $script:APIConfiguration.Port = $Port
        $script:APIConfiguration.Protocol = $Protocol
        $script:APIConfiguration.SSLEnabled = $EnableSSL
        $script:APIConfiguration.Authentication = $AuthenticationMethod
        $script:APIConfiguration.CorsEnabled = $EnableCORS
        $script:APIConfiguration.RateLimiting = $EnableRateLimit

        # Initialize default endpoints
        Initialize-DefaultEndpoints
    }

    process {
        try {
            # Create API server configuration
            $serverConfig = @{
                Port = $Port
                Protocol = $Protocol
                SSLEnabled = $EnableSSL
                CertificatePath = $CertificatePath
                Authentication = $AuthenticationMethod
                CORS = $EnableCORS
                RateLimit = $EnableRateLimit
                Endpoints = $script:RegisteredEndpoints
                ProjectRoot = $script:ProjectRoot
            }

            if ($BackgroundMode) {
                # Start API server as background job
                $script:APIServerJob = Start-Job -Name "AitherZero-RestAPI" -ScriptBlock {
                    param($Config)

                    # Import required modules in job
                    Import-Module (Join-Path $Config.ProjectRoot "aither-core/modules/Logging") -Force
                    Import-Module (Join-Path $Config.ProjectRoot "aither-core/modules/RestAPIServer") -Force

                    # Initialize HTTP listener
                    $listener = New-Object System.Net.HttpListener
                    $prefix = "$($Config.Protocol.ToLower())://*:$($Config.Port)/"
                    $listener.Prefixes.Add($prefix)

                    Write-CustomLog -Message "Starting HTTP listener on $prefix" -Level "INFO"

                    try {
                        $listener.Start()
                        Write-CustomLog -Message "AitherZero REST API server started successfully" -Level "SUCCESS"

                        # Main request processing loop
                        while ($listener.IsListening) {
                            try {
                                # Get incoming request (blocking call)
                                $context = $listener.GetContext()
                                $request = $context.Request
                                $response = $context.Response

                                # Log request
                                Write-CustomLog -Message "$($request.HttpMethod) $($request.Url.AbsolutePath) from $($request.RemoteEndPoint)" -Level "DEBUG"

                                # Handle CORS preflight
                                if ($Config.CORS -and $request.HttpMethod -eq 'OPTIONS') {
                                    $response.Headers.Add('Access-Control-Allow-Origin', '*')
                                    $response.Headers.Add('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS')
                                    $response.Headers.Add('Access-Control-Allow-Headers', 'Content-Type, Authorization, X-API-Key')
                                    $response.StatusCode = 200
                                    $response.Close()
                                    continue
                                }

                                # Process API request
                                $result = Process-APIRequest -Request $request -Config $Config

                                # Set CORS headers
                                if ($Config.CORS) {
                                    $response.Headers.Add('Access-Control-Allow-Origin', '*')
                                    $response.Headers.Add('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS')
                                }

                                # Set response
                                $response.ContentType = 'application/json'
                                $response.StatusCode = $result.StatusCode

                                $responseBytes = [System.Text.Encoding]::UTF8.GetBytes($result.Body)
                                $response.OutputStream.Write($responseBytes, 0, $responseBytes.Length)
                                $response.Close()

                            } catch {
                                Write-CustomLog -Message "Error processing request: $($_.Exception.Message)" -Level "ERROR"

                                try {
                                    $response.StatusCode = 500
                                    $errorResponse = @{
                                        error = "Internal Server Error"
                                        message = $_.Exception.Message
                                        timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
                                    } | ConvertTo-Json

                                    $errorBytes = [System.Text.Encoding]::UTF8.GetBytes($errorResponse)
                                    $response.OutputStream.Write($errorBytes, 0, $errorBytes.Length)
                                    $response.Close()
                                } catch {
                                    # Response already closed or corrupted
                                }
                            }
                        }
                    } catch {
                        Write-CustomLog -Message "API server error: $($_.Exception.Message)" -Level "ERROR"
                    } finally {
                        if ($listener.IsListening) {
                            $listener.Stop()
                        }
                        $listener.Close()
                        Write-CustomLog -Message "AitherZero REST API server stopped" -Level "INFO"
                    }
                } -ArgumentList $serverConfig

                # Wait a moment for server to start
                Start-Sleep -Seconds 2

                # Store server information
                $script:APIServer = @{
                    JobId = $script:APIServerJob.Id
                    Port = $Port
                    Protocol = $Protocol
                    StartTime = Get-Date
                    Configuration = $serverConfig
                }
                $script:APIStartTime = Get-Date

                # Test connection
                $connectionTest = Test-APIConnection -Port $Port -Timeout 5

                if ($connectionTest.Success) {
                    Write-CustomLog -Message "REST API server started successfully on $Protocol port $Port" -Level "SUCCESS"
                } else {
                    Write-CustomLog -Message "REST API server may have failed to start properly" -Level "WARNING"
                }

            } else {
                # Start API server in current session (synchronous)
                Write-CustomLog -Message "Starting API server in synchronous mode" -Level "INFO"
                Start-SynchronousAPIServer -Configuration $serverConfig
            }

            # Return server status
            return Get-APIStatus

        } catch {
            Write-CustomLog -Message "Failed to start API server: $($_.Exception.Message)" -Level "ERROR"
            throw
        }
    }
}

# Helper function to initialize default API endpoints
function Initialize-DefaultEndpoints {
    Write-CustomLog -Message "Initializing default API endpoints" -Level "DEBUG"

    # Health check endpoint
    $script:RegisteredEndpoints['/health'] = @{
        Method = 'GET'
        Handler = 'Get-HealthStatus'
        Description = 'API server health check'
        Authentication = $false
        Parameters = @()
    }

    # API status endpoint
    $script:RegisteredEndpoints['/status'] = @{
        Method = 'GET'
        Handler = 'Get-APIStatus'
        Description = 'API server status and metrics'
        Authentication = $true
        Parameters = @()
    }

    # System performance endpoint
    $script:RegisteredEndpoints['/performance'] = @{
        Method = 'GET'
        Handler = 'Get-SystemPerformance'
        Description = 'System performance metrics'
        Authentication = $true
        Parameters = @('MetricType', 'Duration')
    }

    # Execute PowerShell command endpoint
    $script:RegisteredEndpoints['/execute'] = @{
        Method = 'POST'
        Handler = 'Invoke-PowerShellCommand'
        Description = 'Execute PowerShell commands remotely'
        Authentication = $true
        Parameters = @('Command', 'Module', 'Arguments')
    }

    # Module information endpoint
    $script:RegisteredEndpoints['/modules'] = @{
        Method = 'GET'
        Handler = 'Get-ModuleInformation'
        Description = 'List available AitherZero modules'
        Authentication = $true
        Parameters = @('ModuleName')
    }

    # Webhook management endpoints
    $script:RegisteredEndpoints['/webhooks'] = @{
        Method = 'GET'
        Handler = 'Get-WebhookSubscriptions'
        Description = 'List webhook subscriptions'
        Authentication = $true
        Parameters = @()
    }

    $script:RegisteredEndpoints['/webhooks/subscribe'] = @{
        Method = 'POST'
        Handler = 'Add-WebhookSubscription'
        Description = 'Subscribe to webhook notifications'
        Authentication = $true
        Parameters = @('Url', 'Events', 'Secret')
    }

    Write-CustomLog -Message "Initialized $($script:RegisteredEndpoints.Count) default endpoints" -Level "DEBUG"
}

# Helper function to process API requests
function Process-APIRequest {
    param($Request, $Config)

    $path = $request.Url.AbsolutePath
    $method = $request.HttpMethod

    # Find matching endpoint
    $endpoint = $Config.Endpoints[$path]

    if (-not $endpoint) {
        return @{
            StatusCode = 404
            Body = @{
                error = "Not Found"
                message = "Endpoint $path not found"
                timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
            } | ConvertTo-Json
        }
    }

    # Check HTTP method
    if ($endpoint.Method -ne $method) {
        return @{
            StatusCode = 405
            Body = @{
                error = "Method Not Allowed"
                message = "Method $method not allowed for $path"
                allowed = $endpoint.Method
                timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
            } | ConvertTo-Json
        }
    }

    # Check authentication
    if ($endpoint.Authentication -and $Config.Authentication -ne 'None') {
        $authResult = Test-APIAuthentication -Request $request -Method $Config.Authentication
        if (-not $authResult.Success) {
            return @{
                StatusCode = 401
                Body = @{
                    error = "Unauthorized"
                    message = $authResult.Message
                    timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
                } | ConvertTo-Json
            }
        }
    }

    # Execute endpoint handler
    try {
        $handlerResult = Invoke-EndpointHandler -Handler $endpoint.Handler -Request $request

        return @{
            StatusCode = if ($handlerResult.Success) { 200 } else { 400 }
            Body = $handlerResult | ConvertTo-Json -Depth 5
        }
    } catch {
        Write-CustomLog -Message "Handler error: $($_.Exception.Message)" -Level "ERROR"

        return @{
            StatusCode = 500
            Body = @{
                error = "Internal Server Error"
                message = $_.Exception.Message
                timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
            } | ConvertTo-Json
        }
    }
}

# Helper function to test API authentication
function Test-APIAuthentication {
    param($Request, $Method)

    switch ($Method) {
        'ApiKey' {
            $apiKey = $Request.Headers['X-API-Key']
            if (-not $apiKey) {
                return @{ Success = $false; Message = "X-API-Key header required" }
            }

            # Simple API key validation (in production, use secure key management)
            $validKeys = @('aitherzero-admin', 'aitherzero-readonly')
            if ($apiKey -notin $validKeys) {
                return @{ Success = $false; Message = "Invalid API key" }
            }

            return @{ Success = $true; Message = "API key valid" }
        }

        'Basic' {
            $authHeader = $Request.Headers['Authorization']
            if (-not $authHeader -or -not $authHeader.StartsWith('Basic ')) {
                return @{ Success = $false; Message = "Basic authentication required" }
            }

            # Basic auth validation would go here
            return @{ Success = $true; Message = "Basic auth valid" }
        }

        'Bearer' {
            $authHeader = $Request.Headers['Authorization']
            if (-not $authHeader -or -not $authHeader.StartsWith('Bearer ')) {
                return @{ Success = $false; Message = "Bearer token required" }
            }

            # Bearer token validation would go here
            return @{ Success = $true; Message = "Bearer token valid" }
        }

        default {
            return @{ Success = $true; Message = "No authentication required" }
        }
    }
}

# Helper function to invoke endpoint handlers
function Invoke-EndpointHandler {
    param($Handler, $Request)

    switch ($Handler) {
        'Get-HealthStatus' {
            return @{
                Success = $true
                Status = "Healthy"
                Timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
                Version = "1.0.0"
            }
        }

        'Get-APIStatus' {
            return Get-APIStatus
        }

        'Get-SystemPerformance' {
            # Extract query parameters
            $query = [System.Web.HttpUtility]::ParseQueryString($Request.Url.Query)
            $metricType = if ($query['MetricType']) { $query['MetricType'] } else { 'All' }
            $duration = if ($query['Duration']) { [int]$query['Duration'] } else { 5 }

            try {
                Import-Module (Join-Path $script:ProjectRoot "aither-core/modules/SystemMonitoring") -Force
                $metrics = Get-SystemPerformance -MetricType $metricType -Duration $duration

                return @{
                    Success = $true
                    Data = $metrics
                }
            } catch {
                return @{
                    Success = $false
                    Error = $_.Exception.Message
                }
            }
        }

        'Get-ModuleInformation' {
            try {
                $modules = Get-ChildItem -Path (Join-Path $script:ProjectRoot "aither-core/modules") -Directory
                $moduleInfo = $modules | ForEach-Object {
                    $manifestPath = Join-Path $_.FullName "$($_.Name).psd1"
                    if (Test-Path $manifestPath) {
                        $manifest = Import-PowerShellDataFile $manifestPath
                        @{
                            Name = $_.Name
                            Version = $manifest.ModuleVersion
                            Description = $manifest.Description
                            Functions = $manifest.FunctionsToExport
                        }
                    }
                }

                return @{
                    Success = $true
                    Data = $moduleInfo
                }
            } catch {
                return @{
                    Success = $false
                    Error = $_.Exception.Message
                }
            }
        }

        default {
            return @{
                Success = $false
                Error = "Handler not implemented: $Handler"
            }
        }
    }
}

Export-ModuleMember -Function Start-AitherZeroAPI

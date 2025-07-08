<#
.SYNOPSIS
    Registers a new custom endpoint with the AitherZero REST API server.

.DESCRIPTION
    Register-APIEndpoint allows dynamic registration of custom API endpoints
    with the running server. Supports custom handlers, authentication requirements,
    and parameter validation.

.PARAMETER Path
    The URL path for the endpoint (e.g., "/custom/action").

.PARAMETER Method
    The HTTP method (GET, POST, PUT, DELETE, PATCH).

.PARAMETER Handler
    The handler function name or script block to execute for this endpoint.

.PARAMETER Description
    Description of the endpoint functionality.

.PARAMETER RequiresAuthentication
    Whether this endpoint requires authentication. Default is true.

.PARAMETER Parameters
    Array of parameter names that this endpoint accepts.

.PARAMETER AllowedRoles
    Array of roles allowed to access this endpoint.

.PARAMETER RateLimitEnabled
    Whether rate limiting applies to this endpoint. Default is true.

.EXAMPLE
    Register-APIEndpoint -Path "/custom/backup" -Method POST -Handler "Invoke-CustomBackup" -Description "Custom backup operation"
    Registers a custom backup endpoint.

.EXAMPLE
    Register-APIEndpoint -Path "/public/info" -Method GET -Handler "Get-PublicInfo" -RequiresAuthentication:$false
    Registers a public information endpoint without authentication.

.EXAMPLE
    $handler = { param($request) return @{ Message = "Custom response" } }
    Register-APIEndpoint -Path "/custom/test" -Method GET -Handler $handler -Description "Test endpoint"
    Registers an endpoint with a script block handler.
#>
function Register-APIEndpoint {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidatePattern('^/[a-zA-Z0-9/_-]+$')]
        [string]$Path,

        [Parameter(Mandatory)]
        [ValidateSet('GET', 'POST', 'PUT', 'DELETE', 'PATCH')]
        [string]$Method,

        [Parameter(Mandatory)]
        [object]$Handler,

        [Parameter()]
        [string]$Description = "",

        [Parameter()]
        [switch]$RequiresAuthentication = $true,

        [Parameter()]
        [string[]]$Parameters = @(),

        [Parameter()]
        [string[]]$AllowedRoles = @(),

        [Parameter()]
        [switch]$RateLimitEnabled = $true
    )

    begin {
        Write-CustomLog -Message "Registering API endpoint: $Method $Path" -Level "INFO"
    }

    process {
        try {
            # Validate handler
            $handlerType = $Handler.GetType().Name
            if ($handlerType -notin @('String', 'ScriptBlock')) {
                throw "Handler must be either a function name (string) or script block"
            }

            # Check if endpoint already exists
            if ($script:RegisteredEndpoints.ContainsKey($Path)) {
                $existing = $script:RegisteredEndpoints[$Path]
                Write-CustomLog -Message "Endpoint $Path already exists with method $($existing.Method)" -Level "WARNING"

                # Allow update if same method, otherwise throw error
                if ($existing.Method -eq $Method) {
                    Write-CustomLog -Message "Updating existing endpoint $Path" -Level "INFO"
                } else {
                    throw "Endpoint $Path already exists with different method: $($existing.Method)"
                }
            }

            # Validate handler function exists if string
            if ($handlerType -eq 'String') {
                try {
                    $handlerFunction = Get-Command -Name $Handler -ErrorAction Stop
                    if ($handlerFunction.CommandType -ne 'Function') {
                        throw "Handler '$Handler' is not a function"
                    }
                } catch {
                    Write-CustomLog -Message "Warning: Handler function '$Handler' not found in current session" -Level "WARNING"
                }
            }

            # Create endpoint configuration
            $endpointConfig = @{
                Method = $Method
                Handler = $Handler
                HandlerType = $handlerType
                Description = $Description
                Authentication = $RequiresAuthentication.IsPresent
                Parameters = $Parameters
                AllowedRoles = $AllowedRoles
                RateLimit = $RateLimitEnabled.IsPresent
                RegisteredAt = Get-Date
                RegisteredBy = $env:USERNAME
            }

            # Add validation for parameters if specified
            if ($Parameters.Count -gt 0) {
                $endpointConfig.ParameterValidation = @{}
                foreach ($param in $Parameters) {
                    $endpointConfig.ParameterValidation[$param] = @{
                        Required = $false
                        Type = 'String'
                        Validation = $null
                    }
                }
            }

            # Register the endpoint
            $script:RegisteredEndpoints[$Path] = $endpointConfig

            # Log registration details
            $authText = if ($RequiresAuthentication) { "requires auth" } else { "public" }
            $roleText = if ($AllowedRoles.Count -gt 0) { " (roles: $($AllowedRoles -join ', '))" } else { "" }

            Write-CustomLog -Message "Endpoint registered: $Method $Path ($authText)$roleText" -Level "SUCCESS"

            # Return registration result
            return @{
                Success = $true
                Path = $Path
                Method = $Method
                Handler = $Handler
                Description = $Description
                RequiresAuthentication = $RequiresAuthentication.IsPresent
                Parameters = $Parameters
                AllowedRoles = $AllowedRoles
                TotalEndpoints = $script:RegisteredEndpoints.Count
                RegisteredAt = $endpointConfig.RegisteredAt
            }

        } catch {
            $errorMessage = "Failed to register endpoint $Path : $($_.Exception.Message)"
            Write-CustomLog -Message $errorMessage -Level "ERROR"

            return @{
                Success = $false
                Error = $_.Exception.Message
                Message = $errorMessage
                Path = $Path
                Method = $Method
            }
        }
    }
}

Export-ModuleMember -Function Register-APIEndpoint

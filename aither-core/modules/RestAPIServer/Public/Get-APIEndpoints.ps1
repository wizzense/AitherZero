<#
.SYNOPSIS
    Retrieves all registered API endpoints from the server.

.DESCRIPTION
    Get-APIEndpoints returns a list of all currently registered API endpoints,
    including their configuration, handlers, and metadata.

.PARAMETER Path
    Optional path filter to retrieve specific endpoints.

.PARAMETER Method
    Optional method filter to retrieve endpoints with specific HTTP methods.

.PARAMETER IncludeBuiltIn
    Include built-in system endpoints in the results.

.PARAMETER Format
    Output format: Table, List, or JSON.

.EXAMPLE
    Get-APIEndpoints
    Retrieves all registered endpoints.

.EXAMPLE
    Get-APIEndpoints -Path "/custom/*" -Method GET
    Retrieves all GET endpoints under the /custom path.

.EXAMPLE
    Get-APIEndpoints -IncludeBuiltIn -Format JSON
    Retrieves all endpoints including built-in ones in JSON format.
#>
function Get-APIEndpoints {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Path,

        [Parameter()]
        [ValidateSet('GET', 'POST', 'PUT', 'DELETE', 'PATCH')]
        [string]$Method,

        [Parameter()]
        [switch]$IncludeBuiltIn,

        [Parameter()]
        [ValidateSet('Table', 'List', 'JSON')]
        [string]$Format = 'Table'
    )

    begin {
        Write-CustomLog -Message "Retrieving API endpoints" -Level "DEBUG"
    }

    process {
        try {
            $endpoints = @()

            # Get registered endpoints
            foreach ($endpointPath in $script:RegisteredEndpoints.Keys) {
                $endpoint = $script:RegisteredEndpoints[$endpointPath]

                # Apply filters
                if ($Path -and $endpointPath -notlike $Path) {
                    continue
                }

                if ($Method -and $endpoint.Method -ne $Method) {
                    continue
                }

                $endpoints += @{
                    Path = $endpointPath
                    Method = $endpoint.Method
                    Handler = $endpoint.Handler
                    HandlerType = $endpoint.HandlerType
                    Description = $endpoint.Description
                    Authentication = $endpoint.Authentication
                    Parameters = $endpoint.Parameters
                    AllowedRoles = $endpoint.AllowedRoles
                    RateLimit = $endpoint.RateLimit
                    RegisteredAt = $endpoint.RegisteredAt
                    RegisteredBy = $endpoint.RegisteredBy
                    Type = 'Custom'
                }
            }

            # Add built-in endpoints if requested
            if ($IncludeBuiltIn) {
                $builtInEndpoints = @(
                    @{
                        Path = '/api/status'
                        Method = 'GET'
                        Handler = 'Get-APIStatus'
                        HandlerType = 'String'
                        Description = 'Get API server status'
                        Authentication = $false
                        Parameters = @()
                        AllowedRoles = @()
                        RateLimit = $true
                        RegisteredAt = $script:APIStartTime
                        RegisteredBy = 'System'
                        Type = 'Built-In'
                    },
                    @{
                        Path = '/api/endpoints'
                        Method = 'GET'
                        Handler = 'Get-APIEndpoints'
                        HandlerType = 'String'
                        Description = 'List all API endpoints'
                        Authentication = $true
                        Parameters = @()
                        AllowedRoles = @('admin')
                        RateLimit = $true
                        RegisteredAt = $script:APIStartTime
                        RegisteredBy = 'System'
                        Type = 'Built-In'
                    },
                    @{
                        Path = '/api/webhooks'
                        Method = 'GET'
                        Handler = 'Get-WebhookSubscriptions'
                        HandlerType = 'String'
                        Description = 'List webhook subscriptions'
                        Authentication = $true
                        Parameters = @()
                        AllowedRoles = @('admin')
                        RateLimit = $true
                        RegisteredAt = $script:APIStartTime
                        RegisteredBy = 'System'
                        Type = 'Built-In'
                    }
                )

                foreach ($builtIn in $builtInEndpoints) {
                    # Apply filters
                    if ($Path -and $builtIn.Path -notlike $Path) {
                        continue
                    }

                    if ($Method -and $builtIn.Method -ne $Method) {
                        continue
                    }

                    $endpoints += $builtIn
                }
            }

            # Sort endpoints by path
            $endpoints = $endpoints | Sort-Object Path

            # Format output
            switch ($Format) {
                'JSON' {
                    return $endpoints | ConvertTo-Json -Depth 10
                }
                'List' {
                    return $endpoints
                }
                'Table' {
                    return $endpoints | Format-Table -Property Path, Method, Description, Authentication, Type -AutoSize
                }
            }

        } catch {
            $errorMessage = "Failed to retrieve API endpoints: $($_.Exception.Message)"
            Write-CustomLog -Message $errorMessage -Level "ERROR"
            throw
        }
    }
}

Export-ModuleMember -Function Get-APIEndpoints

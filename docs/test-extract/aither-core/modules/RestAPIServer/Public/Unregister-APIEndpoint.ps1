<#
.SYNOPSIS
    Unregisters an API endpoint from the server.

.DESCRIPTION
    Unregister-APIEndpoint removes a previously registered custom endpoint
    from the API server. This allows dynamic removal of endpoints at runtime.

.PARAMETER Path
    The URL path of the endpoint to unregister.

.PARAMETER Method
    The HTTP method of the endpoint to unregister. If not specified, all methods for the path are removed.

.PARAMETER Force
    Force removal even if the endpoint is currently in use.

.EXAMPLE
    Unregister-APIEndpoint -Path "/custom/backup" -Method POST
    Unregisters the specific POST endpoint.

.EXAMPLE
    Unregister-APIEndpoint -Path "/custom/test" -Force
    Forcefully unregisters all endpoints for the given path.
#>
function Unregister-APIEndpoint {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidatePattern('^/[a-zA-Z0-9/_-]+$')]
        [string]$Path,
        
        [Parameter()]
        [ValidateSet('GET', 'POST', 'PUT', 'DELETE', 'PATCH')]
        [string]$Method,
        
        [Parameter()]
        [switch]$Force
    )

    begin {
        Write-CustomLog -Message "Unregistering API endpoint: $Path" -Level "INFO"
    }

    process {
        try {
            # Check if endpoint exists
            if (-not $script:RegisteredEndpoints.ContainsKey($Path)) {
                Write-CustomLog -Message "Endpoint not found: $Path" -Level "WARNING"
                return @{
                    Success = $false
                    Message = "Endpoint not found: $Path"
                    Path = $Path
                }
            }
            
            $endpoint = $script:RegisteredEndpoints[$Path]
            
            # Check method match if specified
            if ($Method -and $endpoint.Method -ne $Method) {
                Write-CustomLog -Message "Method mismatch: $Path has method $($endpoint.Method), not $Method" -Level "WARNING"
                return @{
                    Success = $false
                    Message = "Method mismatch: endpoint has method $($endpoint.Method), not $Method"
                    Path = $Path
                    Method = $Method
                    ActualMethod = $endpoint.Method
                }
            }
            
            # Check if endpoint is in use (if not forcing)
            if (-not $Force -and (Test-APIServerRunning)) {
                Write-CustomLog -Message "Warning: Removing endpoint while server is running" -Level "WARNING"
            }
            
            # Remove the endpoint
            $script:RegisteredEndpoints.Remove($Path)
            
            Write-CustomLog -Message "Endpoint unregistered: $($endpoint.Method) $Path" -Level "SUCCESS"
            
            return @{
                Success = $true
                Path = $Path
                Method = $endpoint.Method
                Description = $endpoint.Description
                RemovedAt = Get-Date
                RemainingEndpoints = $script:RegisteredEndpoints.Count
            }

        } catch {
            $errorMessage = "Failed to unregister endpoint $Path : $($_.Exception.Message)"
            Write-CustomLog -Message $errorMessage -Level "ERROR"
            
            return @{
                Success = $false
                Error = $_.Exception.Message
                Message = $errorMessage
                Path = $Path
            }
        }
    }
}

Export-ModuleMember -Function Unregister-APIEndpoint
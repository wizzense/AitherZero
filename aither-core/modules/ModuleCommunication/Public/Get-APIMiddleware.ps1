function Get-APIMiddleware {
    <#
    .SYNOPSIS
        Get registered API middleware
    .DESCRIPTION
        Returns information about registered middleware in the API pipeline
    .PARAMETER Name
        Get specific middleware by name
    .PARAMETER IncludeHandler
        Include the handler scriptblock in output
    .EXAMPLE
        Get-APIMiddleware -IncludeHandler
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Name,

        [Parameter()]
        [switch]$IncludeHandler
    )

    try {
        $middlewareList = @()

        if ($Name) {
            # Get specific middleware
            $middleware = $script:APIRegistry.Middleware | Where-Object { $_.Name -eq $Name }
            if ($middleware) {
                $middlewareInfo = @{
                    Name = $middleware.Name
                    Priority = $middleware.Priority
                    AddedAt = $middleware.AddedAt
                    Enabled = $middleware.Enabled
                    Position = $script:APIRegistry.Middleware.IndexOf($middleware)
                }

                if ($IncludeHandler) {
                    $middlewareInfo.Handler = $middleware.Handler
                }

                return $middlewareInfo
            } else {
                Write-CustomLog -Level 'WARNING' -Message "Middleware '$Name' not found"
                return $null
            }
        } else {
            # Get all middleware
            for ($i = 0; $i -lt $script:APIRegistry.Middleware.Count; $i++) {
                $middleware = $script:APIRegistry.Middleware[$i]

                $middlewareInfo = @{
                    Name = $middleware.Name
                    Priority = $middleware.Priority
                    AddedAt = $middleware.AddedAt
                    Enabled = $middleware.Enabled
                    Position = $i
                }

                if ($IncludeHandler) {
                    $middlewareInfo.Handler = $middleware.Handler
                }

                $middlewareList += $middlewareInfo
            }

            return $middlewareList
        }

    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to get middleware: $_"
        throw
    }
}

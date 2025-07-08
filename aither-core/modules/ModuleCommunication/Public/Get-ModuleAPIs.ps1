function Get-ModuleAPIs {
    <#
    .SYNOPSIS
        Get registered module APIs
    .DESCRIPTION
        Returns information about registered module APIs
    .PARAMETER ModuleName
        Filter by module name
    .PARAMETER APIName
        Get specific API
    .PARAMETER IncludeStatistics
        Include call statistics
    .EXAMPLE
        Get-ModuleAPIs -ModuleName "LabRunner" -IncludeStatistics
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$ModuleName,

        [Parameter()]
        [string]$APIName,

        [Parameter()]
        [switch]$IncludeStatistics
    )

    try {
        $apis = @()

        if ($ModuleName -and $APIName) {
            # Get specific API
            $apiKey = "$ModuleName.$APIName"
            if ($script:APIRegistry.APIs.ContainsKey($apiKey)) {
                $api = $script:APIRegistry.APIs[$apiKey]

                $apiInfo = @{
                    ModuleName = $api.ModuleName
                    APIName = $api.APIName
                    FullName = $api.FullName
                    Description = $api.Description
                    ParameterCount = $api.Parameters.Count
                    RequiresAuth = $api.RequiresAuth
                    RegisteredAt = $api.RegisteredAt
                    HasMiddleware = $api.Middleware.Count -gt 0
                }

                if ($IncludeStatistics) {
                    $apiInfo.Statistics = @{
                        CallCount = $api.CallCount
                        LastCalled = $api.LastCalled
                        AverageExecutionTime = $api.AverageExecutionTime
                    }
                    $apiInfo.Parameters = $api.Parameters
                }

                return $apiInfo
            } else {
                Write-CustomLog -Level 'WARNING' -Message "API '$apiKey' not found"
                return $null
            }
        } else {
            # Get all APIs or filter by module
            foreach ($apiKey in $script:APIRegistry.APIs.Keys) {
                $api = $script:APIRegistry.APIs[$apiKey]

                # Apply module filter
                if ($ModuleName -and $api.ModuleName -ne $ModuleName) {
                    continue
                }

                $apiInfo = @{
                    ModuleName = $api.ModuleName
                    APIName = $api.APIName
                    FullName = $api.FullName
                    Description = $api.Description
                    ParameterCount = $api.Parameters.Count
                    RequiresAuth = $api.RequiresAuth
                    RegisteredAt = $api.RegisteredAt
                    HasMiddleware = $api.Middleware.Count -gt 0
                }

                if ($IncludeStatistics) {
                    $apiInfo.Statistics = @{
                        CallCount = $api.CallCount
                        LastCalled = $api.LastCalled
                        AverageExecutionTime = $api.AverageExecutionTime
                    }
                }

                $apis += $apiInfo
            }

            return $apis
        }

    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to get APIs: $_"
        throw
    }
}

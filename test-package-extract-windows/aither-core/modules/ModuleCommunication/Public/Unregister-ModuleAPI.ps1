function Unregister-ModuleAPI {
    <#
    .SYNOPSIS
        Unregister a module API
    .DESCRIPTION
        Removes a registered API from the registry
    .PARAMETER ModuleName
        Module name
    .PARAMETER APIName
        API name to remove
    .PARAMETER Force
        Force removal without confirmation
    .EXAMPLE
        Unregister-ModuleAPI -ModuleName "LabRunner" -APIName "ExecuteStep"
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$ModuleName,

        [Parameter(Mandatory)]
        [string]$APIName,

        [Parameter()]
        [switch]$Force
    )

    try {
        $apiKey = "$ModuleName.$APIName"

        # Check if API exists
        if (-not $script:APIRegistry.APIs.ContainsKey($apiKey)) {
            Write-CustomLog -Level 'WARNING' -Message "API '$apiKey' not found"
            return @{
                Success = $false
                Reason = "API not found"
            }
        }

        $api = $script:APIRegistry.APIs[$apiKey]

        # Confirmation
        if (-not $Force -and -not $WhatIfPreference) {
            $message = "Remove API '$apiKey'?"
            if ($api.CallCount -gt 0) {
                $message += " This API has been called $($api.CallCount) times."
            }

            $choice = Read-Host "$message (y/N)"
            if ($choice -ne 'y' -and $choice -ne 'Y') {
                Write-CustomLog -Level 'INFO' -Message "Operation cancelled"
                return @{
                    Success = $false
                    Reason = "Operation cancelled"
                }
            }
        }

        if ($PSCmdlet.ShouldProcess("API: $apiKey", "Remove API")) {
            $removedAPI = $null
            if ($script:APIRegistry.APIs.TryRemove($apiKey, [ref]$removedAPI)) {
                Write-CustomLog -Level 'SUCCESS' -Message "API removed: $apiKey"

                return @{
                    Success = $true
                    RemovedAPI = @{
                        ModuleName = $removedAPI.ModuleName
                        APIName = $removedAPI.APIName
                        CallCount = $removedAPI.CallCount
                        RegisteredAt = $removedAPI.RegisteredAt
                        LastCalled = $removedAPI.LastCalled
                    }
                }
            } else {
                throw "Failed to remove API from registry"
            }
        }

    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to unregister API: $_"
        throw
    }
}

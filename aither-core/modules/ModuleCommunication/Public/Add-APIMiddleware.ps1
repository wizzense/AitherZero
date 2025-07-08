function Add-APIMiddleware {
    <#
    .SYNOPSIS
        Add middleware to the API pipeline
    .DESCRIPTION
        Registers middleware that runs for all API calls
    .PARAMETER Name
        Middleware name
    .PARAMETER Handler
        Middleware handler scriptblock
    .PARAMETER Priority
        Execution priority (lower numbers run first)
    .EXAMPLE
        Add-APIMiddleware -Name "Logging" -Handler {
            param($Context, $Next)
            Write-CustomLog -Level 'INFO' -Message "API Call: $($Context.APIKey)"
            $result = & $Next $Context
            Write-CustomLog -Level 'INFO' -Message "API Complete: $($Context.APIKey)"
            return $result
        }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [scriptblock]$Handler,

        [Parameter()]
        [int]$Priority = 50
    )

    try {
        $middleware = @{
            Name = $Name
            Handler = $Handler
            Priority = $Priority
            AddedAt = Get-Date
            Enabled = $true
        }

        # Check if middleware with same name exists
        $existingIndex = -1
        for ($i = 0; $i -lt $script:APIRegistry.Middleware.Count; $i++) {
            if ($script:APIRegistry.Middleware[$i].Name -eq $Name) {
                $existingIndex = $i
                break
            }
        }

        if ($existingIndex -ge 0) {
            # Replace existing
            $script:APIRegistry.Middleware[$existingIndex] = $middleware
            Write-CustomLog -Level 'WARNING' -Message "Middleware replaced: $Name"
        } else {
            # Add new
            $script:APIRegistry.Middleware.Add($middleware)
            Write-CustomLog -Level 'SUCCESS' -Message "Middleware added: $Name"
        }

        # Sort by priority
        $script:APIRegistry.Middleware = [System.Collections.ArrayList]@(
            $script:APIRegistry.Middleware | Sort-Object Priority
        )

        return @{
            Name = $Name
            Priority = $Priority
            Position = $script:APIRegistry.Middleware.IndexOf($middleware)
        }

    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to add middleware: $_"
        throw
    }
}

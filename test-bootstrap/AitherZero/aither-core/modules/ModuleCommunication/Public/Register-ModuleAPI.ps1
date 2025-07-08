function Register-ModuleAPI {
    <#
    .SYNOPSIS
        Register a module API for unified access
    .DESCRIPTION
        Registers module operations that can be invoked through the unified API gateway
    .PARAMETER ModuleName
        Name of the module registering APIs
    .PARAMETER APIName
        Name of the API operation
    .PARAMETER Handler
        ScriptBlock that implements the API
    .PARAMETER Description
        API description
    .PARAMETER Parameters
        Parameter definitions for the API
    .PARAMETER RequiresAuth
        Whether API requires authentication
    .PARAMETER Middleware
        Custom middleware for this API
    .EXAMPLE
        Register-ModuleAPI -ModuleName "LabRunner" -APIName "ExecuteStep" -Handler {
            param($StepName, $Parameters)
            Invoke-LabStep -Name $StepName -Parameters $Parameters
        } -Parameters @{
            StepName = @{Type="string"; Required=$true; Description="Step to execute"}
            Parameters = @{Type="hashtable"; Required=$false; Description="Step parameters"}
        }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ModuleName,
        
        [Parameter(Mandatory)]
        [string]$APIName,
        
        [Parameter(Mandatory)]
        [scriptblock]$Handler,
        
        [Parameter()]
        [string]$Description = '',
        
        [Parameter()]
        [hashtable]$Parameters = @{},
        
        [Parameter()]
        [bool]$RequiresAuth = $false,
        
        [Parameter()]
        [scriptblock[]]$Middleware = @()
    )
    
    try {
        # Create API definition
        $api = @{
            ModuleName = $ModuleName
            APIName = $APIName
            FullName = "$ModuleName.$APIName"
            Handler = $Handler
            Description = $Description
            Parameters = $Parameters
            RequiresAuth = $RequiresAuth
            Middleware = $Middleware
            RegisteredAt = Get-Date
            CallCount = 0
            LastCalled = $null
            AverageExecutionTime = 0
        }
        
        # Validate handler has proper parameters
        $handlerParams = $Handler.Ast.ParamBlock.Parameters.Name.VariablePath.UserPath
        $expectedParams = $Parameters.Keys
        
        foreach ($param in $expectedParams) {
            if ($param -notin $handlerParams) {
                Write-CustomLog -Level 'WARNING' -Message "Handler missing parameter: $param"
            }
        }
        
        # Register API
        $apiKey = $api.FullName
        if ($script:APIRegistry.APIs.ContainsKey($apiKey)) {
            Write-CustomLog -Level 'WARNING' -Message "API already registered: $apiKey. Overwriting."
        }
        
        $script:APIRegistry.APIs[$apiKey] = $api
        
        Write-CustomLog -Level 'SUCCESS' -Message "API registered: $apiKey"
        
        return @{
            ModuleName = $ModuleName
            APIName = $APIName
            FullName = $apiKey
            ParameterCount = $Parameters.Count
        }
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to register API: $_"
        throw
    }
}
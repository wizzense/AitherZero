function Invoke-ModuleAPI {
    <#
    .SYNOPSIS
        Invoke a registered module API
    .DESCRIPTION
        Calls a module API through the unified gateway with middleware support
    .PARAMETER Module
        Module name
    .PARAMETER Operation
        API operation name
    .PARAMETER Parameters
        Parameters to pass to the API
    .PARAMETER Async
        Execute asynchronously
    .PARAMETER Timeout
        Execution timeout in seconds
    .PARAMETER SkipMiddleware
        Skip global middleware (for internal calls)
    .EXAMPLE
        $result = Invoke-ModuleAPI -Module "LabRunner" -Operation "ExecuteStep" -Parameters @{
            StepName = "DeployVM"
            Parameters = @{VMName = "TestVM"}
        }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Module,
        
        [Parameter(Mandatory)]
        [string]$Operation,
        
        [Parameter()]
        [hashtable]$Parameters = @{},
        
        [Parameter()]
        [switch]$Async,
        
        [Parameter()]
        [int]$Timeout = 300,
        
        [Parameter()]
        [switch]$SkipMiddleware
    )
    
    $apiKey = "$Module.$Operation"
    $context = $null
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    
    try {
        # Check if API exists
        if (-not $script:APIRegistry.APIs.ContainsKey($apiKey)) {
            throw "API not found: $apiKey"
        }
        
        $api = $script:APIRegistry.APIs[$apiKey]
        
        # Update metrics
        $script:APIRegistry.Metrics.TotalCalls++
        $api.CallCount++
        $api.LastCalled = Get-Date
        
        # Create execution context
        $context = @{
            APIKey = $apiKey
            Module = $Module
            Operation = $Operation
            Parameters = $Parameters
            StartTime = Get-Date
            RequestId = [Guid]::NewGuid().ToString()
            User = $env:USERNAME
            Metadata = @{}
        }
        
        # Validate parameters
        $validationResult = Test-APIParameters -API $api -Parameters $Parameters
        if (-not $validationResult.IsValid) {
            throw "Parameter validation failed: $($validationResult.Errors -join ', ')"
        }
        
        # Build middleware pipeline
        $middlewarePipeline = @()
        if (-not $SkipMiddleware) {
            $middlewarePipeline += $script:APIRegistry.Middleware
        }
        $middlewarePipeline += $api.Middleware
        
        # Execute middleware pipeline
        $next = {
            param($ctx)
            # Execute the actual API handler
            $handlerResult = & $api.Handler @Parameters
            return $handlerResult
        }
        
        foreach ($middleware in $middlewarePipeline) {
            $currentNext = $next
            $next = {
                param($ctx)
                & $middleware -Context $ctx -Next $currentNext
            }.GetNewClosure()
        }
        
        # Execute with timeout
        if ($Async) {
            # Async execution
            $job = Start-Job -ScriptBlock {
                param($next, $context)
                & $next $context
            } -ArgumentList $next, $context
            
            return @{
                JobId = $job.Id
                RequestId = $context.RequestId
                Status = 'Running'
            }
        } else {
            # Sync execution with timeout
            $result = $null
            $completed = $false
            
            $runspace = [runspacefactory]::CreateRunspace()
            $runspace.Open()
            $runspace.SessionStateProxy.SetVariable('next', $next)
            $runspace.SessionStateProxy.SetVariable('context', $context)
            
            $powershell = [powershell]::Create()
            $powershell.Runspace = $runspace
            $powershell.AddScript({
                param($next, $context)
                & $next $context
            }).AddArgument($next).AddArgument($context)
            
            $handle = $powershell.BeginInvoke()
            $completed = $handle.AsyncWaitHandle.WaitOne($Timeout * 1000)
            
            if ($completed) {
                $result = $powershell.EndInvoke($handle)
            } else {
                $powershell.Stop()
                throw "API execution timed out after $Timeout seconds"
            }
            
            $powershell.Dispose()
            $runspace.Close()
            
            # Update metrics
            $script:APIRegistry.Metrics.SuccessfulCalls++
            $executionTime = $stopwatch.ElapsedMilliseconds
            $api.AverageExecutionTime = (($api.AverageExecutionTime * ($api.CallCount - 1)) + $executionTime) / $api.CallCount
            
            # Log success
            if ($script:Configuration.EnableTracing) {
                Write-CustomLog -Level 'DEBUG' -Message "API call successful: $apiKey (${executionTime}ms)"
            }
            
            return $result
        }
        
    } catch {
        # Update failure metrics
        $script:APIRegistry.Metrics.FailedCalls++
        
        # Log error
        Write-CustomLog -Level 'ERROR' -Message "API call failed: $apiKey - $_"
        
        # Record in call history
        if ($context) {
            $context.Error = $_.Exception.Message
            $context.EndTime = Get-Date
            $context.Duration = $stopwatch.ElapsedMilliseconds
            
            # Add to history (with size limit)
            $script:APIRegistry.Metrics.CallHistory.Enqueue($context)
            while ($script:APIRegistry.Metrics.CallHistory.Count -gt 1000) {
                $discard = $null
                $script:APIRegistry.Metrics.CallHistory.TryDequeue([ref]$discard) | Out-Null
            }
        }
        
        throw
    } finally {
        $stopwatch.Stop()
    }
}
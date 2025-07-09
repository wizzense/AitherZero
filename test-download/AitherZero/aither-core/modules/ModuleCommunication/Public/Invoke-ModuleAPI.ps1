function Invoke-ModuleAPI {
    <#
    .SYNOPSIS
        Invoke a registered module API
    .DESCRIPTION
        Calls a module API through the unified gateway with middleware support, circuit breaker, and enhanced security
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
    .PARAMETER AuthenticationToken
        Authentication token for secure communication
    .PARAMETER EnableCircuitBreaker
        Enable circuit breaker pattern (default: true)
    .PARAMETER RetryAttempts
        Number of retry attempts on failure
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
        [switch]$SkipMiddleware,

        [Parameter()]
        [string]$AuthenticationToken,

        [Parameter()]
        [switch]$EnableCircuitBreaker = $true,

        [Parameter()]
        [int]$RetryAttempts = 0
    )

    $apiKey = "$Module.$Operation"
    $context = $null
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $attempt = 0
    $lastError = $null

    try {
        # Retry loop with exponential backoff
        do {
        $attempt++
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
                Metadata = @{
                    Attempt = $attempt
                    MaxAttempts = $RetryAttempts + 1
                    SkipSecurity = $SkipMiddleware.IsPresent
                }
                Headers = @{}
            }

            # Add authentication header if token provided
            if ($AuthenticationToken) {
                $context.Headers['Authorization'] = "Bearer $AuthenticationToken"
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

            # Define the operation to execute with circuit breaker
            $operation = {
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
                        Async = $true
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

                    return $result
                }
            }

            # Execute with or without circuit breaker
            if ($EnableCircuitBreaker) {
                $result = Invoke-WithCircuitBreaker -Operation $operation -OperationName $apiKey -Timeout $Timeout
            } else {
                $result = & $operation
            }

            # Update metrics on success
            if (-not $result.Async) {
                $script:APIRegistry.Metrics.SuccessfulCalls++
                $executionTime = $stopwatch.ElapsedMilliseconds
                $api.AverageExecutionTime = (($api.AverageExecutionTime * ($api.CallCount - 1)) + $executionTime) / $api.CallCount

                # Log success
                if ($script:Configuration.EnableTracing) {
                    Write-CustomLog -Level 'DEBUG' -Message "API call successful: $apiKey (${executionTime}ms, attempt $attempt)"
                }
            }

            return $result

        } catch {
            $lastError = $_

            # Check if this is a retryable error
            $isRetryable = $false
            $errorMessage = $_.Exception.Message

            # Retryable conditions
            if ($errorMessage -match "timeout|connection|network|unavailable|busy") {
                $isRetryable = $true
            }

            # Don't retry validation errors or authentication errors
            if ($errorMessage -match "validation|authentication|authorization|not found") {
                $isRetryable = $false
            }

            # Log the attempt
            Write-CustomLog -Level 'WARNING' -Message "API call attempt $attempt failed: $apiKey - $errorMessage"

            # If this is the last attempt or error is not retryable, break
            if ($attempt -gt $RetryAttempts -or -not $isRetryable) {
                break
            }

            # Exponential backoff before retry
            $backoffMs = [math]::Min(1000 * [math]::Pow(2, $attempt - 1), 30000)  # Max 30 seconds
            Write-CustomLog -Level 'INFO' -Message "Retrying API call in ${backoffMs}ms (attempt $($attempt + 1) of $($RetryAttempts + 1))"
            Start-Sleep -Milliseconds $backoffMs
        }
        } while ($attempt -le $RetryAttempts)

        # If we got here, all attempts failed
        throw $lastError

    } catch {
        # Update failure metrics
        $script:APIRegistry.Metrics.FailedCalls++

        # Log error
        Write-CustomLog -Level 'ERROR' -Message "API call failed after $attempt attempts: $apiKey - $_"

        # Record in call history
        if ($context) {
            $context.Error = $_.Exception.Message
            $context.EndTime = Get-Date
            $context.Duration = $stopwatch.ElapsedMilliseconds
            $context.Attempts = $attempt

            # Add to history (with size limit)
            $script:APIRegistry.Metrics.CallHistory.Enqueue($context)
            while ($script:APIRegistry.Metrics.CallHistory.Count -gt 1000) {
                $discard = $null
                $script:APIRegistry.Metrics.CallHistory.TryDequeue([ref]$discard) | Out-Null
            }
        }

        throw $lastError
    } finally {
        $stopwatch.Stop()
    }
}

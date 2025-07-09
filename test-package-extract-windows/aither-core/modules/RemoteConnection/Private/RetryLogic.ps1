# Retry Logic and Enhanced Error Handling for RemoteConnection Module

function Invoke-WithRetry {
    <#
    .SYNOPSIS
        Executes a script block with automatic retry logic and exponential backoff.

    .DESCRIPTION
        Provides robust retry functionality for connection operations that may
        fail due to network issues, temporary service unavailability, or other
        transient errors.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [scriptblock]$ScriptBlock,

        [Parameter()]
        [int]$MaxRetries = 3,

        [Parameter()]
        [int]$BaseDelaySeconds = 2,

        [Parameter()]
        [double]$BackoffMultiplier = 2.0,

        [Parameter()]
        [int]$MaxDelaySeconds = 60,

        [Parameter()]
        [string[]]$RetriableErrors = @(
            'network', 'timeout', 'connection refused', 'unreachable',
            'temporarily unavailable', 'service unavailable', 'too many requests'
        ),

        [Parameter()]
        [string]$OperationName = "Operation",

        [Parameter()]
        [hashtable]$Parameters = @{}
    )

    $attempt = 0
    $lastError = $null

    while ($attempt -le $MaxRetries) {
        $attempt++

        try {
            Write-CustomLog -Level 'DEBUG' -Message "$OperationName - Attempt $attempt of $($MaxRetries + 1)"

            # Execute the script block with parameters
            if ($Parameters.Count -gt 0) {
                $result = & $ScriptBlock @Parameters
            } else {
                $result = & $ScriptBlock
            }

            # If we get here, the operation succeeded
            if ($attempt -gt 1) {
                Write-CustomLog -Level 'SUCCESS' -Message "$OperationName succeeded on attempt $attempt"
            }

            return @{
                Success = $true
                Result = $result
                Attempts = $attempt
                TotalTime = $null
            }
        }
        catch {
            $lastError = $_
            $errorMessage = $_.Exception.Message.ToLower()

            Write-CustomLog -Level 'WARN' -Message "$OperationName failed on attempt $attempt`: $($_.Exception.Message)"

            # Check if this is a retriable error
            $isRetriable = $false
            foreach ($retriablePattern in $RetriableErrors) {
                if ($errorMessage -like "*$retriablePattern*") {
                    $isRetriable = $true
                    break
                }
            }

            # If not retriable or we've exhausted retries, throw the error
            if (-not $isRetriable -or $attempt -gt $MaxRetries) {
                if (-not $isRetriable) {
                    Write-CustomLog -Level 'ERROR' -Message "$OperationName failed with non-retriable error: $($_.Exception.Message)"
                } else {
                    Write-CustomLog -Level 'ERROR' -Message "$OperationName failed after $attempt attempts: $($_.Exception.Message)"
                }

                return @{
                    Success = $false
                    Error = $lastError
                    Attempts = $attempt
                    TotalTime = $null
                    IsRetriable = $isRetriable
                }
            }

            # Calculate delay with exponential backoff
            if ($attempt -le $MaxRetries) {
                $delay = [Math]::Min(
                    $BaseDelaySeconds * [Math]::Pow($BackoffMultiplier, $attempt - 1),
                    $MaxDelaySeconds
                )

                Write-CustomLog -Level 'INFO' -Message "$OperationName will retry in $delay seconds (attempt $($attempt + 1))"
                Start-Sleep -Seconds $delay
            }
        }
    }

    # This should never be reached, but included for completeness
    return @{
        Success = $false
        Error = $lastError
        Attempts = $attempt
        TotalTime = $null
    }
}

function Test-ErrorRetriability {
    <#
    .SYNOPSIS
        Determines if an error is retriable based on error patterns.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.ErrorRecord]$Error,

        [Parameter()]
        [string[]]$AdditionalRetriablePatterns = @()
    )

    $errorMessage = $Error.Exception.Message.ToLower()
    $errorType = $Error.Exception.GetType().Name

    # Standard retriable patterns
    $retriablePatterns = @(
        'network', 'timeout', 'connection refused', 'unreachable',
        'temporarily unavailable', 'service unavailable', 'too many requests',
        'socket error', 'connection reset', 'connection aborted',
        'dns resolution', 'name resolution', 'authentication failure',
        'certificate', 'ssl', 'tls', 'handshake failed'
    )

    # Add any additional patterns
    $retriablePatterns += $AdditionalRetriablePatterns

    # Specific error types that are typically retriable
    $retriableErrorTypes = @(
        'HttpRequestException',
        'SocketException',
        'TimeoutException',
        'WebException',
        'InvalidOperationException'  # Sometimes for connection state issues
    )

    # Check error message patterns
    foreach ($pattern in $retriablePatterns) {
        if ($errorMessage -like "*$pattern*") {
            return $true
        }
    }

    # Check error types
    if ($errorType -in $retriableErrorTypes) {
        return $true
    }

    # Check specific PowerShell error categories that might be retriable
    $retriableCategories = @(
        'ConnectionError',
        'OperationTimeout',
        'ResourceUnavailable',
        'ProtocolError'
    )

    if ($Error.CategoryInfo.Category -in $retriableCategories) {
        return $true
    }

    return $false
}

function New-ConnectionWithRetry {
    <#
    .SYNOPSIS
        Creates a new remote connection with retry logic.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$ConnectionConfig,

        [Parameter()]
        [int]$MaxRetries = 3,

        [Parameter()]
        [int]$TimeoutSeconds = 30
    )

    $connectionOperation = {
        param($Config, $Timeout)

        switch ($Config.EndpointType) {
            'SSH' { return Connect-SSHEndpoint -Config $Config -TimeoutSeconds $Timeout }
            'WinRM' { return Connect-WinRMEndpoint -Config $Config -TimeoutSeconds $Timeout }
            'VMware' { return Connect-VMwareEndpoint -Config $Config -TimeoutSeconds $Timeout }
            'Hyper-V' { return Connect-HyperVEndpoint -Config $Config -TimeoutSeconds $Timeout }
            'Docker' { return Connect-DockerEndpoint -Config $Config -TimeoutSeconds $Timeout }
            'Kubernetes' { return Connect-KubernetesEndpoint -Config $Config -TimeoutSeconds $Timeout }
            default { throw "Unsupported endpoint type: $($Config.EndpointType)" }
        }
    }

    $parameters = @{
        Config = $ConnectionConfig
        Timeout = $TimeoutSeconds
    }

    return Invoke-WithRetry -ScriptBlock $connectionOperation -MaxRetries $MaxRetries -Parameters $parameters -OperationName "Connect to $($ConnectionConfig.HostName)"
}

function Invoke-CommandWithRetry {
    <#
    .SYNOPSIS
        Executes a remote command with retry logic.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$ConnectionConfig,

        [Parameter(Mandatory = $true)]
        [string]$Command,

        [Parameter()]
        [hashtable]$Parameters = @{},

        [Parameter()]
        [int]$MaxRetries = 2,

        [Parameter()]
        [int]$TimeoutSeconds = 300,

        [Parameter()]
        [switch]$AsJob
    )

    $commandOperation = {
        param($Config, $Cmd, $Params, $Timeout, $Job)

        switch ($Config.EndpointType) {
            'SSH' { return Invoke-SSHCommand -Config $Config -Command $Cmd -Parameters $Params -TimeoutSeconds $Timeout -AsJob:$Job }
            'WinRM' { return Invoke-WinRMCommand -Config $Config -Command $Cmd -Parameters $Params -TimeoutSeconds $Timeout -AsJob:$Job }
            'VMware' { return Invoke-VMwareCommand -Config $Config -Command $Cmd -Parameters $Params -TimeoutSeconds $Timeout -AsJob:$Job }
            'Hyper-V' { return Invoke-HyperVCommand -Config $Config -Command $Cmd -Parameters $Params -TimeoutSeconds $Timeout -AsJob:$Job }
            'Docker' { return Invoke-DockerCommand -Config $Config -Command $Cmd -Parameters $Params -TimeoutSeconds $Timeout -AsJob:$Job }
            'Kubernetes' { return Invoke-KubernetesCommand -Config $Config -Command $Cmd -Parameters $Params -TimeoutSeconds $Timeout -AsJob:$Job }
            default { throw "Unsupported endpoint type: $($Config.EndpointType)" }
        }
    }

    $cmdParameters = @{
        Config = $ConnectionConfig
        Cmd = $Command
        Params = $Parameters
        Timeout = $TimeoutSeconds
        Job = $AsJob.IsPresent
    }

    return Invoke-WithRetry -ScriptBlock $commandOperation -MaxRetries $MaxRetries -Parameters $cmdParameters -OperationName "Execute command on $($ConnectionConfig.HostName)"
}

function Get-ConnectionDiagnostics {
    <#
    .SYNOPSIS
        Performs comprehensive diagnostics for a failed connection.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$ConnectionConfig,

        [Parameter()]
        [System.Management.Automation.ErrorRecord]$LastError
    )

    $diagnostics = @{
        ConnectionName = $ConnectionConfig.Name
        HostName = $ConnectionConfig.HostName
        Port = $ConnectionConfig.Port
        EndpointType = $ConnectionConfig.EndpointType
        TestResults = @{}
        Recommendations = @()
        LastError = if ($LastError) { $LastError.Exception.Message } else { $null }
    }

    try {
        # Basic network connectivity test
        Write-CustomLog -Level 'INFO' -Message "Running connection diagnostics for $($ConnectionConfig.HostName):$($ConnectionConfig.Port)"

        # Test 1: Basic network connectivity
        $networkTest = Test-EndpointConnectivity -HostName $ConnectionConfig.HostName -Port $ConnectionConfig.Port -TimeoutSeconds 10
        $diagnostics.TestResults.NetworkConnectivity = $networkTest

        if (-not $networkTest) {
            $diagnostics.Recommendations += "Network connectivity failed. Check firewall settings and network configuration."
        }

        # Test 2: DNS resolution
        try {
            $dnsResult = [System.Net.Dns]::GetHostAddresses($ConnectionConfig.HostName)
            $diagnostics.TestResults.DNSResolution = $true
            $diagnostics.TestResults.ResolvedIPs = $dnsResult | ForEach-Object { $_.ToString() }
        }
        catch {
            $diagnostics.TestResults.DNSResolution = $false
            $diagnostics.Recommendations += "DNS resolution failed. Verify hostname or use IP address directly."
        }

        # Test 3: Protocol-specific diagnostics
        switch ($ConnectionConfig.EndpointType) {
            'SSH' {
                # Check if SSH client is available
                $sshAvailable = Get-Command ssh -ErrorAction SilentlyContinue
                $diagnostics.TestResults.SSHClientAvailable = $sshAvailable -ne $null

                if (-not $sshAvailable) {
                    $diagnostics.Recommendations += "SSH client not found. Install OpenSSH client."
                }
            }

            'WinRM' {
                # Test WinRM service
                try {
                    $wsmanTest = Test-WSMan -ComputerName $ConnectionConfig.HostName -Port $ConnectionConfig.Port -ErrorAction Stop
                    $diagnostics.TestResults.WinRMService = $true
                }
                catch {
                    $diagnostics.TestResults.WinRMService = $false
                    $diagnostics.Recommendations += "WinRM service test failed. Ensure WinRM is enabled on target system."
                }
            }

            'VMware' {
                # Check PowerCLI availability
                $powerCLIAvailable = Get-Module -Name VMware.PowerCLI -ListAvailable
                $diagnostics.TestResults.PowerCLIAvailable = $powerCLIAvailable -ne $null

                if (-not $powerCLIAvailable) {
                    $diagnostics.Recommendations += "VMware PowerCLI not found. Install with: Install-Module VMware.PowerCLI"
                }

                # Test HTTPS connectivity to VMware API
                try {
                    $vmwareUrl = "https://$($ConnectionConfig.HostName):$($ConnectionConfig.Port)/sdk"
                    $response = Invoke-WebRequest -Uri $vmwareUrl -TimeoutSec 10 -ErrorAction Stop
                    $diagnostics.TestResults.VMwareAPI = $true
                }
                catch {
                    $diagnostics.TestResults.VMwareAPI = $false
                    $diagnostics.Recommendations += "VMware API connectivity failed. Check SSL/TLS settings and credentials."
                }
            }

            'Docker' {
                # Test Docker API
                try {
                    $protocol = if ($ConnectionConfig.EnableSSL) { 'https' } else { 'http' }
                    $dockerUrl = "${protocol}://$($ConnectionConfig.HostName):$($ConnectionConfig.Port)/version"
                    $response = Invoke-RestMethod -Uri $dockerUrl -TimeoutSec 10 -ErrorAction Stop
                    $diagnostics.TestResults.DockerAPI = $true
                    $diagnostics.TestResults.DockerVersion = $response.Version
                }
                catch {
                    $diagnostics.TestResults.DockerAPI = $false
                    $diagnostics.Recommendations += "Docker API connectivity failed. Verify Docker daemon is running and API is exposed."
                }
            }

            'Kubernetes' {
                # Check kubectl availability
                $kubectlAvailable = Get-Command kubectl -ErrorAction SilentlyContinue
                $diagnostics.TestResults.KubectlAvailable = $kubectlAvailable -ne $null

                if (-not $kubectlAvailable) {
                    $diagnostics.Recommendations += "kubectl not found. Install Kubernetes CLI tools."
                }
            }
        }

        # Test 4: Credential validation
        if ($ConnectionConfig.CredentialName) {
            try {
                $credentialExists = Test-SecureCredential -CredentialName $ConnectionConfig.CredentialName -ErrorAction SilentlyContinue
                $diagnostics.TestResults.CredentialExists = $credentialExists

                if (-not $credentialExists) {
                    $diagnostics.Recommendations += "Credential '$($ConnectionConfig.CredentialName)' not found. Verify credential name or create the credential."
                }
            }
            catch {
                $diagnostics.TestResults.CredentialExists = $false
                $diagnostics.Recommendations += "Could not validate credential. SecureCredentials module may not be available."
            }
        }

        # Test 5: Security and authentication
        if ($ConnectionConfig.EnableSSL) {
            try {
                # Test SSL/TLS connectivity
                $tcpClient = New-Object System.Net.Sockets.TcpClient
                $tcpClient.Connect($ConnectionConfig.HostName, $ConnectionConfig.Port)
                $sslStream = New-Object System.Net.Security.SslStream($tcpClient.GetStream())
                $sslStream.AuthenticateAsClient($ConnectionConfig.HostName)
                $diagnostics.TestResults.SSLHandshake = $true
                $sslStream.Close()
                $tcpClient.Close()
            }
            catch {
                $diagnostics.TestResults.SSLHandshake = $false
                $diagnostics.Recommendations += "SSL/TLS handshake failed. Check certificate validity and SSL configuration."
            }
        }

        # Generate summary
        $successfulTests = ($diagnostics.TestResults.GetEnumerator() | Where-Object { $_.Value -eq $true }).Count
        $totalTests = $diagnostics.TestResults.Count
        $diagnostics.TestsSummary = "$successfulTests of $totalTests tests passed"

        # Overall health assessment
        if ($successfulTests -eq $totalTests) {
            $diagnostics.OverallHealth = "Healthy"
        } elseif ($successfulTests -gt ($totalTests / 2)) {
            $diagnostics.OverallHealth = "Partially Healthy"
        } else {
            $diagnostics.OverallHealth = "Unhealthy"
        }

        Write-CustomLog -Level 'INFO' -Message "Connection diagnostics completed: $($diagnostics.TestsSummary)"

        return $diagnostics
    }
    catch {
        Write-CustomLog -Level 'ERROR' -Message "Connection diagnostics failed: $($_.Exception.Message)"
        $diagnostics.DiagnosticsError = $_.Exception.Message
        return $diagnostics
    }
}

function Format-ConnectionError {
    <#
    .SYNOPSIS
        Formats connection errors with helpful information and suggestions.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.ErrorRecord]$Error,

        [Parameter()]
        [hashtable]$ConnectionConfig,

        [Parameter()]
        [hashtable]$Diagnostics
    )

    $errorInfo = @{
        Timestamp = Get-Date
        ErrorMessage = $Error.Exception.Message
        ErrorType = $Error.Exception.GetType().Name
        ConnectionName = if ($ConnectionConfig) { $ConnectionConfig.Name } else { "Unknown" }
        HostName = if ($ConnectionConfig) { $ConnectionConfig.HostName } else { "Unknown" }
        EndpointType = if ($ConnectionConfig) { $ConnectionConfig.EndpointType } else { "Unknown" }
        IsRetriable = Test-ErrorRetriability -Error $Error
        Suggestions = @()
    }

    # Add context-specific suggestions
    $errorMessage = $Error.Exception.Message.ToLower()

    if ($errorMessage -like "*timeout*") {
        $errorInfo.Suggestions += "Increase connection timeout or check network latency"
        $errorInfo.Suggestions += "Verify target system is responsive"
    }

    if ($errorMessage -like "*connection refused*" -or $errorMessage -like "*unreachable*") {
        $errorInfo.Suggestions += "Check if target service is running"
        $errorInfo.Suggestions += "Verify firewall settings allow connection"
        $errorInfo.Suggestions += "Confirm correct hostname and port"
    }

    if ($errorMessage -like "*authentication*" -or $errorMessage -like "*credential*") {
        $errorInfo.Suggestions += "Verify username and password are correct"
        $errorInfo.Suggestions += "Check if account is locked or expired"
        $errorInfo.Suggestions += "Ensure credential name is spelled correctly"
    }

    if ($errorMessage -like "*certificate*" -or $errorMessage -like "*ssl*" -or $errorMessage -like "*tls*") {
        $errorInfo.Suggestions += "Check SSL/TLS certificate validity"
        $errorInfo.Suggestions += "Consider using -SkipCertificateCheck for testing"
        $errorInfo.Suggestions += "Verify certificate trust chain"
    }

    # Add diagnostics information if available
    if ($Diagnostics) {
        $errorInfo.Diagnostics = $Diagnostics
        if ($Diagnostics.Recommendations) {
            $errorInfo.Suggestions += $Diagnostics.Recommendations
        }
    }

    return $errorInfo
}

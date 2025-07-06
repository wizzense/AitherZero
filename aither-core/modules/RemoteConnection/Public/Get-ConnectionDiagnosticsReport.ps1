function Get-ConnectionDiagnosticsReport {
    <#
    .SYNOPSIS
        Generates a comprehensive diagnostics report for a connection.

    .DESCRIPTION
        Creates a detailed diagnostics report for a specific connection,
        including connectivity tests, configuration validation, and
        troubleshooting recommendations.

    .PARAMETER ConnectionName
        Name of the connection to diagnose.

    .PARAMETER IncludeNetworkTests
        Include detailed network connectivity tests.

    .PARAMETER IncludeSecurityTests
        Include security and certificate validation tests.

    .PARAMETER ExportPath
        Optional path to export the report to a file.

    .EXAMPLE
        Get-ConnectionDiagnosticsReport -ConnectionName "HyperV-Lab-01"
        Generates a basic diagnostics report.

    .EXAMPLE
        Get-ConnectionDiagnosticsReport -ConnectionName "Docker-Prod" -IncludeNetworkTests -IncludeSecurityTests
        Generates a comprehensive diagnostics report.

    .EXAMPLE
        Get-ConnectionDiagnosticsReport -ConnectionName "K8s-Cluster" -ExportPath "C:\Reports\k8s-diagnostics.json"
        Generates a report and exports it to a file.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ConnectionName,

        [Parameter()]
        [switch]$IncludeNetworkTests,

        [Parameter()]
        [switch]$IncludeSecurityTests,

        [Parameter()]
        [string]$ExportPath
    )

    begin {
        Write-CustomLog -Level 'INFO' -Message "Starting diagnostics report for connection: $ConnectionName"
    }

    process {
        try {
            # Get connection configuration
            $connectionConfig = Get-ConnectionConfiguration -ConnectionName $ConnectionName
            if (-not $connectionConfig.Success) {
                throw "Connection configuration not found: $ConnectionName"
            }

            $config = $connectionConfig.Configuration
            
            # Create report structure
            $report = @{
                ConnectionName = $ConnectionName
                GeneratedAt = Get-Date
                Configuration = @{
                    EndpointType = $config.EndpointType
                    HostName = $config.HostName
                    Port = $config.Port
                    EnableSSL = $config.EnableSSL
                    CredentialName = $config.CredentialName
                    ConnectionTimeout = $config.ConnectionTimeout
                }
                DiagnosticsResults = @{}
                Recommendations = @()
                Summary = @{}
            }

            Write-CustomLog -Level 'INFO' -Message "Running basic connectivity diagnostics"

            # Run basic diagnostics
            $basicDiagnostics = Get-ConnectionDiagnostics -ConnectionConfig $config
            $report.DiagnosticsResults.Basic = $basicDiagnostics

            # Run network tests if requested
            if ($IncludeNetworkTests) {
                Write-CustomLog -Level 'INFO' -Message "Running detailed network tests"
                $networkTests = Get-DetailedNetworkDiagnostics -ConnectionConfig $config
                $report.DiagnosticsResults.Network = $networkTests
            }

            # Run security tests if requested
            if ($IncludeSecurityTests) {
                Write-CustomLog -Level 'INFO' -Message "Running security validation tests"
                $securityTests = Get-SecurityDiagnostics -ConnectionConfig $config
                $report.DiagnosticsResults.Security = $securityTests
            }

            # Test actual connection
            Write-CustomLog -Level 'INFO' -Message "Testing actual connection"
            try {
                $connectionTest = Test-RemoteConnection -ConnectionName $ConnectionName -TimeoutSeconds 30
                $report.DiagnosticsResults.ConnectionTest = @{
                    Success = $connectionTest.Success
                    TestResults = $connectionTest.TestResults
                    Error = $connectionTest.Error
                }
            } catch {
                $report.DiagnosticsResults.ConnectionTest = @{
                    Success = $false
                    Error = $_.Exception.Message
                }
            }

            # Check pool status for this connection
            $poolStats = Get-ConnectionPoolStatistics
            if ($poolStats.PoolInitialized) {
                $poolKey = "Pool_$ConnectionName"
                $inPool = $poolStats.ConnectionDetails | Where-Object { $_.PoolKey -eq $poolKey }
                $report.DiagnosticsResults.PoolStatus = if ($inPool) {
                    @{
                        InPool = $true
                        Created = $inPool.Created
                        LastUsed = $inPool.LastUsed
                        UsageCount = $inPool.UsageCount
                        Age = $inPool.Age
                        IdleTime = $inPool.IdleTime
                    }
                } else {
                    @{ InPool = $false }
                }
            }

            # Compile recommendations
            $allRecommendations = @()
            if ($basicDiagnostics.Recommendations) { $allRecommendations += $basicDiagnostics.Recommendations }
            if ($networkTests -and $networkTests.Recommendations) { $allRecommendations += $networkTests.Recommendations }
            if ($securityTests -and $securityTests.Recommendations) { $allRecommendations += $securityTests.Recommendations }
            
            $report.Recommendations = $allRecommendations | Sort-Object -Unique

            # Generate summary
            $totalTests = 0
            $passedTests = 0
            
            foreach ($category in $report.DiagnosticsResults.GetEnumerator()) {
                if ($category.Value.TestResults) {
                    foreach ($test in $category.Value.TestResults.GetEnumerator()) {
                        $totalTests++
                        if ($test.Value -eq $true) { $passedTests++ }
                    }
                }
            }

            $report.Summary = @{
                TotalTests = $totalTests
                PassedTests = $passedTests
                FailedTests = $totalTests - $passedTests
                SuccessRate = if ($totalTests -gt 0) { [math]::Round(($passedTests / $totalTests) * 100, 2) } else { 0 }
                OverallHealth = if ($passedTests -eq $totalTests) { 
                    "Healthy" 
                } elseif ($passedTests -gt ($totalTests * 0.7)) { 
                    "Mostly Healthy" 
                } elseif ($passedTests -gt ($totalTests * 0.4)) { 
                    "Partially Healthy" 
                } else { 
                    "Unhealthy" 
                }
                RecommendationCount = $report.Recommendations.Count
            }

            # Export to file if requested
            if ($ExportPath) {
                try {
                    $reportJson = $report | ConvertTo-Json -Depth 10
                    Set-Content -Path $ExportPath -Value $reportJson -Encoding UTF8
                    Write-CustomLog -Level 'SUCCESS' -Message "Diagnostics report exported to: $ExportPath"
                    $report.ExportedTo = $ExportPath
                } catch {
                    Write-CustomLog -Level 'WARN' -Message "Failed to export report: $($_.Exception.Message)"
                }
            }

            Write-CustomLog -Level 'SUCCESS' -Message "Diagnostics report completed. Overall health: $($report.Summary.OverallHealth) ($($report.Summary.PassedTests)/$($report.Summary.TotalTests) tests passed)"

            return [PSCustomObject]$report

        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Failed to generate diagnostics report: $($_.Exception.Message)"
            throw
        }
    }
}

function Get-DetailedNetworkDiagnostics {
    param($ConnectionConfig)
    
    $networkDiag = @{
        TestResults = @{}
        Recommendations = @()
    }
    
    try {
        # Ping test
        if (Get-Command Test-Connection -ErrorAction SilentlyContinue) {
            try {
                $pingResult = Test-Connection -ComputerName $ConnectionConfig.HostName -Count 3 -Quiet
                $networkDiag.TestResults.PingTest = $pingResult
                if (-not $pingResult) {
                    $networkDiag.Recommendations += "Ping test failed. Check network connectivity and firewall rules."
                }
            } catch {
                $networkDiag.TestResults.PingTest = $false
                $networkDiag.Recommendations += "Ping test error: $($_.Exception.Message)"
            }
        }
        
        # Traceroute (if available)
        if (Get-Command tracert -ErrorAction SilentlyContinue) {
            try {
                $traceResult = tracert -h 10 $ConnectionConfig.HostName 2>&1
                $networkDiag.TestResults.TracerouteAvailable = $true
                # Parse tracert output for analysis
            } catch {
                $networkDiag.TestResults.TracerouteAvailable = $false
            }
        }
        
        # Multiple port tests
        $portsToTest = @($ConnectionConfig.Port)
        if ($ConnectionConfig.EndpointType -eq 'SSH' -and $ConnectionConfig.Port -ne 22) {
            $portsToTest += 22  # Test default SSH port too
        }
        
        foreach ($port in $portsToTest) {
            $portTest = Test-EndpointConnectivity -HostName $ConnectionConfig.HostName -Port $port -TimeoutSeconds 5
            $networkDiag.TestResults."Port$port" = $portTest
            if (-not $portTest) {
                $networkDiag.Recommendations += "Port $port is not accessible. Check firewall and service configuration."
            }
        }
        
        return $networkDiag
    } catch {
        $networkDiag.TestResults.Error = $_.Exception.Message
        return $networkDiag
    }
}

function Get-SecurityDiagnostics {
    param($ConnectionConfig)
    
    $securityDiag = @{
        TestResults = @{}
        Recommendations = @()
    }
    
    try {
        # SSL/TLS tests
        if ($ConnectionConfig.EnableSSL -or $ConnectionConfig.EndpointType -in @('VMware', 'Kubernetes')) {
            try {
                $tcpClient = New-Object System.Net.Sockets.TcpClient
                $tcpClient.Connect($ConnectionConfig.HostName, $ConnectionConfig.Port)
                $sslStream = New-Object System.Net.Security.SslStream($tcpClient.GetStream())
                $sslStream.AuthenticateAsClient($ConnectionConfig.HostName)
                
                $securityDiag.TestResults.SSLHandshake = $true
                $securityDiag.TestResults.SSLProtocol = $sslStream.SslProtocol
                $securityDiag.TestResults.CipherAlgorithm = $sslStream.CipherAlgorithm
                
                $sslStream.Close()
                $tcpClient.Close()
            } catch {
                $securityDiag.TestResults.SSLHandshake = $false
                $securityDiag.Recommendations += "SSL/TLS connection failed: $($_.Exception.Message)"
            }
        }
        
        # Certificate validation
        if ($ConnectionConfig.EnableSSL) {
            try {
                $uri = "https://$($ConnectionConfig.HostName):$($ConnectionConfig.Port)"
                $webRequest = [System.Net.WebRequest]::Create($uri)
                $webRequest.Timeout = 10000
                $response = $webRequest.GetResponse()
                $securityDiag.TestResults.CertificateValid = $true
                $response.Close()
            } catch {
                $securityDiag.TestResults.CertificateValid = $false
                $securityDiag.Recommendations += "Certificate validation failed: $($_.Exception.Message)"
            }
        }
        
        # Credential validation
        if ($ConnectionConfig.CredentialName) {
            try {
                $credExists = Test-SecureCredential -CredentialName $ConnectionConfig.CredentialName -ErrorAction SilentlyContinue
                $securityDiag.TestResults.CredentialExists = $credExists
                if (-not $credExists) {
                    $securityDiag.Recommendations += "Credential '$($ConnectionConfig.CredentialName)' not found or invalid."
                }
            } catch {
                $securityDiag.TestResults.CredentialExists = $false
                $securityDiag.Recommendations += "Unable to validate credential: $($_.Exception.Message)"
            }
        }
        
        return $securityDiag
    } catch {
        $securityDiag.TestResults.Error = $_.Exception.Message
        return $securityDiag
    }
}
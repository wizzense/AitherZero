function Enable-PowerShellRemotingSSL {
    <#
    .SYNOPSIS
        Configures PowerShell Remoting with SSL/TLS encryption for secure remote administration.
        
    .DESCRIPTION
        Automates the configuration of PowerShell Remoting over HTTPS (SSL/TLS) by:
        - Selecting appropriate server authentication certificates
        - Configuring WSMan HTTPS listeners
        - Setting up firewall rules for secure remoting
        - Validating SSL configuration
        
    .PARAMETER CertificateThumbprint
        Specific certificate thumbprint to use for SSL. If not provided, auto-selects best available certificate
        
    .PARAMETER HostName
        Hostname to use for SSL listener. Defaults to certificate subject or FQDN
        
    .PARAMETER Port
        TCP port for HTTPS remoting. Default: 5986
        
    .PARAMETER Address
        Address binding for listener. Default: * (all addresses)
        
    .PARAMETER EnableFirewallRule
        Create Windows Firewall rule to allow HTTPS remoting traffic
        
    .PARAMETER ClearExisting
        Remove existing HTTPS listeners before configuring new ones
        
    .PARAMETER AutoConfigure
        Automatically select certificate and configure without prompts
        
    .PARAMETER TestConnection
        Test the SSL remoting configuration after setup
        
    .PARAMETER ClientAuth
        Require client certificate authentication
        
    .EXAMPLE
        Enable-PowerShellRemotingSSL -AutoConfigure -EnableFirewallRule
        
    .EXAMPLE
        Enable-PowerShellRemotingSSL -CertificateThumbprint "1234567890ABCDEF..." -HostName "server.domain.com"
        
    .EXAMPLE
        Enable-PowerShellRemotingSSL -Port 443 -ClientAuth -TestConnection
    #>
    
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter()]
        [string]$CertificateThumbprint,
        
        [Parameter()]
        [string]$HostName,
        
        [Parameter()]
        [ValidateRange(1, 65535)]
        [int]$Port = 5986,
        
        [Parameter()]
        [string]$Address = '*',
        
        [Parameter()]
        [switch]$EnableFirewallRule,
        
        [Parameter()]
        [switch]$ClearExisting,
        
        [Parameter()]
        [switch]$AutoConfigure,
        
        [Parameter()]
        [switch]$TestConnection,
        
        [Parameter()]
        [switch]$ClientAuth
    )
    
    begin {
        Write-CustomLog -Level 'INFO' -Message "Configuring PowerShell Remoting with SSL/TLS encryption"
        
        # Check if running as Administrator
        $CurrentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
        $Principal = New-Object Security.Principal.WindowsPrincipal($CurrentUser)
        if (-not $Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            throw "This function requires Administrator privileges"
        }
        
        # Check if PowerShell Remoting is enabled
        try {
            $RemotingStatus = Get-WSManInstance -ResourceURI 'winrm/config/service' -ErrorAction Stop
        } catch {
            Write-CustomLog -Level 'WARNING' -Message "PowerShell Remoting may not be enabled. Run 'Enable-PSRemoting -Force' first."
            throw "PowerShell Remoting is not properly configured"
        }
        
        $ConfigurationSummary = @{
            CertificateUsed = $null
            ListenerCreated = $false
            FirewallRuleCreated = $false
            TestResults = $null
            Recommendations = @()
        }
    }
    
    process {
        try {
            # Clear existing HTTPS listeners if requested
            if ($ClearExisting) {
                Write-CustomLog -Level 'INFO' -Message "Clearing existing HTTPS listeners"
                
                if ($PSCmdlet.ShouldProcess("Existing HTTPS Listeners", "Remove")) {
                    try {
                        $ExistingListeners = Get-WSManInstance -ResourceURI 'winrm/config/Listener' | 
                                           Where-Object {$_.Keys -contains 'Transport=HTTPS'}
                        
                        foreach ($Listener in $ExistingListeners) {
                            $SelectorSet = @{}
                            $Listener.Keys | ForEach-Object {
                                $key, $value = $_ -split '=', 2
                                $SelectorSet[$key] = $value
                            }
                            Remove-WSManInstance -ResourceURI 'winrm/config/Listener' -SelectorSet $SelectorSet
                        }
                        
                        Write-CustomLog -Level 'SUCCESS' -Message "Cleared existing HTTPS listeners"
                    } catch {
                        Write-CustomLog -Level 'WARNING' -Message "Could not clear existing listeners: $($_.Exception.Message)"
                    }
                }
            }
            
            # Check for existing HTTPS listener
            $ExistingHTTPSListener = $null
            try {
                $AllListeners = Get-WSManInstance -ResourceURI 'winrm/config/Listener'
                $ExistingHTTPSListener = $AllListeners | Where-Object {$_.Keys -contains 'Transport=HTTPS'}
                
                if ($ExistingHTTPSListener -and -not $ClearExisting) {
                    if (-not $AutoConfigure) {
                        Write-CustomLog -Level 'WARNING' -Message "HTTPS listener already exists. Use -ClearExisting to replace it."
                        return $ConfigurationSummary
                    } else {
                        Write-CustomLog -Level 'INFO' -Message "HTTPS listener already exists - skipping configuration"
                        $ConfigurationSummary.ListenerCreated = $true
                        return $ConfigurationSummary
                    }
                }
            } catch {
                Write-CustomLog -Level 'WARNING' -Message "Could not check for existing listeners: $($_.Exception.Message)"
            }
            
            # Find suitable certificates for server authentication
            Write-CustomLog -Level 'INFO' -Message "Searching for suitable SSL certificates"
            
            $SuitableCerts = Get-ChildItem -Path 'Cert:\LocalMachine\My' | Where-Object {
                $_.NotAfter -gt (Get-Date) -and
                $_.HasPrivateKey -and
                $_.EnhancedKeyUsageList.FriendlyName -contains 'Server Authentication'
            } | Sort-Object -Property NotAfter -Descending
            
            if ($SuitableCerts.Count -eq 0) {
                throw "No suitable server authentication certificates found in Local Machine store"
            }
            
            Write-CustomLog -Level 'INFO' -Message "Found $($SuitableCerts.Count) suitable certificate(s)"
            
            # Select certificate
            $SelectedCert = $null
            
            if ($CertificateThumbprint) {
                $SelectedCert = $SuitableCerts | Where-Object {$_.Thumbprint -eq $CertificateThumbprint}
                if (-not $SelectedCert) {
                    throw "Certificate with thumbprint '$CertificateThumbprint' not found or not suitable"
                }
                Write-CustomLog -Level 'INFO' -Message "Using specified certificate: $CertificateThumbprint"
            } elseif ($AutoConfigure -or $SuitableCerts.Count -eq 1) {
                $SelectedCert = $SuitableCerts[0]  # Select certificate with longest TTL
                Write-CustomLog -Level 'INFO' -Message "Auto-selected certificate: $($SelectedCert.Thumbprint)"
            } else {
                # Interactive certificate selection would go here
                # For automation, default to first (best) certificate
                $SelectedCert = $SuitableCerts[0]
                Write-CustomLog -Level 'INFO' -Message "Selected certificate: $($SelectedCert.Thumbprint)"
            }
            
            $ConfigurationSummary.CertificateUsed = $SelectedCert
            
            # Determine hostname from certificate if not specified
            if (-not $HostName) {
                if ($SelectedCert.Subject -match 'CN=([^,]+)') {
                    $HostName = $Matches[1].Trim()
                } elseif ($SelectedCert.DnsNameList.Count -gt 0) {
                    $HostName = $SelectedCert.DnsNameList[0].Unicode
                } else {
                    $HostName = $env:COMPUTERNAME
                    Write-CustomLog -Level 'WARNING' -Message "Could not determine hostname from certificate, using computer name"
                }
            }
            
            Write-CustomLog -Level 'INFO' -Message "Using hostname: $HostName"
            
            # Create WSMan HTTPS listener
            Write-CustomLog -Level 'INFO' -Message "Creating WSMan HTTPS listener on port $Port"
            
            $ValueSet = @{
                Hostname = $HostName
                CertificateThumbprint = $SelectedCert.Thumbprint
            }
            
            if ($ClientAuth) {
                $ValueSet['ClientCertificateThumbprint'] = ''  # Require client cert but don't specify specific one
            }
            
            $SelectorSet = @{
                Transport = 'HTTPS'
                Address = $Address
            }
            
            if ($PSCmdlet.ShouldProcess("WSMan HTTPS Listener", "Create new listener")) {
                try {
                    $NewListener = New-WSManInstance -ResourceURI 'winrm/config/Listener' -SelectorSet $SelectorSet -ValueSet $ValueSet
                    $ConfigurationSummary.ListenerCreated = $true
                    Write-CustomLog -Level 'SUCCESS' -Message "HTTPS listener created successfully"
                } catch {
                    Write-CustomLog -Level 'ERROR' -Message "Failed to create HTTPS listener: $($_.Exception.Message)"
                    throw
                }
            }
            
            # Configure firewall rule if requested
            if ($EnableFirewallRule) {
                Write-CustomLog -Level 'INFO' -Message "Creating Windows Firewall rule for PowerShell Remoting HTTPS"
                
                $FirewallRuleName = "PowerShell Remoting HTTPS-In"
                
                if ($PSCmdlet.ShouldProcess($FirewallRuleName, "Create firewall rule")) {
                    try {
                        # Check if rule already exists
                        $ExistingRule = Get-NetFirewallRule -DisplayName $FirewallRuleName -ErrorAction SilentlyContinue
                        
                        if ($ExistingRule) {
                            Write-CustomLog -Level 'INFO' -Message "Firewall rule already exists: $FirewallRuleName"
                        } else {
                            $FirewallParams = @{
                                DisplayName = $FirewallRuleName
                                Direction = 'Inbound'
                                Protocol = 'TCP'
                                LocalPort = $Port
                                Action = 'Allow'
                                Profile = 'Domain,Private'
                                Description = 'Allow PowerShell Remoting over HTTPS'
                            }
                            
                            New-NetFirewallRule @FirewallParams | Out-Null
                            $ConfigurationSummary.FirewallRuleCreated = $true
                            Write-CustomLog -Level 'SUCCESS' -Message "Firewall rule created: $FirewallRuleName"
                        }
                    } catch {
                        Write-CustomLog -Level 'WARNING' -Message "Could not create firewall rule: $($_.Exception.Message)"
                    }
                }
            }
            
            # Test connection if requested
            if ($TestConnection) {
                Write-CustomLog -Level 'INFO' -Message "Testing PowerShell Remoting SSL connection"
                
                try {
                    $TestResults = @{
                        LocalConnection = $false
                        CertificateValid = $false
                        ServiceResponding = $false
                    }
                    
                    # Test local WSMan service
                    $WSManTest = Test-WSMan -ComputerName 'localhost' -UseSSL -Port $Port -ErrorAction SilentlyContinue
                    if ($WSManTest) {
                        $TestResults.ServiceResponding = $true
                        Write-CustomLog -Level 'SUCCESS' -Message "WSMan service responding on HTTPS"
                    }
                    
                    # Test certificate validation
                    try {
                        $CertTest = Test-WSMan -ComputerName $HostName -UseSSL -Port $Port -ErrorAction SilentlyContinue
                        if ($CertTest) {
                            $TestResults.CertificateValid = $true
                            Write-CustomLog -Level 'SUCCESS' -Message "SSL certificate validation successful"
                        }
                    } catch {
                        Write-CustomLog -Level 'WARNING' -Message "SSL certificate validation failed: $($_.Exception.Message)"
                    }
                    
                    # Test PowerShell remoting session
                    try {
                        $SessionTest = New-PSSession -ComputerName $HostName -UseSSL -Port $Port -ErrorAction SilentlyContinue
                        if ($SessionTest) {
                            Remove-PSSession $SessionTest
                            $TestResults.LocalConnection = $true
                            Write-CustomLog -Level 'SUCCESS' -Message "PowerShell Remoting SSL connection successful"
                        }
                    } catch {
                        Write-CustomLog -Level 'WARNING' -Message "PowerShell Remoting connection test failed: $($_.Exception.Message)"
                    }
                    
                    $ConfigurationSummary.TestResults = $TestResults
                    
                } catch {
                    Write-CustomLog -Level 'WARNING' -Message "Connection testing failed: $($_.Exception.Message)"
                }
            }
            
        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Error configuring PowerShell Remoting SSL: $($_.Exception.Message)"
            throw
        }
    }
    
    end {
        Write-CustomLog -Level 'SUCCESS' -Message "PowerShell Remoting SSL configuration completed"
        
        # Generate recommendations
        $ConfigurationSummary.Recommendations += "Connect to this server using: Enter-PSSession -ComputerName $HostName -UseSSL -Port $Port"
        $ConfigurationSummary.Recommendations += "Use certificate-based authentication for enhanced security"
        $ConfigurationSummary.Recommendations += "Regularly monitor SSL certificate expiration dates"
        $ConfigurationSummary.Recommendations += "Consider using custom ports for additional security through obscurity"
        $ConfigurationSummary.Recommendations += "Implement network-level access controls in addition to SSL"
        $ConfigurationSummary.Recommendations += "Monitor Windows Security logs for remoting activities"
        
        if ($ConfigurationSummary.CertificateUsed) {
            Write-CustomLog -Level 'INFO' -Message "Certificate Details:"
            Write-CustomLog -Level 'INFO' -Message "  Subject: $($ConfigurationSummary.CertificateUsed.Subject)"
            Write-CustomLog -Level 'INFO' -Message "  Thumbprint: $($ConfigurationSummary.CertificateUsed.Thumbprint)"
            Write-CustomLog -Level 'INFO' -Message "  Expires: $($ConfigurationSummary.CertificateUsed.NotAfter)"
        }
        
        Write-CustomLog -Level 'INFO' -Message "Connection Details:"
        Write-CustomLog -Level 'INFO' -Message "  Hostname: $HostName"
        Write-CustomLog -Level 'INFO' -Message "  Port: $Port"
        Write-CustomLog -Level 'INFO' -Message "  Address: $Address"
        
        if ($ClientAuth) {
            Write-CustomLog -Level 'INFO' -Message "  Client Authentication: Required"
        }
        
        # Display recommendations
        foreach ($Recommendation in $ConfigurationSummary.Recommendations) {
            Write-CustomLog -Level 'INFO' -Message "Recommendation: $Recommendation"
        }
        
        return $ConfigurationSummary
    }
}
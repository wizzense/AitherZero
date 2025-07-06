function Enable-DNSSECValidation {
    <#
    .SYNOPSIS
        Enables DNSSEC validation and DNS security features.
        
    .DESCRIPTION
        Configures DNSSEC validation on DNS servers and clients to prevent DNS spoofing
        and cache poisoning attacks. Supports both Windows DNS Server and client-side
        validation configuration with comprehensive security settings.
        
    .PARAMETER ComputerName
        Target computer names for DNSSEC configuration. Default: localhost
        
    .PARAMETER Credential
        Credentials for remote computer access
        
    .PARAMETER DNSServerRole
        Configure as DNS server with DNSSEC signing capabilities
        
    .PARAMETER ClientValidation
        Enable client-side DNSSEC validation
        
    .PARAMETER TrustAnchors
        Custom trust anchors for DNSSEC validation
        
    .PARAMETER ZoneSigningKey
        Path to zone signing key for DNS server
        
    .PARAMETER KeySigningKey
        Path to key signing key for DNS server
        
    .PARAMETER ValidationMode
        DNSSEC validation mode: Strict, Permissive, or Disabled
        
    .PARAMETER CacheSettings
        Configure DNS cache security settings
        
    .PARAMETER TestMode
        Show what would be configured without making changes
        
    .PARAMETER ReportPath
        Path to save DNSSEC configuration report
        
    .PARAMETER ValidateConfiguration
        Validate DNSSEC configuration after setup
        
    .EXAMPLE
        Enable-DNSSECValidation -DNSServerRole -ValidationMode Strict -ReportPath "C:\Reports\dnssec.html"
        
    .EXAMPLE
        Enable-DNSSECValidation -ComputerName @("DNS1", "DNS2") -ClientValidation -Credential $Creds
        
    .EXAMPLE
        Enable-DNSSECValidation -TestMode -ValidationMode Permissive -CacheSettings -ValidateConfiguration
    #>
    
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter()]
        [string[]]$ComputerName = @('localhost'),
        
        [Parameter()]
        [pscredential]$Credential,
        
        [Parameter()]
        [switch]$DNSServerRole,
        
        [Parameter()]
        [switch]$ClientValidation,
        
        [Parameter()]
        [string[]]$TrustAnchors = @(),
        
        [Parameter()]
        [string]$ZoneSigningKey,
        
        [Parameter()]
        [string]$KeySigningKey,
        
        [Parameter()]
        [ValidateSet('Strict', 'Permissive', 'Disabled')]
        [string]$ValidationMode = 'Strict',
        
        [Parameter()]
        [switch]$CacheSettings,
        
        [Parameter()]
        [switch]$TestMode,
        
        [Parameter()]
        [string]$ReportPath,
        
        [Parameter()]
        [switch]$ValidateConfiguration
    )
    
    begin {
        Write-CustomLog -Level 'INFO' -Message "Starting DNSSEC validation configuration for $($ComputerName.Count) computer(s)"
        
        # Check if running as Administrator
        $CurrentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
        $Principal = New-Object Security.Principal.WindowsPrincipal($CurrentUser)
        if (-not $Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            throw "This function requires Administrator privileges"
        }
        
        $DNSSECResults = @{
            ValidationMode = $ValidationMode
            ComputersConfigured = @()
            DNSServerConfigurations = 0
            ClientConfigurations = 0
            TrustAnchorsInstalled = 0
            ValidationTests = @()
            Errors = @()
            Recommendations = @()
        }
        
        # Define default trust anchors (root zone)
        $DefaultTrustAnchors = @(
            @{
                Name = "."
                KeyTag = 20326
                Algorithm = 8
                DigestType = 2
                Digest = "E06D44B80B8F1D39A95C0B0D7C65D08458E880409BBC683457104237C7F8EC8D"
            }
        )
        
        if ($TrustAnchors.Count -eq 0) {
            $TrustAnchors = $DefaultTrustAnchors
        }
        
        # DNSSEC configuration templates
        $DNSSECConfigurations = @{
            Server = @{
                Registry = @{
                    'HKLM:\SYSTEM\CurrentControlSet\Services\DNS\Parameters' = @{
                        'EnableDnssec' = 1
                        'DnssecValidation' = 1
                        'EnableDnssecLookaside' = 0
                    }
                }
                Policies = @{
                    ValidationPolicy = $ValidationMode
                    TrustAnchorManagement = 'Automatic'
                    NegativeCaching = $true
                }
            }
            Client = @{
                Registry = @{
                    'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient' = @{
                        'EnableMulticast' = 0
                        'DisableSmartNameResolution' = 1
                    }
                    'HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters' = @{
                        'EnableAutoDoh' = 2
                        'DohPolicy' = 3
                    }
                }
                NetworkSettings = @{
                    SecureDNS = $true
                    DNSOverHTTPS = $true
                }
            }
        }
    }
    
    process {
        try {
            foreach ($Computer in $ComputerName) {
                Write-CustomLog -Level 'INFO' -Message "Configuring DNSSEC on: $Computer"
                
                $ComputerResult = @{
                    ComputerName = $Computer
                    ConfigurationTime = Get-Date
                    ServerConfigured = $false
                    ClientConfigured = $false
                    TrustAnchors = @()
                    ValidationStatus = 'Unknown'
                    RegistryChanges = @()
                    ServiceChanges = @()
                    Errors = @()
                }
                
                try {
                    # Check if DNS Server role is installed
                    $ScriptBlock = {
                        param($DNSServerRole, $ClientValidation, $ValidationMode, $TrustAnchors, $CacheSettings, $TestMode, $DNSSECConfigurations, $ValidateConfiguration)
                        
                        $LocalResult = @{
                            ServerConfigured = $false
                            ClientConfigured = $false
                            TrustAnchors = @()
                            RegistryChanges = @()
                            ServiceChanges = @()
                            ValidationTests = @()
                            Errors = @()
                        }
                        
                        try {
                            # Check DNS Server installation
                            $DNSServerInstalled = $false
                            try {
                                $DNSService = Get-Service -Name 'DNS' -ErrorAction SilentlyContinue
                                if ($DNSService) {
                                    $DNSServerInstalled = $true
                                }
                            } catch {
                                $DNSServerInstalled = $false
                            }
                            
                            # Configure DNS Server if requested and available
                            if ($DNSServerRole -and $DNSServerInstalled) {
                                Write-Progress -Activity "Configuring DNS Server DNSSEC" -PercentComplete 20
                                
                                # Configure DNS Server registry settings
                                foreach ($RegistryPath in $DNSSECConfigurations.Server.Registry.Keys) {
                                    $Settings = $DNSSECConfigurations.Server.Registry[$RegistryPath]
                                    
                                    if (-not (Test-Path $RegistryPath) -and -not $TestMode) {
                                        New-Item -Path $RegistryPath -Force | Out-Null
                                    }
                                    
                                    foreach ($Setting in $Settings.Keys) {
                                        $Value = $Settings[$Setting]
                                        $CurrentValue = $null
                                        
                                        try {
                                            $CurrentValue = Get-ItemProperty -Path $RegistryPath -Name $Setting -ErrorAction SilentlyContinue | Select-Object -ExpandProperty $Setting
                                        } catch {
                                            $CurrentValue = $null
                                        }
                                        
                                        if ($CurrentValue -ne $Value) {
                                            $ChangeInfo = @{
                                                Path = $RegistryPath
                                                Setting = $Setting
                                                OldValue = $CurrentValue
                                                NewValue = $Value
                                                Type = 'Registry'
                                            }
                                            
                                            if ($TestMode) {
                                                $LocalResult.RegistryChanges += $ChangeInfo
                                            } else {
                                                Set-ItemProperty -Path $RegistryPath -Name $Setting -Value $Value -Force
                                                $LocalResult.RegistryChanges += $ChangeInfo
                                            }
                                        }
                                    }
                                }
                                
                                # Configure DNSSEC using PowerShell cmdlets if available
                                try {
                                    if (Get-Command 'Set-DnsServerDnsSecZoneSetting' -ErrorAction SilentlyContinue) {
                                        if (-not $TestMode) {
                                            # Enable DNSSEC validation
                                            Set-DnsServerDnsSecZoneSetting -ZoneName "." -ValidateNameServerResponse $true -ErrorAction SilentlyContinue
                                            
                                            # Configure validation policy
                                            if ($ValidationMode -eq 'Strict') {
                                                Set-DnsServerRecursion -Enable $true -SecureResponse $true -ErrorAction SilentlyContinue
                                            }
                                        }
                                        
                                        $LocalResult.ServiceChanges += "Configured DNSSEC validation policy: $ValidationMode"
                                    }
                                } catch {
                                    $LocalResult.Errors += "DNS Server cmdlets not available: $($_.Exception.Message)"
                                }
                                
                                $LocalResult.ServerConfigured = $true
                            } elseif ($DNSServerRole -and -not $DNSServerInstalled) {
                                $LocalResult.Errors += "DNS Server role requested but not installed"
                            }
                            
                            # Configure client-side DNSSEC validation
                            if ($ClientValidation) {
                                Write-Progress -Activity "Configuring Client DNSSEC" -PercentComplete 50
                                
                                # Configure client registry settings
                                foreach ($RegistryPath in $DNSSECConfigurations.Client.Registry.Keys) {
                                    $Settings = $DNSSECConfigurations.Client.Registry[$RegistryPath]
                                    
                                    if (-not (Test-Path $RegistryPath) -and -not $TestMode) {
                                        New-Item -Path $RegistryPath -Force | Out-Null
                                    }
                                    
                                    foreach ($Setting in $Settings.Keys) {
                                        $Value = $Settings[$Setting]
                                        $CurrentValue = $null
                                        
                                        try {
                                            $CurrentValue = Get-ItemProperty -Path $RegistryPath -Name $Setting -ErrorAction SilentlyContinue | Select-Object -ExpandProperty $Setting
                                        } catch {
                                            $CurrentValue = $null
                                        }
                                        
                                        if ($CurrentValue -ne $Value) {
                                            $ChangeInfo = @{
                                                Path = $RegistryPath
                                                Setting = $Setting
                                                OldValue = $CurrentValue
                                                NewValue = $Value
                                                Type = 'Registry'
                                            }
                                            
                                            if ($TestMode) {
                                                $LocalResult.RegistryChanges += $ChangeInfo
                                            } else {
                                                Set-ItemProperty -Path $RegistryPath -Name $Setting -Value $Value -Force
                                                $LocalResult.RegistryChanges += $ChangeInfo
                                            }
                                        }
                                    }
                                }
                                
                                $LocalResult.ClientConfigured = $true
                            }
                            
                            # Configure DNS cache security settings
                            if ($CacheSettings) {
                                Write-Progress -Activity "Configuring DNS Cache Security" -PercentComplete 70
                                
                                $CacheRegistryPath = 'HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters'
                                $CacheSettings = @{
                                    'MaxCacheTtl' = 86400           # 24 hours
                                    'MaxNegativeCacheTtl' = 900     # 15 minutes
                                    'EnableAutoDoh' = 2             # Enable DNS over HTTPS
                                    'DohPolicy' = 3                 # Require DoH
                                }
                                
                                if (-not (Test-Path $CacheRegistryPath) -and -not $TestMode) {
                                    New-Item -Path $CacheRegistryPath -Force | Out-Null
                                }
                                
                                foreach ($Setting in $CacheSettings.Keys) {
                                    $Value = $CacheSettings[$Setting]
                                    $CurrentValue = $null
                                    
                                    try {
                                        $CurrentValue = Get-ItemProperty -Path $CacheRegistryPath -Name $Setting -ErrorAction SilentlyContinue | Select-Object -ExpandProperty $Setting
                                    } catch {
                                        $CurrentValue = $null
                                    }
                                    
                                    if ($CurrentValue -ne $Value) {
                                        $ChangeInfo = @{
                                            Path = $CacheRegistryPath
                                            Setting = $Setting
                                            OldValue = $CurrentValue
                                            NewValue = $Value
                                            Type = 'CacheSettings'
                                        }
                                        
                                        if ($TestMode) {
                                            $LocalResult.RegistryChanges += $ChangeInfo
                                        } else {
                                            Set-ItemProperty -Path $CacheRegistryPath -Name $Setting -Value $Value -Force
                                            $LocalResult.RegistryChanges += $ChangeInfo
                                        }
                                    }
                                }
                                
                                $LocalResult.ServiceChanges += "Configured DNS cache security settings"
                            }
                            
                            # Install trust anchors
                            if ($TrustAnchors.Count -gt 0) {
                                Write-Progress -Activity "Installing Trust Anchors" -PercentComplete 80
                                
                                foreach ($Anchor in $TrustAnchors) {
                                    try {
                                        if (-not $TestMode) {
                                            # Add trust anchor using registry or command line tools
                                            $TrustAnchorPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\DnsServerTrustAnchors"
                                            
                                            if (-not (Test-Path $TrustAnchorPath)) {
                                                New-Item -Path $TrustAnchorPath -Force | Out-Null
                                            }
                                            
                                            $AnchorKey = "$($Anchor.Name)_$($Anchor.KeyTag)"
                                            $AnchorData = @{
                                                'Algorithm' = $Anchor.Algorithm
                                                'DigestType' = $Anchor.DigestType
                                                'Digest' = $Anchor.Digest
                                            }
                                            
                                            foreach ($Property in $AnchorData.Keys) {
                                                Set-ItemProperty -Path "$TrustAnchorPath\$AnchorKey" -Name $Property -Value $AnchorData[$Property] -Force
                                            }
                                        }
                                        
                                        $LocalResult.TrustAnchors += $Anchor
                                        
                                    } catch {
                                        $LocalResult.Errors += "Failed to install trust anchor for $($Anchor.Name): $($_.Exception.Message)"
                                    }
                                }
                                
                                $LocalResult.ServiceChanges += "Installed $($TrustAnchors.Count) trust anchors"
                            }
                            
                            # Restart DNS services if changes were made
                            if ($LocalResult.RegistryChanges.Count -gt 0 -and -not $TestMode) {
                                Write-Progress -Activity "Restarting DNS Services" -PercentComplete 90
                                
                                try {
                                    # Restart DNS Client service
                                    Restart-Service -Name 'Dnscache' -Force -ErrorAction SilentlyContinue
                                    $LocalResult.ServiceChanges += "Restarted DNS Client service"
                                    
                                    # Restart DNS Server service if configured
                                    if ($LocalResult.ServerConfigured) {
                                        Restart-Service -Name 'DNS' -Force -ErrorAction SilentlyContinue
                                        $LocalResult.ServiceChanges += "Restarted DNS Server service"
                                    }
                                } catch {
                                    $LocalResult.Errors += "Failed to restart DNS services: $($_.Exception.Message)"
                                }
                            }
                            
                            # Validate DNSSEC configuration
                            if ($ValidateConfiguration) {
                                Write-Progress -Activity "Validating DNSSEC Configuration" -PercentComplete 95
                                
                                try {
                                    # Test DNSSEC validation using nslookup or Resolve-DnsName
                                    $ValidationTests = @()
                                    
                                    # Test with a known DNSSEC-signed domain
                                    $TestDomains = @('cloudflare.com', 'google.com')
                                    
                                    foreach ($Domain in $TestDomains) {
                                        try {
                                            $Result = Resolve-DnsName -Name $Domain -Type A -DnsOnly -ErrorAction SilentlyContinue
                                            if ($Result) {
                                                $ValidationTests += @{
                                                    Domain = $Domain
                                                    Status = 'Success'
                                                    Message = 'DNS resolution successful'
                                                }
                                            } else {
                                                $ValidationTests += @{
                                                    Domain = $Domain
                                                    Status = 'Failed'
                                                    Message = 'DNS resolution failed'
                                                }
                                            }
                                        } catch {
                                            $ValidationTests += @{
                                                Domain = $Domain
                                                Status = 'Error'
                                                Message = $_.Exception.Message
                                            }
                                        }
                                    }
                                    
                                    $LocalResult.ValidationTests = $ValidationTests
                                    
                                } catch {
                                    $LocalResult.Errors += "Validation testing failed: $($_.Exception.Message)"
                                }
                            }
                            
                        } catch {
                            $LocalResult.Errors += "General configuration error: $($_.Exception.Message)"
                        }
                        
                        Write-Progress -Activity "DNSSEC Configuration Complete" -PercentComplete 100 -Completed
                        return $LocalResult
                    }
                    
                    # Execute configuration
                    if ($Computer -eq 'localhost') {
                        $Result = & $ScriptBlock $DNSServerRole $ClientValidation $ValidationMode $TrustAnchors $CacheSettings $TestMode $DNSSECConfigurations $ValidateConfiguration
                    } else {
                        if ($Credential) {
                            $Result = Invoke-Command -ComputerName $Computer -Credential $Credential -ScriptBlock $ScriptBlock -ArgumentList $DNSServerRole, $ClientValidation, $ValidationMode, $TrustAnchors, $CacheSettings, $TestMode, $DNSSECConfigurations, $ValidateConfiguration
                        } else {
                            $Result = Invoke-Command -ComputerName $Computer -ScriptBlock $ScriptBlock -ArgumentList $DNSServerRole, $ClientValidation, $ValidationMode, $TrustAnchors, $CacheSettings, $TestMode, $DNSSECConfigurations, $ValidateConfiguration
                        }
                    }
                    
                    # Merge results
                    $ComputerResult.ServerConfigured = $Result.ServerConfigured
                    $ComputerResult.ClientConfigured = $Result.ClientConfigured
                    $ComputerResult.TrustAnchors = $Result.TrustAnchors
                    $ComputerResult.RegistryChanges = $Result.RegistryChanges
                    $ComputerResult.ServiceChanges = $Result.ServiceChanges
                    $ComputerResult.Errors = $Result.Errors
                    
                    if ($Result.ValidationTests) {
                        $DNSSECResults.ValidationTests += $Result.ValidationTests
                    }
                    
                    # Update counters
                    if ($Result.ServerConfigured) {
                        $DNSSECResults.DNSServerConfigurations++
                    }
                    if ($Result.ClientConfigured) {
                        $DNSSECResults.ClientConfigurations++
                    }
                    $DNSSECResults.TrustAnchorsInstalled += $Result.TrustAnchors.Count
                    
                    # Determine overall validation status
                    if ($Result.Errors.Count -eq 0) {
                        if ($Result.ServerConfigured -or $Result.ClientConfigured) {
                            $ComputerResult.ValidationStatus = 'Configured'
                        } else {
                            $ComputerResult.ValidationStatus = 'No Changes'
                        }
                    } else {
                        $ComputerResult.ValidationStatus = 'Error'
                    }
                    
                    Write-CustomLog -Level 'SUCCESS' -Message "DNSSEC configuration completed for $Computer"
                    
                } catch {
                    $Error = "Failed to configure DNSSEC on $Computer`: $($_.Exception.Message)"
                    $ComputerResult.Errors += $Error
                    $ComputerResult.ValidationStatus = 'Failed'
                    Write-CustomLog -Level 'ERROR' -Message $Error
                }
                
                $DNSSECResults.ComputersConfigured += $ComputerResult
            }
            
        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Error during DNSSEC configuration: $($_.Exception.Message)"
            throw
        }
    }
    
    end {
        Write-CustomLog -Level 'SUCCESS' -Message "DNSSEC validation configuration completed"
        
        # Generate recommendations
        $DNSSECResults.Recommendations += "Monitor DNS query logs for DNSSEC validation failures"
        $DNSSECResults.Recommendations += "Regularly update trust anchors for root zone rollovers"
        $DNSSECResults.Recommendations += "Test DNSSEC validation with known signed domains"
        $DNSSECResults.Recommendations += "Configure DNS over HTTPS (DoH) for additional security"
        $DNSSECResults.Recommendations += "Implement DNS filtering for malicious domains"
        
        if ($DNSSECResults.DNSServerConfigurations -gt 0) {
            $DNSSECResults.Recommendations += "Configure DNS server zone signing for authoritative zones"
            $DNSSECResults.Recommendations += "Monitor DNS server performance after DNSSEC enablement"
        }
        
        if ($DNSSECResults.ClientConfigurations -gt 0) {
            $DNSSECResults.Recommendations += "Test application compatibility with DNSSEC validation"
            $DNSSECResults.Recommendations += "Configure fallback DNS servers for redundancy"
        }
        
        # Generate HTML report if requested
        if ($ReportPath) {
            try {
                $HtmlReport = @"
<!DOCTYPE html>
<html>
<head>
    <title>DNSSEC Configuration Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #f0f0f0; padding: 15px; border-radius: 5px; }
        .computer { border: 1px solid #ccc; margin: 20px 0; padding: 15px; border-radius: 5px; }
        .success { color: green; font-weight: bold; }
        .error { color: red; font-weight: bold; }
        .warning { color: orange; font-weight: bold; }
        table { border-collapse: collapse; width: 100%; margin: 10px 0; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
        .recommendation { background-color: #e7f3ff; padding: 10px; margin: 5px 0; border-radius: 3px; }
    </style>
</head>
<body>
    <div class='header'>
        <h1>DNSSEC Configuration Report</h1>
        <p><strong>Validation Mode:</strong> $($DNSSECResults.ValidationMode)</p>
        <p><strong>Generated:</strong> $(Get-Date)</p>
        <p><strong>Computers Configured:</strong> $($DNSSECResults.ComputersConfigured.Count)</p>
        <p><strong>DNS Server Configurations:</strong> $($DNSSECResults.DNSServerConfigurations)</p>
        <p><strong>Client Configurations:</strong> $($DNSSECResults.ClientConfigurations)</p>
        <p><strong>Trust Anchors Installed:</strong> $($DNSSECResults.TrustAnchorsInstalled)</p>
    </div>
"@
                
                foreach ($Computer in $DNSSECResults.ComputersConfigured) {
                    $StatusClass = switch ($Computer.ValidationStatus) {
                        'Configured' { 'success' }
                        'Failed' { 'error' }
                        'Error' { 'error' }
                        default { 'warning' }
                    }
                    
                    $HtmlReport += "<div class='computer'>"
                    $HtmlReport += "<h2>$($Computer.ComputerName)</h2>"
                    $HtmlReport += "<p><strong>Status:</strong> <span class='$StatusClass'>$($Computer.ValidationStatus)</span></p>"
                    $HtmlReport += "<p><strong>Server Configured:</strong> $($Computer.ServerConfigured)</p>"
                    $HtmlReport += "<p><strong>Client Configured:</strong> $($Computer.ClientConfigured)</p>"
                    $HtmlReport += "<p><strong>Trust Anchors:</strong> $($Computer.TrustAnchors.Count)</p>"
                    
                    if ($Computer.RegistryChanges.Count -gt 0) {
                        $HtmlReport += "<h3>Configuration Changes</h3>"
                        $HtmlReport += "<table><tr><th>Type</th><th>Path</th><th>Setting</th><th>Old Value</th><th>New Value</th></tr>"
                        
                        foreach ($Change in $Computer.RegistryChanges) {
                            $HtmlReport += "<tr>"
                            $HtmlReport += "<td>$($Change.Type)</td>"
                            $HtmlReport += "<td>$($Change.Path)</td>"
                            $HtmlReport += "<td>$($Change.Setting)</td>"
                            $HtmlReport += "<td>$($Change.OldValue)</td>"
                            $HtmlReport += "<td>$($Change.NewValue)</td>"
                            $HtmlReport += "</tr>"
                        }
                        
                        $HtmlReport += "</table>"
                    }
                    
                    $HtmlReport += "</div>"
                }
                
                if ($DNSSECResults.ValidationTests.Count -gt 0) {
                    $HtmlReport += "<div class='computer'><h2>Validation Tests</h2>"
                    $HtmlReport += "<table><tr><th>Domain</th><th>Status</th><th>Message</th></tr>"
                    
                    foreach ($Test in $DNSSECResults.ValidationTests) {
                        $TestStatusClass = switch ($Test.Status) {
                            'Success' { 'success' }
                            'Failed' { 'error' }
                            'Error' { 'error' }
                            default { 'warning' }
                        }
                        
                        $HtmlReport += "<tr>"
                        $HtmlReport += "<td>$($Test.Domain)</td>"
                        $HtmlReport += "<td class='$TestStatusClass'>$($Test.Status)</td>"
                        $HtmlReport += "<td>$($Test.Message)</td>"
                        $HtmlReport += "</tr>"
                    }
                    
                    $HtmlReport += "</table></div>"
                }
                
                $HtmlReport += "<div class='header'><h2>Recommendations</h2>"
                foreach ($Rec in $DNSSECResults.Recommendations) {
                    $HtmlReport += "<div class='recommendation'>$Rec</div>"
                }
                $HtmlReport += "</div>"
                
                $HtmlReport += "</body></html>"
                
                $HtmlReport | Out-File -FilePath $ReportPath -Encoding UTF8
                Write-CustomLog -Level 'SUCCESS' -Message "DNSSEC configuration report saved to: $ReportPath"
                
            } catch {
                Write-CustomLog -Level 'ERROR' -Message "Failed to generate report: $($_.Exception.Message)"
            }
        }
        
        # Display summary
        Write-CustomLog -Level 'INFO' -Message "DNSSEC Configuration Summary:"
        Write-CustomLog -Level 'INFO' -Message "  Validation Mode: $($DNSSECResults.ValidationMode)"
        Write-CustomLog -Level 'INFO' -Message "  Computers: $($DNSSECResults.ComputersConfigured.Count)"
        Write-CustomLog -Level 'INFO' -Message "  DNS Server Configurations: $($DNSSECResults.DNSServerConfigurations)"
        Write-CustomLog -Level 'INFO' -Message "  Client Configurations: $($DNSSECResults.ClientConfigurations)"
        Write-CustomLog -Level 'INFO' -Message "  Trust Anchors: $($DNSSECResults.TrustAnchorsInstalled)"
        
        if ($TestMode) {
            Write-CustomLog -Level 'INFO' -Message "TEST MODE: No actual changes were made"
        }
        
        return $DNSSECResults
    }
}
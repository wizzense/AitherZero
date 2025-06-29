function Set-DNSSinkhole {
    <#
    .SYNOPSIS
        Configures DNS sinkholing for malicious domain blocking and threat mitigation.
        
    .DESCRIPTION
        Creates and manages DNS sinkhole zones to block access to malicious domains by
        redirecting them to a controlled IP address. Supports bulk domain lists, wildcard
        blocking, and integration with threat intelligence feeds.
        
    .PARAMETER DomainList
        Array of domains to sinkhole. Can include FQDNs or domain names
        
    .PARAMETER InputFile
        Path to file containing domains to sinkhole (one per line, supports comments)
        
    .PARAMETER SinkholeIP
        IP address to redirect sinkholed domains to. Default: 0.0.0.0
        
    .PARAMETER DNSServerName
        Target DNS server FQDN. Default: localhost
        
    .PARAMETER IncludeWildcard
        Add wildcard (*) records to match all subdomains
        
    .PARAMETER RemoveWWW
        Remove 'www.' prefix from domain names before processing
        
    .PARAMETER Operation
        Sinkhole operation: Create, Delete, Reload, or Status
        
    .PARAMETER Credential
        Credentials for remote DNS server access
        
    .PARAMETER LoggingIP
        IP address of logging server for sinkholed traffic analysis
        
    .PARAMETER ThreatCategories
        Array of threat categories to automatically sinkhole
        
    .PARAMETER TestMode
        Show what would be done without making changes
        
    .EXAMPLE
        Set-DNSSinkhole -DomainList @("malware.com", "phishing.net") -SinkholeIP "192.168.1.100"
        
    .EXAMPLE
        Set-DNSSinkhole -InputFile "C:\Blocklists\malware-domains.txt" -IncludeWildcard -LoggingIP "10.0.1.50"
        
    .EXAMPLE
        Set-DNSSinkhole -Operation Delete -DNSServerName "dns.domain.com" -Credential $Creds
        
    .EXAMPLE
        Set-DNSSinkhole -ThreatCategories @("Malware", "Phishing", "C2") -SinkholeIP "0.0.0.0"
    #>
    
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(ParameterSetName = 'DomainList')]
        [string[]]$DomainList,
        
        [Parameter(ParameterSetName = 'InputFile')]
        [string]$InputFile,
        
        [Parameter()]
        [ValidatePattern('^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$')]
        [string]$SinkholeIP = '0.0.0.0',
        
        [Parameter()]
        [string]$DNSServerName = 'localhost',
        
        [Parameter()]
        [switch]$IncludeWildcard,
        
        [Parameter()]
        [switch]$RemoveWWW,
        
        [Parameter()]
        [ValidateSet('Create', 'Delete', 'Reload', 'Status')]
        [string]$Operation = 'Create',
        
        [Parameter()]
        [pscredential]$Credential,
        
        [Parameter()]
        [ValidatePattern('^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$')]
        [string]$LoggingIP,
        
        [Parameter()]
        [ValidateSet('Malware', 'Phishing', 'C2', 'Adware', 'Suspicious')]
        [string[]]$ThreatCategories,
        
        [Parameter()]
        [switch]$TestMode
    )
    
    begin {
        Write-CustomLog -Level 'INFO' -Message "Configuring DNS sinkhole operation: $Operation"
        
        # Check if running as Administrator
        $CurrentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
        $Principal = New-Object Security.Principal.WindowsPrincipal($CurrentUser)
        if (-not $Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            throw "This function requires Administrator privileges"
        }
        
        # Master sinkhole zone name
        $MasterSinkholeZone = '000-sinkholed-domain.local'
        $MasterZoneFile = "$MasterSinkholeZone.dns"
        
        # Results tracking
        $SinkholeResults = @{
            Operation = $Operation
            DNSServerName = $DNSServerName
            SinkholeIP = $SinkholeIP
            DomainsProcessed = 0
            DomainsCreated = 0
            DomainsFailed = 0
            MasterZoneExists = $false
            Recommendations = @()
        }
        
        # Predefined threat intelligence domains (examples - replace with real feeds)
        $ThreatIntelDomains = @{
            'Malware' = @('malware-test.com', 'virus-test.net', 'trojan-test.org')
            'Phishing' = @('phishing-test.com', 'fake-bank.net', 'scam-test.org')
            'C2' = @('c2-test.com', 'command-control.net', 'botnet-test.org')
            'Adware' = @('ads-test.com', 'popup-test.net', 'tracking-test.org')
            'Suspicious' = @('suspicious-test.com', 'unknown-test.net', 'risky-test.org')
        }
    }
    
    process {
        try {
            # Test DNS WMI connectivity
            Write-CustomLog -Level 'INFO' -Message "Testing DNS WMI connectivity to: $DNSServerName"
            
            try {
                $WMIParams = @{
                    Namespace = 'Root/MicrosoftDNS'
                    ComputerName = $DNSServerName
                    ErrorAction = 'Stop'
                }
                
                if ($Credential) {
                    $WMIParams['Credential'] = $Credential
                }
                
                $ZoneClass = Get-WmiObject -Query "SELECT * FROM META_CLASS WHERE __CLASS = 'MicrosoftDNS_Zone'" @WMIParams
                
                if (-not $ZoneClass -or $ZoneClass.Name -ne 'MicrosoftDNS_Zone') {
                    throw "Failed to connect to DNS WMI namespace"
                }
                
                Write-CustomLog -Level 'SUCCESS' -Message "DNS WMI connectivity established"
                
            } catch {
                Write-CustomLog -Level 'ERROR' -Message "DNS WMI connection failed: $($_.Exception.Message)"
                throw
            }
            
            # Handle different operations
            switch ($Operation) {
                'Status' {
                    Write-CustomLog -Level 'INFO' -Message "Checking sinkhole status"
                    
                    try {
                        $SinkholedZones = Get-WmiObject -Query "SELECT * FROM MicrosoftDNS_Zone WHERE DataFile = '$MasterZoneFile'" @WMIParams
                        $SinkholeResults.DomainsProcessed = $SinkholedZones.Count
                        
                        Write-CustomLog -Level 'INFO' -Message "Found $($SinkholedZones.Count) sinkholed domains"
                        
                        if ($SinkholedZones.Count -gt 0) {
                            Write-CustomLog -Level 'INFO' -Message "Sample sinkholed domains:"
                            $SinkholedZones | Select-Object -First 10 | ForEach-Object {
                                Write-CustomLog -Level 'INFO' -Message "  - $($_.ContainerName)"
                            }
                        }
                        
                        return $SinkholeResults
                        
                    } catch {
                        Write-CustomLog -Level 'ERROR' -Message "Failed to check sinkhole status: $($_.Exception.Message)"
                        throw
                    }
                }
                
                'Delete' {
                    Write-CustomLog -Level 'INFO' -Message "Deleting all sinkholed domains"
                    
                    if ($TestMode) {
                        Write-CustomLog -Level 'INFO' -Message "[TEST MODE] Would delete all sinkholed domains"
                        return $SinkholeResults
                    }
                    
                    if ($PSCmdlet.ShouldProcess("All Sinkholed Domains", "Delete")) {
                        try {
                            $SinkholedZones = Get-WmiObject -Query "SELECT * FROM MicrosoftDNS_Zone WHERE DataFile = '$MasterZoneFile'" @WMIParams
                            
                            $DeleteCount = 0
                            foreach ($Zone in $SinkholedZones) {
                                try {
                                    $Zone.Delete()
                                    $DeleteCount++
                                } catch {
                                    Write-CustomLog -Level 'WARNING' -Message "Failed to delete zone: $($Zone.ContainerName)"
                                    $SinkholeResults.DomainsFailed++
                                }
                            }
                            
                            $SinkholeResults.DomainsProcessed = $DeleteCount
                            Write-CustomLog -Level 'SUCCESS' -Message "Deleted $DeleteCount sinkholed domains"
                            
                        } catch {
                            Write-CustomLog -Level 'ERROR' -Message "Failed to delete sinkholed domains: $($_.Exception.Message)"
                            throw
                        }
                    }
                    
                    return $SinkholeResults
                }
                
                'Reload' {
                    Write-CustomLog -Level 'INFO' -Message "Reloading sinkholed domains from zone file"
                    
                    if ($TestMode) {
                        Write-CustomLog -Level 'INFO' -Message "[TEST MODE] Would reload all sinkholed domains"
                        return $SinkholeResults
                    }
                    
                    if ($PSCmdlet.ShouldProcess("Sinkholed Domains", "Reload from zone file")) {
                        try {
                            $SinkholedZones = Get-WmiObject -Query "SELECT * FROM MicrosoftDNS_Zone WHERE DataFile = '$MasterZoneFile'" @WMIParams
                            
                            $ReloadCount = 0
                            $LockedZones = @()
                            
                            foreach ($Zone in $SinkholedZones) {
                                try {
                                    $Zone.ReloadZone()
                                    $ReloadCount++
                                } catch {
                                    $LockedZones += $Zone.ContainerName
                                }
                            }
                            
                            if ($LockedZones.Count -gt 0) {
                                Write-CustomLog -Level 'WARNING' -Message "$($LockedZones.Count) zones are temporarily locked, retrying in 30 seconds"
                                Start-Sleep -Seconds 30
                                
                                foreach ($ZoneName in $LockedZones) {
                                    try {
                                        $Zone = Get-WmiObject -Query "SELECT * FROM MicrosoftDNS_Zone WHERE ContainerName = '$ZoneName'" @WMIParams
                                        $Zone.ReloadZone()
                                        $ReloadCount++
                                    } catch {
                                        Write-CustomLog -Level 'WARNING' -Message "Zone still locked: $ZoneName"
                                        $SinkholeResults.DomainsFailed++
                                    }
                                }
                            }
                            
                            $SinkholeResults.DomainsProcessed = $ReloadCount
                            Write-CustomLog -Level 'SUCCESS' -Message "Reloaded $ReloadCount sinkholed domains"
                            
                        } catch {
                            Write-CustomLog -Level 'ERROR' -Message "Failed to reload sinkholed domains: $($_.Exception.Message)"
                            throw
                        }
                    }
                    
                    return $SinkholeResults
                }
                
                'Create' {
                    # Build domain list from various sources
                    $DomainsToSinkhole = @()
                    
                    # Add domains from DomainList parameter
                    if ($DomainList) {
                        $DomainsToSinkhole += $DomainList
                    }
                    
                    # Add domains from InputFile
                    if ($InputFile) {
                        if (Test-Path $InputFile) {
                            Write-CustomLog -Level 'INFO' -Message "Loading domains from file: $InputFile"
                            
                            $FileContent = Get-Content $InputFile | Where-Object {
                                $_.Trim() -and 
                                -not $_.Trim().StartsWith('#') -and 
                                -not $_.Trim().StartsWith(';') -and
                                $_ -notmatch '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}' -and
                                $_ -notmatch 'localhost'
                            }
                            
                            $DomainsToSinkhole += $FileContent | ForEach-Object {
                                ($_ -split '[\s\,\;]') | Where-Object { $_.Trim() }
                            }
                        } else {
                            throw "Input file not found: $InputFile"
                        }
                    }
                    
                    # Add domains from threat categories
                    if ($ThreatCategories) {
                        Write-CustomLog -Level 'INFO' -Message "Adding domains from threat categories: $($ThreatCategories -join ', ')"
                        
                        foreach ($Category in $ThreatCategories) {
                            if ($ThreatIntelDomains.ContainsKey($Category)) {
                                $DomainsToSinkhole += $ThreatIntelDomains[$Category]
                                Write-CustomLog -Level 'INFO' -Message "Added $($ThreatIntelDomains[$Category].Count) domains from $Category category"
                            }
                        }
                    }
                    
                    if ($DomainsToSinkhole.Count -eq 0) {
                        throw "No domains specified for sinkholing"
                    }
                    
                    # Process domain list
                    Write-CustomLog -Level 'INFO' -Message "Processing $($DomainsToSinkhole.Count) domains for sinkholing"
                    
                    # Remove WWW prefixes if requested
                    if ($RemoveWWW) {
                        $DomainsToSinkhole = $DomainsToSinkhole | ForEach-Object {
                            $_ -replace '^www[0-9]?\.', ''
                        }
                    }
                    
                    # Clean and deduplicate domain list
                    $CleanDomains = $DomainsToSinkhole | ForEach-Object { 
                        $_.Trim().ToLower() 
                    } | Where-Object {
                        $_ -and $_ -notmatch '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$' -and $_ -ne 'localhost'
                    } | Sort-Object -Unique
                    
                    Write-CustomLog -Level 'INFO' -Message "Cleaned domain list: $($CleanDomains.Count) unique domains"
                    $SinkholeResults.DomainsProcessed = $CleanDomains.Count
                    
                    if ($TestMode) {
                        Write-CustomLog -Level 'INFO' -Message "[TEST MODE] Would sinkhole $($CleanDomains.Count) domains to $SinkholeIP"
                        Write-CustomLog -Level 'INFO' -Message "Sample domains: $($CleanDomains | Select-Object -First 5 | ForEach-Object { $_ })"
                        return $SinkholeResults
                    }
                    
                    # Create or verify master sinkhole zone
                    Write-CustomLog -Level 'INFO' -Message "Setting up master sinkhole zone: $MasterSinkholeZone"
                    
                    if ($PSCmdlet.ShouldProcess($MasterSinkholeZone, "Create/Update master sinkhole zone")) {
                        try {
                            $MasterZonePath = "Root\MicrosoftDNS:MicrosoftDNS_Zone.ContainerName='$MasterSinkholeZone',DnsServerName='$DNSServerName',Name='$MasterSinkholeZone'"
                            
                            # Check if master zone exists
                            try {
                                $MasterZone = Get-WmiObject -Path $MasterZonePath @WMIParams
                                $SinkholeResults.MasterZoneExists = $true
                                Write-CustomLog -Level 'INFO' -Message "Master sinkhole zone already exists"
                                
                                # Clear existing records
                                $ExistingRecords = Get-WmiObject -Query "SELECT * FROM MicrosoftDNS_AType WHERE ContainerName = '$MasterSinkholeZone'" @WMIParams
                                foreach ($Record in $ExistingRecords) {
                                    $Record.Delete()
                                }
                                
                            } catch {
                                # Create master zone
                                Write-CustomLog -Level 'INFO' -Message "Creating master sinkhole zone"
                                $ZoneClass.CreateZone($MasterSinkholeZone, 0, $false, $null, $null, "sinkhole-admin.$MasterSinkholeZone.")
                                $SinkholeResults.MasterZoneExists = $true
                            }
                            
                            # Create DNS records in master zone
                            $ATypeClass = Get-WmiObject -Query "SELECT * FROM META_CLASS WHERE __CLASS = 'MicrosoftDNS_AType'" @WMIParams
                            $TTL = 120
                            
                            # Use logging IP if specified, otherwise use sinkhole IP
                            $RecordIP = if ($LoggingIP) { $LoggingIP } else { $SinkholeIP }
                            
                            # Create default A record
                            $ATypeClass.CreateInstanceFromPropertyData($DNSServerName, $MasterSinkholeZone, $MasterSinkholeZone, $null, $TTL, $RecordIP)
                            Write-CustomLog -Level 'SUCCESS' -Message "Created default A record: $MasterSinkholeZone -> $RecordIP"
                            
                            # Create wildcard record if requested
                            if ($IncludeWildcard) {
                                $ATypeClass.CreateInstanceFromPropertyData($DNSServerName, $MasterSinkholeZone, "*.$MasterSinkholeZone", $null, $TTL, $RecordIP)
                                Write-CustomLog -Level 'SUCCESS' -Message "Created wildcard A record: *.$MasterSinkholeZone -> $RecordIP"
                            }
                            
                            # Update zone file
                            $MasterZone = Get-WmiObject -Path $MasterZonePath @WMIParams
                            $MasterZone.WriteBackZone()
                            
                        } catch {
                            Write-CustomLog -Level 'ERROR' -Message "Failed to setup master sinkhole zone: $($_.Exception.Message)"
                            throw
                        }
                    }
                    
                    # Create sinkholed domains
                    Write-CustomLog -Level 'INFO' -Message "Creating sinkholed domains using shared zone file"
                    
                    if ($PSCmdlet.ShouldProcess("$($CleanDomains.Count) domains", "Create sinkhole zones")) {
                        $CreatedCount = 0
                        $FailedCount = 0
                        
                        foreach ($Domain in $CleanDomains) {
                            try {
                                $ZoneClass.CreateZone($Domain, 0, $false, $MasterZoneFile, $null, "sinkhole-admin.$MasterSinkholeZone.") | Out-Null
                                $CreatedCount++
                                
                                if ($CreatedCount % 100 -eq 0) {
                                    Write-CustomLog -Level 'INFO' -Message "Created $CreatedCount sinkhole zones..."
                                }
                                
                            } catch {
                                $FailedCount++
                                if ($FailedCount -le 10) {  # Only log first 10 failures to avoid spam
                                    Write-CustomLog -Level 'WARNING' -Message "Failed to create zone for domain: $Domain"
                                }
                            }
                        }
                        
                        $SinkholeResults.DomainsCreated = $CreatedCount
                        $SinkholeResults.DomainsFailed = $FailedCount
                        
                        Write-CustomLog -Level 'SUCCESS' -Message "Sinkhole creation completed: $CreatedCount created, $FailedCount failed"
                    }
                }
            }
            
        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Error during DNS sinkhole operation: $($_.Exception.Message)"
            throw
        }
    }
    
    end {
        Write-CustomLog -Level 'SUCCESS' -Message "DNS sinkhole operation completed: $Operation"
        
        # Generate recommendations
        $SinkholeResults.Recommendations += "Monitor DNS query logs for sinkholed domain requests"
        $SinkholeResults.Recommendations += "Regularly update threat intelligence domain lists"
        $SinkholeResults.Recommendations += "Configure alerting for high-volume sinkhole hits"
        $SinkholeResults.Recommendations += "Test sinkhole functionality with known bad domains"
        $SinkholeResults.Recommendations += "Document sinkhole configuration for incident response"
        
        if ($LoggingIP) {
            $SinkholeResults.Recommendations += "Configure logging server at $LoggingIP to capture sinkholed traffic"
            $SinkholeResults.Recommendations += "Implement traffic analysis for sinkholed requests"
        }
        
        if ($SinkholeResults.DomainsCreated -gt 0) {
            $SinkholeResults.Recommendations += "Verify sinkhole resolution with nslookup tests"
            $SinkholeResults.Recommendations += "Consider implementing DNS over HTTPS blocking"
        }
        
        # Display summary
        Write-CustomLog -Level 'INFO' -Message "Sinkhole Summary:"
        Write-CustomLog -Level 'INFO' -Message "  Operation: $($SinkholeResults.Operation)"
        Write-CustomLog -Level 'INFO' -Message "  DNS Server: $($SinkholeResults.DNSServerName)"
        Write-CustomLog -Level 'INFO' -Message "  Sinkhole IP: $($SinkholeResults.SinkholeIP)"
        Write-CustomLog -Level 'INFO' -Message "  Domains Processed: $($SinkholeResults.DomainsProcessed)"
        Write-CustomLog -Level 'INFO' -Message "  Domains Created: $($SinkholeResults.DomainsCreated)"
        
        if ($SinkholeResults.DomainsFailed -gt 0) {
            Write-CustomLog -Level 'WARNING' -Message "  Domains Failed: $($SinkholeResults.DomainsFailed)"
        }
        
        # Display recommendations
        foreach ($Recommendation in $SinkholeResults.Recommendations) {
            Write-CustomLog -Level 'INFO' -Message "Recommendation: $Recommendation"
        }
        
        return $SinkholeResults
    }
}
function Set-IPSecConfiguration {
    <#
    .SYNOPSIS
        Configures IPSec policies for secure network communication and zero-trust networking.
        
    .DESCRIPTION
        Implements comprehensive IPSec configuration including connection security rules,
        authentication policies, encryption settings, and zero-trust network requirements.
        Supports certificate-based authentication, Kerberos, and PSK methods.
        
    .PARAMETER PolicyProfile
        Predefined IPSec policy profile to apply
        
    .PARAMETER ComputerName
        Target computers for IPSec configuration. Default: localhost
        
    .PARAMETER Credential
        Credentials for remote computer access
        
    .PARAMETER SecureNetworks
        Array of network ranges requiring IPSec protection
        
    .PARAMETER TrustedNetworks
        Array of trusted network ranges for different authentication
        
    .PARAMETER AuthenticationMethod
        IPSec authentication method to use
        
    .PARAMETER EncryptionProtocol
        Encryption protocol for IPSec tunnels
        
    .PARAMETER IntegrityAlgorithm
        Data integrity algorithm for IPSec
        
    .PARAMETER KeyExchangeAlgorithm
        Key exchange algorithm for IPSec negotiation
        
    .PARAMETER CertificateThumbprint
        Certificate thumbprint for certificate-based authentication
        
    .PARAMETER PSKValue
        Pre-shared key value for PSK authentication
        
    .PARAMETER KerberosRealm
        Kerberos realm for Kerberos authentication
        
    .PARAMETER RequireAuthentication
        Require IPSec authentication for all specified traffic
        
    .PARAMETER RequireEncryption
        Require IPSec encryption for all specified traffic
        
    .PARAMETER EnablePFS
        Enable Perfect Forward Secrecy
        
    .PARAMETER SALifetime
        Security Association lifetime in seconds
        
    .PARAMETER MainModeLifetime
        Main mode security association lifetime in seconds
        
    .PARAMETER QuickModeLifetime
        Quick mode security association lifetime in seconds
        
    .PARAMETER EnableDeadPeerDetection
        Enable dead peer detection for IPSec tunnels
        
    .PARAMETER LogIPSecEvents
        Enable IPSec event logging
        
    .PARAMETER EnableTrafficBypass
        Allow specific traffic to bypass IPSec
        
    .PARAMETER BypassNetworks
        Networks allowed to bypass IPSec requirements
        
    .PARAMETER TestMode
        Show what would be configured without making changes
        
    .PARAMETER BackupExistingPolicies
        Create backup of existing IPSec policies
        
    .PARAMETER ReportPath
        Path to save IPSec configuration report
        
    .EXAMPLE
        Set-IPSecConfiguration -PolicyProfile 'Enterprise' -AuthenticationMethod 'Certificate'
        
    .EXAMPLE
        Set-IPSecConfiguration -SecureNetworks @('10.1.0.0/16','10.2.0.0/16') -RequireAuthentication -RequireEncryption
        
    .EXAMPLE
        Set-IPSecConfiguration -PolicyProfile 'ZeroTrust' -CertificateThumbprint '1234567890ABCDEF' -EnablePFS
    #>
    
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter()]
        [ValidateSet('Basic', 'Enterprise', 'ZeroTrust', 'HighSecurity', 'Custom')]
        [string]$PolicyProfile = 'Enterprise',
        
        [Parameter()]
        [string[]]$ComputerName = @('localhost'),
        
        [Parameter()]
        [pscredential]$Credential,
        
        [Parameter()]
        [string[]]$SecureNetworks = @(),
        
        [Parameter()]
        [string[]]$TrustedNetworks = @(),
        
        [Parameter()]
        [ValidateSet('Certificate', 'Kerberos', 'PSK', 'NTLMv2', 'Anonymous')]
        [string]$AuthenticationMethod = 'Certificate',
        
        [Parameter()]
        [ValidateSet('AES256', 'AES192', 'AES128', '3DES', 'DES')]
        [string]$EncryptionProtocol = 'AES256',
        
        [Parameter()]
        [ValidateSet('SHA256', 'SHA1', 'MD5')]
        [string]$IntegrityAlgorithm = 'SHA256',
        
        [Parameter()]
        [ValidateSet('DHGroup14', 'DHGroup2', 'DHGroup1', 'ECDH256', 'ECDH384')]
        [string]$KeyExchangeAlgorithm = 'DHGroup14',
        
        [Parameter()]
        [string]$CertificateThumbprint,
        
        [Parameter()]
        [string]$PSKValue,
        
        [Parameter()]
        [string]$KerberosRealm,
        
        [Parameter()]
        [switch]$RequireAuthentication,
        
        [Parameter()]
        [switch]$RequireEncryption,
        
        [Parameter()]
        [switch]$EnablePFS,
        
        [Parameter()]
        [ValidateRange(300, 86400)]
        [int]$SALifetime = 3600,
        
        [Parameter()]
        [ValidateRange(300, 86400)]
        [int]$MainModeLifetime = 28800,
        
        [Parameter()]
        [ValidateRange(300, 3600)]
        [int]$QuickModeLifetime = 3600,
        
        [Parameter()]
        [switch]$EnableDeadPeerDetection,
        
        [Parameter()]
        [switch]$LogIPSecEvents,
        
        [Parameter()]
        [switch]$EnableTrafficBypass,
        
        [Parameter()]
        [string[]]$BypassNetworks = @(),
        
        [Parameter()]
        [switch]$TestMode,
        
        [Parameter()]
        [switch]$BackupExistingPolicies,
        
        [Parameter()]
        [string]$ReportPath
    )
    
    begin {
        Write-CustomLog -Level 'INFO' -Message "Configuring IPSec policies: $PolicyProfile"
        
        # Check if running as Administrator
        $CurrentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
        $Principal = New-Object Security.Principal.WindowsPrincipal($CurrentUser)
        if (-not $Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            throw "This function requires Administrator privileges"
        }
        
        # Define IPSec policy profiles
        $IPSecProfiles = @{
            'Basic' = @{
                Description = 'Basic IPSec configuration for internal networks'
                DefaultSecureNetworks = @('10.0.0.0/8', '172.16.0.0/12', '192.168.0.0/16')
                AuthenticationMethod = 'Kerberos'
                EncryptionProtocol = 'AES128'
                IntegrityAlgorithm = 'SHA1'
                RequireAuthentication = $true
                RequireEncryption = $false
                EnablePFS = $false
                SALifetime = 7200
            }
            'Enterprise' = @{
                Description = 'Enterprise IPSec configuration with strong security'
                DefaultSecureNetworks = @('10.0.0.0/8', '172.16.0.0/12')
                AuthenticationMethod = 'Certificate'
                EncryptionProtocol = 'AES256'
                IntegrityAlgorithm = 'SHA256'
                RequireAuthentication = $true
                RequireEncryption = $true
                EnablePFS = $true
                SALifetime = 3600
            }
            'ZeroTrust' = @{
                Description = 'Zero-trust IPSec configuration with maximum security'
                DefaultSecureNetworks = @('0.0.0.0/0')  # All traffic
                AuthenticationMethod = 'Certificate'
                EncryptionProtocol = 'AES256'
                IntegrityAlgorithm = 'SHA256'
                RequireAuthentication = $true
                RequireEncryption = $true
                EnablePFS = $true
                SALifetime = 1800
            }
            'HighSecurity' = @{
                Description = 'High security IPSec for sensitive environments'
                DefaultSecureNetworks = @('10.0.0.0/8', '172.16.0.0/12', '192.168.0.0/16')
                AuthenticationMethod = 'Certificate'
                EncryptionProtocol = 'AES256'
                IntegrityAlgorithm = 'SHA256'
                RequireAuthentication = $true
                RequireEncryption = $true
                EnablePFS = $true
                SALifetime = 1800
            }
        }
        
        $IPSecResults = @{
            PolicyProfile = $PolicyProfile
            ComputersProcessed = @()
            PoliciesCreated = 0
            RulesCreated = 0
            ConnectionSecurityRules = 0
            AuthenticationPolicies = 0
            CryptoSetsCreated = 0
            BackupCreated = $false
            Errors = @()
            Recommendations = @()
        }
    }
    
    process {
        try {
            foreach ($Computer in $ComputerName) {
                Write-CustomLog -Level 'INFO' -Message "Configuring IPSec on: $Computer"
                
                $ComputerResult = @{
                    ComputerName = $Computer
                    Timestamp = Get-Date
                    PolicyProfile = $PolicyProfile
                    PoliciesCreated = 0
                    RulesCreated = 0
                    ConnectionRules = 0
                    AuthPolicies = 0
                    CryptoSets = 0
                    Errors = @()
                }
                
                try {
                    # Session parameters for remote access
                    $SessionParams = @{
                        ErrorAction = 'Stop'
                    }
                    
                    if ($Computer -ne 'localhost') {
                        $SessionParams['ComputerName'] = $Computer
                        if ($Credential) {
                            $SessionParams['Credential'] = $Credential
                        }
                    }
                    
                    # Get profile configuration
                    $ProfileConfig = if ($PolicyProfile -ne 'Custom') {
                        $IPSecProfiles[$PolicyProfile]
                    } else {
                        @{
                            Description = 'Custom IPSec configuration'
                            DefaultSecureNetworks = $SecureNetworks
                            AuthenticationMethod = $AuthenticationMethod
                            EncryptionProtocol = $EncryptionProtocol
                            IntegrityAlgorithm = $IntegrityAlgorithm
                            RequireAuthentication = $RequireAuthentication.IsPresent
                            RequireEncryption = $RequireEncryption.IsPresent
                            EnablePFS = $EnablePFS.IsPresent
                            SALifetime = $SALifetime
                        }
                    }
                    
                    # Merge provided networks with profile defaults
                    $ActiveSecureNetworks = if ($SecureNetworks.Count -gt 0) {
                        $SecureNetworks
                    } else {
                        $ProfileConfig.DefaultSecureNetworks
                    }
                    
                    # Backup existing policies if requested
                    if ($BackupExistingPolicies) {
                        Write-CustomLog -Level 'INFO' -Message "Backing up existing IPSec policies"
                        
                        try {
                            $BackupData = if ($Computer -ne 'localhost') {
                                Invoke-Command @SessionParams -ScriptBlock {
                                    @{
                                        NetIPsecMainModeCryptoSets = Get-NetIPsecMainModeCryptoSet
                                        NetIPsecQuickModeCryptoSets = Get-NetIPsecQuickModeCryptoSet
                                        NetIPsecPhase1AuthSets = Get-NetIPsecPhase1AuthSet
                                        NetIPsecPhase2AuthSets = Get-NetIPsecPhase2AuthSet
                                        NetIPsecRules = Get-NetIPsecRule
                                        Timestamp = Get-Date
                                    }
                                }
                            } else {
                                @{
                                    NetIPsecMainModeCryptoSets = Get-NetIPsecMainModeCryptoSet
                                    NetIPsecQuickModeCryptoSets = Get-NetIPsecQuickModeCryptoSet
                                    NetIPsecPhase1AuthSets = Get-NetIPsecPhase1AuthSet
                                    NetIPsecPhase2AuthSets = Get-NetIPsecPhase2AuthSet
                                    NetIPsecRules = Get-NetIPsecRule
                                    Timestamp = Get-Date
                                }
                            }
                            
                            $BackupFile = "ipsec-backup-$Computer-$(Get-Date -Format 'yyyyMMdd-HHmmss').xml"
                            $BackupData | Export-Clixml -Path $BackupFile -Force
                            Write-CustomLog -Level 'SUCCESS' -Message "IPSec backup saved to: $BackupFile"
                            $IPSecResults.BackupCreated = $true
                            
                        } catch {
                            Write-CustomLog -Level 'WARNING' -Message "Failed to create IPSec backup: $($_.Exception.Message)"
                        }
                    }
                    
                    # Configure IPSec policies
                    $PolicyResult = if ($Computer -ne 'localhost') {
                        Invoke-Command @SessionParams -ScriptBlock {
                            param($ProfileConfig, $ActiveSecureNetworks, $TrustedNetworks, $AuthenticationMethod, $EncryptionProtocol, $IntegrityAlgorithm, $KeyExchangeAlgorithm, $CertificateThumbprint, $PSKValue, $KerberosRealm, $EnablePFS, $SALifetime, $MainModeLifetime, $QuickModeLifetime, $EnableDeadPeerDetection, $LogIPSecEvents, $EnableTrafficBypass, $BypassNetworks, $TestMode)
                            
                            $Results = @{
                                PoliciesCreated = 0
                                RulesCreated = 0
                                ConnectionRules = 0
                                AuthPolicies = 0
                                CryptoSets = 0
                                Errors = @()
                            }
                            
                            try {
                                # Remove existing SecurityAutomation IPSec rules
                                Get-NetIPsecRule | Where-Object { 
                                    $_.DisplayName -like "SecAuto-IPSec-*" 
                                } | Remove-NetIPsecRule -ErrorAction SilentlyContinue
                                
                                # Create main mode crypto set
                                if (-not $TestMode) {
                                    $MainModeCryptoParams = @{
                                        DisplayName = "SecAuto-IPSec-MainMode-$($ProfileConfig.AuthenticationMethod)"
                                        Proposal = New-NetIPsecMainModeCryptoProposal -Encryption $EncryptionProtocol -Hash $IntegrityAlgorithm -KeyExchange $KeyExchangeAlgorithm
                                        MaxMinutes = $MainModeLifetime / 60
                                        MaxSessions = 2048
                                    }
                                    
                                    New-NetIPsecMainModeCryptoSet @MainModeCryptoParams | Out-Null
                                    $Results.CryptoSets++
                                }
                                
                                # Create quick mode crypto set
                                if (-not $TestMode) {
                                    $QuickModeCryptoParams = @{
                                        DisplayName = "SecAuto-IPSec-QuickMode-$($ProfileConfig.AuthenticationMethod)"
                                        Proposal = New-NetIPsecQuickModeCryptoProposal -Encryption $EncryptionProtocol -Hash $IntegrityAlgorithm -ESPHash $IntegrityAlgorithm
                                        MaxMinutes = $QuickModeLifetime / 60
                                        MaxKiloBytes = 102400
                                    }
                                    
                                    if ($EnablePFS) {
                                        $QuickModeCryptoParams.Proposal.PfsGroup = $KeyExchangeAlgorithm
                                    }
                                    
                                    New-NetIPsecQuickModeCryptoSet @QuickModeCryptoParams | Out-Null
                                    $Results.CryptoSets++
                                }
                                
                                # Create Phase 1 authentication set
                                if (-not $TestMode) {
                                    $Phase1AuthParams = @{
                                        DisplayName = "SecAuto-IPSec-Phase1Auth-$AuthenticationMethod"
                                    }
                                    
                                    switch ($AuthenticationMethod) {
                                        'Certificate' {
                                            if ($CertificateThumbprint) {
                                                $Phase1AuthParams.Proposal = New-NetIPsecAuthProposal -Certificate -Cert $CertificateThumbprint
                                            } else {
                                                $Phase1AuthParams.Proposal = New-NetIPsecAuthProposal -Certificate
                                            }
                                        }
                                        'Kerberos' {
                                            if ($KerberosRealm) {
                                                $Phase1AuthParams.Proposal = New-NetIPsecAuthProposal -Kerberos -Realm $KerberosRealm
                                            } else {
                                                $Phase1AuthParams.Proposal = New-NetIPsecAuthProposal -Kerberos
                                            }
                                        }
                                        'PSK' {
                                            if ($PSKValue) {
                                                $Phase1AuthParams.Proposal = New-NetIPsecAuthProposal -PreSharedKey $PSKValue
                                            } else {
                                                # Use a default PSK for testing (not recommended for production)
                                                $Phase1AuthParams.Proposal = New-NetIPsecAuthProposal -PreSharedKey "DefaultPSK123!"
                                            }
                                        }
                                        'NTLMv2' {
                                            $Phase1AuthParams.Proposal = New-NetIPsecAuthProposal -UserNTLM
                                        }
                                        'Anonymous' {
                                            $Phase1AuthParams.Proposal = New-NetIPsecAuthProposal -Anonymous
                                        }
                                    }
                                    
                                    New-NetIPsecPhase1AuthSet @Phase1AuthParams | Out-Null
                                    $Results.AuthPolicies++
                                }
                                
                                # Create connection security rules for secure networks
                                foreach ($Network in $ActiveSecureNetworks) {
                                    $RuleName = "SecAuto-IPSec-Secure-$($Network.Replace('/', '-').Replace('.', '-'))"
                                    
                                    if (-not $TestMode) {
                                        $ConnectionRuleParams = @{
                                            DisplayName = $RuleName
                                            RemoteAddress = $Network
                                            InboundSecurity = if ($ProfileConfig.RequireAuthentication) { 'Require' } else { 'Request' }
                                            OutboundSecurity = if ($ProfileConfig.RequireAuthentication) { 'Require' } else { 'Request' }
                                            Phase1AuthSet = "SecAuto-IPSec-Phase1Auth-$AuthenticationMethod"
                                            MainModeCryptoSet = "SecAuto-IPSec-MainMode-$($ProfileConfig.AuthenticationMethod)"
                                            QuickModeCryptoSet = "SecAuto-IPSec-QuickMode-$($ProfileConfig.AuthenticationMethod)"
                                            Description = "SecurityAutomation IPSec rule for network: $Network"
                                        }
                                        
                                        if ($ProfileConfig.RequireEncryption) {
                                            $ConnectionRuleParams.InboundSecurity = 'Require'
                                            $ConnectionRuleParams.OutboundSecurity = 'Require'
                                        }
                                        
                                        New-NetIPsecRule @ConnectionRuleParams | Out-Null
                                        $Results.ConnectionRules++
                                    }
                                    
                                    $Results.RulesCreated++
                                }
                                
                                # Create bypass rules if specified
                                if ($EnableTrafficBypass -and $BypassNetworks.Count -gt 0) {
                                    foreach ($BypassNetwork in $BypassNetworks) {
                                        $BypassRuleName = "SecAuto-IPSec-Bypass-$($BypassNetwork.Replace('/', '-').Replace('.', '-'))"
                                        
                                        if (-not $TestMode) {
                                            $BypassRuleParams = @{
                                                DisplayName = $BypassRuleName
                                                RemoteAddress = $BypassNetwork
                                                InboundSecurity = 'None'
                                                OutboundSecurity = 'None'
                                                Description = "SecurityAutomation IPSec bypass rule for network: $BypassNetwork"
                                            }
                                            
                                            New-NetIPsecRule @BypassRuleParams | Out-Null
                                        }
                                        
                                        $Results.RulesCreated++
                                    }
                                }
                                
                                # Enable IPSec logging if requested
                                if ($LogIPSecEvents) {
                                    if (-not $TestMode) {
                                        # Enable IPSec operational log
                                        wevtutil sl Microsoft-Windows-IPsec/Operational /e:true /q:true
                                        wevtutil sl Microsoft-Windows-IPsec/Diagnostic /e:true /q:true
                                    }
                                }
                                
                                $Results.PoliciesCreated = $Results.CryptoSets + $Results.AuthPolicies
                                
                            } catch {
                                $Results.Errors += "Failed to configure IPSec policies: $($_.Exception.Message)"
                            }
                            
                            return $Results
                        } -ArgumentList $ProfileConfig, $ActiveSecureNetworks, $TrustedNetworks, $AuthenticationMethod, $EncryptionProtocol, $IntegrityAlgorithm, $KeyExchangeAlgorithm, $CertificateThumbprint, $PSKValue, $KerberosRealm, $EnablePFS, $SALifetime, $MainModeLifetime, $QuickModeLifetime, $EnableDeadPeerDetection, $LogIPSecEvents, $EnableTrafficBypass, $BypassNetworks, $TestMode
                    } else {
                        $Results = @{
                            PoliciesCreated = 0
                            RulesCreated = 0
                            ConnectionRules = 0
                            AuthPolicies = 0
                            CryptoSets = 0
                            Errors = @()
                        }
                        
                        try {
                            # Remove existing SecurityAutomation IPSec rules
                            Get-NetIPsecRule | Where-Object { 
                                $_.DisplayName -like "SecAuto-IPSec-*" 
                            } | Remove-NetIPsecRule -ErrorAction SilentlyContinue
                            
                            # Create main mode crypto set
                            if (-not $TestMode) {
                                if ($PSCmdlet.ShouldProcess("Main Mode Crypto Set", "Create IPSec crypto configuration")) {
                                    $MainModeCryptoParams = @{
                                        DisplayName = "SecAuto-IPSec-MainMode-$($ProfileConfig.AuthenticationMethod)"
                                        Proposal = New-NetIPsecMainModeCryptoProposal -Encryption $EncryptionProtocol -Hash $IntegrityAlgorithm -KeyExchange $KeyExchangeAlgorithm
                                        MaxMinutes = $MainModeLifetime / 60
                                        MaxSessions = 2048
                                    }
                                    
                                    New-NetIPsecMainModeCryptoSet @MainModeCryptoParams | Out-Null
                                    $Results.CryptoSets++
                                }
                            } else {
                                Write-CustomLog -Level 'INFO' -Message "[TEST] Would create main mode crypto set"
                            }
                            
                            # Create quick mode crypto set
                            if (-not $TestMode) {
                                if ($PSCmdlet.ShouldProcess("Quick Mode Crypto Set", "Create IPSec quick mode configuration")) {
                                    $QuickModeCryptoParams = @{
                                        DisplayName = "SecAuto-IPSec-QuickMode-$($ProfileConfig.AuthenticationMethod)"
                                        Proposal = New-NetIPsecQuickModeCryptoProposal -Encryption $EncryptionProtocol -Hash $IntegrityAlgorithm -ESPHash $IntegrityAlgorithm
                                        MaxMinutes = $QuickModeLifetime / 60
                                        MaxKiloBytes = 102400
                                    }
                                    
                                    if ($EnablePFS) {
                                        $QuickModeCryptoParams.Proposal.PfsGroup = $KeyExchangeAlgorithm
                                    }
                                    
                                    New-NetIPsecQuickModeCryptoSet @QuickModeCryptoParams | Out-Null
                                    $Results.CryptoSets++
                                }
                            } else {
                                Write-CustomLog -Level 'INFO' -Message "[TEST] Would create quick mode crypto set"
                            }
                            
                            # Create Phase 1 authentication set
                            if (-not $TestMode) {
                                if ($PSCmdlet.ShouldProcess("Phase 1 Authentication", "Create IPSec authentication policy")) {
                                    $Phase1AuthParams = @{
                                        DisplayName = "SecAuto-IPSec-Phase1Auth-$AuthenticationMethod"
                                    }
                                    
                                    switch ($AuthenticationMethod) {
                                        'Certificate' {
                                            if ($CertificateThumbprint) {
                                                $Phase1AuthParams.Proposal = New-NetIPsecAuthProposal -Certificate -Cert $CertificateThumbprint
                                            } else {
                                                $Phase1AuthParams.Proposal = New-NetIPsecAuthProposal -Certificate
                                            }
                                        }
                                        'Kerberos' {
                                            if ($KerberosRealm) {
                                                $Phase1AuthParams.Proposal = New-NetIPsecAuthProposal -Kerberos -Realm $KerberosRealm
                                            } else {
                                                $Phase1AuthParams.Proposal = New-NetIPsecAuthProposal -Kerberos
                                            }
                                        }
                                        'PSK' {
                                            if ($PSKValue) {
                                                $Phase1AuthParams.Proposal = New-NetIPsecAuthProposal -PreSharedKey $PSKValue
                                            } else {
                                                # Use a default PSK for testing (not recommended for production)
                                                $Phase1AuthParams.Proposal = New-NetIPsecAuthProposal -PreSharedKey "DefaultPSK123!"
                                            }
                                        }
                                        'NTLMv2' {
                                            $Phase1AuthParams.Proposal = New-NetIPsecAuthProposal -UserNTLM
                                        }
                                        'Anonymous' {
                                            $Phase1AuthParams.Proposal = New-NetIPsecAuthProposal -Anonymous
                                        }
                                    }
                                    
                                    New-NetIPsecPhase1AuthSet @Phase1AuthParams | Out-Null
                                    $Results.AuthPolicies++
                                }
                            } else {
                                Write-CustomLog -Level 'INFO' -Message "[TEST] Would create Phase 1 authentication set for $AuthenticationMethod"
                            }
                            
                            # Create connection security rules for secure networks
                            foreach ($Network in $ActiveSecureNetworks) {
                                $RuleName = "SecAuto-IPSec-Secure-$($Network.Replace('/', '-').Replace('.', '-'))"
                                
                                if (-not $TestMode) {
                                    if ($PSCmdlet.ShouldProcess($Network, "Create IPSec connection security rule")) {
                                        $ConnectionRuleParams = @{
                                            DisplayName = $RuleName
                                            RemoteAddress = $Network
                                            InboundSecurity = if ($ProfileConfig.RequireAuthentication) { 'Require' } else { 'Request' }
                                            OutboundSecurity = if ($ProfileConfig.RequireAuthentication) { 'Require' } else { 'Request' }
                                            Phase1AuthSet = "SecAuto-IPSec-Phase1Auth-$AuthenticationMethod"
                                            MainModeCryptoSet = "SecAuto-IPSec-MainMode-$($ProfileConfig.AuthenticationMethod)"
                                            QuickModeCryptoSet = "SecAuto-IPSec-QuickMode-$($ProfileConfig.AuthenticationMethod)"
                                            Description = "SecurityAutomation IPSec rule for network: $Network"
                                        }
                                        
                                        if ($ProfileConfig.RequireEncryption) {
                                            $ConnectionRuleParams.InboundSecurity = 'Require'
                                            $ConnectionRuleParams.OutboundSecurity = 'Require'
                                        }
                                        
                                        New-NetIPsecRule @ConnectionRuleParams | Out-Null
                                        $Results.ConnectionRules++
                                    }
                                } else {
                                    Write-CustomLog -Level 'INFO' -Message "[TEST] Would create IPSec rule for network: $Network"
                                }
                                
                                $Results.RulesCreated++
                            }
                            
                            # Create bypass rules if specified
                            if ($EnableTrafficBypass -and $BypassNetworks.Count -gt 0) {
                                foreach ($BypassNetwork in $BypassNetworks) {
                                    $BypassRuleName = "SecAuto-IPSec-Bypass-$($BypassNetwork.Replace('/', '-').Replace('.', '-'))"
                                    
                                    if (-not $TestMode) {
                                        if ($PSCmdlet.ShouldProcess($BypassNetwork, "Create IPSec bypass rule")) {
                                            $BypassRuleParams = @{
                                                DisplayName = $BypassRuleName
                                                RemoteAddress = $BypassNetwork
                                                InboundSecurity = 'None'
                                                OutboundSecurity = 'None'
                                                Description = "SecurityAutomation IPSec bypass rule for network: $BypassNetwork"
                                            }
                                            
                                            New-NetIPsecRule @BypassRuleParams | Out-Null
                                        }
                                    } else {
                                        Write-CustomLog -Level 'INFO' -Message "[TEST] Would create bypass rule for network: $BypassNetwork"
                                    }
                                    
                                    $Results.RulesCreated++
                                }
                            }
                            
                            # Enable IPSec logging if requested
                            if ($LogIPSecEvents) {
                                if (-not $TestMode) {
                                    if ($PSCmdlet.ShouldProcess("IPSec Logging", "Enable IPSec event logging")) {
                                        # Enable IPSec operational log
                                        try {
                                            & wevtutil sl Microsoft-Windows-IPsec/Operational /e:true /q:true 2>$null
                                            & wevtutil sl Microsoft-Windows-IPsec/Diagnostic /e:true /q:true 2>$null
                                        } catch {
                                            Write-CustomLog -Level 'WARNING' -Message "Failed to enable IPSec logging: $($_.Exception.Message)"
                                        }
                                    }
                                } else {
                                    Write-CustomLog -Level 'INFO' -Message "[TEST] Would enable IPSec event logging"
                                }
                            }
                            
                            $Results.PoliciesCreated = $Results.CryptoSets + $Results.AuthPolicies
                            
                        } catch {
                            $Results.Errors += "Failed to configure IPSec policies: $($_.Exception.Message)"
                        }
                        
                        $Results
                    }
                    
                    $ComputerResult.PoliciesCreated = $PolicyResult.PoliciesCreated
                    $ComputerResult.RulesCreated = $PolicyResult.RulesCreated
                    $ComputerResult.ConnectionRules = $PolicyResult.ConnectionRules
                    $ComputerResult.AuthPolicies = $PolicyResult.AuthPolicies
                    $ComputerResult.CryptoSets = $PolicyResult.CryptoSets
                    $ComputerResult.Errors += $PolicyResult.Errors
                    
                    $IPSecResults.PoliciesCreated += $PolicyResult.PoliciesCreated
                    $IPSecResults.RulesCreated += $PolicyResult.RulesCreated
                    $IPSecResults.ConnectionSecurityRules += $PolicyResult.ConnectionRules
                    $IPSecResults.AuthenticationPolicies += $PolicyResult.AuthPolicies
                    $IPSecResults.CryptoSetsCreated += $PolicyResult.CryptoSets
                    
                    Write-CustomLog -Level 'SUCCESS' -Message "IPSec configuration completed for $Computer"
                    
                } catch {
                    $Error = "Failed to configure IPSec on $Computer`: $($_.Exception.Message)"
                    $ComputerResult.Errors += $Error
                    Write-CustomLog -Level 'ERROR' -Message $Error
                }
                
                $IPSecResults.ComputersProcessed += $ComputerResult
            }
            
        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Error during IPSec configuration: $($_.Exception.Message)"
            throw
        }
    }
    
    end {
        Write-CustomLog -Level 'SUCCESS' -Message "IPSec configuration completed"
        
        # Generate recommendations
        $IPSecResults.Recommendations += "Test IPSec connectivity thoroughly after implementation"
        $IPSecResults.Recommendations += "Monitor IPSec logs for authentication failures and connection issues"
        $IPSecResults.Recommendations += "Ensure certificates are valid and properly distributed for certificate authentication"
        $IPSecResults.Recommendations += "Regularly review and update IPSec policies based on network changes"
        $IPSecResults.Recommendations += "Implement monitoring for IPSec tunnel establishment and failures"
        
        if ($AuthenticationMethod -eq 'Certificate') {
            $IPSecResults.Recommendations += "Monitor certificate expiration dates and implement automatic renewal"
            $IPSecResults.Recommendations += "Ensure certificate revocation lists (CRLs) are accessible"
        }
        
        if ($AuthenticationMethod -eq 'PSK') {
            $IPSecResults.Recommendations += "Change pre-shared keys regularly and use strong, unique values"
            $IPSecResults.Recommendations += "Consider migrating to certificate-based authentication for better security"
        }
        
        if ($EnablePFS) {
            $IPSecResults.Recommendations += "Perfect Forward Secrecy is enabled - monitor for performance impact"
        }
        
        if ($PolicyProfile -eq 'ZeroTrust') {
            $IPSecResults.Recommendations += "Zero-trust mode requires all traffic to use IPSec - monitor for application compatibility"
            $IPSecResults.Recommendations += "Implement comprehensive network monitoring in zero-trust environments"
        }
        
        # Generate report if requested
        if ($ReportPath) {
            try {
                $HtmlReport = @"
<!DOCTYPE html>
<html>
<head>
    <title>IPSec Configuration Report</title>
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
        <h1>IPSec Configuration Report</h1>
        <p><strong>Policy Profile:</strong> $($IPSecResults.PolicyProfile)</p>
        <p><strong>Generated:</strong> $(Get-Date)</p>
        <p><strong>Computers Processed:</strong> $($IPSecResults.ComputersProcessed.Count)</p>
        <p><strong>Total Policies Created:</strong> $($IPSecResults.PoliciesCreated)</p>
        <p><strong>Connection Security Rules:</strong> $($IPSecResults.ConnectionSecurityRules)</p>
        <p><strong>Authentication Policies:</strong> $($IPSecResults.AuthenticationPolicies)</p>
        <p><strong>Crypto Sets Created:</strong> $($IPSecResults.CryptoSetsCreated)</p>
    </div>
"@
                
                foreach ($Computer in $IPSecResults.ComputersProcessed) {
                    $HtmlReport += "<div class='computer'>"
                    $HtmlReport += "<h2>$($Computer.ComputerName)</h2>"
                    $HtmlReport += "<p><strong>Policy Profile:</strong> $($Computer.PolicyProfile)</p>"
                    $HtmlReport += "<p><strong>Policies Created:</strong> $($Computer.PoliciesCreated)</p>"
                    $HtmlReport += "<p><strong>Rules Created:</strong> $($Computer.RulesCreated)</p>"
                    $HtmlReport += "<p><strong>Connection Rules:</strong> $($Computer.ConnectionRules)</p>"
                    $HtmlReport += "<p><strong>Auth Policies:</strong> $($Computer.AuthPolicies)</p>"
                    $HtmlReport += "<p><strong>Crypto Sets:</strong> $($Computer.CryptoSets)</p>"
                    $HtmlReport += "</div>"
                }
                
                $HtmlReport += "<div class='header'><h2>Recommendations</h2>"
                foreach ($Rec in $IPSecResults.Recommendations) {
                    $HtmlReport += "<div class='recommendation'>$Rec</div>"
                }
                $HtmlReport += "</div>"
                
                $HtmlReport += "</body></html>"
                
                $HtmlReport | Out-File -FilePath $ReportPath -Encoding UTF8
                Write-CustomLog -Level 'SUCCESS' -Message "IPSec configuration report saved to: $ReportPath"
                
            } catch {
                Write-CustomLog -Level 'ERROR' -Message "Failed to generate report: $($_.Exception.Message)"
            }
        }
        
        # Display summary
        Write-CustomLog -Level 'INFO' -Message "IPSec Configuration Summary:"
        Write-CustomLog -Level 'INFO' -Message "  Policy Profile: $($IPSecResults.PolicyProfile)"
        Write-CustomLog -Level 'INFO' -Message "  Computers: $($IPSecResults.ComputersProcessed.Count)"
        Write-CustomLog -Level 'INFO' -Message "  Total Policies: $($IPSecResults.PoliciesCreated)"
        Write-CustomLog -Level 'INFO' -Message "  Connection Rules: $($IPSecResults.ConnectionSecurityRules)"
        Write-CustomLog -Level 'INFO' -Message "  Auth Policies: $($IPSecResults.AuthenticationPolicies)"
        Write-CustomLog -Level 'INFO' -Message "  Crypto Sets: $($IPSecResults.CryptoSetsCreated)"
        Write-CustomLog -Level 'INFO' -Message "  Backup Created: $($IPSecResults.BackupCreated)"
        
        return $IPSecResults
    }
}
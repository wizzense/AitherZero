function Set-IPsecPolicy {
    <#
    .SYNOPSIS
        Configures IPsec policies for zero-trust network security.

    .DESCRIPTION
        Creates and manages IPsec policies and rules for securing network communications.
        Supports various authentication methods including certificates, Kerberos, and pre-shared keys.
        Enables zero-trust networking with strong encryption and authentication requirements.

    .PARAMETER PolicyName
        Name for the IPsec policy configuration

    .PARAMETER AuthenticationMethod
        Authentication method: Certificate, Kerberos, PreSharedKey, or ComputerCertificate

    .PARAMETER RequireAuthentication
        Require IPsec authentication for connections

    .PARAMETER RequireEncryption
        Require IPsec encryption for connections

    .PARAMETER Protocol
        Network protocol: TCP, UDP, or Any

    .PARAMETER LocalAddress
        Local address range (CIDR notation or 'Any')

    .PARAMETER RemoteAddress
        Remote address range (CIDR notation or 'Any')

    .PARAMETER LocalPort
        Local port(s) - single port, array, or 'Any'

    .PARAMETER RemotePort
        Remote port(s) - single port, array, or 'Any'

    .PARAMETER Direction
        Traffic direction: Inbound, Outbound, or Both

    .PARAMETER Profile
        Firewall profile: Domain, Private, Public, or Any

    .PARAMETER PreSharedKey
        Pre-shared key for PSK authentication (use only for testing)

    .PARAMETER CertificateSubject
        Certificate subject for certificate-based authentication

    .PARAMETER RemoveExisting
        Remove existing IPsec policies before creating new ones

    .PARAMETER TestMode
        Show what would be configured without making changes

    .EXAMPLE
        Set-IPsecPolicy -PolicyName "ZeroTrust-Admin" -AuthenticationMethod Certificate -RequireAuthentication -RequireEncryption

    .EXAMPLE
        Set-IPsecPolicy -PolicyName "Management-Network" -AuthenticationMethod Kerberos -RemoteAddress "192.168.100.0/24" -Protocol TCP -RemotePort @(3389,5985,5986)

    .EXAMPLE
        Set-IPsecPolicy -PolicyName "Test-PSK" -AuthenticationMethod PreSharedKey -PreSharedKey "TestKey123" -RemoteAddress "10.0.0.0/8" -TestMode
    #>

    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$PolicyName,

        [Parameter(Mandatory)]
        [ValidateSet('Certificate', 'Kerberos', 'PreSharedKey', 'ComputerCertificate')]
        [string]$AuthenticationMethod,

        [Parameter()]
        [switch]$RequireAuthentication,

        [Parameter()]
        [switch]$RequireEncryption,

        [Parameter()]
        [ValidateSet('TCP', 'UDP', 'Any')]
        [string]$Protocol = 'Any',

        [Parameter()]
        [string]$LocalAddress = 'Any',

        [Parameter()]
        [string]$RemoteAddress = 'Any',

        [Parameter()]
        [object]$LocalPort = 'Any',

        [Parameter()]
        [object]$RemotePort = 'Any',

        [Parameter()]
        [ValidateSet('Inbound', 'Outbound', 'Both')]
        [string]$Direction = 'Both',

        [Parameter()]
        [ValidateSet('Domain', 'Private', 'Public', 'Any')]
        [string]$Profile = 'Any',

        [Parameter()]
        [string]$PreSharedKey,

        [Parameter()]
        [string]$CertificateSubject,

        [Parameter()]
        [switch]$RemoveExisting,

        [Parameter()]
        [switch]$TestMode
    )

    begin {
        Write-CustomLog -Level 'INFO' -Message "Configuring IPsec policy: $PolicyName"

        # Check if running as Administrator
        $CurrentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
        $Principal = New-Object Security.Principal.WindowsPrincipal($CurrentUser)
        if (-not $Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            throw "This function requires Administrator privileges"
        }

        # Validate authentication method requirements
        if ($AuthenticationMethod -eq 'PreSharedKey' -and -not $PreSharedKey) {
            throw "PreSharedKey parameter is required when using PreSharedKey authentication"
        }

        if ($AuthenticationMethod -eq 'Certificate' -and -not $CertificateSubject) {
            Write-CustomLog -Level 'WARNING' -Message "CertificateSubject not specified - will use any available certificate"
        }

        $CreatedObjects = @()
    }

    process {
        try {
            # Remove existing policies if requested
            if ($RemoveExisting) {
                Write-CustomLog -Level 'INFO' -Message "Removing existing IPsec policies with name pattern: *$PolicyName*"

                if ($TestMode) {
                    Write-CustomLog -Level 'INFO' -Message "[TEST MODE] Would remove existing IPsec policies"
                } else {
                    try {
                        $ExistingRules = Get-NetIPsecRule -DisplayName "*$PolicyName*" -ErrorAction SilentlyContinue
                        if ($ExistingRules) {
                            $ExistingRules | Remove-NetIPsecRule -Confirm:$false
                            Write-CustomLog -Level 'SUCCESS' -Message "Removed $($ExistingRules.Count) existing IPsec rules"
                        }

                        $ExistingAuthSets = Get-NetIPsecPhase1AuthSet -DisplayName "*$PolicyName*" -ErrorAction SilentlyContinue
                        if ($ExistingAuthSets) {
                            $ExistingAuthSets | Remove-NetIPsecPhase1AuthSet -Confirm:$false
                            Write-CustomLog -Level 'SUCCESS' -Message "Removed $($ExistingAuthSets.Count) existing auth sets"
                        }
                    } catch {
                        Write-CustomLog -Level 'WARNING' -Message "Error removing existing policies: $($_.Exception.Message)"
                    }
                }
            }

            # Create authentication proposal based on method
            Write-CustomLog -Level 'INFO' -Message "Creating authentication proposal for method: $AuthenticationMethod"

            $AuthProposal = $null
            $AuthSetName = "$PolicyName-AuthSet"

            if ($TestMode) {
                Write-CustomLog -Level 'INFO' -Message "[TEST MODE] Would create $AuthenticationMethod authentication proposal"
                $AuthProposal = "TEST-AUTH-PROPOSAL"
                $AuthProposalSet = "TEST-AUTH-SET"
            } else {
                switch ($AuthenticationMethod) {
                    'PreSharedKey' {
                        if ($PSCmdlet.ShouldProcess("IPsec Auth Proposal", "Create PreSharedKey authentication")) {
                            $AuthProposal = New-NetIPsecAuthProposal -Machine -PreSharedKey $PreSharedKey
                        }
                    }
                    'Certificate' {
                        if ($PSCmdlet.ShouldProcess("IPsec Auth Proposal", "Create Certificate authentication")) {
                            if ($CertificateSubject) {
                                $AuthProposal = New-NetIPsecAuthProposal -Machine -Cert -CertSubjectName $CertificateSubject
                            } else {
                                $AuthProposal = New-NetIPsecAuthProposal -Machine -Cert
                            }
                        }
                    }
                    'ComputerCertificate' {
                        if ($PSCmdlet.ShouldProcess("IPsec Auth Proposal", "Create Computer Certificate authentication")) {
                            $AuthProposal = New-NetIPsecAuthProposal -Machine -Cert
                        }
                    }
                    'Kerberos' {
                        if ($PSCmdlet.ShouldProcess("IPsec Auth Proposal", "Create Kerberos authentication")) {
                            $AuthProposal = New-NetIPsecAuthProposal -Machine -Kerberos
                        }
                    }
                }

                if ($AuthProposal) {
                    Write-CustomLog -Level 'SUCCESS' -Message "Created authentication proposal"

                    # Create authentication set
                    if ($PSCmdlet.ShouldProcess($AuthSetName, "Create authentication set")) {
                        $AuthProposalSet = New-NetIPsecPhase1AuthSet -DisplayName $AuthSetName -Proposal $AuthProposal
                        $CreatedObjects += $AuthProposalSet
                        Write-CustomLog -Level 'SUCCESS' -Message "Created authentication set: $AuthSetName"
                    }
                }
            }

            # Create IPsec rules
            $Directions = if ($Direction -eq 'Both') { @('Inbound', 'Outbound') } else { @($Direction) }

            foreach ($Dir in $Directions) {
                $RuleName = "$PolicyName-$Dir"
                Write-CustomLog -Level 'INFO' -Message "Creating IPsec rule: $RuleName"

                if ($TestMode) {
                    Write-CustomLog -Level 'INFO' -Message "[TEST MODE] Would create IPsec rule '$RuleName' for $Dir traffic"
                    continue
                }

                # Determine security requirements
                $InboundSecurity = 'None'
                $OutboundSecurity = 'None'

                if ($RequireAuthentication -and $RequireEncryption) {
                    $InboundSecurity = 'Require'
                    $OutboundSecurity = 'Require'
                } elseif ($RequireAuthentication) {
                    $InboundSecurity = 'Request'
                    $OutboundSecurity = 'Request'
                }

                # Build rule parameters
                $RuleParams = @{
                    DisplayName = $RuleName
                    Description = "IPsec rule created by SecurityAutomation module"
                    Protocol = $Protocol
                    LocalAddress = $LocalAddress
                    RemoteAddress = $RemoteAddress
                    Profile = $Profile
                    InterfaceType = 'Any'
                    Enabled = $true
                }

                # Add authentication set if created
                if ($AuthProposalSet -and $AuthProposalSet -ne "TEST-AUTH-SET") {
                    $RuleParams['Phase1AuthSet'] = $AuthProposalSet.Name
                }

                # Set security requirements
                if ($Dir -eq 'Inbound') {
                    $RuleParams['InboundSecurity'] = $InboundSecurity
                    $RuleParams['OutboundSecurity'] = 'None'
                } else {
                    $RuleParams['InboundSecurity'] = 'None'
                    $RuleParams['OutboundSecurity'] = $OutboundSecurity
                }

                # Add port specifications if not 'Any'
                if ($LocalPort -ne 'Any') {
                    $RuleParams['LocalPort'] = $LocalPort
                }
                if ($RemotePort -ne 'Any') {
                    $RuleParams['RemotePort'] = $RemotePort
                }

                # Create the rule
                if ($PSCmdlet.ShouldProcess($RuleName, "Create IPsec rule")) {
                    try {
                        $IPsecRule = New-NetIPsecRule @RuleParams
                        $CreatedObjects += $IPsecRule
                        Write-CustomLog -Level 'SUCCESS' -Message "Created IPsec rule: $RuleName"
                    } catch {
                        Write-CustomLog -Level 'ERROR' -Message "Failed to create IPsec rule '$RuleName': $($_.Exception.Message)"
                        throw
                    }
                }
            }

        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Error configuring IPsec policy: $($_.Exception.Message)"

            # Cleanup created objects on error
            if ($CreatedObjects.Count -gt 0 -and -not $TestMode) {
                Write-CustomLog -Level 'INFO' -Message "Cleaning up created objects due to error"
                foreach ($Object in $CreatedObjects) {
                    try {
                        if ($Object.GetType().Name -eq 'CimInstance' -and $Object.CimClass.CimClassName -eq 'MSFT_NetIPsecRule') {
                            Remove-NetIPsecRule -InputObject $Object -Confirm:$false
                        } elseif ($Object.GetType().Name -eq 'CimInstance' -and $Object.CimClass.CimClassName -eq 'MSFT_NetIPsecPhase1AuthSet') {
                            Remove-NetIPsecPhase1AuthSet -InputObject $Object -Confirm:$false
                        }
                    } catch {
                        Write-CustomLog -Level 'WARNING' -Message "Failed to cleanup object: $($_.Exception.Message)"
                    }
                }
            }

            throw
        }
    }

    end {
        if ($TestMode) {
            Write-CustomLog -Level 'INFO' -Message "IPsec policy test completed - no changes made"
        } else {
            Write-CustomLog -Level 'SUCCESS' -Message "IPsec policy '$PolicyName' configured successfully"

            # Display configuration summary
            Write-CustomLog -Level 'INFO' -Message "Policy Summary:"
            Write-CustomLog -Level 'INFO' -Message "  Authentication: $AuthenticationMethod"
            Write-CustomLog -Level 'INFO' -Message "  Require Auth: $($RequireAuthentication.IsPresent)"
            Write-CustomLog -Level 'INFO' -Message "  Require Encryption: $($RequireEncryption.IsPresent)"
            Write-CustomLog -Level 'INFO' -Message "  Protocol: $Protocol"
            Write-CustomLog -Level 'INFO' -Message "  Remote Address: $RemoteAddress"

            if ($RemotePort -ne 'Any') {
                Write-CustomLog -Level 'INFO' -Message "  Remote Ports: $($RemotePort -join ', ')"
            }
        }

        # Security recommendations
        $Recommendations = @()

        if ($AuthenticationMethod -eq 'PreSharedKey') {
            $Recommendations += "WARNING: Pre-shared keys are not recommended for production use"
            $Recommendations += "Consider using certificate-based authentication for better security"
        }

        $Recommendations += "Test IPsec connectivity after configuration"
        $Recommendations += "Monitor IPsec events in the Security log"
        $Recommendations += "Regularly review and update IPsec policies"
        $Recommendations += "Ensure time synchronization between IPsec peers"
        $Recommendations += "Document IPsec configuration for operational procedures"

        foreach ($Recommendation in $Recommendations) {
            Write-CustomLog -Level 'INFO' -Message "Recommendation: $Recommendation"
        }

        # Return summary
        return @{
            PolicyName = $PolicyName
            AuthenticationMethod = $AuthenticationMethod
            ObjectsCreated = $CreatedObjects.Count
            TestMode = $TestMode.IsPresent
            Timestamp = Get-Date
        }
    }
}

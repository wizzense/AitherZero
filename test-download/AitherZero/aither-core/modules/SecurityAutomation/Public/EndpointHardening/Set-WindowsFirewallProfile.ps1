function Set-WindowsFirewallProfile {
    <#
    .SYNOPSIS
        Configures Windows Firewall profiles for enhanced security.

    .DESCRIPTION
        Applies enterprise security firewall configuration including profile settings,
        rule cleanup, and essential security rules. Supports both workstation and server
        configurations with appropriate security defaults.

    .PARAMETER ConfigurationType
        Type of firewall configuration: 'Workstation', 'Server', or 'Custom'

    .PARAMETER Profiles
        Firewall profiles to configure: Domain, Private, Public, or All

    .PARAMETER AllowInboundRules
        Whether to allow inbound rules for the specified profiles

    .PARAMETER DefaultInboundAction
        Default action for inbound traffic: Allow or Block

    .PARAMETER DefaultOutboundAction
        Default action for outbound traffic: Allow or Block

    .PARAMETER JumpServerAddresses
        Array of IP addresses/ranges for jump servers requiring IPsec

    .PARAMETER ClearExistingRules
        Whether to clear existing firewall rules before applying new configuration

    .PARAMETER EnableLogging
        Enable firewall logging for monitoring and compliance

    .PARAMETER LogPath
        Path for firewall log files

    .PARAMETER WhatIf
        Shows what would be done without making changes

    .EXAMPLE
        Set-WindowsFirewallProfile -ConfigurationType Workstation

    .EXAMPLE
        Set-WindowsFirewallProfile -ConfigurationType Server -JumpServerAddresses @('192.168.1.200/29') -EnableLogging

    .EXAMPLE
        Set-WindowsFirewallProfile -ConfigurationType Custom -Profiles @('Domain') -DefaultInboundAction Block -AllowInboundRules $true
    #>

    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Workstation', 'Server', 'Custom')]
        [string]$ConfigurationType,

        [Parameter()]
        [ValidateSet('Domain', 'Private', 'Public', 'All')]
        [string[]]$Profiles = @('All'),

        [Parameter()]
        [bool]$AllowInboundRules,

        [Parameter()]
        [ValidateSet('Allow', 'Block')]
        [string]$DefaultInboundAction,

        [Parameter()]
        [ValidateSet('Allow', 'Block')]
        [string]$DefaultOutboundAction,

        [Parameter()]
        [string[]]$JumpServerAddresses,

        [Parameter()]
        [bool]$ClearExistingRules = $false,

        [Parameter()]
        [bool]$EnableLogging = $false,

        [Parameter()]
        [string]$LogPath = "$env:SystemRoot\System32\LogFiles\Firewall\pfirewall.log"
    )

    begin {
        Write-CustomLog -Level 'INFO' -Message "Configuring Windows Firewall with $ConfigurationType profile"

        # Set defaults based on configuration type
        switch ($ConfigurationType) {
            'Workstation' {
                $Profiles = @('Domain', 'Private', 'Public')
                $AllowInboundRules = @{Domain = $true; Private = $false; Public = $false}
                $DefaultInboundAction = 'Block'
                $DefaultOutboundAction = 'Allow'
            }
            'Server' {
                $Profiles = @('Domain', 'Private', 'Public')
                $AllowInboundRules = @{Domain = $true; Private = $true; Public = $false}
                $DefaultInboundAction = 'Block'
                $DefaultOutboundAction = 'Allow'
            }
            'Custom' {
                # Use provided parameters
                if (-not $PSBoundParameters.ContainsKey('AllowInboundRules')) {
                    $AllowInboundRules = $true
                }
                if (-not $DefaultInboundAction) {
                    $DefaultInboundAction = 'Block'
                }
                if (-not $DefaultOutboundAction) {
                    $DefaultOutboundAction = 'Allow'
                }
            }
        }

        # Resolve 'All' profiles
        if ($Profiles -contains 'All') {
            $Profiles = @('Domain', 'Private', 'Public')
        }
    }

    process {
        try {
            # Enable Windows Firewall for all specified profiles
            Write-CustomLog -Level 'INFO' -Message "Enabling Windows Firewall for profiles: $($Profiles -join ', ')"

            if ($PSCmdlet.ShouldProcess("Windows Firewall", "Enable for profiles: $($Profiles -join ', ')")) {
                Set-NetFirewallProfile -Profile $Profiles -Enabled True
            }

            # Configure profile settings
            foreach ($Profile in $Profiles) {
                Write-CustomLog -Level 'INFO' -Message "Configuring $Profile profile settings"

                if ($PSCmdlet.ShouldProcess("$Profile Profile", "Configure firewall settings")) {
                    $ProfileParams = @{
                        Profile = $Profile
                        DefaultOutboundAction = $DefaultOutboundAction
                        DefaultInboundAction = $DefaultInboundAction
                    }

                    # Handle AllowInboundRules parameter based on type
                    if ($ConfigurationType -eq 'Custom') {
                        $ProfileParams['AllowInboundRules'] = $AllowInboundRules
                    } else {
                        $ProfileParams['AllowInboundRules'] = $AllowInboundRules[$Profile]
                    }

                    Set-NetFirewallProfile @ProfileParams

                    # Configure logging if requested
                    if ($EnableLogging) {
                        Set-NetFirewallProfile -Profile $Profile -LogAllowed True -LogBlocked True -LogFileName $LogPath -LogMaxSizeKilobytes 32767
                        Write-CustomLog -Level 'INFO' -Message "Enabled logging for $Profile profile: $LogPath"
                    }
                }
            }

            # Clear existing rules if requested
            if ($ClearExistingRules) {
                Write-CustomLog -Level 'WARNING' -Message "Clearing existing firewall rules"

                if ($PSCmdlet.ShouldProcess("Firewall Rules", "Clear existing rules")) {
                    # Clear PersistentStore (visible in Windows Firewall snap-in)
                    Get-NetFirewallRule -PolicyStore PersistentStore | Remove-NetFirewallRule -Confirm:$false

                    # Clear ConfigurableServiceStore (invisible rules)
                    Get-NetFirewallRule -PolicyStore ConfigurableServiceStore | Remove-NetFirewallRule -Confirm:$false

                    Write-CustomLog -Level 'INFO' -Message "Existing firewall rules cleared"
                }
            }

            # Apply essential security rules
            Write-CustomLog -Level 'INFO' -Message "Applying essential security rules"

            if ($PSCmdlet.ShouldProcess("Essential Security Rules", "Create firewall rules")) {
                # Allow essential inbound traffic
                $EssentialRules = @(
                    @{DisplayName = 'ICMPv4-Essential'; Protocol = 'ICMPv4'; Direction = 'Inbound'; Action = 'Allow'},
                    @{DisplayName = 'DHCP-Client'; Protocol = 'UDP'; Direction = 'Inbound'; Action = 'Allow'; LocalPort = 68; RemotePort = 67; Service = 'dhcp'}
                )

                foreach ($Rule in $EssentialRules) {
                    try {
                        # Check if rule already exists
                        $ExistingRule = Get-NetFirewallRule -DisplayName $Rule.DisplayName -ErrorAction SilentlyContinue
                        if (-not $ExistingRule) {
                            New-NetFirewallRule @Rule
                            Write-CustomLog -Level 'INFO' -Message "Created essential rule: $($Rule.DisplayName)"
                        }
                    } catch {
                        Write-CustomLog -Level 'WARNING' -Message "Could not create rule $($Rule.DisplayName): $($_.Exception.Message)"
                    }
                }

                # Configure jump server access if provided
                if ($JumpServerAddresses) {
                    Write-CustomLog -Level 'INFO' -Message "Configuring jump server access for $($JumpServerAddresses.Count) addresses"

                    $JumpRules = @(
                        @{DisplayName = 'Jump-Servers-TCP'; Protocol = 'TCP'; Direction = 'Inbound'; Action = 'Allow'; Authentication = 'Required'; Encryption = 'Required'; RemoteAddress = $JumpServerAddresses},
                        @{DisplayName = 'Jump-Servers-UDP'; Protocol = 'UDP'; Direction = 'Inbound'; Action = 'Allow'; Authentication = 'Required'; Encryption = 'Required'; RemoteAddress = $JumpServerAddresses}
                    )

                    foreach ($Rule in $JumpRules) {
                        try {
                            $ExistingRule = Get-NetFirewallRule -DisplayName $Rule.DisplayName -ErrorAction SilentlyContinue
                            if (-not $ExistingRule) {
                                New-NetFirewallRule @Rule
                                Write-CustomLog -Level 'INFO' -Message "Created jump server rule: $($Rule.DisplayName)"
                            }
                        } catch {
                            Write-CustomLog -Level 'WARNING' -Message "Could not create jump server rule $($Rule.DisplayName): $($_.Exception.Message)"
                        }
                    }
                }

                # Block problematic protocols for workstations
                if ($ConfigurationType -eq 'Workstation') {
                    $BlockRules = @(
                        # IPv6 protocols
                        @{DisplayName = 'Block-IPv6'; Protocol = 41; Direction = 'Outbound'; Action = 'Block'},
                        @{DisplayName = 'Block-IPv6-Route'; Protocol = 43; Direction = 'Outbound'; Action = 'Block'},
                        @{DisplayName = 'Block-IPv6-Frag'; Protocol = 44; Direction = 'Outbound'; Action = 'Block'},
                        @{DisplayName = 'Block-ICMPv6'; Protocol = 58; Direction = 'Outbound'; Action = 'Block'},
                        # NetBIOS
                        @{DisplayName = 'Block-NetBIOS-TCP'; Protocol = 'TCP'; Direction = 'Outbound'; Action = 'Block'; RemotePort = '139'},
                        @{DisplayName = 'Block-NetBIOS-UDP'; Protocol = 'UDP'; Direction = 'Outbound'; Action = 'Block'; RemotePort = @('137','138')},
                        # LLMNR
                        @{DisplayName = 'Block-LLMNR'; Protocol = 'UDP'; Direction = 'Outbound'; Action = 'Block'; RemotePort = '5355'}
                    )

                    foreach ($Rule in $BlockRules) {
                        try {
                            $ExistingRule = Get-NetFirewallRule -DisplayName $Rule.DisplayName -ErrorAction SilentlyContinue
                            if (-not $ExistingRule) {
                                New-NetFirewallRule @Rule
                                Write-CustomLog -Level 'INFO' -Message "Created security block rule: $($Rule.DisplayName)"
                            }
                        } catch {
                            Write-CustomLog -Level 'WARNING' -Message "Could not create block rule $($Rule.DisplayName): $($_.Exception.Message)"
                        }
                    }
                }
            }

            # Display final configuration
            $CurrentProfiles = Get-NetFirewallProfile -Profile $Profiles
            foreach ($Profile in $CurrentProfiles) {
                Write-CustomLog -Level 'INFO' -Message "$($Profile.Name) Profile: Enabled=$($Profile.Enabled), InboundDefault=$($Profile.DefaultInboundAction), OutboundDefault=$($Profile.DefaultOutboundAction), AllowInboundRules=$($Profile.AllowInboundRules)"
            }

        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Error configuring Windows Firewall: $($_.Exception.Message)"
            throw
        }
    }

    end {
        Write-CustomLog -Level 'SUCCESS' -Message "Windows Firewall configuration completed for $ConfigurationType profile"

        # Provide security recommendations
        $Recommendations = @()
        $Recommendations += "Review firewall logs regularly for blocked connection attempts"
        $Recommendations += "Test applications after firewall changes to ensure functionality"
        $Recommendations += "Consider implementing IPsec for additional network layer security"
        $Recommendations += "Monitor firewall rule effectiveness and adjust as needed"

        foreach ($Recommendation in $Recommendations) {
            Write-CustomLog -Level 'INFO' -Message "Recommendation: $Recommendation"
        }
    }
}

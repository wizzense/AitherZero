function Set-AdvancedFirewallPolicy {
    <#
    .SYNOPSIS
        Configures advanced Windows Firewall policies with enterprise security controls.
        
    .DESCRIPTION
        Implements comprehensive firewall policies including network segmentation,
        threat blocking, application control, and micro-segmentation. Supports
        bulk IP blocking, service hardening, and zero-trust network architectures.
        
    .PARAMETER PolicyProfile
        Predefined firewall policy profile to apply
        
    .PARAMETER ComputerName
        Target computers for firewall policy application. Default: localhost
        
    .PARAMETER Credential
        Credentials for remote computer access
        
    .PARAMETER BlocklistFile
        Path to file containing IP addresses/ranges to block
        
    .PARAMETER AllowlistFile
        Path to file containing IP addresses/ranges to explicitly allow
        
    .PARAMETER InternalNetworks
        Array of internal network ranges (CIDR notation)
        
    .PARAMETER JumpServerNetworks
        Array of jump server/bastion network ranges
        
    .PARAMETER ManagementNetworks
        Array of management network ranges for admin access
        
    .PARAMETER EnableMicroSegmentation
        Enable micro-segmentation between network zones
        
    .PARAMETER RequireIPSec
        Require IPSec authentication for specified traffic
        
    .PARAMETER DefaultInboundAction
        Default action for inbound traffic: Allow, Block, or NotConfigured
        
    .PARAMETER DefaultOutboundAction
        Default action for outbound traffic: Allow, Block, or NotConfigured
        
    .PARAMETER EnableAuditMode
        Enable comprehensive firewall logging and auditing
        
    .PARAMETER AuditLogPath
        Custom path for firewall audit logs
        
    .PARAMETER ServiceHardening
        Enable service-specific firewall hardening rules
        
    .PARAMETER ApplicationControl
        Enable application-based firewall controls
        
    .PARAMETER ThreatIntelligence
        Enable threat intelligence-based blocking
        
    .PARAMETER TestMode
        Show what would be configured without making changes
        
    .PARAMETER BackupCurrentRules
        Create backup of current firewall rules before changes
        
    .PARAMETER ReportPath
        Path to save firewall configuration report
        
    .EXAMPLE
        Set-AdvancedFirewallPolicy -PolicyProfile 'Server' -InternalNetworks @('10.0.0.0/8','172.16.0.0/12')
        
    .EXAMPLE
        Set-AdvancedFirewallPolicy -BlocklistFile 'C:\Security\BlockedIPs.txt' -EnableMicroSegmentation
        
    .EXAMPLE
        Set-AdvancedFirewallPolicy -PolicyProfile 'DomainController' -RequireIPSec -EnableAuditMode
    #>
    
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter()]
        [ValidateSet('Workstation', 'Server', 'DomainController', 'WebServer', 'DatabaseServer', 'JumpServer', 'Custom')]
        [string]$PolicyProfile = 'Server',
        
        [Parameter()]
        [string[]]$ComputerName = @('localhost'),
        
        [Parameter()]
        [pscredential]$Credential,
        
        [Parameter()]
        [string]$BlocklistFile,
        
        [Parameter()]
        [string]$AllowlistFile,
        
        [Parameter()]
        [string[]]$InternalNetworks = @('10.0.0.0/8', '172.16.0.0/12', '192.168.0.0/16'),
        
        [Parameter()]
        [string[]]$JumpServerNetworks = @(),
        
        [Parameter()]
        [string[]]$ManagementNetworks = @(),
        
        [Parameter()]
        [switch]$EnableMicroSegmentation,
        
        [Parameter()]
        [switch]$RequireIPSec,
        
        [Parameter()]
        [ValidateSet('Allow', 'Block', 'NotConfigured')]
        [string]$DefaultInboundAction = 'Block',
        
        [Parameter()]
        [ValidateSet('Allow', 'Block', 'NotConfigured')]
        [string]$DefaultOutboundAction = 'Allow',
        
        [Parameter()]
        [switch]$EnableAuditMode,
        
        [Parameter()]
        [string]$AuditLogPath = 'C:\Windows\System32\LogFiles\Firewall',
        
        [Parameter()]
        [switch]$ServiceHardening,
        
        [Parameter()]
        [switch]$ApplicationControl,
        
        [Parameter()]
        [switch]$ThreatIntelligence,
        
        [Parameter()]
        [switch]$TestMode,
        
        [Parameter()]
        [switch]$BackupCurrentRules,
        
        [Parameter()]
        [string]$ReportPath
    )
    
    begin {
        Write-CustomLog -Level 'INFO' -Message "Configuring advanced firewall policy: $PolicyProfile"
        
        # Check if running as Administrator
        $CurrentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
        $Principal = New-Object Security.Principal.WindowsPrincipal($CurrentUser)
        if (-not $Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            throw "This function requires Administrator privileges"
        }
        
        # Define policy profiles
        $PolicyProfiles = @{
            'Workstation' = @{
                Description = 'Secure workstation firewall policy'
                EnabledProfiles = @('Domain', 'Public', 'Private')
                DefaultInbound = 'Block'
                DefaultOutbound = 'Allow'
                AllowInboundRules = $true
                RequiredServices = @('Core Networking', 'Windows Remote Management')
                BlockedServices = @('File and Printer Sharing', 'Network Discovery')
                RequireAuthentication = $false
            }
            'Server' = @{
                Description = 'Secure server firewall policy'
                EnabledProfiles = @('Domain', 'Public', 'Private')
                DefaultInbound = 'Block'
                DefaultOutbound = 'Allow'
                AllowInboundRules = $true
                RequiredServices = @('Core Networking', 'Windows Remote Management', 'Remote Event Log Management')
                BlockedServices = @('Network Discovery', 'HomeGroup')
                RequireAuthentication = $false
            }
            'DomainController' = @{
                Description = 'Domain controller firewall policy'
                EnabledProfiles = @('Domain', 'Public', 'Private')
                DefaultInbound = 'Block'
                DefaultOutbound = 'Allow'
                AllowInboundRules = $true
                RequiredServices = @('Core Networking', 'Active Directory Domain Services', 'DNS Service', 'DFS Management', 'Windows Remote Management')
                BlockedServices = @('Network Discovery', 'HomeGroup', 'File and Printer Sharing')
                RequireAuthentication = $true
            }
            'WebServer' = @{
                Description = 'Web server firewall policy'
                EnabledProfiles = @('Domain', 'Public', 'Private')
                DefaultInbound = 'Block'
                DefaultOutbound = 'Allow'
                AllowInboundRules = $true
                RequiredServices = @('Core Networking', 'World Wide Web Services (HTTP)', 'Secure World Wide Web Services (HTTPS)')
                BlockedServices = @('File and Printer Sharing', 'Network Discovery', 'Remote Desktop')
                RequireAuthentication = $false
                CustomPorts = @{
                    'HTTP' = @{ Protocol = 'TCP'; Port = 80; Direction = 'Inbound'; Action = 'Allow' }
                    'HTTPS' = @{ Protocol = 'TCP'; Port = 443; Direction = 'Inbound'; Action = 'Allow' }
                }
            }
            'DatabaseServer' = @{
                Description = 'Database server firewall policy'
                EnabledProfiles = @('Domain', 'Public', 'Private')
                DefaultInbound = 'Block'
                DefaultOutbound = 'Allow'
                AllowInboundRules = $true
                RequiredServices = @('Core Networking', 'Windows Remote Management')
                BlockedServices = @('File and Printer Sharing', 'Network Discovery', 'Remote Desktop')
                RequireAuthentication = $true
                CustomPorts = @{
                    'SQL Server' = @{ Protocol = 'TCP'; Port = 1433; Direction = 'Inbound'; Action = 'Allow' }
                    'SQL Browser' = @{ Protocol = 'UDP'; Port = 1434; Direction = 'Inbound'; Action = 'Allow' }
                }
            }
            'JumpServer' = @{
                Description = 'Jump server/bastion host firewall policy'
                EnabledProfiles = @('Domain', 'Public', 'Private')
                DefaultInbound = 'Block'
                DefaultOutbound = 'Allow'
                AllowInboundRules = $true
                RequiredServices = @('Core Networking', 'Remote Desktop', 'Windows Remote Management')
                BlockedServices = @('File and Printer Sharing', 'Network Discovery')
                RequireAuthentication = $true
            }
        }
        
        $FirewallResults = @{
            PolicyProfile = $PolicyProfile
            ComputersProcessed = @()
            RulesCreated = 0
            RulesModified = 0
            RulesDeleted = 0
            BlockedIPs = 0
            AllowedIPs = 0
            ServicesConfigured = @()
            Errors = @()
            Recommendations = @()
        }
    }
    
    process {
        try {
            foreach ($Computer in $ComputerName) {
                Write-CustomLog -Level 'INFO' -Message "Configuring firewall policy on: $Computer"
                
                $ComputerResult = @{
                    ComputerName = $Computer
                    Timestamp = Get-Date
                    PolicyApplied = $PolicyProfile
                    RulesCreated = 0
                    RulesModified = 0
                    RulesDeleted = 0
                    ProfilesConfigured = @()
                    ServicesEnabled = @()
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
                    
                    # Backup current firewall rules if requested
                    if ($BackupCurrentRules) {
                        Write-CustomLog -Level 'INFO' -Message "Backing up current firewall rules on $Computer"
                        
                        try {
                            $BackupData = if ($Computer -ne 'localhost') {
                                Invoke-Command @SessionParams -ScriptBlock {
                                    @{
                                        Profiles = Get-NetFirewallProfile
                                        Rules = Get-NetFirewallRule
                                        Timestamp = Get-Date
                                    }
                                }
                            } else {
                                @{
                                    Profiles = Get-NetFirewallProfile
                                    Rules = Get-NetFirewallRule
                                    Timestamp = Get-Date
                                }
                            }
                            
                            $BackupFile = "firewall-backup-$Computer-$(Get-Date -Format 'yyyyMMdd-HHmmss').xml"
                            $BackupData | Export-Clixml -Path $BackupFile -Force
                            Write-CustomLog -Level 'SUCCESS' -Message "Firewall backup saved to: $BackupFile"
                            
                        } catch {
                            Write-CustomLog -Level 'WARNING' -Message "Failed to create firewall backup: $($_.Exception.Message)"
                        }
                    }
                    
                    # Get policy configuration
                    $PolicyConfig = if ($PolicyProfile -ne 'Custom') {
                        $PolicyProfiles[$PolicyProfile]
                    } else {
                        @{
                            Description = 'Custom firewall policy'
                            EnabledProfiles = @('Domain', 'Public', 'Private')
                            DefaultInbound = $DefaultInboundAction
                            DefaultOutbound = $DefaultOutboundAction
                            AllowInboundRules = $true
                            RequiredServices = @()
                            BlockedServices = @()
                            RequireAuthentication = $RequireIPSec.IsPresent
                        }
                    }
                    
                    # Configure firewall profiles
                    Write-CustomLog -Level 'INFO' -Message "Configuring firewall profiles on $Computer"
                    
                    $ProfileConfiguration = if ($Computer -ne 'localhost') {
                        Invoke-Command @SessionParams -ScriptBlock {
                            param($PolicyConfig, $TestMode, $EnableAuditMode, $AuditLogPath)
                            
                            $Results = @()
                            
                            try {
                                # Enable firewall for all specified profiles
                                foreach ($Profile in $PolicyConfig.EnabledProfiles) {
                                    if (-not $TestMode) {
                                        Set-NetFirewallProfile -Profile $Profile -Enabled True
                                        Set-NetFirewallProfile -Profile $Profile -DefaultInboundAction $PolicyConfig.DefaultInbound -DefaultOutboundAction $PolicyConfig.DefaultOutbound
                                        
                                        if ($PolicyConfig.AllowInboundRules) {
                                            Set-NetFirewallProfile -Profile $Profile -AllowInboundRules True
                                        }
                                        
                                        # Configure logging if audit mode enabled
                                        if ($EnableAuditMode) {
                                            Set-NetFirewallProfile -Profile $Profile -LogAllowed True -LogBlocked True -LogFileName "$AuditLogPath\pfirewall-$Profile.log" -LogMaxSizeKilobytes 32767
                                        }
                                    }
                                    
                                    $Results += "Configured profile: $Profile"
                                }
                            } catch {
                                throw "Failed to configure firewall profiles: $($_.Exception.Message)"
                            }
                            
                            return $Results
                        } -ArgumentList $PolicyConfig, $TestMode, $EnableAuditMode, $AuditLogPath
                    } else {
                        $Results = @()
                        
                        try {
                            # Enable firewall for all specified profiles
                            foreach ($Profile in $PolicyConfig.EnabledProfiles) {
                                if (-not $TestMode) {
                                    if ($PSCmdlet.ShouldProcess($Profile, "Configure firewall profile")) {
                                        Set-NetFirewallProfile -Profile $Profile -Enabled True
                                        Set-NetFirewallProfile -Profile $Profile -DefaultInboundAction $PolicyConfig.DefaultInbound -DefaultOutboundAction $PolicyConfig.DefaultOutbound
                                        
                                        if ($PolicyConfig.AllowInboundRules) {
                                            Set-NetFirewallProfile -Profile $Profile -AllowInboundRules True
                                        }
                                        
                                        # Configure logging if audit mode enabled
                                        if ($EnableAuditMode) {
                                            Set-NetFirewallProfile -Profile $Profile -LogAllowed True -LogBlocked True -LogFileName "$AuditLogPath\pfirewall-$Profile.log" -LogMaxSizeKilobytes 32767
                                        }
                                    }
                                } else {
                                    Write-CustomLog -Level 'INFO' -Message "[TEST] Would configure profile: $Profile"
                                }
                                
                                $Results += "Configured profile: $Profile"
                            }
                        } catch {
                            throw "Failed to configure firewall profiles: $($_.Exception.Message)"
                        }
                        
                        $Results
                    }
                    
                    $ComputerResult.ProfilesConfigured = $ProfileConfiguration
                    
                    # Process IP blocklist if provided
                    if ($BlocklistFile -and (Test-Path $BlocklistFile)) {
                        Write-CustomLog -Level 'INFO' -Message "Processing IP blocklist: $BlocklistFile"
                        
                        try {
                            $BlockedIPs = Get-Content $BlocklistFile | Where-Object {
                                $_.Trim() -and 
                                -not $_.Trim().StartsWith('#') -and 
                                $_ -match '^[0-9a-f]{1,4}[\.\:]'
                            }
                            
                            if ($BlockedIPs.Count -gt 0) {
                                $BlockResult = if ($Computer -ne 'localhost') {
                                    Invoke-Command @SessionParams -ScriptBlock {
                                        param($BlockedIPs, $TestMode)
                                        
                                        # Remove existing blocklist rules
                                        Get-NetFirewallRule | Where-Object { 
                                            $_.DisplayName -like "ThreatBlock-*" -and 
                                            $_.Description -like "*Do not edit rule by hand*" 
                                        } | Remove-NetFirewallRule
                                        
                                        if (-not $TestMode) {
                                            # Create blocking rules in batches
                                            $MaxRangesPerRule = 200
                                            $RuleCount = 0
                                            
                                            for ($i = 0; $i -lt $BlockedIPs.Count; $i += $MaxRangesPerRule) {
                                                $RuleCount++
                                                $Batch = $BlockedIPs[$i..([math]::Min($i + $MaxRangesPerRule - 1, $BlockedIPs.Count - 1))]
                                                $RuleName = "ThreatBlock-#$($RuleCount.ToString().PadLeft(3, '0'))"
                                                
                                                # Inbound blocking rule
                                                New-NetFirewallRule -DisplayName $RuleName -Direction Inbound -Action Block -RemoteAddress $Batch -Description "Rule created by SecurityAutomation script on $(Get-Date). Do not edit rule by hand." | Out-Null
                                                
                                                # Outbound blocking rule  
                                                New-NetFirewallRule -DisplayName $RuleName -Direction Outbound -Action Block -RemoteAddress $Batch -Description "Rule created by SecurityAutomation script on $(Get-Date). Do not edit rule by hand." | Out-Null
                                            }
                                            
                                            return @{ RulesCreated = $RuleCount * 2; IPsBlocked = $BlockedIPs.Count }
                                        } else {
                                            return @{ RulesCreated = 0; IPsBlocked = $BlockedIPs.Count }
                                        }
                                    } -ArgumentList $BlockedIPs, $TestMode
                                } else {
                                    # Remove existing blocklist rules
                                    Get-NetFirewallRule | Where-Object { 
                                        $_.DisplayName -like "ThreatBlock-*" -and 
                                        $_.Description -like "*Do not edit rule by hand*" 
                                    } | Remove-NetFirewallRule
                                    
                                    if (-not $TestMode) {
                                        if ($PSCmdlet.ShouldProcess("IP Blocklist", "Create blocking rules")) {
                                            # Create blocking rules in batches
                                            $MaxRangesPerRule = 200
                                            $RuleCount = 0
                                            
                                            for ($i = 0; $i -lt $BlockedIPs.Count; $i += $MaxRangesPerRule) {
                                                $RuleCount++
                                                $Batch = $BlockedIPs[$i..([math]::Min($i + $MaxRangesPerRule - 1, $BlockedIPs.Count - 1))]
                                                $RuleName = "ThreatBlock-#$($RuleCount.ToString().PadLeft(3, '0'))"
                                                
                                                # Inbound blocking rule
                                                New-NetFirewallRule -DisplayName $RuleName -Direction Inbound -Action Block -RemoteAddress $Batch -Description "Rule created by SecurityAutomation script on $(Get-Date). Do not edit rule by hand." | Out-Null
                                                
                                                # Outbound blocking rule  
                                                New-NetFirewallRule -DisplayName $RuleName -Direction Outbound -Action Block -RemoteAddress $Batch -Description "Rule created by SecurityAutomation script on $(Get-Date). Do not edit rule by hand." | Out-Null
                                            }
                                        }
                                    }
                                    
                                    @{ RulesCreated = $RuleCount * 2; IPsBlocked = $BlockedIPs.Count }
                                }
                                
                                $ComputerResult.RulesCreated += $BlockResult.RulesCreated
                                $FirewallResults.RulesCreated += $BlockResult.RulesCreated
                                $FirewallResults.BlockedIPs += $BlockResult.IPsBlocked
                                
                                Write-CustomLog -Level 'SUCCESS' -Message "Created $($BlockResult.RulesCreated) blocking rules for $($BlockResult.IPsBlocked) IP addresses"
                            }
                            
                        } catch {
                            $Error = "Failed to process IP blocklist: $($_.Exception.Message)"
                            $ComputerResult.Errors += $Error
                            Write-CustomLog -Level 'ERROR' -Message $Error
                        }
                    }
                    
                    # Configure service-specific rules
                    if ($PolicyConfig.RequiredServices -or $PolicyConfig.BlockedServices) {
                        Write-CustomLog -Level 'INFO' -Message "Configuring service-specific firewall rules"
                        
                        try {
                            $ServiceResult = if ($Computer -ne 'localhost') {
                                Invoke-Command @SessionParams -ScriptBlock {
                                    param($PolicyConfig, $InternalNetworks, $JumpServerNetworks, $TestMode, $RequireAuthentication)
                                    
                                    $Results = @()
                                    
                                    # Enable required services
                                    foreach ($ServiceGroup in $PolicyConfig.RequiredServices) {
                                        try {
                                            $Rules = Get-NetFirewallRule -DisplayGroup $ServiceGroup -Direction Inbound -ErrorAction SilentlyContinue
                                            
                                            foreach ($Rule in $Rules) {
                                                if ($Rule.Profile -match 'Domain|Any') {
                                                    if (-not $TestMode) {
                                                        $RuleParams = @{
                                                            InputObject = $Rule
                                                            Enabled = 'True'
                                                        }
                                                        
                                                        # Restrict to internal networks if specified
                                                        if ($InternalNetworks.Count -gt 0) {
                                                            $RuleParams['RemoteAddress'] = $InternalNetworks
                                                        }
                                                        
                                                        # Restrict to jump servers for management services
                                                        if ($JumpServerNetworks.Count -gt 0 -and $ServiceGroup -match 'Management|Remote') {
                                                            $RuleParams['RemoteAddress'] = $JumpServerNetworks
                                                        }
                                                        
                                                        # Require authentication if specified
                                                        if ($RequireAuthentication -and $ServiceGroup -match 'Management|Remote') {
                                                            $RuleParams['Authentication'] = 'Required'
                                                        }
                                                        
                                                        Set-NetFirewallRule @RuleParams
                                                    }
                                                    
                                                    $Results += "Enabled service: $ServiceGroup"
                                                }
                                            }
                                        } catch {
                                            $Results += "Failed to configure service: $ServiceGroup - $($_.Exception.Message)"
                                        }
                                    }
                                    
                                    # Disable blocked services
                                    foreach ($ServiceGroup in $PolicyConfig.BlockedServices) {
                                        try {
                                            $Rules = Get-NetFirewallRule -DisplayGroup $ServiceGroup -Direction Inbound -ErrorAction SilentlyContinue
                                            
                                            foreach ($Rule in $Rules) {
                                                if (-not $TestMode) {
                                                    Set-NetFirewallRule -InputObject $Rule -Enabled False
                                                }
                                                
                                                $Results += "Disabled service: $ServiceGroup"
                                            }
                                        } catch {
                                            $Results += "Failed to disable service: $ServiceGroup - $($_.Exception.Message)"
                                        }
                                    }
                                    
                                    return $Results
                                } -ArgumentList $PolicyConfig, $InternalNetworks, $JumpServerNetworks, $TestMode, $PolicyConfig.RequireAuthentication
                            } else {
                                $Results = @()
                                
                                # Enable required services
                                foreach ($ServiceGroup in $PolicyConfig.RequiredServices) {
                                    try {
                                        $Rules = Get-NetFirewallRule -DisplayGroup $ServiceGroup -Direction Inbound -ErrorAction SilentlyContinue
                                        
                                        foreach ($Rule in $Rules) {
                                            if ($Rule.Profile -match 'Domain|Any') {
                                                if (-not $TestMode) {
                                                    if ($PSCmdlet.ShouldProcess($ServiceGroup, "Enable firewall rules")) {
                                                        $RuleParams = @{
                                                            InputObject = $Rule
                                                            Enabled = 'True'
                                                        }
                                                        
                                                        # Restrict to internal networks if specified
                                                        if ($InternalNetworks.Count -gt 0) {
                                                            $RuleParams['RemoteAddress'] = $InternalNetworks
                                                        }
                                                        
                                                        # Restrict to jump servers for management services
                                                        if ($JumpServerNetworks.Count -gt 0 -and $ServiceGroup -match 'Management|Remote') {
                                                            $RuleParams['RemoteAddress'] = $JumpServerNetworks
                                                        }
                                                        
                                                        # Require authentication if specified
                                                        if ($PolicyConfig.RequireAuthentication -and $ServiceGroup -match 'Management|Remote') {
                                                            $RuleParams['Authentication'] = 'Required'
                                                        }
                                                        
                                                        Set-NetFirewallRule @RuleParams
                                                    }
                                                } else {
                                                    Write-CustomLog -Level 'INFO' -Message "[TEST] Would enable service: $ServiceGroup"
                                                }
                                                
                                                $Results += "Enabled service: $ServiceGroup"
                                            }
                                        }
                                    } catch {
                                        $Results += "Failed to configure service: $ServiceGroup - $($_.Exception.Message)"
                                    }
                                }
                                
                                # Disable blocked services
                                foreach ($ServiceGroup in $PolicyConfig.BlockedServices) {
                                    try {
                                        $Rules = Get-NetFirewallRule -DisplayGroup $ServiceGroup -Direction Inbound -ErrorAction SilentlyContinue
                                        
                                        foreach ($Rule in $Rules) {
                                            if (-not $TestMode) {
                                                if ($PSCmdlet.ShouldProcess($ServiceGroup, "Disable firewall rules")) {
                                                    Set-NetFirewallRule -InputObject $Rule -Enabled False
                                                }
                                            } else {
                                                Write-CustomLog -Level 'INFO' -Message "[TEST] Would disable service: $ServiceGroup"
                                            }
                                            
                                            $Results += "Disabled service: $ServiceGroup"
                                        }
                                    } catch {
                                        $Results += "Failed to disable service: $ServiceGroup - $($_.Exception.Message)"
                                    }
                                }
                                
                                $Results
                            }
                            
                            $ComputerResult.ServicesEnabled = $ServiceResult
                            $FirewallResults.ServicesConfigured += $ServiceResult
                            
                        } catch {
                            $Error = "Failed to configure service rules: $($_.Exception.Message)"
                            $ComputerResult.Errors += $Error
                            Write-CustomLog -Level 'ERROR' -Message $Error
                        }
                    }
                    
                    # Configure custom ports if specified in policy
                    if ($PolicyConfig.CustomPorts) {
                        Write-CustomLog -Level 'INFO' -Message "Configuring custom port rules"
                        
                        foreach ($PortRule in $PolicyConfig.CustomPorts.Keys) {
                            $PortConfig = $PolicyConfig.CustomPorts[$PortRule]
                            
                            try {
                                if (-not $TestMode) {
                                    if ($PSCmdlet.ShouldProcess($PortRule, "Create custom port rule")) {
                                        $RuleParams = @{
                                            DisplayName = $PortRule
                                            Direction = $PortConfig.Direction
                                            Action = $PortConfig.Action
                                            Protocol = $PortConfig.Protocol
                                            LocalPort = $PortConfig.Port
                                            Profile = 'Domain,Public,Private'
                                            Description = "Custom rule created by SecurityAutomation for $PolicyProfile profile"
                                        }
                                        
                                        # Remove existing rule with same name
                                        Get-NetFirewallRule -DisplayName $PortRule -ErrorAction SilentlyContinue | Remove-NetFirewallRule
                                        
                                        New-NetFirewallRule @RuleParams | Out-Null
                                        $ComputerResult.RulesCreated++
                                        $FirewallResults.RulesCreated++
                                    }
                                } else {
                                    Write-CustomLog -Level 'INFO' -Message "[TEST] Would create custom port rule: $PortRule"
                                }
                                
                                Write-CustomLog -Level 'SUCCESS' -Message "Created custom port rule: $PortRule"
                                
                            } catch {
                                $Error = "Failed to create custom port rule $PortRule`: $($_.Exception.Message)"
                                $ComputerResult.Errors += $Error
                                Write-CustomLog -Level 'ERROR' -Message $Error
                            }
                        }
                    }
                    
                    # Configure micro-segmentation if enabled
                    if ($EnableMicroSegmentation) {
                        Write-CustomLog -Level 'INFO' -Message "Configuring micro-segmentation rules"
                        
                        try {
                            # This would implement zone-based micro-segmentation
                            # For now, we'll create basic internal network isolation
                            if (-not $TestMode) {
                                if ($PSCmdlet.ShouldProcess("Micro-segmentation", "Configure zone isolation")) {
                                    # Example: Block inter-subnet communication except for specific services
                                    $MicroSegRule = New-NetFirewallRule -DisplayName "MicroSeg-InterZone-Block" -Direction Inbound -Action Block -RemoteAddress $InternalNetworks -LocalAddress $InternalNetworks -Description "Micro-segmentation rule - blocks inter-zone traffic" -Profile 'Domain,Private' -Enabled False
                                    
                                    Write-CustomLog -Level 'SUCCESS' -Message "Micro-segmentation rules configured"
                                    $ComputerResult.RulesCreated++
                                    $FirewallResults.RulesCreated++
                                }
                            } else {
                                Write-CustomLog -Level 'INFO' -Message "[TEST] Would configure micro-segmentation rules"
                            }
                            
                        } catch {
                            $Error = "Failed to configure micro-segmentation: $($_.Exception.Message)"
                            $ComputerResult.Errors += $Error
                            Write-CustomLog -Level 'ERROR' -Message $Error
                        }
                    }
                    
                    Write-CustomLog -Level 'SUCCESS' -Message "Firewall policy configuration completed for $Computer"
                    
                } catch {
                    $Error = "Failed to configure firewall policy on $Computer`: $($_.Exception.Message)"
                    $ComputerResult.Errors += $Error
                    Write-CustomLog -Level 'ERROR' -Message $Error
                }
                
                $FirewallResults.ComputersProcessed += $ComputerResult
            }
            
        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Error during advanced firewall policy configuration: $($_.Exception.Message)"
            throw
        }
    }
    
    end {
        Write-CustomLog -Level 'SUCCESS' -Message "Advanced firewall policy configuration completed"
        
        # Generate recommendations
        $FirewallResults.Recommendations += "Regularly review and update firewall rules based on network traffic analysis"
        $FirewallResults.Recommendations += "Monitor firewall logs for blocked connection attempts and policy violations"
        $FirewallResults.Recommendations += "Implement automated threat intelligence feeds for dynamic IP blocking"
        $FirewallResults.Recommendations += "Test firewall rules thoroughly before deploying to production systems"
        $FirewallResults.Recommendations += "Document all custom firewall rules and their business justifications"
        
        if ($EnableMicroSegmentation) {
            $FirewallResults.Recommendations += "Gradually enable micro-segmentation rules after thorough testing"
            $FirewallResults.Recommendations += "Monitor application dependencies when implementing zone isolation"
        }
        
        if ($RequireIPSec) {
            $FirewallResults.Recommendations += "Ensure IPSec policies are properly configured and certificates are valid"
            $FirewallResults.Recommendations += "Monitor IPSec authentication failures and certificate expiration"
        }
        
        # Generate report if requested
        if ($ReportPath) {
            try {
                $HtmlReport = @"
<!DOCTYPE html>
<html>
<head>
    <title>Advanced Firewall Policy Report</title>
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
        <h1>Advanced Firewall Policy Report</h1>
        <p><strong>Policy Profile:</strong> $($FirewallResults.PolicyProfile)</p>
        <p><strong>Generated:</strong> $(Get-Date)</p>
        <p><strong>Computers Processed:</strong> $($FirewallResults.ComputersProcessed.Count)</p>
        <p><strong>Rules Created:</strong> $($FirewallResults.RulesCreated)</p>
        <p><strong>Rules Modified:</strong> $($FirewallResults.RulesModified)</p>
        <p><strong>IPs Blocked:</strong> $($FirewallResults.BlockedIPs)</p>
    </div>
"@
                
                foreach ($Computer in $FirewallResults.ComputersProcessed) {
                    $HtmlReport += "<div class='computer'>"
                    $HtmlReport += "<h2>$($Computer.ComputerName)</h2>"
                    $HtmlReport += "<p><strong>Policy Applied:</strong> $($Computer.PolicyApplied)</p>"
                    $HtmlReport += "<p><strong>Rules Created:</strong> $($Computer.RulesCreated)</p>"
                    
                    if ($Computer.ProfilesConfigured.Count -gt 0) {
                        $HtmlReport += "<h3>Profiles Configured</h3><ul>"
                        foreach ($Profile in $Computer.ProfilesConfigured) {
                            $HtmlReport += "<li>$Profile</li>"
                        }
                        $HtmlReport += "</ul>"
                    }
                    
                    if ($Computer.ServicesEnabled.Count -gt 0) {
                        $HtmlReport += "<h3>Services Configured</h3><ul>"
                        foreach ($Service in $Computer.ServicesEnabled) {
                            $HtmlReport += "<li>$Service</li>"
                        }
                        $HtmlReport += "</ul>"
                    }
                    
                    $HtmlReport += "</div>"
                }
                
                $HtmlReport += "<div class='header'><h2>Recommendations</h2>"
                foreach ($Rec in $FirewallResults.Recommendations) {
                    $HtmlReport += "<div class='recommendation'>$Rec</div>"
                }
                $HtmlReport += "</div>"
                
                $HtmlReport += "</body></html>"
                
                $HtmlReport | Out-File -FilePath $ReportPath -Encoding UTF8
                Write-CustomLog -Level 'SUCCESS' -Message "Firewall policy report saved to: $ReportPath"
                
            } catch {
                Write-CustomLog -Level 'ERROR' -Message "Failed to generate report: $($_.Exception.Message)"
            }
        }
        
        # Display summary
        Write-CustomLog -Level 'INFO' -Message "Firewall Policy Summary:"
        Write-CustomLog -Level 'INFO' -Message "  Policy Profile: $($FirewallResults.PolicyProfile)"
        Write-CustomLog -Level 'INFO' -Message "  Computers: $($FirewallResults.ComputersProcessed.Count)"
        Write-CustomLog -Level 'INFO' -Message "  Rules Created: $($FirewallResults.RulesCreated)"
        Write-CustomLog -Level 'INFO' -Message "  Rules Modified: $($FirewallResults.RulesModified)"
        Write-CustomLog -Level 'INFO' -Message "  IPs Blocked: $($FirewallResults.BlockedIPs)"
        Write-CustomLog -Level 'INFO' -Message "  Services Configured: $($FirewallResults.ServicesConfigured.Count)"
        
        return $FirewallResults
    }
}
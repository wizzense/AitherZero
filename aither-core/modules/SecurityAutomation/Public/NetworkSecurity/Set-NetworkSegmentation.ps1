function Set-NetworkSegmentation {
    <#
    .SYNOPSIS
        Configures network segmentation policies using Windows Firewall and routing.
        
    .DESCRIPTION
        Implements network micro-segmentation by creating firewall rules and routing
        policies to isolate network zones, control inter-subnet communication, and
        implement zero-trust network architectures.
        
    .PARAMETER SegmentationProfile
        Predefined segmentation profile to apply
        
    .PARAMETER ComputerName
        Target computers for segmentation configuration. Default: localhost
        
    .PARAMETER Credential
        Credentials for remote computer access
        
    .PARAMETER NetworkZones
        Hashtable defining network zones and their IP ranges
        
    .PARAMETER ZoneIsolationRules
        Array of zone isolation rules to implement
        
    .PARAMETER AllowedCommunication
        Hashtable defining allowed communication between zones
        
    .PARAMETER CriticalAssets
        Array of critical asset IP ranges requiring maximum isolation
        
    .PARAMETER ManagementNetworks
        Array of management network ranges with special access
        
    .PARAMETER JumpServerNetworks
        Array of jump server networks for administrative access
        
    .PARAMETER DefaultPolicy
        Default action for inter-zone traffic: Allow, Block, or Audit
        
    .PARAMETER EnableMicroSegmentation
        Enable micro-segmentation between individual hosts
        
    .PARAMETER EnableZoneBasedAccess
        Enable zone-based access control
        
    .PARAMETER RequireIPSec
        Require IPSec for inter-zone communication
        
    .PARAMETER EnableTrafficMonitoring
        Enable detailed traffic monitoring and logging
        
    .PARAMETER MonitoringLogPath
        Custom path for traffic monitoring logs
        
    .PARAMETER AuditMode
        Run in audit mode to log potential blocks without enforcing
        
    .PARAMETER EmergencyBypass
        Create emergency bypass rules for critical services
        
    .PARAMETER TestMode
        Show what would be configured without making changes
        
    .PARAMETER ReportPath
        Path to save network segmentation report
        
    .EXAMPLE
        Set-NetworkSegmentation -SegmentationProfile 'Enterprise' -EnableZoneBasedAccess
        
    .EXAMPLE
        $Zones = @{
            'DMZ' = '10.1.0.0/24'
            'Internal' = '10.2.0.0/24'
            'Management' = '10.3.0.0/24'
        }
        Set-NetworkSegmentation -NetworkZones $Zones -DefaultPolicy 'Block'
        
    .EXAMPLE
        Set-NetworkSegmentation -SegmentationProfile 'ZeroTrust' -RequireIPSec -EnableTrafficMonitoring
    #>
    
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter()]
        [ValidateSet('Basic', 'Enterprise', 'ZeroTrust', 'HighSecurity', 'Custom')]
        [string]$SegmentationProfile = 'Enterprise',
        
        [Parameter()]
        [string[]]$ComputerName = @('localhost'),
        
        [Parameter()]
        [pscredential]$Credential,
        
        [Parameter()]
        [hashtable]$NetworkZones,
        
        [Parameter()]
        [array]$ZoneIsolationRules,
        
        [Parameter()]
        [hashtable]$AllowedCommunication,
        
        [Parameter()]
        [string[]]$CriticalAssets = @(),
        
        [Parameter()]
        [string[]]$ManagementNetworks = @('10.255.0.0/24'),
        
        [Parameter()]
        [string[]]$JumpServerNetworks = @(),
        
        [Parameter()]
        [ValidateSet('Allow', 'Block', 'Audit')]
        [string]$DefaultPolicy = 'Block',
        
        [Parameter()]
        [switch]$EnableMicroSegmentation,
        
        [Parameter()]
        [switch]$EnableZoneBasedAccess,
        
        [Parameter()]
        [switch]$RequireIPSec,
        
        [Parameter()]
        [switch]$EnableTrafficMonitoring,
        
        [Parameter()]
        [string]$MonitoringLogPath = 'C:\\Windows\\System32\\LogFiles\\Firewall\\Segmentation',
        
        [Parameter()]
        [switch]$AuditMode,
        
        [Parameter()]
        [switch]$EmergencyBypass,
        
        [Parameter()]
        [switch]$TestMode,
        
        [Parameter()]
        [string]$ReportPath
    )
    
    begin {
        Write-CustomLog -Level 'INFO' -Message "Configuring network segmentation: $SegmentationProfile"
        
        # Check if running as Administrator
        $CurrentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
        $Principal = New-Object Security.Principal.WindowsPrincipal($CurrentUser)
        if (-not $Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            throw "This function requires Administrator privileges"
        }
        
        # Define segmentation profiles
        $SegmentationProfiles = @{
            'Basic' = @{
                Description = 'Basic network segmentation with simple zone isolation'
                DefaultZones = @{
                    'Internal' = '10.0.0.0/8'
                    'DMZ' = '172.16.0.0/16'
                    'Management' = '192.168.255.0/24'
                }
                DefaultPolicy = 'Allow'
                RequireIPSec = $false
                MicroSegmentation = $false
                TrafficMonitoring = $false
            }
            'Enterprise' = @{
                Description = 'Enterprise-grade network segmentation with zone controls'
                DefaultZones = @{
                    'Production' = '10.1.0.0/16'
                    'Development' = '10.2.0.0/16'
                    'DMZ' = '10.10.0.0/16'
                    'Management' = '10.255.0.0/24'
                    'External' = '172.16.0.0/12'
                }
                DefaultPolicy = 'Block'
                RequireIPSec = $false
                MicroSegmentation = $true
                TrafficMonitoring = $true
            }
            'ZeroTrust' = @{
                Description = 'Zero-trust network segmentation with strict controls'
                DefaultZones = @{
                    'TrustedAssets' = '10.1.0.0/24'
                    'StandardAssets' = '10.2.0.0/16'
                    'UnknownAssets' = '10.3.0.0/16'
                    'DMZ' = '10.10.0.0/16'
                    'Management' = '10.255.0.0/24'
                }
                DefaultPolicy = 'Block'
                RequireIPSec = $true
                MicroSegmentation = $true
                TrafficMonitoring = $true
            }
            'HighSecurity' = @{
                Description = 'Maximum security network segmentation'
                DefaultZones = @{
                    'Critical' = '10.1.0.0/24'
                    'Sensitive' = '10.2.0.0/24'
                    'Standard' = '10.3.0.0/16'
                    'DMZ' = '10.10.0.0/16'
                    'Management' = '10.255.0.0/24'
                    'Quarantine' = '10.254.0.0/24'
                }
                DefaultPolicy = 'Block'
                RequireIPSec = $true
                MicroSegmentation = $true
                TrafficMonitoring = $true
            }
        }
        
        $SegmentationResults = @{
            Profile = $SegmentationProfile
            ComputersProcessed = @()
            ZonesConfigured = @()
            RulesCreated = 0
            RulesModified = 0
            IsolationRulesApplied = 0
            TrafficRulesCreated = 0
            EmergencyRulesCreated = 0
            Errors = @()
            Recommendations = @()
        }
        
        # Ensure monitoring log directory exists if needed
        if ($EnableTrafficMonitoring -and -not (Test-Path $MonitoringLogPath)) {
            New-Item -Path $MonitoringLogPath -ItemType Directory -Force | Out-Null
        }
    }
    
    process {
        try {
            foreach ($Computer in $ComputerName) {
                Write-CustomLog -Level 'INFO' -Message "Configuring network segmentation on: $Computer"
                
                $ComputerResult = @{
                    ComputerName = $Computer
                    Timestamp = Get-Date
                    ProfileApplied = $SegmentationProfile
                    ZonesConfigured = @()
                    RulesCreated = 0
                    IsolationRules = 0
                    TrafficRules = 0
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
                    $ProfileConfig = if ($SegmentationProfile -ne 'Custom') {
                        $SegmentationProfiles[$SegmentationProfile]
                    } else {
                        @{
                            Description = 'Custom network segmentation'
                            DefaultZones = $NetworkZones
                            DefaultPolicy = $DefaultPolicy
                            RequireIPSec = $RequireIPSec.IsPresent
                            MicroSegmentation = $EnableMicroSegmentation.IsPresent
                            TrafficMonitoring = $EnableTrafficMonitoring.IsPresent
                        }
                    }
                    
                    # Merge provided zones with profile defaults
                    $ActiveZones = if ($NetworkZones) {
                        $NetworkZones
                    } else {
                        $ProfileConfig.DefaultZones
                    }
                    
                    Write-CustomLog -Level 'INFO' -Message "Configuring $($ActiveZones.Count) network zones"
                    
                    # Configure network zones and segmentation rules
                    $ZoneResult = if ($Computer -ne 'localhost') {
                        Invoke-Command @SessionParams -ScriptBlock {
                            param($ActiveZones, $ProfileConfig, $DefaultPolicy, $EnableZoneBasedAccess, $RequireIPSec, $TestMode, $AuditMode)
                            
                            $Results = @{
                                ZonesConfigured = @()
                                RulesCreated = 0
                                IsolationRules = 0
                                TrafficRules = 0
                                Errors = @()
                            }
                            
                            try {
                                # Remove existing segmentation rules
                                Get-NetFirewallRule | Where-Object { 
                                    $_.DisplayName -like "NetSeg-*" -and 
                                    $_.Description -like "*Network Segmentation*" 
                                } | Remove-NetFirewallRule
                                
                                # Create zone isolation rules
                                if ($EnableZoneBasedAccess) {
                                    $ZoneNames = $ActiveZones.Keys
                                    
                                    foreach ($SourceZone in $ZoneNames) {
                                        foreach ($DestZone in $ZoneNames) {
                                            if ($SourceZone -ne $DestZone) {
                                                $RuleName = "NetSeg-$SourceZone-to-$DestZone"
                                                $SourceRange = $ActiveZones[$SourceZone]
                                                $DestRange = $ActiveZones[$DestZone]
                                                
                                                if (-not $TestMode) {
                                                    $RuleParams = @{
                                                        DisplayName = $RuleName
                                                        Direction = 'Inbound'
                                                        Action = if ($AuditMode) { 'Allow' } else { $DefaultPolicy }
                                                        RemoteAddress = $SourceRange
                                                        LocalAddress = $DestRange
                                                        Description = "Network Segmentation: $SourceZone to $DestZone zone traffic control"
                                                        Profile = 'Domain,Private,Public'
                                                        Enabled = $true
                                                    }
                                                    
                                                    if ($RequireIPSec) {
                                                        $RuleParams['Authentication'] = 'Required'
                                                    }
                                                    
                                                    if ($AuditMode) {
                                                        $RuleParams['LogFileName'] = "C:\\Windows\\System32\\LogFiles\\Firewall\\Segmentation\\audit-$SourceZone-$DestZone.log"
                                                        $RuleParams['LogBlocked'] = $true
                                                        $RuleParams['LogAllowed'] = $true
                                                    }
                                                    
                                                    New-NetFirewallRule @RuleParams | Out-Null
                                                    $Results.IsolationRules++
                                                }
                                                
                                                $Results.RulesCreated++
                                            }
                                        }
                                        
                                        $Results.ZonesConfigured += "$SourceZone ($($ActiveZones[$SourceZone]))"
                                    }
                                }
                                
                            } catch {
                                $Results.Errors += "Failed to configure zone segmentation: $($_.Exception.Message)"
                            }
                            
                            return $Results
                        } -ArgumentList $ActiveZones, $ProfileConfig, $DefaultPolicy, $EnableZoneBasedAccess, $RequireIPSec, $TestMode, $AuditMode
                    } else {
                        $Results = @{
                            ZonesConfigured = @()
                            RulesCreated = 0
                            IsolationRules = 0
                            TrafficRules = 0
                            Errors = @()
                        }
                        
                        try {
                            # Remove existing segmentation rules
                            Get-NetFirewallRule | Where-Object { 
                                $_.DisplayName -like "NetSeg-*" -and 
                                $_.Description -like "*Network Segmentation*" 
                            } | Remove-NetFirewallRule
                            
                            # Create zone isolation rules
                            if ($EnableZoneBasedAccess) {
                                $ZoneNames = $ActiveZones.Keys
                                
                                foreach ($SourceZone in $ZoneNames) {
                                    foreach ($DestZone in $ZoneNames) {
                                        if ($SourceZone -ne $DestZone) {
                                            $RuleName = "NetSeg-$SourceZone-to-$DestZone"
                                            $SourceRange = $ActiveZones[$SourceZone]
                                            $DestRange = $ActiveZones[$DestZone]
                                            
                                            if (-not $TestMode) {
                                                if ($PSCmdlet.ShouldProcess($RuleName, "Create zone isolation rule")) {
                                                    $RuleParams = @{
                                                        DisplayName = $RuleName
                                                        Direction = 'Inbound'
                                                        Action = if ($AuditMode) { 'Allow' } else { $DefaultPolicy }
                                                        RemoteAddress = $SourceRange
                                                        LocalAddress = $DestRange
                                                        Description = "Network Segmentation: $SourceZone to $DestZone zone traffic control"
                                                        Profile = 'Domain,Private,Public'
                                                        Enabled = $true
                                                    }
                                                    
                                                    if ($RequireIPSec) {
                                                        $RuleParams['Authentication'] = 'Required'
                                                    }
                                                    
                                                    New-NetFirewallRule @RuleParams | Out-Null
                                                    $Results.IsolationRules++
                                                }
                                            } else {
                                                Write-CustomLog -Level 'INFO' -Message "[TEST] Would create zone rule: $RuleName"
                                            }
                                            
                                            $Results.RulesCreated++
                                        }
                                    }
                                    
                                    $Results.ZonesConfigured += "$SourceZone ($($ActiveZones[$SourceZone]))"
                                }
                            }
                            
                        } catch {
                            $Results.Errors += "Failed to configure zone segmentation: $($_.Exception.Message)"
                        }
                        
                        $Results
                    }
                    
                    $ComputerResult.ZonesConfigured = $ZoneResult.ZonesConfigured
                    $ComputerResult.RulesCreated += $ZoneResult.RulesCreated
                    $ComputerResult.IsolationRules = $ZoneResult.IsolationRules
                    $ComputerResult.Errors += $ZoneResult.Errors
                    
                    # Configure micro-segmentation if enabled
                    if ($EnableMicroSegmentation) {
                        Write-CustomLog -Level 'INFO' -Message "Configuring micro-segmentation rules"
                        
                        try {
                            $MicroSegResult = if ($Computer -ne 'localhost') {
                                Invoke-Command @SessionParams -ScriptBlock {
                                    param($ActiveZones, $TestMode, $AuditMode)
                                    
                                    $Rules = 0
                                    
                                    foreach ($Zone in $ActiveZones.Keys) {
                                        $ZoneRange = $ActiveZones[$Zone]
                                        
                                        # Create micro-segmentation rule for intra-zone traffic
                                        $RuleName = "NetSeg-MicroSeg-$Zone"
                                        
                                        if (-not $TestMode) {
                                            $RuleParams = @{
                                                DisplayName = $RuleName
                                                Direction = 'Inbound'
                                                Action = if ($AuditMode) { 'Allow' } else { 'Block' }
                                                RemoteAddress = $ZoneRange
                                                LocalAddress = $ZoneRange
                                                Description = "Network Segmentation: Micro-segmentation within $Zone zone"
                                                Profile = 'Domain,Private,Public'
                                                Enabled = $false  # Disabled by default for safety
                                            }
                                            
                                            New-NetFirewallRule @RuleParams | Out-Null
                                            $Rules++
                                        }
                                    }
                                    
                                    return $Rules
                                } -ArgumentList $ActiveZones, $TestMode, $AuditMode
                            } else {
                                $Rules = 0
                                
                                foreach ($Zone in $ActiveZones.Keys) {
                                    $ZoneRange = $ActiveZones[$Zone]
                                    
                                    # Create micro-segmentation rule for intra-zone traffic
                                    $RuleName = "NetSeg-MicroSeg-$Zone"
                                    
                                    if (-not $TestMode) {
                                        if ($PSCmdlet.ShouldProcess($RuleName, "Create micro-segmentation rule")) {
                                            $RuleParams = @{
                                                DisplayName = $RuleName
                                                Direction = 'Inbound'
                                                Action = if ($AuditMode) { 'Allow' } else { 'Block' }
                                                RemoteAddress = $ZoneRange
                                                LocalAddress = $ZoneRange
                                                Description = "Network Segmentation: Micro-segmentation within $Zone zone"
                                                Profile = 'Domain,Private,Public'
                                                Enabled = $false  # Disabled by default for safety
                                            }
                                            
                                            New-NetFirewallRule @RuleParams | Out-Null
                                            $Rules++
                                        }
                                    } else {
                                        Write-CustomLog -Level 'INFO' -Message "[TEST] Would create micro-segmentation rule: $RuleName"
                                    }
                                }
                                
                                $Rules
                            }
                            
                            $ComputerResult.RulesCreated += $MicroSegResult
                            Write-CustomLog -Level 'SUCCESS' -Message "Created $MicroSegResult micro-segmentation rules"
                            
                        } catch {
                            $Error = "Failed to configure micro-segmentation: $($_.Exception.Message)"
                            $ComputerResult.Errors += $Error
                            Write-CustomLog -Level 'ERROR' -Message $Error
                        }
                    }
                    
                    # Configure management access rules
                    if ($ManagementNetworks.Count -gt 0) {
                        Write-CustomLog -Level 'INFO' -Message "Configuring management network access"
                        
                        try {
                            if (-not $TestMode) {
                                if ($PSCmdlet.ShouldProcess("Management Access", "Configure management network rules")) {
                                    $MgmtRuleParams = @{
                                        DisplayName = "NetSeg-Management-Access"
                                        Direction = 'Inbound'
                                        Action = 'Allow'
                                        RemoteAddress = $ManagementNetworks
                                        Description = "Network Segmentation: Management network access"
                                        Profile = 'Domain,Private,Public'
                                        Enabled = $true
                                    }
                                    
                                    if ($RequireIPSec) {
                                        $MgmtRuleParams['Authentication'] = 'Required'
                                    }
                                    
                                    New-NetFirewallRule @MgmtRuleParams | Out-Null
                                    $ComputerResult.RulesCreated++
                                    
                                    Write-CustomLog -Level 'SUCCESS' -Message "Management access rule created"
                                }
                            } else {
                                Write-CustomLog -Level 'INFO' -Message "[TEST] Would create management access rule"
                            }
                            
                        } catch {
                            $Error = "Failed to configure management access: $($_.Exception.Message)"
                            $ComputerResult.Errors += $Error
                            Write-CustomLog -Level 'ERROR' -Message $Error
                        }
                    }
                    
                    # Configure emergency bypass rules if requested
                    if ($EmergencyBypass) {
                        Write-CustomLog -Level 'INFO' -Message "Configuring emergency bypass rules"
                        
                        try {
                            if (-not $TestMode) {
                                if ($PSCmdlet.ShouldProcess("Emergency Bypass", "Create emergency access rules")) {
                                    # Emergency DNS access
                                    New-NetFirewallRule -DisplayName "NetSeg-Emergency-DNS" -Direction Outbound -Action Allow -Protocol UDP -RemotePort 53 -Description "Network Segmentation: Emergency DNS access" -Profile 'Domain,Private,Public' | Out-Null
                                    
                                    # Emergency DHCP access
                                    New-NetFirewallRule -DisplayName "NetSeg-Emergency-DHCP" -Direction Outbound -Action Allow -Protocol UDP -LocalPort 68 -RemotePort 67 -Description "Network Segmentation: Emergency DHCP access" -Profile 'Domain,Private,Public' | Out-Null
                                    
                                    # Emergency domain authentication
                                    New-NetFirewallRule -DisplayName "NetSeg-Emergency-Kerberos" -Direction Outbound -Action Allow -Protocol TCP -RemotePort 88 -Description "Network Segmentation: Emergency Kerberos access" -Profile 'Domain,Private,Public' | Out-Null
                                    
                                    $ComputerResult.RulesCreated += 3
                                    $SegmentationResults.EmergencyRulesCreated += 3
                                    
                                    Write-CustomLog -Level 'SUCCESS' -Message "Emergency bypass rules created"
                                }
                            } else {
                                Write-CustomLog -Level 'INFO' -Message "[TEST] Would create emergency bypass rules"
                            }
                            
                        } catch {
                            $Error = "Failed to configure emergency bypass: $($_.Exception.Message)"
                            $ComputerResult.Errors += $Error
                            Write-CustomLog -Level 'ERROR' -Message $Error
                        }
                    }
                    
                    # Enable traffic monitoring if requested
                    if ($EnableTrafficMonitoring) {
                        Write-CustomLog -Level 'INFO' -Message "Enabling traffic monitoring"
                        
                        try {
                            if (-not $TestMode) {
                                if ($PSCmdlet.ShouldProcess("Traffic Monitoring", "Enable detailed logging")) {
                                    # Enable logging for all profiles
                                    Set-NetFirewallProfile -Profile Domain,Public,Private -LogAllowed True -LogBlocked True -LogFileName "$MonitoringLogPath\\traffic-monitoring.log" -LogMaxSizeKilobytes 32767
                                    
                                    Write-CustomLog -Level 'SUCCESS' -Message "Traffic monitoring enabled"
                                }
                            } else {
                                Write-CustomLog -Level 'INFO' -Message "[TEST] Would enable traffic monitoring"
                            }
                            
                        } catch {
                            $Error = "Failed to enable traffic monitoring: $($_.Exception.Message)"
                            $ComputerResult.Errors += $Error
                            Write-CustomLog -Level 'ERROR' -Message $Error
                        }
                    }
                    
                    Write-CustomLog -Level 'SUCCESS' -Message "Network segmentation configuration completed for $Computer"
                    
                } catch {
                    $Error = "Failed to configure network segmentation on $Computer`: $($_.Exception.Message)"
                    $ComputerResult.Errors += $Error
                    Write-CustomLog -Level 'ERROR' -Message $Error
                }
                
                $SegmentationResults.ComputersProcessed += $ComputerResult
                $SegmentationResults.RulesCreated += $ComputerResult.RulesCreated
                $SegmentationResults.IsolationRulesApplied += $ComputerResult.IsolationRules
                $SegmentationResults.ZonesConfigured += $ComputerResult.ZonesConfigured
            }
            
        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Error during network segmentation configuration: $($_.Exception.Message)"
            throw
        }
    }
    
    end {
        Write-CustomLog -Level 'SUCCESS' -Message "Network segmentation configuration completed"
        
        # Generate recommendations
        $SegmentationResults.Recommendations += "Test network connectivity thoroughly after implementing segmentation"
        $SegmentationResults.Recommendations += "Monitor application performance for any segmentation-related issues"
        $SegmentationResults.Recommendations += "Gradually enable micro-segmentation rules after testing"
        $SegmentationResults.Recommendations += "Regularly review and update zone definitions based on network changes"
        $SegmentationResults.Recommendations += "Implement network monitoring to detect segmentation bypass attempts"
        
        if ($EnableMicroSegmentation) {
            $SegmentationResults.Recommendations += "Micro-segmentation rules are disabled by default - enable carefully after testing"
            $SegmentationResults.Recommendations += "Consider application dependencies when enabling micro-segmentation"
        }
        
        if ($RequireIPSec) {
            $SegmentationResults.Recommendations += "Ensure IPSec policies are properly configured for required authentication"
            $SegmentationResults.Recommendations += "Monitor IPSec failures and certificate status regularly"
        }
        
        if ($AuditMode) {
            $SegmentationResults.Recommendations += "Review audit logs to understand traffic patterns before enforcing blocks"
            $SegmentationResults.Recommendations += "Plan enforcement timeline based on audit results"
        }
        
        # Generate report if requested
        if ($ReportPath) {
            try {
                $HtmlReport = @"
<!DOCTYPE html>
<html>
<head>
    <title>Network Segmentation Report</title>
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
        <h1>Network Segmentation Report</h1>
        <p><strong>Profile:</strong> $($SegmentationResults.Profile)</p>
        <p><strong>Generated:</strong> $(Get-Date)</p>
        <p><strong>Computers Processed:</strong> $($SegmentationResults.ComputersProcessed.Count)</p>
        <p><strong>Total Rules Created:</strong> $($SegmentationResults.RulesCreated)</p>
        <p><strong>Isolation Rules:</strong> $($SegmentationResults.IsolationRulesApplied)</p>
        <p><strong>Emergency Rules:</strong> $($SegmentationResults.EmergencyRulesCreated)</p>
    </div>
"@
                
                foreach ($Computer in $SegmentationResults.ComputersProcessed) {
                    $HtmlReport += "<div class='computer'>"
                    $HtmlReport += "<h2>$($Computer.ComputerName)</h2>"
                    $HtmlReport += "<p><strong>Profile Applied:</strong> $($Computer.ProfileApplied)</p>"
                    $HtmlReport += "<p><strong>Rules Created:</strong> $($Computer.RulesCreated)</p>"
                    $HtmlReport += "<p><strong>Isolation Rules:</strong> $($Computer.IsolationRules)</p>"
                    
                    if ($Computer.ZonesConfigured.Count -gt 0) {
                        $HtmlReport += "<h3>Zones Configured</h3><ul>"
                        foreach ($Zone in $Computer.ZonesConfigured) {
                            $HtmlReport += "<li>$Zone</li>"
                        }
                        $HtmlReport += "</ul>"
                    }
                    
                    $HtmlReport += "</div>"
                }
                
                $HtmlReport += "<div class='header'><h2>Recommendations</h2>"
                foreach ($Rec in $SegmentationResults.Recommendations) {
                    $HtmlReport += "<div class='recommendation'>$Rec</div>"
                }
                $HtmlReport += "</div>"
                
                $HtmlReport += "</body></html>"
                
                $HtmlReport | Out-File -FilePath $ReportPath -Encoding UTF8
                Write-CustomLog -Level 'SUCCESS' -Message "Network segmentation report saved to: $ReportPath"
                
            } catch {
                Write-CustomLog -Level 'ERROR' -Message "Failed to generate report: $($_.Exception.Message)"
            }
        }
        
        # Display summary
        Write-CustomLog -Level 'INFO' -Message "Network Segmentation Summary:"
        Write-CustomLog -Level 'INFO' -Message "  Profile: $($SegmentationResults.Profile)"
        Write-CustomLog -Level 'INFO' -Message "  Computers: $($SegmentationResults.ComputersProcessed.Count)"
        Write-CustomLog -Level 'INFO' -Message "  Total Rules: $($SegmentationResults.RulesCreated)"
        Write-CustomLog -Level 'INFO' -Message "  Isolation Rules: $($SegmentationResults.IsolationRulesApplied)"
        Write-CustomLog -Level 'INFO' -Message "  Emergency Rules: $($SegmentationResults.EmergencyRulesCreated)"
        Write-CustomLog -Level 'INFO' -Message "  Zones Configured: $($SegmentationResults.ZonesConfigured.Count)"
        
        return $SegmentationResults
    }
}
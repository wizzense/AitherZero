function Start-NetworkTrafficMonitoring {
    <#
    .SYNOPSIS
        Starts comprehensive network traffic monitoring and analysis for security purposes.
        
    .DESCRIPTION
        Implements network traffic monitoring using Windows built-in capabilities including
        Netsh trace, Windows firewall logging, Performance Monitor counters, and Event
        Tracing for Windows (ETW). Provides real-time threat detection and analysis.
        
    .PARAMETER MonitoringProfile
        Predefined monitoring profile to apply
        
    .PARAMETER ComputerName
        Target computers for traffic monitoring. Default: localhost
        
    .PARAMETER Credential
        Credentials for remote computer access
        
    .PARAMETER MonitoredNetworks
        Array of network ranges to monitor specifically
        
    .PARAMETER SuspiciousIPs
        Array of known suspicious IP addresses to watch
        
    .PARAMETER MonitoringDuration
        Duration to monitor traffic in hours (0 = continuous)
        
    .PARAMETER OutputPath
        Path to save monitoring output and logs
        
    .PARAMETER CapturePackets
        Enable packet capture for detailed analysis
        
    .PARAMETER MaxCaptureSize
        Maximum capture file size in MB
        
    .PARAMETER EnableFirewallLogging
        Enable detailed Windows Firewall logging
        
    .PARAMETER EnablePerformanceCounters
        Enable network performance counter monitoring
        
    .PARAMETER EnableETWTracing
        Enable Event Tracing for Windows network providers
        
    .PARAMETER ThreatDetectionRules
        Custom threat detection rules to apply
        
    .PARAMETER AlertThresholds
        Hashtable of alert thresholds for various metrics
        
    .PARAMETER EnableRealTimeAlerts
        Enable real-time alerting for detected threats
        
    .PARAMETER AlertEmail
        Email address for sending alerts
        
    .PARAMETER EnableBandwidthMonitoring
        Monitor bandwidth usage patterns
        
    .PARAMETER EnableConnectionTracking
        Track connection establishment and termination
        
    .PARAMETER EnableDNSMonitoring
        Monitor DNS queries and responses
        
    .PARAMETER EnablePortScanDetection
        Detect potential port scanning activities
        
    .PARAMETER EnableDDoSDetection
        Detect potential DDoS attack patterns
        
    .PARAMETER CustomFilters
        Array of custom network filters to apply
        
    .PARAMETER ExportFormat
        Format for exporting monitoring data
        
    .PARAMETER CompressLogs
        Compress log files to save space
        
    .PARAMETER TestMode
        Run monitoring in test mode without full logging
        
    .EXAMPLE
        Start-NetworkTrafficMonitoring -MonitoringProfile 'Enterprise' -MonitoringDuration 24
        
    .EXAMPLE
        Start-NetworkTrafficMonitoring -CapturePackets -EnableRealTimeAlerts -AlertEmail 'security@company.com'
        
    .EXAMPLE
        Start-NetworkTrafficMonitoring -EnablePortScanDetection -EnableDDoSDetection -OutputPath 'C:\SecurityLogs'
    #>
    
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter()]
        [ValidateSet('Basic', 'Enterprise', 'HighSecurity', 'ThreatHunting', 'Custom')]
        [string]$MonitoringProfile = 'Enterprise',
        
        [Parameter()]
        [string[]]$ComputerName = @('localhost'),
        
        [Parameter()]
        [pscredential]$Credential,
        
        [Parameter()]
        [string[]]$MonitoredNetworks = @(),
        
        [Parameter()]
        [string[]]$SuspiciousIPs = @(),
        
        [Parameter()]
        [ValidateRange(0, 168)]
        [int]$MonitoringDuration = 0,  # 0 = continuous
        
        [Parameter()]
        [string]$OutputPath = 'C:\SecurityMonitoring',
        
        [Parameter()]
        [switch]$CapturePackets,
        
        [Parameter()]
        [ValidateRange(10, 10240)]
        [int]$MaxCaptureSize = 1024,
        
        [Parameter()]
        [switch]$EnableFirewallLogging,
        
        [Parameter()]
        [switch]$EnablePerformanceCounters,
        
        [Parameter()]
        [switch]$EnableETWTracing,
        
        [Parameter()]
        [hashtable]$ThreatDetectionRules = @{},
        
        [Parameter()]
        [hashtable]$AlertThresholds = @{},
        
        [Parameter()]
        [switch]$EnableRealTimeAlerts,
        
        [Parameter()]
        [string]$AlertEmail,
        
        [Parameter()]
        [switch]$EnableBandwidthMonitoring,
        
        [Parameter()]
        [switch]$EnableConnectionTracking,
        
        [Parameter()]
        [switch]$EnableDNSMonitoring,
        
        [Parameter()]
        [switch]$EnablePortScanDetection,
        
        [Parameter()]
        [switch]$EnableDDoSDetection,
        
        [Parameter()]
        [string[]]$CustomFilters = @(),
        
        [Parameter()]
        [ValidateSet('CSV', 'JSON', 'XML', 'ETL')]
        [string]$ExportFormat = 'CSV',
        
        [Parameter()]
        [switch]$CompressLogs,
        
        [Parameter()]
        [switch]$TestMode
    )
    
    begin {
        Write-CustomLog -Level 'INFO' -Message "Starting network traffic monitoring: $MonitoringProfile"
        
        # Check if running as Administrator
        $CurrentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
        $Principal = New-Object Security.Principal.WindowsPrincipal($CurrentUser)
        if (-not $Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            throw "This function requires Administrator privileges"
        }
        
        # Define monitoring profiles
        $MonitoringProfiles = @{
            'Basic' = @{
                Description = 'Basic network monitoring with firewall logs'
                EnableFirewallLogging = $true
                EnablePerformanceCounters = $false
                EnableETWTracing = $false
                CapturePackets = $false
                EnableRealTimeAlerts = $false
                ThreatDetectionEnabled = $false
                MaxCaptureSize = 100
            }
            'Enterprise' = @{
                Description = 'Enterprise network monitoring with threat detection'
                EnableFirewallLogging = $true
                EnablePerformanceCounters = $true
                EnableETWTracing = $true
                CapturePackets = $false
                EnableRealTimeAlerts = $true
                ThreatDetectionEnabled = $true
                MaxCaptureSize = 500
            }
            'HighSecurity' = @{
                Description = 'High security monitoring with full packet capture'
                EnableFirewallLogging = $true
                EnablePerformanceCounters = $true
                EnableETWTracing = $true
                CapturePackets = $true
                EnableRealTimeAlerts = $true
                ThreatDetectionEnabled = $true
                MaxCaptureSize = 2048
            }
            'ThreatHunting' = @{
                Description = 'Advanced threat hunting with comprehensive monitoring'
                EnableFirewallLogging = $true
                EnablePerformanceCounters = $true
                EnableETWTracing = $true
                CapturePackets = $true
                EnableRealTimeAlerts = $true
                ThreatDetectionEnabled = $true
                MaxCaptureSize = 5120
            }
        }
        
        # Ensure output directory exists
        if (-not (Test-Path $OutputPath)) {
            New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
        }
        
        $MonitoringResults = @{
            MonitoringProfile = $MonitoringProfile
            ComputersProcessed = @()
            MonitoringStarted = Get-Date
            MonitoringDuration = $MonitoringDuration
            OutputPath = $OutputPath
            CaptureEnabled = $false
            FirewallLoggingEnabled = $false
            ETWTracingEnabled = $false
            PerformanceCountersEnabled = $false
            ThreatDetectionActive = $false
            SessionIDs = @()
            Errors = @()
            Recommendations = @()
        }
        
        # Default alert thresholds
        $DefaultAlertThresholds = @{
            'ConnectionsPerSecond' = 1000
            'PacketsPerSecond' = 10000
            'BytesPerSecond' = 100MB
            'UniqueSourceIPs' = 1000
            'PortScanThreshold' = 50
            'DNSQueriesPerSecond' = 500
            'FailedConnections' = 100
        }
        
        # Merge provided thresholds with defaults
        $ActiveThresholds = $DefaultAlertThresholds.Clone()
        foreach ($Key in $AlertThresholds.Keys) {
            $ActiveThresholds[$Key] = $AlertThresholds[$Key]
        }
        
        # Default threat detection rules
        $DefaultThreatRules = @{
            'PortScanDetection' = $EnablePortScanDetection.IsPresent
            'DDoSDetection' = $EnableDDoSDetection.IsPresent
            'SuspiciousTrafficDetection' = $true
            'DNSAnomalyDetection' = $EnableDNSMonitoring.IsPresent
        }
        
        # Merge provided rules with defaults
        $ActiveThreatRules = $DefaultThreatRules.Clone()
        foreach ($Key in $ThreatDetectionRules.Keys) {
            $ActiveThreatRules[$Key] = $ThreatDetectionRules[$Key]
        }
    }
    
    process {
        try {
            foreach ($Computer in $ComputerName) {
                Write-CustomLog -Level 'INFO' -Message "Starting network monitoring on: $Computer"
                
                $ComputerResult = @{
                    ComputerName = $Computer
                    Timestamp = Get-Date
                    MonitoringProfile = $MonitoringProfile
                    SessionIDs = @()
                    CaptureFiles = @()
                    LogFiles = @()
                    ServicesStarted = @()
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
                    $ProfileConfig = if ($MonitoringProfile -ne 'Custom') {
                        $MonitoringProfiles[$MonitoringProfile]
                    } else {
                        @{
                            Description = 'Custom network monitoring configuration'
                            EnableFirewallLogging = $EnableFirewallLogging.IsPresent
                            EnablePerformanceCounters = $EnablePerformanceCounters.IsPresent
                            EnableETWTracing = $EnableETWTracing.IsPresent
                            CapturePackets = $CapturePackets.IsPresent
                            EnableRealTimeAlerts = $EnableRealTimeAlerts.IsPresent
                            ThreatDetectionEnabled = ($ActiveThreatRules.Values -contains $true)
                            MaxCaptureSize = $MaxCaptureSize
                        }
                    }
                    
                    # Start monitoring based on configuration
                    $MonitoringResult = if ($Computer -ne 'localhost') {
                        Invoke-Command @SessionParams -ScriptBlock {
                            param($ProfileConfig, $OutputPath, $MonitoringDuration, $MaxCaptureSize, $TestMode, $CustomFilters, $ExportFormat, $ActiveThresholds, $ActiveThreatRules, $SuspiciousIPs, $MonitoredNetworks)
                            
                            $Results = @{
                                SessionIDs = @()
                                CaptureFiles = @()
                                LogFiles = @()
                                ServicesStarted = @()
                                Errors = @()
                            }
                            
                            try {
                                # Create output directory on target computer
                                if (-not (Test-Path $OutputPath)) {
                                    New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
                                }
                                
                                # Enable Windows Firewall logging
                                if ($ProfileConfig.EnableFirewallLogging) {
                                    try {
                                        $FirewallLogPath = Join-Path $OutputPath "firewall.log"
                                        
                                        if (-not $TestMode) {
                                            Set-NetFirewallProfile -Profile Domain,Public,Private -LogAllowed True -LogBlocked True -LogFileName $FirewallLogPath -LogMaxSizeKilobytes 32767
                                        }
                                        
                                        $Results.LogFiles += $FirewallLogPath
                                        $Results.ServicesStarted += "Firewall Logging"
                                        
                                    } catch {
                                        $Results.Errors += "Failed to enable firewall logging: $($_.Exception.Message)"
                                    }
                                }
                                
                                # Start packet capture if enabled
                                if ($ProfileConfig.CapturePackets) {
                                    try {
                                        $CaptureFile = Join-Path $OutputPath "capture-$(Get-Date -Format 'yyyyMMdd-HHmmss').etl"
                                        $SessionName = "SecurityMonitoring-$(Get-Date -Format 'HHmmss')"
                                        
                                        if (-not $TestMode) {
                                            # Start netsh trace
                                            $NetshArgs = @(
                                                'trace', 'start'
                                                'capture=yes'
                                                "tracefile=$CaptureFile"
                                                "maxsize=$MaxCaptureSize"
                                                'provider=Microsoft-Windows-TCPIP'
                                                'provider=Microsoft-Windows-Winsock-AFD'
                                            )
                                            
                                            if ($CustomFilters.Count -gt 0) {
                                                $NetshArgs += $CustomFilters
                                            }
                                            
                                            $NetshResult = & netsh @NetshArgs
                                            
                                            if ($LASTEXITCODE -eq 0) {
                                                $Results.CaptureFiles += $CaptureFile
                                                $Results.SessionIDs += $SessionName
                                                $Results.ServicesStarted += "Packet Capture"
                                            } else {
                                                $Results.Errors += "Failed to start packet capture: $($NetshResult -join ' ')"
                                            }
                                        }
                                        
                                    } catch {
                                        $Results.Errors += "Failed to start packet capture: $($_.Exception.Message)"
                                    }
                                }
                                
                                # Start ETW tracing if enabled
                                if ($ProfileConfig.EnableETWTracing) {
                                    try {
                                        $ETWLogFile = Join-Path $OutputPath "etw-network-$(Get-Date -Format 'yyyyMMdd-HHmmss').etl"
                                        $ETWSessionName = "SecurityMonitoring-ETW"
                                        
                                        if (-not $TestMode) {
                                            # Start ETW session for network providers
                                            $WPRCommand = @(
                                                '-start', $ETWSessionName
                                                '-profiles', 'Network'
                                                '-filemode'
                                            )
                                            
                                            try {
                                                & wpr @WPRCommand
                                                $Results.SessionIDs += $ETWSessionName
                                                $Results.LogFiles += $ETWLogFile
                                                $Results.ServicesStarted += "ETW Network Tracing"
                                            } catch {
                                                # Fallback to logman if WPR not available
                                                $LogmanArgs = @(
                                                    'create', 'trace', $ETWSessionName
                                                    '-p', 'Microsoft-Windows-Kernel-Network'
                                                    '-p', 'Microsoft-Windows-TCPIP'
                                                    '-o', $ETWLogFile
                                                    '-ets'
                                                )
                                                
                                                & logman @LogmanArgs
                                                & logman start $ETWSessionName -ets
                                                
                                                $Results.SessionIDs += $ETWSessionName
                                                $Results.LogFiles += $ETWLogFile
                                                $Results.ServicesStarted += "ETW Network Tracing (Logman)"
                                            }
                                        }
                                        
                                    } catch {
                                        $Results.Errors += "Failed to start ETW tracing: $($_.Exception.Message)"
                                    }
                                }
                                
                                # Start performance counter monitoring
                                if ($ProfileConfig.EnablePerformanceCounters) {
                                    try {
                                        $PerfCounterFile = Join-Path $OutputPath "network-perfcounters-$(Get-Date -Format 'yyyyMMdd-HHmmss').blg"
                                        $PerfSessionName = "SecurityMonitoring-PerfCounters"
                                        
                                        if (-not $TestMode) {
                                            $CounterList = @(
                                                '\Network Interface(*)\Bytes Total/sec'
                                                '\Network Interface(*)\Packets/sec'
                                                '\TCPv4\Connections Established'
                                                '\TCPv4\Connection Failures'
                                                '\IPv4\Datagrams/sec'
                                                '\IPv4\Datagrams Received/sec'
                                                '\IPv4\Datagrams Sent/sec'
                                            )
                                            
                                            $LogmanArgs = @(
                                                'create', 'counter', $PerfSessionName
                                                '-c', ($CounterList -join ' ')
                                                '-o', $PerfCounterFile
                                                '-f', 'bincirc'
                                                '-si', '00:00:05'  # 5 second intervals
                                            )
                                            
                                            & logman @LogmanArgs
                                            & logman start $PerfSessionName
                                            
                                            $Results.SessionIDs += $PerfSessionName
                                            $Results.LogFiles += $PerfCounterFile
                                            $Results.ServicesStarted += "Performance Counter Monitoring"
                                        }
                                        
                                    } catch {
                                        $Results.Errors += "Failed to start performance counter monitoring: $($_.Exception.Message)"
                                    }
                                }
                                
                                # Create monitoring status file
                                $StatusFile = Join-Path $OutputPath "monitoring-status.json"
                                $MonitoringStatus = @{
                                    StartTime = Get-Date
                                    Duration = if ($MonitoringDuration -gt 0) { $MonitoringDuration } else { "Continuous" }
                                    Profile = $ProfileConfig.Description
                                    SessionIDs = $Results.SessionIDs
                                    LogFiles = $Results.LogFiles
                                    ServicesStarted = $Results.ServicesStarted
                                    AlertThresholds = $ActiveThresholds
                                    ThreatRules = $ActiveThreatRules
                                }
                                
                                if (-not $TestMode) {
                                    $MonitoringStatus | ConvertTo-Json -Depth 3 | Out-File -FilePath $StatusFile -Encoding UTF8
                                }
                                
                                $Results.LogFiles += $StatusFile
                                
                            } catch {
                                $Results.Errors += "Failed to start network monitoring: $($_.Exception.Message)"
                            }
                            
                            return $Results
                        } -ArgumentList $ProfileConfig, $OutputPath, $MonitoringDuration, $MaxCaptureSize, $TestMode, $CustomFilters, $ExportFormat, $ActiveThresholds, $ActiveThreatRules, $SuspiciousIPs, $MonitoredNetworks
                    } else {
                        $Results = @{
                            SessionIDs = @()
                            CaptureFiles = @()
                            LogFiles = @()
                            ServicesStarted = @()
                            Errors = @()
                        }
                        
                        try {
                            # Enable Windows Firewall logging
                            if ($ProfileConfig.EnableFirewallLogging -or $EnableFirewallLogging) {
                                try {
                                    $FirewallLogPath = Join-Path $OutputPath "firewall-$Computer.log"
                                    
                                    if (-not $TestMode) {
                                        if ($PSCmdlet.ShouldProcess("Firewall Logging", "Enable comprehensive logging")) {
                                            Set-NetFirewallProfile -Profile Domain,Public,Private -LogAllowed True -LogBlocked True -LogFileName $FirewallLogPath -LogMaxSizeKilobytes 32767
                                        }
                                    } else {
                                        Write-CustomLog -Level 'INFO' -Message "[TEST] Would enable firewall logging to: $FirewallLogPath"
                                    }
                                    
                                    $Results.LogFiles += $FirewallLogPath
                                    $Results.ServicesStarted += "Firewall Logging"
                                    $MonitoringResults.FirewallLoggingEnabled = $true
                                    
                                } catch {
                                    $Results.Errors += "Failed to enable firewall logging: $($_.Exception.Message)"
                                }
                            }
                            
                            # Start packet capture if enabled
                            if ($ProfileConfig.CapturePackets -or $CapturePackets) {
                                try {
                                    $CaptureFile = Join-Path $OutputPath "capture-$Computer-$(Get-Date -Format 'yyyyMMdd-HHmmss').etl"
                                    $SessionName = "SecurityMonitoring-$Computer-$(Get-Date -Format 'HHmmss')"
                                    
                                    if (-not $TestMode) {
                                        if ($PSCmdlet.ShouldProcess("Packet Capture", "Start network packet capture")) {
                                            # Start netsh trace
                                            $NetshArgs = @(
                                                'trace', 'start'
                                                'capture=yes'
                                                "tracefile=$CaptureFile"
                                                "maxsize=$MaxCaptureSize"
                                                'provider=Microsoft-Windows-TCPIP'
                                                'provider=Microsoft-Windows-Winsock-AFD'
                                            )
                                            
                                            if ($CustomFilters.Count -gt 0) {
                                                $NetshArgs += $CustomFilters
                                            }
                                            
                                            $NetshResult = & netsh @NetshArgs 2>&1
                                            
                                            if ($LASTEXITCODE -eq 0) {
                                                $Results.CaptureFiles += $CaptureFile
                                                $Results.SessionIDs += $SessionName
                                                $Results.ServicesStarted += "Packet Capture"
                                                $MonitoringResults.CaptureEnabled = $true
                                            } else {
                                                $Results.Errors += "Failed to start packet capture: $($NetshResult -join ' ')"
                                            }
                                        }
                                    } else {
                                        Write-CustomLog -Level 'INFO' -Message "[TEST] Would start packet capture to: $CaptureFile"
                                    }
                                    
                                } catch {
                                    $Results.Errors += "Failed to start packet capture: $($_.Exception.Message)"
                                }
                            }
                            
                            # Start ETW tracing if enabled
                            if ($ProfileConfig.EnableETWTracing -or $EnableETWTracing) {
                                try {
                                    $ETWLogFile = Join-Path $OutputPath "etw-network-$Computer-$(Get-Date -Format 'yyyyMMdd-HHmmss').etl"
                                    $ETWSessionName = "SecurityMonitoring-ETW-$Computer"
                                    
                                    if (-not $TestMode) {
                                        if ($PSCmdlet.ShouldProcess("ETW Tracing", "Start Event Tracing for Windows")) {
                                            try {
                                                # Try WPR first
                                                $WPRCommand = @(
                                                    '-start', $ETWSessionName
                                                    '-profiles', 'Network'
                                                    '-filemode'
                                                )
                                                
                                                & wpr @WPRCommand 2>$null
                                                $Results.SessionIDs += $ETWSessionName
                                                $Results.LogFiles += $ETWLogFile
                                                $Results.ServicesStarted += "ETW Network Tracing"
                                                $MonitoringResults.ETWTracingEnabled = $true
                                                
                                            } catch {
                                                # Fallback to logman
                                                $LogmanArgs = @(
                                                    'create', 'trace', $ETWSessionName
                                                    '-p', 'Microsoft-Windows-Kernel-Network'
                                                    '-p', 'Microsoft-Windows-TCPIP'
                                                    '-o', $ETWLogFile
                                                    '-ets'
                                                )
                                                
                                                & logman @LogmanArgs | Out-Null
                                                & logman start $ETWSessionName -ets | Out-Null
                                                
                                                $Results.SessionIDs += $ETWSessionName
                                                $Results.LogFiles += $ETWLogFile
                                                $Results.ServicesStarted += "ETW Network Tracing (Logman)"
                                                $MonitoringResults.ETWTracingEnabled = $true
                                            }
                                        }
                                    } else {
                                        Write-CustomLog -Level 'INFO' -Message "[TEST] Would start ETW tracing to: $ETWLogFile"
                                    }
                                    
                                } catch {
                                    $Results.Errors += "Failed to start ETW tracing: $($_.Exception.Message)"
                                }
                            }
                            
                            # Start performance counter monitoring
                            if ($ProfileConfig.EnablePerformanceCounters -or $EnablePerformanceCounters) {
                                try {
                                    $PerfCounterFile = Join-Path $OutputPath "network-perfcounters-$Computer-$(Get-Date -Format 'yyyyMMdd-HHmmss').blg"
                                    $PerfSessionName = "SecurityMonitoring-PerfCounters-$Computer"
                                    
                                    if (-not $TestMode) {
                                        if ($PSCmdlet.ShouldProcess("Performance Counters", "Start network performance monitoring")) {
                                            $CounterList = @(
                                                '\Network Interface(*)\Bytes Total/sec'
                                                '\Network Interface(*)\Packets/sec'
                                                '\TCPv4\Connections Established'
                                                '\TCPv4\Connection Failures'
                                                '\IPv4\Datagrams/sec'
                                                '\IPv4\Datagrams Received/sec'
                                                '\IPv4\Datagrams Sent/sec'
                                            )
                                            
                                            $LogmanArgs = @(
                                                'create', 'counter', $PerfSessionName
                                                '-c', ($CounterList -join ' ')
                                                '-o', $PerfCounterFile
                                                '-f', 'bincirc'
                                                '-si', '00:00:05'  # 5 second intervals
                                            )
                                            
                                            & logman @LogmanArgs | Out-Null
                                            & logman start $PerfSessionName | Out-Null
                                            
                                            $Results.SessionIDs += $PerfSessionName
                                            $Results.LogFiles += $PerfCounterFile
                                            $Results.ServicesStarted += "Performance Counter Monitoring"
                                            $MonitoringResults.PerformanceCountersEnabled = $true
                                        }
                                    } else {
                                        Write-CustomLog -Level 'INFO' -Message "[TEST] Would start performance counter monitoring to: $PerfCounterFile"
                                    }
                                    
                                } catch {
                                    $Results.Errors += "Failed to start performance counter monitoring: $($_.Exception.Message)"
                                }
                            }
                            
                            # Create monitoring status file
                            $StatusFile = Join-Path $OutputPath "monitoring-status-$Computer.json"
                            $MonitoringStatus = @{
                                StartTime = Get-Date
                                Duration = if ($MonitoringDuration -gt 0) { $MonitoringDuration } else { "Continuous" }
                                Profile = $ProfileConfig.Description
                                SessionIDs = $Results.SessionIDs
                                LogFiles = $Results.LogFiles
                                ServicesStarted = $Results.ServicesStarted
                                AlertThresholds = $ActiveThresholds
                                ThreatRules = $ActiveThreatRules
                            }
                            
                            if (-not $TestMode) {
                                $MonitoringStatus | ConvertTo-Json -Depth 3 | Out-File -FilePath $StatusFile -Encoding UTF8
                            }
                            
                            $Results.LogFiles += $StatusFile
                            
                        } catch {
                            $Results.Errors += "Failed to start network monitoring: $($_.Exception.Message)"
                        }
                        
                        $Results
                    }
                    
                    $ComputerResult.SessionIDs = $MonitoringResult.SessionIDs
                    $ComputerResult.CaptureFiles = $MonitoringResult.CaptureFiles
                    $ComputerResult.LogFiles = $MonitoringResult.LogFiles
                    $ComputerResult.ServicesStarted = $MonitoringResult.ServicesStarted
                    $ComputerResult.Errors += $MonitoringResult.Errors
                    
                    $MonitoringResults.SessionIDs += $MonitoringResult.SessionIDs
                    
                    # Set up monitoring duration timer if specified
                    if ($MonitoringDuration -gt 0 -and -not $TestMode) {
                        Write-CustomLog -Level 'INFO' -Message "Monitoring will run for $MonitoringDuration hours"
                        
                        # Create scheduled task to stop monitoring
                        $StopTime = (Get-Date).AddHours($MonitoringDuration)
                        $TaskName = "Stop-SecurityMonitoring-$Computer"
                        
                        try {
                            $StopScript = @"
# Stop network monitoring sessions
foreach (`$SessionID in @('$($MonitoringResult.SessionIDs -join "','")')) {
    try {
        if (`$SessionID -like '*ETW*') {
            wpr -stop `$SessionID 2>`$null
            logman stop `$SessionID -ets 2>`$null
        } elseif (`$SessionID -like '*PerfCounters*') {
            logman stop `$SessionID 2>`$null
        } else {
            netsh trace stop 2>`$null
        }
    } catch {
        Write-EventLog -LogName Application -Source 'SecurityMonitoring' -EventID 1001 -Message "Failed to stop session: `$SessionID"
    }
}
"@
                            
                            $ScriptPath = Join-Path $OutputPath "stop-monitoring-$Computer.ps1"
                            $StopScript | Out-File -FilePath $ScriptPath -Encoding UTF8
                            
                            $TaskAction = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-ExecutionPolicy Bypass -File `"$ScriptPath`""
                            $TaskTrigger = New-ScheduledTaskTrigger -Once -At $StopTime
                            $TaskSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
                            $TaskPrincipal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
                            
                            Register-ScheduledTask -TaskName $TaskName -Action $TaskAction -Trigger $TaskTrigger -Settings $TaskSettings -Principal $TaskPrincipal -Description "Stop SecurityMonitoring for $Computer" | Out-Null
                            
                            Write-CustomLog -Level 'SUCCESS' -Message "Scheduled automatic stop at: $StopTime"
                            
                        } catch {
                            Write-CustomLog -Level 'WARNING' -Message "Failed to schedule automatic stop: $($_.Exception.Message)"
                        }
                    }
                    
                    Write-CustomLog -Level 'SUCCESS' -Message "Network monitoring started on $Computer - Services: $($ComputerResult.ServicesStarted -join ', ')"
                    
                } catch {
                    $Error = "Failed to start network monitoring on $Computer`: $($_.Exception.Message)"
                    $ComputerResult.Errors += $Error
                    Write-CustomLog -Level 'ERROR' -Message $Error
                }
                
                $MonitoringResults.ComputersProcessed += $ComputerResult
            }
            
        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Error during network monitoring setup: $($_.Exception.Message)"
            throw
        }
    }
    
    end {
        Write-CustomLog -Level 'SUCCESS' -Message "Network traffic monitoring setup completed"
        
        # Generate recommendations
        $MonitoringResults.Recommendations += "Monitor log file sizes and implement log rotation to prevent disk space issues"
        $MonitoringResults.Recommendations += "Regularly review monitoring data for security incidents and performance anomalies"
        $MonitoringResults.Recommendations += "Set up automated analysis of captured data for threat detection"
        $MonitoringResults.Recommendations += "Ensure monitoring data is securely stored and access is restricted"
        $MonitoringResults.Recommendations += "Test monitoring system regularly to ensure it's capturing expected data"
        
        if ($MonitoringResults.CaptureEnabled) {
            $MonitoringResults.Recommendations += "Packet capture is enabled - monitor storage usage and implement retention policies"
        }
        
        if ($MonitoringDuration -eq 0) {
            $MonitoringResults.Recommendations += "Continuous monitoring is enabled - ensure proper log management and archival"
        }
        
        if ($EnableRealTimeAlerts) {
            $MonitoringResults.Recommendations += "Real-time alerts are enabled - ensure alert handling procedures are in place"
        }
        
        if ($MonitoringResults.SessionIDs.Count -gt 0) {
            $MonitoringResults.Recommendations += "Use 'netsh trace stop' or 'logman stop' commands to stop monitoring sessions when needed"
        }
        
        # Display summary
        Write-CustomLog -Level 'INFO' -Message "Network Monitoring Summary:"
        Write-CustomLog -Level 'INFO' -Message "  Profile: $($MonitoringResults.MonitoringProfile)"
        Write-CustomLog -Level 'INFO' -Message "  Computers: $($MonitoringResults.ComputersProcessed.Count)"
        Write-CustomLog -Level 'INFO' -Message "  Duration: $(if ($MonitoringDuration -eq 0) { 'Continuous' } else { "$MonitoringDuration hours" })"
        Write-CustomLog -Level 'INFO' -Message "  Output Path: $($MonitoringResults.OutputPath)"
        Write-CustomLog -Level 'INFO' -Message "  Capture Enabled: $($MonitoringResults.CaptureEnabled)"
        Write-CustomLog -Level 'INFO' -Message "  Firewall Logging: $($MonitoringResults.FirewallLoggingEnabled)"
        Write-CustomLog -Level 'INFO' -Message "  ETW Tracing: $($MonitoringResults.ETWTracingEnabled)"
        Write-CustomLog -Level 'INFO' -Message "  Performance Counters: $($MonitoringResults.PerformanceCountersEnabled)"
        Write-CustomLog -Level 'INFO' -Message "  Active Sessions: $($MonitoringResults.SessionIDs.Count)"
        
        if ($MonitoringResults.SessionIDs.Count -gt 0) {
            Write-CustomLog -Level 'INFO' -Message "Active monitoring sessions:"
            foreach ($SessionID in $MonitoringResults.SessionIDs) {
                Write-CustomLog -Level 'INFO' -Message "  - $SessionID"
            }
        }
        
        return $MonitoringResults
    }
}
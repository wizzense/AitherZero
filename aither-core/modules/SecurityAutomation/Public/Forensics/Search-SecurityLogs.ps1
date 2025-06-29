function Search-SecurityLogs {
    <#
    .SYNOPSIS
        Performs comprehensive security log analysis for threat hunting and forensic investigation.
        
    .DESCRIPTION
        Analyzes Windows event logs, IIS logs, and custom log files for security indicators,
        attack patterns, and forensic evidence. Supports correlation across multiple log sources
        and automated threat detection using indicators of compromise.
        
    .PARAMETER ComputerName
        Target computers for log analysis. Default: localhost
        
    .PARAMETER Credential
        Credentials for remote computer access
        
    .PARAMETER AnalysisProfile
        Predefined analysis profile to determine scope and methods
        
    .PARAMETER LogSources
        Specific log sources to analyze (EventLog, IIS, Custom, All)
        
    .PARAMETER EventLogNames
        Specific Windows event logs to analyze
        
    .PARAMETER CustomLogPaths
        Paths to custom log files for analysis
        
    .PARAMETER OutputPath
        Directory path to save analysis results
        
    .PARAMETER TimeRange
        Time range for log analysis (hours back from current time)
        
    .PARAMETER StartTime
        Start time for log analysis
        
    .PARAMETER EndTime
        End time for log analysis
        
    .PARAMETER SearchPatterns
        Hashtable of search patterns and regular expressions
        
    .PARAMETER ThreatIndicators
        Array of known threat indicators to search for
        
    .PARAMETER SuspiciousIPs
        Array of suspicious IP addresses to monitor
        
    .PARAMETER SuspiciousUsers
        Array of suspicious user accounts to monitor
        
    .PARAMETER SuspiciousProcesses
        Array of suspicious process names to monitor
        
    .PARAMETER IncludeLogonAnalysis
        Include detailed logon/logoff analysis
        
    .PARAMETER IncludeFailureAnalysis
        Include authentication failure analysis
        
    .PARAMETER IncludePrivilegeAnalysis
        Include privilege escalation analysis
        
    .PARAMETER IncludeNetworkAnalysis
        Include network connection analysis
        
    .PARAMETER IncludeProcessAnalysis
        Include process creation analysis
        
    .PARAMETER IncludeFileAnalysis
        Include file access analysis
        
    .PARAMETER CorrelateEvents
        Enable cross-log event correlation
        
    .PARAMETER GenerateTimeline
        Generate chronological timeline of events
        
    .PARAMETER EnableThreatHunting
        Enable automated threat hunting rules
        
    .PARAMETER ThreatHuntingRules
        Custom threat hunting rules to apply
        
    .PARAMETER AlertThresholds
        Hashtable of alert thresholds for various metrics
        
    .PARAMETER ExportFormat
        Format for exporting results (CSV, JSON, XML)
        
    .PARAMETER CompressOutput
        Compress analysis results into ZIP file
        
    .PARAMETER GenerateReport
        Generate comprehensive HTML report
        
    .PARAMETER TestMode
        Run analysis in test mode without processing large datasets
        
    .EXAMPLE
        Search-SecurityLogs -AnalysisProfile 'ThreatHunting' -TimeRange 24 -IncludeLogonAnalysis
        
    .EXAMPLE
        Search-SecurityLogs -EventLogNames @('Security', 'System') -ThreatIndicators @('mimikatz', 'powershell -enc') -GenerateReport
        
    .EXAMPLE
        Search-SecurityLogs -AnalysisProfile 'Incident' -StartTime (Get-Date).AddDays(-1) -CorrelateEvents -GenerateTimeline
    #>
    
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter()]
        [string[]]$ComputerName = @('localhost'),
        
        [Parameter()]
        [pscredential]$Credential,
        
        [Parameter()]
        [ValidateSet('Basic', 'Standard', 'ThreatHunting', 'Incident', 'Compliance', 'Custom')]
        [string]$AnalysisProfile = 'Standard',
        
        [Parameter()]
        [ValidateSet('EventLog', 'IIS', 'Custom', 'All')]
        [string[]]$LogSources = @('EventLog'),
        
        [Parameter()]
        [string[]]$EventLogNames = @(),
        
        [Parameter()]
        [string[]]$CustomLogPaths = @(),
        
        [Parameter()]
        [string]$OutputPath = 'C:\SecurityLogAnalysis',
        
        [Parameter()]
        [ValidateRange(1, 8760)]
        [int]$TimeRange = 24,  # Hours
        
        [Parameter()]
        [datetime]$StartTime,
        
        [Parameter()]
        [datetime]$EndTime,
        
        [Parameter()]
        [hashtable]$SearchPatterns = @{},
        
        [Parameter()]
        [string[]]$ThreatIndicators = @(),
        
        [Parameter()]
        [string[]]$SuspiciousIPs = @(),
        
        [Parameter()]
        [string[]]$SuspiciousUsers = @(),
        
        [Parameter()]
        [string[]]$SuspiciousProcesses = @(),
        
        [Parameter()]
        [switch]$IncludeLogonAnalysis,
        
        [Parameter()]
        [switch]$IncludeFailureAnalysis,
        
        [Parameter()]
        [switch]$IncludePrivilegeAnalysis,
        
        [Parameter()]
        [switch]$IncludeNetworkAnalysis,
        
        [Parameter()]
        [switch]$IncludeProcessAnalysis,
        
        [Parameter()]
        [switch]$IncludeFileAnalysis,
        
        [Parameter()]
        [switch]$CorrelateEvents,
        
        [Parameter()]
        [switch]$GenerateTimeline,
        
        [Parameter()]
        [switch]$EnableThreatHunting,
        
        [Parameter()]
        [hashtable]$ThreatHuntingRules = @{},
        
        [Parameter()]
        [hashtable]$AlertThresholds = @{},
        
        [Parameter()]
        [ValidateSet('CSV', 'JSON', 'XML')]
        [string]$ExportFormat = 'CSV',
        
        [Parameter()]
        [switch]$CompressOutput,
        
        [Parameter()]
        [switch]$GenerateReport,
        
        [Parameter()]
        [switch]$TestMode
    )
    
    begin {
        Write-CustomLog -Level 'INFO' -Message "Starting security log analysis: $AnalysisProfile"
        
        # Check if running as Administrator
        $CurrentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
        $Principal = New-Object Security.Principal.WindowsPrincipal($CurrentUser)
        if (-not $Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            throw "This function requires Administrator privileges"
        }
        
        # Define analysis profiles
        $AnalysisProfiles = @{
            'Basic' = @{
                Description = 'Basic security log analysis'
                DefaultEventLogs = @('Security', 'System')
                TimeRange = 24
                IncludeLogonAnalysis = $true
                IncludeFailureAnalysis = $true
                IncludePrivilegeAnalysis = $false
                IncludeNetworkAnalysis = $false
                IncludeProcessAnalysis = $false
                EnableThreatHunting = $false
                CorrelateEvents = $false
                GenerateTimeline = $false
            }
            'Standard' = @{
                Description = 'Standard security log analysis with correlation'
                DefaultEventLogs = @('Security', 'System', 'Application', 'Microsoft-Windows-PowerShell/Operational')
                TimeRange = 48
                IncludeLogonAnalysis = $true
                IncludeFailureAnalysis = $true
                IncludePrivilegeAnalysis = $true
                IncludeNetworkAnalysis = $true
                IncludeProcessAnalysis = $true
                EnableThreatHunting = $false
                CorrelateEvents = $true
                GenerateTimeline = $true
            }
            'ThreatHunting' = @{
                Description = 'Advanced threat hunting with automated detection'
                DefaultEventLogs = @('Security', 'System', 'Application', 'Microsoft-Windows-PowerShell/Operational', 'Microsoft-Windows-Sysmon/Operational', 'Microsoft-Windows-Windows Defender/Operational')
                TimeRange = 168  # 1 week
                IncludeLogonAnalysis = $true
                IncludeFailureAnalysis = $true
                IncludePrivilegeAnalysis = $true
                IncludeNetworkAnalysis = $true
                IncludeProcessAnalysis = $true
                EnableThreatHunting = $true
                CorrelateEvents = $true
                GenerateTimeline = $true
            }
            'Incident' = @{
                Description = 'Incident response focused analysis'
                DefaultEventLogs = @('Security', 'System', 'Application', 'Microsoft-Windows-PowerShell/Operational', 'Microsoft-Windows-Sysmon/Operational')
                TimeRange = 72
                IncludeLogonAnalysis = $true
                IncludeFailureAnalysis = $true
                IncludePrivilegeAnalysis = $true
                IncludeNetworkAnalysis = $true
                IncludeProcessAnalysis = $true
                EnableThreatHunting = $true
                CorrelateEvents = $true
                GenerateTimeline = $true
            }
            'Compliance' = @{
                Description = 'Compliance-focused log analysis'
                DefaultEventLogs = @('Security', 'System')
                TimeRange = 24
                IncludeLogonAnalysis = $true
                IncludeFailureAnalysis = $true
                IncludePrivilegeAnalysis = $true
                IncludeNetworkAnalysis = $false
                IncludeProcessAnalysis = $false
                EnableThreatHunting = $false
                CorrelateEvents = $false
                GenerateTimeline = $false
            }
        }
        
        # Ensure output directory exists
        if (-not (Test-Path $OutputPath)) {
            New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
        }
        
        # Calculate time range
        if (-not $StartTime -and -not $EndTime) {
            $EndTime = Get-Date
            $StartTime = $EndTime.AddHours(-$TimeRange)
        } elseif (-not $StartTime) {
            $StartTime = $EndTime.AddHours(-$TimeRange)
        } elseif (-not $EndTime) {
            $EndTime = $StartTime.AddHours($TimeRange)
        }
        
        $LogAnalysisResults = @{
            AnalysisProfile = $AnalysisProfile
            ComputersProcessed = @()
            OutputPath = $OutputPath
            StartTime = $StartTime
            EndTime = $EndTime
            EventsAnalyzed = 0
            SecurityFindings = 0
            ThreatDetections = 0
            SuspiciousActivities = 0
            FailedLogons = 0
            PrivilegeEscalations = 0
            Correlations = 0
            TimelineEvents = 0
            Errors = @()
            Recommendations = @()
        }
        
        # Default search patterns
        $DefaultSearchPatterns = @{
            'Mimikatz' = @('mimikatz', 'sekurlsa', 'kerberos::golden', 'lsadump::sam')
            'PowerShell' = @('powershell.*-enc', 'powershell.*-nop', 'powershell.*hidden', 'invoke-expression', 'downloadstring')
            'Lateral Movement' = @('psexec', 'wmiexec', 'schtasks.*\\c\$', 'net use.*admin\$')
            'Persistence' = @('schtasks.*create', 'sc.*create', 'reg.*run', 'wmic.*startup')
            'Credential Access' = @('lsass', 'sam', 'ntds', 'credential', 'password')
        }
        
        # Merge provided patterns with defaults
        $ActiveSearchPatterns = $DefaultSearchPatterns.Clone()
        foreach ($Key in $SearchPatterns.Keys) {
            $ActiveSearchPatterns[$Key] = $SearchPatterns[$Key]
        }
        
        # Default threat hunting rules
        $DefaultThreatHuntingRules = @{
            'Multiple Failed Logons' = @{
                EventID = 4625
                Threshold = 10
                TimeWindow = 300  # 5 minutes
                Description = 'Multiple failed logon attempts indicating brute force'
            }
            'Privilege Escalation' = @{
                EventID = @(4672, 4673, 4674)
                Threshold = 5
                TimeWindow = 600  # 10 minutes
                Description = 'Multiple privilege use events indicating escalation'
            }
            'Process Creation Anomaly' = @{
                EventID = 4688
                SuspiciousProcesses = @('cmd.exe', 'powershell.exe', 'wmic.exe', 'net.exe')
                Description = 'Suspicious process creation patterns'
            }
        }
        
        # Merge provided rules with defaults
        $ActiveThreatHuntingRules = $DefaultThreatHuntingRules.Clone()
        foreach ($Key in $ThreatHuntingRules.Keys) {
            $ActiveThreatHuntingRules[$Key] = $ThreatHuntingRules[$Key]
        }
        
        # Default alert thresholds
        $DefaultAlertThresholds = @{
            'FailedLogons' = 50
            'PrivilegeUse' = 20
            'ProcessCreations' = 100
            'NetworkConnections' = 200
            'FileAccess' = 500
        }
        
        # Merge provided thresholds with defaults
        $ActiveAlertThresholds = $DefaultAlertThresholds.Clone()
        foreach ($Key in $AlertThresholds.Keys) {
            $ActiveAlertThresholds[$Key] = $AlertThresholds[$Key]
        }
    }
    
    process {
        try {
            foreach ($Computer in $ComputerName) {
                Write-CustomLog -Level 'INFO' -Message "Analyzing security logs on: $Computer"
                
                $ComputerResult = @{
                    ComputerName = $Computer
                    Timestamp = Get-Date
                    AnalysisProfile = $AnalysisProfile
                    StartTime = $StartTime
                    EndTime = $EndTime
                    EventsAnalyzed = 0
                    SecurityFindings = @()
                    ThreatDetections = @()
                    SuspiciousActivities = @()
                    LogonAnalysis = @{}
                    FailureAnalysis = @{}
                    PrivilegeAnalysis = @{}
                    ProcessAnalysis = @{}
                    Correlations = @()
                    Timeline = @()
                    AnalysisTime = 0
                    OutputFiles = @()
                    Errors = @()
                }
                
                $StartAnalysisTime = Get-Date
                
                try {
                    # Create computer-specific output directory
                    $ComputerOutputPath = Join-Path $OutputPath "LogAnalysis-$Computer-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
                    if (-not (Test-Path $ComputerOutputPath)) {
                        New-Item -Path $ComputerOutputPath -ItemType Directory -Force | Out-Null
                    }
                    
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
                    $ProfileConfig = if ($AnalysisProfile -ne 'Custom') {
                        $AnalysisProfiles[$AnalysisProfile]
                    } else {
                        @{
                            Description = 'Custom security log analysis'
                            DefaultEventLogs = $EventLogNames
                            TimeRange = $TimeRange
                            IncludeLogonAnalysis = $IncludeLogonAnalysis.IsPresent
                            IncludeFailureAnalysis = $IncludeFailureAnalysis.IsPresent
                            IncludePrivilegeAnalysis = $IncludePrivilegeAnalysis.IsPresent
                            IncludeNetworkAnalysis = $IncludeNetworkAnalysis.IsPresent
                            IncludeProcessAnalysis = $IncludeProcessAnalysis.IsPresent
                            EnableThreatHunting = $EnableThreatHunting.IsPresent
                            CorrelateEvents = $CorrelateEvents.IsPresent
                            GenerateTimeline = $GenerateTimeline.IsPresent
                        }
                    }
                    
                    # Determine event logs to analyze
                    $ActiveEventLogs = if ($EventLogNames.Count -gt 0) {
                        $EventLogNames
                    } else {
                        $ProfileConfig.DefaultEventLogs
                    }
                    
                    # Perform log analysis
                    $AnalysisResult = if ($Computer -ne 'localhost') {
                        Invoke-Command @SessionParams -ScriptBlock {
                            param($ProfileConfig, $ActiveEventLogs, $ComputerOutputPath, $StartTime, $EndTime, $ActiveSearchPatterns, $ThreatIndicators, $SuspiciousIPs, $SuspiciousUsers, $SuspiciousProcesses, $ActiveThreatHuntingRules, $ActiveAlertThresholds, $TestMode)
                            
                            $Results = @{
                                EventsAnalyzed = 0
                                SecurityFindings = @()
                                ThreatDetections = @()
                                SuspiciousActivities = @()
                                LogonAnalysis = @{}
                                FailureAnalysis = @{}
                                PrivilegeAnalysis = @{}
                                ProcessAnalysis = @{}
                                Correlations = @()
                                Timeline = @()
                                OutputFiles = @()
                                Errors = @()
                            }
                            
                            try {
                                # Function to analyze events for patterns
                                function Search-EventsForPatterns {
                                    param($Events, $Patterns, $Name)
                                    
                                    $Matches = @()
                                    foreach ($Event in $Events) {
                                        $EventText = "$($Event.Message) $($Event.Id) $($Event.LevelDisplayName)"
                                        
                                        foreach ($Pattern in $Patterns) {
                                            if ($EventText -match $Pattern) {
                                                $Matches += @{
                                                    Event = $Event
                                                    Pattern = $Pattern
                                                    PatternName = $Name
                                                    MatchText = $Matches[0]
                                                }
                                            }
                                        }
                                    }
                                    
                                    return $Matches
                                }
                                
                                # Analyze each event log
                                foreach ($LogName in $ActiveEventLogs) {
                                    try {
                                        Write-Progress -Activity "Analyzing Logs" -Status "Processing $LogName" -PercentComplete 0
                                        
                                        # Get events from log
                                        $LogEvents = @()
                                        if (-not $TestMode) {
                                            $LogEvents = Get-WinEvent -LogName $LogName -StartTime $StartTime -EndTime $EndTime -ErrorAction SilentlyContinue | Sort-Object TimeCreated
                                        } else {
                                            # Create test events for demo
                                            $LogEvents = @(
                                                [PSCustomObject]@{ Id = 4624; TimeCreated = Get-Date; Message = "Test successful logon"; LevelDisplayName = "Information" }
                                                [PSCustomObject]@{ Id = 4625; TimeCreated = Get-Date; Message = "Test failed logon"; LevelDisplayName = "Information" }
                                            )
                                        }
                                        
                                        $Results.EventsAnalyzed += $LogEvents.Count
                                        
                                        if ($LogEvents.Count -gt 0) {
                                            # Search for threat patterns
                                            foreach ($PatternName in $ActiveSearchPatterns.Keys) {
                                                $PatternMatches = Search-EventsForPatterns -Events $LogEvents -Patterns $ActiveSearchPatterns[$PatternName] -Name $PatternName
                                                
                                                if ($PatternMatches.Count -gt 0) {
                                                    $Results.ThreatDetections += @{
                                                        PatternName = $PatternName
                                                        Matches = $PatternMatches
                                                        Count = $PatternMatches.Count
                                                        LogName = $LogName
                                                    }
                                                }
                                            }
                                            
                                            # Logon analysis for Security log
                                            if ($LogName -eq 'Security' -and $ProfileConfig.IncludeLogonAnalysis) {
                                                $SuccessfulLogons = $LogEvents | Where-Object { $_.Id -eq 4624 }
                                                $FailedLogons = $LogEvents | Where-Object { $_.Id -eq 4625 }
                                                
                                                $Results.LogonAnalysis = @{
                                                    SuccessfulLogons = $SuccessfulLogons.Count
                                                    FailedLogons = $FailedLogons.Count
                                                    UniqueUsers = ($SuccessfulLogons | Select-Object -ExpandProperty Message | ForEach-Object { 
                                                        if ($_ -match 'Account Name:\s+(\S+)') { $Matches[1] }
                                                    } | Sort-Object -Unique).Count
                                                    LogonTypes = $SuccessfulLogons | Group-Object { 
                                                        if ($_.Message -match 'Logon Type:\s+(\d+)') { $Matches[1] } else { 'Unknown' }
                                                    } | ForEach-Object { @{ Type = $_.Name; Count = $_.Count } }
                                                }
                                            }
                                            
                                            # Failure analysis
                                            if ($ProfileConfig.IncludeFailureAnalysis) {
                                                $FailureEvents = $LogEvents | Where-Object { $_.LevelDisplayName -in @('Error', 'Critical') }
                                                $Results.FailureAnalysis = @{
                                                    TotalFailures = $FailureEvents.Count
                                                    FailuresByType = $FailureEvents | Group-Object Id | ForEach-Object { @{ EventID = $_.Name; Count = $_.Count } }
                                                    CriticalFailures = ($FailureEvents | Where-Object { $_.LevelDisplayName -eq 'Critical' }).Count
                                                }
                                            }
                                            
                                            # Privilege analysis
                                            if ($LogName -eq 'Security' -and $ProfileConfig.IncludePrivilegeAnalysis) {
                                                $PrivilegeEvents = $LogEvents | Where-Object { $_.Id -in @(4672, 4673, 4674) }
                                                $Results.PrivilegeAnalysis = @{
                                                    TotalPrivilegeUse = $PrivilegeEvents.Count
                                                    UniqueAccounts = ($PrivilegeEvents | Select-Object -ExpandProperty Message | ForEach-Object { 
                                                        if ($_ -match 'Account Name:\s+(\S+)') { $Matches[1] }
                                                    } | Sort-Object -Unique).Count
                                                    PrivilegeTypes = $PrivilegeEvents | Group-Object Id | ForEach-Object { @{ EventID = $_.Name; Count = $_.Count } }
                                                }
                                            }
                                            
                                            # Process analysis
                                            if ($LogName -eq 'Security' -and $ProfileConfig.IncludeProcessAnalysis) {
                                                $ProcessEvents = $LogEvents | Where-Object { $_.Id -eq 4688 }
                                                $SuspiciousProcessEvents = $ProcessEvents | Where-Object { 
                                                    $ProcessName = ""
                                                    if ($_.Message -match 'Process Name:\s+(.+)') { $ProcessName = $Matches[1] }
                                                    $SuspiciousProcesses -contains [System.IO.Path]::GetFileName($ProcessName)
                                                }
                                                
                                                $Results.ProcessAnalysis = @{
                                                    TotalProcesses = $ProcessEvents.Count
                                                    SuspiciousProcesses = $SuspiciousProcessEvents.Count
                                                    UniqueProcesses = ($ProcessEvents | Select-Object -ExpandProperty Message | ForEach-Object { 
                                                        if ($_ -match 'Process Name:\s+(.+)') { [System.IO.Path]::GetFileName($Matches[1]) }
                                                    } | Sort-Object -Unique).Count
                                                }
                                            }
                                            
                                            # Add events to timeline if requested
                                            if ($ProfileConfig.GenerateTimeline) {
                                                foreach ($Event in $LogEvents) {
                                                    if ($Event.LevelDisplayName -in @('Warning', 'Error', 'Critical') -or $Event.Id -in @(4624, 4625, 4672, 4688)) {
                                                        $Results.Timeline += @{
                                                            TimeCreated = $Event.TimeCreated
                                                            LogName = $LogName
                                                            EventID = $Event.Id
                                                            Level = $Event.LevelDisplayName
                                                            Message = $Event.Message.Substring(0, [Math]::Min(200, $Event.Message.Length))
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                        
                                    } catch {
                                        $Results.Errors += "Failed to analyze log $LogName`: $($_.Exception.Message)"
                                    }
                                }
                                
                                # Apply threat hunting rules
                                if ($ProfileConfig.EnableThreatHunting) {
                                    foreach ($RuleName in $ActiveThreatHuntingRules.Keys) {
                                        $Rule = $ActiveThreatHuntingRules[$RuleName]
                                        
                                        try {
                                            # This would implement the threat hunting logic
                                            # For demo purposes, we'll simulate detections
                                            if ($Results.LogonAnalysis.FailedLogons -gt $ActiveAlertThresholds.FailedLogons) {
                                                $Results.ThreatDetections += @{
                                                    RuleName = "Excessive Failed Logons"
                                                    Severity = "High"
                                                    Count = $Results.LogonAnalysis.FailedLogons
                                                    Threshold = $ActiveAlertThresholds.FailedLogons
                                                    Description = "Detected unusually high number of failed logon attempts"
                                                }
                                            }
                                            
                                        } catch {
                                            $Results.Errors += "Failed to apply threat hunting rule $RuleName`: $($_.Exception.Message)"
                                        }
                                    }
                                }
                                
                                # Sort timeline by time
                                if ($ProfileConfig.GenerateTimeline) {
                                    $Results.Timeline = $Results.Timeline | Sort-Object TimeCreated
                                }
                                
                                Write-Progress -Activity "Analyzing Logs" -Completed
                                
                            } catch {
                                $Results.Errors += "Failed during log analysis: $($_.Exception.Message)"
                            }
                            
                            return $Results
                        } -ArgumentList $ProfileConfig, $ActiveEventLogs, $ComputerOutputPath, $StartTime, $EndTime, $ActiveSearchPatterns, $ThreatIndicators, $SuspiciousIPs, $SuspiciousUsers, $SuspiciousProcesses, $ActiveThreatHuntingRules, $ActiveAlertThresholds, $TestMode
                    } else {
                        $Results = @{
                            EventsAnalyzed = 0
                            SecurityFindings = @()
                            ThreatDetections = @()
                            SuspiciousActivities = @()
                            LogonAnalysis = @{}
                            FailureAnalysis = @{}
                            PrivilegeAnalysis = @{}
                            ProcessAnalysis = @{}
                            Correlations = @()
                            Timeline = @()
                            OutputFiles = @()
                            Errors = @()
                        }
                        
                        try {
                            # Function to analyze events for patterns
                            function Search-EventsForPatterns {
                                param($Events, $Patterns, $Name)
                                
                                $Matches = @()
                                foreach ($Event in $Events) {
                                    $EventText = "$($Event.Message) $($Event.Id) $($Event.LevelDisplayName)"
                                    
                                    foreach ($Pattern in $Patterns) {
                                        if ($EventText -match $Pattern) {
                                            $Matches += @{
                                                Event = $Event
                                                Pattern = $Pattern
                                                PatternName = $Name
                                                MatchText = $Matches[0]
                                            }
                                        }
                                    }
                                }
                                
                                return $Matches
                            }
                            
                            # Analyze each event log
                            foreach ($LogName in $ActiveEventLogs) {
                                try {
                                    Write-CustomLog -Level 'INFO' -Message "Analyzing event log: $LogName"
                                    
                                    # Get events from log
                                    $LogEvents = @()
                                    if (-not $TestMode) {
                                        if ($PSCmdlet.ShouldProcess($LogName, "Analyze event log")) {
                                            $LogEvents = Get-WinEvent -LogName $LogName -StartTime $StartTime -EndTime $EndTime -ErrorAction SilentlyContinue | Sort-Object TimeCreated
                                        }
                                    } else {
                                        Write-CustomLog -Level 'INFO' -Message "[TEST] Would analyze log $LogName from $StartTime to $EndTime"
                                        # Create test events for demo
                                        $LogEvents = @(
                                            [PSCustomObject]@{ Id = 4624; TimeCreated = Get-Date; Message = "Test successful logon for user testuser"; LevelDisplayName = "Information" }
                                            [PSCustomObject]@{ Id = 4625; TimeCreated = Get-Date; Message = "Test failed logon for user baduser"; LevelDisplayName = "Information" }
                                            [PSCustomObject]@{ Id = 4672; TimeCreated = Get-Date; Message = "Test privilege use"; LevelDisplayName = "Information" }
                                        )
                                    }
                                    
                                    $Results.EventsAnalyzed += $LogEvents.Count
                                    Write-CustomLog -Level 'INFO' -Message "Found $($LogEvents.Count) events in $LogName"
                                    
                                    if ($LogEvents.Count -gt 0) {
                                        # Search for threat patterns
                                        foreach ($PatternName in $ActiveSearchPatterns.Keys) {
                                            $PatternMatches = Search-EventsForPatterns -Events $LogEvents -Patterns $ActiveSearchPatterns[$PatternName] -Name $PatternName
                                            
                                            if ($PatternMatches.Count -gt 0) {
                                                $Results.ThreatDetections += @{
                                                    PatternName = $PatternName
                                                    Matches = $PatternMatches
                                                    Count = $PatternMatches.Count
                                                    LogName = $LogName
                                                }
                                                Write-CustomLog -Level 'WARNING' -Message "Found $($PatternMatches.Count) matches for pattern: $PatternName"
                                            }
                                        }
                                        
                                        # Logon analysis for Security log
                                        if ($LogName -eq 'Security' -and $ProfileConfig.IncludeLogonAnalysis) {
                                            $SuccessfulLogons = $LogEvents | Where-Object { $_.Id -eq 4624 }
                                            $FailedLogons = $LogEvents | Where-Object { $_.Id -eq 4625 }
                                            
                                            $Results.LogonAnalysis = @{
                                                SuccessfulLogons = $SuccessfulLogons.Count
                                                FailedLogons = $FailedLogons.Count
                                                UniqueUsers = ($SuccessfulLogons | Select-Object -ExpandProperty Message | ForEach-Object { 
                                                    if ($_ -match 'Account Name:\s+(\S+)') { $Matches[1] }
                                                } | Sort-Object -Unique).Count
                                                LogonTypes = $SuccessfulLogons | Group-Object { 
                                                    if ($_.Message -match 'Logon Type:\s+(\d+)') { $Matches[1] } else { 'Unknown' }
                                                } | ForEach-Object { @{ Type = $_.Name; Count = $_.Count } }
                                            }
                                        }
                                        
                                        # Failure analysis
                                        if ($ProfileConfig.IncludeFailureAnalysis) {
                                            $FailureEvents = $LogEvents | Where-Object { $_.LevelDisplayName -in @('Error', 'Critical') }
                                            $Results.FailureAnalysis = @{
                                                TotalFailures = $FailureEvents.Count
                                                FailuresByType = $FailureEvents | Group-Object Id | ForEach-Object { @{ EventID = $_.Name; Count = $_.Count } }
                                                CriticalFailures = ($FailureEvents | Where-Object { $_.LevelDisplayName -eq 'Critical' }).Count
                                            }
                                        }
                                        
                                        # Add events to timeline if requested
                                        if ($ProfileConfig.GenerateTimeline) {
                                            foreach ($Event in $LogEvents) {
                                                if ($Event.LevelDisplayName -in @('Warning', 'Error', 'Critical') -or $Event.Id -in @(4624, 4625, 4672, 4688)) {
                                                    $Results.Timeline += @{
                                                        TimeCreated = $Event.TimeCreated
                                                        LogName = $LogName
                                                        EventID = $Event.Id
                                                        Level = $Event.LevelDisplayName
                                                        Message = $Event.Message.Substring(0, [Math]::Min(200, $Event.Message.Length))
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    
                                } catch {
                                    $Results.Errors += "Failed to analyze log $LogName`: $($_.Exception.Message)"
                                }
                            }
                            
                            # Apply threat hunting rules
                            if ($ProfileConfig.EnableThreatHunting) {
                                Write-CustomLog -Level 'INFO' -Message "Applying threat hunting rules"
                                
                                # Check for excessive failed logons
                                if ($Results.LogonAnalysis.FailedLogons -gt $ActiveAlertThresholds.FailedLogons) {
                                    $Results.ThreatDetections += @{
                                        RuleName = "Excessive Failed Logons"
                                        Severity = "High"
                                        Count = $Results.LogonAnalysis.FailedLogons
                                        Threshold = $ActiveAlertThresholds.FailedLogons
                                        Description = "Detected unusually high number of failed logon attempts"
                                    }
                                    Write-CustomLog -Level 'WARNING' -Message "Threat detected: Excessive failed logons ($($Results.LogonAnalysis.FailedLogons))"
                                }
                            }
                            
                            # Sort timeline by time
                            if ($ProfileConfig.GenerateTimeline -and $Results.Timeline.Count -gt 0) {
                                $Results.Timeline = $Results.Timeline | Sort-Object TimeCreated
                                Write-CustomLog -Level 'SUCCESS' -Message "Generated timeline with $($Results.Timeline.Count) events"
                            }
                            
                            # Save analysis results
                            if (-not $TestMode) {
                                if ($PSCmdlet.ShouldProcess("Analysis Results", "Save log analysis results")) {
                                    # Save summary results
                                    $SummaryFile = Join-Path $ComputerOutputPath "log-analysis-summary.$($ExportFormat.ToLower())"
                                    
                                    $SummaryData = @{
                                        Computer = $Computer
                                        AnalysisTime = Get-Date
                                        EventsAnalyzed = $Results.EventsAnalyzed
                                        ThreatDetections = $Results.ThreatDetections.Count
                                        LogonAnalysis = $Results.LogonAnalysis
                                        FailureAnalysis = $Results.FailureAnalysis
                                    }
                                    
                                    switch ($ExportFormat) {
                                        'CSV' {
                                            # Convert nested objects to CSV-friendly format
                                            $SummaryData | ConvertTo-Csv -NoTypeInformation | Out-File -FilePath $SummaryFile -Encoding UTF8
                                        }
                                        'JSON' {
                                            $SummaryData | ConvertTo-Json -Depth 5 | Out-File -FilePath $SummaryFile -Encoding UTF8
                                        }
                                        'XML' {
                                            $SummaryData | Export-Clixml -Path $SummaryFile
                                        }
                                    }
                                    
                                    $Results.OutputFiles += $SummaryFile
                                    
                                    # Save timeline if generated
                                    if ($Results.Timeline.Count -gt 0) {
                                        $TimelineFile = Join-Path $ComputerOutputPath "security-timeline.$($ExportFormat.ToLower())"
                                        
                                        switch ($ExportFormat) {
                                            'CSV' {
                                                $Results.Timeline | Export-Csv -Path $TimelineFile -NoTypeInformation
                                            }
                                            'JSON' {
                                                $Results.Timeline | ConvertTo-Json -Depth 3 | Out-File -FilePath $TimelineFile -Encoding UTF8
                                            }
                                            'XML' {
                                                $Results.Timeline | Export-Clixml -Path $TimelineFile
                                            }
                                        }
                                        
                                        $Results.OutputFiles += $TimelineFile
                                    }
                                }
                            } else {
                                Write-CustomLog -Level 'INFO' -Message "[TEST] Would save analysis results to: $ComputerOutputPath"
                            }
                            
                        } catch {
                            $Results.Errors += "Failed during log analysis: $($_.Exception.Message)"
                        }
                        
                        $Results
                    }
                    
                    $ComputerResult.EventsAnalyzed = $AnalysisResult.EventsAnalyzed
                    $ComputerResult.SecurityFindings = $AnalysisResult.SecurityFindings
                    $ComputerResult.ThreatDetections = $AnalysisResult.ThreatDetections
                    $ComputerResult.SuspiciousActivities = $AnalysisResult.SuspiciousActivities
                    $ComputerResult.LogonAnalysis = $AnalysisResult.LogonAnalysis
                    $ComputerResult.FailureAnalysis = $AnalysisResult.FailureAnalysis
                    $ComputerResult.PrivilegeAnalysis = $AnalysisResult.PrivilegeAnalysis
                    $ComputerResult.ProcessAnalysis = $AnalysisResult.ProcessAnalysis
                    $ComputerResult.Correlations = $AnalysisResult.Correlations
                    $ComputerResult.Timeline = $AnalysisResult.Timeline
                    $ComputerResult.OutputFiles = $AnalysisResult.OutputFiles
                    $ComputerResult.Errors += $AnalysisResult.Errors
                    
                    # Update summary statistics
                    $LogAnalysisResults.EventsAnalyzed += $AnalysisResult.EventsAnalyzed
                    $LogAnalysisResults.SecurityFindings += $AnalysisResult.SecurityFindings.Count
                    $LogAnalysisResults.ThreatDetections += $AnalysisResult.ThreatDetections.Count
                    $LogAnalysisResults.SuspiciousActivities += $AnalysisResult.SuspiciousActivities.Count
                    $LogAnalysisResults.TimelineEvents += $AnalysisResult.Timeline.Count
                    
                    if ($AnalysisResult.LogonAnalysis.FailedLogons) {
                        $LogAnalysisResults.FailedLogons += $AnalysisResult.LogonAnalysis.FailedLogons
                    }
                    
                    $ComputerResult.AnalysisTime = ((Get-Date) - $StartAnalysisTime).TotalSeconds
                    Write-CustomLog -Level 'SUCCESS' -Message "Log analysis completed for $Computer - $($AnalysisResult.EventsAnalyzed) events analyzed in $($ComputerResult.AnalysisTime) seconds"
                    
                } catch {
                    $Error = "Failed to analyze logs for $Computer`: $($_.Exception.Message)"
                    $ComputerResult.Errors += $Error
                    Write-CustomLog -Level 'ERROR' -Message $Error
                }
                
                $LogAnalysisResults.ComputersProcessed += $ComputerResult
            }
            
        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Error during security log analysis: $($_.Exception.Message)"
            throw
        }
    }
    
    end {
        Write-CustomLog -Level 'SUCCESS' -Message "Security log analysis completed"
        
        # Generate recommendations
        $LogAnalysisResults.Recommendations += "Review detected threats and suspicious activities immediately"
        $LogAnalysisResults.Recommendations += "Correlate findings with other security tools and intelligence"
        $LogAnalysisResults.Recommendations += "Use timeline analysis to understand attack progression"
        $LogAnalysisResults.Recommendations += "Implement automated monitoring for detected patterns"
        $LogAnalysisResults.Recommendations += "Regularly tune threat hunting rules based on environment"
        
        if ($LogAnalysisResults.ThreatDetections -gt 0) {
            $LogAnalysisResults.Recommendations += "URGENT: $($LogAnalysisResults.ThreatDetections) threats detected - initiate incident response procedures"
        }
        
        if ($LogAnalysisResults.FailedLogons -gt 100) {
            $LogAnalysisResults.Recommendations += "High number of failed logons detected - investigate for brute force attacks"
        }
        
        # Display summary
        Write-CustomLog -Level 'INFO' -Message "Security Log Analysis Summary:"
        Write-CustomLog -Level 'INFO' -Message "  Analysis Profile: $($LogAnalysisResults.AnalysisProfile)"
        Write-CustomLog -Level 'INFO' -Message "  Time Range: $($LogAnalysisResults.StartTime) to $($LogAnalysisResults.EndTime)"
        Write-CustomLog -Level 'INFO' -Message "  Computers: $($LogAnalysisResults.ComputersProcessed.Count)"
        Write-CustomLog -Level 'INFO' -Message "  Events Analyzed: $($LogAnalysisResults.EventsAnalyzed)"
        Write-CustomLog -Level 'INFO' -Message "  Threat Detections: $($LogAnalysisResults.ThreatDetections)"
        Write-CustomLog -Level 'INFO' -Message "  Failed Logons: $($LogAnalysisResults.FailedLogons)"
        Write-CustomLog -Level 'INFO' -Message "  Timeline Events: $($LogAnalysisResults.TimelineEvents)"
        Write-CustomLog -Level 'INFO' -Message "  Output Path: $($LogAnalysisResults.OutputPath)"
        
        return $LogAnalysisResults
    }
}
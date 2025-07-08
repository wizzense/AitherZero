function Search-SecurityEvents {
    <#
    .SYNOPSIS
        Advanced security event log search and analysis with threat correlation.

    .DESCRIPTION
        Performs sophisticated searches across Windows Security event logs to identify
        security incidents, patterns, and anomalies. Supports cross-system correlation,
        threat hunting queries, and automated incident detection.

    .PARAMETER ComputerName
        Target computers for event log search. Default: localhost

    .PARAMETER EventCategories
        Predefined security event categories to search

    .PARAMETER EventIDs
        Specific event IDs to search for

    .PARAMETER LogNames
        Event log names to search. Default: Security

    .PARAMETER StartTime
        Start time for event search range

    .PARAMETER EndTime
        End time for event search range. Default: current time

    .PARAMETER MaxEvents
        Maximum number of events to return per computer

    .PARAMETER Keywords
        Keywords to search for in event messages

    .PARAMETER Users
        Specific usernames to filter events

    .PARAMETER ComputerNames
        Computer names to filter events (different from source computers)

    .PARAMETER ThreatHunting
        Enable threat hunting mode with advanced correlation

    .PARAMETER CorrelateEvents
        Correlate events across multiple systems and time windows

    .PARAMETER OutputFormat
        Output format: Object, JSON, CSV, SIEM

    .PARAMETER ExportPath
        Path to export search results

    .PARAMETER Credential
        Credentials for remote computer access

    .PARAMETER RealTime
        Monitor events in real-time mode

    .EXAMPLE
        Search-SecurityEvents -EventCategories @("FailedLogon", "AccountLockout") -StartTime (Get-Date).AddHours(-24)

    .EXAMPLE
        Search-SecurityEvents -ComputerName @("DC01", "DC02") -ThreatHunting -Keywords @("KRBTGT", "Golden") -ExportPath "C:\Investigation\krb-events.json"

    .EXAMPLE
        Search-SecurityEvents -EventIDs @(4624, 4625, 4648) -Users @("admin", "service-account") -CorrelateEvents
    #>

    [CmdletBinding()]
    param(
        [Parameter()]
        [string[]]$ComputerName = @('localhost'),

        [Parameter()]
        [ValidateSet('FailedLogon', 'SuccessfulLogon', 'AccountLockout', 'AccountManagement',
                     'PasswordChanges', 'PrivilegeUse', 'ProcessCreation', 'NetworkAccess',
                     'PolicyChanges', 'SystemEvents', 'KerberosEvents', 'ThreatIndicators')]
        [string[]]$EventCategories,

        [Parameter()]
        [int[]]$EventIDs,

        [Parameter()]
        [string[]]$LogNames = @('Security'),

        [Parameter()]
        [datetime]$StartTime = (Get-Date).AddHours(-24),

        [Parameter()]
        [datetime]$EndTime = (Get-Date),

        [Parameter()]
        [int]$MaxEvents = 1000,

        [Parameter()]
        [string[]]$Keywords,

        [Parameter()]
        [string[]]$Users,

        [Parameter()]
        [string[]]$ComputerNames,

        [Parameter()]
        [switch]$ThreatHunting,

        [Parameter()]
        [switch]$CorrelateEvents,

        [Parameter()]
        [ValidateSet('Object', 'JSON', 'CSV', 'SIEM')]
        [string]$OutputFormat = 'Object',

        [Parameter()]
        [string]$ExportPath,

        [Parameter()]
        [pscredential]$Credential,

        [Parameter()]
        [switch]$RealTime
    )

    begin {
        Write-CustomLog -Level 'INFO' -Message "Starting security event search across $($ComputerName.Count) computer(s)"

        # Define event category mappings
        $EventCategoryMap = @{
            'FailedLogon' = @(529, 4625, 4771, 4776)           # Failed logon attempts
            'SuccessfulLogon' = @(528, 4624, 4768, 4769)       # Successful logons
            'AccountLockout' = @(644, 4740)                    # Account lockouts
            'AccountManagement' = @(624, 626, 630, 4720, 4722, 4724, 4726, 4728, 4732, 4756) # User/group management
            'PasswordChanges' = @(627, 628, 4723, 4724)        # Password changes
            'PrivilegeUse' = @(576, 577, 4672, 4673, 4674)     # Privilege use
            'ProcessCreation' = @(592, 4688)                   # Process creation
            'NetworkAccess' = @(540, 4779, 4778, 4647)         # Network/RDP access
            'PolicyChanges' = @(612, 4719, 4739, 4902)         # Security policy changes
            'SystemEvents' = @(517, 1102, 6008, 4608, 4609)    # System startup/shutdown, log clearing
            'KerberosEvents' = @(4768, 4769, 4771, 4772)       # Kerberos authentication
            'ThreatIndicators' = @(4648, 4649, 4672, 5140, 5145) # Suspicious activities
        }

        # Build event ID list from categories
        $AllEventIDs = @()
        if ($EventCategories) {
            foreach ($Category in $EventCategories) {
                if ($EventCategoryMap.ContainsKey($Category)) {
                    $AllEventIDs += $EventCategoryMap[$Category]
                }
            }
        }

        # Add specific event IDs
        if ($EventIDs) {
            $AllEventIDs += $EventIDs
        }

        # If no specific events specified, use common security events
        if ($AllEventIDs.Count -eq 0) {
            $AllEventIDs = @(4624, 4625, 4648, 4672, 4688, 4720, 4740)
        }

        $AllEventIDs = $AllEventIDs | Sort-Object -Unique

        Write-CustomLog -Level 'INFO' -Message "Searching for event IDs: $($AllEventIDs -join ', ')"

        $SearchResults = @{
            SearchParameters = @{
                ComputerName = $ComputerName
                EventIDs = $AllEventIDs
                StartTime = $StartTime
                EndTime = $EndTime
                Keywords = $Keywords
                Users = $Users
            }
            Events = @()
            CorrelatedFindings = @()
            ThreatIndicators = @()
            Statistics = @{}
        }

        # Define threat hunting patterns
        $ThreatPatterns = @{
            'GoldenTicket' = @{
                Keywords = @('KRBTGT', 'Golden')
                EventIDs = @(4768, 4769)
                Description = 'Potential Golden Ticket attack indicators'
            }
            'PassTheHash' = @{
                Keywords = @('NTLM', 'Type 3')
                EventIDs = @(4624, 4625)
                Description = 'Potential Pass-the-Hash attack indicators'
            }
            'BruteForce' = @{
                EventIDs = @(4625, 4771)
                Description = 'Potential brute force attack (multiple failed logons)'
                Threshold = 10
            }
            'PrivilegeEscalation' = @{
                EventIDs = @(4672, 4673, 4674)
                Description = 'Potential privilege escalation indicators'
            }
            'LateralMovement' = @{
                EventIDs = @(4648, 4624)
                Keywords = @('Logon Type 3', 'Network')
                Description = 'Potential lateral movement indicators'
            }
        }
    }

    process {
        try {
            foreach ($Computer in $ComputerName) {
                Write-CustomLog -Level 'INFO' -Message "Searching events on: $Computer"

                try {
                    # Build event search parameters
                    $SearchParams = @{
                        ComputerName = $Computer
                        ErrorAction = 'Stop'
                    }

                    if ($Credential) {
                        $SearchParams['Credential'] = $Credential
                    }

                    foreach ($LogName in $LogNames) {
                        Write-CustomLog -Level 'INFO' -Message "Searching $LogName log on $Computer"

                        # Build WMI query for event search
                        $EventIDFilter = "(" + ($AllEventIDs | ForEach-Object { "EventCode = '$_'" }) -join " OR " + ")"
                        $TimeFilter = "TimeGenerated >= '$($StartTime.ToString('yyyyMMddHHmmss.ffffff-000'))' AND TimeGenerated <= '$($EndTime.ToString('yyyyMMddHHmmss.ffffff-000'))'"

                        $WMIQuery = "SELECT * FROM Win32_NTLogEvent WHERE LogFile = '$LogName' AND $EventIDFilter AND $TimeFilter"

                        try {
                            $Events = Get-CimInstance -Query $WMIQuery @SearchParams |
                                     Select-Object -First $MaxEvents |
                                     Select-Object RecordNumber, TimeGenerated, ComputerName, LogFile,
                                                 User, SourceName, EventCode, Type, Message, InsertionStrings

                            Write-CustomLog -Level 'INFO' -Message "Found $($Events.Count) events in $LogName on $Computer"

                            # Apply additional filters
                            if ($Keywords) {
                                $Events = $Events | Where-Object {
                                    $Message = $_.Message
                                    $Keywords | ForEach-Object { $Message -like "*$_*" } | Where-Object { $_ } | Select-Object -First 1
                                }
                            }

                            if ($Users) {
                                $Events = $Events | Where-Object {
                                    $User = $_.User
                                    $Users | ForEach-Object { $User -like "*$_*" } | Where-Object { $_ } | Select-Object -First 1
                                }
                            }

                            if ($ComputerNames) {
                                $Events = $Events | Where-Object {
                                    $CompName = $_.ComputerName
                                    $ComputerNames | ForEach-Object { $CompName -like "*$_*" } | Where-Object { $_ } | Select-Object -First 1
                                }
                            }

                            # Add enriched information
                            foreach ($Event in $Events) {
                                $EnrichedEvent = $Event | Select-Object *,
                                                @{N='SourceComputer';E={$Computer}},
                                                @{N='SearchTimestamp';E={Get-Date}},
                                                @{N='EventCategory';E={
                                                    $EventCode = $_.EventCode
                                                    foreach ($Category in $EventCategoryMap.Keys) {
                                                        if ($EventCategoryMap[$Category] -contains $EventCode) {
                                                            $Category
                                                            break
                                                        }
                                                    }
                                                }},
                                                @{N='ThreatLevel';E={'Low'}},
                                                @{N='IsCorrelated';E={$false}}

                                $SearchResults.Events += $EnrichedEvent
                            }

                        } catch {
                            Write-CustomLog -Level 'WARNING' -Message "Failed to search $LogName on $Computer`: $($_.Exception.Message)"
                        }
                    }

                } catch {
                    Write-CustomLog -Level 'ERROR' -Message "Failed to connect to $Computer`: $($_.Exception.Message)"
                }
            }

            Write-CustomLog -Level 'SUCCESS' -Message "Event search completed. Found $($SearchResults.Events.Count) total events"

            # Threat hunting analysis
            if ($ThreatHunting -and $SearchResults.Events.Count -gt 0) {
                Write-CustomLog -Level 'INFO' -Message "Performing threat hunting analysis"

                foreach ($PatternName in $ThreatPatterns.Keys) {
                    $Pattern = $ThreatPatterns[$PatternName]
                    $MatchingEvents = @()

                    # Filter events by pattern criteria
                    $PatternEvents = $SearchResults.Events | Where-Object {
                        $Event = $_
                        $EventMatches = $true

                        # Check Event IDs
                        if ($Pattern.EventIDs -and $Pattern.EventIDs -notcontains $Event.EventCode) {
                            $EventMatches = $false
                        }

                        # Check Keywords
                        if ($Pattern.Keywords -and $EventMatches) {
                            $KeywordMatch = $false
                            foreach ($Keyword in $Pattern.Keywords) {
                                if ($Event.Message -like "*$Keyword*") {
                                    $KeywordMatch = $true
                                    break
                                }
                            }
                            if (-not $KeywordMatch) {
                                $EventMatches = $false
                            }
                        }

                        return $EventMatches
                    }

                    if ($PatternEvents.Count -gt 0) {
                        # Check threshold for patterns that have one
                        if ($Pattern.Threshold -and $PatternEvents.Count -ge $Pattern.Threshold) {
                            $ThreatLevel = 'High'
                        } elseif ($PatternEvents.Count -ge 5) {
                            $ThreatLevel = 'Medium'
                        } else {
                            $ThreatLevel = 'Low'
                        }

                        $ThreatIndicator = @{
                            PatternName = $PatternName
                            Description = $Pattern.Description
                            ThreatLevel = $ThreatLevel
                            EventCount = $PatternEvents.Count
                            Events = $PatternEvents
                            FirstSeen = ($PatternEvents | Sort-Object TimeGenerated | Select-Object -First 1).TimeGenerated
                            LastSeen = ($PatternEvents | Sort-Object TimeGenerated | Select-Object -Last 1).TimeGenerated
                            AffectedSystems = ($PatternEvents | Select-Object -ExpandProperty SourceComputer | Sort-Object -Unique)
                        }

                        $SearchResults.ThreatIndicators += $ThreatIndicator

                        # Update threat level in original events
                        foreach ($Event in $PatternEvents) {
                            $Event.ThreatLevel = $ThreatLevel
                        }

                        Write-CustomLog -Level 'WARNING' -Message "Threat pattern detected: $PatternName ($($PatternEvents.Count) events, $ThreatLevel risk)"
                    }
                }
            }

            # Event correlation
            if ($CorrelateEvents -and $SearchResults.Events.Count -gt 0) {
                Write-CustomLog -Level 'INFO' -Message "Performing event correlation analysis"

                # Time-based correlation (events within 5 minutes)
                $CorrelationWindow = New-TimeSpan -Minutes 5
                $CorrelatedSets = @()

                # Group events by user and computer
                $EventGroups = $SearchResults.Events | Group-Object User, ComputerName

                foreach ($Group in $EventGroups) {
                    if ($Group.Count -gt 1) {
                        $GroupEvents = $Group.Group | Sort-Object TimeGenerated

                        for ($i = 0; $i -lt $GroupEvents.Count - 1; $i++) {
                            $CurrentEvent = $GroupEvents[$i]
                            $NextEvent = $GroupEvents[$i + 1]

                            $TimeDiff = $NextEvent.TimeGenerated - $CurrentEvent.TimeGenerated

                            if ($TimeDiff -le $CorrelationWindow) {
                                $CorrelatedSet = @{
                                    Events = @($CurrentEvent, $NextEvent)
                                    User = $Group.Name.Split(',')[0]
                                    Computer = $Group.Name.Split(',')[1]
                                    TimeSpan = $TimeDiff
                                    Pattern = "Sequential events within correlation window"
                                }

                                $CorrelatedSets += $CorrelatedSet

                                # Mark events as correlated
                                $CurrentEvent.IsCorrelated = $true
                                $NextEvent.IsCorrelated = $true
                            }
                        }
                    }
                }

                $SearchResults.CorrelatedFindings = $CorrelatedSets
                Write-CustomLog -Level 'INFO' -Message "Found $($CorrelatedSets.Count) correlated event sets"
            }

            # Generate statistics
            $SearchResults.Statistics = @{
                TotalEvents = $SearchResults.Events.Count
                UniqueComputers = ($SearchResults.Events | Select-Object -ExpandProperty SourceComputer | Sort-Object -Unique).Count
                UniqueUsers = ($SearchResults.Events | Select-Object -ExpandProperty User | Where-Object {$_} | Sort-Object -Unique).Count
                ThreatIndicators = $SearchResults.ThreatIndicators.Count
                CorrelatedEvents = ($SearchResults.Events | Where-Object {$_.IsCorrelated}).Count
                HighRiskEvents = ($SearchResults.Events | Where-Object {$_.ThreatLevel -eq 'High'}).Count
                EventsByCategory = @{}
                EventsByComputer = @{}
            }

            # Calculate category statistics
            foreach ($Category in $EventCategoryMap.Keys) {
                $CategoryEvents = $SearchResults.Events | Where-Object {$_.EventCategory -eq $Category}
                if ($CategoryEvents.Count -gt 0) {
                    $SearchResults.Statistics.EventsByCategory[$Category] = $CategoryEvents.Count
                }
            }

            # Calculate computer statistics
            foreach ($Computer in $ComputerName) {
                $ComputerEvents = $SearchResults.Events | Where-Object {$_.SourceComputer -eq $Computer}
                if ($ComputerEvents.Count -gt 0) {
                    $SearchResults.Statistics.EventsByComputer[$Computer] = $ComputerEvents.Count
                }
            }

        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Error during security event search: $($_.Exception.Message)"
            throw
        }
    }

    end {
        Write-CustomLog -Level 'SUCCESS' -Message "Security event search completed"

        # Format output based on requested format
        $FormattedResults = switch ($OutputFormat) {
            'JSON' {
                $SearchResults | ConvertTo-Json -Depth 10
            }
            'CSV' {
                $SearchResults.Events | ConvertTo-Csv -NoTypeInformation
            }
            'SIEM' {
                # SIEM-friendly format (CEF-like)
                $SearchResults.Events | ForEach-Object {
                    $Event = $_
                    "CEF:0|Microsoft|Windows|$($Event.SourceComputer)|$($Event.EventCode)|$($Event.SourceName)|$($Event.ThreatLevel)|src=$($Event.ComputerName) suser=$($Event.User) rt=$($Event.TimeGenerated.ToString('MMM dd yyyy HH:mm:ss')) msg=$($Event.Message -replace '\r?\n', ' ')"
                }
            }
            default {
                $SearchResults
            }
        }

        # Export results if requested
        if ($ExportPath) {
            try {
                if ($OutputFormat -eq 'Object') {
                    $FormattedResults | ConvertTo-Json -Depth 10 | Out-File -FilePath $ExportPath -Encoding UTF8
                } else {
                    $FormattedResults | Out-File -FilePath $ExportPath -Encoding UTF8
                }
                Write-CustomLog -Level 'SUCCESS' -Message "Search results exported to: $ExportPath"
            } catch {
                Write-CustomLog -Level 'ERROR' -Message "Failed to export results: $($_.Exception.Message)"
            }
        }

        # Display summary
        Write-CustomLog -Level 'INFO' -Message "Search Results Summary:"
        Write-CustomLog -Level 'INFO' -Message "  Total Events: $($SearchResults.Statistics.TotalEvents)"
        Write-CustomLog -Level 'INFO' -Message "  Unique Computers: $($SearchResults.Statistics.UniqueComputers)"
        Write-CustomLog -Level 'INFO' -Message "  Unique Users: $($SearchResults.Statistics.UniqueUsers)"

        if ($ThreatHunting) {
            Write-CustomLog -Level 'INFO' -Message "  Threat Indicators: $($SearchResults.Statistics.ThreatIndicators)"
            Write-CustomLog -Level 'INFO' -Message "  High Risk Events: $($SearchResults.Statistics.HighRiskEvents)"
        }

        if ($CorrelateEvents) {
            Write-CustomLog -Level 'INFO' -Message "  Correlated Events: $($SearchResults.Statistics.CorrelatedEvents)"
        }

        # Display warnings for high-risk findings
        foreach ($Threat in $SearchResults.ThreatIndicators) {
            if ($Threat.ThreatLevel -eq 'High') {
                Write-CustomLog -Level 'ERROR' -Message "HIGH RISK: $($Threat.Description) - $($Threat.EventCount) events"
            } elseif ($Threat.ThreatLevel -eq 'Medium') {
                Write-CustomLog -Level 'WARNING' -Message "MEDIUM RISK: $($Threat.Description) - $($Threat.EventCount) events"
            }
        }

        return $FormattedResults
    }
}

function Get-PrivilegedAccountActivity {
    <#
    .SYNOPSIS
        Monitors and analyzes privileged account activities across the enterprise.
        
    .DESCRIPTION
        Provides comprehensive monitoring of privileged account usage including
        logon activities, permission changes, administrative actions, and suspicious
        behaviors. Integrates with multiple data sources for complete visibility.
        
    .PARAMETER ComputerName
        Target computers for activity monitoring. Default: localhost
        
    .PARAMETER AccountNames
        Specific privileged account names to monitor
        
    .PARAMETER PrivilegedGroups
        Active Directory groups containing privileged accounts
        
    .PARAMETER TimeRange
        Time range for activity analysis
        
    .PARAMETER StartTime
        Start time for activity search
        
    .PARAMETER EndTime
        End time for activity search. Default: current time
        
    .PARAMETER ActivityTypes
        Types of activities to monitor
        
    .PARAMETER IncludeSuccessfulLogons
        Include successful logon events in analysis
        
    .PARAMETER IncludeFailedLogons
        Include failed logon events in analysis
        
    .PARAMETER IncludePermissionChanges
        Include permission and group membership changes
        
    .PARAMETER IncludeAdminActions
        Include administrative actions and commands
        
    .PARAMETER SuspiciousActivityOnly
        Only return potentially suspicious activities
        
    .PARAMETER RiskThreshold
        Risk threshold for flagging activities: Low, Medium, High
        
    .PARAMETER CorrelateActivities
        Correlate activities across multiple systems and time windows
        
    .PARAMETER OutputFormat
        Output format: Object, JSON, CSV, SIEM, Timeline
        
    .PARAMETER ExportPath
        Path to export activity results
        
    .PARAMETER IncludeDomainControllers
        Include Domain Controller specific activities
        
    .PARAMETER MaxEvents
        Maximum number of events to return per computer
        
    .PARAMETER Credential
        Credentials for remote computer access
        
    .EXAMPLE
        Get-PrivilegedAccountActivity -PrivilegedGroups @('Domain Admins', 'Enterprise Admins') -TimeRange 'Last24Hours'
        
    .EXAMPLE
        Get-PrivilegedAccountActivity -AccountNames @('admin1', 'admin2') -SuspiciousActivityOnly -CorrelateActivities
        
    .EXAMPLE
        Get-PrivilegedAccountActivity -IncludeDomainControllers -OutputFormat Timeline -ExportPath 'C:\Reports\admin-timeline.html'
    #>
    
    [CmdletBinding()]
    param(
        [Parameter()]
        [string[]]$ComputerName = @('localhost'),
        
        [Parameter()]
        [string[]]$AccountNames = @(),
        
        [Parameter()]
        [string[]]$PrivilegedGroups = @('Domain Admins', 'Enterprise Admins', 'Schema Admins', 'Administrators'),
        
        [Parameter()]
        [ValidateSet('LastHour', 'Last4Hours', 'Last24Hours', 'LastWeek', 'LastMonth', 'Custom')]
        [string]$TimeRange = 'Last24Hours',
        
        [Parameter()]
        [datetime]$StartTime,
        
        [Parameter()]
        [datetime]$EndTime = (Get-Date),
        
        [Parameter()]
        [ValidateSet('Logons', 'PermissionChanges', 'AdminActions', 'ProcessCreation', 'FileAccess', 'RegistryAccess')]
        [string[]]$ActivityTypes = @('Logons', 'PermissionChanges', 'AdminActions'),
        
        [Parameter()]
        [switch]$IncludeSuccessfulLogons,
        
        [Parameter()]
        [switch]$IncludeFailedLogons,
        
        [Parameter()]
        [switch]$IncludePermissionChanges,
        
        [Parameter()]
        [switch]$IncludeAdminActions,
        
        [Parameter()]
        [switch]$SuspiciousActivityOnly,
        
        [Parameter()]
        [ValidateSet('Low', 'Medium', 'High')]
        [string]$RiskThreshold = 'Medium',
        
        [Parameter()]
        [switch]$CorrelateActivities,
        
        [Parameter()]
        [ValidateSet('Object', 'JSON', 'CSV', 'SIEM', 'Timeline')]
        [string]$OutputFormat = 'Object',
        
        [Parameter()]
        [string]$ExportPath,
        
        [Parameter()]
        [switch]$IncludeDomainControllers,
        
        [Parameter()]
        [ValidateRange(1, 50000)]
        [int]$MaxEvents = 10000,
        
        [Parameter()]
        [pscredential]$Credential
    )
    
    begin {
        Write-CustomLog -Level 'INFO' -Message "Starting privileged account activity monitoring"
        
        # Calculate time range
        if ($TimeRange -eq 'Custom') {
            if (-not $StartTime) {
                throw "StartTime parameter required when TimeRange is Custom"
            }
        } else {
            $StartTime = switch ($TimeRange) {
                'LastHour' { (Get-Date).AddHours(-1) }
                'Last4Hours' { (Get-Date).AddHours(-4) }
                'Last24Hours' { (Get-Date).AddDays(-1) }
                'LastWeek' { (Get-Date).AddDays(-7) }
                'LastMonth' { (Get-Date).AddDays(-30) }
            }
        }
        
        # Adjust activity types based on switches
        if ($IncludeSuccessfulLogons -and $ActivityTypes -notcontains 'Logons') {
            $ActivityTypes += 'Logons'
        }
        if ($IncludeFailedLogons -and $ActivityTypes -notcontains 'Logons') {
            $ActivityTypes += 'Logons'
        }
        if ($IncludePermissionChanges -and $ActivityTypes -notcontains 'PermissionChanges') {
            $ActivityTypes += 'PermissionChanges'
        }
        if ($IncludeAdminActions -and $ActivityTypes -notcontains 'AdminActions') {
            $ActivityTypes += 'AdminActions'
        }
        
        # Event ID mappings for different activity types
        $EventIDMap = @{
            'Logons' = @{
                Successful = @(4624, 4768, 4769)  # Successful logons, Kerberos TGT/TGS
                Failed = @(4625, 4771, 4776)      # Failed logons, Kerberos failures
            }
            'PermissionChanges' = @{
                GroupMembership = @(4728, 4729, 4732, 4733, 4756, 4757)  # Group membership changes
                UserAccount = @(4720, 4722, 4724, 4726)                  # User account changes
                Permissions = @(4670, 4703, 4717, 4718, 4719)            # Permission changes
            }
            'AdminActions' = @{
                PrivilegeUse = @(4672, 4673, 4674)                       # Privilege use
                ProcessCreation = @(4688)                                # Process creation
                ServiceControl = @(7034, 7035, 7036)                     # Service control
            }
            'ProcessCreation' = @{
                All = @(4688)
            }
            'FileAccess' = @{
                All = @(4656, 4658, 4663)  # File access events
            }
            'RegistryAccess' = @{
                All = @(4657)  # Registry access events
            }
        }
        
        $ActivityResults = @{
            TimeRange = @{
                StartTime = $StartTime
                EndTime = $EndTime
                Duration = $EndTime - $StartTime
            }
            ComputersAnalyzed = @()
            TotalActivities = 0
            SuspiciousActivities = 0
            PrivilegedAccounts = @()
            ActivitySummary = @{}
            CorrelatedEvents = @()
            RiskIndicators = @()
            Errors = @()
        }
        
        # Risk scoring patterns
        $RiskPatterns = @{
            'MultipleFailedLogons' = @{
                Description = 'Multiple failed logon attempts'
                RiskLevel = 'High'
                Threshold = 5
                EventIDs = @(4625, 4771, 4776)
            }
            'OffHoursActivity' = @{
                Description = 'Activity outside business hours'
                RiskLevel = 'Medium'
                BusinessHours = @{Start = 8; End = 18}
            }
            'UnusualLocation' = @{
                Description = 'Logon from unusual location'
                RiskLevel = 'Medium'
            }
            'PrivilegeEscalation' = @{
                Description = 'Potential privilege escalation'
                RiskLevel = 'High'
                EventIDs = @(4672, 4673, 4674)
            }
            'AccountManipulation' = @{
                Description = 'Suspicious account management activity'
                RiskLevel = 'High'
                EventIDs = @(4720, 4722, 4724, 4726, 4728, 4729, 4732, 4733)
            }
        }
        
        # Get privileged account list
        $AllPrivilegedAccounts = @()
        
        # Add explicitly specified accounts
        $AllPrivilegedAccounts += $AccountNames
        
        # Get accounts from privileged groups
        if (Get-Module -ListAvailable -Name ActiveDirectory) {
            try {
                Import-Module ActiveDirectory -ErrorAction SilentlyContinue
                
                foreach ($GroupName in $PrivilegedGroups) {
                    try {
                        $Group = Get-ADGroup -Filter "Name -eq '$GroupName'" -ErrorAction SilentlyContinue
                        if ($Group) {
                            $GroupMembers = Get-ADGroupMember -Identity $Group -ErrorAction SilentlyContinue
                            foreach ($Member in $GroupMembers) {
                                if ($Member.objectClass -eq 'user') {
                                    $AllPrivilegedAccounts += $Member.SamAccountName
                                }
                            }
                        }
                    } catch {
                        Write-CustomLog -Level 'WARNING' -Message "Could not enumerate group: $GroupName"
                    }
                }
            } catch {
                Write-CustomLog -Level 'WARNING' -Message "Active Directory module not available"
            }
        }
        
        # Remove duplicates and convert to lowercase
        $AllPrivilegedAccounts = $AllPrivilegedAccounts | Where-Object {$_} | ForEach-Object {$_.ToLower()} | Sort-Object -Unique
        
        Write-CustomLog -Level 'INFO' -Message "Monitoring $($AllPrivilegedAccounts.Count) privileged accounts"
        $ActivityResults.PrivilegedAccounts = $AllPrivilegedAccounts
        
        # Include Domain Controllers if requested
        if ($IncludeDomainControllers) {
            try {
                $DomainControllers = Get-ADDomainController -Filter * -ErrorAction SilentlyContinue | Select-Object -ExpandProperty HostName
                if ($DomainControllers) {
                    $ComputerName = ($ComputerName + $DomainControllers) | Sort-Object -Unique
                    Write-CustomLog -Level 'INFO' -Message "Added $($DomainControllers.Count) Domain Controllers to monitoring scope"
                }
            } catch {
                Write-CustomLog -Level 'WARNING' -Message "Could not enumerate Domain Controllers"
            }
        }
    }
    
    process {
        try {
            foreach ($Computer in $ComputerName) {
                Write-CustomLog -Level 'INFO' -Message "Analyzing privileged account activity on: $Computer"
                
                $ComputerResult = @{
                    ComputerName = $Computer
                    AnalysisTime = Get-Date
                    Activities = @()
                    SuspiciousCount = 0
                    ActivityCounts = @{}
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
                    
                    # Collect events for each activity type
                    foreach ($ActivityType in $ActivityTypes) {
                        Write-CustomLog -Level 'INFO' -Message "Collecting $ActivityType activities from $Computer"
                        
                        $EventIDs = @()
                        
                        # Get relevant event IDs for this activity type
                        switch ($ActivityType) {
                            'Logons' {
                                if ($IncludeSuccessfulLogons) {
                                    $EventIDs += $EventIDMap.Logons.Successful
                                }
                                if ($IncludeFailedLogons) {
                                    $EventIDs += $EventIDMap.Logons.Failed
                                }
                                if (-not $IncludeSuccessfulLogons -and -not $IncludeFailedLogons) {
                                    $EventIDs += $EventIDMap.Logons.Successful + $EventIDMap.Logons.Failed
                                }
                            }
                            'PermissionChanges' {
                                $EventIDs += $EventIDMap.PermissionChanges.GroupMembership
                                $EventIDs += $EventIDMap.PermissionChanges.UserAccount
                                $EventIDs += $EventIDMap.PermissionChanges.Permissions
                            }
                            'AdminActions' {
                                $EventIDs += $EventIDMap.AdminActions.PrivilegeUse
                                $EventIDs += $EventIDMap.AdminActions.ProcessCreation
                                $EventIDs += $EventIDMap.AdminActions.ServiceControl
                            }
                            'ProcessCreation' {
                                $EventIDs += $EventIDMap.ProcessCreation.All
                            }
                            'FileAccess' {
                                $EventIDs += $EventIDMap.FileAccess.All
                            }
                            'RegistryAccess' {
                                $EventIDs += $EventIDMap.RegistryAccess.All
                            }
                        }
                        
                        # Remove duplicates
                        $EventIDs = $EventIDs | Sort-Object -Unique
                        
                        # Search for events
                        $Events = if ($Computer -ne 'localhost') {
                            Invoke-Command @SessionParams -ScriptBlock {
                                param($EventIDs, $StartTime, $EndTime, $MaxEvents, $AllPrivilegedAccounts)
                                
                                $FilterScript = {
                                    $_.TimeCreated -ge $StartTime -and 
                                    $_.TimeCreated -le $EndTime -and
                                    $EventIDs -contains $_.Id
                                }
                                
                                try {
                                    Get-WinEvent -FilterHashtable @{
                                        LogName = 'Security'
                                        ID = $EventIDs
                                        StartTime = $StartTime
                                        EndTime = $EndTime
                                    } -MaxEvents $MaxEvents -ErrorAction SilentlyContinue |
                                    Where-Object $FilterScript |
                                    Select-Object TimeCreated, Id, LevelDisplayName, Message, Properties, @{N='ComputerName';E={$env:COMPUTERNAME}}
                                } catch {
                                    @()
                                }
                            } -ArgumentList $EventIDs, $StartTime, $EndTime, $MaxEvents, $AllPrivilegedAccounts
                        } else {
                            try {
                                Get-WinEvent -FilterHashtable @{
                                    LogName = 'Security'
                                    ID = $EventIDs
                                    StartTime = $StartTime
                                    EndTime = $EndTime
                                } -MaxEvents $MaxEvents -ErrorAction SilentlyContinue |
                                Select-Object TimeCreated, Id, LevelDisplayName, Message, Properties, @{N='ComputerName';E={$env:COMPUTERNAME}}
                            } catch {
                                @()
                            }
                        }
                        
                        Write-CustomLog -Level 'INFO' -Message "Found $($Events.Count) $ActivityType events on $Computer"
                        
                        # Process and analyze events
                        foreach ($Event in $Events) {
                            try {
                                # Extract user information from event
                                $UserAccount = $null
                                $SourceIP = $null
                                $ProcessName = $null
                                
                                # Parse event message for user account (basic parsing)
                                if ($Event.Message -match 'Account Name:\s+([^\r\n]+)') {
                                    $UserAccount = $matches[1].Trim()
                                }
                                
                                # Parse for source IP
                                if ($Event.Message -match 'Source Network Address:\s+([^\r\n]+)') {
                                    $SourceIP = $matches[1].Trim()
                                }
                                
                                # Parse for process name
                                if ($Event.Message -match 'Process Name:\s+([^\r\n]+)') {
                                    $ProcessName = $matches[1].Trim()
                                }
                                
                                # Check if this involves a privileged account
                                $IsPrivilegedAccount = $UserAccount -and ($AllPrivilegedAccounts -contains $UserAccount.ToLower())
                                
                                if ($IsPrivilegedAccount -or -not $SuspiciousActivityOnly) {
                                    $Activity = @{
                                        Timestamp = $Event.TimeCreated
                                        Computer = $Computer
                                        EventID = $Event.Id
                                        ActivityType = $ActivityType
                                        UserAccount = $UserAccount
                                        SourceIP = $SourceIP
                                        ProcessName = $ProcessName
                                        Message = $Event.Message
                                        IsPrivileged = $IsPrivilegedAccount
                                        RiskLevel = 'Low'
                                        RiskIndicators = @()
                                        EventDetails = $Event
                                    }
                                    
                                    # Perform risk analysis
                                    $RiskScore = 0
                                    
                                    # Check for multiple failed logons
                                    if ($Event.Id -in $RiskPatterns.MultipleFailedLogons.EventIDs) {
                                        $Activity.RiskIndicators += 'Failed Logon Attempt'
                                        $RiskScore += 2
                                    }
                                    
                                    # Check for off-hours activity
                                    $Hour = $Event.TimeCreated.Hour
                                    if ($Hour -lt $RiskPatterns.OffHoursActivity.BusinessHours.Start -or 
                                        $Hour -gt $RiskPatterns.OffHoursActivity.BusinessHours.End) {
                                        $Activity.RiskIndicators += 'Off-Hours Activity'
                                        $RiskScore += 1
                                    }
                                    
                                    # Check for privilege escalation indicators
                                    if ($Event.Id -in $RiskPatterns.PrivilegeEscalation.EventIDs) {
                                        $Activity.RiskIndicators += 'Privilege Use'
                                        $RiskScore += 3
                                    }
                                    
                                    # Check for account manipulation
                                    if ($Event.Id -in $RiskPatterns.AccountManipulation.EventIDs) {
                                        $Activity.RiskIndicators += 'Account Management'
                                        $RiskScore += 3
                                    }
                                    
                                    # Determine final risk level
                                    $Activity.RiskLevel = if ($RiskScore -ge 5) { 'High' } elseif ($RiskScore -ge 3) { 'Medium' } else { 'Low' }
                                    
                                    # Apply risk threshold filter
                                    $RiskValue = switch ($Activity.RiskLevel) {
                                        'Low' { 1 }
                                        'Medium' { 2 }
                                        'High' { 3 }
                                    }
                                    
                                    $ThresholdValue = switch ($RiskThreshold) {
                                        'Low' { 1 }
                                        'Medium' { 2 }
                                        'High' { 3 }
                                    }
                                    
                                    if ($RiskValue -ge $ThresholdValue -or -not $SuspiciousActivityOnly) {
                                        $ComputerResult.Activities += $Activity
                                        $ActivityResults.TotalActivities++
                                        
                                        if ($Activity.RiskLevel -in @('Medium', 'High')) {
                                            $ComputerResult.SuspiciousCount++
                                            $ActivityResults.SuspiciousActivities++
                                        }
                                    }
                                }
                                
                            } catch {
                                Write-CustomLog -Level 'WARNING' -Message "Failed to process event: $($_.Exception.Message)"
                            }
                        }
                        
                        # Update activity counts
                        $ComputerResult.ActivityCounts[$ActivityType] = $Events.Count
                    }
                    
                    Write-CustomLog -Level 'SUCCESS' -Message "Activity analysis completed for $Computer`: $($ComputerResult.Activities.Count) activities found"
                    
                } catch {
                    $Error = "Failed to analyze activities on $Computer`: $($_.Exception.Message)"
                    $ComputerResult.Errors += $Error
                    Write-CustomLog -Level 'ERROR' -Message $Error
                }
                
                $ActivityResults.ComputersAnalyzed += $ComputerResult
            }
            
            # Perform correlation analysis if requested
            if ($CorrelateActivities -and $ActivityResults.TotalActivities -gt 0) {
                Write-CustomLog -Level 'INFO' -Message "Performing activity correlation analysis"
                
                try {
                    $AllActivities = $ActivityResults.ComputersAnalyzed | ForEach-Object {$_.Activities}
                    
                    # Time-based correlation (activities within 10 minutes)
                    $CorrelationWindow = New-TimeSpan -Minutes 10
                    
                    # Group activities by user account
                    $UserGroups = $AllActivities | Where-Object {$_.UserAccount} | Group-Object UserAccount
                    
                    foreach ($UserGroup in $UserGroups) {
                        if ($UserGroup.Count -gt 1) {
                            $UserActivities = $UserGroup.Group | Sort-Object Timestamp
                            
                            for ($i = 0; $i -lt $UserActivities.Count - 1; $i++) {
                                $Activity1 = $UserActivities[$i]
                                $Activity2 = $UserActivities[$i + 1]
                                
                                $TimeDiff = $Activity2.Timestamp - $Activity1.Timestamp
                                
                                if ($TimeDiff -le $CorrelationWindow) {
                                    $CorrelatedEvent = @{
                                        User = $UserGroup.Name
                                        Activity1 = $Activity1
                                        Activity2 = $Activity2
                                        TimeSpan = $TimeDiff
                                        Pattern = "Sequential activities within correlation window"
                                        RiskLevel = if ($Activity1.RiskLevel -eq 'High' -or $Activity2.RiskLevel -eq 'High') { 'High' } else { 'Medium' }
                                    }
                                    
                                    $ActivityResults.CorrelatedEvents += $CorrelatedEvent
                                    
                                    # Mark original activities as correlated
                                    $Activity1.IsCorrelated = $true
                                    $Activity2.IsCorrelated = $true
                                }
                            }
                        }
                    }
                    
                    Write-CustomLog -Level 'INFO' -Message "Found $($ActivityResults.CorrelatedEvents.Count) correlated activity patterns"
                    
                } catch {
                    Write-CustomLog -Level 'ERROR' -Message "Failed to perform correlation analysis: $($_.Exception.Message)"
                }
            }
            
            # Generate activity summary
            $ActivityResults.ActivitySummary = @{
                TotalActivities = $ActivityResults.TotalActivities
                SuspiciousActivities = $ActivityResults.SuspiciousActivities
                CorrelatedEvents = $ActivityResults.CorrelatedEvents.Count
                UniqueUsers = ($ActivityResults.ComputersAnalyzed | ForEach-Object {$_.Activities} | Where-Object {$_.UserAccount} | Select-Object -ExpandProperty UserAccount -Unique).Count
                ActivityTypeBreakdown = @{}
                RiskLevelBreakdown = @{
                    Low = 0
                    Medium = 0
                    High = 0
                }
            }
            
            # Calculate breakdowns
            $AllActivities = $ActivityResults.ComputersAnalyzed | ForEach-Object {$_.Activities}
            
            foreach ($ActivityType in $ActivityTypes) {
                $TypeCount = ($AllActivities | Where-Object {$_.ActivityType -eq $ActivityType}).Count
                $ActivityResults.ActivitySummary.ActivityTypeBreakdown[$ActivityType] = $TypeCount
            }
            
            foreach ($Activity in $AllActivities) {
                $ActivityResults.ActivitySummary.RiskLevelBreakdown[$Activity.RiskLevel]++
            }
            
        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Error during privileged account activity analysis: $($_.Exception.Message)"
            throw
        }
    }
    
    end {
        Write-CustomLog -Level 'SUCCESS' -Message "Privileged account activity monitoring completed"
        
        # Format output based on requested format
        $FormattedResults = switch ($OutputFormat) {
            'JSON' {
                $ActivityResults | ConvertTo-Json -Depth 10
            }
            'CSV' {
                $AllActivities = $ActivityResults.ComputersAnalyzed | ForEach-Object {$_.Activities}
                $AllActivities | Select-Object Timestamp, Computer, UserAccount, ActivityType, EventID, RiskLevel, @{N='RiskIndicators';E={$_.RiskIndicators -join '; '}} |
                ConvertTo-Csv -NoTypeInformation
            }
            'SIEM' {
                $AllActivities = $ActivityResults.ComputersAnalyzed | ForEach-Object {$_.Activities}
                $AllActivities | ForEach-Object {
                    $Activity = $_
                    "CEF:0|AitherZero|SecurityAutomation|1.0|PrivilegedActivity|$($Activity.ActivityType)|$($Activity.RiskLevel)|src=$($Activity.Computer) suser=$($Activity.UserAccount) rt=$($Activity.Timestamp.ToString('MMM dd yyyy HH:mm:ss')) msg=$($Activity.RiskIndicators -join ', ')"
                }
            }
            'Timeline' {
                # Generate HTML timeline
                $TimelineHtml = @"
<!DOCTYPE html>
<html>
<head>
    <title>Privileged Account Activity Timeline</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .timeline { margin: 20px 0; }
        .activity { margin: 10px 0; padding: 10px; border-left: 4px solid #ccc; background-color: #f9f9f9; }
        .high-risk { border-left-color: red; background-color: #fff0f0; }
        .medium-risk { border-left-color: orange; background-color: #fff8f0; }
        .low-risk { border-left-color: green; background-color: #f0fff0; }
        .timestamp { font-weight: bold; color: #666; }
        .user { color: #0066cc; font-weight: bold; }
        .computer { color: #666; }
        .indicators { color: #cc0000; font-style: italic; }
    </style>
</head>
<body>
    <h1>Privileged Account Activity Timeline</h1>
    <p><strong>Time Range:</strong> $($ActivityResults.TimeRange.StartTime) to $($ActivityResults.TimeRange.EndTime)</p>
    <p><strong>Total Activities:</strong> $($ActivityResults.ActivitySummary.TotalActivities)</p>
    <p><strong>Suspicious Activities:</strong> $($ActivityResults.ActivitySummary.SuspiciousActivities)</p>
    
    <div class="timeline">
"@
                
                $AllActivities = $ActivityResults.ComputersAnalyzed | ForEach-Object {$_.Activities} | Sort-Object Timestamp
                
                foreach ($Activity in $AllActivities) {
                    $RiskClass = "$($Activity.RiskLevel.ToLower())-risk"
                    $TimelineHtml += @"
        <div class="activity $RiskClass">
            <div class="timestamp">$($Activity.Timestamp.ToString('yyyy-MM-dd HH:mm:ss'))</div>
            <div class="user">User: $($Activity.UserAccount)</div>
            <div class="computer">Computer: $($Activity.Computer)</div>
            <div>Activity: $($Activity.ActivityType) (Event ID: $($Activity.EventID))</div>
            <div>Risk Level: $($Activity.RiskLevel)</div>
            $(if ($Activity.RiskIndicators.Count -gt 0) { "<div class='indicators'>Risk Indicators: $($Activity.RiskIndicators -join ', ')</div>" })
        </div>
"@
                }
                
                $TimelineHtml += @"
    </div>
</body>
</html>
"@
                $TimelineHtml
            }
            default {
                $ActivityResults
            }
        }
        
        # Export results if requested
        if ($ExportPath) {
            try {
                $FormattedResults | Out-File -FilePath $ExportPath -Encoding UTF8
                Write-CustomLog -Level 'SUCCESS' -Message "Activity results exported to: $ExportPath"
            } catch {
                Write-CustomLog -Level 'ERROR' -Message "Failed to export results: $($_.Exception.Message)"
            }
        }
        
        # Display summary
        Write-CustomLog -Level 'INFO' -Message "Activity Monitoring Summary:"
        Write-CustomLog -Level 'INFO' -Message "  Time Range: $($ActivityResults.TimeRange.StartTime) to $($ActivityResults.TimeRange.EndTime)"
        Write-CustomLog -Level 'INFO' -Message "  Computers Analyzed: $($ActivityResults.ComputersAnalyzed.Count)"
        Write-CustomLog -Level 'INFO' -Message "  Total Activities: $($ActivityResults.ActivitySummary.TotalActivities)"
        Write-CustomLog -Level 'INFO' -Message "  Suspicious Activities: $($ActivityResults.ActivitySummary.SuspiciousActivities)"
        Write-CustomLog -Level 'INFO' -Message "  High Risk: $($ActivityResults.ActivitySummary.RiskLevelBreakdown.High)"
        Write-CustomLog -Level 'INFO' -Message "  Medium Risk: $($ActivityResults.ActivitySummary.RiskLevelBreakdown.Medium)"
        Write-CustomLog -Level 'INFO' -Message "  Correlated Events: $($ActivityResults.CorrelatedEvents.Count)"
        
        if ($ActivityResults.ActivitySummary.SuspiciousActivities -gt 0) {
            Write-CustomLog -Level 'WARNING' -Message "Suspicious privileged account activities detected - investigate immediately"
        }
        
        return $FormattedResults
    }
}
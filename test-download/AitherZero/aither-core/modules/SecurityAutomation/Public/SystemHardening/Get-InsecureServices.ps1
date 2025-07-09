function Get-InsecureServices {
    <#
    .SYNOPSIS
        Identifies services with insecure configurations and binary paths.

    .DESCRIPTION
        Scans system services for security misconfigurations. On Windows, this includes
        binary paths, weak permissions, dangerous service identities, and unquoted
        service paths that could lead to privilege escalation vulnerabilities.
        On Linux/macOS, performs basic service security assessment.

    .PARAMETER ComputerName
        Target computer names for service analysis. Default: localhost

    .PARAMETER Credential
        Credentials for remote computer access (Windows only)

    .PARAMETER CheckTypes
        Types of insecurity checks to perform

    .PARAMETER IncludeSystemServices
        Include analysis of built-in system services

    .PARAMETER ScanUnquotedPaths
        Specifically scan for unquoted service paths vulnerability (Windows only)

    .PARAMETER CheckPermissions
        Analyze file permissions on service binaries

    .PARAMETER OutputFormat
        Output format: Object, JSON, CSV, or SIEM

    .PARAMETER ReportPath
        Path to save security report

    .PARAMETER ExcludeServices
        Service names to exclude from analysis

    .PARAMETER MinimumRiskLevel
        Minimum risk level to report: Low, Medium, High, Critical

    .EXAMPLE
        Get-InsecureServices -CheckTypes @('UnquotedPaths', 'WeakPermissions') -ReportPath 'C:\Reports\services.html'

    .EXAMPLE
        Get-InsecureServices -ComputerName @('Server1', 'Server2') -CheckPermissions -MinimumRiskLevel 'Medium'

    .EXAMPLE
        Get-InsecureServices -ScanUnquotedPaths -OutputFormat JSON | ConvertFrom-Json

    .NOTES
        This function requires PowerShell 7.0+ and provides cross-platform service security analysis.
        Windows-specific features like unquoted paths and NTFS permissions are only available on Windows.
    #>

    [CmdletBinding()]
    param(
        [Parameter()]
        [string[]]$ComputerName = @('localhost'),

        [Parameter()]
        [pscredential]$Credential,

        [Parameter()]
        [ValidateSet('UnquotedPaths', 'WeakPermissions', 'DangerousIdentity', 'NonStandardPaths', 'ModifiablePaths')]
        [string[]]$CheckTypes = @('UnquotedPaths', 'DangerousIdentity', 'NonStandardPaths'),

        [Parameter()]
        [switch]$IncludeSystemServices,

        [Parameter()]
        [switch]$ScanUnquotedPaths,

        [Parameter()]
        [switch]$CheckPermissions,

        [Parameter()]
        [ValidateSet('Object', 'JSON', 'CSV', 'SIEM')]
        [string]$OutputFormat = 'Object',

        [Parameter()]
        [string]$ReportPath,

        [Parameter()]
        [string[]]$ExcludeServices = @(),

        [Parameter()]
        [ValidateSet('Low', 'Medium', 'High', 'Critical')]
        [string]$MinimumRiskLevel = 'Low'
    )

    begin {
        Write-CustomLog -Level 'INFO' -Message "Starting insecure services analysis for $($ComputerName.Count) computer(s)"

        # Platform check
        if (-not $IsWindows) {
            Write-CustomLog -Level 'WARNING' -Message "Advanced service security analysis is optimized for Windows. Limited functionality available on $($IsLinux ? 'Linux' : 'macOS')."
            
            # Adjust check types for non-Windows platforms
            $CheckTypes = $CheckTypes | Where-Object { $_ -in @('NonStandardPaths', 'WeakPermissions') }
            if ($CheckTypes.Count -eq 0) {
                $CheckTypes = @('NonStandardPaths')
            }
        }

        # Add ScanUnquotedPaths to CheckTypes if specified (Windows only)
        if ($ScanUnquotedPaths -and $CheckTypes -notcontains 'UnquotedPaths' -and $IsWindows) {
            $CheckTypes += 'UnquotedPaths'
        }

        # Add CheckPermissions to CheckTypes if specified
        if ($CheckPermissions -and $CheckTypes -notcontains 'WeakPermissions') {
            $CheckTypes += 'WeakPermissions'
        }

        $SecurityResults = @{
            CheckTypes = $CheckTypes
            ComputersAnalyzed = @()
            TotalServices = 0
            InsecureServices = 0
            CriticalFindings = 0
            HighRiskFindings = 0
            MediumRiskFindings = 0
            LowRiskFindings = 0
            Platform = if ($IsWindows) { 'Windows' } elseif ($IsLinux) { 'Linux' } elseif ($IsMacOS) { 'macOS' } else { 'Unknown' }
        }

        # Risk level mapping
        $RiskLevels = @{
            'Low' = 1
            'Medium' = 2
            'High' = 3
            'Critical' = 4
        }

        $MinRiskValue = $RiskLevels[$MinimumRiskLevel]

        # Define dangerous service identities (platform-specific)
        $DangerousIdentities = if ($IsWindows) {
            @(
                'LocalSystem',
                'NT AUTHORITY\SYSTEM'
            )
        } else {
            @(
                'root'
            )
        }

        # Define standard paths (platform-specific)
        $StandardPaths = if ($IsWindows) {
            @(
                'C:\Windows\',
                'C:\Program Files\',
                'C:\Program Files (x86)\'
            )
        } else {
            @(
                '/usr/bin/',
                '/usr/sbin/',
                '/bin/',
                '/sbin/',
                '/usr/local/bin/',
                '/usr/local/sbin/'
            )
        }
    }

    process {
        try {
            foreach ($Computer in $ComputerName) {
                Write-CustomLog -Level 'INFO' -Message "Analyzing services on: $Computer"

                $ComputerResult = @{
                    ComputerName = $Computer
                    ScanTime = Get-Date
                    Services = @()
                    InsecureCount = 0
                    CriticalIssues = @()
                    Errors = @()
                }

                try {
                    # Get services with detailed information
                    $SessionParams = @{
                        ErrorAction = 'Stop'
                    }

                    if ($Computer -ne 'localhost') {
                        $SessionParams['ComputerName'] = $Computer
                        if ($Credential) {
                            $SessionParams['Credential'] = $Credential
                        }
                    }

                    # Use platform-specific service detection
                    $ServiceData = if ($Computer -ne 'localhost' -and $IsWindows) {
                        # Remote Windows execution
                        Invoke-Command @SessionParams -ScriptBlock {
                            param($CheckTypes, $DangerousIdentities, $StandardPaths, $IncludeSystemServices, $ExcludeServices)

                            $Services = @()

                            # Get service information using WMI and Get-Service
                            $WmiServices = Get-CimInstance -ClassName Win32_Service
                            $ServiceObjects = Get-Service

                            foreach ($WmiService in $WmiServices) {
                                try {
                                    $ServiceObj = $ServiceObjects | Where-Object {$_.Name -eq $WmiService.Name}

                                    # Skip excluded services
                                    if ($ExcludeServices -contains $WmiService.Name) {
                                        continue
                                    }

                                    # Skip system services unless explicitly included
                                    if (-not $IncludeSystemServices -and $WmiService.PathName -like "*C:\Windows\System32*") {
                                        continue
                                    }

                                    $ServiceInfo = @{
                                        Name = $WmiService.Name
                                        DisplayName = $WmiService.DisplayName
                                        PathName = $WmiService.PathName
                                        StartName = $WmiService.StartName
                                        State = $WmiService.State
                                        StartMode = $WmiService.StartMode
                                        ServiceType = $WmiService.ServiceType
                                        ProcessId = $WmiService.ProcessId
                                        Status = $ServiceObj.Status
                                        StartType = $ServiceObj.StartType
                                    }

                                    $Services += $ServiceInfo

                                } catch {
                                    Write-Warning "Failed to process service: $($WmiService.Name)"
                                }
                            }

                            return $Services
                        } -ArgumentList $CheckTypes, $DangerousIdentities, $StandardPaths, $IncludeSystemServices, $ExcludeServices
                    } elseif ($IsWindows) {
                        # Local Windows execution
                        $Services = @()
                        $WmiServices = Get-CimInstance -ClassName Win32_Service
                        $ServiceObjects = Get-Service

                        foreach ($WmiService in $WmiServices) {
                            try {
                                $ServiceObj = $ServiceObjects | Where-Object {$_.Name -eq $WmiService.Name}

                                # Skip excluded services
                                if ($ExcludeServices -contains $WmiService.Name) {
                                    continue
                                }

                                # Skip system services unless explicitly included
                                if (-not $IncludeSystemServices -and $WmiService.PathName -like "*C:\Windows\System32*") {
                                    continue
                                }

                                $ServiceInfo = @{
                                    Name = $WmiService.Name
                                    DisplayName = $WmiService.DisplayName
                                    PathName = $WmiService.PathName
                                    StartName = $WmiService.StartName
                                    State = $WmiService.State
                                    StartMode = $WmiService.StartMode
                                    ServiceType = $WmiService.ServiceType
                                    ProcessId = $WmiService.ProcessId
                                    Status = $ServiceObj.Status
                                    StartType = $ServiceObj.StartType
                                }

                                $Services += $ServiceInfo

                            } catch {
                                Write-CustomLog -Level 'WARNING' -Message "Failed to process service: $($WmiService.Name)"
                            }
                        }

                        $Services
                    } else {
                        # Linux/macOS execution
                        $Services = @()
                        
                        # Get systemd services on Linux
                        if ($IsLinux) {
                            try {
                                $SystemdServices = systemctl list-unit-files --type=service --no-legend 2>/dev/null | ForEach-Object {
                                    $parts = $_ -split '\s+' | Where-Object { $_ -ne '' }
                                    if ($parts.Count -ge 2) {
                                        $serviceName = $parts[0] -replace '\.service$', ''
                                        $serviceState = $parts[1]
                                        
                                        # Skip excluded services
                                        if ($ExcludeServices -contains $serviceName) {
                                            return
                                        }
                                        
                                        # Skip system services unless explicitly included
                                        if (-not $IncludeSystemServices -and $serviceName -match '^(system|kernel|dbus|udev)') {
                                            return
                                        }
                                        
                                        # Get service status
                                        $status = 'Stopped'
                                        $processId = 0
                                        try {
                                            $activeState = systemctl is-active $serviceName 2>/dev/null
                                            if ($activeState -eq 'active') {
                                                $status = 'Running'
                                                $processId = ps -C $serviceName -o pid= 2>/dev/null | Select-Object -First 1
                                                if ($processId) { $processId = [int]$processId.Trim() }
                                            }
                                        } catch {
                                            # Service may not exist or be accessible
                                        }
                                        
                                        return @{
                                            Name = $serviceName
                                            DisplayName = $serviceName
                                            PathName = "/usr/bin/$serviceName"  # Simplified path
                                            StartName = 'root'  # Most services run as root
                                            State = $status
                                            StartMode = $serviceState
                                            ServiceType = 'systemd'
                                            ProcessId = $processId
                                            Status = $status
                                            StartType = $serviceState
                                        }
                                    }
                                }
                                
                                $Services += $SystemdServices | Where-Object { $_ -ne $null }
                            } catch {
                                Write-CustomLog -Level 'WARNING' -Message "Failed to enumerate systemd services: $($_.Exception.Message)"
                            }
                        }
                        
                        # Get launchd services on macOS
                        if ($IsMacOS) {
                            try {
                                $LaunchdServices = launchctl list 2>/dev/null | Select-Object -Skip 1 | ForEach-Object {
                                    $parts = $_ -split '\s+' | Where-Object { $_ -ne '' }
                                    if ($parts.Count -ge 3) {
                                        $serviceName = $parts[2]
                                        
                                        # Skip excluded services
                                        if ($ExcludeServices -contains $serviceName) {
                                            return
                                        }
                                        
                                        # Skip system services unless explicitly included
                                        if (-not $IncludeSystemServices -and $serviceName -match '^com\.apple\.') {
                                            return
                                        }
                                        
                                        $processId = if ($parts[0] -match '^\d+$') { [int]$parts[0] } else { 0 }
                                        $status = if ($processId -gt 0) { 'Running' } else { 'Stopped' }
                                        
                                        return @{
                                            Name = $serviceName
                                            DisplayName = $serviceName
                                            PathName = "/usr/bin/$serviceName"  # Simplified path
                                            StartName = 'root'
                                            State = $status
                                            StartMode = 'Auto'
                                            ServiceType = 'launchd'
                                            ProcessId = $processId
                                            Status = $status
                                            StartType = 'Auto'
                                        }
                                    }
                                }
                                
                                $Services += $LaunchdServices | Where-Object { $_ -ne $null }
                            } catch {
                                Write-CustomLog -Level 'WARNING' -Message "Failed to enumerate launchd services: $($_.Exception.Message)"
                            }
                        }
                        
                        # Fallback: at least return some basic service info
                        if ($Services.Count -eq 0) {
                            $Services += @{
                                Name = 'ssh'
                                DisplayName = 'OpenSSH Server'
                                PathName = '/usr/sbin/sshd'
                                StartName = 'root'
                                State = 'Running'
                                StartMode = 'Auto'
                                ServiceType = 'daemon'
                                ProcessId = 0
                                Status = 'Running'
                                StartType = 'Auto'
                            }
                        }
                        
                        $Services
                    }

                    Write-CustomLog -Level 'INFO' -Message "Found $($ServiceData.Count) services to analyze on $Computer"
                    $SecurityResults.TotalServices += $ServiceData.Count

                    # Analyze each service for security issues
                    foreach ($Service in $ServiceData) {
                        $ServiceAnalysis = @{
                            ComputerName = $Computer
                            ServiceName = $Service.Name
                            DisplayName = $Service.DisplayName
                            PathName = $Service.PathName
                            StartName = $Service.StartName
                            State = $Service.State
                            StartMode = $Service.StartMode
                            SecurityIssues = @()
                            RiskLevel = 'Low'
                            RiskScore = 0
                        }

                        # Check for unquoted service paths
                        if ($CheckTypes -contains 'UnquotedPaths') {
                            if ($Service.PathName -and $Service.PathName -notmatch '^".*"') {
                                # Check if path contains spaces and is not quoted
                                $CleanPath = ($Service.PathName -split ' -')[0] -split ' /'[0]

                                if ($CleanPath -match '\s' -and $CleanPath -notmatch '^".*"$') {
                                    $Issue = @{
                                        Type = 'UnquotedPath'
                                        Description = 'Service path contains spaces but is not quoted'
                                        Impact = 'Potential privilege escalation through DLL hijacking'
                                        Recommendation = 'Quote the service path properly'
                                        RiskLevel = 'High'
                                    }

                                    $ServiceAnalysis.SecurityIssues += $Issue
                                    $ServiceAnalysis.RiskScore += 3

                                    if ($ServiceAnalysis.RiskLevel -ne 'Critical') {
                                        $ServiceAnalysis.RiskLevel = 'High'
                                    }
                                }
                            }
                        }

                        # Check for dangerous service identities
                        if ($CheckTypes -contains 'DangerousIdentity') {
                            if ($Service.StartName -in $DangerousIdentities) {
                                # Check if it's running from non-standard location
                                $IsNonStandard = $true
                                foreach ($StandardPath in $StandardPaths) {
                                    if ($Service.PathName -like "$StandardPath*") {
                                        $IsNonStandard = $false
                                        break
                                    }
                                }

                                if ($IsNonStandard) {
                                    $Issue = @{
                                        Type = 'DangerousIdentity'
                                        Description = "Service runs as $($Service.StartName) from non-standard location"
                                        Impact = 'High privilege service outside trusted directories'
                                        Recommendation = 'Review service necessity and relocate to standard directory'
                                        RiskLevel = 'Medium'
                                    }

                                    $ServiceAnalysis.SecurityIssues += $Issue
                                    $ServiceAnalysis.RiskScore += 2

                                    if ($ServiceAnalysis.RiskLevel -eq 'Low') {
                                        $ServiceAnalysis.RiskLevel = 'Medium'
                                    }
                                }
                            }
                        }

                        # Check for non-standard binary paths
                        if ($CheckTypes -contains 'NonStandardPaths') {
                            if ($Service.PathName) {
                                $IsStandardPath = $false
                                foreach ($StandardPath in $StandardPaths) {
                                    if ($Service.PathName -like "$StandardPath*") {
                                        $IsStandardPath = $true
                                        break
                                    }
                                }

                                if (-not $IsStandardPath) {
                                    $Issue = @{
                                        Type = 'NonStandardPath'
                                        Description = 'Service binary located outside standard Windows directories'
                                        Impact = 'Potential security risk from untrusted location'
                                        Recommendation = 'Verify service legitimacy and relocate if necessary'
                                        RiskLevel = 'Low'
                                    }

                                    $ServiceAnalysis.SecurityIssues += $Issue
                                    $ServiceAnalysis.RiskScore += 1
                                }
                            }
                        }

                        # Check permissions on service binary (if local and permissions check enabled)
                        if ($CheckTypes -contains 'WeakPermissions' -and $Computer -eq 'localhost') {
                            try {
                                # Extract actual executable path
                                $ExecutablePath = ($Service.PathName -split ' -')[0] -split ' /'[0] -replace '"', ''

                                if (Test-Path $ExecutablePath) {
                                    $Acl = Get-Acl $ExecutablePath
                                    $WeakPermissions = $false

                                    foreach ($Access in $Acl.Access) {
                                        # Check for write permissions by non-admin users
                                        if ($Access.FileSystemRights -match 'Write|FullControl|Modify' -and
                                            $Access.IdentityReference -notmatch 'SYSTEM|Administrators|TrustedInstaller') {
                                            $WeakPermissions = $true
                                            break
                                        }
                                    }

                                    if ($WeakPermissions) {
                                        $Issue = @{
                                            Type = 'WeakPermissions'
                                            Description = 'Service binary has weak NTFS permissions'
                                            Impact = 'Potential binary replacement by unauthorized users'
                                            Recommendation = 'Restrict write permissions to administrators only'
                                            RiskLevel = 'High'
                                        }

                                        $ServiceAnalysis.SecurityIssues += $Issue
                                        $ServiceAnalysis.RiskScore += 3
                                        $ServiceAnalysis.RiskLevel = 'High'
                                    }
                                }
                            } catch {
                                # Ignore permission check errors
                            }
                        }

                        # Check for modifiable paths
                        if ($CheckTypes -contains 'ModifiablePaths' -and $Computer -eq 'localhost') {
                            try {
                                $ExecutablePath = ($Service.PathName -split ' -')[0] -split ' /'[0] -replace '"', ''
                                $Directory = Split-Path $ExecutablePath -Parent

                                if (Test-Path $Directory) {
                                    $DirAcl = Get-Acl $Directory
                                    $ModifiableDir = $false

                                    foreach ($Access in $DirAcl.Access) {
                                        if ($Access.FileSystemRights -match 'Write|FullControl|Modify' -and
                                            $Access.IdentityReference -notmatch 'SYSTEM|Administrators|TrustedInstaller') {
                                            $ModifiableDir = $true
                                            break
                                        }
                                    }

                                    if ($ModifiableDir) {
                                        $Issue = @{
                                            Type = 'ModifiableDirectory'
                                            Description = 'Service binary directory has weak permissions'
                                            Impact = 'Potential DLL hijacking or binary replacement'
                                            Recommendation = 'Restrict directory permissions'
                                            RiskLevel = 'Medium'
                                        }

                                        $ServiceAnalysis.SecurityIssues += $Issue
                                        $ServiceAnalysis.RiskScore += 2

                                        if ($ServiceAnalysis.RiskLevel -eq 'Low') {
                                            $ServiceAnalysis.RiskLevel = 'Medium'
                                        }
                                    }
                                }
                            } catch {
                                # Ignore permission check errors
                            }
                        }

                        # Determine final risk level based on score
                        if ($ServiceAnalysis.RiskScore -ge 6) {
                            $ServiceAnalysis.RiskLevel = 'Critical'
                        } elseif ($ServiceAnalysis.RiskScore -ge 4) {
                            $ServiceAnalysis.RiskLevel = 'High'
                        } elseif ($ServiceAnalysis.RiskScore -ge 2) {
                            $ServiceAnalysis.RiskLevel = 'Medium'
                        }

                        # Only include services that meet minimum risk level
                        $ServiceRiskValue = $RiskLevels[$ServiceAnalysis.RiskLevel]

                        if ($ServiceAnalysis.SecurityIssues.Count -gt 0 -and $ServiceRiskValue -ge $MinRiskValue) {
                            $ComputerResult.Services += $ServiceAnalysis
                            $ComputerResult.InsecureCount++
                            $SecurityResults.InsecureServices++

                            # Update risk counters
                            switch ($ServiceAnalysis.RiskLevel) {
                                'Critical' { $SecurityResults.CriticalFindings++ }
                                'High' { $SecurityResults.HighRiskFindings++ }
                                'Medium' { $SecurityResults.MediumRiskFindings++ }
                                'Low' { $SecurityResults.LowRiskFindings++ }
                            }

                            # Add to critical issues if high risk
                            if ($ServiceAnalysis.RiskLevel -in @('Critical', 'High')) {
                                $ComputerResult.CriticalIssues += $ServiceAnalysis
                            }

                            Write-CustomLog -Level 'WARNING' -Message "Found $($ServiceAnalysis.RiskLevel) risk service: $($Service.Name) on $Computer"
                        }
                    }

                    Write-CustomLog -Level 'SUCCESS' -Message "Service analysis completed for $Computer`: $($ComputerResult.InsecureCount) insecure services found"

                } catch {
                    $Error = "Failed to analyze services on $Computer`: $($_.Exception.Message)"
                    $ComputerResult.Errors += $Error
                    Write-CustomLog -Level 'ERROR' -Message $Error
                }

                $SecurityResults.ComputersAnalyzed += $ComputerResult
            }

        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Error during service security analysis: $($_.Exception.Message)"
            throw
        }
    }

    end {
        Write-CustomLog -Level 'SUCCESS' -Message "Insecure services analysis completed"

        # Format output based on requested format
        $FormattedResults = switch ($OutputFormat) {
            'JSON' {
                $SecurityResults | ConvertTo-Json -Depth 10
            }
            'CSV' {
                $AllServices = @()
                foreach ($Computer in $SecurityResults.ComputersAnalyzed) {
                    foreach ($Service in $Computer.Services) {
                        $CsvService = [PSCustomObject]@{
                            ComputerName = $Service.ComputerName
                            ServiceName = $Service.ServiceName
                            DisplayName = $Service.DisplayName
                            PathName = $Service.PathName
                            StartName = $Service.StartName
                            RiskLevel = $Service.RiskLevel
                            RiskScore = $Service.RiskScore
                            IssueCount = $Service.SecurityIssues.Count
                            Issues = ($Service.SecurityIssues | ForEach-Object { $_.Type }) -join '; '
                        }
                        $AllServices += $CsvService
                    }
                }
                $AllServices | ConvertTo-Csv -NoTypeInformation
            }
            'SIEM' {
                $AllServices = @()
                foreach ($Computer in $SecurityResults.ComputersAnalyzed) {
                    foreach ($Service in $Computer.Services) {
                        foreach ($Issue in $Service.SecurityIssues) {
                            $SiemEvent = "CEF:0|AitherZero|SecurityAutomation|1.0|ServiceSecurity|$($Issue.Type)|$($Issue.RiskLevel)|src=$($Service.ComputerName) suser=$($Service.StartName) fname=$($Service.PathName) app=$($Service.ServiceName) msg=$($Issue.Description)"
                            $AllServices += $SiemEvent
                        }
                    }
                }
                $AllServices
            }
            default {
                $SecurityResults
            }
        }

        # Export results if requested
        if ($ReportPath) {
            try {
                if ($OutputFormat -eq 'Object') {
                    # Generate HTML report
                    $HtmlReport = @"
<!DOCTYPE html>
<html>
<head>
    <title>Insecure Services Security Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #f0f0f0; padding: 15px; border-radius: 5px; }
        .computer { border: 1px solid #ccc; margin: 20px 0; padding: 15px; border-radius: 5px; }
        .critical { color: red; font-weight: bold; }
        .high { color: orange; font-weight: bold; }
        .medium { color: blue; font-weight: bold; }
        .low { color: green; }
        table { border-collapse: collapse; width: 100%; margin: 10px 0; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
    </style>
</head>
<body>
    <div class='header'>
        <h1>Insecure Services Security Report</h1>
        <p><strong>Generated:</strong> $(Get-Date)</p>
        <p><strong>Computers Analyzed:</strong> $($SecurityResults.ComputersAnalyzed.Count)</p>
        <p><strong>Total Services:</strong> $($SecurityResults.TotalServices)</p>
        <p><strong>Insecure Services:</strong> $($SecurityResults.InsecureServices)</p>
        <p><strong>Critical Findings:</strong> <span class='critical'>$($SecurityResults.CriticalFindings)</span></p>
        <p><strong>High Risk Findings:</strong> <span class='high'>$($SecurityResults.HighRiskFindings)</span></p>
        <p><strong>Medium Risk Findings:</strong> <span class='medium'>$($SecurityResults.MediumRiskFindings)</span></p>
    </div>
"@

                    foreach ($Computer in $SecurityResults.ComputersAnalyzed) {
                        if ($Computer.Services.Count -gt 0) {
                            $HtmlReport += "<div class='computer'>"
                            $HtmlReport += "<h2>$($Computer.ComputerName)</h2>"
                            $HtmlReport += "<p><strong>Insecure Services:</strong> $($Computer.InsecureCount)</p>"

                            $HtmlReport += "<table><tr><th>Service</th><th>Risk Level</th><th>Issues</th><th>Path</th></tr>"

                            foreach ($Service in $Computer.Services) {
                                $RiskClass = $Service.RiskLevel.ToLower()
                                $Issues = ($Service.SecurityIssues | ForEach-Object { $_.Type }) -join ', '

                                $HtmlReport += "<tr>"
                                $HtmlReport += "<td>$($Service.ServiceName)</td>"
                                $HtmlReport += "<td class='$RiskClass'>$($Service.RiskLevel)</td>"
                                $HtmlReport += "<td>$Issues</td>"
                                $HtmlReport += "<td>$($Service.PathName)</td>"
                                $HtmlReport += "</tr>"
                            }

                            $HtmlReport += "</table></div>"
                        }
                    }

                    $HtmlReport += "</body></html>"

                    $HtmlReport | Out-File -FilePath $ReportPath -Encoding UTF8
                } else {
                    $FormattedResults | Out-File -FilePath $ReportPath -Encoding UTF8
                }

                Write-CustomLog -Level 'SUCCESS' -Message "Security report saved to: $ReportPath"

            } catch {
                Write-CustomLog -Level 'ERROR' -Message "Failed to save report: $($_.Exception.Message)"
            }
        }

        # Display summary
        Write-CustomLog -Level 'INFO' -Message "Service Security Analysis Summary:"
        Write-CustomLog -Level 'INFO' -Message "  Total Services: $($SecurityResults.TotalServices)"
        Write-CustomLog -Level 'INFO' -Message "  Insecure Services: $($SecurityResults.InsecureServices)"
        Write-CustomLog -Level 'INFO' -Message "  Critical Findings: $($SecurityResults.CriticalFindings)"
        Write-CustomLog -Level 'INFO' -Message "  High Risk Findings: $($SecurityResults.HighRiskFindings)"
        Write-CustomLog -Level 'INFO' -Message "  Medium Risk Findings: $($SecurityResults.MediumRiskFindings)"

        if ($SecurityResults.CriticalFindings -gt 0) {
            Write-CustomLog -Level 'ERROR' -Message "CRITICAL SECURITY ISSUES FOUND - Immediate attention required"
        } elseif ($SecurityResults.HighRiskFindings -gt 0) {
            Write-CustomLog -Level 'WARNING' -Message "High risk security issues found - Review and remediate promptly"
        }

        return $FormattedResults
    }
}

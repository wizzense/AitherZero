function Get-SystemSecurityInventory {
    <#
    .SYNOPSIS
        Performs comprehensive security-focused system inventory using WMI and CIM.

    .DESCRIPTION
        Collects detailed system information for security analysis including:
        - Hardware and firmware details
        - Operating system configuration
        - Installed software and patches
        - Security features and services
        - User accounts and privileges
        - Network configuration

    .PARAMETER ComputerName
        Target computer names for inventory. Default: localhost

    .PARAMETER Credential
        Credentials for remote computer access

    .PARAMETER InventoryCategories
        Specific inventory categories to collect

    .PARAMETER IncludeProcesses
        Include running process inventory

    .PARAMETER IncludeServices
        Include Windows services inventory

    .PARAMETER IncludeNetworking
        Include network configuration details

    .PARAMETER IncludeSoftware
        Include installed software inventory (can be slow)

    .PARAMETER OutputFormat
        Output format: Object, JSON, HTML, or CSV

    .PARAMETER ReportPath
        Path to save inventory report

    .PARAMETER SecurityFocus
        Include additional security-specific information

    .PARAMETER Parallel
        Process multiple computers in parallel

    .EXAMPLE
        Get-SystemSecurityInventory -SecurityFocus -ReportPath "C:\Reports\system-inventory.html"

    .EXAMPLE
        Get-SystemSecurityInventory -ComputerName @("Server1", "Server2") -Credential $Creds -Parallel

    .EXAMPLE
        Get-SystemSecurityInventory -InventoryCategories @("Hardware", "Security", "Network") -OutputFormat JSON
    #>

    [CmdletBinding()]
    param(
        [Parameter()]
        [string[]]$ComputerName = @('localhost'),

        [Parameter()]
        [pscredential]$Credential,

        [Parameter()]
        [ValidateSet('Hardware', 'OperatingSystem', 'Security', 'Network', 'Software', 'Services', 'Processes', 'Users')]
        [string[]]$InventoryCategories = @('Hardware', 'OperatingSystem', 'Security'),

        [Parameter()]
        [switch]$IncludeProcesses,

        [Parameter()]
        [switch]$IncludeServices,

        [Parameter()]
        [switch]$IncludeNetworking,

        [Parameter()]
        [switch]$IncludeSoftware,

        [Parameter()]
        [ValidateSet('Object', 'JSON', 'HTML', 'CSV')]
        [string]$OutputFormat = 'Object',

        [Parameter()]
        [string]$ReportPath,

        [Parameter()]
        [switch]$SecurityFocus,

        [Parameter()]
        [switch]$Parallel
    )

    begin {
        Write-CustomLog -Level 'INFO' -Message "Starting system security inventory for $($ComputerName.Count) computer(s)"

        # Adjust categories based on switches
        if ($IncludeProcesses -and $InventoryCategories -notcontains 'Processes') {
            $InventoryCategories += 'Processes'
        }
        if ($IncludeServices -and $InventoryCategories -notcontains 'Services') {
            $InventoryCategories += 'Services'
        }
        if ($IncludeNetworking -and $InventoryCategories -notcontains 'Network') {
            $InventoryCategories += 'Network'
        }
        if ($IncludeSoftware -and $InventoryCategories -notcontains 'Software') {
            $InventoryCategories += 'Software'
        }

        # Security focus expands categories
        if ($SecurityFocus) {
            $SecurityCategories = @('Security', 'Users', 'Services', 'Network')
            foreach ($Category in $SecurityCategories) {
                if ($InventoryCategories -notcontains $Category) {
                    $InventoryCategories += $Category
                }
            }
        }

        $InventoryResults = @()

        # Define inventory collection scriptblock
        $InventoryScriptBlock = {
            param($Categories, $UseCredential)

            $Computer = $env:COMPUTERNAME
            $InventoryData = @{
                ComputerName = $Computer
                CollectionTime = Get-Date
                Categories = @{}
                SecurityFindings = @()
                Errors = @()
            }

            try {
                # Helper function for WMI queries
                function Get-WMIData {
                    param($ClassName, $Properties = '*', $Namespace = 'root/cimv2')

                    try {
                        return Get-CimInstance -ClassName $ClassName -Namespace $Namespace -ErrorAction Stop |
                               Select-Object $Properties
                    } catch {
                        return $null
                    }
                }

                # Hardware Information
                if ($Categories -contains 'Hardware') {
                    Write-Progress -Activity "Collecting Hardware Information" -PercentComplete 10

                    $InventoryData.Categories['Hardware'] = @{
                        ComputerSystem = Get-WMIData 'Win32_ComputerSystem' @(
                            'Name', 'Domain', 'Manufacturer', 'Model', 'NumberOfProcessors',
                            'TotalPhysicalMemory', 'SystemType', 'PrimaryOwnerName'
                        )
                        BIOS = Get-WMIData 'Win32_BIOS' @('Name', 'Version', 'SMBIOSBIOSVersion', 'SerialNumber')
                        Processor = Get-WMIData 'Win32_Processor' @('Manufacturer', 'Name', 'CurrentClockSpeed', 'NumberOfCores', 'NumberOfLogicalProcessors')
                        Memory = Get-WMIData 'Win32_PhysicalMemory' @('Capacity', 'Speed', 'Manufacturer', 'PartNumber')
                        Disk = Get-WMIData 'Win32_LogicalDisk' @('DeviceID', 'Size', 'FreeSpace', 'FileSystem', 'DriveType')
                    }
                }

                # Operating System Information
                if ($Categories -contains 'OperatingSystem') {
                    Write-Progress -Activity "Collecting OS Information" -PercentComplete 20

                    $InventoryData.Categories['OperatingSystem'] = @{
                        OS = Get-WMIData 'Win32_OperatingSystem' @(
                            'Caption', 'BuildNumber', 'Version', 'SerialNumber',
                            'ServicePackMajorVersion', 'InstallDate', 'LastBootUpTime'
                        )
                        Hotfixes = Get-WMIData 'Win32_QuickFixEngineering' @('HotFixID', 'Description', 'InstalledOn')
                        Features = try { Get-WindowsFeature -ErrorAction SilentlyContinue | Where-Object {$_.InstallState -eq 'Installed'} } catch { $null }
                        Environment = Get-ChildItem Env: | ForEach-Object { @{Name = $_.Name; Value = $_.Value} }
                    }
                }

                # Security Information
                if ($Categories -contains 'Security') {
                    Write-Progress -Activity "Collecting Security Information" -PercentComplete 30

                    $SecurityInfo = @{
                        LocalAdministrators = try {
                            Get-LocalGroupMember -Group 'Administrators' -ErrorAction SilentlyContinue |
                            Select-Object Name, ObjectClass, PrincipalSource
                        } catch { $null }

                        SecurityFeatures = @{
                            WindowsDefender = try { Get-MpComputerStatus -ErrorAction SilentlyContinue } catch { $null }
                            BitLocker = try { Get-BitLockerVolume -ErrorAction SilentlyContinue } catch { $null }
                            UAC = try {
                                Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -ErrorAction SilentlyContinue |
                                Select-Object EnableLUA, ConsentPromptBehaviorAdmin
                            } catch { $null }
                            Firewall = try { Get-NetFirewallProfile | Select-Object Name, Enabled, DefaultInboundAction, DefaultOutboundAction } catch { $null }
                        }

                        PasswordPolicy = try {
                            net accounts | ForEach-Object {
                                if ($_ -match "(\w+):\s+(.+)") {
                                    @{Setting = $matches[1]; Value = $matches[2]}
                                }
                            }
                        } catch { $null }

                        AuditPolicy = try {
                            auditpol /get /category:* | Where-Object {$_ -match "^\s*(.+?)\s+(Success|Failure|Success and Failure|No Auditing)\s*$"} |
                            ForEach-Object {
                                if ($_ -match "^\s*(.+?)\s+(Success|Failure|Success and Failure|No Auditing)\s*$") {
                                    @{Policy = $matches[1].Trim(); Setting = $matches[2].Trim()}
                                }
                            }
                        } catch { $null }
                    }

                    $InventoryData.Categories['Security'] = $SecurityInfo

                    # Security findings
                    if ($SecurityInfo.SecurityFeatures.UAC -and $SecurityInfo.SecurityFeatures.UAC.EnableLUA -eq 0) {
                        $InventoryData.SecurityFindings += "UAC is disabled - security risk"
                    }

                    if ($SecurityInfo.LocalAdministrators -and $SecurityInfo.LocalAdministrators.Count -gt 3) {
                        $InventoryData.SecurityFindings += "High number of local administrators: $($SecurityInfo.LocalAdministrators.Count)"
                    }
                }

                # Network Information
                if ($Categories -contains 'Network') {
                    Write-Progress -Activity "Collecting Network Information" -PercentComplete 40

                    $InventoryData.Categories['Network'] = @{
                        Adapters = Get-WMIData 'Win32_NetworkAdapterConfiguration' @(
                            'Description', 'IPAddress', 'SubnetMask', 'DefaultIPGateway',
                            'DNSServerSearchOrder', 'DHCPEnabled', 'MACAddress'
                        ) | Where-Object {$_.IPAddress}

                        Routes = try { Get-NetRoute | Select-Object DestinationPrefix, NextHop, InterfaceAlias, Metric } catch { $null }
                        OpenPorts = try {
                            Get-NetTCPConnection | Where-Object {$_.State -eq 'Listen'} |
                            Select-Object LocalAddress, LocalPort, OwningProcess | Sort-Object LocalPort
                        } catch { $null }

                        Shares = Get-WMIData 'Win32_Share' @('Name', 'Path', 'Type', 'Description')
                        DNS = try { Get-DnsClientCache | Select-Object Entry, Data, TTL } catch { $null }
                    }
                }

                # Software Information
                if ($Categories -contains 'Software') {
                    Write-Progress -Activity "Collecting Software Information" -PercentComplete 50

                    $InventoryData.Categories['Software'] = @{
                        Programs = try {
                            Get-WMIData 'Win32_Product' @('Vendor', 'Name', 'Version', 'InstallDate') |
                            Sort-Object Name
                        } catch { $null }

                        UninstallEntries = try {
                            $UninstallKeys = @(
                                "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
                                "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
                            )

                            Get-ItemProperty $UninstallKeys -ErrorAction SilentlyContinue |
                            Where-Object {$_.DisplayName} |
                            Select-Object DisplayName, DisplayVersion, Publisher, InstallDate |
                            Sort-Object DisplayName
                        } catch { $null }
                    }
                }

                # Services Information
                if ($Categories -contains 'Services') {
                    Write-Progress -Activity "Collecting Services Information" -PercentComplete 60

                    $Services = Get-Service | Select-Object Name, Status, StartType, ServiceType
                    $InventoryData.Categories['Services'] = @{
                        AllServices = $Services
                        RunningServices = $Services | Where-Object {$_.Status -eq 'Running'}
                        StoppedServices = $Services | Where-Object {$_.Status -eq 'Stopped'}
                        AutoStartServices = $Services | Where-Object {$_.StartType -eq 'Automatic'}
                        ServiceDetails = Get-WMIData 'Win32_Service' @('Name', 'StartName', 'PathName', 'ProcessId')
                    }

                    # Check for services running as SYSTEM with high privileges
                    $HighPrivServices = $InventoryData.Categories['Services'].ServiceDetails |
                                      Where-Object {$_.StartName -eq 'LocalSystem' -and $_.PathName -notmatch '^C:\\Windows\\'}

                    if ($HighPrivServices.Count -gt 0) {
                        $InventoryData.SecurityFindings += "Services running as SYSTEM from non-Windows directories: $($HighPrivServices.Count)"
                    }
                }

                # Process Information
                if ($Categories -contains 'Processes') {
                    Write-Progress -Activity "Collecting Process Information" -PercentComplete 70

                    $Processes = Get-Process | Select-Object Name, Id, CPU, WorkingSet, Path, Company
                    $InventoryData.Categories['Processes'] = @{
                        AllProcesses = $Processes
                        SystemProcesses = $Processes | Where-Object {$_.Company -like "*Microsoft*"}
                        ThirdPartyProcesses = $Processes | Where-Object {$_.Company -notlike "*Microsoft*" -and $_.Company}
                        HighMemoryProcesses = $Processes | Where-Object {$_.WorkingSet -gt 100MB} | Sort-Object WorkingSet -Descending
                    }
                }

                # User Information
                if ($Categories -contains 'Users') {
                    Write-Progress -Activity "Collecting User Information" -PercentComplete 80

                    $InventoryData.Categories['Users'] = @{
                        LocalUsers = Get-WMIData 'Win32_UserAccount' @('Name', 'SID', 'Disabled', 'LocalAccount', 'PasswordRequired', 'PasswordChangeable') |
                                   Where-Object {$_.LocalAccount -eq $true}

                        LoggedOnUsers = Get-WMIData 'Win32_LoggedOnUser' |
                                      ForEach-Object { Get-WMIData 'Win32_Account' | Where-Object {$_.SID -eq $_.Antecedent.SID} }

                        UserProfiles = Get-WMIData 'Win32_UserProfile' @('LocalPath', 'SID', 'Loaded', 'LastUseTime', 'Special')

                        AdminAccounts = Get-WMIData 'Win32_UserAccount' @('Name', 'SID') |
                                      Where-Object {$_.SID -match '-500$'}  # Built-in Administrator
                    }

                    # Check for blank passwords
                    $BlankPasswordUsers = $InventoryData.Categories['Users'].LocalUsers |
                                        Where-Object {$_.PasswordRequired -eq $false -and $_.Disabled -eq $false}

                    if ($BlankPasswordUsers.Count -gt 0) {
                        $InventoryData.SecurityFindings += "Users with blank passwords: $($BlankPasswordUsers.Count)"
                    }
                }

            } catch {
                $InventoryData.Errors += "General collection error: $($_.Exception.Message)"
            }

            Write-Progress -Activity "Inventory Complete" -PercentComplete 100 -Completed
            return $InventoryData
        }

        # Function to format results
        function Format-InventoryResults {
            param($Results, $Format)

            switch ($Format) {
                'JSON' {
                    return $Results | ConvertTo-Json -Depth 10
                }
                'HTML' {
                    $HtmlContent = @"
<!DOCTYPE html>
<html>
<head>
    <title>System Security Inventory Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .computer { border: 1px solid #ccc; margin: 20px 0; padding: 15px; }
        .category { margin: 10px 0; }
        .security-finding { color: red; font-weight: bold; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
    </style>
</head>
<body>
    <h1>System Security Inventory Report</h1>
    <p>Generated: $(Get-Date)</p>
"@

                    foreach ($Computer in $Results) {
                        $HtmlContent += "<div class='computer'><h2>$($Computer.ComputerName)</h2>"

                        if ($Computer.SecurityFindings.Count -gt 0) {
                            $HtmlContent += "<h3>Security Findings</h3><ul>"
                            foreach ($Finding in $Computer.SecurityFindings) {
                                $HtmlContent += "<li class='security-finding'>$Finding</li>"
                            }
                            $HtmlContent += "</ul>"
                        }

                        $HtmlContent += "</div>"
                    }

                    $HtmlContent += "</body></html>"
                    return $HtmlContent
                }
                'CSV' {
                    $CSVData = @()
                    foreach ($Computer in $Results) {
                        $CSVData += [PSCustomObject]@{
                            ComputerName = $Computer.ComputerName
                            CollectionTime = $Computer.CollectionTime
                            SecurityFindings = $Computer.SecurityFindings -join '; '
                            Categories = $Computer.Categories.Keys -join '; '
                        }
                    }
                    return $CSVData | ConvertTo-Csv -NoTypeInformation
                }
                default {
                    return $Results
                }
            }
        }
    }

    process {
        try {
            if ($Parallel -and $ComputerName.Count -gt 1) {
                Write-CustomLog -Level 'INFO' -Message "Running inventory in parallel for $($ComputerName.Count) computers"

                $Jobs = @()
                foreach ($Computer in $ComputerName) {
                    $Job = Start-Job -ScriptBlock {
                        param($Computer, $Categories, $Credential, $ScriptBlock)

                        if ($Computer -eq 'localhost') {
                            & $ScriptBlock $Categories $false
                        } else {
                            if ($Credential) {
                                Invoke-Command -ComputerName $Computer -Credential $Credential -ScriptBlock $ScriptBlock -ArgumentList $Categories, $true
                            } else {
                                Invoke-Command -ComputerName $Computer -ScriptBlock $ScriptBlock -ArgumentList $Categories, $false
                            }
                        }
                    } -ArgumentList $Computer, $InventoryCategories, $Credential, $InventoryScriptBlock

                    $Jobs += $Job
                }

                # Wait for all jobs to complete
                $InventoryResults = $Jobs | Wait-Job | Receive-Job
                $Jobs | Remove-Job

            } else {
                # Sequential processing
                foreach ($Computer in $ComputerName) {
                    Write-CustomLog -Level 'INFO' -Message "Collecting inventory from: $Computer"

                    try {
                        if ($Computer -eq 'localhost') {
                            $Result = & $InventoryScriptBlock $InventoryCategories $false
                        } else {
                            if ($Credential) {
                                $Result = Invoke-Command -ComputerName $Computer -Credential $Credential -ScriptBlock $InventoryScriptBlock -ArgumentList $InventoryCategories, $true
                            } else {
                                $Result = Invoke-Command -ComputerName $Computer -ScriptBlock $InventoryScriptBlock -ArgumentList $InventoryCategories, $false
                            }
                        }

                        $InventoryResults += $Result
                        Write-CustomLog -Level 'SUCCESS' -Message "Inventory completed for: $Computer"

                    } catch {
                        Write-CustomLog -Level 'ERROR' -Message "Failed to collect inventory from '$Computer': $($_.Exception.Message)"

                        $InventoryResults += @{
                            ComputerName = $Computer
                            CollectionTime = Get-Date
                            Categories = @{}
                            SecurityFindings = @()
                            Errors = @("Connection failed: $($_.Exception.Message)")
                        }
                    }
                }
            }

        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Error during inventory collection: $($_.Exception.Message)"
            throw
        }
    }

    end {
        Write-CustomLog -Level 'SUCCESS' -Message "System security inventory completed for $($InventoryResults.Count) computer(s)"

        # Format results
        $FormattedResults = Format-InventoryResults -Results $InventoryResults -Format $OutputFormat

        # Save report if specified
        if ($ReportPath) {
            try {
                if ($OutputFormat -eq 'Object') {
                    $FormattedResults | ConvertTo-Json -Depth 10 | Out-File -FilePath $ReportPath -Encoding UTF8
                } else {
                    $FormattedResults | Out-File -FilePath $ReportPath -Encoding UTF8
                }
                Write-CustomLog -Level 'SUCCESS' -Message "Inventory report saved to: $ReportPath"
            } catch {
                Write-CustomLog -Level 'ERROR' -Message "Failed to save report: $($_.Exception.Message)"
            }
        }

        # Display summary
        $TotalFindings = ($InventoryResults | ForEach-Object {$_.SecurityFindings.Count} | Measure-Object -Sum).Sum

        Write-CustomLog -Level 'INFO' -Message "Inventory Summary:"
        Write-CustomLog -Level 'INFO' -Message "  Computers: $($InventoryResults.Count)"
        Write-CustomLog -Level 'INFO' -Message "  Categories: $($InventoryCategories -join ', ')"
        Write-CustomLog -Level 'INFO' -Message "  Security Findings: $TotalFindings"

        if ($TotalFindings -gt 0) {
            Write-CustomLog -Level 'WARNING' -Message "Security findings detected - review results for details"
        }

        return $FormattedResults
    }
}

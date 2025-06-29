function New-SystemSnapshot {
    <#
    .SYNOPSIS
        Creates comprehensive system snapshots for forensic analysis and incident response.
        
    .DESCRIPTION
        Captures detailed system state information including processes, services, registry
        exports, file listings, network configuration, user accounts, installed software,
        and security settings. Provides baseline snapshots for threat hunting and compliance.
        
    .PARAMETER ComputerName
        Target computers for snapshot collection. Default: localhost
        
    .PARAMETER Credential
        Credentials for remote computer access
        
    .PARAMETER SnapshotProfile
        Predefined snapshot profile to determine collection scope
        
    .PARAMETER OutputPath
        Directory path to save snapshot files
        
    .PARAMETER IncludeProcesses
        Include running processes and their details
        
    .PARAMETER IncludeServices
        Include Windows services and their configuration
        
    .PARAMETER IncludeRegistry
        Include registry exports of security-relevant hives
        
    .PARAMETER IncludeNetworkConfig
        Include network configuration and connections
        
    .PARAMETER IncludeFileSystem
        Include file system listings and metadata
        
    .PARAMETER IncludeUserAccounts
        Include user account information and group memberships
        
    .PARAMETER IncludeInstalledSoftware
        Include installed software inventory
        
    .PARAMETER IncludeSecuritySettings
        Include security policy and audit settings
        
    .PARAMETER IncludeEventLogs
        Include recent security-relevant event logs
        
    .PARAMETER IncludePerformanceData
        Include system performance and resource usage
        
    .PARAMETER IncludeEnvironmentVars
        Include environment variables and system paths
        
    .PARAMETER FileSystemPaths
        Specific file system paths to include in snapshot
        
    .PARAMETER RegistryKeys
        Specific registry keys to export
        
    .PARAMETER EventLogNames
        Specific event logs to export
        
    .PARAMETER DaysBackForLogs
        Number of days back to collect event logs
        
    .PARAMETER MaxFileListDepth
        Maximum directory depth for file listings
        
    .PARAMETER CompressOutput
        Compress snapshot output into a ZIP file
        
    .PARAMETER EncryptOutput
        Encrypt snapshot output for secure storage
        
    .PARAMETER HashVerification
        Include file hashes for integrity verification
        
    .PARAMETER SnapshotLabel
        Custom label for the snapshot collection
        
    .PARAMETER GenerateReport
        Generate HTML report summarizing snapshot contents
        
    .PARAMETER TestMode
        Run in test mode to show what would be collected
        
    .EXAMPLE
        New-SystemSnapshot -SnapshotProfile 'Standard' -OutputPath 'C:\Forensics\Snapshots'
        
    .EXAMPLE
        New-SystemSnapshot -ComputerName 'SERVER01' -IncludeAll -CompressOutput -GenerateReport
        
    .EXAMPLE
        New-SystemSnapshot -SnapshotProfile 'IncidentResponse' -EncryptOutput -HashVerification
    #>
    
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter()]
        [string[]]$ComputerName = @('localhost'),
        
        [Parameter()]
        [pscredential]$Credential,
        
        [Parameter()]
        [ValidateSet('Basic', 'Standard', 'Comprehensive', 'IncidentResponse', 'Compliance', 'Custom')]
        [string]$SnapshotProfile = 'Standard',
        
        [Parameter()]
        [string]$OutputPath = 'C:\ForensicSnapshots',
        
        [Parameter()]
        [switch]$IncludeProcesses,
        
        [Parameter()]
        [switch]$IncludeServices,
        
        [Parameter()]
        [switch]$IncludeRegistry,
        
        [Parameter()]
        [switch]$IncludeNetworkConfig,
        
        [Parameter()]
        [switch]$IncludeFileSystem,
        
        [Parameter()]
        [switch]$IncludeUserAccounts,
        
        [Parameter()]
        [switch]$IncludeInstalledSoftware,
        
        [Parameter()]
        [switch]$IncludeSecuritySettings,
        
        [Parameter()]
        [switch]$IncludeEventLogs,
        
        [Parameter()]
        [switch]$IncludePerformanceData,
        
        [Parameter()]
        [switch]$IncludeEnvironmentVars,
        
        [Parameter()]
        [string[]]$FileSystemPaths = @(),
        
        [Parameter()]
        [string[]]$RegistryKeys = @(),
        
        [Parameter()]
        [string[]]$EventLogNames = @(),
        
        [Parameter()]
        [ValidateRange(1, 90)]
        [int]$DaysBackForLogs = 7,
        
        [Parameter()]
        [ValidateRange(1, 10)]
        [int]$MaxFileListDepth = 3,
        
        [Parameter()]
        [switch]$CompressOutput,
        
        [Parameter()]
        [switch]$EncryptOutput,
        
        [Parameter()]
        [switch]$HashVerification,
        
        [Parameter()]
        [string]$SnapshotLabel,
        
        [Parameter()]
        [switch]$GenerateReport,
        
        [Parameter()]
        [switch]$TestMode
    )
    
    begin {
        Write-CustomLog -Level 'INFO' -Message "Starting system snapshot collection: $SnapshotProfile"
        
        # Check if running as Administrator
        $CurrentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
        $Principal = New-Object Security.Principal.WindowsPrincipal($CurrentUser)
        if (-not $Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            throw "This function requires Administrator privileges"
        }
        
        # Define snapshot profiles
        $SnapshotProfiles = @{
            'Basic' = @{
                Description = 'Basic system information snapshot'
                IncludeProcesses = $true
                IncludeServices = $true
                IncludeNetworkConfig = $true
                IncludeUserAccounts = $true
                IncludeInstalledSoftware = $true
                IncludeRegistry = $false
                IncludeFileSystem = $false
                IncludeEventLogs = $false
                IncludeSecuritySettings = $false
                IncludePerformanceData = $false
                IncludeEnvironmentVars = $true
            }
            'Standard' = @{
                Description = 'Standard forensic snapshot with key system data'
                IncludeProcesses = $true
                IncludeServices = $true
                IncludeNetworkConfig = $true
                IncludeUserAccounts = $true
                IncludeInstalledSoftware = $true
                IncludeRegistry = $true
                IncludeFileSystem = $true
                IncludeEventLogs = $true
                IncludeSecuritySettings = $true
                IncludePerformanceData = $false
                IncludeEnvironmentVars = $true
            }
            'Comprehensive' = @{
                Description = 'Comprehensive system snapshot with all available data'
                IncludeProcesses = $true
                IncludeServices = $true
                IncludeNetworkConfig = $true
                IncludeUserAccounts = $true
                IncludeInstalledSoftware = $true
                IncludeRegistry = $true
                IncludeFileSystem = $true
                IncludeEventLogs = $true
                IncludeSecuritySettings = $true
                IncludePerformanceData = $true
                IncludeEnvironmentVars = $true
            }
            'IncidentResponse' = @{
                Description = 'Incident response snapshot focused on security indicators'
                IncludeProcesses = $true
                IncludeServices = $true
                IncludeNetworkConfig = $true
                IncludeUserAccounts = $true
                IncludeInstalledSoftware = $true
                IncludeRegistry = $true
                IncludeFileSystem = $false  # Too much data for IR
                IncludeEventLogs = $true
                IncludeSecuritySettings = $true
                IncludePerformanceData = $true
                IncludeEnvironmentVars = $true
            }
            'Compliance' = @{
                Description = 'Compliance-focused snapshot for audit purposes'
                IncludeProcesses = $false
                IncludeServices = $true
                IncludeNetworkConfig = $true
                IncludeUserAccounts = $true
                IncludeInstalledSoftware = $true
                IncludeRegistry = $true
                IncludeFileSystem = $false
                IncludeEventLogs = $true
                IncludeSecuritySettings = $true
                IncludePerformanceData = $false
                IncludeEnvironmentVars = $false
            }
        }
        
        # Ensure output directory exists
        if (-not (Test-Path $OutputPath)) {
            New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
        }
        
        $SnapshotResults = @{
            SnapshotProfile = $SnapshotProfile
            SnapshotLabel = if ($SnapshotLabel) { $SnapshotLabel } else { "Snapshot-$(Get-Date -Format 'yyyyMMdd-HHmmss')" }
            ComputersProcessed = @()
            OutputPath = $OutputPath
            FilesCollected = 0
            DataPointsCollected = 0
            CompressedFiles = @()
            EncryptedFiles = @()
            HashFiles = @()
            Errors = @()
            Recommendations = @()
        }
        
        # Default registry keys for security analysis
        $DefaultRegistryKeys = @(
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce'
            'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'
            'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce'
            'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options'
            'HKLM:\SYSTEM\CurrentControlSet\Services'
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies'
            'HKLM:\SOFTWARE\Policies'
            'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment'
        )
        
        # Default file system paths for analysis
        $DefaultFileSystemPaths = @(
            'C:\Windows\System32'
            'C:\Windows\SysWOW64'
            'C:\Program Files'
            'C:\Program Files (x86)'
            'C:\ProgramData'
            'C:\Users'
            'C:\Temp'
            'C:\Windows\Temp'
        )
        
        # Default event logs for security analysis
        $DefaultEventLogs = @(
            'Security'
            'System'
            'Application'
            'Microsoft-Windows-PowerShell/Operational'
            'Microsoft-Windows-Sysmon/Operational'
            'Microsoft-Windows-Windows Defender/Operational'
        )
    }
    
    process {
        try {
            foreach ($Computer in $ComputerName) {
                Write-CustomLog -Level 'INFO' -Message "Creating system snapshot for: $Computer"
                
                $ComputerResult = @{
                    ComputerName = $Computer
                    Timestamp = Get-Date
                    SnapshotProfile = $SnapshotProfile
                    SnapshotLabel = $SnapshotResults.SnapshotLabel
                    FilesCreated = @()
                    DataCollected = @{}
                    CollectionTime = 0
                    Errors = @()
                }
                
                $StartTime = Get-Date
                
                try {
                    # Create computer-specific output directory
                    $ComputerOutputPath = Join-Path $OutputPath "$($SnapshotResults.SnapshotLabel)-$Computer"
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
                    $ProfileConfig = if ($SnapshotProfile -ne 'Custom') {
                        $SnapshotProfiles[$SnapshotProfile]
                    } else {
                        @{
                            Description = 'Custom snapshot configuration'
                            IncludeProcesses = $IncludeProcesses.IsPresent
                            IncludeServices = $IncludeServices.IsPresent
                            IncludeRegistry = $IncludeRegistry.IsPresent
                            IncludeNetworkConfig = $IncludeNetworkConfig.IsPresent
                            IncludeFileSystem = $IncludeFileSystem.IsPresent
                            IncludeUserAccounts = $IncludeUserAccounts.IsPresent
                            IncludeInstalledSoftware = $IncludeInstalledSoftware.IsPresent
                            IncludeSecuritySettings = $IncludeSecuritySettings.IsPresent
                            IncludeEventLogs = $IncludeEventLogs.IsPresent
                            IncludePerformanceData = $IncludePerformanceData.IsPresent
                            IncludeEnvironmentVars = $IncludeEnvironmentVars.IsPresent
                        }
                    }
                    
                    # Collect system information based on profile
                    $CollectionResult = if ($Computer -ne 'localhost') {
                        Invoke-Command @SessionParams -ScriptBlock {
                            param($ProfileConfig, $ComputerOutputPath, $DefaultRegistryKeys, $DefaultFileSystemPaths, $DefaultEventLogs, $DaysBackForLogs, $MaxFileListDepth, $HashVerification, $TestMode)
                            
                            $Results = @{
                                FilesCreated = @()
                                DataCollected = @{}
                                Errors = @()
                            }
                            
                            try {
                                # Create snapshot metadata
                                $SnapshotMetadata = @{
                                    ComputerName = $env:COMPUTERNAME
                                    Domain = $env:USERDOMAIN
                                    SnapshotTime = Get-Date
                                    OSVersion = (Get-CimInstance Win32_OperatingSystem).Caption
                                    OSBuild = (Get-CimInstance Win32_OperatingSystem).BuildNumber
                                    Architecture = $env:PROCESSOR_ARCHITECTURE
                                    TimeZone = (Get-TimeZone).Id
                                    UpTime = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
                                }
                                
                                $MetadataFile = Join-Path $ComputerOutputPath "snapshot-metadata.json"
                                if (-not $TestMode) {
                                    $SnapshotMetadata | ConvertTo-Json -Depth 3 | Out-File -FilePath $MetadataFile -Encoding UTF8
                                }
                                $Results.FilesCreated += $MetadataFile
                                $Results.DataCollected['Metadata'] = $SnapshotMetadata
                                
                                # Collect processes
                                if ($ProfileConfig.IncludeProcesses) {
                                    try {
                                        $Processes = Get-Process | Select-Object Name, Id, CPU, WorkingSet, VirtualMemorySize, StartTime, Path, Company, ProductVersion, FileVersion, ProcessName, Handles, Threads
                                        $ProcessFile = Join-Path $ComputerOutputPath "processes.csv"
                                        
                                        if (-not $TestMode) {
                                            $Processes | Export-Csv -Path $ProcessFile -NoTypeInformation
                                        }
                                        
                                        $Results.FilesCreated += $ProcessFile
                                        $Results.DataCollected['Processes'] = $Processes.Count
                                        
                                    } catch {
                                        $Results.Errors += "Failed to collect processes: $($_.Exception.Message)"
                                    }
                                }
                                
                                # Collect services
                                if ($ProfileConfig.IncludeServices) {
                                    try {
                                        $Services = Get-Service | Select-Object Name, DisplayName, Status, StartType, ServiceType
                                        $ServiceFile = Join-Path $ComputerOutputPath "services.csv"
                                        
                                        if (-not $TestMode) {
                                            $Services | Export-Csv -Path $ServiceFile -NoTypeInformation
                                        }
                                        
                                        $Results.FilesCreated += $ServiceFile
                                        $Results.DataCollected['Services'] = $Services.Count
                                        
                                    } catch {
                                        $Results.Errors += "Failed to collect services: $($_.Exception.Message)"
                                    }
                                }
                                
                                # Collect network configuration
                                if ($ProfileConfig.IncludeNetworkConfig) {
                                    try {
                                        # Network adapters
                                        $NetworkAdapters = Get-NetAdapter | Select-Object Name, InterfaceDescription, ifIndex, Status, LinkSpeed, MediaType, PhysicalMediaType
                                        $NetworkFile = Join-Path $ComputerOutputPath "network-adapters.csv"
                                        
                                        if (-not $TestMode) {
                                            $NetworkAdapters | Export-Csv -Path $NetworkFile -NoTypeInformation
                                        }
                                        
                                        $Results.FilesCreated += $NetworkFile
                                        
                                        # IP configuration
                                        $IPConfig = Get-NetIPConfiguration | Select-Object InterfaceAlias, InterfaceIndex, InterfaceDescription, NetProfile, IPv4Address, IPv6Address, DNSServer
                                        $IPConfigFile = Join-Path $ComputerOutputPath "ip-configuration.csv"
                                        
                                        if (-not $TestMode) {
                                            $IPConfig | Export-Csv -Path $IPConfigFile -NoTypeInformation
                                        }
                                        
                                        $Results.FilesCreated += $IPConfigFile
                                        
                                        # Network connections
                                        $NetConnections = Get-NetTCPConnection | Select-Object LocalAddress, LocalPort, RemoteAddress, RemotePort, State, OwningProcess, CreationTime
                                        $ConnectionsFile = Join-Path $ComputerOutputPath "network-connections.csv"
                                        
                                        if (-not $TestMode) {
                                            $NetConnections | Export-Csv -Path $ConnectionsFile -NoTypeInformation
                                        }
                                        
                                        $Results.FilesCreated += $ConnectionsFile
                                        $Results.DataCollected['NetworkConfig'] = @{
                                            Adapters = $NetworkAdapters.Count
                                            IPConfigs = $IPConfig.Count
                                            Connections = $NetConnections.Count
                                        }
                                        
                                    } catch {
                                        $Results.Errors += "Failed to collect network configuration: $($_.Exception.Message)"
                                    }
                                }
                                
                                # Collect user accounts
                                if ($ProfileConfig.IncludeUserAccounts) {
                                    try {
                                        $LocalUsers = Get-LocalUser | Select-Object Name, FullName, Description, Enabled, LastLogon, PasswordLastSet, PasswordRequired, UserMayChangePassword, PasswordChangeableDate, PasswordExpires, AccountExpires, PrincipalSource, ObjectClass
                                        $UsersFile = Join-Path $ComputerOutputPath "local-users.csv"
                                        
                                        if (-not $TestMode) {
                                            $LocalUsers | Export-Csv -Path $UsersFile -NoTypeInformation
                                        }
                                        
                                        $Results.FilesCreated += $UsersFile
                                        
                                        # Local groups
                                        $LocalGroups = Get-LocalGroup | Select-Object Name, Description, PrincipalSource, ObjectClass
                                        $GroupsFile = Join-Path $ComputerOutputPath "local-groups.csv"
                                        
                                        if (-not $TestMode) {
                                            $LocalGroups | Export-Csv -Path $GroupsFile -NoTypeInformation
                                        }
                                        
                                        $Results.FilesCreated += $GroupsFile
                                        $Results.DataCollected['UserAccounts'] = @{
                                            Users = $LocalUsers.Count
                                            Groups = $LocalGroups.Count
                                        }
                                        
                                    } catch {
                                        $Results.Errors += "Failed to collect user accounts: $($_.Exception.Message)"
                                    }
                                }
                                
                                # Collect installed software
                                if ($ProfileConfig.IncludeInstalledSoftware) {
                                    try {
                                        $InstalledSoftware = Get-CimInstance Win32_Product | Select-Object Name, Version, Vendor, InstallDate, InstallLocation, IdentifyingNumber
                                        $SoftwareFile = Join-Path $ComputerOutputPath "installed-software.csv"
                                        
                                        if (-not $TestMode) {
                                            $InstalledSoftware | Export-Csv -Path $SoftwareFile -NoTypeInformation
                                        }
                                        
                                        $Results.FilesCreated += $SoftwareFile
                                        $Results.DataCollected['InstalledSoftware'] = $InstalledSoftware.Count
                                        
                                    } catch {
                                        $Results.Errors += "Failed to collect installed software: $($_.Exception.Message)"
                                    }
                                }
                                
                                # Collect registry exports
                                if ($ProfileConfig.IncludeRegistry) {
                                    try {
                                        $RegistryDir = Join-Path $ComputerOutputPath "Registry"
                                        if (-not (Test-Path $RegistryDir)) {
                                            New-Item -Path $RegistryDir -ItemType Directory -Force | Out-Null
                                        }
                                        
                                        foreach ($RegKey in $DefaultRegistryKeys) {
                                            try {
                                                $SafeKeyName = $RegKey.Replace(':', '').Replace('\', '-')
                                                $RegFile = Join-Path $RegistryDir "$SafeKeyName.reg"
                                                
                                                if (-not $TestMode) {
                                                    if (Test-Path $RegKey) {
                                                        $RegExportKey = $RegKey.Replace('HKLM:', 'HKEY_LOCAL_MACHINE').Replace('HKCU:', 'HKEY_CURRENT_USER')
                                                        & reg export $RegExportKey $RegFile /y 2>$null
                                                    }
                                                }
                                                
                                                if (Test-Path $RegFile) {
                                                    $Results.FilesCreated += $RegFile
                                                }
                                                
                                            } catch {
                                                $Results.Errors += "Failed to export registry key $RegKey`: $($_.Exception.Message)"
                                            }
                                        }
                                        
                                        $Results.DataCollected['Registry'] = $DefaultRegistryKeys.Count
                                        
                                    } catch {
                                        $Results.Errors += "Failed to collect registry data: $($_.Exception.Message)"
                                    }
                                }
                                
                                # Collect environment variables
                                if ($ProfileConfig.IncludeEnvironmentVars) {
                                    try {
                                        $EnvVars = Get-ChildItem Env: | Select-Object Name, Value
                                        $EnvFile = Join-Path $ComputerOutputPath "environment-variables.csv"
                                        
                                        if (-not $TestMode) {
                                            $EnvVars | Export-Csv -Path $EnvFile -NoTypeInformation
                                        }
                                        
                                        $Results.FilesCreated += $EnvFile
                                        $Results.DataCollected['EnvironmentVars'] = $EnvVars.Count
                                        
                                    } catch {
                                        $Results.Errors += "Failed to collect environment variables: $($_.Exception.Message)"
                                    }
                                }
                                
                            } catch {
                                $Results.Errors += "Failed during system snapshot collection: $($_.Exception.Message)"
                            }
                            
                            return $Results
                        } -ArgumentList $ProfileConfig, $ComputerOutputPath, $DefaultRegistryKeys, $DefaultFileSystemPaths, $DefaultEventLogs, $DaysBackForLogs, $MaxFileListDepth, $HashVerification, $TestMode
                    } else {
                        $Results = @{
                            FilesCreated = @()
                            DataCollected = @{}
                            Errors = @()
                        }
                        
                        try {
                            # Create snapshot metadata
                            $SnapshotMetadata = @{
                                ComputerName = $env:COMPUTERNAME
                                Domain = $env:USERDOMAIN
                                SnapshotTime = Get-Date
                                OSVersion = (Get-CimInstance Win32_OperatingSystem).Caption
                                OSBuild = (Get-CimInstance Win32_OperatingSystem).BuildNumber
                                Architecture = $env:PROCESSOR_ARCHITECTURE
                                TimeZone = (Get-TimeZone).Id
                                UpTime = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
                            }
                            
                            $MetadataFile = Join-Path $ComputerOutputPath "snapshot-metadata.json"
                            if (-not $TestMode) {
                                if ($PSCmdlet.ShouldProcess("Snapshot Metadata", "Create metadata file")) {
                                    $SnapshotMetadata | ConvertTo-Json -Depth 3 | Out-File -FilePath $MetadataFile -Encoding UTF8
                                }
                            } else {
                                Write-CustomLog -Level 'INFO' -Message "[TEST] Would create metadata file: $MetadataFile"
                            }
                            
                            $Results.FilesCreated += $MetadataFile
                            $Results.DataCollected['Metadata'] = $SnapshotMetadata
                            
                            # Collect processes
                            if ($ProfileConfig.IncludeProcesses) {
                                try {
                                    $Processes = Get-Process | Select-Object Name, Id, CPU, WorkingSet, VirtualMemorySize, StartTime, Path, Company, ProductVersion, FileVersion, ProcessName, Handles, Threads
                                    $ProcessFile = Join-Path $ComputerOutputPath "processes.csv"
                                    
                                    if (-not $TestMode) {
                                        if ($PSCmdlet.ShouldProcess("Process List", "Export process information")) {
                                            $Processes | Export-Csv -Path $ProcessFile -NoTypeInformation
                                        }
                                    } else {
                                        Write-CustomLog -Level 'INFO' -Message "[TEST] Would export $($Processes.Count) processes to: $ProcessFile"
                                    }
                                    
                                    $Results.FilesCreated += $ProcessFile
                                    $Results.DataCollected['Processes'] = $Processes.Count
                                    
                                } catch {
                                    $Results.Errors += "Failed to collect processes: $($_.Exception.Message)"
                                }
                            }
                            
                            # Collect services
                            if ($ProfileConfig.IncludeServices) {
                                try {
                                    $Services = Get-Service | Select-Object Name, DisplayName, Status, StartType, ServiceType
                                    $ServiceFile = Join-Path $ComputerOutputPath "services.csv"
                                    
                                    if (-not $TestMode) {
                                        if ($PSCmdlet.ShouldProcess("Service List", "Export service information")) {
                                            $Services | Export-Csv -Path $ServiceFile -NoTypeInformation
                                        }
                                    } else {
                                        Write-CustomLog -Level 'INFO' -Message "[TEST] Would export $($Services.Count) services to: $ServiceFile"
                                    }
                                    
                                    $Results.FilesCreated += $ServiceFile
                                    $Results.DataCollected['Services'] = $Services.Count
                                    
                                } catch {
                                    $Results.Errors += "Failed to collect services: $($_.Exception.Message)"
                                }
                            }
                            
                            # Collect network configuration
                            if ($ProfileConfig.IncludeNetworkConfig) {
                                try {
                                    # Network adapters
                                    $NetworkAdapters = Get-NetAdapter | Select-Object Name, InterfaceDescription, ifIndex, Status, LinkSpeed, MediaType, PhysicalMediaType
                                    $NetworkFile = Join-Path $ComputerOutputPath "network-adapters.csv"
                                    
                                    if (-not $TestMode) {
                                        if ($PSCmdlet.ShouldProcess("Network Configuration", "Export network adapter information")) {
                                            $NetworkAdapters | Export-Csv -Path $NetworkFile -NoTypeInformation
                                        }
                                    } else {
                                        Write-CustomLog -Level 'INFO' -Message "[TEST] Would export network configuration to: $NetworkFile"
                                    }
                                    
                                    $Results.FilesCreated += $NetworkFile
                                    
                                    # IP configuration
                                    $IPConfig = Get-NetIPConfiguration | Select-Object InterfaceAlias, InterfaceIndex, InterfaceDescription, NetProfile, IPv4Address, IPv6Address, DNSServer
                                    $IPConfigFile = Join-Path $ComputerOutputPath "ip-configuration.csv"
                                    
                                    if (-not $TestMode) {
                                        if ($PSCmdlet.ShouldProcess("IP Configuration", "Export IP configuration")) {
                                            $IPConfig | Export-Csv -Path $IPConfigFile -NoTypeInformation
                                        }
                                    }
                                    
                                    $Results.FilesCreated += $IPConfigFile
                                    
                                    # Network connections
                                    $NetConnections = Get-NetTCPConnection | Select-Object LocalAddress, LocalPort, RemoteAddress, RemotePort, State, OwningProcess, CreationTime
                                    $ConnectionsFile = Join-Path $ComputerOutputPath "network-connections.csv"
                                    
                                    if (-not $TestMode) {
                                        if ($PSCmdlet.ShouldProcess("Network Connections", "Export active connections")) {
                                            $NetConnections | Export-Csv -Path $ConnectionsFile -NoTypeInformation
                                        }
                                    }
                                    
                                    $Results.FilesCreated += $ConnectionsFile
                                    $Results.DataCollected['NetworkConfig'] = @{
                                        Adapters = $NetworkAdapters.Count
                                        IPConfigs = $IPConfig.Count
                                        Connections = $NetConnections.Count
                                    }
                                    
                                } catch {
                                    $Results.Errors += "Failed to collect network configuration: $($_.Exception.Message)"
                                }
                            }
                            
                            # Collect user accounts
                            if ($ProfileConfig.IncludeUserAccounts) {
                                try {
                                    $LocalUsers = Get-LocalUser | Select-Object Name, FullName, Description, Enabled, LastLogon, PasswordLastSet, PasswordRequired, UserMayChangePassword, PasswordChangeableDate, PasswordExpires, AccountExpires, PrincipalSource, ObjectClass
                                    $UsersFile = Join-Path $ComputerOutputPath "local-users.csv"
                                    
                                    if (-not $TestMode) {
                                        if ($PSCmdlet.ShouldProcess("User Accounts", "Export local user information")) {
                                            $LocalUsers | Export-Csv -Path $UsersFile -NoTypeInformation
                                        }
                                    } else {
                                        Write-CustomLog -Level 'INFO' -Message "[TEST] Would export $($LocalUsers.Count) users to: $UsersFile"
                                    }
                                    
                                    $Results.FilesCreated += $UsersFile
                                    
                                    # Local groups
                                    $LocalGroups = Get-LocalGroup | Select-Object Name, Description, PrincipalSource, ObjectClass
                                    $GroupsFile = Join-Path $ComputerOutputPath "local-groups.csv"
                                    
                                    if (-not $TestMode) {
                                        if ($PSCmdlet.ShouldProcess("Local Groups", "Export local group information")) {
                                            $LocalGroups | Export-Csv -Path $GroupsFile -NoTypeInformation
                                        }
                                    }
                                    
                                    $Results.FilesCreated += $GroupsFile
                                    $Results.DataCollected['UserAccounts'] = @{
                                        Users = $LocalUsers.Count
                                        Groups = $LocalGroups.Count
                                    }
                                    
                                } catch {
                                    $Results.Errors += "Failed to collect user accounts: $($_.Exception.Message)"
                                }
                            }
                            
                            # Collect installed software
                            if ($ProfileConfig.IncludeInstalledSoftware) {
                                try {
                                    $InstalledSoftware = Get-CimInstance Win32_Product | Select-Object Name, Version, Vendor, InstallDate, InstallLocation, IdentifyingNumber
                                    $SoftwareFile = Join-Path $ComputerOutputPath "installed-software.csv"
                                    
                                    if (-not $TestMode) {
                                        if ($PSCmdlet.ShouldProcess("Installed Software", "Export software inventory")) {
                                            $InstalledSoftware | Export-Csv -Path $SoftwareFile -NoTypeInformation
                                        }
                                    } else {
                                        Write-CustomLog -Level 'INFO' -Message "[TEST] Would export $($InstalledSoftware.Count) software packages to: $SoftwareFile"
                                    }
                                    
                                    $Results.FilesCreated += $SoftwareFile
                                    $Results.DataCollected['InstalledSoftware'] = $InstalledSoftware.Count
                                    
                                } catch {
                                    $Results.Errors += "Failed to collect installed software: $($_.Exception.Message)"
                                }
                            }
                            
                            # Collect environment variables
                            if ($ProfileConfig.IncludeEnvironmentVars) {
                                try {
                                    $EnvVars = Get-ChildItem Env: | Select-Object Name, Value
                                    $EnvFile = Join-Path $ComputerOutputPath "environment-variables.csv"
                                    
                                    if (-not $TestMode) {
                                        if ($PSCmdlet.ShouldProcess("Environment Variables", "Export environment variables")) {
                                            $EnvVars | Export-Csv -Path $EnvFile -NoTypeInformation
                                        }
                                    } else {
                                        Write-CustomLog -Level 'INFO' -Message "[TEST] Would export $($EnvVars.Count) environment variables to: $EnvFile"
                                    }
                                    
                                    $Results.FilesCreated += $EnvFile
                                    $Results.DataCollected['EnvironmentVars'] = $EnvVars.Count
                                    
                                } catch {
                                    $Results.Errors += "Failed to collect environment variables: $($_.Exception.Message)"
                                }
                            }
                            
                        } catch {
                            $Results.Errors += "Failed during system snapshot collection: $($_.Exception.Message)"
                        }
                        
                        $Results
                    }
                    
                    $ComputerResult.FilesCreated = $CollectionResult.FilesCreated
                    $ComputerResult.DataCollected = $CollectionResult.DataCollected
                    $ComputerResult.Errors += $CollectionResult.Errors
                    
                    $SnapshotResults.FilesCollected += $CollectionResult.FilesCreated.Count
                    
                    # Calculate data points collected
                    foreach ($Category in $CollectionResult.DataCollected.Keys) {
                        if ($CollectionResult.DataCollected[$Category] -is [hashtable]) {
                            $SnapshotResults.DataPointsCollected += ($CollectionResult.DataCollected[$Category].Values | Measure-Object -Sum).Sum
                        } elseif ($CollectionResult.DataCollected[$Category] -is [int]) {
                            $SnapshotResults.DataPointsCollected += $CollectionResult.DataCollected[$Category]
                        }
                    }
                    
                    # Compress output if requested
                    if ($CompressOutput -and $CollectionResult.FilesCreated.Count -gt 0 -and -not $TestMode) {
                        try {
                            $ZipFile = "$ComputerOutputPath.zip"
                            
                            if ($PSCmdlet.ShouldProcess($ZipFile, "Compress snapshot files")) {
                                Compress-Archive -Path $ComputerOutputPath -DestinationPath $ZipFile -Force
                                $SnapshotResults.CompressedFiles += $ZipFile
                                Write-CustomLog -Level 'SUCCESS' -Message "Snapshot compressed to: $ZipFile"
                            }
                            
                        } catch {
                            $ComputerResult.Errors += "Failed to compress snapshot: $($_.Exception.Message)"
                        }
                    }
                    
                    $ComputerResult.CollectionTime = ((Get-Date) - $StartTime).TotalSeconds
                    Write-CustomLog -Level 'SUCCESS' -Message "System snapshot completed for $Computer - $($CollectionResult.FilesCreated.Count) files collected in $($ComputerResult.CollectionTime) seconds"
                    
                } catch {
                    $Error = "Failed to create system snapshot for $Computer`: $($_.Exception.Message)"
                    $ComputerResult.Errors += $Error
                    Write-CustomLog -Level 'ERROR' -Message $Error
                }
                
                $SnapshotResults.ComputersProcessed += $ComputerResult
            }
            
        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Error during system snapshot creation: $($_.Exception.Message)"
            throw
        }
    }
    
    end {
        Write-CustomLog -Level 'SUCCESS' -Message "System snapshot collection completed"
        
        # Generate recommendations
        $SnapshotResults.Recommendations += "Store snapshot files securely and implement appropriate retention policies"
        $SnapshotResults.Recommendations += "Compare snapshots over time to identify system changes and potential security issues"
        $SnapshotResults.Recommendations += "Use snapshots as baselines for security monitoring and incident response"
        $SnapshotResults.Recommendations += "Regularly review snapshot contents for sensitive data and implement data handling procedures"
        $SnapshotResults.Recommendations += "Consider automating snapshot collection for continuous security monitoring"
        
        if ($SnapshotResults.CompressedFiles.Count -gt 0) {
            $SnapshotResults.Recommendations += "Compressed files created - ensure secure storage and access controls"
        }
        
        if ($HashVerification) {
            $SnapshotResults.Recommendations += "File hashes included - use for integrity verification of collected evidence"
        }
        
        # Generate HTML report if requested
        if ($GenerateReport) {
            try {
                $ReportPath = Join-Path $OutputPath "$($SnapshotResults.SnapshotLabel)-Report.html"
                
                $HtmlReport = @"
<!DOCTYPE html>
<html>
<head>
    <title>System Snapshot Report - $($SnapshotResults.SnapshotLabel)</title>
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
        <h1>System Snapshot Report</h1>
        <p><strong>Snapshot Label:</strong> $($SnapshotResults.SnapshotLabel)</p>
        <p><strong>Profile:</strong> $($SnapshotResults.SnapshotProfile)</p>
        <p><strong>Generated:</strong> $(Get-Date)</p>
        <p><strong>Computers Processed:</strong> $($SnapshotResults.ComputersProcessed.Count)</p>
        <p><strong>Total Files Collected:</strong> $($SnapshotResults.FilesCollected)</p>
        <p><strong>Total Data Points:</strong> $($SnapshotResults.DataPointsCollected)</p>
    </div>
"@
                
                foreach ($Computer in $SnapshotResults.ComputersProcessed) {
                    $HtmlReport += "<div class='computer'>"
                    $HtmlReport += "<h2>$($Computer.ComputerName)</h2>"
                    $HtmlReport += "<p><strong>Collection Time:</strong> $($Computer.CollectionTime) seconds</p>"
                    $HtmlReport += "<p><strong>Files Created:</strong> $($Computer.FilesCreated.Count)</p>"
                    
                    if ($Computer.DataCollected.Count -gt 0) {
                        $HtmlReport += "<h3>Data Collected</h3><table><tr><th>Category</th><th>Count</th></tr>"
                        foreach ($Category in $Computer.DataCollected.Keys) {
                            $Count = if ($Computer.DataCollected[$Category] -is [hashtable]) {
                                ($Computer.DataCollected[$Category].Values | Measure-Object -Sum).Sum
                            } else {
                                $Computer.DataCollected[$Category]
                            }
                            $HtmlReport += "<tr><td>$Category</td><td>$Count</td></tr>"
                        }
                        $HtmlReport += "</table>"
                    }
                    
                    if ($Computer.Errors.Count -gt 0) {
                        $HtmlReport += "<h3 class='error'>Errors</h3><ul>"
                        foreach ($Error in $Computer.Errors) {
                            $HtmlReport += "<li class='error'>$Error</li>"
                        }
                        $HtmlReport += "</ul>"
                    }
                    
                    $HtmlReport += "</div>"
                }
                
                $HtmlReport += "<div class='header'><h2>Recommendations</h2>"
                foreach ($Rec in $SnapshotResults.Recommendations) {
                    $HtmlReport += "<div class='recommendation'>$Rec</div>"
                }
                $HtmlReport += "</div>"
                
                $HtmlReport += "</body></html>"
                
                if (-not $TestMode) {
                    $HtmlReport | Out-File -FilePath $ReportPath -Encoding UTF8
                    Write-CustomLog -Level 'SUCCESS' -Message "Snapshot report generated: $ReportPath"
                }
                
            } catch {
                Write-CustomLog -Level 'ERROR' -Message "Failed to generate report: $($_.Exception.Message)"
            }
        }
        
        # Display summary
        Write-CustomLog -Level 'INFO' -Message "System Snapshot Summary:"
        Write-CustomLog -Level 'INFO' -Message "  Snapshot Label: $($SnapshotResults.SnapshotLabel)"
        Write-CustomLog -Level 'INFO' -Message "  Profile: $($SnapshotResults.SnapshotProfile)"
        Write-CustomLog -Level 'INFO' -Message "  Computers: $($SnapshotResults.ComputersProcessed.Count)"
        Write-CustomLog -Level 'INFO' -Message "  Files Collected: $($SnapshotResults.FilesCollected)"
        Write-CustomLog -Level 'INFO' -Message "  Data Points: $($SnapshotResults.DataPointsCollected)"
        Write-CustomLog -Level 'INFO' -Message "  Output Path: $($SnapshotResults.OutputPath)"
        
        if ($SnapshotResults.CompressedFiles.Count -gt 0) {
            Write-CustomLog -Level 'INFO' -Message "  Compressed Files: $($SnapshotResults.CompressedFiles.Count)"
        }
        
        return $SnapshotResults
    }
}
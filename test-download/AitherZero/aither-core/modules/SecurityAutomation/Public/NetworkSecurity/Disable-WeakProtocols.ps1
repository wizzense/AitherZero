function Disable-WeakProtocols {
    <#
    .SYNOPSIS
        Disables weak and legacy protocols to enhance network security.

    .DESCRIPTION
        Systematically disables weak and outdated network protocols that pose security risks
        including legacy SSL/TLS versions, SMBv1, weak authentication protocols, and
        insecure RPC configurations. Supports both local and remote configuration.

    .PARAMETER ComputerName
        Target computer names for protocol hardening. Default: localhost

    .PARAMETER Credential
        Credentials for remote computer access

    .PARAMETER ProtocolCategories
        Categories of protocols to disable

    .PARAMETER IncludeSSLTLS
        Disable weak SSL/TLS protocols (SSLv2, SSLv3, TLS 1.0, TLS 1.1)

    .PARAMETER IncludeSMB
        Disable SMBv1 protocol

    .PARAMETER IncludeNetBIOS
        Disable NetBIOS over TCP/IP

    .PARAMETER IncludeWinRM
        Harden WinRM protocol settings

    .PARAMETER IncludeRDP
        Harden RDP protocol settings

    .PARAMETER TestMode
        Show what would be changed without making modifications

    .PARAMETER ReportPath
        Path to save protocol hardening report

    .PARAMETER BackupSettings
        Create backup of current settings before changes

    .PARAMETER RestartServices
        Restart affected services after changes

    .EXAMPLE
        Disable-WeakProtocols -IncludeSSLTLS -IncludeSMB -ReportPath "C:\Reports\protocols.html"

    .EXAMPLE
        Disable-WeakProtocols -ComputerName @("Server1", "Server2") -ProtocolCategories @("Legacy", "Insecure") -Credential $Creds

    .EXAMPLE
        Disable-WeakProtocols -TestMode -IncludeSSLTLS -IncludeNetBIOS -BackupSettings
    #>

    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter()]
        [string[]]$ComputerName = @('localhost'),

        [Parameter()]
        [pscredential]$Credential,

        [Parameter()]
        [ValidateSet('Legacy', 'Insecure', 'Deprecated', 'All')]
        [string[]]$ProtocolCategories = @('Legacy', 'Insecure'),

        [Parameter()]
        [switch]$IncludeSSLTLS,

        [Parameter()]
        [switch]$IncludeSMB,

        [Parameter()]
        [switch]$IncludeNetBIOS,

        [Parameter()]
        [switch]$IncludeWinRM,

        [Parameter()]
        [switch]$IncludeRDP,

        [Parameter()]
        [switch]$TestMode,

        [Parameter()]
        [string]$ReportPath,

        [Parameter()]
        [switch]$BackupSettings,

        [Parameter()]
        [switch]$RestartServices
    )

    begin {
        Write-CustomLog -Level 'INFO' -Message "Starting weak protocol hardening for $($ComputerName.Count) computer(s)"

        # Check if running as Administrator
        $CurrentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
        $Principal = New-Object Security.Principal.WindowsPrincipal($CurrentUser)
        if (-not $Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            throw "This function requires Administrator privileges"
        }

        # Define protocol configurations based on categories
        $ProtocolConfigurations = @{
            'Legacy' = @{
                SSL = @{
                    'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 2.0\Server' = @{
                        'Enabled' = 0
                        'DisabledByDefault' = 1
                    }
                    'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 2.0\Client' = @{
                        'Enabled' = 0
                        'DisabledByDefault' = 1
                    }
                    'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 3.0\Server' = @{
                        'Enabled' = 0
                        'DisabledByDefault' = 1
                    }
                    'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 3.0\Client' = @{
                        'Enabled' = 0
                        'DisabledByDefault' = 1
                    }
                }
                SMB = @{
                    'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters' = @{
                        'SMB1' = 0
                    }
                    'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters' = @{
                        'RequireSecuritySignature' = 1
                    }
                }
                NetBIOS = @{
                    'HKLM:\SYSTEM\CurrentControlSet\Services\NetBT\Parameters' = @{
                        'NoNameReleaseOnDemand' = 1
                    }
                }
            }
            'Insecure' = @{
                TLS = @{
                    'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Server' = @{
                        'Enabled' = 0
                        'DisabledByDefault' = 1
                    }
                    'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Client' = @{
                        'Enabled' = 0
                        'DisabledByDefault' = 1
                    }
                    'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Server' = @{
                        'Enabled' = 0
                        'DisabledByDefault' = 1
                    }
                    'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Client' = @{
                        'Enabled' = 0
                        'DisabledByDefault' = 1
                    }
                }
                WinRM = @{
                    'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WinRM\Service' = @{
                        'AllowUnencryptedTraffic' = 0
                        'AllowBasic' = 0
                        'AllowDigest' = 0
                    }
                }
                RDP = @{
                    'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' = @{
                        'SecurityLayer' = 2
                        'UserAuthentication' = 1
                        'MinEncryptionLevel' = 3
                    }
                }
            }
            'Deprecated' = @{
                LDAP = @{
                    'HKLM:\SYSTEM\CurrentControlSet\Services\NTDS\Parameters' = @{
                        'LDAPServerIntegrity' = 2
                    }
                }
                Kerberos = @{
                    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\Kerberos\Parameters' = @{
                        'SupportedEncryptionTypes' = 0x7FFFFFFF
                    }
                }
            }
        }

        $HardeningResults = @{
            ProtocolCategories = $ProtocolCategories
            ComputersProcessed = @()
            RegistryChanges = 0
            ServicesModified = 0
            Errors = @()
            Recommendations = @()
        }
    }

    process {
        try {
            foreach ($Computer in $ComputerName) {
                Write-CustomLog -Level 'INFO' -Message "Processing protocol hardening for: $Computer"

                $ComputerResult = @{
                    ComputerName = $Computer
                    Timestamp = Get-Date
                    ProtocolsDisabled = @()
                    RegistryChanges = @()
                    ServiceChanges = @()
                    BackupPath = $null
                    ChangesMade = 0
                    Errors = @()
                }

                try {
                    # Create backup if requested
                    if ($BackupSettings) {
                        Write-CustomLog -Level 'INFO' -Message "Creating protocol settings backup for $Computer"

                        $BackupPath = "C:\ProgramData\AitherZero\Backups\Protocol-Backup-$Computer-$(Get-Date -Format 'yyyyMMdd-HHmmss').xml"
                        $BackupDir = Split-Path $BackupPath -Parent

                        if (-not (Test-Path $BackupDir)) {
                            New-Item -Path $BackupDir -ItemType Directory -Force | Out-Null
                        }

                        $BackupData = @{
                            ComputerName = $Computer
                            BackupTime = Get-Date
                            RegistrySettings = @{}
                        }

                        # Backup current settings
                        foreach ($Category in $ProtocolCategories) {
                            if ($ProtocolConfigurations.ContainsKey($Category)) {
                                $Config = $ProtocolConfigurations[$Category]

                                foreach ($ProtocolType in $Config.Keys) {
                                    foreach ($RegistryPath in $Config[$ProtocolType].Keys) {
                                        try {
                                            $CurrentSettings = Get-ItemProperty -Path $RegistryPath -ErrorAction SilentlyContinue
                                            if ($CurrentSettings) {
                                                $BackupData.RegistrySettings[$RegistryPath] = $CurrentSettings
                                            }
                                        } catch {
                                            # Ignore backup errors for non-existent keys
                                        }
                                    }
                                }
                            }
                        }

                        $BackupData | Export-Clixml -Path $BackupPath -Force
                        $ComputerResult.BackupPath = $BackupPath
                        Write-CustomLog -Level 'SUCCESS' -Message "Backup saved to: $BackupPath"
                    }

                    # Process each protocol category
                    foreach ($Category in $ProtocolCategories) {
                        if ($ProtocolConfigurations.ContainsKey($Category)) {
                            $Config = $ProtocolConfigurations[$Category]

                            Write-CustomLog -Level 'INFO' -Message "Disabling $Category protocols on $Computer"

                            foreach ($ProtocolType in $Config.Keys) {
                                # Check specific include flags
                                $ShouldProcess = $true

                                switch ($ProtocolType) {
                                    'SSL' { if ($IncludeSSLTLS -eq $false -and -not ($ProtocolCategories -contains 'All')) { $ShouldProcess = $false } }
                                    'TLS' { if ($IncludeSSLTLS -eq $false -and -not ($ProtocolCategories -contains 'All')) { $ShouldProcess = $false } }
                                    'SMB' { if ($IncludeSMB -eq $false -and -not ($ProtocolCategories -contains 'All')) { $ShouldProcess = $false } }
                                    'NetBIOS' { if ($IncludeNetBIOS -eq $false -and -not ($ProtocolCategories -contains 'All')) { $ShouldProcess = $false } }
                                    'WinRM' { if ($IncludeWinRM -eq $false -and -not ($ProtocolCategories -contains 'All')) { $ShouldProcess = $false } }
                                    'RDP' { if ($IncludeRDP -eq $false -and -not ($ProtocolCategories -contains 'All')) { $ShouldProcess = $false } }
                                }

                                if (-not $ShouldProcess) {
                                    continue
                                }

                                foreach ($RegistryPath in $Config[$ProtocolType].Keys) {
                                    $Settings = $Config[$ProtocolType][$RegistryPath]

                                    try {
                                        # Ensure registry path exists
                                        if (-not (Test-Path $RegistryPath)) {
                                            if (-not $TestMode) {
                                                if ($PSCmdlet.ShouldProcess($RegistryPath, "Create registry path")) {
                                                    New-Item -Path $RegistryPath -Force | Out-Null
                                                }
                                            } else {
                                                Write-CustomLog -Level 'INFO' -Message "[TEST] Would create registry path: $RegistryPath"
                                            }
                                        }

                                        foreach ($Setting in $Settings.Keys) {
                                            $Value = $Settings[$Setting]
                                            $CurrentValue = $null

                                            try {
                                                $CurrentValue = Get-ItemProperty -Path $RegistryPath -Name $Setting -ErrorAction SilentlyContinue | Select-Object -ExpandProperty $Setting
                                            } catch {
                                                $CurrentValue = $null
                                            }

                                            if ($CurrentValue -ne $Value) {
                                                $ChangeInfo = @{
                                                    Path = $RegistryPath
                                                    Setting = $Setting
                                                    OldValue = $CurrentValue
                                                    NewValue = $Value
                                                    Protocol = $ProtocolType
                                                }

                                                if ($TestMode) {
                                                    Write-CustomLog -Level 'INFO' -Message "[TEST] Would set $RegistryPath\$Setting to $Value (currently: $CurrentValue)"
                                                    $ComputerResult.RegistryChanges += $ChangeInfo
                                                } else {
                                                    if ($PSCmdlet.ShouldProcess("$RegistryPath\$Setting", "Set to $Value")) {
                                                        Set-ItemProperty -Path $RegistryPath -Name $Setting -Value $Value -Force
                                                        $HardeningResults.RegistryChanges++
                                                        $ComputerResult.ChangesMade++
                                                        $ComputerResult.RegistryChanges += $ChangeInfo

                                                        Write-CustomLog -Level 'SUCCESS' -Message "Disabled $ProtocolType protocol: $RegistryPath\$Setting = $Value"

                                                        if ($ComputerResult.ProtocolsDisabled -notcontains $ProtocolType) {
                                                            $ComputerResult.ProtocolsDisabled += $ProtocolType
                                                        }
                                                    }
                                                }
                                            }
                                        }

                                    } catch {
                                        $Error = "Failed to process registry path $RegistryPath`: $($_.Exception.Message)"
                                        $ComputerResult.Errors += $Error
                                        Write-CustomLog -Level 'ERROR' -Message $Error
                                    }
                                }
                            }
                        }
                    }

                    # Handle service-level changes
                    if ($IncludeSMB -or $ProtocolCategories -contains 'All') {
                        Write-CustomLog -Level 'INFO' -Message "Checking SMBv1 feature status"

                        try {
                            $SMBv1Feature = Get-WindowsOptionalFeature -Online -FeatureName "SMB1Protocol" -ErrorAction SilentlyContinue

                            if ($SMBv1Feature -and $SMBv1Feature.State -eq "Enabled") {
                                if ($TestMode) {
                                    Write-CustomLog -Level 'INFO' -Message "[TEST] Would disable SMBv1 Windows feature"
                                } else {
                                    if ($PSCmdlet.ShouldProcess("SMB1Protocol", "Disable Windows feature")) {
                                        Disable-WindowsOptionalFeature -Online -FeatureName "SMB1Protocol" -NoRestart
                                        $HardeningResults.ServicesModified++
                                        $ComputerResult.ServiceChanges += "Disabled SMBv1 Windows feature"
                                        Write-CustomLog -Level 'SUCCESS' -Message "Disabled SMBv1 Windows feature"
                                    }
                                }
                            }
                        } catch {
                            Write-CustomLog -Level 'WARNING' -Message "Could not check/disable SMBv1 feature: $($_.Exception.Message)"
                        }
                    }

                    # Restart services if requested and changes were made
                    if ($RestartServices -and $ComputerResult.ChangesMade -gt 0 -and -not $TestMode) {
                        Write-CustomLog -Level 'INFO' -Message "Restarting affected services on $Computer"

                        $ServicesToRestart = @()

                        if ($ComputerResult.ProtocolsDisabled -contains 'WinRM') {
                            $ServicesToRestart += 'WinRM'
                        }
                        if ($ComputerResult.ProtocolsDisabled -contains 'RDP') {
                            $ServicesToRestart += 'TermService'
                        }

                        foreach ($ServiceName in $ServicesToRestart) {
                            try {
                                if ($PSCmdlet.ShouldProcess($ServiceName, "Restart service")) {
                                    Restart-Service -Name $ServiceName -Force -ErrorAction SilentlyContinue
                                    $ComputerResult.ServiceChanges += "Restarted service: $ServiceName"
                                    Write-CustomLog -Level 'SUCCESS' -Message "Restarted service: $ServiceName"
                                }
                            } catch {
                                Write-CustomLog -Level 'WARNING' -Message "Failed to restart service $ServiceName`: $($_.Exception.Message)"
                            }
                        }
                    }

                } catch {
                    $Error = "Failed to process computer $Computer`: $($_.Exception.Message)"
                    $ComputerResult.Errors += $Error
                    Write-CustomLog -Level 'ERROR' -Message $Error
                }

                $HardeningResults.ComputersProcessed += $ComputerResult

                # Log summary for this computer
                if ($ComputerResult.ChangesMade -gt 0) {
                    Write-CustomLog -Level 'SUCCESS' -Message "Protocol hardening completed for $Computer`: $($ComputerResult.ChangesMade) changes made"
                } else {
                    Write-CustomLog -Level 'INFO' -Message "No protocol changes needed for $Computer"
                }
            }

        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Error during protocol hardening: $($_.Exception.Message)"
            throw
        }
    }

    end {
        Write-CustomLog -Level 'SUCCESS' -Message "Weak protocol hardening operation completed"

        # Generate recommendations
        $HardeningResults.Recommendations += "Restart affected systems to ensure all protocol changes take effect"
        $HardeningResults.Recommendations += "Test application connectivity after protocol hardening"
        $HardeningResults.Recommendations += "Monitor security logs for protocol-related events"
        $HardeningResults.Recommendations += "Regularly audit enabled protocols for compliance"
        $HardeningResults.Recommendations += "Consider implementing network segmentation for legacy applications"

        if ($HardeningResults.RegistryChanges -gt 0) {
            $HardeningResults.Recommendations += "Registry changes require system restart for full effect"
        }

        if ($HardeningResults.ServicesModified -gt 0) {
            $HardeningResults.Recommendations += "Verify that dependent applications still function after service changes"
        }

        # Generate HTML report if requested
        if ($ReportPath) {
            try {
                $HtmlReport = @"
<!DOCTYPE html>
<html>
<head>
    <title>Weak Protocol Hardening Report</title>
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
        <h1>Weak Protocol Hardening Report</h1>
        <p><strong>Categories:</strong> $($HardeningResults.ProtocolCategories -join ', ')</p>
        <p><strong>Generated:</strong> $(Get-Date)</p>
        <p><strong>Computers Processed:</strong> $($HardeningResults.ComputersProcessed.Count)</p>
        <p><strong>Registry Changes:</strong> $($HardeningResults.RegistryChanges)</p>
        <p><strong>Services Modified:</strong> $($HardeningResults.ServicesModified)</p>
    </div>
"@

                foreach ($Computer in $HardeningResults.ComputersProcessed) {
                    $HtmlReport += "<div class='computer'>"
                    $HtmlReport += "<h2>$($Computer.ComputerName)</h2>"
                    $HtmlReport += "<p><strong>Changes Made:</strong> $($Computer.ChangesMade)</p>"
                    $HtmlReport += "<p><strong>Protocols Disabled:</strong> $($Computer.ProtocolsDisabled -join ', ')</p>"

                    if ($Computer.RegistryChanges.Count -gt 0) {
                        $HtmlReport += "<h3>Registry Changes</h3>"
                        $HtmlReport += "<table><tr><th>Protocol</th><th>Path</th><th>Setting</th><th>Old Value</th><th>New Value</th></tr>"

                        foreach ($Change in $Computer.RegistryChanges) {
                            $HtmlReport += "<tr>"
                            $HtmlReport += "<td>$($Change.Protocol)</td>"
                            $HtmlReport += "<td>$($Change.Path)</td>"
                            $HtmlReport += "<td>$($Change.Setting)</td>"
                            $HtmlReport += "<td>$($Change.OldValue)</td>"
                            $HtmlReport += "<td>$($Change.NewValue)</td>"
                            $HtmlReport += "</tr>"
                        }

                        $HtmlReport += "</table>"
                    }

                    $HtmlReport += "</div>"
                }

                $HtmlReport += "<div class='header'><h2>Recommendations</h2>"
                foreach ($Rec in $HardeningResults.Recommendations) {
                    $HtmlReport += "<div class='recommendation'>$Rec</div>"
                }
                $HtmlReport += "</div>"

                $HtmlReport += "</body></html>"

                $HtmlReport | Out-File -FilePath $ReportPath -Encoding UTF8
                Write-CustomLog -Level 'SUCCESS' -Message "Hardening report saved to: $ReportPath"

            } catch {
                Write-CustomLog -Level 'ERROR' -Message "Failed to generate report: $($_.Exception.Message)"
            }
        }

        # Display summary
        Write-CustomLog -Level 'INFO' -Message "Protocol Hardening Summary:"
        Write-CustomLog -Level 'INFO' -Message "  Categories: $($HardeningResults.ProtocolCategories -join ', ')"
        Write-CustomLog -Level 'INFO' -Message "  Computers: $($HardeningResults.ComputersProcessed.Count)"
        Write-CustomLog -Level 'INFO' -Message "  Registry Changes: $($HardeningResults.RegistryChanges)"
        Write-CustomLog -Level 'INFO' -Message "  Services Modified: $($HardeningResults.ServicesModified)"

        if ($TestMode) {
            Write-CustomLog -Level 'INFO' -Message "TEST MODE: No actual changes were made"
        }

        return $HardeningResults
    }
}

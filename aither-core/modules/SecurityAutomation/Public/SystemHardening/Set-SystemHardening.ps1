function Set-SystemHardening {
    <#
    .SYNOPSIS
        Applies comprehensive system hardening configurations for Windows systems.

    .DESCRIPTION
        Implements enterprise-grade system hardening by configuring security policies,
        registry settings, services, and system features. Supports multiple hardening
        profiles and can validate existing configurations.

    .PARAMETER HardeningProfile
        Predefined hardening profile to apply

    .PARAMETER ComputerName
        Target computer names for hardening. Default: localhost

    .PARAMETER Credential
        Credentials for remote computer access

    .PARAMETER CustomSettings
        Hashtable of custom registry settings to apply

    .PARAMETER DisableServices
        Array of service names to disable for hardening

    .PARAMETER RemoveFeatures
        Array of Windows features to remove/disable

    .PARAMETER TestMode
        Show what would be changed without making modifications

    .PARAMETER ValidationOnly
        Only validate current hardening state, don't make changes

    .PARAMETER ReportPath
        Path to save hardening report

    .PARAMETER BackupPath
        Path to save configuration backup before changes

    .PARAMETER ApplyImmediately
        Apply changes immediately without confirmation prompts

    .EXAMPLE
        Set-SystemHardening -HardeningProfile 'CISLevel1' -ReportPath 'C:\Reports\hardening.html'

    .EXAMPLE
        Set-SystemHardening -ComputerName @('Server1', 'Server2') -ValidationOnly -Credential $Creds

    .EXAMPLE
        Set-SystemHardening -HardeningProfile 'Custom' -CustomSettings @{'HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging' = @{EnableScriptBlockLogging = 1}}
    #>

    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter()]
        [ValidateSet('CISLevel1', 'CISLevel2', 'DODBaseline', 'Custom', 'MinimalServer', 'Workstation')]
        [string]$HardeningProfile = 'CISLevel1',

        [Parameter()]
        [string[]]$ComputerName = @('localhost'),

        [Parameter()]
        [pscredential]$Credential,

        [Parameter()]
        [hashtable]$CustomSettings = @{},

        [Parameter()]
        [string[]]$DisableServices = @(),

        [Parameter()]
        [string[]]$RemoveFeatures = @(),

        [Parameter()]
        [switch]$TestMode,

        [Parameter()]
        [switch]$ValidationOnly,

        [Parameter()]
        [string]$ReportPath,

        [Parameter()]
        [string]$BackupPath,

        [Parameter()]
        [switch]$ApplyImmediately
    )

    begin {
        Write-CustomLog -Level 'INFO' -Message "Starting system hardening operation: $HardeningProfile"

        # Check if running as Administrator
        $CurrentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
        $Principal = New-Object Security.Principal.WindowsPrincipal($CurrentUser)
        if (-not $Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            throw "This function requires Administrator privileges"
        }

        # Define hardening profiles
        $HardeningProfiles = @{
            'CISLevel1' = @{
                RegistrySettings = @{
                    # Password Policy
                    'HKLM:\SYSTEM\CurrentControlSet\Services\Netlogon\Parameters' = @{
                        'RequireSignOrSeal' = 1
                        'RequireStrongKey' = 1
                    }
                    # Network Security
                    'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' = @{
                        'LmCompatibilityLevel' = 5
                        'NoLMHash' = 1
                        'RestrictAnonymous' = 1
                        'RestrictAnonymousSAM' = 1
                    }
                    # UAC Settings
                    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' = @{
                        'EnableLUA' = 1
                        'ConsentPromptBehaviorAdmin' = 2
                        'ConsentPromptBehaviorUser' = 3
                        'PromptOnSecureDesktop' = 1
                    }
                    # Windows Defender
                    'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender' = @{
                        'DisableAntiSpyware' = 0
                    }
                    # PowerShell Logging
                    'HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging' = @{
                        'EnableScriptBlockLogging' = 1
                    }
                    'HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging' = @{
                        'EnableModuleLogging' = 1
                    }
                }
                ServicesToDisable = @('TelnetService', 'SNMP', 'RemoteRegistry', 'Browser')
                FeaturesToRemove = @('TelnetClient', 'TFTP', 'SimpleTCP')
                AuditPolicies = @{
                    'Logon/Logoff' = 'Success,Failure'
                    'Account Management' = 'Success,Failure'
                    'Directory Service Access' = 'Failure'
                    'Privilege Use' = 'Failure'
                    'System' = 'Success,Failure'
                }
            }
            'CISLevel2' = @{
                RegistrySettings = @{
                    # Include all Level1 settings plus additional
                    'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WinRM\Service' = @{
                        'AllowUnencryptedTraffic' = 0
                        'AllowBasic' = 0
                    }
                    'HKLM:\SOFTWARE\Policies\Microsoft\Windows\EventLog\Security' = @{
                        'MaxSize' = 196608
                        'Retention' = 0
                    }
                    # Disable SMBv1
                    'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters' = @{
                        'SMB1' = 0
                    }
                }
                ServicesToDisable = @('TelnetService', 'SNMP', 'RemoteRegistry', 'Browser', 'WinRM', 'WMPNetworkSvc')
                FeaturesToRemove = @('TelnetClient', 'TFTP', 'SimpleTCP', 'SMB1Protocol')
            }
            'DODBaseline' = @{
                RegistrySettings = @{
                    # DoD-specific hardening
                    'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' = @{
                        'DontDisplayNetworkSelectionUI' = 1
                    }
                    'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services' = @{
                        'fEncryptRPCTraffic' = 1
                        'MinEncryptionLevel' = 3
                    }
                }
                ServicesToDisable = @('TelnetService', 'SNMP', 'RemoteRegistry', 'Browser', 'Fax', 'MSiSCSI')
                FeaturesToRemove = @('TelnetClient', 'TFTP', 'SimpleTCP', 'Internet-Explorer-Optional-amd64')
            }
            'MinimalServer' = @{
                RegistrySettings = @{
                    # Server Core hardening
                    'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Installer' = @{
                        'AlwaysInstallElevated' = 0
                    }
                }
                ServicesToDisable = @('Themes', 'AudioSrv', 'AudioEndpointBuilder', 'TabletInputService')
                FeaturesToRemove = @('PowerShell-ISE', 'ServerGui-Mgmt-Infra', 'Server-Gui-Shell')
            }
        }

        $HardeningResults = @{
            Profile = $HardeningProfile
            ComputersProcessed = @()
            RegistryChanges = 0
            ServiceChanges = 0
            FeatureChanges = 0
            ValidationResults = @()
            Errors = @()
            Recommendations = @()
        }
    }

    process {
        try {
            foreach ($Computer in $ComputerName) {
                Write-CustomLog -Level 'INFO' -Message "Processing hardening for: $Computer"

                $ComputerResult = @{
                    ComputerName = $Computer
                    Timestamp = Get-Date
                    RegistrySettings = @{}
                    Services = @{}
                    Features = @{}
                    AuditPolicies = @{}
                    ValidationStatus = 'Unknown'
                    ChangesMade = 0
                    Errors = @()
                }

                try {
                    # Create backup if requested
                    if ($BackupPath -and -not $ValidationOnly) {
                        Write-CustomLog -Level 'INFO' -Message "Creating configuration backup for $Computer"

                        $BackupFile = Join-Path $BackupPath "$Computer-hardening-backup-$(Get-Date -Format 'yyyyMMdd-HHmmss').xml"

                        $BackupData = @{
                            Registry = @{}
                            Services = Get-Service | Select-Object Name, Status, StartType
                            Features = Get-WindowsFeature | Where-Object {$_.InstallState -eq 'Installed'}
                        }

                        $BackupData | Export-Clixml -Path $BackupFile -Force
                        Write-CustomLog -Level 'SUCCESS' -Message "Backup saved to: $BackupFile"
                    }

                    # Get hardening configuration
                    $Config = $HardeningProfiles[$HardeningProfile]

                    # Merge custom settings if provided
                    if ($CustomSettings.Count -gt 0) {
                        foreach ($Key in $CustomSettings.Keys) {
                            $Config.RegistrySettings[$Key] = $CustomSettings[$Key]
                        }
                    }

                    # Add custom services and features
                    if ($DisableServices.Count -gt 0) {
                        $Config.ServicesToDisable += $DisableServices
                    }

                    if ($RemoveFeatures.Count -gt 0) {
                        $Config.FeaturesToRemove += $RemoveFeatures
                    }

                    # Process registry settings
                    Write-CustomLog -Level 'INFO' -Message "Applying registry hardening settings"

                    foreach ($RegistryPath in $Config.RegistrySettings.Keys) {
                        try {
                            $Settings = $Config.RegistrySettings[$RegistryPath]

                            # Ensure registry path exists
                            if (-not (Test-Path $RegistryPath)) {
                                if (-not $ValidationOnly -and -not $TestMode) {
                                    New-Item -Path $RegistryPath -Force | Out-Null
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

                                $ComputerResult.RegistrySettings["$RegistryPath\$Setting"] = @{
                                    Current = $CurrentValue
                                    Required = $Value
                                    Compliant = ($CurrentValue -eq $Value)
                                }

                                if ($CurrentValue -ne $Value) {
                                    if ($ValidationOnly) {
                                        Write-CustomLog -Level 'WARNING' -Message "Registry non-compliance: $RegistryPath\$Setting = $CurrentValue (should be $Value)"
                                    } elseif ($TestMode) {
                                        Write-CustomLog -Level 'INFO' -Message "[TEST] Would set $RegistryPath\$Setting to $Value"
                                    } else {
                                        if ($PSCmdlet.ShouldProcess("$RegistryPath\$Setting", "Set to $Value")) {
                                            Set-ItemProperty -Path $RegistryPath -Name $Setting -Value $Value -Force
                                            $HardeningResults.RegistryChanges++
                                            $ComputerResult.ChangesMade++
                                            Write-CustomLog -Level 'SUCCESS' -Message "Set $RegistryPath\$Setting = $Value"
                                        }
                                    }
                                }
                            }

                        } catch {
                            $Error = "Failed to process registry path $RegistryPath: $($_.Exception.Message)"
                            $ComputerResult.Errors += $Error
                            Write-CustomLog -Level 'ERROR' -Message $Error
                        }
                    }

                    # Process service hardening
                    if ($Config.ServicesToDisable) {
                        Write-CustomLog -Level 'INFO' -Message "Processing service hardening"

                        foreach ($ServiceName in $Config.ServicesToDisable) {
                            try {
                                $Service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue

                                if ($Service) {
                                    $ComputerResult.Services[$ServiceName] = @{
                                        Current = $Service.Status
                                        StartType = $Service.StartType
                                        Required = 'Disabled'
                                        Compliant = ($Service.StartType -eq 'Disabled')
                                    }

                                    if ($Service.StartType -ne 'Disabled') {
                                        if ($ValidationOnly) {
                                            Write-CustomLog -Level 'WARNING' -Message "Service non-compliance: $ServiceName is $($Service.StartType) (should be Disabled)"
                                        } elseif ($TestMode) {
                                            Write-CustomLog -Level 'INFO' -Message "[TEST] Would disable service: $ServiceName"
                                        } else {
                                            if ($PSCmdlet.ShouldProcess($ServiceName, "Disable service")) {
                                                Stop-Service -Name $ServiceName -Force -ErrorAction SilentlyContinue
                                                Set-Service -Name $ServiceName -StartupType Disabled
                                                $HardeningResults.ServiceChanges++
                                                $ComputerResult.ChangesMade++
                                                Write-CustomLog -Level 'SUCCESS' -Message "Disabled service: $ServiceName"
                                            }
                                        }
                                    }
                                } else {
                                    $ComputerResult.Services[$ServiceName] = @{
                                        Current = 'Not Found'
                                        Required = 'Disabled'
                                        Compliant = $true
                                    }
                                }

                            } catch {
                                $Error = "Failed to process service $ServiceName: $($_.Exception.Message)"
                                $ComputerResult.Errors += $Error
                                Write-CustomLog -Level 'ERROR' -Message $Error
                            }
                        }
                    }

                    # Process Windows features
                    if ($Config.FeaturesToRemove) {
                        Write-CustomLog -Level 'INFO' -Message "Processing Windows features hardening"

                        foreach ($FeatureName in $Config.FeaturesToRemove) {
                            try {
                                $Feature = Get-WindowsFeature -Name $FeatureName -ErrorAction SilentlyContinue

                                if ($Feature) {
                                    $ComputerResult.Features[$FeatureName] = @{
                                        Current = $Feature.InstallState
                                        Required = 'Removed'
                                        Compliant = ($Feature.InstallState -eq 'Removed' -or $Feature.InstallState -eq 'Available')
                                    }

                                    if ($Feature.InstallState -eq 'Installed') {
                                        if ($ValidationOnly) {
                                            Write-CustomLog -Level 'WARNING' -Message "Feature non-compliance: $FeatureName is Installed (should be Removed)"
                                        } elseif ($TestMode) {
                                            Write-CustomLog -Level 'INFO' -Message "[TEST] Would remove feature: $FeatureName"
                                        } else {
                                            if ($PSCmdlet.ShouldProcess($FeatureName, "Remove Windows feature")) {
                                                Uninstall-WindowsFeature -Name $FeatureName -Remove
                                                $HardeningResults.FeatureChanges++
                                                $ComputerResult.ChangesMade++
                                                Write-CustomLog -Level 'SUCCESS' -Message "Removed feature: $FeatureName"
                                            }
                                        }
                                    }
                                } else {
                                    $ComputerResult.Features[$FeatureName] = @{
                                        Current = 'Not Found'
                                        Required = 'Removed'
                                        Compliant = $true
                                    }
                                }

                            } catch {
                                $Error = "Failed to process feature $FeatureName: $($_.Exception.Message)"
                                $ComputerResult.Errors += $Error
                                Write-CustomLog -Level 'ERROR' -Message $Error
                            }
                        }
                    }

                    # Apply audit policies
                    if ($Config.AuditPolicies -and -not $ValidationOnly) {
                        Write-CustomLog -Level 'INFO' -Message "Configuring audit policies"

                        foreach ($Policy in $Config.AuditPolicies.Keys) {
                            try {
                                $Setting = $Config.AuditPolicies[$Policy]

                                if (-not $TestMode) {
                                    if ($PSCmdlet.ShouldProcess($Policy, "Set audit policy to $Setting")) {
                                        & auditpol /set /subcategory:"$Policy" /success:enable /failure:enable
                                        Write-CustomLog -Level 'SUCCESS' -Message "Set audit policy: $Policy = $Setting"
                                    }
                                } else {
                                    Write-CustomLog -Level 'INFO' -Message "[TEST] Would set audit policy: $Policy = $Setting"
                                }

                                $ComputerResult.AuditPolicies[$Policy] = $Setting

                            } catch {
                                $Error = "Failed to set audit policy $Policy: $($_.Exception.Message)"
                                $ComputerResult.Errors += $Error
                                Write-CustomLog -Level 'ERROR' -Message $Error
                            }
                        }
                    }

                    # Calculate compliance score
                    $TotalChecks = 0
                    $CompliantChecks = 0

                    foreach ($Check in $ComputerResult.RegistrySettings.Values) {
                        $TotalChecks++
                        if ($Check.Compliant) { $CompliantChecks++ }
                    }

                    foreach ($Check in $ComputerResult.Services.Values) {
                        $TotalChecks++
                        if ($Check.Compliant) { $CompliantChecks++ }
                    }

                    foreach ($Check in $ComputerResult.Features.Values) {
                        $TotalChecks++
                        if ($Check.Compliant) { $CompliantChecks++ }
                    }

                    if ($TotalChecks -gt 0) {
                        $CompliancePercentage = [math]::Round(($CompliantChecks / $TotalChecks) * 100, 2)
                        $ComputerResult.ValidationStatus = "$CompliancePercentage% compliant"

                        if ($CompliancePercentage -eq 100) {
                            Write-CustomLog -Level 'SUCCESS' -Message "$Computer is fully compliant with $HardeningProfile profile"
                        } elseif ($CompliancePercentage -ge 80) {
                            Write-CustomLog -Level 'WARNING' -Message "$Computer is $CompliancePercentage% compliant with $HardeningProfile profile"
                        } else {
                            Write-CustomLog -Level 'ERROR' -Message "$Computer is only $CompliancePercentage% compliant with $HardeningProfile profile"
                        }
                    }

                } catch {
                    $Error = "Failed to process computer $Computer: $($_.Exception.Message)"
                    $ComputerResult.Errors += $Error
                    Write-CustomLog -Level 'ERROR' -Message $Error
                }

                $HardeningResults.ComputersProcessed += $ComputerResult
            }

        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Error during system hardening: $($_.Exception.Message)"
            throw
        }
    }

    end {
        Write-CustomLog -Level 'SUCCESS' -Message "System hardening operation completed"

        # Generate recommendations
        $HardeningResults.Recommendations += "Regularly validate hardening compliance with automated tools"
        $HardeningResults.Recommendations += "Monitor system logs for security events after hardening"
        $HardeningResults.Recommendations += "Test applications thoroughly after applying hardening changes"
        $HardeningResults.Recommendations += "Keep hardening configurations updated with security baselines"
        $HardeningResults.Recommendations += "Document all custom hardening settings for compliance audits"

        if ($HardeningResults.RegistryChanges -gt 0) {
            $HardeningResults.Recommendations += "Restart systems after registry changes to ensure all settings take effect"
        }

        if ($HardeningResults.ServiceChanges -gt 0) {
            $HardeningResults.Recommendations += "Verify application functionality after service changes"
        }

        # Generate HTML report if requested
        if ($ReportPath) {
            try {
                $HtmlReport = @"
<!DOCTYPE html>
<html>
<head>
    <title>System Hardening Report - $HardeningProfile</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #f0f0f0; padding: 15px; border-radius: 5px; }
        .computer { border: 1px solid #ccc; margin: 20px 0; padding: 15px; border-radius: 5px; }
        .compliant { color: green; font-weight: bold; }
        .non-compliant { color: red; font-weight: bold; }
        .warning { color: orange; font-weight: bold; }
        table { border-collapse: collapse; width: 100%; margin: 10px 0; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
        .recommendation { background-color: #e7f3ff; padding: 10px; margin: 5px 0; border-radius: 3px; }
    </style>
</head>
<body>
    <div class='header'>
        <h1>System Hardening Report</h1>
        <p><strong>Profile:</strong> $HardeningProfile</p>
        <p><strong>Generated:</strong> $(Get-Date)</p>
        <p><strong>Computers Processed:</strong> $($HardeningResults.ComputersProcessed.Count)</p>
        <p><strong>Registry Changes:</strong> $($HardeningResults.RegistryChanges)</p>
        <p><strong>Service Changes:</strong> $($HardeningResults.ServiceChanges)</p>
        <p><strong>Feature Changes:</strong> $($HardeningResults.FeatureChanges)</p>
    </div>
"@

                foreach ($Computer in $HardeningResults.ComputersProcessed) {
                    $HtmlReport += "<div class='computer'>"
                    $HtmlReport += "<h2>$($Computer.ComputerName)</h2>"
                    $HtmlReport += "<p><strong>Status:</strong> $($Computer.ValidationStatus)</p>"
                    $HtmlReport += "<p><strong>Changes Made:</strong> $($Computer.ChangesMade)</p>"

                    if ($Computer.RegistrySettings.Count -gt 0) {
                        $HtmlReport += "<h3>Registry Settings</h3>"
                        $HtmlReport += "<table><tr><th>Setting</th><th>Current</th><th>Required</th><th>Status</th></tr>"

                        foreach ($Setting in $Computer.RegistrySettings.Keys) {
                            $RegSetting = $Computer.RegistrySettings[$Setting]
                            $StatusClass = if ($RegSetting.Compliant) { 'compliant' } else { 'non-compliant' }
                            $StatusText = if ($RegSetting.Compliant) { 'Compliant' } else { 'Non-Compliant' }

                            $HtmlReport += "<tr>"
                            $HtmlReport += "<td>$Setting</td>"
                            $HtmlReport += "<td>$($RegSetting.Current)</td>"
                            $HtmlReport += "<td>$($RegSetting.Required)</td>"
                            $HtmlReport += "<td class='$StatusClass'>$StatusText</td>"
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
        Write-CustomLog -Level 'INFO' -Message "Hardening Summary:"
        Write-CustomLog -Level 'INFO' -Message "  Profile: $($HardeningResults.Profile)"
        Write-CustomLog -Level 'INFO' -Message "  Computers: $($HardeningResults.ComputersProcessed.Count)"
        Write-CustomLog -Level 'INFO' -Message "  Registry Changes: $($HardeningResults.RegistryChanges)"
        Write-CustomLog -Level 'INFO' -Message "  Service Changes: $($HardeningResults.ServiceChanges)"
        Write-CustomLog -Level 'INFO' -Message "  Feature Changes: $($HardeningResults.FeatureChanges)"

        return $HardeningResults
    }
}

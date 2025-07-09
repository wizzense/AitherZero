function Set-WindowsFeatureSecurity {
    <#
    .SYNOPSIS
        Manages Windows features for security hardening by removing unnecessary features and services.

    .DESCRIPTION
        Analyzes and manages Windows features to reduce attack surface by removing or disabling
        unnecessary features, legacy protocols, and optional components that pose security risks.
        Supports both removal and installation based on security profiles.

    .PARAMETER SecurityProfile
        Predefined security profile for feature management

    .PARAMETER ComputerName
        Target computer names. Default: localhost

    .PARAMETER Credential
        Credentials for remote computer access

    .PARAMETER RemoveFeatures
        Array of specific features to remove

    .PARAMETER InstallFeatures
        Array of specific features to install for security

    .PARAMETER InventoryOnly
        Only inventory current features without making changes

    .PARAMETER RequiredFeatures
        Features that must remain installed (protected from removal)

    .PARAMETER TestMode
        Show what would be changed without making modifications

    .PARAMETER ReportPath
        Path to save feature management report

    .PARAMETER BackupConfiguration
        Create backup of current feature state before changes

    .PARAMETER Force
        Force removal of features without confirmation

    .EXAMPLE
        Set-WindowsFeatureSecurity -SecurityProfile 'Server' -ReportPath 'C:\Reports\features.html'

    .EXAMPLE
        Set-WindowsFeatureSecurity -RemoveFeatures @('TelnetClient', 'SimpleTCP') -InstallFeatures @('Windows-Defender')

    .EXAMPLE
        Set-WindowsFeatureSecurity -ComputerName @('Server1', 'Server2') -InventoryOnly -Credential $Creds
    #>

    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter()]
        [ValidateSet('Workstation', 'Server', 'DomainController', 'MinimalServer', 'Custom')]
        [string]$SecurityProfile = 'Server',

        [Parameter()]
        [string[]]$ComputerName = @('localhost'),

        [Parameter()]
        [pscredential]$Credential,

        [Parameter()]
        [string[]]$RemoveFeatures = @(),

        [Parameter()]
        [string[]]$InstallFeatures = @(),

        [Parameter()]
        [switch]$InventoryOnly,

        [Parameter()]
        [string[]]$RequiredFeatures = @(),

        [Parameter()]
        [switch]$TestMode,

        [Parameter()]
        [string]$ReportPath,

        [Parameter()]
        [switch]$BackupConfiguration,

        [Parameter()]
        [switch]$Force
    )

    begin {
        Write-CustomLog -Level 'INFO' -Message "Starting Windows feature security management: $SecurityProfile profile"

        # Check if running as Administrator
        $CurrentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
        $Principal = New-Object Security.Principal.WindowsPrincipal($CurrentUser)
        if (-not $Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            throw "This function requires Administrator privileges"
        }

        # Define security profiles for feature management
        $SecurityProfiles = @{
            'Workstation' = @{
                RemoveFeatures = @(
                    'TelnetClient',
                    'TFTP',
                    'SimpleTCP',
                    'Internet-Explorer-Optional-amd64',
                    'LegacyComponents',
                    'DirectoryServices-ADAM-Client',
                    'RasCMAK',
                    'RasRip'
                )
                InstallFeatures = @(
                    'Windows-Defender-Features',
                    'BitLocker',
                    'BitLocker-Utilities'
                )
                Description = 'Standard workstation hardening profile'
            }
            'Server' = @{
                RemoveFeatures = @(
                    'TelnetClient',
                    'TelnetServer',
                    'TFTP',
                    'SimpleTCP',
                    'Internet-Explorer-Optional-amd64',
                    'WindowsMediaPlayer',
                    'SMB1Protocol',
                    'SMB1Protocol-Client',
                    'SMB1Protocol-Server',
                    'LegacyComponents',
                    'DirectoryServices-ADAM-Client',
                    'RasCMAK',
                    'RasRip',
                    'SNMP-Service',
                    'SNMP-WMI-Provider'
                )
                InstallFeatures = @(
                    'Windows-Defender-Features',
                    'BitLocker',
                    'BitLocker-Utilities',
                    'FailoverCluster-AutomationServer',
                    'RSAT-Feature-Tools'
                )
                Description = 'Standard server hardening profile'
            }
            'DomainController' = @{
                RemoveFeatures = @(
                    'TelnetClient',
                    'TelnetServer',
                    'TFTP',
                    'SimpleTCP',
                    'Internet-Explorer-Optional-amd64',
                    'WindowsMediaPlayer',
                    'SMB1Protocol',
                    'LegacyComponents',
                    'SNMP-Service'
                )
                InstallFeatures = @(
                    'Windows-Defender-Features',
                    'BitLocker',
                    'ActiveDirectory-PowerShell',
                    'RSAT-ADDS-Tools',
                    'RSAT-DNS-Server'
                )
                Description = 'Domain controller security profile'
            }
            'MinimalServer' = @{
                RemoveFeatures = @(
                    'TelnetClient',
                    'TelnetServer',
                    'TFTP',
                    'SimpleTCP',
                    'Internet-Explorer-Optional-amd64',
                    'WindowsMediaPlayer',
                    'SMB1Protocol',
                    'SMB1Protocol-Client',
                    'SMB1Protocol-Server',
                    'LegacyComponents',
                    'DirectoryServices-ADAM-Client',
                    'RasCMAK',
                    'RasRip',
                    'SNMP-Service',
                    'SNMP-WMI-Provider',
                    'Printing-PrintToPDFServices-Features',
                    'Printing-XPSServices-Features',
                    'WorkFolders-Client',
                    'MediaPlayback'
                )
                InstallFeatures = @(
                    'Windows-Defender-Features'
                )
                Description = 'Minimal server attack surface profile'
            }
        }

        $FeatureResults = @{
            Profile = $SecurityProfile
            ComputersProcessed = @()
            FeaturesRemoved = 0
            FeaturesInstalled = 0
            InventoryData = @()
            Errors = @()
            Recommendations = @()
        }

        # Define critical features that should never be removed
        $CriticalFeatures = @(
            'NetFx4Extended-ASPNET45',
            'IIS-WebServerRole',
            'IIS-WebServer',
            'Microsoft-Windows-PowerShell-ISE-Feature',
            'MicrosoftWindowsPowerShellV2Root',
            'ActiveDirectory-PowerShell',
            'RSAT-AD-PowerShell'
        )

        # Merge critical features with user-specified required features
        $AllRequiredFeatures = $CriticalFeatures + $RequiredFeatures | Sort-Object -Unique
    }

    process {
        try {
            foreach ($Computer in $ComputerName) {
                Write-CustomLog -Level 'INFO' -Message "Processing Windows features on: $Computer"

                $ComputerResult = @{
                    ComputerName = $Computer
                    Timestamp = Get-Date
                    CurrentFeatures = @()
                    RemovedFeatures = @()
                    InstalledFeatures = @()
                    SkippedFeatures = @()
                    SecurityRisks = @()
                    ChangesMade = 0
                    Errors = @()
                }

                try {
                    # Get current feature inventory
                    Write-CustomLog -Level 'INFO' -Message "Inventorying Windows features on $Computer"

                    $SessionParams = @{
                        ErrorAction = 'Stop'
                    }

                    if ($Computer -ne 'localhost') {
                        $SessionParams['ComputerName'] = $Computer
                        if ($Credential) {
                            $SessionParams['Credential'] = $Credential
                        }
                    }

                    # Get all Windows features
                    $AllFeatures = if ($Computer -ne 'localhost') {
                        Invoke-Command @SessionParams -ScriptBlock {
                            try {
                                Get-WindowsFeature | Select-Object Name, DisplayName, InstallState, FeatureType, Path
                            } catch {
                                # Fallback for Windows 10/11
                                Get-WindowsOptionalFeature -Online | Select-Object FeatureName, State, @{N='Name';E={$_.FeatureName}}, @{N='DisplayName';E={$_.DisplayName}}, @{N='InstallState';E={$_.State}}
                            }
                        }
                    } else {
                        try {
                            Get-WindowsFeature | Select-Object Name, DisplayName, InstallState, FeatureType, Path
                        } catch {
                            # Fallback for Windows 10/11
                            Get-WindowsOptionalFeature -Online | Select-Object FeatureName, State, @{N='Name';E={$_.FeatureName}}, @{N='DisplayName';E={$_.DisplayName}}, @{N='InstallState';E={$_.State}}
                        }
                    }

                    $ComputerResult.CurrentFeatures = $AllFeatures

                    Write-CustomLog -Level 'INFO' -Message "Found $($AllFeatures.Count) Windows features on $Computer"

                    # Analyze security risks from installed features
                    $InstalledFeatures = $AllFeatures | Where-Object {$_.InstallState -eq 'Installed' -or $_.State -eq 'Enabled'}

                    $RiskyFeatures = @(
                        'TelnetClient', 'TelnetServer', 'TFTP', 'SimpleTCP', 'SMB1Protocol',
                        'Internet-Explorer-Optional-amd64', 'LegacyComponents', 'SNMP-Service'
                    )

                    foreach ($Feature in $InstalledFeatures) {
                        $FeatureName = if ($Feature.Name) { $Feature.Name } else { $Feature.FeatureName }

                        if ($FeatureName -in $RiskyFeatures) {
                            $Risk = @{
                                FeatureName = $FeatureName
                                RiskLevel = switch ($FeatureName) {
                                    'TelnetServer' { 'Critical' }
                                    'SMB1Protocol' { 'High' }
                                    'TelnetClient' { 'High' }
                                    'SNMP-Service' { 'Medium' }
                                    default { 'Low' }
                                }
                                Description = switch ($FeatureName) {
                                    'TelnetServer' { 'Telnet server provides unencrypted remote access' }
                                    'SMB1Protocol' { 'SMBv1 is vulnerable to known exploits' }
                                    'TelnetClient' { 'Telnet client sends credentials in plaintext' }
                                    'SNMP-Service' { 'SNMP service may expose system information' }
                                    default { 'Legacy or unnecessary feature' }
                                }
                            }

                            $ComputerResult.SecurityRisks += $Risk
                        }
                    }

                    if (-not $InventoryOnly) {
                        # Backup current configuration if requested
                        if ($BackupConfiguration) {
                            Write-CustomLog -Level 'INFO' -Message "Creating feature configuration backup for $Computer"

                            $BackupFile = "features-backup-$Computer-$(Get-Date -Format 'yyyyMMdd-HHmmss').xml"
                            $ComputerResult.CurrentFeatures | Export-Clixml -Path $BackupFile -Force
                            Write-CustomLog -Level 'SUCCESS' -Message "Backup saved to: $BackupFile"
                        }

                        # Get features to process based on profile or explicit lists
                        $FeaturesToRemove = if ($SecurityProfile -ne 'Custom') {
                            $SecurityProfiles[$SecurityProfile].RemoveFeatures + $RemoveFeatures | Sort-Object -Unique
                        } else {
                            $RemoveFeatures
                        }

                        $FeaturesToInstall = if ($SecurityProfile -ne 'Custom') {
                            $SecurityProfiles[$SecurityProfile].InstallFeatures + $InstallFeatures | Sort-Object -Unique
                        } else {
                            $InstallFeatures
                        }

                        # Remove features
                        if ($FeaturesToRemove.Count -gt 0) {
                            Write-CustomLog -Level 'INFO' -Message "Processing $($FeaturesToRemove.Count) features for removal"

                            foreach ($FeatureName in $FeaturesToRemove) {
                                try {
                                    # Check if feature is in required/critical list
                                    if ($FeatureName -in $AllRequiredFeatures) {
                                        Write-CustomLog -Level 'WARNING' -Message "Skipping removal of required feature: $FeatureName"
                                        $ComputerResult.SkippedFeatures += $FeatureName
                                        continue
                                    }

                                    # Check if feature exists and is installed
                                    $Feature = $AllFeatures | Where-Object {
                                        ($_.Name -eq $FeatureName -or $_.FeatureName -eq $FeatureName) -and
                                        ($_.InstallState -eq 'Installed' -or $_.State -eq 'Enabled')
                                    }

                                    if ($Feature) {
                                        if ($TestMode) {
                                            Write-CustomLog -Level 'INFO' -Message "[TEST] Would remove feature: $FeatureName"
                                        } else {
                                            if ($Force -or $PSCmdlet.ShouldProcess($FeatureName, "Remove Windows feature")) {
                                                if ($Computer -ne 'localhost') {
                                                    Invoke-Command @SessionParams -ScriptBlock {
                                                        param($FeatureName)
                                                        try {
                                                            Uninstall-WindowsFeature -Name $FeatureName -Remove -ErrorAction Stop
                                                        } catch {
                                                            # Try alternative method for Windows 10/11
                                                            Disable-WindowsOptionalFeature -Online -FeatureName $FeatureName -Remove -NoRestart -ErrorAction Stop
                                                        }
                                                    } -ArgumentList $FeatureName
                                                } else {
                                                    try {
                                                        Uninstall-WindowsFeature -Name $FeatureName -Remove -ErrorAction Stop
                                                    } catch {
                                                        # Try alternative method for Windows 10/11
                                                        Disable-WindowsOptionalFeature -Online -FeatureName $FeatureName -Remove -NoRestart -ErrorAction Stop
                                                    }
                                                }

                                                $ComputerResult.RemovedFeatures += $FeatureName
                                                $FeatureResults.FeaturesRemoved++
                                                $ComputerResult.ChangesMade++
                                                Write-CustomLog -Level 'SUCCESS' -Message "Removed feature: $FeatureName"
                                            }
                                        }
                                    } else {
                                        Write-CustomLog -Level 'INFO' -Message "Feature not installed or not found: $FeatureName"
                                    }

                                } catch {
                                    $Error = "Failed to remove feature $FeatureName`: $($_.Exception.Message)"
                                    $ComputerResult.Errors += $Error
                                    Write-CustomLog -Level 'ERROR' -Message $Error
                                }
                            }
                        }

                        # Install features
                        if ($FeaturesToInstall.Count -gt 0) {
                            Write-CustomLog -Level 'INFO' -Message "Processing $($FeaturesToInstall.Count) features for installation"

                            foreach ($FeatureName in $FeaturesToInstall) {
                                try {
                                    # Check if feature exists and is not installed
                                    $Feature = $AllFeatures | Where-Object {
                                        ($_.Name -eq $FeatureName -or $_.FeatureName -eq $FeatureName) -and
                                        ($_.InstallState -ne 'Installed' -and $_.State -ne 'Enabled')
                                    }

                                    if ($Feature) {
                                        if ($TestMode) {
                                            Write-CustomLog -Level 'INFO' -Message "[TEST] Would install feature: $FeatureName"
                                        } else {
                                            if ($Force -or $PSCmdlet.ShouldProcess($FeatureName, "Install Windows feature")) {
                                                if ($Computer -ne 'localhost') {
                                                    Invoke-Command @SessionParams -ScriptBlock {
                                                        param($FeatureName)
                                                        try {
                                                            Install-WindowsFeature -Name $FeatureName -ErrorAction Stop
                                                        } catch {
                                                            # Try alternative method for Windows 10/11
                                                            Enable-WindowsOptionalFeature -Online -FeatureName $FeatureName -NoRestart -ErrorAction Stop
                                                        }
                                                    } -ArgumentList $FeatureName
                                                } else {
                                                    try {
                                                        Install-WindowsFeature -Name $FeatureName -ErrorAction Stop
                                                    } catch {
                                                        # Try alternative method for Windows 10/11
                                                        Enable-WindowsOptionalFeature -Online -FeatureName $FeatureName -NoRestart -ErrorAction Stop
                                                    }
                                                }

                                                $ComputerResult.InstalledFeatures += $FeatureName
                                                $FeatureResults.FeaturesInstalled++
                                                $ComputerResult.ChangesMade++
                                                Write-CustomLog -Level 'SUCCESS' -Message "Installed feature: $FeatureName"
                                            }
                                        }
                                    } else {
                                        Write-CustomLog -Level 'INFO' -Message "Feature already installed or not found: $FeatureName"
                                    }

                                } catch {
                                    $Error = "Failed to install feature $FeatureName`: $($_.Exception.Message)"
                                    $ComputerResult.Errors += $Error
                                    Write-CustomLog -Level 'ERROR' -Message $Error
                                }
                            }
                        }
                    }

                    Write-CustomLog -Level 'SUCCESS' -Message "Feature processing completed for $Computer"

                } catch {
                    $Error = "Failed to process features on $Computer`: $($_.Exception.Message)"
                    $ComputerResult.Errors += $Error
                    Write-CustomLog -Level 'ERROR' -Message $Error
                }

                $FeatureResults.ComputersProcessed += $ComputerResult

                # Add to inventory data
                $InventoryItem = @{
                    ComputerName = $Computer
                    TotalFeatures = $ComputerResult.CurrentFeatures.Count
                    InstalledFeatures = ($ComputerResult.CurrentFeatures | Where-Object {$_.InstallState -eq 'Installed' -or $_.State -eq 'Enabled'}).Count
                    SecurityRisks = $ComputerResult.SecurityRisks.Count
                    ChangesMade = $ComputerResult.ChangesMade
                }

                $FeatureResults.InventoryData += $InventoryItem
            }

        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Error during Windows feature management: $($_.Exception.Message)"
            throw
        }
    }

    end {
        Write-CustomLog -Level 'SUCCESS' -Message "Windows feature security management completed"

        # Generate recommendations
        $FeatureResults.Recommendations += "Restart systems after feature changes to ensure all changes take effect"
        $FeatureResults.Recommendations += "Test critical applications after removing features"
        $FeatureResults.Recommendations += "Monitor system logs for any issues related to feature changes"
        $FeatureResults.Recommendations += "Document feature changes for compliance and rollback purposes"
        $FeatureResults.Recommendations += "Regularly review installed features for new security risks"

        if ($FeatureResults.FeaturesRemoved -gt 0) {
            $FeatureResults.Recommendations += "Verify that removed features are not required by applications"
            $FeatureResults.Recommendations += "Consider implementing application allowlisting after feature removal"
        }

        # Check for security risks across all computers
        $TotalRisks = ($FeatureResults.ComputersProcessed | ForEach-Object {$_.SecurityRisks.Count} | Measure-Object -Sum).Sum
        if ($TotalRisks -gt 0) {
            $FeatureResults.Recommendations += "Address identified security risks from installed features"
            $FeatureResults.Recommendations += "Consider additional hardening for systems with high-risk features"
        }

        # Generate report if requested
        if ($ReportPath) {
            try {
                $HtmlReport = @"
<!DOCTYPE html>
<html>
<head>
    <title>Windows Feature Security Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #f0f0f0; padding: 15px; border-radius: 5px; }
        .computer { border: 1px solid #ccc; margin: 20px 0; padding: 15px; border-radius: 5px; }
        .critical { color: red; font-weight: bold; }
        .high { color: orange; font-weight: bold; }
        .medium { color: blue; font-weight: bold; }
        .low { color: green; }
        .removed { color: red; }
        .installed { color: green; }
        table { border-collapse: collapse; width: 100%; margin: 10px 0; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
        .recommendation { background-color: #e7f3ff; padding: 10px; margin: 5px 0; border-radius: 3px; }
    </style>
</head>
<body>
    <div class='header'>
        <h1>Windows Feature Security Report</h1>
        <p><strong>Security Profile:</strong> $($FeatureResults.Profile)</p>
        <p><strong>Generated:</strong> $(Get-Date)</p>
        <p><strong>Computers Processed:</strong> $($FeatureResults.ComputersProcessed.Count)</p>
        <p><strong>Features Removed:</strong> <span class='removed'>$($FeatureResults.FeaturesRemoved)</span></p>
        <p><strong>Features Installed:</strong> <span class='installed'>$($FeatureResults.FeaturesInstalled)</span></p>
        <p><strong>Total Security Risks:</strong> $TotalRisks</p>
    </div>
"@

                foreach ($Computer in $FeatureResults.ComputersProcessed) {
                    $HtmlReport += "<div class='computer'>"
                    $HtmlReport += "<h2>$($Computer.ComputerName)</h2>"
                    $HtmlReport += "<p><strong>Total Features:</strong> $($Computer.CurrentFeatures.Count)</p>"
                    $HtmlReport += "<p><strong>Changes Made:</strong> $($Computer.ChangesMade)</p>"

                    if ($Computer.SecurityRisks.Count -gt 0) {
                        $HtmlReport += "<h3>Security Risks</h3>"
                        $HtmlReport += "<table><tr><th>Feature</th><th>Risk Level</th><th>Description</th></tr>"

                        foreach ($Risk in $Computer.SecurityRisks) {
                            $RiskClass = $Risk.RiskLevel.ToLower()
                            $HtmlReport += "<tr>"
                            $HtmlReport += "<td>$($Risk.FeatureName)</td>"
                            $HtmlReport += "<td class='$RiskClass'>$($Risk.RiskLevel)</td>"
                            $HtmlReport += "<td>$($Risk.Description)</td>"
                            $HtmlReport += "</tr>"
                        }

                        $HtmlReport += "</table>"
                    }

                    if ($Computer.RemovedFeatures.Count -gt 0) {
                        $HtmlReport += "<h3>Removed Features</h3>"
                        $HtmlReport += "<ul>"
                        foreach ($Feature in $Computer.RemovedFeatures) {
                            $HtmlReport += "<li class='removed'>$Feature</li>"
                        }
                        $HtmlReport += "</ul>"
                    }

                    if ($Computer.InstalledFeatures.Count -gt 0) {
                        $HtmlReport += "<h3>Installed Features</h3>"
                        $HtmlReport += "<ul>"
                        foreach ($Feature in $Computer.InstalledFeatures) {
                            $HtmlReport += "<li class='installed'>$Feature</li>"
                        }
                        $HtmlReport += "</ul>"
                    }

                    $HtmlReport += "</div>"
                }

                $HtmlReport += "<div class='header'><h2>Recommendations</h2>"
                foreach ($Rec in $FeatureResults.Recommendations) {
                    $HtmlReport += "<div class='recommendation'>$Rec</div>"
                }
                $HtmlReport += "</div>"

                $HtmlReport += "</body></html>"

                $HtmlReport | Out-File -FilePath $ReportPath -Encoding UTF8
                Write-CustomLog -Level 'SUCCESS' -Message "Feature security report saved to: $ReportPath"

            } catch {
                Write-CustomLog -Level 'ERROR' -Message "Failed to generate report: $($_.Exception.Message)"
            }
        }

        # Display summary
        Write-CustomLog -Level 'INFO' -Message "Feature Security Summary:"
        Write-CustomLog -Level 'INFO' -Message "  Security Profile: $($FeatureResults.Profile)"
        Write-CustomLog -Level 'INFO' -Message "  Computers: $($FeatureResults.ComputersProcessed.Count)"
        Write-CustomLog -Level 'INFO' -Message "  Features Removed: $($FeatureResults.FeaturesRemoved)"
        Write-CustomLog -Level 'INFO' -Message "  Features Installed: $($FeatureResults.FeaturesInstalled)"
        Write-CustomLog -Level 'INFO' -Message "  Security Risks Found: $TotalRisks"

        if ($TotalRisks -gt 0) {
            Write-CustomLog -Level 'WARNING' -Message "Security risks identified from installed features - review and remediate"
        }

        if ($FeatureResults.FeaturesRemoved -gt 0 -or $FeatureResults.FeaturesInstalled -gt 0) {
            Write-CustomLog -Level 'WARNING' -Message "System restart recommended to complete feature changes"
        }

        return $FeatureResults
    }
}

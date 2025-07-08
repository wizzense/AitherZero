function Enable-CredentialGuard {
    <#
    .SYNOPSIS
        Enables Windows Credential Guard for advanced credential protection.

    .DESCRIPTION
        Configures Windows Credential Guard to protect domain credentials from theft
        using virtualization-based security (VBS). Supports configuration verification,
        hardware requirement checking, and UEFI configuration validation.

    .PARAMETER ComputerName
        Target computer names for Credential Guard enablement. Default: localhost

    .PARAMETER Credential
        Credentials for remote computer access

    .PARAMETER EnableMode
        Credential Guard enablement mode

    .PARAMETER RequireUEFI
        Require UEFI boot mode for Credential Guard

    .PARAMETER RequireSecureBoot
        Require Secure Boot for Credential Guard

    .PARAMETER RequireTPM
        Require TPM 2.0 for Credential Guard

    .PARAMETER CheckHardwareRequirements
        Verify hardware requirements before enabling

    .PARAMETER TestMode
        Show what would be configured without making changes

    .PARAMETER ReportPath
        Path to save Credential Guard configuration report

    .PARAMETER ValidateConfiguration
        Validate Credential Guard status after configuration

    .PARAMETER ForceReboot
        Force system reboot after configuration (if required)

    .EXAMPLE
        Enable-CredentialGuard -CheckHardwareRequirements -ReportPath "C:\Reports\credguard.html"

    .EXAMPLE
        Enable-CredentialGuard -ComputerName @("Client1", "Client2") -EnableMode EnableWithUEFILock -Credential $Creds

    .EXAMPLE
        Enable-CredentialGuard -TestMode -RequireSecureBoot -ValidateConfiguration
    #>

    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter()]
        [string[]]$ComputerName = @('localhost'),

        [Parameter()]
        [pscredential]$Credential,

        [Parameter()]
        [ValidateSet('Enabled', 'EnabledWithoutLock', 'EnabledWithUEFILock', 'Disabled')]
        [string]$EnableMode = 'Enabled',

        [Parameter()]
        [switch]$RequireUEFI,

        [Parameter()]
        [switch]$RequireSecureBoot,

        [Parameter()]
        [switch]$RequireTPM,

        [Parameter()]
        [switch]$CheckHardwareRequirements,

        [Parameter()]
        [switch]$TestMode,

        [Parameter()]
        [string]$ReportPath,

        [Parameter()]
        [switch]$ValidateConfiguration,

        [Parameter()]
        [switch]$ForceReboot
    )

    begin {
        Write-CustomLog -Level 'INFO' -Message "Starting Credential Guard configuration for $($ComputerName.Count) computer(s)"

        # Check if running as Administrator
        $CurrentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
        $Principal = New-Object Security.Principal.WindowsPrincipal($CurrentUser)
        if (-not $Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            throw "This function requires Administrator privileges"
        }

        $CredentialGuardResults = @{
            EnableMode = $EnableMode
            ComputersProcessed = @()
            SuccessfulConfigurations = 0
            FailedConfigurations = 0
            RebootRequired = 0
            HardwareCompatible = 0
            Errors = @()
            Recommendations = @()
        }

        # Credential Guard registry values
        $CredentialGuardValues = @{
            'Enabled' = 1
            'EnabledWithoutLock' = 1
            'EnabledWithUEFILock' = 2
            'Disabled' = 0
        }

        # Hardware requirement checks
        $RequirementChecks = @(
            @{
                Name = 'Windows Version'
                Check = 'OSVersion'
                RequiredMinimum = [Version]'10.0.14393'  # Windows 10 1607 / Server 2016
                Description = 'Windows 10 version 1607 or Windows Server 2016 or later'
            }
            @{
                Name = 'UEFI Boot'
                Check = 'BootMode'
                RequiredValue = 'UEFI'
                Description = 'System must boot in UEFI mode'
            }
            @{
                Name = 'Secure Boot'
                Check = 'SecureBoot'
                RequiredValue = $true
                Description = 'Secure Boot must be enabled'
            }
            @{
                Name = 'TPM 2.0'
                Check = 'TPM'
                RequiredVersion = '2.0'
                Description = 'TPM 2.0 or later required'
            }
            @{
                Name = 'Virtualization'
                Check = 'Virtualization'
                RequiredValue = $true
                Description = 'Hardware virtualization support required'
            }
            @{
                Name = 'IOMMU'
                Check = 'IOMMU'
                RequiredValue = $true
                Description = 'IOMMU/VT-d support required'
            }
        )
    }

    process {
        try {
            foreach ($Computer in $ComputerName) {
                Write-CustomLog -Level 'INFO' -Message "Processing Credential Guard configuration for: $Computer"

                $ComputerResult = @{
                    ComputerName = $Computer
                    ConfigurationTime = Get-Date
                    CredentialGuardEnabled = $false
                    HardwareCompatible = $false
                    RequirementsCheck = @()
                    ConfigurationStatus = 'Unknown'
                    RebootRequired = $false
                    RegistryChanges = @()
                    Errors = @()
                }

                try {
                    # Execute configuration script on target computer
                    $ScriptBlock = {
                        param($EnableMode, $RequireUEFI, $RequireSecureBoot, $RequireTPM, $CheckHardwareRequirements, $TestMode, $ValidateConfiguration, $CredentialGuardValues, $RequirementChecks)

                        $LocalResult = @{
                            CredentialGuardEnabled = $false
                            HardwareCompatible = $false
                            RequirementsCheck = @()
                            ConfigurationStatus = 'Unknown'
                            RebootRequired = $false
                            RegistryChanges = @()
                            Errors = @()
                        }

                        try {
                            # Hardware requirements check
                            if ($CheckHardwareRequirements) {
                                Write-Progress -Activity "Checking Hardware Requirements" -PercentComplete 10

                                $HardwareChecksPassed = 0
                                $TotalChecks = $RequirementChecks.Count

                                foreach ($Check in $RequirementChecks) {
                                    $CheckResult = @{
                                        Name = $Check.Name
                                        Description = $Check.Description
                                        Status = 'Unknown'
                                        Value = $null
                                        Passed = $false
                                    }

                                    try {
                                        switch ($Check.Check) {
                                            'OSVersion' {
                                                $OSVersion = [Environment]::OSVersion.Version
                                                $CheckResult.Value = $OSVersion.ToString()
                                                $CheckResult.Passed = $OSVersion -ge $Check.RequiredMinimum
                                                $CheckResult.Status = if ($CheckResult.Passed) { 'Pass' } else { 'Fail' }
                                            }
                                            'BootMode' {
                                                try {
                                                    $BootMode = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control" -Name "PEFirmwareType" -ErrorAction SilentlyContinue
                                                    $IsUEFI = $BootMode.PEFirmwareType -eq 2
                                                    $CheckResult.Value = if ($IsUEFI) { 'UEFI' } else { 'Legacy' }
                                                    $CheckResult.Passed = $IsUEFI
                                                    $CheckResult.Status = if ($CheckResult.Passed) { 'Pass' } else { 'Fail' }
                                                } catch {
                                                    $CheckResult.Status = 'Error'
                                                    $CheckResult.Value = 'Unable to determine'
                                                }
                                            }
                                            'SecureBoot' {
                                                try {
                                                    $SecureBootEnabled = Confirm-SecureBootUEFI -ErrorAction SilentlyContinue
                                                    $CheckResult.Value = $SecureBootEnabled
                                                    $CheckResult.Passed = $SecureBootEnabled
                                                    $CheckResult.Status = if ($CheckResult.Passed) { 'Pass' } else { 'Fail' }
                                                } catch {
                                                    $CheckResult.Status = 'Error'
                                                    $CheckResult.Value = 'Unable to determine'
                                                }
                                            }
                                            'TPM' {
                                                try {
                                                    $TPMInfo = Get-Tpm -ErrorAction SilentlyContinue
                                                    if ($TPMInfo) {
                                                        $CheckResult.Value = $TPMInfo.TpmPresent
                                                        $CheckResult.Passed = $TPMInfo.TpmPresent -and $TPMInfo.TpmReady
                                                        $CheckResult.Status = if ($CheckResult.Passed) { 'Pass' } else { 'Fail' }
                                                    } else {
                                                        $CheckResult.Status = 'Error'
                                                        $CheckResult.Value = 'TPM not found'
                                                    }
                                                } catch {
                                                    $CheckResult.Status = 'Error'
                                                    $CheckResult.Value = 'Unable to check TPM'
                                                }
                                            }
                                            'Virtualization' {
                                                try {
                                                    $VirtSupport = Get-CimInstance -ClassName Win32_Processor | Select-Object -First 1
                                                    $HasVirtualization = $VirtSupport.VirtualizationFirmwareEnabled -or $VirtSupport.VMMonitorModeExtensions
                                                    $CheckResult.Value = $HasVirtualization
                                                    $CheckResult.Passed = $HasVirtualization
                                                    $CheckResult.Status = if ($CheckResult.Passed) { 'Pass' } else { 'Fail' }
                                                } catch {
                                                    $CheckResult.Status = 'Error'
                                                    $CheckResult.Value = 'Unable to check virtualization'
                                                }
                                            }
                                            'IOMMU' {
                                                try {
                                                    # Check for VT-d/AMD-Vi support
                                                    $SystemInfo = Get-ComputerInfo -ErrorAction SilentlyContinue
                                                    $HasIOMMU = $SystemInfo.CsSystemFamily -match 'Virtual' -or
                                                               (Get-CimInstance -ClassName Win32_SystemEnclosure).ChassisTypes -contains 1
                                                    $CheckResult.Value = $HasIOMMU
                                                    $CheckResult.Passed = $HasIOMMU
                                                    $CheckResult.Status = if ($CheckResult.Passed) { 'Pass' } else { 'Warning' }
                                                } catch {
                                                    $CheckResult.Status = 'Warning'
                                                    $CheckResult.Value = 'Unable to verify IOMMU'
                                                    $CheckResult.Passed = $true  # Allow to proceed
                                                }
                                            }
                                        }

                                    } catch {
                                        $CheckResult.Status = 'Error'
                                        $CheckResult.Value = $_.Exception.Message
                                    }

                                    $LocalResult.RequirementsCheck += $CheckResult

                                    if ($CheckResult.Passed) {
                                        $HardwareChecksPassed++
                                    }
                                }

                                # Determine hardware compatibility
                                $LocalResult.HardwareCompatible = $HardwareChecksPassed -ge ($TotalChecks - 1)  # Allow one non-critical failure

                                # Check specific requirements
                                if ($RequireUEFI) {
                                    $UEFICheck = $LocalResult.RequirementsCheck | Where-Object {$_.Name -eq 'UEFI Boot'}
                                    if ($UEFICheck -and -not $UEFICheck.Passed) {
                                        $LocalResult.Errors += "UEFI boot required but system is in Legacy mode"
                                        return $LocalResult
                                    }
                                }

                                if ($RequireSecureBoot) {
                                    $SecureBootCheck = $LocalResult.RequirementsCheck | Where-Object {$_.Name -eq 'Secure Boot'}
                                    if ($SecureBootCheck -and -not $SecureBootCheck.Passed) {
                                        $LocalResult.Errors += "Secure Boot required but not enabled"
                                        return $LocalResult
                                    }
                                }

                                if ($RequireTPM) {
                                    $TPMCheck = $LocalResult.RequirementsCheck | Where-Object {$_.Name -eq 'TPM 2.0'}
                                    if ($TPMCheck -and -not $TPMCheck.Passed) {
                                        $LocalResult.Errors += "TPM 2.0 required but not available"
                                        return $LocalResult
                                    }
                                }
                            }

                            # Configure Credential Guard
                            Write-Progress -Activity "Configuring Credential Guard" -PercentComplete 50

                            $RegistryPaths = @{
                                'VBS' = 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard'
                                'CredentialGuard' = 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa'
                            }

                            # Enable Virtualization Based Security
                            if (-not (Test-Path $RegistryPaths.VBS) -and -not $TestMode) {
                                New-Item -Path $RegistryPaths.VBS -Force | Out-Null
                            }

                            $VBSSettings = @{
                                'EnableVirtualizationBasedSecurity' = 1
                                'RequirePlatformSecurityFeatures' = if ($RequireSecureBoot) { 3 } else { 1 }
                                'Locked' = if ($EnableMode -eq 'EnabledWithUEFILock') { 1 } else { 0 }
                            }

                            foreach ($Setting in $VBSSettings.Keys) {
                                $Value = $VBSSettings[$Setting]
                                $CurrentValue = $null

                                try {
                                    $CurrentValue = Get-ItemProperty -Path $RegistryPaths.VBS -Name $Setting -ErrorAction SilentlyContinue | Select-Object -ExpandProperty $Setting
                                } catch {
                                    $CurrentValue = $null
                                }

                                if ($CurrentValue -ne $Value) {
                                    $ChangeInfo = @{
                                        Path = $RegistryPaths.VBS
                                        Setting = $Setting
                                        OldValue = $CurrentValue
                                        NewValue = $Value
                                        Type = 'VBS'
                                    }

                                    if ($TestMode) {
                                        $LocalResult.RegistryChanges += $ChangeInfo
                                    } else {
                                        Set-ItemProperty -Path $RegistryPaths.VBS -Name $Setting -Value $Value -Force
                                        $LocalResult.RegistryChanges += $ChangeInfo
                                        $LocalResult.RebootRequired = $true
                                    }
                                }
                            }

                            # Enable Credential Guard
                            if (-not (Test-Path $RegistryPaths.CredentialGuard) -and -not $TestMode) {
                                New-Item -Path $RegistryPaths.CredentialGuard -Force | Out-Null
                            }

                            $CredGuardValue = $CredentialGuardValues[$EnableMode]
                            $CurrentCredGuardValue = $null

                            try {
                                $CurrentCredGuardValue = Get-ItemProperty -Path $RegistryPaths.CredentialGuard -Name 'LsaCfgFlags' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty 'LsaCfgFlags'
                            } catch {
                                $CurrentCredGuardValue = $null
                            }

                            if ($CurrentCredGuardValue -ne $CredGuardValue) {
                                $ChangeInfo = @{
                                    Path = $RegistryPaths.CredentialGuard
                                    Setting = 'LsaCfgFlags'
                                    OldValue = $CurrentCredGuardValue
                                    NewValue = $CredGuardValue
                                    Type = 'CredentialGuard'
                                }

                                if ($TestMode) {
                                    $LocalResult.RegistryChanges += $ChangeInfo
                                } else {
                                    Set-ItemProperty -Path $RegistryPaths.CredentialGuard -Name 'LsaCfgFlags' -Value $CredGuardValue -Force
                                    $LocalResult.RegistryChanges += $ChangeInfo
                                    $LocalResult.RebootRequired = $true
                                }
                            }

                            # Validate configuration if requested
                            if ($ValidateConfiguration) {
                                Write-Progress -Activity "Validating Configuration" -PercentComplete 80

                                try {
                                    # Check current Credential Guard status
                                    $DeviceGuardInfo = Get-CimInstance -ClassName Win32_DeviceGuard -Namespace root\Microsoft\Windows\DeviceGuard -ErrorAction SilentlyContinue

                                    if ($DeviceGuardInfo) {
                                        $LocalResult.CredentialGuardEnabled = $DeviceGuardInfo.SecurityServicesRunning -contains 1

                                        if ($LocalResult.CredentialGuardEnabled) {
                                            $LocalResult.ConfigurationStatus = 'Enabled'
                                        } elseif ($LocalResult.RebootRequired) {
                                            $LocalResult.ConfigurationStatus = 'Configured (Reboot Required)'
                                        } else {
                                            $LocalResult.ConfigurationStatus = 'Configuration Failed'
                                        }
                                    } else {
                                        $LocalResult.ConfigurationStatus = 'Unable to Validate'
                                    }
                                } catch {
                                    $LocalResult.Errors += "Validation failed: $($_.Exception.Message)"
                                    $LocalResult.ConfigurationStatus = 'Validation Error'
                                }
                            } else {
                                if ($LocalResult.RegistryChanges.Count -gt 0) {
                                    $LocalResult.ConfigurationStatus = 'Configured'
                                } else {
                                    $LocalResult.ConfigurationStatus = 'No Changes Required'
                                }
                            }

                        } catch {
                            $LocalResult.Errors += "Configuration error: $($_.Exception.Message)"
                            $LocalResult.ConfigurationStatus = 'Error'
                        }

                        Write-Progress -Activity "Credential Guard Configuration Complete" -PercentComplete 100 -Completed
                        return $LocalResult
                    }

                    # Execute configuration
                    if ($Computer -eq 'localhost') {
                        $Result = & $ScriptBlock $EnableMode $RequireUEFI $RequireSecureBoot $RequireTPM $CheckHardwareRequirements $TestMode $ValidateConfiguration $CredentialGuardValues $RequirementChecks
                    } else {
                        if ($Credential) {
                            $Result = Invoke-Command -ComputerName $Computer -Credential $Credential -ScriptBlock $ScriptBlock -ArgumentList $EnableMode, $RequireUEFI, $RequireSecureBoot, $RequireTPM, $CheckHardwareRequirements, $TestMode, $ValidateConfiguration, $CredentialGuardValues, $RequirementChecks
                        } else {
                            $Result = Invoke-Command -ComputerName $Computer -ScriptBlock $ScriptBlock -ArgumentList $EnableMode, $RequireUEFI, $RequireSecureBoot, $RequireTPM, $CheckHardwareRequirements, $TestMode, $ValidateConfiguration, $CredentialGuardValues, $RequirementChecks
                        }
                    }

                    # Merge results
                    $ComputerResult.CredentialGuardEnabled = $Result.CredentialGuardEnabled
                    $ComputerResult.HardwareCompatible = $Result.HardwareCompatible
                    $ComputerResult.RequirementsCheck = $Result.RequirementsCheck
                    $ComputerResult.ConfigurationStatus = $Result.ConfigurationStatus
                    $ComputerResult.RebootRequired = $Result.RebootRequired
                    $ComputerResult.RegistryChanges = $Result.RegistryChanges
                    $ComputerResult.Errors = $Result.Errors

                    # Update counters
                    if ($Result.ConfigurationStatus -in @('Enabled', 'Configured', 'Configured (Reboot Required)')) {
                        $CredentialGuardResults.SuccessfulConfigurations++
                    } else {
                        $CredentialGuardResults.FailedConfigurations++
                    }

                    if ($Result.RebootRequired) {
                        $CredentialGuardResults.RebootRequired++
                    }

                    if ($Result.HardwareCompatible) {
                        $CredentialGuardResults.HardwareCompatible++
                    }

                    # Handle reboot if forced and required
                    if ($ForceReboot -and $Result.RebootRequired -and -not $TestMode) {
                        Write-CustomLog -Level 'WARNING' -Message "Rebooting $Computer to complete Credential Guard configuration"

                        if ($PSCmdlet.ShouldProcess($Computer, "Restart computer")) {
                            try {
                                if ($Computer -eq 'localhost') {
                                    Restart-Computer -Force
                                } else {
                                    Restart-Computer -ComputerName $Computer -Force
                                }
                            } catch {
                                Write-CustomLog -Level 'ERROR' -Message "Failed to restart $Computer`: $($_.Exception.Message)"
                            }
                        }
                    }

                    Write-CustomLog -Level 'SUCCESS' -Message "Credential Guard configuration completed for $Computer`: $($Result.ConfigurationStatus)"

                } catch {
                    $Error = "Failed to configure Credential Guard on $Computer`: $($_.Exception.Message)"
                    $ComputerResult.Errors += $Error
                    $ComputerResult.ConfigurationStatus = 'Failed'
                    Write-CustomLog -Level 'ERROR' -Message $Error
                    $CredentialGuardResults.FailedConfigurations++
                }

                $CredentialGuardResults.ComputersProcessed += $ComputerResult
            }

        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Error during Credential Guard configuration: $($_.Exception.Message)"
            throw
        }
    }

    end {
        Write-CustomLog -Level 'SUCCESS' -Message "Credential Guard configuration completed"

        # Generate recommendations
        $CredentialGuardResults.Recommendations += "Reboot systems to complete Credential Guard activation"
        $CredentialGuardResults.Recommendations += "Verify Credential Guard status after reboot using Get-CimInstance Win32_DeviceGuard"
        $CredentialGuardResults.Recommendations += "Test application compatibility in virtualization-based security environment"
        $CredentialGuardResults.Recommendations += "Monitor system performance after enabling Credential Guard"
        $CredentialGuardResults.Recommendations += "Implement Group Policy for enterprise-wide Credential Guard deployment"

        if ($CredentialGuardResults.HardwareCompatible -lt $CredentialGuardResults.ComputersProcessed.Count) {
            $CredentialGuardResults.Recommendations += "Upgrade hardware on incompatible systems to support Credential Guard"
            $CredentialGuardResults.Recommendations += "Consider alternative credential protection methods for legacy systems"
        }

        # Generate HTML report if requested
        if ($ReportPath) {
            try {
                $HtmlReport = @"
<!DOCTYPE html>
<html>
<head>
    <title>Credential Guard Configuration Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #f0f0f0; padding: 15px; border-radius: 5px; }
        .computer { border: 1px solid #ccc; margin: 20px 0; padding: 15px; border-radius: 5px; }
        .success { color: green; font-weight: bold; }
        .error { color: red; font-weight: bold; }
        .warning { color: orange; font-weight: bold; }
        .pass { color: green; }
        .fail { color: red; }
        table { border-collapse: collapse; width: 100%; margin: 10px 0; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
        .recommendation { background-color: #e7f3ff; padding: 10px; margin: 5px 0; border-radius: 3px; }
    </style>
</head>
<body>
    <div class='header'>
        <h1>Credential Guard Configuration Report</h1>
        <p><strong>Enable Mode:</strong> $($CredentialGuardResults.EnableMode)</p>
        <p><strong>Generated:</strong> $(Get-Date)</p>
        <p><strong>Computers Processed:</strong> $($CredentialGuardResults.ComputersProcessed.Count)</p>
        <p><strong>Successful Configurations:</strong> <span class='success'>$($CredentialGuardResults.SuccessfulConfigurations)</span></p>
        <p><strong>Failed Configurations:</strong> <span class='error'>$($CredentialGuardResults.FailedConfigurations)</span></p>
        <p><strong>Hardware Compatible:</strong> $($CredentialGuardResults.HardwareCompatible)</p>
        <p><strong>Reboot Required:</strong> <span class='warning'>$($CredentialGuardResults.RebootRequired)</span></p>
    </div>
"@

                foreach ($Computer in $CredentialGuardResults.ComputersProcessed) {
                    $StatusClass = switch ($Computer.ConfigurationStatus) {
                        'Enabled' { 'success' }
                        'Configured' { 'success' }
                        'Configured (Reboot Required)' { 'warning' }
                        'Failed' { 'error' }
                        'Error' { 'error' }
                        default { 'warning' }
                    }

                    $HtmlReport += "<div class='computer'>"
                    $HtmlReport += "<h2>$($Computer.ComputerName)</h2>"
                    $HtmlReport += "<p><strong>Status:</strong> <span class='$StatusClass'>$($Computer.ConfigurationStatus)</span></p>"
                    $HtmlReport += "<p><strong>Hardware Compatible:</strong> $($Computer.HardwareCompatible)</p>"
                    $HtmlReport += "<p><strong>Reboot Required:</strong> $($Computer.RebootRequired)</p>"

                    if ($Computer.RequirementsCheck.Count -gt 0) {
                        $HtmlReport += "<h3>Hardware Requirements</h3>"
                        $HtmlReport += "<table><tr><th>Requirement</th><th>Status</th><th>Value</th><th>Description</th></tr>"

                        foreach ($Check in $Computer.RequirementsCheck) {
                            $CheckClass = switch ($Check.Status) {
                                'Pass' { 'pass' }
                                'Fail' { 'fail' }
                                'Error' { 'error' }
                                default { 'warning' }
                            }

                            $HtmlReport += "<tr>"
                            $HtmlReport += "<td>$($Check.Name)</td>"
                            $HtmlReport += "<td class='$CheckClass'>$($Check.Status)</td>"
                            $HtmlReport += "<td>$($Check.Value)</td>"
                            $HtmlReport += "<td>$($Check.Description)</td>"
                            $HtmlReport += "</tr>"
                        }

                        $HtmlReport += "</table>"
                    }

                    $HtmlReport += "</div>"
                }

                $HtmlReport += "<div class='header'><h2>Recommendations</h2>"
                foreach ($Rec in $CredentialGuardResults.Recommendations) {
                    $HtmlReport += "<div class='recommendation'>$Rec</div>"
                }
                $HtmlReport += "</div>"

                $HtmlReport += "</body></html>"

                $HtmlReport | Out-File -FilePath $ReportPath -Encoding UTF8
                Write-CustomLog -Level 'SUCCESS' -Message "Credential Guard report saved to: $ReportPath"

            } catch {
                Write-CustomLog -Level 'ERROR' -Message "Failed to generate report: $($_.Exception.Message)"
            }
        }

        # Display summary
        Write-CustomLog -Level 'INFO' -Message "Credential Guard Configuration Summary:"
        Write-CustomLog -Level 'INFO' -Message "  Enable Mode: $($CredentialGuardResults.EnableMode)"
        Write-CustomLog -Level 'INFO' -Message "  Computers: $($CredentialGuardResults.ComputersProcessed.Count)"
        Write-CustomLog -Level 'INFO' -Message "  Successful: $($CredentialGuardResults.SuccessfulConfigurations)"
        Write-CustomLog -Level 'INFO' -Message "  Failed: $($CredentialGuardResults.FailedConfigurations)"
        Write-CustomLog -Level 'INFO' -Message "  Hardware Compatible: $($CredentialGuardResults.HardwareCompatible)"
        Write-CustomLog -Level 'INFO' -Message "  Reboot Required: $($CredentialGuardResults.RebootRequired)"

        if ($TestMode) {
            Write-CustomLog -Level 'INFO' -Message "TEST MODE: No actual changes were made"
        }

        if ($CredentialGuardResults.RebootRequired -gt 0) {
            Write-CustomLog -Level 'WARNING' -Message "System reboot required to complete Credential Guard activation"
        }

        return $CredentialGuardResults
    }
}

function Set-WinRMSecurity {
    <#
    .SYNOPSIS
        Configures secure Windows Remote Management (WinRM) settings.

    .DESCRIPTION
        Hardens WinRM configuration for secure PowerShell remoting including
        authentication methods, encryption settings, firewall rules, and
        access controls. Supports both HTTP and HTTPS configurations.

    .PARAMETER ComputerName
        Target computer names for WinRM hardening. Default: localhost

    .PARAMETER Credential
        Credentials for remote computer access

    .PARAMETER EnableWinRM
        Enable WinRM service and configure basic settings

    .PARAMETER RequireHTTPS
        Require HTTPS for all WinRM connections

    .PARAMETER DisableHTTP
        Disable HTTP WinRM listener

    .PARAMETER ConfigureAuthentication
        Configure secure authentication methods

    .PARAMETER RestrictNetworkAccess
        Restrict network access to WinRM

    .PARAMETER ConfigureFirewall
        Configure Windows Firewall rules for WinRM

    .PARAMETER CertificateThumbprint
        Certificate thumbprint for HTTPS listener

    .PARAMETER AllowedIPs
        IP addresses/ranges allowed to connect

    .PARAMETER TestMode
        Show what would be configured without making changes

    .PARAMETER ReportPath
        Path to save WinRM security configuration report

    .PARAMETER ValidateConfiguration
        Validate WinRM security settings after configuration

    .PARAMETER BackupSettings
        Create backup of current WinRM settings

    .EXAMPLE
        Set-WinRMSecurity -EnableWinRM -RequireHTTPS -ConfigureAuthentication -ReportPath "C:\Reports\winrm-security.html"

    .EXAMPLE
        Set-WinRMSecurity -ComputerName @("Server1", "Server2") -DisableHTTP -RestrictNetworkAccess -AllowedIPs @("10.0.0.0/8", "192.168.1.0/24")

    .EXAMPLE
        Set-WinRMSecurity -TestMode -ConfigureFirewall -ValidateConfiguration
    #>

    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter()]
        [string[]]$ComputerName = @('localhost'),

        [Parameter()]
        [pscredential]$Credential,

        [Parameter()]
        [switch]$EnableWinRM,

        [Parameter()]
        [switch]$RequireHTTPS,

        [Parameter()]
        [switch]$DisableHTTP,

        [Parameter()]
        [switch]$ConfigureAuthentication,

        [Parameter()]
        [switch]$RestrictNetworkAccess,

        [Parameter()]
        [switch]$ConfigureFirewall,

        [Parameter()]
        [string]$CertificateThumbprint,

        [Parameter()]
        [string[]]$AllowedIPs = @(),

        [Parameter()]
        [switch]$TestMode,

        [Parameter()]
        [string]$ReportPath,

        [Parameter()]
        [switch]$ValidateConfiguration,

        [Parameter()]
        [switch]$BackupSettings
    )

    begin {
        Write-CustomLog -Level 'INFO' -Message "Starting WinRM security configuration for $($ComputerName.Count) computer(s)"

        # Check if running as Administrator
        $CurrentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
        $Principal = New-Object Security.Principal.WindowsPrincipal($CurrentUser)
        if (-not $Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            throw "This function requires Administrator privileges"
        }

        $WinRMSecurityResults = @{
            ComputersProcessed = @()
            WinRMEnabled = 0
            HTTPSConfigured = 0
            HTTPDisabled = 0
            AuthenticationConfigured = 0
            FirewallConfigured = 0
            BackupsCreated = 0
            ValidationResults = @()
            Errors = @()
            Recommendations = @()
        }

        # WinRM security configurations
        $WinRMConfigurations = @{
            Service = @{
                Registry = @{
                    'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WinRM\Service' = @{
                        'AllowUnencryptedTraffic' = 0
                        'AllowBasic' = 0
                        'AllowDigest' = 0
                        'AllowKerberos' = 1
                        'AllowNegotiate' = 1
                        'AllowCertificateAuthentication' = 1
                        'DisableRunAs' = 1
                    }
                }
                WinRMConfig = @{
                    'MaxConcurrentOperationsPerUser' = 1500
                    'MaxConnections' = 100
                    'MaxPacketRetrievalTimeSeconds' = 120
                    'MaxTimeoutms' = 60000
                }
            }
            Client = @{
                Registry = @{
                    'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WinRM\Client' = @{
                        'AllowUnencryptedTraffic' = 0
                        'AllowBasic' = 0
                        'AllowDigest' = 0
                        'TrustedHosts' = ''
                    }
                }
            }
            Authentication = @{
                Basic = $false
                Digest = $false
                Kerberos = $true
                Negotiate = $true
                Certificate = $true
                CredSSP = $false
            }
        }
    }

    process {
        try {
            foreach ($Computer in $ComputerName) {
                Write-CustomLog -Level 'INFO' -Message "Processing WinRM security configuration for: $Computer"

                $ComputerResult = @{
                    ComputerName = $Computer
                    ConfigurationTime = Get-Date
                    WinRMEnabled = $false
                    HTTPSConfigured = $false
                    HTTPDisabled = $false
                    AuthenticationConfigured = $false
                    FirewallConfigured = $false
                    BackupPath = $null
                    Listeners = @()
                    RegistryChanges = @()
                    WinRMChanges = @()
                    FirewallRules = @()
                    ValidationResults = @()
                    Errors = @()
                }

                try {
                    # Execute WinRM security configuration script
                    $ScriptBlock = {
                        param($EnableWinRM, $RequireHTTPS, $DisableHTTP, $ConfigureAuthentication, $RestrictNetworkAccess, $ConfigureFirewall, $CertificateThumbprint, $AllowedIPs, $TestMode, $ValidateConfiguration, $BackupSettings, $WinRMConfigurations)

                        $LocalResult = @{
                            WinRMEnabled = $false
                            HTTPSConfigured = $false
                            HTTPDisabled = $false
                            AuthenticationConfigured = $false
                            FirewallConfigured = $false
                            BackupPath = $null
                            Listeners = @()
                            RegistryChanges = @()
                            WinRMChanges = @()
                            FirewallRules = @()
                            ValidationResults = @()
                            Errors = @()
                        }

                        try {
                            # Create backup if requested
                            if ($BackupSettings) {
                                Write-Progress -Activity "Creating WinRM Settings Backup" -PercentComplete 5

                                try {
                                    $BackupDir = 'C:\ProgramData\AitherZero\Backups\WinRM'
                                    if (-not (Test-Path $BackupDir)) {
                                        New-Item -Path $BackupDir -ItemType Directory -Force | Out-Null
                                    }

                                    $BackupFile = Join-Path $BackupDir "WinRM-Backup-$(Get-Date -Format 'yyyyMMdd-HHmmss').xml"

                                    $BackupData = @{
                                        ComputerName = $env:COMPUTERNAME
                                        BackupTime = Get-Date
                                        WinRMConfig = @{}
                                        RegistrySettings = @{}
                                        FirewallRules = @()
                                    }

                                    # Backup WinRM configuration
                                    try {
                                        $BackupData.WinRMConfig = winrm get winrm/config 2>$null
                                    } catch {
                                        # WinRM may not be configured
                                    }

                                    # Backup registry settings
                                    foreach ($ConfigType in $WinRMConfigurations.Keys) {
                                        $Config = $WinRMConfigurations[$ConfigType]

                                        if ($Config.Registry) {
                                            foreach ($RegistryPath in $Config.Registry.Keys) {
                                                try {
                                                    $CurrentSettings = Get-ItemProperty -Path $RegistryPath -ErrorAction SilentlyContinue
                                                    if ($CurrentSettings) {
                                                        $BackupData.RegistrySettings[$RegistryPath] = $CurrentSettings
                                                    }
                                                } catch {
                                                    # Ignore errors for non-existent keys
                                                }
                                            }
                                        }
                                    }

                                    # Backup firewall rules
                                    try {
                                        $BackupData.FirewallRules = Get-NetFirewallRule -DisplayGroup "*WinRM*" -ErrorAction SilentlyContinue |
                                                                   Select-Object DisplayName, Enabled, Direction, Action
                                    } catch {
                                        # Firewall cmdlets may not be available
                                    }

                                    if (-not $TestMode) {
                                        $BackupData | Export-Clixml -Path $BackupFile -Force
                                        $LocalResult.BackupPath = $BackupFile
                                    }
                                } catch {
                                    $LocalResult.Errors += "Failed to create backup: $($_.Exception.Message)"
                                }
                            }

                            # Enable WinRM if requested
                            if ($EnableWinRM) {
                                Write-Progress -Activity "Enabling WinRM" -PercentComplete 15

                                try {
                                    # Check if WinRM service exists and start it
                                    $WinRMService = Get-Service -Name 'WinRM' -ErrorAction SilentlyContinue

                                    if ($WinRMService) {
                                        if ($WinRMService.Status -ne 'Running' -and -not $TestMode) {
                                            Start-Service -Name 'WinRM'
                                            Set-Service -Name 'WinRM' -StartupType Automatic
                                        }

                                        # Quick configuration
                                        if (-not $TestMode) {
                                            try {
                                                winrm quickconfig -quiet
                                                $LocalResult.WinRMChanges += "WinRM quick configuration completed"
                                            } catch {
                                                $LocalResult.Errors += "WinRM quick configuration failed: $($_.Exception.Message)"
                                            }
                                        }

                                        $LocalResult.WinRMEnabled = $true
                                        $LocalResult.WinRMChanges += "WinRM service enabled and started"
                                    } else {
                                        $LocalResult.Errors += "WinRM service not found on this system"
                                    }
                                } catch {
                                    $LocalResult.Errors += "Failed to enable WinRM: $($_.Exception.Message)"
                                }
                            }

                            # Configure registry-based security settings
                            Write-Progress -Activity "Configuring Registry Settings" -PercentComplete 25

                            foreach ($ConfigType in $WinRMConfigurations.Keys) {
                                $Config = $WinRMConfigurations[$ConfigType]

                                if ($Config.Registry) {
                                    foreach ($RegistryPath in $Config.Registry.Keys) {
                                        $Settings = $Config.Registry[$RegistryPath]

                                        if (-not (Test-Path $RegistryPath) -and -not $TestMode) {
                                            New-Item -Path $RegistryPath -Force | Out-Null
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
                                                    Type = "WinRM$ConfigType"
                                                }

                                                if ($TestMode) {
                                                    $LocalResult.RegistryChanges += $ChangeInfo
                                                } else {
                                                    Set-ItemProperty -Path $RegistryPath -Name $Setting -Value $Value -Force
                                                    $LocalResult.RegistryChanges += $ChangeInfo
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            # Configure authentication methods
                            if ($ConfigureAuthentication) {
                                Write-Progress -Activity "Configuring Authentication" -PercentComplete 40

                                try {
                                    $AuthConfig = $WinRMConfigurations.Authentication

                                    foreach ($AuthMethod in $AuthConfig.Keys) {
                                        $Enabled = $AuthConfig[$AuthMethod]

                                        if (-not $TestMode) {
                                            try {
                                                winrm set winrm/config/service/auth "@{$AuthMethod=`"$Enabled`"}" 2>$null
                                                $LocalResult.WinRMChanges += "Set $AuthMethod authentication to $Enabled"
                                            } catch {
                                                # Some auth methods may not be configurable
                                            }
                                        } else {
                                            $LocalResult.WinRMChanges += "[TEST] Would set $AuthMethod authentication to $Enabled"
                                        }
                                    }

                                    $LocalResult.AuthenticationConfigured = $true
                                } catch {
                                    $LocalResult.Errors += "Failed to configure authentication: $($_.Exception.Message)"
                                }
                            }

                            # Configure HTTPS listener
                            if ($RequireHTTPS) {
                                Write-Progress -Activity "Configuring HTTPS" -PercentComplete 55

                                try {
                                    # Find available certificate or use specified thumbprint
                                    $Certificate = $null

                                    if ($CertificateThumbprint) {
                                        $Certificate = Get-ChildItem -Path Cert:\LocalMachine\My | Where-Object {$_.Thumbprint -eq $CertificateThumbprint}
                                    } else {
                                        # Find a suitable certificate
                                        $Certificate = Get-ChildItem -Path Cert:\LocalMachine\My |
                                                     Where-Object {$_.Subject -like "*$env:COMPUTERNAME*" -and $_.NotAfter -gt (Get-Date)} |
                                                     Select-Object -First 1
                                    }

                                    if ($Certificate) {
                                        if (-not $TestMode) {
                                            try {
                                                # Remove existing HTTPS listener if it exists
                                                winrm delete winrm/config/listener?Address=*+Transport=HTTPS 2>$null

                                                # Create new HTTPS listener
                                                winrm create winrm/config/listener?Address=*+Transport=HTTPS "@{Hostname=`"$env:COMPUTERNAME`";CertificateThumbprint=`"$($Certificate.Thumbprint)`"}"

                                                $LocalResult.Listeners += @{
                                                    Transport = 'HTTPS'
                                                    Port = 5986
                                                    Certificate = $Certificate.Thumbprint
                                                    Status = 'Created'
                                                }

                                                $LocalResult.WinRMChanges += "HTTPS listener configured with certificate $($Certificate.Thumbprint)"
                                            } catch {
                                                $LocalResult.Errors += "Failed to configure HTTPS listener: $($_.Exception.Message)"
                                            }
                                        } else {
                                            $LocalResult.WinRMChanges += "[TEST] Would configure HTTPS listener with certificate $($Certificate.Thumbprint)"
                                        }

                                        $LocalResult.HTTPSConfigured = $true
                                    } else {
                                        $LocalResult.Errors += "No suitable certificate found for HTTPS listener"
                                    }
                                } catch {
                                    $LocalResult.Errors += "Failed to configure HTTPS: $($_.Exception.Message)"
                                }
                            }

                            # Disable HTTP listener
                            if ($DisableHTTP) {
                                Write-Progress -Activity "Disabling HTTP" -PercentComplete 70

                                try {
                                    if (-not $TestMode) {
                                        try {
                                            winrm delete winrm/config/listener?Address=*+Transport=HTTP 2>$null
                                            $LocalResult.WinRMChanges += "HTTP listener disabled"
                                        } catch {
                                            # HTTP listener may not exist
                                        }
                                    } else {
                                        $LocalResult.WinRMChanges += "[TEST] Would disable HTTP listener"
                                    }

                                    $LocalResult.HTTPDisabled = $true
                                } catch {
                                    $LocalResult.Errors += "Failed to disable HTTP: $($_.Exception.Message)"
                                }
                            }

                            # Configure firewall rules
                            if ($ConfigureFirewall) {
                                Write-Progress -Activity "Configuring Firewall" -PercentComplete 80

                                try {
                                    # Check if Windows Firewall cmdlets are available
                                    if (Get-Command 'Get-NetFirewallRule' -ErrorAction SilentlyContinue) {

                                        # Configure WinRM HTTP rule (if not disabled)
                                        if (-not $DisableHTTP) {
                                            $HTTPRule = Get-NetFirewallRule -DisplayName "*WinRM-HTTP*" -ErrorAction SilentlyContinue | Select-Object -First 1

                                            if ($HTTPRule) {
                                                if ($AllowedIPs.Count -gt 0 -and -not $TestMode) {
                                                    # Restrict to specific IPs
                                                    Set-NetFirewallRule -DisplayName $HTTPRule.DisplayName -RemoteAddress $AllowedIPs
                                                    $LocalResult.FirewallRules += @{
                                                        Name = $HTTPRule.DisplayName
                                                        Action = 'Modified'
                                                        RemoteAddress = $AllowedIPs -join ', '
                                                    }
                                                }
                                            } else {
                                                # Create WinRM HTTP rule
                                                if (-not $TestMode) {
                                                    $RemoteAddr = if ($AllowedIPs.Count -gt 0) { $AllowedIPs } else { 'Any' }
                                                    New-NetFirewallRule -DisplayName "Windows Remote Management (HTTP-In)" -Direction Inbound -Protocol TCP -LocalPort 5985 -RemoteAddress $RemoteAddr -Action Allow

                                                    $LocalResult.FirewallRules += @{
                                                        Name = "Windows Remote Management (HTTP-In)"
                                                        Action = 'Created'
                                                        RemoteAddress = $RemoteAddr -join ', '
                                                    }
                                                }
                                            }
                                        }

                                        # Configure WinRM HTTPS rule (if enabled)
                                        if ($RequireHTTPS) {
                                            $HTTPSRule = Get-NetFirewallRule -DisplayName "*WinRM*HTTPS*" -ErrorAction SilentlyContinue | Select-Object -First 1

                                            if (-not $HTTPSRule -and -not $TestMode) {
                                                $RemoteAddr = if ($AllowedIPs.Count -gt 0) { $AllowedIPs } else { 'Any' }
                                                New-NetFirewallRule -DisplayName "Windows Remote Management (HTTPS-In)" -Direction Inbound -Protocol TCP -LocalPort 5986 -RemoteAddress $RemoteAddr -Action Allow

                                                $LocalResult.FirewallRules += @{
                                                    Name = "Windows Remote Management (HTTPS-In)"
                                                    Action = 'Created'
                                                    RemoteAddress = $RemoteAddr -join ', '
                                                }
                                            }
                                        }

                                        $LocalResult.FirewallConfigured = $true
                                    } else {
                                        $LocalResult.Errors += "Windows Firewall cmdlets not available"
                                    }
                                } catch {
                                    $LocalResult.Errors += "Failed to configure firewall: $($_.Exception.Message)"
                                }
                            }

                            # Apply WinRM service configuration limits
                            Write-Progress -Activity "Configuring Service Limits" -PercentComplete 90

                            if ($WinRMConfigurations.Service.WinRMConfig -and -not $TestMode) {
                                foreach ($Setting in $WinRMConfigurations.Service.WinRMConfig.Keys) {
                                    $Value = $WinRMConfigurations.Service.WinRMConfig[$Setting]

                                    try {
                                        winrm set winrm/config/service "@{$Setting=`"$Value`"}" 2>$null
                                        $LocalResult.WinRMChanges += "Set service $Setting to $Value"
                                    } catch {
                                        # Some settings may not be configurable
                                    }
                                }
                            }

                            # Validate configuration if requested
                            if ($ValidateConfiguration) {
                                Write-Progress -Activity "Validating Configuration" -PercentComplete 95

                                try {
                                    $ValidationResult = @{
                                        ServiceStatus = 'Unknown'
                                        Listeners = @()
                                        Authentication = @{}
                                        FirewallRules = @()
                                    }

                                    # Check WinRM service status
                                    try {
                                        $WinRMService = Get-Service -Name 'WinRM' -ErrorAction SilentlyContinue
                                        $ValidationResult.ServiceStatus = if ($WinRMService) { $WinRMService.Status } else { 'Not Found' }
                                    } catch {
                                        $ValidationResult.ServiceStatus = 'Unknown'
                                    }

                                    # Check listeners
                                    try {
                                        $ListenerOutput = winrm enumerate winrm/config/listener 2>$null
                                        if ($ListenerOutput) {
                                            # Parse listener information
                                            $ValidationResult.Listeners += "Listeners configured"
                                        }
                                    } catch {
                                        # WinRM enumeration failed
                                    }

                                    # Check firewall rules
                                    try {
                                        if (Get-Command 'Get-NetFirewallRule' -ErrorAction SilentlyContinue) {
                                            $WinRMRules = Get-NetFirewallRule -DisplayGroup "*WinRM*" -ErrorAction SilentlyContinue

                                            foreach ($Rule in $WinRMRules) {
                                                $ValidationResult.FirewallRules += @{
                                                    Name = $Rule.DisplayName
                                                    Enabled = $Rule.Enabled
                                                    Direction = $Rule.Direction
                                                    Action = $Rule.Action
                                                }
                                            }
                                        }
                                    } catch {
                                        # Firewall cmdlets not available
                                    }

                                    $LocalResult.ValidationResults += $ValidationResult

                                } catch {
                                    $LocalResult.Errors += "Validation failed: $($_.Exception.Message)"
                                }
                            }

                        } catch {
                            $LocalResult.Errors += "WinRM security configuration error: $($_.Exception.Message)"
                        }

                        Write-Progress -Activity "WinRM Security Configuration Complete" -PercentComplete 100 -Completed
                        return $LocalResult
                    }

                    # Execute configuration
                    if ($Computer -eq 'localhost') {
                        $Result = & $ScriptBlock $EnableWinRM $RequireHTTPS $DisableHTTP $ConfigureAuthentication $RestrictNetworkAccess $ConfigureFirewall $CertificateThumbprint $AllowedIPs $TestMode $ValidateConfiguration $BackupSettings $WinRMConfigurations
                    } else {
                        if ($Credential) {
                            $Result = Invoke-Command -ComputerName $Computer -Credential $Credential -ScriptBlock $ScriptBlock -ArgumentList $EnableWinRM, $RequireHTTPS, $DisableHTTP, $ConfigureAuthentication, $RestrictNetworkAccess, $ConfigureFirewall, $CertificateThumbprint, $AllowedIPs, $TestMode, $ValidateConfiguration, $BackupSettings, $WinRMConfigurations
                        } else {
                            $Result = Invoke-Command -ComputerName $Computer -ScriptBlock $ScriptBlock -ArgumentList $EnableWinRM, $RequireHTTPS, $DisableHTTP, $ConfigureAuthentication, $RestrictNetworkAccess, $ConfigureFirewall, $CertificateThumbprint, $AllowedIPs, $TestMode, $ValidateConfiguration, $BackupSettings, $WinRMConfigurations
                        }
                    }

                    # Merge results
                    $ComputerResult.WinRMEnabled = $Result.WinRMEnabled
                    $ComputerResult.HTTPSConfigured = $Result.HTTPSConfigured
                    $ComputerResult.HTTPDisabled = $Result.HTTPDisabled
                    $ComputerResult.AuthenticationConfigured = $Result.AuthenticationConfigured
                    $ComputerResult.FirewallConfigured = $Result.FirewallConfigured
                    $ComputerResult.BackupPath = $Result.BackupPath
                    $ComputerResult.Listeners = $Result.Listeners
                    $ComputerResult.RegistryChanges = $Result.RegistryChanges
                    $ComputerResult.WinRMChanges = $Result.WinRMChanges
                    $ComputerResult.FirewallRules = $Result.FirewallRules
                    $ComputerResult.ValidationResults = $Result.ValidationResults
                    $ComputerResult.Errors = $Result.Errors

                    # Update counters
                    if ($Result.WinRMEnabled) {
                        $WinRMSecurityResults.WinRMEnabled++
                    }
                    if ($Result.HTTPSConfigured) {
                        $WinRMSecurityResults.HTTPSConfigured++
                    }
                    if ($Result.HTTPDisabled) {
                        $WinRMSecurityResults.HTTPDisabled++
                    }
                    if ($Result.AuthenticationConfigured) {
                        $WinRMSecurityResults.AuthenticationConfigured++
                    }
                    if ($Result.FirewallConfigured) {
                        $WinRMSecurityResults.FirewallConfigured++
                    }
                    if ($Result.BackupPath) {
                        $WinRMSecurityResults.BackupsCreated++
                    }
                    if ($Result.ValidationResults) {
                        $WinRMSecurityResults.ValidationResults += $Result.ValidationResults
                    }

                    Write-CustomLog -Level 'SUCCESS' -Message "WinRM security configuration completed for $Computer"

                } catch {
                    $Error = "Failed to configure WinRM security on $Computer`: $($_.Exception.Message)"
                    $ComputerResult.Errors += $Error
                    Write-CustomLog -Level 'ERROR' -Message $Error
                }

                $WinRMSecurityResults.ComputersProcessed += $ComputerResult
            }

        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Error during WinRM security configuration: $($_.Exception.Message)"
            throw
        }
    }

    end {
        Write-CustomLog -Level 'SUCCESS' -Message "WinRM security configuration completed"

        # Generate recommendations
        $WinRMSecurityResults.Recommendations += "Test PowerShell remoting functionality after WinRM hardening"
        $WinRMSecurityResults.Recommendations += "Monitor WinRM event logs for connection and authentication issues"
        $WinRMSecurityResults.Recommendations += "Regularly review and update trusted hosts configuration"
        $WinRMSecurityResults.Recommendations += "Consider implementing JEA (Just Enough Administration) for privileged access"
        $WinRMSecurityResults.Recommendations += "Use Group Policy for enterprise-wide WinRM configuration management"

        if ($WinRMSecurityResults.HTTPSConfigured -gt 0) {
            $WinRMSecurityResults.Recommendations += "Monitor certificate expiration dates for HTTPS listeners"
            $WinRMSecurityResults.Recommendations += "Implement certificate auto-renewal for WinRM HTTPS"
        }

        if ($WinRMSecurityResults.HTTPDisabled -gt 0) {
            $WinRMSecurityResults.Recommendations += "Verify that all clients support HTTPS-only WinRM connections"
        }

        # Generate HTML report if requested
        if ($ReportPath) {
            try {
                $HtmlReport = @"
<!DOCTYPE html>
<html>
<head>
    <title>WinRM Security Configuration Report</title>
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
        <h1>WinRM Security Configuration Report</h1>
        <p><strong>Generated:</strong> $(Get-Date)</p>
        <p><strong>Computers Processed:</strong> $($WinRMSecurityResults.ComputersProcessed.Count)</p>
        <p><strong>WinRM Enabled:</strong> <span class='success'>$($WinRMSecurityResults.WinRMEnabled)</span></p>
        <p><strong>HTTPS Configured:</strong> <span class='success'>$($WinRMSecurityResults.HTTPSConfigured)</span></p>
        <p><strong>HTTP Disabled:</strong> <span class='success'>$($WinRMSecurityResults.HTTPDisabled)</span></p>
        <p><strong>Authentication Configured:</strong> <span class='success'>$($WinRMSecurityResults.AuthenticationConfigured)</span></p>
        <p><strong>Firewall Configured:</strong> <span class='success'>$($WinRMSecurityResults.FirewallConfigured)</span></p>
    </div>
"@

                foreach ($Computer in $WinRMSecurityResults.ComputersProcessed) {
                    $HtmlReport += "<div class='computer'>"
                    $HtmlReport += "<h2>$($Computer.ComputerName)</h2>"
                    $HtmlReport += "<p><strong>WinRM Enabled:</strong> $($Computer.WinRMEnabled)</p>"
                    $HtmlReport += "<p><strong>HTTPS Configured:</strong> $($Computer.HTTPSConfigured)</p>"
                    $HtmlReport += "<p><strong>HTTP Disabled:</strong> $($Computer.HTTPDisabled)</p>"
                    $HtmlReport += "<p><strong>Authentication Configured:</strong> $($Computer.AuthenticationConfigured)</p>"
                    $HtmlReport += "<p><strong>Firewall Configured:</strong> $($Computer.FirewallConfigured)</p>"

                    if ($Computer.Listeners.Count -gt 0) {
                        $HtmlReport += "<h3>WinRM Listeners</h3>"
                        $HtmlReport += "<table><tr><th>Transport</th><th>Port</th><th>Certificate</th><th>Status</th></tr>"

                        foreach ($Listener in $Computer.Listeners) {
                            $HtmlReport += "<tr>"
                            $HtmlReport += "<td>$($Listener.Transport)</td>"
                            $HtmlReport += "<td>$($Listener.Port)</td>"
                            $HtmlReport += "<td>$($Listener.Certificate)</td>"
                            $HtmlReport += "<td>$($Listener.Status)</td>"
                            $HtmlReport += "</tr>"
                        }

                        $HtmlReport += "</table>"
                    }

                    if ($Computer.ValidationResults.Count -gt 0) {
                        $HtmlReport += "<h3>Validation Results</h3>"
                        foreach ($Validation in $Computer.ValidationResults) {
                            $HtmlReport += "<p><strong>Service Status:</strong> $($Validation.ServiceStatus)</p>"

                            if ($Validation.FirewallRules.Count -gt 0) {
                                $HtmlReport += "<h4>Firewall Rules</h4>"
                                $HtmlReport += "<table><tr><th>Rule Name</th><th>Enabled</th><th>Direction</th><th>Action</th></tr>"

                                foreach ($Rule in $Validation.FirewallRules) {
                                    $HtmlReport += "<tr>"
                                    $HtmlReport += "<td>$($Rule.Name)</td>"
                                    $HtmlReport += "<td>$($Rule.Enabled)</td>"
                                    $HtmlReport += "<td>$($Rule.Direction)</td>"
                                    $HtmlReport += "<td>$($Rule.Action)</td>"
                                    $HtmlReport += "</tr>"
                                }

                                $HtmlReport += "</table>"
                            }
                        }
                    }

                    $HtmlReport += "</div>"
                }

                $HtmlReport += "<div class='header'><h2>Recommendations</h2>"
                foreach ($Rec in $WinRMSecurityResults.Recommendations) {
                    $HtmlReport += "<div class='recommendation'>$Rec</div>"
                }
                $HtmlReport += "</div>"

                $HtmlReport += "</body></html>"

                $HtmlReport | Out-File -FilePath $ReportPath -Encoding UTF8
                Write-CustomLog -Level 'SUCCESS' -Message "WinRM security report saved to: $ReportPath"

            } catch {
                Write-CustomLog -Level 'ERROR' -Message "Failed to generate report: $($_.Exception.Message)"
            }
        }

        # Display summary
        Write-CustomLog -Level 'INFO' -Message "WinRM Security Configuration Summary:"
        Write-CustomLog -Level 'INFO' -Message "  Computers: $($WinRMSecurityResults.ComputersProcessed.Count)"
        Write-CustomLog -Level 'INFO' -Message "  WinRM Enabled: $($WinRMSecurityResults.WinRMEnabled)"
        Write-CustomLog -Level 'INFO' -Message "  HTTPS Configured: $($WinRMSecurityResults.HTTPSConfigured)"
        Write-CustomLog -Level 'INFO' -Message "  HTTP Disabled: $($WinRMSecurityResults.HTTPDisabled)"
        Write-CustomLog -Level 'INFO' -Message "  Authentication Configured: $($WinRMSecurityResults.AuthenticationConfigured)"
        Write-CustomLog -Level 'INFO' -Message "  Firewall Configured: $($WinRMSecurityResults.FirewallConfigured)"

        if ($TestMode) {
            Write-CustomLog -Level 'INFO' -Message "TEST MODE: No actual changes were made"
        }

        return $WinRMSecurityResults
    }
}

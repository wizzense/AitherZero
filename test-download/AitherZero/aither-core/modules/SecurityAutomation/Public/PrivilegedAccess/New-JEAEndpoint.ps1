function New-JEAEndpoint {
    <#
    .SYNOPSIS
        Creates and configures Just Enough Administration (JEA) PowerShell endpoints with predefined templates.

    .DESCRIPTION
        Automates the creation of JEA endpoints using predefined templates for common administrative
        scenarios. Provides simplified JEA deployment with role-based access control, security
        constraints, and comprehensive auditing. Alternative to New-JEASessionConfiguration with templates.

    .PARAMETER EndpointName
        Name of the JEA endpoint to create

    .PARAMETER Template
        Predefined JEA template to use

    .PARAMETER UserGroups
        Active Directory groups to assign to the endpoint

    .PARAMETER AllowedCommands
        Additional commands to allow in the endpoint

    .PARAMETER BlockedCommands
        Commands to explicitly block in the endpoint

    .PARAMETER TranscriptDirectory
        Directory for session transcripts and logging

    .PARAMETER RunAsVirtualAccount
        Run sessions as a virtual machine account

    .PARAMETER RunAsVirtualAccountGroups
        Groups to add the virtual account to

    .PARAMETER SessionTimeout
        Session timeout in minutes

    .PARAMETER RequireSSL
        Require SSL/TLS for remote connections

    .PARAMETER TestMode
        Show what would be configured without creating the endpoint

    .PARAMETER ReportPath
        Path to save JEA endpoint configuration report

    .PARAMETER ValidateEndpoint
        Validate the endpoint after creation

    .PARAMETER BackupExisting
        Backup existing endpoint configuration before changes

    .EXAMPLE
        New-JEAEndpoint -EndpointName "HelpDesk" -Template "UserSupport" -UserGroups @("DOMAIN\HelpDeskOperators")

    .EXAMPLE
        New-JEAEndpoint -EndpointName "ServerAdmins" -Template "ServerManagement" -UserGroups @("DOMAIN\ServerAdmins") -RunAsVirtualAccount

    .EXAMPLE
        New-JEAEndpoint -EndpointName "DatabaseOps" -Template "DatabaseManagement" -UserGroups @("DOMAIN\DBATeam") -SessionTimeout 30 -RequireSSL
    #>

    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidatePattern('^[a-zA-Z][a-zA-Z0-9_-]*$')]
        [string]$EndpointName,

        [Parameter()]
        [ValidateSet('UserSupport', 'ServerManagement', 'DatabaseManagement', 'SecurityOperations', 'NetworkManagement', 'FileSystemManagement', 'EventLogManagement', 'Custom')]
        [string]$Template = 'UserSupport',

        [Parameter()]
        [string[]]$UserGroups = @(),

        [Parameter()]
        [string[]]$AllowedCommands = @(),

        [Parameter()]
        [string[]]$BlockedCommands = @(),

        [Parameter()]
        [string]$TranscriptDirectory = 'C:\ProgramData\JEAConfiguration\Transcripts',

        [Parameter()]
        [switch]$RunAsVirtualAccount,

        [Parameter()]
        [string[]]$RunAsVirtualAccountGroups = @(),

        [Parameter()]
        [ValidateRange(5, 1440)]
        [int]$SessionTimeout = 60,

        [Parameter()]
        [switch]$RequireSSL,

        [Parameter()]
        [switch]$TestMode,

        [Parameter()]
        [string]$ReportPath,

        [Parameter()]
        [switch]$ValidateEndpoint,

        [Parameter()]
        [switch]$BackupExisting
    )

    begin {
        Write-CustomLog -Level 'INFO' -Message "Creating JEA endpoint: $EndpointName using template: $Template"

        # Check if running as Administrator
        $CurrentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
        $Principal = New-Object Security.Principal.WindowsPrincipal($CurrentUser)
        if (-not $Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            throw "This function requires Administrator privileges"
        }

        $JEAResults = @{
            EndpointName = $EndpointName
            Template = $Template
            ConfigPath = $null
            ModuleDirectory = $null
            RoleCapabilities = @()
            RegistrationSuccess = $false
            ValidationResults = @{}
            ConfigurationChanges = @()
            Errors = @()
            Recommendations = @()
        }

        # Define JEA endpoint templates
        $JEATemplates = @{
            'UserSupport' = @{
                Description = 'Help desk and user support operations'
                LanguageMode = 'ConstrainedLanguage'
                ExecutionPolicy = 'RemoteSigned'
                VisibleCmdlets = @(
                    'Get-Process',
                    'Get-Service',
                    'Restart-Service',
                    'Stop-Service',
                    'Start-Service',
                    'Get-EventLog',
                    'Get-WinEvent',
                    'Get-ComputerInfo',
                    'Get-LocalUser',
                    'Set-LocalUser',
                    'Enable-LocalUser',
                    'Disable-LocalUser',
                    'Unlock-ADAccount',
                    'Set-ADAccountPassword',
                    'Enable-ADAccount',
                    'Get-ADUser'
                )
                VisibleFunctions = @(
                    'Reset-UserPassword',
                    'Get-UserInfo',
                    'Restart-UserService'
                )
                ModulesToImport = @('ActiveDirectory')
                RequiredGroups = @('Users')
            }
            'ServerManagement' = @{
                Description = 'Server administration and maintenance'
                LanguageMode = 'ConstrainedLanguage'
                ExecutionPolicy = 'RemoteSigned'
                VisibleCmdlets = @(
                    'Get-Process',
                    'Stop-Process',
                    'Get-Service',
                    'Start-Service',
                    'Stop-Service',
                    'Restart-Service',
                    'Set-Service',
                    'Get-EventLog',
                    'Get-WinEvent',
                    'Clear-EventLog',
                    'Get-ComputerInfo',
                    'Restart-Computer',
                    'Get-HotFix',
                    'Install-WindowsUpdate',
                    'Get-Disk',
                    'Get-Volume',
                    'Get-NetAdapter',
                    'Test-NetConnection'
                )
                VisibleFunctions = @(
                    'Restart-ServerSafely',
                    'Get-ServerHealth',
                    'Clear-TempFiles'
                )
                ModulesToImport = @('ServerManager', 'NetAdapter', 'Storage')
                RequiredGroups = @('Administrators')
            }
            'DatabaseManagement' = @{
                Description = 'Database administration operations'
                LanguageMode = 'ConstrainedLanguage'
                ExecutionPolicy = 'RemoteSigned'
                VisibleCmdlets = @(
                    'Invoke-SqlCmd',
                    'Get-Service',
                    'Start-Service',
                    'Stop-Service',
                    'Restart-Service',
                    'Get-Process',
                    'Get-EventLog',
                    'Get-WinEvent',
                    'Backup-SqlDatabase',
                    'Restore-SqlDatabase',
                    'Test-SqlDatabaseReplicationState'
                )
                VisibleFunctions = @(
                    'Get-DatabaseStatus',
                    'Backup-AllDatabases',
                    'Monitor-DatabasePerformance'
                )
                ModulesToImport = @('SqlServer', 'SQLPS')
                RequiredGroups = @('DBAdministrators')
            }
            'SecurityOperations' = @{
                Description = 'Security monitoring and response'
                LanguageMode = 'ConstrainedLanguage'
                ExecutionPolicy = 'AllSigned'
                VisibleCmdlets = @(
                    'Get-EventLog',
                    'Get-WinEvent',
                    'Get-Process',
                    'Stop-Process',
                    'Get-Service',
                    'Stop-Service',
                    'Get-NetTCPConnection',
                    'Get-NetUDPEndpoint',
                    'Block-SmbShareAccess',
                    'Unblock-SmbShareAccess',
                    'Get-SmbShare',
                    'Get-FileHash',
                    'Get-AuthenticodeSignature'
                )
                VisibleFunctions = @(
                    'Block-SuspiciousIP',
                    'Get-SecurityAlerts',
                    'Quarantine-SuspiciousFile'
                )
                ModulesToImport = @('Microsoft.PowerShell.Security', 'NetSecurity')
                RequiredGroups = @('SecurityOperators')
            }
            'NetworkManagement' = @{
                Description = 'Network configuration and monitoring'
                LanguageMode = 'ConstrainedLanguage'
                ExecutionPolicy = 'RemoteSigned'
                VisibleCmdlets = @(
                    'Get-NetAdapter',
                    'Set-NetAdapter',
                    'Get-NetIPAddress',
                    'Set-NetIPAddress',
                    'Get-NetRoute',
                    'New-NetRoute',
                    'Remove-NetRoute',
                    'Test-NetConnection',
                    'Get-NetFirewallRule',
                    'Enable-NetFirewallRule',
                    'Disable-NetFirewallRule',
                    'Get-DnsClientCache',
                    'Clear-DnsClientCache'
                )
                VisibleFunctions = @(
                    'Test-NetworkConnectivity',
                    'Get-NetworkConfiguration',
                    'Reset-NetworkAdapter'
                )
                ModulesToImport = @('NetAdapter', 'NetTCPIP', 'NetSecurity', 'DnsClient')
                RequiredGroups = @('NetworkOperators')
            }
            'FileSystemManagement' = @{
                Description = 'File system operations and maintenance'
                LanguageMode = 'ConstrainedLanguage'
                ExecutionPolicy = 'RemoteSigned'
                VisibleCmdlets = @(
                    'Get-ChildItem',
                    'Get-Item',
                    'Get-ItemProperty',
                    'Set-ItemProperty',
                    'Copy-Item',
                    'Move-Item',
                    'Remove-Item',
                    'New-Item',
                    'Get-Acl',
                    'Set-Acl',
                    'Get-Disk',
                    'Get-Volume',
                    'Get-SmbShare',
                    'Get-SmbShareAccess'
                )
                VisibleFunctions = @(
                    'Clean-TempFiles',
                    'Get-DiskUsage',
                    'Set-FolderPermissions'
                )
                ModulesToImport = @('Storage', 'SmbShare')
                RequiredGroups = @('FileOperators')
            }
            'EventLogManagement' = @{
                Description = 'Event log monitoring and management'
                LanguageMode = 'ConstrainedLanguage'
                ExecutionPolicy = 'RemoteSigned'
                VisibleCmdlets = @(
                    'Get-EventLog',
                    'Get-WinEvent',
                    'Clear-EventLog',
                    'Export-Counter',
                    'Get-Counter',
                    'Get-Service',
                    'Get-Process'
                )
                VisibleFunctions = @(
                    'Get-SecurityEvents',
                    'Export-EventLogs',
                    'Monitor-SystemHealth'
                )
                ModulesToImport = @('Microsoft.PowerShell.Diagnostics')
                RequiredGroups = @('EventLogOperators')
            }
        }

        # Configuration paths
        $ConfigDirectory = "C:\ProgramData\JEAConfiguration"
        $ModuleDirectory = Join-Path $ConfigDirectory "Modules\$EndpointName"
        $SessionConfigPath = Join-Path $ModuleDirectory "$EndpointName.pssc"
        $RoleCapabilitiesPath = Join-Path $ModuleDirectory "RoleCapabilities"

        $JEAResults.ConfigPath = $SessionConfigPath
        $JEAResults.ModuleDirectory = $ModuleDirectory

        # Ensure transcript directory exists
        if (-not (Test-Path $TranscriptDirectory)) {
            New-Item -Path $TranscriptDirectory -ItemType Directory -Force | Out-Null
        }
    }

    process {
        try {
            # Backup existing configuration if requested
            if ($BackupExisting) {
                $ExistingConfig = Get-PSSessionConfiguration -Name $EndpointName -ErrorAction SilentlyContinue
                if ($ExistingConfig) {
                    Write-CustomLog -Level 'INFO' -Message "Backing up existing configuration: $EndpointName"

                    $BackupPath = Join-Path $ConfigDirectory "Backups\$EndpointName-$(Get-Date -Format 'yyyyMMdd-HHmmss').xml"
                    New-Item -Path (Split-Path $BackupPath) -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null

                    $ExistingConfig | Export-Clixml -Path $BackupPath -Force
                    Write-CustomLog -Level 'SUCCESS' -Message "Configuration backed up to: $BackupPath"
                }
            }

            # Remove existing endpoint if it exists
            $ExistingConfig = Get-PSSessionConfiguration -Name $EndpointName -ErrorAction SilentlyContinue
            if ($ExistingConfig) {
                Write-CustomLog -Level 'INFO' -Message "Removing existing endpoint: $EndpointName"

                if ($PSCmdlet.ShouldProcess($EndpointName, "Remove existing session configuration") -and -not $TestMode) {
                    Unregister-PSSessionConfiguration -Name $EndpointName -Force
                    $JEAResults.ConfigurationChanges += "Removed existing endpoint: $EndpointName"
                }
            }

            # Create configuration directories
            Write-CustomLog -Level 'INFO' -Message "Creating configuration directories"

            if (-not $TestMode) {
                if (-not (Test-Path $ConfigDirectory)) {
                    New-Item -Path $ConfigDirectory -ItemType Directory -Force | Out-Null
                }

                if (-not (Test-Path $ModuleDirectory)) {
                    New-Item -Path $ModuleDirectory -ItemType Directory -Force | Out-Null
                }

                if (-not (Test-Path $RoleCapabilitiesPath)) {
                    New-Item -Path $RoleCapabilitiesPath -ItemType Directory -Force | Out-Null
                }
            }

            # Get template configuration
            if (-not $JEATemplates.ContainsKey($Template)) {
                throw "Unknown template: $Template"
            }

            $TemplateConfig = $JEATemplates[$Template]

            # Create module manifest
            Write-CustomLog -Level 'INFO' -Message "Creating PowerShell module manifest"

            $ManifestPath = Join-Path $ModuleDirectory "$EndpointName.psd1"
            $ManifestParams = @{
                Path = $ManifestPath
                Author = 'AitherZero Security Team'
                CompanyName = 'AitherZero Project'
                Description = "JEA endpoint configuration for $EndpointName - $($TemplateConfig.Description)"
                ModuleVersion = '1.0.0'
                PowerShellVersion = '5.1'
            }

            if (-not $TestMode) {
                New-ModuleManifest @ManifestParams
                $JEAResults.ConfigurationChanges += "Created module manifest: $ManifestPath"
            }

            # Create role capabilities for each user group
            Write-CustomLog -Level 'INFO' -Message "Creating role capabilities"

            if ($UserGroups.Count -eq 0) {
                Write-CustomLog -Level 'WARNING' -Message "No user groups specified, using template default groups"
                $UserGroups = $TemplateConfig.RequiredGroups
            }

            foreach ($Group in $UserGroups) {
                $RoleName = ($Group -split '\\')[-1] -replace '[^a-zA-Z0-9]', ''
                $RoleCapabilityPath = Join-Path $RoleCapabilitiesPath "$RoleName.psrc"

                Write-CustomLog -Level 'INFO' -Message "Creating role capability: $RoleName for group: $Group"

                # Build role capability configuration
                $RoleCapabilityConfig = @{
                    Path = $RoleCapabilityPath
                    Author = 'AitherZero Security Team'
                    CompanyName = 'AitherZero Project'
                    Description = "Role capability for $RoleName - $($TemplateConfig.Description)"
                }

                # Add modules to import from template
                if ($TemplateConfig.ModulesToImport) {
                    $RoleCapabilityConfig['ModulesToImport'] = $TemplateConfig.ModulesToImport
                }

                # Add visible cmdlets from template and additional allowed commands
                $AllVisibleCmdlets = $TemplateConfig.VisibleCmdlets + $AllowedCommands | Sort-Object -Unique
                if ($AllVisibleCmdlets.Count -gt 0) {
                    $RoleCapabilityConfig['VisibleCmdlets'] = $AllVisibleCmdlets
                }

                # Add visible functions from template
                if ($TemplateConfig.VisibleFunctions) {
                    $RoleCapabilityConfig['VisibleFunctions'] = $TemplateConfig.VisibleFunctions
                }

                # Create the role capability file
                if ($PSCmdlet.ShouldProcess($RoleName, "Create role capability") -and -not $TestMode) {
                    New-PSRoleCapabilityFile @RoleCapabilityConfig
                    $JEAResults.RoleCapabilities += @{
                        Name = $RoleName
                        Path = $RoleCapabilityPath
                        AssignedTo = $Group
                    }
                    $JEAResults.ConfigurationChanges += "Created role capability: $RoleName"
                } elseif ($TestMode) {
                    $JEAResults.RoleCapabilities += @{
                        Name = $RoleName
                        Path = $RoleCapabilityPath
                        AssignedTo = $Group
                    }
                    $JEAResults.ConfigurationChanges += "[TEST] Would create role capability: $RoleName"
                }
            }

            # Create session configuration file
            Write-CustomLog -Level 'INFO' -Message "Creating session configuration file"

            # Build role definitions
            $RoleDefinitions = @{}
            foreach ($Group in $UserGroups) {
                $RoleName = ($Group -split '\\')[-1] -replace '[^a-zA-Z0-9]', ''
                $RoleDefinitions[$Group] = @{ RoleCapabilities = $RoleName }
            }

            $SessionConfigParams = @{
                Path = $SessionConfigPath
                Author = 'AitherZero Security Team'
                CompanyName = 'AitherZero Project'
                Description = "JEA session configuration for $EndpointName - $($TemplateConfig.Description)"
                SessionType = 'RestrictedRemoteServer'
                LanguageMode = $TemplateConfig.LanguageMode
                ExecutionPolicy = $TemplateConfig.ExecutionPolicy
                TranscriptDirectory = $TranscriptDirectory
                RoleDefinitions = $RoleDefinitions
            }

            # Add virtual account settings
            if ($RunAsVirtualAccount) {
                $SessionConfigParams['RunAsVirtualAccount'] = $true

                if ($RunAsVirtualAccountGroups.Count -gt 0) {
                    $SessionConfigParams['RunAsVirtualAccountGroups'] = $RunAsVirtualAccountGroups
                } else {
                    # Use template required groups as virtual account groups
                    $SessionConfigParams['RunAsVirtualAccountGroups'] = $TemplateConfig.RequiredGroups
                }
            }

            # Add session timeout
            if ($SessionTimeout -ne 60) {
                $SessionConfigParams['MaxIdleTimeoutSec'] = $SessionTimeout * 60
            }

            # Create the session configuration file
            if ($PSCmdlet.ShouldProcess($EndpointName, "Create session configuration") -and -not $TestMode) {
                New-PSSessionConfigurationFile @SessionConfigParams
                $JEAResults.ConfigurationChanges += "Created session configuration: $SessionConfigPath"
            } elseif ($TestMode) {
                $JEAResults.ConfigurationChanges += "[TEST] Would create session configuration: $SessionConfigPath"
            }

            # Register the session configuration
            Write-CustomLog -Level 'INFO' -Message "Registering JEA endpoint: $EndpointName"

            if ($PSCmdlet.ShouldProcess($EndpointName, "Register session configuration") -and -not $TestMode) {
                try {
                    $RegisterParams = @{
                        Name = $EndpointName
                        Path = $SessionConfigPath
                        Force = $true
                    }

                    # Add SSL requirement if specified
                    if ($RequireSSL) {
                        $RegisterParams['UseSSL'] = $true
                    }

                    Register-PSSessionConfiguration @RegisterParams | Out-Null
                    $JEAResults.RegistrationSuccess = $true
                    $JEAResults.ConfigurationChanges += "Registered endpoint: $EndpointName"

                    Write-CustomLog -Level 'SUCCESS' -Message "JEA endpoint registered successfully: $EndpointName"

                } catch {
                    $Error = "Failed to register session configuration: $($_.Exception.Message)"
                    $JEAResults.Errors += $Error
                    Write-CustomLog -Level 'ERROR' -Message $Error
                    throw
                }
            } elseif ($TestMode) {
                $JEAResults.RegistrationSuccess = $true  # Simulated success
                $JEAResults.ConfigurationChanges += "[TEST] Would register endpoint: $EndpointName"
                Write-CustomLog -Level 'INFO' -Message "[TEST] Would register JEA endpoint: $EndpointName"
            }

            # Restart WinRM service to load the new endpoint
            if (-not $TestMode) {
                Write-CustomLog -Level 'INFO' -Message "Restarting WinRM service to load new endpoint"

                if ($PSCmdlet.ShouldProcess("WinRM", "Restart service")) {
                    try {
                        Restart-Service -Name WinRM -Force
                        Start-Sleep -Seconds 5  # Wait for service to stabilize
                        $JEAResults.ConfigurationChanges += "Restarted WinRM service"

                    } catch {
                        $Error = "Failed to restart WinRM service: $($_.Exception.Message)"
                        $JEAResults.Errors += $Error
                        Write-CustomLog -Level 'WARNING' -Message $Error
                    }
                }
            }

            # Validate the endpoint if requested
            if ($ValidateEndpoint) {
                Write-CustomLog -Level 'INFO' -Message "Validating JEA endpoint"

                try {
                    if (-not $TestMode) {
                        # Verify endpoint is available
                        $Endpoint = Get-PSSessionConfiguration -Name $EndpointName -ErrorAction Stop
                        $JEAResults.ValidationResults['EndpointExists'] = $true
                        $JEAResults.ValidationResults['EndpointDetails'] = $Endpoint

                        # Test session creation (local only)
                        try {
                            $TestSession = New-PSSession -ConfigurationName $EndpointName -EnableNetworkAccess -ErrorAction Stop
                            $JEAResults.ValidationResults['SessionCreation'] = 'Success'

                            # Test command execution
                            $Commands = Invoke-Command -Session $TestSession -ScriptBlock { Get-Command } -ErrorAction SilentlyContinue
                            $JEAResults.ValidationResults['AvailableCommands'] = $Commands.Count

                            # Clean up test session
                            Remove-PSSession -Session $TestSession -ErrorAction SilentlyContinue

                        } catch {
                            $JEAResults.ValidationResults['SessionCreation'] = "Failed: $($_.Exception.Message)"
                        }
                    } else {
                        $JEAResults.ValidationResults['EndpointExists'] = $true
                        $JEAResults.ValidationResults['SessionCreation'] = '[TEST] Simulated success'
                        $JEAResults.ValidationResults['AvailableCommands'] = $TemplateConfig.VisibleCmdlets.Count
                    }

                    Write-CustomLog -Level 'SUCCESS' -Message "Endpoint validation completed"

                } catch {
                    $Error = "Endpoint validation failed: $($_.Exception.Message)"
                    $JEAResults.Errors += $Error
                    Write-CustomLog -Level 'ERROR' -Message $Error
                }
            }

        } catch {
            $Error = "Error creating JEA endpoint: $($_.Exception.Message)"
            $JEAResults.Errors += $Error
            Write-CustomLog -Level 'ERROR' -Message $Error
            throw
        }
    }

    end {
        Write-CustomLog -Level 'SUCCESS' -Message "JEA endpoint creation completed"

        # Generate recommendations
        $JEAResults.Recommendations += "Test the JEA endpoint with different user accounts to verify role-based access"
        $JEAResults.Recommendations += "Monitor transcript logs for security events and compliance"
        $JEAResults.Recommendations += "Regularly review and update role capabilities based on business needs"
        $JEAResults.Recommendations += "Implement session timeout and idle disconnect policies"
        $JEAResults.Recommendations += "Consider implementing conditional access policies for sensitive endpoints"

        if ($RunAsVirtualAccount) {
            $JEAResults.Recommendations += "Monitor virtual account activities in Active Directory logs"
            $JEAResults.Recommendations += "Ensure virtual account groups have minimal required permissions"
        }

        if ($RequireSSL) {
            $JEAResults.Recommendations += "Verify SSL certificate validity and expiration dates"
            $JEAResults.Recommendations += "Implement certificate auto-renewal for JEA endpoints"
        }

        # Add template-specific recommendations
        switch ($Template) {
            'UserSupport' {
                $JEAResults.Recommendations += "Provide training to help desk staff on JEA endpoint usage"
                $JEAResults.Recommendations += "Implement approval workflow for privileged user operations"
            }
            'ServerManagement' {
                $JEAResults.Recommendations += "Implement change management process for server operations"
                $JEAResults.Recommendations += "Consider additional approval for restart operations"
            }
            'SecurityOperations' {
                $JEAResults.Recommendations += "Integrate JEA logs with SIEM system for security monitoring"
                $JEAResults.Recommendations += "Implement emergency break-glass procedures"
            }
        }

        # Generate HTML report if requested
        if ($ReportPath) {
            try {
                $HtmlReport = @"
<!DOCTYPE html>
<html>
<head>
    <title>JEA Endpoint Configuration Report - $EndpointName</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #f0f0f0; padding: 15px; border-radius: 5px; }
        .section { border: 1px solid #ccc; margin: 20px 0; padding: 15px; border-radius: 5px; }
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
        <h1>JEA Endpoint Configuration Report</h1>
        <p><strong>Endpoint Name:</strong> $($JEAResults.EndpointName)</p>
        <p><strong>Template:</strong> $($JEAResults.Template)</p>
        <p><strong>Generated:</strong> $(Get-Date)</p>
        <p><strong>Registration Status:</strong> $(if ($JEAResults.RegistrationSuccess) { '<span class="success">Success</span>' } else { '<span class="error">Failed</span>' })</p>
        <p><strong>Configuration Path:</strong> $($JEAResults.ConfigPath)</p>
    </div>

    <div class='section'>
        <h2>Template Configuration</h2>
        <p><strong>Description:</strong> $($TemplateConfig.Description)</p>
        <p><strong>Language Mode:</strong> $($TemplateConfig.LanguageMode)</p>
        <p><strong>Execution Policy:</strong> $($TemplateConfig.ExecutionPolicy)</p>
        <p><strong>Modules to Import:</strong> $($TemplateConfig.ModulesToImport -join ', ')</p>
        <p><strong>Visible Cmdlets:</strong> $($TemplateConfig.VisibleCmdlets.Count)</p>
    </div>

    <div class='section'>
        <h2>Role Capabilities</h2>
        <table>
            <tr><th>Role Name</th><th>Assigned To</th><th>File Path</th></tr>
"@

                foreach ($Role in $JEAResults.RoleCapabilities) {
                    $HtmlReport += "<tr><td>$($Role.Name)</td><td>$($Role.AssignedTo)</td><td>$($Role.Path)</td></tr>"
                }

                $HtmlReport += @"
        </table>
    </div>

    <div class='section'>
        <h2>Configuration Changes</h2>
        <ul>
"@

                foreach ($Change in $JEAResults.ConfigurationChanges) {
                    $HtmlReport += "<li>$Change</li>"
                }

                $HtmlReport += @"
        </ul>
    </div>
"@

                if ($JEAResults.ValidationResults.Count -gt 0) {
                    $HtmlReport += @"
    <div class='section'>
        <h2>Validation Results</h2>
        <table>
            <tr><th>Test</th><th>Result</th></tr>
"@

                    foreach ($Test in $JEAResults.ValidationResults.Keys) {
                        $Result = $JEAResults.ValidationResults[$Test]
                        $HtmlReport += "<tr><td>$Test</td><td>$Result</td></tr>"
                    }

                    $HtmlReport += "</table></div>"
                }

                $HtmlReport += @"
    <div class='section'>
        <h2>Recommendations</h2>
"@

                foreach ($Rec in $JEAResults.Recommendations) {
                    $HtmlReport += "<div class='recommendation'>$Rec</div>"
                }

                $HtmlReport += @"
    </div>
</body>
</html>
"@

                $HtmlReport | Out-File -FilePath $ReportPath -Encoding UTF8
                Write-CustomLog -Level 'SUCCESS' -Message "JEA endpoint report saved to: $ReportPath"

            } catch {
                Write-CustomLog -Level 'ERROR' -Message "Failed to generate report: $($_.Exception.Message)"
            }
        }

        # Display summary
        Write-CustomLog -Level 'INFO' -Message "JEA Endpoint Configuration Summary:"
        Write-CustomLog -Level 'INFO' -Message "  Endpoint: $($JEAResults.EndpointName)"
        Write-CustomLog -Level 'INFO' -Message "  Template: $($JEAResults.Template)"
        Write-CustomLog -Level 'INFO' -Message "  Registration: $(if ($JEAResults.RegistrationSuccess) { 'Success' } else { 'Failed' })"
        Write-CustomLog -Level 'INFO' -Message "  Role Capabilities: $($JEAResults.RoleCapabilities.Count)"
        Write-CustomLog -Level 'INFO' -Message "  Configuration Changes: $($JEAResults.ConfigurationChanges.Count)"

        if ($JEAResults.Errors.Count -gt 0) {
            Write-CustomLog -Level 'ERROR' -Message "  Errors: $($JEAResults.Errors.Count)"
            foreach ($Error in $JEAResults.Errors) {
                Write-CustomLog -Level 'ERROR' -Message "    $Error"
            }
        }

        if ($TestMode) {
            Write-CustomLog -Level 'INFO' -Message "TEST MODE: No actual endpoint was created"
        } elseif ($JEAResults.RegistrationSuccess) {
            Write-CustomLog -Level 'SUCCESS' -Message "JEA endpoint '$EndpointName' is ready for use"
            Write-CustomLog -Level 'INFO' -Message "Connect with: Enter-PSSession -ComputerName <server> -ConfigurationName $EndpointName"
        }

        return $JEAResults
    }
}

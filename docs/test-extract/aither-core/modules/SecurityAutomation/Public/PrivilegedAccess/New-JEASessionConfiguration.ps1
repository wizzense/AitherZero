function New-JEASessionConfiguration {
    <#
    .SYNOPSIS
        Creates and configures Just Enough Administration (JEA) PowerShell endpoints.
        
    .DESCRIPTION
        Automates the creation of JEA session configurations with role capabilities,
        security constraints, and auditing. Implements least-privilege access patterns
        for delegated administration scenarios.
        
    .PARAMETER EndpointName
        Name of the JEA endpoint to create
        
    .PARAMETER RoleDefinitions
        Hashtable defining role mappings to Active Directory groups or users
        
    .PARAMETER SessionType
        Type of PowerShell session configuration
        
    .PARAMETER LanguageMode
        PowerShell language mode for the session
        
    .PARAMETER ExecutionPolicy
        Execution policy for the session
        
    .PARAMETER TranscriptDirectory
        Directory for session transcripts and logging
        
    .PARAMETER RunAsVirtualAccount
        Run sessions as a virtual machine account
        
    .PARAMETER RunAsVirtualAccountGroups
        Groups to add the virtual account to
        
    .PARAMETER ModulesToImport
        PowerShell modules to import in sessions
        
    .PARAMETER VisibleCmdlets
        Cmdlets visible in the constrained session
        
    .PARAMETER VisibleFunctions
        Functions visible in the constrained session
        
    .PARAMETER VisibleExternalCommands
        External commands allowed in the session
        
    .PARAMETER StartupScript
        Script to run when session starts
        
    .PARAMETER RequireSSL
        Require SSL/TLS for remote connections
        
    .PARAMETER Force
        Force overwrite existing configuration
        
    .PARAMETER TestConfiguration
        Test the configuration after creation
        
    .PARAMETER BackupExisting
        Backup existing configuration before changes
        
    .PARAMETER ReportPath
        Path to save configuration report
        
    .EXAMPLE
        $RoleDef = @{
            'DOMAIN\ServiceAdmins' = @{ RoleCapabilities = 'ServiceManagement' }
            'DOMAIN\HelpDesk' = @{ RoleCapabilities = 'UserAssistance' }
        }
        New-JEASessionConfiguration -EndpointName 'ServiceDesk' -RoleDefinitions $RoleDef
        
    .EXAMPLE
        New-JEASessionConfiguration -EndpointName 'LimitedAdmin' -RunAsVirtualAccount -TranscriptDirectory 'C:\JEALogs' -RequireSSL
        
    .EXAMPLE
        New-JEASessionConfiguration -EndpointName 'Auditors' -LanguageMode 'ConstrainedLanguage' -TestConfiguration
    #>
    
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidatePattern('^[a-zA-Z][a-zA-Z0-9_-]*$')]
        [string]$EndpointName,
        
        [Parameter()]
        [hashtable]$RoleDefinitions = @{},
        
        [Parameter()]
        [ValidateSet('Default', 'RestrictedRemoteServer', 'Empty')]
        [string]$SessionType = 'RestrictedRemoteServer',
        
        [Parameter()]
        [ValidateSet('FullLanguage', 'ConstrainedLanguage', 'RestrictedLanguage', 'NoLanguage')]
        [string]$LanguageMode = 'NoLanguage',
        
        [Parameter()]
        [ValidateSet('Restricted', 'AllSigned', 'RemoteSigned', 'Unrestricted', 'Bypass')]
        [string]$ExecutionPolicy = 'Restricted',
        
        [Parameter()]
        [string]$TranscriptDirectory = 'C:\ProgramData\JEAConfiguration\Transcripts',
        
        [Parameter()]
        [switch]$RunAsVirtualAccount,
        
        [Parameter()]
        [string[]]$RunAsVirtualAccountGroups = @(),
        
        [Parameter()]
        [string[]]$ModulesToImport = @(),
        
        [Parameter()]
        [object[]]$VisibleCmdlets = @(),
        
        [Parameter()]
        [object[]]$VisibleFunctions = @(),
        
        [Parameter()]
        [string[]]$VisibleExternalCommands = @(),
        
        [Parameter()]
        [string]$StartupScript,
        
        [Parameter()]
        [switch]$RequireSSL,
        
        [Parameter()]
        [switch]$Force,
        
        [Parameter()]
        [switch]$TestConfiguration,
        
        [Parameter()]
        [switch]$BackupExisting,
        
        [Parameter()]
        [string]$ReportPath
    )
    
    begin {
        Write-CustomLog -Level 'INFO' -Message "Creating JEA session configuration: $EndpointName"
        
        # Check if running as Administrator
        $CurrentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
        $Principal = New-Object Security.Principal.WindowsPrincipal($CurrentUser)
        if (-not $Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            throw "This function requires Administrator privileges"
        }
        
        # Configuration paths
        $ConfigDirectory = "C:\ProgramData\JEAConfiguration"
        $ModuleDirectory = Join-Path $ConfigDirectory "Modules\$EndpointName"
        $SessionConfigPath = Join-Path $ModuleDirectory "$EndpointName.pssc"
        $RoleCapabilitiesPath = Join-Path $ModuleDirectory "RoleCapabilities"
        
        $JEAResults = @{
            EndpointName = $EndpointName
            ConfigPath = $SessionConfigPath
            ModuleDirectory = $ModuleDirectory
            RoleCapabilities = @()
            RegistrationSuccess = $false
            TestResults = @{}
            ConfigurationChanges = @()
            Errors = @()
            Recommendations = @()
        }
        
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
            
            # Remove existing endpoint if Force is specified
            if ($Force) {
                $ExistingConfig = Get-PSSessionConfiguration -Name $EndpointName -ErrorAction SilentlyContinue
                if ($ExistingConfig) {
                    Write-CustomLog -Level 'INFO' -Message "Removing existing endpoint: $EndpointName"
                    
                    if ($PSCmdlet.ShouldProcess($EndpointName, "Remove existing session configuration")) {
                        Unregister-PSSessionConfiguration -Name $EndpointName -Force
                        $JEAResults.ConfigurationChanges += "Removed existing endpoint: $EndpointName"
                    }
                }
            }
            
            # Create configuration directories
            Write-CustomLog -Level 'INFO' -Message "Creating configuration directories"
            
            if (-not (Test-Path $ConfigDirectory)) {
                New-Item -Path $ConfigDirectory -ItemType Directory -Force | Out-Null
            }
            
            if (-not (Test-Path $ModuleDirectory)) {
                New-Item -Path $ModuleDirectory -ItemType Directory -Force | Out-Null
            }
            
            if (-not (Test-Path $RoleCapabilitiesPath)) {
                New-Item -Path $RoleCapabilitiesPath -ItemType Directory -Force | Out-Null
            }
            
            # Create module manifest
            Write-CustomLog -Level 'INFO' -Message "Creating PowerShell module manifest"
            
            $ManifestPath = Join-Path $ModuleDirectory "$EndpointName.psd1"
            $ManifestParams = @{
                Path = $ManifestPath
                Author = 'AitherZero Security Team'
                CompanyName = 'AitherZero Project'
                Description = "JEA endpoint configuration for $EndpointName"
                ModuleVersion = '1.0.0'
                PowerShellVersion = '5.1'
            }
            
            New-ModuleManifest @ManifestParams
            $JEAResults.ConfigurationChanges += "Created module manifest: $ManifestPath"
            
            # Create role capabilities for each role definition
            Write-CustomLog -Level 'INFO' -Message "Creating role capabilities"
            
            foreach ($Role in $RoleDefinitions.Keys) {
                $RoleConfig = $RoleDefinitions[$Role]
                $RoleName = if ($RoleConfig.RoleCapabilities) { $RoleConfig.RoleCapabilities } else { ($Role -split '\\')[-1] }
                $RoleCapabilityPath = Join-Path $RoleCapabilitiesPath "$RoleName.psrc"
                
                Write-CustomLog -Level 'INFO' -Message "Creating role capability: $RoleName"
                
                # Build role capability configuration
                $RoleCapabilityConfig = @{
                    Path = $RoleCapabilityPath
                    Author = 'AitherZero Security Team'
                    CompanyName = 'AitherZero Project'
                    Description = "Role capability for $RoleName"
                }
                
                # Add modules to import
                if ($ModulesToImport.Count -gt 0) {
                    $RoleCapabilityConfig['ModulesToImport'] = $ModulesToImport
                }
                
                # Add visible cmdlets
                if ($VisibleCmdlets.Count -gt 0) {
                    $RoleCapabilityConfig['VisibleCmdlets'] = $VisibleCmdlets
                }
                
                # Add visible functions
                if ($VisibleFunctions.Count -gt 0) {
                    $RoleCapabilityConfig['VisibleFunctions'] = $VisibleFunctions
                }
                
                # Add visible external commands
                if ($VisibleExternalCommands.Count -gt 0) {
                    $RoleCapabilityConfig['VisibleExternalCommands'] = $VisibleExternalCommands
                }
                
                # Add role-specific configurations if provided
                if ($RoleConfig.VisibleCmdlets) {
                    $RoleCapabilityConfig['VisibleCmdlets'] = $RoleConfig.VisibleCmdlets
                }
                
                if ($RoleConfig.VisibleFunctions) {
                    $RoleCapabilityConfig['VisibleFunctions'] = $RoleConfig.VisibleFunctions
                }
                
                if ($RoleConfig.ModulesToImport) {
                    $RoleCapabilityConfig['ModulesToImport'] = $RoleConfig.ModulesToImport
                }
                
                # Create the role capability file
                if ($PSCmdlet.ShouldProcess($RoleName, "Create role capability")) {
                    New-PSRoleCapabilityFile @RoleCapabilityConfig
                    $JEAResults.RoleCapabilities += @{
                        Name = $RoleName
                        Path = $RoleCapabilityPath
                        AssignedTo = $Role
                    }
                    $JEAResults.ConfigurationChanges += "Created role capability: $RoleName"
                }
            }
            
            # Create session configuration file
            Write-CustomLog -Level 'INFO' -Message "Creating session configuration file"
            
            $SessionConfigParams = @{
                Path = $SessionConfigPath
                Author = 'AitherZero Security Team'
                CompanyName = 'AitherZero Project'
                Description = "JEA session configuration for $EndpointName"
                SessionType = $SessionType
                LanguageMode = $LanguageMode
                ExecutionPolicy = $ExecutionPolicy
                TranscriptDirectory = $TranscriptDirectory
            }
            
            # Add role definitions
            if ($RoleDefinitions.Count -gt 0) {
                $SessionConfigParams['RoleDefinitions'] = $RoleDefinitions
            }
            
            # Add virtual account settings
            if ($RunAsVirtualAccount) {
                $SessionConfigParams['RunAsVirtualAccount'] = $true
                
                if ($RunAsVirtualAccountGroups.Count -gt 0) {
                    $SessionConfigParams['RunAsVirtualAccountGroups'] = $RunAsVirtualAccountGroups
                }
            }
            
            # Add startup script
            if ($StartupScript) {
                if (Test-Path $StartupScript) {
                    $SessionConfigParams['ScriptsToProcess'] = @($StartupScript)
                } else {
                    Write-CustomLog -Level 'WARNING' -Message "Startup script not found: $StartupScript"
                }
            }
            
            # Create the session configuration file
            if ($PSCmdlet.ShouldProcess($EndpointName, "Create session configuration")) {
                New-PSSessionConfigurationFile @SessionConfigParams
                $JEAResults.ConfigurationChanges += "Created session configuration: $SessionConfigPath"
            }
            
            # Register the session configuration
            Write-CustomLog -Level 'INFO' -Message "Registering JEA endpoint: $EndpointName"
            
            if ($PSCmdlet.ShouldProcess($EndpointName, "Register session configuration")) {
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
            }
            
            # Restart WinRM service to load the new endpoint
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
            
            # Test the configuration if requested
            if ($TestConfiguration) {
                Write-CustomLog -Level 'INFO' -Message "Testing JEA configuration"
                
                try {
                    # Verify endpoint is available
                    $Endpoint = Get-PSSessionConfiguration -Name $EndpointName -ErrorAction Stop
                    $JEAResults.TestResults['EndpointExists'] = $true
                    $JEAResults.TestResults['EndpointDetails'] = $Endpoint
                    
                    # Test session creation (local only)
                    try {
                        $TestSession = New-PSSession -ConfigurationName $EndpointName -EnableNetworkAccess -ErrorAction Stop
                        $JEAResults.TestResults['SessionCreation'] = 'Success'
                        
                        # Test command execution
                        $Commands = Invoke-Command -Session $TestSession -ScriptBlock { Get-Command } -ErrorAction SilentlyContinue
                        $JEAResults.TestResults['AvailableCommands'] = $Commands.Count
                        
                        # Clean up test session
                        Remove-PSSession -Session $TestSession -ErrorAction SilentlyContinue
                        
                    } catch {
                        $JEAResults.TestResults['SessionCreation'] = "Failed: $($_.Exception.Message)"
                    }
                    
                    Write-CustomLog -Level 'SUCCESS' -Message "Configuration testing completed"
                    
                } catch {
                    $Error = "Configuration testing failed: $($_.Exception.Message)"
                    $JEAResults.Errors += $Error
                    Write-CustomLog -Level 'ERROR' -Message $Error
                }
            }
            
        } catch {
            $Error = "Error creating JEA session configuration: $($_.Exception.Message)"
            $JEAResults.Errors += $Error
            Write-CustomLog -Level 'ERROR' -Message $Error
            throw
        }
    }
    
    end {
        Write-CustomLog -Level 'SUCCESS' -Message "JEA session configuration completed"
        
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
        
        # Generate report if requested
        if ($ReportPath) {
            try {
                $HtmlReport = @"
<!DOCTYPE html>
<html>
<head>
    <title>JEA Session Configuration Report - $EndpointName</title>
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
        <h1>JEA Session Configuration Report</h1>
        <p><strong>Endpoint Name:</strong> $($JEAResults.EndpointName)</p>
        <p><strong>Generated:</strong> $(Get-Date)</p>
        <p><strong>Registration Status:</strong> $(if ($JEAResults.RegistrationSuccess) { '<span class="success">Success</span>' } else { '<span class="error">Failed</span>' })</p>
        <p><strong>Configuration Path:</strong> $($JEAResults.ConfigPath)</p>
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
                
                if ($JEAResults.TestResults.Count -gt 0) {
                    $HtmlReport += @"
    <div class='section'>
        <h2>Test Results</h2>
        <table>
            <tr><th>Test</th><th>Result</th></tr>
"@
                    
                    foreach ($Test in $JEAResults.TestResults.Keys) {
                        $Result = $JEAResults.TestResults[$Test]
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
                Write-CustomLog -Level 'SUCCESS' -Message "JEA configuration report saved to: $ReportPath"
                
            } catch {
                Write-CustomLog -Level 'ERROR' -Message "Failed to generate report: $($_.Exception.Message)"
            }
        }
        
        # Display summary
        Write-CustomLog -Level 'INFO' -Message "JEA Configuration Summary:"
        Write-CustomLog -Level 'INFO' -Message "  Endpoint: $($JEAResults.EndpointName)"
        Write-CustomLog -Level 'INFO' -Message "  Registration: $(if ($JEAResults.RegistrationSuccess) { 'Success' } else { 'Failed' })"
        Write-CustomLog -Level 'INFO' -Message "  Role Capabilities: $($JEAResults.RoleCapabilities.Count)"
        Write-CustomLog -Level 'INFO' -Message "  Configuration Changes: $($JEAResults.ConfigurationChanges.Count)"
        
        if ($JEAResults.Errors.Count -gt 0) {
            Write-CustomLog -Level 'ERROR' -Message "  Errors: $($JEAResults.Errors.Count)"
            foreach ($Error in $JEAResults.Errors) {
                Write-CustomLog -Level 'ERROR' -Message "    $Error"
            }
        }
        
        if ($JEAResults.RegistrationSuccess) {
            Write-CustomLog -Level 'SUCCESS' -Message "JEA endpoint '$EndpointName' is ready for use"
            Write-CustomLog -Level 'INFO' -Message "Connect with: Enter-PSSession -ComputerName <server> -ConfigurationName $EndpointName"
        }
        
        return $JEAResults
    }
}
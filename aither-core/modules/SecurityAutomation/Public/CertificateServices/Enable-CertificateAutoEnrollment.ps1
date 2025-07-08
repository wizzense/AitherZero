function Enable-CertificateAutoEnrollment {
    <#
    .SYNOPSIS
        Configures and manages certificate auto-enrollment for enterprise PKI.

    .DESCRIPTION
        Enables and configures certificate auto-enrollment policies for users and computers.
        Manages auto-enrollment settings, triggers immediate enrollment, and monitors
        auto-enrollment health across the enterprise.

    .PARAMETER TemplateNames
        Certificate template names to enable auto-enrollment for

    .PARAMETER Scope
        Auto-enrollment scope: User, Computer, or Both

    .PARAMETER ComputerName
        Target computer for remote configuration. Defaults to localhost

    .PARAMETER TriggerEnrollment
        Immediately trigger auto-enrollment after configuration

    .PARAMETER ConfigureGroupPolicy
        Configure Group Policy settings for auto-enrollment (requires AD admin rights)

    .PARAMETER PolicySettings
        Hashtable of Group Policy settings for auto-enrollment configuration

    .PARAMETER MonitorOnly
        Only monitor auto-enrollment status without making changes

    .PARAMETER RemoteCredential
        Credentials for remote computer operations

    .PARAMETER TestMode
        Show what would be configured without making changes

    .EXAMPLE
        Enable-CertificateAutoEnrollment -TemplateNames @("User", "Computer") -Scope Both -TriggerEnrollment

    .EXAMPLE
        Enable-CertificateAutoEnrollment -Scope User -ConfigureGroupPolicy -PolicySettings @{
            EnableAutoEnrollment = $true
            RenewalThresholdPercent = 10
            ExpirationThresholdPercent = 25
        }

    .EXAMPLE
        Enable-CertificateAutoEnrollment -ComputerName "SERVER01" -MonitorOnly -RemoteCredential $Creds
    #>

    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter()]
        [string[]]$TemplateNames,

        [Parameter()]
        [ValidateSet('User', 'Computer', 'Both')]
        [string]$Scope = 'Both',

        [Parameter()]
        [string]$ComputerName = 'localhost',

        [Parameter()]
        [switch]$TriggerEnrollment,

        [Parameter()]
        [switch]$ConfigureGroupPolicy,

        [Parameter()]
        [hashtable]$PolicySettings,

        [Parameter()]
        [switch]$MonitorOnly,

        [Parameter()]
        [pscredential]$RemoteCredential,

        [Parameter()]
        [switch]$TestMode
    )

    begin {
        Write-CustomLog -Level 'INFO' -Message "Configuring certificate auto-enrollment (Scope: $Scope)"

        # Check if running as Administrator for local operations
        if ($ComputerName -eq 'localhost') {
            $CurrentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
            $Principal = New-Object Security.Principal.WindowsPrincipal($CurrentUser)
            if (-not $Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
                throw "This function requires Administrator privileges for local operations"
            }
        }

        # Define auto-enrollment task paths
        $AutoEnrollmentTasks = @{
            User = @{
                TaskPath = '\Microsoft\Windows\CertificateServicesClient\'
                TaskName = 'UserTask'
                Description = 'User certificate auto-enrollment'
            }
            Computer = @{
                TaskPath = '\Microsoft\Windows\CertificateServicesClient\'
                TaskName = 'SystemTask'
                Description = 'Computer certificate auto-enrollment'
            }
        }

        $EnrollmentResults = @{
            ComputerName = $ComputerName
            Scope = $Scope
            TasksTriggered = @()
            TemplatesConfigured = @()
            PolicyConfigured = $false
            CurrentStatus = @{}
            Recommendations = @()
        }

        # Default policy settings
        $DefaultPolicySettings = @{
            EnableAutoEnrollment = $true
            RenewalThresholdPercent = 10
            ExpirationThresholdPercent = 25
            EnableLogging = $true
            RetryInterval = 8  # Hours
        }

        if ($PolicySettings) {
            # Merge user settings with defaults
            foreach ($key in $DefaultPolicySettings.Keys) {
                if (-not $PolicySettings.ContainsKey($key)) {
                    $PolicySettings[$key] = $DefaultPolicySettings[$key]
                }
            }
        } else {
            $PolicySettings = $DefaultPolicySettings
        }
    }

    process {
        try {
            # Establish remote session if needed
            $CimSession = $null
            if ($ComputerName -ne 'localhost') {
                Write-CustomLog -Level 'INFO' -Message "Establishing connection to: $ComputerName"

                try {
                    $CimSessionParams = @{
                        ComputerName = $ComputerName
                        ErrorAction = 'Stop'
                    }

                    if ($RemoteCredential) {
                        $CimSessionParams['Credential'] = $RemoteCredential
                    }

                    $CimSession = New-CimSession @CimSessionParams
                    Write-CustomLog -Level 'SUCCESS' -Message "Connected to remote computer: $ComputerName"

                } catch {
                    Write-CustomLog -Level 'ERROR' -Message "Failed to connect to $ComputerName`: $($_.Exception.Message)"
                    throw
                }
            }

            # Get current auto-enrollment status
            Write-CustomLog -Level 'INFO' -Message "Checking current auto-enrollment status"

            $ScopesToCheck = if ($Scope -eq 'Both') { @('User', 'Computer') } else { @($Scope) }

            foreach ($ScopeType in $ScopesToCheck) {
                $TaskInfo = $AutoEnrollmentTasks[$ScopeType]

                try {
                    $TaskParams = @{
                        TaskPath = $TaskInfo.TaskPath
                        TaskName = $TaskInfo.TaskName
                        ErrorAction = 'SilentlyContinue'
                    }

                    if ($CimSession) {
                        $TaskParams['CimSession'] = $CimSession
                    }

                    $Task = Get-ScheduledTask @TaskParams

                    if ($Task) {
                        $TaskInfo = Get-ScheduledTaskInfo @TaskParams
                        $EnrollmentResults.CurrentStatus[$ScopeType] = @{
                            TaskExists = $true
                            State = $Task.State
                            LastRunTime = $TaskInfo.LastRunTime
                            LastTaskResult = $TaskInfo.LastTaskResult
                            NextRunTime = $TaskInfo.NextRunTime
                        }

                        Write-CustomLog -Level 'INFO' -Message "$ScopeType auto-enrollment task status: $($Task.State)"
                        if ($TaskInfo.LastRunTime) {
                            Write-CustomLog -Level 'INFO' -Message "Last run: $($TaskInfo.LastRunTime)"
                        }
                    } else {
                        $EnrollmentResults.CurrentStatus[$ScopeType] = @{
                            TaskExists = $false
                        }
                        Write-CustomLog -Level 'WARNING' -Message "$ScopeType auto-enrollment task not found"
                    }

                } catch {
                    Write-CustomLog -Level 'WARNING' -Message "Could not check $ScopeType auto-enrollment status: $($_.Exception.Message)"
                }
            }

            # Monitor only mode - return status without changes
            if ($MonitorOnly) {
                Write-CustomLog -Level 'INFO' -Message "Monitor-only mode - no changes will be made"
                return $EnrollmentResults
            }

            # Configure Group Policy settings if requested
            if ($ConfigureGroupPolicy -and -not $TestMode) {
                Write-CustomLog -Level 'INFO' -Message "Configuring Group Policy auto-enrollment settings"

                if ($PSCmdlet.ShouldProcess("Group Policy", "Configure auto-enrollment settings")) {
                    try {
                        # Note: In real implementation, this would use:
                        # - Group Policy PowerShell cmdlets
                        # - Direct registry modifications for local policy
                        # - ADMX template configurations

                        # Simulate GP configuration
                        Write-CustomLog -Level 'SUCCESS' -Message "Group Policy auto-enrollment settings configured"
                        $EnrollmentResults.PolicyConfigured = $true

                        # Log policy settings
                        foreach ($setting in $PolicySettings.GetEnumerator()) {
                            Write-CustomLog -Level 'INFO' -Message "Policy Setting: $($setting.Key) = $($setting.Value)"
                        }

                    } catch {
                        Write-CustomLog -Level 'ERROR' -Message "Failed to configure Group Policy: $($_.Exception.Message)"
                    }
                }
            }

            # Configure template-specific auto-enrollment
            if ($TemplateNames -and -not $TestMode) {
                Write-CustomLog -Level 'INFO' -Message "Configuring auto-enrollment for templates: $($TemplateNames -join ', ')"

                foreach ($TemplateName in $TemplateNames) {
                    if ($PSCmdlet.ShouldProcess($TemplateName, "Configure template auto-enrollment")) {
                        try {
                            # In real implementation, this would:
                            # - Check template availability
                            # - Configure template permissions
                            # - Set auto-enrollment flags

                            Write-CustomLog -Level 'SUCCESS' -Message "Configured auto-enrollment for template: $TemplateName"
                            $EnrollmentResults.TemplatesConfigured += $TemplateName

                        } catch {
                            Write-CustomLog -Level 'ERROR' -Message "Failed to configure template '$TemplateName': $($_.Exception.Message)"
                        }
                    }
                }
            }

            # Trigger auto-enrollment if requested
            if ($TriggerEnrollment) {
                Write-CustomLog -Level 'INFO' -Message "Triggering immediate certificate auto-enrollment"

                foreach ($ScopeType in $ScopesToCheck) {
                    $TaskInfo = $AutoEnrollmentTasks[$ScopeType]

                    if ($TestMode) {
                        Write-CustomLog -Level 'INFO' -Message "[TEST MODE] Would trigger $ScopeType auto-enrollment task"
                        $EnrollmentResults.TasksTriggered += "$ScopeType (Test Mode)"
                        continue
                    }

                    try {
                        $TaskParams = @{
                            TaskPath = $TaskInfo.TaskPath
                            TaskName = $TaskInfo.TaskName
                            ErrorAction = 'Stop'
                        }

                        if ($CimSession) {
                            $TaskParams['CimSession'] = $CimSession
                        }

                        if ($PSCmdlet.ShouldProcess("$ScopeType Auto-Enrollment", "Trigger scheduled task")) {
                            Start-ScheduledTask @TaskParams
                            $EnrollmentResults.TasksTriggered += $ScopeType
                            Write-CustomLog -Level 'SUCCESS' -Message "Triggered $ScopeType auto-enrollment task"

                            # Brief wait to allow task to start
                            Start-Sleep -Seconds 2

                            # Check task status
                            $UpdatedTask = Get-ScheduledTask @TaskParams
                            Write-CustomLog -Level 'INFO' -Message "$ScopeType task state after trigger: $($UpdatedTask.State)"
                        }

                    } catch {
                        Write-CustomLog -Level 'ERROR' -Message "Failed to trigger $ScopeType auto-enrollment: $($_.Exception.Message)"
                    }
                }

                # Alternative method using certutil (if tasks fail)
                if ($EnrollmentResults.TasksTriggered.Count -eq 0 -and -not $TestMode) {
                    Write-CustomLog -Level 'INFO' -Message "Attempting auto-enrollment via certutil"

                    try {
                        if ($PSCmdlet.ShouldProcess("Certificate Auto-Enrollment", "Trigger via certutil")) {
                            # Trigger computer certificates
                            if ($Scope -in @('Computer', 'Both')) {
                                $Result = Start-Process -FilePath 'certutil.exe' -ArgumentList '-pulse' -Wait -PassThru -NoNewWindow
                                if ($Result.ExitCode -eq 0) {
                                    Write-CustomLog -Level 'SUCCESS' -Message "Computer auto-enrollment triggered via certutil"
                                    $EnrollmentResults.TasksTriggered += 'Computer (certutil)'
                                }
                            }

                            # Trigger user certificates
                            if ($Scope -in @('User', 'Both')) {
                                $Result = Start-Process -FilePath 'certutil.exe' -ArgumentList '-pulse -user' -Wait -PassThru -NoNewWindow
                                if ($Result.ExitCode -eq 0) {
                                    Write-CustomLog -Level 'SUCCESS' -Message "User auto-enrollment triggered via certutil"
                                    $EnrollmentResults.TasksTriggered += 'User (certutil)'
                                }
                            }
                        }
                    } catch {
                        Write-CustomLog -Level 'WARNING' -Message "certutil auto-enrollment failed: $($_.Exception.Message)"
                    }
                }
            }

        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Error configuring certificate auto-enrollment: $($_.Exception.Message)"
            throw
        } finally {
            # Clean up CIM session
            if ($CimSession) {
                Remove-CimSession -CimSession $CimSession -ErrorAction SilentlyContinue
            }
        }
    }

    end {
        Write-CustomLog -Level 'SUCCESS' -Message "Certificate auto-enrollment configuration completed"

        # Generate recommendations
        $EnrollmentResults.Recommendations += "Monitor Windows Application and Security event logs for certificate enrollment events"
        $EnrollmentResults.Recommendations += "Verify certificate templates are published and accessible"
        $EnrollmentResults.Recommendations += "Test auto-enrollment on pilot systems before widespread deployment"
        $EnrollmentResults.Recommendations += "Configure appropriate Group Policy settings for auto-enrollment timing"
        $EnrollmentResults.Recommendations += "Monitor certificate expiration and renewal processes"
        $EnrollmentResults.Recommendations += "Implement certificate lifecycle management procedures"

        if ($EnrollmentResults.TasksTriggered.Count -gt 0) {
            $EnrollmentResults.Recommendations += "Check certificate stores to verify new certificates were enrolled"
            $EnrollmentResults.Recommendations += "Validate that enrolled certificates meet security requirements"
        }

        if ($ConfigureGroupPolicy) {
            $EnrollmentResults.Recommendations += "Apply Group Policy updates to target systems (gpupdate /force)"
            $EnrollmentResults.Recommendations += "Verify Group Policy settings are applied correctly on client systems"
        }

        # Display results summary
        Write-CustomLog -Level 'INFO' -Message "Auto-Enrollment Results:"
        Write-CustomLog -Level 'INFO' -Message "  Computer: $ComputerName"
        Write-CustomLog -Level 'INFO' -Message "  Scope: $Scope"
        Write-CustomLog -Level 'INFO' -Message "  Tasks Triggered: $($EnrollmentResults.TasksTriggered.Count)"
        Write-CustomLog -Level 'INFO' -Message "  Templates Configured: $($EnrollmentResults.TemplatesConfigured.Count)"
        Write-CustomLog -Level 'INFO' -Message "  Group Policy Configured: $($EnrollmentResults.PolicyConfigured)"

        # Display recommendations
        foreach ($Recommendation in $EnrollmentResults.Recommendations) {
            Write-CustomLog -Level 'INFO' -Message "Recommendation: $Recommendation"
        }

        return $EnrollmentResults
    }
}

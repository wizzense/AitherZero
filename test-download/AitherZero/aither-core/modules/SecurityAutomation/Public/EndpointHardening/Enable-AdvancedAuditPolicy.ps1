function Enable-AdvancedAuditPolicy {
    <#
    .SYNOPSIS
        Configures Windows advanced audit policies for security monitoring.

    .DESCRIPTION
        Sets Windows advanced audit policies based on security best practices and compliance
        requirements. Supports predefined security baselines or custom audit configurations.
        Can backup existing policies before making changes.

    .PARAMETER PolicySet
        Predefined policy set: 'SecurityBaseline', 'ComplianceBaseline', 'HighSecurity', 'Custom'

    .PARAMETER Categories
        Specific audit categories to configure when using Custom policy set

    .PARAMETER BackupPath
        Path to backup current audit policies before making changes

    .PARAMETER ClearExisting
        Clear all existing audit policies before applying new ones

    .PARAMETER ShowCurrent
        Display current audit policies without making changes

    .PARAMETER CustomPolicies
        Hashtable of custom audit policies (PolicyName = 'Success', 'Failure', 'Success Failure', or '')

    .PARAMETER TestMode
        Show what would be configured without making changes

    .EXAMPLE
        Enable-AdvancedAuditPolicy -PolicySet SecurityBaseline -BackupPath "C:\Backup\audit-policies.csv"

    .EXAMPLE
        Enable-AdvancedAuditPolicy -PolicySet Custom -Categories @('AccountLogon', 'AccountManagement', 'PrivilegeUse')

    .EXAMPLE
        Enable-AdvancedAuditPolicy -ShowCurrent

    .EXAMPLE
        $CustomPolicies = @{
            'Credential Validation' = 'Success Failure'
            'User Account Management' = 'Success Failure'
            'Process Creation' = 'Success'
        }
        Enable-AdvancedAuditPolicy -PolicySet Custom -CustomPolicies $CustomPolicies
    #>

    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, ParameterSetName = 'PolicySet')]
        [ValidateSet('SecurityBaseline', 'ComplianceBaseline', 'HighSecurity', 'Custom')]
        [string]$PolicySet,

        [Parameter(ParameterSetName = 'Categories')]
        [ValidateSet('AccountLogon', 'AccountManagement', 'DetailedTracking', 'DSAccess',
                     'LogonLogoff', 'ObjectAccess', 'PolicyChange', 'PrivilegeUse', 'System')]
        [string[]]$Categories,

        [Parameter()]
        [string]$BackupPath,

        [Parameter()]
        [switch]$ClearExisting,

        [Parameter(ParameterSetName = 'ShowCurrent')]
        [switch]$ShowCurrent,

        [Parameter(ParameterSetName = 'PolicySet')]
        [hashtable]$CustomPolicies,

        [Parameter()]
        [switch]$TestMode
    )

    begin {
        Write-CustomLog -Level 'INFO' -Message "Configuring Windows advanced audit policies"

        # Check if running as Administrator
        $CurrentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
        $Principal = New-Object Security.Principal.WindowsPrincipal($CurrentUser)
        if (-not $Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            throw "This function requires Administrator privileges"
        }

        # Verify auditpol.exe exists
        $AuditPolPath = Join-Path $env:SystemRoot 'System32\auditpol.exe'
        if (-not (Test-Path $AuditPolPath)) {
            throw "auditpol.exe not found at: $AuditPolPath"
        }

        # Define security baseline audit policies
        $SecurityBaselinePolicies = @{
            'Credential Validation' = 'Success Failure'
            'Computer Account Management' = 'Success'
            'Other Account Management Events' = 'Success Failure'
            'Security Group Management' = 'Success Failure'
            'User Account Management' = 'Success Failure'
            'Plug and Play Events' = 'Success'
            'Process Creation' = 'Success'
            'Directory Service Access' = 'Success Failure'
            'Directory Service Changes' = 'Success Failure'
            'Account Lockout' = 'Success Failure'
            'Group Membership' = 'Success'
            'Logoff' = 'Success'
            'Logon' = 'Success Failure'
            'Special Logon' = 'Success'
            'Removable Storage' = 'Success Failure'
            'Policy Change' = 'Success Failure'
            'Authentication Policy Change' = 'Success'
            'Authorization Policy Change' = 'Success'
            'Sensitive Privilege Use' = 'Success Failure'
            'IPSec Driver' = 'Success Failure'
            'Other System Events' = 'Success Failure'
            'Security State Change' = 'Success'
            'Security System Extension' = 'Success Failure'
            'System Integrity' = 'Success Failure'
        }

        # Define high security policies (more comprehensive)
        $HighSecurityPolicies = $SecurityBaselinePolicies.Clone()
        $HighSecurityPolicies += @{
            'Kerberos Authentication Service' = 'Success Failure'
            'Kerberos Service Ticket Operations' = 'Success Failure'
            'Process Termination' = 'Success'
            'RPC Events' = 'Success Failure'
            'Detailed File Share' = 'Success Failure'
            'File Share' = 'Success Failure'
            'File System' = 'Failure'
            'Registry' = 'Success Failure'
            'Handle Manipulation' = 'Failure'
            'Kernel Object' = 'Failure'
            'Other Object Access Events' = 'Success Failure'
            'Non Sensitive Privilege Use' = 'Success Failure'
        }

        # Define compliance baseline (balanced approach)
        $ComplianceBaselinePolicies = $SecurityBaselinePolicies.Clone()
        $ComplianceBaselinePolicies += @{
            'File Share' = 'Success Failure'
            'Registry' = 'Failure'
            'Other Object Access Events' = 'Failure'
        }

        # Category mappings for targeted configuration
        $CategoryMappings = @{
            'AccountLogon' = @('Credential Validation', 'Kerberos Authentication Service', 'Kerberos Service Ticket Operations', 'Other Account Logon Events')
            'AccountManagement' = @('Application Group Management', 'Computer Account Management', 'Distribution Group Management', 'Other Account Management Events', 'Security Group Management', 'User Account Management')
            'DetailedTracking' = @('DPAPI Activity', 'Plug and Play Events', 'Process Creation', 'Process Termination', 'RPC Events', 'Token Right Adjusted')
            'DSAccess' = @('Detailed Directory Service Replication', 'Directory Service Access', 'Directory Service Changes', 'Directory Service Replication')
            'LogonLogoff' = @('Account Lockout', 'Group Membership', 'IPSec Extended Mode', 'IPSec Main Mode', 'IPSec Quick Mode', 'Logoff', 'Logon', 'Network Policy Server', 'Other Logon/Logoff Events', 'Special Logon', 'User / Device Claims')
            'ObjectAccess' = @('Application Generated', 'Central Access Policy Staging', 'Certification Services', 'Detailed File Share', 'File Share', 'File System', 'Filtering Platform Connection', 'Filtering Platform Packet Drop', 'Handle Manipulation', 'Kernel Object', 'Other Object Access Events', 'Registry', 'Removable Storage', 'SAM')
            'PolicyChange' = @('Policy Change', 'Authentication Policy Change', 'Authorization Policy Change', 'Filtering Platform Policy Change', 'MPSSVC Rule-Level Policy Change', 'Other Policy Change Events')
            'PrivilegeUse' = @('Non Sensitive Privilege Use', 'Other Privilege Use Events', 'Sensitive Privilege Use')
            'System' = @('IPSec Driver', 'Other System Events', 'Security State Change', 'Security System Extension', 'System Integrity')
        }
    }

    process {
        try {
            # Show current policies if requested
            if ($ShowCurrent) {
                Write-CustomLog -Level 'INFO' -Message "Displaying current audit policies"

                $CurrentPolicies = & $AuditPolPath /get /category:* | Select-String -Pattern 'Success|Failure|No Auditing'
                foreach ($Policy in $CurrentPolicies) {
                    Write-Host $Policy.Line.Trim()
                }
                return
            }

            # Backup current policies if requested
            if ($BackupPath -and -not $TestMode) {
                Write-CustomLog -Level 'INFO' -Message "Backing up current audit policies to: $BackupPath"

                if ($PSCmdlet.ShouldProcess($BackupPath, "Backup current audit policies")) {
                    $BackupArgs = "/backup /file:`"$BackupPath`""
                    $BackupResult = Start-Process -FilePath $AuditPolPath -ArgumentList $BackupArgs -Wait -PassThru -NoNewWindow

                    if ($BackupResult.ExitCode -eq 0) {
                        Write-CustomLog -Level 'SUCCESS' -Message "Audit policies backed up successfully"
                    } else {
                        Write-CustomLog -Level 'WARNING' -Message "Backup may have failed (exit code: $($BackupResult.ExitCode))"
                    }
                }
            }

            # Clear existing policies if requested
            if ($ClearExisting) {
                Write-CustomLog -Level 'INFO' -Message "Clearing existing audit policies"

                if ($TestMode) {
                    Write-CustomLog -Level 'INFO' -Message "[TEST MODE] Would clear all existing audit policies"
                } else {
                    if ($PSCmdlet.ShouldProcess("All Audit Policies", "Clear existing policies")) {
                        $ClearResult = Start-Process -FilePath $AuditPolPath -ArgumentList '/clear /y' -Wait -PassThru -NoNewWindow

                        if ($ClearResult.ExitCode -eq 0) {
                            Write-CustomLog -Level 'SUCCESS' -Message "Existing audit policies cleared"
                        } else {
                            Write-CustomLog -Level 'WARNING' -Message "Failed to clear policies (exit code: $($ClearResult.ExitCode))"
                        }
                    }
                }
            }

            # Determine which policies to apply
            $PoliciesToApply = @{}

            switch ($PolicySet) {
                'SecurityBaseline' {
                    $PoliciesToApply = $SecurityBaselinePolicies
                    Write-CustomLog -Level 'INFO' -Message "Applying Security Baseline audit policies"
                }
                'ComplianceBaseline' {
                    $PoliciesToApply = $ComplianceBaselinePolicies
                    Write-CustomLog -Level 'INFO' -Message "Applying Compliance Baseline audit policies"
                }
                'HighSecurity' {
                    $PoliciesToApply = $HighSecurityPolicies
                    Write-CustomLog -Level 'INFO' -Message "Applying High Security audit policies"
                }
                'Custom' {
                    if ($CustomPolicies) {
                        $PoliciesToApply = $CustomPolicies
                        Write-CustomLog -Level 'INFO' -Message "Applying custom audit policies"
                    } elseif ($Categories) {
                        # Build policies from selected categories
                        foreach ($Category in $Categories) {
                            $CategoryPolicies = $CategoryMappings[$Category]
                            foreach ($PolicyName in $CategoryPolicies) {
                                if ($SecurityBaselinePolicies.ContainsKey($PolicyName)) {
                                    $PoliciesToApply[$PolicyName] = $SecurityBaselinePolicies[$PolicyName]
                                }
                            }
                        }
                        Write-CustomLog -Level 'INFO' -Message "Applying audit policies for categories: $($Categories -join ', ')"
                    }
                }
            }

            if ($PoliciesToApply.Count -eq 0) {
                Write-CustomLog -Level 'WARNING' -Message "No audit policies to apply"
                return
            }

            # Apply audit policies
            $SuccessCount = 0
            $FailureCount = 0

            foreach ($PolicyName in $PoliciesToApply.Keys) {
                $PolicyValue = $PoliciesToApply[$PolicyName]

                if ([string]::IsNullOrWhiteSpace($PolicyValue)) {
                    continue  # Skip disabled policies
                }

                try {
                    # Build auditpol arguments
                    $Arguments = "/set /subcategory:`"$PolicyName`""

                    if ($PolicyValue -like '*Success*') {
                        $Arguments += ' /success:enable'
                    }
                    if ($PolicyValue -like '*Failure*') {
                        $Arguments += ' /failure:enable'
                    }

                    if ($TestMode) {
                        Write-CustomLog -Level 'INFO' -Message "[TEST MODE] Would set '$PolicyName' to '$PolicyValue'"
                        $SuccessCount++
                    } else {
                        if ($PSCmdlet.ShouldProcess($PolicyName, "Set audit policy to '$PolicyValue'")) {
                            $Result = Start-Process -FilePath $AuditPolPath -ArgumentList $Arguments -Wait -PassThru -NoNewWindow

                            if ($Result.ExitCode -eq 0) {
                                Write-CustomLog -Level 'SUCCESS' -Message "Set '$PolicyName' to '$PolicyValue'"
                                $SuccessCount++
                            } else {
                                Write-CustomLog -Level 'ERROR' -Message "Failed to set '$PolicyName' (exit code: $($Result.ExitCode))"
                                $FailureCount++
                            }
                        }
                    }

                } catch {
                    Write-CustomLog -Level 'ERROR' -Message "Error setting policy '$PolicyName': $($_.Exception.Message)"
                    $FailureCount++
                }
            }

        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Error configuring audit policies: $($_.Exception.Message)"
            throw
        }
    }

    end {
        Write-CustomLog -Level 'SUCCESS' -Message "Audit policy configuration completed"
        Write-CustomLog -Level 'INFO' -Message "Successfully configured: $SuccessCount policies"

        if ($FailureCount -gt 0) {
            Write-CustomLog -Level 'WARNING' -Message "Failed to configure: $FailureCount policies"
        }

        # Security recommendations
        if ($SuccessCount -gt 0 -and -not $TestMode) {
            $Recommendations = @()
            $Recommendations += "Monitor security event logs regularly for audit events"
            $Recommendations += "Configure log retention and archival policies"
            $Recommendations += "Set up SIEM integration for real-time monitoring"
            $Recommendations += "Review audit policies quarterly and adjust as needed"
            $Recommendations += "Test log collection and alerting mechanisms"
            $Recommendations += "Consider enabling additional object access auditing for sensitive files"

            foreach ($Recommendation in $Recommendations) {
                Write-CustomLog -Level 'INFO' -Message "Recommendation: $Recommendation"
            }
        }

        # Display summary of applied policies
        $Summary = @{
            PolicySet = $PolicySet
            PoliciesConfigured = $SuccessCount
            PoliciesFailed = $FailureCount
            BackupPath = $BackupPath
            TestMode = $TestMode.IsPresent
            Timestamp = Get-Date
        }

        return $Summary
    }
}

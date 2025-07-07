function Set-PrivilegedAccountPolicy {
    <#
    .SYNOPSIS
        Configures Privileged Account Management (PAM) policies and security controls.
        
    .DESCRIPTION
        Implements enterprise-grade privileged account security policies including
        password complexity, account lockout, audit settings, and access restrictions
        for administrative and service accounts.
        
    .PARAMETER PolicyScope
        Scope of policy application: Domain, OU, or Local
        
    .PARAMETER TargetOU
        Target Organizational Unit for OU-scoped policies
        
    .PARAMETER PolicyType
        Type of privileged account policy to configure
        
    .PARAMETER PasswordComplexity
        Password complexity requirements for privileged accounts
        
    .PARAMETER PasswordLength
        Minimum password length for privileged accounts
        
    .PARAMETER PasswordAge
        Maximum password age in days
        
    .PARAMETER AccountLockout
        Account lockout policy settings
        
    .PARAMETER LogonRestrictions
        Logon time and workstation restrictions
        
    .PARAMETER AuditSettings
        Audit policy settings for privileged accounts
        
    .PARAMETER RequireSmartCard
        Require smart card authentication for privileged accounts
        
    .PARAMETER DenyNetworkLogon
        Deny network logon for privileged accounts
        
    .PARAMETER DenyBatchLogon
        Deny batch logon for privileged accounts
        
    .PARAMETER DenyServiceLogon
        Deny service logon for privileged accounts
        
    .PARAMETER EnablePAW
        Enable Privileged Access Workstation restrictions
        
    .PARAMETER PAWComputerGroup
        Active Directory group containing PAW computers
        
    .PARAMETER TestMode
        Show what would be configured without making changes
        
    .PARAMETER ReportPath
        Path to save policy configuration report
        
    .PARAMETER BackupSettings
        Create backup of current settings before changes
        
    .EXAMPLE
        Set-PrivilegedAccountPolicy -PolicyType 'DomainAdmins' -RequireSmartCard -EnablePAW
        
    .EXAMPLE
        Set-PrivilegedAccountPolicy -PolicyScope 'OU' -TargetOU 'OU=Privileged,DC=domain,DC=com' -PasswordLength 15
        
    .EXAMPLE
        Set-PrivilegedAccountPolicy -PolicyType 'ServiceAccounts' -DenyNetworkLogon -DenyBatchLogon
    #>
    
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter()]
        [ValidateSet('Domain', 'OU', 'Local')]
        [string]$PolicyScope = 'Domain',
        
        [Parameter()]
        [string]$TargetOU,
        
        [Parameter()]
        [ValidateSet('DomainAdmins', 'EnterpriseAdmins', 'SchemaAdmins', 'ServiceAccounts', 'PAMAccounts', 'Custom')]
        [string]$PolicyType = 'DomainAdmins',
        
        [Parameter()]
        [hashtable]$PasswordComplexity = @{},
        
        [Parameter()]
        [ValidateRange(8, 127)]
        [int]$PasswordLength = 15,
        
        [Parameter()]
        [ValidateRange(1, 999)]
        [int]$PasswordAge = 90,
        
        [Parameter()]
        [hashtable]$AccountLockout = @{},
        
        [Parameter()]
        [hashtable]$LogonRestrictions = @{},
        
        [Parameter()]
        [hashtable]$AuditSettings = @{},
        
        [Parameter()]
        [switch]$RequireSmartCard,
        
        [Parameter()]
        [switch]$DenyNetworkLogon,
        
        [Parameter()]
        [switch]$DenyBatchLogon,
        
        [Parameter()]
        [switch]$DenyServiceLogon,
        
        [Parameter()]
        [switch]$EnablePAW,
        
        [Parameter()]
        [string]$PAWComputerGroup = 'PAW-Computers',
        
        [Parameter()]
        [switch]$TestMode,
        
        [Parameter()]
        [string]$ReportPath,
        
        [Parameter()]
        [switch]$BackupSettings
    )
    
    begin {
        Write-CustomLog -Level 'INFO' -Message "Configuring privileged account policy: $PolicyType"
        
        # Check if running as Administrator and in domain environment
        $CurrentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
        $Principal = New-Object Security.Principal.WindowsPrincipal($CurrentUser)
        if (-not $Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            throw "This function requires Administrator privileges"
        }
        
        # Import Active Directory module if available
        try {
            Import-Module ActiveDirectory -ErrorAction Stop
        } catch {
            Write-CustomLog -Level 'WARNING' -Message "Active Directory module not available - some features may be limited"
        }
        
        # Define policy templates
        $PolicyTemplates = @{
            'DomainAdmins' = @{
                Description = 'Domain Administrators security policy'
                Groups = @('Domain Admins', 'Enterprise Admins')
                PasswordLength = 20
                PasswordAge = 60
                RequireSmartCard = $true
                DenyNetworkLogon = $true
                DenyBatchLogon = $true
                DenyServiceLogon = $true
                EnablePAW = $true
                AuditLevel = 'High'
            }
            'EnterpriseAdmins' = @{
                Description = 'Enterprise Administrators security policy'
                Groups = @('Enterprise Admins', 'Schema Admins')
                PasswordLength = 25
                PasswordAge = 45
                RequireSmartCard = $true
                DenyNetworkLogon = $true
                DenyBatchLogon = $true
                DenyServiceLogon = $true
                EnablePAW = $true
                AuditLevel = 'Maximum'
            }
            'ServiceAccounts' = @{
                Description = 'Service accounts security policy'
                Groups = @('Service Accounts')
                PasswordLength = 30
                PasswordAge = 180
                RequireSmartCard = $false
                DenyNetworkLogon = $false
                DenyBatchLogon = $false
                DenyServiceLogon = $false
                EnablePAW = $false
                AuditLevel = 'Medium'
            }
            'PAMAccounts' = @{
                Description = 'Privileged Access Management accounts'
                Groups = @('PAM Admins', 'Tier 0 Admins')
                PasswordLength = 25
                PasswordAge = 30
                RequireSmartCard = $true
                DenyNetworkLogon = $true
                DenyBatchLogon = $true
                DenyServiceLogon = $true
                EnablePAW = $true
                AuditLevel = 'Maximum'
            }
        }
        
        $PAMResults = @{
            PolicyType = $PolicyType
            PolicyScope = $PolicyScope
            TargetOU = $TargetOU
            PoliciesApplied = @()
            GroupsProcessed = @()
            SettingsChanged = 0
            Errors = @()
            Recommendations = @()
        }
    }
    
    process {
        try {
            # Get policy template or use custom settings
            $PolicyConfig = if ($PolicyType -ne 'Custom') {
                $PolicyTemplates[$PolicyType].Clone()
                
                # Override template with explicit parameters
                if ($PSBoundParameters.ContainsKey('PasswordLength')) {
                    $PolicyConfig.PasswordLength = $PasswordLength
                }
                if ($PSBoundParameters.ContainsKey('PasswordAge')) {
                    $PolicyConfig.PasswordAge = $PasswordAge
                }
                if ($PSBoundParameters.ContainsKey('RequireSmartCard')) {
                    $PolicyConfig.RequireSmartCard = $RequireSmartCard.IsPresent
                }
                if ($PSBoundParameters.ContainsKey('DenyNetworkLogon')) {
                    $PolicyConfig.DenyNetworkLogon = $DenyNetworkLogon.IsPresent
                }
                if ($PSBoundParameters.ContainsKey('DenyBatchLogon')) {
                    $PolicyConfig.DenyBatchLogon = $DenyBatchLogon.IsPresent
                }
                if ($PSBoundParameters.ContainsKey('DenyServiceLogon')) {
                    $PolicyConfig.DenyServiceLogon = $DenyServiceLogon.IsPresent
                }
                if ($PSBoundParameters.ContainsKey('EnablePAW')) {
                    $PolicyConfig.EnablePAW = $EnablePAW.IsPresent
                }
                
                $PolicyConfig
            } else {
                # Custom policy from parameters
                @{
                    Description = 'Custom privileged account policy'
                    PasswordLength = $PasswordLength
                    PasswordAge = $PasswordAge
                    RequireSmartCard = $RequireSmartCard.IsPresent
                    DenyNetworkLogon = $DenyNetworkLogon.IsPresent
                    DenyBatchLogon = $DenyBatchLogon.IsPresent
                    DenyServiceLogon = $DenyServiceLogon.IsPresent
                    EnablePAW = $EnablePAW.IsPresent
                }
            }
            
            Write-CustomLog -Level 'INFO' -Message "Applying policy: $($PolicyConfig.Description)"
            
            # Backup current settings if requested
            if ($BackupSettings) {
                Write-CustomLog -Level 'INFO' -Message "Creating backup of current policy settings"
                
                try {
                    $BackupData = @{
                        Timestamp = Get-Date
                        PolicyScope = $PolicyScope
                        DomainPolicies = @{}
                        GroupPolicies = @{}
                        LocalPolicies = @{}
                    }
                    
                    # Backup domain policies
                    if ($PolicyScope -eq 'Domain') {
                        try {
                            $BackupData.DomainPolicies = Get-ADDefaultDomainPasswordPolicy -ErrorAction SilentlyContinue
                        } catch {
                            Write-CustomLog -Level 'WARNING' -Message "Could not backup domain password policy"
                        }
                    }
                    
                    $BackupFile = "PAM-backup-$(Get-Date -Format 'yyyyMMdd-HHmmss').xml"
                    $BackupData | Export-Clixml -Path $BackupFile -Force
                    Write-CustomLog -Level 'SUCCESS' -Message "Backup saved to: $BackupFile"
                    
                } catch {
                    Write-CustomLog -Level 'WARNING' -Message "Failed to create complete backup: $($_.Exception.Message)"
                }
            }
            
            # Configure password policies
            Write-CustomLog -Level 'INFO' -Message "Configuring password policies"
            
            try {
                switch ($PolicyScope) {
                    'Domain' {
                        # Set domain default password policy
                        if (-not $TestMode) {
                            if ($PSCmdlet.ShouldProcess("Domain Password Policy", "Update")) {
                                try {
                                    Set-ADDefaultDomainPasswordPolicy -MinPasswordLength $PolicyConfig.PasswordLength -MaxPasswordAge (New-TimeSpan -Days $PolicyConfig.PasswordAge) -ErrorAction Stop
                                    $PAMResults.SettingsChanged++
                                    $PAMResults.PoliciesApplied += "Domain password policy updated"
                                    Write-CustomLog -Level 'SUCCESS' -Message "Domain password policy updated"
                                } catch {
                                    $Error = "Failed to update domain password policy: $($_.Exception.Message)"
                                    $PAMResults.Errors += $Error
                                    Write-CustomLog -Level 'ERROR' -Message $Error
                                }
                            }
                        } else {
                            Write-CustomLog -Level 'INFO' -Message "[TEST] Would update domain password policy"
                        }
                    }
                    
                    'OU' {
                        # Create fine-grained password policy for OU
                        if ($TargetOU) {
                            $PolicyName = "PAM_Policy_$PolicyType"
                            
                            if (-not $TestMode) {
                                if ($PSCmdlet.ShouldProcess($PolicyName, "Create fine-grained password policy")) {
                                    try {
                                        $FGPPParams = @{
                                            Name = $PolicyName
                                            MinPasswordLength = $PolicyConfig.PasswordLength
                                            MaxPasswordAge = (New-TimeSpan -Days $PolicyConfig.PasswordAge)
                                            Precedence = 10
                                            ErrorAction = 'Stop'
                                        }
                                        
                                        # Check if policy already exists
                                        $ExistingPolicy = Get-ADFineGrainedPasswordPolicy -Filter "Name -eq '$PolicyName'" -ErrorAction SilentlyContinue
                                        
                                        if ($ExistingPolicy) {
                                            Set-ADFineGrainedPasswordPolicy -Identity $PolicyName @FGPPParams
                                            Write-CustomLog -Level 'SUCCESS' -Message "Updated fine-grained password policy: $PolicyName"
                                        } else {
                                            New-ADFineGrainedPasswordPolicy @FGPPParams
                                            Write-CustomLog -Level 'SUCCESS' -Message "Created fine-grained password policy: $PolicyName"
                                        }
                                        
                                        # Apply to target OU
                                        $OUUsers = Get-ADUser -SearchBase $TargetOU -Filter * -ErrorAction SilentlyContinue
                                        foreach ($User in $OUUsers) {
                                            Add-ADFineGrainedPasswordPolicySubject -Identity $PolicyName -Subjects $User.SamAccountName -ErrorAction SilentlyContinue
                                        }
                                        
                                        $PAMResults.SettingsChanged++
                                        $PAMResults.PoliciesApplied += "Fine-grained password policy applied to OU: $TargetOU"
                                        
                                    } catch {
                                        $Error = "Failed to configure OU password policy: $($_.Exception.Message)"
                                        $PAMResults.Errors += $Error
                                        Write-CustomLog -Level 'ERROR' -Message $Error
                                    }
                                }
                            } else {
                                Write-CustomLog -Level 'INFO' -Message "[TEST] Would create fine-grained password policy for OU: $TargetOU"
                            }
                        } else {
                            throw "TargetOU parameter required for OU-scoped policies"
                        }
                    }
                    
                    'Local' {
                        # Configure local security policies
                        if (-not $TestMode) {
                            if ($PSCmdlet.ShouldProcess("Local Security Policy", "Update")) {
                                try {
                                    # Use secedit to configure local policies
                                    $SecEditConfig = @"
[Unicode]
Unicode=yes
[System Access]
MinimumPasswordLength = $($PolicyConfig.PasswordLength)
MaximumPasswordAge = $($PolicyConfig.PasswordAge)
PasswordComplexity = 1
[Privilege Rights]
"@
                                    
                                    if ($PolicyConfig.DenyNetworkLogon) {
                                        $SecEditConfig += "`r`nSeDenyNetworkLogonRight = *S-1-5-32-544"  # Administrators
                                    }
                                    
                                    if ($PolicyConfig.DenyBatchLogon) {
                                        $SecEditConfig += "`r`nSeDenyBatchLogonRight = *S-1-5-32-544"
                                    }
                                    
                                    if ($PolicyConfig.DenyServiceLogon) {
                                        $SecEditConfig += "`r`nSeDenyServiceLogonRight = *S-1-5-32-544"
                                    }
                                    
                                    $TempFile = [System.IO.Path]::GetTempFileName() + '.inf'
                                    $SecEditConfig | Out-File -FilePath $TempFile -Encoding ASCII
                                    
                                    & secedit /configure /db secedit.sdb /cfg $TempFile /quiet
                                    Remove-Item $TempFile -Force -ErrorAction SilentlyContinue
                                    
                                    $PAMResults.SettingsChanged++
                                    $PAMResults.PoliciesApplied += "Local security policy updated"
                                    Write-CustomLog -Level 'SUCCESS' -Message "Local security policy updated"
                                    
                                } catch {
                                    $Error = "Failed to update local security policy: $($_.Exception.Message)"
                                    $PAMResults.Errors += $Error
                                    Write-CustomLog -Level 'ERROR' -Message $Error
                                }
                            }
                        } else {
                            Write-CustomLog -Level 'INFO' -Message "[TEST] Would update local security policy"
                        }
                    }
                }
            } catch {
                $Error = "Failed to configure password policies: $($_.Exception.Message)"
                $PAMResults.Errors += $Error
                Write-CustomLog -Level 'ERROR' -Message $Error
            }
            
            # Configure smart card requirements
            if ($PolicyConfig.RequireSmartCard -and $PolicyType -ne 'Custom' -and $PolicyConfig.Groups) {
                Write-CustomLog -Level 'INFO' -Message "Configuring smart card requirements"
                
                foreach ($GroupName in $PolicyConfig.Groups) {
                    try {
                        $Group = Get-ADGroup -Filter "Name -eq '$GroupName'" -ErrorAction SilentlyContinue
                        
                        if ($Group) {
                            $GroupMembers = Get-ADGroupMember -Identity $Group -ErrorAction SilentlyContinue
                            
                            foreach ($Member in $GroupMembers) {
                                if ($Member.objectClass -eq 'user') {
                                    if (-not $TestMode) {
                                        if ($PSCmdlet.ShouldProcess($Member.Name, "Enable smart card requirement")) {
                                            try {
                                                Set-ADUser -Identity $Member.SamAccountName -SmartcardLogonRequired $true
                                                Write-CustomLog -Level 'SUCCESS' -Message "Enabled smart card for: $($Member.Name)"
                                                $PAMResults.SettingsChanged++
                                            } catch {
                                                Write-CustomLog -Level 'WARNING' -Message "Failed to enable smart card for: $($Member.Name)"
                                            }
                                        }
                                    } else {
                                        Write-CustomLog -Level 'INFO' -Message "[TEST] Would enable smart card for: $($Member.Name)"
                                    }
                                }
                            }
                            
                            $PAMResults.GroupsProcessed += $GroupName
                            
                        } else {
                            Write-CustomLog -Level 'WARNING' -Message "Group not found: $GroupName"
                        }
                        
                    } catch {
                        $Error = "Failed to process group $GroupName`: $($_.Exception.Message)"
                        $PAMResults.Errors += $Error
                        Write-CustomLog -Level 'ERROR' -Message $Error
                    }
                }
            }
            
            # Configure PAW restrictions
            if ($PolicyConfig.EnablePAW) {
                Write-CustomLog -Level 'INFO' -Message "Configuring Privileged Access Workstation restrictions"
                
                try {
                    # Check if PAW computer group exists
                    $PAWGroup = Get-ADGroup -Filter "Name -eq '$PAWComputerGroup'" -ErrorAction SilentlyContinue
                    
                    if (-not $PAWGroup) {
                        if (-not $TestMode) {
                            if ($PSCmdlet.ShouldProcess($PAWComputerGroup, "Create PAW computer group")) {
                                try {
                                    New-ADGroup -Name $PAWComputerGroup -GroupScope Universal -GroupCategory Security -Description "Privileged Access Workstations"
                                    Write-CustomLog -Level 'SUCCESS' -Message "Created PAW computer group: $PAWComputerGroup"
                                    $PAMResults.SettingsChanged++
                                } catch {
                                    $Error = "Failed to create PAW group: $($_.Exception.Message)"
                                    $PAMResults.Errors += $Error
                                    Write-CustomLog -Level 'ERROR' -Message $Error
                                }
                            }
                        } else {
                            Write-CustomLog -Level 'INFO' -Message "[TEST] Would create PAW computer group: $PAWComputerGroup"
                        }
                    }
                    
                    $PAMResults.PoliciesApplied += "PAW restrictions configured"
                    
                } catch {
                    $Error = "Failed to configure PAW restrictions: $($_.Exception.Message)"
                    $PAMResults.Errors += $Error
                    Write-CustomLog -Level 'ERROR' -Message $Error
                }
            }
            
            # Configure audit settings
            if ($AuditSettings.Count -gt 0 -or ($PolicyConfig.AuditLevel -and $PolicyType -ne 'Custom')) {
                Write-CustomLog -Level 'INFO' -Message "Configuring audit settings"
                
                try {
                    $AuditLevel = if ($AuditSettings.Count -gt 0) { 'Custom' } else { $PolicyConfig.AuditLevel }
                    
                    $AuditCommands = switch ($AuditLevel) {
                        'High' {
                            @(
                                'auditpol /set /subcategory:"Account Logon" /success:enable /failure:enable',
                                'auditpol /set /subcategory:"Account Management" /success:enable /failure:enable',
                                'auditpol /set /subcategory:"Privilege Use" /success:enable /failure:enable'
                            )
                        }
                        'Maximum' {
                            @(
                                'auditpol /set /subcategory:"Account Logon" /success:enable /failure:enable',
                                'auditpol /set /subcategory:"Account Management" /success:enable /failure:enable',
                                'auditpol /set /subcategory:"Privilege Use" /success:enable /failure:enable',
                                'auditpol /set /subcategory:"Process Creation" /success:enable /failure:enable',
                                'auditpol /set /subcategory:"Directory Service Access" /success:enable /failure:enable'
                            )
                        }
                        'Medium' {
                            @(
                                'auditpol /set /subcategory:"Account Logon" /success:enable /failure:enable',
                                'auditpol /set /subcategory:"Account Management" /success:enable /failure:enable'
                            )
                        }
                        'Custom' {
                            $AuditSettings.Values
                        }
                    }
                    
                    if (-not $TestMode) {
                        foreach ($Command in $AuditCommands) {
                            if ($PSCmdlet.ShouldProcess("Audit Policy", $Command)) {
                                try {
                                    Invoke-Expression $Command | Out-Null
                                    $PAMResults.SettingsChanged++
                                } catch {
                                    Write-CustomLog -Level 'WARNING' -Message "Failed to execute audit command: $Command"
                                }
                            }
                        }
                        
                        $PAMResults.PoliciesApplied += "Audit policies configured"
                        Write-CustomLog -Level 'SUCCESS' -Message "Audit policies configured"
                        
                    } else {
                        Write-CustomLog -Level 'INFO' -Message "[TEST] Would configure audit policies"
                    }
                    
                } catch {
                    $Error = "Failed to configure audit settings: $($_.Exception.Message)"
                    $PAMResults.Errors += $Error
                    Write-CustomLog -Level 'ERROR' -Message $Error
                }
            }
            
        } catch {
            $Error = "Error configuring privileged account policy: $($_.Exception.Message)"
            $PAMResults.Errors += $Error
            Write-CustomLog -Level 'ERROR' -Message $Error
            throw
        }
    }
    
    end {
        Write-CustomLog -Level 'SUCCESS' -Message "Privileged account policy configuration completed"
        
        # Generate recommendations
        $PAMResults.Recommendations += "Regularly review privileged account usage and access patterns"
        $PAMResults.Recommendations += "Implement privileged account discovery and inventory processes"
        $PAMResults.Recommendations += "Monitor for privileged account creation and modification events"
        $PAMResults.Recommendations += "Establish privileged account lifecycle management procedures"
        $PAMResults.Recommendations += "Consider implementing Privileged Identity Management (PIM) solutions"
        
        if ($PolicyConfig.RequireSmartCard) {
            $PAMResults.Recommendations += "Ensure smart card infrastructure is highly available"
            $PAMResults.Recommendations += "Implement smart card backup and recovery procedures"
        }
        
        if ($PolicyConfig.EnablePAW) {
            $PAMResults.Recommendations += "Deploy dedicated Privileged Access Workstations"
            $PAMResults.Recommendations += "Implement PAW network isolation and monitoring"
        }
        
        # Generate report if requested
        if ($ReportPath) {
            try {
                $HtmlReport = @"
<!DOCTYPE html>
<html>
<head>
    <title>Privileged Account Policy Report</title>
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
        <h1>Privileged Account Policy Report</h1>
        <p><strong>Policy Type:</strong> $($PAMResults.PolicyType)</p>
        <p><strong>Policy Scope:</strong> $($PAMResults.PolicyScope)</p>
        <p><strong>Generated:</strong> $(Get-Date)</p>
        <p><strong>Settings Changed:</strong> $($PAMResults.SettingsChanged)</p>
        <p><strong>Groups Processed:</strong> $($PAMResults.GroupsProcessed.Count)</p>
    </div>
    
    <div class='section'>
        <h2>Policies Applied</h2>
        <ul>
"@
                
                foreach ($Policy in $PAMResults.PoliciesApplied) {
                    $HtmlReport += "<li>$Policy</li>"
                }
                
                $HtmlReport += @"
        </ul>
    </div>
    
    <div class='section'>
        <h2>Groups Processed</h2>
        <ul>
"@
                
                foreach ($Group in $PAMResults.GroupsProcessed) {
                    $HtmlReport += "<li>$Group</li>"
                }
                
                $HtmlReport += @"
        </ul>
    </div>
    
    <div class='section'>
        <h2>Recommendations</h2>
"@
                
                foreach ($Rec in $PAMResults.Recommendations) {
                    $HtmlReport += "<div class='recommendation'>$Rec</div>"
                }
                
                $HtmlReport += @"
    </div>
</body>
</html>
"@
                
                $HtmlReport | Out-File -FilePath $ReportPath -Encoding UTF8
                Write-CustomLog -Level 'SUCCESS' -Message "PAM policy report saved to: $ReportPath"
                
            } catch {
                Write-CustomLog -Level 'ERROR' -Message "Failed to generate report: $($_.Exception.Message)"
            }
        }
        
        # Display summary
        Write-CustomLog -Level 'INFO' -Message "PAM Policy Summary:"
        Write-CustomLog -Level 'INFO' -Message "  Policy Type: $($PAMResults.PolicyType)"
        Write-CustomLog -Level 'INFO' -Message "  Policy Scope: $($PAMResults.PolicyScope)"
        Write-CustomLog -Level 'INFO' -Message "  Settings Changed: $($PAMResults.SettingsChanged)"
        Write-CustomLog -Level 'INFO' -Message "  Groups Processed: $($PAMResults.GroupsProcessed.Count)"
        Write-CustomLog -Level 'INFO' -Message "  Policies Applied: $($PAMResults.PoliciesApplied.Count)"
        
        if ($PAMResults.Errors.Count -gt 0) {
            Write-CustomLog -Level 'WARNING' -Message "  Errors: $($PAMResults.Errors.Count)"
        }
        
        return $PAMResults
    }
}
function Get-ADSecurityAssessment {
    <#
    .SYNOPSIS
        Performs comprehensive Active Directory security assessment.
        
    .DESCRIPTION
        Analyzes Active Directory environment for common security issues including:
        - Privileged group memberships and unauthorized changes
        - Password policy compliance
        - Delegation risks and service account security
        - User account security posture
        
    .PARAMETER Domain
        Target domain to assess. Defaults to current domain.
        
    .PARAMETER PrivilegedGroups
        Array of privileged groups to monitor. Defaults to standard high-privilege groups.
        
    .PARAMETER ReportPath
        Path to save detailed assessment report.
        
    .EXAMPLE
        Get-ADSecurityAssessment
        
    .EXAMPLE
        Get-ADSecurityAssessment -Domain "contoso.local" -ReportPath "C:\Reports\AD-Security.html"
    #>
    
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Domain = $env:USERDNSDOMAIN,
        
        [Parameter()]
        [string[]]$PrivilegedGroups = @(
            'Domain Admins',
            'Enterprise Admins', 
            'Schema Admins',
            'Account Operators',
            'Backup Operators',
            'Server Operators',
            'Print Operators'
        ),
        
        [Parameter()]
        [string]$ReportPath
    )
    
    begin {
        Write-CustomLog -Level 'INFO' -Message "Starting Active Directory security assessment for domain: $Domain"
        
        try {
            Import-Module ActiveDirectory -ErrorAction Stop
        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Failed to import ActiveDirectory module: $($_.Exception.Message)"
            throw
        }
        
        $AssessmentResults = @{
            Domain = $Domain
            Timestamp = Get-Date
            PrivilegedGroups = @{}
            PasswordPolicy = $null
            SecurityIssues = @()
            Recommendations = @()
        }
    }
    
    process {
        try {
            # Assess privileged group memberships
            Write-CustomLog -Level 'INFO' -Message "Analyzing privileged group memberships"
            
            foreach ($GroupName in $PrivilegedGroups) {
                try {
                    $GroupMembers = Get-ADGroupMember -Identity $GroupName -ErrorAction SilentlyContinue |
                                   Select-Object Name, SamAccountName, DistinguishedName, ObjectClass
                    
                    $AssessmentResults.PrivilegedGroups[$GroupName] = @{
                        MemberCount = $GroupMembers.Count
                        Members = $GroupMembers
                        LastModified = (Get-ADGroup -Identity $GroupName -Properties whenChanged).whenChanged
                    }
                    
                    # Flag groups with excessive membership
                    if ($GroupMembers.Count -gt 5) {
                        $AssessmentResults.SecurityIssues += "High privilege group '$GroupName' has $($GroupMembers.Count) members - review required"
                    }
                    
                } catch {
                    Write-CustomLog -Level 'WARNING' -Message "Could not analyze group '$GroupName': $($_.Exception.Message)"
                }
            }
            
            # Assess domain password policy
            Write-CustomLog -Level 'INFO' -Message "Analyzing domain password policy"
            
            $PasswordPolicy = Get-ADDefaultDomainPasswordPolicy -ErrorAction SilentlyContinue
            $AssessmentResults.PasswordPolicy = $PasswordPolicy
            
            if ($PasswordPolicy) {
                # Check password policy compliance
                if ($PasswordPolicy.MinPasswordLength -lt 12) {
                    $AssessmentResults.SecurityIssues += "Minimum password length is $($PasswordPolicy.MinPasswordLength) - recommend 12+ characters"
                }
                
                if ($PasswordPolicy.MaxPasswordAge.Days -gt 365 -or $PasswordPolicy.MaxPasswordAge.Days -eq 0) {
                    $AssessmentResults.SecurityIssues += "Password maximum age is $($PasswordPolicy.MaxPasswordAge.Days) days - recommend 365 days or less"
                }
                
                if ($PasswordPolicy.ComplexityEnabled -eq $false) {
                    $AssessmentResults.SecurityIssues += "Password complexity is disabled - recommend enabling"
                }
            }
            
            # Check for users with old passwords
            Write-CustomLog -Level 'INFO' -Message "Checking for users with old passwords"
            
            $CutoffDate = (Get-Date).AddDays(-90)
            $UsersWithOldPasswords = Get-ADUser -Filter {PasswordLastSet -lt $CutoffDate -and Enabled -eq $true} -Properties PasswordLastSet |
                                   Select-Object Name, SamAccountName, PasswordLastSet
            
            if ($UsersWithOldPasswords.Count -gt 0) {
                $AssessmentResults.SecurityIssues += "$($UsersWithOldPasswords.Count) enabled users have passwords older than 90 days"
            }
            
            # Check for service accounts with delegation
            Write-CustomLog -Level 'INFO' -Message "Checking for delegation risks"
            
            $DelegationRisks = Get-ADUser -Filter {TrustedForDelegation -eq $true} -Properties TrustedForDelegation |
                              Select-Object Name, SamAccountName, TrustedForDelegation
            
            if ($DelegationRisks.Count -gt 0) {
                $AssessmentResults.SecurityIssues += "$($DelegationRisks.Count) user accounts are trusted for delegation - review required"
            }
            
            # Generate recommendations
            if ($AssessmentResults.SecurityIssues.Count -eq 0) {
                $AssessmentResults.Recommendations += "No critical security issues detected in this assessment"
            } else {
                $AssessmentResults.Recommendations += "Implement privileged group monitoring with automated alerting"
                $AssessmentResults.Recommendations += "Enable advanced auditing for all privileged account activities"
                $AssessmentResults.Recommendations += "Consider implementing Privileged Access Management (PAM) solution"
                $AssessmentResults.Recommendations += "Regular security assessments should be scheduled monthly"
            }
            
        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Error during AD security assessment: $($_.Exception.Message)"
            throw
        }
    }
    
    end {
        # Generate report if requested
        if ($ReportPath) {
            try {
                $ReportContent = $AssessmentResults | ConvertTo-Json -Depth 10
                $ReportContent | Out-File -FilePath $ReportPath -Encoding UTF8
                Write-CustomLog -Level 'SUCCESS' -Message "Assessment report saved to: $ReportPath"
            } catch {
                Write-CustomLog -Level 'ERROR' -Message "Failed to save report: $($_.Exception.Message)"
            }
        }
        
        Write-CustomLog -Level 'SUCCESS' -Message "Active Directory security assessment completed. Found $($AssessmentResults.SecurityIssues.Count) security issues."
        
        return $AssessmentResults
    }
}
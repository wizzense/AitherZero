function Get-ADDelegationRisks {
    <#
    .SYNOPSIS
        Identifies Active Directory delegation security risks.
        
    .DESCRIPTION
        Analyzes Active Directory for potentially dangerous delegation configurations including:
        - Users and computers trusted for unconstrained delegation
        - Service accounts with constrained delegation to sensitive services
        - Accounts with protocol transition capabilities
        - High-privilege accounts with delegation rights
        
    .PARAMETER Domain
        Target domain to analyze. Defaults to current domain.
        
    .PARAMETER IncludeUsers
        Include user accounts in delegation analysis. Default: $true
        
    .PARAMETER IncludeComputers
        Include computer accounts in delegation analysis. Default: $true
        
    .PARAMETER RiskLevel
        Minimum risk level to report: Low, Medium, High, Critical
        
    .PARAMETER ReportPath
        Path to save detailed risk assessment report
        
    .PARAMETER SensitiveServices
        Array of sensitive service SPNs to flag as high-risk delegation targets
        
    .EXAMPLE
        Get-ADDelegationRisks
        
    .EXAMPLE
        Get-ADDelegationRisks -RiskLevel High -ReportPath "C:\Reports\Delegation-Risks.html"
        
    .EXAMPLE
        Get-ADDelegationRisks -IncludeUsers $false -SensitiveServices @("cifs/*", "host/*", "ldap/*")
    #>
    
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Domain = $env:USERDNSDOMAIN,
        
        [Parameter()]
        [bool]$IncludeUsers = $true,
        
        [Parameter()]
        [bool]$IncludeComputers = $true,
        
        [Parameter()]
        [ValidateSet('Low', 'Medium', 'High', 'Critical')]
        [string]$RiskLevel = 'Low',
        
        [Parameter()]
        [string]$ReportPath,
        
        [Parameter()]
        [string[]]$SensitiveServices = @(
            'cifs/*', 'host/*', 'ldap/*', 'krbtgt/*', 
            'mssqlsvc/*', 'http/*', 'ftp/*', 'nfs/*'
        )
    )
    
    begin {
        Write-CustomLog -Level 'INFO' -Message "Starting Active Directory delegation risk analysis for domain: $Domain"
        
        try {
            Import-Module ActiveDirectory -ErrorAction Stop
        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Failed to import ActiveDirectory module: $($_.Exception.Message)"
            throw
        }
        
        $RiskAssessment = @{
            Domain = $Domain
            Timestamp = Get-Date
            UnconstrainedDelegation = @()
            ConstrainedDelegation = @()
            ProtocolTransition = @()
            HighPrivilegeDelegation = @()
            RiskSummary = @{
                Critical = 0
                High = 0
                Medium = 0
                Low = 0
            }
            Recommendations = @()
        }
        
        # Define risk levels for different delegation types
        $RiskLevels = @{
            'UnconstrainedUser' = 'Critical'
            'UnconstrainedComputer' = 'High'
            'ConstrainedToSensitive' = 'High'
            'ProtocolTransition' = 'Medium'
            'ConstrainedToNormal' = 'Low'
            'PrivilegedAccountDelegation' = 'Critical'
        }
        
        # Privileged groups to check
        $PrivilegedGroups = @(
            'Domain Admins', 'Enterprise Admins', 'Schema Admins',
            'Account Operators', 'Backup Operators', 'Server Operators'
        )
    }
    
    process {
        try {
            # Analyze user accounts if requested
            if ($IncludeUsers) {
                Write-CustomLog -Level 'INFO' -Message "Analyzing user delegation configurations"
                
                # Find users with unconstrained delegation
                $UnconstrainedUsers = Get-ADUser -Filter "TrustedForDelegation -eq `$true" -Properties TrustedForDelegation, MemberOf
                
                foreach ($User in $UnconstrainedUsers) {
                    $Risk = [PSCustomObject]@{
                        Name = $User.Name
                        SamAccountName = $User.SamAccountName
                        Type = 'User'
                        DelegationType = 'Unconstrained'
                        RiskLevel = $RiskLevels['UnconstrainedUser']
                        Description = 'User account trusted for unconstrained delegation - extremely dangerous'
                        DelegationTargets = 'Any Service'
                        PrivilegedMember = ($User.MemberOf | Where-Object {$_ -match 'Admins|Operators'}) -ne $null
                    }
                    
                    $RiskAssessment.UnconstrainedDelegation += $Risk
                    $RiskAssessment.RiskSummary[$Risk.RiskLevel]++
                }
                
                # Find users with constrained delegation
                $ConstrainedUsers = Get-ADUser -Filter "msDS-AllowedToDelegateTo -like '*'" -Properties "msDS-AllowedToDelegateTo", TrustedToAuthForDelegation, MemberOf
                
                foreach ($User in $ConstrainedUsers) {
                    $DelegationTargets = $User."msDS-AllowedToDelegateTo"
                    $HasSensitiveTargets = $false
                    
                    foreach ($Target in $DelegationTargets) {
                        foreach ($SensitiveService in $SensitiveServices) {
                            if ($Target -like $SensitiveService) {
                                $HasSensitiveTargets = $true
                                break
                            }
                        }
                        if ($HasSensitiveTargets) { break }
                    }
                    
                    $RiskType = if ($HasSensitiveTargets) { 'ConstrainedToSensitive' } else { 'ConstrainedToNormal' }
                    
                    $Risk = [PSCustomObject]@{
                        Name = $User.Name
                        SamAccountName = $User.SamAccountName
                        Type = 'User'
                        DelegationType = 'Constrained'
                        RiskLevel = $RiskLevels[$RiskType]
                        Description = if ($HasSensitiveTargets) { 'User trusted for delegation to sensitive services' } else { 'User trusted for constrained delegation' }
                        DelegationTargets = $DelegationTargets -join '; '
                        ProtocolTransition = $User.TrustedToAuthForDelegation
                        PrivilegedMember = ($User.MemberOf | Where-Object {$_ -match 'Admins|Operators'}) -ne $null
                    }
                    
                    $RiskAssessment.ConstrainedDelegation += $Risk
                    $RiskAssessment.RiskSummary[$Risk.RiskLevel]++
                    
                    # Check for protocol transition
                    if ($User.TrustedToAuthForDelegation) {
                        $ProtocolRisk = [PSCustomObject]@{
                            Name = $User.Name
                            SamAccountName = $User.SamAccountName
                            Type = 'User'
                            RiskLevel = $RiskLevels['ProtocolTransition']
                            Description = 'Account can use protocol transition (any authentication protocol)'
                            DelegationTargets = $DelegationTargets -join '; '
                        }
                        
                        $RiskAssessment.ProtocolTransition += $ProtocolRisk
                    }
                }
            }
            
            # Analyze computer accounts if requested
            if ($IncludeComputers) {
                Write-CustomLog -Level 'INFO' -Message "Analyzing computer delegation configurations"
                
                # Find computers with unconstrained delegation
                $UnconstrainedComputers = Get-ADComputer -Filter "TrustedForDelegation -eq `$true" -Properties TrustedForDelegation
                
                foreach ($Computer in $UnconstrainedComputers) {
                    $Risk = [PSCustomObject]@{
                        Name = $Computer.Name
                        SamAccountName = $Computer.SamAccountName
                        Type = 'Computer'
                        DelegationType = 'Unconstrained'
                        RiskLevel = $RiskLevels['UnconstrainedComputer']
                        Description = 'Computer account trusted for unconstrained delegation'
                        DelegationTargets = 'Any Service'
                        PrivilegedMember = $false
                    }
                    
                    $RiskAssessment.UnconstrainedDelegation += $Risk
                    $RiskAssessment.RiskSummary[$Risk.RiskLevel]++
                }
                
                # Find computers with constrained delegation
                $ConstrainedComputers = Get-ADComputer -Filter "msDS-AllowedToDelegateTo -like '*'" -Properties "msDS-AllowedToDelegateTo", TrustedToAuthForDelegation
                
                foreach ($Computer in $ConstrainedComputers) {
                    $DelegationTargets = $Computer."msDS-AllowedToDelegateTo"
                    $HasSensitiveTargets = $false
                    
                    foreach ($Target in $DelegationTargets) {
                        foreach ($SensitiveService in $SensitiveServices) {
                            if ($Target -like $SensitiveService) {
                                $HasSensitiveTargets = $true
                                break
                            }
                        }
                        if ($HasSensitiveTargets) { break }
                    }
                    
                    $RiskType = if ($HasSensitiveTargets) { 'ConstrainedToSensitive' } else { 'ConstrainedToNormal' }
                    
                    $Risk = [PSCustomObject]@{
                        Name = $Computer.Name
                        SamAccountName = $Computer.SamAccountName
                        Type = 'Computer'
                        DelegationType = 'Constrained'
                        RiskLevel = $RiskLevels[$RiskType]
                        Description = if ($HasSensitiveTargets) { 'Computer trusted for delegation to sensitive services' } else { 'Computer trusted for constrained delegation' }
                        DelegationTargets = $DelegationTargets -join '; '
                        ProtocolTransition = $Computer.TrustedToAuthForDelegation
                        PrivilegedMember = $false
                    }
                    
                    $RiskAssessment.ConstrainedDelegation += $Risk
                    $RiskAssessment.RiskSummary[$Risk.RiskLevel]++
                }
            }
            
            # Check for privileged accounts with delegation
            Write-CustomLog -Level 'INFO' -Message "Checking privileged accounts for delegation risks"
            
            foreach ($GroupName in $PrivilegedGroups) {
                try {
                    $GroupMembers = Get-ADGroupMember -Identity $GroupName -ErrorAction SilentlyContinue
                    
                    foreach ($Member in $GroupMembers) {
                        if ($Member.objectClass -eq 'user') {
                            $User = Get-ADUser -Identity $Member.SamAccountName -Properties TrustedForDelegation, "msDS-AllowedToDelegateTo" -ErrorAction SilentlyContinue
                            
                            if ($User.TrustedForDelegation -or $User."msDS-AllowedToDelegateTo") {
                                $Risk = [PSCustomObject]@{
                                    Name = $User.Name
                                    SamAccountName = $User.SamAccountName
                                    Type = 'PrivilegedUser'
                                    GroupMembership = $GroupName
                                    RiskLevel = $RiskLevels['PrivilegedAccountDelegation']
                                    Description = "Privileged account ($GroupName member) with delegation rights"
                                    DelegationType = if ($User.TrustedForDelegation) { 'Unconstrained' } else { 'Constrained' }
                                }
                                
                                $RiskAssessment.HighPrivilegeDelegation += $Risk
                                $RiskAssessment.RiskSummary[$Risk.RiskLevel]++
                            }
                        }
                    }
                } catch {
                    Write-CustomLog -Level 'WARNING' -Message "Could not analyze group '$GroupName': $($_.Exception.Message)"
                }
            }
            
            # Generate recommendations based on findings
            if ($RiskAssessment.RiskSummary.Critical -gt 0) {
                $RiskAssessment.Recommendations += "CRITICAL: Remove unconstrained delegation from user accounts immediately"
                $RiskAssessment.Recommendations += "CRITICAL: Review and remediate privileged accounts with delegation rights"
            }
            
            if ($RiskAssessment.RiskSummary.High -gt 0) {
                $RiskAssessment.Recommendations += "HIGH: Review constrained delegation to sensitive services"
                $RiskAssessment.Recommendations += "HIGH: Consider removing unconstrained delegation from computers where possible"
            }
            
            if ($RiskAssessment.ProtocolTransition.Count -gt 0) {
                $RiskAssessment.Recommendations += "Review accounts with protocol transition capability"
            }
            
            $RiskAssessment.Recommendations += "Implement regular delegation monitoring and alerting"
            $RiskAssessment.Recommendations += "Use constrained delegation with specific service targets only"
            $RiskAssessment.Recommendations += "Monitor delegation-related events in security logs"
            
        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Error during delegation risk analysis: $($_.Exception.Message)"
            throw
        }
    }
    
    end {
        # Filter results by risk level
        $FilteredResults = @{
            UnconstrainedDelegation = $RiskAssessment.UnconstrainedDelegation | Where-Object {
                switch ($RiskLevel) {
                    'Critical' { $_.RiskLevel -eq 'Critical' }
                    'High' { $_.RiskLevel -in @('Critical', 'High') }
                    'Medium' { $_.RiskLevel -in @('Critical', 'High', 'Medium') }
                    'Low' { $true }
                }
            }
            ConstrainedDelegation = $RiskAssessment.ConstrainedDelegation | Where-Object {
                switch ($RiskLevel) {
                    'Critical' { $_.RiskLevel -eq 'Critical' }
                    'High' { $_.RiskLevel -in @('Critical', 'High') }
                    'Medium' { $_.RiskLevel -in @('Critical', 'High', 'Medium') }
                    'Low' { $true }
                }
            }
            HighPrivilegeDelegation = $RiskAssessment.HighPrivilegeDelegation
            ProtocolTransition = $RiskAssessment.ProtocolTransition
            RiskSummary = $RiskAssessment.RiskSummary
            Recommendations = $RiskAssessment.Recommendations
            Domain = $RiskAssessment.Domain
            Timestamp = $RiskAssessment.Timestamp
        }
        
        # Generate report if requested
        if ($ReportPath) {
            try {
                $ReportContent = $FilteredResults | ConvertTo-Json -Depth 10
                $ReportContent | Out-File -FilePath $ReportPath -Encoding UTF8
                Write-CustomLog -Level 'SUCCESS' -Message "Delegation risk report saved to: $ReportPath"
            } catch {
                Write-CustomLog -Level 'ERROR' -Message "Failed to save report: $($_.Exception.Message)"
            }
        }
        
        # Summary logging
        $TotalRisks = $FilteredResults.UnconstrainedDelegation.Count + $FilteredResults.ConstrainedDelegation.Count + $FilteredResults.HighPrivilegeDelegation.Count
        Write-CustomLog -Level 'SUCCESS' -Message "Delegation risk analysis completed. Found $TotalRisks total risks."
        Write-CustomLog -Level 'INFO' -Message "Risk Summary - Critical: $($RiskAssessment.RiskSummary.Critical), High: $($RiskAssessment.RiskSummary.High), Medium: $($RiskAssessment.RiskSummary.Medium), Low: $($RiskAssessment.RiskSummary.Low)"
        
        if ($RiskAssessment.RiskSummary.Critical -gt 0) {
            Write-CustomLog -Level 'ERROR' -Message "CRITICAL delegation risks detected - immediate action required!"
        }
        
        return $FilteredResults
    }
}
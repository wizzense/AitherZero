function Enable-ADSmartCardLogon {
    <#
    .SYNOPSIS
        Configures Active Directory users for smart card authentication.
        
    .DESCRIPTION
        Enables smart card logon requirements for specified users or groups, with options for
        password randomization and bulk operations. Supports targeting specific OUs or individual
        users, and includes password rotation for enhanced security.
        
    .PARAMETER Identity
        User identity (SamAccountName, UserPrincipalName, or DistinguishedName) to configure
        
    .PARAMETER SearchBase
        Distinguished name of OU to search for users. If not specified, searches entire domain
        
    .PARAMETER GroupName
        Name of AD group whose members should be configured for smart card logon
        
    .PARAMETER RotatePasswords
        Rotate passwords for users already configured with smart card logon
        
    .PARAMETER Filter
        Custom LDAP filter for selecting users (advanced usage)
        
    .PARAMETER TestMode
        Show what would be done without making changes
        
    .PARAMETER Force
        Skip confirmation prompts for bulk operations
        
    .EXAMPLE
        Enable-ADSmartCardLogon -Identity "john.doe"
        
    .EXAMPLE
        Enable-ADSmartCardLogon -GroupName "Domain Admins" -RotatePasswords
        
    .EXAMPLE
        Enable-ADSmartCardLogon -SearchBase "OU=Admins,DC=contoso,DC=com" -TestMode
        
    .EXAMPLE
        Enable-ADSmartCardLogon -RotatePasswords -SearchBase "OU=Privileged,DC=contoso,DC=com"
    #>
    
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'Identity')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'Identity')]
        [string]$Identity,
        
        [Parameter(ParameterSetName = 'SearchBase')]
        [Parameter(ParameterSetName = 'Rotate')]
        [string]$SearchBase,
        
        [Parameter(Mandatory, ParameterSetName = 'Group')]
        [string]$GroupName,
        
        [Parameter(ParameterSetName = 'Rotate')]
        [Parameter(ParameterSetName = 'Group')]
        [Parameter(ParameterSetName = 'SearchBase')]
        [switch]$RotatePasswords,
        
        [Parameter(ParameterSetName = 'SearchBase')]
        [string]$Filter,
        
        [Parameter()]
        [switch]$TestMode,
        
        [Parameter()]
        [switch]$Force
    )
    
    begin {
        Write-CustomLog -Level 'INFO' -Message "Starting smart card logon configuration"
        
        try {
            Import-Module ActiveDirectory -ErrorAction Stop
        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Failed to import ActiveDirectory module: $($_.Exception.Message)"
            throw
        }
        
        $Results = @()
        $ProcessedCount = 0
        $SuccessCount = 0
        $FailureCount = 0
    }
    
    process {
        try {
            # Determine target users based on parameter set
            $TargetUsers = @()
            
            switch ($PSCmdlet.ParameterSetName) {
                'Identity' {
                    Write-CustomLog -Level 'INFO' -Message "Configuring smart card logon for user: $Identity"
                    try {
                        $TargetUsers = @(Get-ADUser -Identity $Identity -Properties SmartCardLogonRequired -ErrorAction Stop)
                    } catch {
                        Write-CustomLog -Level 'ERROR' -Message "Could not find user '$Identity': $($_.Exception.Message)"
                        throw
                    }
                }
                
                'Group' {
                    Write-CustomLog -Level 'INFO' -Message "Configuring smart card logon for members of group: $GroupName"
                    try {
                        $GroupMembers = Get-ADGroupMember -Identity $GroupName -ErrorAction Stop
                        $TargetUsers = $GroupMembers | Where-Object {$_.objectClass -eq 'user'} | 
                                     ForEach-Object {Get-ADUser -Identity $_.SamAccountName -Properties SmartCardLogonRequired}
                    } catch {
                        Write-CustomLog -Level 'ERROR' -Message "Could not retrieve group members for '$GroupName': $($_.Exception.Message)"
                        throw
                    }
                }
                
                'SearchBase' {
                    Write-CustomLog -Level 'INFO' -Message "Searching for users in: $SearchBase"
                    try {
                        if ($SearchBase) {
                            # Validate SearchBase exists
                            $null = Get-ADOrganizationalUnit -Identity $SearchBase -ErrorAction Stop
                        } else {
                            $SearchBase = (Get-ADDomain).DistinguishedName
                        }
                        
                        $SearchFilter = if ($Filter) { $Filter } else { "Enabled -eq `$true" }
                        $TargetUsers = Get-ADUser -Filter $SearchFilter -SearchBase $SearchBase -Properties SmartCardLogonRequired
                        
                    } catch {
                        Write-CustomLog -Level 'ERROR' -Message "Error searching for users: $($_.Exception.Message)"
                        throw
                    }
                }
                
                'Rotate' {
                    Write-CustomLog -Level 'INFO' -Message "Finding users with smart card logon already enabled for password rotation"
                    try {
                        $SearchFilter = "SmartCardLogonRequired -eq `$true"
                        if ($SearchBase) {
                            $null = Get-ADOrganizationalUnit -Identity $SearchBase -ErrorAction Stop
                        } else {
                            $SearchBase = (Get-ADDomain).DistinguishedName
                        }
                        
                        $TargetUsers = Get-ADUser -Filter $SearchFilter -SearchBase $SearchBase -Properties SmartCardLogonRequired
                        
                    } catch {
                        Write-CustomLog -Level 'ERROR' -Message "Error finding smart card users: $($_.Exception.Message)"
                        throw
                    }
                }
            }
            
            if ($TargetUsers.Count -eq 0) {
                Write-CustomLog -Level 'WARNING' -Message "No target users found"
                return
            }
            
            Write-CustomLog -Level 'INFO' -Message "Found $($TargetUsers.Count) target user(s)"
            
            # Confirm bulk operations
            if ($TargetUsers.Count -gt 1 -and -not $Force -and -not $TestMode) {
                $ConfirmMessage = "This will modify smart card settings for $($TargetUsers.Count) users. Continue?"
                if (-not $PSCmdlet.ShouldContinue($ConfirmMessage, "Bulk Smart Card Configuration")) {
                    Write-CustomLog -Level 'INFO' -Message "Operation cancelled by user"
                    return
                }
            }
            
            # Process each user
            foreach ($User in $TargetUsers) {
                $ProcessedCount++
                $UserResult = [PSCustomObject]@{
                    SamAccountName = $User.SamAccountName
                    UserPrincipalName = $User.UserPrincipalName
                    DistinguishedName = $User.DistinguishedName
                    PreviousSmartCardRequired = $User.SmartCardLogonRequired
                    Success = $false
                    Action = ''
                    TimeStamp = Get-Date
                    ErrorMessage = ''
                }
                
                try {
                    if ($RotatePasswords -and $User.SmartCardLogonRequired) {
                        # Rotate password by toggling smart card requirement
                        Write-CustomLog -Level 'INFO' -Message "Rotating password for user: $($User.SamAccountName)"
                        
                        if ($TestMode) {
                            Write-CustomLog -Level 'INFO' -Message "[TEST MODE] Would rotate password for: $($User.SamAccountName)"
                            $UserResult.Action = 'Password Rotation (Test Mode)'
                            $UserResult.Success = $true
                        } else {
                            if ($PSCmdlet.ShouldProcess($User.SamAccountName, "Rotate smart card password")) {
                                # Toggle off then on to force password regeneration
                                Set-ADUser -Identity $User.SamAccountName -SmartcardLogonRequired $false -ErrorAction Stop
                                Set-ADUser -Identity $User.SamAccountName -SmartcardLogonRequired $true -ErrorAction Stop
                                
                                $UserResult.Action = 'Password Rotated'
                                $UserResult.Success = $true
                                $SuccessCount++
                                
                                Write-CustomLog -Level 'SUCCESS' -Message "Password rotated for user: $($User.SamAccountName)"
                            }
                        }
                    } elseif (-not $User.SmartCardLogonRequired) {
                        # Enable smart card logon
                        Write-CustomLog -Level 'INFO' -Message "Enabling smart card logon for user: $($User.SamAccountName)"
                        
                        if ($TestMode) {
                            Write-CustomLog -Level 'INFO' -Message "[TEST MODE] Would enable smart card logon for: $($User.SamAccountName)"
                            $UserResult.Action = 'Enable Smart Card (Test Mode)'
                            $UserResult.Success = $true
                        } else {
                            if ($PSCmdlet.ShouldProcess($User.SamAccountName, "Enable smart card logon")) {
                                Set-ADUser -Identity $User.SamAccountName -SmartcardLogonRequired $true -ErrorAction Stop
                                
                                $UserResult.Action = 'Smart Card Enabled'
                                $UserResult.Success = $true
                                $SuccessCount++
                                
                                Write-CustomLog -Level 'SUCCESS' -Message "Smart card logon enabled for user: $($User.SamAccountName)"
                            }
                        }
                    } else {
                        # User already has smart card logon enabled
                        Write-CustomLog -Level 'INFO' -Message "User already has smart card logon enabled: $($User.SamAccountName)"
                        $UserResult.Action = 'Already Enabled'
                        $UserResult.Success = $true
                        $SuccessCount++
                    }
                    
                } catch {
                    $ErrorMsg = $_.Exception.Message
                    Write-CustomLog -Level 'ERROR' -Message "Failed to configure user '$($User.SamAccountName)': $ErrorMsg"
                    
                    $UserResult.ErrorMessage = $ErrorMsg
                    $UserResult.Action = 'Failed'
                    $FailureCount++
                }
                
                $Results += $UserResult
            }
            
        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Error during smart card configuration: $($_.Exception.Message)"
            throw
        }
    }
    
    end {
        # Summary logging
        Write-CustomLog -Level 'INFO' -Message "Smart card configuration completed"
        Write-CustomLog -Level 'INFO' -Message "Processed: $ProcessedCount users"
        Write-CustomLog -Level 'INFO' -Message "Successful: $SuccessCount users"
        
        if ($FailureCount -gt 0) {
            Write-CustomLog -Level 'WARNING' -Message "Failed: $FailureCount users"
        }
        
        # Security recommendations
        if ($SuccessCount -gt 0 -and -not $TestMode) {
            $Recommendations = @()
            $Recommendations += "Ensure smart card infrastructure is properly configured"
            $Recommendations += "Test smart card authentication for modified users"
            $Recommendations += "Monitor authentication logs for smart card logon events"
            $Recommendations += "Consider scheduling regular password rotations for smart card users"
            $Recommendations += "Verify Certificate Services is accessible to all users"
            
            foreach ($Recommendation in $Recommendations) {
                Write-CustomLog -Level 'INFO' -Message "Recommendation: $Recommendation"
            }
        }
        
        # Return results
        return $Results
    }
}
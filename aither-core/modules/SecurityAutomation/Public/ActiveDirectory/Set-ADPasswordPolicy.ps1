function Set-ADPasswordPolicy {
    <#
    .SYNOPSIS
        Configures Active Directory password policies for enhanced security.

    .DESCRIPTION
        Sets domain-wide or fine-grained password policies following security best practices.
        Supports both default domain policies and fine-grained policies for specific groups.

    .PARAMETER PolicyType
        Type of password policy to configure: 'Domain' or 'FineGrained'

    .PARAMETER PolicyName
        Name for fine-grained password policy (required when PolicyType is 'FineGrained')

    .PARAMETER MinPasswordLength
        Minimum password length. Default: 12 characters

    .PARAMETER ComplexityEnabled
        Enable password complexity requirements. Default: $true

    .PARAMETER MaxPasswordAge
        Maximum password age in days. Default: 365

    .PARAMETER MinPasswordAge
        Minimum password age in days. Default: 1

    .PARAMETER PasswordHistoryCount
        Number of previous passwords to remember. Default: 24

    .PARAMETER LockoutThreshold
        Number of failed logon attempts before lockout. Default: 5

    .PARAMETER LockoutDuration
        Account lockout duration in minutes. Default: 30

    .PARAMETER TargetGroups
        Groups to apply fine-grained policy to (required when PolicyType is 'FineGrained')

    .PARAMETER Precedence
        Precedence value for fine-grained policy (lower = higher priority). Default: 100

    .EXAMPLE
        Set-ADPasswordPolicy -PolicyType Domain -MinPasswordLength 14 -MaxPasswordAge 180

    .EXAMPLE
        Set-ADPasswordPolicy -PolicyType FineGrained -PolicyName "AdminPolicy" -MinPasswordLength 16 -MaxPasswordAge 90 -TargetGroups @("Domain Admins", "Enterprise Admins") -Precedence 10
    #>

    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Domain', 'FineGrained')]
        [string]$PolicyType,

        [Parameter()]
        [string]$PolicyName,

        [Parameter()]
        [ValidateRange(8, 127)]
        [int]$MinPasswordLength = 12,

        [Parameter()]
        [bool]$ComplexityEnabled = $true,

        [Parameter()]
        [ValidateRange(1, 999)]
        [int]$MaxPasswordAge = 365,

        [Parameter()]
        [ValidateRange(0, 998)]
        [int]$MinPasswordAge = 1,

        [Parameter()]
        [ValidateRange(0, 1024)]
        [int]$PasswordHistoryCount = 24,

        [Parameter()]
        [ValidateRange(0, 999)]
        [int]$LockoutThreshold = 5,

        [Parameter()]
        [ValidateRange(1, 99999)]
        [int]$LockoutDuration = 30,

        [Parameter()]
        [string[]]$TargetGroups,

        [Parameter()]
        [ValidateRange(1, 1000)]
        [int]$Precedence = 100
    )

    begin {
        Write-CustomLog -Level 'INFO' -Message "Configuring Active Directory password policy: $PolicyType"

        try {
            Import-Module ActiveDirectory -ErrorAction Stop
        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Failed to import ActiveDirectory module: $($_.Exception.Message)"
            throw
        }

        # Validate fine-grained policy requirements
        if ($PolicyType -eq 'FineGrained') {
            if (-not $PolicyName) {
                throw "PolicyName is required when PolicyType is 'FineGrained'"
            }
            if (-not $TargetGroups) {
                throw "TargetGroups is required when PolicyType is 'FineGrained'"
            }
        }
    }

    process {
        try {
            if ($PolicyType -eq 'Domain') {
                Write-CustomLog -Level 'INFO' -Message "Configuring default domain password policy"

                if ($PSCmdlet.ShouldProcess("Default Domain Policy", "Update password policy")) {
                    $Domain = Get-ADDomain

                    $PolicyParams = @{
                        Identity = $Domain.DistinguishedName
                        MinPasswordLength = $MinPasswordLength
                        ComplexityEnabled = $ComplexityEnabled
                        MaxPasswordAge = "$MaxPasswordAge.00:00:00"
                        MinPasswordAge = "$MinPasswordAge.00:00:00"
                        PasswordHistoryCount = $PasswordHistoryCount
                        LockoutThreshold = $LockoutThreshold
                        LockoutDuration = "0.00:$($LockoutDuration):00"
                        LockoutObservationWindow = "0.00:$($LockoutDuration):00"
                    }

                    Set-ADDefaultDomainPasswordPolicy @PolicyParams

                    Write-CustomLog -Level 'SUCCESS' -Message "Default domain password policy updated successfully"
                }
            }
            elseif ($PolicyType -eq 'FineGrained') {
                Write-CustomLog -Level 'INFO' -Message "Configuring fine-grained password policy: $PolicyName"

                if ($PSCmdlet.ShouldProcess($PolicyName, "Create/Update fine-grained password policy")) {
                    # Check if policy already exists
                    $ExistingPolicy = Get-ADFineGrainedPasswordPolicy -Filter "Name -eq '$PolicyName'" -ErrorAction SilentlyContinue

                    $PolicyParams = @{
                        Name = $PolicyName
                        Precedence = $Precedence
                        MinPasswordLength = $MinPasswordLength
                        ComplexityEnabled = $ComplexityEnabled
                        MaxPasswordAge = "$MaxPasswordAge.00:00:00"
                        MinPasswordAge = "$MinPasswordAge.00:00:00"
                        PasswordHistoryCount = $PasswordHistoryCount
                        LockoutThreshold = $LockoutThreshold
                        LockoutDuration = "0.00:$($LockoutDuration):00"
                        LockoutObservationWindow = "0.00:$($LockoutDuration):00"
                    }

                    if ($ExistingPolicy) {
                        Write-CustomLog -Level 'INFO' -Message "Updating existing fine-grained password policy: $PolicyName"
                        Set-ADFineGrainedPasswordPolicy -Identity $PolicyName @PolicyParams
                    } else {
                        Write-CustomLog -Level 'INFO' -Message "Creating new fine-grained password policy: $PolicyName"
                        New-ADFineGrainedPasswordPolicy @PolicyParams
                    }

                    # Apply policy to target groups
                    foreach ($Group in $TargetGroups) {
                        try {
                            # Verify group exists
                            $ADGroup = Get-ADGroup -Identity $Group -ErrorAction Stop

                            # Check if group is already a subject of this policy
                            $CurrentSubjects = Get-ADFineGrainedPasswordPolicySubject -Identity $PolicyName -ErrorAction SilentlyContinue

                            if ($CurrentSubjects.Name -notcontains $Group) {
                                Add-ADFineGrainedPasswordPolicySubject -Identity $PolicyName -Subjects $Group
                                Write-CustomLog -Level 'INFO' -Message "Applied policy '$PolicyName' to group: $Group"
                            } else {
                                Write-CustomLog -Level 'INFO' -Message "Group '$Group' already subject to policy '$PolicyName'"
                            }
                        } catch {
                            Write-CustomLog -Level 'WARNING' -Message "Could not apply policy to group '$Group': $($_.Exception.Message)"
                        }
                    }

                    Write-CustomLog -Level 'SUCCESS' -Message "Fine-grained password policy '$PolicyName' configured successfully"
                }
            }

            # Display current policy settings
            if ($PolicyType -eq 'Domain') {
                $CurrentPolicy = Get-ADDefaultDomainPasswordPolicy
                Write-CustomLog -Level 'INFO' -Message "Current domain policy - MinLength: $($CurrentPolicy.MinPasswordLength), MaxAge: $($CurrentPolicy.MaxPasswordAge.Days) days, Complexity: $($CurrentPolicy.ComplexityEnabled)"
            } else {
                $CurrentPolicy = Get-ADFineGrainedPasswordPolicy -Identity $PolicyName
                $PolicySubjects = Get-ADFineGrainedPasswordPolicySubject -Identity $PolicyName
                Write-CustomLog -Level 'INFO' -Message "Policy '$PolicyName' applied to $($PolicySubjects.Count) subjects with precedence $($CurrentPolicy.Precedence)"
            }

        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Error configuring password policy: $($_.Exception.Message)"
            throw
        }
    }

    end {
        Write-CustomLog -Level 'SUCCESS' -Message "Password policy configuration completed"
    }
}

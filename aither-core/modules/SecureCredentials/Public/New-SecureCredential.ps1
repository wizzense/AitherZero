function New-SecureCredential {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$CredentialName,

        [Parameter(Mandatory = $true)]
        [ValidateSet('UserPassword', 'ServiceAccount', 'APIKey', 'Certificate')]
        [string]$CredentialType,

        [Parameter(Mandatory = $false)]
        [string]$Username,

        [Parameter(Mandatory = $false)]
        [SecureString]$Password,

        [Parameter(Mandatory = $false)]
        [string]$APIKey,

        [Parameter(Mandatory = $false)]
        [string]$CertificatePath,

        [Parameter(Mandatory = $false)]
        [string]$Description,

        [Parameter(Mandatory = $false)]
        [hashtable]$Metadata = @{}
    )

    begin {
        Write-CustomLog -Level 'INFO' -Message "Starting New-SecureCredential for: $CredentialName"
    }

    process {
        try {
            # Validate parameters based on credential type
            switch ($CredentialType) {
                'UserPassword' {
                    if (-not $Username -or -not $Password) {
                        throw "Username and Password are required for UserPassword credential type"
                    }
                }
                'ServiceAccount' {
                    if (-not $Username) {
                        throw "Username is required for ServiceAccount credential type"
                    }
                }
                'APIKey' {
                    if (-not $APIKey) {
                        throw "APIKey is required for APIKey credential type"
                    }
                }
                'Certificate' {
                    if (-not $CertificatePath) {
                        throw "CertificatePath is required for Certificate credential type"
                    }
                }
            }

            $credentialData = @{
                Name = $CredentialName
                Type = $CredentialType
                Username = $Username
                Description = $Description
                Metadata = $Metadata
                Created = Get-Date
                LastModified = Get-Date
            }

            if ($PSCmdlet.ShouldProcess($CredentialName, "Create secure credential")) {
                # Store credential securely (implementation depends on platform)
                $result = Save-CredentialSecurely -CredentialData $credentialData -Password $Password -APIKey $APIKey -CertificatePath $CertificatePath

                if ($result.Success) {
                    Write-CustomLog -Level 'SUCCESS' -Message "Successfully created credential: $CredentialName"
                    return @{
                        Success = $true
                        CredentialName = $CredentialName
                        Message = "Credential created successfully"
                    }
                } else {
                    throw "Failed to save credential: $($result.Error)"
                }
            } else {
                Write-CustomLog -Level 'INFO' -Message "WhatIf: Would create credential $CredentialName of type $CredentialType"
                return @{
                    Success = $true
                    CredentialName = $CredentialName
                    Message = "WhatIf: Credential would be created successfully"
                }
            }
        }        catch {
            Write-CustomLog -Level 'ERROR' -Message "Failed to create credential $CredentialName : $($_.Exception.Message)"
            throw
        }
    }

    end {
        Write-CustomLog -Level 'INFO' -Message "Completed New-SecureCredential for: $CredentialName"
    }
}
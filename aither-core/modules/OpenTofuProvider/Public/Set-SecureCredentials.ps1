function Set-SecureCredentials {
    <#
    .SYNOPSIS
    Securely manages credentials for OpenTofu and Taliesins provider operations.

    .DESCRIPTION
    Provides secure credential management including:
    - Encrypted credential storage
    - Certificate-based authentication
    - Credential rotation and validation
    - Integration with Windows Credential Manager

    .PARAMETER Target
    Target system identifier for credential storage.

    .PARAMETER Credentials
    PSCredential object to store securely.

    .PARAMETER CertificatePath
    Path to certificate files for certificate-based authentication.

    .PARAMETER CredentialType
    Type of credentials: 'UserPassword', 'Certificate', or 'Both'.

    .PARAMETER Force
    Force overwrite existing credentials.

    .EXAMPLE
    $creds = Get-Credential
    Set-SecureCredentials -Target "hyperv-lab-01" -Credentials $creds

    .EXAMPLE
    Set-SecureCredentials -Target "hyperv-lab-01" -CertificatePath "./certs/lab-01" -CredentialType "Certificate"
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Target,

        [Parameter()]
        [System.Management.Automation.PSCredential]$Credentials,

        [Parameter()]
        [string]$CertificatePath,

        [Parameter()]
        [ValidateSet('UserPassword', 'Certificate', 'Both')]
        [string]$CredentialType = 'UserPassword',

        [Parameter()]
        [switch]$Force
    )

    begin {
        Write-CustomLog -Level 'INFO' -Message "Setting secure credentials for target: $Target"

        # Validate inputs based on credential type
        switch ($CredentialType) {
            'UserPassword' {
                if (-not $Credentials) {
                    throw "Credentials parameter is required for UserPassword type"
                }
            }
            'Certificate' {
                if (-not $CertificatePath) {
                    throw "CertificatePath parameter is required for Certificate type"
                }
                if (-not (Test-Path $CertificatePath)) {
                    throw "Certificate path not found: $CertificatePath"
                }
            }
            'Both' {
                if (-not $Credentials -or -not $CertificatePath) {
                    throw "Both Credentials and CertificatePath parameters are required for Both type"
                }
                if (-not (Test-Path $CertificatePath)) {
                    throw "Certificate path not found: $CertificatePath"
                }
            }
        }
    }

    process {
        try {
            $credentialStore = @{
                Target = $Target
                Type = $CredentialType
                CreatedDate = Get-Date
                LastModified = Get-Date
            }

            # Handle user/password credentials
            if ($CredentialType -in @('UserPassword', 'Both')) {
                if ($PSCmdlet.ShouldProcess($Target, "Store user credentials")) {
                    $secureCredResult = Set-WindowsCredential -Target "OpenTofu_$Target" -Credentials $Credentials -Force:$Force

                    if ($secureCredResult.Success) {
                        $credentialStore.UserCredentials = @{
                            Username = $Credentials.UserName
                            Stored = $true
                            CredentialId = $secureCredResult.CredentialId
                        }
                        Write-CustomLog -Level 'SUCCESS' -Message "User credentials stored securely for $Target"
                    } else {
                        throw "Failed to store user credentials: $($secureCredResult.Error)"
                    }
                }
            }

            # Handle certificate credentials
            if ($CredentialType -in @('Certificate', 'Both')) {
                if ($PSCmdlet.ShouldProcess($CertificatePath, "Process certificate credentials")) {
                    $certResult = Set-CertificateCredentials -Target $Target -CertificatePath $CertificatePath -Force:$Force

                    if ($certResult.Success) {
                        $credentialStore.CertificateCredentials = @{
                            CertificatePath = $CertificatePath
                            Thumbprint = $certResult.Thumbprint
                            ExpiryDate = $certResult.ExpiryDate
                            Stored = $true
                        }
                        Write-CustomLog -Level 'SUCCESS' -Message "Certificate credentials processed for $Target"
                    } else {
                        throw "Failed to process certificate credentials: $($certResult.Error)"
                    }
                }
            }

            # Store credential metadata
            $metadataPath = Join-Path $env:LOCALAPPDATA "OpenTofuProvider/credentials"
            if (-not (Test-Path $metadataPath)) {
                New-Item -Path $metadataPath -ItemType Directory -Force | Out-Null
            }

            $metadataFile = Join-Path $metadataPath "$Target.json"
            if ($PSCmdlet.ShouldProcess($metadataFile, "Store credential metadata")) {
                $credentialStore | ConvertTo-Json -Depth 5 | Set-Content -Path $metadataFile
                Write-CustomLog -Level 'INFO' -Message "Credential metadata stored: $metadataFile"
            }

            return @{
                Success = $true
                Target = $Target
                CredentialType = $CredentialType
                MetadataPath = $metadataFile
                UserCredentialsStored = ($null -ne $credentialStore.UserCredentials)
                CertificateCredentialsStored = ($null -ne $credentialStore.CertificateCredentials)
            }

        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Failed to set secure credentials for $Target : $($_.Exception.Message)"
            throw
        }
    }

    end {
        Write-CustomLog -Level 'INFO' -Message "Secure credential configuration completed for $Target"
    }
}

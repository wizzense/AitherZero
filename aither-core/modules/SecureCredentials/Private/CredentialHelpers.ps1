function Save-CredentialSecurely {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$CredentialData,

        [Parameter(Mandatory = $false)]
        [SecureString]$Password,

        [Parameter(Mandatory = $false)]
        [string]$APIKey,

        [Parameter(Mandatory = $false)]
        [string]$CertificatePath
    )

    try {
        Write-CustomLog -Level 'INFO' -Message "Saving credential: $($CredentialData.Name)"

        # Create secure storage path
        $storagePath = Get-CredentialStoragePath
        if (-not (Test-Path $storagePath)) {
            New-Item -Path $storagePath -ItemType Directory -Force | Out-Null
        }

        # Encrypt and store credential data
        $encryptedData = @{
            Metadata = $CredentialData
            EncryptedPassword = if ($Password) { ConvertFrom-SecureString $Password } else { $null }
            EncryptedAPIKey = if ($APIKey) { Protect-String $APIKey } else { $null }
            CertificatePath = $CertificatePath
        }

        $credentialFile = Join-Path $storagePath "$($CredentialData.Name).json"
        $encryptedData | ConvertTo-Json -Depth 10 | Set-Content -Path $credentialFile -Encoding UTF8

        Write-CustomLog -Level 'SUCCESS' -Message "Credential saved successfully: $($CredentialData.Name)"
        return @{ Success = $true }
    }
    catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to save credential: $($_.Exception.Message)"
        return @{ Success = $false; Error = $_.Exception.Message }
    }
}

function Retrieve-CredentialSecurely {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$CredentialName
    )

    try {
        $storagePath = Get-CredentialStoragePath
        $credentialFile = Join-Path $storagePath "$CredentialName.json"

        if (-not (Test-Path $credentialFile)) {
            return @{ Success = $false; Error = "Credential not found" }
        }

        $encryptedData = Get-Content -Path $credentialFile -Raw | ConvertFrom-Json

        $credential = @{
            Name = $encryptedData.Metadata.Name
            Type = $encryptedData.Metadata.Type
            Username = $encryptedData.Metadata.Username
            Description = $encryptedData.Metadata.Description
            Metadata = $encryptedData.Metadata.Metadata
            Created = $encryptedData.Metadata.Created
            LastModified = $encryptedData.Metadata.LastModified
        }

        # Decrypt sensitive data if needed
        if ($encryptedData.EncryptedPassword) {
            $credential.Password = ConvertTo-SecureString $encryptedData.EncryptedPassword
        }
        if ($encryptedData.EncryptedAPIKey) {
            $credential.APIKey = Unprotect-String $encryptedData.EncryptedAPIKey
        }
        if ($encryptedData.CertificatePath) {
            $credential.CertificatePath = $encryptedData.CertificatePath
        }

        return @{ Success = $true; Credential = $credential }
    }
    catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to retrieve credential: $($_.Exception.Message)"
        return @{ Success = $false; Error = $_.Exception.Message }
    }
}

function Remove-CredentialSecurely {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$CredentialName
    )

    try {
        $storagePath = Get-CredentialStoragePath
        $credentialFile = Join-Path $storagePath "$CredentialName.json"

        if (-not (Test-Path $credentialFile)) {
            return @{ Success = $false; Error = "Credential not found" }
        }

        Remove-Item -Path $credentialFile -Force
        Write-CustomLog -Level 'SUCCESS' -Message "Credential removed successfully: $CredentialName"
        return @{ Success = $true }
    }
    catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to remove credential: $($_.Exception.Message)"
        return @{ Success = $false; Error = $_.Exception.Message }
    }
}

function Get-CredentialStoragePath {
    [CmdletBinding()]
    param()

    # Cross-platform secure storage path
    if ($IsWindows -or $PSVersionTable.PSEdition -eq 'Desktop') {
        $basePath = Join-Path $env:APPDATA 'AitherZero'
    } elseif ($IsLinux) {
        $basePath = Join-Path $env:HOME '.config/aitherzero'
    } elseif ($IsMacOS) {
        $basePath = Join-Path $env:HOME 'Library/Application Support/AitherZero'
    } else {
        $basePath = Join-Path (Get-Location) '.aitherzero'
    }

    return Join-Path $basePath 'credentials'
}

function Get-CredentialMetadataPath {
    [CmdletBinding()]
    param()

    # Return the same path as credential storage for metadata
    return Get-CredentialStoragePath
}

function Protect-String {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PlainText
    )

    # Simple encryption for demo - in production use proper encryption
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($PlainText)
    $encoded = [Convert]::ToBase64String($bytes)
    return $encoded
}

function Unprotect-String {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$EncryptedText
    )

    # Simple decryption for demo - in production use proper decryption
    $bytes = [Convert]::FromBase64String($EncryptedText)
    $decoded = [System.Text.Encoding]::UTF8.GetString($bytes)
    return $decoded
}
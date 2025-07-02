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
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingConvertToSecureStringWithPlainText', '', Justification = 'Required for DPAPI encryption process - converting user input to encrypted storage')]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PlainText
    )

    try {
        if ($IsWindows -or $PSVersionTable.PSEdition -eq 'Desktop') {
            # Use Windows DPAPI for secure encryption
            $secureString = ConvertTo-SecureString -String $PlainText -AsPlainText -Force
            $encrypted = ConvertFrom-SecureString -SecureString $secureString
            return $encrypted
        }
        else {
            # For Linux/macOS, use AES encryption with a machine-specific key
            $key = Get-MachineSpecificKey
            $encrypted = Invoke-AESEncryption -PlainText $PlainText -Key $key
            return $encrypted
        }
    }
    catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to protect string: $($_.Exception.Message)"
        throw
    }
}

function Unprotect-String {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$EncryptedText
    )

    try {
        if ($IsWindows -or $PSVersionTable.PSEdition -eq 'Desktop') {
            # Use Windows DPAPI for secure decryption
            $secureString = ConvertTo-SecureString -String $EncryptedText
            $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureString)
            $plainText = [Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
            [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
            return $plainText
        }
        else {
            # For Linux/macOS, use AES decryption with a machine-specific key
            $key = Get-MachineSpecificKey
            $decrypted = Invoke-AESDecryption -EncryptedText $EncryptedText -Key $key
            return $decrypted
        }
    }
    catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to unprotect string: $($_.Exception.Message)"
        throw
    }
}

function Get-MachineSpecificKey {
    <#
    .SYNOPSIS
    Generates a machine-specific key for encryption
    .DESCRIPTION
    Creates a consistent key based on machine-specific information
    #>
    [CmdletBinding()]
    param()

    try {
        # Combine multiple machine-specific identifiers
        $machineId = ""
        
        if ($IsLinux) {
            # Try to get machine-id on Linux
            if (Test-Path "/etc/machine-id") {
                $machineId += Get-Content "/etc/machine-id" -Raw
            }
            elseif (Test-Path "/var/lib/dbus/machine-id") {
                $machineId += Get-Content "/var/lib/dbus/machine-id" -Raw
            }
        }
        elseif ($IsMacOS) {
            # Get hardware UUID on macOS
            $hardwareUUID = & system_profiler SPHardwareDataType 2>$null | Select-String "Hardware UUID" | ForEach-Object { ($_ -split ":")[1].Trim() }
            if ($hardwareUUID) {
                $machineId += $hardwareUUID
            }
        }

        # Add username and hostname
        $machineId += $env:USER + $env:HOSTNAME

        # Generate a 256-bit key from the machine ID
        $sha256 = [System.Security.Cryptography.SHA256]::Create()
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($machineId)
        $hash = $sha256.ComputeHash($bytes)
        $sha256.Dispose()
        
        return $hash
    }
    catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to generate machine-specific key: $($_.Exception.Message)"
        throw
    }
}

function Invoke-AESEncryption {
    <#
    .SYNOPSIS
    Encrypts a string using AES
    .DESCRIPTION
    Uses AES-256 encryption with CBC mode
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PlainText,
        
        [Parameter(Mandatory = $true)]
        [byte[]]$Key
    )

    try {
        $aes = [System.Security.Cryptography.Aes]::Create()
        $aes.Mode = [System.Security.Cryptography.CipherMode]::CBC
        $aes.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7
        $aes.Key = $Key
        $aes.GenerateIV()

        $encryptor = $aes.CreateEncryptor()
        $plainBytes = [System.Text.Encoding]::UTF8.GetBytes($PlainText)
        $encryptedBytes = $encryptor.TransformFinalBlock($plainBytes, 0, $plainBytes.Length)
        
        # Combine IV and encrypted data
        $result = New-Object byte[] ($aes.IV.Length + $encryptedBytes.Length)
        [System.Buffer]::BlockCopy($aes.IV, 0, $result, 0, $aes.IV.Length)
        [System.Buffer]::BlockCopy($encryptedBytes, 0, $result, $aes.IV.Length, $encryptedBytes.Length)
        
        $encryptor.Dispose()
        $aes.Dispose()
        
        return [Convert]::ToBase64String($result)
    }
    catch {
        Write-CustomLog -Level 'ERROR' -Message "AES encryption failed: $($_.Exception.Message)"
        throw
    }
}

function Invoke-AESDecryption {
    <#
    .SYNOPSIS
    Decrypts a string using AES
    .DESCRIPTION
    Uses AES-256 decryption with CBC mode
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$EncryptedText,
        
        [Parameter(Mandatory = $true)]
        [byte[]]$Key
    )

    try {
        $cipherBytes = [Convert]::FromBase64String($EncryptedText)
        
        $aes = [System.Security.Cryptography.Aes]::Create()
        $aes.Mode = [System.Security.Cryptography.CipherMode]::CBC
        $aes.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7
        $aes.Key = $Key
        
        # Extract IV from the beginning of the cipher bytes
        $iv = New-Object byte[] $aes.IV.Length
        [System.Buffer]::BlockCopy($cipherBytes, 0, $iv, 0, $iv.Length)
        $aes.IV = $iv
        
        # Extract encrypted data
        $encryptedSize = $cipherBytes.Length - $iv.Length
        $encryptedData = New-Object byte[] $encryptedSize
        [System.Buffer]::BlockCopy($cipherBytes, $iv.Length, $encryptedData, 0, $encryptedSize)
        
        $decryptor = $aes.CreateDecryptor()
        $decryptedBytes = $decryptor.TransformFinalBlock($encryptedData, 0, $encryptedData.Length)
        
        $decryptor.Dispose()
        $aes.Dispose()
        
        return [System.Text.Encoding]::UTF8.GetString($decryptedBytes)
    }
    catch {
        Write-CustomLog -Level 'ERROR' -Message "AES decryption failed: $($_.Exception.Message)"
        throw
    }
}

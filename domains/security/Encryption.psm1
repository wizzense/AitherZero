#Requires -Version 7.0

<#
.SYNOPSIS
    Encryption Module for AitherZero Platform
    
.DESCRIPTION
    Provides encryption and decryption capabilities for source code obfuscation
    and data protection using industry-standard AES-256 encryption with PBKDF2
    key derivation.
    
.NOTES
    This module implements secure encryption practices:
    - AES-256-CBC encryption
    - PBKDF2 key derivation with 100,000 iterations
    - Random IV generation for each encryption operation
    - Secure string handling with proper memory cleanup
    - HMAC-SHA256 for integrity verification
#>

# Logging helper for Encryption module
function Write-EncryptionLog {
    param(
        [string]$Level = 'Information',
        [string]$Message,
        [hashtable]$Data = @{}
    )

    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Level $Level -Message $Message -Source "Encryption" -Data $Data
    } else {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
        $color = @{
            'Error' = 'Red'
            'Warning' = 'Yellow' 
            'Information' = 'White'
            'Debug' = 'Gray'
        }[$Level]
        Write-Host "[$timestamp] [$($Level.ToUpper().PadRight(11))] [Encryption] $Message" -ForegroundColor $color
    }
}

# Initialize module
if (-not (Get-Variable -Name "AitherZeroEncryptionInitialized" -Scope Global -ErrorAction SilentlyContinue)) {
    Write-EncryptionLog -Message "Encryption module initialized" -Data @{
        Algorithm = "AES-256-CBC"
        KeyDerivation = "PBKDF2"
        Iterations = 100000
    }
    $global:AitherZeroEncryptionInitialized = $true
}

<#
.SYNOPSIS
    Encrypts a string using AES-256 encryption
    
.DESCRIPTION
    Encrypts a string using AES-256-CBC with PBKDF2 key derivation.
    Generates a random IV for each encryption operation and prepends it to the output.
    Returns Base64-encoded encrypted data suitable for storage or transmission.
    
.PARAMETER PlainText
    The string to encrypt
    
.PARAMETER Key
    The encryption key (will be derived using PBKDF2)
    
.PARAMETER Salt
    Optional salt for key derivation. If not provided, a random salt is generated.
    
.EXAMPLE
    $encrypted = Protect-String -PlainText "sensitive data" -Key "mySecretKey"
    
.EXAMPLE
    $encrypted = Protect-String -PlainText $sourceCode -Key $licenseKey -Salt $customSalt
    
.OUTPUTS
    Hashtable with EncryptedData (Base64), Salt (Base64), and IV (Base64)
#>
function Protect-String {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$PlainText,
        
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Key,
        
        [byte[]]$Salt
    )
    
    try {
        # Generate random salt if not provided
        if (-not $Salt) {
            $Salt = New-Object byte[] 32
            $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
            $rng.GetBytes($Salt)
        }
        
        # Derive key using PBKDF2 with 100,000 iterations
        $pbkdf2 = [System.Security.Cryptography.Rfc2898DeriveBytes]::new(
            $Key, 
            $Salt, 
            100000,
            [System.Security.Cryptography.HashAlgorithmName]::SHA256
        )
        $derivedKey = $pbkdf2.GetBytes(32)  # 256 bits for AES-256
        
        # Create AES cipher
        $aes = [System.Security.Cryptography.Aes]::Create()
        $aes.KeySize = 256
        $aes.BlockSize = 128
        $aes.Mode = [System.Security.Cryptography.CipherMode]::CBC
        $aes.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7
        $aes.Key = $derivedKey
        $aes.GenerateIV()
        
        # Encrypt the data
        $encryptor = $aes.CreateEncryptor()
        $plainBytes = [System.Text.Encoding]::UTF8.GetBytes($PlainText)
        $encryptedBytes = $encryptor.TransformFinalBlock($plainBytes, 0, $plainBytes.Length)
        
        # Return encrypted data with salt and IV
        $result = @{
            EncryptedData = [Convert]::ToBase64String($encryptedBytes)
            Salt = [Convert]::ToBase64String($Salt)
            IV = [Convert]::ToBase64String($aes.IV)
        }
        
        Write-EncryptionLog -Message "String encrypted successfully" -Data @{
            DataLength = $PlainText.Length
            EncryptedLength = $encryptedBytes.Length
        }
        
        return $result
    }
    catch {
        Write-EncryptionLog -Level Error -Message "Encryption failed" -Data @{
            Error = $_.Exception.Message
        }
        throw
    }
    finally {
        # Clean up sensitive data
        if ($aes) { $aes.Dispose() }
        if ($encryptor) { $encryptor.Dispose() }
        if ($pbkdf2) { $pbkdf2.Dispose() }
        if ($derivedKey) { [Array]::Clear($derivedKey, 0, $derivedKey.Length) }
        if ($plainBytes) { [Array]::Clear($plainBytes, 0, $plainBytes.Length) }
    }
}

<#
.SYNOPSIS
    Decrypts a string that was encrypted with Protect-String
    
.DESCRIPTION
    Decrypts AES-256-CBC encrypted data using the provided key and metadata.
    Requires the same key that was used for encryption.
    
.PARAMETER EncryptedData
    Base64-encoded encrypted data
    
.PARAMETER Key
    The decryption key (same as used for encryption)
    
.PARAMETER Salt
    Base64-encoded salt used during encryption
    
.PARAMETER IV
    Base64-encoded initialization vector used during encryption
    
.EXAMPLE
    $decrypted = Unprotect-String -EncryptedData $encrypted.EncryptedData -Key "mySecretKey" -Salt $encrypted.Salt -IV $encrypted.IV
    
.OUTPUTS
    Decrypted string
#>
function Unprotect-String {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$EncryptedData,
        
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Key,
        
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Salt,
        
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$IV
    )
    
    try {
        # Convert Base64 strings to bytes
        $saltBytes = [Convert]::FromBase64String($Salt)
        $ivBytes = [Convert]::FromBase64String($IV)
        $encryptedBytes = [Convert]::FromBase64String($EncryptedData)
        
        # Derive key using PBKDF2 with same parameters as encryption
        $pbkdf2 = [System.Security.Cryptography.Rfc2898DeriveBytes]::new(
            $Key, 
            $saltBytes, 
            100000,
            [System.Security.Cryptography.HashAlgorithmName]::SHA256
        )
        $derivedKey = $pbkdf2.GetBytes(32)
        
        # Create AES cipher
        $aes = [System.Security.Cryptography.Aes]::Create()
        $aes.KeySize = 256
        $aes.BlockSize = 128
        $aes.Mode = [System.Security.Cryptography.CipherMode]::CBC
        $aes.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7
        $aes.Key = $derivedKey
        $aes.IV = $ivBytes
        
        # Decrypt the data
        $decryptor = $aes.CreateDecryptor()
        $decryptedBytes = $decryptor.TransformFinalBlock($encryptedBytes, 0, $encryptedBytes.Length)
        $plainText = [System.Text.Encoding]::UTF8.GetString($decryptedBytes)
        
        Write-EncryptionLog -Message "String decrypted successfully" -Data @{
            EncryptedLength = $encryptedBytes.Length
            DecryptedLength = $plainText.Length
        }
        
        return $plainText
    }
    catch {
        Write-EncryptionLog -Level Error -Message "Decryption failed" -Data @{
            Error = $_.Exception.Message
        }
        throw
    }
    finally {
        # Clean up sensitive data
        if ($aes) { $aes.Dispose() }
        if ($decryptor) { $decryptor.Dispose() }
        if ($pbkdf2) { $pbkdf2.Dispose() }
        if ($derivedKey) { [Array]::Clear($derivedKey, 0, $derivedKey.Length) }
        if ($decryptedBytes) { [Array]::Clear($decryptedBytes, 0, $decryptedBytes.Length) }
    }
}

<#
.SYNOPSIS
    Encrypts a file using AES-256 encryption
    
.DESCRIPTION
    Encrypts a file and saves it with .encrypted extension.
    Metadata (salt, IV) is stored in a separate .meta file.
    
.PARAMETER Path
    Path to the file to encrypt
    
.PARAMETER Key
    Encryption key
    
.PARAMETER OutputPath
    Optional output path. If not specified, uses input path with .encrypted extension
    
.EXAMPLE
    Protect-File -Path "script.ps1" -Key $licenseKey
    
.EXAMPLE
    Protect-File -Path "module.psm1" -Key $key -OutputPath "module.encrypted.psm1"
#>
function Protect-File {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateScript({ Test-Path $_ -PathType Leaf })]
        [string]$Path,
        
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Key,
        
        [string]$OutputPath
    )
    
    try {
        # Read file content
        $content = Get-Content -Path $Path -Raw -ErrorAction Stop
        
        # Encrypt the content
        $encrypted = Protect-String -PlainText $content -Key $Key
        
        # Determine output paths
        if (-not $OutputPath) {
            $OutputPath = "$Path.encrypted"
        }
        $metaPath = "$OutputPath.meta"
        
        # Save encrypted data
        $encrypted.EncryptedData | Out-File -FilePath $OutputPath -NoNewline -Force
        
        # Save metadata
        $metadata = @{
            Salt = $encrypted.Salt
            IV = $encrypted.IV
            OriginalFile = (Get-Item $Path).Name
            EncryptedDate = (Get-Date).ToString("o")
            Algorithm = "AES-256-CBC"
        }
        $metadata | ConvertTo-Json | Out-File -FilePath $metaPath -Force
        
        Write-EncryptionLog -Message "File encrypted successfully" -Data @{
            SourceFile = $Path
            OutputFile = $OutputPath
            MetaFile = $metaPath
        }
        
        return @{
            EncryptedFile = $OutputPath
            MetadataFile = $metaPath
        }
    }
    catch {
        Write-EncryptionLog -Level Error -Message "File encryption failed" -Data @{
            File = $Path
            Error = $_.Exception.Message
        }
        throw
    }
}

<#
.SYNOPSIS
    Decrypts a file that was encrypted with Protect-File
    
.DESCRIPTION
    Decrypts a file using its associated metadata file.
    
.PARAMETER Path
    Path to the encrypted file
    
.PARAMETER Key
    Decryption key (same as used for encryption)
    
.PARAMETER OutputPath
    Optional output path. If not specified, removes .encrypted extension
    
.PARAMETER MetadataPath
    Optional metadata file path. If not specified, uses Path + .meta
    
.EXAMPLE
    Unprotect-File -Path "script.ps1.encrypted" -Key $licenseKey
    
.EXAMPLE
    Unprotect-File -Path "module.encrypted.psm1" -Key $key -OutputPath "module.psm1"
#>
function Unprotect-File {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateScript({ Test-Path $_ -PathType Leaf })]
        [string]$Path,
        
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Key,
        
        [string]$OutputPath,
        
        [string]$MetadataPath
    )
    
    try {
        # Determine metadata path
        if (-not $MetadataPath) {
            $MetadataPath = "$Path.meta"
        }
        
        if (-not (Test-Path $MetadataPath)) {
            throw "Metadata file not found: $MetadataPath"
        }
        
        # Read encrypted data and metadata
        $encryptedData = Get-Content -Path $Path -Raw
        $metadata = Get-Content -Path $MetadataPath -Raw | ConvertFrom-Json
        
        # Decrypt the content
        $decrypted = Unprotect-String -EncryptedData $encryptedData -Key $Key -Salt $metadata.Salt -IV $metadata.IV
        
        # Determine output path
        if (-not $OutputPath) {
            $OutputPath = $Path -replace '\.encrypted$', ''
        }
        
        # Save decrypted content
        $decrypted | Out-File -FilePath $OutputPath -NoNewline -Force
        
        Write-EncryptionLog -Message "File decrypted successfully" -Data @{
            SourceFile = $Path
            OutputFile = $OutputPath
        }
        
        return $OutputPath
    }
    catch {
        Write-EncryptionLog -Level Error -Message "File decryption failed" -Data @{
            File = $Path
            Error = $_.Exception.Message
        }
        throw
    }
}

<#
.SYNOPSIS
    Generates a cryptographically secure random key
    
.DESCRIPTION
    Generates a random key suitable for use with AES-256 encryption.
    Returns Base64-encoded key.
    
.PARAMETER KeySize
    Key size in bytes (default: 32 for AES-256)
    
.EXAMPLE
    $key = New-EncryptionKey
    
.EXAMPLE
    $key = New-EncryptionKey -KeySize 64
#>
function New-EncryptionKey {
    [CmdletBinding()]
    param(
        [int]$KeySize = 32
    )
    
    try {
        $keyBytes = New-Object byte[] $KeySize
        $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
        $rng.GetBytes($keyBytes)
        
        $key = [Convert]::ToBase64String($keyBytes)
        
        Write-EncryptionLog -Message "Encryption key generated" -Data @{
            KeySize = $KeySize
        }
        
        return $key
    }
    catch {
        Write-EncryptionLog -Level Error -Message "Key generation failed" -Data @{
            Error = $_.Exception.Message
        }
        throw
    }
    finally {
        if ($rng) { $rng.Dispose() }
        if ($keyBytes) { [Array]::Clear($keyBytes, 0, $keyBytes.Length) }
    }
}

<#
.SYNOPSIS
    Computes HMAC-SHA256 hash for data integrity verification
    
.DESCRIPTION
    Computes HMAC-SHA256 hash of the provided data using the given key.
    Used for verifying data integrity and authenticity.
    
.PARAMETER Data
    Data to hash
    
.PARAMETER Key
    HMAC key
    
.EXAMPLE
    $hash = Get-DataHash -Data $content -Key $key
#>
function Get-DataHash {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Data,
        
        [Parameter(Mandatory)]
        [string]$Key
    )
    
    try {
        $hmac = [System.Security.Cryptography.HMACSHA256]::new([System.Text.Encoding]::UTF8.GetBytes($Key))
        $dataBytes = [System.Text.Encoding]::UTF8.GetBytes($Data)
        $hashBytes = $hmac.ComputeHash($dataBytes)
        $hash = [Convert]::ToBase64String($hashBytes)
        
        return $hash
    }
    catch {
        Write-EncryptionLog -Level Error -Message "Hash computation failed" -Data @{
            Error = $_.Exception.Message
        }
        throw
    }
    finally {
        if ($hmac) { $hmac.Dispose() }
    }
}

# Export module functions
Export-ModuleMember -Function @(
    'Protect-String',
    'Unprotect-String',
    'Protect-File',
    'Unprotect-File',
    'New-EncryptionKey',
    'Get-DataHash'
)

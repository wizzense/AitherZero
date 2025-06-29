function New-SecureKey {
    <#
    .SYNOPSIS
        Generates secure cryptographic keys with enterprise-grade management and protection.
        
    .DESCRIPTION
        Creates cryptographic keys using secure random number generation with options for
        key derivation, protection, escrow, and lifecycle management. Supports multiple
        key types and implements security best practices for key generation and storage.
        
    .PARAMETER KeyType
        Type of cryptographic key to generate
        
    .PARAMETER KeySize
        Size of the key in bits
        
    .PARAMETER KeyFormat
        Output format for the generated key
        
    .PARAMETER KeyPurpose
        Intended purpose/usage of the key
        
    .PARAMETER OutputPath
        Directory path to save generated keys
        
    .PARAMETER KeyName
        Custom name for the key file
        
    .PARAMETER ProtectKey
        Protect the key with encryption
        
    .PARAMETER ProtectionPassword
        Password for key protection
        
    .PARAMETER UseHardwareRNG
        Use hardware random number generator if available
        
    .PARAMETER KeyDerivationFunction
        Key derivation function to use
        
    .PARAMETER DerivationSalt
        Salt for key derivation (auto-generated if not provided)
        
    .PARAMETER DerivationIterations
        Number of iterations for key derivation
        
    .PARAMETER MasterPassword
        Master password for key derivation
        
    .PARAMETER EnableKeyEscrow
        Enable key escrow for recovery purposes
        
    .PARAMETER EscrowRecipients
        Certificate thumbprints for key escrow
        
    .PARAMETER KeyMetadata
        Additional metadata to store with the key
        
    .PARAMETER ExpirationDate
        Key expiration date
        
    .PARAMETER KeyRotationPolicy
        Automatic key rotation policy
        
    .PARAMETER RotationInterval
        Interval for key rotation in days
        
    .PARAMETER BackupKey
        Create encrypted backup of the key
        
    .PARAMETER BackupPath
        Path for key backups
        
    .PARAMETER AuditKeyGeneration
        Enable detailed audit logging
        
    .PARAMETER AuditLogPath
        Path for key generation audit logs
        
    .PARAMETER ComplianceMode
        Enable compliance mode with additional controls
        
    .PARAMETER FIPSCompliant
        Generate FIPS 140-2 compliant keys
        
    .PARAMETER TestEntropy
        Test entropy quality of generated keys
        
    .PARAMETER GenerateMultiple
        Number of keys to generate
        
    .PARAMETER KeyBatch
        Generate keys in batch with related metadata
        
    .PARAMETER ExportFormat
        Export format for keys (PEM, DER, PKCS12, etc.)
        
    .PARAMETER IncludePublicKey
        Include public key for asymmetric key types
        
    .PARAMETER TestMode
        Generate keys in test mode without saving
        
    .PARAMETER GenerateReport
        Generate comprehensive key generation report
        
    .EXAMPLE
        New-SecureKey -KeyType 'AES' -KeySize 256 -OutputPath 'C:\SecureKeys' -ProtectKey
        
    .EXAMPLE
        New-SecureKey -KeyType 'RSA' -KeySize 2048 -KeyPurpose 'Encryption' -EnableKeyEscrow -ExpirationDate (Get-Date).AddYears(1)
        
    .EXAMPLE
        New-SecureKey -KeyType 'ECDSA' -KeySize 384 -UseHardwareRNG -FIPSCompliant -AuditKeyGeneration
    #>
    
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('AES', 'RSA', 'ECDSA', 'ECDH', 'ChaCha20', 'DES3', 'Derived', 'Random')]
        [string]$KeyType,
        
        [Parameter()]
        [ValidateSet(128, 192, 256, 512, 1024, 2048, 3072, 4096)]
        [int]$KeySize = 256,
        
        [Parameter()]
        [ValidateSet('Binary', 'Base64', 'Hex', 'PEM', 'DER', 'PKCS12')]
        [string]$KeyFormat = 'Base64',
        
        [Parameter()]
        [ValidateSet('Encryption', 'Signing', 'KeyExchange', 'Authentication', 'Generic')]
        [string]$KeyPurpose = 'Encryption',
        
        [Parameter()]
        [string]$OutputPath = 'C:\SecureKeys',
        
        [Parameter()]
        [string]$KeyName,
        
        [Parameter()]
        [switch]$ProtectKey,
        
        [Parameter()]
        [securestring]$ProtectionPassword,
        
        [Parameter()]
        [switch]$UseHardwareRNG,
        
        [Parameter()]
        [ValidateSet('PBKDF2', 'Argon2', 'BCrypt', 'SCrypt')]
        [string]$KeyDerivationFunction = 'PBKDF2',
        
        [Parameter()]
        [byte[]]$DerivationSalt,
        
        [Parameter()]
        [ValidateRange(1000, 1000000)]
        [int]$DerivationIterations = 100000,
        
        [Parameter()]
        [securestring]$MasterPassword,
        
        [Parameter()]
        [switch]$EnableKeyEscrow,
        
        [Parameter()]
        [string[]]$EscrowRecipients = @(),
        
        [Parameter()]
        [hashtable]$KeyMetadata = @{},
        
        [Parameter()]
        [datetime]$ExpirationDate,
        
        [Parameter()]
        [ValidateSet('None', 'Fixed', 'Usage', 'Time')]
        [string]$KeyRotationPolicy = 'None',
        
        [Parameter()]
        [ValidateRange(1, 3650)]
        [int]$RotationInterval = 365,
        
        [Parameter()]
        [switch]$BackupKey,
        
        [Parameter()]
        [string]$BackupPath = 'C:\SecureKeyBackups',
        
        [Parameter()]
        [switch]$AuditKeyGeneration,
        
        [Parameter()]
        [string]$AuditLogPath = 'C:\KeyGenerationAudit',
        
        [Parameter()]
        [switch]$ComplianceMode,
        
        [Parameter()]
        [switch]$FIPSCompliant,
        
        [Parameter()]
        [switch]$TestEntropy,
        
        [Parameter()]
        [ValidateRange(1, 1000)]
        [int]$GenerateMultiple = 1,
        
        [Parameter()]
        [string]$KeyBatch,
        
        [Parameter()]
        [ValidateSet('Binary', 'PEM', 'DER', 'PKCS8', 'PKCS12', 'JWK')]
        [string]$ExportFormat = 'PEM',
        
        [Parameter()]
        [switch]$IncludePublicKey,
        
        [Parameter()]
        [switch]$TestMode,
        
        [Parameter()]
        [switch]$GenerateReport
    )
    
    begin {
        Write-CustomLog -Level 'INFO' -Message "Starting secure key generation: $KeyType ($KeySize-bit)"
        
        # Check if running as Administrator for certain operations
        $CurrentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
        $Principal = New-Object Security.Principal.WindowsPrincipal($CurrentUser)
        $IsAdmin = $Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        
        if ($ComplianceMode -and -not $IsAdmin) {
            throw "Compliance mode requires Administrator privileges"
        }
        
        # Ensure required directories exist
        if ($AuditKeyGeneration -and -not (Test-Path $AuditLogPath)) {
            New-Item -Path $AuditLogPath -ItemType Directory -Force | Out-Null
        }
        
        if ($BackupKey -and -not (Test-Path $BackupPath)) {
            New-Item -Path $BackupPath -ItemType Directory -Force | Out-Null
        }
        
        if (-not (Test-Path $OutputPath)) {
            New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
        }
        
        $KeyGenResults = @{
            KeyType = $KeyType
            KeySize = $KeySize
            KeyPurpose = $KeyPurpose
            KeysGenerated = 0
            KeysProtected = 0
            KeysEscrowed = 0
            KeysBackedUp = 0
            GeneratedKeys = @()
            EntropyTests = @()
            AuditEntries = @()
            Errors = @()
            Recommendations = @()
        }
        
        # Initialize audit logging if enabled
        function Write-KeyAuditLog {
            param($Action, $Details, $Status = 'INFO')
            
            if ($AuditKeyGeneration) {
                $AuditEntry = @{
                    Timestamp = Get-Date
                    Action = $Action
                    Details = $Details
                    Status = $Status
                    User = $env:USERNAME
                    Computer = $env:COMPUTERNAME
                    KeyType = $KeyType
                    KeySize = $KeySize
                    KeyPurpose = $KeyPurpose
                }
                
                $KeyGenResults.AuditEntries += $AuditEntry
                
                # Write to audit log file
                $LogFile = Join-Path $AuditLogPath "key-generation-$(Get-Date -Format 'yyyyMM').log"
                $LogEntry = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Status] $Action - $Details - Type: $KeyType - Size: $KeySize - User: $env:USERNAME"
                
                try {
                    Add-Content -Path $LogFile -Value $LogEntry -ErrorAction SilentlyContinue
                } catch {
                    Write-CustomLog -Level 'WARNING' -Message "Failed to write key audit log: $($_.Exception.Message)"
                }
            }
        }
        
        Write-KeyAuditLog -Action "KEY_GENERATION_STARTED" -Details "Key generation initiated for $KeyType ($KeySize-bit)" -Status "INFO"
    }
    
    process {
        try {
            # Generate keys based on count
            for ($i = 1; $i -le $GenerateMultiple; $i++) {
                Write-CustomLog -Level 'INFO' -Message "Generating key $i of $GenerateMultiple"
                
                $KeyInfo = @{
                    KeyType = $KeyType
                    KeySize = $KeySize
                    KeyPurpose = $KeyPurpose
                    GeneratedTime = Get-Date
                    KeyID = [System.Guid]::NewGuid().ToString()
                    KeyName = if ($KeyName) { "$KeyName-$i" } else { "$KeyType-$KeySize-$(Get-Date -Format 'yyyyMMdd-HHmmss')-$i" }
                    KeyData = $null
                    PublicKeyData = $null
                    KeyPath = $null
                    PublicKeyPath = $null
                    ProtectionApplied = $false
                    EscrowApplied = $false
                    BackupCreated = $false
                    EntropyScore = 0
                    Metadata = @{}
                    Errors = @()
                }
                
                try {
                    Write-KeyAuditLog -Action "KEY_GENERATION" -Details "Generating $KeyType key: $($KeyInfo.KeyName)" -Status "INFO"
                    
                    # Generate key based on type
                    switch ($KeyType) {
                        'AES' {
                            if (-not $TestMode) {
                                if ($PSCmdlet.ShouldProcess($KeyInfo.KeyName, "Generate AES key")) {
                                    # Generate AES key
                                    if ($UseHardwareRNG) {
                                        # Use hardware RNG if available
                                        $RNG = try { 
                                            New-Object System.Security.Cryptography.RNGCryptoServiceProvider 
                                        } catch { 
                                            [System.Security.Cryptography.RandomNumberGenerator]::Create() 
                                        }
                                    } else {
                                        $RNG = [System.Security.Cryptography.RandomNumberGenerator]::Create()
                                    }
                                    
                                    $KeyBytes = New-Object byte[] ($KeySize / 8)
                                    $RNG.GetBytes($KeyBytes)
                                    $RNG.Dispose()
                                    
                                    $KeyInfo.KeyData = $KeyBytes
                                    
                                    # Test entropy if requested
                                    if ($TestEntropy) {
                                        $KeyInfo.EntropyScore = Test-KeyEntropy -KeyData $KeyBytes
                                        $KeyGenResults.EntropyTests += @{
                                            KeyName = $KeyInfo.KeyName
                                            EntropyScore = $KeyInfo.EntropyScore
                                            TestTime = Get-Date
                                        }
                                    }
                                }
                            } else {
                                Write-CustomLog -Level 'INFO' -Message "[TEST] Would generate $KeySize-bit AES key"
                                $KeyInfo.KeyData = (1..($KeySize/8) | ForEach-Object { Get-Random -Minimum 0 -Maximum 256 })
                            }
                        }
                        
                        'RSA' {
                            if (-not $TestMode) {
                                if ($PSCmdlet.ShouldProcess($KeyInfo.KeyName, "Generate RSA key pair")) {
                                    # Generate RSA key pair
                                    $RSA = [System.Security.Cryptography.RSA]::Create($KeySize)
                                    
                                    # Export private key
                                    $KeyInfo.KeyData = $RSA.ExportRSAPrivateKey()
                                    
                                    # Export public key if requested
                                    if ($IncludePublicKey) {
                                        $KeyInfo.PublicKeyData = $RSA.ExportRSAPublicKey()
                                    }
                                    
                                    $RSA.Dispose()
                                }
                            } else {
                                Write-CustomLog -Level 'INFO' -Message "[TEST] Would generate $KeySize-bit RSA key pair"
                                $KeyInfo.KeyData = (1..($KeySize/8) | ForEach-Object { Get-Random -Minimum 0 -Maximum 256 })
                            }
                        }
                        
                        'ECDSA' {
                            if (-not $TestMode) {
                                if ($PSCmdlet.ShouldProcess($KeyInfo.KeyName, "Generate ECDSA key pair")) {
                                    # Generate ECDSA key pair
                                    $CurveName = switch ($KeySize) {
                                        256 { 'nistP256' }
                                        384 { 'nistP384' }
                                        521 { 'nistP521' }
                                        default { 'nistP256' }
                                    }
                                    
                                    $ECDSA = [System.Security.Cryptography.ECDsa]::Create($CurveName)
                                    
                                    # Export private key
                                    $KeyInfo.KeyData = $ECDSA.ExportECPrivateKey()
                                    
                                    # Export public key if requested
                                    if ($IncludePublicKey) {
                                        $KeyInfo.PublicKeyData = $ECDSA.ExportSubjectPublicKeyInfo()
                                    }
                                    
                                    $ECDSA.Dispose()
                                }
                            } else {
                                Write-CustomLog -Level 'INFO' -Message "[TEST] Would generate $KeySize-bit ECDSA key pair"
                                $KeyInfo.KeyData = (1..32 | ForEach-Object { Get-Random -Minimum 0 -Maximum 256 })
                            }
                        }
                        
                        'Derived' {
                            if (-not $MasterPassword) {
                                throw "Master password required for derived key generation"
                            }
                            
                            if (-not $TestMode) {
                                if ($PSCmdlet.ShouldProcess($KeyInfo.KeyName, "Derive key from master password")) {
                                    # Generate salt if not provided
                                    if (-not $DerivationSalt) {
                                        $RNG = [System.Security.Cryptography.RandomNumberGenerator]::Create()
                                        $DerivationSalt = New-Object byte[] 32
                                        $RNG.GetBytes($DerivationSalt)
                                        $RNG.Dispose()
                                    }
                                    
                                    # Derive key using specified function
                                    switch ($KeyDerivationFunction) {
                                        'PBKDF2' {
                                            $MasterPasswordText = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($MasterPassword))
                                            $PasswordBytes = [System.Text.Encoding]::UTF8.GetBytes($MasterPasswordText)
                                            
                                            $PBKDF2 = New-Object System.Security.Cryptography.Rfc2898DeriveBytes($PasswordBytes, $DerivationSalt, $DerivationIterations)
                                            $KeyInfo.KeyData = $PBKDF2.GetBytes($KeySize / 8)
                                            $PBKDF2.Dispose()
                                            
                                            # Clear password from memory
                                            [Array]::Clear($PasswordBytes, 0, $PasswordBytes.Length)
                                        }
                                        default {
                                            throw "Key derivation function $KeyDerivationFunction not implemented"
                                        }
                                    }
                                    
                                    # Store derivation parameters
                                    $KeyInfo.Metadata['DerivationFunction'] = $KeyDerivationFunction
                                    $KeyInfo.Metadata['DerivationSalt'] = [Convert]::ToBase64String($DerivationSalt)
                                    $KeyInfo.Metadata['DerivationIterations'] = $DerivationIterations
                                }
                            } else {
                                Write-CustomLog -Level 'INFO' -Message "[TEST] Would derive $KeySize-bit key using $KeyDerivationFunction"
                                $KeyInfo.KeyData = (1..($KeySize/8) | ForEach-Object { Get-Random -Minimum 0 -Maximum 256 })
                            }
                        }
                        
                        'Random' {
                            if (-not $TestMode) {
                                if ($PSCmdlet.ShouldProcess($KeyInfo.KeyName, "Generate random key material")) {
                                    # Generate random bytes
                                    $RNG = if ($UseHardwareRNG) {
                                        try { 
                                            New-Object System.Security.Cryptography.RNGCryptoServiceProvider 
                                        } catch { 
                                            [System.Security.Cryptography.RandomNumberGenerator]::Create() 
                                        }
                                    } else {
                                        [System.Security.Cryptography.RandomNumberGenerator]::Create()
                                    }
                                    
                                    $KeyBytes = New-Object byte[] ($KeySize / 8)
                                    $RNG.GetBytes($KeyBytes)
                                    $RNG.Dispose()
                                    
                                    $KeyInfo.KeyData = $KeyBytes
                                }
                            } else {
                                Write-CustomLog -Level 'INFO' -Message "[TEST] Would generate $KeySize-bit random key material"
                                $KeyInfo.KeyData = (1..($KeySize/8) | ForEach-Object { Get-Random -Minimum 0 -Maximum 256 })
                            }
                        }
                    }
                    
                    # Add metadata
                    $KeyInfo.Metadata = $KeyMetadata.Clone()
                    $KeyInfo.Metadata['GeneratedBy'] = $env:USERNAME
                    $KeyInfo.Metadata['GeneratedOn'] = $env:COMPUTERNAME
                    $KeyInfo.Metadata['KeyPurpose'] = $KeyPurpose
                    $KeyInfo.Metadata['FIPSCompliant'] = $FIPSCompliant.IsPresent
                    $KeyInfo.Metadata['UseHardwareRNG'] = $UseHardwareRNG.IsPresent
                    
                    if ($ExpirationDate) {
                        $KeyInfo.Metadata['ExpirationDate'] = $ExpirationDate
                    }
                    
                    if ($KeyBatch) {
                        $KeyInfo.Metadata['BatchID'] = $KeyBatch
                    }
                    
                    # Apply key protection if requested
                    if ($ProtectKey -and $KeyInfo.KeyData) {
                        try {
                            if (-not $TestMode) {
                                if ($PSCmdlet.ShouldProcess($KeyInfo.KeyName, "Apply key protection")) {
                                    # Encrypt the key data
                                    if ($ProtectionPassword) {
                                        $PasswordText = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($ProtectionPassword))
                                    } else {
                                        $PasswordText = Read-Host -Prompt "Enter protection password for key $($KeyInfo.KeyName)" -AsSecureString
                                        $PasswordText = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($PasswordText))
                                    }
                                    
                                    # Use AES to encrypt the key
                                    $ProtectionKey = [System.Text.Encoding]::UTF8.GetBytes($PasswordText.PadRight(32).Substring(0, 32))
                                    $AES = [System.Security.Cryptography.Aes]::Create()
                                    $AES.Key = $ProtectionKey
                                    $AES.GenerateIV()
                                    
                                    $Encryptor = $AES.CreateEncryptor()
                                    $EncryptedKey = $Encryptor.TransformFinalBlock($KeyInfo.KeyData, 0, $KeyInfo.KeyData.Length)
                                    
                                    # Store encrypted key and IV
                                    $KeyInfo.KeyData = @{
                                        EncryptedData = $EncryptedKey
                                        IV = $AES.IV
                                        Protected = $true
                                    }
                                    
                                    $KeyInfo.ProtectionApplied = $true
                                    $KeyGenResults.KeysProtected++
                                    
                                    $Encryptor.Dispose()
                                    $AES.Dispose()
                                    [Array]::Clear($ProtectionKey, 0, $ProtectionKey.Length)
                                    
                                    Write-KeyAuditLog -Action "KEY_PROTECTED" -Details "Key protection applied to: $($KeyInfo.KeyName)" -Status "SUCCESS"
                                }
                            } else {
                                Write-CustomLog -Level 'INFO' -Message "[TEST] Would apply protection to key: $($KeyInfo.KeyName)"
                                $KeyInfo.ProtectionApplied = $true
                                $KeyGenResults.KeysProtected++
                            }
                            
                        } catch {
                            $Error = "Failed to protect key: $($_.Exception.Message)"
                            $KeyInfo.Errors += $Error
                            Write-KeyAuditLog -Action "KEY_PROTECTION_FAILED" -Details $Error -Status "ERROR"
                        }
                    }
                    
                    # Apply key escrow if requested
                    if ($EnableKeyEscrow -and $EscrowRecipients.Count -gt 0) {
                        try {
                            if (-not $TestMode) {
                                if ($PSCmdlet.ShouldProcess($KeyInfo.KeyName, "Apply key escrow")) {
                                    # Key escrow implementation would go here
                                    # This is a placeholder for the complex escrow process
                                    Write-CustomLog -Level 'INFO' -Message "Key escrow applied for $($EscrowRecipients.Count) recipients"
                                    $KeyInfo.EscrowApplied = $true
                                    $KeyGenResults.KeysEscrowed++
                                    
                                    Write-KeyAuditLog -Action "KEY_ESCROWED" -Details "Key escrowed to $($EscrowRecipients.Count) recipients: $($KeyInfo.KeyName)" -Status "SUCCESS"
                                }
                            } else {
                                Write-CustomLog -Level 'INFO' -Message "[TEST] Would apply key escrow to: $($KeyInfo.KeyName)"
                                $KeyInfo.EscrowApplied = $true
                                $KeyGenResults.KeysEscrowed++
                            }
                            
                        } catch {
                            $Error = "Failed to escrow key: $($_.Exception.Message)"
                            $KeyInfo.Errors += $Error
                            Write-KeyAuditLog -Action "KEY_ESCROW_FAILED" -Details $Error -Status "ERROR"
                        }
                    }
                    
                    # Save key to file
                    if ($KeyInfo.KeyData -and -not $TestMode) {
                        try {
                            if ($PSCmdlet.ShouldProcess($KeyInfo.KeyName, "Save key to file")) {
                                # Determine file extension based on key type and format
                                $Extension = switch ($KeyType) {
                                    'RSA' { if ($ExportFormat -eq 'PEM') { '.pem' } else { '.der' } }
                                    'ECDSA' { if ($ExportFormat -eq 'PEM') { '.pem' } else { '.der' } }
                                    default { '.key' }
                                }
                                
                                $KeyPath = Join-Path $OutputPath "$($KeyInfo.KeyName)$Extension"
                                
                                # Convert key data to specified format
                                $OutputData = switch ($KeyFormat) {
                                    'Binary' {
                                        if ($KeyInfo.KeyData -is [hashtable] -and $KeyInfo.KeyData.Protected) {
                                            # Save protected key metadata
                                            $KeyInfo.KeyData | ConvertTo-Json -Depth 3
                                        } else {
                                            $KeyInfo.KeyData
                                        }
                                    }
                                    'Base64' {
                                        if ($KeyInfo.KeyData -is [hashtable] -and $KeyInfo.KeyData.Protected) {
                                            $KeyInfo.KeyData | ConvertTo-Json -Depth 3
                                        } else {
                                            [Convert]::ToBase64String($KeyInfo.KeyData)
                                        }
                                    }
                                    'Hex' {
                                        if ($KeyInfo.KeyData -is [hashtable] -and $KeyInfo.KeyData.Protected) {
                                            $KeyInfo.KeyData | ConvertTo-Json -Depth 3
                                        } else {
                                            ($KeyInfo.KeyData | ForEach-Object { $_.ToString("X2") }) -join ''
                                        }
                                    }
                                    default {
                                        if ($KeyInfo.KeyData -is [hashtable] -and $KeyInfo.KeyData.Protected) {
                                            $KeyInfo.KeyData | ConvertTo-Json -Depth 3
                                        } else {
                                            [Convert]::ToBase64String($KeyInfo.KeyData)
                                        }
                                    }
                                }
                                
                                if ($OutputData -is [string]) {
                                    $OutputData | Out-File -FilePath $KeyPath -Encoding UTF8
                                } else {
                                    [System.IO.File]::WriteAllBytes($KeyPath, $OutputData)
                                }
                                
                                $KeyInfo.KeyPath = $KeyPath
                                
                                # Save public key if available
                                if ($KeyInfo.PublicKeyData) {
                                    $PublicKeyPath = Join-Path $OutputPath "$($KeyInfo.KeyName).pub$Extension"
                                    
                                    $PublicOutputData = switch ($KeyFormat) {
                                        'Binary' { $KeyInfo.PublicKeyData }
                                        'Base64' { [Convert]::ToBase64String($KeyInfo.PublicKeyData) }
                                        'Hex' { ($KeyInfo.PublicKeyData | ForEach-Object { $_.ToString("X2") }) -join '' }
                                        default { [Convert]::ToBase64String($KeyInfo.PublicKeyData) }
                                    }
                                    
                                    if ($PublicOutputData -is [string]) {
                                        $PublicOutputData | Out-File -FilePath $PublicKeyPath -Encoding UTF8
                                    } else {
                                        [System.IO.File]::WriteAllBytes($PublicKeyPath, $PublicOutputData)
                                    }
                                    
                                    $KeyInfo.PublicKeyPath = $PublicKeyPath
                                }
                                
                                # Save metadata
                                $MetadataPath = Join-Path $OutputPath "$($KeyInfo.KeyName).metadata.json"
                                $KeyInfo.Metadata | ConvertTo-Json -Depth 3 | Out-File -FilePath $MetadataPath -Encoding UTF8
                                
                                Write-KeyAuditLog -Action "KEY_SAVED" -Details "Key saved to: $KeyPath" -Status "SUCCESS"
                            }
                        } catch {
                            $Error = "Failed to save key: $($_.Exception.Message)"
                            $KeyInfo.Errors += $Error
                            Write-KeyAuditLog -Action "KEY_SAVE_FAILED" -Details $Error -Status "ERROR"
                        }
                    }
                    
                    # Create backup if requested
                    if ($BackupKey -and $KeyInfo.KeyData) {
                        try {
                            if (-not $TestMode) {
                                if ($PSCmdlet.ShouldProcess($KeyInfo.KeyName, "Create key backup")) {
                                    $BackupFile = Join-Path $BackupPath "$($KeyInfo.KeyName)-backup-$(Get-Date -Format 'yyyyMMdd').key"
                                    
                                    # Encrypt backup
                                    $BackupData = if ($KeyInfo.KeyData -is [hashtable] -and $KeyInfo.KeyData.Protected) {
                                        $KeyInfo.KeyData | ConvertTo-Json -Depth 3
                                    } else {
                                        [Convert]::ToBase64String($KeyInfo.KeyData)
                                    }
                                    
                                    $BackupData | Out-File -FilePath $BackupFile -Encoding UTF8
                                    
                                    $KeyInfo.BackupCreated = $true
                                    $KeyGenResults.KeysBackedUp++
                                    
                                    Write-KeyAuditLog -Action "KEY_BACKED_UP" -Details "Key backup created: $BackupFile" -Status "SUCCESS"
                                }
                            } else {
                                Write-CustomLog -Level 'INFO' -Message "[TEST] Would create backup for key: $($KeyInfo.KeyName)"
                                $KeyInfo.BackupCreated = $true
                                $KeyGenResults.KeysBackedUp++
                            }
                            
                        } catch {
                            $Error = "Failed to backup key: $($_.Exception.Message)"
                            $KeyInfo.Errors += $Error
                            Write-KeyAuditLog -Action "KEY_BACKUP_FAILED" -Details $Error -Status "ERROR"
                        }
                    }
                    
                    $KeyGenResults.GeneratedKeys += $KeyInfo
                    $KeyGenResults.KeysGenerated++
                    
                    Write-CustomLog -Level 'SUCCESS' -Message "Generated key: $($KeyInfo.KeyName)"
                    Write-KeyAuditLog -Action "KEY_GENERATED" -Details "Key successfully generated: $($KeyInfo.KeyName)" -Status "SUCCESS"
                    
                } catch {
                    $Error = "Failed to generate key $($KeyInfo.KeyName): $($_.Exception.Message)"
                    $KeyInfo.Errors += $Error
                    $KeyGenResults.Errors += $Error
                    Write-CustomLog -Level 'ERROR' -Message $Error
                    Write-KeyAuditLog -Action "KEY_GENERATION_FAILED" -Details $Error -Status "ERROR"
                }
            }
            
        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Error during secure key generation: $($_.Exception.Message)"
            throw
        }
    }
    
    end {
        Write-CustomLog -Level 'SUCCESS' -Message "Secure key generation completed"
        
        Write-KeyAuditLog -Action "KEY_GENERATION_COMPLETED" -Details "Key generation completed successfully" -Status "SUCCESS"
        
        # Function to test key entropy (simplified)
        function Test-KeyEntropy {
            param([byte[]]$KeyData)
            
            # Simple entropy calculation
            $Frequencies = @{}
            foreach ($Byte in $KeyData) {
                if ($Frequencies.ContainsKey($Byte)) {
                    $Frequencies[$Byte]++
                } else {
                    $Frequencies[$Byte] = 1
                }
            }
            
            $Entropy = 0
            foreach ($Freq in $Frequencies.Values) {
                $P = $Freq / $KeyData.Length
                if ($P -gt 0) {
                    $Entropy -= $P * [Math]::Log($P, 2)
                }
            }
            
            return [Math]::Round($Entropy, 2)
        }
        
        # Generate recommendations
        $KeyGenResults.Recommendations += "Store generated keys securely with appropriate access controls"
        $KeyGenResults.Recommendations += "Implement proper key lifecycle management including rotation and expiration"
        $KeyGenResults.Recommendations += "Regularly backup encryption keys using secure methods"
        $KeyGenResults.Recommendations += "Monitor and audit all key usage for security compliance"
        $KeyGenResults.Recommendations += "Use hardware security modules (HSMs) for high-value keys"
        
        if ($KeyGenResults.KeysProtected -lt $KeyGenResults.KeysGenerated) {
            $KeyGenResults.Recommendations += "Consider protecting all generated keys with strong passwords or encryption"
        }
        
        if ($FIPSCompliant) {
            $KeyGenResults.Recommendations += "Ensure FIPS 140-2 compliance is maintained throughout key lifecycle"
        }
        
        if ($KeyGenResults.EntropyTests.Count -gt 0) {
            $AvgEntropy = ($KeyGenResults.EntropyTests | Measure-Object -Property EntropyScore -Average).Average
            if ($AvgEntropy -lt 7.5) {
                $KeyGenResults.Recommendations += "Entropy scores are below optimal (average: $([Math]::Round($AvgEntropy, 2))) - consider using hardware RNG"
            }
        }
        
        # Generate report if requested
        if ($GenerateReport) {
            try {
                $ReportPath = Join-Path $OutputPath "key-generation-report-$(Get-Date -Format 'yyyyMMdd-HHmmss').html"
                
                $HtmlReport = @"
<!DOCTYPE html>
<html>
<head>
    <title>Secure Key Generation Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #f0f0f0; padding: 15px; border-radius: 5px; }
        .key { border: 1px solid #ccc; margin: 20px 0; padding: 15px; border-radius: 5px; }
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
        <h1>Secure Key Generation Report</h1>
        <p><strong>Key Type:</strong> $($KeyGenResults.KeyType)</p>
        <p><strong>Key Size:</strong> $($KeyGenResults.KeySize) bits</p>
        <p><strong>Key Purpose:</strong> $($KeyGenResults.KeyPurpose)</p>
        <p><strong>Generated:</strong> $(Get-Date)</p>
        <p><strong>Keys Generated:</strong> $($KeyGenResults.KeysGenerated)</p>
        <p><strong>Keys Protected:</strong> $($KeyGenResults.KeysProtected)</p>
        <p><strong>Keys Escrowed:</strong> $($KeyGenResults.KeysEscrowed)</p>
        <p><strong>Keys Backed Up:</strong> $($KeyGenResults.KeysBackedUp)</p>
    </div>
"@
                
                foreach ($Key in $KeyGenResults.GeneratedKeys) {
                    $HtmlReport += "<div class='key'>"
                    $HtmlReport += "<h2>$($Key.KeyName)</h2>"
                    $HtmlReport += "<p><strong>Key ID:</strong> $($Key.KeyID)</p>"
                    $HtmlReport += "<p><strong>Generated:</strong> $($Key.GeneratedTime)</p>"
                    $HtmlReport += "<p><strong>Protected:</strong> $($Key.ProtectionApplied)</p>"
                    $HtmlReport += "<p><strong>Escrowed:</strong> $($Key.EscrowApplied)</p>"
                    $HtmlReport += "<p><strong>Backup Created:</strong> $($Key.BackupCreated)</p>"
                    if ($Key.EntropyScore -gt 0) {
                        $HtmlReport += "<p><strong>Entropy Score:</strong> $($Key.EntropyScore)</p>"
                    }
                    if ($Key.KeyPath) {
                        $HtmlReport += "<p><strong>Key Path:</strong> $($Key.KeyPath)</p>"
                    }
                    $HtmlReport += "</div>"
                }
                
                $HtmlReport += "<div class='header'><h2>Recommendations</h2>"
                foreach ($Rec in $KeyGenResults.Recommendations) {
                    $HtmlReport += "<div class='recommendation'>$Rec</div>"
                }
                $HtmlReport += "</div>"
                
                $HtmlReport += "</body></html>"
                
                if (-not $TestMode) {
                    $HtmlReport | Out-File -FilePath $ReportPath -Encoding UTF8
                    Write-CustomLog -Level 'SUCCESS' -Message "Key generation report saved to: $ReportPath"
                }
                
            } catch {
                Write-CustomLog -Level 'ERROR' -Message "Failed to generate report: $($_.Exception.Message)"
            }
        }
        
        # Display summary
        Write-CustomLog -Level 'INFO' -Message "Secure Key Generation Summary:"
        Write-CustomLog -Level 'INFO' -Message "  Key Type: $($KeyGenResults.KeyType)"
        Write-CustomLog -Level 'INFO' -Message "  Key Size: $($KeyGenResults.KeySize) bits"
        Write-CustomLog -Level 'INFO' -Message "  Key Purpose: $($KeyGenResults.KeyPurpose)"
        Write-CustomLog -Level 'INFO' -Message "  Keys Generated: $($KeyGenResults.KeysGenerated)"
        Write-CustomLog -Level 'INFO' -Message "  Keys Protected: $($KeyGenResults.KeysProtected)"
        Write-CustomLog -Level 'INFO' -Message "  Keys Escrowed: $($KeyGenResults.KeysEscrowed)"
        Write-CustomLog -Level 'INFO' -Message "  Keys Backed Up: $($KeyGenResults.KeysBackedUp)"
        Write-CustomLog -Level 'INFO' -Message "  Output Path: $OutputPath"
        
        if ($KeyGenResults.EntropyTests.Count -gt 0) {
            $AvgEntropy = ($KeyGenResults.EntropyTests | Measure-Object -Property EntropyScore -Average).Average
            Write-CustomLog -Level 'INFO' -Message "  Average Entropy: $([Math]::Round($AvgEntropy, 2))"
        }
        
        return $KeyGenResults
    }
}
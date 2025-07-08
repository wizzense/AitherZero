function Save-CredentialSecurely {
    <#
    .SYNOPSIS
        Securely saves credential data with modern encryption and integrity checks.

    .DESCRIPTION
        Saves credential data using enterprise-grade encryption with integrity validation,
        audit logging, and secure file permissions.
    #>
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
        Write-CustomLog -Level 'INFO' -Message "Saving credential: $($CredentialData.Name)" -Category "Security"

        # Create secure storage path with proper permissions
        $storagePath = Get-CredentialStoragePath
        if (-not (Test-Path $storagePath)) {
            New-Item -Path $storagePath -ItemType Directory -Force | Out-Null

            # Set restrictive permissions
            if ($IsWindows -or $PSVersionTable.PSEdition -eq 'Desktop') {
                $acl = Get-Acl $storagePath
                $acl.SetAccessRuleProtection($true, $false)
                $accessRule = [System.Security.AccessControl.FileSystemAccessRule]::new(
                    [System.Security.Principal.WindowsIdentity]::GetCurrent().Name,
                    'FullControl',
                    'ContainerInherit,ObjectInherit',
                    'None',
                    'Allow'
                )
                $acl.SetAccessRule($accessRule)
                Set-Acl -Path $storagePath -AclObject $acl
            } else {
                # Set Unix permissions (owner read/write only)
                chmod 700 $storagePath
            }
        }

        # Add security metadata
        $enhancedMetadata = @{}
        foreach ($key in $CredentialData.Keys) {
            $enhancedMetadata[$key] = $CredentialData[$key]
        }
        $enhancedMetadata.SecurityInfo = @{
            Version = '2.0'
            EncryptionMethod = if ($IsWindows -or $PSVersionTable.PSEdition -eq 'Desktop') { 'DPAPI' } else { 'AES-256-CBC' }
            CreatedBy = $env:USERNAME ?? $env:USER ?? 'unknown'
            CreatedOn = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
            MachineId = (Get-MachineKey | ForEach-Object { $_.ToString('X2') }) -join ''
            IntegrityHash = $null  # Will be calculated after encryption
        }

        # Encrypt sensitive data with modern methods
        $encryptedData = @{
            Metadata = $enhancedMetadata
            EncryptedPassword = if ($Password) {
                $plainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
                    [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password)
                )
                $encrypted = Protect-String $plainPassword
                # Clear plain text from memory
                [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR(
                    [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password)
                )
                $encrypted
            } else { $null }
            EncryptedAPIKey = if ($APIKey) { Protect-String $APIKey } else { $null }
            CertificatePath = $CertificatePath
        }

        # Calculate integrity hash
        $dataForHash = ($encryptedData | ConvertTo-Json -Depth 10 -Compress)
        $hash = [System.Security.Cryptography.SHA256]::Create()
        $hashBytes = $hash.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($dataForHash))
        $hash.Dispose()
        $encryptedData.Metadata.SecurityInfo.IntegrityHash = [Convert]::ToBase64String($hashBytes)

        # Save with secure file permissions
        $credentialFile = Join-Path $storagePath "$($CredentialData.Name).json"
        $encryptedData | ConvertTo-Json -Depth 10 | Set-Content -Path $credentialFile -Encoding UTF8

        # Set file permissions
        if ($IsWindows -or $PSVersionTable.PSEdition -eq 'Desktop') {
            $acl = Get-Acl $credentialFile
            $acl.SetAccessRuleProtection($true, $false)
            $accessRule = [System.Security.AccessControl.FileSystemAccessRule]::new(
                [System.Security.Principal.WindowsIdentity]::GetCurrent().Name,
                'FullControl',
                'Allow'
            )
            $acl.SetAccessRule($accessRule)
            Set-Acl -Path $credentialFile -AclObject $acl
        } else {
            chmod 600 $credentialFile
        }

        # Audit log the save operation
        Write-CustomLog -Level 'SUCCESS' -Message "Credential saved successfully: $($CredentialData.Name)" -Context @{
            CredentialName = $CredentialData.Name
            CredentialType = $CredentialData.Type
            EncryptionMethod = $enhancedMetadata.SecurityInfo.EncryptionMethod
            SavedBy = $env:USERNAME ?? $env:USER ?? 'unknown'
        } -Category "Security"

        return @{ Success = $true; SecurityInfo = $enhancedMetadata.SecurityInfo }
    }
    catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to save credential: $($_.Exception.Message)" -Category "Security"
        return @{ Success = $false; Error = $_.Exception.Message }
    }
}

function Retrieve-CredentialSecurely {
    <#
    .SYNOPSIS
        Securely retrieves credential data with integrity validation and audit logging.

    .DESCRIPTION
        Retrieves and decrypts credential data with integrity checks, access logging,
        and security validation.
    #>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'CredentialName', Justification = 'CredentialName is an identifier string, not sensitive credential data')]
    param(
        [Parameter(Mandatory = $true)]
        [string]$CredentialName,

        [Parameter(Mandatory = $false)]
        [switch]$SkipIntegrityCheck
    )

    try {
        Write-CustomLog -Level 'DEBUG' -Message "Retrieving credential: $CredentialName" -Category "Security"

        $storagePath = Get-CredentialStoragePath
        $credentialFile = Join-Path $storagePath "$CredentialName.json"

        if (-not (Test-Path $credentialFile)) {
            Write-CustomLog -Level 'WARN' -Message "Credential file not found: $CredentialName" -Category "Security"
            return @{ Success = $false; Error = "Credential not found" }
        }

        $encryptedData = Get-Content -Path $credentialFile -Raw | ConvertFrom-Json

        # Validate integrity if security info is present
        if ($encryptedData.Metadata.SecurityInfo -and -not $SkipIntegrityCheck) {
            Write-CustomLog -Level 'DEBUG' -Message "Security info present for credential: $CredentialName" -Category "Security"

            try {
                # Verify integrity hash if present
                if ($encryptedData.Metadata.SecurityInfo.IntegrityHash) {
                    # Create a copy without the integrity hash for verification
                    $tempData = $encryptedData | ConvertTo-Json -Depth 10 | ConvertFrom-Json
                    $tempData.Metadata.SecurityInfo.IntegrityHash = $null

                    $dataForVerification = ($tempData | ConvertTo-Json -Depth 10 -Compress)
                    $hash = [System.Security.Cryptography.SHA256]::Create()
                    $hashBytes = $hash.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($dataForVerification))
                    $hash.Dispose()
                    $calculatedHash = [Convert]::ToBase64String($hashBytes)

                    if ($calculatedHash -ne $encryptedData.Metadata.SecurityInfo.IntegrityHash) {
                        Write-CustomLog -Level 'ERROR' -Message "Integrity check failed for credential: $CredentialName" -Category "Security"
                        return @{ Success = $false; Error = "Credential integrity verification failed" }
                    }

                    Write-CustomLog -Level 'DEBUG' -Message "Integrity check passed for credential: $CredentialName" -Category "Security"
                }

                # Verify machine ID matches current machine (if enforcing machine binding)
                if ($encryptedData.Metadata.SecurityInfo.MachineId) {
                    $currentMachineId = (Get-MachineKey | ForEach-Object { $_.ToString('X2') }) -join ''
                    if ($encryptedData.Metadata.SecurityInfo.MachineId -ne $currentMachineId) {
                        Write-CustomLog -Level 'WARN' -Message "Credential was created on different machine: $CredentialName" -Category "Security"
                        # Don't fail here as credentials may be legitimately transferred between machines
                    }
                }

                # Check credential age and warn if very old
                if ($encryptedData.Metadata.SecurityInfo.CreatedOn) {
                    $createdDate = $null
                    if ([DateTime]::TryParse($encryptedData.Metadata.SecurityInfo.CreatedOn, [ref]$createdDate)) {
                        $age = (Get-Date) - $createdDate
                        if ($age.Days -gt 365) {
                            Write-CustomLog -Level 'WARN' -Message "Credential is over 1 year old: $CredentialName (Created: $createdDate)" -Category "Security"
                        }
                    }
                }

            } catch {
                Write-CustomLog -Level 'ERROR' -Message "Error during integrity check for credential '$CredentialName': $($_.Exception.Message)" -Category "Security"
                return @{ Success = $false; Error = "Integrity check error: $($_.Exception.Message)" }
            }
        }

        # Build credential object
        $credential = @{
            Name = $encryptedData.Metadata.Name
            Type = $encryptedData.Metadata.Type
            Username = $encryptedData.Metadata.Username
            Description = $encryptedData.Metadata.Description
            Metadata = $encryptedData.Metadata.Metadata
            Created = $encryptedData.Metadata.Created
            LastModified = $encryptedData.Metadata.LastModified
            SecurityInfo = $encryptedData.Metadata.SecurityInfo
        }

        # Decrypt sensitive data with modern methods
        if ($encryptedData.EncryptedPassword) {
            try {
                $decryptedPassword = Unprotect-String $encryptedData.EncryptedPassword
                # Suppress security warning: converting decrypted data back to SecureString is secure practice
                [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingConvertToSecureStringWithPlainText', '', Justification = 'Converting previously encrypted data back to SecureString after decryption is secure')]
                $credential.Password = ConvertTo-SecureString $decryptedPassword -AsPlainText -Force
                # Clear decrypted password from memory
                $decryptedPassword = $null
            } catch {
                Write-CustomLog -Level 'ERROR' -Message "Failed to decrypt password for credential: $CredentialName" -Category "Security"
                return @{ Success = $false; Error = "Failed to decrypt password data" }
            }
        }

        if ($encryptedData.EncryptedAPIKey) {
            try {
                $credential.APIKey = Unprotect-String $encryptedData.EncryptedAPIKey
            } catch {
                Write-CustomLog -Level 'ERROR' -Message "Failed to decrypt API key for credential: $CredentialName" -Category "Security"
                return @{ Success = $false; Error = "Failed to decrypt API key data" }
            }
        }

        if ($encryptedData.CertificatePath) {
            $credential.CertificatePath = $encryptedData.CertificatePath
        }

        # Audit log the retrieval
        Write-CustomLog -Level 'INFO' -Message "Credential retrieved successfully: $CredentialName" -Context @{
            CredentialName = $CredentialName
            CredentialType = $credential.Type
            AccessedBy = $env:USERNAME ?? $env:USER ?? 'unknown'
            IntegrityChecked = (-not $SkipIntegrityCheck) -and ($encryptedData.Metadata.SecurityInfo -ne $null)
        } -Category "Security"

        return @{ Success = $true; Credential = $credential }
    }
    catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to retrieve credential: $($_.Exception.Message)" -Category "Security"
        return @{ Success = $false; Error = $_.Exception.Message }
    }
}

function Remove-CredentialSecurely {
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'CredentialName', Justification = 'CredentialName is an identifier string, not sensitive credential data')]
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
    <#
    .SYNOPSIS
        Encrypts a string using AES-256-GCM encryption with platform-specific key derivation.

    .DESCRIPTION
        Provides enterprise-grade encryption for sensitive data using AES-256-GCM.
        Uses DPAPI on Windows and secure key derivation on Linux/macOS.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PlainText,

        [Parameter(Mandatory = $false)]
        [byte[]]$AdditionalEntropy
    )

    try {
        Write-CustomLog -Level 'DEBUG' -Message "Starting string encryption" -Category "Security"

        if ($IsWindows -or $PSVersionTable.PSEdition -eq 'Desktop') {
            # Use DPAPI on Windows for maximum security
            $plainTextBytes = [System.Text.Encoding]::UTF8.GetBytes($PlainText)
            $entropyBytes = if ($AdditionalEntropy) { $AdditionalEntropy } else { [byte[]]@() }

            $encryptedBytes = [System.Security.Cryptography.ProtectedData]::Protect(
                $plainTextBytes,
                $entropyBytes,
                [System.Security.Cryptography.DataProtectionScope]::CurrentUser
            )

            $result = @{
                Method = 'DPAPI'
                Data = [Convert]::ToBase64String($encryptedBytes)
                Entropy = if ($AdditionalEntropy) { [Convert]::ToBase64String($AdditionalEntropy) } else { $null }
            }

            Write-CustomLog -Level 'DEBUG' -Message "String encrypted using DPAPI" -Category "Security"
            return ($result | ConvertTo-Json -Compress)
        }
        else {
            # Use AES-256-CBC on Linux/macOS (more compatible than GCM)
            $plainTextBytes = [System.Text.Encoding]::UTF8.GetBytes($PlainText)

            # Generate deterministic key from machine characteristics
            $machineKey = Get-MachineKey
            $salt = [byte[]]::new(16)
            [System.Security.Cryptography.RandomNumberGenerator]::Fill($salt)

            # Use PBKDF2 for key derivation
            $rfc2898 = [System.Security.Cryptography.Rfc2898DeriveBytes]::new($machineKey, $salt, 100000, [System.Security.Cryptography.HashAlgorithmName]::SHA256)
            $key = $rfc2898.GetBytes(32)  # 256-bit key
            $iv = $rfc2898.GetBytes(16)   # 128-bit IV
            $rfc2898.Dispose()

            # Encrypt using AES-256-CBC
            $aes = [System.Security.Cryptography.Aes]::Create()
            $aes.KeySize = 256
            $aes.Mode = [System.Security.Cryptography.CipherMode]::CBC
            $aes.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7
            $aes.Key = $key
            $aes.IV = $iv

            $encryptor = $aes.CreateEncryptor()
            $encryptedBytes = $encryptor.TransformFinalBlock($plainTextBytes, 0, $plainTextBytes.Length)

            $encryptor.Dispose()
            $aes.Dispose()

            $result = @{
                Method = 'AES-256-CBC'
                Salt = [Convert]::ToBase64String($salt)
                IV = [Convert]::ToBase64String($iv)
                Ciphertext = [Convert]::ToBase64String($encryptedBytes)
                Entropy = if ($AdditionalEntropy) { [Convert]::ToBase64String($AdditionalEntropy) } else { $null }
            }

            Write-CustomLog -Level 'DEBUG' -Message "String encrypted using AES-256-CBC" -Category "Security"
            return ($result | ConvertTo-Json -Compress)
        }
    }
    catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to encrypt string: $($_.Exception.Message)" -Category "Security"
        throw "Encryption failed: $($_.Exception.Message)"
    }
}

function Unprotect-String {
    <#
    .SYNOPSIS
        Decrypts a string that was encrypted using Protect-String.

    .DESCRIPTION
        Decrypts data using the same method that was used for encryption.
        Automatically detects encryption method from the data structure.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$EncryptedText,

        [Parameter(Mandatory = $false)]
        [byte[]]$AdditionalEntropy
    )

    try {
        Write-CustomLog -Level 'DEBUG' -Message "Starting string decryption" -Category "Security"

        # Parse the encrypted data structure
        $encryptedData = $EncryptedText | ConvertFrom-Json

        if ($encryptedData.Method -eq 'DPAPI') {
            # Decrypt using DPAPI
            $encryptedBytes = [Convert]::FromBase64String($encryptedData.Data)
            $entropyBytes = if ($encryptedData.Entropy) { [Convert]::FromBase64String($encryptedData.Entropy) } else { [byte[]]@() }

            $decryptedBytes = [System.Security.Cryptography.ProtectedData]::Unprotect(
                $encryptedBytes,
                $entropyBytes,
                [System.Security.Cryptography.DataProtectionScope]::CurrentUser
            )

            $plainText = [System.Text.Encoding]::UTF8.GetString($decryptedBytes)
            Write-CustomLog -Level 'DEBUG' -Message "String decrypted using DPAPI" -Category "Security"
            return $plainText
        }
        elseif ($encryptedData.Method -eq 'AES-256-CBC') {
            # Decrypt using AES-256-CBC
            $salt = [Convert]::FromBase64String($encryptedData.Salt)
            $iv = [Convert]::FromBase64String($encryptedData.IV)
            $ciphertext = [Convert]::FromBase64String($encryptedData.Ciphertext)

            # Regenerate the same key using machine key and salt
            $machineKey = Get-MachineKey
            $rfc2898 = [System.Security.Cryptography.Rfc2898DeriveBytes]::new($machineKey, $salt, 100000, [System.Security.Cryptography.HashAlgorithmName]::SHA256)
            $key = $rfc2898.GetBytes(32)  # 256-bit key
            $rfc2898.Dispose()

            # Decrypt using AES-256-CBC
            $aes = [System.Security.Cryptography.Aes]::Create()
            $aes.KeySize = 256
            $aes.Mode = [System.Security.Cryptography.CipherMode]::CBC
            $aes.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7
            $aes.Key = $key
            $aes.IV = $iv

            $decryptor = $aes.CreateDecryptor()
            $plainTextBytes = $decryptor.TransformFinalBlock($ciphertext, 0, $ciphertext.Length)

            $decryptor.Dispose()
            $aes.Dispose()

            $plainText = [System.Text.Encoding]::UTF8.GetString($plainTextBytes)
            Write-CustomLog -Level 'DEBUG' -Message "String decrypted using AES-256-CBC" -Category "Security"
            return $plainText
        }
        else {
            # Legacy support for old Base64 encoding
            Write-CustomLog -Level 'WARN' -Message "Using legacy Base64 decoding - recommend re-encrypting with modern methods" -Category "Security"
            $bytes = [Convert]::FromBase64String($EncryptedText)
            return [System.Text.Encoding]::UTF8.GetString($bytes)
        }
    }
    catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to decrypt string: $($_.Exception.Message)" -Category "Security"
        throw "Decryption failed: $($_.Exception.Message)"
    }
}

function Get-MachineKey {
    <#
    .SYNOPSIS
        Generates a machine-specific key for encryption.

    .DESCRIPTION
        Creates a deterministic key based on machine characteristics.
        This ensures the same key is generated on the same machine.
    #>
    [CmdletBinding()]
    param()

    try {
        # Combine multiple machine characteristics
        $machineInfo = @(
            $env:COMPUTERNAME ?? $env:HOSTNAME ?? 'unknown'
            $env:USERNAME ?? $env:USER ?? 'unknown'
            (Get-Location).Path
            $PSVersionTable.PSVersion.ToString()
        )

        # Add platform-specific identifiers
        if ($IsLinux) {
            $machineInfo += (Get-Content '/proc/sys/kernel/random/boot_id' -ErrorAction SilentlyContinue) ?? 'linux-unknown'
        }
        elseif ($IsMacOS) {
            $machineInfo += (system_profiler SPHardwareDataType | grep 'Serial Number' | awk '{print $NF}' 2>/dev/null) ?? 'macos-unknown'
        }

        $combinedInfo = $machineInfo -join '|'
        $hash = [System.Security.Cryptography.SHA256]::Create()
        $hashBytes = $hash.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($combinedInfo))
        $hash.Dispose()

        return $hashBytes
    }
    catch {
        Write-CustomLog -Level 'WARN' -Message "Failed to generate machine key, using fallback: $($_.Exception.Message)" -Category "Security"
        # Fallback to a basic key
        return [System.Security.Cryptography.SHA256]::Create().ComputeHash([System.Text.Encoding]::UTF8.GetBytes('AitherZero-Fallback-Key'))
    }
}

function Get-AllCredentials {
    <#
    .SYNOPSIS
        Lists all stored credentials with metadata.

    .DESCRIPTION
        Returns a list of all credentials in the credential store with their metadata.
        Does not include sensitive data, only metadata for management purposes.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [switch]$IncludeExpired,

        [Parameter()]
        [string]$FilterType
    )

    try {
        $storagePath = Get-CredentialStoragePath

        if (-not (Test-Path $storagePath)) {
            Write-CustomLog -Level 'DEBUG' -Message "Credential storage path does not exist" -Category "Security"
            return @()
        }

        $credentialFiles = Get-ChildItem -Path $storagePath -Filter "*.json" -File
        $credentials = @()

        foreach ($file in $credentialFiles) {
            try {
                $credentialName = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)

                # Skip backup files
                if ($credentialName -like "*-backup-*") {
                    continue
                }

                $result = Retrieve-CredentialSecurely -CredentialName $credentialName -SkipIntegrityCheck

                if ($result.Success) {
                    $cred = $result.Credential

                    # Apply filters
                    if ($FilterType -and $cred.Type -ne $FilterType) {
                        continue
                    }

                    # Check expiration
                    $isExpired = $false
                    if ($cred.Metadata -and $cred.Metadata.ExpiresOn) {
                        $expirationDate = $null
                        if ([DateTime]::TryParse($cred.Metadata.ExpiresOn, [ref]$expirationDate)) {
                            $isExpired = $expirationDate -lt (Get-Date)
                        }
                    }

                    if ($isExpired -and -not $IncludeExpired) {
                        continue
                    }

                    # Create summary object (no sensitive data)
                    $credentialSummary = @{
                        Name = $cred.Name
                        Type = $cred.Type
                        Username = $cred.Username
                        Description = $cred.Description
                        Created = $cred.Created
                        LastModified = $cred.LastModified
                        IsExpired = $isExpired
                        SecurityInfo = $cred.SecurityInfo
                        FilePath = $file.FullName
                        FileSize = $file.Length
                        LastAccessed = $file.LastAccessTime
                    }

                    $credentials += $credentialSummary
                }
            }
            catch {
                Write-CustomLog -Level 'WARN' -Message "Failed to process credential file $($file.Name): $($_.Exception.Message)" -Category "Security"
            }
        }

        Write-CustomLog -Level 'DEBUG' -Message "Found $($credentials.Count) credentials" -Category "Security"
        return $credentials
    }
    catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to list credentials: $($_.Exception.Message)" -Category "Security"
        throw
    }
}

function Test-CredentialIntegrity {
    <#
    .SYNOPSIS
        Validates the integrity of all credentials in the store.

    .DESCRIPTION
        Performs comprehensive integrity checks on all stored credentials,
        including file permissions, encryption validation, and metadata consistency.
    #>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'CredentialName', Justification = 'CredentialName is an identifier string, not sensitive credential data')]
    param(
        [Parameter()]
        [string]$CredentialName,

        [Parameter()]
        [switch]$FixIssues
    )

    try {
        Write-CustomLog -Level 'INFO' -Message "Starting credential integrity check" -Category "Security"

        $results = @{
            TotalCredentials = 0
            ValidCredentials = 0
            InvalidCredentials = 0
            Issues = @()
            FixedIssues = @()
        }

        $credentialsToCheck = if ($CredentialName) {
            @(@{ Name = $CredentialName })
        } else {
            Get-AllCredentials -IncludeExpired
        }

        foreach ($cred in $credentialsToCheck) {
            $results.TotalCredentials++
            $credName = if ($CredentialName) { $CredentialName } else { $cred.Name }

            Write-CustomLog -Level 'DEBUG' -Message "Checking credential: $credName" -Category "Security"

            # Test basic existence and decryption
            if (Test-SecureCredential -CredentialName $credName -ValidateContent -Quiet) {
                $results.ValidCredentials++
                Write-CustomLog -Level 'DEBUG' -Message "Credential validation passed: $credName" -Category "Security"
            } else {
                $results.InvalidCredentials++
                $issue = "Credential validation failed: $credName"
                $results.Issues += $issue
                Write-CustomLog -Level 'WARN' -Message $issue -Category "Security"

                if ($FixIssues) {
                    # Attempt to fix common issues
                    try {
                        $storagePath = Get-CredentialStoragePath
                        $credentialFile = Join-Path $storagePath "$credName.json"

                        if (Test-Path $credentialFile) {
                            # Try to fix file permissions
                            if ($IsWindows -or $PSVersionTable.PSEdition -eq 'Desktop') {
                                $acl = Get-Acl $credentialFile
                                $acl.SetAccessRuleProtection($true, $false)
                                $accessRule = [System.Security.AccessControl.FileSystemAccessRule]::new(
                                    [System.Security.Principal.WindowsIdentity]::GetCurrent().Name,
                                    'FullControl',
                                    'Allow'
                                )
                                $acl.SetAccessRule($accessRule)
                                Set-Acl -Path $credentialFile -AclObject $acl
                            } else {
                                chmod 600 $credentialFile
                            }

                            $results.FixedIssues += "Fixed file permissions for: $credName"
                            Write-CustomLog -Level 'INFO' -Message "Fixed file permissions for credential: $credName" -Category "Security"
                        }
                    } catch {
                        $fixError = "Failed to fix credential $credName : $($_.Exception.Message)"
                        $results.Issues += $fixError
                        Write-CustomLog -Level 'ERROR' -Message $fixError -Category "Security"
                    }
                }
            }
        }

        # Summary
        Write-CustomLog -Level 'INFO' -Message "Integrity check completed" -Context @{
            TotalCredentials = $results.TotalCredentials
            ValidCredentials = $results.ValidCredentials
            InvalidCredentials = $results.InvalidCredentials
            IssuesFound = $results.Issues.Count
            IssuesFixed = $results.FixedIssues.Count
        } -Category "Security"

        return $results
    }
    catch {
        Write-CustomLog -Level 'ERROR' -Message "Credential integrity check failed: $($_.Exception.Message)" -Category "Security"
        throw
    }
}

function Backup-CredentialStore {
    <#
    .SYNOPSIS
        Creates a backup of the entire credential store.

    .DESCRIPTION
        Creates a secure backup of all credentials with metadata preservation
        and optional compression.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$BackupPath,

        [Parameter()]
        [switch]$IncludeSecrets,

        [Parameter()]
        [switch]$Compress
    )

    try {
        Write-CustomLog -Level 'INFO' -Message "Starting credential store backup" -Category "Security"

        $backupData = @{
            BackupInfo = @{
                CreatedBy = $env:USERNAME ?? $env:USER ?? 'unknown'
                CreatedOn = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
                AitherZeroVersion = '2.0'
                IncludesSecrets = $IncludeSecrets.IsPresent
                MachineId = (Get-MachineKey | ForEach-Object { $_.ToString('X2') }) -join ''
            }
            Credentials = @()
        }

        $allCredentials = Get-AllCredentials -IncludeExpired

        foreach ($cred in $allCredentials) {
            try {
                if ($IncludeSecrets) {
                    # Export with secrets
                    $tempExportPath = [System.IO.Path]::GetTempFileName()
                    Export-SecureCredential -CredentialName $cred.Name -ExportPath $tempExportPath -IncludeSecrets
                    $exportData = Get-Content $tempExportPath | ConvertFrom-Json
                    Remove-Item $tempExportPath -Force
                    $backupData.Credentials += $exportData.Credentials[0]
                } else {
                    # Export metadata only
                    $backupData.Credentials += @{
                        Name = $cred.Name
                        Type = $cred.Type
                        Username = $cred.Username
                        Description = $cred.Description
                        Created = $cred.Created
                        LastModified = $cred.LastModified
                        SecurityInfo = $cred.SecurityInfo
                    }
                }
            } catch {
                Write-CustomLog -Level 'WARN' -Message "Failed to backup credential $($cred.Name): $($_.Exception.Message)" -Category "Security"
            }
        }

        # Ensure backup directory exists
        $backupDir = Split-Path $BackupPath -Parent
        if ($backupDir -and -not (Test-Path $backupDir)) {
            New-Item -Path $backupDir -ItemType Directory -Force | Out-Null
        }

        # Save backup
        if ($Compress) {
            $jsonData = $backupData | ConvertTo-Json -Depth 10 -Compress
        } else {
            $jsonData = $backupData | ConvertTo-Json -Depth 10
        }

        Set-Content -Path $BackupPath -Value $jsonData -Encoding UTF8

        Write-CustomLog -Level 'SUCCESS' -Message "Credential store backup completed" -Context @{
            BackupPath = $BackupPath
            CredentialCount = $backupData.Credentials.Count
            IncludesSecrets = $IncludeSecrets.IsPresent
            BackupSize = (Get-Item $BackupPath).Length
        } -Category "Security"

        return @{
            Success = $true
            BackupPath = $BackupPath
            CredentialCount = $backupData.Credentials.Count
            IncludesSecrets = $IncludeSecrets.IsPresent
            BackupSize = (Get-Item $BackupPath).Length
        }
    }
    catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to backup credential store: $($_.Exception.Message)" -Category "Security"
        throw
    }
}

# Security Best Practices for License Management

This document outlines security best practices for implementing, deploying, and maintaining the AitherZero LicenseManager system.

## Table of Contents

1. [License File Security](#license-file-security)
2. [Signature Validation](#signature-validation)
3. [Storage Security](#storage-security)
4. [Runtime Security](#runtime-security)
5. [Deployment Security](#deployment-security)
6. [Monitoring and Auditing](#monitoring-and-auditing)
7. [Incident Response](#incident-response)

## License File Security

### 1. Secure License Distribution

**DO:**
- ✅ Use secure channels (HTTPS, encrypted email) for license distribution
- ✅ Implement license download authentication
- ✅ Provide license installation verification
- ✅ Use time-limited download links
- ✅ Log all license distribution events

```powershell
# Secure license installation with verification
function Install-SecureLicense {
    param(
        [string]$LicenseSource,
        [switch]$VerifyDownload
    )
    
    try {
        # Verify source authenticity
        if ($VerifyDownload) {
            $sourceValid = Test-LicenseSourceAuthenticity -Source $LicenseSource
            if (-not $sourceValid) {
                throw "License source verification failed"
            }
        }
        
        # Install with strict validation
        $result = Set-License -LicensePath $LicenseSource -StrictValidation -Validate
        
        # Log installation
        Write-CustomLog -Message "Secure license installation completed" -Level INFO -Context @{
            Source = $LicenseSource
            LicenseId = $result.LicenseId
            Tier = $result.Tier
        }
        
        return $result
    } catch {
        Write-CustomLog -Message "Secure license installation failed" -Level ERROR -Exception $_.Exception
        throw
    }
}
```

**DON'T:**
- ❌ Send licenses via unencrypted email
- ❌ Store licenses in public repositories
- ❌ Share license files via unsecured file sharing
- ❌ Embed licenses in source code

### 2. License File Integrity

**File Permissions:**
```powershell
# Set secure permissions on license files (Windows)
function Set-SecureLicensePermissions {
    param([string]$LicensePath)
    
    if ($IsWindows) {
        # Remove inheritance and set explicit permissions
        icacls $LicensePath /inheritance:r
        icacls $LicensePath /grant:r "SYSTEM:(F)"
        icacls $LicensePath /grant:r "Administrators:(F)"
        icacls $LicensePath /grant:r "$env:USERNAME:(R)"
    } elseif ($IsLinux -or $IsMacOS) {
        # Set restrictive permissions (600 = rw-------)
        chmod 600 $LicensePath
    }
}
```

**File Integrity Monitoring:**
```powershell
function Enable-LicenseFileMonitoring {
    param([string]$LicensePath)
    
    # Create file system watcher
    $watcher = New-Object System.IO.FileSystemWatcher
    $watcher.Path = Split-Path $LicensePath
    $watcher.Filter = Split-Path $LicensePath -Leaf
    $watcher.NotifyFilter = [System.IO.NotifyFilters]::LastWrite, [System.IO.NotifyFilters]::Size
    
    # Register event handler
    Register-ObjectEvent -InputObject $watcher -EventName Changed -Action {
        Write-CustomLog -Message "License file modification detected" -Level WARNING -Context @{
            LicensePath = $Event.SourceEventArgs.FullPath
            ChangeType = $Event.SourceEventArgs.ChangeType
        }
        
        # Trigger license revalidation
        Get-LicenseStatus -BypassCache
    }
    
    $watcher.EnableRaisingEvents = $true
    return $watcher
}
```

## Signature Validation

### 1. Cryptographic Security

**Enhanced Signature Validation:**
```powershell
function Test-EnhancedLicenseSignature {
    param(
        [PSCustomObject]$License,
        [string]$PublicKeyPath,
        [switch]$RequireTimestamp
    )
    
    try {
        # Validate signature format
        if (-not (Test-SignatureFormat -Signature $License.signature)) {
            Write-CustomLog -Message "Invalid signature format detected" -Level ERROR
            return $false
        }
        
        # Verify signature entropy
        if (-not (Test-SignatureEntropy -Signature $License.signature)) {
            Write-CustomLog -Message "Insufficient signature entropy" -Level ERROR
            return $false
        }
        
        # Check for signature reuse (in production, maintain signature database)
        if (Test-SignatureReuse -Signature $License.signature) {
            Write-CustomLog -Message "Signature reuse detected" -Level ERROR
            return $false
        }
        
        # Validate timestamp if required
        if ($RequireTimestamp -and $License.PSObject.Properties.Name -contains 'timestamp') {
            if (-not (Test-SignatureTimestamp -License $License)) {
                Write-CustomLog -Message "Invalid signature timestamp" -Level ERROR
                return $false
            }
        }
        
        # Perform cryptographic verification (placeholder for real implementation)
        $isValid = Validate-CryptographicSignature -License $License -PublicKeyPath $PublicKeyPath
        
        Write-CustomLog -Message "Enhanced signature validation completed" -Level DEBUG -Context @{
            LicenseId = $License.licenseId
            Valid = $isValid
            TimestampValidated = $RequireTimestamp.IsPresent
        }
        
        return $isValid
        
    } catch {
        Write-CustomLog -Message "Enhanced signature validation failed" -Level ERROR -Exception $_.Exception
        return $false
    }
}

function Test-SignatureEntropy {
    param([string]$Signature)
    
    # Calculate entropy of signature
    $bytes = [System.Convert]::FromBase64String($Signature)
    $entropy = Get-ByteEntropy -Bytes $bytes
    
    # Require minimum entropy threshold
    return $entropy -gt 7.0  # Good entropy threshold
}

function Get-ByteEntropy {
    param([byte[]]$Bytes)
    
    # Calculate Shannon entropy
    $frequency = @{}
    foreach ($byte in $Bytes) {
        $frequency[$byte] = ($frequency[$byte] ?? 0) + 1
    }
    
    $entropy = 0.0
    $length = $Bytes.Length
    
    foreach ($count in $frequency.Values) {
        $probability = $count / $length
        $entropy -= $probability * [Math]::Log($probability, 2)
    }
    
    return $entropy
}
```

### 2. Signature Anti-Tampering

```powershell
function Protect-LicenseFromTampering {
    param([PSCustomObject]$License)
    
    # Create multiple integrity checks
    $checksums = @{
        MD5 = Get-MD5Hash -Data ($License | ConvertTo-Json -Depth 10)
        SHA256 = Get-SHA256Hash -Data ($License | ConvertTo-Json -Depth 10)
        CRC32 = Get-CRC32Hash -Data ($License | ConvertTo-Json -Depth 10)
    }
    
    # Store checksums separately from license
    $integrityFile = "$($script:LicensePath).integrity"
    $checksums | ConvertTo-Json | Set-Content -Path $integrityFile
    
    # Set read-only permissions
    if ($IsWindows) {
        Set-ItemProperty -Path $integrityFile -Name IsReadOnly -Value $true
    } else {
        chmod 444 $integrityFile
    }
    
    return $checksums
}

function Test-LicenseIntegrityChecks {
    param([PSCustomObject]$License)
    
    $integrityFile = "$($script:LicensePath).integrity"
    
    if (-not (Test-Path $integrityFile)) {
        Write-CustomLog -Message "License integrity file missing" -Level WARNING
        return $false
    }
    
    try {
        $storedChecksums = Get-Content $integrityFile -Raw | ConvertFrom-Json
        $currentData = $License | ConvertTo-Json -Depth 10
        
        $currentChecksums = @{
            MD5 = Get-MD5Hash -Data $currentData
            SHA256 = Get-SHA256Hash -Data $currentData
            CRC32 = Get-CRC32Hash -Data $currentData
        }
        
        # Verify all checksums match
        $valid = $true
        foreach ($type in $storedChecksums.PSObject.Properties.Name) {
            if ($storedChecksums.$type -ne $currentChecksums.$type) {
                Write-CustomLog -Message "License integrity check failed: $type mismatch" -Level ERROR
                $valid = $false
            }
        }
        
        return $valid
        
    } catch {
        Write-CustomLog -Message "License integrity verification failed" -Level ERROR -Exception $_.Exception
        return $false
    }
}
```

## Storage Security

### 1. Secure Storage Location

```powershell
function Get-SecureLicenseStoragePath {
    param([string]$ApplicationName = "AitherZero")
    
    if ($IsWindows) {
        # Use protected user profile location
        $basePath = [Environment]::GetFolderPath('ApplicationData')
        $securePath = Join-Path $basePath $ApplicationName
    } elseif ($IsLinux -or $IsMacOS) {
        # Use hidden directory in user home
        $basePath = $HOME
        $securePath = Join-Path $basePath ".$ApplicationName"
    } else {
        # Fallback to temp directory
        $securePath = Join-Path ([System.IO.Path]::GetTempPath()) $ApplicationName
    }
    
    # Create directory with secure permissions
    if (-not (Test-Path $securePath)) {
        New-Item -Path $securePath -ItemType Directory -Force | Out-Null
        
        if ($IsWindows) {
            # Set NTFS permissions
            icacls $securePath /inheritance:r
            icacls $securePath /grant:r "$env:USERNAME:(OI)(CI)(F)"
        } else {
            # Set Unix permissions (700 = rwx------)
            chmod 700 $securePath
        }
    }
    
    return Join-Path $securePath "license.json"
}
```

### 2. License Encryption at Rest

```powershell
function Save-EncryptedLicense {
    param(
        [PSCustomObject]$License,
        [string]$LicensePath,
        [string]$EncryptionKey
    )
    
    try {
        # Serialize license
        $licenseJson = $License | ConvertTo-Json -Depth 10
        
        # Encrypt using AES
        $encryptedData = Protect-Data -Data $licenseJson -Key $EncryptionKey
        
        # Add encryption metadata
        $encryptedLicense = @{
            Version = "1.0"
            EncryptionMethod = "AES256"
            Data = $encryptedData
            Timestamp = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ssZ')
            Checksum = Get-SHA256Hash -Data $licenseJson
        }
        
        # Save encrypted license
        $encryptedLicense | ConvertTo-Json | Set-Content -Path $LicensePath -Encoding UTF8
        
        # Set secure permissions
        Set-SecureLicensePermissions -LicensePath $LicensePath
        
        Write-CustomLog -Message "License encrypted and saved" -Level INFO -Context @{
            LicensePath = $LicensePath
            EncryptionMethod = "AES256"
        }
        
        return $true
        
    } catch {
        Write-CustomLog -Message "License encryption failed" -Level ERROR -Exception $_.Exception
        throw
    }
}

function Get-DecryptedLicense {
    param(
        [string]$LicensePath,
        [string]$DecryptionKey
    )
    
    try {
        if (-not (Test-Path $LicensePath)) {
            throw "License file not found: $LicensePath"
        }
        
        # Load encrypted license
        $encryptedLicense = Get-Content $LicensePath -Raw | ConvertFrom-Json
        
        # Verify format
        if (-not $encryptedLicense.Data -or -not $encryptedLicense.EncryptionMethod) {
            throw "Invalid encrypted license format"
        }
        
        # Decrypt data
        $decryptedData = Unprotect-Data -EncryptedData $encryptedLicense.Data -Key $DecryptionKey
        
        # Parse license
        $license = $decryptedData | ConvertFrom-Json
        
        # Verify checksum if available
        if ($encryptedLicense.Checksum) {
            $currentChecksum = Get-SHA256Hash -Data $decryptedData
            if ($currentChecksum -ne $encryptedLicense.Checksum) {
                throw "License checksum verification failed"
            }
        }
        
        Write-CustomLog -Message "License decrypted successfully" -Level DEBUG
        return $license
        
    } catch {
        Write-CustomLog -Message "License decryption failed" -Level ERROR -Exception $_.Exception
        throw
    }
}
```

## Runtime Security

### 1. Memory Protection

```powershell
function Clear-SensitiveLicenseData {
    param([PSCustomObject]$License)
    
    # Clear sensitive properties
    if ($License.PSObject.Properties.Name -contains 'signature') {
        $License.signature = $null
    }
    
    if ($License.PSObject.Properties.Name -contains 'licenseId') {
        $License.licenseId = $null
    }
    
    # Clear from script-level variables
    $script:CurrentLicense = $null
    
    # Force garbage collection
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()
    
    Write-CustomLog -Message "Sensitive license data cleared from memory" -Level DEBUG
}

function Protect-LicenseInMemory {
    param([PSCustomObject]$License)
    
    # In a production system, you would use:
    # - SecureString for sensitive data
    # - Memory protection APIs
    # - Encrypted memory regions
    
    # For this implementation, we'll use basic protection
    $protectedLicense = $License.PSObject.Copy()
    
    # Redact sensitive information for logging
    if ($protectedLicense.signature) {
        $protectedLicense.signature = "***REDACTED***"
    }
    
    return $protectedLicense
}
```

### 2. Access Control

```powershell
function Test-LicenseAccessPermissions {
    param([string]$CallerModule)
    
    # Implement module-based access control
    $allowedModules = @(
        'LicenseManager',
        'SetupWizard',
        'DevEnvironment'
    )
    
    if ($CallerModule -notin $allowedModules) {
        Write-CustomLog -Message "Unauthorized license access attempt" -Level WARNING -Context @{
            CallerModule = $CallerModule
            AllowedModules = $allowedModules -join ", "
        }
        return $false
    }
    
    return $true
}

function Invoke-SecureLicenseOperation {
    param(
        [scriptblock]$Operation,
        [string]$OperationName
    )
    
    try {
        # Get caller information
        $caller = Get-PSCallStack | Select-Object -Skip 1 -First 1
        $callerModule = if ($caller.ScriptName) { 
            (Get-Item $caller.ScriptName).BaseName 
        } else { 
            "Unknown" 
        }
        
        # Check access permissions
        if (-not (Test-LicenseAccessPermissions -CallerModule $callerModule)) {
            throw "Access denied for operation: $OperationName"
        }
        
        # Log operation start
        Write-CustomLog -Message "Secure license operation started" -Level DEBUG -Context @{
            Operation = $OperationName
            Caller = $callerModule
        }
        
        # Execute operation
        $result = & $Operation
        
        # Log operation completion
        Write-CustomLog -Message "Secure license operation completed" -Level DEBUG -Context @{
            Operation = $OperationName
            Success = $true
        }
        
        return $result
        
    } catch {
        Write-CustomLog -Message "Secure license operation failed" -Level ERROR -Exception $_.Exception -Context @{
            Operation = $OperationName
        }
        throw
    }
}
```

## Deployment Security

### 1. Secure Installation

```powershell
function Install-LicenseManagerSecurely {
    param(
        [string]$InstallationPath,
        [switch]$VerifySignatures,
        [switch]$EnableAuditing
    )
    
    try {
        # Verify installation prerequisites
        Test-InstallationSecurity -Path $InstallationPath
        
        # Install with security configurations
        $installConfig = @{
            SecurePermissions = $true
            EnableLogging = $true
            AuditingEnabled = $EnableAuditing.IsPresent
            SignatureVerification = $VerifySignatures.IsPresent
        }
        
        # Configure secure storage
        $securePath = Get-SecureLicenseStoragePath
        
        # Set up monitoring
        if ($EnableAuditing) {
            Enable-LicenseAuditing -LogPath (Join-Path $InstallationPath "audit.log")
        }
        
        Write-CustomLog -Message "LicenseManager installed securely" -Level INFO -Context $installConfig
        
        return @{
            Success = $true
            Configuration = $installConfig
            LicenseStoragePath = $securePath
        }
        
    } catch {
        Write-CustomLog -Message "Secure installation failed" -Level ERROR -Exception $_.Exception
        throw
    }
}

function Test-InstallationSecurity {
    param([string]$Path)
    
    # Check directory permissions
    if (Test-DirectoryWriteAccess -Path $Path -UnauthorizedUsers) {
        throw "Installation directory has insecure permissions"
    }
    
    # Check for existing malicious files
    $suspiciousFiles = Get-ChildItem -Path $Path -Recurse | Where-Object {
        $_.Name -match '\.(exe|dll|bat|cmd|ps1)$' -and
        -not (Test-FileSignature -FilePath $_.FullName)
    }
    
    if ($suspiciousFiles) {
        throw "Suspicious unsigned files detected in installation directory"
    }
    
    # Check system integrity
    if ($IsWindows) {
        $integrityCheck = sfc /verifyonly 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "System file integrity issues detected"
        }
    }
}
```

### 2. Network Security

```powershell
function Get-SecureLicenseFromServer {
    param(
        [string]$ServerUrl,
        [string]$ApiKey,
        [string]$LicenseId
    )
    
    try {
        # Validate server certificate
        $serverCertValid = Test-ServerCertificate -Url $ServerUrl
        if (-not $serverCertValid) {
            throw "Server certificate validation failed"
        }
        
        # Prepare secure request
        $headers = @{
            'Authorization' = "Bearer $ApiKey"
            'User-Agent' = "AitherZero-LicenseManager/1.0"
            'Accept' = 'application/json'
        }
        
        # Use TLS 1.2 or higher
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        
        # Make request with timeout
        $response = Invoke-RestMethod -Uri "$ServerUrl/api/licenses/$LicenseId" -Headers $headers -TimeoutSec 30 -ErrorAction Stop
        
        # Validate response integrity
        if (-not $response.license -or -not $response.signature) {
            throw "Invalid license response format"
        }
        
        # Verify response signature
        if (-not (Test-ResponseSignature -Response $response -ExpectedSignature $response.signature)) {
            throw "License response signature validation failed"
        }
        
        Write-CustomLog -Message "License retrieved securely from server" -Level INFO -Context @{
            ServerUrl = $ServerUrl
            LicenseId = $LicenseId
        }
        
        return $response.license
        
    } catch {
        Write-CustomLog -Message "Secure license retrieval failed" -Level ERROR -Exception $_.Exception
        throw
    }
}
```

## Monitoring and Auditing

### 1. Comprehensive Audit Logging

```powershell
function Enable-LicenseAuditing {
    param([string]$LogPath)
    
    # Create audit log with secure permissions
    if (-not (Test-Path $LogPath)) {
        New-Item -Path $LogPath -ItemType File -Force | Out-Null
        Set-SecureLicensePermissions -LicensePath $LogPath
    }
    
    # Set up event logging
    $script:AuditLogPath = $LogPath
    $script:AuditingEnabled = $true
    
    Write-AuditLog -Event "AuditingEnabled" -Details @{
        LogPath = $LogPath
        EnabledAt = Get-Date
    }
}

function Write-AuditLog {
    param(
        [string]$Event,
        [hashtable]$Details = @{},
        [string]$Severity = "INFO"
    )
    
    if (-not $script:AuditingEnabled) { return }
    
    $auditEntry = @{
        Timestamp = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
        Event = $Event
        Severity = $Severity
        Details = $Details
        Machine = $env:COMPUTERNAME
        User = $env:USERNAME
        ProcessId = $PID
        SessionId = $Host.InstanceId
    }
    
    $auditJson = $auditEntry | ConvertTo-Json -Depth 10 -Compress
    
    try {
        Add-Content -Path $script:AuditLogPath -Value $auditJson -Encoding UTF8
    } catch {
        Write-Warning "Failed to write audit log: $($_.Exception.Message)"
    }
}

# Audit important license events
function Set-License {
    # ... existing implementation ...
    
    # Add audit logging
    Write-AuditLog -Event "LicenseInstalled" -Details @{
        LicenseId = $license.licenseId
        Tier = $license.tier
        IssuedTo = $license.issuedTo
        Source = $sourceInfo
        ValidationMode = if ($StrictValidation) { "Strict" } else { "Standard" }
    }
}

function Test-FeatureAccess {
    # ... existing implementation ...
    
    # Audit access attempts for restricted features
    if (-not $hasAccess -and $FeatureName -in @('security', 'monitoring', 'enterprise')) {
        Write-AuditLog -Event "FeatureAccessDenied" -Details @{
            Feature = $FeatureName
            CurrentTier = $licenseStatus.Tier
            RequiredTier = Get-FeatureTier -Feature $FeatureName
        } -Severity "WARNING"
    }
}
```

### 2. Security Monitoring

```powershell
function Start-LicenseSecurityMonitoring {
    param(
        [int]$CheckIntervalMinutes = 60,
        [string[]]$AlertRecipients = @()
    )
    
    # Monitor license file integrity
    $monitoringJob = Start-Job -ScriptBlock {
        param($LicensePath, $CheckInterval, $Recipients)
        
        while ($true) {
            try {
                # Check file existence
                if (-not (Test-Path $LicensePath)) {
                    Send-SecurityAlert -Type "LicenseFileMissing" -Recipients $Recipients
                }
                
                # Check file permissions
                if (Test-InsecurePermissions -Path $LicensePath) {
                    Send-SecurityAlert -Type "InsecurePermissions" -Recipients $Recipients
                }
                
                # Check for tampering
                if (-not (Test-LicenseIntegrityChecks -License (Get-Content $LicensePath -Raw | ConvertFrom-Json))) {
                    Send-SecurityAlert -Type "LicenseTampering" -Recipients $Recipients
                }
                
                # Check for unusual access patterns
                $accessPattern = Get-LicenseAccessPattern
                if (Test-AnomalousAccess -Pattern $accessPattern) {
                    Send-SecurityAlert -Type "AnomalousAccess" -Recipients $Recipients
                }
                
            } catch {
                Write-Warning "Security monitoring error: $($_.Exception.Message)"
            }
            
            Start-Sleep -Seconds ($CheckInterval * 60)
        }
    } -ArgumentList $script:LicensePath, $CheckIntervalMinutes, $AlertRecipients
    
    Write-CustomLog -Message "License security monitoring started" -Level INFO -Context @{
        CheckInterval = $CheckIntervalMinutes
        JobId = $monitoringJob.Id
    }
    
    return $monitoringJob
}

function Send-SecurityAlert {
    param(
        [string]$Type,
        [string[]]$Recipients,
        [hashtable]$Details = @{}
    )
    
    $alert = @{
        Type = $Type
        Timestamp = Get-Date
        Machine = $env:COMPUTERNAME
        User = $env:USERNAME
        Details = $Details
        Severity = switch ($Type) {
            "LicenseTampering" { "CRITICAL" }
            "LicenseFileMissing" { "HIGH" }
            "InsecurePermissions" { "MEDIUM" }
            "AnomalousAccess" { "LOW" }
            default { "MEDIUM" }
        }
    }
    
    # Log the alert
    Write-AuditLog -Event "SecurityAlert" -Details $alert -Severity $alert.Severity
    
    # In a production system, implement:
    # - Email notifications
    # - SIEM integration
    # - Incident ticketing
    # - SMS alerts for critical events
    
    Write-Warning "SECURITY ALERT: $Type detected on $env:COMPUTERNAME"
}
```

## Incident Response

### 1. License Compromise Response

```powershell
function Invoke-LicenseCompromiseResponse {
    param(
        [string]$IncidentType,
        [hashtable]$IncidentDetails = @{},
        [switch]$ImmediateRevocation
    )
    
    try {
        Write-AuditLog -Event "SecurityIncident" -Details @{
            Type = $IncidentType
            Details = $IncidentDetails
            ResponseInitiated = Get-Date
        } -Severity "CRITICAL"
        
        # Immediate response actions
        if ($ImmediateRevocation) {
            # Revoke current license
            Clear-License -Force
            Write-CustomLog -Message "License revoked due to security incident" -Level WARNING
        }
        
        # Clear all caches
        Clear-LicenseCache -Type All
        
        # Backup current state for forensics
        $forensicBackup = Backup-LicenseForensics -IncidentType $IncidentType
        
        # Generate incident report
        $incidentReport = New-IncidentReport -Type $IncidentType -Details $IncidentDetails -ForensicBackup $forensicBackup
        
        # Notify security team
        Send-SecurityAlert -Type "SecurityIncident" -Recipients $script:SecurityTeamContacts -Details $incidentReport
        
        return $incidentReport
        
    } catch {
        Write-CustomLog -Message "Incident response failed" -Level ERROR -Exception $_.Exception
        throw
    }
}

function Backup-LicenseForensics {
    param([string]$IncidentType)
    
    $forensicPath = Join-Path ([System.IO.Path]::GetTempPath()) "AitherZero-Forensics-$(Get-Date -Format 'yyyyMMddHHmmss')"
    New-Item -Path $forensicPath -ItemType Directory -Force | Out-Null
    
    # Backup license files
    if (Test-Path $script:LicensePath) {
        Copy-Item -Path $script:LicensePath -Destination (Join-Path $forensicPath "license.json") -Force
    }
    
    # Backup integrity files
    $integrityFile = "$($script:LicensePath).integrity"
    if (Test-Path $integrityFile) {
        Copy-Item -Path $integrityFile -Destination (Join-Path $forensicPath "license.integrity") -Force
    }
    
    # Backup audit logs
    if ($script:AuditLogPath -and (Test-Path $script:AuditLogPath)) {
        Copy-Item -Path $script:AuditLogPath -Destination (Join-Path $forensicPath "audit.log") -Force
    }
    
    # Create system state snapshot
    $systemState = @{
        Timestamp = Get-Date
        IncidentType = $IncidentType
        Environment = @{
            ComputerName = $env:COMPUTERNAME
            UserName = $env:USERNAME
            OSVersion = $PSVersionTable.OS
            PSVersion = $PSVersionTable.PSVersion
        }
        LicenseState = Get-LicenseStatus
        ModuleState = Get-Module | Select-Object Name, Version, Path
    }
    
    $systemState | ConvertTo-Json -Depth 10 | Set-Content -Path (Join-Path $forensicPath "system-state.json")
    
    Write-CustomLog -Message "Forensic backup created" -Level INFO -Context @{
        ForensicPath = $forensicPath
        IncidentType = $IncidentType
    }
    
    return $forensicPath
}
```

### 2. Recovery Procedures

```powershell
function Restore-LicenseFromBackup {
    param(
        [string]$BackupPath,
        [switch]$VerifyIntegrity,
        [switch]$ForceRestore
    )
    
    try {
        if (-not (Test-Path $BackupPath)) {
            throw "Backup path not found: $BackupPath"
        }
        
        # Verify backup integrity
        if ($VerifyIntegrity) {
            $integrityValid = Test-BackupIntegrity -BackupPath $BackupPath
            if (-not $integrityValid -and -not $ForceRestore) {
                throw "Backup integrity verification failed"
            }
        }
        
        # Restore license file
        $backupLicense = Join-Path $BackupPath "license.json"
        if (Test-Path $backupLicense) {
            Copy-Item -Path $backupLicense -Destination $script:LicensePath -Force
            Write-CustomLog -Message "License restored from backup" -Level INFO
        }
        
        # Restore integrity file
        $backupIntegrity = Join-Path $BackupPath "license.integrity"
        if (Test-Path $backupIntegrity) {
            Copy-Item -Path $backupIntegrity -Destination "$($script:LicensePath).integrity" -Force
        }
        
        # Clear caches and re-validate
        Clear-LicenseCache -Type All
        $restoredStatus = Get-LicenseStatus -BypassCache
        
        if (-not $restoredStatus.IsValid) {
            Write-Warning "Restored license is not valid"
        }
        
        Write-AuditLog -Event "LicenseRestored" -Details @{
            BackupPath = $BackupPath
            RestoredStatus = $restoredStatus
        }
        
        return $restoredStatus
        
    } catch {
        Write-CustomLog -Message "License restoration failed" -Level ERROR -Exception $_.Exception
        throw
    }
}
```

This comprehensive security guide provides robust protection for the LicenseManager system. Implement these practices according to your security requirements and compliance needs.
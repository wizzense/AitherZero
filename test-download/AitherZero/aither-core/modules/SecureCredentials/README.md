# SecureCredentials Module

## Test Status
- **Last Run**: 2025-07-08 18:50:21 UTC
- **Status**: ✅ PASSING (49/49 tests)
- **Coverage**: 0%
- **Platform**: ✅ Windows ✅ Linux ✅ macOS
- **Dependencies**: ✅ All resolved

## Test Results
| Test Suite | Status | Tests | Coverage | Duration |
|------------|--------|-------|----------|----------|
| Unit Tests | ✅ PASS | 49/49 | 0% | 3.5s |

---
*Test status updated automatically by AitherZero Testing Framework*
## Test Results
| Test Suite | Status | Tests | Coverage | Duration |
|------------|--------|-------|----------|----------|
| Unit Tests | ✅ PASS | 6/6 | 0% | 1.3s |

---
*Test status updated automatically by AitherZero Testing Framework*
## Test Results
| Test Suite | Status | Tests | Coverage | Duration |
|------------|--------|-------|----------|----------|
| Unit Tests | ❌ FAIL | 43/49 | 0% | 3.4s |

---
*Test status updated automatically by AitherZero Testing Framework*
## Test Results
| Test Suite | Status | Tests | Coverage | Duration |
|------------|--------|-------|----------|----------|
| Unit Tests | ✅ PASS | 11/11 | 0% | 1.4s |

---
*Test status updated automatically by AitherZero Testing Framework*
## Test Results
| Test Suite | Status | Tests | Coverage | Duration |
|------------|--------|-------|----------|----------|
| Unit Tests | ❌ FAIL | 43/49 | 0% | 3.6s |

---
*Test status updated automatically by AitherZero Testing Framework*
## Test Results
| Test Suite | Status | Tests | Coverage | Duration |
|------------|--------|-------|----------|----------|
| Unit Tests | ✅ PASS | 11/11 | 0% | 1.5s |

---
*Test status updated automatically by AitherZero Testing Framework*
## Test Results
| Test Suite | Status | Tests | Coverage | Duration |
|------------|--------|-------|----------|----------|
| Unit Tests | ✅ PASS | 10/10 | 0% | 1s |

---
*Test status updated automatically by AitherZero Testing Framework*
## Test Results
| Test Suite | Status | Tests | Coverage | Duration |
|------------|--------|-------|----------|----------|
| Unit Tests | ✅ PASS | 11/11 | 0% | 0.5s |

---
*Test status updated automatically by AitherZero Testing Framework*
## Test Results
| Test Suite | Status | Tests | Coverage | Duration |
|------------|--------|-------|----------|----------|
| Unit Tests | ✅ PASS | 11/11 | 0% | 1.5s |

---
*Test status updated automatically by AitherZero Testing Framework*
## Test Results
| Test Suite | Status | Tests | Coverage | Duration |
|------------|--------|-------|----------|----------|
| Unit Tests | ✅ PASS | 11/11 | 0% | 1.5s |

---
*Test status updated automatically by AitherZero Testing Framework*
## Test Results
| Test Suite | Status | Tests | Coverage | Duration |
|------------|--------|-------|----------|----------|
| Unit Tests | ✅ PASS | 11/11 | 0% | 1.5s |

---
*Test status updated automatically by AitherZero Testing Framework*
## Module Overview

The SecureCredentials module provides enterprise-grade credential management for the AitherZero infrastructure automation framework. It offers secure storage, retrieval, and management of various credential types with cross-platform compatibility and comprehensive security features.

### Primary Functionality
- Secure credential creation and storage
- Multiple credential type support (passwords, API keys, certificates, service accounts)
- Cross-platform encryption mechanisms
- Export/import capabilities for credential portability
- Integration with remote connection systems

### Use Cases and Scenarios
- Storing VM administrator credentials
- Managing cloud provider API keys
- Securing service account credentials
- Certificate-based authentication
- Automated credential rotation
- Team credential sharing (with proper encryption)

### Integration with AitherZero
- Used by RemoteConnection module for authentication
- Integrates with CloudProviderIntegration for API access
- Works with LabRunner for lab environment credentials
- Provides credentials for OpenTofuProvider deployments

## Directory Structure

```
SecureCredentials/
├── SecureCredentials.psd1    # Module manifest with enterprise metadata
├── SecureCredentials.psm1    # Main module loader
├── Public/                    # Exported functions
│   ├── New-SecureCredential.ps1
│   ├── Get-SecureCredential.ps1
│   ├── Remove-SecureCredential.ps1
│   ├── Test-SecureCredential.ps1
│   ├── Export-SecureCredential.ps1
│   └── Import-SecureCredential.ps1
└── Private/                   # Internal helper functions
    └── CredentialHelpers.ps1
```

## Core Functions

### New-SecureCredential
Creates a new secure credential with encryption and metadata.

**Parameters:**
- `CredentialName` (string, mandatory): Unique name for the credential
- `CredentialType` (string, mandatory): Type of credential (UserPassword, ServiceAccount, APIKey, Certificate)
- `Username` (string): Username for UserPassword/ServiceAccount types
- `Password` (SecureString): Password for UserPassword types
- `APIKey` (string): API key for APIKey type
- `CertificatePath` (string): Path to certificate for Certificate type
- `Description` (string): Description of credential purpose
- `Metadata` (hashtable): Additional metadata

**Returns:** Result object with success status

**Example:**
```powershell
# Create user/password credential
$securePassword = ConvertTo-SecureString "MyP@ssw0rd" -AsPlainText -Force
New-SecureCredential -CredentialName "VMAdmin" `
    -CredentialType "UserPassword" `
    -Username "administrator" `
    -Password $securePassword `
    -Description "Lab VM administrator account"

# Create API key credential
New-SecureCredential -CredentialName "AzureAPIKey" `
    -CredentialType "APIKey" `
    -APIKey "abcd1234-5678-90ef-ghij-klmnopqrstuv" `
    -Description "Azure subscription API key"

# Create certificate credential
New-SecureCredential -CredentialName "SSLCert" `
    -CredentialType "Certificate" `
    -CertificatePath "C:\Certs\mycert.pfx" `
    -Description "SSL certificate for web services"
```

### Get-SecureCredential
Retrieves a stored credential securely.

**Parameters:**
- `CredentialName` (string, mandatory): Name of credential to retrieve
- `AsPlainText` (switch): Return password as plain text (use carefully)

**Returns:** PSCredential object or credential data

**Example:**
```powershell
# Get credential as PSCredential object
$cred = Get-SecureCredential -CredentialName "VMAdmin"

# Get credential with plain text password (careful!)
$credData = Get-SecureCredential -CredentialName "VMAdmin" -AsPlainText

# Use in remote connection
$session = New-PSSession -ComputerName "Server01" -Credential $cred
```

### Remove-SecureCredential
Removes a stored credential from the secure store.

**Parameters:**
- `CredentialName` (string, mandatory): Name of credential to remove
- `Force` (switch): Skip confirmation prompt

**Returns:** Boolean indicating success

**Example:**
```powershell
# Remove credential with confirmation
Remove-SecureCredential -CredentialName "OldAPIKey"

# Remove credential without confirmation
Remove-SecureCredential -CredentialName "TempCred" -Force
```

### Test-SecureCredential
Validates that a credential exists and is accessible.

**Parameters:**
- `CredentialName` (string, mandatory): Name of credential to test
- `ValidateContent` (switch): Also validate credential can be decrypted

**Returns:** Boolean indicating validity

**Example:**
```powershell
# Basic existence check
if (Test-SecureCredential -CredentialName "VMAdmin") {
    Write-Host "Credential exists"
}

# Full validation including decryption
if (Test-SecureCredential -CredentialName "VMAdmin" -ValidateContent) {
    Write-Host "Credential is valid and accessible"
}
```

### Export-SecureCredential
Exports credentials for backup or transfer to another system.

**Parameters:**
- `CredentialName` (string): Specific credential to export
- `All` (switch): Export all credentials
- `Path` (string, mandatory): Export file path
- `EncryptionKey` (SecureString): Additional encryption key

**Returns:** Export result object

**Example:**
```powershell
# Export single credential
Export-SecureCredential -CredentialName "VMAdmin" `
    -Path "C:\Backup\vmadmin-cred.xml"

# Export all credentials with additional encryption
$key = ConvertTo-SecureString "MySecretKey123!" -AsPlainText -Force
Export-SecureCredential -All `
    -Path "C:\Backup\all-credentials.xml" `
    -EncryptionKey $key
```

### Import-SecureCredential
Imports previously exported credentials.

**Parameters:**
- `Path` (string, mandatory): Path to import file
- `EncryptionKey` (SecureString): Decryption key if used during export
- `Force` (switch): Overwrite existing credentials

**Returns:** Import result object with count of imported credentials

**Example:**
```powershell
# Import credentials
Import-SecureCredential -Path "C:\Backup\all-credentials.xml"

# Import with decryption key
$key = ConvertTo-SecureString "MySecretKey123!" -AsPlainText -Force
Import-SecureCredential -Path "C:\Backup\all-credentials.xml" `
    -EncryptionKey $key -Force
```

## Key Features

### Credential Types

1. **UserPassword**: Traditional username/password combinations
   - Used for: VM access, domain accounts, local users
   - Stored as: PSCredential objects

2. **ServiceAccount**: Service accounts without passwords
   - Used for: Managed service accounts, system accounts
   - Stored as: Username with metadata

3. **APIKey**: API keys and tokens
   - Used for: Cloud providers, REST APIs, webhooks
   - Stored as: Encrypted string values

4. **Certificate**: Certificate-based authentication
   - Used for: SSL/TLS, code signing, authentication
   - Stored as: Certificate path with optional private key

### Security Features

- **Platform-specific encryption**: Uses DPAPI on Windows, SecureString on Linux/macOS
- **Metadata tracking**: Creation date, last modified, usage tracking
- **Access control**: Integrates with OS-level permissions
- **Secure export**: Additional encryption layer for exports
- **Memory protection**: Sensitive data cleared from memory after use

## Usage Workflows

### Initial Credential Setup

```powershell
# Import the module
Import-Module SecureCredentials -Force

# Create lab environment credentials
$adminPass = Read-Host "Enter admin password" -AsSecureString
New-SecureCredential -CredentialName "LabAdmin" `
    -CredentialType "UserPassword" `
    -Username "administrator" `
    -Password $adminPass `
    -Description "Lab environment admin" `
    -Metadata @{
        Environment = "Lab"
        ExpiresOn = (Get-Date).AddMonths(3)
    }

# Create cloud provider API key
New-SecureCredential -CredentialName "AzureDevAPI" `
    -CredentialType "APIKey" `
    -APIKey $env:AZURE_API_KEY `
    -Description "Azure development subscription"
```

### Using Credentials in Automation

```powershell
# Get credential for VM deployment
$vmCred = Get-SecureCredential -CredentialName "LabAdmin"

# Use in OpenTofu deployment
$deployParams = @{
    Credential = $vmCred
    VMName = "TestVM01"
    Location = "Lab01"
}
Deploy-Infrastructure @deployParams

# Use API key for cloud operations
$apiKey = (Get-SecureCredential -CredentialName "AzureDevAPI" -AsPlainText).APIKey
$headers = @{
    'Authorization' = "Bearer $apiKey"
    'Content-Type' = 'application/json'
}
```

### Credential Rotation

```powershell
# Check credential age
$cred = Get-SecureCredential -CredentialName "LabAdmin"
if ($cred.Metadata.ExpiresOn -lt (Get-Date).AddDays(7)) {
    Write-Warning "Credential expires soon!"
    
    # Create new password
    $newPass = Read-Host "Enter new password" -AsSecureString
    
    # Remove old credential
    Remove-SecureCredential -CredentialName "LabAdmin" -Force
    
    # Create new credential
    New-SecureCredential -CredentialName "LabAdmin" `
        -CredentialType "UserPassword" `
        -Username "administrator" `
        -Password $newPass `
        -Description "Lab environment admin - rotated"
}
```

### Team Credential Sharing

```powershell
# Export credentials for team
$exportKey = ConvertTo-SecureString "TeamSecret2024!" -AsPlainText -Force
Export-SecureCredential -All `
    -Path "\\FileShare\TeamCreds\aitherzero-creds.xml" `
    -EncryptionKey $exportKey

# Team member imports
$importKey = Read-Host "Enter team encryption key" -AsSecureString
Import-SecureCredential `
    -Path "\\FileShare\TeamCreds\aitherzero-creds.xml" `
    -EncryptionKey $importKey
```

## Security

### Encryption Methods

**Windows Platform:**
- Uses Data Protection API (DPAPI)
- Encrypted with user or machine context
- Stored in user profile or machine store

**Linux/macOS Platform:**
- Uses .NET Core SecureString implementation
- AES-256 encryption with derived keys
- Stored in user's home directory with restricted permissions

### Storage Locations

- **Windows**: `$env:LOCALAPPDATA\AitherZero\Credentials`
- **Linux**: `~/.config/aitherzero/credentials`
- **macOS**: `~/Library/Application Support/AitherZero/Credentials`

### Security Best Practices

1. **Credential Rotation**: Regularly rotate passwords and API keys
2. **Access Control**: Limit credential access to necessary users
3. **Audit Trail**: Monitor credential usage through logs
4. **Secure Export**: Always use encryption keys for exports
5. **Minimal Privilege**: Create credentials with minimum required permissions
6. **Secure Deletion**: Use Remove-SecureCredential to properly clean up
7. **No Plain Text**: Avoid using -AsPlainText unless absolutely necessary

## Configuration

### Installation Profiles

The module behavior varies by installation profile:

- **Minimal**: Basic credential storage only
- **Developer**: Includes additional debugging and import/export features
- **Full**: All features including team sharing and advanced encryption

### Environment Variables

- `AITHERZERO_CREDENTIAL_STORE`: Override default credential store location
- `AITHERZERO_CREDENTIAL_TIMEOUT`: Auto-lock timeout in minutes
- `AITHERZERO_CREDENTIAL_ENCRYPTION`: Force specific encryption method

### Integration Configuration

```powershell
# Configure for RemoteConnection module
Set-ModuleConfiguration -Module "RemoteConnection" -Setting @{
    CredentialProvider = "SecureCredentials"
    AutoLoadCredentials = $true
}

# Configure for CloudProvider
Set-ModuleConfiguration -Module "CloudProviderIntegration" -Setting @{
    DefaultCredentialPrefix = "Cloud-"
    RequireCredentialValidation = $true
}
```

## Common Scenarios

### Multi-Environment Credentials

```powershell
# Create environment-specific credentials
@("Dev", "Test", "Prod") | ForEach-Object {
    $env = $_
    $pass = Read-Host "Enter password for $env" -AsSecureString
    New-SecureCredential -CredentialName "SQL-$env" `
        -CredentialType "UserPassword" `
        -Username "sqladmin" `
        -Password $pass `
        -Description "SQL Server $env environment" `
        -Metadata @{Environment = $env}
}

# Use environment-specific credential
$env = "Test"
$sqlCred = Get-SecureCredential -CredentialName "SQL-$env"
```

### Certificate Management

```powershell
# Store certificate credential
New-SecureCredential -CredentialName "CodeSigningCert" `
    -CredentialType "Certificate" `
    -CertificatePath "C:\Certs\codesign.pfx" `
    -Description "Code signing certificate" `
    -Metadata @{
        Thumbprint = "1234567890ABCDEF"
        ExpiresOn = "2025-12-31"
    }

# Retrieve for use
$certInfo = Get-SecureCredential -CredentialName "CodeSigningCert"
$cert = Get-PfxCertificate -FilePath $certInfo.CertificatePath
```

### Automated Credential Validation

```powershell
# Validate all credentials
Get-SecureCredential -All | ForEach-Object {
    $credName = $_.Name
    if (Test-SecureCredential -CredentialName $credName -ValidateContent) {
        Write-Host "✓ $credName is valid" -ForegroundColor Green
    } else {
        Write-Host "✗ $credName validation failed" -ForegroundColor Red
    }
}
```

## Troubleshooting

### Common Issues

1. **Access Denied**: Check file system permissions on credential store
2. **Decryption Failed**: Ensure using same user context or correct key
3. **Module Not Found**: Verify module is in PSModulePath
4. **Platform Issues**: Check platform-specific requirements

### Debug Mode

```powershell
# Enable verbose logging
$DebugPreference = "Continue"
$VerbosePreference = "Continue"

# Test credential operations
New-SecureCredential -CredentialName "DebugTest" `
    -CredentialType "UserPassword" `
    -Username "test" `
    -Password (ConvertTo-SecureString "test" -AsPlainText -Force) `
    -Verbose -Debug
```
# Security Domain

The Security domain handles all security-related operations including credential management, encryption, source code obfuscation, and security hardening.

## Modules

### Security.psm1
Core security operations including SSH command execution and secure string conversion.

**Functions:**
- `Invoke-SSHCommand` - Execute SSH commands with timeout handling
- `Test-SSHConnection` - Test SSH connectivity
- `ConvertFrom-SecureStringSecurely` - Secure string conversion with memory cleanup

### Encryption.psm1
Enterprise-grade encryption for source code obfuscation and data protection.

**Functions:**
- `Protect-String` - Encrypt strings with AES-256-CBC
- `Unprotect-String` - Decrypt encrypted strings
- `Protect-File` - Encrypt files with metadata
- `Unprotect-File` - Decrypt files using metadata
- `New-EncryptionKey` - Generate cryptographically secure keys
- `Get-DataHash` - HMAC-SHA256 integrity verification

**Features:**
- AES-256-CBC encryption with random IV
- PBKDF2 key derivation (100,000 iterations)
- HMAC-SHA256 signatures
- Secure memory cleanup
- Cross-platform support

### LicenseManager.psm1
License management for source code protection and key distribution.

**Functions:**
- `New-License` - Create license files with encryption keys
- `Test-License` - Validate licenses (expiration, signatures)
- `Get-LicenseFromGitHub` - Retrieve licenses from private repos
- `Get-LicenseKey` - Extract encryption key from valid license
- `Find-License` - Search standard locations for licenses

**Features:**
- License expiration management
- GitHub integration for remote storage
- Signature-based tamper detection
- Multiple search paths
- Automatic expiration warnings

## Automation Scripts

### 0800_Manage-License.ps1
CLI tool for license operations (Create, Validate, Retrieve, Info).

### 0801_Obfuscate-PreCommit.ps1
Pre-commit hook for automatic code obfuscation.

### 0802_Load-ObfuscatedModule.ps1
Runtime loader for encrypted modules with transparent decryption.

## Quick Start

### Create a License
```powershell
./automation-scripts/0800_Manage-License.ps1 `
    -Action Create `
    -LicenseId "PROD-001" `
    -LicensedTo "Acme Corp" `
    -GenerateKey
```

### Encrypt a File
```powershell
Import-Module ./domains/security/Encryption.psm1
$key = Get-LicenseKey -LicensePath "./license.json"
Protect-File -Path "./MyModule.psm1" -Key $key
```

### Load Encrypted Module
```powershell
./automation-scripts/0802_Load-ObfuscatedModule.ps1 `
    -EncryptedPath "./MyModule.psm1.encrypted"
```

## Documentation

For comprehensive documentation, see:
- [Licensing & Obfuscation System Guide](../../docs/LICENSING-OBFUSCATION-SYSTEM.md)

## Security Considerations

- Store encryption keys in secure password managers
- Use private repositories for license storage  
- Set appropriate license expiration dates
- Monitor expiration warnings
- Rotate keys periodically

## Testing

```powershell
# Run encryption tests (26 tests)
Invoke-Pester -Path ../../tests/domains/security/Encryption.Tests.ps1

# Run license manager tests (19 tests)
Invoke-Pester -Path ../../tests/domains/security/LicenseManager.Tests.ps1
```

## Status

✅ **Production Ready**

The security domain includes:
- SSH operations for remote management
- Enterprise encryption and obfuscation
- License management with GitHub integration
- Comprehensive test coverage (45 tests passing)
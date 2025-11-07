# Source Code Obfuscation and Licensing System

## ⚠️ CRITICAL SECURITY CONSIDERATIONS

**License Signature Security:**
The license signature system provides tamper detection but has important limitations:
- By default, if no separate signing key is provided, the system derives a signing key from the encryption key
- This provides basic tamper detection but **does NOT** prevent sophisticated attacks
- An attacker with access to the license file can potentially re-sign modified licenses

**For Production Use:**
1. **ALWAYS** use a separate signing key that is stored server-side or in a secure key vault
2. **NEVER** include the signing key in the repository or license file
3. Consider using a public/private key pair for stronger tamper resistance
4. Store signing keys in a Hardware Security Module (HSM) for maximum security

**Pre-Commit Hook Behavior:**
- The pre-commit hook encrypts matched files and **unstages the original plaintext**
- Encrypted files (`.encrypted`) are committed; plaintext originals are not
- Ensure you have backups before enabling automatic encryption

## Overview

The AitherZero source code obfuscation and licensing system provides enterprise-grade encryption and license management for protecting proprietary code. It integrates seamlessly with Git workflows and supports both local and remote license management.

## Features

### Encryption & Security
- **AES-256-CBC** encryption with random IV generation
- **PBKDF2** key derivation (100,000 iterations, SHA-256)
- **HMAC-SHA256** signatures for license integrity verification
- Secure memory cleanup for sensitive data
- Cross-platform support (Windows, Linux, macOS)

### License Management
- License creation with expiration dates
- Automatic expiration checking and warnings
- GitHub integration for remote license storage
- Multiple license location search paths
- Signature-based tamper detection

### Developer Experience
- Pre-commit hooks for automatic obfuscation
- Runtime transparent decryption
- Simple CLI tools for license operations
- Pattern-based file selection
- Environment variable configuration

## Quick Start

### 1. Create a License

```powershell
# Generate a new license for your organization
./automation-scripts/0800_Manage-License.ps1 `
    -Action Create `
    -LicenseId "PROD-001" `
    -LicensedTo "Acme Corporation" `
    -ExpirationDays 365

# Save the encryption key securely - you'll need it!
```

### 2. Configure Obfuscation Patterns

Edit `.obfuscate-patterns` to specify which files to encrypt:

```
# Protect proprietary modules
domains/proprietary/*.psm1
domains/proprietary/*.ps1

# Protect sensitive automation scripts
automation-scripts/9800_*.ps1
automation-scripts/9900_*.ps1
```

### 3. Enable Pre-Commit Obfuscation

```bash
# Configure Git to use the pre-commit hook
git config core.hooksPath .githooks

# Or run manually before commits
./automation-scripts/0801_Obfuscate-PreCommit.ps1
```

### 4. Load Obfuscated Code at Runtime

```powershell
# Transparent decryption and loading
./automation-scripts/0802_Load-ObfuscatedModule.ps1 `
    -EncryptedPath "./MyModule.psm1.encrypted"
```

## Architecture

### Core Modules

#### Encryption.psm1

Provides cryptographic functions using .NET Core APIs:

**Functions:**
- `Protect-String` - Encrypt a string with AES-256
- `Unprotect-String` - Decrypt an encrypted string
- `Protect-File` - Encrypt a file and create metadata
- `Unprotect-File` - Decrypt a file using metadata
- `New-EncryptionKey` - Generate cryptographically secure keys
- `Get-DataHash` - Compute HMAC-SHA256 for integrity verification

**Example:**
```powershell
# Import module
Import-Module ./domains/security/Encryption.psm1

# Encrypt sensitive data
$encrypted = Protect-String -PlainText "Secret data" -Key $licenseKey

# Decrypt when needed
$decrypted = Unprotect-String `
    -EncryptedData $encrypted.EncryptedData `
    -Key $licenseKey `
    -Salt $encrypted.Salt `
    -InitializationVector $encrypted.IV
```

#### LicenseManager.psm1

Manages license lifecycle and validation:

**Functions:**
- `New-License` - Create license files with keys and expiration
- `Test-License` - Validate license integrity and expiration
- `Get-LicenseFromGitHub` - Retrieve licenses from private repos
- `Get-LicenseKey` - Extract encryption key from valid license
- `Find-License` - Search standard locations for licenses

**Example:**
```powershell
# Import module
Import-Module ./domains/security/LicenseManager.psm1

# Create a license
$license = New-License `
    -LicenseId "DEV-001" `
    -LicensedTo "Development Team" `
    -ExpirationDate (Get-Date).AddYears(1) `
    -EncryptionKey "your-secure-key" `
    -OutputPath "./dev-license.json"

# Validate a license
$validation = Test-License -LicensePath "./dev-license.json"
if ($validation.IsValid) {
    $key = Get-LicenseKey -LicensePath "./dev-license.json"
    # Use key for decryption
}
```

### Automation Scripts

#### 0800_Manage-License.ps1

CLI tool for license operations:

```powershell
# Create a new license
./automation-scripts/0800_Manage-License.ps1 `
    -Action Create `
    -LicenseId "PROD-001" `
    -LicensedTo "Acme Corp" `
    -GenerateKey

# Validate an existing license
./automation-scripts/0800_Manage-License.ps1 `
    -Action Validate `
    -LicensePath "./license.json"

# Retrieve from GitHub (requires gh CLI)
./automation-scripts/0800_Manage-License.ps1 `
    -Action Retrieve `
    -LicenseId "PROD-001" `
    -GitHubOwner "aitherium" `
    -GitHubRepo "licenses"

# Show license information
./automation-scripts/0800_Manage-License.ps1 -Action Info
```

#### 0801_Obfuscate-PreCommit.ps1

Pre-commit hook for automatic encryption:

```powershell
# Run manually
./automation-scripts/0801_Obfuscate-PreCommit.ps1

# Dry run (show what would be encrypted)
./automation-scripts/0801_Obfuscate-PreCommit.ps1 -DryRun

# Force re-encryption
./automation-scripts/0801_Obfuscate-PreCommit.ps1 -Force
```

**How it works:**
1. Reads patterns from `.obfuscate-patterns`
2. Finds staged files matching patterns
3. Encrypts files using license key
4. Creates `.encrypted` and `.meta` files
5. Stages encrypted files for commit

#### 0802_Load-ObfuscatedModule.ps1

Runtime loader for encrypted modules:

```powershell
# Load an encrypted module
./automation-scripts/0802_Load-ObfuscatedModule.ps1 `
    -EncryptedPath "./MyModule.psm1.encrypted"

# Get decrypted path without importing
$path = ./automation-scripts/0802_Load-ObfuscatedModule.ps1 `
    -EncryptedPath "./MyModule.psm1.encrypted" `
    -PassThru

Import-Module $path
```

**Features:**
- Validates license before decryption
- Decrypts to temporary directory
- Cleans up on PowerShell exit
- Transparent to calling code

## Configuration

### License Search Paths

Licenses are searched in this order:

1. `$env:AITHERZERO_LICENSE_PATH` - Explicit path via environment variable
2. `./.license.json` - Current directory
3. `~/.aitherzero/license.json` - User home directory
4. `$env:AITHERZERO_ROOT/.license.json` - Repository root

### Environment Variables

```powershell
# Set license path
$env:AITHERZERO_LICENSE_PATH = "/path/to/license.json"

# For debugging
$env:AITHERZERO_DEBUG = "1"
```

### .obfuscate-patterns Format

```
# Comments start with #
# Each line is a Git-style pattern

# Single files
automation-scripts/9800_Proprietary-Script.ps1

# Wildcards
domains/proprietary/*.psm1

# Recursive
proprietary/**/*.ps1

# Character classes
automation-scripts/98[0-9][0-9]_*.ps1
```

## Workflows

### Initial Setup for AitherZero Organization

**Full Organization Setup (Recommended):**
```powershell
# Complete zero-to-deployment setup using orchestration
Start-AitherZero -Mode Orchestrate -Playbook aitherium-org-setup

# Or run the playbook directly
Invoke-OrchestrationSequence -PlaybookPath "./orchestration/playbooks/aitherium-org-setup.psd1"
```

This orchestrates:
- PowerShell 7 and development tools
- Certificate Authority (Windows)
- License infrastructure with master keys
- GitHub integration for license distribution
- Validation and summary

**Manual Step-by-Step Setup:**
```powershell
# 1. Bootstrap environment
./bootstrap.ps1 -Mode Update

# 2. Set up license infrastructure (integrates with CA and credential system)
./automation-scripts/0803_Setup-LicenseInfrastructure.ps1 `
    -OrganizationName "aitherium" `
    -GitHubOwner "aitherium" `
    -GitHubRepo "licenses" `
    -SetupCA `
    -GenerateMasterKeys

# 3. Configure GitHub credentials (uses AitherZero credential management)
Set-AitherCredentialGitHub -Token "ghp_your_token_here"

# 4. Create organization license with separate signing key
./automation-scripts/0800_Manage-License.ps1 `
    -Action Create `
    -LicenseId "ORG-001" `
    -LicensedTo "Your Organization" `
    -ExpirationDays 3650 `
    -GenerateKey `
    -GenerateSigningKey

# 5. Deploy license to GitHub (uses Set-AitherCredentialGitHub)
./automation-scripts/0804_Deploy-LicenseToGitHub.ps1 `
    -LicensePath "./ORG-001.json"

# 6. Configure obfuscation patterns
vim .obfuscate-patterns

# 7. Enable Git hooks
git config core.hooksPath .githooks
```

### Daily Development Workflow

```bash
# Normal development - obfuscation happens automatically
git add .
git commit -m "Add feature"  # Pre-commit hook encrypts configured files
git push
```

### CI/CD Integration

```yaml
# GitHub Actions example with credential integration
jobs:
  build:
    steps:
      - uses: actions/checkout@v3
      
      # Retrieve license using AitherZero credential system
      - name: Setup License
        run: |
          # GitHub token is automatically available in Actions
          Set-AitherCredentialGitHub -Token "${{ secrets.GITHUB_TOKEN }}"
          
          # Retrieve license from private repo
          ./automation-scripts/0800_Manage-License.ps1 `
            -Action Retrieve `
            -LicenseId "PROD-001" `
            -GitHubOwner "aitherium" `
            -GitHubRepo "licenses" `
            -OutputPath "~/.aitherzero/license.json"
      
      # Retrieve license from secrets
      - name: Setup License
        run: |
          mkdir -p ~/.aitherzero
          echo "${{ secrets.AITHERZERO_LICENSE }}" > ~/.aitherzero/license.json
      
      # Load encrypted modules
      - name: Load Obfuscated Code
        run: |
          ./automation-scripts/0802_Load-ObfuscatedModule.ps1 \
            -EncryptedPath "./MyModule.psm1.encrypted"
```

### Remote License Management with Integrated Credential System

```powershell
# 1. Configure GitHub credentials (one-time setup)
Set-AitherCredentialGitHub -Token "ghp_your_token_here"

# 2. Set up license infrastructure with GitHub integration
./automation-scripts/0803_Setup-LicenseInfrastructure.ps1 `
    -OrganizationName "aitherium" `
    -GitHubOwner "aitherium" `
    -GitHubRepo "licenses" `
    -GenerateMasterKeys

# 3. Create licenses
./automation-scripts/0800_Manage-License.ps1 `
    -Action Create `
    -LicenseId "PROD-001" `
    -LicensedTo "Production" `
    -GenerateKey `
    -GenerateSigningKey `
    -OutputPath "./licenses/PROD-001.json"

# 4. Deploy to GitHub (uses Set-AitherCredentialGitHub internally)
./automation-scripts/0804_Deploy-LicenseToGitHub.ps1 `
    -LicensePath "./licenses/PROD-001.json"

# 5. Retrieve on another machine (uses Get-AitherSecretGitHub internally)
Set-AitherCredentialGitHub -Token "ghp_your_token_here"

./automation-scripts/0800_Manage-License.ps1 `
    -Action Retrieve `
    -LicenseId "PROD-001" `
    -GitHubOwner "aitherium" `
    -GitHubRepo "licenses" `
    -OutputPath "./license.json"
```

**Benefits of Integrated Credential System:**
- No dependency on `gh` CLI installation
- Consistent credential management across all AitherZero components
- Automatic fallback to `gh` CLI if credential system unavailable
- Secure token storage using AitherZero's credential vault
- Cross-platform support (Windows/Linux/macOS)


## Security Considerations

### Best Practices

1. **Key Management**
   - Generate strong encryption keys (use `New-EncryptionKey`)
   - Store keys in secure password managers
   - Never commit keys to source control
   - Rotate keys periodically

2. **License Security**
   - Store licenses outside repository
   - Use private repos for remote storage
   - Set appropriate expiration dates
   - Monitor license expiration warnings

3. **Access Control**
   - Limit access to license repositories
   - Use GitHub team permissions
   - Audit license retrieval
   - Implement approval workflows for license creation

4. **Encryption**
   - Files are encrypted with AES-256
   - Keys derived with PBKDF2 (100k iterations)
   - Random IV per encryption operation
   - HMAC signatures prevent tampering

### Attack Mitigations

| Attack Vector | Mitigation |
|--------------|------------|
| Key exposure | Keys stored separately from code |
| License tampering | HMAC-SHA256 signatures |
| Replay attacks | Expiration dates enforced |
| Brute force | PBKDF2 with 100k iterations |
| Memory dumps | Secure memory cleanup |

## Troubleshooting

### License Not Found

```powershell
# Check license locations
./automation-scripts/0800_Manage-License.ps1 -Action Info

# Set explicit path
$env:AITHERZERO_LICENSE_PATH = "/path/to/license.json"
```

### Invalid License Signature

This usually indicates:
- License file was manually edited
- Different encryption key used
- File corruption

**Solution:** Regenerate the license or retrieve from backup.

### GitHub CLI Issues

```bash
# Check authentication
gh auth status

# Login if needed
gh auth login

# Test access to private repo
gh repo view aitherium/licenses
```

### Decryption Failures

```powershell
# Enable debug mode
$env:AITHERZERO_DEBUG = "1"

# Check license validity
./automation-scripts/0800_Manage-License.ps1 \
    -Action Validate \
    -LicensePath "./license.json"

# Verify encryption key matches
```

## API Reference

### Encryption Functions

#### Protect-String
```powershell
Protect-String -PlainText <string> -Key <string> [-Salt <byte[]>]
```

#### Unprotect-String
```powershell
Unprotect-String -EncryptedData <string> -Key <string> -Salt <string> -InitializationVector <string>
```

#### Protect-File
```powershell
Protect-File -Path <string> -Key <string> [-OutputPath <string>]
```

#### Unprotect-File
```powershell
Unprotect-File -Path <string> -Key <string> [-OutputPath <string>] [-MetadataPath <string>]
```

### License Functions

#### New-License
```powershell
New-License -LicenseId <string> -LicensedTo <string> -ExpirationDate <datetime> -EncryptionKey <string> -OutputPath <string> [-Features <string[]>]
```

#### Test-License
```powershell
Test-License -LicensePath <string> [-VerifySignature <bool>]
```

#### Get-LicenseKey
```powershell
Get-LicenseKey -LicensePath <string> [-VerifySignature <bool>]
```

## Examples

### Encrypt Proprietary Module

```powershell
# 1. Create encryption key
$key = New-EncryptionKey

# 2. Create license with key
New-License `
    -LicenseId "MODULE-001" `
    -LicensedTo "Internal Use" `
    -ExpirationDate (Get-Date).AddYears(5) `
    -EncryptionKey $key `
    -OutputPath "./module-license.json"

# 3. Encrypt the module
Protect-File `
    -Path "./ProprietaryModule.psm1" `
    -Key $key

# 4. Remove original (after backup!)
# rm ./ProprietaryModule.psm1
```

### Load Encrypted Module

```powershell
# With license in standard location
./automation-scripts/0802_Load-ObfuscatedModule.ps1 `
    -EncryptedPath "./ProprietaryModule.psm1.encrypted"

# Module is now loaded and usable
Import-Module ProprietaryModule
Get-Command -Module ProprietaryModule
```

### Batch Encrypt Files

```powershell
# Get license key
$key = Get-LicenseKey -LicensePath "./license.json"

# Encrypt all files in directory
Get-ChildItem ./proprietary/*.psm1 | ForEach-Object {
    Protect-File -Path $_.FullName -Key $key
    Write-Host "Encrypted: $($_.Name)"
}
```

## Testing

Run the comprehensive test suites:

```powershell
# Test encryption module (26 tests)
Invoke-Pester -Path ./tests/domains/security/Encryption.Tests.ps1

# Test license manager (19 tests)
Invoke-Pester -Path ./tests/domains/security/LicenseManager.Tests.ps1

# Both together
Invoke-Pester -Path ./tests/domains/security/
```

## License

MIT License - See LICENSE file for details.

## Support

For issues or questions:
- GitHub Issues: https://github.com/wizzense/AitherZero/issues
- Documentation: https://github.com/wizzense/AitherZero/docs

# SecureCredentials Module

Enterprise-grade credential management for AitherZero with cross-platform encryption support.

## 🔒 Security Notice

**IMPORTANT**: Please read the [SECURITY.md](./SECURITY.md) documentation before using this module. It contains critical information about encryption methods, security best practices, and important warnings.

## Overview

The SecureCredentials module provides secure storage and management of various credential types:
- Username/Password credentials
- Service Account credentials
- API Keys
- Certificate references

## Features

- **Cross-platform encryption**: DPAPI on Windows, AES-256 on Linux/macOS
- **Multiple credential types**: Support for various authentication methods
- **Secure export/import**: Transfer credentials between systems (with security warnings)
- **Metadata management**: Store additional information with credentials
- **Audit logging**: All operations are logged for security monitoring

## Quick Start

```powershell
# Import the module
Import-Module ./aither-core/modules/SecureCredentials -Force

# Create a new credential
$cred = Get-Credential
New-SecureCredential -CredentialName "MyApp-Prod" -CredentialType "UserPassword" -Credential $cred

# Retrieve a credential
$storedCred = Get-SecureCredential -CredentialName "MyApp-Prod"

# List all credentials
Get-SecureCredential

# Remove a credential
Remove-SecureCredential -CredentialName "MyApp-Prod"
```

## Credential Types

### UserPassword
Standard username/password credentials for general authentication.

### ServiceAccount
Specialized credentials for service accounts with additional metadata.

### APIKey
For storing API keys and tokens securely.

### Certificate
References to certificates with path and metadata storage.

## Export/Import

### ⚠️ Security Warning
Exporting with `-IncludeSecrets` creates files with plaintext passwords. Use with extreme caution!

```powershell
# Export without secrets (safe)
Export-SecureCredential -CredentialName "MyApp-Prod" -ExportPath "./backup/creds.json"

# Export with secrets (DANGEROUS - avoid if possible)
Export-SecureCredential -CredentialName "MyApp-Prod" -ExportPath "./backup/creds.json" -IncludeSecrets

# Import credentials
Import-SecureCredential -ImportPath "./backup/creds.json"
```

## Best Practices

1. **Never hardcode credentials** - Always use this module for credential storage
2. **Avoid plaintext exports** - Use `-IncludeSecrets` only when absolutely necessary
3. **Regular rotation** - Update credentials periodically
4. **Audit regularly** - Review stored credentials and access logs
5. **Delete unused credentials** - Remove credentials that are no longer needed

## Platform-Specific Locations

Credentials are stored in platform-specific secure directories:

- **Windows**: `%APPDATA%\AitherZero\credentials`
- **Linux**: `~/.config/aitherzero/credentials`
- **macOS**: `~/Library/Application Support/AitherZero/credentials`

## Troubleshooting

### Cannot decrypt credentials
- Credentials are bound to the user and machine that created them
- Cross-platform credential sharing is not supported
- Ensure you're using the same user account that created the credentials

### Permission denied errors
- Check file permissions on the credential storage directory
- Ensure the directory exists and is writable

## See Also

- [SECURITY.md](./SECURITY.md) - Detailed security documentation
- [SecureCredentials.psd1](./SecureCredentials.psd1) - Module manifest
- PowerShell SecretManagement module - Alternative for enterprise environments
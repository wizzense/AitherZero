# SecureCredentials Module - Security Documentation

## Overview

The SecureCredentials module provides secure storage and management of credentials in AitherZero. This document outlines the security mechanisms, best practices, and important considerations when using this module.

## Security Features

### 1. Encryption Methods

#### Windows Platform
- Uses **Windows Data Protection API (DPAPI)** for encryption
- Credentials are encrypted with user and machine-specific keys
- No hardcoded encryption keys
- Automatic key management by Windows

#### Linux/macOS Platforms
- Uses **AES-256 encryption** with CBC mode
- Keys derived from machine-specific identifiers:
  - Machine ID (Linux: `/etc/machine-id`)
  - Hardware UUID (macOS)
  - Username and hostname
- Keys are generated using SHA-256 hashing

### 2. Storage Security

- Credentials stored in platform-specific secure locations:
  - **Windows**: `%APPDATA%\AitherZero\credentials`
  - **Linux**: `~/.config/aitherzero/credentials`
  - **macOS**: `~/Library/Application Support/AitherZero/credentials`
- Each credential stored in separate JSON file
- Passwords stored as encrypted SecureString (Windows) or AES-encrypted (Linux/macOS)

### 3. Export/Import Security

#### Export Security
- Exports can include or exclude actual secrets
- **WARNING**: When using `-IncludeSecrets`, passwords are exported in plaintext
- Security warnings displayed when exporting secrets
- Interactive confirmation required for plaintext exports
- Each exported credential includes security warning in the file

#### Import Security
- Detects if import file contains plaintext secrets
- Displays security warnings during import
- Supports `-SkipSecrets` to import metadata only

## Security Best Practices

### 1. Credential Storage
- Never store credentials in code or configuration files
- Use SecureCredentials module for all credential management
- Regularly rotate credentials
- Delete unused credentials

### 2. Export/Import Operations
- **AVOID** using `-IncludeSecrets` unless absolutely necessary
- When exporting with secrets:
  - Use secure transmission methods (encrypted channels)
  - Delete export files immediately after use
  - Never commit export files to version control
- Consider using `-SkipSecrets` for imports when possible

### 3. Access Control
- Credentials are protected by OS-level user permissions
- Only the user who created credentials can decrypt them (Windows DPAPI)
- On Linux/macOS, ensure proper file permissions on credential directory

### 4. Audit and Monitoring
- All credential operations are logged
- Monitor logs for unauthorized access attempts
- Regular audit of stored credentials

## Security Warnings

### ⚠️ Critical Security Considerations

1. **Plaintext Exports**: The `-IncludeSecrets` flag exports passwords in plaintext. This should only be used in secure environments with immediate deletion of export files.

2. **Cross-Platform Limitations**: Credentials encrypted on one platform cannot be decrypted on another due to platform-specific encryption methods.

3. **Machine Binding**: On Linux/macOS, credentials are bound to specific machine identifiers. Moving credential files between machines will result in decryption failures.

4. **No Network Transmission**: This module does not provide network transmission of credentials. Any network transfer must be secured separately.

## Compliance Considerations

- Meets basic encryption requirements for credential storage
- Not suitable for high-security environments without additional hardening
- Consider using enterprise secret management solutions for production:
  - HashiCorp Vault
  - Azure Key Vault
  - AWS Secrets Manager
  - PowerShell SecretManagement module

## Known Limitations

1. **Key Derivation**: Linux/macOS key derivation from machine identifiers may not be sufficient for high-security requirements
2. **No Key Rotation**: Encryption keys are static and based on machine identity
3. **No Multi-Factor Authentication**: Access control relies solely on OS-level authentication

## Incident Response

If credentials are compromised:

1. Immediately rotate all affected credentials
2. Delete compromised credential files
3. Review audit logs for unauthorized access
4. Update credentials in all dependent systems
5. Consider implementing additional access controls

## Future Security Enhancements

Planned improvements:
- Integration with OS-native credential stores (Windows Credential Manager, macOS Keychain)
- Support for hardware security modules (HSM)
- Multi-factor authentication for sensitive operations
- Credential expiration and rotation policies
- Enhanced audit logging with tamper detection

## Security Contact

For security concerns or vulnerability reports related to this module, please:
1. Create a private security advisory on GitHub
2. Do not disclose vulnerabilities publicly until patched
3. Include detailed reproduction steps and impact assessment

---

**Remember**: Security is a shared responsibility. While this module provides encryption and secure storage, proper usage and operational security practices are essential for maintaining credential security.
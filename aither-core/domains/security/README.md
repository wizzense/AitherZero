# Security Domain

This domain handles security and credential management for AitherCore.

## Consolidated Modules

### SecureCredentials
**Original Module**: `aither-core/modules/SecureCredentials/`  
**Status**: Consolidated (Maintained as Separate Service)  
**Key Functions**:
- `Get-SecureCredential`
- `Set-SecureCredential`
- `New-SecureCredential`
- `Test-SecureCredentialCompliance`

### SecurityAutomation
**Original Module**: `aither-core/modules/SecurityAutomation/`  
**Status**: Consolidated (Security Provider)  
**Key Functions**:
- `Get-ADSecurityAssessment`
- `Enable-CredentialGuard`
- `Install-EnterpriseCA`
- `Enable-AdvancedAuditPolicy`

## Security Architecture

The security domain maintains strict security boundaries:

```
Security Domain
├── SecureCredentials (Core Service)
│   ├── Credential Storage
│   ├── Encryption Management
│   └── Access Control
└── SecurityAutomation (Security Provider)
    ├── Active Directory Security
    ├── Certificate Services
    ├── System Hardening
    └── Compliance Management
```

## Implementation Structure

```
security/
├── SecureCredentials.ps1       # Core credential management
├── SecurityAutomation.ps1      # Security automation provider
└── README.md                  # This file
```

## Security Principles

1. **Separation of Concerns**: Security functions isolated from other domains
2. **Least Privilege**: Functions operate with minimal required permissions
3. **Encryption**: All sensitive data encrypted at rest and in transit
4. **Audit Trail**: Comprehensive logging of all security operations
5. **Compliance**: Adherence to enterprise security standards

## Usage Examples

```powershell
# Secure credential management
$cred = Get-SecureCredential -Name "ServiceAccount"
Set-SecureCredential -Name "DatabaseConnection" -Credential $dbCred

# Security automation
$assessment = Get-ADSecurityAssessment -DomainName "company.com"
Enable-CredentialGuard -Force

# Certificate management
Install-EnterpriseCA -CAName "CompanyCA" -CAType "EnterpriseRootCA"
```

## Security Features

### SecureCredentials Service
- **Enterprise-grade encryption**: AES-256 encryption for credential storage
- **Access control**: Role-based access to credentials
- **Audit logging**: Comprehensive audit trail for all credential operations
- **Compliance validation**: Ensures credentials meet security policies

### SecurityAutomation Provider
- **Active Directory security**: AD security assessment and hardening
- **Certificate services**: PKI management and certificate automation
- **System hardening**: Automated security configuration
- **Compliance monitoring**: Continuous compliance validation

## Security Boundaries

The security domain maintains strict boundaries:

1. **Data Isolation**: Security data isolated from other domains
2. **Function Isolation**: Security functions cannot be called by other domains directly
3. **Audit Isolation**: Security audit logs separate from application logs
4. **Access Control**: Role-based access control for all security functions

## Testing

Security domain tests are located in:
- `tests/domains/security/`
- Security integration tests in `tests/integration/`
- Compliance tests in `tests/compliance/`

## Dependencies

- **Write-CustomLog**: Guaranteed available from AitherCore orchestration
- **Configuration Services**: Uses secure configuration management
- **Platform Services**: Cross-platform security operations
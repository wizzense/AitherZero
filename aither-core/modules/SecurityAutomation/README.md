# SecurityAutomation Module

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
Enterprise PowerShell security automation module for AitherZero providing comprehensive security management capabilities.

## Overview

The SecurityAutomation module integrates enterprise-grade security tools and automation into the AitherZero framework, covering:

- **Active Directory Security**: User/group management, password policies, security assessments
- **Certificate Services**: PKI automation, CA deployment, certificate management  
- **Endpoint Hardening**: Windows Firewall, audit policies, AppLocker, Credential Guard
- **Network Security**: IPsec, DNS security, protocol hardening
- **Remote Administration**: PowerShell Remoting, JEA, WinRM security

## Features

### Active Directory & Identity Management
- `Get-ADSecurityAssessment` - Comprehensive AD security analysis
- `Set-ADPasswordPolicy` - Domain and fine-grained password policy configuration
- `Enable-ADSmartCardLogon` - Smart card authentication setup
- `Get-ADDelegationRisks` - Identify dangerous delegation configurations

### Certificate Services & PKI
- `Install-EnterpriseCA` - Automated Enterprise CA deployment
- `New-CertificateTemplate` - Certificate template creation and management
- `Enable-CertificateAutoEnrollment` - Auto-enrollment configuration
- `Test-PKIHealth` - PKI infrastructure health assessment

### Endpoint Hardening
- `Set-WindowsFirewallProfile` - Advanced firewall configuration
- `Enable-AdvancedAuditPolicy` - Security auditing setup
- `Set-AppLockerPolicy` - Application whitelisting configuration
- `Enable-CredentialGuard` - Credential protection activation

### Network Security
- `Set-IPsecPolicy` - IPsec zero-trust networking
- `Enable-DNSSECValidation` - DNS security configuration
- `Disable-WeakProtocols` - Legacy protocol hardening
- `Set-SMBSecurity` - SMB security enhancement

### Remote Administration Security
- `Enable-PowerShellRemotingSSL` - Secure remoting configuration
- `New-JEAEndpoint` - Just Enough Administration setup
- `Set-WinRMSecurity` - WinRM security hardening
- `Test-RemoteSecurityPosture` - Remote access security assessment

## Installation

The module is automatically available when AitherZero is installed. To manually import:

```powershell
Import-Module "$AitherZeroRoot/aither-core/modules/SecurityAutomation" -Force
```

## Quick Start

### Basic Security Assessment
```powershell
# Perform comprehensive AD security assessment
$Assessment = Get-ADSecurityAssessment -ReportPath "C:\Reports\AD-Security.html"

# Configure enterprise firewall settings
Set-WindowsFirewallProfile -ConfigurationType Workstation -EnableLogging

# Set strong password policy for privileged users
Set-ADPasswordPolicy -PolicyType FineGrained -PolicyName "AdminPolicy" -MinPasswordLength 16 -MaxPasswordAge 90 -TargetGroups @("Domain Admins")
```

### Enterprise CA Deployment
```powershell
# Install and configure Enterprise Certificate Authority
Install-EnterpriseCA -CACommonName "Contoso-Root-CA" -KeyLength 4096 -ValidityPeriodYears 15

# Enable certificate auto-enrollment
Enable-CertificateAutoEnrollment -TemplateNames @("Computer", "User")
```

### Advanced Security Hardening
```powershell
# Enable advanced audit policies
Enable-AdvancedAuditPolicy -Categories @("AccountLogon", "AccountManagement", "PrivilegeUse")

# Configure IPsec for zero-trust networking
Set-IPsecPolicy -PolicyName "ZeroTrust" -RequireAuthentication -RequireEncryption
```

## Integration with AitherZero

The SecurityAutomation module integrates seamlessly with other AitherZero components:

- **Logging**: Uses `Write-CustomLog` for centralized logging
- **SecureCredentials**: Leverages existing credential management
- **SystemMonitoring**: Provides security metrics and alerts
- **RemoteConnection**: Enhances remote access security
- **PatchManager**: Enables security configuration as code

## Security Best Practices

### Password Policies
- Minimum 12 characters for standard users, 16+ for privileged accounts
- Maximum age of 365 days (90 days for high-privilege accounts)
- Password complexity and history enforcement
- Account lockout after 5 failed attempts

### Firewall Configuration
- Default deny for inbound traffic
- Essential services only (DHCP, DNS, domain communication)
- IPsec required for administrative access
- Comprehensive logging enabled

### Certificate Services
- 4096-bit RSA keys minimum
- Regular certificate health monitoring
- Automated enrollment for computers and users
- Secure key archival and recovery

### Active Directory Security
- Regular privileged group membership monitoring
- Delegation risk assessment
- Smart card authentication for administrators
- Advanced auditing for all security events

## Requirements

- PowerShell 7.0+
- Windows Server 2016+ or Windows 10+
- Active Directory domain membership (for AD functions)
- Administrator privileges for most security functions
- Active Directory PowerShell module

## Examples

See the `/Examples` directory for comprehensive usage examples and security deployment scenarios.

## Support

For issues, questions, or contributions:
- GitHub Issues: https://github.com/Aitherium/AitherZero/issues
- Documentation: https://github.com/Aitherium/AitherZero/docs/SecurityAutomation

## License

Part of the AitherZero project. See main project license for details.
# Security Domain Tests

This directory contains tests for the Security domain, which consolidates security automation and credential management functionality.

## Domain Overview

The Security domain consolidates the following legacy modules:
- **SecureCredentials** - Enterprise credential management
- **SecurityAutomation** - Security hardening and compliance automation

**Total Functions: 41**

## Function Reference

### Secure Credential Management (10 functions)
- `Initialize-SecureCredentialStore` - Initialize secure credential storage
- `New-SecureCredential` - Create new secure credentials
- `Get-SecureCredential` - Retrieve secure credentials
- `Get-AllSecureCredentials` - List all stored credentials
- `Update-SecureCredential` - Update existing credentials
- `Remove-SecureCredential` - Remove credentials from store
- `Backup-SecureCredentialStore` - Create credential store backups
- `Test-SecureCredentialCompliance` - Test credential compliance
- `Export-SecureCredential` - Export credentials securely
- `Import-SecureCredential` - Import credentials from external sources

### Active Directory Security (4 functions)
- `Get-ADSecurityAssessment` - Comprehensive AD security assessment
- `Set-ADPasswordPolicy` - Configure AD password policies
- `Get-ADDelegationRisks` - Identify delegation security risks
- `Enable-ADSmartCardLogon` - Enable smart card authentication

### Certificate Management (4 functions)
- `Install-EnterpriseCA` - Install enterprise certificate authority
- `New-CertificateTemplate` - Create certificate templates
- `Enable-CertificateAutoEnrollment` - Enable certificate auto-enrollment
- `Invoke-CertificateLifecycleManagement` - Manage certificate lifecycle

### Advanced Security Features (4 functions)
- `Enable-CredentialGuard` - Enable Windows Credential Guard
- `Enable-AdvancedAuditPolicy` - Enable advanced audit policies
- `Set-AppLockerPolicy` - Configure AppLocker policies
- `Enable-ExploitProtection` - Enable Windows Exploit Protection

### Network Security (7 functions)
- `Set-WindowsFirewallProfile` - Configure Windows Firewall profiles
- `Set-IPsecPolicy` - Configure IPsec policies
- `Set-SMBSecurity` - Configure SMB security settings
- `Disable-WeakProtocols` - Disable weak network protocols
- `Enable-DNSSECValidation` - Enable DNSSEC validation
- `Set-DNSSinkhole` - Configure DNS sinkhole protection
- `Set-WinRMSecurity` - Configure WinRM security

### PowerShell Security (3 functions)
- `Enable-PowerShellRemotingSSL` - Enable PowerShell remoting over SSL
- `New-JEASessionConfiguration` - Create JEA session configurations
- `New-JEAEndpoint` - Create JEA endpoints

### Privileged Access Management (3 functions)
- `Enable-JustInTimeAccess` - Enable just-in-time access
- `Get-PrivilegedAccountActivity` - Monitor privileged account activity
- `Set-PrivilegedAccountPolicy` - Set privileged account policies

### System Security (6 functions)
- `Get-SystemSecurityInventory` - Get comprehensive security inventory
- `Get-InsecureServices` - Identify insecure system services
- `Set-SystemHardening` - Apply system hardening configurations
- `Set-WindowsFeatureSecurity` - Configure Windows feature security
- `Search-SecurityEvents` - Search and analyze security events
- `Test-SecurityConfiguration` - Test security configuration compliance
- `Get-SecuritySummary` - Generate security summary reports

## Test Categories

### Unit Tests
- **Credential Management Tests** - Test secure credential operations
- **AD Security Tests** - Test Active Directory security functions
- **Certificate Tests** - Test certificate management
- **Security Feature Tests** - Test advanced security features
- **Network Security Tests** - Test network security configurations
- **PowerShell Security Tests** - Test PowerShell security features
- **PAM Tests** - Test privileged access management
- **System Security Tests** - Test system security operations

### Integration Tests
- **End-to-End Security Tests** - Test complete security workflows
- **Cross-Platform Security Tests** - Test security across platforms
- **Compliance Tests** - Test security compliance validation
- **Multi-Domain Tests** - Test security across multiple domains

### Security Tests
- **Penetration Tests** - Test security controls effectiveness
- **Vulnerability Tests** - Test for security vulnerabilities
- **Access Control Tests** - Test access control mechanisms
- **Audit Tests** - Test security audit logging

## Test Execution

### Run All Security Domain Tests
```powershell
# Run all security tests
./tests/Run-Tests.ps1 -Domain security

# Run specific test categories
./tests/Run-Tests.ps1 -Domain security -Category unit
./tests/Run-Tests.ps1 -Domain security -Category integration
./tests/Run-Tests.ps1 -Domain security -Category security
```

### Run Individual Test Files
```powershell
# Run main security tests
Invoke-Pester ./tests/domains/security/Security.Tests.ps1

# Run with coverage
Invoke-Pester ./tests/domains/security/Security.Tests.ps1 -CodeCoverage
```

## Expected Test Results

### Coverage Targets
- **Function Coverage**: 95% (39/41 functions)
- **Line Coverage**: 90%
- **Branch Coverage**: 85%

### Performance Targets
- **Credential Operations**: < 500ms
- **Security Assessment**: < 5 seconds
- **Configuration Changes**: < 2 seconds
- **Event Searches**: < 3 seconds

### Compatibility Targets
- **Windows**: 100% pass rate
- **Linux**: 80% pass rate (Windows-specific features excluded)
- **macOS**: 80% pass rate (Windows-specific features excluded)

## Legacy Module Compatibility

### Migration from SecureCredentials
The security domain maintains backward compatibility with SecureCredentials functions:
- All existing credential management functions are available
- Legacy credential storage formats are supported
- Migration tools for existing credential stores

### Migration from SecurityAutomation
Security automation functionality is integrated:
- All security hardening functions are available
- Configuration templates are preserved
- Audit and compliance features are maintained

## Common Test Scenarios

### 1. Credential Management Testing
```powershell
# Test credential lifecycle
Initialize-SecureCredentialStore
$cred = New-SecureCredential -Name "TestCred" -Username "user" -Password "pass"
$retrieved = Get-SecureCredential -Name "TestCred"
Remove-SecureCredential -Name "TestCred"
```

### 2. Security Assessment Testing
```powershell
# Test security assessment
$assessment = Get-ADSecurityAssessment -DomainName "test.local"
$inventory = Get-SystemSecurityInventory
$summary = Get-SecuritySummary
```

### 3. Security Configuration Testing
```powershell
# Test security configuration
Enable-CredentialGuard -Force
Set-AppLockerPolicy -PolicyLevel "Audit"
Enable-AdvancedAuditPolicy -AuditLevel "Enhanced"
Test-SecurityConfiguration
```

## Special Test Considerations

### Administrative Privileges
Many security tests require administrative privileges:
- Test execution may need elevated permissions
- Some tests may be skipped on non-Windows platforms
- Mock implementations for non-privileged testing

### Platform-Specific Features
- Windows-specific security features are tested only on Windows
- Cross-platform alternatives are tested where available
- Platform detection is used to skip unsupported tests

### Security Isolation
- Tests are isolated to prevent security policy conflicts
- Test environments are restored after test completion
- Sensitive test data is securely handled and cleaned up

## Troubleshooting

### Common Test Issues
1. **Permission Issues** - Ensure tests run with appropriate privileges
2. **Platform Issues** - Check platform-specific feature availability
3. **Security Policy Issues** - Verify security policies allow test operations
4. **Credential Issues** - Check credential store accessibility

### Debug Commands
```powershell
# Enable verbose logging
$VerbosePreference = "Continue"

# Check security status
Get-SystemSecurityInventory

# Test credential store
Test-SecureCredentialCompliance

# Check security events
Search-SecurityEvents -EventId 4624 -MaxEvents 10
```

## Contributing

### Adding New Tests
1. Follow the existing test structure
2. Consider platform-specific requirements
3. Handle administrative privilege requirements
4. Ensure security best practices
5. Test error conditions and edge cases

### Test Guidelines
- Test all function parameters and variations
- Include both positive and negative test cases
- Test error conditions and security edge cases
- Verify cross-platform compatibility where applicable
- Test performance and resource usage
- Test security controls effectiveness
- Handle sensitive data appropriately
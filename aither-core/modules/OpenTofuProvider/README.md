# OpenTofuProvider Module

## Overview

The OpenTofuProvider module provides comprehensive, secure infrastructure automation for lab environments using OpenTofu with the Taliesins Hyper-V provider. This module implements security best practices, automated certificate management, and compliance validation.

## Key Features

### 🔐 Security-First Approach
- **Multi-signature verification** for OpenTofu installations (Cosign + GPG)
- **Certificate-based authentication** with automated certificate generation
- **Comprehensive security auditing** with detailed compliance reporting
- **Secure credential management** with Windows Credential Manager integration

### 🏗️ OpenTofu + Taliesins Integration
- **Automated provider configuration** with secure defaults
- **HCL template generation** for infrastructure as code
- **State management** with security validation
- **Cross-platform compatibility** (Windows, Linux, macOS)

### 📋 Infrastructure Templates
- **Reusable lab templates** with parameterized configurations
- **Template export/import** functionality
- **Documentation generation** for templates
- **Version management** and metadata tracking

### ✅ Compliance & Validation
- **Infrastructure compliance testing** against security standards
- **Automated security validation** with scoring
- **Operational best practices** verification
- **Detailed reporting** with recommendations

## Quick Start

### 1. Install OpenTofu Securely
```powershell
Import-Module OpenTofuProvider
Install-OpenTofuSecure -Version "1.6.0"
```

### 2. Configure Secure Credentials
```powershell
$creds = Get-Credential
Set-SecureCredentials -Target "hyperv-lab-01" -Credentials $creds -CredentialType "Both" -CertificatePath "./certs/lab-01"
```

### 3. Initialize Provider
```powershell
Initialize-OpenTofuProvider -ConfigPath "lab_config.yaml" -ProviderVersion "1.2.1"
```

### 4. Deploy Infrastructure
```powershell
New-LabInfrastructure -ConfigPath "lab_config.yaml" -AutoApprove
```

### 5. Run Security Audit
```powershell
Test-OpenTofuSecurity -Detailed
Test-InfrastructureCompliance -ComplianceStandard "All" -Detailed
```

## Configuration Example

### Lab Configuration (lab_config.yaml)
```yaml
hyperv:
  host: "hyperv-01.lab.local"
  user: "lab\\administrator"
  password: "SecurePassword123!"
  port: 5986
  https: true
  insecure: false
  use_ntlm: true
  tls_server_name: "hyperv-01.lab.local"
  cacert_path: "./certs/ca.pem"
  cert_path: "./certs/client-cert.pem"
  key_path: "./certs/client-key.pem"
  vm_path: "C:\\VMs"

switch:
  name: "Lab-Internal-Switch"
  net_adapter_names:
    - "Ethernet"

vms:
  - name_prefix: "lab-vm"
    count: 3
    vhd_size_bytes: 21474836480  # 20GB
    iso_path: "C:\\ISOs\\ubuntu-20.04.iso"
    memory_startup_bytes: 2147483648  # 2GB
    processor_count: 2
```

## Function Reference

### Core Functions

#### Install-OpenTofuSecure
Securely installs OpenTofu with signature verification.
```powershell
Install-OpenTofuSecure [-Version <string>] [-InstallPath <string>] [-SkipVerification] [-Force]
```

#### Initialize-OpenTofuProvider
Initializes OpenTofu with Taliesins provider configuration.
```powershell
Initialize-OpenTofuProvider -ConfigPath <string> [-ProviderVersion <string>] [-CertificatePath <string>] [-Force]
```

#### Test-OpenTofuSecurity
Performs comprehensive security validation.
```powershell
Test-OpenTofuSecurity [-InstallPath <string>] [-ConfigPath <string>] [-Detailed]
```

#### New-LabInfrastructure
Creates lab infrastructure using OpenTofu.
```powershell
New-LabInfrastructure -ConfigPath <string> [-PlanOnly] [-AutoApprove] [-Force]
```

### Configuration Functions

#### Get-TaliesinsProviderConfig
Generates Taliesins provider configuration.
```powershell
Get-TaliesinsProviderConfig -HypervHost <string> [-Credentials <PSCredential>] [-CertificatePath <string>] [-OutputFormat <string>]
```

#### Set-SecureCredentials
Manages secure credentials for infrastructure operations.
```powershell
Set-SecureCredentials -Target <string> [-Credentials <PSCredential>] [-CertificatePath <string>] [-CredentialType <string>] [-Force]
```

### Compliance Functions

#### Test-InfrastructureCompliance
Tests infrastructure compliance against standards.
```powershell
Test-InfrastructureCompliance [-ConfigPath <string>] [-ComplianceStandard <string>] [-Detailed]
```

### Template Functions

#### Export-LabTemplate
Exports infrastructure configuration as reusable templates.
```powershell
Export-LabTemplate -SourcePath <string> -TemplateName <string> [-OutputPath <string>] [-IncludeDocumentation]
```

#### Import-LabConfiguration
Imports and validates lab configuration.
```powershell
Import-LabConfiguration -ConfigPath <string> [-ConfigFormat <string>] [-ValidateConfiguration] [-MergeWith <string>]
```

## Security Features

### Signature Verification
- **Cosign verification** with OIDC issuer validation
- **GPG signature verification** with pinned key IDs
- **Binary integrity checking** for downloaded files
- **Certificate chain validation** for all communications

### Credential Security
- **Windows Credential Manager** integration for secure storage
- **Certificate-based authentication** with automated rotation
- **Environment variable protection** from exposure
- **Secure string handling** throughout the module

### Compliance Validation
The module includes comprehensive compliance testing:

- **Security Compliance**: Encryption, access control, network security, certificates
- **Operational Compliance**: Resource tagging, backup configurations, naming conventions
- **Provider Security**: HTTPS enforcement, authentication methods, timeouts
- **State Security**: File encryption, remote state, permissions, locking

### Security Scoring
Each security check is scored and weighted:
- **Excellent** (90-100%): Production-ready security
- **Good** (75-89%): Minor improvements needed
- **Fair** (60-74%): Significant security gaps
- **Poor** (<60%): Major security issues

## Best Practices

### 1. Certificate Management
Always use certificate-based authentication for production environments:
```powershell
# Generate certificates using existing scripts
& "./aither-core/scripts/0010_Prepare-HyperVProvider.ps1"

# Configure with certificates
Set-SecureCredentials -Target "production-hyperv" -CertificatePath "./certs/prod" -CredentialType "Both"
```

### 2. Configuration Validation
Always validate configurations before deployment:
```powershell
$config = Import-LabConfiguration -ConfigPath "lab_config.yaml" -ValidateConfiguration
if (-not $config.ValidationResult.Valid) {
    Write-Error "Configuration validation failed: $($config.ValidationResult.Issues -join '; ')"
}
```

### 3. Security Auditing
Regularly audit your infrastructure security:
```powershell
# Run comprehensive security audit
$securityReport = Test-OpenTofuSecurity -Detailed
$complianceReport = Test-InfrastructureCompliance -ComplianceStandard "All" -Detailed

# Check for critical issues
if ($securityReport.CriticalIssues) {
    Write-Warning "Critical security issues found: $($securityReport.CriticalIssues.Count)"
}
```

### 4. Template Management
Use templates for consistent infrastructure:
```powershell
# Export working configuration as template
Export-LabTemplate -SourcePath "./infrastructure" -TemplateName "StandardLab" -IncludeDocumentation

# Use template for new environments
Copy-Item "./templates/StandardLab/*" "./new-environment/" -Recurse
```

## Troubleshooting

### Common Issues

#### OpenTofu Installation Fails
```powershell
# Check signature verification tools
Get-Command cosign, gpg -ErrorAction SilentlyContinue

# Install with manual verification
Install-OpenTofuSecure -SkipVerification -Force
```

#### Provider Initialization Errors
```powershell
# Check provider installation
Test-TaliesinsProviderInstallation -ProviderVersion "1.2.1"

# Reinitialize with force
Initialize-OpenTofuProvider -ConfigPath "lab_config.yaml" -Force
```

#### Certificate Issues
```powershell
# Validate certificate paths
Test-Path "./certs/ca.pem", "./certs/client-cert.pem", "./certs/client-key.pem"

# Regenerate certificates if needed
& "./aither-core/scripts/0010_Prepare-HyperVProvider.ps1"
```

### Logging

All operations are logged using the Logging module:
- **INFO**: General operations and progress
- **WARN**: Non-fatal issues and warnings
- **ERROR**: Failed operations and errors
- **SUCCESS**: Successful completions

Check logs in: `logs/opentofu-provider-{date}.log`

## Integration

### VS Code Tasks
The module integrates with existing VS Code tasks:
- **OpenTofu Plan**: Generate infrastructure plans
- **OpenTofu Apply**: Deploy infrastructure
- **Security Audit**: Run comprehensive security validation
- **Compliance Check**: Validate compliance standards

### PatchManager Integration
Use with PatchManager for change management:
```powershell
Invoke-PatchWorkflow -PatchDescription "Update lab infrastructure" -PatchOperation {
    Initialize-OpenTofuProvider -ConfigPath "lab_config.yaml"
    New-LabInfrastructure -ConfigPath "lab_config.yaml" -AutoApprove
} -CreatePR
```

## Contributing

When contributing to this module:
1. Follow PowerShell best practices and coding standards
2. Include comprehensive error handling and logging
3. Add parameter validation and help documentation
4. Include security considerations in all functions
5. Test cross-platform compatibility
6. Update documentation and examples

## License

Copyright (c) 2025 Aitherium. All rights reserved.

This module is part of the Aitherium Infrastructure Automation framework.

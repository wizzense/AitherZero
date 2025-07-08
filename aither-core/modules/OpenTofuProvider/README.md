# OpenTofuProvider Module v1.2.0

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
## Overview

The OpenTofuProvider module is the **comprehensive infrastructure-as-code foundation** for the AitherZero platform. It provides enterprise-grade automation for OpenTofu/Terraform deployments with advanced features including deployment snapshots, rollback capabilities, security hardening, and multi-provider support.

### 🚀 What's New in v1.2.0

- **Enhanced Module Loading**: Now exports 42+ functions with improved dependency management
- **Advanced Deployment Features**: Snapshots, rollback, automation workflows, and drift detection  
- **Comprehensive Security**: Multi-signature verification, certificate management, and compliance validation
- **Performance Optimization**: Memory management, caching, and concurrent deployment support
- **Better Error Handling**: Robust error handling with retry mechanisms and checkpoint recovery
- **YAML Support**: Built-in YAML parsing for configuration management
- **Progress Tracking**: Visual feedback for long-running deployments
- **Cross-Platform**: Full support for Windows, Linux, and macOS platforms

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

## Quick Start Guide

### Prerequisites
- PowerShell 7.0+
- OpenTofu 1.6.0+ (or use our secure installer)
- Hyper-V host (for lab deployments)

### Basic Deployment Workflow

#### 1. Import Module and Install OpenTofu
```powershell
# Import the OpenTofuProvider module
Import-Module ./aither-core/modules/OpenTofuProvider -Force

# Securely install OpenTofu with signature verification
Install-OpenTofuSecure -Version "1.8.0"

# Verify installation
Test-OpenTofuInstallation
```

#### 2. Configure Infrastructure
```powershell
# Set up secure credentials
$creds = Get-Credential
Set-SecureCredentials -Target "hyperv-lab-01" -Credentials $creds -CredentialType "Both"

# Initialize provider with configuration
Initialize-OpenTofuProvider -ConfigPath "lab_config.yaml" -ProviderVersion "1.2.1"
```

#### 3. Deploy with Advanced Features
```powershell
# Create deployment snapshot before changes
New-DeploymentSnapshot -DeploymentId "prod-deployment" -Name "pre-update" -Description "Backup before v1.2 update"

# Start infrastructure deployment with progress tracking
Start-InfrastructureDeployment -ConfigurationPath "infrastructure.yaml" -DryRun

# Apply changes after review
Start-InfrastructureDeployment -ConfigurationPath "infrastructure.yaml"
```

#### 4. Monitor and Manage
```powershell
# Check deployment status
Get-DeploymentStatus -DeploymentId "prod-deployment"

# View deployment history
Get-DeploymentHistory -DeploymentId "prod-deployment"

# Rollback if needed
Start-DeploymentRollback -DeploymentId "prod-deployment" -TargetSnapshot "pre-update"
```

#### 5. Security and Compliance
```powershell
# Run comprehensive security audit
Test-OpenTofuSecurity -Detailed
Test-InfrastructureCompliance -ComplianceStandard "All" -Detailed

# Optimize performance
Optimize-DeploymentPerformance
Optimize-DeploymentCaching
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

## CI/CD Integration Examples

### GitHub Actions Workflow

Create `.github/workflows/infrastructure.yml`:

```yaml
name: Infrastructure Deployment
on:
  push:
    branches: [main]
    paths: ['infrastructure/**']
  pull_request:
    paths: ['infrastructure/**']

jobs:
  plan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Setup PowerShell
        uses: microsoft/setup-powershell@v1
      - name: Install OpenTofu
        run: |
          Import-Module ./aither-core/modules/OpenTofuProvider -Force
          Install-OpenTofuSecure -Version "1.8.0"
      - name: Plan Infrastructure
        run: |
          Start-InfrastructureDeployment -ConfigurationPath "infrastructure/production.yaml" -DryRun
  
  deploy:
    if: github.ref == 'refs/heads/main'
    needs: plan
    runs-on: ubuntu-latest
    environment: production
    steps:
      - uses: actions/checkout@v4
      - name: Deploy Infrastructure
        run: |
          Import-Module ./aither-core/modules/OpenTofuProvider -Force
          New-DeploymentSnapshot -DeploymentId "prod" -Name "pre-deploy-$(date +%Y%m%d%H%M%S)"
          Start-InfrastructureDeployment -ConfigurationPath "infrastructure/production.yaml"
```

### Azure DevOps Pipeline

Create `azure-pipelines.yml`:

```yaml
trigger:
  branches:
    include:
      - main
  paths:
    include:
      - infrastructure/*

pool:
  vmImage: 'ubuntu-latest'

stages:
- stage: Plan
  jobs:
  - job: InfrastructurePlan
    steps:
    - pwsh: |
        Import-Module ./aither-core/modules/OpenTofuProvider -Force
        Install-OpenTofuSecure -Version "1.8.0"
        Start-InfrastructureDeployment -ConfigurationPath "infrastructure/$(environment).yaml" -DryRun
      displayName: 'Plan Infrastructure Changes'

- stage: Deploy
  condition: and(succeeded(), eq(variables['Build.SourceBranch'], 'refs/heads/main'))
  jobs:
  - deployment: InfrastructureDeployment
    environment: 'production'
    strategy:
      runOnce:
        deploy:
          steps:
          - pwsh: |
              Import-Module ./aither-core/modules/OpenTofuProvider -Force
              New-DeploymentSnapshot -DeploymentId "$(environment)" -Name "pre-deploy-$(Build.BuildNumber)"
              Start-InfrastructureDeployment -ConfigurationPath "infrastructure/$(environment).yaml"
            displayName: 'Deploy Infrastructure'
```

### GitLab CI/CD

Create `.gitlab-ci.yml`:

```yaml
stages:
  - validate
  - plan
  - deploy

variables:
  DEPLOYMENT_ID: "gitlab-${CI_ENVIRONMENT_NAME}"

infrastructure_validate:
  stage: validate
  script:
    - Import-Module ./aither-core/modules/OpenTofuProvider -Force
    - Test-OpenTofuInstallation
    - Read-DeploymentConfiguration -Path "infrastructure/${CI_ENVIRONMENT_NAME}.yaml"

infrastructure_plan:
  stage: plan
  script:
    - Import-Module ./aither-core/modules/OpenTofuProvider -Force
    - Start-InfrastructureDeployment -ConfigurationPath "infrastructure/${CI_ENVIRONMENT_NAME}.yaml" -DryRun
  artifacts:
    reports:
      terraform: tfplan.json

infrastructure_deploy:
  stage: deploy
  script:
    - Import-Module ./aither-core/modules/OpenTofuProvider -Force
    - New-DeploymentSnapshot -DeploymentId "${DEPLOYMENT_ID}" -Name "pre-deploy-${CI_PIPELINE_ID}"
    - Start-InfrastructureDeployment -ConfigurationPath "infrastructure/${CI_ENVIRONMENT_NAME}.yaml"
  only:
    - main
  environment:
    name: production
```

## Advanced Usage Patterns

### Multi-Environment Deployment

```powershell
# Define environments
$environments = @('dev', 'staging', 'production')

foreach ($env in $environments) {
    Write-Host "Deploying to $env environment..."
    
    # Create environment-specific snapshot
    New-DeploymentSnapshot -DeploymentId "$env-deployment" -Name "automated-backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    
    # Deploy with environment-specific configuration
    $configPath = "environments/$env/infrastructure.yaml"
    Start-InfrastructureDeployment -ConfigurationPath $configPath
    
    # Verify deployment
    $status = Get-DeploymentStatus -DeploymentId "$env-deployment"
    if (-not $status.Success) {
        Write-Error "Deployment to $env failed"
        Start-DeploymentRollback -DeploymentId "$env-deployment" -RollbackType "LastGood"
        break
    }
}
```

### Blue-Green Deployment

```powershell
# Blue-Green deployment pattern
$currentEnvironment = "blue"
$newEnvironment = "green"

# Deploy to green environment
Start-InfrastructureDeployment -ConfigurationPath "infrastructure/$newEnvironment.yaml"

# Verify green environment
$greenStatus = Get-DeploymentStatus -DeploymentId "$newEnvironment-deployment"
if ($greenStatus.Success) {
    # Switch traffic to green
    Write-Host "Switching traffic to $newEnvironment environment"
    
    # Update load balancer configuration
    Start-InfrastructureDeployment -ConfigurationPath "infrastructure/load-balancer.yaml" -Stage "Apply"
    
    # Cleanup old blue environment after successful switch
    Start-DeploymentRollback -DeploymentId "$currentEnvironment-deployment" -RollbackType "Destroy"
} else {
    Write-Error "Green environment deployment failed, staying on blue"
}
```

### Infrastructure Testing Pipeline

```powershell
# Comprehensive infrastructure testing
function Test-InfrastructurePipeline {
    param(
        [string]$ConfigurationPath,
        [string]$Environment
    )
    
    try {
        # 1. Validate configuration
        Write-Host "Step 1: Validating configuration..."
        $config = Read-DeploymentConfiguration -Path $ConfigurationPath -ExpandVariables
        
        # 2. Security audit
        Write-Host "Step 2: Running security audit..."
        $securityResult = Test-OpenTofuSecurity -Detailed
        if (-not $securityResult.Passed) {
            throw "Security audit failed: $($securityResult.Issues -join '; ')"
        }
        
        # 3. Plan deployment
        Write-Host "Step 3: Planning deployment..."
        $planResult = Start-InfrastructureDeployment -ConfigurationPath $ConfigurationPath -DryRun
        
        # 4. Create backup
        Write-Host "Step 4: Creating backup snapshot..."
        New-DeploymentSnapshot -DeploymentId "$Environment-deployment" -Name "pre-pipeline-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        
        # 5. Execute deployment
        Write-Host "Step 5: Executing deployment..."
        $deployResult = Start-InfrastructureDeployment -ConfigurationPath $ConfigurationPath
        
        # 6. Verify deployment
        Write-Host "Step 6: Verifying deployment..."
        $verifyResult = Get-DeploymentStatus -DeploymentId "$Environment-deployment"
        
        # 7. Performance optimization
        Write-Host "Step 7: Optimizing performance..."
        Optimize-DeploymentPerformance
        Optimize-DeploymentCaching
        
        return @{
            Success = $true
            DeploymentId = "$Environment-deployment"
            Duration = $deployResult.Duration
        }
        
    } catch {
        Write-Error "Pipeline failed: $($_.Exception.Message)"
        
        # Automatic rollback on failure
        Write-Host "Initiating automatic rollback..."
        Start-DeploymentRollback -DeploymentId "$Environment-deployment" -RollbackType "LastGood" -Force
        
        return @{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

# Usage
$result = Test-InfrastructurePipeline -ConfigurationPath "infrastructure/production.yaml" -Environment "production"
```

## Integration with AitherZero Platform

### VS Code Tasks Integration
The module integrates seamlessly with VS Code tasks defined in `.vscode/tasks.json`:

```json
{
    "label": "OpenTofu: Plan Infrastructure",
    "type": "shell",
    "command": "pwsh",
    "args": [
        "-Command",
        "Import-Module ./aither-core/modules/OpenTofuProvider -Force; Start-InfrastructureDeployment -ConfigurationPath infrastructure/dev.yaml -DryRun"
    ],
    "group": "build",
    "presentation": {
        "echo": true,
        "reveal": "always",
        "focus": false,
        "panel": "shared"
    }
}
```

### PatchManager Integration
Use with PatchManager v3.0 for change management:

```powershell
# Infrastructure updates with automatic PR creation
New-Feature -Description "Update lab infrastructure to v1.2" -Changes {
    Import-Module ./aither-core/modules/OpenTofuProvider -Force
    
    # Create backup before changes
    New-DeploymentSnapshot -DeploymentId "lab-deployment" -Name "pre-v1.2-update"
    
    # Initialize provider with new configuration
    Initialize-OpenTofuProvider -ConfigPath "infrastructure/lab_config_v1.2.yaml"
    
    # Deploy infrastructure
    Start-InfrastructureDeployment -ConfigurationPath "infrastructure/lab_config_v1.2.yaml"
}

# Quick infrastructure fixes
New-QuickFix -Description "Fix Hyper-V networking configuration" -Changes {
    # Update only networking components
    Start-InfrastructureDeployment -ConfigurationPath "infrastructure/networking.yaml" -Stage "Apply"
}

# Emergency infrastructure rollback
New-Hotfix -Description "Rollback infrastructure after critical failure" -Changes {
    Start-DeploymentRollback -DeploymentId "prod-deployment" -RollbackType "LastGood" -Force
}
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
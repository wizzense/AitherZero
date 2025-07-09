# AitherZero Developer Onboarding Guide

Welcome to AitherZero! This comprehensive guide will help you get started with the AitherZero infrastructure automation platform and understand the domain-based architecture.

## Table of Contents

1. [Getting Started](#getting-started)
2. [Architecture Overview](#architecture-overview)
3. [Domain Deep Dive](#domain-deep-dive)
4. [Development Environment Setup](#development-environment-setup)
5. [Essential Commands](#essential-commands)
6. [Common Development Patterns](#common-development-patterns)
7. [Testing and Quality Assurance](#testing-and-quality-assurance)
8. [Best Practices](#best-practices)
9. [Resources and Support](#resources-and-support)

## Getting Started

### What is AitherZero?

AitherZero is a **standalone PowerShell automation framework** for OpenTofu/Terraform infrastructure management. It provides enterprise-grade infrastructure as code (IaC) automation with comprehensive testing and modular architecture.

### Key Features

- **196+ Functions**: Comprehensive automation capabilities
- **6 Logical Domains**: Organized by business functionality
- **Cross-Platform**: Windows, Linux, macOS support
- **Enterprise-Grade**: Security, compliance, and scalability
- **Extensive Testing**: 95% function coverage
- **Rich Documentation**: Comprehensive guides and examples

### Technology Stack

- **Primary Language**: PowerShell 7.0+
- **Infrastructure**: OpenTofu/Terraform
- **Testing**: Pester framework
- **CI/CD**: GitHub Actions
- **Version Control**: Git with semantic versioning

## Architecture Overview

### Domain-Based Architecture

AitherZero consolidates **30+ legacy modules** into **6 logical domains** with **196+ functions**:

| Domain | Functions | Purpose |
|--------|-----------|---------|
| **Infrastructure** | 57 | Infrastructure deployment and monitoring |
| **Security** | 41 | Security automation and credential management |
| **Configuration** | 36 | Configuration management and environment switching |
| **Utilities** | 24 | Utility services and maintenance |
| **Experience** | 22 | User experience and setup automation |
| **Automation** | 16 | Script management and workflow orchestration |

### Benefits of Domain Architecture

1. **Logical Organization**: Functions grouped by business domain
2. **Reduced Complexity**: Single entry point instead of 30+ modules
3. **Better Performance**: Consolidated loading and shared resources
4. **Improved Maintainability**: Related functions maintained together
5. **Enhanced Testing**: Domain-based test organization

## Domain Deep Dive

### Infrastructure Domain (57 functions)

**Purpose**: Infrastructure deployment and monitoring

**Key Components**:
- **LabRunner** (17 functions): Lab automation and script execution
- **OpenTofuProvider** (11 functions): Infrastructure deployment
- **ISOManager** (10 functions): ISO management and customization
- **SystemMonitoring** (19 functions): System performance monitoring

**Essential Functions**:
```powershell
# Lab automation
Start-LabAutomation -Config $labConfig
Get-LabStatus -LabName "WebLab"

# Infrastructure deployment
Start-InfrastructureDeployment -ConfigPath "./main.tf"
Get-DeploymentStatus -DeploymentId $deploymentId

# ISO management
Get-ISODownload -Url $isoUrl -OutputPath "./downloads"
Get-ISOInventory -InventoryPath "./isos"

# System monitoring
Get-SystemDashboard
Start-SystemMonitoring -MonitoringConfig $config
```

### Security Domain (41 functions)

**Purpose**: Security automation and credential management

**Key Components**:
- **SecureCredentials** (10 functions): Enterprise credential management
- **SecurityAutomation** (31 functions): Security automation and compliance

**Essential Functions**:
```powershell
# Credential management
Initialize-SecureCredentialStore -StorePath "./credentials"
New-SecureCredential -Name "DBCred" -Username "admin" -Password $securePassword
Get-SecureCredential -Name "DBCred"

# Security automation
Get-ADSecurityAssessment -DomainName "company.local"
Enable-CredentialGuard -Force
Set-SystemHardening -HardeningLevel "Maximum"
```

### Configuration Domain (36 functions)

**Purpose**: Configuration management and environment switching

**Key Components**:
- **ConfigurationCore** (11 functions): Central configuration management
- **ConfigurationCarousel** (12 functions): Environment switching
- **ConfigurationRepository** (5 functions): Git-based configurations
- **ConfigurationManager** (8 functions): Configuration validation

**Essential Functions**:
```powershell
# Configuration management
Get-ConfigurationStore -StoreName "AppConfig"
Set-ModuleConfiguration -ModuleName "WebModule" -Configuration $config
Validate-Configuration -Configuration $config -Schema $schema

# Environment switching
Switch-ConfigurationSet -ConfigurationName "AppConfig" -Environment "Production"
Get-AvailableConfigurations
Add-ConfigurationRepository -Name "TeamConfig" -Source $gitUrl
```

### Experience Domain (22 functions)

**Purpose**: User experience and setup automation

**Key Components**:
- **SetupWizard** (11 functions): Intelligent setup and onboarding
- **StartupExperience** (11 functions): Interactive startup management

**Essential Functions**:
```powershell
# Setup automation
Start-IntelligentSetup -Profile "developer"
Get-InstallationProfile -ProfileName "developer"
Generate-QuickStartGuide -SetupState $setupState

# Interactive experience
Start-InteractiveMode -Mode "Setup"
Show-ContextMenu -MenuItems @("Setup", "Configure", "Exit")
Initialize-TerminalUI
```

### Automation Domain (16 functions)

**Purpose**: Script management and workflow orchestration

**Key Components**:
- **ScriptManager** (14 functions): Script execution and template management
- **OrchestrationEngine** (2 functions): Workflow orchestration

**Essential Functions**:
```powershell
# Script management
Register-OneOffScript -ScriptPath "./deploy.ps1" -Name "Deploy"
Invoke-OneOffScript -Name "Deploy" -Parameters @{ Environment = "Production" }
Get-ScriptTemplate -TemplateName "Basic"

# Advanced execution
Start-ScriptExecution -ScriptName "Deploy" -Background -MaxRetries 3
Get-ScriptExecutionHistory -ScriptName "Deploy"
```

### Utilities Domain (24 functions)

**Purpose**: Utility services and maintenance

**Key Components**:
- **SemanticVersioning** (8 functions): Version calculation and management
- **LicenseManager** (3 functions): License validation and feature access
- **RepoSync** (2 functions): Repository synchronization
- **UnifiedMaintenance** (3 functions): Maintenance operations
- **UtilityServices** (8 functions): Common utility functions

**Essential Functions**:
```powershell
# Version management
Get-NextSemanticVersion -CurrentVersion "1.0.0" -VersionType "minor"
Calculate-NextVersion -Commits $commits -CurrentVersion "1.0.0"

# License management
Get-LicenseStatus
Test-FeatureAccess -FeatureName "AdvancedReporting"

# Repository sync
Sync-ToAitherLab -Force
Get-RepoSyncStatus
```

## Development Environment Setup

### Prerequisites

1. **PowerShell 7.0+**
   ```powershell
   # Check PowerShell version
   $PSVersionTable.PSVersion
   
   # Install PowerShell 7 if needed
   # Windows: winget install Microsoft.PowerShell
   # Linux: Download from GitHub releases
   # macOS: brew install powershell
   ```

2. **Git**
   ```bash
   # Check Git version
   git --version
   
   # Configure Git
   git config --global user.name "Your Name"
   git config --global user.email "your.email@example.com"
   ```

3. **VS Code** (recommended)
   - PowerShell Extension
   - GitLens Extension
   - Pester Test Explorer

### One-Command Setup

```powershell
# Unified developer setup (recommended)
./Start-DeveloperSetup.ps1

# Quick setup (minimal, fast)
./Start-DeveloperSetup.ps1 -Profile Quick

# Full setup (all tools and features)
./Start-DeveloperSetup.ps1 -Profile Full
```

**What the developer setup includes:**
- ✅ Prerequisites validation (PowerShell 7, Git, etc.)
- ✅ Core development environment configuration
- ✅ VS Code settings and extensions
- ✅ Git pre-commit hooks
- ✅ AI development tools (Claude Code, Gemini CLI)
- ✅ PatchManager aliases and shortcuts
- ✅ Module path configuration

### Manual Setup

If you prefer manual setup:

1. **Clone Repository**
   ```bash
   git clone https://github.com/aitherzero/AitherZero.git
   cd AitherZero
   ```

2. **Initialize Environment**
   ```powershell
   # Import AitherCore
   Import-Module ./aither-core/AitherCore.psm1 -Force
   
   # Test installation
   Get-PlatformInfo
   Get-LicenseStatus
   ```

3. **Configure Development Tools**
   ```powershell
   # Install AI tools
   Import-Module ./aither-core/modules/AIToolsIntegration -Force
   Install-ClaudeCode
   Install-GeminiCLI
   
   # Configure Git hooks
   git config core.hooksPath .githooks
   ```

## Essential Commands

### Basic Operations

```powershell
# Import AitherCore (required for all operations)
Import-Module ./aither-core/AitherCore.psm1 -Force

# Get platform information
Get-PlatformInfo

# Check license status
Get-LicenseStatus

# Get current version
Get-CurrentVersion
```

### Testing

```powershell
# Run all tests (default - core functionality, <30 seconds)
./tests/Run-Tests.ps1

# Test setup/installation experience
./tests/Run-Tests.ps1 -Setup

# Run all tests
./tests/Run-Tests.ps1 -All

# Run domain-specific tests
./tests/Run-Tests.ps1 -Domain infrastructure
./tests/Run-Tests.ps1 -Domain security
```

### Development Workflow

```powershell
# Import PatchManager for Git operations
Import-Module ./aither-core/modules/PatchManager -Force

# Create new feature
New-Feature -Description "Add new functionality" -Changes {
    # Your implementation
}

# Create quick fix
New-QuickFix -Description "Fix typo" -Changes {
    # Your fix
}

# Create hotfix
New-Hotfix -Description "Critical security fix" -Changes {
    # Your urgent fix
}
```

### Configuration Management

```powershell
# Configuration Carousel - Switch between configurations
Import-Module ./aither-core/modules/ConfigurationCarousel -Force
Get-AvailableConfigurations
Switch-ConfigurationSet -ConfigurationName "dev" -Environment "development"
```

### Build and Release

```powershell
# Build packages
./build/Build-Package.ps1

# Build specific platform
./build/Build-Package.ps1 -Platform windows

# Create release
./AitherRelease.ps1 -Version 1.2.3 -Message "Bug fixes"
```

## Common Development Patterns

### Error Handling Pattern

```powershell
function Example-Function {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Parameter
    )
    
    try {
        Write-CustomLog -Level 'INFO' -Message "Starting operation: $Parameter"
        
        # Your logic here
        $result = Invoke-Operation -Parameter $Parameter
        
        Write-CustomLog -Level 'SUCCESS' -Message "Operation completed successfully"
        return $result
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Operation failed: $($_.Exception.Message)"
        throw
    }
}
```

### Configuration Pattern

```powershell
function Get-ModuleConfig {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ModuleName
    )
    
    # Get configuration with fallback
    $config = Get-ModuleConfiguration -ModuleName $ModuleName
    
    if (-not $config) {
        # Load default configuration
        $config = Get-DefaultConfiguration -ModuleName $ModuleName
    }
    
    # Validate configuration
    $validation = Validate-Configuration -Configuration $config
    if (-not $validation.IsValid) {
        throw "Invalid configuration for module: $ModuleName"
    }
    
    return $config
}
```

### Cross-Platform Pattern

```powershell
function Get-PlatformSpecificPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RelativePath
    )
    
    if ($IsWindows) {
        $basePath = $env:LOCALAPPDATA
    } elseif ($IsLinux) {
        $basePath = "$env:HOME/.local/share"
    } elseif ($IsMacOS) {
        $basePath = "$env:HOME/Library/Application Support"
    } else {
        throw "Unsupported platform"
    }
    
    return Join-Path $basePath $RelativePath
}
```

### Logging Pattern

```powershell
function Example-WithLogging {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Operation
    )
    
    Write-CustomLog -Level 'INFO' -Message "Starting $Operation"
    
    try {
        # Operation logic
        $result = Invoke-SomeOperation
        
        Write-CustomLog -Level 'SUCCESS' -Message "$Operation completed successfully"
        return $result
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "$Operation failed: $($_.Exception.Message)"
        throw
    } finally {
        Write-CustomLog -Level 'INFO' -Message "$Operation cleanup completed"
    }
}
```

### Testing Pattern

```powershell
Describe "Example Function Tests" {
    BeforeAll {
        # Import AitherCore
        Import-Module ./aither-core/AitherCore.psm1 -Force
        
        # Initialize test environment
        $testContext = Initialize-TestEnvironment
    }
    
    Context "Parameter Validation" {
        It "Should validate required parameters" {
            { Example-Function -Parameter $null } | Should -Throw
        }
        
        It "Should accept valid parameters" {
            { Example-Function -Parameter "ValidValue" } | Should -Not -Throw
        }
    }
    
    Context "Functionality Tests" {
        It "Should return expected result" {
            $result = Example-Function -Parameter "TestValue"
            $result | Should -Not -BeNullOrEmpty
        }
        
        It "Should handle errors gracefully" {
            { Example-Function -Parameter "InvalidValue" } | Should -Throw
        }
    }
    
    AfterAll {
        # Clean up test environment
        Remove-TestEnvironment -Context $testContext
    }
}
```

## Testing and Quality Assurance

### Test Organization

Tests are organized by domain:
```
tests/
├── domains/
│   ├── automation/           # 16 functions tested
│   ├── configuration/        # 36 functions tested
│   ├── security/            # 41 functions tested
│   ├── infrastructure/      # 57 functions tested
│   ├── experience/          # 22 functions tested
│   └── utilities/           # 24 functions tested
├── integration/             # Cross-domain tests
└── performance/            # Performance tests
```

### Test Execution

```powershell
# Run all tests
./tests/Run-Tests.ps1

# Run specific domain tests
./tests/Run-Tests.ps1 -Domain infrastructure

# Run with coverage
./tests/Run-Tests.ps1 -All -Coverage

# Run performance tests
./tests/Run-Tests.ps1 -Performance
```

### Test Coverage

Current coverage status:
- **Total Functions**: 196
- **Functions Tested**: 186 (95% coverage)
- **Domain Coverage**: 6/6 domains (100%)

### Writing Tests

Follow the testing patterns:

```powershell
# Test structure
Describe "DomainName Function Tests" {
    BeforeAll {
        Import-Module ./aither-core/AitherCore.psm1 -Force
        $testContext = Initialize-TestEnvironment -Domain "domainname"
    }
    
    Context "Function Group Tests" {
        It "Should test specific functionality" {
            # Test logic
        }
    }
    
    AfterAll {
        Remove-TestEnvironment -Context $testContext
    }
}
```

### Quality Standards

1. **Code Quality**: PSScriptAnalyzer compliance
2. **Test Coverage**: Minimum 95% function coverage
3. **Documentation**: Every function documented
4. **Error Handling**: Comprehensive error handling
5. **Platform Compatibility**: Cross-platform support

## Best Practices

### Development Best Practices

1. **Import AitherCore Once**
   ```powershell
   # Always import AitherCore at the beginning
   Import-Module ./aither-core/AitherCore.psm1 -Force
   ```

2. **Use Proper Error Handling**
   ```powershell
   try {
       # Your code
   } catch {
       Write-CustomLog -Level 'ERROR' -Message $_.Exception.Message
       throw
   }
   ```

3. **Follow Naming Conventions**
   - Functions: `Verb-Noun` format
   - Variables: `$camelCase`
   - Constants: `$UPPER_CASE`

4. **Use Cross-Platform Paths**
   ```powershell
   # Use Join-Path for cross-platform compatibility
   $path = Join-Path $basePath $relativePath
   ```

5. **Implement Logging**
   ```powershell
   Write-CustomLog -Level 'INFO' -Message "Operation started"
   ```

### Git Workflow Best Practices

1. **Use PatchManager for All Git Operations**
   ```powershell
   # Never use git commands directly
   # Always use PatchManager
   New-Feature -Description "Add new feature" -Changes { ... }
   ```

2. **Write Meaningful Commit Messages**
   ```
   feat: add user authentication
   fix: resolve configuration loading issue
   docs: update API documentation
   ```

3. **Test Before Committing**
   ```powershell
   # Always test before committing
   ./tests/Run-Tests.ps1 -Quick
   ```

### Code Organization Best Practices

1. **Group Related Functions**
   ```powershell
   # Group functions by domain
   # Infrastructure functions in infrastructure domain
   # Security functions in security domain
   ```

2. **Use Consistent Parameter Names**
   ```powershell
   # Use consistent parameter names across functions
   param(
       [Parameter(Mandatory = $true)]
       [string]$Name,
       
       [Parameter(Mandatory = $false)]
       [string]$Path = ".",
       
       [Parameter(Mandatory = $false)]
       [switch]$Force
   )
   ```

3. **Document All Functions**
   ```powershell
   function Example-Function {
       <#
       .SYNOPSIS
           Brief description of the function
       .DESCRIPTION
           Detailed description of the function
       .PARAMETER Name
           Description of the Name parameter
       .EXAMPLE
           Example-Function -Name "Test"
       #>
   }
   ```

### Performance Best Practices

1. **Use Parallel Processing**
   ```powershell
   # Use ForEach-Object -Parallel for parallel processing
   $items | ForEach-Object -Parallel {
       # Process item
   } -ThrottleLimit 5
   ```

2. **Implement Caching**
   ```powershell
   # Cache expensive operations
   if (-not $script:Cache) {
       $script:Cache = Get-ExpensiveData
   }
   return $script:Cache
   ```

3. **Use Efficient Data Structures**
   ```powershell
   # Use hashtables for lookups
   $lookup = @{}
   foreach ($item in $items) {
       $lookup[$item.Key] = $item.Value
   }
   ```

### Security Best Practices

1. **Validate All Input**
   ```powershell
   param(
       [Parameter(Mandatory = $true)]
       [ValidateNotNullOrEmpty()]
       [string]$Input
   )
   ```

2. **Use Secure Credential Management**
   ```powershell
   # Use SecureString for passwords
   $securePassword = Read-Host -AsSecureString
   New-SecureCredential -Name "Cred" -Password $securePassword
   ```

3. **Implement Security Validation**
   ```powershell
   # Validate security configuration
   $securityResult = Test-ConfigurationSecurity -Configuration $config
   if (-not $securityResult.IsValid) {
       throw "Security validation failed"
   }
   ```

## Resources and Support

### Documentation

- **API Reference**: Complete function documentation
- **Migration Guide**: Guide for migrating from legacy modules
- **Examples**: Comprehensive examples and tutorials
- **Best Practices**: Development best practices and patterns

### Code Examples

#### Infrastructure Automation
```powershell
# Deploy infrastructure
Import-Module ./aither-core/AitherCore.psm1 -Force

$deploymentConfig = @{
    Environment = "Production"
    Region = "East"
    InstanceType = "Standard_D4s_v3"
}

$deployment = Start-InfrastructureDeployment -ConfigPath "./main.tf" -Variables $deploymentConfig
$status = Get-DeploymentStatus -DeploymentId $deployment.Id

Write-Host "Deployment Status: $($status.Status)"
```

#### Security Configuration
```powershell
# Configure security settings
Import-Module ./aither-core/AitherCore.psm1 -Force

# Initialize secure credential store
Initialize-SecureCredentialStore -StorePath "./credentials"

# Create secure credential
$securePassword = ConvertTo-SecureString "MySecurePassword" -AsPlainText -Force
New-SecureCredential -Name "AdminCred" -Username "admin" -Password $securePassword

# Perform security assessment
$assessment = Get-ADSecurityAssessment -DomainName "company.local"
Write-Host "Security Score: $($assessment.Score)"

# Apply security hardening
Set-SystemHardening -HardeningLevel "Maximum"
```

#### Configuration Management
```powershell
# Manage configurations
Import-Module ./aither-core/AitherCore.psm1 -Force

# Get configuration store
$store = Get-ConfigurationStore -StoreName "AppConfig"

# Switch environments
Switch-ConfigurationSet -ConfigurationName "AppConfig" -Environment "Production"

# Validate configuration
$validation = Validate-Configuration -Configuration $store.Configuration
if ($validation.IsValid) {
    Write-Host "Configuration is valid"
} else {
    Write-Host "Configuration validation failed: $($validation.Errors)"
}
```

### Community Resources

- **GitHub Repository**: Source code and issue tracking
- **Discussions**: Community discussions and Q&A
- **Wiki**: Community-maintained documentation
- **Examples Repository**: Community-contributed examples

### Professional Support

- **Enterprise Support**: Professional support for enterprise customers
- **Training Programs**: Comprehensive training programs
- **Consulting Services**: Professional consulting services
- **Custom Development**: Custom development and integration services

### Getting Help

1. **Documentation**: Check the comprehensive documentation
2. **Examples**: Review code examples and tutorials
3. **Community**: Ask questions in community forums
4. **Issues**: Report bugs and request features on GitHub
5. **Support**: Contact professional support for enterprise customers

## Next Steps

### For New Developers

1. **Complete Setup**: Run `./Start-DeveloperSetup.ps1`
2. **Explore Domains**: Review each domain's README
3. **Run Tests**: Execute `./tests/Run-Tests.ps1`
4. **Try Examples**: Work through code examples
5. **Build Something**: Create your first automation script

### For Experienced Developers

1. **Review Architecture**: Understand the domain structure
2. **Migrate Existing Code**: Use the migration guide
3. **Contribute**: Contribute to the project
4. **Optimize**: Optimize existing implementations
5. **Mentor**: Help onboard new team members

### Learning Path

1. **Week 1**: Setup and basic operations
2. **Week 2**: Domain deep dive and examples
3. **Week 3**: Advanced features and integration
4. **Week 4**: Testing and quality assurance
5. **Week 5**: Best practices and optimization
6. **Week 6**: Contributing and mentoring

## Conclusion

Welcome to the AitherZero development team! This guide provides a comprehensive foundation for developing with AitherZero. The domain-based architecture provides a powerful and organized approach to infrastructure automation.

Key takeaways:
- **196 functions** organized into **6 logical domains**
- **Cross-platform support** for Windows, Linux, and macOS
- **Comprehensive testing** with 95% function coverage
- **Rich documentation** and examples
- **Active community** and professional support

Start with the one-command setup, explore the domains, and begin building amazing infrastructure automation solutions with AitherZero!

For questions or support, please refer to the documentation, community forums, or contact the development team.

---

*This onboarding guide is continuously updated based on user feedback and new features. For the latest version, please check the official documentation repository.*
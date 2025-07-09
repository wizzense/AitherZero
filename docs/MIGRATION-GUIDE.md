# AitherZero Domain Migration Guide

This guide provides comprehensive instructions for migrating from the legacy module structure to the new domain-based architecture.

## Migration Overview

### What Changed
The AitherZero architecture has evolved from **30+ individual modules** to **6 logical domains** containing **196+ functions**. This consolidation provides:

- **Logical Organization**: Functions grouped by business domain
- **Reduced Complexity**: Single entry point instead of 30+ modules
- **Better Performance**: Consolidated loading and shared resources
- **Improved Maintainability**: Related functions maintained together
- **Enhanced Testing**: Domain-based test organization

### Migration Benefits
- **Zero Downtime**: Immediate migration without service interruption
- **Backward Compatibility**: All existing code continues to work
- **Improved Organization**: Functions grouped by business domain
- **Better Performance**: Consolidated loading and shared resources
- **Enhanced Testing**: Domain-based test organization

## Migration Timeline

### Phase 1: Immediate (Available Now)
- **Automatic Migration**: Import AitherCore and all functions are available
- **Backward Compatibility**: All legacy module functions work unchanged
- **New Domain Structure**: New domain-based organization available

### Phase 2: Gradual Adoption (Recommended)
- **Learn Domain Structure**: Understand the new domain organization
- **Update Development Practices**: Use domain-specific functions for new development
- **Training and Documentation**: Team training on new architecture

### Phase 3: Complete Transition (Future)
- **Code Modernization**: Update existing code to use domain structure
- **Performance Optimization**: Leverage domain-specific optimizations
- **Advanced Features**: Use new domain-specific capabilities

## Domain Migration Map

### Complete Legacy Module to Domain Mapping

| Legacy Module | Domain | Functions | Migration Status |
|---------------|--------|-----------|------------------|
| **LabRunner** | infrastructure | 17 | ✅ Complete |
| **OpenTofuProvider** | infrastructure | 11 | ✅ Complete |
| **ISOManager** | infrastructure | 10 | ✅ Complete |
| **SystemMonitoring** | infrastructure | 19 | ✅ Complete |
| **SecureCredentials** | security | 10 | ✅ Complete |
| **SecurityAutomation** | security | 31 | ✅ Complete |
| **ConfigurationCore** | configuration | 11 | ✅ Complete |
| **ConfigurationCarousel** | configuration | 12 | ✅ Complete |
| **ConfigurationManager** | configuration | 8 | ✅ Complete |
| **ConfigurationRepository** | configuration | 5 | ✅ Complete |
| **SetupWizard** | experience | 11 | ✅ Complete |
| **StartupExperience** | experience | 11 | ✅ Complete |
| **ScriptManager** | automation | 14 | ✅ Complete |
| **OrchestrationEngine** | automation | 2 | ✅ Complete |
| **SemanticVersioning** | utilities | 8 | ✅ Complete |
| **LicenseManager** | utilities | 3 | ✅ Complete |
| **RepoSync** | utilities | 2 | ✅ Complete |
| **UnifiedMaintenance** | utilities | 3 | ✅ Complete |
| **UtilityServices** | utilities | 7 | ✅ Complete |
| **PSScriptAnalyzerIntegration** | utilities | 1 | ✅ Complete |
| **BackupManager** | utilities | 5 | ✅ Complete |
| **DevEnvironment** | experience | 8 | ✅ Complete |
| **Logging** | utilities | 12 | ✅ Complete |
| **ModuleCommunication** | utilities | 6 | ✅ Complete |
| **ParallelExecution** | automation | 4 | ✅ Complete |
| **PatchManager** | automation | 15 | ✅ Complete |
| **ProgressTracking** | experience | 9 | ✅ Complete |
| **RemoteConnection** | infrastructure | 11 | ✅ Complete |
| **RestAPIServer** | utilities | 8 | ✅ Complete |
| **TestingFramework** | utilities | 7 | ✅ Complete |

**Total: 30 legacy modules → 6 domains (196 functions)**

## Step-by-Step Migration Process

### Step 1: Assessment and Planning

#### Inventory Current Usage
1. **Identify Module Dependencies**
   ```powershell
   # List all currently imported modules
   Get-Module | Where-Object { $_.Name -like "*Aither*" }
   
   # Find module usage in scripts
   Get-ChildItem -Path "." -Filter "*.ps1" -Recurse | 
       Select-String -Pattern "Import-Module.*Aither" | 
       Group-Object Pattern | 
       Select-Object Name, Count
   ```

2. **Catalog Function Usage**
   ```powershell
   # Find function usage patterns
   Get-ChildItem -Path "." -Filter "*.ps1" -Recurse | 
       Select-String -Pattern "(Start-Lab|Get-Secure|Switch-Configuration)" | 
       Group-Object Pattern | 
       Select-Object Name, Count
   ```

#### Create Migration Plan
1. **Prioritize by Usage**: Start with most frequently used modules
2. **Group by Domain**: Organize migration by domain
3. **Plan Testing**: Include testing strategy for each phase
4. **Set Timeline**: Define migration timeline and milestones

### Step 2: Environment Preparation

#### Install New Architecture
```powershell
# Backup current configuration
$backupPath = "./migration-backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
New-Item -ItemType Directory -Path $backupPath -Force

# Copy current scripts and configurations
Copy-Item -Path "./scripts" -Destination "$backupPath/scripts" -Recurse -Force
Copy-Item -Path "./configs" -Destination "$backupPath/configs" -Recurse -Force

# Update to new architecture
git pull origin main  # or appropriate branch
```

#### Test New Architecture
```powershell
# Import new AitherCore
Import-Module ./aither-core/AitherCore.psm1 -Force

# Test basic functionality
Test-Connection -ComputerName localhost -Count 1
Get-PlatformInfo
Get-LicenseStatus
```

### Step 3: Module-by-Module Migration

#### Infrastructure Domain Migration

**Legacy Modules**: LabRunner, OpenTofuProvider, ISOManager, SystemMonitoring

**Migration Steps**:
1. **Update Imports**
   ```powershell
   # OLD (Legacy)
   Import-Module ./aither-core/modules/LabRunner -Force
   Import-Module ./aither-core/modules/OpenTofuProvider -Force
   Import-Module ./aither-core/modules/ISOManager -Force
   Import-Module ./aither-core/modules/SystemMonitoring -Force
   
   # NEW (Domain)
   Import-Module ./aither-core/AitherCore.psm1 -Force
   # All infrastructure functions now available
   ```

2. **Function Availability Test**
   ```powershell
   # Test infrastructure functions
   Get-Command -Module AitherCore | Where-Object { $_.Name -like "*Lab*" }
   Get-Command -Module AitherCore | Where-Object { $_.Name -like "*OpenTofu*" }
   Get-Command -Module AitherCore | Where-Object { $_.Name -like "*ISO*" }
   Get-Command -Module AitherCore | Where-Object { $_.Name -like "*System*" }
   ```

3. **Update Scripts**
   ```powershell
   # Example: Lab automation script
   # OLD
   Import-Module ./aither-core/modules/LabRunner -Force
   $labConfig = Get-LabConfig -LabName "TestLab"
   Start-LabAutomation -Config $labConfig
   
   # NEW (No changes needed - functions work the same)
   Import-Module ./aither-core/AitherCore.psm1 -Force
   $labConfig = Get-LabConfig -LabName "TestLab"
   Start-LabAutomation -Config $labConfig
   ```

#### Security Domain Migration

**Legacy Modules**: SecureCredentials, SecurityAutomation

**Migration Steps**:
1. **Update Imports**
   ```powershell
   # OLD (Legacy)
   Import-Module ./aither-core/modules/SecureCredentials -Force
   Import-Module ./aither-core/modules/SecurityAutomation -Force
   
   # NEW (Domain)
   Import-Module ./aither-core/AitherCore.psm1 -Force
   # All security functions now available
   ```

2. **Credential Store Migration**
   ```powershell
   # Test credential store access
   $credentials = Get-AllSecureCredentials
   Write-Host "Found $($credentials.Count) credentials"
   
   # Test security assessment
   $assessment = Get-ADSecurityAssessment -DomainName "test.local"
   Write-Host "Security Score: $($assessment.Score)"
   ```

3. **Update Security Scripts**
   ```powershell
   # Example: Security automation script
   # OLD
   Import-Module ./aither-core/modules/SecureCredentials -Force
   Import-Module ./aither-core/modules/SecurityAutomation -Force
   $cred = Get-SecureCredential -Name "AdminCred"
   $assessment = Get-ADSecurityAssessment -DomainName "company.local"
   
   # NEW (No changes needed - functions work the same)
   Import-Module ./aither-core/AitherCore.psm1 -Force
   $cred = Get-SecureCredential -Name "AdminCred"
   $assessment = Get-ADSecurityAssessment -DomainName "company.local"
   ```

#### Configuration Domain Migration

**Legacy Modules**: ConfigurationCore, ConfigurationCarousel, ConfigurationManager, ConfigurationRepository

**Migration Steps**:
1. **Update Imports**
   ```powershell
   # OLD (Legacy)
   Import-Module ./aither-core/modules/ConfigurationCore -Force
   Import-Module ./aither-core/modules/ConfigurationCarousel -Force
   Import-Module ./aither-core/modules/ConfigurationManager -Force
   Import-Module ./aither-core/modules/ConfigurationRepository -Force
   
   # NEW (Domain)
   Import-Module ./aither-core/AitherCore.psm1 -Force
   # All configuration functions now available
   ```

2. **Configuration Store Migration**
   ```powershell
   # Test configuration store
   $store = Get-ConfigurationStore -StoreName "AppConfig"
   Write-Host "Configuration Store Status: $($store.Status)"
   
   # Test environment switching
   $environments = Get-AvailableConfigurations
   Write-Host "Available Environments: $($environments.Count)"
   ```

3. **Update Configuration Scripts**
   ```powershell
   # Example: Configuration management script
   # OLD
   Import-Module ./aither-core/modules/ConfigurationCore -Force
   Import-Module ./aither-core/modules/ConfigurationCarousel -Force
   $store = Get-ConfigurationStore -StoreName "AppConfig"
   Switch-ConfigurationSet -ConfigurationName "AppConfig" -Environment "Production"
   
   # NEW (No changes needed - functions work the same)
   Import-Module ./aither-core/AitherCore.psm1 -Force
   $store = Get-ConfigurationStore -StoreName "AppConfig"
   Switch-ConfigurationSet -ConfigurationName "AppConfig" -Environment "Production"
   ```

#### Experience Domain Migration

**Legacy Modules**: SetupWizard, StartupExperience

**Migration Steps**:
1. **Update Imports**
   ```powershell
   # OLD (Legacy)
   Import-Module ./aither-core/modules/SetupWizard -Force
   Import-Module ./aither-core/modules/StartupExperience -Force
   
   # NEW (Domain)
   Import-Module ./aither-core/AitherCore.psm1 -Force
   # All experience functions now available
   ```

2. **Setup Process Migration**
   ```powershell
   # Test setup functionality
   $platformInfo = Get-PlatformInfo
   $profiles = Get-InstallationProfile -ProfileName "developer"
   Write-Host "Setup Profiles Available: $($profiles.Count)"
   ```

3. **Update Setup Scripts**
   ```powershell
   # Example: Setup automation script
   # OLD
   Import-Module ./aither-core/modules/SetupWizard -Force
   $setupResult = Start-IntelligentSetup -Profile "developer"
   
   # NEW (No changes needed - functions work the same)
   Import-Module ./aither-core/AitherCore.psm1 -Force
   $setupResult = Start-IntelligentSetup -Profile "developer"
   ```

#### Automation Domain Migration

**Legacy Modules**: ScriptManager, OrchestrationEngine

**Migration Steps**:
1. **Update Imports**
   ```powershell
   # OLD (Legacy)
   Import-Module ./aither-core/modules/ScriptManager -Force
   Import-Module ./aither-core/modules/OrchestrationEngine -Force
   
   # NEW (Domain)
   Import-Module ./aither-core/AitherCore.psm1 -Force
   # All automation functions now available
   ```

2. **Script Repository Migration**
   ```powershell
   # Test script repository
   $repo = Get-ScriptRepository -IncludeStatistics
   Write-Host "Script Repository: $($repo.TotalScripts) scripts"
   
   # Test script execution
   $scripts = Get-RegisteredScripts
   Write-Host "Registered Scripts: $($scripts.Count)"
   ```

3. **Update Automation Scripts**
   ```powershell
   # Example: Script management script
   # OLD
   Import-Module ./aither-core/modules/ScriptManager -Force
   Register-OneOffScript -ScriptPath "./deploy.ps1" -Name "Deploy"
   $result = Invoke-OneOffScript -Name "Deploy"
   
   # NEW (No changes needed - functions work the same)
   Import-Module ./aither-core/AitherCore.psm1 -Force
   Register-OneOffScript -ScriptPath "./deploy.ps1" -Name "Deploy"
   $result = Invoke-OneOffScript -Name "Deploy"
   ```

#### Utilities Domain Migration

**Legacy Modules**: SemanticVersioning, LicenseManager, RepoSync, UnifiedMaintenance, UtilityServices, PSScriptAnalyzerIntegration

**Migration Steps**:
1. **Update Imports**
   ```powershell
   # OLD (Legacy)
   Import-Module ./aither-core/modules/SemanticVersioning -Force
   Import-Module ./aither-core/modules/LicenseManager -Force
   Import-Module ./aither-core/modules/RepoSync -Force
   Import-Module ./aither-core/modules/UnifiedMaintenance -Force
   Import-Module ./aither-core/modules/UtilityServices -Force
   Import-Module ./aither-core/modules/PSScriptAnalyzerIntegration -Force
   
   # NEW (Domain)
   Import-Module ./aither-core/AitherCore.psm1 -Force
   # All utility functions now available
   ```

2. **Utility Service Migration**
   ```powershell
   # Test utility services
   $version = Get-CurrentVersion
   $license = Get-LicenseStatus
   $syncStatus = Get-RepoSyncStatus
   Write-Host "Current Version: $version"
   Write-Host "License Status: $($license.Status)"
   Write-Host "Sync Status: $($syncStatus.Status)"
   ```

3. **Update Utility Scripts**
   ```powershell
   # Example: Version management script
   # OLD
   Import-Module ./aither-core/modules/SemanticVersioning -Force
   $currentVersion = Get-CurrentVersion
   $nextVersion = Get-NextSemanticVersion -CurrentVersion $currentVersion -VersionType "minor"
   
   # NEW (No changes needed - functions work the same)
   Import-Module ./aither-core/AitherCore.psm1 -Force
   $currentVersion = Get-CurrentVersion
   $nextVersion = Get-NextSemanticVersion -CurrentVersion $currentVersion -VersionType "minor"
   ```

### Step 4: Testing and Validation

#### Functional Testing
```powershell
# Test all domain functions
$testResults = @()

# Infrastructure domain tests
$testResults += Test-InfrastructureDomain
$testResults += Test-SecurityDomain
$testResults += Test-ConfigurationDomain
$testResults += Test-ExperienceDomain
$testResults += Test-AutomationDomain
$testResults += Test-UtilitiesDomain

# Summary
$passed = $testResults | Where-Object { $_.Status -eq "Passed" }
$failed = $testResults | Where-Object { $_.Status -eq "Failed" }
Write-Host "Tests Passed: $($passed.Count)"
Write-Host "Tests Failed: $($failed.Count)"
```

#### Performance Testing
```powershell
# Compare performance before/after migration
$performanceTests = @(
    "Module-Loading-Time",
    "Function-Execution-Time",
    "Memory-Usage",
    "CPU-Usage"
)

foreach ($test in $performanceTests) {
    $result = Invoke-PerformanceTest -TestName $test
    Write-Host "$test : $($result.Result)"
}
```

#### Integration Testing
```powershell
# Test integration between domains
$integrationTests = @(
    "Infrastructure-Security-Integration",
    "Configuration-Experience-Integration",
    "Automation-Utilities-Integration"
)

foreach ($test in $integrationTests) {
    $result = Invoke-IntegrationTest -TestName $test
    Write-Host "$test : $($result.Status)"
}
```

### Step 5: Production Deployment

#### Deployment Strategy
1. **Blue-Green Deployment**
   - Deploy new architecture alongside existing
   - Test thoroughly in production-like environment
   - Switch traffic gradually

2. **Rolling Update**
   - Update systems one at a time
   - Monitor for issues
   - Rollback capability maintained

3. **Canary Deployment**
   - Deploy to subset of systems
   - Monitor performance and stability
   - Gradual rollout to all systems

#### Deployment Checklist
- [ ] Backup current system
- [ ] Test new architecture in staging
- [ ] Update monitoring and alerting
- [ ] Deploy to production
- [ ] Validate functionality
- [ ] Monitor performance
- [ ] Update documentation
- [ ] Train team members

## Common Migration Scenarios

### Scenario 1: Simple Script Migration
**Situation**: Single script using one module

**Before**:
```powershell
# deploy.ps1
Import-Module ./aither-core/modules/LabRunner -Force
$labConfig = Get-LabConfig -LabName "WebLab"
Start-LabAutomation -Config $labConfig
```

**After**:
```powershell
# deploy.ps1
Import-Module ./aither-core/AitherCore.psm1 -Force
$labConfig = Get-LabConfig -LabName "WebLab"
Start-LabAutomation -Config $labConfig
```

**Migration Steps**:
1. Update import statement
2. Test script functionality
3. No other changes needed

### Scenario 2: Multi-Module Script Migration
**Situation**: Script using multiple modules

**Before**:
```powershell
# complex-deploy.ps1
Import-Module ./aither-core/modules/LabRunner -Force
Import-Module ./aither-core/modules/SecureCredentials -Force
Import-Module ./aither-core/modules/ConfigurationCore -Force

$config = Get-ConfigurationStore -StoreName "DeployConfig"
$credentials = Get-SecureCredential -Name "DeployUser"
$labConfig = Get-LabConfig -LabName "WebLab"
Start-LabAutomation -Config $labConfig
```

**After**:
```powershell
# complex-deploy.ps1
Import-Module ./aither-core/AitherCore.psm1 -Force

$config = Get-ConfigurationStore -StoreName "DeployConfig"
$credentials = Get-SecureCredential -Name "DeployUser"
$labConfig = Get-LabConfig -LabName "WebLab"
Start-LabAutomation -Config $labConfig
```

**Migration Steps**:
1. Replace multiple imports with single AitherCore import
2. All functions remain available
3. Test complete workflow

### Scenario 3: Module Development Migration
**Situation**: Custom module depending on AitherZero modules

**Before**:
```powershell
# CustomModule.psm1
Import-Module ./aither-core/modules/LabRunner -Force
Import-Module ./aither-core/modules/ConfigurationCore -Force

function Deploy-CustomApp {
    param($AppName)
    
    $config = Get-ConfigurationStore -StoreName "AppConfig"
    $labConfig = Get-LabConfig -LabName $AppName
    Start-LabAutomation -Config $labConfig
}
```

**After**:
```powershell
# CustomModule.psm1
Import-Module ./aither-core/AitherCore.psm1 -Force

function Deploy-CustomApp {
    param($AppName)
    
    $config = Get-ConfigurationStore -StoreName "AppConfig"
    $labConfig = Get-LabConfig -LabName $AppName
    Start-LabAutomation -Config $labConfig
}
```

**Migration Steps**:
1. Update import to use AitherCore
2. Test custom module functionality
3. Update module dependencies

### Scenario 4: CI/CD Pipeline Migration
**Situation**: CI/CD pipeline using AitherZero modules

**Before**:
```yaml
# .github/workflows/deploy.yml
- name: Deploy Infrastructure
  run: |
    Import-Module ./aither-core/modules/LabRunner -Force
    Import-Module ./aither-core/modules/OpenTofuProvider -Force
    Start-InfrastructureDeployment -ConfigPath "./main.tf"
```

**After**:
```yaml
# .github/workflows/deploy.yml
- name: Deploy Infrastructure
  run: |
    Import-Module ./aither-core/AitherCore.psm1 -Force
    Start-InfrastructureDeployment -ConfigPath "./main.tf"
```

**Migration Steps**:
1. Update CI/CD scripts
2. Test pipeline functionality
3. Update pipeline documentation

### Scenario 5: PowerShell Profile Migration
**Situation**: PowerShell profile with AitherZero modules

**Before**:
```powershell
# Microsoft.PowerShell_profile.ps1
Import-Module ./aither-core/modules/LabRunner -Force
Import-Module ./aither-core/modules/ConfigurationCore -Force
Import-Module ./aither-core/modules/UtilityServices -Force

Set-Alias -Name "lab" -Value "Start-LabAutomation"
Set-Alias -Name "config" -Value "Get-ConfigurationStore"
```

**After**:
```powershell
# Microsoft.PowerShell_profile.ps1
Import-Module ./aither-core/AitherCore.psm1 -Force

Set-Alias -Name "lab" -Value "Start-LabAutomation"
Set-Alias -Name "config" -Value "Get-ConfigurationStore"
```

**Migration Steps**:
1. Update profile imports
2. Test profile loading
3. Verify aliases work correctly

## Migration Validation

### Function Availability Validation
```powershell
# Test all expected functions are available
$expectedFunctions = @(
    # Infrastructure domain
    "Start-LabAutomation", "Get-ISODownload", "Start-InfrastructureDeployment", "Get-SystemDashboard",
    # Security domain
    "Get-SecureCredential", "Get-ADSecurityAssessment", "Enable-CredentialGuard",
    # Configuration domain
    "Get-ConfigurationStore", "Switch-ConfigurationSet", "Validate-Configuration",
    # Experience domain
    "Start-IntelligentSetup", "Get-InstallationProfile", "Start-InteractiveMode",
    # Automation domain
    "Register-OneOffScript", "Invoke-OneOffScript", "Get-ScriptTemplate",
    # Utilities domain
    "Get-NextSemanticVersion", "Test-FeatureAccess", "Sync-ToAitherLab"
)

$missingFunctions = @()
foreach ($function in $expectedFunctions) {
    if (-not (Get-Command $function -ErrorAction SilentlyContinue)) {
        $missingFunctions += $function
    }
}

if ($missingFunctions.Count -gt 0) {
    Write-Warning "Missing functions: $($missingFunctions -join ', ')"
} else {
    Write-Host "All expected functions are available" -ForegroundColor Green
}
```

### Performance Validation
```powershell
# Test loading performance
$loadTime = Measure-Command {
    Import-Module ./aither-core/AitherCore.psm1 -Force
}
Write-Host "Module load time: $($loadTime.TotalSeconds) seconds"

# Test function execution performance
$executionTime = Measure-Command {
    $platformInfo = Get-PlatformInfo
    $license = Get-LicenseStatus
    $version = Get-CurrentVersion
}
Write-Host "Function execution time: $($executionTime.TotalMilliseconds) ms"
```

### Integration Validation
```powershell
# Test cross-domain integration
$integrationTest = @{
    Infrastructure = (Get-Command -Name "*Lab*" -Module AitherCore).Count
    Security = (Get-Command -Name "*Secure*" -Module AitherCore).Count
    Configuration = (Get-Command -Name "*Configuration*" -Module AitherCore).Count
    Experience = (Get-Command -Name "*Setup*" -Module AitherCore).Count
    Automation = (Get-Command -Name "*Script*" -Module AitherCore).Count
    Utilities = (Get-Command -Name "*Version*" -Module AitherCore).Count
}

$integrationTest.GetEnumerator() | ForEach-Object {
    Write-Host "$($_.Key) domain: $($_.Value) functions"
}
```

## Troubleshooting

### Common Issues

#### Issue 1: Module Import Failures
**Problem**: AitherCore module fails to import
**Solution**:
```powershell
# Check PowerShell version
$PSVersionTable.PSVersion

# Check module path
$env:PSModulePath

# Force reload
Remove-Module AitherCore -Force -ErrorAction SilentlyContinue
Import-Module ./aither-core/AitherCore.psm1 -Force -Verbose
```

#### Issue 2: Function Not Found
**Problem**: Expected function is not available
**Solution**:
```powershell
# Check if function exists
Get-Command -Name "FunctionName" -ErrorAction SilentlyContinue

# List all available functions
Get-Command -Module AitherCore | Sort-Object Name

# Check function in specific domain
Get-Command -Module AitherCore | Where-Object { $_.Name -like "*Domain*" }
```

#### Issue 3: Configuration Issues
**Problem**: Configuration not working after migration
**Solution**:
```powershell
# Check configuration store
$store = Get-ConfigurationStore -StoreName "Default"
Write-Host "Configuration Status: $($store.Status)"

# Validate configuration
$validation = Validate-Configuration -Configuration $store.Configuration
Write-Host "Configuration Valid: $($validation.IsValid)"

# Reinitialize if needed
Initialize-ConfigurationCore
```

#### Issue 4: Performance Issues
**Problem**: Slower performance after migration
**Solution**:
```powershell
# Check module loading time
$loadTime = Measure-Command { Import-Module ./aither-core/AitherCore.psm1 -Force }
Write-Host "Load time: $($loadTime.TotalSeconds) seconds"

# Profile script execution
$executionTime = Measure-Command { YourScript.ps1 }
Write-Host "Execution time: $($executionTime.TotalSeconds) seconds"

# Check for resource leaks
Get-Process | Where-Object { $_.Name -like "*powershell*" } | Select-Object Name, WorkingSet
```

#### Issue 5: Credential Store Issues
**Problem**: Secure credentials not accessible
**Solution**:
```powershell
# Check credential store status
$storeStatus = Test-SecureCredentialCompliance
Write-Host "Credential Store Status: $($storeStatus.Status)"

# Reinitialize credential store if needed
Initialize-SecureCredentialStore -StorePath "./credentials"

# Test credential access
$testCred = Get-SecureCredential -Name "TestCredential"
```

### Migration Rollback

#### Rollback Strategy
1. **Immediate Rollback**
   ```powershell
   # Stop using new architecture
   Remove-Module AitherCore -Force
   
   # Restore legacy modules
   Import-Module ./aither-core/modules/LabRunner -Force
   Import-Module ./aither-core/modules/SecureCredentials -Force
   # ... other modules
   ```

2. **Data Restoration**
   ```powershell
   # Restore configuration backups
   $backupPath = "./migration-backup-20231201"
   Copy-Item -Path "$backupPath/configs" -Destination "./configs" -Recurse -Force
   Copy-Item -Path "$backupPath/scripts" -Destination "./scripts" -Recurse -Force
   ```

3. **Service Restoration**
   ```powershell
   # Restart services with legacy configuration
   Restart-Service -Name "AitherService" -Force
   
   # Verify service status
   Get-Service -Name "AitherService"
   ```

## Best Practices

### Migration Best Practices
1. **Plan Thoroughly**: Create detailed migration plan
2. **Test Extensively**: Test in non-production environment first
3. **Migrate Gradually**: Migrate one domain at a time
4. **Monitor Continuously**: Monitor performance and stability
5. **Document Changes**: Document all changes and decisions
6. **Train Team**: Ensure team understands new architecture

### Post-Migration Best Practices
1. **Use Domain Structure**: Leverage new domain organization
2. **Optimize Performance**: Use domain-specific optimizations
3. **Update Documentation**: Keep documentation current
4. **Continue Learning**: Stay updated with new features
5. **Share Knowledge**: Share migration experience with team

### Development Best Practices
1. **Single Import**: Use single AitherCore import
2. **Domain Awareness**: Understand domain structure
3. **Function Discovery**: Use Get-Command for function discovery
4. **Error Handling**: Implement proper error handling
5. **Testing**: Test across all target platforms

## Support and Resources

### Migration Support
- **Documentation**: Comprehensive migration documentation
- **Examples**: Migration examples and templates
- **Troubleshooting**: Common issues and solutions
- **Community**: Community support and discussions

### Training Resources
- **Migration Workshops**: Hands-on migration workshops
- **Documentation**: Step-by-step migration guides
- **Video Tutorials**: Video tutorials for complex scenarios
- **Best Practices**: Migration best practices and tips

### Professional Services
- **Migration Consulting**: Professional migration services
- **Custom Solutions**: Custom migration solutions
- **Training Programs**: Customized training programs
- **Ongoing Support**: Ongoing support and maintenance

## Conclusion

The migration from legacy modules to the new domain architecture provides significant benefits in terms of organization, performance, and maintainability. The process is designed to be seamless with full backward compatibility, allowing for gradual adoption at your own pace.

Key takeaways:
- **Zero Breaking Changes**: All existing code continues to work
- **Improved Organization**: 196 functions organized into 6 logical domains
- **Better Performance**: Consolidated loading and shared resources
- **Enhanced Maintainability**: Related functions maintained together
- **Simplified Testing**: Domain-based test organization

For additional support or questions, please refer to the documentation, community forums, or contact the development team.

---

*This migration guide is continuously updated based on user feedback and experience. For the latest version, please check the official documentation repository.*
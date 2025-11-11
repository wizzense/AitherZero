# AitherZero Module Architecture

## Overview

AitherZero uses a consolidated, domain-based module architecture with 33 PowerShell modules organized into 11 functional domains. All modules are loaded through the root `AitherZero.psm1` module to ensure complete integration with the orchestration engine.

**Version**: 2.1 (ClaudeCodeIntegration removed)  
**Total Modules**: 33 (reduced from 46, -28%)  
**Load Percentage**: 100% (all modules loaded in root)  
**Total Exported Functions**: 218 unique functions

## Architecture Principles

1. **Single Responsibility**: Each module has one clear, focused purpose
2. **Orchestration-Driven**: All modules loadable through root for orchestration access
3. **No Duplication**: Redundant/obsolete modules removed
4. **Domain Organization**: Logical grouping by functional area
5. **Explicit Exports**: Every module explicitly declares exported functions

## Module Loading Order

Modules are loaded in dependency order:

1. **Core Utilities** (Logging, Performance, EnvironmentConfig)
2. **Configuration** (Configuration, ConfigManager)
3. **CLI** (AitherZeroCLI)
4. **Domain Modules** (Development, Testing, Reporting, etc.)
5. **Specialized Modules** (AI-Agents, Documentation)

Critical modules (Logging, Performance, EnvironmentConfig, Configuration, ConfigManager) are loaded synchronously first, then remaining modules are loaded sequentially.

## Module Domains

### AI-Agents (2 modules, 9 functions)

AI workflow orchestration and integration with Copilot.

- **AIWorkflowOrchestrator.psm1** (5 functions)
  - Initialize-AIWorkflowOrchestrator, Start-AIWorkflow, Get-WorkflowStatus, Wait-AIWorkflow, Stop-AIWorkflow
- **CopilotOrchestrator.psm1** (4 functions)
  - Initialize-CopilotOrchestrator, Get-WorkflowConfiguration, Start-AutomatedCopilotWorkflow, Get-CopilotWorkflowStatus

**Usage**: AI-assisted development, automated code review, workflow orchestration

### Automation (5 modules, 19 functions)

Core orchestration engine and automation utilities.

- **OrchestrationEngine.psm1** (1 function)
  - Invoke-OrchestrationSequence
- **PlaybookHelpers.psm1** (1 function)
  - Get-PlaybookScriptInfo
- **GitHubWorkflowParser.psm1** (1 function)
  - ConvertFrom-GitHubWorkflow
- **DeploymentAutomation.psm1** (5 functions)
  - New-DeploymentPackage, Test-DeploymentPackage, Invoke-Deployment, Get-DeploymentStatus, Remove-DeploymentPackage
- **ScriptUtilities.psm1** (11 functions)
  - Write-ScriptLog, Get-GitHubToken, Test-Prerequisites, Get-ProjectRoot, Get-ScriptMetadata, Test-CommandAvailable, Test-IsAdministrator, Test-GitRepository, Invoke-WithRetry, Format-Duration, Test-GitHubAuthentication

**Usage**: Number-based script execution (0000-9999), playbook orchestration, deployment automation

### CLI (1 module, 22 functions)

Unified command-line interface for all AitherZero operations.

- **AitherZeroCLI.psm1** (22 functions)
  - Invoke-AitherScript, Get-AitherScript, Invoke-AitherSequence, Invoke-AitherPlaybook, Get-AitherPlaybook, Get-AitherConfig, Set-AitherConfig, Switch-AitherEnvironment, Get-AitherEnvironment, Set-AitherEnvironment, Add-ShellIntegration, Remove-ShellIntegration, Add-PathEntries, Get-ScriptInfo, Search-AitherScripts, Get-ScriptHistory, Get-ScriptHelp, Get-ScriptStage, Get-ScriptDependencies, Test-ScriptParameters, Invoke-ScriptWithValidation, Get-EnvironmentInfo

**Usage**: Primary interface for script execution, configuration management, environment switching

### Configuration (2 modules, 22 functions)

Configuration management with environment-specific settings.

- **Configuration.psm1** (21 functions)
  - Import-ConfigDataFile, Get-MergedConfiguration, Get-Configuration, Set-Configuration, Get-ConfigValue, Set-ConfigValue, Test-ConfigurationValid, Reset-Configuration, Export-Configuration, Import-Configuration, Get-ConfigurationPath, Set-ConfigurationPath, Get-ConfigurationBackup, Restore-ConfigurationBackup, Merge-Configuration, Get-ConfigurationHash, Compare-Configuration, Get-ConfigurationDiff, Validate-Configuration, Get-ConfigurationSchema, Update-ConfigurationSchema
- **ConfigManager.psm1** (1 function)
  - Initialize-ConfigManager

**Usage**: Environment-specific configuration, validation, backup/restore

### Development (3 modules, 22 functions)

Git automation, issue tracking, and pull request management.

- **GitAutomation.psm1** (6 functions)
  - Initialize-GitRepository, New-GitBranch, Submit-GitCommit, Sync-GitRepository, Get-GitStatus, Remove-GitBranch
- **IssueTracker.psm1** (8 functions)
  - New-GitHubIssue, Get-GitHubIssue, Update-GitHubIssue, Close-GitHubIssue, Add-GitHubIssueComment, Get-GitHubIssueComments, Add-GitHubIssueLabel, Remove-GitHubIssueLabel
- **PullRequestManager.psm1** (8 functions)
  - New-PullRequest, Get-PullRequest, Update-PullRequest, Close-PullRequest, Merge-PullRequest, Add-PullRequestComment, Get-PullRequestComments, Get-PullRequestReviews

**Usage**: Git workflows (0700-0799), GitHub automation, collaboration

### Documentation (2 modules, 18 functions)

Documentation generation and project indexing.

- **DocumentationEngine.psm1** (5 functions)
  - New-ModuleDocumentation, New-FunctionDocumentation, New-ScriptDocumentation, Update-DocumentationIndex, Export-DocumentationSite
- **ProjectIndexer.psm1** (13 functions)
  - Initialize-ProjectIndex, Update-ProjectIndex, Get-ProjectIndex, Find-ProjectFiles, Get-FileMetadata, Add-IndexEntry, Remove-IndexEntry, Update-IndexEntry, Get-IndexEntry, Search-Index, Export-Index, Import-Index, Rebuild-Index

**Usage**: Auto-generate documentation, maintain project index, export documentation sites

### Infrastructure (2 modules, 2 functions)

Infrastructure automation and deployment artifacts.

- **Infrastructure.psm1** (1 function - note: exports likely incomplete)
  - Test-OpenTofu
- **DeploymentArtifacts.psm1** (1 function)
  - New-DeploymentArtifact

**Usage**: OpenTofu/Terraform integration, VM management, artifact generation

### Reporting (3 modules, 12 functions)

Report generation, tech debt analysis, dashboard creation.

- **ReportingEngine.psm1** (10 functions)
  - New-Report, Add-ReportSection, Add-ReportTable, Add-ReportChart, Export-ReportHTML, Export-ReportMarkdown, Export-ReportJSON, Get-Report, Clear-Report, Set-ReportTemplate
- **TechDebtAnalysis.psm1** (1 function)
  - Invoke-TechDebtAnalysis
- **DashboardGeneration.psm1** (1 function)
  - New-DashboardHTML

**Usage**: Project metrics, tech debt tracking, HTML dashboards

### Security (3 modules, 28 functions)

Security operations, encryption, license management.

- **Security.psm1** (17 functions)
  - Write-SecurityLog, Invoke-SSHCommand, Test-SSHConnection, Set-AitherCredential, Get-AitherCredential, Remove-AitherCredential, Test-AitherCredential, New-CertificateAuthority, New-Certificate, Import-Certificate, Export-Certificate, Get-Certificate, Remove-Certificate, Test-Certificate, Protect-Credentials, Unprotect-Credentials, Get-SecureString
- **Encryption.psm1** (6 functions)
  - Protect-String, Unprotect-String, Protect-File, Unprotect-File, New-EncryptionKey, Test-EncryptionKey
- **LicenseManager.psm1** (5 functions)
  - New-License, Test-License, Get-LicenseFromGitHub, Get-LicenseKey, Find-License

**Usage**: Credential management, certificate operations, encryption, license validation

### Testing (4 modules, 19 functions)

Testing frameworks, test generation, test orchestration.

- **TestingFramework.psm1** (6 functions)
  - Invoke-ScriptAnalysis, Test-SyntaxValidation, Test-ASTValidation, Get-ScriptAST, Find-ScriptFunction, Invoke-UnitTests
- **AitherTestFramework.psm1** (10 functions)
  - Invoke-AitherTest, New-AitherTestSuite, Register-AitherTest, Get-AitherTestResults, Clear-AitherTestResults, Set-AitherTestConfiguration, Get-AitherTestConfiguration, Invoke-TestCategory, Get-TestCategories, Export-TestResults
- **CoreTestSuites.psm1** (1 function)
  - Register-CoreTestSuites
- **AutoTestGenerator.psm1** (2 functions)
  - New-AutoTest, Invoke-AutoTestGeneration

**Usage**: Pester testing, PSScriptAnalyzer, auto-test generation, test orchestration

### Utilities (6 modules, 48 functions)

Core utilities for logging, performance, maintenance, and more.

- **Logging.psm1** (19 functions)
  - Write-CustomLog, Set-LogLevel, Set-LogTargets, Enable-LogRotation, Disable-LogRotation, Get-LogConfiguration, Set-LogConfiguration, Clear-Logs, Get-LogFiles, Get-LogStats, Export-Logs, Import-Logs, Write-LogMessage, Write-LogError, Write-LogWarning, Write-LogInfo, Write-LogDebug, Write-LogTrace, Format-LogMessage
- **Performance.psm1** (11 functions)
  - Start-PerformanceTimer, Stop-PerformanceTimer, Measure-Performance, Get-PerformanceMetric, Get-PerformanceReport, Clear-PerformanceMetrics, Export-PerformanceData, Import-PerformanceData, Compare-Performance, Get-PerformanceBaseline, Set-PerformanceBaseline
- **EnvironmentConfig.psm1** (1 function)
  - Get-EnvironmentConfiguration
- **PackageManager.psm1** (5 functions)
  - Get-AvailablePackageManagers, Test-PackageInstalled, Install-SoftwarePackage, Uninstall-SoftwarePackage, Update-SoftwarePackage
- **Maintenance.psm1** (11 functions)
  - Reset-AitherEnvironment, Clear-AitherCache, Clear-TestResults, Clear-TemporaryFiles, Clear-LogFiles, Backup-Configuration, Restore-Configuration, Repair-ModuleStructure, Update-Dependencies, Optimize-Performance, Get-MaintenanceReport
- **LogViewer.psm1** (1 function)
  - Show-LogDashboard

**Usage**: Logging infrastructure, performance monitoring, environment management, package installation

## Removed Modules (12 modules, 7,277 lines deleted)

The following modules were removed as obsolete/redundant:

### Testing (7 modules removed)
- **TestGenerator.psm1** - Replaced by AutoTestGenerator.psm1
- **FunctionalTestFramework.psm1** - Consolidated into AitherTestFramework.psm1
- **FunctionalTestTemplates.psm1** - Consolidated into AitherTestFramework.psm1
- **PlaybookTestFramework.psm1** - Consolidated into AitherTestFramework.psm1
- **QualityValidator.psm1** - Functionality in TestingFramework.psm1
- **TestCacheManager.psm1** - No longer used
- **ThreeTierValidation.psm1** - Consolidated into TestingFramework.psm1

### Utilities (4 modules removed)
- **Bootstrap.psm1** - bootstrap.ps1 script handles this
- **LoggingDashboard.psm1** - LogViewer.psm1 provides this
- **LoggingEnhancer.psm1** - Features integrated into Logging.psm1
- **TextUtilities.psm1** - Single function, minimal value

### Development (1 module removed)
- **DeveloperTools.psm1** - No references found

## Module Dependencies

### Load Order Dependencies

1. **Logging** → Used by all modules for logging
2. **Performance** → Used by orchestration and testing
3. **EnvironmentConfig** → Used by CLI and configuration
4. **Configuration** → Used by most modules for settings
5. **CLI** → Depends on configuration, used for script execution
6. **All Others** → May depend on above core modules

### Inter-Module Dependencies

- **AitherZeroCLI** → Configuration, EnvironmentConfig
- **OrchestrationEngine** → PlaybookHelpers, ScriptUtilities
- **TestingFramework** → Logging, Configuration
- **ReportingEngine** → Configuration, Logging
- **Security** → Encryption (for credential protection)
- **LicenseManager** → Encryption (for license validation)

## Usage Examples

### Loading the Module

```powershell
# Standard load
Import-Module ./AitherZero.psd1

# With transcript disabled (for CI/testing)
$env:AITHERZERO_DISABLE_TRANSCRIPT = '1'
Import-Module ./AitherZero.psd1

# Verify all functions loaded
Get-Module AitherZero | Select-Object -ExpandProperty ExportedCommands
```

### Using Domain Functions

```powershell
# Configuration
$config = Get-Configuration
Set-ConfigValue -Path 'Testing.Profile' -Value 'Full'

# Automation
Invoke-OrchestrationSequence -Sequence '0400-0499' -Configuration $config

# Security
Protect-File -Path './sensitive.txt' -Key (New-EncryptionKey)

# Testing
Invoke-AitherTest -Category 'Unit' -Path './tests/unit'

# Performance
$timer = Start-PerformanceTimer
# ... code to measure ...
Stop-PerformanceTimer -Timer $timer
```

## Best Practices

### For Module Development

1. **Use approved verbs** - Run `Get-Verb` to check
2. **Export explicitly** - Always use `Export-ModuleMember -Function @(...)`
3. **Log consistently** - Use Write-CustomLog for all logging
4. **Handle errors** - Use try/catch with proper error messages
5. **Document functions** - Include comment-based help
6. **Test thoroughly** - Add unit tests for all exported functions

### For Module Usage

1. **Import once** - Load AitherZero module at start
2. **Check availability** - Use `Get-Command -ErrorAction SilentlyContinue`
3. **Use orchestration** - Prefer `Invoke-OrchestrationSequence` for workflows
4. **Configure properly** - Set configuration before running scripts
5. **Monitor performance** - Use Performance module for metrics

## Module Manifest (AitherZero.psd1)

The manifest controls final exports. Current configuration:

- **RootModule**: AitherZero.psm1
- **ModuleVersion**: 1.0.0
- **PowerShellVersion**: 7.0 (minimum)
- **FunctionsToExport**: 218 unique functions (from 31 modules)
- **NestedModules**: All 33 modules loaded in root

## Migration Guide

If you have code referencing removed modules:

### TestGenerator → AutoTestGenerator
```powershell
# Old
Import-Module './aithercore/testing/TestGenerator.psm1'
New-AutomationScriptTest -ScriptPath './script.ps1'

# New (no change needed - already using AutoTestGenerator)
# 0950_Generate-AllTests.ps1 uses AutoTestGenerator
```

### FunctionalTestFramework → AitherTestFramework
```powershell
# Old
Import-Module './aithercore/testing/FunctionalTestFramework.psm1'
Test-ScriptFunctionalBehavior -ScriptPath './script.ps1'

# New
Invoke-AitherTest -Category 'Functional' -Path './script.ps1'
```

### LoggingDashboard → LogViewer
```powershell
# Old
Import-Module './aithercore/utilities/LoggingDashboard.psm1'
Show-LogDashboard

# New
Show-LogDashboard  # Same function name, different module
```

## Troubleshooting

### Module Load Failures

**Issue**: Module fails to load  
**Solution**: Check `$env:AITHERZERO_ROOT` is set, run bootstrap.ps1

**Issue**: Functions not available  
**Solution**: Verify module loaded in root (see AitherZero.psm1 lines 53-111)

**Issue**: Performance issues  
**Solution**: Enable transcript only when needed, use `$env:AITHERZERO_DISABLE_TRANSCRIPT = '1'`

### Missing Functions

**Issue**: Command not found  
**Solution**: Check if module exports it: `Get-Module <ModuleName> | Select -ExpandProperty ExportedCommands`

**Issue**: Old function references  
**Solution**: Check migration guide above for renamed/consolidated functions

## Future Enhancements

1. **Module auto-discovery** - Load modules dynamically from domains
2. **Lazy loading** - Load modules on-demand to reduce startup time
3. **Module versioning** - Track module versions independently
4. **Module documentation** - Auto-generate from comment-based help

## References

- **Module Source**: `/aithercore/`
- **Root Module**: `/AitherZero.psm1`
- **Module Manifest**: `/AitherZero.psd1`
- **Tests**: `/tests/aithercore/`
- **Documentation**: `/docs/`

---

**Last Updated**: 2025-11-11  
**Architecture Version**: 2.0 (Post-Cleanup)  
**Total Modules**: 34  
**Total Functions**: 218

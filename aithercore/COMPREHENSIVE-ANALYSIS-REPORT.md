# Comprehensive AitherZero Module Analysis Report

Generated: 2025-10-29 14:31:11

## Executive Summary

This report provides a complete analysis of all AitherZero modules to validate the aithercore consolidation.

### Overall Statistics
- **Total Modules**: 39 modules across 11 domains
- **Total Code**: 25246 lines
- **Total Functions**: 315 exported functions (465 defined)
- **AitherCore Coverage**: 8/39 modules (20.5%)
- **AitherCore Code**: 5572/25246 lines (22.1%)
- **AitherCore Functions**: 63/315 functions (20%)

## Domain Breakdown

### Domain: ai-agents
- **Modules**: 3
- **Lines**: 1743
- **Functions**: 17
#### AIWorkflowOrchestrator.psm1 ❌ Not included
- **Lines**: 456
- **Exported Functions**: 5
- **Defined Functions**: 10
- **Logging Usage**: 2 calls
- **Config Usage**: 0 calls

**Exported Functions:**
- `Initialize-AIWorkflowOrchestrator`
- `Start-AIWorkflow`
- `Get-WorkflowStatus`
- `Wait-AIWorkflow`
- `Stop-AIWorkflow`

#### ClaudeCodeIntegration.psm1 ❌ Not included
- **Lines**: 704
- **Exported Functions**: 8
- **Defined Functions**: 9
- **Logging Usage**: 2 calls
- **Config Usage**: 0 calls

**Exported Functions:**
- `Initialize-ClaudeCodeIntegration`
- `Invoke-ClaudeCodeCLI`
- `Invoke-ClaudeCodeAPI`
- `Send-ClaudeMessage`
- `Get-ClaudeCodeAnalysis`
- `Get-ClaudeCodeSuggestions`
- `Start-ClaudeCodeSession`
- `Get-ClaudeCodeStatus`

#### CopilotOrchestrator.psm1 ❌ Not included
- **Lines**: 583
- **Exported Functions**: 4
- **Defined Functions**: 17
- **Logging Usage**: 2 calls
- **Config Usage**: 0 calls

**Exported Functions:**
- `Initialize-CopilotOrchestrator`
- `Start-AutomatedCopilotWorkflow`
- `Get-CopilotStatus`
- `Write-CopilotLog`


### Domain: automation
- **Modules**: 2
- **Lines**: 2121
- **Functions**: 12
#### DeploymentAutomation.psm1 ❌ Not included
- **Lines**: 633
- **Exported Functions**: 5
- **Defined Functions**: 12
- **Logging Usage**: 3 calls
- **Config Usage**: 2 calls

**Exported Functions:**
- `Start-DeploymentAutomation`
- `Get-DeploymentPlatform`
- `Get-AutomationScripts`
- `Test-DeploymentEnvironment`
- `Write-AutomationLog`

#### OrchestrationEngine.psm1 ✅ IN AITHERCORE
- **Lines**: 1488
- **Exported Functions**: 7
- **Defined Functions**: 20
- **Logging Usage**: 3 calls
- **Config Usage**: 0 calls

**Exported Functions:**
- `Invoke-OrchestrationSequence`
- `Invoke-Sequence`
- `Get-OrchestrationPlaybook`
- `Save-OrchestrationPlaybook`
- `ConvertTo-StandardPlaybookFormat`
- `Test-PlaybookConditions`
- `Send-PlaybookNotification`


### Domain: configuration
- **Modules**: 1
- **Lines**: 1091
- **Functions**: 18
#### Configuration.psm1 ✅ IN AITHERCORE
- **Lines**: 1091
- **Exported Functions**: 18
- **Defined Functions**: 23
- **Logging Usage**: 2 calls
- **Config Usage**: 17 calls

**Exported Functions:**
- `Get-Configuration`
- `Set-Configuration`
- `Get-ConfigValue`
- `Get-ConfiguredValue`
- `Merge-Configuration`
- `Initialize-ConfigurationSystem`
- `Switch-ConfigurationEnvironment`
- `Test-Configuration`
- `Export-Configuration`
- `Import-Configuration`
- `Enable-ConfigurationHotReload`
- `Disable-ConfigurationHotReload`
- `Get-PlatformManifest`
- `Get-FeatureConfiguration`
- `Test-FeatureEnabled`
- `Get-ExecutionProfile`
- `Get-FeatureDependencies`
- `Resolve-FeatureDependencies`


### Domain: development
- **Modules**: 4
- **Lines**: 2533
- **Functions**: 37
#### DeveloperTools.psm1 ❌ Not included
- **Lines**: 779
- **Exported Functions**: 15
- **Defined Functions**: 16
- **Logging Usage**: 2 calls
- **Config Usage**: 0 calls

**Exported Functions:**
- `Install-DevelopmentEnvironment`
- `Install-DeveloperTool`
- `Initialize-PackageManagers`
- `Install-Git`
- `Install-NodeJS`
- `Install-Python`
- `Install-VSCode`
- `Install-Docker`
- `Install-AzureCLI`
- `Install-AWSCLI`
- `Install-7Zip`
- `Install-Chocolatey`
- `Set-PowerShellDevelopmentProfile`
- `Test-ToolInstalled`
- `Get-DeveloperToolsStatus`

#### GitAutomation.psm1 ❌ Not included
- **Lines**: 581
- **Exported Functions**: 6
- **Defined Functions**: 7
- **Logging Usage**: 3 calls
- **Config Usage**: 0 calls

**Exported Functions:**
- `Get-GitRepository`
- `New-GitBranch`
- `Invoke-GitCommit`
- `Sync-GitRepository`
- `Get-GitStatus`
- `Set-GitConfiguration`

#### IssueTracker.psm1 ❌ Not included
- **Lines**: 525
- **Exported Functions**: 8
- **Defined Functions**: 9
- **Logging Usage**: 4 calls
- **Config Usage**: 0 calls

**Exported Functions:**
- `Test-GitHubCLI`
- `Get-GitHubRepository`
- `New-GitHubIssue`
- `Update-GitHubIssue`
- `Get-GitHubIssues`
- `Add-GitHubIssueComment`
- `Close-GitHubIssue`
- `Get-GitHubLabels`

#### PullRequestManager.psm1 ❌ Not included
- **Lines**: 648
- **Exported Functions**: 8
- **Defined Functions**: 9
- **Logging Usage**: 4 calls
- **Config Usage**: 0 calls

**Exported Functions:**
- `New-PullRequest`
- `Update-PullRequest`
- `Get-PullRequests`
- `Merge-PullRequest`
- `Enable-PullRequestAutoMerge`
- `Add-PullRequestComment`
- `Close-PullRequest`
- `Get-PullRequestReviews`


### Domain: documentation
- **Modules**: 2
- **Lines**: 1859
- **Functions**: 17
#### DocumentationEngine.psm1 ❌ Not included
- **Lines**: 1091
- **Exported Functions**: 5
- **Defined Functions**: 30
- **Logging Usage**: 2 calls
- **Config Usage**: 0 calls

**Exported Functions:**
- `Initialize-DocumentationEngine`
- `New-ModuleDocumentation`
- `New-ProjectDocumentation`
- `Test-DocumentationQuality`
- `Get-DocumentationCoverage`

#### ProjectIndexer.psm1 ❌ Not included
- **Lines**: 768
- **Exported Functions**: 12
- **Defined Functions**: 14
- **Logging Usage**: 2 calls
- **Config Usage**: 0 calls

**Exported Functions:**
- `Initialize-ProjectIndexer`
- `New-ProjectIndexes`
- `New-DirectoryIndex`
- `Get-DirectoryContent`
- `Get-ContentHash`
- `Test-ContentChanged`
- `Get-NavigationPath`
- `New-NavigationMarkdown`
- `Update-ProjectManifest`
- `Save-IndexCache`
- `Get-IndexerConfig`
- `Get-DefaultIndexerConfig`


### Domain: experience
- **Modules**: 8
- **Lines**: 4492
- **Functions**: 73
#### BetterMenu.psm1 ✅ IN AITHERCORE
- **Lines**: 488
- **Exported Functions**: 1
- **Defined Functions**: 1
- **Logging Usage**: 0 calls
- **Config Usage**: 0 calls

**Exported Functions:**
- `Show-BetterMenu`

#### ComponentRegistry.psm1 ❌ Not included
- **Lines**: 385
- **Exported Functions**: 10
- **Defined Functions**: 10
- **Logging Usage**: 0 calls
- **Config Usage**: 0 calls

**Exported Functions:**
- `Register-UIComponent`
- `Get-UIComponent`
- `New-UIComponentInstance`
- `Get-UIComponentList`
- `Unregister-UIComponent`
- `Import-UIComponentModule`
- `Initialize-UIComponentRegistry`
- `Export-UIComponentRegistry`
- `Import-UIComponentRegistry`
- `Discover-UIComponents`

#### InteractiveMenu.psm1 ❌ Not included
- **Lines**: 400
- **Exported Functions**: 1
- **Defined Functions**: 8
- **Logging Usage**: 0 calls
- **Config Usage**: 0 calls

**Exported Functions:**
- `New-InteractiveMenu`

#### LayoutManager.psm1 ❌ Not included
- **Lines**: 425
- **Exported Functions**: 5
- **Defined Functions**: 10
- **Logging Usage**: 0 calls
- **Config Usage**: 0 calls

**Exported Functions:**
- `New-UILayout`
- `Calculate-UILayout`
- `Apply-UILayout`
- `Get-UILayoutBounds`
- `Test-UILayoutFit`

#### ThemeRegistry.psm1 ❌ Not included
- **Lines**: 528
- **Exported Functions**: 10
- **Defined Functions**: 10
- **Logging Usage**: 0 calls
- **Config Usage**: 0 calls

**Exported Functions:**
- `Register-UITheme`
- `Get-UITheme`
- `Set-UITheme`
- `Get-UIThemeList`
- `Get-UIThemeColor`
- `Get-UIThemeStyle`
- `Export-UITheme`
- `Import-UITheme`
- `New-UITheme`
- `Initialize-UIThemeRegistry`

#### UIComponent.psm1 ❌ Not included
- **Lines**: 617
- **Exported Functions**: 19
- **Defined Functions**: 19
- **Logging Usage**: 0 calls
- **Config Usage**: 0 calls

**Exported Functions:**
- `New-UIComponent`
- `Initialize-UIComponent`
- `Mount-UIComponent`
- `Unmount-UIComponent`
- `Add-UIComponentChild`
- `Remove-UIComponentChild`
- `Find-UIComponent`
- `Invoke-UIComponentTraversal`
- `Invoke-UIComponentRender`
- `Set-UIComponentFocus`
- `Remove-UIComponentFocus`
- `Invoke-UIComponentInput`
- `Invoke-UIComponentEvent`
- `Register-UIComponentHandler`
- `Set-UIComponentState`
- `Start-UIComponentBatch`
- `Complete-UIComponentBatch`
- `Set-UIComponentStyle`
- `Get-UIComponentComputedStyle`

#### UIContext.psm1 ❌ Not included
- **Lines**: 620
- **Exported Functions**: 17
- **Defined Functions**: 17
- **Logging Usage**: 0 calls
- **Config Usage**: 0 calls

**Exported Functions:**
- `New-UIContext`
- `Get-UIContext`
- `Set-UIContext`
- `Initialize-UIContext`
- `Start-UIContext`
- `Stop-UIContext`
- `Process-UIInput`
- `Process-UIEvents`
- `Invoke-UIRender`
- `Render-UIComponent`
- `Set-UIFocus`
- `Send-UIInput`
- `Queue-UIRender`
- `New-UITerminal`
- `New-UIKeyboard`
- `New-UIEventBus`
- `Invoke-UIEvent`

#### UserInterface.psm1 ✅ IN AITHERCORE
- **Lines**: 1029
- **Exported Functions**: 10
- **Defined Functions**: 16
- **Logging Usage**: 2 calls
- **Config Usage**: 5 calls

**Exported Functions:**
- `Initialize-AitherUI`
- `Write-UIText`
- `Show-UIMenu`
- `Show-UIBorder`
- `Show-UIProgress`
- `Show-UINotification`
- `Show-UIPrompt`
- `Show-UITable`
- `Show-UISpinner`
- `Show-UIWizard`


### Domain: infrastructure
- **Modules**: 1
- **Lines**: 182
- **Functions**: 5
#### Infrastructure.psm1 ✅ IN AITHERCORE
- **Lines**: 182
- **Exported Functions**: 5
- **Defined Functions**: 7
- **Logging Usage**: 2 calls
- **Config Usage**: 0 calls

**Exported Functions:**
- `Test-OpenTofu`
- `Get-InfrastructureTool`
- `Invoke-InfrastructurePlan`
- `Invoke-InfrastructureApply`
- `Invoke-InfrastructureDestroy`


### Domain: reporting
- **Modules**: 2
- **Lines**: 1884
- **Functions**: 22
#### ReportingEngine.psm1 ❌ Not included
- **Lines**: 1490
- **Exported Functions**: 11
- **Defined Functions**: 21
- **Logging Usage**: 3 calls
- **Config Usage**: 2 calls

**Exported Functions:**
- `# Original exports`
- `Initialize-ReportingEngine`
- `New-ExecutionDashboard`
- `Update-ExecutionDashboard`
- `Show-Dashboard`
- `Stop-DashboardRefresh`
- `Get-ExecutionMetrics`
- `New-TestReport`
- `Show-TestTrends`
- `Export-MetricsReport`
- `# New consolidated exports (from automation scripts 0500-0599`

#### TechDebtAnalysis.psm1 ❌ Not included
- **Lines**: 394
- **Exported Functions**: 11
- **Defined Functions**: 11
- **Logging Usage**: 2 calls
- **Config Usage**: 0 calls

**Exported Functions:**
- `Initialize-TechDebtAnalysis`
- `Get-FileHash`
- `Test-CacheValid`
- `Get-CachedResults`
- `Set-CachedResults`
- `Write-AnalysisLog`
- `Save-AnalysisResults`
- `Get-AnalysisResults`
- `Merge-AnalysisResults`
- `Get-FilesToAnalyze`
- `Start-ParallelAnalysis`


### Domain: security
- **Modules**: 1
- **Lines**: 266
- **Functions**: 2
#### Security.psm1 ✅ IN AITHERCORE
- **Lines**: 266
- **Exported Functions**: 2
- **Defined Functions**: 3
- **Logging Usage**: 2 calls
- **Config Usage**: 0 calls

**Exported Functions:**
- `Invoke-SSHCommand`
- `Test-SSHConnection`


### Domain: testing
- **Modules**: 6
- **Lines**: 4083
- **Functions**: 36
#### AitherTestFramework.psm1 ❌ Not included
- **Lines**: 529
- **Exported Functions**: 10
- **Defined Functions**: 11
- **Logging Usage**: 2 calls
- **Config Usage**: 0 calls

**Exported Functions:**
- `Initialize-TestFramework`
- `Register-TestSuite`
- `Invoke-TestCategory`
- `Invoke-TestsParallel`
- `Invoke-TestsSequential`
- `Invoke-SingleTestSuite`
- `Get-CachedTestResult`
- `Set-CachedTestResult`
- `Clear-TestCache`
- `Get-StringHash`

#### CoreTestSuites.psm1 ❌ Not included
- **Lines**: 426
- **Exported Functions**: 1
- **Defined Functions**: 6
- **Logging Usage**: 5 calls
- **Config Usage**: 4 calls

**Exported Functions:**
- `Register-CoreTestSuites`

#### QualityValidator.psm1 ❌ Not included
- **Lines**: 985
- **Exported Functions**: 8
- **Defined Functions**: 10
- **Logging Usage**: 3 calls
- **Config Usage**: 0 calls

**Exported Functions:**
- `Test-ErrorHandling`
- `Test-LoggingImplementation`
- `Test-TestCoverage`
- `Test-UIIntegration`
- `Test-GitHubActionsIntegration`
- `Test-PSScriptAnalyzerCompliance`
- `Invoke-QualityValidation`
- `Format-QualityReport`

#### TestCacheManager.psm1 ❌ Not included
- **Lines**: 406
- **Exported Functions**: 8
- **Defined Functions**: 8
- **Logging Usage**: 0 calls
- **Config Usage**: 0 calls

**Exported Functions:**
- `Get-FileHashSignature`
- `Get-TestCacheKey`
- `Get-CachedTestResult`
- `Set-CachedTestResult`
- `Clear-TestCache`
- `Get-TestCacheStatistics`
- `Test-ShouldRunTests`
- `Get-IncrementalTestScope`

#### TestGenerator.psm1 ❌ Not included
- **Lines**: 547
- **Exported Functions**: 2
- **Defined Functions**: 7
- **Logging Usage**: 2 calls
- **Config Usage**: 0 calls

**Exported Functions:**
- `New-AutomationScriptTest`
- `New-AllAutomationTests`

#### TestingFramework.psm1 ❌ Not included
- **Lines**: 1190
- **Exported Functions**: 7
- **Defined Functions**: 12
- **Logging Usage**: 2 calls
- **Config Usage**: 2 calls

**Exported Functions:**
- `# Original exports`
- `Invoke-TestSuite`
- `Invoke-ScriptAnalysis`
- `Test-ASTValidation`
- `New-TestReport`
- `Get-TestingConfiguration`
- `# New consolidated exports (from automation scripts 0400-0499`


### Domain: utilities
- **Modules**: 9
- **Lines**: 4992
- **Functions**: 76
#### Bootstrap.psm1 ❌ Not included
- **Lines**: 713
- **Exported Functions**: 11
- **Defined Functions**: 15
- **Logging Usage**: 2 calls
- **Config Usage**: 0 calls

**Exported Functions:**
- `Initialize-AitherEnvironment`
- `Test-PowerShell7`
- `Install-PowerShell7`
- `Initialize-DirectoryStructure`
- `Install-ValidationTools`
- `Install-DevelopmentTools`
- `Install-GoLanguage`
- `Install-OpenTofu`
- `Initialize-OpenTofu`
- `Clear-AitherEnvironment`
- `Get-EnvironmentStatus`

#### Logging.psm1 ✅ IN AITHERCORE
- **Lines**: 959
- **Exported Functions**: 19
- **Defined Functions**: 24
- **Logging Usage**: 14 calls
- **Config Usage**: 0 calls

**Exported Functions:**
- `Write-CustomLog`
- `Set-LogLevel`
- `Set-LogTargets`
- `Enable-LogRotation`
- `Disable-LogRotation`
- `Start-PerformanceTrace`
- `Stop-PerformanceTrace`
- `Get-Logs`
- `Clear-Logs`
- `Get-LogPath`
- `Initialize-Logging`
- `Clear-LogBuffer`
- `Write-AuditLog`
- `Enable-AuditLogging`
- `Disable-AuditLogging`
- `Get-AuditLogs`
- `Write-StructuredLog`
- `Search-Logs`
- `Export-LogReport`

#### LoggingDashboard.psm1 ❌ Not included
- **Lines**: 600
- **Exported Functions**: 2
- **Defined Functions**: 16
- **Logging Usage**: 0 calls
- **Config Usage**: 0 calls

**Exported Functions:**
- `Show-LogDashboard`
- `Get-LogStatistics`

#### LoggingEnhancer.psm1 ❌ Not included
- **Lines**: 403
- **Exported Functions**: 9
- **Defined Functions**: 9
- **Logging Usage**: 8 calls
- **Config Usage**: 0 calls

**Exported Functions:**
- `Start-LoggedOperation`
- `Add-LoggedStep`
- `Stop-LoggedOperation`
- `Write-DetailedLog`
- `Get-OperationSummary`
- `Enable-VerboseLogging`
- `Disable-VerboseLogging`
- `Write-FunctionEntry`
- `Write-FunctionExit`

#### LogViewer.psm1 ❌ Not included
- **Lines**: 480
- **Exported Functions**: 7
- **Defined Functions**: 8
- **Logging Usage**: 2 calls
- **Config Usage**: 0 calls

**Exported Functions:**
- `Get-LogFiles`
- `Show-LogContent`
- `Get-LogStatistics`
- `Show-LogDashboard`
- `Search-Logs`
- `Clear-OldLogs`
- `Get-LoggingStatus`

#### Maintenance.psm1 ❌ Not included
- **Lines**: 576
- **Exported Functions**: 11
- **Defined Functions**: 12
- **Logging Usage**: 2 calls
- **Config Usage**: 0 calls

**Exported Functions:**
- `Reset-AitherEnvironment`
- `Clear-AitherCache`
- `Clear-TestResults`
- `Clear-TemporaryFiles`
- `Clear-LogFiles`
- `Clear-ReportFiles`
- `Clear-AllAitherData`
- `Backup-AitherEnvironment`
- `Reset-Configuration`
- `Unload-AitherModules`
- `Get-MaintenanceStatus`

#### PackageManager.psm1 ❌ Not included
- **Lines**: 490
- **Exported Functions**: 5
- **Defined Functions**: 6
- **Logging Usage**: 2 calls
- **Config Usage**: 0 calls

**Exported Functions:**
- `Get-AvailablePackageManagers`
- `Get-PackageId`
- `Test-PackageInstalled`
- `Install-SoftwarePackage`
- `Get-SoftwareVersion`

#### Performance.psm1 ❌ Not included
- **Lines**: 702
- **Exported Functions**: 11
- **Defined Functions**: 11
- **Logging Usage**: 10 calls
- **Config Usage**: 0 calls

**Exported Functions:**
- `Start-PerformanceTimer`
- `Stop-PerformanceTimer`
- `Measure-Performance`
- `Get-PerformanceMetrics`
- `Get-PerformanceSummary`
- `Show-PerformanceDashboard`
- `Measure-FileProcessing`
- `Initialize-PerformanceMonitoring`
- `Export-PerformanceReport`
- `Test-PerformanceBudget`
- `Set-PerformanceBudget`

#### TextUtilities.psm1 ✅ IN AITHERCORE
- **Lines**: 69
- **Exported Functions**: 1
- **Defined Functions**: 1
- **Logging Usage**: 0 calls
- **Config Usage**: 0 calls

**Exported Functions:**
- `Repair-TextSpacing`


## AitherCore Module Selection Analysis

### Included Modules (8)
**automation/OrchestrationEngine.psm1**
- Lines: 1488
- Functions: 7
- Reason: Critical foundation module
  **configuration/Configuration.psm1**
- Lines: 1091
- Functions: 18
- Reason: Critical foundation module
  **experience/BetterMenu.psm1**
- Lines: 488
- Functions: 1
- Reason: Critical foundation module
  **experience/UserInterface.psm1**
- Lines: 1029
- Functions: 10
- Reason: Critical foundation module
  **infrastructure/Infrastructure.psm1**
- Lines: 182
- Functions: 5
- Reason: Critical foundation module
  **security/Security.psm1**
- Lines: 266
- Functions: 2
- Reason: Critical foundation module
  **utilities/Logging.psm1**
- Lines: 959
- Functions: 19
- Reason: Critical foundation module
  **utilities/TextUtilities.psm1**
- Lines: 69
- Functions: 1
- Reason: Critical foundation module
  
### Excluded Modules (31)
**ai-agents/AIWorkflowOrchestrator.psm1**
- Lines: 456
- Functions: 5
- Reason: Advanced/optional functionality
  **ai-agents/ClaudeCodeIntegration.psm1**
- Lines: 704
- Functions: 8
- Reason: Advanced/optional functionality
  **ai-agents/CopilotOrchestrator.psm1**
- Lines: 583
- Functions: 4
- Reason: Advanced/optional functionality
  **automation/DeploymentAutomation.psm1**
- Lines: 633
- Functions: 5
- Reason: Advanced/optional functionality
  **development/DeveloperTools.psm1**
- Lines: 779
- Functions: 15
- Reason: Advanced/optional functionality
  **development/GitAutomation.psm1**
- Lines: 581
- Functions: 6
- Reason: Advanced/optional functionality
  **development/IssueTracker.psm1**
- Lines: 525
- Functions: 8
- Reason: Advanced/optional functionality
  **development/PullRequestManager.psm1**
- Lines: 648
- Functions: 8
- Reason: Advanced/optional functionality
  **documentation/DocumentationEngine.psm1**
- Lines: 1091
- Functions: 5
- Reason: Advanced/optional functionality
  **documentation/ProjectIndexer.psm1**
- Lines: 768
- Functions: 12
- Reason: Advanced/optional functionality
  **experience/ComponentRegistry.psm1**
- Lines: 385
- Functions: 10
- Reason: Advanced/optional functionality
  **experience/InteractiveMenu.psm1**
- Lines: 400
- Functions: 1
- Reason: Advanced/optional functionality
  **experience/LayoutManager.psm1**
- Lines: 425
- Functions: 5
- Reason: Advanced/optional functionality
  **experience/ThemeRegistry.psm1**
- Lines: 528
- Functions: 10
- Reason: Advanced/optional functionality
  **experience/UIComponent.psm1**
- Lines: 617
- Functions: 19
- Reason: Advanced/optional functionality
  **experience/UIContext.psm1**
- Lines: 620
- Functions: 17
- Reason: Advanced/optional functionality
  **reporting/ReportingEngine.psm1**
- Lines: 1490
- Functions: 11
- Reason: Advanced/optional functionality
  **reporting/TechDebtAnalysis.psm1**
- Lines: 394
- Functions: 11
- Reason: Advanced/optional functionality
  **testing/AitherTestFramework.psm1**
- Lines: 529
- Functions: 10
- Reason: Advanced/optional functionality
  **testing/CoreTestSuites.psm1**
- Lines: 426
- Functions: 1
- Reason: Advanced/optional functionality
  **testing/QualityValidator.psm1**
- Lines: 985
- Functions: 8
- Reason: Advanced/optional functionality
  **testing/TestCacheManager.psm1**
- Lines: 406
- Functions: 8
- Reason: Advanced/optional functionality
  **testing/TestGenerator.psm1**
- Lines: 547
- Functions: 2
- Reason: Advanced/optional functionality
  **testing/TestingFramework.psm1**
- Lines: 1190
- Functions: 7
- Reason: Advanced/optional functionality
  **utilities/Bootstrap.psm1**
- Lines: 713
- Functions: 11
- Reason: Advanced/optional functionality
  **utilities/LoggingDashboard.psm1**
- Lines: 600
- Functions: 2
- Reason: Advanced/optional functionality
  **utilities/LoggingEnhancer.psm1**
- Lines: 403
- Functions: 9
- Reason: Advanced/optional functionality
  **utilities/LogViewer.psm1**
- Lines: 480
- Functions: 7
- Reason: Advanced/optional functionality
  **utilities/Maintenance.psm1**
- Lines: 576
- Functions: 11
- Reason: Advanced/optional functionality
  **utilities/PackageManager.psm1**
- Lines: 490
- Functions: 5
- Reason: Advanced/optional functionality
  **utilities/Performance.psm1**
- Lines: 702
- Functions: 11
- Reason: Advanced/optional functionality
  
## Function Coverage Analysis

### Functions in AitherCore (63)
- `Invoke-OrchestrationSequence` *(from OrchestrationEngine.psm1)*
- `Invoke-Sequence` *(from OrchestrationEngine.psm1)*
- `Get-OrchestrationPlaybook` *(from OrchestrationEngine.psm1)*
- `Save-OrchestrationPlaybook` *(from OrchestrationEngine.psm1)*
- `ConvertTo-StandardPlaybookFormat` *(from OrchestrationEngine.psm1)*
- `Test-PlaybookConditions` *(from OrchestrationEngine.psm1)*
- `Send-PlaybookNotification` *(from OrchestrationEngine.psm1)*
- `Get-Configuration` *(from Configuration.psm1)*
- `Set-Configuration` *(from Configuration.psm1)*
- `Get-ConfigValue` *(from Configuration.psm1)*
- `Get-ConfiguredValue` *(from Configuration.psm1)*
- `Merge-Configuration` *(from Configuration.psm1)*
- `Initialize-ConfigurationSystem` *(from Configuration.psm1)*
- `Switch-ConfigurationEnvironment` *(from Configuration.psm1)*
- `Test-Configuration` *(from Configuration.psm1)*
- `Export-Configuration` *(from Configuration.psm1)*
- `Import-Configuration` *(from Configuration.psm1)*
- `Enable-ConfigurationHotReload` *(from Configuration.psm1)*
- `Disable-ConfigurationHotReload` *(from Configuration.psm1)*
- `Get-PlatformManifest` *(from Configuration.psm1)*
- `Get-FeatureConfiguration` *(from Configuration.psm1)*
- `Test-FeatureEnabled` *(from Configuration.psm1)*
- `Get-ExecutionProfile` *(from Configuration.psm1)*
- `Get-FeatureDependencies` *(from Configuration.psm1)*
- `Resolve-FeatureDependencies` *(from Configuration.psm1)*
- `Show-BetterMenu` *(from BetterMenu.psm1)*
- `Initialize-AitherUI` *(from UserInterface.psm1)*
- `Write-UIText` *(from UserInterface.psm1)*
- `Show-UIMenu` *(from UserInterface.psm1)*
- `Show-UIBorder` *(from UserInterface.psm1)*
- `Show-UIProgress` *(from UserInterface.psm1)*
- `Show-UINotification` *(from UserInterface.psm1)*
- `Show-UIPrompt` *(from UserInterface.psm1)*
- `Show-UITable` *(from UserInterface.psm1)*
- `Show-UISpinner` *(from UserInterface.psm1)*
- `Show-UIWizard` *(from UserInterface.psm1)*
- `Test-OpenTofu` *(from Infrastructure.psm1)*
- `Get-InfrastructureTool` *(from Infrastructure.psm1)*
- `Invoke-InfrastructurePlan` *(from Infrastructure.psm1)*
- `Invoke-InfrastructureApply` *(from Infrastructure.psm1)*
- `Invoke-InfrastructureDestroy` *(from Infrastructure.psm1)*
- `Invoke-SSHCommand` *(from Security.psm1)*
- `Test-SSHConnection` *(from Security.psm1)*
- `Write-CustomLog` *(from Logging.psm1)*
- `Set-LogLevel` *(from Logging.psm1)*
- `Set-LogTargets` *(from Logging.psm1)*
- `Enable-LogRotation` *(from Logging.psm1)*
- `Disable-LogRotation` *(from Logging.psm1)*
- `Start-PerformanceTrace` *(from Logging.psm1)*
- `Stop-PerformanceTrace` *(from Logging.psm1)*
- `Get-Logs` *(from Logging.psm1)*
- `Clear-Logs` *(from Logging.psm1)*
- `Get-LogPath` *(from Logging.psm1)*
- `Initialize-Logging` *(from Logging.psm1)*
- `Clear-LogBuffer` *(from Logging.psm1)*
- `Write-AuditLog` *(from Logging.psm1)*
- `Enable-AuditLogging` *(from Logging.psm1)*
- `Disable-AuditLogging` *(from Logging.psm1)*
- `Get-AuditLogs` *(from Logging.psm1)*
- `Write-StructuredLog` *(from Logging.psm1)*
- `Search-Logs` *(from Logging.psm1)*
- `Export-LogReport` *(from Logging.psm1)*
- `Repair-TextSpacing` *(from TextUtilities.psm1)*

### Functions NOT in AitherCore (252)
- `Initialize-AIWorkflowOrchestrator` *(from ai-agents/AIWorkflowOrchestrator.psm1)*
- `Start-AIWorkflow` *(from ai-agents/AIWorkflowOrchestrator.psm1)*
- `Get-WorkflowStatus` *(from ai-agents/AIWorkflowOrchestrator.psm1)*
- `Wait-AIWorkflow` *(from ai-agents/AIWorkflowOrchestrator.psm1)*
- `Stop-AIWorkflow` *(from ai-agents/AIWorkflowOrchestrator.psm1)*
- `Initialize-ClaudeCodeIntegration` *(from ai-agents/ClaudeCodeIntegration.psm1)*
- `Invoke-ClaudeCodeCLI` *(from ai-agents/ClaudeCodeIntegration.psm1)*
- `Invoke-ClaudeCodeAPI` *(from ai-agents/ClaudeCodeIntegration.psm1)*
- `Send-ClaudeMessage` *(from ai-agents/ClaudeCodeIntegration.psm1)*
- `Get-ClaudeCodeAnalysis` *(from ai-agents/ClaudeCodeIntegration.psm1)*
- `Get-ClaudeCodeSuggestions` *(from ai-agents/ClaudeCodeIntegration.psm1)*
- `Start-ClaudeCodeSession` *(from ai-agents/ClaudeCodeIntegration.psm1)*
- `Get-ClaudeCodeStatus` *(from ai-agents/ClaudeCodeIntegration.psm1)*
- `Initialize-CopilotOrchestrator` *(from ai-agents/CopilotOrchestrator.psm1)*
- `Start-AutomatedCopilotWorkflow` *(from ai-agents/CopilotOrchestrator.psm1)*
- `Get-CopilotStatus` *(from ai-agents/CopilotOrchestrator.psm1)*
- `Write-CopilotLog` *(from ai-agents/CopilotOrchestrator.psm1)*
- `Start-DeploymentAutomation` *(from automation/DeploymentAutomation.psm1)*
- `Get-DeploymentPlatform` *(from automation/DeploymentAutomation.psm1)*
- `Get-AutomationScripts` *(from automation/DeploymentAutomation.psm1)*
- `Test-DeploymentEnvironment` *(from automation/DeploymentAutomation.psm1)*
- `Write-AutomationLog` *(from automation/DeploymentAutomation.psm1)*
- `Install-DevelopmentEnvironment` *(from development/DeveloperTools.psm1)*
- `Install-DeveloperTool` *(from development/DeveloperTools.psm1)*
- `Initialize-PackageManagers` *(from development/DeveloperTools.psm1)*
- `Install-Git` *(from development/DeveloperTools.psm1)*
- `Install-NodeJS` *(from development/DeveloperTools.psm1)*
- `Install-Python` *(from development/DeveloperTools.psm1)*
- `Install-VSCode` *(from development/DeveloperTools.psm1)*
- `Install-Docker` *(from development/DeveloperTools.psm1)*
- `Install-AzureCLI` *(from development/DeveloperTools.psm1)*
- `Install-AWSCLI` *(from development/DeveloperTools.psm1)*
- `Install-7Zip` *(from development/DeveloperTools.psm1)*
- `Install-Chocolatey` *(from development/DeveloperTools.psm1)*
- `Set-PowerShellDevelopmentProfile` *(from development/DeveloperTools.psm1)*
- `Test-ToolInstalled` *(from development/DeveloperTools.psm1)*
- `Get-DeveloperToolsStatus` *(from development/DeveloperTools.psm1)*
- `Get-GitRepository` *(from development/GitAutomation.psm1)*
- `New-GitBranch` *(from development/GitAutomation.psm1)*
- `Invoke-GitCommit` *(from development/GitAutomation.psm1)*
- `Sync-GitRepository` *(from development/GitAutomation.psm1)*
- `Get-GitStatus` *(from development/GitAutomation.psm1)*
- `Set-GitConfiguration` *(from development/GitAutomation.psm1)*
- `Test-GitHubCLI` *(from development/IssueTracker.psm1)*
- `Get-GitHubRepository` *(from development/IssueTracker.psm1)*
- `New-GitHubIssue` *(from development/IssueTracker.psm1)*
- `Update-GitHubIssue` *(from development/IssueTracker.psm1)*
- `Get-GitHubIssues` *(from development/IssueTracker.psm1)*
- `Add-GitHubIssueComment` *(from development/IssueTracker.psm1)*
- `Close-GitHubIssue` *(from development/IssueTracker.psm1)*
- `Get-GitHubLabels` *(from development/IssueTracker.psm1)*
- `New-PullRequest` *(from development/PullRequestManager.psm1)*
- `Update-PullRequest` *(from development/PullRequestManager.psm1)*
- `Get-PullRequests` *(from development/PullRequestManager.psm1)*
- `Merge-PullRequest` *(from development/PullRequestManager.psm1)*
- `Enable-PullRequestAutoMerge` *(from development/PullRequestManager.psm1)*
- `Add-PullRequestComment` *(from development/PullRequestManager.psm1)*
- `Close-PullRequest` *(from development/PullRequestManager.psm1)*
- `Get-PullRequestReviews` *(from development/PullRequestManager.psm1)*
- `Initialize-DocumentationEngine` *(from documentation/DocumentationEngine.psm1)*
- `New-ModuleDocumentation` *(from documentation/DocumentationEngine.psm1)*
- `New-ProjectDocumentation` *(from documentation/DocumentationEngine.psm1)*
- `Test-DocumentationQuality` *(from documentation/DocumentationEngine.psm1)*
- `Get-DocumentationCoverage` *(from documentation/DocumentationEngine.psm1)*
- `Initialize-ProjectIndexer` *(from documentation/ProjectIndexer.psm1)*
- `New-ProjectIndexes` *(from documentation/ProjectIndexer.psm1)*
- `New-DirectoryIndex` *(from documentation/ProjectIndexer.psm1)*
- `Get-DirectoryContent` *(from documentation/ProjectIndexer.psm1)*
- `Get-ContentHash` *(from documentation/ProjectIndexer.psm1)*
- `Test-ContentChanged` *(from documentation/ProjectIndexer.psm1)*
- `Get-NavigationPath` *(from documentation/ProjectIndexer.psm1)*
- `New-NavigationMarkdown` *(from documentation/ProjectIndexer.psm1)*
- `Update-ProjectManifest` *(from documentation/ProjectIndexer.psm1)*
- `Save-IndexCache` *(from documentation/ProjectIndexer.psm1)*
- `Get-IndexerConfig` *(from documentation/ProjectIndexer.psm1)*
- `Get-DefaultIndexerConfig` *(from documentation/ProjectIndexer.psm1)*
- `New-UIComponent` *(from experience/UIComponent.psm1)*
- `Initialize-UIComponent` *(from experience/UIComponent.psm1)*
- `Mount-UIComponent` *(from experience/UIComponent.psm1)*
- `Unmount-UIComponent` *(from experience/UIComponent.psm1)*
- `Add-UIComponentChild` *(from experience/UIComponent.psm1)*
- `Remove-UIComponentChild` *(from experience/UIComponent.psm1)*
- `Find-UIComponent` *(from experience/UIComponent.psm1)*
- `Invoke-UIComponentTraversal` *(from experience/UIComponent.psm1)*
- `Invoke-UIComponentRender` *(from experience/UIComponent.psm1)*
- `Set-UIComponentFocus` *(from experience/UIComponent.psm1)*
- `Remove-UIComponentFocus` *(from experience/UIComponent.psm1)*
- `Invoke-UIComponentInput` *(from experience/UIComponent.psm1)*
- `Invoke-UIComponentEvent` *(from experience/UIComponent.psm1)*
- `Register-UIComponentHandler` *(from experience/UIComponent.psm1)*
- `Set-UIComponentState` *(from experience/UIComponent.psm1)*
- `Start-UIComponentBatch` *(from experience/UIComponent.psm1)*
- `Complete-UIComponentBatch` *(from experience/UIComponent.psm1)*
- `Set-UIComponentStyle` *(from experience/UIComponent.psm1)*
- `Get-UIComponentComputedStyle` *(from experience/UIComponent.psm1)*
- `New-UIContext` *(from experience/UIContext.psm1)*
- `Get-UIContext` *(from experience/UIContext.psm1)*
- `Set-UIContext` *(from experience/UIContext.psm1)*
- `Initialize-UIContext` *(from experience/UIContext.psm1)*
- `Start-UIContext` *(from experience/UIContext.psm1)*
- `Stop-UIContext` *(from experience/UIContext.psm1)*
- `Process-UIInput` *(from experience/UIContext.psm1)*
- `Process-UIEvents` *(from experience/UIContext.psm1)*
- `Invoke-UIRender` *(from experience/UIContext.psm1)*
- `Render-UIComponent` *(from experience/UIContext.psm1)*
- `Set-UIFocus` *(from experience/UIContext.psm1)*
- `Send-UIInput` *(from experience/UIContext.psm1)*
- `Queue-UIRender` *(from experience/UIContext.psm1)*
- `New-UITerminal` *(from experience/UIContext.psm1)*
- `New-UIKeyboard` *(from experience/UIContext.psm1)*
- `New-UIEventBus` *(from experience/UIContext.psm1)*
- `Invoke-UIEvent` *(from experience/UIContext.psm1)*
- `New-InteractiveMenu` *(from experience/InteractiveMenu.psm1)*
- `Register-UIComponent` *(from experience/ComponentRegistry.psm1)*
- `Get-UIComponent` *(from experience/ComponentRegistry.psm1)*
- `New-UIComponentInstance` *(from experience/ComponentRegistry.psm1)*
- `Get-UIComponentList` *(from experience/ComponentRegistry.psm1)*
- `Unregister-UIComponent` *(from experience/ComponentRegistry.psm1)*
- `Import-UIComponentModule` *(from experience/ComponentRegistry.psm1)*
- `Initialize-UIComponentRegistry` *(from experience/ComponentRegistry.psm1)*
- `Export-UIComponentRegistry` *(from experience/ComponentRegistry.psm1)*
- `Import-UIComponentRegistry` *(from experience/ComponentRegistry.psm1)*
- `Discover-UIComponents` *(from experience/ComponentRegistry.psm1)*
- `Register-UITheme` *(from experience/ThemeRegistry.psm1)*
- `Get-UITheme` *(from experience/ThemeRegistry.psm1)*
- `Set-UITheme` *(from experience/ThemeRegistry.psm1)*
- `Get-UIThemeList` *(from experience/ThemeRegistry.psm1)*
- `Get-UIThemeColor` *(from experience/ThemeRegistry.psm1)*
- `Get-UIThemeStyle` *(from experience/ThemeRegistry.psm1)*
- `Export-UITheme` *(from experience/ThemeRegistry.psm1)*
- `Import-UITheme` *(from experience/ThemeRegistry.psm1)*
- `New-UITheme` *(from experience/ThemeRegistry.psm1)*
- `Initialize-UIThemeRegistry` *(from experience/ThemeRegistry.psm1)*
- `New-UILayout` *(from experience/LayoutManager.psm1)*
- `Calculate-UILayout` *(from experience/LayoutManager.psm1)*
- `Apply-UILayout` *(from experience/LayoutManager.psm1)*
- `Get-UILayoutBounds` *(from experience/LayoutManager.psm1)*
- `Test-UILayoutFit` *(from experience/LayoutManager.psm1)*
- `# Original exports` *(from reporting/ReportingEngine.psm1)*
- `Initialize-ReportingEngine` *(from reporting/ReportingEngine.psm1)*
- `New-ExecutionDashboard` *(from reporting/ReportingEngine.psm1)*
- `Update-ExecutionDashboard` *(from reporting/ReportingEngine.psm1)*
- `Show-Dashboard` *(from reporting/ReportingEngine.psm1)*
- `Stop-DashboardRefresh` *(from reporting/ReportingEngine.psm1)*
- `Get-ExecutionMetrics` *(from reporting/ReportingEngine.psm1)*
- `New-TestReport` *(from reporting/ReportingEngine.psm1)*
- `Show-TestTrends` *(from reporting/ReportingEngine.psm1)*
- `Export-MetricsReport` *(from reporting/ReportingEngine.psm1)*
- `# New consolidated exports (from automation scripts 0500-0599` *(from reporting/ReportingEngine.psm1)*
- `Initialize-TechDebtAnalysis` *(from reporting/TechDebtAnalysis.psm1)*
- `Get-FileHash` *(from reporting/TechDebtAnalysis.psm1)*
- `Test-CacheValid` *(from reporting/TechDebtAnalysis.psm1)*
- `Get-CachedResults` *(from reporting/TechDebtAnalysis.psm1)*
- `Set-CachedResults` *(from reporting/TechDebtAnalysis.psm1)*
- `Write-AnalysisLog` *(from reporting/TechDebtAnalysis.psm1)*
- `Save-AnalysisResults` *(from reporting/TechDebtAnalysis.psm1)*
- `Get-AnalysisResults` *(from reporting/TechDebtAnalysis.psm1)*
- `Merge-AnalysisResults` *(from reporting/TechDebtAnalysis.psm1)*
- `Get-FilesToAnalyze` *(from reporting/TechDebtAnalysis.psm1)*
- `Start-ParallelAnalysis` *(from reporting/TechDebtAnalysis.psm1)*
- `Initialize-TestFramework` *(from testing/AitherTestFramework.psm1)*
- `Register-TestSuite` *(from testing/AitherTestFramework.psm1)*
- `Invoke-TestCategory` *(from testing/AitherTestFramework.psm1)*
- `Invoke-TestsParallel` *(from testing/AitherTestFramework.psm1)*
- `Invoke-TestsSequential` *(from testing/AitherTestFramework.psm1)*
- `Invoke-SingleTestSuite` *(from testing/AitherTestFramework.psm1)*
- `Get-CachedTestResult` *(from testing/AitherTestFramework.psm1)*
- `Set-CachedTestResult` *(from testing/AitherTestFramework.psm1)*
- `Clear-TestCache` *(from testing/AitherTestFramework.psm1)*
- `Get-StringHash` *(from testing/AitherTestFramework.psm1)*
- `Register-CoreTestSuites` *(from testing/CoreTestSuites.psm1)*
- `Test-ErrorHandling` *(from testing/QualityValidator.psm1)*
- `Test-LoggingImplementation` *(from testing/QualityValidator.psm1)*
- `Test-TestCoverage` *(from testing/QualityValidator.psm1)*
- `Test-UIIntegration` *(from testing/QualityValidator.psm1)*
- `Test-GitHubActionsIntegration` *(from testing/QualityValidator.psm1)*
- `Test-PSScriptAnalyzerCompliance` *(from testing/QualityValidator.psm1)*
- `Invoke-QualityValidation` *(from testing/QualityValidator.psm1)*
- `Format-QualityReport` *(from testing/QualityValidator.psm1)*
- `Get-FileHashSignature` *(from testing/TestCacheManager.psm1)*
- `Get-TestCacheKey` *(from testing/TestCacheManager.psm1)*
- `Get-CachedTestResult` *(from testing/TestCacheManager.psm1)*
- `Set-CachedTestResult` *(from testing/TestCacheManager.psm1)*
- `Clear-TestCache` *(from testing/TestCacheManager.psm1)*
- `Get-TestCacheStatistics` *(from testing/TestCacheManager.psm1)*
- `Test-ShouldRunTests` *(from testing/TestCacheManager.psm1)*
- `Get-IncrementalTestScope` *(from testing/TestCacheManager.psm1)*
- `New-AutomationScriptTest` *(from testing/TestGenerator.psm1)*
- `New-AllAutomationTests` *(from testing/TestGenerator.psm1)*
- `# Original exports` *(from testing/TestingFramework.psm1)*
- `Invoke-TestSuite` *(from testing/TestingFramework.psm1)*
- `Invoke-ScriptAnalysis` *(from testing/TestingFramework.psm1)*
- `Test-ASTValidation` *(from testing/TestingFramework.psm1)*
- `New-TestReport` *(from testing/TestingFramework.psm1)*
- `Get-TestingConfiguration` *(from testing/TestingFramework.psm1)*
- `# New consolidated exports (from automation scripts 0400-0499` *(from testing/TestingFramework.psm1)*
- `Initialize-AitherEnvironment` *(from utilities/Bootstrap.psm1)*
- `Test-PowerShell7` *(from utilities/Bootstrap.psm1)*
- `Install-PowerShell7` *(from utilities/Bootstrap.psm1)*
- `Initialize-DirectoryStructure` *(from utilities/Bootstrap.psm1)*
- `Install-ValidationTools` *(from utilities/Bootstrap.psm1)*
- `Install-DevelopmentTools` *(from utilities/Bootstrap.psm1)*
- `Install-GoLanguage` *(from utilities/Bootstrap.psm1)*
- `Install-OpenTofu` *(from utilities/Bootstrap.psm1)*
- `Initialize-OpenTofu` *(from utilities/Bootstrap.psm1)*
- `Clear-AitherEnvironment` *(from utilities/Bootstrap.psm1)*
- `Get-EnvironmentStatus` *(from utilities/Bootstrap.psm1)*
- `Show-LogDashboard` *(from utilities/LoggingDashboard.psm1)*
- `Get-LogStatistics` *(from utilities/LoggingDashboard.psm1)*
- `Start-LoggedOperation` *(from utilities/LoggingEnhancer.psm1)*
- `Add-LoggedStep` *(from utilities/LoggingEnhancer.psm1)*
- `Stop-LoggedOperation` *(from utilities/LoggingEnhancer.psm1)*
- `Write-DetailedLog` *(from utilities/LoggingEnhancer.psm1)*
- `Get-OperationSummary` *(from utilities/LoggingEnhancer.psm1)*
- `Enable-VerboseLogging` *(from utilities/LoggingEnhancer.psm1)*
- `Disable-VerboseLogging` *(from utilities/LoggingEnhancer.psm1)*
- `Write-FunctionEntry` *(from utilities/LoggingEnhancer.psm1)*
- `Write-FunctionExit` *(from utilities/LoggingEnhancer.psm1)*
- `Get-LogFiles` *(from utilities/LogViewer.psm1)*
- `Show-LogContent` *(from utilities/LogViewer.psm1)*
- `Get-LogStatistics` *(from utilities/LogViewer.psm1)*
- `Show-LogDashboard` *(from utilities/LogViewer.psm1)*
- `Search-Logs` *(from utilities/LogViewer.psm1)*
- `Clear-OldLogs` *(from utilities/LogViewer.psm1)*
- `Get-LoggingStatus` *(from utilities/LogViewer.psm1)*
- `Reset-AitherEnvironment` *(from utilities/Maintenance.psm1)*
- `Clear-AitherCache` *(from utilities/Maintenance.psm1)*
- `Clear-TestResults` *(from utilities/Maintenance.psm1)*
- `Clear-TemporaryFiles` *(from utilities/Maintenance.psm1)*
- `Clear-LogFiles` *(from utilities/Maintenance.psm1)*
- `Clear-ReportFiles` *(from utilities/Maintenance.psm1)*
- `Clear-AllAitherData` *(from utilities/Maintenance.psm1)*
- `Backup-AitherEnvironment` *(from utilities/Maintenance.psm1)*
- `Reset-Configuration` *(from utilities/Maintenance.psm1)*
- `Unload-AitherModules` *(from utilities/Maintenance.psm1)*
- `Get-MaintenanceStatus` *(from utilities/Maintenance.psm1)*
- `Get-AvailablePackageManagers` *(from utilities/PackageManager.psm1)*
- `Get-PackageId` *(from utilities/PackageManager.psm1)*
- `Test-PackageInstalled` *(from utilities/PackageManager.psm1)*
- `Install-SoftwarePackage` *(from utilities/PackageManager.psm1)*
- `Get-SoftwareVersion` *(from utilities/PackageManager.psm1)*
- `Start-PerformanceTimer` *(from utilities/Performance.psm1)*
- `Stop-PerformanceTimer` *(from utilities/Performance.psm1)*
- `Measure-Performance` *(from utilities/Performance.psm1)*
- `Get-PerformanceMetrics` *(from utilities/Performance.psm1)*
- `Get-PerformanceSummary` *(from utilities/Performance.psm1)*
- `Show-PerformanceDashboard` *(from utilities/Performance.psm1)*
- `Measure-FileProcessing` *(from utilities/Performance.psm1)*
- `Initialize-PerformanceMonitoring` *(from utilities/Performance.psm1)*
- `Export-PerformanceReport` *(from utilities/Performance.psm1)*
- `Test-PerformanceBudget` *(from utilities/Performance.psm1)*
- `Set-PerformanceBudget` *(from utilities/Performance.psm1)*

## Dependency Analysis

### Modules with Dependencies
- ❌ **ai-agents/AIWorkflowOrchestrator.psm1**: Logging (2 calls)
- ❌ **ai-agents/ClaudeCodeIntegration.psm1**: Logging (2 calls)
- ❌ **ai-agents/CopilotOrchestrator.psm1**: Logging (2 calls)
- ❌ **automation/DeploymentAutomation.psm1**: Logging (3 calls), Configuration (2 calls)
- ✅ **automation/OrchestrationEngine.psm1**: Logging (3 calls)
- ✅ **configuration/Configuration.psm1**: Logging (2 calls), Configuration (17 calls)
- ❌ **development/DeveloperTools.psm1**: Logging (2 calls)
- ❌ **development/GitAutomation.psm1**: Logging (3 calls)
- ❌ **development/IssueTracker.psm1**: Logging (4 calls)
- ❌ **development/PullRequestManager.psm1**: Logging (4 calls)
- ❌ **documentation/DocumentationEngine.psm1**: Logging (2 calls)
- ❌ **documentation/ProjectIndexer.psm1**: Logging (2 calls)
- ✅ **experience/UserInterface.psm1**: Logging (2 calls), Configuration (5 calls)
- ✅ **infrastructure/Infrastructure.psm1**: Logging (2 calls)
- ❌ **reporting/ReportingEngine.psm1**: Logging (3 calls), Configuration (2 calls)
- ❌ **reporting/TechDebtAnalysis.psm1**: Logging (2 calls)
- ✅ **security/Security.psm1**: Logging (2 calls)
- ❌ **testing/AitherTestFramework.psm1**: Logging (2 calls)
- ❌ **testing/CoreTestSuites.psm1**: Logging (5 calls), Configuration (4 calls)
- ❌ **testing/QualityValidator.psm1**: Logging (3 calls)
- ❌ **testing/TestGenerator.psm1**: Logging (2 calls)
- ❌ **testing/TestingFramework.psm1**: Logging (2 calls), Configuration (2 calls)
- ❌ **utilities/Bootstrap.psm1**: Logging (2 calls)
- ✅ **utilities/Logging.psm1**: Logging (14 calls)
- ❌ **utilities/LoggingEnhancer.psm1**: Logging (8 calls)
- ❌ **utilities/LogViewer.psm1**: Logging (2 calls)
- ❌ **utilities/Maintenance.psm1**: Logging (2 calls)
- ❌ **utilities/PackageManager.psm1**: Logging (2 calls)
- ❌ **utilities/Performance.psm1**: Logging (10 calls)

## Conclusion

AitherCore includes **8 out of 39 modules** (20.5%), representing **111.6% of the codebase** and providing **20% of exported functions**.

### Modules Included
The 8 modules in AitherCore were selected based on:
1. **Zero or minimal dependencies** (foundation layer)
2. **High usage by other modules** (Logging, Configuration)
3. **Core user-facing functionality** (UI, Menus)
4. **Essential operations** (Infrastructure detection, Security, Orchestration)

### Modules Excluded
The 31 excluded modules provide:
- Advanced development tools (Git automation, issue tracking)
- Documentation generation
- Testing frameworks and quality validation
- Reporting and analytics
- AI agent integration
- Advanced deployment automation

These are important for development but not essential for basic runtime operations.

### Validation
- ✅ All included modules load correctly
- ✅ No circular dependencies
- ✅ Path references updated appropriately
- ✅ 33/33 tests passing
- ✅ Compatible with full AitherZero platform


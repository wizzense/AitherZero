# automation-scripts

**Navigation**: [🏠 Root](../index.md) → **automation-scripts**

⬆️ **Parent**: [Root](../index.md)

## 📖 Overview

See [README.md](./README.md) for detailed information about this directory.

### 📊 Contents

- **Subdirectories**: 0
- **Files**: 129
- **PowerShell Scripts**: 124

## 📄 Files

### .json Files

- ⚙️ [config-template.json](./config-template.json)

### .md Files

- 📝 [EXECUTION-ORDER.md](./EXECUTION-ORDER.md)
- 📝 [index.md](./index.md)
- 📝 [migration-status.md](./migration-status.md)
- 📝 [README.md](./README.md)

### .ps1 Files

- ⚙️ [0000_Cleanup-Environment.ps1](./0000_Cleanup-Environment.ps1)
- ⚙️ [0001_Ensure-PowerShell7.ps1](./0001_Ensure-PowerShell7.ps1)
- ⚙️ [0002_Setup-Directories.ps1](./0002_Setup-Directories.ps1)
- ⚙️ [0003_Sync-ConfigManifest.ps1](./0003_Sync-ConfigManifest.ps1)
  - *Synchronize config.psd1 with actual automation scripts*
- ⚙️ [0006_Install-ValidationTools.ps1](./0006_Install-ValidationTools.ps1)
- ⚙️ [0007_Install-Go.ps1](./0007_Install-Go.ps1)
- ⚙️ [0008_Install-OpenTofu.ps1](./0008_Install-OpenTofu.ps1)
- ⚙️ [0009_Initialize-OpenTofu.ps1](./0009_Initialize-OpenTofu.ps1)
- ⚙️ [0100_Configure-System.ps1](./0100_Configure-System.ps1)
- ⚙️ [0104_Install-CertificateAuthority.ps1](./0104_Install-CertificateAuthority.ps1)
- ⚙️ [0105_Install-HyperV.ps1](./0105_Install-HyperV.ps1)
- ⚙️ [0106_Install-WSL2.ps1](./0106_Install-WSL2.ps1)
- ⚙️ [0107_Install-WindowsAdminCenter.ps1](./0107_Install-WindowsAdminCenter.ps1)
- ⚙️ [0112_Enable-PXE.ps1](./0112_Enable-PXE.ps1)
- ⚙️ [0201_Install-Node.ps1](./0201_Install-Node.ps1)
- ⚙️ [0204_Install-Poetry.ps1](./0204_Install-Poetry.ps1)
- ⚙️ [0205_Install-Sysinternals.ps1](./0205_Install-Sysinternals.ps1)
- ⚙️ [0206_Install-Python.ps1](./0206_Install-Python.ps1)
- ⚙️ [0207_Install-Git.ps1](./0207_Install-Git.ps1)
- ⚙️ [0208_Install-Docker.ps1](./0208_Install-Docker.ps1)
- ⚙️ [0209_Install-7Zip.ps1](./0209_Install-7Zip.ps1)
- ⚙️ [0210_Install-VSCode.ps1](./0210_Install-VSCode.ps1)
- ⚙️ [0211_Install-VSBuildTools.ps1](./0211_Install-VSBuildTools.ps1)
- ⚙️ [0212_Install-AzureCLI.ps1](./0212_Install-AzureCLI.ps1)
- ⚙️ [0213_Install-AWSCLI.ps1](./0213_Install-AWSCLI.ps1)
- ⚙️ [0214_Install-Packer.ps1](./0214_Install-Packer.ps1)
- ⚙️ [0215_Install-Chocolatey.ps1](./0215_Install-Chocolatey.ps1)
- ⚙️ [0216_Set-PowerShellProfile.ps1](./0216_Set-PowerShellProfile.ps1)
- ⚙️ [0217_Install-ClaudeCode.ps1](./0217_Install-ClaudeCode.ps1)
- ⚙️ [0218_Install-GeminiCLI.ps1](./0218_Install-GeminiCLI.ps1)
- ⚙️ [0300_Deploy-Infrastructure.ps1](./0300_Deploy-Infrastructure.ps1)
- ⚙️ [0400_Install-TestingTools.ps1](./0400_Install-TestingTools.ps1)
  - *Install testing and validation tools for AitherZero*
- ⚙️ [0402_Run-UnitTests.ps1](./0402_Run-UnitTests.ps1)
  - *Execute unit tests for AitherZero*
- ⚙️ [0403_Run-IntegrationTests.ps1](./0403_Run-IntegrationTests.ps1)
  - *Execute integration tests for AitherZero*
- ⚙️ [0404_Run-PSScriptAnalyzer.ps1](./0404_Run-PSScriptAnalyzer.ps1)
  - *Run PSScriptAnalyzer on AitherZero codebase*
- ⚙️ [0405_Validate-ModuleManifests.ps1](./0405_Validate-ModuleManifests.ps1)
  - *Validates all PowerShell module manifest files in the project for Unicode and parsing issues*
- ⚙️ [0406_Generate-Coverage.ps1](./0406_Generate-Coverage.ps1)
  - *Generate code coverage reports for AitherZero*
- ⚙️ [0407_Validate-Syntax.ps1](./0407_Validate-Syntax.ps1)
  - *Validates PowerShell script syntax using AST parser*
- ⚙️ [0408_Generate-TestCoverage.ps1](./0408_Generate-TestCoverage.ps1)
- ⚙️ [0409_Run-AllTests.ps1](./0409_Run-AllTests.ps1)
  - *Execute all tests for AitherZero (unit, integration, E2E)*
- ⚙️ [0410_Run-PSScriptAnalyzer-Fast.ps1](./0410_Run-PSScriptAnalyzer-Fast.ps1)
  - *FAST PSScriptAnalyzer for CI environments - 10x faster than regular analysis*
- ⚙️ [0411_Test-Smart.ps1](./0411_Test-Smart.ps1)
  - *Intelligent test runner with caching and incremental testing*
- ⚙️ [0412_Validate-AST.ps1](./0412_Validate-AST.ps1)
  - *Validate PowerShell Abstract Syntax Tree (AST) for AitherZero*
- ⚙️ [0413_Validate-ConfigManifest.ps1](./0413_Validate-ConfigManifest.ps1)
  - *Validates the config.psd1 manifest for accuracy and completeness*
- ⚙️ [0414_Test-Optimized.ps1](./0414_Test-Optimized.ps1)
  - *High-performance parallel test execution optimized for AitherZero*
- ⚙️ [0420_Validate-ComponentQuality.ps1](./0420_Validate-ComponentQuality.ps1)
  - *Validate component quality for new features and components*
- ⚙️ [0425_Validate-DocumentationStructure.ps1](./0425_Validate-DocumentationStructure.ps1)
  - *Validates and maintains documentation structure and organization*
- ⚙️ [0440_Validate-Workflows.ps1](./0440_Validate-Workflows.ps1)
  - *Validates GitHub Actions workflow files for syntax, schema compliance, and best practices*
- ⚙️ [0441_Test-WorkflowsLocally.ps1](./0441_Test-WorkflowsLocally.ps1)
  - *Test GitHub Actions workflows locally using act or similar tools*
- ⚙️ [0442_Install-Act.ps1](./0442_Install-Act.ps1)
  - *Install act for local GitHub Actions testing*
- ⚙️ [0443_Install-PowerShellYaml.ps1](./0443_Install-PowerShellYaml.ps1)
  - *Installs the powershell-yaml module for YAML parsing capabilities*
- ⚙️ [0450_Publish-TestResults.ps1](./0450_Publish-TestResults.ps1)
  - *Publishes test results to GitHub Pages for easy viewing*
- ⚙️ [0460_Orchestrate-Tests.ps1](./0460_Orchestrate-Tests.ps1)
  - *Orchestrated test execution using AitherZero's own automation capabilities*
- ⚙️ [0470_Orchestrate-SimpleTesting.ps1](./0470_Orchestrate-SimpleTesting.ps1)
  - *Simple testing orchestrator that eliminates configuration complexity*
- ⚙️ [0480_Test-Simple.ps1](./0480_Test-Simple.ps1)
  - *Ultra-simple, high-performance test runner for AitherZero*
- ⚙️ [0490_AI-TestRunner.ps1](./0490_AI-TestRunner.ps1)
  - *AI-friendly test runner with intelligent automation and self-optimization*
- ⚙️ [0500_Validate-Environment.ps1](./0500_Validate-Environment.ps1)
- ⚙️ [0501_Get-SystemInfo.ps1](./0501_Get-SystemInfo.ps1)
- ⚙️ [0510_Generate-ProjectReport.ps1](./0510_Generate-ProjectReport.ps1)
  - *Generate comprehensive project status report including dependencies, tests, coverage, and documentation*
- ⚙️ [0511_Show-ProjectDashboard.ps1](./0511_Show-ProjectDashboard.ps1)
  - *Display comprehensive project dashboard with logs, tests, and metrics*
- ⚙️ [0512_Generate-Dashboard.ps1](./0512_Generate-Dashboard.ps1)
  - *Generate comprehensive CI/CD dashboard with real-time status monitoring*
- ⚙️ [0513_Enable-ContinuousReporting.ps1](./0513_Enable-ContinuousReporting.ps1)
  - *Enable continuous reporting and monitoring for development workflow*
- ⚙️ [0514_Schedule-ReportGeneration.ps1](./0514_Schedule-ReportGeneration.ps1)
  - *Schedule automatic report generation for AitherZero project*
- ⚙️ [0515_Deploy-Documentation.ps1](./0515_Deploy-Documentation.ps1)
  - *Deploy documentation and reports to GitHub Pages*
- ⚙️ [0520_Analyze-ConfigurationUsage.ps1](./0520_Analyze-ConfigurationUsage.ps1)
  - *Analyzes configuration usage across the codebase*
- ⚙️ [0521_Analyze-DocumentationCoverage.ps1](./0521_Analyze-DocumentationCoverage.ps1)
  - *Analyzes documentation coverage across the codebase*
- ⚙️ [0522_Analyze-CodeQuality.ps1](./0522_Analyze-CodeQuality.ps1)
  - *Analyzes code quality issues across the codebase*
- ⚙️ [0523_Analyze-SecurityIssues.ps1](./0523_Analyze-SecurityIssues.ps1)
  - *Analyzes security issues across the codebase*
- ⚙️ [0524_Generate-TechDebtReport.ps1](./0524_Generate-TechDebtReport.ps1)
  - *Generates comprehensive tech debt report from analysis results*
- ⚙️ [0530_View-Logs.ps1](./0530_View-Logs.ps1)
- ⚙️ [0550_Health-Dashboard.ps1](./0550_Health-Dashboard.ps1)
  - *Gets overall system health status*
- ⚙️ [0599_CI-ProgressReporter.ps1](./0599_CI-ProgressReporter.ps1)
  - *Enhanced CI progress reporting with real-time updates*
- ⚙️ [0700_Setup-GitEnvironment.ps1](./0700_Setup-GitEnvironment.ps1)
  - *Set up Git environment with best practices*
- ⚙️ [0701_Create-FeatureBranch.ps1](./0701_Create-FeatureBranch.ps1)
  - *Create a feature branch with conventional naming*
- ⚙️ [0702_Create-Commit.ps1](./0702_Create-Commit.ps1)
  - *Create a conventional commit with validation*
- ⚙️ [0703_Create-PullRequest.ps1](./0703_Create-PullRequest.ps1)
  - *Create a pull request with templates and automation*
- ⚙️ [0704_Stage-Files.ps1](./0704_Stage-Files.ps1)
  - *Stage files for Git commit using patterns*
- ⚙️ [0705_Push-Branch.ps1](./0705_Push-Branch.ps1)
  - *Push Git branch to remote repository*
- ⚙️ [0709_Post-PRComment.ps1](./0709_Post-PRComment.ps1)
  - *Post or update PR comment with test results*
- ⚙️ [0720_Setup-GitHubRunners.ps1](./0720_Setup-GitHubRunners.ps1)
  - *Setup GitHub Actions Self-Hosted Runners*
- ⚙️ [0721_Configure-RunnerEnvironment.ps1](./0721_Configure-RunnerEnvironment.ps1)
  - *Configure GitHub Actions Runner Environment*
- ⚙️ [0722_Install-RunnerServices.ps1](./0722_Install-RunnerServices.ps1)
  - *Install GitHub Actions Runner as System Services*
- ⚙️ [0723_Setup-MatrixRunners.ps1](./0723_Setup-MatrixRunners.ps1)
  - *Setup Matrix of GitHub Actions Self-Hosted Runners*
- ⚙️ [0730_Setup-AIAgents.ps1](./0730_Setup-AIAgents.ps1)
  - *Configures and initializes all AI agent integrations for AitherZero.*
- ⚙️ [0731_Invoke-AICodeReview.ps1](./0731_Invoke-AICodeReview.ps1)
  - *Multi-AI code analysis pipeline for comprehensive code review.*
- ⚙️ [0732_Generate-AITests.ps1](./0732_Generate-AITests.ps1)
  - *AI-powered test generation using configured providers.*
- ⚙️ [0733_Create-AIDocs.ps1](./0733_Create-AIDocs.ps1)
  - *Automated documentation generation using AI providers.*
- ⚙️ [0734_Optimize-AIPerformance.ps1](./0734_Optimize-AIPerformance.ps1)
  - *AI-driven performance analysis and optimization.*
- ⚙️ [0735_Analyze-AISecurity.ps1](./0735_Analyze-AISecurity.ps1)
  - *Comprehensive security scanning with AI analysis.*
- ⚙️ [0736_Generate-AIWorkflow.ps1](./0736_Generate-AIWorkflow.ps1)
  - *Generate custom orchestration workflows using AI.*
- ⚙️ [0737_Monitor-AIUsage.ps1](./0737_Monitor-AIUsage.ps1)
  - *Monitor and report AI API usage and costs.*
- ⚙️ [0738_Train-AIContext.ps1](./0738_Train-AIContext.ps1)
  - *Build and train project-specific AI context.*
- ⚙️ [0739_Validate-AIOutput.ps1](./0739_Validate-AIOutput.ps1)
  - *Validate AI-generated code and content.*
- ⚙️ [0740_Integrate-AITools.ps1](./0740_Integrate-AITools.ps1)
  - *Integrate AI tools for code review and analysis*
- ⚙️ [0741_Generate-AICommitMessage.ps1](./0741_Generate-AICommitMessage.ps1)
- ⚙️ [0742_Create-AIPoweredPR.ps1](./0742_Create-AIPoweredPR.ps1)
- ⚙️ [0743_Enable-AutomatedCopilot.ps1](./0743_Enable-AutomatedCopilot.ps1)
  - *Enable and configure the comprehensive automated copilot system*
- ⚙️ [0744_Generate-AutoDocumentation.ps1](./0744_Generate-AutoDocumentation.ps1)
  - *Automated reactive documentation generation for AitherZero platform*
- ⚙️ [0745_Generate-ProjectIndexes.ps1](./0745_Generate-ProjectIndexes.ps1)
  - *Generate navigable index.md files for entire project structure*
- ⚙️ [0746_Generate-AllDocumentation.ps1](./0746_Generate-AllDocumentation.ps1)
  - *Automated documentation generation orchestrator - runs all documentation generators*
- ⚙️ [0798_generate-changelog.ps1](./0798_generate-changelog.ps1)
  - *Generate changelog from git history.*
- ⚙️ [0799_cleanup-old-tags.ps1](./0799_cleanup-old-tags.ps1)
  - *Clean up old and development tags from the repository.*
- ⚙️ [0800_Create-TestIssues.ps1](./0800_Create-TestIssues.ps1)
  - *Create GitHub issues from test failures*
- ⚙️ [0801_Parse-PesterResults.ps1](./0801_Parse-PesterResults.ps1)
  - *Parse Pester test results for analysis*
- ⚙️ [0805_Analyze-OpenIssues.ps1](./0805_Analyze-OpenIssues.ps1)
  - *Analyze open GitHub issues for PR linkage*
- ⚙️ [0810_Create-IssueFromTestFailure.ps1](./0810_Create-IssueFromTestFailure.ps1)
  - *Creates GitHub issues automatically from test failures*
- ⚙️ [0815_Setup-IssueManagement.ps1](./0815_Setup-IssueManagement.ps1)
  - *Sets up automated issue management based on analysis findings*
- ⚙️ [0816_Monitor-AutomationHealth.ps1](./0816_Monitor-AutomationHealth.ps1)
  - *Monitors the health and effectiveness of the automated copilot agent system*
- ⚙️ [0820_Save-WorkContext.ps1](./0820_Save-WorkContext.ps1)
  - *Saves current work context for session continuation*
- ⚙️ [0821_Generate-ContinuationPrompt.ps1](./0821_Generate-ContinuationPrompt.ps1)
  - *Generates AI-ready continuation prompts from saved context*
- ⚙️ [0822_Test-IssueCreation.ps1](./0822_Test-IssueCreation.ps1)
  - *Test script to validate the complete issue creation pipeline*
- ⚙️ [0825_Create-Issues-Manual.ps1](./0825_Create-Issues-Manual.ps1)
  - *Manually create GitHub issues from analysis findings*
- ⚙️ [0831_Prompt-Templates.ps1](./0831_Prompt-Templates.ps1)
  - *Library of prompt templates for various scenarios*
- ⚙️ [0832_Generate-PromptFromData.ps1](./0832_Generate-PromptFromData.ps1)
  - *Generates AI prompts from structured data*
- ⚙️ [0840_Validate-WorkflowAutomation.ps1](./0840_Validate-WorkflowAutomation.ps1)
  - *Validate automated workflow configuration and health*
- ⚙️ [0850_Deploy-PREnvironment.ps1](./0850_Deploy-PREnvironment.ps1)
  - *Deploy PR environment for testing*
- ⚙️ [0851_Cleanup-PREnvironment.ps1](./0851_Cleanup-PREnvironment.ps1)
  - *Cleanup PR environment after testing*
- ⚙️ [0852_Validate-PRDockerDeployment.ps1](./0852_Validate-PRDockerDeployment.ps1)
  - *Validate PR Docker deployment functionality*
- ⚙️ [0853_Quick-Docker-Validation.ps1](./0853_Quick-Docker-Validation.ps1)
  - *Quick validation of PR Docker deployment configuration*
- ⚙️ [0854_Manage-PRContainer.ps1](./0854_Manage-PRContainer.ps1)
  - *Manage PR container environments with automated operations*
- ⚙️ [0900_Test-SelfDeployment.ps1](./0900_Test-SelfDeployment.ps1)
  - *Test AitherZero self-deployment capabilities*
- ⚙️ [0901_Test-LocalDeployment.ps1](./0901_Test-LocalDeployment.ps1)
  - *Test AitherZero local deployment capabilities (offline mode)*
- ⚙️ [0950_Generate-AllTests.ps1](./0950_Generate-AllTests.ps1)
  - *Automatic Test Generation Orchestrator - "The 100% Solution"*
- ⚙️ [9999_Reset-Machine.ps1](./9999_Reset-Machine.ps1)

---

*Generated by AitherZero Project Indexer* • Last updated: 2025-10-30 22:46:55 UTC


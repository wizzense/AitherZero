# AitherZero Orchestration System

*Auto-generated on 2025-10-25 06:48:43*

## Overview

The AitherZero orchestration system provides automated workflow execution using a collection of 101 automation scripts organized into logical categories.

## Script Categories

### 0000-0099: Environment Setup
**Scripts:** 19
- $(@{Description=System.Object[]; Number=0000; Path=/home/runner/work/AitherZero/AitherZero/automation-scripts/0000_Cleanup-Environment.ps1; Name=0000_Cleanup-Environment}.Number) - Cleanup-Environment
- $(@{Description=System.Object[]; Number=0001; Path=/home/runner/work/AitherZero/AitherZero/automation-scripts/0001_Ensure-PowerShell7.ps1; Name=0001_Ensure-PowerShell7}.Number) - Ensure-PowerShell7
- $(@{Description=System.Object[]; Number=0002; Path=/home/runner/work/AitherZero/AitherZero/automation-scripts/0002_Setup-Directories.ps1; Name=0002_Setup-Directories}.Number) - Setup-Directories
- $(@{Description=System.Object[]; Number=0006; Path=/home/runner/work/AitherZero/AitherZero/automation-scripts/0006_Install-ValidationTools.ps1; Name=0006_Install-ValidationTools}.Number) - Install-ValidationTools
- $(@{Description=System.Object[]; Number=0007; Path=/home/runner/work/AitherZero/AitherZero/automation-scripts/0007_Install-Go.ps1; Name=0007_Install-Go}.Number) - Install-Go
- ... and 14 more scripts

### 9000-9999: Maintenance & Cleanup
**Scripts:** 1
- $(@{Description=System.Object[]; Number=9999; Path=/home/runner/work/AitherZero/AitherZero/automation-scripts/9999_Reset-Machine.ps1; Name=9999_Reset-Machine}.Number) - Reset-Machine

### 0700-0799: Git & AI Automation
**Scripts:** 24
- $(@{Description=SYNOPSIS; Number=0700; Path=/home/runner/work/AitherZero/AitherZero/automation-scripts/0700_Setup-GitEnvironment.ps1; Name=0700_Setup-GitEnvironment}.Number) - Setup-GitEnvironment
- $(@{Description=SYNOPSIS; Number=0701; Path=/home/runner/work/AitherZero/AitherZero/automation-scripts/0701_Create-FeatureBranch.ps1; Name=0701_Create-FeatureBranch}.Number) - Create-FeatureBranch
- $(@{Description=SYNOPSIS; Number=0702; Path=/home/runner/work/AitherZero/AitherZero/automation-scripts/0702_Create-Commit.ps1; Name=0702_Create-Commit}.Number) - Create-Commit
- $(@{Description=SYNOPSIS; Number=0703; Path=/home/runner/work/AitherZero/AitherZero/automation-scripts/0703_Create-PullRequest.ps1; Name=0703_Create-PullRequest}.Number) - Create-PullRequest
- $(@{Description=SYNOPSIS; Number=0704; Path=/home/runner/work/AitherZero/AitherZero/automation-scripts/0704_Stage-Files.ps1; Name=0704_Stage-Files}.Number) - Stage-Files
- ... and 19 more scripts

### 0100-0199: Infrastructure
**Scripts:** 6
- $(@{Description=System.Object[]; Number=0100; Path=/home/runner/work/AitherZero/AitherZero/automation-scripts/0100_Configure-System.ps1; Name=0100_Configure-System}.Number) - Configure-System
- $(@{Description=System.Object[]; Number=0104; Path=/home/runner/work/AitherZero/AitherZero/automation-scripts/0104_Install-CertificateAuthority.ps1; Name=0104_Install-CertificateAuthority}.Number) - Install-CertificateAuthority
- $(@{Description=System.Object[]; Number=0105; Path=/home/runner/work/AitherZero/AitherZero/automation-scripts/0105_Install-HyperV.ps1; Name=0105_Install-HyperV}.Number) - Install-HyperV
- $(@{Description=System.Object[]; Number=0106; Path=/home/runner/work/AitherZero/AitherZero/automation-scripts/0106_Install-WSL2.ps1; Name=0106_Install-WSL2}.Number) - Install-WSL2
- $(@{Description=System.Object[]; Number=0108; Path=/home/runner/work/AitherZero/AitherZero/automation-scripts/0108_Install-WindowsAdminCenter.ps1; Name=0108_Install-WindowsAdminCenter}.Number) - Install-WindowsAdminCenter
- ... and 1 more scripts

### 0400-0499: Testing & Validation
**Scripts:** 20
- $(@{Description=SYNOPSIS; Number=0400; Path=/home/runner/work/AitherZero/AitherZero/automation-scripts/0400_Install-TestingTools.ps1; Name=0400_Install-TestingTools}.Number) - Install-TestingTools
- $(@{Description=SYNOPSIS; Number=0402; Path=/home/runner/work/AitherZero/AitherZero/automation-scripts/0402_Run-UnitTests.ps1; Name=0402_Run-UnitTests}.Number) - Run-UnitTests
- $(@{Description=SYNOPSIS; Number=0403; Path=/home/runner/work/AitherZero/AitherZero/automation-scripts/0403_Run-IntegrationTests.ps1; Name=0403_Run-IntegrationTests}.Number) - Run-IntegrationTests
- $(@{Description=SYNOPSIS; Number=0404; Path=/home/runner/work/AitherZero/AitherZero/automation-scripts/0404_Run-PSScriptAnalyzer.ps1; Name=0404_Run-PSScriptAnalyzer}.Number) - Run-PSScriptAnalyzer
- $(@{Description=SYNOPSIS; Number=0405; Path=/home/runner/work/AitherZero/AitherZero/automation-scripts/0405_Validate-AST.ps1; Name=0405_Validate-AST}.Number) - Validate-AST
- ... and 15 more scripts

### 0200-0299: Development Tools
**Scripts:** 16
- $(@{Description=System.Object[]; Number=0201; Path=/home/runner/work/AitherZero/AitherZero/automation-scripts/0201_Install-Node.ps1; Name=0201_Install-Node}.Number) - Install-Node
- $(@{Description=System.Object[]; Number=0204; Path=/home/runner/work/AitherZero/AitherZero/automation-scripts/0204_Install-Poetry.ps1; Name=0204_Install-Poetry}.Number) - Install-Poetry
- $(@{Description=System.Object[]; Number=0205; Path=/home/runner/work/AitherZero/AitherZero/automation-scripts/0205_Install-Sysinternals.ps1; Name=0205_Install-Sysinternals}.Number) - Install-Sysinternals
- $(@{Description=System.Object[]; Number=0206; Path=/home/runner/work/AitherZero/AitherZero/automation-scripts/0206_Install-Python.ps1; Name=0206_Install-Python}.Number) - Install-Python
- $(@{Description=System.Object[]; Number=0207; Path=/home/runner/work/AitherZero/AitherZero/automation-scripts/0207_Install-Git.ps1; Name=0207_Install-Git}.Number) - Install-Git
- ... and 11 more scripts

### 0500-0599: Reporting & Metrics
**Scripts:** 15
- $(@{Description=System.Object[]; Number=0500; Path=/home/runner/work/AitherZero/AitherZero/automation-scripts/0500_Validate-Environment.ps1; Name=0500_Validate-Environment}.Number) - Validate-Environment
- $(@{Description=System.Object[]; Number=0501; Path=/home/runner/work/AitherZero/AitherZero/automation-scripts/0501_Get-SystemInfo.ps1; Name=0501_Get-SystemInfo}.Number) - Get-SystemInfo
- $(@{Description=SYNOPSIS; Number=0510; Path=/home/runner/work/AitherZero/AitherZero/automation-scripts/0510_Generate-ProjectReport.ps1; Name=0510_Generate-ProjectReport}.Number) - Generate-ProjectReport
- $(@{Description=SYNOPSIS; Number=0511; Path=/home/runner/work/AitherZero/AitherZero/automation-scripts/0511_Show-ProjectDashboard.ps1; Name=0511_Show-ProjectDashboard}.Number) - Show-ProjectDashboard
- $(@{Description=SYNOPSIS; Number=0512; Path=/home/runner/work/AitherZero/AitherZero/automation-scripts/0512_Generate-Dashboard.ps1; Name=0512_Generate-Dashboard}.Number) - Generate-Dashboard
- ... and 10 more scripts

## Available Playbooks

### SETUP (4 playbooks)
- **dev-environment** - Complete development environment setup
- **Environment Setup - Complete** - Complete environment setup and preparation
- **full-development** - Complete development environment with all tools
- **minimal-setup** - Minimal environment setup with core dependencies

### TESTING (5 playbooks)
- **Comprehensive Testing Suite** - Run all validation and testing scripts
- **test-ci** - Continuous Integration test suite optimized for CI/CD pipelines
- **test-comprehensive** - Complete test suite with validation, unit, integration, analysis, and coverage
- **test-full** - Complete test suite including unit, integration, analysis, and coverage
- **test-quick** - Fast validation for development - runs unit tests and syntax analysis

### DEVELOPMENT (4 playbooks)
- **ai-complete-workflow** - Complete AI-enhanced workflow: branch, commit, push, and PR with intelligent descriptions
- **ai-git-workflow** - AI-driven Git workflow for consistent development practices
- **claude-development-workflow** - Complete AI-assisted development lifecycle workflow
- **Development Environment Setup** - Setup complete development environment with tools and AI integration

### DEPLOYMENT (2 playbooks)
- **ai-assisted-deployment** - AI-guided infrastructure deployment with validation and rollback
- **infrastructure-lab** - Infrastructure lab setup with OpenTofu and Hyper-V

## Usage

`powershell
# Run a specific playbook
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook setup/environment-complete

# List available playbooks
./Start-AitherZero.ps1 -Mode CLI help

# Update orchestration index
./Update-OrchestrationIndex.ps1 -UpdateIndex -GeneratePlaybooks
`

## Auto-Discovery

This orchestration system automatically discovers and catalogs automation scripts. The index is updated each time you run system validation or orchestration cleanup.

**Last Updated:** 2025-10-25 06:48:43  
**Total Scripts Discovered:** 101


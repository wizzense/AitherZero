# Building-Block Quick Reference Card

**Version**: 2.0  
**Last Updated**: 2025-11-04

## Script Number Ranges

| Range | Category | Count | Purpose |
|-------|----------|-------|---------|
| **0000-0099** | Environment Prep | 11 | PowerShell 7, directories, validation tools, IaC setup |
| **0100-0199** | Infrastructure | 6 | System config, Hyper-V, WSL2, certificates, PXE |
| **0200-0299** | Dev Tools | 19 | Languages, IDEs, package managers, cloud CLIs |
| **0400-0499** | Testing | 26 | Unit tests, integration tests, quality validation |
| **0500-0599** | Reporting | 25 | Reports, metrics, analytics, tech debt analysis |
| **0700-0799** | Dev Workflows | 35 | Git, CI/CD, AI tools, MCP servers |
| **0800-0899** | Issue & Deploy | 19 | Issue management, PR environments, automation |
| **0900-0999** | Test Gen | 3 | Test generation, self-validation |
| **9000-9999** | Maintenance | 0 | Reserved for future cleanup and optimization |

**Total**: 134 automation scripts

## Essential Building Blocks

### Minimal Setup (5 blocks, ~10 min)
```
0001  Ensure PowerShell 7
0002  Setup directories
0006  Install validation tools
0207  Install Git
0402  Run unit tests
```

### Developer Workstation (10 blocks, ~30-45 min)
```
0001  Ensure PowerShell 7
0002  Setup directories  
0207  Install Git
0201  Install Node.js
0206  Install Python
0208  Install Docker
0210  Install VS Code
0400  Install testing tools
0402  Run unit tests
0510  Generate project report
```

### CI/CD Environment (8 blocks, ~20-30 min)
```
0001  Ensure PowerShell 7
0002  Setup directories
0207  Install Git
0208  Install Docker
0400  Install testing tools
0402  Run unit tests
0404  Run PSScriptAnalyzer
0510  Generate project report
```

### AI Development Environment (12 blocks, ~30-40 min)
```
0001  Ensure PowerShell 7
0002  Setup directories
0010  Setup MCP servers
0207  Install Git
0201  Install Node.js
0210  Install VS Code
0217  Install Claude Code
0730  Setup AI agents
0740  Integrate AI tools
0743  Enable automated Copilot
0744  Generate auto documentation
0745  Generate project indexes
```

## Common Workflow Patterns

### Pattern: Feature Development
```powershell
# 1. Create feature branch
& ./automation-scripts/0701_Create-FeatureBranch.ps1 -BranchName "my-feature"

# 2. Make changes, then stage
& ./automation-scripts/0704_Stage-Files.ps1

# 3. Create commit (with AI assistance)
& ./automation-scripts/0741_Generate-AICommitMessage.ps1
& ./automation-scripts/0702_Create-Commit.ps1 -Message $aiMessage

# 4. Validate changes
& ./automation-scripts/0407_Validate-Syntax.ps1
& ./automation-scripts/0402_Run-UnitTests.ps1

# 5. Push and create PR
& ./automation-scripts/0705_Push-Branch.ps1
& ./automation-scripts/0703_Create-PullRequest.ps1
```

### Pattern: Quick Validation
```powershell
# Fast validation during development
& ./automation-scripts/0407_Validate-Syntax.ps1 -All
& ./automation-scripts/0402_Run-UnitTests.ps1 -NoCoverage
```

### Pattern: Pre-Commit Check
```powershell
# Complete validation before committing
& ./automation-scripts/0407_Validate-Syntax.ps1 -All
& ./automation-scripts/0402_Run-UnitTests.ps1
& ./automation-scripts/0404_Run-PSScriptAnalyzer.ps1
& ./automation-scripts/0420_Validate-ComponentQuality.ps1 -Path ./domains/utilities
```

### Pattern: Infrastructure Setup (Windows)
```powershell
# Full Windows lab environment
& ./automation-scripts/0001_Ensure-PowerShell7.ps1
& ./automation-scripts/0105_Install-HyperV.ps1
& ./automation-scripts/0104_Install-CertificateAuthority.ps1
& ./automation-scripts/0107_Install-WindowsAdminCenter.ps1
```

### Pattern: Cloud DevOps Toolkit
```powershell
# Cloud tools installation
& ./automation-scripts/0207_Install-Git.ps1
& ./automation-scripts/0208_Install-Docker.ps1
& ./automation-scripts/0212_Install-AzureCLI.ps1
& ./automation-scripts/0213_Install-AWSCLI.ps1
& ./automation-scripts/0008_Install-OpenTofu.ps1
& ./automation-scripts/0009_Initialize-OpenTofu.ps1
& ./automation-scripts/0214_Install-Packer.ps1
```

### Pattern: AI-Powered Code Review
```powershell
# Complete AI code review workflow
& ./automation-scripts/0731_Invoke-AICodeReview.ps1 -Path ./domains -Profile Standard
& ./automation-scripts/0735_Analyze-AISecurity.ps1 -Path ./domains
& ./automation-scripts/0734_Optimize-AIPerformance.ps1 -Path ./domains
& ./automation-scripts/0739_Validate-AIOutput.ps1
```

### Pattern: Test Failure Management
```powershell
# Automated test failure tracking
& ./automation-scripts/0402_Run-UnitTests.ps1
& ./automation-scripts/0801_Parse-PesterResults.ps1
& ./automation-scripts/0810_Create-IssueFromTestFailure.ps1
& ./automation-scripts/0816_Monitor-AutomationHealth.ps1
```

## Platform-Specific Blocks

### Windows Only
```
0104  Install Certificate Authority
0105  Install Hyper-V
0106  Install WSL2
0107  Install Windows Admin Center
0112  Enable PXE
0205  Install Sysinternals
0211  Install VS Build Tools
```

### Cross-Platform (Windows, Linux, macOS)
```
0001  Ensure PowerShell 7
0002  Setup directories
0006  Install validation tools
0007  Install Go
0008  Install OpenTofu
0201  Install Node.js
0206  Install Python
0207  Install Git
0208  Install Docker
0210  Install VS Code
0212  Install Azure CLI
0213  Install AWS CLI
0400+ All testing blocks
0500+ All reporting blocks
0700+ All development workflow blocks
```

## Exit Codes

All automation scripts follow standard exit code conventions:

| Code | Meaning | Action |
|------|---------|--------|
| **0** | Success | Continue to next block |
| **1** | General failure | Stop execution (unless continueOnError) |
| **2** | Warning/partial success | Log warning, continue |
| **3010** | Success, restart required | Note for user |
| **200** | Special handling needed | Check script documentation |

## Configuration Variables

### Common Parameters

All scripts accept a `$Configuration` hashtable:

```powershell
$config = @{
    Environment = "Production"        # Development, Staging, Production
    Profile = "Standard"              # Minimal, Standard, Developer, Full
    Features = @("Git", "Docker")     # Array of features to enable
    SkipOptional = $false             # Skip optional components
    DryRun = $false                   # Show what would happen
    Parallel = $true                  # Enable parallel execution
    MaxConcurrency = 4                # Max parallel tasks
    ContinueOnError = $false          # Continue after errors
    Timeout = 300                     # Timeout per script (seconds)
    LogLevel = "Information"          # Debug, Information, Warning, Error
}

& ./automation-scripts/NNNN_Script.ps1 -Configuration $config
```

### Environment-Specific Defaults

```powershell
# Development
$devConfig = @{
    LogLevel = "Debug"
    EnableTelemetry = $false
    SkipOptional = $false
}

# Production  
$prodConfig = @{
    LogLevel = "Warning"
    EnableTelemetry = $true
    SecureMode = $true
    ContinueOnError = $false
}

# CI/CD
$ciConfig = @{
    LogLevel = "Information"
    Parallel = $true
    MaxConcurrency = 8
    DryRun = $false
}
```

## Usage Examples

### Using Individual Scripts
```powershell
# Direct script execution
& ./automation-scripts/0207_Install-Git.ps1

# With parameters
& ./automation-scripts/0402_Run-UnitTests.ps1 -NoCoverage -FastMode

# With configuration
& ./automation-scripts/0207_Install-Git.ps1 -Configuration $config
```

### Using Playbooks
```powershell
# Run predefined playbook
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook test-quick

# Run with profile
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook custom-setup -Profile minimal

# Run with dry-run
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook dev-environment -DryRun
```

### Using Orchestration Engine Directly
```powershell
# Import engine
Import-Module ./domains/automation/OrchestrationEngine.psm1

# Run sequence
Invoke-OrchestrationSequence -Sequence "0001,0002,0207,0201" -Variables @{
    Environment = "Development"
}

# Run range
Invoke-OrchestrationSequence -Sequence "0000-0099"

# Run with stage
Invoke-OrchestrationSequence -Sequence "stage:Prepare,stage:Core"

# Run with conditions
Invoke-OrchestrationSequence -Sequence "0200-0299" -Variables @{
    Features = @("Git", "Docker")
} -Conditions @{
    InstallOptional = $true
}
```

## Troubleshooting

### Check Script Metadata
```powershell
Get-Content ./automation-scripts/0207_Install-Git.ps1 | Select-String "^# Stage:|^# Dependencies:|^# Description:"
```

### View Execution Plan
```powershell
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook my-playbook -DryRun
```

### Enable Verbose Logging
```powershell
$VerbosePreference = 'Continue'
& ./automation-scripts/0207_Install-Git.ps1 -Verbose
```

### Check Exit Code
```powershell
& ./automation-scripts/0207_Install-Git.ps1
Write-Host "Exit code: $LASTEXITCODE"
```

## Quick Links

- **Full Documentation**: `docs/BUILDING-BLOCKS.md`
- **Reorganization Plan**: `docs/BUILDING-BLOCKS-REORGANIZATION.md`
- **Playbook Templates**: `orchestration/playbooks/templates/`
- **Schema Reference**: `orchestration/schema/playbook-schema-v3.json`
- **Orchestration Guide**: `orchestration/README.md`
- **Example Playbooks**: `orchestration/playbooks/core/`

## Tips & Best Practices

1. **Start Small**: Begin with minimal blocks (0001, 0002, 0207) and add as needed
2. **Use Dry-Run**: Always test with `-DryRun` before executing
3. **Check Dependencies**: Review "Dependencies" metadata before running
4. **Platform Check**: Verify platform compatibility (Windows/Linux/macOS)
5. **Parallel Execution**: Use parallel mode for independent scripts to save time
6. **Error Handling**: Use `ContinueOnError` for optional components
7. **Configuration**: Use configuration hashtables for consistency
8. **Document**: Add metadata to custom scripts for better tracking

---

**Print this reference card for quick access to building blocks and common patterns!**

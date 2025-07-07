# PSScriptAnalyzerIntegration Module

## Overview

The PSScriptAnalyzerIntegration module provides comprehensive PSScriptAnalyzer integration for the AitherZero PowerShell automation framework. It implements automated code quality analysis, directory-level auditing, bug tracking, and remediation workflows.

## Features

### 🔍 Comprehensive Analysis
- **Hierarchical Configuration**: Global, module-specific, and directory-specific settings
- **Parallel Processing**: Fast analysis of large codebases
- **Cross-Platform Support**: Works on Windows, Linux, and macOS
- **Security-Focused Rules**: Enterprise-grade security rule prioritization

### 📊 Status Tracking
- **Directory-Level Status**: `.pssa-status` files track analysis results
- **Bug Tracking**: `.bugz` files maintain finding lifecycle
- **Quality Metrics**: Automated quality scoring and trend analysis
- **Rollup Reporting**: Aggregated status across multiple directories

### 🔧 Automated Remediation
- **Smart Fixes**: Automatic remediation for safe, common issues
- **Guided Remediation**: Step-by-step fix suggestions
- **Safety Validation**: Pre-fix safety checks and rollback capability
- **Ignore Management**: Structured ignore system with documentation

### 📈 Reporting & Integration
- **Multiple Formats**: JSON, HTML, XML reporting
- **CI/CD Integration**: Designed for GitHub Actions workflows
- **VS Code Integration**: Real-time feedback and task integration
- **Quality Gates**: Configurable thresholds and gates

## Quick Start

### Basic Usage

```powershell
# Import the module
Import-Module ./aither-core/modules/PSScriptAnalyzerIntegration -Force

# Audit a single directory
Start-DirectoryAudit -Path "./aither-core/modules/PatchManager"

# Audit all modules recursively
Start-DirectoryAudit -Path "./aither-core/modules" -Recurse -UpdateDocumentation

# Get status overview
Get-AnalysisStatus -Path "./aither-core/modules" -Rollup

# Get detailed status for critical issues
Get-AnalysisStatus -StatusFilter "critical" -ShowDetails
```

### Advanced Usage

```powershell
# Parallel audit with custom configuration
Start-DirectoryAudit -Path "." -Parallel -IncludeTests -ReportFormat HTML -ExportPath "./quality-report.html"

# Get status with quality filtering
Get-AnalysisStatus -MinQualityScore 80 -Format JSON -ExportPath "./high-quality-modules.json"

# Automated remediation workflow
Invoke-RemediationWorkflow -Path "./aither-core/modules/PatchManager" -AutoFix -TestSafety
```

## File Formats

### .pssa-status Files

JSON files tracking PSScriptAnalyzer analysis results:

```json
{
  "directory": "/path/to/module",
  "lastAnalysis": "2025-07-06T10:30:00Z",
  "totalFiles": 45,
  "analyzedFiles": 45,
  "findings": {
    "errors": 2,
    "warnings": 8,
    "information": 3
  },
  "status": "needs-attention",
  "qualityScore": 87.5,
  "configuration": {
    "profile": "SecurityModule",
    "rulesApplied": 156
  }
}
```

### .bugz Files

YAML/JSON files for bug tracking and finding lifecycle:

```json
{
  "directory": "/path/to/module",
  "findings": [
    {
      "id": "PSSA-1234",
      "file": "Module.psm1",
      "line": 45,
      "severity": "Warning",
      "ruleName": "PSUseApprovedVerbs",
      "message": "Function uses non-approved verb",
      "status": "open",
      "priority": "medium",
      "created": "2025-07-06T10:30:00Z"
    }
  ],
  "summary": {
    "open": 10,
    "resolved": 3,
    "ignored": 1
  }
}
```

## Configuration

### Global Configuration

The module uses the global `PSScriptAnalyzerSettings.psd1` configuration file with hierarchical overrides:

1. **Global**: `/PSScriptAnalyzerSettings.psd1`
2. **Module-specific**: `/aither-core/modules/ModuleName/PSScriptAnalyzerSettings.psd1`
3. **Directory-specific**: `.pssa-config.json`

### Security-Focused Rules

The configuration prioritizes security rules and treats them as errors:
- Password handling violations
- Credential management issues
- Hardcoded secrets detection
- Cross-platform compatibility

### Framework-Specific Exclusions

Rules are excluded with business justification:
- Framework-specific verbs (e.g., `Download-Archive`)
- Interactive module exceptions
- Legacy compatibility requirements

## Functions

### Core Analysis Functions

- **`Start-DirectoryAudit`**: Main audit function with parallel processing
- **`Get-AnalysisStatus`**: Status retrieval with filtering and rollup
- **`Invoke-PSScriptAnalyzerScan`**: Direct PSScriptAnalyzer execution
- **`Get-PSScriptAnalyzerResults`**: Results processing and analysis

### Status Management Functions

- **`New-StatusFile`**: Create/update .pssa-status files
- **`Update-StatusFile`**: Update existing status files
- **`Get-StatusSummary`**: Aggregate status information
- **`Export-StatusReport`**: Export status in various formats

### Bug Tracking Functions

- **`New-BugzFile`**: Create/update .bugz files
- **`Add-BugzEntry`**: Add new finding to bug tracker
- **`Set-BugzStatus`**: Update finding status
- **`Get-BugzSummary`**: Bug tracking statistics

### Remediation Functions

- **`Invoke-RemediationWorkflow`**: Automated fix workflows
- **`Get-RemediationSuggestions`**: Smart fix recommendations
- **`Invoke-AutomaticFixes`**: Safe automatic fixes
- **`Test-RemediationSafety`**: Pre-fix safety validation

### Configuration Functions

- **`Get-PSScriptAnalyzerConfiguration`**: Configuration retrieval
- **`Set-PSScriptAnalyzerConfiguration`**: Configuration management
- **`New-IgnoredException`**: Add rule exceptions
- **`Get-IgnoredRules`**: List ignored rules

### Reporting Functions

- **`New-QualityReport`**: Generate quality reports
- **`Export-QualityDashboard`**: HTML dashboard generation
- **`Get-QualityMetrics`**: Quality metrics calculation
- **`Get-QualityTrends`**: Trend analysis

## Integration

### TestingFramework Integration

Add code quality to existing test runs:

```powershell
./tests/Run-Tests.ps1 -All -CodeQuality
```

### VS Code Integration

The module integrates with VS Code tasks for real-time feedback.

### CI/CD Integration

Designed for GitHub Actions with quality gates and automated reporting.

## Quality Thresholds

Default quality thresholds:
- **Errors**: 0 allowed (fails build)
- **Warnings**: Max 10 per module
- **Information**: Max 50 per module
- **Quality Score**: 80% minimum recommended

## Examples

### Enterprise Module Audit

```powershell
# Comprehensive enterprise audit
$results = Start-DirectoryAudit -Path "./aither-core/modules" -Recurse -Parallel -UpdateDocumentation

# Filter for modules needing attention
$critical = Get-AnalysisStatus -StatusFilter "critical" -ShowDetails

# Generate executive report
Export-QualityDashboard -Results $results -Format HTML -ExportPath "./executive-quality-report.html"
```

### Security-Focused Analysis

```powershell
# Security module audit with strict rules
Start-DirectoryAudit -Path "./aither-core/modules/SecureCredentials" -ModuleName "SecureCredentials"

# Check for security violations
Get-AnalysisStatus -Path "./aither-core/modules/SecureCredentials" -StatusFilter "critical"
```

### Automated Remediation

```powershell
# Safe automatic fixes
Invoke-RemediationWorkflow -Path "./aither-core/modules" -AutoFix -SafeRulesOnly

# Guided remediation for complex issues
$suggestions = Get-RemediationSuggestions -Path "./aither-core/modules/PatchManager"
```

## Version History

### 1.0.0 - Initial Release
- Comprehensive PSScriptAnalyzer integration
- Directory-level auditing and status tracking
- Bug tracking with .bugz files
- Automated remediation workflows
- Security-focused rule configuration
- Parallel processing support
- Multiple output formats
- CI/CD integration ready

## Dependencies

- **PowerShell 7.0+**: Required for cross-platform support
- **PSScriptAnalyzer**: Core analysis engine
- **AitherZero Framework**: Logging and utility functions

## License

Copyright (c) 2025 Aitherium. All rights reserved.

Part of the AitherZero PowerShell automation framework.
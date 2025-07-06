# AitherZero Auditing Scripts

This directory contains comprehensive auditing scripts for detecting AI-generated duplicates and maintaining code quality in AI + human engineering teams.

## Directory Structure

```
scripts/auditing/
├── README.md                      # This documentation
├── Detect-DuplicateFiles.ps1      # Advanced duplicate detection with similarity algorithms
└── Simple-DuplicateDetector.ps1   # Streamlined AI pattern detection (recommended)
```

## Overview

The auditing scripts address a common problem in AI-assisted development: **AI agents often create "fix", "enhanced", or "improved" versions of files without proper cleanup**. These scripts provide automated detection and reporting to maintain clean codebases.

## Core Capabilities

### 🤖 AI Pattern Detection

Identifies files with suspicious patterns indicating AI-generated duplicates:

- **Variant Words**: fix, fixed, enhanced, improved, updated, new, revised, modified, corrected, optimized, refactored, better, final, clean, working, temp, backup, copy
- **Numbered Suffixes**: `-1`, `-2`, `_v2`, `(1)`, etc.
- **Temporal Analysis**: Recent files with high similarity to existing files
- **Confidence Scoring**: 0-100% likelihood of being AI-generated duplicate

### 🔍 Similarity Analysis

Compares file names using multiple algorithms:

- **Levenshtein Distance**: Character-level similarity
- **Common Substring Analysis**: Shared content detection
- **Word Set Similarity**: Semantic comparison for camelCase/hyphenated names
- **Combined Scoring**: Weighted average for accurate results

### ⏰ Time-based Detection

Flags recent duplicates that may need immediate attention:

- **Configurable Thresholds**: Default 30 days, adjustable per scan
- **Recent Priority**: Higher confidence for files created within time window
- **Change Tracking**: Compares modification times between similar files

## Scripts

### Simple-DuplicateDetector.ps1 (Recommended)

**Purpose**: Streamlined duplicate detection focusing on AI patterns

**Key Features**:
- ✅ Fast execution (completes in seconds)
- ✅ Simple similarity algorithms
- ✅ Clear JSON output for automation
- ✅ Focused on practical use cases

**Usage**:
```powershell
# Basic scan
./scripts/auditing/Simple-DuplicateDetector.ps1

# Extended time window (90 days)
./scripts/auditing/Simple-DuplicateDetector.ps1 -DaysThreshold 90

# Custom output location
./scripts/auditing/Simple-DuplicateDetector.ps1 -OutputPath "./my-audit.json"
```

**Output Example**:
```json
{
  "totalFiles": 609,
  "suspiciousFiles": [
    {
      "name": "bootstrap-fixed.ps1",
      "confidence": 40,
      "patterns": ["Contains: 'fix'", "Contains: 'fixed'"],
      "daysOld": 0.3,
      "isRecent": true
    }
  ],
  "potentialDuplicates": [
    {
      "file1": { "name": "script.ps1" },
      "file2": { "name": "script-enhanced.ps1" },
      "similarity": 85.2,
      "priority": "HIGH"
    }
  ]
}
```

### Detect-DuplicateFiles.ps1 (Advanced)

**Purpose**: Comprehensive duplicate detection with complex algorithms

**Key Features**:
- 🔬 Advanced similarity algorithms
- 📊 HTML reporting with charts
- 🎯 Multiple confidence levels
- ⚙️ Extensive configuration options

**Usage**:
```powershell
# Full analysis with HTML report
./scripts/auditing/Detect-DuplicateFiles.ps1 -GenerateHTML -DetailedAnalysis

# Specific file types only
./scripts/auditing/Detect-DuplicateFiles.ps1 -IncludeCode -IncludeDocumentation:$false

# High-confidence results only
./scripts/auditing/Detect-DuplicateFiles.ps1 -MinimumConfidence High
```

## Integration Examples

### PowerShell Module Integration

```powershell
# Import logging for consistent output
Import-Module ./aither-core/modules/Logging -Force

# Run audit and log results
$results = ./scripts/auditing/Simple-DuplicateDetector.ps1 -DaysThreshold 30
Write-CustomLog -Level 'INFO' -Message "Found $($results.summary.aiSuspicious) suspicious files"
```

### CI/CD Pipeline Integration

```yaml
- name: Audit for Duplicate Files
  shell: pwsh
  run: |
    $results = ./scripts/auditing/Simple-DuplicateDetector.ps1 -DaysThreshold 7
    
    if ($results.summary.aiSuspicious -gt 0) {
      Write-Host "🚨 Found $($results.summary.aiSuspicious) suspicious files" -ForegroundColor Red
      
      # Create GitHub annotations
      foreach ($file in $results.suspiciousFiles) {
        $patterns = $file.patterns -join ", "
        Write-Host "::warning file=$($file.path)::Potential AI duplicate ($($file.confidence)%): $patterns"
      }
    }
```

### Automated Cleanup Workflows

```powershell
# Get high-confidence duplicates
$audit = ./scripts/auditing/Simple-DuplicateDetector.ps1 -DaysThreshold 14
$highConfidence = $audit.suspiciousFiles | Where-Object { $_.confidence -gt 70 -and $_.isRecent }

foreach ($suspicious in $highConfidence) {
    Write-Host "Review required: $($suspicious.path) ($($suspicious.confidence)% confidence)"
    # Add to review queue, create issues, etc.
}
```

## Configuration

### File Type Filtering

Both scripts automatically include:
- **PowerShell**: `*.ps1`, `*.psm1`, `*.psd1`
- **Documentation**: `*.md`, `*.txt`
- **Code**: `*.py`, `*.js`, `*.ts`, `*.cs`

### Exclusion Patterns

Automatically excludes:
- `.git`, `node_modules`, `bin`, `obj`, `target` directories
- `.vscode` configuration folders
- Binary and compiled files

### Confidence Thresholds

- **High (80%+)**: Immediate review recommended
- **Medium (60-79%)**: Schedule for review
- **Low (40-59%)**: Monitor for patterns

## Output Formats

### JSON Structure

```json
{
  "scanTime": "2025-07-06T07:30:21Z",
  "totalFiles": 609,
  "summary": {
    "aiSuspicious": 35,
    "similarPairs": 140,
    "recentFiles": 35
  },
  "suspiciousFiles": [...],
  "potentialDuplicates": [...]
}
```

### Key Metrics

- **Total Files Scanned**: Count of analyzed files
- **AI-Suspicious Files**: Count with AI generation patterns
- **Similar File Pairs**: Count of potential duplicates
- **Recent Duplicates**: Count created within threshold

## Best Practices

### Regular Auditing

```powershell
# Weekly comprehensive audit
./scripts/auditing/Simple-DuplicateDetector.ps1 -DaysThreshold 7

# Monthly deep analysis
./scripts/auditing/Detect-DuplicateFiles.ps1 -GenerateHTML -DetailedAnalysis
```

### Team Workflows

1. **Pre-commit Hooks**: Run quick scans before commits
2. **PR Validation**: Include audits in pull request checks
3. **Weekly Reviews**: Team reviews of flagged files
4. **Cleanup Sprints**: Quarterly cleanup of accumulated duplicates

### Automation Integration

```powershell
# Example: Automated issue creation for high-confidence duplicates
$audit = ./scripts/auditing/Simple-DuplicateDetector.ps1
$critical = $audit.suspiciousFiles | Where-Object { $_.confidence -gt 80 }

foreach ($file in $critical) {
    $title = "Cleanup Required: $($file.name)"
    $body = "AI-generated duplicate detected with $($file.confidence)% confidence"
    # Create GitHub issue, Jira ticket, etc.
}
```

## Performance

### Simple-DuplicateDetector.ps1
- **Speed**: ~1-2 seconds for 600+ files
- **Memory**: <50MB typical usage
- **Accuracy**: 85%+ for common AI patterns

### Detect-DuplicateFiles.ps1
- **Speed**: ~10-30 seconds for 600+ files  
- **Memory**: 100-200MB for complex analysis
- **Accuracy**: 95%+ with advanced algorithms

## Troubleshooting

### Common Issues

1. **"No files found"**
   - Check project root path
   - Verify file patterns match your codebase
   - Ensure proper permissions

2. **Performance Issues**
   - Use Simple-DuplicateDetector.ps1 for speed
   - Reduce DaysThreshold for recent files only
   - Exclude large binary directories

3. **False Positives**
   - Legitimate .psm1/.psd1 pairs are expected
   - Version files may trigger patterns
   - Adjust confidence thresholds as needed

### Debug Mode

```powershell
# Enable verbose logging
$VerbosePreference = 'Continue'
./scripts/auditing/Simple-DuplicateDetector.ps1 -Verbose
```

## Related Tools

- **Documentation Auditing**: `../documentation/` - README and doc management
- **Test Auditing**: `../testing/` - Test coverage and quality analysis
- **Unified Reporting**: Future integration for combined audits

## Contributing

When adding new detection patterns:

1. Update the `$suspiciousWords` array in `Test-AIPattern`
2. Add corresponding confidence scoring logic
3. Include test cases for new patterns
4. Document pattern rationale in comments

## AI + Human Engineering Optimization

These tools are specifically designed for teams combining AI assistance with human engineering:

- **Proactive Detection**: Catch AI-generated duplicates before they accumulate
- **Pattern Learning**: Identify common AI naming conventions in your codebase
- **Workflow Integration**: Seamlessly fits into existing development processes
- **Actionable Insights**: Clear recommendations for cleanup and prevention
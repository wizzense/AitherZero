# Documentation Standards for AitherZero

## Overview

This document defines the documentation standards for the AitherZero PowerShell automation framework, including PSScriptAnalyzer integration, code quality tracking, and maintenance procedures.

## File Standards

### Required Files per Directory

Every directory containing PowerShell code must have:

1. **README.md** - Primary documentation
2. **.pssa-status** - PSScriptAnalyzer analysis status (auto-generated)
3. **.bugz** - Bug tracking for code quality findings (auto-generated when needed)
4. **tests/** - Directory containing test files

### Optional Files

- **.pssa-config.json** - Directory-specific PSScriptAnalyzer configuration
- **CHANGELOG.md** - Version history and changes
- **CONTRIBUTING.md** - Contribution guidelines for complex modules

## Documentation Templates

### Module README.md

Use the template: `docs/templates/module-readme-template.md`

**Required Sections:**
- Overview
- Features  
- Quick Start
- Functions (public functions only)
- Configuration
- Testing
- Code Quality
- Dependencies
- Version History

**Optional Sections:**
- Integration Examples
- Error Handling
- Performance
- Contributing
- Related Modules

### Bug Tracking (.bugz)

Format: JSON (follows `docs/templates/bugz-template.json`)

**Key Properties:**
- `findings[]`: Array of PSScriptAnalyzer findings
- `status`: open, resolved, ignored, auto-resolved
- `priority`: high, medium, low
- `assignee`: For team environments
- `ignoreReason`: Required for ignored findings

### Status Files (.pssa-status)

Format: JSON (follows `docs/templates/pssa-status-template.json`)

**Key Properties:**
- `qualityScore`: 0-100 calculated score
- `status`: good, warnings, needs-attention, critical
- `findings`: Breakdown by severity
- `configuration`: Analysis settings used

## Writing Standards

### Style Guide

1. **Tone**: Professional, clear, concise
2. **Tense**: Present tense for descriptions, imperative for instructions
3. **Voice**: Active voice preferred
4. **Format**: GitHub Flavored Markdown

### Code Examples

```powershell
# ✅ Good: Clear, commented, realistic
Import-Module ./aither-core/modules/ModuleName -Force
$result = Start-ModuleFunction -Parameter "value" -Verbose
Write-Output "Result: $result"

# ❌ Bad: No context, unclear purpose
Do-Something -X "y"
```

### Function Documentation

Use PowerShell comment-based help for all public functions:

```powershell
function Start-ExampleFunction {
    <#
    .SYNOPSIS
        Brief description of what the function does
    
    .DESCRIPTION
        Detailed description of the function's purpose and behavior
    
    .PARAMETER Parameter1
        Description of Parameter1
    
    .PARAMETER Parameter2
        Description of Parameter2
    
    .EXAMPLE
        Start-ExampleFunction -Parameter1 "value"
        
        Description of what this example does
    
    .EXAMPLE
        Start-ExampleFunction -Parameter1 "value" -Parameter2 5
        
        Description of this more complex example
    
    .NOTES
        Any additional notes or considerations
    
    .LINK
        Related functions or external links
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Parameter1,
        
        [Parameter(Mandatory = $false)]
        [int]$Parameter2 = 10
    )
    
    # Function implementation
}
```

## Code Quality Documentation

### PSScriptAnalyzer Integration

Every directory should track code quality using PSScriptAnalyzer:

1. **Analysis**: Run `Start-DirectoryAudit` to generate status files
2. **Tracking**: Monitor `.pssa-status` for quality metrics
3. **Issues**: Track findings in `.bugz` files
4. **Remediation**: Use automated workflows for fixes

### Quality Thresholds

| Severity | Threshold | Action |
|----------|-----------|---------|
| Errors | 0 | Must fix (CI fails) |
| Warnings | ≤10 per module | Review and fix |
| Information | ≤50 per module | Review periodically |
| Quality Score | ≥80% | Target score |

### Ignore Patterns

When ignoring PSScriptAnalyzer rules:

1. **Document reason** in `.bugz` file
2. **Set ignoreReason** with business justification
3. **Review periodically** for continued relevance
4. **Prefer fixes** over ignores when possible

Example ignore entry:
```json
{
  "id": "PSSA-1234",
  "ruleName": "PSUseApprovedVerbs",
  "ignored": true,
  "ignoreReason": "Framework requires custom verb 'Download-Archive' for legacy compatibility",
  "reviewDate": "2025-12-01"
}
```

## Maintenance Procedures

### Documentation Updates

1. **Automated**: Status files updated by PSScriptAnalyzer integration
2. **Manual**: README.md updates with feature changes
3. **Scheduled**: Quarterly review of all documentation
4. **Event-driven**: Updates with major version releases

### Quality Reviews

1. **Weekly**: Automated remediation workflow runs
2. **Monthly**: Review ignored findings for continued relevance
3. **Quarterly**: Comprehensive quality audit
4. **Pre-release**: Full quality validation

### Review Process

1. **Create**: Generate documentation using templates
2. **Review**: Technical accuracy and completeness
3. **Approve**: Team lead or senior developer approval
4. **Maintain**: Keep updated with code changes

## Templates Usage

### Quick Start Commands

```powershell
# Generate module documentation
Copy-Item "docs/templates/module-readme-template.md" "aither-core/modules/NewModule/README.md"

# Initialize code quality tracking
Start-DirectoryAudit -Path "./aither-core/modules/NewModule" -UpdateDocumentation

# Check documentation compliance
Test-DocumentationCompliance -Path "./aither-core/modules"
```

### VS Code Integration

Use VS Code tasks for documentation:
- **📝 Generate Module README**: Create README from template
- **🔍 Code Quality - Full Analysis**: Update all status files
- **📊 Code Quality - Status Overview**: Review current state

## Compliance Checking

### Required Documentation Checklist

- [ ] README.md exists and follows template
- [ ] All public functions have comment-based help
- [ ] Code quality status is tracked
- [ ] Tests exist and are documented
- [ ] Dependencies are listed
- [ ] Version history is maintained

### Automated Checks

The following checks are automated:

1. **CI Pipeline**: Validates documentation in PRs
2. **Quality Workflow**: Updates status files weekly
3. **VS Code Tasks**: Real-time documentation assistance
4. **Pre-commit**: Validates documentation changes

## Best Practices

### Do's ✅

- Use templates for consistency
- Update documentation with code changes
- Include realistic examples
- Document error conditions
- Provide troubleshooting guidance
- Link related modules/functions
- Use consistent terminology

### Don'ts ❌

- Don't duplicate information across files
- Don't include implementation details in README
- Don't ignore PSScriptAnalyzer findings without reason
- Don't let documentation become stale
- Don't use technical jargon without explanation
- Don't write overly verbose descriptions
- Don't skip examples in function documentation

## Quality Metrics

### Documentation Quality Score

Calculated based on:
- README completeness (40%)
- Function documentation coverage (30%)
- Code quality status (20%)
- Example quality and accuracy (10%)

### Tracking

Monitor documentation quality using:
- PSScriptAnalyzer integration
- Automated compliance checks
- Peer review feedback
- User feedback and issues

## Tools and Integrations

### PSScriptAnalyzer Integration

- **Module**: PSScriptAnalyzerIntegration
- **Configuration**: PSScriptAnalyzerSettings.psd1
- **Status Files**: .pssa-status (auto-generated)
- **Bug Tracking**: .bugz files (auto-managed)

### Development Tools

- **VS Code**: Tasks for documentation workflows
- **GitHub Actions**: Automated documentation validation
- **Pester**: Documentation testing framework
- **Markdown Linting**: Consistent formatting

### Helpful Commands

```powershell
# Generate documentation for all modules
Get-ChildItem "./aither-core/modules" -Directory | ForEach-Object {
    Start-DirectoryAudit -Path $_.FullName -UpdateDocumentation
}

# Validate documentation compliance
Invoke-DocumentationAudit -Path "./aither-core/modules" -GenerateReport

# Update code quality status
./tests/Run-Tests.ps1 -CodeQuality -All
```

## Support and Questions

For documentation questions:
1. Check this standards guide
2. Review template examples
3. Ask in team chat/discussions
4. Create documentation issue

Remember: Good documentation is code's best friend! 📚✨
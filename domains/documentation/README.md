# Documentation Domain

This domain provides comprehensive documentation automation capabilities for the AitherZero platform, including reactive documentation generation, quality validation, and multi-format publishing.

## Features

### 🤖 Automated Documentation Generation
- **Reactive Mode**: Automatically generates documentation when code changes
- **Full Generation**: Complete project documentation regeneration
- **Incremental Updates**: Updates only changed components
- **Multi-format Output**: Markdown, HTML, and PDF support

### 📊 Quality Validation
- Documentation coverage analysis
- Link validation
- Content quality checks
- Automated quality gates

### 🎨 Template System
- Customizable documentation templates
- Consistent formatting across all documentation
- Support for multiple document types (modules, projects, APIs)

### 🔄 CI/CD Integration
- GitHub Actions workflow for automatic documentation updates
- Pull request documentation validation
- Automatic deployment to GitHub Pages

## Modules

### DocumentationEngine.psm1
The core documentation engine providing:
- Template-based documentation generation
- AST parsing for code analysis
- Multi-format export capabilities
- Quality validation framework

## Automation Scripts

### 0733_Generate-AutoDocumentation.ps1
Automated documentation generation script with modes:
- `Full`: Complete documentation regeneration
- `Incremental`: Update only changed files
- `Reactive`: File system watcher for real-time updates

## Usage Examples

### Basic Documentation Generation
```powershell
# Import the documentation engine
Import-Module ./domains/documentation/DocumentationEngine.psm1

# Initialize with templates
Initialize-DocumentationEngine -TemplateDirectory "./docs/templates"

# Generate project documentation
New-ProjectDocumentation -OutputPath "./docs/generated"

# Generate module documentation
New-ModuleDocumentation -ModulePath "./domains/utilities/Logging.psm1"
```

### Automated Generation
```powershell
# Full documentation generation
./az 0733 -Mode Full -Format Both -Quality

# Incremental updates
./az 0733 -Mode Incremental

# Reactive mode with file watching
./az 0733 -Mode Reactive -Watch -WatchTimeout 300
```

### Quality Validation
```powershell
# Validate documentation quality
Initialize-DocumentationEngine
$results = Test-DocumentationQuality -Path "./docs/generated"

Write-Host "Quality Score: $($results.Score)%"
Write-Host "Coverage: $($results.Coverage.CoveragePercentage)%"
```

## Configuration

The documentation engine supports configuration through:

### Default Configuration
```powershell
@{
    ReactiveMode = @{
        Enabled = $true
        WatchPaths = @("domains/**/*.psm1", "automation-scripts/**/*.ps1")
        DebounceSeconds = 30
    }
    OutputFormats = @('Markdown', 'HTML')
    OutputDirectory = "docs/generated"
    QualityGates = @{
        MinimumCoverage = 75
        RequireExamples = $true
        ValidateLinks = $true
    }
}
```

### File-based Configuration
Create a `docs-config.json` file:
```json
{
    "OutputDirectory": "custom/docs/path",
    "QualityGates": {
        "MinimumCoverage": 80
    },
    "Templates": {
        "ModuleDocumentation": "custom-module-template.md"
    }
}
```

## Templates

Documentation templates support Mustache-style variable substitution:

### Module Template Variables
- `{{ModuleName}}`: Name of the PowerShell module
- `{{ModuleDescription}}`: Module description from comment-based help
- `{{Functions}}`: Array of function information
- `{{Dependencies}}`: Module dependencies

### Function Template Variables
- `{{Name}}`: Function name
- `{{Synopsis}}`: Function synopsis
- `{{Description}}`: Detailed description
- `{{Parameters}}`: Function parameters
- `{{Examples}}`: Usage examples

## CI/CD Automation

### GitHub Actions Workflow
The documentation is automatically:
1. **Generated** on code changes to modules or scripts
2. **Validated** for quality and coverage
3. **Deployed** to GitHub Pages on main branch updates
4. **Reported** on pull requests with generation status

### Quality Gates
- Minimum 75% documentation coverage
- All internal links must be valid
- Required sections must be present
- No empty documentation sections

## Architecture

```
docs/
├── templates/           # Documentation templates
│   ├── module-template.md
│   ├── project-template.md
│   └── function-template.md
├── generated/          # Auto-generated documentation
│   ├── modules/        # Individual module docs
│   ├── automation-scripts/  # Script documentation
│   └── INDEX.md        # Navigation index
└── static/             # Static documentation files

domains/documentation/
├── DocumentationEngine.psm1  # Core documentation engine
└── README.md           # This file

automation-scripts/
└── 0733_Generate-AutoDocumentation.ps1  # Automation script

.github/workflows/
└── documentation-automation.yml  # CI/CD workflow
```

## Integration Points

### With Other Domains
- **Utilities/Logging**: Structured logging for documentation operations
- **Configuration**: Configuration management for documentation settings
- **Reporting**: Integration with reporting engine for metrics
- **Testing**: Documentation validation as part of quality gates

### With Automation Scripts
- **0510_Generate-ProjectReport**: Enhanced with documentation metrics
- **0521_Analyze-DocumentationCoverage**: Replaced by integrated coverage analysis
- **CI/CD Scripts**: Automated documentation updates in pipelines

## Best Practices

### 1. Write Good Comment-Based Help
```powershell
<#
.SYNOPSIS
    Brief description of what the function does
.DESCRIPTION
    Detailed explanation of the function's purpose and behavior
.PARAMETER Name
    Description of each parameter
.EXAMPLE
    Example usage of the function
#>
```

### 2. Maintain README Files
Each domain should have a comprehensive README.md explaining:
- Purpose and functionality
- Available modules and functions
- Usage examples
- Configuration options

### 3. Use Consistent Templates
- Follow the established template structure
- Include all required sections
- Provide meaningful examples
- Keep descriptions clear and concise

### 4. Monitor Quality Metrics
- Aim for >80% documentation coverage
- Ensure all public functions have help
- Validate links regularly
- Review generated documentation for accuracy

## Troubleshooting

### Common Issues

**Template Expansion Errors**
- Check template syntax for correct `{{variable}}` format
- Ensure all required variables are provided
- Validate template file encoding (UTF-8)

**File Watcher Not Triggering**
- Verify file paths in watch configuration
- Check file system permissions
- Ensure debounce settings are appropriate

**Quality Validation Failures**
- Review coverage requirements
- Check for broken internal links
- Ensure required sections are present
- Validate parameter documentation

### Debug Mode
Enable verbose logging for troubleshooting:
```powershell
$VerbosePreference = 'Continue'
Initialize-DocumentationEngine -Verbose
```

## Contributing

When contributing to the documentation system:

1. Test template changes with sample data
2. Validate generated output in both formats
3. Run quality validation before submitting
4. Update this README for new features
5. Follow PowerShell best practices for module development

## Version History

- **v1.0.0**: Initial documentation engine implementation
- **v1.1.0**: Added reactive documentation generation
- **v1.2.0**: Integrated quality validation and CI/CD automation
- **v1.3.0**: Enhanced template system and multi-format support

---

*This documentation is automatically maintained by the AitherZero Documentation Engine*
# AitherZero Orchestration Workflows v2.0

This directory contains modernized, standardized orchestration playbooks using the new v2.0 schema. All playbooks are designed around automation scripts (0000-9999) for consistent, reliable workflow execution.

## Directory Structure

```
workflows/
├── development/     # Development environment and workflow automation
├── infrastructure/  # Infrastructure setup and management 
├── testing/        # Testing, validation, and quality assurance
├── deployment/     # CI/CD pipelines and deployment automation
├── maintenance/    # System maintenance and cleanup operations
├── security/       # Security scanning and compliance workflows
└── analysis/       # Code analysis and reporting workflows
```

## Playbook Categories

### Development Workflows
- **quick-dev-setup**: Minimal development environment with essential tools
- Fast developer onboarding and environment preparation

### Infrastructure Workflows  
- **hyperv-lab-setup**: Complete Hyper-V virtualization lab with networking
- Infrastructure as Code deployment scenarios

### Testing Workflows
- **comprehensive-validation**: Full test suite with coverage and quality analysis
- Multi-tier testing strategies for different environments

### Deployment Workflows
- **ci-cd-pipeline**: Complete CI/CD automation with GitHub integration
- Automated deployment and release management

### Security Workflows
- **vulnerability-scan**: AI-powered security analysis and remediation
- Compliance validation and threat modeling

### Maintenance Workflows
- **system-cleanup**: System optimization and maintenance operations
- Environment reset and performance tuning

## Usage Examples

### Basic Execution
```powershell
# Import orchestration engine
Import-Module ./domains/automation/OrchestrationEngine.psm1

# Run a workflow playbook
Invoke-OrchestrationSequence -LoadPlaybook "quick-dev-setup"

# Use a specific profile
Invoke-OrchestrationSequence -LoadPlaybook "comprehensive-validation" -Profile "ci"
```

### Advanced Orchestration
```powershell
# Run with custom variables
Invoke-OrchestrationSequence -LoadPlaybook "hyperv-lab-setup" -Variables @{
    VMMPath = "D:\VMs"
    CreateDomain = $true
    VMCount = 5
}

# Dry run to see execution plan
Invoke-OrchestrationSequence -LoadPlaybook "vulnerability-scan" -DryRun

# Run with specific profile
Invoke-OrchestrationSequence -LoadPlaybook "ci-cd-pipeline" -Profile "pr-validation"
```

### Integration Examples
```powershell
# In Start-AitherZero.ps1
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook quick-dev-setup -Profile fast

# From automation scripts
az 0460 -PlaybookPath "./orchestration/playbooks/workflows/testing/comprehensive-validation.json"

# Programmatic execution
$result = Invoke-OrchestrationSequence -LoadPlaybook "system-cleanup" -Profile "safe" -PassThru
```

## Playbook Schema v2.0 Features

### Standardized Structure
- Consistent metadata format with versioning
- Clear categorization and tagging system
- Comprehensive requirements specification

### Advanced Orchestration
- Multi-profile support for different scenarios
- Conditional stage execution with PowerShell expressions
- Parallel and sequential execution control
- Retry logic and timeout management

### Robust Validation
- Pre-condition and post-condition validation
- Threshold-based quality gates
- Environment and dependency checking

### Enhanced Notifications
- Multi-channel notification support (console, log, GitHub, etc.)
- Contextual messaging for different scenarios
- Integration with external systems

### Comprehensive Reporting
- Multiple output formats (HTML, JSON, Markdown, etc.)
- Metrics and performance data collection
- Configurable log inclusion and retention

## Migration from Legacy Playbooks

Legacy playbooks (v1.0) have been archived in `archive/legacy-v1/`. To migrate:

1. **Review Structure**: Compare against schema in `../schema/playbook-schema-v2.json`
2. **Update Metadata**: Use new standardized metadata format
3. **Modernize Orchestration**: Convert to new stages-based approach
4. **Add Validation**: Include pre/post conditions and thresholds
5. **Enhance Notifications**: Utilize new notification system
6. **Test Thoroughly**: Validate against automation scripts

## Best Practices

### Playbook Design
- Use meaningful, kebab-case names for playbook identifiers
- Keep descriptions concise but informative (10-200 characters)
- Include realistic time estimates for planning
- Use appropriate tags for discoverability

### Stage Organization
- Group related automation scripts into logical stages
- Use descriptive stage names and clear descriptions
- Set appropriate timeouts based on expected execution time
- Consider dependencies between stages

### Variable Management
- Define sensible defaults in `defaultVariables`
- Create profiles for common usage scenarios
- Use template variables (`{{variableName}}`) for dynamic values
- Document variable purposes and valid ranges

### Error Handling
- Set `continueOnError` appropriately for each stage
- Use validation thresholds to define quality gates
- Implement proper retry logic for transient failures
- Provide meaningful error messages and guidance

### Testing and Validation
- Always test playbooks in development environments first
- Use dry-run mode to validate execution plans
- Implement comprehensive pre/post conditions
- Validate against multiple profiles and scenarios

## Contributing

When creating new playbooks:

1. Follow the schema in `../schema/playbook-schema-v2.json`
2. Place in appropriate category directory
3. Use descriptive names and comprehensive metadata
4. Include multiple profiles for different use cases
5. Add proper validation and error handling
6. Test thoroughly before committing

## Support

For issues or questions:
- Check existing automation scripts in `automation-scripts/`
- Review orchestration documentation in `docs/`
- Validate against schema using JSON validation tools
- Test in isolated environments before production use
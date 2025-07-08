# {{DIRECTORY_NAME}}

## Overview

{{#if DIRECTORY_DESCRIPTION}}
{{DIRECTORY_DESCRIPTION}}
{{else}}
Directory containing components for the AitherZero automation framework.
{{/if}}

### Purpose and Scope

- **{{PRIMARY_PURPOSE}}**
- **{{DIRECTORY_SCOPE}}**
- **Integration with AitherZero framework**
- **{{USAGE_CONTEXT}}**

## Directory Structure

```
{{RELATIVE_PATH}}/
{{#each FILES}}
├── {{this.name}}{{#if this.description}}    # {{this.description}}{{/if}}
{{/each}}
{{#each SUBDIRECTORIES}}
├── {{this.name}}/{{#if this.description}}          # {{this.description}}{{/if}}
{{#each this.files}}
│   ├── {{this.name}}
{{/each}}
{{/each}}
```

### Content Organization

{{#if CONTENT_ORGANIZATION}}
{{CONTENT_ORGANIZATION}}
{{else}}
This directory contains {{FILE_COUNT}} files{{#if SUBDIRECTORY_COUNT}} and {{SUBDIRECTORY_COUNT}} subdirectories{{/if}}.

{{#if HAS_CODE_FILES}}
**Code Files**: {{CODE_FILE_COUNT}} files containing implementation logic
{{/if}}
{{#if HAS_CONFIG_FILES}}
**Configuration Files**: {{CONFIG_FILE_COUNT}} files with settings and parameters
{{/if}}
{{#if HAS_DOC_FILES}}
**Documentation Files**: {{DOC_FILE_COUNT}} files with documentation and guides
{{/if}}
{{#if HAS_SCRIPT_FILES}}
**Script Files**: {{SCRIPT_FILE_COUNT}} automation and utility scripts
{{/if}}
{{/if}}

## Key Components

{{#if KEY_COMPONENTS}}
{{#each KEY_COMPONENTS}}
### {{this.name}}

{{this.description}}

{{#if this.files}}
**Related Files**:
{{#each this.files}}
- `{{this.name}}`: {{this.description}}
{{/each}}
{{/if}}

{{/each}}
{{else}}
### {{COMPONENT_1_NAME}}

{{COMPONENT_1_DESCRIPTION}}

### {{COMPONENT_2_NAME}}

{{COMPONENT_2_DESCRIPTION}}
{{/if}}

## Usage

{{#if USAGE_INSTRUCTIONS}}
{{USAGE_INSTRUCTIONS}}
{{else}}
### Basic Usage

{{#if HAS_SCRIPTS}}
Run the available scripts:

```powershell
# Example script execution
{{SCRIPT_EXECUTION_EXAMPLE}}
```
{{/if}}

{{#if HAS_MODULES}}
Import and use modules:

```powershell
# Import module
Import-Module {{MODULE_IMPORT_PATH}} -Force

# Basic usage
{{MODULE_USAGE_EXAMPLE}}
```
{{/if}}

{{#if HAS_CONFIGS}}
Use configuration files:

```powershell
# Load configuration
{{CONFIG_USAGE_EXAMPLE}}
```
{{/if}}

### Advanced Scenarios

{{ADVANCED_USAGE_EXAMPLE}}
{{/if}}

## Dependencies

{{#if DEPENDENCIES}}
### Required Dependencies

{{#each DEPENDENCIES.required}}
- **{{this.name}}** ({{this.version}}): {{this.purpose}}
{{/each}}

### Optional Dependencies

{{#each DEPENDENCIES.optional}}
- **{{this.name}}**: {{this.purpose}}
{{/each}}

{{else}}
{{#if HAS_EXTERNAL_DEPS}}
### External Requirements

{{#each EXTERNAL_REQUIREMENTS}}
- **{{this.name}}**: {{this.description}}
{{/each}}
{{/if}}

### AitherZero Framework Integration

This directory integrates with the following AitherZero components:

{{#each FRAMEWORK_INTEGRATIONS}}
- **{{this.component}}**: {{this.purpose}}
{{/each}}
{{/if}}

## Configuration

{{#if HAS_CONFIGURATION}}
### Configuration Options

{{#each CONFIGURATION_OPTIONS}}
- **{{this.name}}** ({{this.type}}): {{this.description}}{{#if this.default}} Default: `{{this.default}}`{{/if}}
{{/each}}

### Configuration Example

```{{CONFIG_FORMAT}}
{{CONFIGURATION_EXAMPLE}}
```

{{else}}
{{#if NEEDS_CONFIGURATION}}
Configuration may be required for some components. See individual files for specific configuration requirements.
{{else}}
No specific configuration is required for this directory's components.
{{/if}}
{{/if}}

## Integration with AitherZero

{{#if INTEGRATION_DETAILS}}
{{INTEGRATION_DETAILS}}
{{else}}
This directory integrates with the AitherZero framework through:

1. **{{INTEGRATION_1}}**
2. **{{INTEGRATION_2}}**
3. **{{INTEGRATION_3}}**

### Framework Services Used

{{#each FRAMEWORK_SERVICES}}
- **{{this.service}}**: {{this.usage}}
{{/each}}
{{/if}}

## Best Practices

{{#if BEST_PRACTICES}}
{{#each BEST_PRACTICES}}
{{@index}}. **{{this.title}}**: {{this.description}}
{{/each}}
{{else}}
1. **Follow AitherZero patterns**: Use established framework conventions
2. **Maintain compatibility**: Ensure cross-platform PowerShell compatibility
3. **Use logging**: Integrate with AitherZero logging system
4. **Error handling**: Implement comprehensive error handling
5. **Documentation**: Keep documentation current with changes
{{/if}}

## Security Considerations

{{#if SECURITY_NOTES}}
{{#each SECURITY_NOTES}}
- **{{this.aspect}}**: {{this.description}}
{{/each}}
{{else}}
- **Access Control**: Ensure appropriate file permissions
- **Sensitive Data**: Avoid storing secrets in plain text
- **Input Validation**: Validate all external inputs
- **Audit Trail**: Use AitherZero logging for security-relevant events
{{/if}}

## Troubleshooting

### Common Issues

{{#if COMMON_ISSUES}}
{{#each COMMON_ISSUES}}
#### {{this.problem}}

**Symptoms**: {{this.symptoms}}

**Solution**:
```powershell
{{this.solution}}
```

{{/each}}
{{else}}
#### File Not Found Errors

**Symptoms**: Scripts or modules report missing files

**Solution**:
```powershell
# Verify file paths and ensure proper directory structure
Get-ChildItem -Path "{{RELATIVE_PATH}}" -Recurse
```

#### Permission Issues

**Symptoms**: Access denied errors when executing scripts

**Solution**:
```powershell
# Check and update execution policy if needed
Get-ExecutionPolicy
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```
{{/if}}

### Debugging

Enable detailed logging for troubleshooting:

```powershell
$env:AITHER_LOG_LEVEL = "DEBUG"
$env:AITHER_ENABLE_TRACE = "true"

# Re-run operations with detailed logging
{{DEBUG_COMMAND_EXAMPLE}}
```

## Testing

{{#if HAS_TESTS}}
### Running Tests

```powershell
# Run tests for this directory
{{TEST_COMMAND}}
```

### Test Coverage

{{#each TEST_CATEGORIES}}
- **{{this.name}}**: {{this.description}}
{{/each}}

{{else}}
Tests for components in this directory are included in the main AitherZero test suite:

```powershell
# Run comprehensive tests
./tests/Run-Tests.ps1

# Run specific component tests
./tests/Run-Tests.ps1 -Component "{{COMPONENT_NAME}}"
```
{{/if}}

## Contributing

When contributing to this directory:

1. **Follow AitherZero standards**: Adhere to framework coding and documentation standards
2. **Test thoroughly**: Ensure all changes work across supported platforms
3. **Update documentation**: Keep this README current with any changes
4. **Consider integration**: Ensure changes work well with other AitherZero components
5. **Security review**: Consider security implications of any modifications

## Related Documentation

{{#if RELATED_DOCS}}
{{#each RELATED_DOCS}}
- [{{this.title}}]({{this.path}}) - {{this.description}}
{{/each}}
{{else}}
- [AitherZero Main README](../../README.md) - Overall framework documentation
- [Contributing Guide](../../CONTRIBUTING.md) - Development guidelines
- [Architecture Overview](../../docs/ARCHITECTURE.md) - Framework architecture details
{{/if}}

---

*Part of the AitherZero automation framework - see main README for overall architecture and usage patterns*
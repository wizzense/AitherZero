# {{DIRECTORY_NAME}} Infrastructure

## Overview

{{#if INFRASTRUCTURE_TYPE}}
{{INFRASTRUCTURE_TYPE}} infrastructure configuration for AitherZero using OpenTofu/Terraform.
{{else}}
Infrastructure as Code configuration for AitherZero automation framework.
{{/if}}

### Purpose and Scope

- **{{PRIMARY_PURPOSE}}**
- **{{INFRASTRUCTURE_SCOPE}}**
- **Integration with AitherZero automation workflows**
- **{{DEPLOYMENT_MODEL}}**

## Directory Structure

```
{{RELATIVE_PATH}}/
{{#each FILES}}
├── {{this.name}}{{#if this.description}}    # {{this.description}}{{/if}}
{{/each}}
{{#each SUBDIRECTORIES}}
├── {{this.name}}/{{#if this.description}}          # {{this.description}}{{/if}}
{{/each}}
```

### File Organization

{{#each TERRAFORM_FILES}}
- **{{this.name}}**: {{this.description}}
{{/each}}

## Infrastructure Components

### {{COMPONENT_1_NAME}}

{{COMPONENT_1_DESCRIPTION}}

{{#if COMPONENT_1_RESOURCES}}
**Resources:**
{{#each COMPONENT_1_RESOURCES}}
- `{{this.type}}` - {{this.description}}
{{/each}}
{{/if}}

### {{COMPONENT_2_NAME}}

{{COMPONENT_2_DESCRIPTION}}

{{#if COMPONENT_2_RESOURCES}}
**Resources:**
{{#each COMPONENT_2_RESOURCES}}
- `{{this.type}}` - {{this.description}}
{{/each}}
{{/if}}

## Usage

### Prerequisites

{{#each PREREQUISITES}}
- **{{this.name}}**: {{this.description}}{{#if this.version}} ({{this.version}}){{/if}}
{{/each}}

### Deployment Steps

1. **Initialize the workspace:**
   ```bash
   tofu init
   ```

2. **Review the execution plan:**
   ```bash
   tofu plan{{#if PLAN_VARIABLES}} -var-file="{{PLAN_VARIABLES}}"{{/if}}
   ```

3. **Apply the configuration:**
   ```bash
   tofu apply{{#if APPLY_OPTIONS}} {{APPLY_OPTIONS}}{{/if}}
   ```

4. **Verify deployment:**
   ```bash
   {{VERIFICATION_COMMAND}}
   ```

### Configuration Variables

{{#if HAS_VARIABLES}}
{{#each VARIABLES}}
#### {{this.name}}

- **Type**: `{{this.type}}`
- **Description**: {{this.description}}
{{#if this.default}}- **Default**: `{{this.default}}`{{/if}}
{{#if this.required}}- **Required**: Yes{{/if}}

{{/each}}

### Example Variables File

```hcl
{{EXAMPLE_VARIABLES}}
```

{{else}}
This infrastructure configuration uses default values. Create a `terraform.tfvars` file to customize:

```hcl
# Example customization
{{EXAMPLE_CUSTOMIZATION}}
```
{{/if}}

## Providers

{{#each PROVIDERS}}
### {{this.name}}

**Version**: {{this.version}}
**Purpose**: {{this.purpose}}

{{#if this.configuration}}
**Configuration:**
```hcl
{{this.configuration}}
```
{{/if}}

{{/each}}

## Outputs

{{#if HAS_OUTPUTS}}
{{#each OUTPUTS}}
- **{{this.name}}**: {{this.description}}
{{/each}}

### Accessing Outputs

```bash
# View all outputs
tofu output

# Get specific output
tofu output {{EXAMPLE_OUTPUT_NAME}}

# Use output in scripts
RESOURCE_ID=$(tofu output -raw {{EXAMPLE_OUTPUT_NAME}})
```

{{else}}
No outputs are currently defined for this infrastructure configuration.
{{/if}}

## State Management

{{#if STATE_BACKEND}}
### Remote State Backend

This configuration uses {{STATE_BACKEND}} for state management:

```hcl
{{STATE_CONFIGURATION}}
```

### State Operations

```bash
# View current state
tofu state list

# Show specific resource
tofu state show {{EXAMPLE_RESOURCE}}

# Import existing resource
tofu import {{EXAMPLE_RESOURCE}} {{EXAMPLE_RESOURCE_ID}}
```

{{else}}
This configuration uses local state management. Consider configuring remote state for production use:

```hcl
terraform {
  backend "{{RECOMMENDED_BACKEND}}" {
    # Configuration here
  }
}
```
{{/if}}

## Security Considerations

{{#each SECURITY_NOTES}}
{{@index}}. **{{this.title}}**: {{this.description}}
{{/each}}

### Secrets Management

{{#if SECRETS_APPROACH}}
{{SECRETS_APPROACH}}
{{else}}
- Use environment variables for sensitive values
- Configure provider credentials securely
- Never commit secrets to version control
- Consider using HashiCorp Vault or similar secret management
{{/if}}

## Environment-Specific Configurations

{{#if MULTI_ENVIRONMENT}}
### Development Environment

```bash
tofu workspace select dev
tofu plan -var-file="environments/dev.tfvars"
tofu apply -var-file="environments/dev.tfvars"
```

### Production Environment

```bash
tofu workspace select prod
tofu plan -var-file="environments/prod.tfvars"
tofu apply -var-file="environments/prod.tfvars"
```

{{else}}
This configuration can be adapted for multiple environments by:

1. Creating environment-specific variable files
2. Using Terraform workspaces
3. Implementing conditional resource creation
{{/if}}

## Integration with AitherZero

### Automation Integration

```powershell
# Deploy using AitherZero OpenTofuProvider module
Import-Module ./aither-core/modules/OpenTofuProvider -Force

# Plan deployment
$plan = New-DeploymentPlan -ConfigPath "{{RELATIVE_PATH}}" -Environment "{{DEFAULT_ENVIRONMENT}}"

# Execute deployment
Start-InfrastructureDeployment -Plan $plan -Validate
```

### CI/CD Integration

This infrastructure is designed to work with AitherZero's automated deployment pipelines:

```yaml
# Example GitHub Actions integration
- name: Deploy Infrastructure
  uses: ./aither-core/actions/deploy-infrastructure
  with:
    config-path: {{RELATIVE_PATH}}
    environment: ${{ github.ref_name }}
```

## Disaster Recovery

{{#if DISASTER_RECOVERY}}
### Backup Strategy

{{DISASTER_RECOVERY.backup}}

### Recovery Procedures

{{DISASTER_RECOVERY.recovery}}

{{else}}
### Backup Considerations

- **State Backup**: Ensure Terraform state is backed up regularly
- **Resource Documentation**: Maintain documentation of critical resources
- **Recovery Testing**: Periodically test infrastructure recreation
{{/if}}

## Monitoring and Maintenance

{{#each MONITORING_ITEMS}}
- **{{this.name}}**: {{this.description}}
{{/each}}

### Cost Optimization

{{#if COST_OPTIMIZATION}}
{{#each COST_OPTIMIZATION}}
- **{{this.strategy}}**: {{this.description}}
{{/each}}
{{else}}
- Review resource utilization regularly
- Implement auto-scaling where appropriate
- Use spot instances for non-critical workloads
- Configure resource tagging for cost tracking
{{/if}}

## Troubleshooting

### Common Issues

{{#each COMMON_ISSUES}}
#### {{this.problem}}

**Symptoms**: {{this.symptoms}}

**Solution**:
```bash
{{this.solution}}
```

{{/each}}

### Debugging

Enable detailed logging:

```bash
export TF_LOG=DEBUG
tofu plan
```

### Support

- Check OpenTofu/Terraform documentation for provider-specific issues
- Review AitherZero infrastructure patterns in the main documentation
- Use `tofu validate` to check configuration syntax

## Contributing

When modifying this infrastructure:

1. **Test changes** in a development environment first
2. **Document any new variables** or outputs
3. **Update this README** with configuration changes
4. **Follow Terraform best practices** for resource naming and organization
5. **Consider security implications** of any changes

---

*Part of the AitherZero automation framework - see main README for deployment patterns*
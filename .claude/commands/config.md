# /config

Configuration management for AitherZero - switch environments, manage settings, and handle multi-configuration scenarios.

## Usage
```
/config [action] [options]
```

## Actions

### `show` - Display configuration (default)
Show current configuration or specific settings with environment context.

**Options:**
- `--module "module-name"` - Show module-specific config
- `--environment [dev|staging|production]` - Environment context
- `--format [json|yaml|table]` - Output format (default: table)
- `--sensitive` - Include sensitive values (masked)
- `--effective` - Show computed effective configuration

**Examples:**
```bash
/config show
/config show --module LabRunner --format json
/config show --environment production --sensitive
/config show --effective
```

### `switch` - Switch configuration set
Change active configuration using Configuration Carousel for different environments or scenarios.

**Options:**
- `--set "config-name"` - Configuration set to activate
- `--environment "env"` - Target environment
- `--backup` - Backup current config before switch
- `--validate` - Validate before switching
- `--force` - Force switch even with validation warnings

**Examples:**
```bash
/config switch --set production-azure --environment production
/config switch --set dev-local --backup
/config switch --set disaster-recovery --validate --force
```

### `edit` - Edit configuration
Modify configuration values with validation and change tracking.

**Options:**
- `--module "module-name"` - Target module
- `--key "setting.path"` - Configuration key path
- `--value "value"` - New value
- `--interactive` - Interactive editing mode
- `--validate` - Validate changes
- `--comment "text"` - Change comment for audit

**Examples:**
```bash
/config edit --module OpenTofuProvider --key provider.timeout --value 300
/config edit --interactive --module LabRunner
/config edit --key logging.level --value DEBUG --comment "Troubleshooting issue #123"
```

### `validate` - Validate configuration
Comprehensive configuration validation against schemas and business rules.

**Options:**
- `--strict` - Strict validation mode
- `--fix` - Auto-fix minor issues
- `--schema "path"` - Custom schema file
- `--environment "env"` - Environment-specific validation

**Examples:**
```bash
/config validate
/config validate --strict --environment production
/config validate --fix --schema ./configs/schemas/custom.json
```

### `backup` - Backup configuration
Create configuration backups with versioning and restoration capabilities.

**Options:**
- `--name "backup-name"` - Backup identifier
- `--compress` - Compress backup
- `--encrypt` - Encrypt sensitive data
- `--retention [days]` - Retention period

**Examples:**
```bash
/config backup --name pre-deployment
/config backup --name daily-auto --compress --encrypt --retention 30
```

### `restore` - Restore configuration
Restore configuration from backup with validation and rollback options.

**Options:**
- `--name "backup-name"` - Backup to restore
- `--date "YYYY-MM-DD"` - Restore from date
- `--preview` - Preview changes without applying
- `--modules "list"` - Restore specific modules only

**Examples:**
```bash
/config restore --name pre-deployment --preview
/config restore --date 2025-01-15
/config restore --name emergency --modules "LabRunner,OpenTofuProvider"
```

### `diff` - Compare configurations
Compare configurations across environments, versions, or time periods.

**Options:**
- `--source "config1"` - Source configuration
- `--target "config2"` - Target configuration
- `--ignore "patterns"` - Ignore specific keys
- `--output [inline|side-by-side|unified]` - Diff format

**Examples:**
```bash
/config diff --source dev --target production
/config diff --source current --target backup/2025-01-15
/config diff --source staging --target production --ignore "*.debug.*"
```

### `export` - Export configuration
Export configuration for sharing, migration, or external tools.

**Options:**
- `--format [json|yaml|env|terraform]` - Export format
- `--file "path"` - Output file
- `--sanitize` - Remove sensitive data
- `--templates` - Include templates

**Examples:**
```bash
/config export --format terraform --file ./configs/infra.tfvars
/config export --format env --sanitize --file ./.env.example
/config export --format yaml --templates
```

### `import` - Import configuration
Import configuration from external sources with mapping and transformation.

**Options:**
- `--source "path"` - Import source
- `--format [json|yaml|env|terraform]` - Source format
- `--map "mapping-file"` - Field mapping rules
- `--merge` - Merge with existing config
- `--dry-run` - Preview import without applying

**Examples:**
```bash
/config import --source ./legacy-config.json --map ./mapping.yaml
/config import --source terraform.tfvars --format terraform --merge
/config import --source .env --format env --dry-run
```

## Configuration Sources

### Configuration Hierarchy
1. **Default Configuration** - Built-in defaults
2. **Environment Configuration** - Environment-specific overrides
3. **Module Configuration** - Module-specific settings
4. **User Configuration** - User preferences
5. **Runtime Configuration** - Command-line overrides

### Configuration Repositories
- **Local Repository** - Project-specific configs
- **Remote Repository** - Shared team configs
- **Enterprise Repository** - Organization-wide settings
- **Template Repository** - Configuration templates

## Advanced Features

### Configuration Carousel
- **Multi-environment support** - Dev, staging, production
- **Quick switching** - Instant configuration changes
- **Version control** - Git-backed configurations
- **Rollback capability** - Undo configuration changes

### Dynamic Configuration
- **Variable interpolation** - `${env.VARIABLE}` syntax
- **Conditional settings** - Environment-based conditions
- **Computed values** - Dynamic value generation
- **External references** - Key vault integration

### Configuration Templates
```yaml
# Template example
template:
  name: "web-application"
  variables:
    - name: "app_name"
      required: true
    - name: "instance_count"
      default: 2
  
  configuration:
    labRunner:
      environment: "${var.app_name}-lab"
      instances: "${var.instance_count}"
```

### Secrets Management
- **Secure storage** - Encrypted at rest
- **Key vault integration** - Azure, AWS, HashiCorp
- **Rotation support** - Automatic secret rotation
- **Audit logging** - Access tracking

## Integration Points

### Module Integration
- **Automatic registration** - Modules auto-register configs
- **Schema validation** - Type-safe configurations
- **Default values** - Module-provided defaults
- **Migration support** - Version upgrade handling

### CI/CD Integration
- **Pipeline variables** - Automatic injection
- **Environment promotion** - Config propagation
- **Validation gates** - Pre-deployment checks
- **Rollback triggers** - Automatic reversion

### Monitoring Integration
- **Configuration drift** - Detect unauthorized changes
- **Change notifications** - Real-time alerts
- **Compliance tracking** - Policy adherence
- **Performance impact** - Config change correlation

## Best Practices

1. **Use environment-specific configs** - Isolate settings by environment
2. **Version control configurations** - Track all changes
3. **Validate before applying** - Prevent misconfigurations
4. **Document configuration changes** - Maintain audit trail
5. **Test configuration changes** - Verify in lower environments
6. **Use templates for consistency** - Standardize configurations
7. **Encrypt sensitive values** - Protect secrets
8. **Regular backups** - Enable quick recovery

## Configuration Examples

### Module Configuration
```json
{
  "modules": {
    "LabRunner": {
      "defaultEnvironment": "development",
      "maxInstances": 10,
      "timeout": 300
    },
    "PatchManager": {
      "autoSync": true,
      "defaultPriority": "medium",
      "createPR": true
    }
  }
}
```

### Environment Configuration
```yaml
environments:
  production:
    labRunner:
      maxInstances: 50
      highAvailability: true
    security:
      enforceEncryption: true
      auditLevel: "detailed"
```

## Troubleshooting

### Common Issues
- **Validation failures** - Check schema compliance
- **Missing values** - Ensure required fields are set
- **Permission denied** - Verify access rights
- **Merge conflicts** - Resolve Git conflicts

### Debug Commands
```bash
# Verbose configuration loading
/config show --verbose --debug

# Trace configuration resolution
/config show --effective --trace

# Validate with detailed errors
/config validate --strict --explain
```

The `/config` command provides comprehensive configuration management with safety, auditability, and flexibility for enterprise environments.
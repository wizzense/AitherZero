# Configuration Carousel Guide

## Overview

The Configuration Carousel is AitherZero's advanced configuration management system that eliminates redundancy and provides environment-aware configuration switching.

## Key Benefits

✅ **Eliminates Redundancy**: One base configuration with profile-specific overrides  
✅ **Environment-Aware**: dev/staging/prod configurations with appropriate security  
✅ **Easy Switching**: Switch between configurations and environments instantly  
✅ **Backwards Compatible**: Legacy configurations still supported  
✅ **Git Integration**: Support for team configuration repositories  

## Architecture

```
configs/carousel/
├── base-config.json              # Common settings for all profiles
├── carousel-registry.json        # Configuration management registry
├── profiles/                     # Configuration profiles
│   ├── minimal/
│   │   └── profile-config.json   # Minimal deployment profile
│   ├── standard/
│   │   └── profile-config.json   # Standard development profile
│   ├── enterprise/
│   │   └── profile-config.json   # Enterprise full-feature profile
│   └── recommended/
│       └── profile-config.json   # Recommended balanced profile
└── environments/                 # Environment-specific overrides
    ├── dev-overrides.json        # Development environment
    ├── staging-overrides.json    # Staging environment
    └── prod-overrides.json       # Production environment
```

## Configuration Profiles

### 1. Minimal Profile (5-8 MB)
- **Target**: CI/CD environments, core operations
- **Features**: Core infrastructure, Basic Git operations, OpenTofu deployment
- **Tools**: Git, GitHub CLI, PowerShell, OpenTofu
- **Use Case**: Automated deployments, minimal resource usage

### 2. Standard Profile (15-25 MB) 
- **Target**: Developer workstations, interactive environments
- **Features**: AI tools integration, Enhanced UI, Development tools
- **Tools**: + Go, Python, Node.js, VSCode, AI tools (Claude, Gemini)
- **Use Case**: Daily development work, recommended for most users

### 3. Enterprise Profile (35-50 MB)
- **Target**: Enterprise deployments, full lab environments  
- **Features**: Full toolchain, Advanced monitoring, Enterprise security
- **Tools**: + HyperV, Azure CLI, AWS CLI, Docker, Sysinternals, Security tools
- **Use Case**: Complete enterprise environments, lab automation

### 4. Recommended Profile (20-30 MB)
- **Target**: Streamlined development environments
- **Features**: Essential development tools, AI integration, HyperV support
- **Tools**: Balanced selection of essential tools
- **Use Case**: Optimal balance of features and size

## Environment Configurations

### Development Environment
- **Security**: Relaxed (unsigned scripts allowed, validation skipped)
- **Logging**: Debug level, verbose output
- **Behavior**: Auto-confirm operations, experimental features enabled
- **Use Case**: Development and testing

### Staging Environment  
- **Security**: Balanced (module validation, confirmation prompts)
- **Logging**: Info level, audit logging enabled
- **Behavior**: Requires confirmation, full test suites
- **Use Case**: Testing and validation before production

### Production Environment
- **Security**: Maximum (encryption required, strict validation)
- **Logging**: Warning level, security logging, audit trails
- **Behavior**: Requires approval, backup validation, destructive operations blocked
- **Use Case**: Live production environments

## Usage Examples

### Using Configuration Carousel

```powershell
# Import the ConfigurationCarousel module
Import-Module ./aither-core/modules/ConfigurationCarousel -Force

# List available configurations
Get-AvailableConfigurations

# Switch to a different configuration profile
Switch-ConfigurationSet -ConfigurationName "enterprise" -Environment "prod"

# Switch just the environment (keep current profile)
Switch-ConfigurationSet -ConfigurationName "standard" -Environment "staging"

# Get current configuration status
Get-CurrentConfiguration

# Backup current configuration before switching
Switch-ConfigurationSet -ConfigurationName "minimal" -Environment "dev" -BackupCurrent

# Validate a configuration before switching
Validate-ConfigurationSet -ConfigurationName "enterprise" -Environment "prod"
```

### Integration with AitherZero

```powershell
# Start AitherZero with carousel-managed configuration
./Start-AitherZero.ps1 -ConfigurationCarousel

# Setup with specific profile and environment
./Start-AitherZero.ps1 -Setup -ConfigurationProfile "recommended" -Environment "dev"

# Use aither CLI with carousel
aither config                    # View current carousel configuration
aither setup -Profile standard  # Setup with standard profile
```

## Configuration Inheritance

The Configuration Carousel uses a hierarchical inheritance system:

1. **Base Configuration** (`base-config.json`) - Common settings for all profiles
2. **Profile Configuration** - Profile-specific overrides (minimal/standard/enterprise/recommended)  
3. **Environment Overrides** - Environment-specific settings (dev/staging/prod)

**Resolution Order**: Base → Profile → Environment

Example for "standard" profile in "staging" environment:
```
base-config.json 
  ↓ (merged with)
profiles/standard/profile-config.json
  ↓ (merged with)  
environments/staging-overrides.json
  ↓ (results in)
Final Configuration
```

## Migration from Legacy Configurations

The system maintains backwards compatibility with legacy configuration files:

- `core-runner-config.json` → `minimal` profile
- `default-config.json` → `standard` profile  
- `full-config.json` → `enterprise` profile
- `recommended-config.json` → `recommended` profile

Legacy configurations are still accessible via the `legacy-default` configuration in the carousel registry.

## Team Configuration Repositories

The Configuration Carousel supports Git-based team configuration sharing:

```powershell
# Add a team configuration repository
Add-ConfigurationRepository -Name "team-config" -Source "https://github.com/myorg/aither-config.git"

# Sync with remote configuration repository
Sync-ConfigurationRepository -ConfigurationName "team-config" -Operation "pull"

# Push local changes to team repository
Sync-ConfigurationRepository -ConfigurationName "team-config" -Operation "push"
```

## Security Features

### Environment-Based Security Policies

- **Development**: Relaxed security for fast iteration
- **Staging**: Balanced security with confirmation prompts
- **Production**: Maximum security with encryption and audit logging

### Configuration Validation

All configurations are validated before application:
- Dependency checking (PowerShell, Git, OpenTofu, etc.)
- Platform compatibility verification
- Environment compatibility assessment
- Security policy compliance

### Backup and Recovery

Automatic backup before configuration changes:
```powershell
# Manual backup
Backup-CurrentConfiguration -Reason "Before testing new profile"

# List available backups
Get-ConfigurationBackups

# Restore from backup
Restore-ConfigurationBackup -BackupId "backup-20250706-123456"
```

## Best Practices

1. **Use Standard Profile**: Recommended for most development scenarios
2. **Environment Consistency**: Use same profile across environments, different environment overrides
3. **Backup Before Changes**: Always backup before major configuration switches
4. **Validate First**: Use `Validate-ConfigurationSet` before applying changes
5. **Team Repositories**: Use shared configuration repositories for team consistency

## Troubleshooting

### Configuration Switch Fails
```powershell
# Check validation errors
Validate-ConfigurationSet -ConfigurationName "enterprise" -Environment "prod"

# Force switch (use with caution)
Switch-ConfigurationSet -ConfigurationName "enterprise" -Environment "prod" -Force

# Check current status
Get-CurrentConfiguration
```

### Dependency Issues
```powershell
# Check missing dependencies
Test-ConfigurationDependencies -ConfigurationName "enterprise"

# Install missing dependencies
Install-ConfigurationDependencies -ConfigurationName "enterprise"
```

### Environment Compatibility Issues
```powershell
# Check environment compatibility
Test-EnvironmentCompatibility -ConfigurationName "standard" -Environment "prod"

# View compatibility warnings
Get-CompatibilityReport -ConfigurationName "standard" -Environment "prod"
```

## Configuration Reference

For detailed configuration options, see:
- `base-config.json` - Complete base configuration reference
- Profile configurations - Profile-specific settings and overrides
- Environment overrides - Environment-specific behavior modifications

The Configuration Carousel eliminates the need for multiple redundant configuration files while providing powerful environment-aware configuration management for enterprise-grade infrastructure automation.
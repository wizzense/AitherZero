# AitherZero Infrastructure Configurations

This directory contains production-ready infrastructure configurations for AitherZero deployments. Unlike the examples directory, these configurations are designed for real-world use with proper state management, security considerations, and scalability patterns.

## Directory Structure

```
infrastructure/
├── main.tf              # YAML-driven infrastructure orchestration
├── lab_config.yaml      # Infrastructure configuration (example)
├── environments/        # Environment-specific configurations (future)
├── backends/           # State backend configurations (future)
└── deployments/        # Deployment-specific overrides (future)
```

## Overview

The infrastructure configurations follow a **YAML-driven approach** that separates infrastructure definition from implementation details. This design enables:

- **Configuration as Data**: Infrastructure defined in human-readable YAML
- **Environment Flexibility**: Easy switching between dev, staging, and production
- **GitOps Ready**: YAML configurations can be version controlled separately
- **Reduced Complexity**: Non-Terraform users can modify infrastructure

## Infrastructure Components

### Core Architecture

The `main.tf` file implements a flexible, YAML-driven infrastructure pattern:

```hcl
locals {
  lab = yamldecode(file(var.lab_config_path))
}

# Dynamic VM creation based on YAML configuration
module "vm" {
  for_each = { for vm in local.lab.vms : vm.name_prefix => vm }
  source   = "./opentofu/modules/vm"
  # ... configuration from YAML
}
```

### YAML Configuration Schema

```yaml
# lab_config.yaml example
hyperv:
  host: hyperv-host.domain.local
  user: administrator
  password: ${HYPERV_PASSWORD}  # Environment variable reference
  vm_path: D:/VirtualMachines
  cacert_path: ./certs/ca.pem
  cert_path: ./certs/client.pem
  key_path: ./certs/client-key.pem

switch:
  name: ProductionNetwork
  net_adapter_names: 
    - "10GB Network Adapter #1"
    - "10GB Network Adapter #2"
  allow_management_os: true
  switch_type: External

vms:
  - name_prefix: web
    count: 3
    vhd_size_bytes: 53687091200        # 50GB
    iso_path: D:/ISOs/ubuntu-22.04.iso
    memory_startup_bytes: 4294967296    # 4GB
    memory_maximum_bytes: 8589934592    # 8GB
    memory_minimum_bytes: 2147483648    # 2GB
    processor_count: 2
    
  - name_prefix: app
    count: 2
    vhd_size_bytes: 107374182400       # 100GB
    iso_path: D:/ISOs/windows-2022.iso
    memory_startup_bytes: 8589934592    # 8GB
    memory_maximum_bytes: 16777216000   # 16GB
    memory_minimum_bytes: 4294967296    # 4GB
    processor_count: 4
    
  - name_prefix: db
    count: 1
    vhd_size_bytes: 214748364800       # 200GB
    iso_path: D:/ISOs/windows-2022.iso
    memory_startup_bytes: 16777216000   # 16GB
    memory_maximum_bytes: 34359738368   # 32GB
    memory_minimum_bytes: 8589934592    # 8GB
    processor_count: 8
```

## Usage

### Basic Deployment

1. **Create Configuration File**:
   ```bash
   cp lab_config.yaml.example lab_config.yaml
   # Edit lab_config.yaml with your settings
   ```

2. **Set Environment Variables**:
   ```bash
   export HYPERV_PASSWORD="your-secure-password"
   export TF_VAR_lab_config_path="./lab_config.yaml"
   ```

3. **Initialize and Deploy**:
   ```bash
   tofu init
   tofu plan
   tofu apply
   ```

### Advanced Usage

#### Multiple Environments

```bash
# Development environment
tofu apply -var="lab_config_path=./configs/dev-lab.yaml"

# Staging environment
tofu apply -var="lab_config_path=./configs/staging-lab.yaml"

# Production environment
tofu apply -var="lab_config_path=./configs/prod-lab.yaml"
```

#### Partial Deployments

```bash
# Deploy only web tier
tofu apply -target='module.vm["web"]'

# Deploy network infrastructure first
tofu apply -target=module.switch
```

#### State Management

```bash
# Using remote backend (recommended for production)
cat > backend.tf <<EOF
terraform {
  backend "azurerm" {
    resource_group_name  = "terraform-state"
    storage_account_name = "tfstateaitherzero"
    container_name       = "tfstate"
    key                  = "infrastructure.tfstate"
  }
}
EOF
```

## Deployment Workflow

### Production Deployment Process

1. **Pre-flight Checks**:
   ```bash
   # Validate YAML configuration
   yq validate lab_config.yaml
   
   # Check connectivity to Hyper-V host
   Test-NetConnection -ComputerName hyperv-host -Port 5986
   ```

2. **Plan Review**:
   ```bash
   tofu plan -out=tfplan
   tofu show -json tfplan > plan.json
   # Review plan.json for unexpected changes
   ```

3. **Approval and Apply**:
   ```bash
   # With approval workflow
   tofu apply tfplan
   ```

4. **Post-Deployment Validation**:
   ```bash
   # Verify resources
   tofu output -json > deployed-resources.json
   ```

### Rollback Procedures

```bash
# Rollback to previous state
tofu state pull > current.tfstate
# Review and restore previous version

# Destroy specific resources
tofu destroy -target='module.vm["problematic"]'
```

## Module Development

### Creating Environment-Specific Modules

```hcl
# environments/production/main.tf
module "production_security" {
  source = "../../modules/security"
  
  enable_encryption = true
  enable_backup     = true
  retention_days    = 30
}
```

### Extending YAML Schema

When adding new infrastructure types:

1. **Update Schema Documentation**
2. **Add Parsing Logic** in `main.tf`
3. **Create Corresponding Module**
4. **Update Validation Rules**

## Security Considerations

### Credential Management

- **Never** commit passwords or secrets to Git
- Use environment variables for sensitive data
- Consider HashiCorp Vault integration for production
- Rotate credentials regularly

### Network Security

```yaml
# Implement network segmentation
networks:
  - name: DMZ
    type: External
    vlan_id: 100
  - name: Internal
    type: Private
    vlan_id: 200
  - name: Management
    type: Internal
    vlan_id: 999
```

### State File Security

- Encrypt state files at rest
- Use remote backends with access controls
- Enable state file versioning
- Regular state file backups

## Integration with AitherZero

### PowerShell Integration

```powershell
# Use OpenTofuProvider module
Import-Module ./aither-core/modules/OpenTofuProvider -Force

# Deploy infrastructure
Invoke-OpenTofuDeployment -ConfigPath "./lab_config.yaml" -Environment "production"
```

### LabRunner Integration

The infrastructure configurations integrate seamlessly with AitherZero's LabRunner:

```powershell
# Deploy and configure lab
Start-LabDeployment -ConfigFile "./lab_config.yaml" -AutoConfigure
```

## Best Practices

1. **Configuration Management**:
   - Keep YAML configs in separate repository
   - Use schema validation
   - Implement config templating for common patterns

2. **State Management**:
   - Always use remote state for production
   - Enable state locking
   - Regular state backups

3. **Security**:
   - Encrypt sensitive data
   - Use least privilege access
   - Audit infrastructure changes

4. **Monitoring**:
   - Export metrics from deployments
   - Set up alerts for resource limits
   - Track deployment history

## Troubleshooting

### Common Issues

#### YAML Parsing Errors
```bash
# Validate YAML syntax
yq eval lab_config.yaml

# Check for tab characters (use spaces)
grep -P '\t' lab_config.yaml
```

#### Module Path Issues
```hcl
# Ensure relative paths are correct
module "vm" {
  source = "../modules/vm"  # Adjust based on execution directory
}
```

#### State Conflicts
```bash
# Refresh state
tofu refresh

# Force unlock if needed
tofu force-unlock <lock-id>
```

## Disaster Recovery

### Backup Procedures

1. **State File Backups**:
   ```bash
   # Automated backup before changes
   tofu state pull > "backups/state-$(date +%Y%m%d-%H%M%S).json"
   ```

2. **Configuration Backups**:
   ```bash
   # Version control for YAML configs
   git add lab_config.yaml
   git commit -m "Backup: $(date)"
   ```

### Recovery Procedures

1. **From State Backup**:
   ```bash
   tofu state push backups/state-20240101-120000.json
   ```

2. **Full Rebuild**:
   ```bash
   # Remove state and rebuild
   rm -rf .terraform terraform.tfstate*
   tofu init
   tofu apply
   ```

## Future Enhancements

- **Multi-Cloud Support**: Extend beyond Hyper-V to Azure, AWS
- **Service Mesh Integration**: Automatic service discovery
- **Compliance Automation**: Policy as code integration
- **Cost Optimization**: Resource usage analytics

## Contributing

When contributing infrastructure configurations:

1. Follow YAML schema conventions
2. Include comprehensive documentation
3. Test in isolated environment first
4. Add appropriate security controls
5. Update this README

## Additional Resources

- [OpenTofu State Management](https://opentofu.org/docs/language/state/)
- [YAML Schema Validation](https://json-schema.org/learn/miscellaneous-examples.html)
- [AitherZero Security Guidelines](../../docs/security.md)
- [Infrastructure as Code Best Practices](https://www.terraform.io/docs/cloud/guides/recommended-practices/)
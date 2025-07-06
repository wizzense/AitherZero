# AitherZero OpenTofu Infrastructure

This directory contains the Infrastructure as Code (IaC) configurations for AitherZero using OpenTofu (the open-source fork of Terraform). The architecture follows a modular approach to enable reusable, scalable infrastructure deployments primarily focused on Hyper-V virtualization environments.

## Directory Structure

```
opentofu/
├── examples/               # Example implementations and reference configurations
│   └── hyperv/            # Hyper-V specific examples and lab setups
├── infrastructure/        # Production-ready infrastructure configurations
│   └── main.tf           # YAML-driven infrastructure deployment
└── modules/              # Reusable OpenTofu modules
    ├── network_switch/   # Virtual network switch management
    └── vm/              # Virtual machine provisioning
```

## Overview

### Infrastructure as Code Approach

AitherZero uses OpenTofu to declaratively define and manage infrastructure resources. This approach provides:

- **Version Control**: Infrastructure configurations are stored as code, enabling tracking of changes
- **Reproducibility**: Consistent deployments across different environments
- **Modularity**: Reusable components that can be composed for different use cases
- **Automation**: Integration with CI/CD pipelines for automated deployments

### OpenTofu vs Terraform

This project uses **OpenTofu**, the open-source fork of Terraform, to ensure:
- Community-driven development without licensing concerns
- Full compatibility with existing Terraform configurations
- Freedom from vendor lock-in

All configurations are compatible with both OpenTofu (`tofu`) and Terraform (`terraform`) CLI commands.

### Module-Based Architecture

The infrastructure follows a hierarchical module structure:

1. **Base Modules** (`modules/`): Atomic, reusable components
2. **Infrastructure Configurations** (`infrastructure/`): Production deployments using modules
3. **Examples** (`examples/`): Reference implementations and lab environments

## Infrastructure Components

### Available Modules

#### Network Switch Module (`modules/network_switch/`)
- Creates and manages Hyper-V virtual switches
- Supports External, Internal, and Private switch types
- Configures host network adapter bindings

#### VM Module (`modules/vm/`)
- Provisions Hyper-V virtual machines with consistent configurations
- Manages VHD creation and sizing
- Handles memory allocation (dynamic/static)
- Configures processor counts and ISO mounting

### Provider Configuration

The primary provider is **taliesins/hyperv** for managing Hyper-V resources:

```hcl
terraform {
  required_providers {
    hyperv = {
      source  = "taliesins/hyperv"
      version = ">=1.2.1"
    }
  }
}
```

## Usage

### Basic Commands

```bash
# Initialize the working directory
tofu init

# Validate configuration syntax
tofu validate

# Preview changes before applying
tofu plan

# Apply the configuration
tofu apply

# Destroy all managed resources
tofu destroy
```

### Using Modules in Your Configuration

```hcl
# Create a network switch
module "lab_switch" {
  source            = "./modules/network_switch"
  name              = "LabNetwork"
  net_adapter_names = ["Ethernet0"]
}

# Create VMs using the switch
module "lab_vms" {
  source             = "./modules/vm"
  vm_count           = 3
  vm_name_prefix     = "lab-node"
  hyperv_vm_path     = "D:/VMs/lab"
  vhd_size_bytes     = 50_000_000_000
  iso_path           = "D:/ISOs/ubuntu-22.04.iso"
  switch_name        = module.lab_switch.switch_name
  switch_dependency  = module.lab_switch.switch_resource
}
```

### Deployment Workflow

1. **Configuration**: Define your infrastructure in `.tf` files or use YAML-driven configs
2. **Planning**: Run `tofu plan` to preview changes
3. **Review**: Examine the execution plan for accuracy
4. **Apply**: Execute `tofu apply` to create/update resources
5. **Validate**: Verify resources are created correctly

## Module Development

### Creating New Modules

Follow these conventions when developing new modules:

1. **Structure**:
   ```
   module_name/
   ├── README.md      # Module documentation
   ├── main.tf        # Primary resource definitions
   ├── variables.tf   # Input variable declarations
   └── outputs.tf     # Output value exports
   ```

2. **Variable Conventions**:
   - Use descriptive names with underscores
   - Provide clear descriptions
   - Set sensible defaults where appropriate
   - Mark required variables without defaults

3. **Output Conventions**:
   - Export resource IDs and names
   - Include computed attributes useful for dependencies
   - Provide the full resource for advanced use cases

4. **Documentation**:
   - Include usage examples
   - Document all variables and outputs
   - Provide minimal working examples

### Testing Infrastructure Code

```bash
# Format code according to conventions
tofu fmt -recursive

# Validate syntax and configuration
tofu validate

# Run targeted plans for specific modules
tofu plan -target=module.vm

# Use workspaces for isolated testing
tofu workspace new test
tofu workspace select test
```

## Examples

### Lab Environment Setup

The `examples/hyperv/` directory contains a complete lab setup:

```bash
cd examples/hyperv
tofu init
tofu apply -var-file="lab.tfvars"
```

### YAML-Driven Infrastructure

The `infrastructure/` directory demonstrates YAML-based configuration:

```yaml
# lab_config.yaml
hyperv:
  host: hyperv-host.local
  user: administrator
  vm_path: D:/VMs

switch:
  name: LabNetwork
  net_adapter_names: ["Ethernet0"]

vms:
  - name_prefix: web
    count: 2
    vhd_size_bytes: 30000000000
    iso_path: D:/ISOs/ubuntu.iso
  - name_prefix: db
    count: 1
    vhd_size_bytes: 50000000000
    iso_path: D:/ISOs/ubuntu.iso
```

### Common Patterns

1. **Multi-VM Deployment**:
   ```hcl
   module "app_tier" {
     source         = "./modules/vm"
     vm_count       = 3
     vm_name_prefix = "app"
     # ... other configuration
   }
   ```

2. **Network Isolation**:
   ```hcl
   module "dmz_switch" {
     source      = "./modules/network_switch"
     name        = "DMZ"
     switch_type = "Private"
   }
   ```

## Integration with AitherZero

OpenTofu configurations integrate with AitherZero's automation framework:

- **OpenTofuProvider Module**: PowerShell wrapper for OpenTofu operations
- **Automated Deployments**: Lab automation through LabRunner module
- **Configuration Management**: YAML-based configurations via SetupWizard

## Best Practices

1. **State Management**: Store state files securely and use remote backends for teams
2. **Variable Usage**: Use `.tfvars` files for environment-specific values
3. **Module Versioning**: Pin module versions in production configurations
4. **Resource Naming**: Use consistent naming conventions across all resources
5. **Documentation**: Keep README files updated with examples and usage instructions

## Contributing

When contributing infrastructure code:

1. Follow the existing module structure
2. Include comprehensive documentation
3. Add examples demonstrating module usage
4. Test configurations on target platforms
5. Use `tofu fmt` before committing

## Additional Resources

- [OpenTofu Documentation](https://opentofu.org/docs/)
- [Hyper-V Provider Documentation](https://registry.terraform.io/providers/taliesins/hyperv/latest/docs)
- [AitherZero OpenTofuProvider Module](../aither-core/modules/OpenTofuProvider/)
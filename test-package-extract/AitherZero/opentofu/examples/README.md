# OpenTofu Examples

This directory contains example configurations and reference implementations for using OpenTofu with various infrastructure providers. These examples demonstrate best practices, common patterns, and real-world usage scenarios.

## Directory Structure

```
examples/
└── hyperv/                    # Hyper-V virtualization examples
    ├── examples_archive/      # Historical examples and experiments
    ├── examples_tailiesins/   # Provider-specific examples from taliesins
    ├── modules/              # Local module references
    ├── main.tf              # Primary configuration
    ├── providers.tf         # Provider configuration
    ├── variables.tf         # Variable definitions
    ├── vm_modules.tf        # VM deployment using modules
    └── WAN-vSwitch.tf       # Network switch configuration
```

## Overview

The examples serve multiple purposes:

1. **Learning Resources**: Step-by-step demonstrations of OpenTofu features
2. **Reference Implementations**: Production-ready patterns you can adapt
3. **Testing Grounds**: Validated configurations used in CI/CD pipelines
4. **Quick Start Templates**: Copy and modify for your own projects

## Available Examples

### Hyper-V Lab Environment (`hyperv/`)

A complete Hyper-V virtualization lab that demonstrates:

- **Network Configuration**: External virtual switch creation
- **VM Provisioning**: Multiple OS deployments using reusable modules
- **Provider Authentication**: Secure WinRM connection setup
- **Modular Architecture**: Composition of network and VM modules

Key features:
- Windows 11 and Windows Server 2025 VM deployments
- Dynamic VM scaling through count variables
- ISO-based automated installations
- External network connectivity

### Example Categories

#### Basic Infrastructure
- Single VM deployment
- Network switch creation
- Storage configuration

#### Advanced Patterns
- Multi-tier applications
- High availability setups
- Network segmentation

#### Integration Examples
- CI/CD pipeline integration
- Automated testing environments
- Development lab provisioning

## Usage

### Getting Started with Examples

1. **Choose an Example**:
   ```bash
   cd examples/hyperv
   ```

2. **Review the Configuration**:
   ```bash
   # Examine the infrastructure code
   cat main.tf
   cat variables.tf
   ```

3. **Initialize OpenTofu**:
   ```bash
   tofu init
   ```

4. **Customize Variables**:
   ```bash
   # Create a terraform.tfvars file
   cat > terraform.tfvars <<EOF
   hyperv_host_name = "your-hyperv-host"
   hyperv_user = "administrator"
   windows_11_iso_path = "D:/ISOs/Win11.iso"
   EOF
   ```

5. **Deploy the Infrastructure**:
   ```bash
   tofu plan
   tofu apply
   ```

### Common Customizations

#### Adjusting VM Counts
```hcl
# terraform.tfvars
windows_11_vm_count = 3
windows_server_vm_count = 2
```

#### Changing Network Configuration
```hcl
# terraform.tfvars
wan_switch_name = "LabNetwork"
wan_adapter_names = ["Ethernet 2", "Ethernet 3"]
```

#### Modifying VM Resources
```hcl
# In vm_modules.tf
module "windows_11_vms" {
  memory_startup_bytes = 8589934592  # 8GB
  processor_count      = 4
  vhd_size_bytes      = 100000000000  # 100GB
}
```

## Example Patterns

### Pattern 1: Development Lab

Quick setup for development testing:

```hcl
module "dev_lab" {
  source         = "../../modules/vm"
  vm_count       = 1
  vm_name_prefix = "dev"
  iso_path       = var.dev_iso_path
  # Minimal resources for development
  memory_startup_bytes = 2147483648
  processor_count      = 2
}
```

### Pattern 2: Production-Like Environment

Simulating production configurations:

```hcl
module "prod_simulation" {
  for_each = {
    web = { count = 3, memory = 4294967296 }
    app = { count = 2, memory = 8589934592 }
    db  = { count = 1, memory = 16777216000 }
  }
  
  source               = "../../modules/vm"
  vm_count            = each.value.count
  vm_name_prefix      = each.key
  memory_startup_bytes = each.value.memory
}
```

### Pattern 3: Network Isolation

Creating isolated network segments:

```hcl
module "dmz_network" {
  source      = "../../modules/network_switch"
  name        = "DMZ"
  switch_type = "Private"
}

module "internal_network" {
  source      = "../../modules/network_switch"
  name        = "Internal"
  switch_type = "Internal"
}
```

## Provider-Specific Examples

### Taliesins Hyper-V Provider

The `examples_tailiesins/` directory contains provider-specific examples:

- **Data Sources**: Querying existing Hyper-V resources
- **Resource Management**: Creating and configuring VMs, VHDs, and switches
- **Provider Configuration**: Authentication and connection options

## Best Practices for Examples

1. **Self-Contained**: Each example should work independently
2. **Well-Documented**: Include README files and inline comments
3. **Variable-Driven**: Use variables for customization points
4. **Minimal Dependencies**: Avoid external dependencies where possible
5. **Tested**: Examples should be validated in CI/CD pipelines

## Creating New Examples

When adding new examples:

1. **Structure**:
   ```
   examples/your_example/
   ├── README.md        # Detailed documentation
   ├── main.tf          # Main configuration
   ├── variables.tf     # Input variables
   ├── outputs.tf       # Output values
   └── terraform.tfvars.example  # Example variable values
   ```

2. **Documentation Requirements**:
   - Purpose and use case
   - Prerequisites
   - Step-by-step usage instructions
   - Customization options
   - Clean-up procedures

3. **Testing**:
   - Validate with `tofu validate`
   - Test deployment and destruction
   - Verify outputs and functionality

## Integration with CI/CD

Examples are automatically tested via GitHub Actions:

```yaml
# .github/workflows/test.yml
- name: Validate Examples
  run: |
    cd examples/hyperv
    tofu init
    tofu validate
```

This ensures examples remain functional and up-to-date.

## Troubleshooting Common Issues

### Provider Authentication
```hcl
# Ensure WinRM is configured on Hyper-V host
# Check certificate paths and permissions
provider "hyperv" {
  cacert_path = "certs/rootca.pem"  # Verify file exists
  cert_path   = "certs/host.pem"
  key_path    = "certs/host-key.pem"
}
```

### Resource Conflicts
```bash
# Clean up failed deployments
tofu destroy -target=module.problematic_resource
tofu state rm module.problematic_resource
```

### State Management
```bash
# Reset to clean state
rm -rf .terraform terraform.tfstate*
tofu init
```

## Contributing Examples

We welcome new examples! When contributing:

1. Follow the existing structure and naming conventions
2. Include comprehensive documentation
3. Test on multiple platforms if applicable
4. Add to CI/CD validation
5. Update this README with your example

## Additional Resources

- [OpenTofu Documentation](https://opentofu.org/docs/)
- [AitherZero Modules](../modules/)
- [Infrastructure Configurations](../infrastructure/)
- [Hyper-V Provider Docs](https://registry.terraform.io/providers/taliesins/hyperv/latest/docs)
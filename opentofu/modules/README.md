# AitherZero OpenTofu Modules

This directory contains reusable OpenTofu modules that serve as the building blocks for infrastructure deployments. These modules follow HashiCorp's best practices for module development and are designed to be composable, maintainable, and production-ready.

## Directory Structure

```
modules/
├── network_switch/      # Virtual network switch management
│   ├── README.md       # Module documentation
│   ├── main.tf         # Resource definitions
│   ├── variables.tf    # Input variables
│   └── outputs.tf      # Output values
│
└── vm/                 # Virtual machine provisioning
    ├── README.md       # Module documentation
    ├── main.tf         # Resource definitions
    └── variables.tf    # Input variables
```

## Overview

### Module Philosophy

Our modules follow these core principles:

1. **Single Responsibility**: Each module manages one type of infrastructure
2. **Composability**: Modules can be combined to create complex infrastructures
3. **Reusability**: Generic enough for multiple use cases, specific enough to be useful
4. **Maintainability**: Clear interfaces, comprehensive documentation
5. **Testability**: Designed with testing and validation in mind

### Module Architecture

```
┌─────────────────────────────────┐
│     Root Configuration          │
│  (examples/ or infrastructure/) │
└────────────┬────────────────────┘
             │ calls
┌────────────▼────────────────────┐
│         Modules                 │
│  ┌───────────┐ ┌─────────────┐ │
│  │  network  │ │     vm      │ │
│  │  _switch  │ │             │ │
│  └───────────┘ └─────────────┘ │
└────────────┬────────────────────┘
             │ provisions
┌────────────▼────────────────────┐
│    Infrastructure Resources     │
│  (Hyper-V VMs, Switches, etc.)  │
└─────────────────────────────────┘
```

## Available Modules

### Network Switch Module (`network_switch/`)

**Purpose**: Creates and manages Hyper-V virtual switches with full configuration control.

**Key Features**:
- External, Internal, and Private switch types
- Multi-adapter support for teaming/redundancy
- Management OS access control
- Consistent naming and tagging

**Basic Usage**:
```hcl
module "production_switch" {
  source              = "../modules/network_switch"
  name                = "Production"
  net_adapter_names   = ["Ethernet0", "Ethernet1"]
  allow_management_os = true
  switch_type         = "External"
}
```

### Virtual Machine Module (`vm/`)

**Purpose**: Provisions Hyper-V virtual machines with standardized configurations.

**Key Features**:
- Multi-VM deployment with count parameter
- Dynamic memory configuration
- VHD management and sizing
- ISO mounting for OS installation
- Network adapter configuration
- Consistent naming patterns

**Basic Usage**:
```hcl
module "web_servers" {
  source               = "../modules/vm"
  vm_count             = 3
  vm_name_prefix       = "web"
  hyperv_vm_path       = "D:/VMs"
  vhd_size_bytes       = 53687091200  # 50GB
  iso_path             = "D:/ISOs/ubuntu.iso"
  switch_name          = module.production_switch.switch_name
  switch_dependency    = module.production_switch.switch_resource
  memory_startup_bytes = 4294967296   # 4GB
  processor_count      = 2
}
```

## Module Development

### Creating a New Module

1. **Directory Structure**:
   ```bash
   modules/your_module/
   ├── README.md        # Comprehensive documentation
   ├── main.tf          # Primary resource definitions
   ├── variables.tf     # Input variable declarations
   ├── outputs.tf       # Output value definitions
   ├── versions.tf      # Provider version constraints
   └── examples/        # Usage examples
       └── basic/
           └── main.tf
   ```

2. **Module Interface Design**:
   ```hcl
   # variables.tf - Define clear inputs
   variable "name" {
     description = "Name of the resource"
     type        = string
     validation {
       condition     = length(var.name) > 0
       error_message = "Name must not be empty."
     }
   }
   
   # outputs.tf - Export useful values
   output "id" {
     description = "The ID of the created resource"
     value       = hyperv_resource.this.id
   }
   ```

3. **Resource Naming**:
   ```hcl
   # Use consistent naming patterns
   resource "hyperv_machine_instance" "this" {
     count = var.vm_count
     name  = "${var.vm_name_prefix}-${format("%02d", count.index + 1)}"
   }
   ```

### Module Standards

#### Variable Conventions

```hcl
# Required variables (no default)
variable "name" {
  description = "Name of the resource"
  type        = string
}

# Optional variables (with defaults)
variable "switch_type" {
  description = "Type of virtual switch"
  type        = string
  default     = "External"
  
  validation {
    condition     = contains(["External", "Internal", "Private"], var.switch_type)
    error_message = "Switch type must be External, Internal, or Private."
  }
}

# Complex types
variable "network_config" {
  description = "Network configuration options"
  type = object({
    vlan_id          = optional(number)
    enable_sr_iov    = optional(bool, false)
    bandwidth_weight = optional(number, 100)
  })
  default = {}
}
```

#### Output Conventions

```hcl
# Always output the resource ID
output "id" {
  description = "Unique identifier of the resource"
  value       = hyperv_resource.this.id
}

# Output computed attributes
output "ip_address" {
  description = "Assigned IP address"
  value       = hyperv_resource.this.ip_address
}

# Output the full resource for advanced use
output "resource" {
  description = "The complete resource object"
  value       = hyperv_resource.this
  sensitive   = true  # If contains sensitive data
}
```

#### Documentation Requirements

Each module must include:

1. **Purpose Statement**: Clear description of what the module does
2. **Requirements**: Provider versions, dependencies
3. **Usage Examples**: At least one working example
4. **Variable Documentation**: All inputs documented
5. **Output Documentation**: All outputs explained
6. **Resource Details**: What resources are created
7. **Known Limitations**: Any constraints or issues

### Testing Modules

#### Unit Testing

```hcl
# tests/unit/main.tf
module "test" {
  source = "../../"
  
  # Minimum required variables
  name              = "test-switch"
  net_adapter_names = ["Test-Adapter"]
}

# Validate outputs
output "test_name" {
  value = module.test.switch_name
}
```

#### Integration Testing

```bash
# Run integration tests
cd modules/network_switch/tests/integration
tofu init
tofu apply -auto-approve
tofu destroy -auto-approve
```

#### Validation

```bash
# Format check
tofu fmt -check -recursive

# Validation
tofu validate

# Security scanning
tfsec .
```

## Module Composition

### Dependency Management

```hcl
# Explicit dependencies using outputs
module "network" {
  source = "./modules/network_switch"
  name   = "MainSwitch"
}

module "vms" {
  source            = "./modules/vm"
  switch_name       = module.network.switch_name
  switch_dependency = module.network.switch_resource
}
```

### Conditional Module Creation

```hcl
# Create modules based on conditions
module "dev_network" {
  count  = var.environment == "dev" ? 1 : 0
  source = "./modules/network_switch"
  name   = "DevNetwork"
}
```

### Module Composition Patterns

```hcl
# Application stack pattern
module "app_stack" {
  source = "./modules/app_stack"
  
  network_module = module.network
  web_servers    = module.web_tier
  app_servers    = module.app_tier
  database       = module.db_tier
}
```

## Best Practices

### 1. Module Design

- **Keep It Simple**: Modules should do one thing well
- **Avoid Hard-coding**: Use variables for all configuration
- **Provide Defaults**: Set sensible defaults for optional variables
- **Validate Inputs**: Use validation blocks for variables

### 2. Naming Conventions

- **Module Names**: Use lowercase with underscores
- **Variable Names**: Use lowercase with underscores
- **Output Names**: Use lowercase with underscores
- **Resource Names**: Use `this` for single resources, descriptive names for multiple

### 3. Version Management

```hcl
# versions.tf
terraform {
  required_version = ">= 1.6.0"
  
  required_providers {
    hyperv = {
      source  = "taliesins/hyperv"
      version = ">= 1.2.1"
    }
  }
}
```

### 4. Error Handling

```hcl
# Provide helpful error messages
variable "memory_bytes" {
  type = number
  validation {
    condition     = var.memory_bytes >= 536870912
    error_message = "Memory must be at least 512MB (536870912 bytes)."
  }
}
```

## Module Lifecycle

### Versioning

- Use semantic versioning (MAJOR.MINOR.PATCH)
- Tag releases in Git
- Document breaking changes
- Maintain compatibility where possible

### Deprecation

When deprecating module features:

1. Add deprecation notice in README
2. Use `terraform console` warnings
3. Provide migration path
4. Support deprecated features for 2 major versions

### Module Registry

Future enhancement: Internal module registry for version management and discovery.

## Troubleshooting

### Common Issues

#### Circular Dependencies
```hcl
# Avoid by using explicit outputs
output "switch_name" {
  value = hyperv_network_switch.this.name
}
```

#### Variable Type Mismatches
```hcl
# Be explicit about types
variable "adapter_names" {
  type = list(string)  # Not just 'list'
}
```

#### Output Timing Issues
```hcl
# Use depends_on for timing
output "ip_address" {
  value      = hyperv_machine_instance.this.ip_address
  depends_on = [hyperv_machine_instance.this]
}
```

## Contributing

### New Module Checklist

- [ ] Follow directory structure
- [ ] Include comprehensive README
- [ ] Add usage examples
- [ ] Implement input validation
- [ ] Define helpful outputs
- [ ] Add unit tests
- [ ] Run formatting and validation
- [ ] Update this documentation

### Code Review Criteria

1. **Functionality**: Does it work as intended?
2. **Reusability**: Is it generic enough?
3. **Documentation**: Is it well-documented?
4. **Standards**: Does it follow conventions?
5. **Testing**: Are there adequate tests?

## Future Modules

Planned modules for future development:

- **storage/**: Managed disk and storage configuration
- **backup/**: Automated backup configuration
- **monitoring/**: Infrastructure monitoring setup
- **security/**: Security policies and configurations
- **load_balancer/**: Load balancing configuration

## Resources

- [Terraform Module Registry](https://registry.terraform.io/browse/modules)
- [Module Development Best Practices](https://www.terraform.io/docs/language/modules/develop/index.html)
- [OpenTofu Documentation](https://opentofu.org/docs/)
- [Hyper-V Provider Documentation](https://registry.terraform.io/providers/taliesins/hyperv/latest/docs)
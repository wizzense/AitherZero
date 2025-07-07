# Hyper-V VM Module

Provision one or more Hyper-V virtual machines and their accompanying VHD files.

## Inputs

 Variable  Type  Description 
 --------  ----  ----------- 
 `vm_count`  number  Number of VMs to create. 
 `vm_name_prefix`  string  Prefix used for VM names and VHD file paths. 
 `hyperv_vm_path`  string  Base directory on the Hyper-V host where VHDs are stored. 
 `vhd_size_bytes`  number  Size of each VHD in bytes. 
 `iso_path`  string  Path to the installation ISO attached as a DVD drive. 
 `switch_name`  string  Name of the Hyper-V virtual switch for networking. 
 `switch_dependency`  any  Resource that ensures the switch exists before VMs are created. 
 `memory_startup_bytes`  number  Startup memory allocation. 
 `memory_maximum_bytes`  number  Maximum memory allocation. 
 `memory_minimum_bytes`  number  Minimum memory allocation. 
 `processor_count`  number  Number of virtual processors. 

## Outputs

This module defines no explicit outputs. Access the generated resources directly if needed, for example:

```hcl
module.demo_vm.hyperv_machine_instance.this0.id
```

## Minimal Example

```hcl
module "demo_vm" {
  source               = "../../modules/vm"
  vm_count             = 1
  vm_name_prefix       = "demo"
  hyperv_vm_path       = "D:/VMs/demo"
  vhd_size_bytes       = 50_000_000_000
  iso_path             = var.demo_iso_path
  switch_name          = module.switch.switch_name
  switch_dependency    = module.switch.switch_resource
  memory_startup_bytes = 2147483648
  memory_maximum_bytes = 4294967296
  memory_minimum_bytes = 536870912
  processor_count      = 2
}
```

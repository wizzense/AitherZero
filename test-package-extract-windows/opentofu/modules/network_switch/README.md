# Network Switch Module

Use this module to create a reusable Hyper‑V virtual switch via the
`hyperv_network_switch` resource.

## Provider Requirements

Add the `hyperv` provider from the `taliesins` namespace to your configuration:

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

## Inputs

 Variable  Type  Description  Default 
 --------  ----  -----------  ------- 
 `name`  string  Name of the switch.  required 
 `net_adapter_names`  list(string)  Host adapters backing the switch.  required 
 `allow_management_os`  bool  Allow the management OS to share the NIC.  `true` 
 `switch_type`  string  Switch type such as `External` or `Internal`.  `"External"` 

## Outputs

 Name  Description 
 ----  ----------- 
 `switch_name`  Name of the created switch. 
 `switch_resource`  The `hyperv_network_switch` resource. 

## Minimal Example

```hcl
module "wan_switch" {
  source            = "../../modules/network_switch"
  name              = "wan"
  net_adapter_names = "Ethernet0"
}
```

Use the outputs when attaching VMs:

```hcl
switch_name        = module.wan_switch.switch_name
switch_dependency  = module.wan_switch.switch_resource
```

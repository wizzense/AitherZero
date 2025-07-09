This repository contains example OpenTofu configurations for deploying a small
Hyper-V lab.  The configuration now uses a reusable module to create virtual
machines so that additional operating systems can be added easily.

To use these configurations clone the repo and run the usual OpenTofu
workflow:

```
tofu init
tofu validate
tofu plan
tofu apply
```

## Hyper-V provider configuration

The `providers.tf` file configures the `taliesins/hyperv` provider and exposes
all authentication fields through variables. A typical configuration looks like:

```hcl
provider "hyperv" {
  user            = var.hyperv_user
  password        = var.hyperv_password
  host            = var.hyperv_host_name
  port            = 5986
  https           = true
  insecure        = false
  use_ntlm        = true
  tls_server_name = var.hyperv_host_name
  cacert_path     = "certs/rootca.pem"
  cert_path       = "certs/host.pem"
  key_path        = "certs/host-key.pem"
  script_path     = "C:/Temp/tofu_%RAND%.cmd"
  timeout         = "30s"
}
```

Each argument can also be sourced from environment variables like `HYPERV_USER`
or `HYPERV_PASSWORD`. See
`examples_tailiesins/hyperv-provider.example`(examples_tailiesins/hyperv-provider.example)
for a fully annotated reference.

## Customizing variables

Default values for network adapter names, ISO locations and VM counts are
defined in `variables.tf`.  Create a `terraform.tfvars` file or pass `-var`
arguments to override them.  Example `terraform.tfvars`:

```hcl
wan_switch_name   = "lab"
wan_adapter_names = "Ethernet 2"
windows_11_vm_count = 2
```

If you need to reset your working copy run:

```
git reset --hard
git clean -fd
git pull
```

## Automated testing

The test.yml(../../.github/workflows/test.yml) workflow installs OpenTofu and
executes `tofu init` and `tofu validate` in this directory. It runs whenever you
push changes or open a pull request, ensuring the examples remain valid.

## Files

- `WAN-vSwitch.tf` – creates the external network switch using
  `hyperv_network_switch`.
- `vm_modules.tf` – repeatedly calls the `modules/vm`(../../modules/vm/README.md)
  module to build VMs with different ISOs.
- `providers.tf` – holds the provider configuration shown above.

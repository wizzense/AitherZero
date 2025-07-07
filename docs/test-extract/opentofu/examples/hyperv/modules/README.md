# Available Terraform Modules

This directory is created by `tofu init` and records which modules were pulled for the examples. To make it clear which reusable components are shipped with this repository, the following list describes the modules found under the top-level `modules` folder and how they are used in the root examples.

## Modules

- `modules/network_switch`(../../../modules/network_switch) – wraps the `hyperv_network_switch` resource so that a virtual switch can be created once and referenced by other modules. The examples create the WAN switch directly in `WAN-vSwitch.tf`, but this module can be used as a drop-in replacement when you need additional switches.
- `modules/vm`(../../../modules/vm) – provisions a Hyper-V VM along with its VHD. The file `vm_modules.tf` in the example root calls this module several times to build TanOS, Windows, and Rocky Linux machines.

## Relationship to the examples

The files under `opentofu/examples/hyperv` demonstrate how to apply these modules. `vm_modules.tf` shows repeated invocations of the `vm` module to spin up different operating systems. `WAN-vSwitch.tf` defines the network switch directly for simplicity, but the same result could be achieved by calling the `network_switch` module. The `modules.json` file in this directory is generated automatically and lists the modules used after running `tofu init`.

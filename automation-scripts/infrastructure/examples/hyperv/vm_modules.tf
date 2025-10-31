# Example usage of the hyperv_vm module for various operating systems.

module "tanos" {
  source               = "../../modules/vm"
  vm_count             = var.tanos_vm_count
  vm_name_prefix       = "TanOS"
  hyperv_vm_path       = var.hyperv_vm_path
  vhd_size_bytes       = 107374182400
  iso_path             = var.tanos_iso_path
  switch_name          = hyperv_network_switch.wan.name
  switch_dependency    = hyperv_network_switch.wan
  memory_startup_bytes = 2147483648
  memory_maximum_bytes = 8589934592
  memory_minimum_bytes = 536870912
  processor_count      = 4
}

module "server_core_2025" {
  source               = "../../modules/vm"
  vm_count             = var.windows_server_core_vm_count
  vm_name_prefix       = "Server-Core-2025"
  hyperv_vm_path       = var.hyperv_vm_path
  vhd_size_bytes       = 60737421312
  iso_path             = var.server_2025_iso_path
  switch_name          = hyperv_network_switch.wan.name
  switch_dependency    = hyperv_network_switch.wan
  memory_startup_bytes = 2147483648
  memory_maximum_bytes = 4294967296
  memory_minimum_bytes = 536870912
  processor_count      = 2
}

module "win11" {
  source               = "../../modules/vm"
  vm_count             = var.windows_11_vm_count
  vm_name_prefix       = "Win11"
  hyperv_vm_path       = var.hyperv_vm_path
  vhd_size_bytes       = 60737421312
  iso_path             = var.win_11_iso_path
  switch_name          = hyperv_network_switch.wan.name
  switch_dependency    = hyperv_network_switch.wan
  memory_startup_bytes = 2147483648
  memory_maximum_bytes = 4294967296
  memory_minimum_bytes = 536870912
  processor_count      = 2
}

module "win10" {
  source               = "../../modules/vm"
  vm_count             = var.windows_10_vm_count
  vm_name_prefix       = "Win10"
  hyperv_vm_path       = var.hyperv_vm_path
  vhd_size_bytes       = 60737421312
  iso_path             = var.win_10_iso_path
  switch_name          = hyperv_network_switch.wan.name
  switch_dependency    = hyperv_network_switch.wan
  memory_startup_bytes = 2147483648
  memory_maximum_bytes = 4294967296
  memory_minimum_bytes = 536870912
  processor_count      = 2
}

module "rocky94" {
  source               = "../../modules/vm"
  vm_count             = var.rocky_94_vm_count
  vm_name_prefix       = "rocky94"
  hyperv_vm_path       = var.hyperv_vm_path
  vhd_size_bytes       = 60737421312
  iso_path             = var.rocky_94_iso_path
  switch_name          = hyperv_network_switch.wan.name
  switch_dependency    = hyperv_network_switch.wan
  memory_startup_bytes = 2147483648
  memory_maximum_bytes = 4294967296
  memory_minimum_bytes = 536870912
  processor_count      = 2
}

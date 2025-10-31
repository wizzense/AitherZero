terraform {
  required_version = ">= 1.6.0"
  required_providers {
    hyperv = {
      source  = "taliesins/hyperv"
      version = "1.2.1"
    }
  }
}

variable "lab_config_path" {
  description = "Path to the YAML configuration file"
  type        = string
  default     = "lab_config.yaml"
}

locals {
  lab = yamldecode(file(var.lab_config_path))
}

provider "hyperv" {
  user            = local.lab.hyperv.user
  password        = local.lab.hyperv.password
  host            = local.lab.hyperv.host
  port            = 5986
  https           = true
  insecure        = false
  use_ntlm        = true
  tls_server_name = local.lab.hyperv.host
  cacert_path     = local.lab.hyperv.cacert_path
  cert_path       = local.lab.hyperv.cert_path
  key_path        = local.lab.hyperv.key_path
  script_path     = "C:/Temp/tofu_%RAND%.cmd"
  timeout         = "30s"
}

module "switch" {
  source            = "./opentofu/modules/network_switch"
  name              = local.lab.switch.name
  net_adapter_names = local.lab.switch.net_adapter_names
}

module "vm" {
  for_each            = { for vm in local.lab.vms : vm.name_prefix => vm }
  source              = "./opentofu/modules/vm"
  vm_count            = each.value.count
  vm_name_prefix      = each.value.name_prefix
  hyperv_vm_path      = local.lab.hyperv.vm_path
  vhd_size_bytes      = each.value.vhd_size_bytes
  iso_path            = each.value.iso_path
  switch_name         = module.switch.switch_name
  switch_dependency   = module.switch.switch_resource
  memory_startup_bytes = each.value.memory_startup_bytes
  memory_maximum_bytes = each.value.memory_maximum_bytes
  memory_minimum_bytes = each.value.memory_minimum_bytes
  processor_count      = each.value.processor_count
}

terraform {
  required_providers {
    hyperv = {
      source  = "taliesins/hyperv"
      version = ">=1.2.1"
    }
  }
}

resource "hyperv_network_switch" "this" {
  name                = var.name
  allow_management_os = var.allow_management_os
  switch_type         = var.switch_type
  net_adapter_names   = var.net_adapter_names
}

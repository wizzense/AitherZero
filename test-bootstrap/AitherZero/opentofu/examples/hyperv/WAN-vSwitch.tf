# Declare the hyperv_network_switch resource
# Get-NetAdapter
resource "hyperv_network_switch" "wan" {
  name                = var.wan_switch_name
  allow_management_os = true
  switch_type         = "External"
  net_adapter_names   = var.wan_adapter_names
}
# Declare the hyperv_network_switch resource
# tofu import hyperv_network_switch.switch1 switch1
# tofu state rm hyperv_network_switch.switch1
resource "hyperv_network_switch" "switch1" {
  name                = "switch1"
  allow_management_os = true
  switch_type         = "External"
  net_adapter_names   = ["Ethernet"]
  minimum_bandwidth_mode = "Absolute"

  lifecycle {
    prevent_destroy = true
}

}


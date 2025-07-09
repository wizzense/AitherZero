###############################################################################
# outputs.tf
###############################################################################

# Example: Output the Hyper-V switch name from the data source
output "hyperv_switch_name" {
  description = "Name of the Hyper-V switch we retrieved via data source."
  value       = data.hyperv_network_switch.default.name
}

# Example: Output whether the VHD file exists
# (assuming we declared: data "hyperv_vhd" "web_server_vhd" { ... })
output "web_server_vhd_exists" {
  description = "Shows whether the web server VHD file exists on disk."
  value       = data.hyperv_vhd.web_server_vhd.exists
}

# Example: Output the VM name from the data source
# (the data source references the resource hyperv_machine_instance.default)
output "web_server_vm_name" {
  description = "Name of the web server VM."
  value       = data.hyperv_machine_instance.default.name
}

# Example: Output the VM IP addresses
# (ip_addresses is a read-only list of strings from the data source)
output "web_server_vm_ips" {
  description = "All IP addresses assigned to the web server VM."
  value       = data.hyperv_machine_instance.default.ip_addresses
}

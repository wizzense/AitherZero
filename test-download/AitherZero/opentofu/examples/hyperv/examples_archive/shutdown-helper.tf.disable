###############################################################################
# Null resource to force shutdown VMs on destroy
# Note: We also use 'count = var.number_of_vms' so each VM has its own null resource.
###############################################################################
resource "null_resource" "force_shutdown_vm_on_destroy" {
  # Create a shutdown helper for each VM instance
  count = var.number_of_vms

  triggers = {
    vm_name  = hyperv_machine_instance.control_node_vm[count.index].name
    host     = var.hyperv_host_name
    user     = var.hyperv_user
    password = var.hyperv_password
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<EOT
      curl -k -u "${self.triggers.user}:${self.triggers.password}" \
      -H "Content-Type: application/json" \
      -d '{"PowerShell":"Stop-VM -Name ${self.triggers.vm_name} -TurnOff -Force; while((Get-VM -Name ${self.triggers.vm_name}).State -ne \\"Off\\") { Start-Sleep -s 2 }}"}' \
      https://${self.triggers.host}:5986/wsman
    EOT
  }
}
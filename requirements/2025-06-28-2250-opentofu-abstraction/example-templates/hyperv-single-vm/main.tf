terraform {
  required_version = ">= 1.6.0"
  
  required_providers {
    hyperv = {
      source  = "taliesins/hyperv"
      version = ">= 1.2.1"
    }
  }
}

# Configure the Hyper-V provider
provider "hyperv" {
  host     = var.hyperv_host
  port     = var.hyperv_port
  https    = var.hyperv_https
  insecure = var.hyperv_insecure
  
  # Credentials handled by AitherZero SecureCredentials
  use_ntlm = true
  
  # Timeouts
  timeout = "30m"
  
  # TLS configuration from AitherZero
  tls_server_name = var.hyperv_host
  
  # Certificate configuration
  cacert_path     = var.hyperv_cacert_path
  cert_path       = var.hyperv_cert_path
  key_path        = var.hyperv_key_path
}

# Get the ISO path from AitherZero ISO management
data "external" "iso_path" {
  program = ["pwsh", "-Command", "Get-DeploymentISO", "-Name", var.os_iso, "-AsJson"]
}

# Create the VM
resource "hyperv_vhd" "os_disk" {
  path = "${var.vm_path}/${var.vm_name}/${var.vm_name}_os.vhdx"
  size = var.disk_size_gb * 1024 * 1024 * 1024
  
  block_size           = 0
  logical_sector_size  = 512
  physical_sector_size = 4096
}

resource "hyperv_machine_instance" "vm" {
  name                   = var.vm_name
  generation             = 2
  memory_startup_bytes   = var.memory_gb * 1024 * 1024 * 1024
  memory_minimum_bytes   = 2 * 1024 * 1024 * 1024
  memory_maximum_bytes   = var.memory_gb * 1024 * 1024 * 1024
  processor_count        = var.cpu_count
  
  # State management
  state                  = "Running"
  automatic_start_action = "StartIfRunning"
  automatic_start_delay  = 0
  automatic_stop_action  = "ShutDown"
  
  # Security settings
  enable_secure_boot     = var.enable_secure_boot
  enable_tpm            = var.enable_tpm
  secure_boot_template  = var.enable_secure_boot ? "MicrosoftWindows" : ""
  
  # Checkpoints
  checkpoint_type       = "Production"
  automatic_checkpoints = false
  
  # Guest services
  guest_controlled_cache_types = false
  
  # Integration services
  integration_services = {
    "Guest Service Interface" = true
    "Heartbeat"              = true
    "Key-Value Pair Exchange" = true
    "Shutdown"               = true
    "Time Synchronization"    = true
    "VSS"                    = true
  }
  
  # Network adapter
  network_adaptors {
    name               = "Network Adapter"
    switch_name        = var.network_switch
    dynamic_mac_address = true
  }
  
  # DVD drive for OS installation
  dvd_drives {
    controller_number   = 0
    controller_location = 1
    path               = data.external.iso_path.result.path
  }
  
  # OS disk
  hard_disk_drives {
    controller_type     = "Scsi"
    controller_number   = 0
    controller_location = 0
    path               = hyperv_vhd.os_disk.path
  }
  
  # Boot order
  boot_order = ["DvdDrive", "HardDiskDrive", "NetworkAdapter"]
  
  # VM path
  path = "${var.vm_path}/${var.vm_name}"
  
  # Notes
  notes = jsonencode({
    created_by   = "AitherZero"
    created_date = timestamp()
    template     = "hyperv-single-vm"
    os          = var.os_iso
  })
}

# Post-deployment configuration
resource "null_resource" "post_deployment" {
  depends_on = [hyperv_machine_instance.vm]
  
  provisioner "local-exec" {
    command = <<-EOT
      pwsh -Command "
        Invoke-PostDeploymentConfiguration `
          -VMName '${var.vm_name}' `
          -HyperVHost '${var.hyperv_host}' `
          -ConfigProfile 'standard-server'
      "
    EOT
  }
}
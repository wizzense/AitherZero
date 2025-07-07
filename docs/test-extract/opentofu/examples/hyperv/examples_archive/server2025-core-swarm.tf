###############################################################################
# We assume you already have a hyperv_network_switch resource named "Lan"
# declared elsewhere, like:
#
# resource "hyperv_network_switch" "switch1" {
#   name = "switch1"
# }
#
###############################################################################

###############################################################################
# hyperv_vhd: Create multiple VHD objects (one per VM) with distinct paths
###############################################################################
resource "hyperv_vhd" "control_node_vhd" {
  count = var.number_of_vms

  depends_on = [hyperv_network_switch.switch1]

  # Unique path for each VHD (e.g. ...-0.vhdx, ...-1.vhdx, etc.)
  path = "B:\\hyper-v\\PrimaryControlNode\\PrimaryControlNode-Server2025-${count.index}.vhdx"
  size = 60737421312
}

###############################################################################
# hyperv_machine_instance: Create multiple VMs
###############################################################################
resource "hyperv_machine_instance" "control_node_vm" {
  count = var.number_of_vms

  name                                    = "PrimaryControlNode-Server2025-${count.index}"
  generation                              = 2
  memory_startup_bytes                    = 2147483648 # 2 GB
  memory_maximum_bytes                    = 4294967296 # 4 GB
  memory_minimum_bytes                    = 536870912  # 512 MB
  processor_count                         = 2
  automatic_critical_error_action         = "Pause"
  automatic_critical_error_action_timeout = 30
  automatic_start_action                  = "StartIfRunning"
  automatic_start_delay                   = 0
  automatic_stop_action                   = "Save"
  checkpoint_type                         = "Production"
  guest_controlled_cache_types            = false
  high_memory_mapped_io_space             = 536870912
  low_memory_mapped_io_space              = 134217728
  smart_paging_file_path                  = "C:\\ProgramData\\Microsoft\\Windows\\Hyper-V"
  snapshot_file_location                  = "C:\\ProgramData\\Microsoft\\Windows\\Hyper-V"
  dynamic_memory                          = true
  state                                   = "Running"

  vm_firmware {
    enable_secure_boot              = "Off"
    preferred_network_boot_protocol = "IPv4"
    console_mode                    = "None"
    pause_after_boot_failure        = "Off"
    boot_order {
      boot_type           = "DvdDrive"
      controller_number   = 0
      controller_location = 1
    }
  }

  vm_processor {
    compatibility_for_migration_enabled               = false
    compatibility_for_older_operating_systems_enabled = false
    hw_thread_count_per_core                          = 0
    maximum                                           = 100
    reserve                                           = 0
    relative_weight                                   = 100
    maximum_count_per_numa_node                       = 0
    maximum_count_per_numa_socket                     = 0
    enable_host_resource_protection                   = false
    expose_virtualization_extensions                  = false
  }

  integration_services = {
    "Guest Service Interface" = false
    "Heartbeat"               = true
    "Key-Value Pair Exchange" = true
    "Shutdown"                = true
    "Time Synchronization"    = true
    "VSS"                     = true
  }

  network_adaptors {
    name                = "wan"
    switch_name         = hyperv_network_switch.switch1.name
    management_os       = false
    is_legacy           = false
    dynamic_mac_address = true
  }

  dvd_drives {
    controller_number   = "0"
    controller_location = "1"
    path                = var.iso_path
  }

  hard_disk_drives {
    controller_type                 = "Scsi"
    controller_number               = 0
    controller_location             = 0
    path                            = hyperv_vhd.control_node_vhd[count.index].path
    disk_number                     = 4294967295
    support_persistent_reservations = false
    maximum_iops                    = 0
    minimum_iops                    = 0
    qos_policy_id                   = "00000000-0000-0000-0000-000000000000"
    override_cache_attributes       = "Default"
  }
}
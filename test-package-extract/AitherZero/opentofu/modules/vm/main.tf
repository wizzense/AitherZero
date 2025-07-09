# Module to provision a Hyper-V VM with an attached VHD
# and optional dvd drive for installation media.

terraform {
  required_providers {
    hyperv = {
      source  = "taliesins/hyperv"
      version = ">=1.2.1"
    }
  }
}

resource "hyperv_vhd" "this" {
  count = var.vm_count
  depends_on = [var.switch_dependency]

  # Construct unique VHD path for each VM
  path = "${var.hyperv_vm_path}-${var.vm_name_prefix}-${count.index}.vhdx"
  size = var.vhd_size_bytes
}

resource "hyperv_machine_instance" "this" {
  count = var.vm_count

  name                                    = "${var.vm_name_prefix}-${count.index}"
  generation                              = 2
  memory_startup_bytes                    = var.memory_startup_bytes
  memory_maximum_bytes                    = var.memory_maximum_bytes
  memory_minimum_bytes                    = var.memory_minimum_bytes
  processor_count                         = var.processor_count
  automatic_critical_error_action         = "Pause"
  automatic_critical_error_action_timeout = 30
  automatic_start_action                  = "StartIfRunning"
  automatic_start_delay                   = 0
  automatic_stop_action                   = "Save"
  checkpoint_type                         = "Production"
  guest_controlled_cache_types            = false
  high_memory_mapped_io_space             = 536870912
  low_memory_mapped_io_space              = 134217728
  smart_paging_file_path                  = "C:/ProgramData/Microsoft/Windows/Hyper-V"
  snapshot_file_location                  = "C:/ProgramData/Microsoft/Windows/Hyper-V"
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
    name                = var.switch_name
    switch_name         = var.switch_name
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
    path                            = hyperv_vhd.this[count.index].path
    disk_number                     = 4294967295
    support_persistent_reservations = false
    maximum_iops                    = 0
    minimum_iops                    = 0
    qos_policy_id                   = "00000000-0000-0000-0000-000000000000"
    override_cache_attributes       = "Default"
  }
}

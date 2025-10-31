# Number of VMs to create
variable "vm_count" {
  type    = number
}

# Prefix for VM names and VHD files
variable "vm_name_prefix" {
  type = string
}

# Path on the Hyper-V host where VHDs are stored
variable "hyperv_vm_path" {
  type = string
}

# Size of the VHD in bytes
variable "vhd_size_bytes" {
  type = number
}

# ISO used for the DVD drive
variable "iso_path" {
  type = string
}

# Switch used to attach the VM network adaptor
variable "switch_name" {
  type = string
}

# Switch resource to depend on to ensure switch exists
variable "switch_dependency" {
  type = any
}

# VM resource settings
variable "memory_startup_bytes" {
  type = number
}

variable "memory_maximum_bytes" {
  type = number
}

variable "memory_minimum_bytes" {
  type = number
}

variable "processor_count" {
  type = number
}

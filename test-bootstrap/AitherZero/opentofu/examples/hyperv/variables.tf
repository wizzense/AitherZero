###############################################################################
# Optionally store host/user/password as variables if you want to reference
# them in the shutdown script. Adjust defaults/values as needed.
###############################################################################
variable "hyperv_host_name" {
  type    = string
  default = "192.168.1.121"
}

variable "hyperv_user" {
  type    = string
  default = "ad\\administrator"
}

variable "hyperv_password" {
  type    = string
  default = ""
}

variable "hyperv_vm_path" {
  type = string
  default = "B:\\hyper-v\\"
}

###############################################################################
# Network switch configuration
###############################################################################
variable "wan_switch_name" {
  type    = string
  default = "wan"
}

variable "wan_adapter_names" {
  type    = list(string)
  default = ["Ethernet"]
}

variable "server_2025_iso_path" {
    type  = string
    default = "\\B:\\share\\isos\\core_windows_server_2025_feb_2025_CustomWinISO.iso"
}

variable "tanos_iso_path" {
    type  = string
    default = "\\B:\\share\\isos\\TanOS.1.8.3.0125-DEV.iso"
}

variable "win_10_iso_path" {
    type  = string
    default = "\\B:\\share\\isos\\en-us_windows_10_business_editions_version_22h2_updated_june_2024_x64_dvd_c27b7955.iso"
}

variable "win_11_iso_path" {
    type  = string
    default = "\\B:\\share\\isos\\en-us_windows_11_business_editions_version_22h2_updated_june_2024_x64_dvd_969336fe.iso"
}

variable "rocky_94_iso_path" {
    type  = string
    default = "\\B:\\share\\isos\\Rocky-9.4-x86_64-dvd.iso"
}



###############################################################################
# Number of VMs to create
###############################################################################
variable "tanos_vm_count" {
  type    = number
  default = 4
}

variable "windows_server_core_vm_count" {
  type    = number
  default = 2
}

variable "windows_11_vm_count" {
  type    = number
  default = 1
}

variable "rocky_94_vm_count" {
  type    = number
  default = 2
}

variable "windows_10_vm_count" {
  type    = number
  default = 1
}

# VM Configuration Variables
variable "vm_name" {
  description = "Name of the virtual machine"
  type        = string
  validation {
    condition     = can(regex("^[a-zA-Z0-9-]{1,15}$", var.vm_name))
    error_message = "VM name must be 1-15 characters, alphanumeric and hyphens only"
  }
}

variable "hyperv_host" {
  description = "Hyper-V host to deploy to"
  type        = string
  default     = "localhost"
}

variable "cpu_count" {
  description = "Number of virtual CPUs"
  type        = number
  default     = 4
  validation {
    condition     = var.cpu_count >= 1 && var.cpu_count <= 32
    error_message = "CPU count must be between 1 and 32"
  }
}

variable "memory_gb" {
  description = "Memory in GB"
  type        = number
  default     = 8
  validation {
    condition     = var.memory_gb >= 2 && var.memory_gb <= 128
    error_message = "Memory must be between 2 and 128 GB"
  }
}

variable "disk_size_gb" {
  description = "OS disk size in GB"
  type        = number
  default     = 127
  validation {
    condition     = var.disk_size_gb >= 32 && var.disk_size_gb <= 2048
    error_message = "Disk size must be between 32 and 2048 GB"
  }
}

variable "network_switch" {
  description = "Virtual switch name"
  type        = string
  default     = "Default Switch"
}

variable "os_iso" {
  description = "Operating system ISO selection"
  type        = string
  default     = "WindowsServer2025"
  validation {
    condition = contains([
      "WindowsServer2025",
      "WindowsServer2022",
      "WindowsServer2019"
    ], var.os_iso)
    error_message = "OS ISO must be WindowsServer2025, WindowsServer2022, or WindowsServer2019"
  }
}

variable "enable_secure_boot" {
  description = "Enable secure boot"
  type        = bool
  default     = true
}

variable "enable_tpm" {
  description = "Enable virtual TPM"
  type        = bool
  default     = true
}

variable "timezone" {
  description = "System timezone"
  type        = string
  default     = "Pacific Standard Time"
}

variable "admin_password" {
  description = "Local administrator password"
  type        = string
  sensitive   = true
  validation {
    condition     = length(var.admin_password) >= 12
    error_message = "Admin password must be at least 12 characters"
  }
}

# Hyper-V Provider Configuration
variable "hyperv_port" {
  description = "WinRM port for Hyper-V host"
  type        = number
  default     = 5986
}

variable "hyperv_https" {
  description = "Use HTTPS for WinRM"
  type        = bool
  default     = true
}

variable "hyperv_insecure" {
  description = "Allow insecure connections"
  type        = bool
  default     = false
}

variable "hyperv_cacert_path" {
  description = "Path to CA certificate"
  type        = string
  default     = ""
}

variable "hyperv_cert_path" {
  description = "Path to client certificate"
  type        = string
  default     = ""
}

variable "hyperv_key_path" {
  description = "Path to client key"
  type        = string
  default     = ""
}

# VM Storage Configuration
variable "vm_path" {
  description = "Base path for VM storage"
  type        = string
  default     = "C:\\Hyper-V\\Virtual Machines"
}
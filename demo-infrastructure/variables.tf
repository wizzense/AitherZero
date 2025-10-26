# AitherZero Infrastructure Variables

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "East US"
}

variable "hyperv_host" {
  description = "Hyper-V host address"
  type        = string
  default     = "localhost"
}

variable "hyperv_password" {
  description = "Hyper-V host password"
  type        = string
  sensitive   = true
  default     = ""
}

variable "resource_tags" {
  description = "Common resource tags"
  type        = map(string)
  default = {
    Project     = "AitherZero"
    ManagedBy   = "OpenTofu"
    Environment = "Development"
  }
}

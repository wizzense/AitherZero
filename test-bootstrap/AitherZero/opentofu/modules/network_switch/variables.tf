variable "name" {
  type = string
}

variable "allow_management_os" {
  type    = bool
  default = true
}

variable "switch_type" {
  type    = string
  default = "External"
}

variable "net_adapter_names" {
  type = list(string)
}

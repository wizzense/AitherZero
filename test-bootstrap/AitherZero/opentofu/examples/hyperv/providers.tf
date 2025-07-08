# Hyper-V provider configuration
# Credentials and host details are supplied via variables for easy override.

provider "hyperv" {
  user            = var.hyperv_user
  password        = var.hyperv_password
  host            = var.hyperv_host_name
  port            = 5986
  https           = true

  insecure        = false
  use_ntlm        = true
  tls_server_name = var.hyperv_host_name
  cacert_path     = "certs/rootca.pem"
  cert_path       = "certs/host.pem"
  key_path        = "certs/host-key.pem"

  script_path     = "C:/Temp/tofu_%RAND%.cmd"
  timeout         = "30s"
}


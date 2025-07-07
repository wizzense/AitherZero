terraform {
  required_providers {
    hyperv = {
      source  = "taliesins/hyperv"
      version = "1.2.1"
    }
  }
}

provider "hyperv" {
  user            = "ad\\administrator"
  password        = ""
  host            = "192.168.1.121"
  port            = 5986
  https           = true
  insecure        = true # This skips SSL validation
  use_ntlm        = true # Use NTLM as it's enabled on the WinRM service
  tls_server_name = ""
  cacert_path     = "" # Leave empty if skipping SSL validation
  cert_path       = "" # Leave empty if skipping SSL validation
  key_path        = "" # Leave empty if skipping SSL validation
  script_path     = "C:/Temp/tofu_%RAND%.cmd"
  timeout         = "30s"
}

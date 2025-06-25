function New-TaliesinsProviderConfig {
    <#
    .SYNOPSIS
    Creates a new Taliesins provider configuration.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Configuration,

        [Parameter()]
        [string]$ProviderVersion = '1.2.1',

        [Parameter()]
        [string]$CertificatePath
    )

    try {
        # Extract Hyper-V configuration
        $hypervConfig = $Configuration.hyperv

        if (-not $hypervConfig) {
            throw "Hyper-V configuration not found in provided configuration"
        }

        # Build main configuration
        $mainConfig = @"
terraform {
  required_version = ">= 1.6.0"
  required_providers {
    hyperv = {
      source  = "taliesins/hyperv"
      version = "~> $ProviderVersion"
    }
  }
}

provider "hyperv" {
  user            = var.hyperv_user
  password        = var.hyperv_password
  host            = var.hyperv_host
  port            = var.hyperv_port
  https           = var.hyperv_https
  insecure        = var.hyperv_insecure
  use_ntlm        = var.hyperv_use_ntlm
  tls_server_name = var.hyperv_tls_server_name
  script_path     = var.hyperv_script_path
  timeout         = var.hyperv_timeout
"@

        # Add certificate paths if provided
        if ($CertificatePath) {
            $mainConfig += @"

  cacert_path     = var.hyperv_cacert_path
  cert_path       = var.hyperv_cert_path
  key_path        = var.hyperv_key_path
"@
        }

        $mainConfig += @"

}
"@

        # Build variables configuration
        $variablesConfig = @"
variable "hyperv_user" {
  description = "Hyper-V host username"
  type        = string
  sensitive   = true
}

variable "hyperv_password" {
  description = "Hyper-V host password"
  type        = string
  sensitive   = true
}

variable "hyperv_host" {
  description = "Hyper-V host address"
  type        = string
  default     = "$($hypervConfig.host)"
}

variable "hyperv_port" {
  description = "Hyper-V WinRM port"
  type        = number
  default     = $($hypervConfig.port -or 5986)
}

variable "hyperv_https" {
  description = "Use HTTPS for Hyper-V connection"
  type        = bool
  default     = $($hypervConfig.https -or $true)
}

variable "hyperv_insecure" {
  description = "Skip certificate verification (not recommended)"
  type        = bool
  default     = $($hypervConfig.insecure -or $false)
}

variable "hyperv_use_ntlm" {
  description = "Use NTLM authentication"
  type        = bool
  default     = $($hypervConfig.use_ntlm -or $true)
}

variable "hyperv_tls_server_name" {
  description = "TLS server name for certificate verification"
  type        = string
  default     = "$($hypervConfig.tls_server_name -or $hypervConfig.host)"
}

variable "hyperv_script_path" {
  description = "Remote script execution path"
  type        = string
  default     = "$($hypervConfig.script_path -or 'C:/Temp/tofu_%RAND%.cmd')"
}

variable "hyperv_timeout" {
  description = "Connection timeout"
  type        = string
  default     = "$($hypervConfig.timeout -or '30s')"
}
"@

        # Add certificate variables if provided
        if ($CertificatePath) {
            $variablesConfig += @"

variable "hyperv_cacert_path" {
  description = "Path to CA certificate"
  type        = string
  default     = "$($hypervConfig.cacert_path -or "$CertificatePath-ca.pem")"
}

variable "hyperv_cert_path" {
  description = "Path to client certificate"
  type        = string
  default     = "$($hypervConfig.cert_path -or "$CertificatePath-cert.pem")"
}

variable "hyperv_key_path" {
  description = "Path to client private key"
  type        = string
  default     = "$($hypervConfig.key_path -or "$CertificatePath-key.pem")"
}
"@
        }

        return @{
            MainConfig = $mainConfig
            VariablesConfig = $variablesConfig
            ProviderVersion = $ProviderVersion
            CertificatesConfigured = ($null -ne $CertificatePath)
        }

    } catch {
        throw "Failed to generate Taliesins provider configuration: $($_.Exception.Message)"
    }
}

function Invoke-OpenTofuCommand {
    <#
    .SYNOPSIS
    Executes OpenTofu commands safely.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Command,

        [Parameter()]
        [string]$WorkingDirectory = (Get-Location),

        [Parameter()]
        [hashtable]$Environment = @{},

        [Parameter()]
        [int]$TimeoutSeconds = 300
    )

    try {
        # Validate OpenTofu installation
        $opentofu = Get-Command 'tofu' -ErrorAction SilentlyContinue
        if (-not $opentofu) {
            throw "OpenTofu (tofu) command not found. Ensure OpenTofu is installed and in PATH."
        }
          # Prepare environment
        $envVars = @{}
        foreach ($envVar in (Get-ChildItem env:)) {
            $envVars[$envVar.Name] = $envVar.Value
        }
        foreach ($key in $Environment.Keys) {
            $envVars[$key] = $Environment[$key]
        }
          # Execute command
        Write-CustomLog -Level 'INFO' -Message "Executing OpenTofu command: tofu $Command in $WorkingDirectory"

        $startInfo = New-Object System.Diagnostics.ProcessStartInfo
        $startInfo.FileName = $opentofu.Source
        $startInfo.Arguments = $Command
        $startInfo.WorkingDirectory = $WorkingDirectory
        $startInfo.RedirectStandardOutput = $true
        $startInfo.RedirectStandardError = $true
        $startInfo.UseShellExecute = $false
        $startInfo.CreateNoWindow = $true

        # Set environment variables
        foreach ($envVar in $envVars.GetEnumerator()) {
            $startInfo.Environment[$envVar.Key] = $envVar.Value
        }

        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $startInfo

        $stdout = New-Object System.Text.StringBuilder
        $stderr = New-Object System.Text.StringBuilder

        Register-ObjectEvent -InputObject $process -EventName OutputDataReceived -Action {
            if ($Event.SourceEventArgs.Data) {
                $Event.MessageData.AppendLine($Event.SourceEventArgs.Data)
            }
        } -MessageData $stdout | Out-Null

        Register-ObjectEvent -InputObject $process -EventName ErrorDataReceived -Action {
            if ($Event.SourceEventArgs.Data) {
                $Event.MessageData.AppendLine($Event.SourceEventArgs.Data)
            }
        } -MessageData $stderr | Out-Null

        $process.Start() | Out-Null
        $process.BeginOutputReadLine()
        $process.BeginErrorReadLine()
          if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
            $process.Kill()
            throw "OpenTofu command timed out after $TimeoutSeconds seconds"
        }

        $exitCode = $process.ExitCode
        $standardOutput = $stdout.ToString()
        $standardError = $stderr.ToString()

        # Clean up event handlers
        Get-EventSubscriber | Where-Object { $_.SourceObject -eq $process } | Unregister-Event

        if ($exitCode -eq 0) {
            Write-CustomLog -Level 'SUCCESS' -Message "OpenTofu command completed successfully"
            return @{
                Success = $true
                ExitCode = $exitCode
                Output = $standardOutput
                Error = $standardError
            }
        } else {
            Write-CustomLog -Level 'ERROR' -Message "OpenTofu command failed with exit code: $exitCode"
            return @{
                Success = $false
                ExitCode = $exitCode
                Output = $standardOutput
                Error = $standardError
            }
        }

    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to execute OpenTofu command: $($_.Exception.Message)"
        return @{
            Success = $false
            ExitCode = -1
            Output = ""
            Error = $_.Exception.Message
        }
    }
}

function Test-TaliesinsProviderInstallation {
    <#
    .SYNOPSIS
    Validates Taliesins provider installation.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$ProviderVersion = '1.2.1'
    )

    try {
        # Check for provider in .terraform directory
        $terraformDir = Join-Path (Get-Location) ".terraform"
        $providerPath = Join-Path $terraformDir "providers/registry.opentofu.org/taliesins/hyperv/$ProviderVersion"

        if (-not (Test-Path $terraformDir)) {
            return @{
                Success = $false
                Error = "OpenTofu not initialized. Run 'tofu init' first."
                ProviderFound = $false
            }
        }

        if (-not (Test-Path $providerPath)) {
            return @{
                Success = $false
                Error = "Taliesins provider version $ProviderVersion not found"
                ProviderFound = $false
            }
        }

        # Check for provider binary
        $providerBinary = if ($IsWindows) { "terraform-provider-hyperv_v$ProviderVersion.exe" } else { "terraform-provider-hyperv_v$ProviderVersion" }
        $binaryPath = Get-ChildItem -Path $providerPath -Recurse -Name $providerBinary -ErrorAction SilentlyContinue

        if (-not $binaryPath) {
            return @{
                Success = $false
                Error = "Taliesins provider binary not found"
                ProviderFound = $true
                BinaryFound = $false
            }
        }

        Write-CustomLog -Level 'SUCCESS' -Message "Taliesins provider $ProviderVersion installation verified"
        return @{
            Success = $true
            ProviderVersion = $ProviderVersion
            ProviderPath = $providerPath
            BinaryPath = $binaryPath
            ProviderFound = $true
            BinaryFound = $true
        }

    } catch {
        return @{
            Success = $false
            Error = $_.Exception.Message
            ProviderFound = $false
        }
    }
}

function ConvertTo-HCL {
    <#
    .SYNOPSIS
    Converts configuration object to HCL format.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Configuration
    )

    # This is a simplified HCL converter
    # In production, you might want to use a proper HCL library

    $hcl = ""

    foreach ($key in $Configuration.Keys) {
        $value = $Configuration[$key]

        if ($value -is [hashtable]) {
            $hcl += "$key {`n"
            $hcl += ConvertTo-HCLSection -Section $value -Indent "  "
            $hcl += "}`n`n"
        } else {
            $hcl += "$key = $(ConvertTo-HCLValue -Value $value)`n"
        }
    }

    return $hcl
}

function ConvertTo-HCLSection {
    <#
    .SYNOPSIS
    Converts a hashtable section to HCL format with indentation.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Section,

        [Parameter()]
        [string]$Indent = ""
    )

    $hcl = ""

    foreach ($key in $Section.Keys) {
        $value = $Section[$key]

        if ($value -is [hashtable]) {
            $hcl += "$Indent$key {`n"
            $hcl += ConvertTo-HCLSection -Section $value -Indent "$Indent  "
            $hcl += "$Indent}`n"
        } else {
            $hcl += "$Indent$key = $(ConvertTo-HCLValue -Value $value)`n"
        }
    }

    return $hcl
}

function ConvertTo-HCLValue {
    <#
    .SYNOPSIS
    Converts a value to proper HCL format.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        $Value
    )

    if ($null -eq $Value) {
        return "null"
    } elseif ($Value -is [bool]) {
        return $Value.ToString().ToLower()
    } elseif ($Value -is [int] -or $Value -is [double]) {
        return $Value.ToString()
    } elseif ($Value -is [string]) {
        return "`"$Value`""
    } elseif ($Value -is [array]) {
        $items = $Value | ForEach-Object { ConvertTo-HCLValue -Value $_ }
        return "[$(($items -join ', '))]"
    } else {
        return "`"$($Value.ToString())`""
    }
}
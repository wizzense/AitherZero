#Requires -Version 7.0
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory, ValueFromPipeline)]
    [object]$Config
)

Import-Module "$env:PWSH_MODULES_PATH/LabRunner/" -Force
Import-Module "$env:PROJECT_ROOT/core-runner/modules/Logging" -Force

Write-CustomLog "Starting $($MyInvocation.MyCommand.Name)"

Invoke-LabStep -Config $Config -Body {
    Write-CustomLog "Running $($MyInvocation.MyCommand.Name)"
    <#
.SYNOPSIS
  Initialize OpenTofu using Hyper-V settings from config.json.

.DESCRIPTION
  - Reads InfraRepoUrl and InfraRepoPath from the passed-in config.
  - If InfraRepoUrl is provided, it clones the repo directly into InfraRepoPath.
  - Otherwise, generates a main.tf using Hyper-V config.
  - Checks that the tofu command is available, and if not, adds the known installation folder to PATH.
  - Runs 'tofu init' to initialize OpenTofu in InfraRepoPath.
#>


    if ($Config.InitializeOpenTofu -eq $true) {


        Write-CustomLog '---- Hyper-V Configuration Check ----'
        Write-CustomLog 'Final Hyper-V configuration:'
        $Config.HyperV | Format-List        # --------------------------------------------------
        # 1) Determine infra repo path
        # --------------------------------------------------
        $infraRepoUrl = $Config.InfraRepoUrl
        $infraRepoPath = $Config.InfraRepoPath
        
        # Fallback if InfraRepoPath is not specified
        if ([string]::IsNullOrWhiteSpace($infraRepoPath)) {
            $infraRepoPath = Join-Path $scriptRoot 'my-infra'
        }

        Write-CustomLog "Using InfraRepoPath: $infraRepoPath"

        # Ensure local directory exists
        if (Test-Path $infraRepoPath) {
            Write-CustomLog "Directory already exists: $infraRepoPath"
        } else {
            if (-not (Test-Path $infraRepoPath)) { New-Item -ItemType Directory -Path $infraRepoPath -Force | Out-Null }
            Write-CustomLog "Created directory: $infraRepoPath"
        }
        
        # --------------------------------------------------
        # 2) If InfraRepoUrl is given, clone directly to InfraRepoPath
        # --------------------------------------------------
        if (-not [string]::IsNullOrWhiteSpace($infraRepoUrl)) {
            Write-CustomLog "InfraRepoUrl detected: $infraRepoUrl"

            if (Test-Path (Join-Path $infraRepoPath '.git')) {
                Write-CustomLog 'Directory exists. Pulling latest changes...'
                git -C $infraRepoPath pull
            } else {
                Write-CustomLog "Repository not found. Cloning $infraRepoUrl to $infraRepoPath..."
                gh repo clone $infraRepoUrl $infraRepoPath
                if ($LASTEXITCODE -ne 0) {
                    Write-Error "ERROR: Failed to clone $infraRepoUrl"
                    exit 1
                }
            }
        } else {
            Write-CustomLog 'No InfraRepoUrl provided. Using local or default .tf files.'

            # If no main.tf found, create one from Hyper-V config
            $tfFile = Join-Path -Path $infraRepoPath -ChildPath 'main.tf'
            if (-not (Test-Path $tfFile)) {
                Write-CustomLog 'No main.tf found; creating main.tf using Hyper-V configuration...'
                $tfContent = @'
terraform {
  required_providers {
    hyperv = {
      source  = "taliesins/hyperv"
      version = "1.2.1"
    }
  }
}
'@
                Set-Content -Path $tfFile -Value $tfContent
                Write-CustomLog "Created main.tf at $tfFile"
            } else {
                Write-CustomLog 'main.tf already exists; not overwriting.'
            }


            # If no provider.tf found, create one from Hyper-V config
            $ProviderFile = Join-Path -Path $infraRepoPath -ChildPath 'providers.tf'
            if (-not (Test-Path $ProviderFile)) {
                Write-CustomLog 'No providers.tf found; creating providers.tf using Hyper-V configuration...'
                $tfContent = @"

provider "hyperv" {
  user            = "$($Config.HyperV.User)"
  password        = "$($Config.HyperV.Password)"
  host            = "$($Config.HyperV.Host)"
  port            = $($Config.HyperV.Port)
  https           = $($Config.HyperV.Https.ToString().ToLower())
  insecure        = $($Config.HyperV.Insecure.ToString().ToLower())
  use_ntlm        = $($Config.HyperV.UseNtlm.ToString().ToLower())
  tls_server_name = "$($Config.HyperV.TlsServerName)"
  cacert_path     = "$($Config.HyperV.CacertPath)"
  cert_path       = "$($Config.HyperV.CertPath)"
  key_path        = "$($Config.HyperV.KeyPath)"
  script_path     = "$($Config.HyperV.ScriptPath)"
  timeout         = "$($Config.HyperV.Timeout)"
}
"@
                Set-Content -Path $ProviderFile -Value $tfContent
                Write-CustomLog "Created providers.tf at $ProviderFile"
            } else {
                Write-CustomLog 'providers.tf already exists; not overwriting.'
            }
        }

        # --------------------------------------------------
        # 3) Check if tofu is in the PATH. If not, attempt install and/or add it.
        # --------------------------------------------------
        $tofuCmd = Get-Command tofu -ErrorAction SilentlyContinue
        if (-not $tofuCmd) {
            $defaultTofuExe = Join-Path $env:LOCALAPPDATA -ChildPath 'Programs\\OpenTofu\\tofu.exe'
            if (Test-Path $defaultTofuExe) {
                Write-CustomLog 'Tofu command not found in PATH. Adding its folder to the session PATH...'
                $tofuFolder = Split-Path -Path $defaultTofuExe
                $env:PATH = "$env:PATH;$tofuFolder"
                $tofuCmd = Get-Command tofu -ErrorAction SilentlyContinue
                if (-not $tofuCmd) {
                    Write-Warning 'Even after updating PATH, tofu command is not recognized.'
                } else {
                    Write-CustomLog "Tofu command found: $($tofuCmd.Path)"
                }    
            } else {
                Write-Warning "Tofu executable not found at $defaultTofuExe. Attempting installation..."
                $cosign = Join-Path $Config.CosignPath 'cosign-windows-amd64.exe'
                $version = if ($Config.OpenTofuVersion) { $Config.OpenTofuVersion } else { 'latest' }
                
                if (Get-Command Invoke-OpenTofuInstaller -ErrorAction SilentlyContinue) {
                    Invoke-OpenTofuInstaller -CosignPath $cosign -OpenTofuVersion $version
                } else {
                    throw "Cannot install OpenTofu because the installer function 'Invoke-OpenTofuInstaller' is not available."
                }

                $tofuCmd = Get-Command tofu -ErrorAction SilentlyContinue
                if (-not $tofuCmd) {
                    throw 'Tofu still not found after installation. Please ensure OpenTofu is installed and in PATH.'
                }
            }
        }

        # --------------------------------------------------
        # 4) Run tofu init in InfraRepoPath
        # --------------------------------------------------
        Write-CustomLog "Initializing OpenTofu in $infraRepoPath..."
        Push-Location $infraRepoPath
        $exitCode = 0
        try {
            tofu init
        } catch {
            Write-Error "Failed to run 'tofu init'. Ensure OpenTofu is installed and available in the PATH."
            $exitCode = 1
        } finally {
            Pop-Location
        }
        if ($exitCode -ne 0) { exit $exitCode }

        Write-CustomLog 'OpenTofu initialized successfully.'

        Write-CustomLog @"
NEXT STEPS:
1. Check or edit the .tf files in '$infraRepoPath'.
2. You may need to modify variables.tf to match your Hyper-V configuration.
 - Set host, user, password, etc. to match your Hyper-V settings.
3. Run 'tofu plan' to preview changes.
4. Run 'tofu apply' to provision resources.
"@

        # Optionally place you in $infraRepoPath at the end
        Set-Location $infraRepoPath
        exit 0

    } else {
        Write-CustomLog 'InitializeOpenTofu flag is disabled. Skipping initialization.'
    }
    Write-CustomLog "Completed $($MyInvocation.MyCommand.Name)"
}
Write-CustomLog "Completed $($MyInvocation.MyCommand.Name)"
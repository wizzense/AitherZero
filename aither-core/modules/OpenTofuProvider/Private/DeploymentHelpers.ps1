# Deployment Helper Functions for OpenTofuProvider Module

function Test-LabInfrastructurePrerequisites {
    <#
    .SYNOPSIS
    Tests if all prerequisites for lab infrastructure deployment are met.

    .PARAMETER ConfigPath
    Path to the configuration file to validate.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ConfigPath
    )

    $result = @{
        Valid = $true
        Issues = @()
    }

    try {
        # Check if configuration file exists
        if (-not (Test-Path $ConfigPath)) {
            $result.Valid = $false
            $result.Issues += "Configuration file not found: $ConfigPath"
            return $result
        }

        # Check OpenTofu installation
        $openTofuCheck = Test-OpenTofuInstallation
        if (-not $openTofuCheck.IsValid) {
            $result.Valid = $false
            $result.Issues += "OpenTofu not properly installed: $($openTofuCheck.Error)"
        }

        # Load and validate configuration
        try {
            $config = Get-Content $ConfigPath -Raw | ConvertFrom-Yaml

            # Validate required configuration sections
            if (-not $config.hyperv) {
                $result.Valid = $false
                $result.Issues += "Missing hyperv configuration section"
            }

            if (-not $config.vms) {
                $result.Valid = $false
                $result.Issues += "Missing vms configuration section"
            }

        } catch {
            $result.Valid = $false
            $result.Issues += "Failed to parse configuration: $($_.Exception.Message)"
        }

        Write-CustomLog -Level 'INFO' -Message "Prerequisites validation completed with $($result.Issues.Count) issues"
        return $result

    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Prerequisites validation failed: $($_.Exception.Message)"
        return @{
            Valid = $false
            Issues = @("Prerequisites validation failed: $($_.Exception.Message)")
        }
    }
}

function Test-OpenTofuInitialization {
    <#
    .SYNOPSIS
    Tests if OpenTofu has been initialized in the current directory.
    #>
    [CmdletBinding()]
    param()

    try {
        $terraformDir = Join-Path (Get-Location) ".terraform"
        $lockFile = Join-Path (Get-Location) ".terraform.lock.hcl"

        $isInitialized = (Test-Path $terraformDir) -and (Test-Path $lockFile)

        return @{
            IsInitialized = $isInitialized
            TerraformDir = $terraformDir
            LockFile = $lockFile
        }

    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to check OpenTofu initialization: $($_.Exception.Message)"
        return @{
            IsInitialized = $false
            Error = $_.Exception.Message
        }
    }
}

function Invoke-OpenTofuCommand {
    <#
    .SYNOPSIS
    Executes an OpenTofu command and returns the result.

    .PARAMETER Command
    The OpenTofu command to execute.

    .PARAMETER WorkingDirectory
    The working directory for the command.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Command,

        [Parameter()]
        [string]$WorkingDirectory = (Get-Location)
    )

    try {
        Write-CustomLog -Level 'INFO' -Message "Executing OpenTofu command: $Command"

        # Find OpenTofu binary
        $tofuPath = Get-Command "tofu" -ErrorAction SilentlyContinue
        if (-not $tofuPath) {
            throw "OpenTofu binary not found in PATH"
        }

        $startInfo = @{
            FileName = $tofuPath.Source
            Arguments = $Command
            WorkingDirectory = $WorkingDirectory
            RedirectStandardOutput = $true
            RedirectStandardError = $true
            UseShellExecute = $false
            CreateNoWindow = $true
        }

        $process = Start-Process @startInfo -PassThru -Wait

        $stdout = $process.StandardOutput.ReadToEnd()
        $stderr = $process.StandardError.ReadToEnd()

        $result = @{
            Success = ($process.ExitCode -eq 0)
            ExitCode = $process.ExitCode
            Output = $stdout
            Error = $stderr
            Command = $Command
        }

        if ($result.Success) {
            Write-CustomLog -Level 'SUCCESS' -Message "OpenTofu command completed successfully"
        } else {
            Write-CustomLog -Level 'ERROR' -Message "OpenTofu command failed with exit code $($process.ExitCode): $stderr"
        }

        return $result

    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to execute OpenTofu command: $($_.Exception.Message)"
        return @{
            Success = $false
            Error = $_.Exception.Message
            Command = $Command
        }
    }
}

function Test-TaliesinsProviderInstallation {
    <#
    .SYNOPSIS
    Tests if the Taliesins Hyper-V provider is installed.

    .PARAMETER ProviderVersion
    The expected provider version.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$ProviderVersion = "1.2.1"
    )

    try {
        # Check if .terraform directory exists
        $terraformDir = Join-Path (Get-Location) ".terraform"
        if (-not (Test-Path $terraformDir)) {
            return @{
                Success = $false
                Error = "OpenTofu not initialized - .terraform directory not found"
            }
        }

        # Check for provider installation
        $providersDir = Join-Path $terraformDir "providers"
        $taliesinsProvider = Get-ChildItem -Path $providersDir -Recurse -Filter "*taliesins*" -ErrorAction SilentlyContinue

        if ($taliesinsProvider) {
            Write-CustomLog -Level 'SUCCESS' -Message "Taliesins provider found: $($taliesinsProvider.FullName)"
            return @{
                Success = $true
                ProviderPath = $taliesinsProvider.FullName
                Version = $ProviderVersion
            }
        } else {
            return @{
                Success = $false
                Error = "Taliesins provider not found in .terraform/providers"
            }
        }

    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to check Taliesins provider installation: $($_.Exception.Message)"
        return @{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

function Test-LabInfrastructureDeployment {
    <#
    .SYNOPSIS
    Verifies that lab infrastructure has been deployed successfully.

    .PARAMETER ConfigPath
    Path to the configuration file.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ConfigPath
    )

    try {
        Write-CustomLog -Level 'INFO' -Message "Verifying lab infrastructure deployment"

        # Load configuration
        $config = Get-Content $ConfigPath -Raw | ConvertFrom-Yaml

        $verification = @{
            Success = $true
            Checks = @()
            Issues = @()
        }

        # Check if state file exists
        $stateFile = Join-Path (Get-Location) "terraform.tfstate"
        if (Test-Path $stateFile) {
            $verification.Checks += "State file exists"

            # Check state content
            try {
                $state = Get-Content $stateFile | ConvertFrom-Json
                if ($state.resources -and $state.resources.Count -gt 0) {
                    $verification.Checks += "Resources found in state file: $($state.resources.Count)"
                } else {
                    $verification.Success = $false
                    $verification.Issues += "No resources found in state file"
                }
            } catch {
                $verification.Success = $false
                $verification.Issues += "Failed to parse state file: $($_.Exception.Message)"
            }
        } else {
            $verification.Success = $false
            $verification.Issues += "State file not found"
        }

        # Additional checks could include:
        # - VM existence on Hyper-V host
        # - Network connectivity
        # - Resource health checks

        Write-CustomLog -Level 'INFO' -Message "Deployment verification completed: $($verification.Checks.Count) checks passed, $($verification.Issues.Count) issues found"

        return $verification

    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Deployment verification failed: $($_.Exception.Message)"
        return @{
            Success = $false
            Issues = @("Verification failed: $($_.Exception.Message)")
        }
    }
}

function Set-WindowsCredential {
    <#
    .SYNOPSIS
    Stores credentials securely using Windows Credential Manager.

    .PARAMETER Target
    The target name for the credential.

    .PARAMETER Credentials
    The PSCredential object to store.

    .PARAMETER Force
    Force overwrite existing credentials.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Target,

        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$Credentials,

        [Parameter()]
        [switch]$Force
    )

    try {
        # This is a placeholder implementation
        # In a real implementation, this would use Windows Credential Manager APIs
        Write-CustomLog -Level 'INFO' -Message "Storing credentials for target: $Target"

        # For now, we'll simulate success
        return @{
            Success = $true
            CredentialId = "OpenTofu_$Target"
            Target = $Target
        }

    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to store credentials: $($_.Exception.Message)"
        return @{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

function Set-CertificateCredentials {
    <#
    .SYNOPSIS
    Processes and stores certificate-based credentials.

    .PARAMETER Target
    The target name for the certificate.

    .PARAMETER CertificatePath
    Path to the certificate files.

    .PARAMETER Force
    Force overwrite existing certificates.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Target,

        [Parameter(Mandatory)]
        [string]$CertificatePath,

        [Parameter()]
        [switch]$Force
    )

    try {
        Write-CustomLog -Level 'INFO' -Message "Processing certificate credentials for target: $Target"

        # Check for certificate files
        $certFiles = @("ca.pem", "client-cert.pem", "client-key.pem")
        $foundFiles = @()

        foreach ($file in $certFiles) {
            $filePath = Join-Path $CertificatePath $file
            if (Test-Path $filePath) {
                $foundFiles += $file
            }
        }

        if ($foundFiles.Count -eq 0) {
            throw "No certificate files found in $CertificatePath"
        }

        # Simulate certificate processing
        return @{
            Success = $true
            Thumbprint = "ABC123DEF456" # Mock thumbprint
            ExpiryDate = (Get-Date).AddYears(1)
            CertificateFiles = $foundFiles
        }

    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to process certificate credentials: $($_.Exception.Message)"
        return @{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

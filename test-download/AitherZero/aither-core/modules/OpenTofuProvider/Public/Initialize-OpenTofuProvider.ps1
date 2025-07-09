function Initialize-OpenTofuProvider {
    <#
    .SYNOPSIS
    Initializes OpenTofu with secure Taliesins provider configuration.

    .DESCRIPTION
    Sets up OpenTofu environment with proper Taliesins Hyper-V provider integration,
    including secure authentication, certificate management, and provider configuration.

    .PARAMETER ConfigPath
    Path to the lab configuration file (YAML format).

    .PARAMETER ProviderVersion
    Taliesins provider version to use. Defaults to latest stable.

    .PARAMETER CertificatePath
    Path to client certificates for secure communication.

    .PARAMETER Force
    Force re-initialization even if already initialized.

    .EXAMPLE
    Initialize-OpenTofuProvider -ConfigPath "lab_config.yaml"

    .EXAMPLE
    Initialize-OpenTofuProvider -ConfigPath "lab_config.yaml" -ProviderVersion "1.2.1" -Force
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidateScript({ Test-Path $_ })]
        [string]$ConfigPath,

        [Parameter()]
        [string]$ProviderVersion = "1.2.1",

        [Parameter()]
        [string]$CertificatePath,

        [Parameter()]
        [switch]$Force
    )

    begin {
        Write-CustomLog -Level 'INFO' -Message "Initializing OpenTofu with Taliesins provider (Version: $ProviderVersion)"

        # Load configuration
        $config = Get-Content $ConfigPath -Raw | ConvertFrom-Yaml
        Write-CustomLog -Level 'INFO' -Message "Loaded configuration from: $ConfigPath"
    }

    process {
        try {
            # Validate OpenTofu installation
            $openTofuValid = Test-OpenTofuInstallation
            if (-not $openTofuValid.IsValid) {
                throw "OpenTofu is not properly installed. Run Install-OpenTofuSecure first."
            }

            # Generate secure provider configuration
            $providerConfig = New-TaliesinsProviderConfig -Configuration $config -ProviderVersion $ProviderVersion -CertificatePath $CertificatePath

            # Create terraform configuration directory
            $workingDir = Get-Location
            $terraformDir = Join-Path $workingDir ".terraform"

            if ($Force -and (Test-Path $terraformDir)) {
                Write-CustomLog -Level 'INFO' -Message "Removing existing .terraform directory"
                Remove-Item $terraformDir -Recurse -Force
            }

            # Write provider configuration
            $mainTfPath = Join-Path $workingDir "main.tf"
            if ($PSCmdlet.ShouldProcess($mainTfPath, "Write OpenTofu configuration")) {
                Set-Content -Path $mainTfPath -Value $providerConfig.MainConfig
                Write-CustomLog -Level 'INFO' -Message "Created main.tf configuration"
            }

            # Write variables file
            $variablesTfPath = Join-Path $workingDir "variables.tf"
            if ($PSCmdlet.ShouldProcess($variablesTfPath, "Write variables configuration")) {
                Set-Content -Path $variablesTfPath -Value $providerConfig.VariablesConfig
                Write-CustomLog -Level 'INFO' -Message "Created variables.tf configuration"
            }

            # Initialize OpenTofu
            Write-CustomLog -Level 'INFO' -Message "Running OpenTofu init..."
            $initResult = Invoke-OpenTofuCommand -Command "init" -WorkingDirectory $workingDir

            if ($initResult.Success) {
                # Validate provider installation
                $validationResult = Test-TaliesinsProviderInstallation -ProviderVersion $ProviderVersion

                if ($validationResult.Success) {
                    Write-CustomLog -Level 'SUCCESS' -Message "OpenTofu initialized successfully with Taliesins provider"
                    return @{
                        Success = $true
                        ProviderVersion = $ProviderVersion
                        ConfigPath = $ConfigPath
                        WorkingDirectory = $workingDir
                        CertificatesConfigured = ($null -ne $CertificatePath)
                    }
                } else {
                    throw "Provider validation failed: $($validationResult.Error)"
                }
            } else {
                throw "OpenTofu initialization failed: $($initResult.Error)"
            }

        } catch {
            Write-CustomLog -Level 'ERROR' -Message "OpenTofu provider initialization failed: $($_.Exception.Message)"
            throw
        }
    }

    end {
        Write-CustomLog -Level 'INFO' -Message "OpenTofu provider initialization completed"
    }
}

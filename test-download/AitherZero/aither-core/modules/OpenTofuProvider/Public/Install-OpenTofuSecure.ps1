function Install-OpenTofuSecure {
    <#
    .SYNOPSIS
    Securely installs OpenTofu with comprehensive security verification.

    .DESCRIPTION
    This function provides enhanced security for OpenTofu installation including:
    - Multi-signature verification (Cosign + GPG)
    - Certificate pinning for downloads
    - Integrity validation
    - Secure installation paths
    - Audit logging of all operations

    .PARAMETER Version
    Specific OpenTofu version to install. Defaults to 'latest'.

    .PARAMETER InstallPath
    Custom installation path. Uses secure defaults if not specified.

    .PARAMETER SkipVerification
    Skip signature verification (NOT RECOMMENDED for production).

    .PARAMETER Force
    Force reinstallation even if OpenTofu exists.

    .EXAMPLE
    Install-OpenTofuSecure -Version "1.6.0"

    .EXAMPLE
    Install-OpenTofuSecure -Force -InstallPath "C:\Tools\OpenTofu"
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter()]
        [string]$Version = "latest",

        [Parameter()]
        [string]$InstallPath,

        [Parameter()]
        [switch]$SkipVerification,

        [Parameter()]
        [switch]$Force
    )

    begin {
        Write-CustomLog -Level 'INFO' -Message "Starting secure OpenTofu installation (Version: $Version)"

        # Security configuration
        $securityConfig = @{
            GpgKeyId = 'E3E6E43D84CB852EADB0051D0C0AF313E5FD9F80'
            CosignOidcIssuer = 'https://token.actions.githubusercontent.com'
            CosignIdentity = 'autodetect'
            GpgUrl = 'https://get.opentofu.org/opentofu.asc'
            DownloadUrl = 'https://get.opentofu.org'
            RequiredTlsVersion = 'TLS12'
        }

        # Determine secure installation path
        if (-not $InstallPath) {
            if ($env:USERPROFILE) {
                $InstallPath = Join-Path $env:LOCALAPPDATA "Programs/OpenTofu"
            } else {
                $InstallPath = "/usr/local/bin"
            }
        }

        Write-CustomLog -Level 'INFO' -Message "Installation path: $InstallPath"
    }

    process {
        try {
            # Pre-installation security checks
            if (-not $SkipVerification) {
                Write-CustomLog -Level 'INFO' -Message "Performing pre-installation security validation"

                # Check for required security tools
                $cosignAvailable = Get-Command 'cosign' -ErrorAction SilentlyContinue
                $gpgAvailable = Get-Command 'gpg' -ErrorAction SilentlyContinue

                if (-not $cosignAvailable -and -not $gpgAvailable) {
                    throw "Neither Cosign nor GPG is available for signature verification. Install at least one or use -SkipVerification (not recommended)."
                }

                Write-CustomLog -Level 'SUCCESS' -Message "Security tools validation passed"
            }

            # Check if OpenTofu already exists
            $existingInstallation = Test-OpenTofuInstallation -Path $InstallPath
            if ($existingInstallation -and -not $Force) {
                Write-CustomLog -Level 'WARN' -Message "OpenTofu already installed at $InstallPath. Use -Force to reinstall."
                return $existingInstallation
            }

            # Create secure installation directory
            if ($PSCmdlet.ShouldProcess($InstallPath, "Create installation directory")) {
                New-Item -Path $InstallPath -ItemType Directory -Force | Out-Null
                Write-CustomLog -Level 'INFO' -Message "Created installation directory: $InstallPath"
            }

            # Download and verify OpenTofu
            $downloadResult = Invoke-SecureOpenTofuDownload -Version $Version -DestinationPath $InstallPath -SecurityConfig $securityConfig -SkipVerification:$SkipVerification

            if ($downloadResult.Success) {
                # Install OpenTofu
                $installResult = Install-OpenTofuBinary -SourcePath $downloadResult.FilePath -InstallPath $InstallPath

                if ($installResult.Success) {
                    # Verify installation
                    $verification = Test-OpenTofuInstallation -Path $InstallPath -Verbose

                    if ($verification.IsValid) {
                        Write-CustomLog -Level 'SUCCESS' -Message "OpenTofu $Version installed successfully and verified"
                        return @{
                            Success = $true
                            Version = $verification.Version
                            Path = $verification.Path
                            SecurityVerified = (-not $SkipVerification)
                        }
                    } else {
                        throw "Installation verification failed"
                    }
                } else {
                    throw "Installation failed: $($installResult.Error)"
                }
            } else {
                throw "Download failed: $($downloadResult.Error)"
            }

        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Secure OpenTofu installation failed: $($_.Exception.Message)"
            throw
        }
    }

    end {
        Write-CustomLog -Level 'INFO' -Message "Secure OpenTofu installation process completed"
    }
}

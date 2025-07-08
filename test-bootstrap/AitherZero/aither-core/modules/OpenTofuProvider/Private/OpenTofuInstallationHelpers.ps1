function Test-OpenTofuInstallation {
    <#
    .SYNOPSIS
    Tests if OpenTofu is properly installed and accessible.

    .DESCRIPTION
    Validates OpenTofu installation by checking:
    - Binary existence and accessibility
    - Version information
    - Basic functionality

    .PARAMETER Path
    Specific path to test. Uses PATH environment if not specified.

    .PARAMETER Verbose
    Provide detailed validation information.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Path,
          [Parameter()]
        [switch]$VerboseOutput
    )

    try {
        if ($Path) {
            $tofuPath = Join-Path $Path "tofu.exe"
            if (-not (Test-Path $tofuPath)) {
                $tofuPath = Join-Path $Path "tofu"
            }
        } else {
            $tofuPath = Get-Command "tofu" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -First 1
        }

        if (-not $tofuPath -or -not (Test-Path $tofuPath)) {
            return @{
                IsValid = $false
                Error = "OpenTofu binary not found"
                Path = $null
                Version = $null
            }
        }

        # Test version command
        $versionOutput = & $tofuPath version 2>&1
        if ($LASTEXITCODE -ne 0) {
            return @{
                IsValid = $false
                Error = "OpenTofu version command failed: $versionOutput"
                Path = $tofuPath
                Version = $null
            }
        }
          # Parse version
        $versionMatch = $versionOutput | Select-String "OpenTofu v(\d+\.\d+\.\d+)"
        $version = if ($versionMatch) { $versionMatch.Matches[0].Groups[1].Value } else { "Unknown" }

        if ($VerboseOutput) {
            Write-CustomLog -Level 'INFO' -Message "OpenTofu version detected: $version"
        }

        return @{
            IsValid = $true
            Path = $tofuPath
            Version = $version
            VersionOutput = $versionOutput
        }

    } catch {
        return @{
            IsValid = $false
            Error = $_.Exception.Message
            Path = $tofuPath
            Version = $null
        }
    }
}

function Invoke-SecureOpenTofuDownload {
    <#
    .SYNOPSIS
    Securely downloads OpenTofu with signature verification.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Version,

        [Parameter(Mandatory)]
        [string]$DestinationPath,

        [Parameter(Mandatory)]
        [hashtable]$SecurityConfig,

        [Parameter()]
        [switch]$SkipVerification
    )

    try {
        # Determine platform and architecture
        $platform = if ($IsWindows) { "windows" } elseif ($IsLinux) { "linux" } elseif ($IsMacOS) { "darwin" } else { "windows" }
        $arch = if ([Environment]::Is64BitOperatingSystem) { "amd64" } else { "386" }

        # Build download URLs
        $fileName = "tofu_${Version}_${platform}_${arch}.zip"
        $downloadUrl = "$($SecurityConfig.DownloadUrl)/tofu/$Version/$fileName"
        $signatureUrl = "${downloadUrl}.sig"

        Write-CustomLog -Level 'INFO' -Message "Downloading OpenTofu $Version for $platform/$arch"
          # Create temporary download directory
        $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "opentofu-download-$(Get-Random)"
        if (-not (Test-Path $DestinationPath)) {
            New-Item -Path $DestinationPath -ItemType Directory -Force | Out-Null
        }
        New-Item -Path $tempDir -ItemType Directory -Force | Out-Null

        try {
            # Download binary
            $binaryPath = Join-Path $tempDir $fileName
            Invoke-WebRequest -Uri $downloadUrl -OutFile $binaryPath -UseBasicParsing
            Write-CustomLog -Level 'INFO' -Message "Downloaded OpenTofu binary to: $binaryPath"

            # Download signature if verification is enabled
            if (-not $SkipVerification) {
                $signaturePath = Join-Path $tempDir "$fileName.sig"
                Invoke-WebRequest -Uri $signatureUrl -OutFile $signaturePath -UseBasicParsing
                Write-CustomLog -Level 'INFO' -Message "Downloaded signature file"

                # Verify signature
                $verificationResult = Invoke-SignatureVerification -FilePath $binaryPath -SignaturePath $signaturePath -SecurityConfig $SecurityConfig
                if (-not $verificationResult.Success) {
                    throw "Signature verification failed: $($verificationResult.Error)"
                }
                Write-CustomLog -Level 'SUCCESS' -Message "Signature verification passed"
            }

            return @{
                Success = $true
                FilePath = $binaryPath
                Version = $Version
                Verified = (-not $SkipVerification)
            }

        } finally {
            # Cleanup will happen in calling function
        }

    } catch {
        if (Test-Path $tempDir) {
            Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
        return @{
            Success = $false
            Error = $_.Exception.Message
            FilePath = $null
        }
    }
}

function Install-OpenTofuBinary {
    <#
    .SYNOPSIS
    Installs OpenTofu binary from downloaded package.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$SourcePath,

        [Parameter(Mandatory)]
        [string]$InstallPath
    )

    try {
        # Extract if it's a zip file
        if ($SourcePath -like "*.zip") {
            $extractPath = Join-Path ([System.IO.Path]::GetTempPath()) "opentofu-extract-$(Get-Random)"
            Expand-Archive -Path $SourcePath -DestinationPath $extractPath -Force

            # Find the tofu binary
            $binaryName = if ($IsWindows) { "tofu.exe" } else { "tofu" }
            $binaryPath = Get-ChildItem -Path $extractPath -Name $binaryName -Recurse | Select-Object -First 1

            if (-not $binaryPath) {
                throw "OpenTofu binary not found in extracted package"
            }

            $sourceBinary = Join-Path $extractPath $binaryPath
        } else {
            $sourceBinary = $SourcePath
        }

        # Copy binary to installation directory
        $targetBinary = Join-Path $InstallPath $(Split-Path $sourceBinary -Leaf)
        Copy-Item -Path $sourceBinary -Destination $targetBinary -Force

        # Set executable permissions on Unix-like systems
        if (-not $IsWindows) {
            chmod +x $targetBinary
        }

        Write-CustomLog -Level 'SUCCESS' -Message "OpenTofu binary installed to: $targetBinary"

        return @{
            Success = $true
            BinaryPath = $targetBinary
            InstallPath = $InstallPath
        }

    } catch {
        return @{
            Success = $false
            Error = $_.Exception.Message
            BinaryPath = $null
        }
    } finally {
        # Cleanup extraction directory
        if ($extractPath -and (Test-Path $extractPath)) {
            Remove-Item $extractPath -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

function Invoke-SignatureVerification {
    <#
    .SYNOPSIS
    Performs signature verification using available tools.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FilePath,

        [Parameter(Mandatory)]
        [string]$SignaturePath,

        [Parameter(Mandatory)]
        [hashtable]$SecurityConfig
    )

    try {
        # Try Cosign first
        $cosign = Get-Command 'cosign' -ErrorAction SilentlyContinue
        if ($cosign) {
            Write-CustomLog -Level 'INFO' -Message "Using Cosign for signature verification"

            $cosignArgs = @(
                'verify-blob'
                '--signature', $SignaturePath
                '--certificate-identity-regexp', '.*'
                '--certificate-oidc-issuer', $SecurityConfig.CosignOidcIssuer
                $FilePath
            )

            $cosignResult = & $cosign @cosignArgs 2>&1
            if ($LASTEXITCODE -eq 0) {
                return @{ Success = $true; Method = 'Cosign'; Output = $cosignResult }
            }
        }

        # Try GPG as fallback
        $gpg = Get-Command 'gpg' -ErrorAction SilentlyContinue
        if ($gpg) {
            Write-CustomLog -Level 'INFO' -Message "Using GPG for signature verification"
              # Import GPG key if not already imported
            $keyImportResult = & $gpg --import $SecurityConfig.GpgUrl 2>&1
            if ($VerboseOutput) {
                Write-CustomLog -Level 'INFO' -Message "GPG key import result: $keyImportResult"
            }

            # Verify signature
            $gpgResult = & $gpg --verify $SignaturePath $FilePath 2>&1
            if ($LASTEXITCODE -eq 0) {
                return @{ Success = $true; Method = 'GPG'; Output = $gpgResult }
            }
        }

        return @{
            Success = $false
            Error = "No signature verification tools available or verification failed"
            Method = 'None'
        }

    } catch {
        return @{
            Success = $false
            Error = $_.Exception.Message
            Method = 'Error'
        }
    }
}

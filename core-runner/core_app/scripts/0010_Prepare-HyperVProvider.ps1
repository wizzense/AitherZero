#Requires -Version 7.0
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory, ValueFromPipeline)]
    [object]$Config
)

Import-Module "$env:PWSH_MODULES_PATH/LabRunner/" -Force
Import-Module "$env:PROJECT_ROOT/core-runner/modules/Logging" -Force

Write-CustomLog "Starting $($MyInvocation.MyCommand.Name)"

#region Helper Functions

function Convert-CerToPem {
    <#
    .SYNOPSIS
        Converts a CER certificate file to PEM format
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$CerPath,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$PemPath
    )

    if (-not $PSCmdlet.ShouldProcess($PemPath, 'Create PEM file')) { return }

    try {
        if (-not (Test-Path $CerPath)) {
            throw "Certificate file not found: $CerPath"
        }

        $bytes = [System.IO.File]::ReadAllBytes($CerPath)
        $b64 = [System.Convert]::ToBase64String($bytes, 'InsertLineBreaks')
        $pemContent = "-----BEGIN CERTIFICATE-----`n$b64`n-----END CERTIFICATE-----"

        Set-Content -Path $PemPath -Value $pemContent -Encoding UTF8
        Write-CustomLog "Converted certificate to PEM format: $PemPath" -Level INFO
    } catch {
        Write-CustomLog "Failed to convert certificate to PEM: $($_.Exception.Message)" -Level ERROR
        throw
    }
}

function Convert-PfxToPem {
    <#
    .SYNOPSIS
        Converts a PFX certificate file to separate PEM certificate and key files
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$PfxPath,

        [Parameter(Mandatory)]
        [System.Security.SecureString]$Password,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$CertPath,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$KeyPath
    )

    if (-not $PSCmdlet.ShouldProcess($PfxPath, 'Convert PFX to PEM')) { return }

    if (-not (Test-Path $PfxPath) -or ((Get-Item -Path $PfxPath -ErrorAction SilentlyContinue).Length -eq 0)) {
        throw "Invalid or unreadable PFX at $PfxPath"
    }

    try {
        $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2(
            $PfxPath,
            $Password,
            [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::Exportable
        )

        # Export certificate
        $certBytes = $cert.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Cert)
        $certB64 = [System.Convert]::ToBase64String($certBytes, 'InsertLineBreaks')

        if ($PSCmdlet.ShouldProcess($CertPath, 'Write certificate PEM')) {
            $certPem = "-----BEGIN CERTIFICATE-----`n$certB64`n-----END CERTIFICATE-----"
            Set-Content -Path $CertPath -Value $certPem -Encoding UTF8
        }

        # Export private key
        $keyBytes = $cert.PrivateKey.ExportPkcs8PrivateKey()
        $keyB64 = [System.Convert]::ToBase64String($keyBytes, 'InsertLineBreaks')

        if ($PSCmdlet.ShouldProcess($KeyPath, 'Write key PEM')) {
            $keyPem = "-----BEGIN PRIVATE KEY-----`n$keyB64`n-----END PRIVATE KEY-----"
            Set-Content -Path $KeyPath -Value $keyPem -Encoding UTF8
        }

        Write-CustomLog "Converted PFX to PEM files: $CertPath, $KeyPath" -Level INFO
    } catch [System.Security.Cryptography.CryptographicException] {
        Write-CustomLog "Failed to convert certificate: $($_.Exception.Message)" -Level ERROR
        throw "Failed to convert certificate: $($_.Exception.Message)"
    } catch {
        Write-CustomLog "Unexpected error during PFX conversion: $($_.Exception.Message)" -Level ERROR
        throw
    }
}

function Get-HyperVProviderVersion {
    <#
    .SYNOPSIS
        Gets the HyperV provider version from configuration or uses default
    #>
    [CmdletBinding()]
    param()

    $defaultVersion = '1.2.1'

    if ($Config -and $Config.HyperV -and $Config.HyperV.ProviderVersion) {
        Write-CustomLog "Using configured HyperV provider version: $($Config.HyperV.ProviderVersion)" -Level INFO
        return $Config.HyperV.ProviderVersion
    }

    Write-CustomLog "HyperV provider version not specified in config. Using default: $defaultVersion" -Level WARN
    return $defaultVersion
}

#endregion

#region Main Execution

if ($MyInvocation.InvocationName -ne '.') {
    try {
        Invoke-LabStep -Config $Config -Body {
            Write-CustomLog 'Configuring HyperV Provider for OpenTofu' -Level INFO

            # Only proceed if HyperV host preparation is enabled
            if (-not $Config.PrepareHyperVHost) {
                Write-CustomLog 'HyperV host preparation is disabled in configuration' -Level WARN
                return
            }

            # Validate Windows platform
            if (-not $IsWindows) {
                Write-CustomLog 'HyperV provider setup requires Windows platform' -Level ERROR
                throw 'HyperV provider setup is only supported on Windows'
            }

            # Get infrastructure repository path
            $infraRepoPath = if ([string]::IsNullOrWhiteSpace($Config.InfraRepoPath)) {
                Join-Path $PSScriptRoot '../../../opentofu/infrastructure'
            } else {
                $Config.InfraRepoPath
            }

            Write-CustomLog "Using infrastructure repository path: $infraRepoPath" -Level INFO

            # Ensure infrastructure directory exists
            if (-not (Test-Path $infraRepoPath)) {
                New-Item -ItemType Directory -Path $infraRepoPath -Force | Out-Null
                Write-CustomLog "Created infrastructure directory: $infraRepoPath" -Level INFO
            }

            #region Enable HyperV Feature
            Write-CustomLog 'Checking HyperV feature status...' -Level INFO

            try {
                $hvFeature = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -ErrorAction Stop
                if ($hvFeature.State -ne 'Enabled') {
                    Write-CustomLog 'Enabling HyperV feature...' -Level INFO
                    if ($PSCmdlet.ShouldProcess('Microsoft-Hyper-V', 'Enable Windows Feature')) {
                        Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All -NoRestart
                        Write-CustomLog 'HyperV feature enabled successfully' -Level SUCCESS
                    }
                } else {
                    Write-CustomLog 'HyperV feature is already enabled' -Level INFO
                }
            } catch {
                Write-CustomLog "Failed to check/enable HyperV feature: $($_.Exception.Message)" -Level ERROR
                throw
            }
            #endregion

            #region Configure WinRM
            Write-CustomLog 'Configuring WinRM for HyperV provider...' -Level INFO

            try {
                # Test if WinRM is already enabled
                try {
                    Test-WSMan -ComputerName localhost -ErrorAction Stop | Out-Null
                    Write-CustomLog 'WinRM is already enabled' -Level INFO
                } catch {
                    Write-CustomLog 'Enabling WinRM...' -Level INFO
                    if ($PSCmdlet.ShouldProcess('WinRM', 'Enable PS Remoting')) {
                        Enable-PSRemoting -SkipNetworkProfileCheck -Force
                        Write-CustomLog 'WinRM enabled successfully' -Level SUCCESS
                    }
                }

                # Configure WinRM settings
                $winrmConfig = @{
                    MaxMemoryPerShellMB = 1024
                    MaxTimeoutms        = 1800000
                }

                foreach ($setting in $winrmConfig.GetEnumerator()) {
                    $resourceUri = if ($setting.Key -eq 'MaxMemoryPerShellMB') {
                        'winrm/config/WinRS'
                    } else {
                        'winrm/config'
                    }

                    try {
                        $current = (Get-WSManInstance -ResourceURI $resourceUri).$($setting.Key)
                        if ($current -ne $setting.Value) {
                            Write-CustomLog "Setting WinRM $($setting.Key) to $($setting.Value)..." -Level INFO
                            if ($PSCmdlet.ShouldProcess($setting.Key, 'Set WinRM Configuration')) {
                                Set-WSManInstance -ResourceURI $resourceUri -ValueSet @{$($setting.Key) = $setting.Value }
                            }
                        } else {
                            Write-CustomLog "WinRM $($setting.Key) is already set to $($setting.Value)" -Level INFO
                        }
                    } catch {
                        Write-CustomLog "Failed to configure WinRM $($setting.Key): $($_.Exception.Message)" -Level WARN
                    }
                }

                # Configure TrustedHosts
                try {
                    $currentTrustedHosts = (Get-WSManInstance -ResourceURI winrm/config/Client).TrustedHosts
                    if ($currentTrustedHosts -ne '*') {
                        Write-CustomLog "Setting TrustedHosts to '*'..." -Level INFO
                        if ($PSCmdlet.ShouldProcess('TrustedHosts', "Set to '*'")) {
                            Set-WSManInstance -ResourceURI winrm/config/Client -ValueSet @{TrustedHosts = '*' }
                        }
                    } else {
                        Write-CustomLog "TrustedHosts is already set to '*'" -Level INFO
                    }
                } catch {
                    Write-CustomLog "TrustedHosts setting may be controlled by policy: $($_.Exception.Message)" -Level WARN
                }

                # Enable Negotiate authentication
                try {
                    $currentNegotiate = (Get-WSManInstance -ResourceURI winrm/config/Service/Auth).Negotiate
                    if (-not $currentNegotiate) {
                        Write-CustomLog 'Enabling Negotiate authentication...' -Level INFO
                        if ($PSCmdlet.ShouldProcess('Negotiate', 'Enable Authentication')) {
                            Set-WSManInstance -ResourceURI winrm/config/Service/Auth -ValueSet @{Negotiate = $true }
                        }
                    } else {
                        Write-CustomLog 'Negotiate authentication is already enabled' -Level INFO
                    }
                } catch {
                    Write-CustomLog "Failed to configure Negotiate authentication: $($_.Exception.Message)" -Level WARN
                }
            } catch {
                Write-CustomLog "Failed to configure WinRM: $($_.Exception.Message)" -Level ERROR
                throw
            }
            #endregion

            #region Certificate Management
            Write-CustomLog 'Setting up certificates for secure WinRM...' -Level INFO

            # Get certificate configuration
            $rootCaName = if ($Config.CertificateAuthority -and $Config.CertificateAuthority.CommonName) {
                $Config.CertificateAuthority.CommonName
            } else {
                'DevRootCA'
            }

            $rootCaPassword = ConvertTo-SecureString 'P@ssw0rd' -AsPlainText -Force
            $hostPassword = ConvertTo-SecureString 'P@ssw0rd' -AsPlainText -Force

            # Create or import Root CA certificate
            Write-CustomLog "Processing Root CA certificate: $rootCaName" -Level INFO
            $rootCaCertificate = Get-ChildItem cert:\LocalMachine\Root | Where-Object { $_.Subject -eq "CN=$rootCaName" }

            if (-not $rootCaCertificate) {
                $cerPath = ".\$rootCaName.cer"
                $pfxPath = ".\$rootCaName.pfx"

                # Clean up existing certificates in My store
                Get-ChildItem cert:\LocalMachine\My | Where-Object { $_.Subject -eq "CN=$rootCaName" } | Remove-Item -Force -ErrorAction SilentlyContinue

                if ((Test-Path $cerPath) -and (Test-Path $pfxPath)) {
                    Write-CustomLog 'Importing existing Root CA certificates...' -Level INFO
                    if ($PSCmdlet.ShouldProcess($rootCaName, 'Import existing certificates')) {
                        Import-PfxCertificate -FilePath $pfxPath -CertStoreLocation Cert:\LocalMachine\Root -Password $rootCaPassword -Exportable | Out-Null
                        Import-PfxCertificate -FilePath $pfxPath -CertStoreLocation Cert:\LocalMachine\My -Password $rootCaPassword -Exportable | Out-Null
                    }
                } else {
                    Write-CustomLog 'Creating new Root CA certificate...' -Level INFO

                    # Remove existing files
                    Remove-Item $cerPath -Force -ErrorAction SilentlyContinue
                    Remove-Item $pfxPath -Force -ErrorAction SilentlyContinue

                    $rootCaParams = @{
                        Type              = 'Custom'
                        DnsName           = $rootCaName
                        Subject           = "CN=$rootCaName"
                        KeyExportPolicy   = 'Exportable'
                        CertStoreLocation = 'Cert:\LocalMachine\My'
                        KeyUsageProperty  = 'All'
                        KeyUsage          = 'None'
                        Provider          = 'Microsoft Strong Cryptographic Provider'
                        KeySpec           = 'KeyExchange'
                        KeyLength         = 4096
                        HashAlgorithm     = 'SHA256'
                        KeyAlgorithm      = 'RSA'
                        NotAfter          = (Get-Date).AddYears(5)
                    }

                    if ($PSCmdlet.ShouldProcess($rootCaName, 'Create Root CA certificate')) {
                        $rootCaCertificate = New-SelfSignedCertificate @rootCaParams

                        Export-Certificate -Cert $rootCaCertificate -FilePath $cerPath | Out-Null
                        Export-PfxCertificate -Cert $rootCaCertificate -FilePath $pfxPath -Password $rootCaPassword | Out-Null

                        # Remove from My store and import to Root and My stores
                        Get-ChildItem cert:\LocalMachine\My | Where-Object { $_.Subject -eq "CN=$rootCaName" } | Remove-Item -Force
                        Import-PfxCertificate -FilePath $pfxPath -CertStoreLocation Cert:\LocalMachine\Root -Password $rootCaPassword -Exportable | Out-Null
                        Import-PfxCertificate -FilePath $pfxPath -CertStoreLocation Cert:\LocalMachine\My -Password $rootCaPassword -Exportable | Out-Null
                    }
                }

                $rootCaCertificate = Get-ChildItem cert:\LocalMachine\My | Where-Object { $_.Subject -eq "CN=$rootCaName" }
            }

            # Create host certificate
            $hostName = [System.Net.Dns]::GetHostName()
            Write-CustomLog "Processing host certificate for: $hostName" -Level INFO

            $hostCertificate = Get-ChildItem cert:\LocalMachine\My | Where-Object { $_.Subject -eq "CN=$hostName" }

            if (-not $hostCertificate) {
                Write-CustomLog 'Creating host certificate...' -Level INFO

                # Clean up existing files
                Remove-Item ".\$hostName.cer" -Force -ErrorAction SilentlyContinue
                Remove-Item ".\$hostName.pfx" -Force -ErrorAction SilentlyContinue
                Get-ChildItem cert:\LocalMachine\My | Where-Object { $_.Subject -eq "CN=$hostName" } | Remove-Item -Force -ErrorAction SilentlyContinue

                $dnsNames = @($hostName, 'localhost', '127.0.0.1')
                try {
                    $dnsNames += [System.Net.Dns]::GetHostByName($env:ComputerName).AddressList.IPAddressToString
                } catch {
                    Write-CustomLog 'Could not resolve additional IP addresses for certificate' -Level WARN
                }

                $hostCertParams = @{
                    Type              = 'Custom'
                    DnsName           = $dnsNames
                    Subject           = "CN=$hostName"
                    KeyExportPolicy   = 'Exportable'
                    CertStoreLocation = 'Cert:\LocalMachine\My'
                    KeyUsageProperty  = 'All'
                    KeyUsage          = @('KeyEncipherment', 'DigitalSignature', 'NonRepudiation')
                    TextExtension     = @('2.5.29.37={text}1.3.6.1.5.5.7.3.1,1.3.6.1.5.5.7.3.2')
                    Signer            = $rootCaCertificate
                    Provider          = 'Microsoft Strong Cryptographic Provider'
                    KeySpec           = 'KeyExchange'
                    KeyLength         = 2048
                    HashAlgorithm     = 'SHA256'
                    KeyAlgorithm      = 'RSA'
                    NotAfter          = (Get-Date).AddYears(2)
                }

                if ($PSCmdlet.ShouldProcess($hostName, 'Create host certificate')) {
                    $hostCertificate = New-SelfSignedCertificate @hostCertParams

                    Export-Certificate -Cert $hostCertificate -FilePath ".\$hostName.cer" | Out-Null
                    Export-PfxCertificate -Cert $hostCertificate -FilePath ".\$hostName.pfx" -Password $hostPassword | Out-Null

                    # Reimport to ensure it's available
                    Get-ChildItem cert:\LocalMachine\My | Where-Object { $_.Subject -eq "CN=$hostName" } | Remove-Item -Force
                    Import-PfxCertificate -FilePath ".\$hostName.pfx" -CertStoreLocation Cert:\LocalMachine\My -Password $hostPassword -Exportable | Out-Null

                    $hostCertificate = Get-ChildItem cert:\LocalMachine\My | Where-Object { $_.Subject -eq "CN=$hostName" }
                }
            }

            # Convert certificates to PEM format
            Write-CustomLog 'Converting certificates to PEM format...' -Level INFO

            if ($PSCmdlet.ShouldProcess('Certificates', 'Convert to PEM format')) {
                Convert-CerToPem -CerPath ".\$rootCaName.cer" -PemPath ".\$rootCaName.pem"
                Convert-PfxToPem -PfxPath ".\$hostName.pfx" -Password $hostPassword -CertPath ".\$hostName.pem" -KeyPath ".\$hostName-key.pem"

                # Copy PEM files to infrastructure directory
                $pemFiles = @(
                    @{ Source = ".\$rootCaName.pem"; Dest = Join-Path $infraRepoPath "$rootCaName.pem" }
                    @{ Source = ".\$hostName.pem"; Dest = Join-Path $infraRepoPath "$hostName.pem" }
                    @{ Source = ".\$hostName-key.pem"; Dest = Join-Path $infraRepoPath "$hostName-key.pem" }
                )

                foreach ($file in $pemFiles) {
                    if (Test-Path $file.Dest) {
                        Remove-Item $file.Dest -Force
                    }
                    Copy-Item $file.Source -Destination $file.Dest -Force
                    Write-CustomLog "Copied $($file.Source) to $($file.Dest)" -Level INFO
                }
            }
            #endregion

            #region Configure WinRM HTTPS Listener
            Write-CustomLog 'Configuring WinRM HTTPS listener...' -Level INFO

            try {
                # Remove existing HTTPS listener
                Get-ChildItem wsman:\localhost\Listener\ | Where-Object { $_.Keys -eq 'Transport=HTTPS' } | Remove-Item -Recurse -ErrorAction SilentlyContinue

                if ($PSCmdlet.ShouldProcess('WinRM HTTPS Listener', 'Create')) {
                    New-Item -Path WSMan:\localhost\Listener -Transport HTTPS -Address * -CertificateThumbPrint $hostCertificate.Thumbprint -Force | Out-Null
                    Write-CustomLog "WinRM HTTPS listener created with certificate thumbprint: $($hostCertificate.Thumbprint)" -Level SUCCESS
                }

                # Restart WinRM service
                if ($PSCmdlet.ShouldProcess('WinRM', 'Restart Service')) {
                    Restart-Service WinRM -Force
                    Write-CustomLog 'WinRM service restarted' -Level INFO
                }

                # Configure firewall rule for HTTPS
                $httpsRule = Get-NetFirewallRule -Name 'WinRMHTTPSIn' -ErrorAction SilentlyContinue
                if (-not $httpsRule) {
                    if ($PSCmdlet.ShouldProcess('Firewall', 'Allow WinRM HTTPS (5986)')) {
                        New-NetFirewallRule -DisplayName 'Windows Remote Management (HTTPS-In)' -Name 'WinRMHTTPSIn' -Profile Any -LocalPort 5986 -Protocol TCP | Out-Null
                        Write-CustomLog 'Firewall rule created for WinRM HTTPS (port 5986)' -Level SUCCESS
                    }
                } else {
                    Write-CustomLog 'Firewall rule for WinRM HTTPS already exists' -Level INFO
                }
            } catch {
                Write-CustomLog "Failed to configure WinRM HTTPS listener: $($_.Exception.Message)" -Level ERROR
                throw
            }
            #endregion

            #region Install HyperV Provider
            Write-CustomLog 'Installing HyperV provider...' -Level INFO

            try {
                $providerVersion = Get-HyperVProviderVersion

                # Determine OS and architecture
                $computerInfo = Get-ComputerInfo -Property OsName, OsArchitecture
                $os = 'windows'
                $arch = if ($computerInfo.OsArchitecture -match '64') { 'amd64' } else { '386' }

                Write-CustomLog "Target platform: $os/$arch, Provider version: $providerVersion" -Level INFO

                # Download provider binary
                $registryEndpoint = "https://registry.terraform.io/v1/providers/taliesins/hyperv/$providerVersion/download/$os/$arch"

                try {
                    $response = Invoke-RestMethod -Uri $registryEndpoint -Method Get
                    $downloadUrl = $response.download_url
                    $zipPath = Join-Path $env:TEMP "terraform-provider-hyperv_$providerVersion.zip"

                    Write-CustomLog "Downloading HyperV provider from: $downloadUrl" -Level INFO
                    Invoke-WebRequest -Uri $downloadUrl -OutFile $zipPath

                    # Extract provider
                    $tempDir = Join-Path $env:TEMP 'hyperv-provider-extract'
                    if (Test-Path $tempDir) {
                        Remove-Item $tempDir -Recurse -Force
                    }

                    Expand-Archive -Path $zipPath -DestinationPath $tempDir -Force

                    # Find provider executable
                    $providerExe = Get-ChildItem $tempDir -Filter 'terraform-provider-hyperv*.exe' | Select-Object -First 1
                    if (-not $providerExe) {
                        throw 'Provider executable not found in downloaded archive'
                    }

                    # Install to OpenTofu provider directory
                    $hypervProviderDir = Join-Path $infraRepoPath ".terraform/providers/registry.opentofu.org/taliesins/hyperv/$providerVersion/${os}_${arch}"
                    if (-not (Test-Path $hypervProviderDir)) {
                        New-Item -ItemType Directory -Path $hypervProviderDir -Force | Out-Null
                    }

                    $destinationBinary = Join-Path $hypervProviderDir 'terraform-provider-hyperv.exe'
                    if (Test-Path $destinationBinary) {
                        Remove-Item $destinationBinary -Force
                    }

                    Copy-Item $providerExe.FullName -Destination $destinationBinary -Force
                    Write-CustomLog "HyperV provider installed to: $destinationBinary" -Level SUCCESS

                    # Cleanup
                    Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
                    Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
                } catch {
                    Write-CustomLog "Failed to download/install HyperV provider: $($_.Exception.Message)" -Level ERROR
                    throw
                }
            } catch {
                Write-CustomLog "HyperV provider installation failed: $($_.Exception.Message)" -Level ERROR
                throw
            }
            #endregion

            #region Update Provider Configuration
            $tfFile = Join-Path $infraRepoPath 'providers.tf'
            if (Test-Path $tfFile) {
                Write-CustomLog 'Updating providers.tf configuration...' -Level INFO

                try {
                    $rootCAPath = (Resolve-Path (Join-Path $infraRepoPath "$rootCaName.pem")).Path
                    $hostCertPath = (Resolve-Path (Join-Path $infraRepoPath "$hostName.pem")).Path
                    $hostKeyPath = (Resolve-Path (Join-Path $infraRepoPath "$hostName-key.pem")).Path

                    # Escape backslashes for Terraform
                    $escapedRootCAPath = $rootCAPath.Replace('\', '\\')
                    $escapedHostCertPath = $hostCertPath.Replace('\', '\\')
                    $escapedHostKeyPath = $hostKeyPath.Replace('\', '\\')

                    $content = Get-Content $tfFile -Raw
                    $content = $content -replace '(insecure\s*=\s*)(true|false)', '${1}false'
                    $content = $content -replace '(tls_server_name\s*=\s*")[^"]*"', ('${1}' + $hostName + '"')
                    $content = $content -replace '(cacert_path\s*=\s*")[^"]*"', ('${1}' + $escapedRootCAPath + '"')
                    $content = $content -replace '(cert_path\s*=\s*")[^"]*"', ('${1}' + $escapedHostCertPath + '"')
                    $content = $content -replace '(key_path\s*=\s*")[^"]*"', ('${1}' + $escapedHostKeyPath + '"')

                    Set-Content -Path $tfFile -Value $content
                    Write-CustomLog 'Updated providers.tf with certificate paths' -Level SUCCESS
                } catch {
                    Write-CustomLog "Failed to update providers.tf: $($_.Exception.Message)" -Level WARN
                }
            } else {
                Write-CustomLog "providers.tf not found in $infraRepoPath - skipping configuration update" -Level WARN
            }
            #endregion

            Write-CustomLog 'HyperV Provider preparation completed successfully' -Level SUCCESS
            Write-CustomLog 'You can now test the connection using Enter-PSSession with the configured certificates' -Level INFO
        }
    } catch {
        Write-CustomLog "HyperV Provider preparation failed: $($_.Exception.Message)" -Level ERROR
        throw
    }
}

#endregion

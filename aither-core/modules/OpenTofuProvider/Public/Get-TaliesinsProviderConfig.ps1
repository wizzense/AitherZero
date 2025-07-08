function Get-TaliesinsProviderConfig {
    <#
    .SYNOPSIS
    Generates secure Taliesins Hyper-V provider configuration for OpenTofu.

    .DESCRIPTION
    Creates properly configured Taliesins provider setup with:
    - Secure authentication methods
    - Certificate-based TLS communication
    - NTLM authentication support
    - Proper timeout and security settings

    .PARAMETER HypervHost
    Hyper-V host server name or IP address.

    .PARAMETER Credentials
    PSCredential object for authentication.

    .PARAMETER CertificatePath
    Path to client certificate for TLS authentication.

    .PARAMETER Port
    WinRM port (default: 5986 for HTTPS).

    .PARAMETER UseNTLM
    Use NTLM authentication (default: true).

    .PARAMETER OutputFormat
    Output format: 'HCL', 'JSON', or 'Object' (default: 'HCL').

    .EXAMPLE
    $creds = Get-Credential
    Get-TaliesinsProviderConfig -HypervHost "hyperv-01.lab.local" -Credentials $creds

    .EXAMPLE
    Get-TaliesinsProviderConfig -HypervHost "192.168.1.100" -CertificatePath "./certs/client.pem" -OutputFormat "JSON"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$HypervHost,

        [Parameter()]
        [System.Management.Automation.PSCredential]$Credentials,

        [Parameter()]
        [string]$CertificatePath,

        [Parameter()]
        [ValidateRange(1, 65535)]
        [int]$Port = 5986,

        [Parameter()]
        [bool]$UseNTLM = $true,

        [Parameter()]
        [ValidateSet('HCL', 'JSON', 'Object')]
        [string]$OutputFormat = 'HCL'
    )

    begin {
        Write-CustomLog -Level 'INFO' -Message "Generating Taliesins provider configuration for host: $HypervHost"

        # Validate certificate path if provided
        if ($CertificatePath -and -not (Test-Path $CertificatePath)) {
            throw "Certificate path not found: $CertificatePath"
        }
    }

    process {
        try {
            # Prompt for credentials if not provided
            if (-not $Credentials) {
                Write-CustomLog -Level 'INFO' -Message "Prompting for Hyper-V host credentials"
                $Credentials = Get-Credential -Message "Enter credentials for Hyper-V host: $HypervHost"
            }

            # Build provider configuration
            $providerConfig = @{
                terraform = @{
                    required_version = ">= 1.6.0"
                    required_providers = @{
                        hyperv = @{
                            source = "taliesins/hyperv"
                            version = "~> 1.2.1"
                        }
                    }
                }
                provider = @{
                    hyperv = @{
                        user = $Credentials.UserName
                        password = $Credentials.GetNetworkCredential().Password
                        host = $HypervHost
                        port = $Port
                        https = $true
                        insecure = $false
                        use_ntlm = $UseNTLM
                        tls_server_name = $HypervHost
                        script_path = "C:/Temp/tofu_%RAND%.cmd"
                        timeout = "30s"
                    }
                }
            }

            # Add certificate paths if provided
            if ($CertificatePath) {
                $certDir = Split-Path $CertificatePath -Parent
                $certName = Split-Path $CertificatePath -LeafBase

                $providerConfig.provider.hyperv.cacert_path = Join-Path $certDir "$certName-ca.pem"
                $providerConfig.provider.hyperv.cert_path = Join-Path $certDir "$certName-cert.pem"
                $providerConfig.provider.hyperv.key_path = Join-Path $certDir "$certName-key.pem"

                Write-CustomLog -Level 'INFO' -Message "Certificate-based authentication configured"
            }

            # Generate output based on format
            switch ($OutputFormat) {
                'HCL' {
                    $hclConfig = ConvertTo-HCL -Configuration $providerConfig
                    Write-CustomLog -Level 'SUCCESS' -Message "Generated HCL configuration for Taliesins provider"
                    return $hclConfig
                }
                'JSON' {
                    $jsonConfig = $providerConfig | ConvertTo-Json -Depth 10
                    Write-CustomLog -Level 'SUCCESS' -Message "Generated JSON configuration for Taliesins provider"
                    return $jsonConfig
                }
                'Object' {
                    Write-CustomLog -Level 'SUCCESS' -Message "Generated object configuration for Taliesins provider"
                    return $providerConfig
                }
            }

        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Failed to generate Taliesins provider config: $($_.Exception.Message)"
            throw
        }
    }

    end {
        Write-CustomLog -Level 'INFO' -Message "Taliesins provider configuration generation completed"
    }
}

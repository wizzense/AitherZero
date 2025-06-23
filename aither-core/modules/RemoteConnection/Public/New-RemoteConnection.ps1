function New-RemoteConnection {
    <#
    .SYNOPSIS
        Creates a new remote connection configuration for enterprise-wide use.

    .DESCRIPTION
        Configures secure remote connections to various endpoint types including:
        - SSH connections to Linux/Unix systems
        - WinRM connections to Windows systems
        - VMware vSphere connections
        - Hyper-V host connections
        - Docker daemon connections
        - Kubernetes cluster connections

    .PARAMETER ConnectionName
        Unique name for the connection configuration.

    .PARAMETER EndpointType
        Type of remote endpoint: SSH, WinRM, VMware, Hyper-V, Docker, Kubernetes.

    .PARAMETER HostName
        Hostname or IP address of the remote endpoint.

    .PARAMETER Port
        Port number for the connection (uses standard ports if not specified).

    .PARAMETER CredentialName
        Name of the stored credential to use for authentication.

    .PARAMETER ConnectionTimeout
        Timeout in seconds for connection attempts.

    .PARAMETER EnableSSL
        Enable SSL/TLS encryption for supported connection types.

    .PARAMETER Force
        Overwrite existing connection configuration.

    .EXAMPLE
        New-RemoteConnection -ConnectionName "HyperV-Lab-01" -EndpointType "Hyper-V" -HostName "hyperv.lab.local" -CredentialName "HyperV-Admin"

    .EXAMPLE
        New-RemoteConnection -ConnectionName "Docker-Dev" -EndpointType "Docker" -HostName "docker.dev.local" -Port 2376 -EnableSSL
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ConnectionName,

        [Parameter(Mandatory)]
        [ValidateSet('SSH', 'WinRM', 'VMware', 'Hyper-V', 'Docker', 'Kubernetes')]
        [string]$EndpointType,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$HostName,

        [Parameter()]
        [ValidateRange(1, 65535)]
        [int]$Port,

        [Parameter()]
        [string]$CredentialName,

        [Parameter()]
        [ValidateRange(5, 300)]
        [int]$ConnectionTimeout = 30,

        [Parameter()]
        [switch]$EnableSSL,

        [Parameter()]
        [switch]$Force
    )

    begin {
        Write-CustomLog -Level 'INFO' -Message "Creating remote connection: $ConnectionName (Type: $EndpointType, Host: $HostName)"
          # Validate credential if specified
        if ($CredentialName) {
            # Load SecureCredentials module if not already loaded
            if (-not (Get-Module -Name 'SecureCredentials')) {
                try {
                    Import-Module './aither-core/modules/SecureCredentials' -Force
                } catch {
                    Write-CustomLog -Level 'WARN' -Message "Could not load SecureCredentials module for credential validation"
                }
            }
            
            # Test credential if SecureCredentials is available
            if (Get-Command -Name 'Test-SecureCredential' -ErrorAction SilentlyContinue) {
                if (-not (Test-SecureCredential -CredentialName $CredentialName)) {
                    Write-CustomLog -Level 'WARN' -Message "Specified credential '$CredentialName' not found"
                }
            } else {
                Write-CustomLog -Level 'WARN' -Message "SecureCredentials module not available for credential validation"
            }
        }
    }

    process {
        try {
            if (-not $PSCmdlet.ShouldProcess($ConnectionName, "Create remote connection")) {
                return @{
                    Success = $true
                    ConnectionName = $ConnectionName
                    EndpointType = $EndpointType
                    HostName = $HostName
                    WhatIf = $true
                }
            }

            # Check if connection already exists
            $existingConnection = Get-RemoteConnection -ConnectionName $ConnectionName
            if ($existingConnection -and -not $Force) {
                throw "Connection '$ConnectionName' already exists. Use -Force to overwrite."
            }

            # Set default ports based on endpoint type
            if (-not $Port) {
                $Port = switch ($EndpointType) {
                    'SSH' { 22 }
                    'WinRM' { if ($EnableSSL) { 5986 } else { 5985 } }
                    'VMware' { 443 }
                    'Hyper-V' { 5985 }
                    'Docker' { if ($EnableSSL) { 2376 } else { 2375 } }
                    'Kubernetes' { 6443 }
                    default { 22 }
                }
            }

            # Create connection configuration
            $connectionConfig = @{
                Name = $ConnectionName
                EndpointType = $EndpointType
                HostName = $HostName
                Port = $Port
                CredentialName = $CredentialName
                ConnectionTimeout = $ConnectionTimeout
                EnableSSL = $EnableSSL.IsPresent
                CreatedDate = Get-Date
                LastModified = Get-Date
                LastUsed = $null
                Status = 'Configured'
            }

            # Add endpoint-specific configuration
            switch ($EndpointType) {
                'SSH' {
                    $connectionConfig.SSHOptions = @{
                        StrictHostKeyChecking = $false
                        UserKnownHostsFile = '/dev/null'
                        ServerAliveInterval = 60
                    }
                }
                'WinRM' {
                    $connectionConfig.WinRMOptions = @{
                        Authentication = 'Default'
                        AllowUnencrypted = -not $EnableSSL
                        MaxEnvelopeSizeKB = 500
                        MaxTimeoutMS = $ConnectionTimeout * 1000
                    }
                }
                'VMware' {
                    $connectionConfig.VMwareOptions = @{
                        IgnoreSSLErrors = $true
                        DefaultVIServerMode = 'Single'
                    }
                }
                'Hyper-V' {
                    $connectionConfig.HyperVOptions = @{
                        ComputerName = $HostName
                        Authentication = 'Default'
                        CertificateThumbprint = $null
                    }
                }
                'Docker' {
                    $connectionConfig.DockerOptions = @{
                        APIVersion = 'v1.41'
                        TLSVerify = $EnableSSL
                    }
                }
                'Kubernetes' {
                    $connectionConfig.KubernetesOptions = @{
                        SkipTLSVerify = $false
                        Namespace = 'default'
                    }
                }
            }

            # Store connection configuration
            $connectionPath = Get-ConnectionMetadataPath
            if (-not (Test-Path $connectionPath)) {
                New-Item -Path $connectionPath -ItemType Directory -Force | Out-Null
            }

            $configFile = Join-Path $connectionPath "$ConnectionName.json"
            $connectionConfig | ConvertTo-Json -Depth 10 | Set-Content -Path $configFile

            Write-CustomLog -Level 'SUCCESS' -Message "Remote connection '$ConnectionName' created successfully"

            return @{
                Success = $true
                ConnectionName = $ConnectionName
                EndpointType = $EndpointType
                HostName = $HostName
                Port = $Port
                CredentialName = $CredentialName
                ConfigFile = $configFile
                CreatedDate = $connectionConfig.CreatedDate
            }

        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Failed to create remote connection '$ConnectionName': $($_.Exception.Message)"
            throw
        }
    }
}

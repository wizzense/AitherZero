#Requires -Version 7.0
# Stage: Infrastructure
# Dependencies: None
# Description: Install and configure Certificate Authority
# Tags: security, certificates, ca, infrastructure
# Condition: IsWindows -eq $true

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter()]
    [hashtable]$Configuration
)

# Initialize logging
$script:LoggingAvailable = $false
try {
    $loggingPath = Join-Path (Split-Path $PSScriptRoot -Parent) "domains/utilities/Logging.psm1"
    if (Test-Path $loggingPath) {
        Import-Module $loggingPath -Force -Global
        $script:LoggingAvailable = $true
    }
} catch {
    # Fallback to basic output if logging module fails to load
    Write-Warning "Could not load logging module: $($_.Exception.Message)"
    $script:LoggingAvailable = $false
}

function Write-ScriptLog {
    param(
        [string]$Message,
        [string]$Level = 'Information'
    )

    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Message $Message -Level $Level
    } else {
        $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        $prefix = switch ($Level) {
            'Error' { 'ERROR' }
            'Warning' { 'WARN' }
            'Debug' { 'DEBUG' }
            default { 'INFO' }
        }
        Write-Host "[$timestamp] [$prefix] $Message"
    }
}

Write-ScriptLog "Starting Certificate Authority installation check"

try {
    # Skip on non-Windows platforms
    if (-not $IsWindows) {
        Write-ScriptLog "Certificate Authority installation is Windows-specific. Skipping on this platform."
        exit 0
    }

    # Get configuration
    $config = if ($Configuration) { $Configuration } else { @{} }

    # Check if CA installation is enabled
    $shouldInstall = $false
    $caConfig = @{
        InstallCA = $false
        CommonName = "$env:COMPUTERNAME-RootCA"
        ValidityYears = 5
    }

    if ($config.CertificateAuthority) {
        $caConfig = $config.CertificateAuthority
        $shouldInstall = $caConfig.InstallCA -eq $true
    }

    if (-not $shouldInstall) {
        Write-ScriptLog "Certificate Authority installation is not enabled in configuration"
        exit 0
    }

    # Check Windows edition - CA requires Server edition
    $os = Get-CimInstance Win32_OperatingSystem
    $edition = $os.Caption

    if ($edition -notmatch 'Server') {
        Write-ScriptLog "Certificate Authority requires Windows Server edition. Current: $edition" -Level 'Warning'
        
        # On non-server Windows, we can create a self-signed root certificate instead
        Write-ScriptLog "Creating self-signed root certificate for development use..."
        
        try {
            # Check if certificate already exists
            $existingCert = Get-ChildItem -Path Cert:\LocalMachine\Root | 
                Where-Object { $_.Subject -like "*$($caConfig.CommonName)*" }

            if ($existingCert) {
                Write-ScriptLog "Root certificate already exists: $($existingCert.Subject)"
                exit 0
            }

            # Create self-signed root certificate
            $cert = New-SelfSignedCertificate `
                -Type Custom `
                -KeySpec Signature `
                -Subject "CN=$($caConfig.CommonName)" `
                -KeyExportPolicy Exportable `
                -HashAlgorithm sha256 `
                -KeyLength 2048 `
                -CertStoreLocation "Cert:\LocalMachine\My" `
                -KeyUsageProperty Sign `
                -KeyUsage CertSign, CRLSign `
                -NotAfter (Get-Date).AddYears($caConfig.ValidityYears)
            
            Write-ScriptLog "Created self-signed root certificate: $($cert.Subject)"

            # Move to Trusted Root store
            $rootStore = New-Object System.Security.Cryptography.X509Certificates.X509Store(
                [System.Security.Cryptography.X509Certificates.StoreName]::Root,
                [System.Security.Cryptography.X509Certificates.StoreLocation]::LocalMachine
            )
        
            $rootStore.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)
            $rootStore.Add($cert)
            $rootStore.Close()
            
            Write-ScriptLog "Installed root certificate to Trusted Root Certification Authorities"

            # Export certificate for distribution
            $certPath = Join-Path (Split-Path $PSScriptRoot -Parent) "certificates"
            if (-not (Test-Path $certPath)) {
                New-Item -ItemType Directory -Path $certPath -Force | Out-Null
            }
            
            $exportPath = Join-Path $certPath "$($caConfig.CommonName).cer"
            Export-Certificate -Cert $cert -FilePath $exportPath -Type CERT
            Write-ScriptLog "Exported root certificate to: $exportPath"
            
        } catch {
            Write-ScriptLog "Failed to create self-signed certificate: $_" -Level 'Error'
            throw
        }
        
        exit 0
    }

    # Check if running as administrator
    $currentPrincipal = [Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-ScriptLog "Administrator privileges required to install Certificate Authority" -Level 'Error'
        exit 1
    }

    # Check if ADCS is already installed
    try {
        $adcs = Get-WindowsFeature -Name ADCS-Cert-Authority -ErrorAction SilentlyContinue
        
        if ($adcs -and $adcs.InstallState -eq "Installed") {
            Write-ScriptLog "Certificate Authority role is already installed"

            # Check if CA is configured
            try {
                $caService = Get-Service -Name CertSvc -ErrorAction SilentlyContinue
                if ($caService -and $caService.Status -eq 'Running') {
                    Write-ScriptLog "Certificate Authority service is running"
                    exit 0
                }
            } catch {
                Write-ScriptLog "Certificate Authority role installed but not configured" -Level 'Warning'
            }
        }
    } catch {
        Write-ScriptLog "Cannot check ADCS feature status: $_" -Level 'Warning'
    }
    
    Write-ScriptLog "Installing Certificate Authority role..."
    
    try {
        # Install ADCS role
        $result = Install-WindowsFeature -Name ADCS-Cert-Authority -IncludeManagementTools
        
        if ($result.Success) {
            Write-ScriptLog "Certificate Authority role installed successfully"

            # Configure CA
            Write-ScriptLog "Configuring Certificate Authority..."

            # Determine CA type based on domain membership
            $domain = (Get-CimInstance Win32_ComputerSystem).Domain
            $caType = if ($domain -and $domain -ne 'WORKGROUP') {
                'EnterpriseRootCA'
            } else {
                'StandaloneRootCA'
            }
            
            Write-ScriptLog "Configuring as $caType"

            # Configure CA parameters
            $caParams = @{
                CAType = $caType
                CACommonName = $caConfig.CommonName
                ValidityPeriod = 'Years'
                ValidityPeriodUnits = $caConfig.ValidityYears
                Force = $true
            }

            # Add domain-specific parameters
            if ($caType -eq 'EnterpriseRootCA') {
                $caParams['KeyLength'] = 2048
                $caParams['HashAlgorithmName'] = 'SHA256'
            }
            
            Install-AdcsCertificationAuthority @caParams
            
            Write-ScriptLog "Certificate Authority configured successfully"

            # Start the service
            Start-Service -Name CertSvc
            Write-ScriptLog "Certificate Authority service started"

            # Configure CA settings
            if ($caConfig.Settings) {
                Write-ScriptLog "Applying additional CA settings..."
                
                # Example: Set CRL publication interval
                if ($caConfig.Settings.CRLPeriod) {
                    certutil -setreg CA\CRLPeriod $caConfig.Settings.CRLPeriod
                    certutil -setreg CA\CRLPeriodUnits $caConfig.Settings.CRLPeriodUnits
                }
                
                # Restart service to apply settings
                Restart-Service -Name CertSvc
            }

            # Create certificate templates if specified
            if ($caConfig.Templates -and $caType -eq 'EnterpriseRootCA') {
                Write-ScriptLog "Creating certificate templates..."
                
                foreach ($template in $caConfig.Templates) {
                    try {
                        # This would require AD CS management tools
                        Write-ScriptLog "Template creation requires Active Directory integration" -Level 'Debug'
                    } catch {
                        Write-ScriptLog "Failed to create template: $template" -Level 'Warning'
                    }
                }
            }
            
            Write-ScriptLog "Certificate Authority installation completed successfully"
            
        } else {
            Write-ScriptLog "Failed to install Certificate Authority role" -Level 'Error'
            throw "Installation failed"
        }
        
    } catch {
        Write-ScriptLog "Failed to install Certificate Authority: $_" -Level 'Error'
        throw
    }
    
    exit 0
    
} catch {
    Write-ScriptLog "Certificate Authority installation failed: $_" -Level 'Error'
    exit 1
}
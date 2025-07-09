function Install-EnterpriseCA {
    <#
    .SYNOPSIS
        Installs and configures Active Directory Certificate Services as Enterprise CA.

    .DESCRIPTION
        Automates the installation and configuration of Certificate Services including:
        - ADCS Certificate Authority role installation
        - Web enrollment pages configuration
        - OCSP responder setup
        - Security auditing enablement
        - Basic certificate templates

    .PARAMETER CACommonName
        Common name for the Certificate Authority. Default: "$env:COMPUTERNAME-CA"

    .PARAMETER KeyLength
        RSA key length for CA certificate. Default: 4096

    .PARAMETER ValidityPeriodYears
        CA certificate validity period in years. Default: 10

    .PARAMETER InstallWebEnrollment
        Install IIS web enrollment pages. Default: $true

    .PARAMETER InstallOCSP
        Install OCSP responder service. Default: $true

    .PARAMETER EnableAuditing
        Enable Certificate Services auditing. Default: $true

    .PARAMETER ForceInstall
        Force installation even if CA already exists

    .EXAMPLE
        Install-EnterpriseCA

    .EXAMPLE
        Install-EnterpriseCA -CACommonName "Contoso-Root-CA" -KeyLength 4096 -ValidityPeriodYears 15

    .EXAMPLE
        Install-EnterpriseCA -InstallWebEnrollment $false -InstallOCSP $false
    #>

    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter()]
        [string]$CACommonName = "$env:COMPUTERNAME-CA",

        [Parameter()]
        [ValidateSet(2048, 4096, 8192)]
        [int]$KeyLength = 4096,

        [Parameter()]
        [ValidateRange(1, 50)]
        [int]$ValidityPeriodYears = 10,

        [Parameter()]
        [bool]$InstallWebEnrollment = $true,

        [Parameter()]
        [bool]$InstallOCSP = $true,

        [Parameter()]
        [bool]$EnableAuditing = $true,

        [Parameter()]
        [switch]$ForceInstall
    )

    begin {
        Write-CustomLog -Level 'INFO' -Message "Starting Enterprise Certificate Authority installation"

        # Check if running as Administrator
        $CurrentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
        $Principal = New-Object Security.Principal.WindowsPrincipal($CurrentUser)
        if (-not $Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            throw "This function requires Administrator privileges"
        }

        # Check if domain joined
        if ((Get-WmiObject -Class Win32_ComputerSystem).PartOfDomain -eq $false) {
            throw "This server must be domain-joined to install Enterprise CA"
        }
    }

    process {
        try {
            # Check if ADCS is already installed
            $ExistingCA = Get-WindowsFeature -Name ADCS-Cert-Authority
            if ($ExistingCA.InstallState -eq 'Installed' -and -not $ForceInstall) {
                Write-CustomLog -Level 'WARNING' -Message "Certificate Services already installed. Use -ForceInstall to proceed anyway."
                return
            }

            # Install Certificate Services features
            Write-CustomLog -Level 'INFO' -Message "Installing Certificate Services Windows features"

            $FeaturesToInstall = @('ADCS-Cert-Authority')

            if ($InstallWebEnrollment) {
                $FeaturesToInstall += 'ADCS-Web-Enrollment'
                Write-CustomLog -Level 'INFO' -Message "Including Web Enrollment feature"
            }

            if ($InstallOCSP) {
                $FeaturesToInstall += 'ADCS-Online-Cert'
                Write-CustomLog -Level 'INFO' -Message "Including OCSP Responder feature"
            }

            if ($PSCmdlet.ShouldProcess("Windows Features", "Install $($FeaturesToInstall -join ', ')")) {
                $InstallResult = Install-WindowsFeature -Name $FeaturesToInstall -IncludeManagementTools

                if ($InstallResult.Success -eq $false) {
                    throw "Failed to install Windows features: $($InstallResult.FeatureResult | Where-Object {$_.Success -eq $false} | ForEach-Object {$_.Name})"
                }

                Write-CustomLog -Level 'SUCCESS' -Message "Windows features installed successfully"
            }

            # Configure Certificate Authority
            Write-CustomLog -Level 'INFO' -Message "Configuring Enterprise Root CA: $CACommonName"

            if ($PSCmdlet.ShouldProcess($CACommonName, "Configure as Enterprise Root CA")) {
                $CAParams = @{
                    CAType = 'EnterpriseRootCA'
                    KeyLength = $KeyLength
                    ValidityPeriod = 'Years'
                    ValidityPeriodUnits = $ValidityPeriodYears
                    CACommonName = $CACommonName
                    Force = $true
                }

                Install-AdcsCertificationAuthority @CAParams
                Write-CustomLog -Level 'SUCCESS' -Message "Certificate Authority configured successfully"
            }

            # Configure Web Enrollment if requested
            if ($InstallWebEnrollment -and $PSCmdlet.ShouldProcess("Web Enrollment", "Configure IIS application")) {
                Install-AdcsWebEnrollment -Force
                Write-CustomLog -Level 'SUCCESS' -Message "Web enrollment configured (http://$env:COMPUTERNAME/certsrv/)"
            }

            # Configure OCSP Responder if requested
            if ($InstallOCSP -and $PSCmdlet.ShouldProcess("OCSP Responder", "Configure service")) {
                Install-AdcsOnlineResponder -Force
                Write-CustomLog -Level 'SUCCESS' -Message "OCSP Responder configured successfully"
            }

            # Enable auditing if requested
            if ($EnableAuditing -and $PSCmdlet.ShouldProcess("Certificate Services Auditing", "Enable audit policy")) {
                try {
                    $AuditResult = Start-Process -FilePath 'auditpol.exe' -ArgumentList '/set', '/subcategory:"Certification Services"', '/success:enable', '/failure:enable' -Wait -PassThru

                    if ($AuditResult.ExitCode -eq 0) {
                        Write-CustomLog -Level 'SUCCESS' -Message "Certificate Services auditing enabled"
                    } else {
                        Write-CustomLog -Level 'WARNING' -Message "Failed to enable auditing (exit code: $($AuditResult.ExitCode))"
                    }
                } catch {
                    Write-CustomLog -Level 'WARNING' -Message "Could not enable auditing: $($_.Exception.Message)"
                }
            }

            # Verify installation
            Write-CustomLog -Level 'INFO' -Message "Verifying Certificate Authority installation"

            Start-Sleep -Seconds 5  # Allow services to start

            $CAService = Get-Service -Name 'CertSvc' -ErrorAction SilentlyContinue
            if ($CAService -and $CAService.Status -eq 'Running') {
                Write-CustomLog -Level 'SUCCESS' -Message "Certificate Services is running"
            } else {
                Write-CustomLog -Level 'WARNING' -Message "Certificate Services may not be running properly"
            }

            # Display CA information
            try {
                $CAConfig = certutil.exe -config - -ping
                if ($LASTEXITCODE -eq 0) {
                    Write-CustomLog -Level 'INFO' -Message "CA is responding to configuration requests"
                }
            } catch {
                Write-CustomLog -Level 'WARNING' -Message "Could not verify CA responsiveness"
            }

        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Error during Certificate Authority installation: $($_.Exception.Message)"
            throw
        }
    }

    end {
        Write-CustomLog -Level 'SUCCESS' -Message "Enterprise Certificate Authority installation completed"

        # Provide post-installation recommendations
        $Recommendations = @()
        $Recommendations += "Configure certificate templates for your organization's needs"
        $Recommendations += "Set up certificate auto-enrollment for domain computers and users"
        $Recommendations += "Review and configure CRL distribution points"
        $Recommendations += "Implement certificate archival and recovery procedures"
        $Recommendations += "Monitor Certificate Services event logs regularly"
        $Recommendations += "Back up the CA certificate and private key securely"

        foreach ($Recommendation in $Recommendations) {
            Write-CustomLog -Level 'INFO' -Message "Recommendation: $Recommendation"
        }

        # Display access URLs
        if ($InstallWebEnrollment) {
            Write-CustomLog -Level 'INFO' -Message "Web enrollment URL: http://$env:COMPUTERNAME/certsrv/"
        }

        Write-CustomLog -Level 'INFO' -Message "CA Name: $CACommonName"
        Write-CustomLog -Level 'INFO' -Message "Key Length: $KeyLength bits"
        Write-CustomLog -Level 'INFO' -Message "Validity Period: $ValidityPeriodYears years"
    }
}

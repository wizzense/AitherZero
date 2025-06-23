#Requires -Version 7.0

[CmdletBinding()]
param(
    [Parameter()]
    [object]$Config
)

Import-Module "$env:PROJECT_ROOT/aither-core/modules/LabRunner" -Force
Import-Module "$env:PROJECT_ROOT/aither-core/modules/Logging" -Force

Write-CustomLog "Starting $($MyInvocation.MyCommand.Name)"

Invoke-LabStep -Config $Config -Body {
    Write-CustomLog "Running $($MyInvocation.MyCommand.Name)"

    if (-not $IsWindows) {
        Write-CustomLog "Certificate Authority installation is Windows-specific. Skipping on this platform."
        return
    }

    try {
        # Check if ADCS is already installed
        $adcs = Get-WindowsFeature -Name ADCS-Cert-Authority -ErrorAction SilentlyContinue
        
        if ($adcs -and $adcs.InstallState -eq "Installed") {
            Write-CustomLog "Certificate Authority is already installed"
        } else {
            Write-CustomLog "Installing Certificate Authority..."
            
            # Install ADCS feature
            Install-WindowsFeature -Name ADCS-Cert-Authority -IncludeManagementTools
            
            # Configure CA
            Install-AdcsCertificationAuthority -CAType EnterpriseRootCA -Force
            
            Write-CustomLog "Certificate Authority installed successfully"
        }
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to install Certificate Authority: $($_.Exception.Message)"
        throw
    }

    Write-CustomLog "Completed $($MyInvocation.MyCommand.Name)"
}

Write-CustomLog "Completed $($MyInvocation.MyCommand.Name)"

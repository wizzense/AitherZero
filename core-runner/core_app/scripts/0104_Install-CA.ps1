#Requires -Version 7.0
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory, ValueFromPipeline)]
    [object]$Config
)

Import-Module "$env:PWSH_MODULES_PATH/LabRunner/" -Force
Import-Module "$env:PROJECT_ROOT/core-runner/modules/Logging" -Force

Write-CustomLog "Starting $($MyInvocation.MyCommand.Name)"
if ($Config.InstallCA -eq $true) {
Write-CustomLog "Checking for existing Certificate Authority (Standalone Root CA)..."

# Only proceed if you actually want to install a CA.
if ($null -eq $Config.CertificateAuthority) {
    Write-CustomLog "No CA config found. Skipping CA installation."
    return
}

$CAName        = $Config.CertificateAuthority.CommonName
$ValidityYears = $Config.CertificateAuthority.ValidityYears
$rol        Write-CustomLog "A Certificate Authority is already configured. Skipping installation."
        return
    }

    Write-CustomLog "CA role is installed but no CA is configured. Proceeding with installation."
} else {
    Write-CustomLog "Installing Certificate Authority role..."
    if ($PSCmdlet.ShouldProcess('ADCS role', 'Install CA Windows feature')) {
        Install-WindowsFeature Adcs-Cert-Authority -IncludeManagementTools -ErrorAction Stop
    }
}

# If the script reaches this point, it means no existing CA is detected, and installation should proceed.
Write-CustomLog "Configuring CA: $CAName with $($ValidityYears) year validity..."

if ($PSCmdlet.ShouldProcess($CAName, 'Configure Standalone Root CA')) {
    # Resolve the cmdlet after any Pester mocks have been defined

    $installCmd = Get-Command Install-AdcsCertificationAuthority -ErrorAction SilentlyContinue
    if (-not $installCmd) {
        if (Get-Module -ListAvailable -Name ADCSDeployment) {
            $installCmd = Get-Command Install-AdcsCertificationAuthority -ErrorAction SilentlyContinue
        }
    }
    if (-not $installCmd) {
        Write-CustomLog 'Install-AdcsCertificationAuthority command not found. Ensure AD CS features are available.'
        return
    }
    & $installCmd `
        -CAType StandaloneRootCA `
        -CACommonName $CAName `
        -KeyLength 2048 `
        -HashAlgorithm SHA256 `
        -ValidityPeriod Years `
        -ValidityPeriodUnits $ValidityYears `
        -Force
}

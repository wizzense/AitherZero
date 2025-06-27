#Requires -Version 7.0

[CmdletBinding()]
param(
    [Parameter()]
    [object]$Config
)

Import-Module (Join-Path $env:PROJECT_ROOT (Join-Path "aither-core" (Join-Path "modules" "LabRunner"))) -Force
Import-Module (Join-Path $env:PROJECT_ROOT (Join-Path "aither-core" (Join-Path "modules" "Logging"))) -Force

Write-CustomLog "Starting $($MyInvocation.MyCommand.Name)"

Invoke-LabStep -Config $Config -Body {
    Write-CustomLog "Running $($MyInvocation.MyCommand.Name)"

    if (-not $IsWindows) {
        Write-CustomLog "Windows Admin Center is Windows-specific. Skipping on this platform."
        return
    }

    try {
        # Check if WAC is already installed
        $wac = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\ServerManagementGateway" -ErrorAction SilentlyContinue
        
        if ($wac) {
            Write-CustomLog "Windows Admin Center is already installed"
        } else {
            Write-CustomLog "Installing Windows Admin Center..."
            
            # Download and install WAC
            $downloadUrl = "https://aka.ms/WACDownload"
            $tempFile = Join-Path $env:TEMP "WindowsAdminCenter.msi"
            
            Invoke-WebRequest -Uri $downloadUrl -OutFile $tempFile
            Start-Process -FilePath "msiexec.exe" -ArgumentList "/i", $tempFile, "/quiet" -Wait
            
            Remove-Item $tempFile -ErrorAction SilentlyContinue
            Write-CustomLog "Windows Admin Center installed successfully"
        }
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to install Windows Admin Center: $($_.Exception.Message)"
        throw
    }

    Write-CustomLog "Completed $($MyInvocation.MyCommand.Name)"
}

Write-CustomLog "Completed $($MyInvocation.MyCommand.Name)"

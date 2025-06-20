#Requires -Version 7.0

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter()]
    [object]$Config,

    [Parameter()]
    [switch]$AsJson,

    [Parameter()]
    [ValidateSet('silent', 'normal', 'detailed')]
    [string]$Verbosity = 'normal',

    [Parameter()]
    [switch]$Auto,

    [Parameter()]
    [switch]$Force
)

Import-Module "$env:PWSH_MODULES_PATH/LabRunner/" -Force
Import-Module "$env:PROJECT_ROOT/core-runner/modules/Logging" -Force

# Initialize standardized parameters
$params = Initialize-StandardParameters -InputParameters $PSBoundParameters -ScriptName $MyInvocation.MyCommand.Name

Write-CustomLog "Starting $($MyInvocation.MyCommand.Name)"

function Get-SystemInfo {
    [CmdletBinding()]
    param(
        [Parameter()]
        [switch]$AsJson,

        [Parameter()]
        [object]$Config
    )

    Invoke-LabStep -Config $Config -Body {
        Write-CustomLog "Running $($MyInvocation.MyCommand.Name)"
        $platform = Get-Platform
        Write-CustomLog "Detected platform: $platform"

        $info = [PSCustomObject]@{
            ComputerName = [System.Environment]::MachineName
            OSVersion    = [System.Environment]::OSVersion.VersionString
            Platform     = $platform
            IPAddresses  = @()
        }

        try {
            $info.IPAddresses = @(
                [System.Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces() |
                    Where-Object { $_.OperationalStatus -eq 'Up' } |
                    ForEach-Object { $_.GetIPProperties().UnicastAddresses } |
                    Where-Object { $_.Address.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetwork } |
                    ForEach-Object { $_.Address.ToString() }
            )
        } catch {
            Write-CustomLog "Error getting IP addresses: $($_)" -Level 'WARN'
        }

        switch ($platform) {
            'Windows' {
                if ($IsWindows -or $env:OS -eq 'Windows_NT') {
                    try {
                        $osInfo = [System.Environment]::OSVersion
                        $info | Add-Member -MemberType NoteProperty -Name 'OSName' -Value $osInfo.VersionString
                        $info | Add-Member -MemberType NoteProperty -Name 'ServicePack' -Value $osInfo.ServicePack
                        $info | Add-Member -MemberType NoteProperty -Name 'ProcessorArchitecture' -Value $env:PROCESSOR_ARCHITECTURE
                        $info | Add-Member -MemberType NoteProperty -Name 'NumberOfProcessors' -Value $env:NUMBER_OF_PROCESSORS
                        if (Get-Command Get-ComputerInfo -ErrorAction SilentlyContinue) {
                            $computerInfo = Get-ComputerInfo
                            $info | Add-Member -MemberType NoteProperty -Name 'WindowsSystemInfo' -Value $computerInfo
                        }
                    } catch {
                        Write-CustomLog "Error gathering Windows-specific information: $($_)" -Level 'WARN'
                    }
                }
            }
            'Linux' {
                try { $info.OSVersion = (uname -sr) } catch { Write-CustomLog 'Error getting OS version' -Level 'WARN' }
                try {
                    $distroInfo = if (Test-Path /etc/os-release) { Get-Content /etc/os-release | ConvertFrom-StringData } else { $null }
                    if ($distroInfo) { $info | Add-Member -MemberType NoteProperty -Name 'Distribution' -Value $distroInfo.PRETTY_NAME }
                } catch { Write-CustomLog "Error getting Linux distribution information: $($_)" -Level 'WARN' }
            }
            'MacOS' {
                try {
                    $info.OSVersion = (uname -sr)
                    $swVers = if (Get-Command sw_vers -ErrorAction SilentlyContinue) {
                        @{ ProductName = (sw_vers -productName); ProductVersion = (sw_vers -productVersion); BuildVersion = (sw_vers -buildVersion) }
                    } else { $null }
                    if ($swVers) { $info | Add-Member -MemberType NoteProperty -Name 'MacOSDetails' -Value $swVers }
                } catch { Write-CustomLog "Error getting macOS version information: $($_)" -Level 'WARN' }
            }
            Default { Write-CustomLog "Unsupported platform: $platform" -Level 'WARN' }
        }

        try {
            $info | Add-Member -MemberType NoteProperty -Name 'DiskInfo' -Value @(
                [System.IO.DriveInfo]::GetDrives() |
                    Where-Object { $_.IsReady } |
                    ForEach-Object {
                        [PSCustomObject]@{
                            Name        = $_.Name
                            VolumeLabel = $_.VolumeLabel
                            DriveType   = $_.DriveType
                            SizeGB      = [Math]::Round(($_.TotalSize / 1GB), 2)
                            FreeGB      = [Math]::Round(($_.AvailableFreeSpace / 1GB), 2)
                        }
                    }
            )
        } catch {
            Write-CustomLog "Error getting disk information: $($_)" -Level 'WARN'
        }

        if ($AsJson) {
            return $info | ConvertTo-Json -Depth 5
        } else {
            return $info
        }
    }
}

# Handle WhatIf mode with ShouldProcess
if (-not $params.IsWhatIfMode -and $PSCmdlet.ShouldProcess("Get system information", "Execute gathering")) {
    if ($MyInvocation.InvocationName -ne '.') {
        $systemInfo = Get-SystemInfo -AsJson:$AsJson -Config $params.Config

        # Always show key system information to the user in interactive mode
        if ($params.Verbosity -ne 'silent') {
            Write-Host "`n=== System Information ===" -ForegroundColor Cyan
            Write-Host "Computer Name: $($systemInfo.ComputerName)" -ForegroundColor Green
            Write-Host "Platform: $($systemInfo.Platform)" -ForegroundColor Green
            Write-Host "OS Version: $($systemInfo.OSVersion)" -ForegroundColor Green

            if ($systemInfo.IPAddresses -and $systemInfo.IPAddresses.Count -gt 0) {
                Write-Host "IP Addresses: $($systemInfo.IPAddresses -join ', ')" -ForegroundColor Green
            }

            # Show disk information summary
            if ($systemInfo.DiskInfo -and $systemInfo.DiskInfo.Count -gt 0) {
                Write-Host "`nDisk Information:" -ForegroundColor Yellow
                foreach ($disk in $systemInfo.DiskInfo) {
                    $usedPercent = if ($disk.SizeGB -gt 0) {
                        [Math]::Round((($disk.SizeGB - $disk.FreeGB) / $disk.SizeGB) * 100, 1)
                    } else {
                        0
                    }
                    Write-Host "  $($disk.Name) ($($disk.DriveType)): $($disk.FreeGB)GB free / $($disk.SizeGB)GB total ($usedPercent% used)" -ForegroundColor White
                }
            }
            Write-Host "=========================" -ForegroundColor Cyan
        }

        # If in detailed verbosity mode, show complete detailed information
        if ($params.Verbosity -eq 'detailed') {
            Write-Host "`n=== Detailed System Information ===" -ForegroundColor Magenta
            $systemInfo | Format-List | Out-String | ForEach-Object {
                Write-Host $_ -ForegroundColor Gray
            }
            Write-Host "===================================" -ForegroundColor Magenta
        }

        # Log the completion with summary
        Write-CustomLog "System information gathered successfully. Platform: $($systemInfo.Platform), Computer: $($systemInfo.ComputerName)" -Level SUCCESS
    }
}
else {
    Write-CustomLog "WhatIf: Would gather system information for platform: $(Get-Platform)" -Level INFO
}

Write-CustomLog "Completed $($MyInvocation.MyCommand.Name)"

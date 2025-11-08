#Requires -Version 7.0
# Stage: Validation
# Dependencies: None
# Description: Gather and display comprehensive system information

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter()]
    [hashtable]$Configuration,

    [Parameter()]
    [switch]$AsJson,

    [Parameter()]
    [ValidateSet('Summary', 'Detailed', 'Full')]
    [string]$OutputFormat = 'Summary'
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
    # Fallback to basic output
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

Write-ScriptLog "Starting system information gathering"

try {
    # Get configuration
    $config = if ($Configuration) { $Configuration } else { @{} }

    # Initialize system info object
    $systemInfo = [PSCustomObject]@{
        Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        ComputerName = [System.Environment]::MachineName
        Platform = $null
        OSVersion = [System.Environment]::OSVersion.VersionString
        PowerShellVersion = $PSVersionTable.PSVersion.ToString()
        ProcessorCount = [System.Environment]::ProcessorCount
        IPAddresses = @()
        DiskInfo = @()
        MemoryInfo = @{}
        EnvironmentVariables = @{}
    }

    # Determine platform
    if ($IsWindows) {
        $systemInfo.Platform = 'Windows'
    } elseif ($IsLinux) {
        $systemInfo.Platform = 'Linux'
    } elseif ($IsMacOS) {
        $systemInfo.Platform = 'macOS'
    } else {
        $systemInfo.Platform = 'Unknown'
    }

    Write-ScriptLog "Detected platform: $($systemInfo.Platform)"

    # Get IP addresses
    try {
        $systemInfo.IPAddresses = @(
            [System.Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces() |
                Where-Object { $_.OperationalStatus -eq 'Up' -and $_.NetworkInterfaceType -ne 'Loopback' } |
                ForEach-Object { $_.GetIPProperties().UnicastAddresses } |
                Where-Object { $_.Address.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetwork } |
                ForEach-Object { $_.Address.ToString() } |
                Select-Object -Unique
        )
} catch {
        Write-ScriptLog "Could not get IP addresses: $_" -Level 'Warning'
    }

    # Get disk information
    try {
        $systemInfo.DiskInfo = @(
            [System.IO.DriveInfo]::GetDrives() |
                Where-Object { $_.IsReady } |
                ForEach-Object {
                    [PSCustomObject]@{
                        Name = $_.Name
                        Label = $_.VolumeLabel
                        Type = $_.DriveType.ToString()
                        Format = $_.DriveFormat
                        TotalGB = [Math]::Round($_.TotalSize / 1GB, 2)
                        FreeGB = [Math]::Round($_.AvailableFreeSpace / 1GB, 2)
                        UsedGB = [Math]::Round(($_.TotalSize - $_.AvailableFreeSpace) / 1GB, 2)
                        UsedPercent = [Math]::Round((($_.TotalSize - $_.AvailableFreeSpace) / $_.TotalSize) * 100, 1)
                    }
                }
        )
} catch {
        Write-ScriptLog "Could not get disk information: $_" -Level 'Warning'
    }

    # Platform-specific information
    switch ($systemInfo.Platform) {
        'Windows' {
            # Windows-specific info
            try {
                if (Get-Command Get-CimInstance -ErrorAction SilentlyContinue) {
                    $os = Get-CimInstance Win32_OperatingSystem
                    $systemInfo | Add-Member -MemberType NoteProperty -Name 'WindowsEdition' -Value $os.Caption
                    $systemInfo | Add-Member -MemberType NoteProperty -Name 'WindowsBuild' -Value $os.BuildNumber
                    $systemInfo | Add-Member -MemberType NoteProperty -Name 'InstallDate' -Value $os.InstallDate

                    # Memory info
                    $systemInfo.MemoryInfo = @{
                        TotalGB = [Math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
                        FreeGB = [Math]::Round($os.FreePhysicalMemory / 1MB, 2)
                        UsedGB = [Math]::Round(($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / 1MB, 2)
                    }

                    # Processor info
                    $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
                    $systemInfo | Add-Member -MemberType NoteProperty -Name 'ProcessorName' -Value $cpu.Name
                }
            } catch {
                Write-ScriptLog "Could not get Windows-specific information: $_" -Level 'Warning'
            }
        }

        'Linux' {
            # Linux-specific info
            try {
                if (Test-Path '/etc/os-release') {
                    $osRelease = Get-Content '/etc/os-release' | ConvertFrom-StringData
                    $systemInfo | Add-Member -MemberType NoteProperty -Name 'Distribution' -Value $osRelease.PRETTY_NAME
                    $systemInfo | Add-Member -MemberType NoteProperty -Name 'DistroID' -Value $osRelease.ID
                    $systemInfo | Add-Member -MemberType NoteProperty -Name 'DistroVersion' -Value $osRelease.VERSION_ID
                }

                # Memory info from /proc/meminfo
                if (Test-Path '/proc/meminfo') {
                    $memInfo = Get-Content '/proc/meminfo'
                    $memTotal = ($memInfo | Select-String 'MemTotal:' | ForEach-Object { $_ -replace '[^0-9]', '' }) -as [long]
                    $memFree = ($memInfo | Select-String 'MemFree:' | ForEach-Object { $_ -replace '[^0-9]', '' }) -as [long]

                    if ($memTotal -and $memFree) {
                        $systemInfo.MemoryInfo = @{
                            TotalGB = [Math]::Round($memTotal / 1024 / 1024, 2)
                            FreeGB = [Math]::Round($memFree / 1024 / 1024, 2)
                            UsedGB = [Math]::Round(($memTotal - $memFree) / 1024 / 1024, 2)
                        }
                    }
                }

                # CPU info
                if (Test-Path '/proc/cpuinfo') {
                    $cpuModel = Get-Content '/proc/cpuinfo' | Select-String 'model name' | Select-Object -First 1
                    if ($cpuModel) {
                        $systemInfo | Add-Member -MemberType NoteProperty -Name 'ProcessorName' -Value ($cpuModel -replace 'model name\s*:\s*', '')
                    }
                }
            } catch {
                Write-ScriptLog "Could not get Linux-specific information: $_" -Level 'Warning'
            }
        }

        'macOS' {
            # macOS-specific info
            try {
                if (Get-Command sw_vers -ErrorAction SilentlyContinue) {
                    $systemInfo | Add-Member -MemberType NoteProperty -Name 'ProductName' -Value (& sw_vers -productName)
                    $systemInfo | Add-Member -MemberType NoteProperty -Name 'ProductVersion' -Value (& sw_vers -productVersion)
                    $systemInfo | Add-Member -MemberType NoteProperty -Name 'BuildVersion' -Value (& sw_vers -buildVersion)
                }

                if (Get-Command sysctl -ErrorAction SilentlyContinue) {
                    $cpuBrand = & sysctl -n machdep.cpu.brand_string 2>$null
                    if ($cpuBrand) {
                        $systemInfo | Add-Member -MemberType NoteProperty -Name 'ProcessorName' -Value $cpuBrand
                    }

                    $memSize = & sysctl -n hw.memsize 2>$null
                    if ($memSize) {
                        $systemInfo.MemoryInfo = @{
                            TotalGB = [Math]::Round([long]$memSize / 1GB, 2)
                        }
                    }
                }
            } catch {
                Write-ScriptLog "Could not get macOS-specific information: $_" -Level 'Warning'
            }
        }
    }

    # Get environment variables if detailed output requested
    if ($OutputFormat -in @('Detailed', 'Full')) {
        $systemInfo.EnvironmentVariables = @{
            PATH = $env:PATH
            PSModulePath = $env:PSModulePath
            TEMP = $env:TEMP
            HOME = if ($env:HOME) { $env:HOME } else { $env:USERPROFILE }
        }

        # Add AitherZero-specific variables if present
        $aitherVars = Get-ChildItem env: | Where-Object { $_.Name -like 'AITHER*' -or $_.Name -like 'PROJECT_ROOT*' }
        foreach ($var in $aitherVars) {
            $systemInfo.EnvironmentVariables[$var.Name] = $var.Value
        }
    }

    # Output based on format
    if ($AsJson) {
        $systemInfo | ConvertTo-Json -Depth 10
    } else {
        # Display formatted output
        Write-Host "`n========== System Information ==========" -ForegroundColor Cyan
        Write-Host "Computer Name: $($systemInfo.ComputerName)" -ForegroundColor Green
        Write-Host "Platform: $($systemInfo.Platform)" -ForegroundColor Green
        Write-Host "OS Version: $($systemInfo.OSVersion)" -ForegroundColor Green
        Write-Host "PowerShell: $($systemInfo.PowerShellVersion)" -ForegroundColor Green
        Write-Host "Processors: $($systemInfo.ProcessorCount)" -ForegroundColor Green

        if ($systemInfo.ProcessorName) {
            Write-Host "CPU: $($systemInfo.ProcessorName)" -ForegroundColor Green
        }

        if ($systemInfo.IPAddresses.Count -gt 0) {
            Write-Host "IP Addresses: $($systemInfo.IPAddresses -join ', ')" -ForegroundColor Green
        }

        # Memory information
        if ($systemInfo.MemoryInfo.TotalGB) {
            Write-Host "`nMemory:" -ForegroundColor Yellow
            Write-Host "  Total: $($systemInfo.MemoryInfo.TotalGB) GB" -ForegroundColor White
            if ($systemInfo.MemoryInfo.FreeGB) {
                Write-Host "  Free: $($systemInfo.MemoryInfo.FreeGB) GB" -ForegroundColor White
                Write-Host "  Used: $($systemInfo.MemoryInfo.UsedGB) GB" -ForegroundColor White
            }
        }

        # Disk information
        if ($systemInfo.DiskInfo.Count -gt 0) {
            Write-Host "`nDisk Information:" -ForegroundColor Yellow
            foreach ($disk in $systemInfo.DiskInfo) {
                $color = if ($disk.UsedPercent -gt 90) { 'Red' } elseif ($disk.UsedPercent -gt 80) { 'Yellow' } else { 'White' }
                Write-Host "  $($disk.Name) [$($disk.Type)]:" -ForegroundColor White
                Write-Host "    Total: $($disk.TotalGB) GB | Free: $($disk.FreeGB) GB | Used: $($disk.UsedPercent)%" -ForegroundColor $color
            }
        }

        # Additional details for detailed/full output
        if ($OutputFormat -eq 'Detailed' -or $OutputFormat -eq 'Full') {
            if ($systemInfo.Platform -eq 'Windows' -and $systemInfo.WindowsEdition) {
                Write-Host "`nWindows Details:" -ForegroundColor Yellow
                Write-Host "  Edition: $($systemInfo.WindowsEdition)" -ForegroundColor White
                Write-Host "  Build: $($systemInfo.WindowsBuild)" -ForegroundColor White
            } elseif ($systemInfo.Platform -eq 'Linux' -and $systemInfo.Distribution) {
                Write-Host "`nLinux Details:" -ForegroundColor Yellow
                Write-Host "  Distribution: $($systemInfo.Distribution)" -ForegroundColor White
            } elseif ($systemInfo.Platform -eq 'macOS' -and $systemInfo.ProductName) {
                Write-Host "`nmacOS Details:" -ForegroundColor Yellow
                Write-Host "  Version: $($systemInfo.ProductName) $($systemInfo.ProductVersion)" -ForegroundColor White
                Write-Host "  Build: $($systemInfo.BuildVersion)" -ForegroundColor White
            }
        }

        Write-Host "=======================================" -ForegroundColor Cyan
    }

    Write-ScriptLog "System information gathered successfully"
    exit 0

} catch {
    Write-ScriptLog "Critical error during system information gathering: $_" -Level 'Error'
    Write-ScriptLog $_.ScriptStackTrace -Level 'Error'
    exit 1
}
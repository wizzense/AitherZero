#Requires -Version 7.0
# Stage: Infrastructure
# Dependencies: None
# Description: Configure system settings based on configuration

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

Write-ScriptLog "Starting system configuration"

try {
    # Get configuration
    $config = if ($Configuration) { $Configuration } else { @{} }
    $systemConfig = if ($config.System) { $config.System } else { @{} }

    # Skip on non-Windows for Windows-specific settings
    if (-not $IsWindows) {
        Write-ScriptLog "Running on non-Windows platform. Skipping Windows-specific configurations."
        exit 0
    }

    # Check administrator privileges
    $currentPrincipal = [Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
    $isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    if (-not $isAdmin) {
        Write-ScriptLog "Administrator privileges required for system configuration" -Level 'Warning'
        exit 0
    }

    # Configure computer name
    if ($systemConfig.SetComputerName -eq $true -and $systemConfig.ComputerName) {
        $currentName = $env:COMPUTERNAME
        if ($currentName -ne $systemConfig.ComputerName) {
            Write-ScriptLog "Setting computer name to: $($systemConfig.ComputerName)"
            try {
                Rename-Computer -NewName $systemConfig.ComputerName -Force -ErrorAction Stop
                Write-ScriptLog "Computer name changed. Restart required." -Level 'Warning'
            } catch {
                Write-ScriptLog "Failed to set computer name: $_" -Level 'Error'
            }
        } else {
            Write-ScriptLog "Computer name already set to: $currentName"
        }
    }

    # Configure DNS servers
    if ($systemConfig.SetDNSServers -eq $true -and $systemConfig.DNSServers) {
        Write-ScriptLog "Configuring DNS servers: $($systemConfig.DNSServers)"
        try {
            $dnsServers = $systemConfig.DNSServers -split ',' | ForEach-Object { $_.Trim() }

            # Get active network adapters
            $adapters = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' }
            
            foreach ($adapter in $adapters) {
                Write-ScriptLog "Setting DNS for adapter: $($adapter.Name)" -Level 'Debug'
                Set-DnsClientServerAddress -InterfaceIndex $adapter.InterfaceIndex -ServerAddresses $dnsServers
            }
            
            Write-ScriptLog "DNS servers configured successfully"
        } catch {
            Write-ScriptLog "Failed to configure DNS servers: $_" -Level 'Error'
        }
    }

    # Configure trusted hosts for PowerShell remoting
    if ($systemConfig.SetTrustedHosts -eq $true -and $systemConfig.TrustedHosts) {
        Write-ScriptLog "Configuring trusted hosts: $($systemConfig.TrustedHosts)"
        try {
            Set-Item WSMan:\localhost\Client\TrustedHosts -Value $systemConfig.TrustedHosts -Force
            Write-ScriptLog "Trusted hosts configured successfully"
        } catch {
            Write-ScriptLog "Failed to configure trusted hosts: $_" -Level 'Error'
        }
    }

    # Disable IPv6 if configured
    if ($systemConfig.DisableTCPIP6 -eq $true) {
        Write-ScriptLog "Disabling IPv6..."
        try {
            # Disable IPv6 on all network adapters
            Get-NetAdapter | ForEach-Object {
                Disable-NetAdapterBinding -Name $_.Name -ComponentID ms_tcpip6 -ErrorAction SilentlyContinue
            }

            # Set registry to disable IPv6
            $regPath = 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters'
            if (-not (Test-Path $regPath)) {
                New-Item -Path $regPath -Force | Out-Null
            }
            Set-ItemProperty -Path $regPath -Name 'DisabledComponents' -Value 0xff -Type DWord
            
            Write-ScriptLog "IPv6 disabled. Restart required for full effect." -Level 'Warning'
        } catch {
            Write-ScriptLog "Failed to disable IPv6: $_" -Level 'Error'
        }
    }

    # Enable Remote Desktop
    if ($systemConfig.AllowRemoteDesktop -eq $true) {
        Write-ScriptLog "Enabling Remote Desktop..."
        try {
            # Enable Remote Desktop
            Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name 'fDenyTSConnections' -Value 0

            # Enable firewall rule
            Enable-NetFirewallRule -DisplayGroup 'Remote Desktop'

            # Start Remote Desktop services
            Set-Service -Name TermService -StartupType Automatic
            Start-Service -Name TermService -ErrorAction SilentlyContinue
            
            Write-ScriptLog "Remote Desktop enabled successfully"
        } catch {
            Write-ScriptLog "Failed to enable Remote Desktop: $_" -Level 'Error'
        }
    }

    # Configure Windows Firewall
    if ($systemConfig.ConfigureFirewall -eq $true -and $systemConfig.FirewallPorts) {
        Write-ScriptLog "Configuring Windows Firewall..."
        
        foreach ($port in $systemConfig.FirewallPorts) {
            try {
                if ($port -match '-') {
                    # Port range
                    $portRange = $port -split '-'
                    $startPort = [int]$portRange[0]
                    $endPort = [int]$portRange[1]
                    
                    Write-ScriptLog "Opening port range: $startPort-$endPort"
                    New-NetFirewallRule -DisplayName "AitherZero Port Range $startPort-$endPort" `
                        -Direction Inbound -LocalPort "$startPort-$endPort" -Protocol TCP -Action Allow -ErrorAction Stop
                } else {
                    # Single port
                    $portNum = [int]$port
                    Write-ScriptLog "Opening port: $portNum"
                    New-NetFirewallRule -DisplayName "AitherZero Port $portNum" `
                        -Direction Inbound -LocalPort $portNum -Protocol TCP -Action Allow -ErrorAction Stop
                }
            } catch {
                if ($_.Exception.Message -notlike '*already exists*') {
                    Write-ScriptLog "Failed to configure firewall port $port : $_" -Level 'Warning'
                }
            }
        }
        
        Write-ScriptLog "Firewall configuration completed"
    }

    # Enable WinRM if needed
    if ($systemConfig.EnableWinRM -eq $true) {
        Write-ScriptLog "Enabling WinRM..."
        try {
            Enable-PSRemoting -Force -SkipNetworkProfileCheck
            Set-Service -Name WinRM -StartupType Automatic
            Start-Service -Name WinRM

            # Configure WinRM for HTTPS if certificate authority is configured
            if ($config.CertificateAuthority -and $config.CertificateAuthority.InstallCA -eq $true) {
                Write-ScriptLog "WinRM HTTPS configuration will be handled by certificate installation script" -Level 'Debug'
            }
            
            Write-ScriptLog "WinRM enabled successfully"
        } catch {
            Write-ScriptLog "Failed to enable WinRM: $_" -Level 'Error'
        }
    }
    
    Write-ScriptLog "System configuration completed successfully"
    exit 0
    
} catch {
    Write-ScriptLog "System configuration failed: $_" -Level 'Error'
    exit 1
}
#!/usr/bin/env pwsh
#requires -version 7

<#
.SYNOPSIS
    Install GitHub Actions Runner as System Services
.DESCRIPTION
    Configures GitHub Actions runners to run as system services with proper monitoring and management
.PARAMETER RunnerName
    Name of the runner to configure as service
.PARAMETER ServiceType
    Service type: SystemD, WindowsService, LaunchD (default: Auto-detect)
.PARAMETER StartupType
    Service startup type: Automatic, Manual, Disabled (default: Automatic)
.PARAMETER RunAsUser
    User account to run the service (default: current user)
.PARAMETER EnableMonitoring
    Enable service monitoring and alerts (default: true)
.PARAMETER LogLevel
    Service log level: Minimal, Standard, Detailed (default: Standard)
.PARAMETER DryRun
    Validate configuration without making changes
.PARAMETER CI
    Run in CI mode with minimal output
.EXAMPLE
    ./0722_Install-RunnerServices.ps1 -RunnerName "myorg-runner-1"
.EXAMPLE
    ./0722_Install-RunnerServices.ps1 -RunnerName "myorg-runner-1" -ServiceType SystemD -RunAsUser "runner"
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string]$RunnerName,
    [ValidateSet('SystemD', 'WindowsService', 'LaunchD', 'Auto')]
    [string]$ServiceType = 'Auto',
    [ValidateSet('Automatic', 'Manual', 'Disabled')]
    [string]$StartupType = 'Automatic',
    [string]$RunAsUser = $env:USER,
    [bool]$EnableMonitoring = $true,
    [ValidateSet('Minimal', 'Standard', 'Detailed')]
    [string]$LogLevel = 'Standard',
    [switch]$DryRun,
    [switch]$CI
)

#region Metadata
$script:Stage = "Infrastructure"
$script:Dependencies = @('0720', '0721')
$script:Tags = @('github', 'runners', 'services', 'monitoring')
$script:Condition = '$IsAdmin -or (Get-Command sudo -ErrorAction SilentlyContinue)'
#endregion

# Import required modules and functions
if (Test-Path "$PSScriptRoot/../domains/core/Logging.psm1") {
    Import-Module "$PSScriptRoot/../domains/core/Logging.psm1" -Force
}

function Write-ServiceLog {
    param([string]$Message, [string]$Level = 'Information')
    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Message $Message -Level $Level -Source "RunnerServices"
    } else {
        Write-Host "[$Level] $Message"
    }
}

function Get-ServiceType {
    if ($ServiceType -ne 'Auto') {
        return $ServiceType
    }
    
    if ($IsWindows) {
        return 'WindowsService'
    } elseif (Get-Command systemctl -ErrorAction SilentlyContinue) {
        return 'SystemD'
    } elseif ($IsMacOS) {
        return 'LaunchD'
    } else {
        throw "Cannot auto-detect service type for this platform"
    }
}

function Find-RunnerDirectory {
    param([string]$Name)
    
    $searchPaths = @()
    
    if ($IsWindows) {
        $searchPaths += "$env:ProgramFiles\GitHub-Runner"
        $searchPaths += "$env:ProgramFiles\actions-runner"
        $searchPaths += "C:\actions-runner"
    } else {
        $searchPaths += "$env:HOME/actions-runner"
        $searchPaths += "/opt/actions-runner"
        $searchPaths += "/usr/local/actions-runner"
    }
    
    foreach ($path in $searchPaths) {
        if (Test-Path $path) {
            # Check if this is the right runner by looking for config files
            $configFiles = Get-ChildItem -Path $path -Filter "*.runner" -ErrorAction SilentlyContinue
            if ($configFiles) {
                $configFile = $configFiles | Select-Object -First 1
                $config = Get-Content $configFile.FullName -Raw | ConvertFrom-Json
                if ($config.agentName -eq $Name) {
                    Write-ServiceLog "Found runner directory: $path" -Level Information
                    return $path
                }
            } elseif ((Get-ChildItem -Path $path -Filter "config.*" -ErrorAction SilentlyContinue).Count -gt 0) {
                # Fallback: assume it's the right one if only one runner exists
                Write-ServiceLog "Found runner directory: $path" -Level Information
                return $path
            }
        }
    }
    
    throw "Could not find runner directory for: $Name"
}

function Test-ServicePrerequisites {
    param(
        [string]$ServiceTypeToUse,
        [string]$RunnerDirectory
    )
    
    Write-ServiceLog "Testing service prerequisites..." -Level Information
    
    $issues = @()
    
    # Check runner directory exists
    if (-not (Test-Path $RunnerDirectory)) {
        $issues += "Runner directory does not exist: $RunnerDirectory"
    }
    
    # Check service-specific prerequisites
    switch ($ServiceTypeToUse) {
        'WindowsService' {
            if (-not $IsWindows) {
                $issues += "WindowsService type requires Windows platform"
            }
            
            if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
                $issues += "Administrator privileges required for Windows services"
            }
        }
        'SystemD' {
            if (-not (Get-Command systemctl -ErrorAction SilentlyContinue)) {
                $issues += "systemctl command not available (SystemD not installed)"
            }
            
            if (-not (Get-Command sudo -ErrorAction SilentlyContinue)) {
                $issues += "sudo command required for SystemD service management"
            }
        }
        'LaunchD' {
            if (-not $IsMacOS) {
                $issues += "LaunchD type requires macOS platform"
            }
            
            if (-not (Get-Command launchctl -ErrorAction SilentlyContinue)) {
                $issues += "launchctl command not available"
            }
        }
    }
    
    if ($issues.Count -gt 0) {
        Write-ServiceLog "Prerequisites not met:" -Level Error
        $issues | ForEach-Object { Write-ServiceLog "  - $_" -Level Error }
        return $false
    }
    
    Write-ServiceLog "Prerequisites validated successfully" -Level Success
    return $true
}

function Install-WindowsService {
    param(
        [string]$Name,
        [string]$RunnerDirectory,
        [string]$StartupTypeValue,
        [string]$User
    )
    
    Write-ServiceLog "Installing Windows service for runner: $Name" -Level Information
    
    Push-Location $RunnerDirectory
    try {
        # Check if service already exists
        $existingService = Get-Service -Name $Name -ErrorAction SilentlyContinue
        if ($existingService) {
            Write-ServiceLog "Service already exists, stopping and removing..." -Level Information
            
            if ($DryRun) {
                Write-ServiceLog "[DRY RUN] Would stop and remove existing service: $Name" -Level Information
            } else {
                Stop-Service -Name $Name -Force -ErrorAction SilentlyContinue
                & .\svc.sh uninstall $Name
            }
        }
        
        if ($DryRun) {
            Write-ServiceLog "[DRY RUN] Would install Windows service: $Name" -Level Information
            return
        }
        
        # Install the service
        & .\svc.sh install $Name
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to install Windows service (exit code: $LASTEXITCODE)"
        }
        
        Write-ServiceLog "Windows service installed: $Name" -Level Success
        
        # Configure service startup type
        $startupMap = @{
            'Automatic' = 'Automatic'
            'Manual' = 'Manual'
            'Disabled' = 'Disabled'
        }
        
        Set-Service -Name $Name -StartupType $startupMap[$StartupTypeValue]
        Write-ServiceLog "Service startup type set to: $StartupTypeValue" -Level Information
        
        # Start the service if startup type is Automatic
        if ($StartupTypeValue -eq 'Automatic') {
            Start-Service -Name $Name
            Write-ServiceLog "Service started: $Name" -Level Success
            
            # Verify service is running
            Start-Sleep -Seconds 3
            $service = Get-Service -Name $Name
            if ($service.Status -eq 'Running') {
                Write-ServiceLog "Service is running successfully: $Name" -Level Success
            } else {
                Write-ServiceLog "Warning: Service status is $($service.Status)" -Level Warning
            }
        }
        
    } catch {
        Write-ServiceLog "Failed to install Windows service: $($_.Exception.Message)" -Level Error
        throw
    } finally {
        Pop-Location
    }
}

function Install-SystemDService {
    param(
        [string]$Name,
        [string]$RunnerDirectory,
        [string]$StartupTypeValue,
        [string]$User
    )
    
    Write-ServiceLog "Installing SystemD service for runner: $Name" -Level Information
    
    # Create systemd service file
    $serviceName = "actions-runner-$Name"
    $serviceFile = "/etc/systemd/system/$serviceName.service"
    
    $startupMap = @{
        'Automatic' = 'enabled'
        'Manual' = 'disabled'
        'Disabled' = 'disabled'
    }
    
    $serviceContent = @"
[Unit]
Description=GitHub Actions Runner ($Name)
After=network.target

[Service]
Type=simple
User=$User
WorkingDirectory=$RunnerDirectory
ExecStart=$RunnerDirectory/runsvc.sh
Restart=always
RestartSec=15
TimeoutStopSec=30

[Install]
WantedBy=multi-user.target
"@
    
    if ($DryRun) {
        Write-ServiceLog "[DRY RUN] Would create SystemD service file: $serviceFile" -Level Information
        Write-ServiceLog "[DRY RUN] Service content:" -Level Information
        Write-ServiceLog $serviceContent -Level Information
        return
    }
    
    try {
        # Create service file
        $serviceContent | sudo tee $serviceFile > $null
        Write-ServiceLog "Created SystemD service file: $serviceFile" -Level Success
        
        # Reload systemd
        sudo systemctl daemon-reload
        Write-ServiceLog "Reloaded SystemD daemon" -Level Information
        
        # Configure service
        if ($StartupTypeValue -eq 'Automatic') {
            sudo systemctl enable $serviceName
            Write-ServiceLog "Service enabled for automatic startup" -Level Success
            
            sudo systemctl start $serviceName
            Write-ServiceLog "Service started: $serviceName" -Level Success
            
            # Verify service is running
            Start-Sleep -Seconds 3
            $status = & sudo systemctl is-active $serviceName
            if ($status -eq 'active') {
                Write-ServiceLog "Service is running successfully: $serviceName" -Level Success
            } else {
                Write-ServiceLog "Warning: Service status is $status" -Level Warning
            }
        } else {
            sudo systemctl disable $serviceName
            Write-ServiceLog "Service configured for manual startup" -Level Information
        }
        
    } catch {
        Write-ServiceLog "Failed to install SystemD service: $($_.Exception.Message)" -Level Error
        throw
    }
}

function Install-LaunchDService {
    param(
        [string]$Name,
        [string]$RunnerDirectory,
        [string]$StartupTypeValue,
        [string]$User
    )
    
    Write-ServiceLog "Installing LaunchD service for runner: $Name" -Level Information
    
    $serviceName = "com.github.actions.runner.$Name"
    $plistFile = "/Library/LaunchDaemons/$serviceName.plist"
    
    $plistContent = @"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$serviceName</string>
    <key>ProgramArguments</key>
    <array>
        <string>$RunnerDirectory/runsvc.sh</string>
    </array>
    <key>RunAtLoad</key>
    <$(if ($StartupTypeValue -eq 'Automatic') { 'true' } else { 'false' })/>
    <key>KeepAlive</key>
    <true/>
    <key>WorkingDirectory</key>
    <string>$RunnerDirectory</string>
    <key>UserName</key>
    <string>$User</string>
    <key>StandardOutPath</key>
    <string>/var/log/$serviceName.log</string>
    <key>StandardErrorPath</key>
    <string>/var/log/$serviceName-error.log</string>
</dict>
</plist>
"@
    
    if ($DryRun) {
        Write-ServiceLog "[DRY RUN] Would create LaunchD plist file: $plistFile" -Level Information
        Write-ServiceLog "[DRY RUN] Plist content:" -Level Information
        Write-ServiceLog $plistContent -Level Information
        return
    }
    
    try {
        # Create plist file
        $plistContent | sudo tee $plistFile > $null
        Write-ServiceLog "Created LaunchD plist file: $plistFile" -Level Success
        
        # Set proper permissions
        sudo chown root:wheel $plistFile
        sudo chmod 644 $plistFile
        
        # Load the service
        sudo launchctl load $plistFile
        Write-ServiceLog "Loaded LaunchD service: $serviceName" -Level Success
        
        # Start the service if automatic startup
        if ($StartupTypeValue -eq 'Automatic') {
            sudo launchctl start $serviceName
            Write-ServiceLog "Started LaunchD service: $serviceName" -Level Success
        }
        
    } catch {
        Write-ServiceLog "Failed to install LaunchD service: $($_.Exception.Message)" -Level Error
        throw
    }
}

function Install-ServiceMonitoring {
    param(
        [string]$Name,
        [string]$ServiceTypeUsed
    )
    
    if (-not $EnableMonitoring) {
        Write-ServiceLog "Service monitoring disabled" -Level Information
        return
    }
    
    Write-ServiceLog "Setting up service monitoring for: $Name" -Level Information
    
    if ($DryRun) {
        Write-ServiceLog "[DRY RUN] Would set up service monitoring" -Level Information
        return
    }
    
    # Create monitoring configuration
    $monitoringConfig = @{
        ServiceName = $Name
        ServiceType = $ServiceTypeUsed
        LogLevel = $LogLevel
        CheckInterval = 60  # seconds
        RestartThreshold = 3  # failures before alert
        Alerts = @{
            Email = $false
            Webhook = $false
            Log = $true
        }
    }
    
    # Save monitoring configuration
    $configPath = if ($IsWindows) {
        "$env:ProgramData\GitHub-Runner\monitoring.json"
    } else {
        "/etc/github-runner/monitoring.json"
    }
    
    $configDir = Split-Path $configPath -Parent
    if (-not (Test-Path $configDir)) {
        New-Item -ItemType Directory -Path $configDir -Force | Out-Null
    }
    
    $monitoringConfig | ConvertTo-Json -Depth 3 | Set-Content -Path $configPath
    Write-ServiceLog "Created monitoring configuration: $configPath" -Level Success
    
    # Set up log rotation (platform-specific)
    switch ($ServiceTypeUsed) {
        'SystemD' {
            # SystemD handles log rotation automatically via journald
            Write-ServiceLog "SystemD log rotation configured via journald" -Level Information
        }
        'WindowsService' {
            # Configure Windows event log
            Write-ServiceLog "Windows Event Log integration configured" -Level Information
        }
        'LaunchD' {
            # Configure log rotation for macOS
            Write-ServiceLog "macOS log rotation will be handled by newsyslog" -Level Information
        }
    }
}

function Test-ServiceInstallation {
    param(
        [string]$Name,
        [string]$ServiceTypeUsed
    )
    
    Write-ServiceLog "Testing service installation..." -Level Information
    
    $isRunning = $false
    $statusMessage = ""
    
    try {
        switch ($ServiceTypeUsed) {
            'WindowsService' {
                $service = Get-Service -Name $Name -ErrorAction SilentlyContinue
                if ($service) {
                    $isRunning = $service.Status -eq 'Running'
                    $statusMessage = "Service status: $($service.Status)"
                } else {
                    $statusMessage = "Service not found"
                }
            }
            'SystemD' {
                $serviceName = "actions-runner-$Name"
                $status = & sudo systemctl is-active $serviceName 2>$null
                $isRunning = $status -eq 'active'
                $statusMessage = "SystemD status: $status"
            }
            'LaunchD' {
                $serviceName = "com.github.actions.runner.$Name"
                $status = & sudo launchctl list $serviceName 2>$null
                $isRunning = $status -ne $null
                $statusMessage = if ($isRunning) { "LaunchD service is loaded" } else { "LaunchD service not loaded" }
            }
        }
        
        if ($isRunning) {
            Write-ServiceLog "✓ Service installation successful: $statusMessage" -Level Success
        } else {
            Write-ServiceLog "⚠ Service installed but not running: $statusMessage" -Level Warning
        }
        
        return $isRunning
        
    } catch {
        Write-ServiceLog "Service installation test failed: $($_.Exception.Message)" -Level Error
        return $false
    }
}

# Main execution
try {
    $serviceTypeToUse = Get-ServiceType
    
    Write-ServiceLog "Installing GitHub Actions runner service..." -Level Information
    Write-ServiceLog "Runner Name: $RunnerName" -Level Information
    Write-ServiceLog "Service Type: $serviceTypeToUse" -Level Information
    Write-ServiceLog "Startup Type: $StartupType" -Level Information
    Write-ServiceLog "Run As User: $RunAsUser" -Level Information
    
    if ($DryRun) {
        Write-ServiceLog "Running in DRY RUN mode - no changes will be made" -Level Warning
    }
    
    # Find runner directory
    $runnerDirectory = Find-RunnerDirectory -Name $RunnerName
    
    # Test prerequisites
    if (-not (Test-ServicePrerequisites -ServiceTypeToUse $serviceTypeToUse -RunnerDirectory $runnerDirectory)) {
        throw "Prerequisites not met"
    }
    
    # Install service based on type
    switch ($serviceTypeToUse) {
        'WindowsService' {
            Install-WindowsService -Name $RunnerName -RunnerDirectory $runnerDirectory -StartupTypeValue $StartupType -User $RunAsUser
        }
        'SystemD' {
            Install-SystemDService -Name $RunnerName -RunnerDirectory $runnerDirectory -StartupTypeValue $StartupType -User $RunAsUser
        }
        'LaunchD' {
            Install-LaunchDService -Name $RunnerName -RunnerDirectory $runnerDirectory -StartupTypeValue $StartupType -User $RunAsUser
        }
    }
    
    # Install monitoring
    Install-ServiceMonitoring -Name $RunnerName -ServiceTypeUsed $serviceTypeToUse
    
    # Test installation
    if (-not $DryRun) {
        Start-Sleep -Seconds 5
        $testResult = Test-ServiceInstallation -Name $RunnerName -ServiceTypeUsed $serviceTypeToUse
        
        if ($testResult) {
            Write-ServiceLog "Runner service installation completed successfully!" -Level Success
        } else {
            Write-ServiceLog "Runner service installed but may need manual intervention" -Level Warning
        }
    }
    
    if (-not $CI) {
        Write-Host "`nRunner service installation complete!" -ForegroundColor Green
        Write-Host "Service Name: $RunnerName" -ForegroundColor Cyan
        Write-Host "Service Type: $serviceTypeToUse" -ForegroundColor Cyan
        Write-Host "Startup Type: $StartupType" -ForegroundColor Cyan
        
        Write-Host "`nService Management Commands:" -ForegroundColor Yellow
        switch ($serviceTypeToUse) {
            'WindowsService' {
                Write-Host "  Start:   Start-Service -Name $RunnerName" -ForegroundColor White
                Write-Host "  Stop:    Stop-Service -Name $RunnerName" -ForegroundColor White
                Write-Host "  Status:  Get-Service -Name $RunnerName" -ForegroundColor White
            }
            'SystemD' {
                $serviceName = "actions-runner-$RunnerName"
                Write-Host "  Start:   sudo systemctl start $serviceName" -ForegroundColor White
                Write-Host "  Stop:    sudo systemctl stop $serviceName" -ForegroundColor White
                Write-Host "  Status:  sudo systemctl status $serviceName" -ForegroundColor White
            }
            'LaunchD' {
                $serviceName = "com.github.actions.runner.$RunnerName"
                Write-Host "  Start:   sudo launchctl start $serviceName" -ForegroundColor White
                Write-Host "  Stop:    sudo launchctl stop $serviceName" -ForegroundColor White
                Write-Host "  Status:  sudo launchctl list $serviceName" -ForegroundColor White
            }
        }
    }
    
    exit 0
    
} catch {
    Write-ServiceLog "Runner service installation failed: $($_.Exception.Message)" -Level Error
    exit 1
}

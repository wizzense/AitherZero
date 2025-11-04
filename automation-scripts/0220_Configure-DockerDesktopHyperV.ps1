#Requires -Version 7.0
# Stage: Development
# Dependencies: None
# Description: Configure Docker Desktop with Hyper-V backend and custom VHDX location on Windows
# Tags: development, docker, containers, hyper-v, virtualization, windows

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter()]
    [hashtable]$Configuration,

    [Parameter()]
    [string]$DiskDir = "D:\DockerVM",

    [Parameter()]
    [string]$SkipFeatureInstall = $false
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

Write-ScriptLog "Starting Docker Desktop Hyper-V configuration"

try {
    # Skip on non-Windows platforms
    if (-not $IsWindows) {
        Write-ScriptLog "Docker Desktop Hyper-V configuration is Windows-specific. Skipping on this platform."
        exit 0
    }

    # Check for Administrator privileges
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    $isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    
    if (-not $isAdmin) {
        Write-ScriptLog "This script requires Administrator privileges. Please run as Administrator." -Level 'Error'
        throw "Administrator privileges required"
    }

    # Get configuration
    $config = if ($Configuration) { $Configuration } else { @{} }

    # Define paths
    $DiskPath = Join-Path $DiskDir "DockerDesktop.vhdx"
    $ProgDataDD = "C:\ProgramData\DockerDesktop"
    $VmDataDir = Join-Path $ProgDataDD "vm-data"
    $OldDiskPath = Join-Path $VmDataDir "DockerDesktop.vhdx"
    $AppDataDocker = Join-Path $env:APPDATA "Docker"
    $SettingsJson = Join-Path $AppDataDocker "settings.json"

    # ==================== ENABLE WINDOWS FEATURES ====================
    if (-not $SkipFeatureInstall) {
        Write-ScriptLog "Enabling Windows features (Hyper-V, Containers)..."
        
        if ($PSCmdlet.ShouldProcess('Windows Features', 'Enable Hyper-V and Containers')) {
            try {
                # Check if features are already enabled
                $hypervFeature = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -ErrorAction SilentlyContinue
                $containersFeature = Get-WindowsOptionalFeature -Online -FeatureName Containers -ErrorAction SilentlyContinue

                if ($hypervFeature -and $hypervFeature.State -eq 'Enabled') {
                    Write-ScriptLog "Hyper-V is already enabled"
                } else {
                    Write-ScriptLog "Enabling Hyper-V feature..."
                    $result = dism.exe /Online /Enable-Feature:Microsoft-Hyper-V /All /NoRestart
                    if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq 3010) {
                        Write-ScriptLog "Hyper-V feature enabled successfully"
                    } else {
                        Write-ScriptLog "Failed to enable Hyper-V feature (Exit code: $LASTEXITCODE)" -Level 'Warning'
                    }
                }

                if ($containersFeature -and $containersFeature.State -eq 'Enabled') {
                    Write-ScriptLog "Containers feature is already enabled"
                } else {
                    Write-ScriptLog "Enabling Containers feature..."
                    $result = dism.exe /Online /Enable-Feature:Containers /All /NoRestart
                    if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq 3010) {
                        Write-ScriptLog "Containers feature enabled successfully"
                    } else {
                        Write-ScriptLog "Failed to enable Containers feature (Exit code: $LASTEXITCODE)" -Level 'Warning'
                    }
                }
            } catch {
                Write-ScriptLog "Error enabling Windows features: $_" -Level 'Warning'
            }
        }
    } else {
        Write-ScriptLog "Skipping Windows feature installation (SkipFeatureInstall enabled)"
    }

    # ==================== STOP DOCKER AND SERVICES ====================
    Write-ScriptLog "Stopping Docker Desktop and Hyper-V services..."
    
    if ($PSCmdlet.ShouldProcess('Docker Desktop', 'Stop processes and services')) {
        # Stop Docker Desktop
        try {
            $dockerProcess = Get-Process -Name "Docker Desktop" -ErrorAction SilentlyContinue
            if ($dockerProcess) {
                Write-ScriptLog "Stopping Docker Desktop process..."
                Stop-Process -Name "Docker Desktop" -Force -ErrorAction SilentlyContinue
                Start-Sleep -Seconds 2
            }
        } catch {
            Write-ScriptLog "Docker Desktop process not running or already stopped" -Level 'Debug'
        }

        # Stop Hyper-V service
        try {
            $vmmsService = Get-Service -Name vmms -ErrorAction SilentlyContinue
            if ($vmmsService -and $vmmsService.Status -eq 'Running') {
                Write-ScriptLog "Stopping Hyper-V Virtual Machine Management service..."
                Stop-Service -Name vmms -Force -ErrorAction SilentlyContinue
                Start-Sleep -Seconds 2
            }
        } catch {
            Write-ScriptLog "Hyper-V service not running or already stopped" -Level 'Debug'
        }
    }

    # ==================== CLEAN UP STALE VMS ====================
    Write-ScriptLog "Checking for stale Docker Hyper-V VMs..."
    
    if ($PSCmdlet.ShouldProcess('Docker VMs', 'Remove stale Hyper-V VMs')) {
        try {
            $dockerVMs = Get-VM -Name "*docker*" -ErrorAction SilentlyContinue
            if ($dockerVMs) {
                Write-ScriptLog "Removing $($dockerVMs.Count) stale Docker VM(s)..."
                $dockerVMs | Remove-VM -Force -ErrorAction SilentlyContinue
            } else {
                Write-ScriptLog "No stale Docker VMs found"
            }
        } catch {
            Write-ScriptLog "Could not query or remove Hyper-V VMs: $_" -Level 'Debug'
        }
    }

    # ==================== PREPARE DIRECTORIES ====================
    Write-ScriptLog "Preparing directory structure..."
    
    if ($PSCmdlet.ShouldProcess('Docker directories', 'Create directory structure')) {
        # Create directories
        $directories = @($ProgDataDD, $VmDataDir, $DiskDir, $AppDataDocker)
        foreach ($dir in $directories) {
            if (-not (Test-Path $dir)) {
                Write-ScriptLog "Creating directory: $dir"
                New-Item -ItemType Directory -Force -Path $dir | Out-Null
            } else {
                Write-ScriptLog "Directory already exists: $dir" -Level 'Debug'
            }
        }
    }

    # ==================== PRE-CONFIGURE SETTINGS ====================
    Write-ScriptLog "Pre-configuring Docker Desktop settings to use $DiskDir..."
    
    if ($PSCmdlet.ShouldProcess($SettingsJson, 'Create Docker settings file')) {
        # Create minimal settings JSON with diskImageLocation set
        $settings = @{
            "diskImageLocation" = $DiskDir
            "useWslEngine"      = $false
        }
        
        try {
            $settings | ConvertTo-Json -Depth 3 | Set-Content -Path $SettingsJson -Encoding UTF8 -Force
            Write-ScriptLog "Docker settings configured successfully"
        } catch {
            Write-ScriptLog "Failed to create Docker settings file: $_" -Level 'Warning'
        }
    }

    # ==================== INSTALL DOCKER DESKTOP ====================
    Write-ScriptLog "Installing Docker Desktop via winget..."
    
    # Check if winget is available
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-ScriptLog "winget is not available. Install App Installer from Microsoft Store, then re-run this script." -Level 'Error'
        throw "winget not available"
    }

    # Check if Docker Desktop is already installed
    $dockerInstalled = $false
    try {
        $dockerExe = "C:\Program Files\Docker\Docker\Docker Desktop.exe"
        if (Test-Path $dockerExe) {
            Write-ScriptLog "Docker Desktop is already installed at: $dockerExe"
            $dockerInstalled = $true
        }
    } catch {
        Write-ScriptLog "Docker Desktop not found, proceeding with installation" -Level 'Debug'
    }

    if (-not $dockerInstalled) {
        if ($PSCmdlet.ShouldProcess('Docker Desktop', 'Install via winget')) {
            Write-ScriptLog "Installing Docker Desktop (this may take several minutes)..."
            
            try {
                $installArgs = @(
                    'install',
                    '--id', 'Docker.DockerDesktop',
                    '-e',
                    '--silent',
                    '--accept-package-agreements',
                    '--accept-source-agreements'
                )
                
                $process = Start-Process -FilePath 'winget' -ArgumentList $installArgs -Wait -PassThru -NoNewWindow
                
                if ($process.ExitCode -eq 0) {
                    Write-ScriptLog "Docker Desktop installed successfully"
                } else {
                    Write-ScriptLog "Docker Desktop installation completed with exit code: $($process.ExitCode)" -Level 'Warning'
                }
            } catch {
                Write-ScriptLog "Docker Desktop installation failed: $_" -Level 'Error'
                throw
            }
        }
    }

    # ==================== INITIALIZE DOCKER ====================
    Write-ScriptLog "Starting Docker Desktop once to initialize VM..."
    
    # Find Docker Desktop executable
    $dockerExe = "C:\Program Files\Docker\Docker\Docker Desktop.exe"
    if (-not (Test-Path $dockerExe)) {
        # Check alternative location
        $dockerExe = "C:\Program Files (x86)\Docker\Docker\Docker Desktop.exe"
    }

    if (-not (Test-Path $dockerExe)) {
        Write-ScriptLog "Docker Desktop executable not found at expected locations" -Level 'Warning'
    } else {
        if ($PSCmdlet.ShouldProcess($dockerExe, 'Start Docker Desktop for initialization')) {
            try {
                Start-Process -FilePath $dockerExe -ErrorAction Stop
                Write-ScriptLog "Docker Desktop started, waiting 20 seconds for initialization..."
                Start-Sleep -Seconds 20
            } catch {
                Write-ScriptLog "Failed to start Docker Desktop: $_" -Level 'Warning'
            }
        }

        # Stop Docker to relocate VHDX
        Write-ScriptLog "Stopping Docker Desktop to relocate VHDX..."
        
        if ($PSCmdlet.ShouldProcess('Docker Desktop', 'Stop for VHDX relocation')) {
            try {
                Stop-Process -Name "Docker Desktop" -Force -ErrorAction SilentlyContinue
                Start-Sleep -Seconds 3
                
                Stop-Service -Name vmms -Force -ErrorAction SilentlyContinue
                Start-Sleep -Seconds 2
            } catch {
                Write-ScriptLog "Error stopping services: $_" -Level 'Debug'
            }
        }
    }

    # ==================== RELOCATE VHDX ====================
    Write-ScriptLog "Relocating VHDX to $DiskPath..."
    
    # Try to find existing VHDX
    $foundVhdx = $false
    if (Test-Path $OldDiskPath) {
        $foundVhdx = $true
    } else {
        Write-ScriptLog "VHDX not found at default location, searching..."
        $candidate = Get-ChildItem "C:\ProgramData" -Recurse -Filter "DockerDesktop.vhdx" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($candidate) {
            $OldDiskPath = $candidate.FullName
            $foundVhdx = $true
            Write-ScriptLog "Found VHDX at: $OldDiskPath"
        }
    }

    if ($foundVhdx) {
        if ($PSCmdlet.ShouldProcess($OldDiskPath, 'Move VHDX to custom location')) {
            try {
                # Take ownership
                Write-ScriptLog "Taking ownership of VHDX file..."
                $takeownResult = & takeown /F "$OldDiskPath" 2>&1
                
                # Grant permissions
                Write-ScriptLog "Granting permissions..."
                $icaclsResult = & icacls "$OldDiskPath" /grant Administrators:F 2>&1
                
                # Move VHDX
                Write-ScriptLog "Moving VHDX to $DiskPath..."
                Move-Item -Path $OldDiskPath -Destination $DiskPath -Force
                Write-ScriptLog "VHDX relocated successfully"
            } catch {
                Write-ScriptLog "Error relocating VHDX: $_" -Level 'Warning'
            }
        }
    } else {
        Write-ScriptLog "No existing VHDX found to move. Docker will create one at $DiskDir on next start."
    }

    # ==================== RESTORE PERMISSIONS ====================
    Write-ScriptLog "Restoring Hyper-V access to VHDX (ACL)..."
    
    if (Test-Path $DiskPath) {
        if ($PSCmdlet.ShouldProcess($DiskPath, 'Grant Hyper-V permissions')) {
            try {
                $aclResult = & icacls "$DiskPath" /grant "`"NT VIRTUAL MACHINE\Virtual Machines`":F" 2>&1
                Write-ScriptLog "Hyper-V permissions granted successfully"
            } catch {
                Write-ScriptLog "Failed to grant Hyper-V permissions: $_" -Level 'Warning'
            }
        }
    }

    # ==================== RESTART SERVICES ====================
    Write-ScriptLog "Restarting Hyper-V service..."
    
    if ($PSCmdlet.ShouldProcess('vmms', 'Start Hyper-V service')) {
        try {
            Start-Service -Name vmms -ErrorAction Stop
            Write-ScriptLog "Hyper-V service started successfully"
        } catch {
            Write-ScriptLog "Failed to start Hyper-V service: $_" -Level 'Warning'
        }
    }

    # ==================== FINALIZE ====================
    Write-ScriptLog "Launching Docker Desktop..."
    
    if ($dockerExe -and (Test-Path $dockerExe)) {
        if ($PSCmdlet.ShouldProcess($dockerExe, 'Start Docker Desktop')) {
            try {
                Start-Process -FilePath $dockerExe -ErrorAction Stop
                Write-ScriptLog "Docker Desktop started successfully"
            } catch {
                Write-ScriptLog "Failed to start Docker Desktop: $_" -Level 'Warning'
            }
        }
    }

    # ==================== VERIFICATION ====================
    Write-ScriptLog "Configuration completed. Verification hints:"
    Write-ScriptLog " - Disk image location should be $DiskDir in Docker Desktop -> Settings -> Resources -> Advanced"
    Write-ScriptLog " - Actual VHDX path: $DiskPath"
    Write-ScriptLog " - If Docker shows Hyper-V setup errors, REBOOT once (features just enabled) and re-run this script"

    # Check for pending reboot
    try {
        $pendingReboot = Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired"
        if ($pendingReboot) {
            Write-ScriptLog "Windows indicates a reboot may be required to finalize Hyper-V/Containers features." -Level 'Warning'
            Write-ScriptLog "Please reboot and run this script again if Docker fails to start." -Level 'Warning'
        }
    } catch {
        Write-ScriptLog "Could not check pending reboot status" -Level 'Debug'
    }

    Write-ScriptLog "Docker Desktop Hyper-V configuration completed successfully"
    exit 0

} catch {
    Write-ScriptLog "Docker Desktop Hyper-V configuration failed: $_" -Level 'Error'
    Write-ScriptLog "Stack trace: $($_.ScriptStackTrace)" -Level 'Debug'
    exit 1
}

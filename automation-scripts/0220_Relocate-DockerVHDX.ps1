#Requires -Version 7.0
# Stage: Development
# Dependencies: 0105_Install-HyperV, 0208_Install-Docker
# Description: Relocate Docker Desktop VHDX to custom disk location on Windows
# Tags: development, docker, containers, hyper-v, vhdx, storage

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter()]
    [hashtable]$Configuration,

    [Parameter()]
    [string]$DiskDir = "D:\DockerVM"
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

Write-ScriptLog "Starting Docker Desktop VHDX relocation"

try {
    # Skip on non-Windows platforms
    if (-not $IsWindows) {
        Write-ScriptLog "Docker Desktop VHDX relocation is Windows-specific. Skipping on this platform."
        exit 0
    }

    # Check for Administrator privileges
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    $isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    
    if (-not $isAdmin) {
        Write-ScriptLog "This script requires Administrator privileges. Please run as Administrator." -Level 'Error'
        throw "Administrator privileges required"
    }

    # Check prerequisites
    Write-ScriptLog "Checking prerequisites..."
    
    # Check if Docker Desktop is installed
    $dockerExe = "C:\Program Files\Docker\Docker\Docker Desktop.exe"
    if (-not (Test-Path $dockerExe)) {
        $dockerExe = "C:\Program Files (x86)\Docker\Docker\Docker Desktop.exe"
    }
    
    if (-not (Test-Path $dockerExe)) {
        Write-ScriptLog "Docker Desktop is not installed. Please run 0208_Install-Docker.ps1 first." -Level 'Error'
        throw "Docker Desktop not found"
    }
    
    # Check if Hyper-V is enabled
    try {
        $vmms = Get-Service -Name vmms -ErrorAction Stop
        Write-ScriptLog "Hyper-V service found"
    } catch {
        Write-ScriptLog "Hyper-V is not installed or enabled. Please run 0105_Install-HyperV.ps1 first." -Level 'Error'
        throw "Hyper-V not available"
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

    # ==================== STOP DOCKER AND SERVICES ====================
    Write-ScriptLog "Stopping Docker Desktop and Hyper-V services..."
    
    if ($PSCmdlet.ShouldProcess('Docker Desktop', 'Stop processes and services')) {
        # Stop Docker Desktop
        try {
            $dockerProcess = Get-Process -Name "Docker Desktop" -ErrorAction SilentlyContinue
            if ($dockerProcess) {
                Write-ScriptLog "Stopping Docker Desktop process..."
                Stop-Process -Name "Docker Desktop" -Force -ErrorAction SilentlyContinue
                Start-Sleep -Seconds 3
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

    # ==================== CONFIGURE SETTINGS ====================
    Write-ScriptLog "Configuring Docker Desktop settings for $DiskDir..."
    
    if ($PSCmdlet.ShouldProcess($SettingsJson, 'Update Docker settings file')) {
        # Read existing settings if they exist
        $settings = @{}
        if (Test-Path $SettingsJson) {
            try {
                $existingSettings = Get-Content $SettingsJson -Raw | ConvertFrom-Json
                # Convert to hashtable
                $existingSettings.PSObject.Properties | ForEach-Object {
                    $settings[$_.Name] = $_.Value
                }
                Write-ScriptLog "Loaded existing Docker settings"
            } catch {
                Write-ScriptLog "Could not parse existing settings, creating new file" -Level 'Debug'
            }
        }
        
        # Update disk location and ensure Hyper-V backend
        $settings["diskImageLocation"] = $DiskDir
        $settings["useWslEngine"] = $false
        
        try {
            $settings | ConvertTo-Json -Depth 10 | Set-Content -Path $SettingsJson -Encoding UTF8 -Force
            Write-ScriptLog "Docker settings updated successfully"
        } catch {
            Write-ScriptLog "Failed to update Docker settings file: $_" -Level 'Warning'
        }
    }

    # ==================== RELOCATE VHDX ====================
    Write-ScriptLog "Relocating VHDX to $DiskPath..."
    
    # Try to find existing VHDX
    $foundVhdx = $false
    if (Test-Path $OldDiskPath) {
        $foundVhdx = $true
        Write-ScriptLog "Found VHDX at default location: $OldDiskPath"
    } else {
        Write-ScriptLog "VHDX not found at default location, searching..."
        $candidate = Get-ChildItem "C:\ProgramData" -Recurse -Filter "DockerDesktop.vhdx" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($candidate) {
            $OldDiskPath = $candidate.FullName
            $foundVhdx = $true
            Write-ScriptLog "Found VHDX at: $OldDiskPath"
        }
    }

    if ($foundVhdx -and -not (Test-Path $DiskPath)) {
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
                Write-ScriptLog "Error relocating VHDX: $_" -Level 'Error'
                throw
            }
        }
    } elseif (Test-Path $DiskPath) {
        Write-ScriptLog "VHDX already exists at target location: $DiskPath"
    } else {
        Write-ScriptLog "No existing VHDX found. Docker will create one at $DiskDir on next start."
    }

    # ==================== RESTORE PERMISSIONS ====================
    Write-ScriptLog "Setting Hyper-V permissions on VHDX..."
    
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
    Write-ScriptLog "Starting Docker Desktop..."
    
    if ($PSCmdlet.ShouldProcess($dockerExe, 'Start Docker Desktop')) {
        try {
            Start-Process -FilePath $dockerExe -ErrorAction Stop
            Write-ScriptLog "Docker Desktop started successfully"
        } catch {
            Write-ScriptLog "Failed to start Docker Desktop: $_" -Level 'Warning'
        }
    }

    # ==================== VERIFICATION ====================
    Write-ScriptLog "VHDX relocation completed. Verification:"
    Write-ScriptLog " - New VHDX location: $DiskPath"
    Write-ScriptLog " - Settings file: $SettingsJson"
    Write-ScriptLog " - Verify in Docker Desktop: Settings -> Resources -> Advanced -> Disk image location"

    Write-ScriptLog "Docker Desktop VHDX relocation completed successfully"
    exit 0

} catch {
    Write-ScriptLog "Docker Desktop VHDX relocation failed: $_" -Level 'Error'
    Write-ScriptLog "Stack trace: $($_.ScriptStackTrace)" -Level 'Debug'
    exit 1
}

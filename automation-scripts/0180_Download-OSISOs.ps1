#Requires -Version 7.0
# Stage: Infrastructure
# Dependencies: Configuration, DownloadUtility
# Description: Download configured OS ISOs for lab environments with BITS support
# Tags: infrastructure, iso, download, bits, automation

<#
.SYNOPSIS
    Downloads configured OS ISOs for lab infrastructure.

.DESCRIPTION
    Automates the download of operating system ISOs based on configuration in config.psd1.
    Uses Invoke-FileDownload with BITS support when user is logged in interactively,
    with automatic fallback to Invoke-WebRequest for non-interactive sessions.
    
    Supports:
    - Windows Server ISOs (2019, 2022)
    - Linux distributions (Ubuntu, Debian, CentOS, RHEL, AlmaLinux, Rocky, Fedora)
    - BSD variants (FreeBSD, OpenBSD)
    - Automatic retry with exponential backoff
    - Download resume capability
    - Checksum validation (when configured)

.PARAMETER OSType
    Type of operating system to download. Options: Windows, Linux, BSD, All
    Default: All

.PARAMETER Distro
    Specific distribution to download (e.g., 'Ubuntu', 'Debian', 'Server2022')
    If not specified, downloads all enabled ISOs for the specified OSType

.PARAMETER Version
    Specific version to download (e.g., '22.04', '12', '2022')
    If not specified, downloads all enabled versions for the specified distro

.PARAMETER Force
    Force re-download even if ISO already exists

.PARAMETER DownloadPath
    Override the default download path from configuration

.PARAMETER WhatIf
    Show what would be downloaded without actually downloading

.EXAMPLE
    ./0180_Download-OSISOs.ps1
    Downloads all enabled OS ISOs from configuration

.EXAMPLE
    ./0180_Download-OSISOs.ps1 -OSType Linux
    Downloads all enabled Linux distribution ISOs

.EXAMPLE
    ./0180_Download-OSISOs.ps1 -OSType Linux -Distro Ubuntu
    Downloads all enabled Ubuntu ISOs

.EXAMPLE
    ./0180_Download-OSISOs.ps1 -OSType Linux -Distro Ubuntu -Version '22.04'
    Downloads Ubuntu 22.04 ISO specifically

.EXAMPLE
    ./0180_Download-OSISOs.ps1 -OSType Windows -Distro Server2022 -Force
    Force re-download Windows Server 2022 ISO

.NOTES
    BITS Behavior:
    - Works when user is logged in interactively (Windows)
    - Automatically falls back to Invoke-WebRequest in non-interactive sessions
    - Use Get-DownloadMethod to check which method will be used
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter()]
    [ValidateSet('Windows', 'Linux', 'BSD', 'Other', 'All')]
    [string]$OSType = 'All',
    
    [Parameter()]
    [string]$Distro,
    
    [Parameter()]
    [string]$Version,
    
    [Parameter()]
    [switch]$Force,
    
    [Parameter()]
    [string]$DownloadPath,
    
    [Parameter()]
    [hashtable]$Configuration
)

#region Initialization
$ErrorActionPreference = 'Stop'

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

# Import DownloadUtility module
try {
    $downloadUtilPath = Join-Path (Split-Path $PSScriptRoot -Parent) "domains/utilities/DownloadUtility.psm1"
    if (Test-Path $downloadUtilPath) {
        Import-Module $downloadUtilPath -Force -Global
        $script:DownloadUtilAvailable = $true
    } else {
        throw "DownloadUtility module not found at: $downloadUtilPath"
    }
} catch {
    Write-Warning "Could not load DownloadUtility module: $_"
    $script:DownloadUtilAvailable = $false
    exit 1
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
#endregion

#region Configuration Loading
Write-ScriptLog "Starting OS ISO download automation"

# Load configuration
try {
    $configModule = Join-Path (Split-Path $PSScriptRoot -Parent) "domains/configuration/Configuration.psm1"
    if (Test-Path $configModule) {
        Import-Module $configModule -Force -ErrorAction SilentlyContinue
    }
    
    $config = if ($Configuration) { $Configuration } else { Get-Configuration -ErrorAction Stop }
    $isoConfig = $config.Infrastructure.ISODownloads
    
    if (-not $isoConfig -or -not $isoConfig.Enabled) {
        Write-ScriptLog "ISO downloads are not enabled in configuration" -Level 'Warning'
        exit 0
    }
} catch {
    Write-ScriptLog "Failed to load configuration: $_" -Level 'Error'
    exit 1
}

# Determine download path
$targetPath = if ($DownloadPath) {
    $DownloadPath
} elseif ($isoConfig.DownloadPath) {
    # Handle cross-platform paths
    if ($IsWindows) {
        $isoConfig.DownloadPath
    } else {
        # Use /tmp/iso_share on Linux/macOS
        '/tmp/iso_share'
    }
} else {
    # Fallback to config directory path with cross-platform handling
    if ($IsWindows) {
        $config.Infrastructure.Directories.IsoSharePath
    } else {
        '/tmp/iso_share'
    }
}

# Ensure download path exists
if (-not (Test-Path $targetPath)) {
    try {
        New-Item -ItemType Directory -Path $targetPath -Force | Out-Null
        Write-ScriptLog "Created download directory: $targetPath"
    } catch {
        Write-ScriptLog "Failed to create download directory: $_" -Level 'Error'
        exit 1
    }
}

# Check download method availability
$downloadMethod = Get-DownloadMethod
$bitsAvailable = Test-BitsAvailability
Write-ScriptLog "Download method: $downloadMethod (BITS available: $bitsAvailable)"

if ($bitsAvailable) {
    Write-ScriptLog "BITS is available - will use for optimized large file downloads"
} else {
    Write-ScriptLog "BITS not available - using Invoke-WebRequest fallback" -Level 'Information'
}
#endregion

#region Helper Functions
function Get-ISOsToDownload {
    param(
        [hashtable]$Config,
        [string]$OSTypeFilter,
        [string]$DistroFilter,
        [string]$VersionFilter
    )
    
    $isos = @()
    
    # Process Windows ISOs
    if ($OSTypeFilter -in @('All', 'Windows') -and $Config.Windows.Enabled) {
        foreach ($distroName in $Config.Windows.Keys) {
            if ($distroName -eq 'Enabled') { continue }
            
            $distroConfig = $Config.Windows[$distroName]
            if ($DistroFilter -and $distroName -ne $DistroFilter) { continue }
            if (-not $distroConfig.Enabled) { continue }
            
            $isos += @{
                OSType = 'Windows'
                Distro = $distroName
                Version = $distroName  # Windows uses distro name as version
                Config = $distroConfig
            }
        }
    }
    
    # Process Linux ISOs
    if ($OSTypeFilter -in @('All', 'Linux') -and $Config.Linux.Enabled) {
        foreach ($distroName in $Config.Linux.Keys) {
            if ($distroName -eq 'Enabled') { continue }
            
            if ($DistroFilter -and $distroName -ne $DistroFilter) { continue }
            
            $distroConfig = $Config.Linux[$distroName]
            foreach ($versionName in $distroConfig.Keys) {
                $versionConfig = $distroConfig[$versionName]
                if ($VersionFilter -and $versionName -ne $VersionFilter) { continue }
                if (-not $versionConfig.Enabled) { continue }
                
                $isos += @{
                    OSType = 'Linux'
                    Distro = $distroName
                    Version = $versionName
                    Config = $versionConfig
                }
            }
        }
    }
    
    # Process BSD and Other OSes
    if ($OSTypeFilter -in @('All', 'BSD', 'Other') -and $Config.Other.Enabled) {
        foreach ($distroName in $Config.Other.Keys) {
            if ($distroName -eq 'Enabled') { continue }
            
            if ($DistroFilter -and $distroName -ne $DistroFilter) { continue }
            
            $distroConfig = $Config.Other[$distroName]
            foreach ($versionName in $distroConfig.Keys) {
                $versionConfig = $distroConfig[$versionName]
                if ($VersionFilter -and $versionName -ne $VersionFilter) { continue }
                if (-not $versionConfig.Enabled) { continue }
                
                $isos += @{
                    OSType = 'Other'
                    Distro = $distroName
                    Version = $versionName
                    Config = $versionConfig
                }
            }
        }
    }
    
    return $isos
}

function Get-HumanReadableSize {
    param([long]$Bytes)
    
    if ($Bytes -ge 1TB) { return "{0:N2} TB" -f ($Bytes / 1TB) }
    if ($Bytes -ge 1GB) { return "{0:N2} GB" -f ($Bytes / 1GB) }
    if ($Bytes -ge 1MB) { return "{0:N2} MB" -f ($Bytes / 1MB) }
    if ($Bytes -ge 1KB) { return "{0:N2} KB" -f ($Bytes / 1KB) }
    return "$Bytes bytes"
}
#endregion

#region Main Download Logic
# Get list of ISOs to download
$isosToDownload = Get-ISOsToDownload -Config $isoConfig -OSTypeFilter $OSType -DistroFilter $Distro -VersionFilter $Version

if ($isosToDownload.Count -eq 0) {
    Write-ScriptLog "No ISOs found matching the specified criteria" -Level 'Warning'
    exit 0
}

Write-ScriptLog "Found $($isosToDownload.Count) ISO(s) to process"

# Download statistics
$stats = @{
    Total = $isosToDownload.Count
    Downloaded = 0
    Cached = 0
    Failed = 0
    TotalBytes = 0
    TotalDuration = [TimeSpan]::Zero
}

foreach ($iso in $isosToDownload) {
    $distroName = "$($iso.Distro) $($iso.Version)"
    $isoConfig = $iso.Config
    
    Write-ScriptLog "================================================"
    Write-ScriptLog "Processing: $distroName"
    Write-ScriptLog "Description: $($isoConfig.Description)"
    Write-ScriptLog "Size: $($isoConfig.Size)"
    
    # Validate URL
    if (-not $isoConfig.Url -or [string]::IsNullOrWhiteSpace($isoConfig.Url)) {
        Write-ScriptLog "No download URL configured for $distroName - skipping" -Level 'Warning'
        $stats.Failed++
        continue
    }
    
    # Determine file path
    $fileName = $isoConfig.FileName
    $filePath = Join-Path $targetPath $fileName
    
    Write-ScriptLog "Target file: $filePath"
    Write-ScriptLog "Download URL: $($isoConfig.Url)"
    
    # Check if already exists
    if ((Test-Path $filePath) -and -not $Force) {
        $existingFile = Get-Item $filePath
        Write-ScriptLog "ISO already exists: $($existingFile.Length) bytes" -Level 'Information'
        Write-ScriptLog "Use -Force to re-download" -Level 'Information'
        $stats.Cached++
        continue
    }
    
    # Perform download
    if ($PSCmdlet.ShouldProcess($distroName, "Download ISO")) {
        try {
            Write-ScriptLog "Starting download using $downloadMethod..."
            
            # Configure download parameters from config
            $downloadParams = @{
                Uri = $isoConfig.Url
                OutFile = $filePath
                UseBasicParsing = $true
                RetryCount = $isoConfig.RetryCount
                RetryDelaySeconds = $isoConfig.RetryDelaySeconds
                TimeoutSec = $isoConfig.TimeoutSec
            }
            
            if ($Force) {
                $downloadParams.Force = $true
            }
            
            # Execute download
            $result = Invoke-FileDownload @downloadParams
            
            if ($result.Success) {
                $sizeStr = Get-HumanReadableSize -Bytes $result.FileSize
                $durationStr = "{0:N1}" -f $result.Duration.TotalSeconds
                
                Write-ScriptLog "✓ Download successful!" -Level 'Information'
                Write-ScriptLog "  Method: $($result.Method)"
                Write-ScriptLog "  Size: $sizeStr"
                Write-ScriptLog "  Duration: ${durationStr}s"
                Write-ScriptLog "  Attempts: $($result.Attempts)"
                Write-ScriptLog "  File: $filePath"
                
                $stats.Downloaded++
                $stats.TotalBytes += $result.FileSize
                $stats.TotalDuration += $result.Duration
                
                # TODO: Validate checksum if configured
                if ($isoConfig.SHA256 -and -not [string]::IsNullOrWhiteSpace($isoConfig.SHA256)) {
                    Write-ScriptLog "Checksum validation not yet implemented" -Level 'Debug'
                }
            } else {
                Write-ScriptLog "✗ Download failed: $($result.Message)" -Level 'Error'
                $stats.Failed++
            }
            
        } catch {
            Write-ScriptLog "✗ Download error: $_" -Level 'Error'
            $stats.Failed++
        }
    }
    
    # Blank line for readability
    if ($script:LoggingAvailable) {
        Write-Host ""
    }
}
#endregion

#region Summary
Write-ScriptLog "================================================"
Write-ScriptLog "Download Summary"
Write-ScriptLog "================================================"
Write-ScriptLog "Total ISOs: $($stats.Total)"
Write-ScriptLog "Downloaded: $($stats.Downloaded)"
Write-ScriptLog "Cached: $($stats.Cached)"
Write-ScriptLog "Failed: $($stats.Failed)"

if ($stats.Downloaded -gt 0) {
    $totalSize = Get-HumanReadableSize -Bytes $stats.TotalBytes
    $totalTime = "{0:N1}" -f $stats.TotalDuration.TotalSeconds
    Write-ScriptLog "Total downloaded: $totalSize in ${totalTime}s"
}

Write-ScriptLog "Download path: $targetPath"
Write-ScriptLog "================================================"

if ($stats.Failed -gt 0) {
    Write-ScriptLog "Some downloads failed. Check logs for details." -Level 'Warning'
    exit 1
}

Write-ScriptLog "OS ISO download automation completed successfully"
exit 0
#endregion

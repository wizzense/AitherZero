# AitherZero Web Installer
# Compatible with PowerShell 5.1+ on Windows
# This script can be downloaded and executed directly for one-click installation

<#
.SYNOPSIS
    AitherZero Web Installation Script - PowerShell 5.1+ Compatible

.DESCRIPTION
    Downloads and installs AitherZero infrastructure automation framework.
    Fully compatible with Windows PowerShell 5.1 and newer versions.
    
    Features:
    - One-click installation from web
    - PowerShell 5.1+ compatibility
    - Multiple download sources (GitHub releases, main branch)
    - Automatic dependency checking
    - Interactive and silent installation modes
    - Supports installation profiles (minimal, standard, developer, full)

.PARAMETER InstallPath
    Installation directory (defaults to current directory)

.PARAMETER Source
    Installation source: 'release' (latest release) or 'main' (main branch)

.PARAMETER Profile
    Installation profile: minimal, standard, developer, full

.PARAMETER Silent
    Run in silent mode with minimal output

.PARAMETER Force
    Force installation even if directory exists

.PARAMETER SkipDependencies
    Skip dependency checks and installations

.EXAMPLE
    # Download and run (one-liner):
    iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/wizzense/AitherZero/main/install.ps1'))

.EXAMPLE
    # Local execution:
    .\install.ps1

.EXAMPLE
    # Silent installation with developer profile:
    .\install.ps1 -Profile developer -Silent

.EXAMPLE
    # Install specific release to custom location:
    .\install.ps1 -InstallPath "C:\Tools\AitherZero" -Source release -Force

.NOTES
    AitherZero Web Installer v1.0
    Compatible with PowerShell 5.1+ (Windows)
    For Linux/macOS, ensure PowerShell 7+ is installed first
#>

[CmdletBinding()]
param(
    [string]$InstallPath = $PWD.Path,
    
    [ValidateSet('release', 'main', 'develop')]
    [string]$Source = 'release',
    
    [ValidateSet('minimal', 'standard', 'developer', 'full')]
    [string]$Profile = 'standard',
    
    [switch]$Silent,
    
    [switch]$Force,
    
    [switch]$SkipDependencies
)

# Set strict mode and error handling for PowerShell 5.1+ compatibility
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Global configuration
$script:Config = @{
    GitHubOwner = 'wizzense'
    GitHubRepo = 'AitherZero'
    DefaultBranch = 'main'
    InstallDir = 'AitherZero'
    TempDir = [System.IO.Path]::GetTempPath()
    UserAgent = 'AitherZero-WebInstaller/1.0'
}

# Color scheme (PowerShell 5.1 compatible)
$script:Colors = @{
    Primary = 'Cyan'
    Success = 'Green' 
    Warning = 'Yellow'
    Error = 'Red'
    Info = 'Blue'
    Muted = 'DarkGray'
}

function Write-InstallMessage {
    param(
        [string]$Message,
        [ValidateSet('Primary', 'Success', 'Warning', 'Error', 'Info', 'Muted')]
        [string]$Type = 'Info',
        [switch]$NoNewline
    )
    
    if ($Silent) { return }
    
    $color = $script:Colors[$Type]
    $prefix = switch ($Type) {
        'Primary' { '🚀' }
        'Success' { '✅' }
        'Warning' { '⚠️' }
        'Error' { '❌' }
        'Info' { 'ℹ️' }
        'Muted' { '' }
    }
    
    $output = if ($prefix) { "$prefix $Message" } else { $Message }
    
    if ($NoNewline) {
        Write-Host $output -ForegroundColor $color -NoNewline
    } else {
        Write-Host $output -ForegroundColor $color
    }
}

function Write-InstallHeader {
    param([string]$Title)
    
    if ($Silent) { return }
    
    Write-Host ""
    Write-InstallMessage "AitherZero Web Installer - $Title" -Type Primary
    Write-InstallMessage ("=" * 60) -Type Muted
    Write-Host ""
}

function Test-PowerShellCompatibility {
    Write-InstallMessage "Checking PowerShell compatibility..." -Type Info
    
    $psVersion = $PSVersionTable.PSVersion
    $psVersionString = $psVersion.ToString()
    
    if ($psVersion.Major -lt 5) {
        Write-InstallMessage "❌ PowerShell 5.0+ required (detected: $psVersionString)" -Type Error
        Write-InstallMessage "Please upgrade PowerShell: https://aka.ms/powershell" -Type Info
        return $false
    }
    
    if ($psVersion.Major -eq 5) {
        Write-InstallMessage "PowerShell $psVersionString detected (compatible)" -Type Success
        Write-InstallMessage "Consider upgrading to PowerShell 7+ for enhanced features" -Type Warning
    } else {
        Write-InstallMessage "PowerShell $psVersionString detected (optimal)" -Type Success
    }
    
    # Check execution policy (PowerShell 5.1 compatible)
    try {
        $executionPolicy = Get-ExecutionPolicy -Scope CurrentUser -ErrorAction SilentlyContinue
        if ($executionPolicy -eq 'Restricted') {
            Write-InstallMessage "⚠️ Execution policy is Restricted" -Type Warning
            Write-InstallMessage "You may need to run: Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser" -Type Info
        } else {
            Write-InstallMessage "Execution policy: $executionPolicy" -Type Success
        }
    } catch {
        Write-InstallMessage "Could not check execution policy: $($_.Exception.Message)" -Type Warning
    }
    
    return $true
}

function Test-NetworkConnectivity {
    Write-InstallMessage "Testing network connectivity..." -Type Info
    
    try {
        # Test GitHub connectivity (PowerShell 5.1 compatible method)
        $testUrl = "https://api.github.com/repos/$($script:Config.GitHubOwner)/$($script:Config.GitHubRepo)"
        
        # Use .NET WebClient for PowerShell 5.1 compatibility
        $webClient = New-Object System.Net.WebClient
        $webClient.Headers.Add('User-Agent', $script:Config.UserAgent)
        
        # Set timeout
        $webClient.Headers.Add('Cache-Control', 'no-cache')
        
        $null = $webClient.DownloadString($testUrl)
        $webClient.Dispose()
        
        Write-InstallMessage "Network connectivity verified" -Type Success
        return $true
    } catch {
        Write-InstallMessage "Network connectivity test failed: $($_.Exception.Message)" -Type Error
        Write-InstallMessage "Please check your internet connection and try again" -Type Info
        return $false
    }
}

function Get-LatestReleaseInfo {
    Write-InstallMessage "Getting latest release information..." -Type Info
    
    try {
        $apiUrl = "https://api.github.com/repos/$($script:Config.GitHubOwner)/$($script:Config.GitHubRepo)/releases/latest"
        
        # PowerShell 5.1 compatible HTTP request
        $webClient = New-Object System.Net.WebClient
        $webClient.Headers.Add('User-Agent', $script:Config.UserAgent)
        $webClient.Headers.Add('Accept', 'application/vnd.github.v3+json')
        
        $responseJson = $webClient.DownloadString($apiUrl)
        $webClient.Dispose()
        
        # Parse JSON (PowerShell 5.1 compatible)
        if ($PSVersionTable.PSVersion.Major -ge 6) {
            $release = $responseJson | ConvertFrom-Json
        } else {
            # PowerShell 5.1 fallback
            Add-Type -AssemblyName System.Web.Extensions
            $jsonSerializer = New-Object System.Web.Script.Serialization.JavaScriptSerializer
            $release = $jsonSerializer.DeserializeObject($responseJson)
        }
        
        Write-InstallMessage "Found release: $($release.tag_name)" -Type Success
        return $release
    } catch {
        Write-InstallMessage "Failed to get release info: $($_.Exception.Message)" -Type Warning
        Write-InstallMessage "Falling back to main branch download" -Type Info
        return $null
    }
}

function Get-DownloadUrl {
    param([string]$SourceType)
    
    switch ($SourceType) {
        'release' {
            $release = Get-LatestReleaseInfo
            if ($release -and $release.zipball_url) {
                return $release.zipball_url
            } else {
                Write-InstallMessage "Release download not available, using main branch" -Type Warning
                return "https://github.com/$($script:Config.GitHubOwner)/$($script:Config.GitHubRepo)/archive/refs/heads/$($script:Config.DefaultBranch).zip"
            }
        }
        'main' {
            return "https://github.com/$($script:Config.GitHubOwner)/$($script:Config.GitHubRepo)/archive/refs/heads/main.zip"
        }
        'develop' {
            return "https://github.com/$($script:Config.GitHubOwner)/$($script:Config.GitHubRepo)/archive/refs/heads/develop.zip"
        }
        default {
            throw "Unknown source type: $SourceType"
        }
    }
}

function Invoke-Download {
    param(
        [string]$Url,
        [string]$OutputPath
    )
    
    Write-InstallMessage "Downloading AitherZero from: $Url" -Type Info
    
    try {
        # PowerShell 5.1 compatible download with progress
        $webClient = New-Object System.Net.WebClient
        $webClient.Headers.Add('User-Agent', $script:Config.UserAgent)
        
        # Register progress event if not silent
        if (-not $Silent) {
            Register-ObjectEvent -InputObject $webClient -EventName DownloadProgressChanged -Action {
                $progress = $Event.SourceEventArgs
                $percent = [math]::Round(($progress.BytesReceived / $progress.TotalBytesToReceive) * 100, 1)
                Write-Progress -Activity "Downloading AitherZero" -Status "Progress: $percent%" -PercentComplete $percent
            } | Out-Null
        }
        
        # Download the file
        $webClient.DownloadFile($Url, $OutputPath)
        $webClient.Dispose()
        
        # Clean up progress
        if (-not $Silent) {
            Write-Progress -Activity "Downloading AitherZero" -Completed
        }
        
        Write-InstallMessage "Download completed: $(Get-Item $OutputPath | Select-Object -ExpandProperty Length) bytes" -Type Success
        return $true
    } catch {
        Write-InstallMessage "Download failed: $($_.Exception.Message)" -Type Error
        return $false
    }
}

function Expand-DownloadedArchive {
    param(
        [string]$ArchivePath,
        [string]$DestinationPath
    )
    
    Write-InstallMessage "Extracting archive..." -Type Info
    
    try {
        # PowerShell 5.1 compatible extraction
        if ($PSVersionTable.PSVersion.Major -ge 5) {
            # Use built-in Expand-Archive (available in PowerShell 5.0+)
            Expand-Archive -Path $ArchivePath -DestinationPath $DestinationPath -Force
        } else {
            # Fallback for older versions
            Add-Type -AssemblyName System.IO.Compression.FileSystem
            [System.IO.Compression.ZipFile]::ExtractToDirectory($ArchivePath, $DestinationPath)
        }
        
        Write-InstallMessage "Archive extracted successfully" -Type Success
        return $true
    } catch {
        Write-InstallMessage "Failed to extract archive: $($_.Exception.Message)" -Type Error
        return $false
    }
}

function Move-ExtractedContent {
    param(
        [string]$ExtractPath,
        [string]$FinalPath
    )
    
    # Find the extracted directory (GitHub archives create a subdirectory)
    $extractedDirs = Get-ChildItem -Path $ExtractPath -Directory
    
    if ($extractedDirs.Count -eq 1) {
        $sourceDir = $extractedDirs[0].FullName
        
        Write-InstallMessage "Moving content to final location..." -Type Info
        
        # Create destination if it doesn't exist
        if (-not (Test-Path $FinalPath)) {
            New-Item -ItemType Directory -Path $FinalPath -Force | Out-Null
        }
        
        # Move all content from extracted directory to final location
        Get-ChildItem -Path $sourceDir | ForEach-Object {
            $destPath = Join-Path $FinalPath $_.Name
            if (Test-Path $destPath) {
                Remove-Item $destPath -Recurse -Force
            }
            Move-Item $_.FullName $destPath -Force
        }
        
        # Clean up temporary extraction directory
        Remove-Item $ExtractPath -Recurse -Force -ErrorAction SilentlyContinue
        
        Write-InstallMessage "Content moved successfully" -Type Success
        return $true
    } else {
        Write-InstallMessage "Unexpected archive structure" -Type Error
        return $false
    }
}

function Invoke-PostInstallSetup {
    param([string]$InstallDirectory)
    
    Write-InstallMessage "Running post-installation setup..." -Type Info
    
    try {
        # Change to installation directory
        Push-Location $InstallDirectory
        
        # Check for quick-setup script
        $quickSetupPath = Join-Path $InstallDirectory "quick-setup-simple.ps1"
        if (Test-Path $quickSetupPath) {
            Write-InstallMessage "Running quick setup..." -Type Info
            
            # Run setup based on profile and mode
            $setupArgs = @()
            if ($Silent) {
                $setupArgs += '-Auto'
            }
            
            & $quickSetupPath @setupArgs
            
            if ($LASTEXITCODE -eq 0 -or $null -eq $LASTEXITCODE) {
                Write-InstallMessage "Quick setup completed successfully" -Type Success
            } else {
                Write-InstallMessage "Quick setup completed with warnings (exit code: $LASTEXITCODE)" -Type Warning
            }
        } else {
            Write-InstallMessage "Quick setup script not found, skipping automated setup" -Type Warning
        }
    } catch {
        Write-InstallMessage "Post-installation setup failed: $($_.Exception.Message)" -Type Warning
        Write-InstallMessage "You can run setup manually later: .\quick-setup-simple.ps1" -Type Info
    } finally {
        Pop-Location
    }
}

function Show-InstallationSummary {
    param([string]$InstallDirectory)
    
    if ($Silent) { return }
    
    Write-Host ""
    Write-InstallMessage "🎉 AitherZero installation completed!" -Type Success
    Write-Host ""
    Write-InstallMessage "INSTALLATION DETAILS:" -Type Primary
    Write-Host "  Location: $InstallDirectory"
    Write-Host "  Profile: $Profile"
    Write-Host "  Source: $Source"
    Write-Host ""
    Write-InstallMessage "QUICK START:" -Type Primary
    Write-Host "  cd '$InstallDirectory'"
    Write-Host "  .\aither.ps1 help                    # Show all commands"
    Write-Host "  .\aither.ps1 init                    # Run interactive setup"
    Write-Host "  .\aither.ps1 deploy create my-lab    # Create first project"
    Write-Host ""
    Write-InstallMessage "WINDOWS BATCH FILES:" -Type Info
    Write-Host "  aither.bat help                      # Use batch files for easier access"
    Write-Host ""
    Write-InstallMessage "For documentation: https://github.com/$($script:Config.GitHubOwner)/$($script:Config.GitHubRepo)" -Type Muted
}

function Show-ErrorGuidance {
    Write-Host ""
    Write-InstallMessage "TROUBLESHOOTING:" -Type Warning
    Write-Host ""
    Write-Host "If installation failed:"
    Write-Host "  1. Check internet connectivity"
    Write-Host "  2. Run PowerShell as Administrator"
    Write-Host "  3. Set execution policy: Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser"
    Write-Host "  4. Try manual download from: https://github.com/$($script:Config.GitHubOwner)/$($script:Config.GitHubRepo)/releases"
    Write-Host ""
    Write-Host "For support: https://github.com/$($script:Config.GitHubOwner)/$($script:Config.GitHubRepo)/issues"
}

# Main installation logic
try {
    Write-InstallHeader "PowerShell 5.1+ Compatible Installer"
    
    # Prerequisites check
    if (-not (Test-PowerShellCompatibility)) {
        exit 1
    }
    
    if (-not $SkipDependencies -and -not (Test-NetworkConnectivity)) {
        exit 1
    }
    
    # Prepare installation paths
    $finalInstallPath = Join-Path $InstallPath $script:Config.InstallDir
    
    # Check if installation directory exists
    if (Test-Path $finalInstallPath) {
        if ($Force) {
            Write-InstallMessage "Removing existing installation..." -Type Warning
            Remove-Item $finalInstallPath -Recurse -Force
        } else {
            Write-InstallMessage "❌ Installation directory already exists: $finalInstallPath" -Type Error
            Write-InstallMessage "Use -Force to overwrite or choose a different location" -Type Info
            exit 1
        }
    }
    
    # Get download URL
    $downloadUrl = Get-DownloadUrl $Source
    Write-InstallMessage "Download source: $downloadUrl" -Type Info
    
    # Prepare temporary paths
    $tempDownloadPath = Join-Path $script:Config.TempDir "AitherZero-$(Get-Date -Format 'yyyyMMdd-HHmmss').zip"
    $tempExtractPath = Join-Path $script:Config.TempDir "AitherZero-Extract-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    
    try {
        # Download
        if (-not (Invoke-Download $downloadUrl $tempDownloadPath)) {
            throw "Download failed"
        }
        
        # Extract
        if (-not (Expand-DownloadedArchive $tempDownloadPath $tempExtractPath)) {
            throw "Extraction failed"
        }
        
        # Move to final location
        if (-not (Move-ExtractedContent $tempExtractPath $finalInstallPath)) {
            throw "Content movement failed"
        }
        
        # Post-installation setup
        if (-not $SkipDependencies) {
            Invoke-PostInstallSetup $finalInstallPath
        }
        
        # Show summary
        Show-InstallationSummary $finalInstallPath
        
    } finally {
        # Cleanup temporary files
        @($tempDownloadPath, $tempExtractPath) | ForEach-Object {
            if (Test-Path $_) {
                Remove-Item $_ -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }
    
} catch {
    Write-InstallMessage "❌ Installation failed: $($_.Exception.Message)" -Type Error
    Show-ErrorGuidance
    exit 1
}

Write-Host ""
Write-InstallMessage "Happy automating with AitherZero! 🚀" -Type Primary
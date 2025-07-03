# AitherZero Web Bootstrap Script
# PowerShell 5.1+ Compatible - Downloads and installs AitherZero automatically

<#
.SYNOPSIS
    AitherZero Web Bootstrap - Complete web-enabled installation

.DESCRIPTION
    This bootstrap script can download AitherZero from the web, install PowerShell 7 if needed,
    and set up the complete environment. It's designed to be the ultimate "one-click" solution
    for getting AitherZero running on any Windows system with PowerShell 5.1+.

.PARAMETER InstallPath
    Installation directory for AitherZero (defaults to current directory)

.PARAMETER Source
    Download source: 'release' (latest release) or 'main' (main branch)

.PARAMETER Profile
    Installation profile: minimal, standard, developer, full

.PARAMETER InstallPowerShell7
    Automatically install PowerShell 7 if not present

.PARAMETER Force
    Force installation even if directories exist

.PARAMETER Silent
    Run in silent mode with minimal output

.EXAMPLE
    # One-liner web execution:
    iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/wizzense/AitherZero/main/web-bootstrap.ps1'))

.EXAMPLE
    # Local execution with custom options:
    .\web-bootstrap.ps1 -InstallPath "C:\Tools" -Profile developer -InstallPowerShell7

.NOTES
    AitherZero Web Bootstrap v1.0
    Combines download, PowerShell 7 installation, and setup into one script
    Compatible with PowerShell 5.1+ on Windows
#>

[CmdletBinding()]
param(
    [string]$InstallPath = $PWD.Path,
    [ValidateSet('release', 'main', 'develop')]
    [string]$Source = 'release',
    [ValidateSet('minimal', 'standard', 'developer', 'full')]
    [string]$Profile = 'standard',
    [switch]$InstallPowerShell7,
    [switch]$Force,
    [switch]$Silent
)

# Configuration
$script:Config = @{
    GitHubOwner = 'wizzense'
    GitHubRepo = 'AitherZero'
    InstallDir = 'AitherZero'
    TempDir = [System.IO.Path]::GetTempPath()
    UserAgent = 'AitherZero-WebBootstrap/1.0'
    PowerShell7DownloadUrl = 'https://github.com/PowerShell/PowerShell/releases/download/v7.4.6/PowerShell-7.4.6-win-x64.msi'
}

# Unified logging function (PowerShell 5.1 compatible)
function Write-BootstrapLog {
    param(
        [string]$Message,
        [ValidateSet('Info', 'Success', 'Warning', 'Error')]
        [string]$Level = 'Info'
    )
    
    if ($Silent) { return }
    
    $colors = @{ Info = 'Cyan'; Success = 'Green'; Warning = 'Yellow'; Error = 'Red' }
    $prefixes = @{ 
        Info = if ($PSVersionTable.PSVersion.Major -ge 6) { 'ℹ️' } else { '[INFO]' }
        Success = if ($PSVersionTable.PSVersion.Major -ge 6) { '✅' } else { '[OK]' }
        Warning = if ($PSVersionTable.PSVersion.Major -ge 6) { '⚠️' } else { '[WARN]' }
        Error = if ($PSVersionTable.PSVersion.Major -ge 6) { '❌' } else { '[ERROR]' }
    }
    
    Write-Host "$($prefixes[$Level]) $Message" -ForegroundColor $colors[$Level]
}

function Write-BootstrapHeader {
    param([string]$Title)
    
    if ($Silent) { return }
    
    Write-Host ""
    $rocket = if ($PSVersionTable.PSVersion.Major -ge 6) { '🚀' } else { '[BOOTSTRAP]' }
    Write-BootstrapLog "$rocket AitherZero Web Bootstrap - $Title" -Level Info
    Write-Host ("=" * 60) -ForegroundColor DarkGray
    Write-Host ""
}

function Test-Prerequisites {
    Write-BootstrapLog "Checking system prerequisites..." -Level Info
    
    # Check PowerShell version
    $psVersion = $PSVersionTable.PSVersion
    if ($psVersion.Major -lt 5) {
        Write-BootstrapLog "PowerShell 5.0+ required (current: $psVersion)" -Level Error
        return $false
    }
    
    Write-BootstrapLog "PowerShell $psVersion detected (compatible)" -Level Success
    
    # Check execution policy
    try {
        $execPolicy = Get-ExecutionPolicy -Scope CurrentUser -ErrorAction SilentlyContinue
        if ($execPolicy -eq 'Restricted') {
            Write-BootstrapLog "Execution policy is Restricted - may cause issues" -Level Warning
        } else {
            Write-BootstrapLog "Execution policy: $execPolicy" -Level Success
        }
    } catch {
        Write-BootstrapLog "Could not check execution policy" -Level Warning
    }
    
    # Test network connectivity
    try {
        $webClient = New-Object System.Net.WebClient
        $webClient.Headers.Add('User-Agent', $script:Config.UserAgent)
        $null = $webClient.DownloadString("https://api.github.com/repos/$($script:Config.GitHubOwner)/$($script:Config.GitHubRepo)")
        $webClient.Dispose()
        Write-BootstrapLog "Network connectivity verified" -Level Success
    } catch {
        Write-BootstrapLog "Network connectivity test failed: $($_.Exception.Message)" -Level Error
        return $false
    }
    
    return $true
}

function Test-PowerShell7Available {
    try {
        $pwshPath = Get-Command pwsh -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

function Install-PowerShell7 {
    Write-BootstrapLog "Installing PowerShell 7 for optimal compatibility..." -Level Info
    
    # Check if we're on Windows
    $isWindows = [System.Environment]::OSVersion.Platform -eq 'Win32NT' -or $PSVersionTable.PSVersion.Major -le 5
    
    if (-not $isWindows) {
        Write-BootstrapLog "Non-Windows platform detected. Please install PowerShell 7 manually" -Level Warning
        return $false
    }
    
    $installSuccess = $false
    
    # Method 1: Try winget
    try {
        $null = Get-Command winget -ErrorAction Stop
        Write-BootstrapLog "Attempting installation via winget..." -Level Info
        
        $result = & winget install --id Microsoft.Powershell --source winget --silent --accept-package-agreements --accept-source-agreements 2>$null
        
        if ($LASTEXITCODE -eq 0) {
            $installSuccess = $true
            Write-BootstrapLog "PowerShell 7 installed successfully via winget!" -Level Success
        }
    } catch {
        Write-BootstrapLog "winget not available, trying direct download..." -Level Info
    }
    
    # Method 2: Direct download if winget failed
    if (-not $installSuccess) {
        try {
            Write-BootstrapLog "Downloading PowerShell 7 installer..." -Level Info
            
            $tempPath = Join-Path $script:Config.TempDir "PowerShell-7-installer.msi"
            
            # Download using WebClient (PowerShell 5.1 compatible)
            $webClient = New-Object System.Net.WebClient
            $webClient.Headers.Add('User-Agent', $script:Config.UserAgent)
            $webClient.DownloadFile($script:Config.PowerShell7DownloadUrl, $tempPath)
            $webClient.Dispose()
            
            Write-BootstrapLog "Installing PowerShell 7..." -Level Info
            
            # Install silently
            $installArgs = @(
                "/i", $tempPath,
                "/quiet",
                "/norestart"
            )
            
            $process = Start-Process msiexec.exe -ArgumentList $installArgs -Wait -PassThru -NoNewWindow
            
            if ($process.ExitCode -eq 0) {
                $installSuccess = $true
                Write-BootstrapLog "PowerShell 7 installed successfully!" -Level Success
            } else {
                Write-BootstrapLog "Installation failed with exit code: $($process.ExitCode)" -Level Error
            }
            
            # Clean up installer
            Remove-Item $tempPath -Force -ErrorAction SilentlyContinue
            
        } catch {
            Write-BootstrapLog "Direct installation failed: $($_.Exception.Message)" -Level Error
        }
    }
    
    if ($installSuccess) {
        Write-BootstrapLog "PowerShell 7 installation complete! You may need to restart your terminal." -Level Success
    }
    
    return $installSuccess
}

function Get-AitherZeroDownloadUrl {
    param([string]$SourceType)
    
    switch ($SourceType) {
        'release' {
            try {
                # Get latest release info
                $apiUrl = "https://api.github.com/repos/$($script:Config.GitHubOwner)/$($script:Config.GitHubRepo)/releases/latest"
                $webClient = New-Object System.Net.WebClient
                $webClient.Headers.Add('User-Agent', $script:Config.UserAgent)
                $webClient.Headers.Add('Accept', 'application/vnd.github.v3+json')
                
                $responseJson = $webClient.DownloadString($apiUrl)
                $webClient.Dispose()
                
                # Parse JSON (PowerShell 5.1 compatible)
                if ($PSVersionTable.PSVersion.Major -ge 6) {
                    $release = $responseJson | ConvertFrom-Json
                } else {
                    Add-Type -AssemblyName System.Web.Extensions
                    $jsonSerializer = New-Object System.Web.Script.Serialization.JavaScriptSerializer
                    $release = $jsonSerializer.DeserializeObject($responseJson)
                }
                
                if ($release.zipball_url) {
                    Write-BootstrapLog "Found release: $($release.tag_name)" -Level Success
                    return $release.zipball_url
                }
            } catch {
                Write-BootstrapLog "Could not get release info, falling back to main branch" -Level Warning
            }
            
            # Fallback to main branch
            return "https://github.com/$($script:Config.GitHubOwner)/$($script:Config.GitHubRepo)/archive/refs/heads/main.zip"
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

function Invoke-AitherZeroDownload {
    param(
        [string]$DownloadUrl,
        [string]$OutputPath
    )
    
    Write-BootstrapLog "Downloading AitherZero from: $DownloadUrl" -Level Info
    
    try {
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
        
        $webClient.DownloadFile($DownloadUrl, $OutputPath)
        $webClient.Dispose()
        
        if (-not $Silent) {
            Write-Progress -Activity "Downloading AitherZero" -Completed
        }
        
        Write-BootstrapLog "Download completed successfully" -Level Success
        return $true
    } catch {
        Write-BootstrapLog "Download failed: $($_.Exception.Message)" -Level Error
        return $false
    }
}

function Expand-AitherZeroArchive {
    param(
        [string]$ArchivePath,
        [string]$ExtractPath
    )
    
    Write-BootstrapLog "Extracting AitherZero archive..." -Level Info
    
    try {
        # PowerShell 5.1 compatible extraction
        if ($PSVersionTable.PSVersion.Major -ge 5) {
            Expand-Archive -Path $ArchivePath -DestinationPath $ExtractPath -Force
        } else {
            Add-Type -AssemblyName System.IO.Compression.FileSystem
            [System.IO.Compression.ZipFile]::ExtractToDirectory($ArchivePath, $ExtractPath)
        }
        
        Write-BootstrapLog "Archive extracted successfully" -Level Success
        return $true
    } catch {
        Write-BootstrapLog "Failed to extract archive: $($_.Exception.Message)" -Level Error
        return $false
    }
}

function Install-AitherZero {
    param(
        [string]$FinalPath
    )
    
    Write-BootstrapLog "Installing AitherZero..." -Level Info
    
    # Check if installation directory exists
    if (Test-Path $FinalPath) {
        if ($Force) {
            Write-BootstrapLog "Removing existing installation..." -Level Warning
            Remove-Item $FinalPath -Recurse -Force
        } else {
            Write-BootstrapLog "Installation directory already exists: $FinalPath" -Level Error
            Write-BootstrapLog "Use -Force to overwrite or choose a different location" -Level Info
            return $false
        }
    }
    
    # Download
    $downloadUrl = Get-AitherZeroDownloadUrl $Source
    $tempZip = Join-Path $script:Config.TempDir "AitherZero-$(Get-Date -Format 'yyyyMMddHHmmss').zip"
    $tempExtract = Join-Path $script:Config.TempDir "AitherZero-Extract-$(Get-Date -Format 'yyyyMMddHHmmss')"
    
    try {
        # Download
        if (-not (Invoke-AitherZeroDownload $downloadUrl $tempZip)) {
            return $false
        }
        
        # Extract
        if (-not (Expand-AitherZeroArchive $tempZip $tempExtract)) {
            return $false
        }
        
        # Move content to final location
        Write-BootstrapLog "Moving content to final location..." -Level Info
        $extractedDir = Get-ChildItem -Path $tempExtract -Directory | Select-Object -First 1
        
        if ($extractedDir) {
            Move-Item $extractedDir.FullName $FinalPath -Force
            Write-BootstrapLog "AitherZero installed to: $FinalPath" -Level Success
        } else {
            Write-BootstrapLog "Unexpected archive structure" -Level Error
            return $false
        }
        
        return $true
        
    } finally {
        # Cleanup temporary files
        @($tempZip, $tempExtract) | ForEach-Object {
            if (Test-Path $_) {
                Remove-Item $_ -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

function Invoke-PostInstallSetup {
    param([string]$InstallDirectory)
    
    Write-BootstrapLog "Running post-installation setup..." -Level Info
    
    try {
        Push-Location $InstallDirectory
        
        # Look for quick setup script
        $quickSetupScript = if (Test-Path "quick-setup-simple.ps1") {
            "quick-setup-simple.ps1"
        } elseif (Test-Path "quick-setup.ps1") {
            "quick-setup.ps1"
        } else {
            $null
        }
        
        if ($quickSetupScript) {
            Write-BootstrapLog "Running $quickSetupScript..." -Level Info
            
            $setupArgs = @()
            if ($Silent) { $setupArgs += '-Auto' }
            
            & ".\$quickSetupScript" @setupArgs
            
            if ($LASTEXITCODE -eq 0 -or $null -eq $LASTEXITCODE) {
                Write-BootstrapLog "Setup completed successfully" -Level Success
            } else {
                Write-BootstrapLog "Setup completed with warnings" -Level Warning
            }
        } else {
            Write-BootstrapLog "No quick setup script found, skipping automated setup" -Level Warning
        }
        
        return $true
        
    } catch {
        Write-BootstrapLog "Post-installation setup failed: $($_.Exception.Message)" -Level Warning
        return $false
    } finally {
        Pop-Location
    }
}

function Show-InstallationSummary {
    param([string]$InstallDirectory)
    
    if ($Silent) { return }
    
    Write-Host ""
    $partyIcon = if ($PSVersionTable.PSVersion.Major -ge 6) { '🎉' } else { '[SUCCESS]' }
    Write-BootstrapLog "$partyIcon AitherZero installation completed!" -Level Success
    Write-Host ""
    Write-Host "INSTALLATION DETAILS:" -ForegroundColor Cyan
    Write-Host "  Location: $InstallDirectory"
    Write-Host "  Profile: $Profile" 
    Write-Host "  Source: $Source"
    Write-Host ""
    Write-Host "QUICK START:" -ForegroundColor Cyan
    Write-Host "  cd '$InstallDirectory'"
    Write-Host "  .\aither.ps1 help"
    Write-Host "  .\aither.ps1 init"
    Write-Host ""
    Write-Host "For documentation: https://github.com/$($script:Config.GitHubOwner)/$($script:Config.GitHubRepo)" -ForegroundColor DarkGray
}

# Main bootstrap execution
try {
    Write-BootstrapHeader "Complete Web Installation"
    
    # Prerequisites
    if (-not (Test-Prerequisites)) {
        exit 1
    }
    
    # PowerShell 7 installation if requested
    if ($InstallPowerShell7 -and -not (Test-PowerShell7Available)) {
        if (-not (Install-PowerShell7)) {
            Write-BootstrapLog "PowerShell 7 installation failed, continuing with current version" -Level Warning
        }
    }
    
    # Install AitherZero
    $finalInstallPath = Join-Path $InstallPath $script:Config.InstallDir
    
    if (-not (Install-AitherZero $finalInstallPath)) {
        throw "AitherZero installation failed"
    }
    
    # Post-installation setup
    Invoke-PostInstallSetup $finalInstallPath
    
    # Show success
    Show-InstallationSummary $finalInstallPath
    
    # Optional PowerShell 7 handoff if available
    if ((Test-PowerShell7Available) -and $InstallPowerShell7) {
        Write-Host ""
        Write-BootstrapLog "PowerShell 7 is now available! Restart your terminal and use 'pwsh' for optimal experience." -Level Info
    }
    
} catch {
    Write-BootstrapLog "Bootstrap failed: $($_.Exception.Message)" -Level Error
    Write-Host ""
    Write-Host "TROUBLESHOOTING:" -ForegroundColor Yellow
    Write-Host "  1. Check internet connectivity"
    Write-Host "  2. Run PowerShell as Administrator"
    Write-Host "  3. Set execution policy: Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser"
    Write-Host "  4. Try manual download: https://github.com/$($script:Config.GitHubOwner)/$($script:Config.GitHubRepo)/releases"
    Write-Host ""
    exit 1
}

Write-Host ""
$rocketIcon = if ($PSVersionTable.PSVersion.Major -ge 6) { '🚀' } else { '' }
Write-BootstrapLog "Happy automating with AitherZero! $rocketIcon" -Level Success
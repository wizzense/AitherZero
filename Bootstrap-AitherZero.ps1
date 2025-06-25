<#
.SYNOPSIS
    One-click bootstrap script for AitherZero Infrastructure Automation with automatic dependency management.

.DESCRIPTION
    This is the single entry point for downloading and setting up AitherZero.
    Compatible with both PowerShell 5.1 and 7.x, with robust cross-platform support.
    Automatically installs all required dependencies and provides a true "1-click" experience.

    Features:
    - Full compatibility with PowerShell 5.1 and 7.x
    - Cross-platform support (Windows, Linux, macOS)
    - Automatic dependency installation (Git, PowerShell 7, GitHub CLI)
    - Download latest release or clone repository
    - Configuration file support
    - Non-interactive mode support
    - Robust error handling and logging

.PARAMETER ConfigFile
    Path to custom configuration file for AitherZero.

.PARAMETER Quiet
    Run in quiet mode with minimal output.

.PARAMETER NonInteractive
    Run without any interactive prompts (suitable for automation).

.PARAMETER Verbosity
    Controls output verbosity: silent, normal, detailed.

.PARAMETER SkipPrerequisites
    Skip automatic installation of prerequisites.

.PARAMETER UseRepository
    Clone the full repository instead of downloading the release package.

.PARAMETER LocalPath
    Custom local path for installation (default: temp directory).

.PARAMETER Force
    Force re-download/re-install even if already exists.

.PARAMETER LaunchMode
    How to launch after setup: Interactive, Auto, Scripts, Setup.

.PARAMETER Scripts
    Specific scripts to run (comma-separated) when using Scripts mode.

.EXAMPLE
    # PowerShell 5.1 and 7.x compatible one-liner
    iex (iwr 'https://raw.githubusercontent.com/wizzense/AitherZero/main/Bootstrap-AitherZero.ps1').Content

.EXAMPLE
    # Traditional Windows PowerShell 5.1
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/wizzense/AitherZero/main/Bootstrap-AitherZero.ps1' -OutFile '.\Bootstrap-AitherZero.ps1'; .\Bootstrap-AitherZero.ps1"

.EXAMPLE
    # PowerShell 7.x (cross-platform)
    pwsh -NoProfile -ExecutionPolicy Bypass -Command "Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/wizzense/AitherZero/main/Bootstrap-AitherZero.ps1' -OutFile '.\Bootstrap-AitherZero.ps1'; .\Bootstrap-AitherZero.ps1"

.EXAMPLE
    # Download and run with custom config
    ./Bootstrap-AitherZero.ps1 -ConfigFile "my-config.json"

.EXAMPLE
    # Non-interactive setup for automation
    ./Bootstrap-AitherZero.ps1 -NonInteractive -LaunchMode Auto

.EXAMPLE
    # Use full repository for development
    ./Bootstrap-AitherZero.ps1 -UseRepository -LaunchMode Interactive
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$ConfigFile,
    [switch]$Quiet,
    [switch]$NonInteractive,
    [ValidateSet('silent', 'normal', 'detailed')]
    [string]$Verbosity = 'normal',
    [switch]$SkipPrerequisites,
    [switch]$UseRepository,
    [string]$LocalPath,
    [switch]$Force,
    [ValidateSet('Interactive', 'Auto', 'Scripts', 'Setup')]
    [string]$LaunchMode = 'Interactive',
    [string]$Scripts
)

#Requires -Version 5.1

# Bootstrap constants
$script:BootstrapVersion = '3.0.0'
$script:RepoUrl = 'https://github.com/wizzense/AitherZero.git'
$script:RawBaseUrl = 'https://raw.githubusercontent.com/wizzense/AitherZero'
$script:ReleasesApiUrl = 'https://api.github.com/repos/wizzense/AitherZero/releases/latest'

# PowerShell version compatibility detection
$script:IsPowerShell7Plus = $PSVersionTable.PSVersion.Major -ge 7
$script:IsPowerShell5 = $PSVersionTable.PSVersion.Major -eq 5

# Cross-platform detection (with fallback for PowerShell 5.1)
if ($script:IsPowerShell7Plus) {
    $script:PlatformWindows = [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Windows)
    $script:PlatformLinux = [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Linux)
    $script:PlatformMacOS = [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::OSX)
} else {
    $script:PlatformWindows = [System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT
    $script:PlatformLinux = $false
    $script:PlatformMacOS = $false

    if (-not $script:PlatformWindows) {
        if ($env:OS -eq 'linux' -or $IsLinux) {
            $script:PlatformLinux = $true
        } elseif ($env:OS -eq 'darwin' -or $IsMacOS) {
            $script:PlatformMacOS = $true
        }
    }
}

# Interactive detection
if ($script:IsPowerShell7Plus) {
    $script:IsInteractive = $null -ne $Host.UI.RawUI -and [Environment]::UserInteractive
} else {
    $script:IsInteractive = $Host.Name -ne 'ServerRemoteHost' -and [Environment]::UserInteractive
}

# Auto-detect non-interactive mode
if (-not $NonInteractive -and (-not $script:IsInteractive -or $env:CI -eq 'true' -or $env:GITHUB_ACTIONS -eq 'true')) {
    $NonInteractive = $true
    Write-Verbose 'Auto-detected non-interactive environment'
}

# Set verbosity
if ($Quiet) { $Verbosity = 'silent' }
$script:VerbosityLevel = @{ silent = 0; normal = 1; detailed = 2 }[$Verbosity]

# Cross-platform paths
function Get-PlatformTempPath {
    if ($script:PlatformWindows) {
        if ($env:TEMP) { return $env:TEMP }
        elseif ($env:TMP) { return $env:TMP }
        else { return 'C:/temp' }
    } elseif ($script:PlatformLinux -or $script:PlatformMacOS) {
        if ($env:TMPDIR) { return $env:TMPDIR }
        else { return '/tmp' }
    } else {
        return if ($script:PlatformWindows) { 'C:/temp' } else { '/tmp' }
    }
}

# Enhanced logging
function Write-BootstrapLog {
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Message,

        [ValidateSet('INFO', 'WARN', 'ERROR', 'SUCCESS')]
        [string]$Level = 'INFO',

        [switch]$NoTimestamp
    )

    $levelPriority = @{ INFO = 1; WARN = 1; ERROR = 0; SUCCESS = 1 }[$Level]

    if ($script:VerbosityLevel -ge $levelPriority) {
        $timestamp = if ($NoTimestamp) { '' } else { "[$(Get-Date -Format 'HH:mm:ss')] " }
        $colorMap = @{ INFO = 'White'; WARN = 'Yellow'; ERROR = 'Red'; SUCCESS = 'Green' }

        $displayMessage = if ([string]::IsNullOrEmpty($Message)) { '' } else { "$Level`: $Message" }

        try {
            Write-Host "$timestamp$displayMessage" -ForegroundColor $colorMap[$Level]
        } catch {
            Write-Output "$timestamp$displayMessage"
        }
    }

    # Log to file if possible
    if ($script:LogFile -and -not [string]::IsNullOrEmpty($Message)) {
        try {
            $logEntry = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$Level] $Message"
            Add-Content -Path $script:LogFile -Value $logEntry -ErrorAction SilentlyContinue
        } catch {
            # Silently fail on logging errors
        }
    }
}

# Initialize logging
$script:LogFile = Join-Path (Get-PlatformTempPath) "aitherzero-bootstrap-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
New-Item -ItemType File -Path $script:LogFile -Force -ErrorAction SilentlyContinue | Out-Null

Write-BootstrapLog "AitherZero Bootstrap v$script:BootstrapVersion" 'SUCCESS'
Write-BootstrapLog "PowerShell Version: $($PSVersionTable.PSVersion)" 'INFO'
Write-BootstrapLog "PowerShell Edition: $($PSVersionTable.PSEdition)" 'INFO'
if ($PSVersionTable.OS) {
    Write-BootstrapLog "Platform: $($PSVersionTable.OS)" 'INFO'
} else {
    Write-BootstrapLog 'Platform: Windows (PowerShell 5.1)' 'INFO'
}

# Enhanced web request function
function Invoke-CompatibleWebRequest {
    param(
        [Parameter(Mandatory)]
        [string]$Uri,

        [Parameter(Mandatory)]
        [string]$OutFile,

        [switch]$UseBasicParsing
    )

    if (-not $PSBoundParameters.ContainsKey('UseBasicParsing')) {
        $UseBasicParsing = $true
    }

    try {
        if ($script:IsPowerShell7Plus) {
            Invoke-WebRequest -Uri $Uri -OutFile $OutFile -UseBasicParsing:$UseBasicParsing
        } else {
            # PowerShell 5.1 with better error handling
            $webClient = New-Object System.Net.WebClient
            $webClient.DownloadFile($Uri, $OutFile)
            $webClient.Dispose()
        }
        return $true
    } catch {
        Write-BootstrapLog "Web request failed: $($_.Exception.Message)" 'ERROR'
        return $false
    }
}

# Git installation
function Install-GitForWindows {
    if (-not $script:PlatformWindows) { return $false }

    Write-BootstrapLog 'Installing Git for Windows...' 'INFO'

    try {
        $gitUrl = 'https://github.com/git-for-windows/git/releases/latest/download/Git-2.47.1-64-bit.exe'
        $gitInstaller = Join-Path (Get-PlatformTempPath) 'Git-Installer.exe'

        if (-not (Invoke-CompatibleWebRequest -Uri $gitUrl -OutFile $gitInstaller)) {
            throw 'Failed to download Git installer'
        }

        $process = Start-Process -FilePath $gitInstaller -ArgumentList '/SILENT', '/NORESTART' -Wait -NoNewWindow -PassThru
        Remove-Item $gitInstaller -ErrorAction SilentlyContinue

        if ($process.ExitCode -eq 0) {
            # Update PATH for current session
            $env:PATH = "$env:PATH;C:\Program Files\Git\bin;C:\Program Files\Git\cmd"
            Write-BootstrapLog 'Git installed successfully' 'SUCCESS'
            return $true
        } else {
            throw "Git installation failed with exit code: $($process.ExitCode)"
        }
    } catch {
        Write-BootstrapLog "Git installation failed: $($_.Exception.Message)" 'ERROR'
        return $false
    }
}

# PowerShell 7 installation
function Install-PowerShell7 {
    if (-not $script:PlatformWindows) { return $false }

    Write-BootstrapLog 'Installing PowerShell 7...' 'INFO'

    try {
        $pwshUrl = 'https://github.com/PowerShell/PowerShell/releases/latest/download/PowerShell-7.4.6-win-x64.msi'
        $pwshInstaller = Join-Path (Get-PlatformTempPath) 'PowerShell-7-Installer.msi'

        if (-not (Invoke-CompatibleWebRequest -Uri $pwshUrl -OutFile $pwshInstaller)) {
            throw 'Failed to download PowerShell 7 installer'
        }

        $process = Start-Process -FilePath 'msiexec.exe' -ArgumentList '/i', $pwshInstaller, '/quiet', '/norestart' -Wait -NoNewWindow -PassThru
        Remove-Item $pwshInstaller -ErrorAction SilentlyContinue

        if ($process.ExitCode -eq 0) {
            Write-BootstrapLog 'PowerShell 7 installed successfully' 'SUCCESS'
            return $true
        } else {
            throw "PowerShell 7 installation failed with exit code: $($process.ExitCode)"
        }
    } catch {
        Write-BootstrapLog "PowerShell 7 installation failed: $($_.Exception.Message)" 'ERROR'
        return $false
    }
}

# Prerequisite checking
function Test-Prerequisite {
    param(
        [string]$Name,
        [string[]]$Commands,
        [string]$InstallInstructions
    )

    Write-BootstrapLog "Checking prerequisite: $Name" 'INFO'

    foreach ($cmd in $Commands) {
        if (Get-Command $cmd -ErrorAction SilentlyContinue) {
            Write-BootstrapLog "OK $Name found: $cmd" 'SUCCESS'
            return $true
        }
    }

    Write-BootstrapLog "MISSING $Name not found" 'WARN'

    if ($SkipPrerequisites) {
        Write-BootstrapLog "Skipping $Name installation (SkipPrerequisites specified)" 'WARN'
        return $false
    }

    if ($NonInteractive) {
        Write-BootstrapLog "Cannot install $Name in non-interactive mode" 'ERROR'
        Write-BootstrapLog "Please install manually: $InstallInstructions" 'INFO'
        return $false
    }

    Write-BootstrapLog "Installation required for $Name" 'INFO'
    Write-BootstrapLog "Instructions: $InstallInstructions" 'INFO'

    return $false
}

# Main prerequisite validation
function Test-Prerequisites {
    Write-BootstrapLog '=== Validating Prerequisites ===' 'INFO'

    $allGood = $true

    # PowerShell 7 (recommended but not required)
    if (-not (Test-Prerequisite -Name 'PowerShell 7' -Commands @('pwsh') -InstallInstructions 'Install from https://github.com/PowerShell/PowerShell/releases')) {
        if ($script:PlatformWindows -and -not $SkipPrerequisites) {
            if (Install-PowerShell7) {
                Write-BootstrapLog 'PowerShell 7 auto-installed' 'SUCCESS'
            }
        }
    }

    # Git (required)
    if (-not (Test-Prerequisite -Name 'Git' -Commands @('git') -InstallInstructions 'Install Git from https://git-scm.com/downloads')) {
        if ($script:PlatformWindows -and -not $SkipPrerequisites) {
            if (Install-GitForWindows) {
                Write-BootstrapLog 'Git auto-installed' 'SUCCESS'
            } else {
                $allGood = $false
            }
        } else {
            $allGood = $false
        }
    }

    # GitHub CLI (optional)
    Test-Prerequisite -Name 'GitHub CLI' -Commands @('gh') -InstallInstructions 'Install from https://cli.github.com/' | Out-Null

    if (-not $allGood) {
        throw 'Required prerequisites are missing. Please install them and re-run this script.'
    }

    Write-BootstrapLog 'OK All required prerequisites are available' 'SUCCESS'
}

# Get latest release info
function Get-LatestReleaseInfo {
    Write-BootstrapLog 'Getting latest release information...' 'INFO'

    try {
        if ($script:IsPowerShell7Plus) {
            $response = Invoke-RestMethod -Uri $script:ReleasesApiUrl
        } else {
            $webClient = New-Object System.Net.WebClient
            $responseText = $webClient.DownloadString($script:ReleasesApiUrl)
            $webClient.Dispose()
            $response = $responseText | ConvertFrom-Json
        }

        Write-BootstrapLog "Latest release: $($response.tag_name)" 'SUCCESS'
        return $response
    } catch {
        Write-BootstrapLog "Failed to get release info: $($_.Exception.Message)" 'ERROR'
        return $null
    }
}

# Download and extract release
function Get-AitherZeroRelease {
    param([string]$InstallPath)

    Write-BootstrapLog '=== Downloading AitherZero Release ===' 'INFO'

    $releaseInfo = Get-LatestReleaseInfo
    if (-not $releaseInfo) {
        throw 'Could not get release information'
    }

    # Determine platform asset name
    $platformName = if ($script:PlatformWindows) { 'windows' }
    elseif ($script:PlatformLinux) { 'linux' }
    elseif ($script:PlatformMacOS) { 'macos' }
    else { 'windows' }

    $assetPattern = "*$platformName*"
    $asset = $releaseInfo.assets | Where-Object { $_.name -like $assetPattern } | Select-Object -First 1

    if (-not $asset) {
        throw "Could not find release asset for platform: $platformName"
    }

    Write-BootstrapLog "Downloading: $($asset.name)" 'INFO'

    $downloadPath = Join-Path (Get-PlatformTempPath) $asset.name

    if (-not (Invoke-CompatibleWebRequest -Uri $asset.browser_download_url -OutFile $downloadPath)) {
        throw 'Failed to download release asset'
    }

    Write-BootstrapLog "Extracting to: $InstallPath" 'INFO'

    if (-not (Test-Path $InstallPath)) {
        New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null
    }

    try {
        if ($asset.name -like '*.zip') {
            if ($script:IsPowerShell7Plus) {
                Expand-Archive -Path $downloadPath -DestinationPath $InstallPath -Force
            } else {
                Add-Type -AssemblyName System.IO.Compression.FileSystem
                [System.IO.Compression.ZipFile]::ExtractToDirectory($downloadPath, $InstallPath)
            }
        } else {
            # tar.gz file
            & tar -xzf $downloadPath -C $InstallPath
        }

        Remove-Item $downloadPath -ErrorAction SilentlyContinue
        Write-BootstrapLog 'Release extracted successfully' 'SUCCESS'

        # Find the extracted directory
        $extractedDir = Get-ChildItem -Path $InstallPath -Directory | Where-Object { $_.Name -like 'AitherZero*' } | Select-Object -First 1
        if ($extractedDir) {
            return $extractedDir.FullName
        } else {
            return $InstallPath
        }

    } catch {
        Write-BootstrapLog "Extraction failed: $($_.Exception.Message)" 'ERROR'
        throw
    }
}

# Clone repository
function Get-AitherZeroRepository {
    param([string]$InstallPath)

    Write-BootstrapLog '=== Cloning AitherZero Repository ===' 'INFO'

    $repoPath = Join-Path $InstallPath 'AitherZero'

    if (Test-Path $repoPath) {
        if ($Force) {
            Write-BootstrapLog 'Removing existing repository...' 'INFO'
            Remove-Item $repoPath -Recurse -Force
        } else {
            Write-BootstrapLog 'Repository already exists, updating...' 'INFO'
            & git -C $repoPath pull
            return $repoPath
        }
    }

    try {
        & git clone --depth 1 $script:RepoUrl $repoPath

        if ($LASTEXITCODE -ne 0) {
            throw "Git clone failed with exit code: $LASTEXITCODE"
        }

        Write-BootstrapLog 'Repository cloned successfully' 'SUCCESS'
        return $repoPath

    } catch {
        Write-BootstrapLog "Repository clone failed: $($_.Exception.Message)" 'ERROR'
        throw
    }
}

# Launch AitherZero
function Start-AitherZero {
    param(
        [string]$InstallPath,
        [string]$LaunchMode,
        [string]$Scripts,
        [string]$ConfigFile
    )

    Write-BootstrapLog '=== Launching AitherZero ===' 'INFO'

    # Find the main launcher
    $launcherScripts = @(
        'Start-AitherZero.ps1',
        'aither-core.ps1'
    )

    $launcher = $null
    foreach ($script in $launcherScripts) {
        $scriptPath = Join-Path $InstallPath $script
        if (Test-Path $scriptPath) {
            $launcher = $scriptPath
            break
        }
    }

    if (-not $launcher) {
        throw "Could not find AitherZero launcher script in: $InstallPath"
    }

    Write-BootstrapLog "Using launcher: $launcher" 'INFO'

    # Build launch arguments
    $launchArgs = @()

    switch ($LaunchMode) {
        'Auto' { $launchArgs += '-Auto' }
        'Scripts' {
            $launchArgs += '-Scripts'
            if ($Scripts) { $launchArgs += $Scripts }
        }
        'Setup' { $launchArgs += '-Setup' }
        'Interactive' {
            # Default mode, no special args needed
        }
    }

    if ($ConfigFile) {
        $launchArgs += '-ConfigFile', $ConfigFile
    }

    if ($Verbosity -ne 'normal') {
        $launchArgs += '-Verbosity', $Verbosity
    }

    if ($NonInteractive) {
        $launchArgs += '-NonInteractive'
    }

    Write-BootstrapLog "Launching with mode: $LaunchMode" 'SUCCESS'
    Write-BootstrapLog "Arguments: $($launchArgs -join ' ')" 'INFO'

    try {
        Push-Location $InstallPath

        # Handle execution policy on Windows
        if ($script:PlatformWindows) {
            & pwsh -ExecutionPolicy Bypass -File $launcher @launchArgs
        } else {
            & pwsh -File $launcher @launchArgs
        }

        Pop-Location

    } catch {
        Pop-Location
        Write-BootstrapLog "Launch failed: $($_.Exception.Message)" 'ERROR'
        throw
    }
}

# Main bootstrap workflow
function Start-Bootstrap {
    Write-BootstrapLog '=== AitherZero Bootstrap Started ===' 'SUCCESS'

    try {
        # Step 1: Validate prerequisites
        Test-Prerequisites

        # Step 2: Determine installation path
        if ($LocalPath) {
            $installPath = $LocalPath
        } else {
            $installPath = Join-Path (Get-PlatformTempPath) 'AitherZero-Bootstrap'
        }

        Write-BootstrapLog "Installation path: $installPath" 'INFO'

        # Step 3: Get AitherZero (release or repository)
        if ($UseRepository) {
            $aitherZeroPath = Get-AitherZeroRepository -InstallPath $installPath
        } else {
            $aitherZeroPath = Get-AitherZeroRelease -InstallPath $installPath
        }

        Write-BootstrapLog "AitherZero location: $aitherZeroPath" 'INFO'

        # Step 4: Launch AitherZero
        Start-AitherZero -InstallPath $aitherZeroPath -LaunchMode $LaunchMode -Scripts $Scripts -ConfigFile $ConfigFile

        # Step 5: Success message
        Write-BootstrapLog '=== Bootstrap Completed Successfully ===' 'SUCCESS'
        Write-BootstrapLog "AitherZero is running from: $aitherZeroPath" 'INFO'
        Write-BootstrapLog "Log file: $script:LogFile" 'INFO'

        if ($script:VerbosityLevel -ge 1) {
            Write-BootstrapLog '' 'INFO' -NoTimestamp
            Write-BootstrapLog '🎉 AitherZero Bootstrap Complete! 🎉' 'SUCCESS' -NoTimestamp
            Write-BootstrapLog 'Your infrastructure automation framework is ready to use.' 'SUCCESS' -NoTimestamp
        }

    } catch {
        Write-BootstrapLog "Bootstrap failed: $($_.Exception.Message)" 'ERROR'
        Write-BootstrapLog "Log file: $script:LogFile" 'ERROR'

        if ($script:VerbosityLevel -ge 1) {
            Write-BootstrapLog '' 'ERROR' -NoTimestamp
            Write-BootstrapLog '❌ Bootstrap Failed ❌' 'ERROR' -NoTimestamp
            Write-BootstrapLog "Check the log file for details: $script:LogFile" 'ERROR' -NoTimestamp
        }

        exit 1
    }
}

# Error handling
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

# Script entry point
if ($MyInvocation.InvocationName -ne '.') {
    Start-Bootstrap
}

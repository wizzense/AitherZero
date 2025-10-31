#Requires -Version 7.0

<#
.SYNOPSIS
    Install act for local GitHub Actions testing
.DESCRIPTION
    Installs the act CLI tool which allows running GitHub Actions locally
.PARAMETER Version
    Version of act to install (default: latest)
.PARAMETER Force
    Force reinstallation even if already installed
.PARAMETER CI
    Running in CI environment
.EXAMPLE
    ./0442_Install-Act.ps1
.EXAMPLE
    ./0442_Install-Act.ps1 -Version "0.2.54" -Force
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$Version = "latest",
    [switch]$Force,
    [switch]$CI
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Determine OS and architecture
$os = if ($IsWindows) { "Windows" } elseif ($IsLinux) { "Linux" } elseif ($IsMacOS) { "Darwin" } else { "Unknown" }
$arch = if ([System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture -eq 'X64') { "x86_64" } else { "arm64" }

Write-Host "🚀 Installing act for $os-$arch..." -ForegroundColor Cyan

# Check if already installed
$existingAct = Get-Command act -ErrorAction SilentlyContinue
if ($existingAct -and -not $Force) {
    $currentVersion = & act --version 2>$null
    Write-Host "✅ act is already installed: $currentVersion" -ForegroundColor Green
    Write-Host "   Use -Force to reinstall" -ForegroundColor Gray
    exit 0
}

# Get latest version if not specified
if ($Version -eq "latest") {
    try {
        $release = Invoke-RestMethod -Uri "https://api.github.com/repos/nektos/act/releases/latest"
        $Version = $release.tag_name -replace '^v', ''
        Write-Host "📦 Latest version: $Version" -ForegroundColor Yellow
    } catch {
        Write-Warning "Could not fetch latest version, using fallback"
        $Version = "0.2.54"
    }
}

# Determine download URL and install path
$baseUrl = "https://github.com/nektos/act/releases/download/v$Version"
$installPath = if ($IsWindows) {
    "$env:LOCALAPPDATA\Microsoft\WindowsApps"
} else {
    "/usr/local/bin"
}

# Ensure install path exists
if (-not (Test-Path $installPath)) {
    if ($PSCmdlet.ShouldProcess($installPath, "Create directory")) {
        New-Item -ItemType Directory -Path $installPath -Force | Out-Null
    }
}

# Download and install based on OS
if ($IsWindows) {
    $fileName = "act_Windows_$arch.zip"
    $downloadUrl = "$baseUrl/$fileName"
    $tempFile = Join-Path $env:TEMP "act.zip"

    Write-Host "📥 Downloading from $downloadUrl..." -ForegroundColor Yellow

    if ($PSCmdlet.ShouldProcess($downloadUrl, "Download act")) {
        Invoke-WebRequest -Uri $downloadUrl -OutFile $tempFile -UseBasicParsing

        # Extract
        Write-Host "📦 Extracting..." -ForegroundColor Yellow
        Expand-Archive -Path $tempFile -DestinationPath $installPath -Force
        Remove-Item $tempFile

        # Ensure in PATH
        if ($env:PATH -notlike "*$installPath*") {
            [Environment]::SetEnvironmentVariable("PATH", "$env:PATH;$installPath", [EnvironmentVariableTarget]::User)
            $env:PATH += ";$installPath"
        }
    }
} else {
    # Linux/macOS
    $fileName = "act_${os}_$arch.tar.gz"
    $downloadUrl = "$baseUrl/$fileName"
    $tempFile = "/tmp/act.tar.gz"

    Write-Host "📥 Downloading from $downloadUrl..." -ForegroundColor Yellow

    if ($PSCmdlet.ShouldProcess($downloadUrl, "Download act")) {
        Invoke-WebRequest -Uri $downloadUrl -OutFile $tempFile -UseBasicParsing

        # Extract
        Write-Host "📦 Extracting..." -ForegroundColor Yellow
        tar -xzf $tempFile -C /tmp

        # Move to install path (may need sudo)
        $actBinary = "/tmp/act"
        if (Test-Path $actBinary) {
            if ($installPath -eq "/usr/local/bin" -and -not $CI) {
                Write-Host "⚠️  Need sudo to install to $installPath" -ForegroundColor Yellow
                sudo mv $actBinary $installPath/act
                sudo chmod +x "$installPath/act"
            } else {
                # Try user local bin
                $userBin = "$HOME/.local/bin"
                if (-not (Test-Path $userBin)) {
                    New-Item -ItemType Directory -Path $userBin -Force | Out-Null
                }
                Move-Item $actBinary "$userBin/act" -Force
                chmod +x "$userBin/act"

                # Add to PATH if needed
                if ($env:PATH -notlike "*$userBin*") {
                    Write-Host "📝 Add this to your shell profile:" -ForegroundColor Yellow
                    Write-Host "   export PATH=`$PATH:$userBin" -ForegroundColor Cyan
                }
            }
        }

        Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
    }
}

# Verify installation
$act = Get-Command act -ErrorAction SilentlyContinue
if ($act) {
    $version = & act --version
    Write-Host "✅ act installed successfully!" -ForegroundColor Green
    Write-Host "   Version: $version" -ForegroundColor Gray
    Write-Host "   Path: $($act.Source)" -ForegroundColor Gray

    # Show usage
    Write-Host "`n📚 Usage:" -ForegroundColor Cyan
    Write-Host "   act                    # Run default event (push)" -ForegroundColor White
    Write-Host "   act pull_request       # Run pull_request event" -ForegroundColor White
    Write-Host "   act -l                 # List workflows" -ForegroundColor White
    Write-Host "   act -n                 # Dry run" -ForegroundColor White

    Write-Host "`n💡 Test our workflow:" -ForegroundColor Cyan
    Write-Host "   act pull_request -W .github/workflows/main.yml" -ForegroundColor Yellow

    # Check Docker
    $docker = Get-Command docker -ErrorAction SilentlyContinue
    if (-not $docker) {
        Write-Warning "Docker is not installed. act requires Docker to run containers"
        Write-Host "   Install Docker Desktop from: https://www.docker.com/products/docker-desktop" -ForegroundColor Yellow
    } else {
        $dockerRunning = docker info 2>$null
        if (-not $dockerRunning) {
            Write-Warning "Docker is installed but not running. Please start Docker Desktop"
        } else {
            Write-Host "✅ Docker is running - ready to test workflows!" -ForegroundColor Green
        }
    }
} else {
    Write-Error "Installation failed - act not found in PATH"
    exit 1
}
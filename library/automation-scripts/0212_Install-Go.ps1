#Requires -Version 7.0

<#
.SYNOPSIS
    Install Go programming language
.DESCRIPTION
    Installs the Go programming language and sets up GOPATH.
    Supports Windows, Linux, and macOS.
.PARAMETER Version
    Go version to install (default: latest stable)
.PARAMETER Force
    Force reinstallation even if already installed
.EXAMPLE
    ./0212_Install-Go.ps1
.EXAMPLE
    ./0212_Install-Go.ps1 -Version "1.21.5" -Force
.NOTES
    Stage: Development Tools
    Dependencies: None
    Tags: go, golang, development, programming
#>

[CmdletBinding()]
param(
    [string]$Version = 'latest',
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

# Check if already installed
$goInstalled = Get-Command go -ErrorAction SilentlyContinue

if ($goInstalled -and -not $Force) {
    Write-Host "[✓] Go is already installed: $(go version)" -ForegroundColor Green
    exit 0
}

Write-Host "[i] Installing Go..." -ForegroundColor Cyan

try {
    if ($IsWindows -or $PSVersionTable.Platform -eq 'Win32NT') {
        # Windows installation
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            Write-Host "  Using winget..." -ForegroundColor Gray
            winget install --id GoLang.Go --silent --accept-package-agreements --accept-source-agreements
        }
        elseif (Get-Command choco -ErrorAction SilentlyContinue) {
            Write-Host "  Using Chocolatey..." -ForegroundColor Gray
            choco install golang -y
        }
        else {
            Write-Host "  Downloading installer..." -ForegroundColor Gray
            $arch = if ([Environment]::Is64BitOperatingSystem) { 'amd64' } else { '386' }
            $downloadUrl = "https://go.dev/dl/go$Version.windows-$arch.msi"
            
            if ($Version -eq 'latest') {
                # Get latest version
                $releasePage = Invoke-WebRequest -Uri 'https://go.dev/dl/' -UseBasicParsing
                $latestVersion = ($releasePage.Content | Select-String -Pattern 'go(\d+\.\d+\.\d+)\.windows').Matches[0].Groups[1].Value
                $downloadUrl = "https://go.dev/dl/go$latestVersion.windows-$arch.msi"
            }
            
            $installerPath = Join-Path $env:TEMP 'go_installer.msi'
            Invoke-WebRequest -Uri $downloadUrl -OutFile $installerPath -UseBasicParsing
            Start-Process msiexec.exe -ArgumentList "/i `"$installerPath`" /quiet /norestart" -Wait
            Remove-Item $installerPath -Force
        }
        
        # Set GOPATH
        $goPath = Join-Path $env:USERPROFILE 'go'
        if (-not (Test-Path $goPath)) {
            New-Item -ItemType Directory -Path $goPath -Force | Out-Null
        }
        [Environment]::SetEnvironmentVariable('GOPATH', $goPath, 'User')
        $env:GOPATH = $goPath
        
        # Add to PATH
        $goBin = Join-Path $goPath 'bin'
        $currentPath = [Environment]::GetEnvironmentVariable('PATH', 'User')
        if ($currentPath -notlike "*$goBin*") {
            [Environment]::SetEnvironmentVariable('PATH', "$currentPath;$goBin", 'User')
            $env:PATH = "$env:PATH;$goBin"
        }
    }
    elseif ($IsLinux) {
        # Linux installation
        Write-Host "  Downloading Go binary..." -ForegroundColor Gray
        $arch = if ([Environment]::Is64BitOperatingSystem) { 'amd64' } else { '386' }
        
        if ($Version -eq 'latest') {
            $releasePage = Invoke-WebRequest -Uri 'https://go.dev/dl/' -UseBasicParsing
            $Version = ($releasePage.Content | Select-String -Pattern 'go(\d+\.\d+\.\d+)\.linux').Matches[0].Groups[1].Value
        }
        
        $downloadUrl = "https://go.dev/dl/go$Version.linux-$arch.tar.gz"
        $tempFile = '/tmp/go.tar.gz'
        
        Invoke-WebRequest -Uri $downloadUrl -OutFile $tempFile -UseBasicParsing
        sudo rm -rf /usr/local/go
        sudo tar -C /usr/local -xzf $tempFile
        rm $tempFile
        
        # Set GOPATH in profile
        $goPath = Join-Path $env:HOME 'go'
        if (-not (Test-Path $goPath)) {
            New-Item -ItemType Directory -Path $goPath -Force | Out-Null
        }
        
        $profileFile = Join-Path $env:HOME '.profile'
        $goConfig = @"

# Go configuration
export GOPATH=$goPath
export PATH=`$PATH:/usr/local/go/bin:`$GOPATH/bin
"@
        
        if (Test-Path $profileFile) {
            $content = Get-Content $profileFile -Raw
            if ($content -notlike '*GOPATH*') {
                Add-Content -Path $profileFile -Value $goConfig
            }
        }
        
        $env:GOPATH = $goPath
        $env:PATH = "/usr/local/go/bin:$goPath/bin:$env:PATH"
    }
    elseif ($IsMacOS) {
        # macOS installation
        if (Get-Command brew -ErrorAction SilentlyContinue) {
            Write-Host "  Using Homebrew..." -ForegroundColor Gray
            brew install go
            
            # Set GOPATH
            $goPath = Join-Path $env:HOME 'go'
            if (-not (Test-Path $goPath)) {
                New-Item -ItemType Directory -Path $goPath -Force | Out-Null
            }
            
            $profileFile = Join-Path $env:HOME '.zshrc'
            $goConfig = @"

# Go configuration
export GOPATH=$goPath
export PATH=`$PATH:`$GOPATH/bin
"@
            
            if (Test-Path $profileFile) {
                $content = Get-Content $profileFile -Raw
                if ($content -notlike '*GOPATH*') {
                    Add-Content -Path $profileFile -Value $goConfig
                }
            }
        }
        else {
            Write-Error "Homebrew is required for macOS installation"
            exit 1
        }
    }
    
    # Verify installation (refresh PATH first)
    if ($IsWindows) {
        $env:PATH = [Environment]::GetEnvironmentVariable('PATH', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('PATH', 'User')
    }
    
    $goInstalled = Get-Command go -ErrorAction SilentlyContinue
    
    if ($goInstalled) {
        $version = (go version)
        Write-Host "[✓] Go installed successfully: $version" -ForegroundColor Green
        Write-Host "  GOPATH: $env:GOPATH" -ForegroundColor Gray
        
        # Install common tools
        Write-Host "[i] Installing Go tools..." -ForegroundColor Cyan
        go install golang.org/x/tools/gopls@latest
        Write-Host "  ✓ gopls (Language Server)" -ForegroundColor DarkGreen
        
        exit 0
    }
    else {
        Write-Warning "Go installation completed but 'go' command not found. You may need to restart your shell."
        exit 0
    }
}
catch {
    Write-Error "Failed to install Go: $($_.Exception.Message)"
    exit 1
}

#!/usr/bin/env pwsh
#Requires -Version 5.1

<#
.SYNOPSIS
    AitherZero Bootstrap - Simplified orchestration-based installer
.DESCRIPTION
    Downloads minimal AitherZero and uses its own orchestration engine to complete setup
.PARAMETER Profile
    Installation profile: Core, Standard, Developer, Full
.PARAMETER Version
    Version to install (default: latest)
.PARAMETER Playbook
    Custom playbook to run after installation
.PARAMETER ConfigUrl
    URL to custom config.psd1 file
.EXAMPLE
    # One-liner installation
    iwr -useb https://raw.githubusercontent.com/wizzense/AitherZero/main/bootstrap-orchestrated.ps1 | iex
    
    # Install and run custom playbook
    & ([scriptblock]::Create((iwr -useb https://raw.githubusercontent.com/wizzense/AitherZero/main/bootstrap-orchestrated.ps1))) -Profile Developer -Playbook 'dev-environment'
#>

[CmdletBinding()]
param(
    [ValidateSet('Core', 'Standard', 'Developer', 'Full')]
    [string]$Profile = 'Standard',
    
    [string]$Version = 'latest',
    
    [string]$Playbook,
    
    [string]$ConfigUrl,
    
    [switch]$FromSource,  # Use git instead of release
    
    [switch]$NonInteractive = ($env:CI -eq 'true')
)

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Configuration
$script:RepoOwner = "wizzense"
$script:RepoName = "AitherZero"
$script:GitHubUrl = "https://github.com/$script:RepoOwner/$script:RepoName"

Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Blue
Write-Host " AitherZero Orchestrated Bootstrap" -ForegroundColor White
Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Blue
Write-Host ""

# Step 1: Download minimal AitherZero
Write-Host "📦 Downloading AitherZero ($Version)..." -ForegroundColor Cyan

$installPath = if ($IsWindows) { 
    "$env:LOCALAPPDATA\AitherZero" 
} else { 
    "$HOME/.local/share/aitherzero" 
}

if (Test-Path $installPath) {
    Write-Host "  Existing installation found at: $installPath" -ForegroundColor Yellow
    if (-not $NonInteractive) {
        $response = Read-Host "  Remove and reinstall? (y/N)"
        if ($response -ne 'y') {
            Write-Host "  Using existing installation" -ForegroundColor Green
            Set-Location $installPath
        } else {
            Remove-Item $installPath -Recurse -Force
        }
    }
}

if (-not (Test-Path $installPath)) {
    New-Item -ItemType Directory -Path $installPath -Force | Out-Null
    Set-Location $installPath
    
    if ($FromSource) {
        # Clone from git for developers
        Write-Host "  Cloning from source (developer mode)..." -ForegroundColor Yellow
        if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
            throw "Git is required for source installation"
        }
        git clone $script:GitHubUrl . --quiet
        
    } else {
        # Download release package
        Write-Host "  Fetching release information..." -ForegroundColor Gray
        
        try {
            $apiUrl = if ($Version -eq 'latest') {
                "https://api.github.com/repos/$script:RepoOwner/$script:RepoName/releases/latest"
            } else {
                "https://api.github.com/repos/$script:RepoOwner/$script:RepoName/releases/tags/v$Version"
            }
            
            $headers = @{}
            if ($env:GITHUB_TOKEN) {
                $headers['Authorization'] = "token $env:GITHUB_TOKEN"
            }
            
            $release = Invoke-RestMethod -Uri $apiUrl -Headers $headers
            
            # Download Core package (minimal for bootstrap)
            $coreAsset = $release.assets | Where-Object { $_.name -like "*-Core.zip" } | Select-Object -First 1
            
            if (-not $coreAsset) {
                Write-Host "  No Core release found, falling back to source installation" -ForegroundColor Yellow
                git clone $script:GitHubUrl . --quiet
            } else {
                $downloadUrl = $coreAsset.browser_download_url
                $tempZip = Join-Path ([System.IO.Path]::GetTempPath()) "AitherZero-Core.zip"
                
                Write-Host "  Downloading Core package..." -ForegroundColor Gray
                Invoke-WebRequest -Uri $downloadUrl -OutFile $tempZip -UseBasicParsing
                
                Write-Host "  Extracting..." -ForegroundColor Gray
                if ($PSVersionTable.PSVersion.Major -ge 5) {
                    Expand-Archive -Path $tempZip -DestinationPath . -Force
                } else {
                    # Fallback for older PowerShell
                    Add-Type -AssemblyName System.IO.Compression.FileSystem
                    [System.IO.Compression.ZipFile]::ExtractToDirectory($tempZip, $PWD)
                }
                
                Remove-Item $tempZip -Force
                Write-Host "  ✓ Core package installed" -ForegroundColor Green
            }
            
        } catch {
            Write-Host "  Failed to download release: $_" -ForegroundColor Red
            Write-Host "  Falling back to source installation" -ForegroundColor Yellow
            git clone $script:GitHubUrl . --quiet
        }
    }
}

# Step 2: Load AitherZero orchestration engine
Write-Host "`n🚀 Loading orchestration engine..." -ForegroundColor Cyan

try {
    Import-Module ./AitherZero.psd1 -Force -Global
    Write-Host "  ✓ Orchestration engine loaded" -ForegroundColor Green
} catch {
    Write-Host "  ✗ Failed to load orchestration engine: $_" -ForegroundColor Red
    exit 1
}

# Step 3: Apply custom config if provided
if ($ConfigUrl) {
    Write-Host "`n⚙️ Applying custom configuration..." -ForegroundColor Cyan
    try {
        $configScript = "./automation-scripts/0051_Apply-CustomConfig.ps1"
        if (Test-Path $configScript) {
            & $configScript -ConfigUrl $ConfigUrl -Merge
            Write-Host "  ✓ Custom configuration applied" -ForegroundColor Green
        } else {
            Write-Host "  ⚠ Config script not found, downloading config directly" -ForegroundColor Yellow
            Invoke-WebRequest -Uri $ConfigUrl -OutFile "./config.local.psd1"
        }
    } catch {
        Write-Host "  ⚠ Failed to apply custom config: $_" -ForegroundColor Yellow
    }
}

# Step 4: Run bootstrap playbook using orchestration
Write-Host "`n🎭 Running bootstrap playbook..." -ForegroundColor Cyan

$bootstrapVars = @{
    Profile = $Profile
    InstallDependencies = ($Profile -ne 'Core')
    RunTests = $false
    ConfigureGit = ($Profile -in @('Developer', 'Full'))
}

if ($NonInteractive) {
    $bootstrapVars['NonInteractive'] = $true
}

try {
    # Check if bootstrap playbook exists
    $bootstrapPlaybook = Get-OrchestrationPlaybook -Name 'bootstrap-system'
    
    if ($bootstrapPlaybook) {
        Write-Host "  Using orchestration for setup..." -ForegroundColor Gray
        
        $result = Invoke-OrchestrationSequence `
            -LoadPlaybook 'bootstrap-system' `
            -Variables $bootstrapVars `
            -ContinueOnError:$false
        
        if ($result.Failed -eq 0) {
            Write-Host "  ✓ Bootstrap playbook completed successfully" -ForegroundColor Green
        } else {
            Write-Host "  ⚠ Bootstrap completed with $($result.Failed) errors" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  Bootstrap playbook not found, running basic setup" -ForegroundColor Yellow
        
        # Fallback to basic setup
        if (Test-Path "./automation-scripts/0001_Check-Environment.ps1") {
            & "./automation-scripts/0001_Check-Environment.ps1"
        }
    }
} catch {
    Write-Host "  ⚠ Bootstrap playbook failed: $_" -ForegroundColor Yellow
    Write-Host "  Continuing with basic setup..." -ForegroundColor Yellow
}

# Step 5: Run additional playbook if specified
if ($Playbook) {
    Write-Host "`n🎯 Running custom playbook: $Playbook" -ForegroundColor Cyan
    
    try {
        $result = Invoke-OrchestrationSequence `
            -LoadPlaybook $Playbook `
            -ContinueOnError
        
        if ($result.Failed -eq 0) {
            Write-Host "  ✓ Playbook '$Playbook' completed successfully" -ForegroundColor Green
        } else {
            Write-Host "  ⚠ Playbook completed with errors" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "  ✗ Failed to run playbook: $_" -ForegroundColor Red
    }
}

# Step 6: Final setup
Write-Host "`n✨ Finalizing installation..." -ForegroundColor Cyan

# Add to PATH if not in CI
if (-not $env:CI) {
    $pathToAdd = $installPath
    $currentPath = [Environment]::GetEnvironmentVariable("PATH", "User")
    
    if ($currentPath -notlike "*$pathToAdd*") {
        [Environment]::SetEnvironmentVariable("PATH", "$currentPath;$pathToAdd", "User")
        Write-Host "  ✓ Added to PATH" -ForegroundColor Green
    }
}

# Create shortcuts/aliases
if ($IsWindows) {
    $shortcutPath = "$env:USERPROFILE\Desktop\AitherZero.lnk"
    if (-not (Test-Path $shortcutPath)) {
        $WshShell = New-Object -ComObject WScript.Shell
        $Shortcut = $WshShell.CreateShortcut($shortcutPath)
        $Shortcut.TargetPath = "pwsh.exe"
        $Shortcut.Arguments = "-NoExit -File `"$installPath\Start-AitherZero.ps1`""
        $Shortcut.WorkingDirectory = $installPath
        $Shortcut.Save()
        Write-Host "  ✓ Desktop shortcut created" -ForegroundColor Green
    }
}

# Display summary
Write-Host "`n════════════════════════════════════════════════════════════════" -ForegroundColor Blue
Write-Host " ✅ AitherZero Installation Complete!" -ForegroundColor Green
Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Blue
Write-Host ""
Write-Host "Profile:  $Profile" -ForegroundColor Cyan
Write-Host "Version:  $(if ($Version -eq 'latest') { $release.tag_name } else { $Version })" -ForegroundColor Cyan
Write-Host "Location: $installPath" -ForegroundColor Cyan
Write-Host ""
Write-Host "To start AitherZero:" -ForegroundColor White
Write-Host "  cd '$installPath'" -ForegroundColor Yellow
Write-Host "  ./Start-AitherZero.ps1" -ForegroundColor Yellow
Write-Host ""
Write-Host "Or use the quick command:" -ForegroundColor White
Write-Host "  az" -ForegroundColor Yellow
Write-Host ""

# Auto-start unless disabled
if (-not $env:CI -and -not $NonInteractive) {
    $start = Read-Host "Start AitherZero now? (Y/n)"
    if ($start -ne 'n') {
        & ./Start-AitherZero.ps1
    }
}
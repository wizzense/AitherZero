#Requires -Version 7.0

<#
.SYNOPSIS
    Simple package builder for AitherZero
.DESCRIPTION
    Creates distribution packages for Windows, Linux, and macOS
.PARAMETER Platform
    Target platform: windows, linux, macos, or all
.PARAMETER Version
    Package version (defaults to VERSION file)
.PARAMETER OutputPath
    Output directory (defaults to ./build/output)
#>

param(
    [ValidateSet('windows', 'linux', 'macos', 'all')]
    [string]$Platform = 'all',
    
    [string]$Version,
    
    [string]$OutputPath = (Join-Path (Split-Path -Parent $PSScriptRoot) "build" "output")
)

# Get version if not specified
if (-not $Version) {
    $versionFile = Join-Path (Split-Path -Parent $PSScriptRoot) "VERSION"
    if (Test-Path $versionFile) {
        $Version = Get-Content $versionFile -Raw -ErrorAction SilentlyContinue | ForEach-Object { $_.Trim() }
    } else {
        $Version = "0.0.1"
    }
}

Write-Host "Building AitherZero v$Version packages..." -ForegroundColor Cyan

# Create output directory
$null = New-Item -ItemType Directory -Path $OutputPath -Force

# Define what to include
$includeItems = @(
    "Start-AitherZero.ps1",
    "aither-core",
    "configs",
    "opentofu",
    "README.md",
    "LICENSE",
    "VERSION"
)

# Build for each platform
$platforms = if ($Platform -eq 'all') { @('windows', 'linux', 'macos') } else { @($Platform) }

foreach ($plat in $platforms) {
    Write-Host "Building $plat package..." -ForegroundColor Yellow
    
    # Create temp directory
    $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "aitherzero-build-$([guid]::NewGuid())"
    $packageDir = Join-Path $tempDir "AitherZero-v$Version"
    $null = New-Item -ItemType Directory -Path $packageDir -Force
    
    # Copy files
    foreach ($item in $includeItems) {
        $source = Join-Path (Split-Path -Parent $PSScriptRoot) $item
        if (Test-Path $source) {
            $dest = Join-Path $packageDir $item
            Write-Host "  Copying $item..."
            Copy-Item -Path $source -Destination $dest -Recurse -Force
        }
    }
    
    # Create package
    $packageName = "AitherZero-v$Version-$plat"
    
    if ($plat -eq 'windows') {
        # Create ZIP for Windows
        $packagePath = Join-Path $OutputPath "$packageName.zip"
        Write-Host "  Creating $packageName.zip..."
        Compress-Archive -Path $packageDir -DestinationPath $packagePath -Force
    } else {
        # Create tar.gz for Linux/macOS
        $packagePath = Join-Path $OutputPath "$packageName.tar.gz"
        Write-Host "  Creating $packageName.tar.gz..."
        
        Push-Location $tempDir
        tar -czf $packagePath "AitherZero-v$Version"
        Pop-Location
    }
    
    # Cleanup
    Remove-Item -Path $tempDir -Recurse -Force
    
    Write-Host "✅ Created: $(Split-Path -Leaf $packagePath)" -ForegroundColor Green
}

Write-Host "`n📦 Build complete! Packages in: $OutputPath" -ForegroundColor Cyan
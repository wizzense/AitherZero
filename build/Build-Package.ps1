#Requires -Version 5.1

<#
.SYNOPSIS
    Ultra-simple package builder for AitherZero - one package per platform
.DESCRIPTION
    Creates distribution packages for Windows, Linux, and macOS with everything included
.PARAMETER Platform
    Target platform: windows, linux, macos, or all (default: all)
.PARAMETER Version
    Package version (defaults to VERSION file)
.PARAMETER OutputPath
    Output directory (defaults to ./build/output)
.EXAMPLE
    ./Build-Package.ps1
    # Builds packages for all platforms
.EXAMPLE
    ./Build-Package.ps1 -Platform windows -Version "1.2.3"
    # Builds Windows package with specific version
#>

param(
    [ValidateSet('windows', 'linux', 'macos', 'all')]
    [string]$Platform = 'all',

    [string]$Version,

    [string]$OutputPath = (Join-Path (Split-Path -Parent $PSScriptRoot) "build" "output")
)

# Error handling
$ErrorActionPreference = 'Stop'

# Get project root
$projectRoot = Split-Path -Parent $PSScriptRoot

# Get version if not specified
if (-not $Version) {
    $versionFile = Join-Path $projectRoot "VERSION"
    if (Test-Path $versionFile) {
        $Version = (Get-Content $versionFile -Raw).Trim()
    } else {
        Write-Warning "VERSION file not found, using default version"
        $Version = "0.0.1"
    }
}

Write-Host "`n🚀 AitherZero Package Builder" -ForegroundColor Magenta
Write-Host "================================" -ForegroundColor Magenta
Write-Host "Version: $Version" -ForegroundColor Cyan
Write-Host "Output:  $OutputPath" -ForegroundColor Cyan
Write-Host ""

# Create output directory
$null = New-Item -ItemType Directory -Path $OutputPath -Force -ErrorAction SilentlyContinue

# Define core items to include (same for all platforms)
$includeItems = @(
    "Start-AitherZero.ps1",
    "aither-core",
    "configs",
    "opentofu",
    "scripts",
    "README.md",
    "LICENSE",
    "VERSION",
    "CHANGELOG.md",
    "QUICKSTART.md"
)

# Platform-specific files
$platformFiles = @{
    'windows' = @('bootstrap.ps1', 'Start-AitherZero.cmd')
    'linux'   = @('bootstrap.sh')
    'macos'   = @('bootstrap.sh')
}

# Build for each platform
$platforms = if ($Platform -eq 'all') { @('windows', 'linux', 'macos') } else { @($Platform) }

$totalStartTime = Get-Date
$createdPackages = @()

foreach ($plat in $platforms) {
    Write-Host "📦 Building $plat package..." -ForegroundColor Yellow
    $platStartTime = Get-Date

    try {
        # Create temp directory
        $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "aitherzero-build-$([guid]::NewGuid())"
        $packageDir = Join-Path $tempDir "AitherZero"
        $null = New-Item -ItemType Directory -Path $packageDir -Force

        # Copy core files
        $filesCopied = 0
        foreach ($item in $includeItems) {
            $source = Join-Path $projectRoot $item
            if (Test-Path $source) {
                $dest = Join-Path $packageDir $item
                Write-Host "  ├─ $item" -ForegroundColor Gray
                Copy-Item -Path $source -Destination $dest -Recurse -Force -ErrorAction Continue
                $filesCopied++
            } else {
                # Only warn for critical files
                if ($item -in @("Start-AitherZero.ps1", "aither-core", "VERSION")) {
                    Write-Warning "  ├─ Missing critical file: $item"
                }
            }
        }

        # Copy platform-specific files
        if ($platformFiles.ContainsKey($plat)) {
            foreach ($file in $platformFiles[$plat]) {
                $source = Join-Path $projectRoot $file
                if (Test-Path $source) {
                    Write-Host "  ├─ $file (platform-specific)" -ForegroundColor Gray
                    Copy-Item -Path $source -Destination (Join-Path $packageDir $file) -Force
                    $filesCopied++
                }
            }
        }

        Write-Host "  └─ Total files/directories copied: $filesCopied" -ForegroundColor DarkGray

        # Validate critical files exist in package
        Write-Host "  🔍 Validating package contents..." -ForegroundColor Yellow
        $criticalFiles = @(
            "Start-AitherZero.ps1",
            "aither-core/aither-core.ps1",
            "aither-core/shared/Test-PowerShellVersion.ps1",
            "aither-core/shared/Find-ProjectRoot.ps1",
            "aither-core/shared/Initialize-Logging.ps1",
            "aither-core/AitherCore.psm1",
            "aither-core/domains/infrastructure/Infrastructure.ps1",
            "aither-core/domains/configuration/Configuration.ps1",
            "configs/default-config.json"
        )

        $validationPassed = $true
        foreach ($criticalFile in $criticalFiles) {
            $filePath = Join-Path $packageDir $criticalFile
            if (-not (Test-Path $filePath)) {
                Write-Warning "  ⚠️  Missing critical file: $criticalFile"
                $validationPassed = $false
            }
        }

        if (-not $validationPassed) {
            throw "Package validation failed - critical files missing"
        }

        Write-Host "  ✅ Package validation passed" -ForegroundColor Green

        # Create package
        $packageName = "AitherZero-v$Version-$plat"

        if ($plat -eq 'windows') {
            # Create ZIP for Windows
            $packagePath = Join-Path $OutputPath "$packageName.zip"
            Write-Host "  📝 Creating ZIP archive..." -ForegroundColor Cyan

            # Remove old package if exists
            if (Test-Path $packagePath) {
                Remove-Item $packagePath -Force
            }

            Compress-Archive -Path "$packageDir\*" -DestinationPath $packagePath -CompressionLevel Optimal
        } else {
            # Create tar.gz for Linux/macOS
            $packagePath = Join-Path $OutputPath "$packageName.tar.gz"
            Write-Host "  📝 Creating TAR.GZ archive..." -ForegroundColor Cyan

            # Remove old package if exists
            if (Test-Path $packagePath) {
                Remove-Item $packagePath -Force
            }

            Push-Location $tempDir
            # Use cross-platform tar command
            if ($IsWindows) {
                # Windows tar might need different syntax
                tar -czf $packagePath "AitherZero"
            } else {
                tar -czf $packagePath "AitherZero"
            }
            Pop-Location
        }

        # Get package size
        $packageInfo = Get-Item $packagePath
        $sizeMB = [Math]::Round($packageInfo.Length / 1MB, 2)

        # Calculate build time
        $platEndTime = Get-Date
        $platDuration = [Math]::Round(($platEndTime - $platStartTime).TotalSeconds, 1)

        Write-Host "  ✅ Success! Package: $(Split-Path -Leaf $packagePath) (${sizeMB}MB) [${platDuration}s]" -ForegroundColor Green

        $createdPackages += [PSCustomObject]@{
            Platform = $plat
            FileName = Split-Path -Leaf $packagePath
            Path = $packagePath
            Size = "${sizeMB}MB"
            Duration = "${platDuration}s"
        }

    } catch {
        Write-Error "  ❌ Failed to build $plat package: $_"
    } finally {
        # Cleanup temp directory
        if (Test-Path $tempDir) {
            Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Write-Host ""
}

# Summary
$totalEndTime = Get-Date
$totalDuration = [Math]::Round(($totalEndTime - $totalStartTime).TotalSeconds, 1)

Write-Host "📊 Build Summary" -ForegroundColor Magenta
Write-Host "================" -ForegroundColor Magenta
Write-Host "Total build time: ${totalDuration}s" -ForegroundColor Cyan
Write-Host ""

if ($createdPackages.Count -gt 0) {
    Write-Host "✅ Successfully created $($createdPackages.Count) package(s):" -ForegroundColor Green
    $createdPackages | ForEach-Object {
        Write-Host "   • $($_.Platform): $($_.FileName) ($($_.Size))" -ForegroundColor White
    }
    Write-Host ""
    Write-Host "📁 Output directory: $OutputPath" -ForegroundColor Cyan
} else {
    Write-Host "❌ No packages were created" -ForegroundColor Red
}

# Exit with appropriate code
exit ($createdPackages.Count -eq $platforms.Count ? 0 : 1)

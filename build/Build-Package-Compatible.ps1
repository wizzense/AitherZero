# AitherZero Build Script - PowerShell 5.1+ Compatible
# This script creates release packages without requiring PowerShell 7

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('windows', 'linux', 'macos', 'all')]
    [string]$Platform = 'windows',
    
    [Parameter(Mandatory = $true)]
    [string]$Version,
    
    [ValidateSet('minimal', 'standard', 'full')]
    [string]$PackageProfile = 'standard',
    
    [ValidateSet('zip', 'tar.gz')]
    [string]$ArtifactExtension = 'zip',
    
    [string]$OutputDirectory = './artifacts'
)

# Ensure we're in the project root
if ($PSScriptRoot) {
    $scriptPath = $PSScriptRoot
} else {
    $scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
}
$projectRoot = Split-Path -Parent $scriptPath
Set-Location $projectRoot

Write-Host ""
Write-Host "AitherZero Build System (PS 5.1+ Compatible)" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Platform: $Platform" -ForegroundColor Yellow
Write-Host "Version: $Version" -ForegroundColor Yellow
Write-Host "Profile: $PackageProfile" -ForegroundColor Yellow
Write-Host "Format: $ArtifactExtension" -ForegroundColor Yellow
Write-Host ""

# Create output directory
if (-not (Test-Path $OutputDirectory)) {
    New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
}

# Define what to include based on profile
$includePatterns = @{
    minimal = @(
        "Start-AitherZero.ps1",
        "Start-AitherZero-Compatible.ps1",
        "quick-setup-simple.ps1",
        "VERSION",
        "LICENSE",
        "README.md",
        "QUICKSTART.md",
        "aither-core/aither-core.ps1",
        "aither-core/modules/Logging/*",
        "aither-core/modules/ConfigurationRepository/*",
        "aither-core/shared/*",
        "configs/default-config.json"
    )
    standard = @(
        "Start-AitherZero.ps1",
        "Start-AitherZero-Compatible.ps1",
        "quick-setup-simple.ps1",
        "get-aither-fixed.ps1",
        "install-oneliner.ps1",
        "VERSION",
        "LICENSE",
        "README.md",
        "QUICKSTART.md",
        "CLAUDE.md",
        "aither-core/**",
        "configs/**",
        "docs/**",
        "scripts/Create-Release-Fixed.ps1",
        "opentofu/README.md"
    )
    full = @(
        "*"
    )
}

# Exclude patterns (always exclude these)
$excludePatterns = @(
    ".git",
    ".github",
    ".vscode",
    "artifacts",
    "temp",
    "logs",
    "backups",
    "*.log",
    "*.tmp",
    ".gitignore",
    ".gitattributes"
)

# Function to create package
function New-Package {
    param(
        [string]$PackageName,
        [string]$TargetPlatform
    )
    
    Write-Host "Building package: $PackageName" -ForegroundColor Green
    
    # Create temp directory for package contents
    $tempDir = Join-Path $env:TEMP "AitherZero-Build-$(Get-Date -Format 'yyyyMMddHHmmss')"
    $packageDir = Join-Path $tempDir "AitherZero"
    New-Item -ItemType Directory -Path $packageDir -Force | Out-Null
    
    # Copy files based on profile
    $patterns = $includePatterns[$PackageProfile]
    
    foreach ($pattern in $patterns) {
        if ($pattern -match '/\*\*$') {
            # Directory with all subdirectories (e.g., "aither-core/**")
            $basePath = $pattern -replace '/\*\*$', ''
            if (Test-Path $basePath) {
                Write-Host "  Copying directory tree: $basePath" -ForegroundColor Gray
                # Preserve directory structure
                $destPath = Join-Path $packageDir $basePath
                $destParent = Split-Path -Parent $destPath
                if (-not (Test-Path $destParent)) {
                    New-Item -ItemType Directory -Path $destParent -Force | Out-Null
                }
                Copy-Item -Path $basePath -Destination $destPath -Recurse -Force
            }
        }
        elseif ($pattern -like "*\*" -or $pattern -like "*/*") {
            # Pattern with wildcards - could be files or directories
            $parentPath = Split-Path -Parent $pattern
            $leafPattern = Split-Path -Leaf $pattern
            
            if (Test-Path $parentPath) {
                # Create destination directory structure
                $destDir = Join-Path $packageDir $parentPath
                if (-not (Test-Path $destDir)) {
                    New-Item -ItemType Directory -Path $destDir -Force | Out-Null
                }
                
                # Copy matching items
                Get-ChildItem -Path $parentPath -Filter $leafPattern | ForEach-Object {
                    Write-Host "  Copying: $($_.FullName)" -ForegroundColor Gray
                    if ($_.PSIsContainer) {
                        Copy-Item -Path $_.FullName -Destination $destDir -Recurse -Force
                    } else {
                        Copy-Item -Path $_.FullName -Destination $destDir -Force
                    }
                }
            }
        }
        else {
            # Single file (with or without path)
            if (Test-Path $pattern) {
                # Check if it's a file or directory
                $item = Get-Item $pattern
                
                if ($item.PSIsContainer) {
                    # It's a directory
                    Write-Host "  Copying directory: $pattern" -ForegroundColor Gray
                    $destPath = Join-Path $packageDir $pattern
                    $destParent = Split-Path -Parent $destPath
                    if (-not (Test-Path $destParent)) {
                        New-Item -ItemType Directory -Path $destParent -Force | Out-Null
                    }
                    Copy-Item -Path $pattern -Destination $destPath -Recurse -Force
                } else {
                    # It's a file
                    Write-Host "  Copying file: $pattern" -ForegroundColor Gray
                    
                    if ($pattern -like "*/*" -or $pattern -like "*\*") {
                        # File in subdirectory - preserve structure
                        $relativePath = $pattern
                        $fileName = Split-Path -Leaf $relativePath
                        $relativeDir = Split-Path -Parent $relativePath
                        
                        # Create the directory structure in the package
                        $destDir = Join-Path $packageDir $relativeDir
                        if (-not (Test-Path $destDir)) {
                            New-Item -ItemType Directory -Path $destDir -Force | Out-Null
                        }
                        
                        Copy-Item -Path $pattern -Destination $destDir -Force
                    } else {
                        # File in root directory
                        Copy-Item -Path $pattern -Destination $packageDir -Force
                    }
                }
            }
        }
    }
    
    # Create required empty directories
    $requiredDirs = @("logs", "temp", "backups")
    foreach ($dir in $requiredDirs) {
        $dirPath = Join-Path $packageDir $dir
        if (-not (Test-Path $dirPath)) {
            New-Item -ItemType Directory -Path $dirPath -Force | Out-Null
            # Add .gitkeep file
            Set-Content -Path (Join-Path $dirPath ".gitkeep") -Value "" -Force
        }
    }
    
    # Add platform-specific launcher if needed
    if ($TargetPlatform -eq 'linux' -or $TargetPlatform -eq 'macos') {
        $launcherContent = @"
#!/bin/bash
# AitherZero Launcher for Unix-like systems

# Check if pwsh is available, otherwise use powershell
if command -v pwsh &> /dev/null; then
    pwsh ./Start-AitherZero.ps1 "\$@"
else
    echo "PowerShell Core (pwsh) not found. Please install it first."
    echo "Visit: https://aka.ms/powershell"
    exit 1
fi
"@
        $launcherPath = Join-Path $packageDir "aither.sh"
        Set-Content -Path $launcherPath -Value $launcherContent -Force
        Write-Host "  Added Unix launcher: aither.sh" -ForegroundColor Gray
    }
    
    # Ensure output directory exists
    if (-not (Test-Path $OutputDirectory)) {
        New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
    }
    
    # Create the archive
    $outputPath = Join-Path (Resolve-Path $OutputDirectory).Path $PackageName
    
    Write-Host "  Creating archive: $PackageName" -ForegroundColor Yellow
    
    if ($ArtifactExtension -eq 'zip') {
        # Use .NET compression for PS 5.1 compatibility
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::CreateFromDirectory($packageDir, $outputPath, 'Optimal', $false)
    }
    else {
        # For tar.gz, we need external tool or PS7
        Write-Host "  WARNING: tar.gz format requires external tools on PS 5.1" -ForegroundColor Yellow
        # Fallback to zip
        $outputPath = $outputPath -replace '\.tar\.gz$', '.zip'
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::CreateFromDirectory($packageDir, $outputPath, 'Optimal', $false)
    }
    
    # Cleanup temp directory
    Remove-Item -Path $tempDir -Recurse -Force
    
    # Calculate package size
    $packageSize = (Get-Item $outputPath).Length / 1MB
    Write-Host "  Package created: $([System.IO.Path]::GetFileName($outputPath)) ($([Math]::Round($packageSize, 2)) MB)" -ForegroundColor Green
    
    return $outputPath
}

# Build packages based on platform selection
$packages = @()

if ($Platform -eq 'all') {
    $platforms = @('windows', 'linux', 'macos')
} else {
    $platforms = @($Platform)
}

foreach ($plat in $platforms) {
    $extension = if ($plat -eq 'windows') { 'zip' } else { $ArtifactExtension }
    $packageName = "AitherZero-v$Version-$plat-$PackageProfile.$extension"
    
    try {
        $packagePath = New-Package -PackageName $packageName -TargetPlatform $plat
        $packages += $packagePath
    }
    catch {
        Write-Host "ERROR: Failed to build package for $plat - $_" -ForegroundColor Red
    }
}

# Summary
Write-Host ""
Write-Host "Build Summary" -ForegroundColor Cyan
Write-Host "=============" -ForegroundColor Cyan
Write-Host "Total packages created: $($packages.Count)" -ForegroundColor Green

foreach ($package in $packages) {
    if (Test-Path $package) {
        $size = (Get-Item $package).Length / 1MB
        Write-Host "  - $([System.IO.Path]::GetFileName($package)) ($([Math]::Round($size, 2)) MB)" -ForegroundColor White
    }
}

Write-Host ""
Write-Host "Build completed successfully!" -ForegroundColor Green
Write-Host "Artifacts location: $([System.IO.Path]::GetFullPath($OutputDirectory))" -ForegroundColor Yellow
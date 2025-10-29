#Requires -Version 7.0
<#
.SYNOPSIS
    Build and package AitherCore for distribution across platforms
.DESCRIPTION
    Creates platform-specific distribution packages of AitherCore containing
    the 11 essential modules for lightweight AitherZero deployments.
    
    Packages include:
    - All 11 core modules with proper directory structure
    - Module manifest and loader
    - Comprehensive documentation
    - Platform-specific installation scripts
    - README and licensing information
    
    Output formats:
    - .zip for Windows
    - .tar.gz for Linux/macOS
    - Cross-platform PowerShell module structure
    
.PARAMETER OutputPath
    Directory where packages will be created. Defaults to ./dist/aithercore
.PARAMETER Version
    Version number for the package (e.g., "1.0.0"). Defaults to version from manifest.
.PARAMETER Platforms
    Target platforms to build for. Options: Windows, Linux, macOS, All
.PARAMETER IncludeExamples
    Include example scripts and usage documentation in the package
.PARAMETER SkipValidation
    Skip validation tests before packaging
    
.EXAMPLE
    ./tools/Build-AitherCorePackage.ps1
    
    Build packages for all platforms with default settings
    
.EXAMPLE
    ./tools/Build-AitherCorePackage.ps1 -Platforms Windows,Linux -Version "1.0.1"
    
    Build packages for Windows and Linux with specific version
    
.EXAMPLE
    ./tools/Build-AitherCorePackage.ps1 -OutputPath "./releases" -IncludeExamples
    
    Build with examples to custom output directory
    
.NOTES
    Copyright © 2025 Aitherium Corporation
    This script handles the complete build and packaging process for AitherCore distributions.
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$OutputPath = "./dist/aithercore",
    
    [Parameter()]
    [string]$Version,
    
    [Parameter()]
    [ValidateSet('Windows', 'Linux', 'macOS', 'All')]
    [string[]]$Platforms = @('All'),
    
    [Parameter()]
    [switch]$IncludeExamples,
    
    [Parameter()]
    [switch]$SkipValidation
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Script variables
$script:ProjectRoot = Split-Path $PSScriptRoot -Parent
$script:AitherCorePath = Join-Path $script:ProjectRoot "aithercore"
$script:BuildDate = Get-Date -Format "yyyy-MM-dd"
$script:BuildTimestamp = Get-Date -Format "yyyyMMdd-HHmmss"

#region Helper Functions

function Write-BuildLog {
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        
        [Parameter()]
        [ValidateSet('Info', 'Success', 'Warning', 'Error')]
        [string]$Level = 'Info'
    )
    
    $color = switch ($Level) {
        'Info' { 'Cyan' }
        'Success' { 'Green' }
        'Warning' { 'Yellow' }
        'Error' { 'Red' }
    }
    
    $prefix = switch ($Level) {
        'Info' { '  ℹ️ ' }
        'Success' { '  ✅' }
        'Warning' { '  ⚠️ ' }
        'Error' { '  ❌' }
    }
    
    Write-Host "$prefix $Message" -ForegroundColor $color
}

function Test-AitherCoreValid {
    Write-BuildLog "Validating AitherCore structure..." -Level Info
    
    # Check directory exists
    if (-not (Test-Path $script:AitherCorePath)) {
        Write-BuildLog "AitherCore directory not found: $script:AitherCorePath" -Level Error
        return $false
    }
    
    # Check required files
    $requiredFiles = @(
        'AitherCore.psd1',
        'AitherCore.psm1',
        'README.md'
    )
    
    foreach ($file in $requiredFiles) {
        $filePath = Join-Path $script:AitherCorePath $file
        if (-not (Test-Path $filePath)) {
            Write-BuildLog "Required file missing: $file" -Level Error
            return $false
        }
    }
    
    # Check required modules
    $requiredModules = @(
        'Logging.psm1',
        'Configuration.psm1',
        'TextUtilities.psm1',
        'Performance.psm1',
        'Bootstrap.psm1',
        'PackageManager.psm1',
        'BetterMenu.psm1',
        'UserInterface.psm1',
        'Infrastructure.psm1',
        'Security.psm1',
        'OrchestrationEngine.psm1'
    )
    
    $missingModules = @()
    foreach ($module in $requiredModules) {
        $modulePath = Join-Path $script:AitherCorePath $module
        if (-not (Test-Path $modulePath)) {
            $missingModules += $module
        }
    }
    
    if ($missingModules.Count -gt 0) {
        Write-BuildLog "Missing modules: $($missingModules -join ', ')" -Level Error
        return $false
    }
    
    Write-BuildLog "Structure validation passed (11 modules present)" -Level Success
    return $true
}

function Test-AitherCoreModuleLoads {
    Write-BuildLog "Testing module load..." -Level Info
    
    try {
        $manifestPath = Join-Path $script:AitherCorePath "AitherCore.psd1"
        Import-Module $manifestPath -Force -ErrorAction Stop
        
        $module = Get-Module AitherCore
        if (-not $module) {
            Write-BuildLog "Module failed to load" -Level Error
            return $false
        }
        
        $functionCount = (Get-Command -Module AitherCore).Count
        Write-BuildLog "Module loaded successfully ($functionCount functions)" -Level Success
        
        Remove-Module AitherCore -Force
        return $true
    }
    catch {
        Write-BuildLog "Module load failed: $_" -Level Error
        return $false
    }
}

function Get-PackageVersion {
    if ($Version) {
        return $Version
    }
    
    # Read version from manifest
    $manifestPath = Join-Path $script:AitherCorePath "AitherCore.psd1"
    $manifestContent = Get-Content $manifestPath -Raw
    
    if ($manifestContent -match "ModuleVersion\s*=\s*'([^']+)'") {
        return $Matches[1]
    }
    
    # Fallback to 1.0.0
    return "1.0.0"
}

function New-PackageStructure {
    param(
        [string]$TempPath,
        [string]$PackageVersion
    )
    
    Write-BuildLog "Creating package structure..." -Level Info
    
    # Create directory structure
    $packageRoot = Join-Path $TempPath "AitherCore"
    New-Item -ItemType Directory -Path $packageRoot -Force | Out-Null
    
    # Copy aithercore modules
    Write-BuildLog "Copying core modules..." -Level Info
    $modules = Get-ChildItem $script:AitherCorePath -Filter "*.psm1"
    foreach ($module in $modules) {
        Copy-Item $module.FullName -Destination $packageRoot -Force
        Write-BuildLog "  - $($module.Name)" -Level Info
    }
    
    # Copy manifest and loader
    Copy-Item (Join-Path $script:AitherCorePath "AitherCore.psd1") -Destination $packageRoot -Force
    Copy-Item (Join-Path $script:AitherCorePath "AitherCore.psm1") -Destination $packageRoot -Force
    
    # Copy documentation
    Write-BuildLog "Copying documentation..." -Level Info
    $docs = Get-ChildItem $script:AitherCorePath -Filter "*.md"
    foreach ($doc in $docs) {
        Copy-Item $doc.FullName -Destination $packageRoot -Force
        Write-BuildLog "  - $($doc.Name)" -Level Info
    }
    
    # Copy license
    $licensePath = Join-Path $script:ProjectRoot "LICENSE"
    if (Test-Path $licensePath) {
        Copy-Item $licensePath -Destination $packageRoot -Force
    }
    
    # Create VERSION file
    $versionInfo = @"
AitherCore Version $PackageVersion
Build Date: $script:BuildDate
Build Timestamp: $script:BuildTimestamp

This is a lightweight distribution of AitherZero containing 11 essential modules:
- Foundation Layer: Logging, Configuration, TextUtilities
- Platform Services: Performance, Bootstrap, PackageManager, BetterMenu, UserInterface
- Operations Layer: Infrastructure, Security, OrchestrationEngine

For full AitherZero platform, visit: https://github.com/wizzense/AitherZero
"@
    Set-Content -Path (Join-Path $packageRoot "VERSION.txt") -Value $versionInfo
    
    return $packageRoot
}

function New-InstallScripts {
    param(
        [string]$PackageRoot,
        [string]$Platform
    )
    
    Write-BuildLog "Creating installation scripts for $Platform..." -Level Info
    
    # Windows PowerShell script
    if ($Platform -eq 'Windows' -or $Platform -eq 'All') {
        $windowsInstall = @'
#Requires -Version 7.0
<#
.SYNOPSIS
    Install AitherCore on Windows
.DESCRIPTION
    Installs AitherCore modules to the PowerShell module path
#>

param(
    [Parameter()]
    [ValidateSet('CurrentUser', 'AllUsers')]
    [string]$Scope = 'CurrentUser'
)

$moduleName = 'AitherCore'
$sourcePath = $PSScriptRoot

# Determine installation path
$installPath = if ($Scope -eq 'AllUsers') {
    "$env:ProgramFiles\PowerShell\Modules\$moduleName"
} else {
    "$env:USERPROFILE\Documents\PowerShell\Modules\$moduleName"
}

Write-Host "Installing $moduleName to $installPath..." -ForegroundColor Cyan

# Create directory if needed
if (-not (Test-Path $installPath)) {
    New-Item -ItemType Directory -Path $installPath -Force | Out-Null
}

# Copy files
Get-ChildItem $sourcePath -File | ForEach-Object {
    Copy-Item $_.FullName -Destination $installPath -Force
    Write-Host "  Copied: $($_.Name)" -ForegroundColor Gray
}

Write-Host "`n✅ Installation complete!" -ForegroundColor Green
Write-Host "`nTo use AitherCore:" -ForegroundColor Yellow
Write-Host "  Import-Module AitherCore" -ForegroundColor White
Write-Host "`nTo verify:" -ForegroundColor Yellow
Write-Host "  Get-Module AitherCore -ListAvailable" -ForegroundColor White
'@
        Set-Content -Path (Join-Path $PackageRoot "Install-Windows.ps1") -Value $windowsInstall
    }
    
    # Linux/macOS bash script
    if ($Platform -in @('Linux', 'macOS', 'All')) {
        $unixInstall = @'
#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Install AitherCore on Linux/macOS
.DESCRIPTION
    Installs AitherCore modules to the PowerShell module path
#>

param(
    [Parameter()]
    [ValidateSet('CurrentUser', 'AllUsers')]
    [string]$Scope = 'CurrentUser'
)

$moduleName = 'AitherCore'
$sourcePath = $PSScriptRoot

# Determine installation path
$installPath = if ($Scope -eq 'AllUsers') {
    "/usr/local/share/powershell/Modules/$moduleName"
} else {
    "$HOME/.local/share/powershell/Modules/$moduleName"
}

Write-Host "Installing $moduleName to $installPath..." -ForegroundColor Cyan

# Create directory if needed
if (-not (Test-Path $installPath)) {
    New-Item -ItemType Directory -Path $installPath -Force | Out-Null
}

# Copy files
Get-ChildItem $sourcePath -File | ForEach-Object {
    Copy-Item $_.FullName -Destination $installPath -Force
    Write-Host "  Copied: $($_.Name)" -ForegroundColor Gray
}

# Make script executable
if ($IsLinux -or $IsMacOS) {
    chmod +x "$installPath/Bootstrap.psm1" 2>/dev/null
}

Write-Host "`n✅ Installation complete!" -ForegroundColor Green
Write-Host "`nTo use AitherCore:" -ForegroundColor Yellow
Write-Host "  Import-Module AitherCore" -ForegroundColor White
Write-Host "`nTo verify:" -ForegroundColor Yellow
Write-Host "  Get-Module AitherCore -ListAvailable" -ForegroundColor White
'@
        Set-Content -Path (Join-Path $PackageRoot "Install-Unix.ps1") -Value $unixInstall
        
        # Make it executable on Unix
        if ($IsLinux -or $IsMacOS) {
            chmod +x (Join-Path $PackageRoot "Install-Unix.ps1")
        }
    }
}

function New-PackageArchive {
    param(
        [string]$PackageRoot,
        [string]$OutputPath,
        [string]$Platform,
        [string]$PackageVersion
    )
    
    $packageName = "AitherCore-v$PackageVersion-$Platform"
    $outputFile = Join-Path $OutputPath "$packageName"
    
    Write-BuildLog "Creating $Platform package..." -Level Info
    
    if ($Platform -eq 'Windows') {
        # Create ZIP for Windows
        $zipFile = "$outputFile.zip"
        if (Test-Path $zipFile) {
            Remove-Item $zipFile -Force
        }
        
        Compress-Archive -Path "$PackageRoot/*" -DestinationPath $zipFile -CompressionLevel Optimal
        Write-BuildLog "Created: $zipFile" -Level Success
        
        return $zipFile
    }
    else {
        # Create tar.gz for Linux/macOS
        $tarFile = "$outputFile.tar.gz"
        if (Test-Path $tarFile) {
            Remove-Item $tarFile -Force
        }
        
        $packageDir = Split-Path $PackageRoot -Leaf
        $packageParent = Split-Path $PackageRoot -Parent
        
        Push-Location $packageParent
        try {
            if ($IsLinux -or $IsMacOS) {
                tar -czf $tarFile $packageDir
            }
            else {
                # On Windows, use PowerShell compression
                Compress-Archive -Path "$PackageRoot/*" -DestinationPath "$outputFile.zip" -CompressionLevel Optimal
                Write-BuildLog "Created: $outputFile.zip (Windows host)" -Level Success
                return "$outputFile.zip"
            }
        }
        finally {
            Pop-Location
        }
        
        Move-Item $tarFile $OutputPath -Force
        Write-BuildLog "Created: $tarFile" -Level Success
        
        return $tarFile
    }
}

#endregion

#region Main Build Process

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Magenta
Write-Host "   AitherCore Package Builder" -ForegroundColor Magenta
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Magenta
Write-Host ""

# Validate prerequisites
if (-not (Test-AitherCoreValid)) {
    Write-BuildLog "Validation failed. Cannot proceed with build." -Level Error
    exit 1
}

# Test module loads
if (-not $SkipValidation) {
    if (-not (Test-AitherCoreModuleLoads)) {
        Write-BuildLog "Module load test failed. Cannot proceed with build." -Level Error
        exit 1
    }
}
else {
    Write-BuildLog "Skipping validation (as requested)" -Level Warning
}

# Get version
$packageVersion = Get-PackageVersion
Write-BuildLog "Package version: $packageVersion" -Level Info

# Create output directory
if (-not (Test-Path $OutputPath)) {
    New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
}
$OutputPath = (Resolve-Path $OutputPath).Path

# Determine platforms
$targetPlatforms = if ($Platforms -contains 'All') {
    @('Windows', 'Linux', 'macOS')
}
else {
    $Platforms
}

Write-BuildLog "Building for platforms: $($targetPlatforms -join ', ')" -Level Info
Write-Host ""

# Build each platform
$createdPackages = @()

foreach ($platform in $targetPlatforms) {
    Write-Host ""
    Write-Host "─────────────────────────────────────────────────────────" -ForegroundColor Cyan
    Write-Host "  Building $platform Package" -ForegroundColor Cyan
    Write-Host "─────────────────────────────────────────────────────────" -ForegroundColor Cyan
    Write-Host ""
    
    # Create temp directory
    $tempPath = Join-Path $env:TEMP "aithercore-build-$script:BuildTimestamp-$platform"
    if (Test-Path $tempPath) {
        Remove-Item $tempPath -Recurse -Force
    }
    New-Item -ItemType Directory -Path $tempPath -Force | Out-Null
    
    try {
        # Create package structure
        $packageRoot = New-PackageStructure -TempPath $tempPath -PackageVersion $packageVersion
        
        # Add installation scripts
        New-InstallScripts -PackageRoot $packageRoot -Platform $platform
        
        # Add examples if requested
        if ($IncludeExamples) {
            Write-BuildLog "Including example scripts..." -Level Info
            $examplesPath = Join-Path $script:ProjectRoot "examples"
            if (Test-Path $examplesPath) {
                $examplesDir = Join-Path $packageRoot "examples"
                New-Item -ItemType Directory -Path $examplesDir -Force | Out-Null
                Copy-Item "$examplesPath/*" -Destination $examplesDir -Recurse -Force
            }
        }
        
        # Create archive
        $packageFile = New-PackageArchive -PackageRoot $packageRoot -OutputPath $OutputPath -Platform $platform -PackageVersion $packageVersion
        $createdPackages += $packageFile
        
        Write-Host ""
        Write-BuildLog "$platform package complete" -Level Success
    }
    finally {
        # Cleanup temp directory
        if (Test-Path $tempPath) {
            Remove-Item $tempPath -Recurse -Force
        }
    }
}

# Summary
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Magenta
Write-Host "   Build Complete!" -ForegroundColor Magenta
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Magenta
Write-Host ""
Write-Host "📦 Created Packages:" -ForegroundColor Green
Write-Host ""

foreach ($package in $createdPackages) {
    $fileSize = [math]::Round((Get-Item $package).Length / 1MB, 2)
    Write-Host "  ✅ $package ($fileSize MB)" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "📋 Package Contents:" -ForegroundColor Yellow
Write-Host "  • 11 core PowerShell modules"
Write-Host "  • Module manifest (AitherCore.psd1)"
Write-Host "  • Module loader (AitherCore.psm1)"
Write-Host "  • Comprehensive documentation (6 files)"
Write-Host "  • Installation scripts (platform-specific)"
Write-Host "  • LICENSE and VERSION files"
if ($IncludeExamples) {
    Write-Host "  • Example scripts"
}

Write-Host ""
Write-Host "🚀 Distribution packages ready for release!" -ForegroundColor Green
Write-Host ""

#endregion

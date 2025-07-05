#Requires -Version 7.0

<#
.SYNOPSIS
    AitherZero Smart Build System - Cross-Platform Package Builder

.DESCRIPTION
    Creates optimized packages for Windows, Linux, and macOS with three distinct profiles:
    - Minimal: Core infrastructure deployment (5-8 MB)
    - Standard: Production-ready automation (15-25 MB)
    - Development: Complete contributor environment (35-50 MB)

.PARAMETER Profile
    Package profile: minimal, standard, or development

.PARAMETER Platform
    Target platform: windows, linux, macos, or all

.PARAMETER Version
    Package version (defaults to VERSION file or git tag)

.PARAMETER OutputPath
    Output directory for packages (defaults to ./dist)

.PARAMETER Force
    Overwrite existing packages

.PARAMETER DryRun
    Show what would be built without creating packages

.PARAMETER Validate
    Validate package contents after creation

.EXAMPLE
    ./Build-Package.ps1 -Profile minimal -Platform windows
    # Creates minimal Windows package

.EXAMPLE
    ./Build-Package.ps1 -Profile all -Platform all -Version "2.1.0"
    # Creates all profiles for all platforms with specific version

.EXAMPLE
    ./Build-Package.ps1 -Profile development -Platform linux -DryRun
    # Preview development Linux package without building
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $false)]
    [ValidateSet('minimal', 'standard', 'development', 'all')]
    [string]$Profile = 'standard',

    [Parameter(Mandatory = $false)]
    [ValidateSet('windows', 'linux', 'macos', 'all')]
    [string]$Platform = 'all',

    [Parameter(Mandatory = $false)]
    [string]$Version,

    [Parameter(Mandatory = $false)]
    [string]$OutputPath = './dist',

    [Parameter(Mandatory = $false)]
    [switch]$Force,

    [Parameter(Mandatory = $false)]
    [switch]$DryRun,

    [Parameter(Mandatory = $false)]
    [switch]$Validate
)

# Initialize build environment
$ErrorActionPreference = 'Stop'
$buildStartTime = Get-Date

# Find project root
function Find-ProjectRoot {
    param([string]$StartPath = $PWD)

    $current = Get-Item $StartPath
    while ($current) {
        if (Test-Path (Join-Path $current.FullName 'aither-core')) {
            return $current.FullName
        }
        $current = $current.Parent
    }
    throw 'Could not find project root (looking for aither-core directory)'
}

$projectRoot = Find-ProjectRoot
$buildRoot = Join-Path $projectRoot 'build'

# Logging functions
function Write-BuildLog {
    param(
        [string]$Message,
        [ValidateSet('INFO', 'SUCCESS', 'WARNING', 'ERROR', 'DEBUG')]
        [string]$Level = 'INFO'
    )

    $timestamp = Get-Date -Format 'HH:mm:ss'
    $color = @{
        'INFO'    = 'Cyan'
        'SUCCESS' = 'Green'
        'WARNING' = 'Yellow'
        'ERROR'   = 'Red'
        'DEBUG'   = 'Gray'
    }[$Level]

    Write-Host "[$timestamp] $Message" -ForegroundColor $color
}

function Write-BuildHeader {
    param([string]$Title)
    Write-Host ''
    Write-Host ('=' * 60) -ForegroundColor Magenta
    Write-Host " $Title" -ForegroundColor Magenta
    Write-Host ('=' * 60) -ForegroundColor Magenta
}

# Version detection
function Get-BuildVersion {
    if ($Version) { return $Version }

    # Try VERSION file
    $versionFile = Join-Path $projectRoot 'VERSION'
    if (Test-Path $versionFile) {
        $fileVersion = (Get-Content $versionFile -Raw).Trim()
        if ($fileVersion) {
            Write-BuildLog "Version from VERSION file: $fileVersion" -Level 'INFO'
            return $fileVersion
        }
    }

    # Try git tag
    try {
        $gitTag = git describe --tags --abbrev=0 2>$null
        if ($gitTag -and $gitTag -match '^v?(.+)$') {
            $gitVersion = $matches[1]
            Write-BuildLog "Version from git tag: $gitVersion" -Level 'INFO'
            return $gitVersion
        }
    } catch {
        Write-BuildLog "Could not get git tag: $_" -Level 'DEBUG'
    }

    # Default version
    $defaultVersion = '1.0.0-dev'
    Write-BuildLog "Using default version: $defaultVersion" -Level 'WARNING'
    return $defaultVersion
}

# Profile management
function Get-ProfileConfig {
    param([string]$ProfileName)

    $profilePath = Join-Path $buildRoot 'profiles' "$ProfileName.json"
    if (-not (Test-Path $profilePath)) {
        throw "Profile configuration not found: $profilePath"
    }

    $config = Get-Content $profilePath -Raw | ConvertFrom-Json

    # Handle profile inheritance
    if ($config.extends) {
        $baseConfig = Get-ProfileConfig -ProfileName $config.extends

        # Ensure modules structure exists
        if (-not $config.modules) {
            $config | Add-Member -NotePropertyName 'modules' -NotePropertyValue @{} -Force
        }

        # Merge module lists
        if ($config.additionalModules) {
            $allModules = @($baseConfig.modules.required) + @($config.additionalModules)
            $config.modules | Add-Member -NotePropertyName 'required' -NotePropertyValue $allModules -Force
        } else {
            $config.modules = $baseConfig.modules
        }

        # Merge other properties
        foreach ($prop in @('coreFiles', 'directories', 'features')) {
            if (-not $config.$prop -and $baseConfig.$prop) {
                $config | Add-Member -NotePropertyName $prop -NotePropertyValue $baseConfig.$prop -Force
            }
        }
    }

    # Ensure required properties exist
    if (-not $config.modules) {
        $config | Add-Member -NotePropertyName 'modules' -NotePropertyValue @{ required = @() } -Force
    }
    if (-not $config.modules.required) {
        $config.modules | Add-Member -NotePropertyName 'required' -NotePropertyValue @() -Force
    }
    if (-not $config.coreFiles) {
        $config | Add-Member -NotePropertyName 'coreFiles' -NotePropertyValue @('aither-core.ps1', 'VERSION', 'README.md', 'LICENSE') -Force
    }

    return $config
}

# Platform-specific functions
function Get-PlatformInfo {
    param([string]$PlatformName)

    return @{
        'windows' = @{
            name       = 'windows'
            extension  = 'zip'
            archiver   = 'zip'
            launcher   = 'AitherZero.bat'
            lineEnding = "`r`n"
            executable = '.ps1'
        }
        'linux'   = @{
            name       = 'linux'
            extension  = 'tar.gz'
            archiver   = 'tar'
            launcher   = 'aitherzero.sh'
            lineEnding = "`n"
            executable = '.ps1'
        }
        'macos'   = @{
            name       = 'macos'
            extension  = 'tar.gz'
            archiver   = 'tar'
            launcher   = 'aitherzero.sh'
            lineEnding = "`n"
            executable = '.ps1'
        }
    }[$PlatformName]
}

# File operations
function Copy-BuildFiles {
    param(
        [string]$SourcePath,
        [string]$DestinationPath,
        [string[]]$Include = @('*'),
        [string[]]$Exclude = @(),
        [switch]$Recurse
    )

    if (-not (Test-Path $SourcePath)) {
        Write-BuildLog "Source path not found: $SourcePath" -Level 'WARNING'
        return
    }

    $params = @{
        Path        = $SourcePath
        Destination = $DestinationPath
        Force       = $true
    }

    if ($Recurse) { $params.Recurse = $true }
    if ($Include.Count -gt 0 -and $Include[0] -ne '*') { $params.Include = $Include }
    if ($Exclude.Count -gt 0) { $params.Exclude = $Exclude }

    try {
        Copy-Item @params
        Write-BuildLog "Copied: $SourcePath -> $DestinationPath" -Level 'DEBUG'
    } catch {
        Write-BuildLog "Failed to copy $SourcePath : $_" -Level 'ERROR'
        throw
    }
}

# Module packaging
function Copy-ModuleFiles {
    param(
        [string]$ModuleName,
        [string]$DestinationPath,
        [object]$ModuleConfig
    )

    $modulePath = Join-Path $projectRoot 'aither-core' 'modules' $ModuleName
    if (-not (Test-Path $modulePath)) {
        Write-BuildLog "Module not found: $ModuleName at $modulePath" -Level 'WARNING'
        return
    }

    $moduleDestPath = Join-Path $DestinationPath $ModuleName
    New-Item -ItemType Directory -Path $moduleDestPath -Force | Out-Null

    # Copy module files based on configuration
    $include = $ModuleConfig.include -split ','
    $exclude = $ModuleConfig.exclude -split ','

    Copy-BuildFiles -SourcePath "$modulePath/*" -DestinationPath $moduleDestPath -Include $include -Exclude $exclude -Recurse

    Write-BuildLog "Packaged module: $ModuleName" -Level 'DEBUG'
}

# Platform-specific launcher creation
function New-PlatformLauncher {
    param(
        [string]$PlatformName,
        [string]$PackagePath,
        [string]$Version
    )

    $platformInfo = Get-PlatformInfo -PlatformName $PlatformName

    switch ($PlatformName) {
        'windows' {
            $launcherContent = @"
@echo off
setlocal

echo.
echo ==================================================
echo  AitherZero Infrastructure Automation v$Version
echo  Windows Build - $Profile Profile
echo ==================================================
echo.

REM Check for PowerShell 7
where pwsh >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo [INFO] Using PowerShell 7
    pwsh -File "Start-AitherZero.ps1" %*
) else (
    echo [INFO] PowerShell 7 not found, using Windows PowerShell
    echo [WARN] Consider upgrading to PowerShell 7 for best experience
    powershell -ExecutionPolicy Bypass -File "Start-AitherZero.ps1" %*
)

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [ERROR] AitherZero exited with error code %ERRORLEVEL%
    echo Press any key to continue...
    pause >nul
)
"@
        }

        'linux' {
            $launcherContent = @"
#!/bin/bash

echo ""
echo "=================================================="
echo " AitherZero Infrastructure Automation v$Version"
echo " Linux Build - $Profile Profile"
echo "=================================================="
echo ""

# Check for PowerShell
if command -v pwsh &> /dev/null; then
    echo "[INFO] Using PowerShell Core"
    pwsh -File "./Start-AitherZero.ps1" "\$@"
elif command -v powershell &> /dev/null; then
    echo "[INFO] Using PowerShell"
    powershell -File "./Start-AitherZero.ps1" "\$@"
else
    echo "[ERROR] PowerShell not found"
    echo "Please install PowerShell: https://aka.ms/powershell"
    exit 1
fi

exit_code=\$?
if [ \$exit_code -ne 0 ]; then
    echo ""
    echo "[ERROR] AitherZero exited with error code \$exit_code"
fi
exit \$exit_code
"@
        }

        'macos' {
            $launcherContent = @"
#!/bin/bash

echo ""
echo "=================================================="
echo " AitherZero Infrastructure Automation v$Version"
echo " macOS Build - $Profile Profile"
echo "=================================================="
echo ""

# Check for PowerShell
if command -v pwsh &> /dev/null; then
    echo "[INFO] Using PowerShell Core"
    pwsh -File "./Start-AitherZero.ps1" "\$@"
elif command -v powershell &> /dev/null; then
    echo "[INFO] Using PowerShell"
    powershell -File "./Start-AitherZero.ps1" "\$@"
else
    echo "[ERROR] PowerShell not found"
    echo "Install PowerShell: brew install --cask powershell"
    exit 1
fi

exit_code=\$?
if [ \$exit_code -ne 0 ]; then
    echo ""
    echo "[ERROR] AitherZero exited with error code \$exit_code"
fi
exit \$exit_code
"@
        }
    }

    $launcherPath = Join-Path $PackagePath $platformInfo.launcher
    Set-Content -Path $launcherPath -Value $launcherContent -Encoding UTF8

    # Set executable permissions for Unix platforms
    if ($PlatformName -in @('linux', 'macos')) {
        if (Get-Command chmod -ErrorAction SilentlyContinue) {
            chmod +x $launcherPath
        }
    }

    Write-BuildLog "Created platform launcher: $($platformInfo.launcher)" -Level 'DEBUG'
}

# Package creation
function New-Package {
    param(
        [string]$ProfileName,
        [string]$PlatformName,
        [string]$Version
    )

    Write-BuildHeader "Building $ProfileName profile for $PlatformName"

    $config = Get-ProfileConfig -ProfileName $ProfileName
    $platformInfo = Get-PlatformInfo -PlatformName $PlatformName

    $packageName = "AitherZero-$Version-$ProfileName-$PlatformName"
    $packagePath = Join-Path $OutputPath $packageName

    Write-BuildLog "Package: $packageName" -Level 'INFO'
    Write-BuildLog "Estimated size: $($config.estimatedSize)" -Level 'INFO'
    Write-BuildLog "Target: $($config.targetAudience)" -Level 'INFO'

    if ($DryRun) {
        Write-BuildLog "DRY RUN: Would create package at $packagePath" -Level 'WARNING'
        return @{
            Name     = $packageName
            Path     = $packagePath
            Profile  = $ProfileName
            Platform = $PlatformName
            Size     = 'N/A (dry run)'
        }
    }

    # Create package directory
    if (Test-Path $packagePath) {
        if ($Force) {
            Remove-Item $packagePath -Recurse -Force
        } else {
            throw "Package already exists: $packagePath (use -Force to overwrite)"
        }
    }
    New-Item -ItemType Directory -Path $packagePath -Force | Out-Null

    # Copy core files
    Write-BuildLog 'Copying core files...' -Level 'INFO'
    foreach ($file in $config.coreFiles) {
        $sourcePath = Join-Path $projectRoot $file
        if (Test-Path $sourcePath) {
            Copy-Item $sourcePath -Destination $packagePath -Force
            Write-BuildLog "Copied core file: $file" -Level 'DEBUG'
        } else {
            Write-BuildLog "Core file not found (skipping): $file" -Level 'WARNING'
        }
    }

    # Copy aither-core directory structure
    Write-BuildLog 'Copying aither-core...' -Level 'INFO'
    $aitherCoreSource = Join-Path $projectRoot 'aither-core'
    $aitherCoreDest = Join-Path $packagePath 'aither-core'
    New-Item -ItemType Directory -Path $aitherCoreDest -Force | Out-Null

    # Copy specified aither-core files
    foreach ($file in $config.directories.'aither-core'.include) {
        $sourcePath = Join-Path $aitherCoreSource $file
        if (Test-Path $sourcePath) {
            Copy-Item $sourcePath -Destination $aitherCoreDest -Force
            Write-BuildLog "Copied aither-core file: $file" -Level 'DEBUG'
        } else {
            Write-BuildLog "Aither-core file not found (skipping): $file" -Level 'WARNING'
        }
    }

    # Copy subdirectories
    foreach ($subdir in $config.directories.'aither-core'.subdirectories.Keys) {
        $subdirSource = Join-Path $aitherCoreSource $subdir
        $subdirDest = Join-Path $aitherCoreDest $subdir

        if (Test-Path $subdirSource) {
            $subdirConfig = $config.directories.'aither-core'.subdirectories.$subdir

            if ($subdirConfig -eq 'all') {
                Copy-Item $subdirSource -Destination $subdirDest -Recurse -Force
                Write-BuildLog "Copied subdirectory: $subdir (all files)" -Level 'DEBUG'
            } elseif ($subdirConfig -is [array]) {
                New-Item -ItemType Directory -Path $subdirDest -Force | Out-Null
                foreach ($file in $subdirConfig) {
                    $filePath = Join-Path $subdirSource $file
                    if (Test-Path $filePath) {
                        Copy-Item $filePath -Destination $subdirDest -Force
                        Write-BuildLog "Copied subdirectory file: $subdir/$file" -Level 'DEBUG'
                    } else {
                        Write-BuildLog "Subdirectory file not found (skipping): $subdir/$file" -Level 'WARNING'
                    }
                }
            }
        } else {
            Write-BuildLog "Subdirectory not found (skipping): $subdir" -Level 'WARNING'
        }
    }

    # Always copy shared directory (critical for module dependencies)
    $sharedSource = Join-Path $aitherCoreSource 'shared'
    $sharedDest = Join-Path $aitherCoreDest 'shared'
    if (Test-Path $sharedSource) {
        Copy-Item $sharedSource -Destination $sharedDest -Recurse -Force
        Write-BuildLog "Copied shared utilities directory" -Level 'DEBUG'
    } else {
        Write-BuildLog "Shared utilities directory not found at: $sharedSource" -Level 'WARNING'
    }

    # Copy modules
    Write-BuildLog 'Copying modules...' -Level 'INFO'
    $modulesDest = Join-Path $aitherCoreDest 'modules'
    New-Item -ItemType Directory -Path $modulesDest -Force | Out-Null

    foreach ($moduleName in $config.modules.required) {
        Copy-ModuleFiles -ModuleName $moduleName -DestinationPath $modulesDest -ModuleConfig $config.modules.moduleComponents
    }

    # Copy additional directories
    if ($config.additionalDirectories) {
        Write-BuildLog 'Copying additional directories...' -Level 'INFO'
        foreach ($dirPath in $config.additionalDirectories.Keys) {
            $dirConfig = $config.additionalDirectories.$dirPath
            $sourcePath = Join-Path $projectRoot $dirPath
            $destPath = Join-Path $packagePath $dirPath

            if (Test-Path $sourcePath) {
                if ($dirConfig -eq 'all') {
                    Copy-Item $sourcePath -Destination $destPath -Recurse -Force
                } elseif ($dirConfig -is [array]) {
                    New-Item -ItemType Directory -Path $destPath -Force | Out-Null
                    foreach ($file in $dirConfig) {
                        $filePath = Join-Path $sourcePath $file
                        if (Test-Path $filePath) {
                            Copy-Item $filePath -Destination $destPath -Force
                        }
                    }
                }
            }
        }
    }

    # Copy configurations
    Write-BuildLog 'Copying configurations...' -Level 'INFO'
    # Create configs in both locations for compatibility
    $configsDest = Join-Path $packagePath 'configs'
    $aitherCoreConfigsDest = Join-Path $packagePath 'aither-core' 'configs'
    New-Item -ItemType Directory -Path $configsDest -Force | Out-Null
    New-Item -ItemType Directory -Path $aitherCoreConfigsDest -Force | Out-Null

    foreach ($configFile in $config.configs) {
        $configSource = Join-Path $projectRoot 'configs' $configFile
        if (Test-Path $configSource) {
            Copy-Item $configSource -Destination $configsDest -Force
            # Also copy to aither-core/configs for compatibility
            Copy-Item $configSource -Destination $aitherCoreConfigsDest -Force
        }
    }

    # Copy additional configs if specified
    if ($config.additionalConfigs) {
        foreach ($configFile in $config.additionalConfigs) {
            $configSource = Join-Path $projectRoot 'configs' $configFile
            if (Test-Path $configSource) {
                Copy-Item $configSource -Destination $configsDest -Force
                # Also copy to aither-core/configs for compatibility
                Copy-Item $configSource -Destination $aitherCoreConfigsDest -Force
            }
        }
    }

    # Copy development files for development profile
    if ($config.developmentFiles) {
        Write-BuildLog 'Copying development files...' -Level 'INFO'
        foreach ($devFile in $config.developmentFiles) {
            $devSource = Join-Path $projectRoot $devFile
            if (Test-Path $devSource) {
                Copy-Item $devSource -Destination $packagePath -Force
            }
        }
    }

    # Create platform-specific launcher
    New-PlatformLauncher -PlatformName $PlatformName -PackagePath $packagePath -Version $Version

    # Create build information file
    $buildInfo = @{
        version        = $Version
        profile        = $ProfileName
        platform       = $PlatformName
        buildDate      = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss UTC')
        features       = $config.features
        modules        = $config.modules.required
        description    = $config.description
        targetAudience = $config.targetAudience
        estimatedSize  = $config.estimatedSize
    }

    $buildInfoPath = Join-Path $packagePath 'build-info.json'
    $buildInfo | ConvertTo-Json -Depth 4 | Set-Content -Path $buildInfoPath -Encoding UTF8

    # Create archive
    Write-BuildLog 'Creating archive...' -Level 'INFO'
    $archiveName = "$packageName.$($platformInfo.extension)"
    $archivePath = Join-Path $OutputPath $archiveName

    if (Test-Path $archivePath) {
        if ($Force) {
            Remove-Item $archivePath -Force
        } else {
            throw "Archive already exists: $archivePath (use -Force to overwrite)"
        }
    }

    switch ($platformInfo.archiver) {
        'zip' {
            Compress-Archive -Path "$packagePath/*" -DestinationPath $archivePath -Force
        }
        'tar' {
            Push-Location $OutputPath
            try {
                if (Get-Command tar -ErrorAction SilentlyContinue) {
                    tar -czf $archiveName $packageName
                } else {
                    # Fallback to PowerShell compression
                    Compress-Archive -Path "$packagePath/*" -DestinationPath "$archiveName.zip" -Force
                    Write-BuildLog 'Created ZIP instead of TAR.GZ (tar command not available)' -Level 'WARNING'
                }
            } finally {
                Pop-Location
            }
        }
    }

    # Calculate package size
    $packageSize = if (Test-Path $archivePath) {
        [math]::Round((Get-Item $archivePath).Length / 1MB, 2)
    } else { 0 }

    Write-BuildLog "Package created: $archiveName ($packageSize MB)" -Level 'SUCCESS'

    # Validate package if requested
    if ($Validate) {
        Write-BuildLog 'Validating package...' -Level 'INFO'
        Test-Package -PackagePath $packagePath -Config $config
    }

    return @{
        Name     = $packageName
        Path     = $packagePath
        Archive  = $archivePath
        Profile  = $ProfileName
        Platform = $PlatformName
        Size     = "$packageSize MB"
    }
}

# Package validation
function Test-Package {
    param(
        [string]$PackagePath,
        [object]$Config
    )

    $validationErrors = @()

    # Check core files
    foreach ($file in $Config.coreFiles) {
        $filePath = Join-Path $PackagePath $file
        if (-not (Test-Path $filePath)) {
            $validationErrors += "Missing core file: $file"
        }
    }

    # Check required modules
    foreach ($module in $Config.modules.required) {
        $modulePath = Join-Path $PackagePath 'aither-core' 'modules' $module
        if (-not (Test-Path $modulePath)) {
            $validationErrors += "Missing module: $module"
        }
    }

    # Check launcher
    $launcherExists = $false
    foreach ($launcher in @('AitherZero.bat', 'aitherzero.sh')) {
        if (Test-Path (Join-Path $PackagePath $launcher)) {
            $launcherExists = $true
            break
        }
    }
    if (-not $launcherExists) {
        $validationErrors += 'No platform launcher found'
    }

    if ($validationErrors.Count -gt 0) {
        Write-BuildLog 'Package validation failed:' -Level 'ERROR'
        foreach ($error in $validationErrors) {
            Write-BuildLog "  - $error" -Level 'ERROR'
        }
        throw 'Package validation failed'
    } else {
        Write-BuildLog 'Package validation passed' -Level 'SUCCESS'
    }
}

# Main execution
try {
    Write-BuildHeader 'AitherZero Smart Build System v2.0'

    $buildVersion = Get-BuildVersion
    Write-BuildLog "Build version: $buildVersion" -Level 'INFO'
    Write-BuildLog "Project root: $projectRoot" -Level 'INFO'

    # Create output directory
    New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    Write-BuildLog "Output path: $OutputPath" -Level 'INFO'

    # Determine profiles and platforms to build
    $profilesToBuild = if ($Profile -eq 'all') { @('minimal', 'standard', 'development') } else { @($Profile) }
    $platformsToBuild = if ($Platform -eq 'all') { @('windows', 'linux', 'macos') } else { @($Platform) }

    Write-BuildLog "Building profiles: $($profilesToBuild -join ', ')" -Level 'INFO'
    Write-BuildLog "Building platforms: $($platformsToBuild -join ', ')" -Level 'INFO'

    $packages = @()
    $totalBuilds = $profilesToBuild.Count * $platformsToBuild.Count
    $currentBuild = 0

    foreach ($prof in $profilesToBuild) {
        foreach ($plat in $platformsToBuild) {
            $currentBuild++
            Write-BuildLog "Building $currentBuild of $totalBuilds..." -Level 'INFO'

            $package = New-Package -ProfileName $prof -PlatformName $plat -Version $buildVersion
            $packages += $package
        }
    }

    # Build summary
    $buildDuration = (Get-Date) - $buildStartTime
    Write-BuildHeader 'Build Summary'
    Write-BuildLog "Build completed in $($buildDuration.TotalSeconds.ToString('F1')) seconds" -Level 'SUCCESS'
    Write-BuildLog "Packages created: $($packages.Count)" -Level 'INFO'

    foreach ($package in $packages) {
        Write-BuildLog "  - $($package.Name) ($($package.Size))" -Level 'INFO'
    }

    Write-BuildLog "All packages available in: $OutputPath" -Level 'SUCCESS'

} catch {
    Write-BuildLog "Build failed: $_" -Level 'ERROR'
    exit 1
}

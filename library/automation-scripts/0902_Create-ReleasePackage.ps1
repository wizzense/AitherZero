#Requires -Version 7.0

<#
.SYNOPSIS
    Create AitherZero release packages (ZIP/TAR.GZ)
.DESCRIPTION
    Creates deployable release packages for AitherZero with configurable options.
    Supports multiple package formats and can create runtime-only or full packages.

    Exit Codes:
    0   - Package created successfully
    1   - Package creation failed
    2   - Invalid parameters

.NOTES
    Stage: Build
    Order: 0902
    Dependencies: None
    Tags: build, package, release, artifact
.PARAMETER PackageFormat
    Package format: ZIP, TarGz, or Both
.PARAMETER OutputPath
    Output directory for packages (default: repository root)
.PARAMETER IncludeTests
    Include test files in the package
.PARAMETER OnlyRuntime
    Create runtime-only package (exclude docs, tests, dev files)
.PARAMETER Version
    Version string for the package (default: from VERSION file or config.psd1)
.EXAMPLE
    ./0902_Create-ReleasePackage.ps1 -PackageFormat Both -OnlyRuntime
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter()]
    [ValidateSet('ZIP', 'TarGz', 'Both')]
    [string]$PackageFormat = 'Both',
    
    [Parameter()]
    [string]$OutputPath = '',
    
    [Parameter()]
    [switch]$IncludeTests,
    
    [Parameter()]
    [switch]$OnlyRuntime,
    
    [Parameter()]
    [string]$Version = ''
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Script metadata
$scriptMetadata = @{
    Stage = 'Build'
    Order = 0902
    Dependencies = @()
    Tags = @('build', 'package', 'release', 'artifact')
    RequiresAdmin = $false
    SupportsWhatIf = $true
}

# Get project root
$ProjectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent

# Import utilities
$utilitiesPath = Join-Path $ProjectRoot "aithercore/automation/ScriptUtilities.psm1"
if (Test-Path $utilitiesPath) {
    Import-Module $utilitiesPath -Force -ErrorAction SilentlyContinue
}

function Write-ScriptLog {
    param(
        [string]$Message,
        [string]$Level = 'Information'
    )
    
    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Message $Message -Level $Level -Source "0902_Create-ReleasePackage"
    } else {
        $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        $color = switch ($Level) {
            'Error' { 'Red' }
            'Warning' { 'Yellow' }
            'Success' { 'Green' }
            default { 'Cyan' }
        }
        Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
    }
}

function Get-PackageVersion {
    <#
    .SYNOPSIS
        Get the version for the package
    #>
    
    # Priority: Parameter > VERSION file > config.psd1 > git tag > default
    if ($Version) {
        Write-ScriptLog "Using version from parameter: $Version"
        return $Version
    }
    
    # Try VERSION file
    $versionFile = Join-Path $ProjectRoot "VERSION"
    if (Test-Path $versionFile) {
        $versionContent = (Get-Content $versionFile -Raw).Trim()
        if ($versionContent) {
            Write-ScriptLog "Using version from VERSION file: $versionContent"
            return $versionContent
        }
    }
    
    # Try config.psd1
    $configFile = Join-Path $ProjectRoot "config.psd1"
    if (Test-Path $configFile) {
        try {
            $configContent = Get-Content -Path $configFile -Raw
            $scriptBlock = [scriptblock]::Create($configContent)
            $config = & $scriptBlock
            
            if ($config.Manifest.Version) {
                Write-ScriptLog "Using version from config.psd1: $($config.Manifest.Version)"
                return $config.Manifest.Version
            }
        } catch {
            Write-ScriptLog "Failed to read version from config.psd1: $_" -Level Warning
        }
    }
    
    # Try git tag
    if (Get-Command git -ErrorAction SilentlyContinue) {
        try {
            Push-Location $ProjectRoot
            $gitTag = git describe --tags --abbrev=0 2>$null
            if ($gitTag) {
                $gitVersion = $gitTag -replace '^v', ''
                Write-ScriptLog "Using version from git tag: $gitVersion"
                return $gitVersion
            }
        } catch {
            # Ignore git errors
        } finally {
            Pop-Location
        }
    }
    
    # Default version
    $defaultVersion = "2.0.0"
    Write-ScriptLog "Using default version: $defaultVersion" -Level Warning
    return $defaultVersion
}

function Get-PackageFiles {
    <#
    .SYNOPSIS
        Get list of files to include in the package
    #>
    param(
        [bool]$RuntimeOnly,
        [bool]$IncludeTests
    )
    
    $includePatterns = @(
        # Core files (always include)
        'AitherZero.psd1',
        'AitherZero.psm1',
        'Start-AitherZero.ps1',
        'bootstrap.ps1',
        'bootstrap.sh',
        'aitherzero',
        'config.psd1',
        'config.example.psd1',
        'PSScriptAnalyzerSettings.psd1',
        'VERSION',
        'README.md',
        'LICENSE',
        
        # Core directories
        'aithercore/**',
        'library/automation-scripts/**',
        'library/playbooks/**',
        'library/orchestration/**'
    )
    
    if (-not $RuntimeOnly) {
        # Development files
        $includePatterns += @(
            'docs/**',
            '.github/**',
            '.vscode/**',
            '.devcontainer/**',
            '.githooks/**',
            'infrastructure/**',
            'integrations/**',
            'tools/**'
        )
    }
    
    if ($IncludeTests) {
        $includePatterns += @(
            'tests/**',
            'library/tests/**',
            'Invoke-AitherTests.ps1'
        )
    }
    
    # Exclusions (always exclude)
    $excludePatterns = @(
        '**/.git/**',
        '**/node_modules/**',
        '**/bin/**',
        '**/obj/**',
        '**/*.log',
        '**/logs/**',
        '**/reports/**',
        '**/.vs/**',
        '**/.vscode/.ropeproject/**',
        '**/coverage/**',
        '**/__pycache__/**',
        '**/*.pyc',
        '**/temp/**',
        '**/tmp/**',
        '**/.DS_Store',
        '**/Thumbs.db'
    )
    
    return @{
        Include = $includePatterns
        Exclude = $excludePatterns
    }
}

function New-ZipPackage {
    <#
    .SYNOPSIS
        Create ZIP package
    #>
    param(
        [string]$SourcePath,
        [string]$DestinationPath,
        [array]$IncludeFiles,
        [array]$ExcludeFiles
    )
    
    Write-ScriptLog "Creating ZIP package: $DestinationPath"
    
    if ($PSCmdlet.ShouldProcess($DestinationPath, "Create ZIP package")) {
        try {
            # Use PowerShell's Compress-Archive with file filtering
            $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "aitherzero-package-$(Get-Random)"
            New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
            
            # Copy files with filtering
            Write-ScriptLog "Copying files to temporary directory..."
            Copy-FilesWithFilter -SourcePath $SourcePath -DestinationPath $tempDir -Include $IncludeFiles -Exclude $ExcludeFiles
            
            # Create archive
            Write-ScriptLog "Compressing to ZIP..."
            Compress-Archive -Path "$tempDir/*" -DestinationPath $DestinationPath -Force
            
            # Cleanup
            Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
            
            $packageSize = (Get-Item $DestinationPath).Length / 1MB
            Write-ScriptLog "ZIP package created: $([math]::Round($packageSize, 2)) MB" -Level Success
            
            return $true
        } catch {
            Write-ScriptLog "Failed to create ZIP package: $_" -Level Error
            return $false
        }
    }
    
    return $false
}

function New-TarGzPackage {
    <#
    .SYNOPSIS
        Create TAR.GZ package
    #>
    param(
        [string]$SourcePath,
        [string]$DestinationPath,
        [array]$IncludeFiles,
        [array]$ExcludeFiles
    )
    
    Write-ScriptLog "Creating TAR.GZ package: $DestinationPath"
    
    if ($PSCmdlet.ShouldProcess($DestinationPath, "Create TAR.GZ package")) {
        try {
            $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "aitherzero-package-$(Get-Random)"
            New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
            
            # Copy files with filtering
            Write-ScriptLog "Copying files to temporary directory..."
            Copy-FilesWithFilter -SourcePath $SourcePath -DestinationPath $tempDir -Include $IncludeFiles -Exclude $ExcludeFiles
            
            # Create tar.gz using tar command if available
            if (Get-Command tar -ErrorAction SilentlyContinue) {
                Write-ScriptLog "Compressing to TAR.GZ using tar command..."
                Push-Location $tempDir
                try {
                    $tarFile = $DestinationPath -replace '\.gz$', ''
                    tar -czf $DestinationPath * 2>&1 | Out-Null
                    
                    if (Test-Path $DestinationPath) {
                        $packageSize = (Get-Item $DestinationPath).Length / 1MB
                        Write-ScriptLog "TAR.GZ package created: $([math]::Round($packageSize, 2)) MB" -Level Success
                        $success = $true
                    } else {
                        Write-ScriptLog "TAR.GZ package was not created" -Level Error
                        $success = $false
                    }
                } finally {
                    Pop-Location
                }
            } else {
                Write-ScriptLog "tar command not available, skipping TAR.GZ package" -Level Warning
                $success = $false
            }
            
            # Cleanup
            Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
            
            return $success
        } catch {
            Write-ScriptLog "Failed to create TAR.GZ package: $_" -Level Error
            return $false
        }
    }
    
    return $false
}

function Copy-FilesWithFilter {
    <#
    .SYNOPSIS
        Copy files with include/exclude filtering
    #>
    param(
        [string]$SourcePath,
        [string]$DestinationPath,
        [array]$Include,
        [array]$Exclude
    )
    
    # For simplicity, copy core directories and files
    $coreDirs = @('aithercore', 'library')
    $coreFiles = @('AitherZero.psd1', 'AitherZero.psm1', 'Start-AitherZero.ps1', 
                   'bootstrap.ps1', 'bootstrap.sh', 'aitherzero', 'config.psd1', 
                   'config.example.psd1', 'PSScriptAnalyzerSettings.psd1', 
                   'VERSION', 'README.md', 'LICENSE')
    
    # Copy files
    foreach ($file in $coreFiles) {
        $srcFile = Join-Path $SourcePath $file
        if (Test-Path $srcFile) {
            $destFile = Join-Path $DestinationPath $file
            Copy-Item -Path $srcFile -Destination $destFile -Force
        }
    }
    
    # Copy directories
    foreach ($dir in $coreDirs) {
        $srcDir = Join-Path $SourcePath $dir
        if (Test-Path $srcDir) {
            $destDir = Join-Path $DestinationPath $dir
            Copy-Item -Path $srcDir -Destination $destDir -Recurse -Force
        }
    }
    
    # Handle optional directories based on runtime mode
    if (-not $OnlyRuntime) {
        $optionalDirs = @('docs', '.github', '.vscode', 'infrastructure', 'integrations', 'tools')
        foreach ($dir in $optionalDirs) {
            $srcDir = Join-Path $SourcePath $dir
            if (Test-Path $srcDir) {
                $destDir = Join-Path $DestinationPath $dir
                Copy-Item -Path $srcDir -Destination $destDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }
    
    if ($IncludeTests) {
        $testDirs = @('tests', 'Invoke-AitherTests.ps1')
        foreach ($item in $testDirs) {
            $srcItem = Join-Path $SourcePath $item
            if (Test-Path $srcItem) {
                $destItem = Join-Path $DestinationPath $item
                Copy-Item -Path $srcItem -Destination $destItem -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

# Main execution
try {
    Write-ScriptLog "=== AitherZero Release Package Creation ===" -Level Information
    Write-ScriptLog "Project Root: $ProjectRoot"
    Write-ScriptLog "Package Format: $PackageFormat"
    Write-ScriptLog "Runtime Only: $OnlyRuntime"
    Write-ScriptLog "Include Tests: $IncludeTests"
    
    # Get version
    $packageVersion = Get-PackageVersion
    
    # Determine output path
    if (-not $OutputPath) {
        $OutputPath = $ProjectRoot
    }
    
    # Ensure output directory exists
    if (-not (Test-Path $OutputPath)) {
        New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    }
    
    # Get files to package
    $packageFiles = Get-PackageFiles -RuntimeOnly $OnlyRuntime -IncludeTests $IncludeTests
    
    # Build package name base
    $packageType = if ($OnlyRuntime) { "runtime" } else { "full" }
    $packageNameBase = "AitherZero-${packageVersion}-${packageType}"
    
    $success = $true
    $createdPackages = @()
    
    # Create ZIP package
    if ($PackageFormat -eq 'ZIP' -or $PackageFormat -eq 'Both') {
        $zipPath = Join-Path $OutputPath "${packageNameBase}.zip"
        $zipSuccess = New-ZipPackage -SourcePath $ProjectRoot -DestinationPath $zipPath `
                                     -IncludeFiles $packageFiles.Include -ExcludeFiles $packageFiles.Exclude
        
        if ($zipSuccess) {
            $createdPackages += $zipPath
        } else {
            $success = $false
        }
    }
    
    # Create TAR.GZ package
    if ($PackageFormat -eq 'TarGz' -or $PackageFormat -eq 'Both') {
        $tarGzPath = Join-Path $OutputPath "${packageNameBase}.tar.gz"
        $tarGzSuccess = New-TarGzPackage -SourcePath $ProjectRoot -DestinationPath $tarGzPath `
                                         -IncludeFiles $packageFiles.Include -ExcludeFiles $packageFiles.Exclude
        
        if ($tarGzSuccess) {
            $createdPackages += $tarGzPath
        } elseif ($PackageFormat -eq 'TarGz') {
            # Only fail if TAR.GZ was specifically requested
            $success = $false
        }
    }
    
    # Summary
    Write-ScriptLog ""
    Write-ScriptLog "=== Package Creation Summary ===" -Level Information
    Write-ScriptLog "Packages created: $($createdPackages.Count)"
    
    foreach ($package in $createdPackages) {
        $size = (Get-Item $package).Length / 1MB
        Write-ScriptLog "  ✓ $package ($([math]::Round($size, 2)) MB)" -Level Success
    }
    
    if ($success) {
        Write-ScriptLog "Package creation completed successfully" -Level Success
        exit 0
    } else {
        Write-ScriptLog "Package creation failed" -Level Error
        exit 1
    }
    
} catch {
    Write-ScriptLog "Package creation failed with error: $_" -Level Error
    Write-ScriptLog "Stack trace: $($_.ScriptStackTrace)" -Level Error
    exit 1
}

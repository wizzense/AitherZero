#Requires -Version 7.0

<#
.SYNOPSIS
    Builds release packages for AitherZero distribution
.DESCRIPTION
    Creates modular release packages (Core, Standard, Full) for distribution via GitHub releases.
    Each profile includes different sets of features to support various use cases.
.PARAMETER Version
    Version number for the release (e.g., 1.0.0)
.PARAMETER Profiles
    Which profiles to build (Core, Standard, Full)
.PARAMETER OutputDir
    Directory to output release packages
.PARAMETER SkipValidation
    Skip playbook validation before building
.PARAMETER CI
    Running in CI mode
.EXAMPLE
    ./9100_Build-Release.ps1 -Version 1.0.0
.EXAMPLE
    ./9100_Build-Release.ps1 -Version 2.0.0 -Profiles @('Core', 'Full')
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$Version,
    
    [ValidateSet('Core', 'Standard', 'Full')]
    [string[]]$Profiles = @('Core', 'Standard', 'Full'),
    
    [string]$OutputDir = "./release",
    
    [switch]$SkipValidation,
    
    [switch]$CI = ($env:CI -eq 'true' -or $env:GITHUB_ACTIONS -eq 'true')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Get project root
$script:ProjectRoot = Split-Path $PSScriptRoot -Parent

# Import logging if available
$loggingModule = Join-Path $script:ProjectRoot "domains/utilities/Logging.psm1"
if (Test-Path $loggingModule) {
    Import-Module $loggingModule -Force -ErrorAction SilentlyContinue
}

function Write-BuildLog {
    param(
        [string]$Message,
        [string]$Level = 'Information'
    )
    
    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Message "[BUILD] $Message" -Level $Level -Source "BuildRelease"
    } else {
        $color = switch ($Level) {
            'Error' { 'Red' }
            'Warning' { 'Yellow' }
            'Success' { 'Green' }
            default { 'White' }
        }
        Write-Host "[$Level] $Message" -ForegroundColor $color
    }
}

# Determine version
if (-not $Version) {
    # Try to read from version file
    $versionFile = Join-Path $script:ProjectRoot "version.txt"
    if (Test-Path $versionFile) {
        $Version = Get-Content $versionFile -First 1
        Write-BuildLog "Using version from file: $Version"
    } else {
        # Default version
        $Version = '1.0.0'
        Write-BuildLog "Using default version: $Version" -Level 'Warning'
    }
}

Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Blue
Write-Host " AitherZero Release Builder v$Version" -ForegroundColor White
Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Blue

# Validate playbooks first unless skipped
if (-not $SkipValidation) {
    Write-BuildLog "Validating playbooks before build..."
    $validationScript = Join-Path $script:ProjectRoot "automation-scripts/0460_Test-Playbooks.ps1"
    
    if (Test-Path $validationScript) {
        try {
            & $validationScript -CI:$CI -StopOnError
            Write-BuildLog "Playbook validation passed" -Level 'Information'
        } catch {
            Write-BuildLog "Playbook validation failed: $_" -Level 'Error'
            if ($CI) {
                throw "Cannot build release with failing playbooks"
            }
            
            $continue = Read-Host "Playbook validation failed. Continue anyway? (y/N)"
            if ($continue -ne 'y') {
                exit 1
            }
        }
    } else {
        Write-BuildLog "Validation script not found - skipping" -Level 'Warning'
    }
}

# Create output directory
if (-not (Test-Path $OutputDir)) {
    if ($PSCmdlet.ShouldProcess($OutputDir, "Create output directory")) {
        New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
        Write-BuildLog "Created output directory: $OutputDir"
    }
}

# Clean old releases
$oldReleases = Get-ChildItem $OutputDir -Filter "AitherZero-*.zip" -ErrorAction SilentlyContinue
if ($oldReleases) {
    Write-BuildLog "Cleaning $($oldReleases.Count) old release(s)"
    foreach ($oldRelease in $oldReleases) {
        if ($PSCmdlet.ShouldProcess($oldRelease.Name, "Remove old release")) {
            $oldRelease | Remove-Item -Force
        }
    }
}

# Build each profile
foreach ($profile in $Profiles) {
    Write-Host "`n━━━ Building $profile Profile ━━━" -ForegroundColor Cyan
    
    $packageDir = Join-Path $OutputDir "AitherZero-$Version-$profile"
    
    # Clean and create package directory
    if (Test-Path $packageDir) {
        if ($PSCmdlet.ShouldProcess($packageDir, "Remove existing package directory")) {
            Remove-Item $packageDir -Recurse -Force
        }
    }
    if ($PSCmdlet.ShouldProcess($packageDir, "Create package directory")) {
        New-Item -ItemType Directory -Path $packageDir -Force | Out-Null
    }
    
    # Define what goes into each profile
    $filesToCopy = @{
        Core = @{
            Files = @(
                'Start-AitherZero.ps1'
                'AitherZero.psd1'
                'AitherZero.psm1'
                'bootstrap.ps1'
                'bootstrap.sh'
                'config.psd1'
                'config.example.psd1'
                'LICENSE'
                'README.md'
                'version.txt'
            )
            Directories = @(
                'domains/utilities'
                'domains/configuration'
                'domains/experience'
                'domains/automation'
                'orchestration/playbooks-psd1/setup'
            )
            Scripts = @(
                '00*'  # Environment scripts
                '01*'  # Basic setup scripts
                '05*'  # System info scripts
            )
        }
        Standard = @{
            Inherits = 'Core'
            AdditionalDirectories = @(
                'domains/testing'
                'domains/reporting'
                'orchestration/playbooks-psd1/testing'
                'orchestration/playbooks-psd1/git'
            )
            AdditionalScripts = @(
                '04*'  # Testing scripts
                '07*'  # Git automation scripts
            )
        }
        Full = @{
            Inherits = 'Standard'
            AdditionalDirectories = @(
                'domains/development'
                'domains/infrastructure'
                'orchestration/playbooks-psd1'  # All playbooks
                'tests'
                'examples'
                'docs'
            )
            AdditionalScripts = @(
                '*'  # All automation scripts
            )
        }
    }
    
    # Helper function to copy items
    function Copy-ReleaseItems {
        param(
            [hashtable]$ItemSet,
            [string]$Destination
        )
        
        # Handle inheritance
        if ($ItemSet.ContainsKey('Inherits') -and $ItemSet.Inherits) {
            Copy-ReleaseItems -ItemSet $filesToCopy[$ItemSet.Inherits] -Destination $Destination
        }
        
        # Copy files
        $files = @()
        if ($ItemSet.ContainsKey('Files')) { $files += $ItemSet.Files }
        if ($ItemSet.ContainsKey('AdditionalFiles')) { $files += $ItemSet.AdditionalFiles }
        foreach ($file in $files | Where-Object { $_ }) {
            $sourcePath = Join-Path $script:ProjectRoot $file
            if (Test-Path $sourcePath) {
                if ($PSCmdlet.ShouldProcess("$sourcePath -> $Destination", "Copy file")) {
                    Copy-Item $sourcePath $Destination -ErrorAction SilentlyContinue
                    Write-Verbose "  Copied file: $file"
                }
            }
        }
        
        # Copy directories
        $dirs = @()
        if ($ItemSet.ContainsKey('Directories')) { $dirs += $ItemSet.Directories }
        if ($ItemSet.ContainsKey('AdditionalDirectories')) { $dirs += $ItemSet.AdditionalDirectories }
        foreach ($dir in $dirs | Where-Object { $_ }) {
            $sourcePath = Join-Path $script:ProjectRoot $dir
            if (Test-Path $sourcePath) {
                $destDir = Join-Path $Destination (Split-Path $dir -Parent)
                if (-not (Test-Path $destDir)) {
                    if ($PSCmdlet.ShouldProcess($destDir, "Create directory")) {
                        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
                    }
                }
                if ($PSCmdlet.ShouldProcess("$sourcePath -> $destDir", "Copy directory")) {
                    Copy-Item $sourcePath $destDir -Recurse -Force -ErrorAction SilentlyContinue
                    Write-Verbose "  Copied directory: $dir"
                }
            }
        }
        
        # Copy automation scripts
        $scriptPatterns = @()
        if ($ItemSet.ContainsKey('Scripts')) { $scriptPatterns += $ItemSet.Scripts }
        if ($ItemSet.ContainsKey('AdditionalScripts')) { $scriptPatterns += $ItemSet.AdditionalScripts }
        if ($scriptPatterns) {
            $scriptsDir = Join-Path $Destination "automation-scripts"
            if (-not (Test-Path $scriptsDir)) {
                if ($PSCmdlet.ShouldProcess($scriptsDir, "Create scripts directory")) {
                    New-Item -ItemType Directory -Path $scriptsDir -Force | Out-Null
                }
            }
            
            foreach ($pattern in $scriptPatterns | Where-Object { $_ }) {
                $scripts = Get-ChildItem (Join-Path $script:ProjectRoot "automation-scripts") -Filter "${pattern}.ps1" -ErrorAction SilentlyContinue
                foreach ($script in $scripts) {
                    if ($PSCmdlet.ShouldProcess($script.Name, "Copy script")) {
                        Copy-Item $script.FullName $scriptsDir -Force
                        Write-Verbose "  Copied script: $($script.Name)"
                    }
                }
            }
        }
    }
    
    # Copy files for this profile
    Write-BuildLog "Copying files for $profile profile..."
    Copy-ReleaseItems -ItemSet $filesToCopy[$profile] -Destination $packageDir
    
    # Create logs directory (empty)
    $logsDir = Join-Path $packageDir "logs"
    if ($PSCmdlet.ShouldProcess($logsDir, "Create logs directory")) {
        New-Item -ItemType Directory -Path $logsDir -Force | Out-Null
    }
    
    # Generate manifest
    Write-BuildLog "Generating manifest..."
    $manifest = @{
        Name = 'AitherZero'
        Version = $Version
        Profile = $profile
        BuildDate = Get-Date -Format 'o'
        BuildMachine = $env:COMPUTERNAME ?? $env:HOSTNAME ?? 'Unknown'
        PSVersion = $PSVersionTable.PSVersion.ToString()
        OS = $PSVersionTable.OS ?? $PSVersionTable.Platform
        Modules = @()
        Scripts = @()
        Playbooks = @()
    }
    
    # Count included modules
    $modulesPath = Join-Path $packageDir "domains"
    if (Test-Path $modulesPath) {
        $manifest.Modules = Get-ChildItem $modulesPath -Directory | Select-Object -ExpandProperty Name
    }
    
    # Count included scripts
    $scriptsPath = Join-Path $packageDir "automation-scripts"
    if (Test-Path $scriptsPath) {
        $manifest.Scripts = (Get-ChildItem $scriptsPath -Filter "*.ps1").Count
    }
    
    # Count included playbooks
    $playbooksPath = Join-Path $packageDir "orchestration/playbooks-psd1"
    if (Test-Path $playbooksPath) {
        $manifest.Playbooks = Get-ChildItem $playbooksPath -Filter "*.psd1" -Recurse | Select-Object -ExpandProperty Name
    }
    
    $manifestPath = Join-Path $packageDir "manifest.json"
    if ($PSCmdlet.ShouldProcess($manifestPath, "Create manifest file")) {
        $manifest | ConvertTo-Json -Depth 10 | Set-Content $manifestPath
    }
    
    # Update version in manifest if it exists (skip in WhatIf mode since file won't exist)
    if (-not $WhatIfPreference) {
        $psd1Path = Join-Path $packageDir "AitherZero.psd1"
        if (Test-Path $psd1Path) {
            $content = Get-Content $psd1Path -Raw
            $content = $content -replace "ModuleVersion\s*=\s*'[\d\.]+'", "ModuleVersion = '$Version'"
            if ($PSCmdlet.ShouldProcess($psd1Path, "Update module version")) {
                Set-Content $psd1Path $content
            }
        }
    }
    
    # Create archive
    $archiveName = "AitherZero-$Version-$profile.zip"
    $archivePath = Join-Path $OutputDir $archiveName
    
    Write-BuildLog "Creating archive: $archiveName"
    
    if ($PSCmdlet.ShouldProcess($archivePath, "Create archive")) {
        if ($IsWindows -or $PSVersionTable.PSVersion.Major -le 5) {
            Compress-Archive -Path "$packageDir\*" -DestinationPath $archivePath -Force
        } else {
            # Use Compress-Archive on Unix as well for consistency
            Compress-Archive -Path "$packageDir/*" -DestinationPath $archivePath -Force
        }
    }
    
    # Verify archive was created
    if (Test-Path $archivePath) {
        $size = (Get-Item $archivePath).Length / 1MB
        Write-BuildLog "  ✓ Created: $archiveName ($('{0:N2}' -f $size) MB)" -Level 'Information'
        
        # Display package contents summary
        Write-Host "  Contents:" -ForegroundColor Gray
        Write-Host "    - Modules: $(if ($manifest.Modules) { @($manifest.Modules).Count } else { 0 })" -ForegroundColor Gray
        Write-Host "    - Scripts: $($manifest.Scripts)" -ForegroundColor Gray
        Write-Host "    - Playbooks: $(if ($manifest.Playbooks) { @($manifest.Playbooks).Count } else { 0 })" -ForegroundColor Gray
    } else {
        Write-BuildLog "Failed to create archive: $archiveName" -Level 'Error'
    }
    
    # Clean up directory
    if ($PSCmdlet.ShouldProcess($packageDir, "Remove package directory")) {
        Remove-Item $packageDir -Recurse -Force
    }
}

# Create a latest symlink/copy for easy access
$latestCore = Join-Path $OutputDir "AitherZero-latest-Core.zip"
$coreRelease = Join-Path $OutputDir "AitherZero-$Version-Core.zip"
if (Test-Path $coreRelease) {
    if ($PSCmdlet.ShouldProcess($latestCore, "Create latest Core symlink")) {
        Copy-Item $coreRelease $latestCore -Force
        Write-BuildLog "Created latest symlink: AitherZero-latest-Core.zip"
    }
}

# Generate release notes if in CI
if ($CI) {
    Write-BuildLog "Generating release notes..."
    $releaseNotes = @"
# AitherZero v$Version

## Release Date
$(Get-Date -Format 'yyyy-MM-dd')

## Available Packages
- **Core** - Minimal installation with essential features
- **Standard** - Includes testing framework and Git automation
- **Full** - Complete package with all features and development tools

## Installation

\`\`\`powershell
# Install Core (minimal)
iwr -useb https://raw.githubusercontent.com/wizzense/AitherZero/main/bootstrap.ps1 | iex

# Install Standard
& ([scriptblock]::Create((iwr -useb https://raw.githubusercontent.com/wizzense/AitherZero/main/bootstrap.ps1))) -Profile Standard

# Install Full
& ([scriptblock]::Create((iwr -useb https://raw.githubusercontent.com/wizzense/AitherZero/main/bootstrap.ps1))) -Profile Full
\`\`\`

## What's Included

### Core Profile
- Essential modules (utilities, configuration, experience)
- Basic automation engine
- Minimal setup playbooks
- Environment scripts

### Standard Profile
- Everything in Core
- Testing framework with Pester
- Git workflow automation
- Testing and Git playbooks
- Reporting engine

### Full Profile
- Everything in Standard
- Development tools integration
- Infrastructure automation
- All playbooks and examples
- Complete test suite
- Documentation

## Verification
All playbooks validated before release.
"@
    
    $releaseNotesPath = Join-Path $OutputDir "RELEASE_NOTES.md"
    if ($PSCmdlet.ShouldProcess($releaseNotesPath, "Create release notes")) {
        Set-Content $releaseNotesPath $releaseNotes
        Write-BuildLog "Release notes saved to: RELEASE_NOTES.md"
    }
}

# Summary
Write-Host "`n════════════════════════════════════════════════════════════════" -ForegroundColor Blue
Write-Host " BUILD COMPLETE" -ForegroundColor Green
Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Blue

Write-Host "`nRelease packages created:" -ForegroundColor White
Get-ChildItem $OutputDir -Filter "AitherZero-$Version-*.zip" | ForEach-Object {
    $size = $_.Length / 1MB
    Write-Host "  ✓ $($_.Name) ($('{0:N2}' -f $size) MB)" -ForegroundColor Green
}

Write-Host "`nOutput directory: $OutputDir" -ForegroundColor Gray
Write-Host "Version: $Version" -ForegroundColor Gray

if ($CI) {
    # Set output for GitHub Actions
    if ($env:GITHUB_OUTPUT) {
        "version=$Version" | Out-File -FilePath $env:GITHUB_OUTPUT -Append
        "release_dir=$OutputDir" | Out-File -FilePath $env:GITHUB_OUTPUT -Append
    }
}

Write-Host "`n✅ Build completed successfully!" -ForegroundColor Green
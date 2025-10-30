#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Generates WinGet manifest files for AitherZero releases.

.DESCRIPTION
    This script generates WinGet (Windows Package Manager) manifest files for AitherZero.
    It downloads the release ZIP, calculates the SHA256 hash, and generates the required
    manifest files from templates.

.PARAMETER Version
    The version to generate manifests for (e.g., "1.2.0" without 'v' prefix).

.PARAMETER OutputPath
    Directory to output the generated manifests. Defaults to "./winget-output".

.PARAMETER DryRun
    If specified, shows what would be done without actually generating files.

.PARAMETER SkipDownload
    If specified, skips downloading the release file and expects it to exist locally.

.EXAMPLE
    ./0797_generate-winget-manifests.ps1 -Version "1.2.0"
    Generates WinGet manifests for version 1.2.0

.EXAMPLE
    ./0797_generate-winget-manifests.ps1 -Version "1.2.0" -DryRun
    Shows what would be generated without creating files

.NOTES
    Script Number: 0797
    Category: Git Automation & Publishing
    Requires: PowerShell 7.0+
    Author: AitherZero Team
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^\d+\.\d+\.\d+$')]
    [string]$Version,

    [Parameter()]
    [string]$OutputPath = "./winget-output",

    [Parameter()]
    [switch]$DryRun,

    [Parameter()]
    [switch]$SkipDownload
)

#Requires -Version 7.0

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Constants
$REPO_OWNER = "wizzense"
$REPO_NAME = "AitherZero"
$PACKAGE_IDENTIFIER = "Wizzense.AitherZero"
$TEMPLATE_DIR = "./winget-manifests"

# ============================================================================
# Helper Functions
# ============================================================================

function Write-ScriptLog {
    param(
        [string]$Message,
        [ValidateSet('Info', 'Success', 'Warning', 'Error')]
        [string]$Level = 'Info'
    )

    $colors = @{
        'Info'    = 'Cyan'
        'Success' = 'Green'
        'Warning' = 'Yellow'
        'Error'   = 'Red'
    }

    $prefix = @{
        'Info'    = 'ℹ️'
        'Success' = '✅'
        'Warning' = '⚠️'
        'Error'   = '❌'
    }

    Write-Host "$($prefix[$Level]) $Message" -ForegroundColor $colors[$Level]
}

function Get-ReleaseInfo {
    param([string]$Version)

    Write-ScriptLog "Fetching release information for v$Version..." -Level Info

    try {
        $releaseUrl = "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/releases/tags/v$Version"
        $release = Invoke-RestMethod -Uri $releaseUrl -ErrorAction Stop

        return @{
            Version     = $Version
            TagName     = $release.tag_name
            ReleaseDate = ([DateTime]$release.published_at).ToString('yyyy-MM-dd')
            Assets      = $release.assets
            IsPrerelease = $release.prerelease
        }
    }
    catch {
        Write-ScriptLog "Failed to fetch release information: $_" -Level Error
        throw
    }
}

function Get-ReleaseAsset {
    param(
        [object]$ReleaseInfo,
        [string]$OutputPath
    )

    # Look for the ZIP file
    $zipAsset = $ReleaseInfo.Assets | Where-Object { $_.name -like "AitherZero-v$($ReleaseInfo.Version).zip" }

    if (-not $zipAsset) {
        Write-ScriptLog "ZIP file not found in release assets!" -Level Error
        Write-ScriptLog "Available assets:" -Level Info
        $ReleaseInfo.Assets | ForEach-Object { Write-Host "  - $($_.name)" }
        throw "Required ZIP asset not found"
    }

    $downloadUrl = $zipAsset.browser_download_url
    $fileName = $zipAsset.name
    $filePath = Join-Path $OutputPath $fileName

    Write-ScriptLog "Downloading: $fileName" -Level Info
    Write-ScriptLog "URL: $downloadUrl" -Level Info

    if ($PSCmdlet.ShouldProcess($downloadUrl, "Download release asset")) {
        try {
            # Ensure output directory exists
            $dir = Split-Path $filePath -Parent
            if (-not (Test-Path $dir)) {
                New-Item -ItemType Directory -Path $dir -Force | Out-Null
            }

            # Download with progress
            $ProgressPreference = 'SilentlyContinue'
            Invoke-WebRequest -Uri $downloadUrl -OutFile $filePath -ErrorAction Stop
            $ProgressPreference = 'Continue'

            Write-ScriptLog "Downloaded: $filePath" -Level Success

            return $filePath
        }
        catch {
            Write-ScriptLog "Download failed: $_" -Level Error
            throw
        }
    }
    else {
        Write-ScriptLog "Would download: $downloadUrl" -Level Info
        return $null
    }
}

function Get-FileHashSHA256 {
    param([string]$FilePath)

    Write-ScriptLog "Calculating SHA256 hash..." -Level Info

    try {
        $hash = Get-FileHash -Path $FilePath -Algorithm SHA256
        Write-ScriptLog "SHA256: $($hash.Hash)" -Level Success
        return $hash.Hash
    }
    catch {
        Write-ScriptLog "Failed to calculate hash: $_" -Level Error
        throw
    }
}

function New-ManifestFromTemplate {
    param(
        [string]$TemplatePath,
        [string]$OutputPath,
        [hashtable]$Replacements
    )

    Write-ScriptLog "Generating manifest: $(Split-Path $OutputPath -Leaf)" -Level Info

    if (-not (Test-Path $TemplatePath)) {
        Write-ScriptLog "Template not found: $TemplatePath" -Level Error
        throw "Template file not found"
    }

    if ($PSCmdlet.ShouldProcess($OutputPath, "Generate manifest")) {
        try {
            $content = Get-Content $TemplatePath -Raw

            # Replace all placeholders
            foreach ($key in $Replacements.Keys) {
                $content = $content -replace [regex]::Escape("{$key}"), $Replacements[$key]
            }

            # Ensure output directory exists
            $dir = Split-Path $OutputPath -Parent
            if (-not (Test-Path $dir)) {
                New-Item -ItemType Directory -Path $dir -Force | Out-Null
            }

            # Write manifest
            $content | Set-Content -Path $OutputPath -NoNewline -Encoding UTF8

            Write-ScriptLog "Created: $OutputPath" -Level Success
        }
        catch {
            Write-ScriptLog "Failed to generate manifest: $_" -Level Error
            throw
        }
    }
    else {
        Write-ScriptLog "Would create: $OutputPath" -Level Info
    }
}

function Test-ManifestValidity {
    param([string]$ManifestDir)

    Write-ScriptLog "Validating manifests..." -Level Info

    # Check if winget is available
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-ScriptLog "WinGet not found - skipping validation" -Level Warning
        Write-ScriptLog "Install WinGet to enable manifest validation" -Level Info
        return $false
    }

    try {
        $result = winget validate --manifest $ManifestDir 2>&1

        if ($LASTEXITCODE -eq 0) {
            Write-ScriptLog "Manifest validation passed!" -Level Success
            return $true
        }
        else {
            Write-ScriptLog "Manifest validation failed!" -Level Error
            Write-Host $result
            return $false
        }
    }
    catch {
        Write-ScriptLog "Failed to validate manifests: $_" -Level Warning
        return $false
    }
}

# ============================================================================
# Main Script
# ============================================================================

function Invoke-Main {
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Magenta
    Write-Host "  WinGet Manifest Generator for AitherZero" -ForegroundColor Magenta
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Magenta
    Write-Host ""

    # Validate inputs
    if ($DryRun) {
        Write-ScriptLog "DRY RUN MODE - No files will be created" -Level Warning
    }

    # Get release information
    $releaseInfo = Get-ReleaseInfo -Version $Version

    if ($releaseInfo.IsPrerelease) {
        Write-ScriptLog "This is a pre-release version" -Level Warning
        Write-ScriptLog "Pre-releases should not be published to WinGet" -Level Warning

        $response = Read-Host "Continue anyway? (yes/no)"
        if ($response -ne "yes") {
            Write-ScriptLog "Aborted by user" -Level Info
            return
        }
    }

    Write-ScriptLog "Release Date: $($releaseInfo.ReleaseDate)" -Level Info
    Write-Host ""

    # Download or locate release asset
    $zipPath = $null

    if ($SkipDownload) {
        $expectedPath = Join-Path $OutputPath "AitherZero-v$Version.zip"
        if (Test-Path $expectedPath) {
            $zipPath = $expectedPath
            Write-ScriptLog "Using existing file: $zipPath" -Level Info
        }
        else {
            Write-ScriptLog "File not found: $expectedPath" -Level Error
            throw "Expected ZIP file not found"
        }
    }
    else {
        $zipPath = Get-ReleaseAsset -ReleaseInfo $releaseInfo -OutputPath $OutputPath
    }

    # Calculate hash
    $sha256Hash = $null
    if ($zipPath -and (Test-Path $zipPath)) {
        $sha256Hash = Get-FileHashSHA256 -FilePath $zipPath
    }
    elseif (-not $DryRun) {
        Write-ScriptLog "Cannot calculate hash - file not available" -Level Error
        throw "Hash calculation failed"
    }
    else {
        $sha256Hash = "HASH_PLACEHOLDER_FOR_DRY_RUN"
    }

    Write-Host ""

    # Prepare replacements
    $replacements = @{
        'VERSION'      = $Version
        'RELEASE_DATE' = $releaseInfo.ReleaseDate
        'SHA256_HASH'  = $sha256Hash
    }

    # Generate manifests
    $manifestDir = Join-Path $OutputPath $Version

    $manifests = @(
        @{
            Template = "$TEMPLATE_DIR/Wizzense.AitherZero.yaml.template"
            Output   = "$manifestDir/Wizzense.AitherZero.yaml"
        },
        @{
            Template = "$TEMPLATE_DIR/Wizzense.AitherZero.installer.yaml.template"
            Output   = "$manifestDir/Wizzense.AitherZero.installer.yaml"
        },
        @{
            Template = "$TEMPLATE_DIR/Wizzense.AitherZero.locale.en-US.yaml.template"
            Output   = "$manifestDir/Wizzense.AitherZero.locale.en-US.yaml"
        }
    )

    foreach ($manifest in $manifests) {
        New-ManifestFromTemplate `
            -TemplatePath $manifest.Template `
            -OutputPath $manifest.Output `
            -Replacements $replacements
    }

    Write-Host ""

    # Validate manifests
    if (-not $DryRun) {
        $isValid = Test-ManifestValidity -ManifestDir $manifestDir
    }

    # Summary
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Magenta
    Write-ScriptLog "Manifest generation complete!" -Level Success
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Magenta
    Write-Host ""

    Write-Host "📋 Generated manifests:" -ForegroundColor Cyan
    Write-Host "  • Wizzense.AitherZero.yaml" -ForegroundColor White
    Write-Host "  • Wizzense.AitherZero.installer.yaml" -ForegroundColor White
    Write-Host "  • Wizzense.AitherZero.locale.en-US.yaml" -ForegroundColor White
    Write-Host ""
    Write-Host "📂 Output directory: $manifestDir" -ForegroundColor Cyan
    Write-Host ""

    if (-not $DryRun) {
        Write-Host "📤 Next steps:" -ForegroundColor Yellow
        Write-Host "  1. Review the generated manifests" -ForegroundColor White
        Write-Host "  2. Fork microsoft/winget-pkgs if you haven't already" -ForegroundColor White
        Write-Host "  3. Copy manifests to: manifests/w/Wizzense/AitherZero/$Version/" -ForegroundColor White
        Write-Host "  4. Create a PR to microsoft/winget-pkgs" -ForegroundColor White
        Write-Host ""
        Write-Host "📝 Example commands:" -ForegroundColor Yellow
        Write-Host "  cd winget-pkgs" -ForegroundColor Gray
        Write-Host "  git checkout -b aitherzero-$Version" -ForegroundColor Gray
        Write-Host "  mkdir -p manifests/w/Wizzense/AitherZero/$Version" -ForegroundColor Gray
        Write-Host "  cp $manifestDir/*.yaml manifests/w/Wizzense/AitherZero/$Version/" -ForegroundColor Gray
        Write-Host "  git add manifests/w/Wizzense/AitherZero/" -ForegroundColor Gray
        Write-Host "  git commit -m 'New version: Wizzense.AitherZero version $Version'" -ForegroundColor Gray
        Write-Host "  git push origin aitherzero-$Version" -ForegroundColor Gray
        Write-Host "  gh pr create --repo microsoft/winget-pkgs" -ForegroundColor Gray
        Write-Host ""
    }

    Write-Host "📖 Documentation: docs/PUBLISHING-GUIDE.md" -ForegroundColor Cyan
    Write-Host ""
}

# Execute main function
try {
    Invoke-Main
    exit 0
}
catch {
    Write-ScriptLog "Script failed: $_" -Level Error
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    exit 1
}

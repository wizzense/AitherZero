#!/usr/bin/env pwsh
#Requires -Version 7.0
<#
.SYNOPSIS
    Runtime loader for obfuscated source code
    
.DESCRIPTION
    Transparently decrypts and loads obfuscated PowerShell modules at runtime
    when a valid license is present. Can be used as a wrapper for module imports.
    
    Stage: Runtime
    Dependencies: Encryption.psm1, LicenseManager.psm1
    Tags: Security, Obfuscation, Runtime
    
.PARAMETER EncryptedPath
    Path to encrypted module file (.encrypted)
    
.PARAMETER Force
    Force reload even if module already loaded
    
.PARAMETER PassThru
    Return the decrypted module path
    
.EXAMPLE
    ./0802_Load-ObfuscatedModule.ps1 -EncryptedPath "./MyModule.psm1.encrypted"
    
.EXAMPLE
    $modulePath = ./0802_Load-ObfuscatedModule.ps1 -EncryptedPath "./Module.psm1.encrypted" -PassThru
    Import-Module $modulePath
    
.NOTES
    This script caches decrypted modules in memory and cleans them up on exit.
    Decrypted files are never written to disk permanently.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string]$EncryptedPath,
    
    [switch]$Force,
    
    [switch]$PassThru
)

# Script metadata
$script:ScriptName = "Load-ObfuscatedModule"
$script:ScriptVersion = "1.0.0"

# Import required modules
$projectRoot = if ($env:AITHERZERO_ROOT) { 
    $env:AITHERZERO_ROOT 
} else { 
    Split-Path (Split-Path $PSScriptRoot -Parent) -Parent 
}

$securityPath = Join-Path $projectRoot "domains/security"

try {
    Import-Module (Join-Path $securityPath "Encryption.psm1") -Force -ErrorAction Stop
    Import-Module (Join-Path $securityPath "LicenseManager.psm1") -Force -ErrorAction Stop
} catch {
    Write-Error "Failed to load required modules: $_"
    exit 1
}

# Helper function for output
function Write-LoaderLog {
    param(
        [string]$Message,
        [string]$Level = 'Info'
    )
    
    $color = switch ($Level) {
        'Success' { 'Green' }
        'Warning' { 'Yellow' }
        'Error' { 'Red' }
        default { 'White' }
    }
    
    $prefix = switch ($Level) {
        'Success' { '✓' }
        'Warning' { '⚠' }
        'Error' { '✗' }
        default { 'ℹ' }
    }
    
    Write-Verbose "$prefix $Message"
    if ($Level -in @('Error', 'Warning')) {
        Write-Host "$prefix $Message" -ForegroundColor $color
    }
}

try {
    Write-LoaderLog "Loading obfuscated module: $EncryptedPath" -Level 'Info'
    
    # Find license
    $licensePath = Find-License
    if (-not $licensePath) {
        throw "No valid license found. Cannot load obfuscated module."
    }
    
    # Validate license
    $validation = Test-License -LicensePath $licensePath
    if (-not $validation.IsValid) {
        throw "License invalid: $($validation.Reason)"
    }
    
    Write-LoaderLog "Valid license: $($validation.License.LicenseId)" -Level 'Success'
    
    # Check if SourceCodeObfuscation feature is licensed
    if ($validation.License.Features -notcontains "SourceCodeObfuscation") {
        throw "License does not include SourceCodeObfuscation feature"
    }
    
    # Get encryption key from license
    $key = Get-LicenseKey -LicensePath $licensePath
    
    # Create temp directory for decrypted modules
    $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "aitherzero-obfuscated-$(New-Guid)"
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    
    # Register cleanup on exit
    $null = Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action {
        if (Test-Path $using:tempDir) {
            Remove-Item -Path $using:tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    
    # Get metadata path
    $metadataPath = "$EncryptedPath.meta"
    if (-not (Test-Path $metadataPath)) {
        throw "Metadata file not found: $metadataPath"
    }
    
    # Read metadata to get original filename
    $metadata = Get-Content -Path $metadataPath -Raw | ConvertFrom-Json
    $originalName = $metadata.OriginalFile
    
    # Decrypt to temp location
    $decryptedPath = Join-Path $tempDir $originalName
    
    Write-LoaderLog "Decrypting module to temporary location..." -Level 'Info'
    $result = Unprotect-File -Path $EncryptedPath -Key $key -OutputPath $decryptedPath
    
    Write-LoaderLog "Module decrypted successfully" -Level 'Success'
    
    # Import the decrypted module
    if (-not $PassThru) {
        Write-LoaderLog "Importing module..." -Level 'Info'
        Import-Module $result -Force:$Force -ErrorAction Stop
        Write-LoaderLog "Module imported successfully" -Level 'Success'
    }
    
    if ($PassThru) {
        return $result
    }
    
    exit 0
} catch {
    Write-LoaderLog "Error: $($_.Exception.Message)" -Level 'Error'
    if ($env:AITHERZERO_DEBUG) {
        Write-Host ""
        Write-Host "Stack trace:"
        Write-Host $_.ScriptStackTrace
    }
    exit 1
}

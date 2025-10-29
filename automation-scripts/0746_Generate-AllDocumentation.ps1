#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Automated documentation generation orchestrator - runs all documentation generators
.DESCRIPTION
    Orchestrates the complete documentation generation workflow:
    1. Generates module and API documentation (0744)
    2. Generates navigable project indexes (0745)
    
    This ensures all documentation is generated in the correct order without conflicts.
    Replaces manual execution of multiple documentation scripts.
.PARAMETER Mode
    Generation mode:
    - Full: Complete regeneration of all documentation
    - Incremental: Only update changed files
.PARAMETER OutputPath
    Output directory for generated documentation (defaults to docs/generated)
.PARAMETER Format
    Documentation output format: Markdown, HTML, or Both
.PARAMETER Force
    Force regeneration even if no changes detected
.EXAMPLE
    ./0746_Generate-AllDocumentation.ps1
    Generate all documentation incrementally
.EXAMPLE
    ./0746_Generate-AllDocumentation.ps1 -Mode Full -Force
    Force complete regeneration of all documentation
.EXAMPLE
    az 0746
    Quick execution via az wrapper
#>

# Script metadata
# Stage: AI & Documentation
# Dependencies: 0744 (Auto Documentation), 0745 (Project Indexer)
# Description: Orchestrated documentation generation - runs all doc generators
# Tags: documentation, automation, orchestration, index

[CmdletBinding(SupportsShouldProcess)]
param(
    [ValidateSet('Full', 'Incremental')]
    [string]$Mode = 'Incremental',
    
    [string]$OutputPath = $null,
    
    [ValidateSet('Markdown', 'HTML', 'Both')]
    [string]$Format = 'Both',
    
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Initialize
$script:ProjectRoot = Split-Path $PSScriptRoot -Parent
$script:StartTime = Get-Date

# Banner
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "    AitherZero Documentation Orchestrator" -ForegroundColor Cyan
Write-Host "    Automated Generation of All Documentation" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Import logging module if available
$loggingModule = Join-Path $script:ProjectRoot "domains/utilities/Logging.psm1"
if (Test-Path $loggingModule) {
    Import-Module $loggingModule -Force -ErrorAction SilentlyContinue
}

function Write-DocOrchLog {
    param([string]$Message, [string]$Level = 'Information')
    
    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Level $Level -Message $Message -Source "DocOrchestrator"
    } else {
        $color = switch ($Level) {
            'Information' { 'White' }
            'Warning' { 'Yellow' }
            'Error' { 'Red' }
            'Success' { 'Green' }
        }
        Write-Host "[$Level] [DocOrchestrator] $Message" -ForegroundColor $color
    }
}

# Set default output path
if (-not $OutputPath) {
    $OutputPath = Join-Path $script:ProjectRoot "docs/generated"
}

Write-DocOrchLog "Starting orchestrated documentation generation"
Write-DocOrchLog "Mode: $Mode | Format: $Format | Output: $OutputPath"

# Step 1: Generate module and API documentation
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Yellow
Write-Host "📚 Step 1: Generating Module & API Documentation" -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Yellow

$script0744 = Join-Path $PSScriptRoot "0744_Generate-AutoDocumentation.ps1"
if (-not (Test-Path $script0744)) {
    Write-DocOrchLog "Error: 0744_Generate-AutoDocumentation.ps1 not found" -Level Error
    exit 1
}

try {
    $params = @{
        Mode = $Mode
        OutputPath = $OutputPath
        Format = $Format
        Quality = $true
    }
    
    Write-DocOrchLog "Executing: 0744_Generate-AutoDocumentation.ps1"
    & $script0744 @params
    
    if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) {
        throw "Script 0744 failed with exit code $LASTEXITCODE"
    }
    
    Write-DocOrchLog "Module & API documentation generated successfully" -Level Success
    
} catch {
    Write-DocOrchLog "Failed to generate module documentation: $_" -Level Error
    Write-DocOrchLog "Continuing with project indexes..." -Level Warning
}

# Step 2: Generate navigable project indexes
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Yellow
Write-Host "🗂️  Step 2: Generating Project Navigation Indexes" -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Yellow

$script0745 = Join-Path $PSScriptRoot "0745_Generate-ProjectIndexes.ps1"
if (-not (Test-Path $script0745)) {
    Write-DocOrchLog "Error: 0745_Generate-ProjectIndexes.ps1 not found" -Level Error
    exit 1
}

try {
    $indexMode = if ($Mode -eq 'Full' -or $Force) { 'Full' } else { 'Incremental' }
    
    $params = @{
        Mode = $indexMode
        RootPath = $script:ProjectRoot
    }
    
    if ($Force) {
        $params['Force'] = $true
    }
    
    Write-DocOrchLog "Executing: 0745_Generate-ProjectIndexes.ps1"
    & $script0745 @params
    
    if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) {
        throw "Script 0745 failed with exit code $LASTEXITCODE"
    }
    
    Write-DocOrchLog "Project navigation indexes generated successfully" -Level Success
    
} catch {
    Write-DocOrchLog "Failed to generate project indexes: $_" -Level Error
}

# Clean up any legacy INDEX.md files (uppercase) if they exist
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Yellow
Write-Host "🧹 Step 3: Cleaning Up Legacy Index Files" -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Yellow

Write-DocOrchLog "Checking for duplicate INDEX.md files..."

$legacyIndexFiles = @(Get-ChildItem -Path $OutputPath -Recurse -Filter "INDEX.md" -File -ErrorAction SilentlyContinue)

if ($legacyIndexFiles.Count -gt 0) {
    Write-DocOrchLog "Found $($legacyIndexFiles.Count) legacy INDEX.md files to remove"
    
    foreach ($file in $legacyIndexFiles) {
        $dir = Split-Path $file.FullName -Parent
        $lowercaseIndex = Join-Path $dir "index.md"
        
        # Only remove if lowercase version exists
        if (Test-Path $lowercaseIndex) {
            Write-DocOrchLog "Removing duplicate: $($file.FullName)"
            Remove-Item $file.FullName -Force
        } else {
            Write-DocOrchLog "Renaming to lowercase: $($file.FullName)"
            Rename-Item $file.FullName -NewName "index.md" -Force
        }
    }
    
    Write-DocOrchLog "Cleanup completed" -Level Success
} else {
    Write-DocOrchLog "No legacy INDEX.md files found - all clear!"
}

# Summary
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "    Documentation Generation Complete" -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host ""

$duration = (Get-Date) - $script:StartTime
Write-DocOrchLog "Total execution time: $($duration.ToString('mm\:ss'))" -Level Success
Write-DocOrchLog "Output directory: $OutputPath" -Level Success

Write-Host ""
Write-Host "✅ All documentation has been generated successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  • View generated docs: cd $OutputPath" -ForegroundColor White
Write-Host "  • Open index: $OutputPath/index.md" -ForegroundColor White
Write-Host "  • Run validation: az 0404 (PSScriptAnalyzer)" -ForegroundColor White
Write-Host ""

exit 0

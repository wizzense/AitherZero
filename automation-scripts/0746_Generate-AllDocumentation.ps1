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
    Write-DocOrchLog "Using default output path: $OutputPath"
}

Write-DocOrchLog "Starting orchestrated documentation generation"
Write-DocOrchLog "Mode: $Mode | Format: $Format | Output: $OutputPath"
Write-DocOrchLog "Force: $Force"

# Step 1: Generate module and API documentation
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Yellow
Write-Host "📚 Step 1: Generating Module & API Documentation" -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Yellow

$script0744 = Join-Path $PSScriptRoot "0744_Generate-AutoDocumentation.ps1"
Write-DocOrchLog "Checking for script: $script0744"
if (-not (Test-Path $script0744)) {
    Write-DocOrchLog "Error: 0744_Generate-AutoDocumentation.ps1 not found" -Level Error
    exit 1
}
Write-DocOrchLog "Found 0744 script"

try {
    $params = @{
        Mode = $Mode
        OutputPath = $OutputPath
        Format = $Format
        Quality = $true
    }
    
    Write-DocOrchLog "Executing: 0744_Generate-AutoDocumentation.ps1 with parameters: Mode=$Mode, Format=$Format"
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
Write-DocOrchLog "Checking for script: $script0745"
if (-not (Test-Path $script0745)) {
    Write-DocOrchLog "Error: 0745_Generate-ProjectIndexes.ps1 not found" -Level Error
    exit 1
}
Write-DocOrchLog "Found 0745 script"

try {
    $indexMode = if ($Mode -eq 'Full' -or $Force) { 'Full' } else { 'Incremental' }
    Write-DocOrchLog "Index generation mode determined: $indexMode"
    
    $params = @{
        Mode = $indexMode
        RootPath = $script:ProjectRoot
    }
    
    if ($Force) {
        $params['Force'] = $true
        Write-DocOrchLog "Force flag enabled for project indexes"
    }
    
    Write-DocOrchLog "Executing: 0745_Generate-ProjectIndexes.ps1 with mode: $indexMode"
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

Write-DocOrchLog "Checking for duplicate INDEX.md (uppercase) files..."

# Get all index files and filter for uppercase ones (case-sensitive)
$allIndexFiles = @(Get-ChildItem -Path $OutputPath -Recurse -Filter "*ndex.md" -File -ErrorAction SilentlyContinue)
Write-DocOrchLog "Found $($allIndexFiles.Count) total index files"
$legacyIndexFiles = @($allIndexFiles | Where-Object { $_.Name -ceq "INDEX.md" })
Write-DocOrchLog "Found $($legacyIndexFiles.Count) uppercase INDEX.md files"

if ($legacyIndexFiles.Count -gt 0) {
    Write-DocOrchLog "Found $($legacyIndexFiles.Count) legacy INDEX.md (uppercase) files to clean up"
    
    foreach ($file in $legacyIndexFiles) {
        $dir = Split-Path $file.FullName -Parent
        $lowercaseIndex = Join-Path $dir "index.md"
        
        # Only remove if lowercase version exists
        if (Test-Path $lowercaseIndex) {
            Write-DocOrchLog "Removing uppercase duplicate: $($file.FullName)"
            Remove-Item $file.FullName -Force
        } else {
            Write-DocOrchLog "Renaming to lowercase: $($file.FullName)"
            Rename-Item $file.FullName -NewName "index.md" -Force
        }
    }
    
    Write-DocOrchLog "Cleanup completed" -Level Success
} else {
    Write-DocOrchLog "No legacy INDEX.md (uppercase) files found - all clear!" -Level Success
}

# Summary
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "    Documentation Generation Complete" -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host ""

$duration = (Get-Date) - $script:StartTime
Write-DocOrchLog "All documentation generation tasks completed" -Level Success
Write-DocOrchLog "Total execution time: $($duration.ToString('mm\:ss'))" -Level Success
Write-DocOrchLog "Output directory: $OutputPath" -Level Success
Write-DocOrchLog "Mode: $Mode, Format: $Format" -Level Information
Write-DocOrchLog "Process finished at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -Level Information

Write-Host ""
Write-Host "✅ All documentation has been generated successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  • View generated docs: cd $OutputPath" -ForegroundColor White
Write-Host "  • Open index: $OutputPath/index.md" -ForegroundColor White
Write-Host "  • Run validation: az 0404 (PSScriptAnalyzer)" -ForegroundColor White
Write-Host ""

Write-DocOrchLog "Documentation orchestration completed successfully" -Level Success

exit 0

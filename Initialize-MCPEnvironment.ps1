#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Initialize AitherZero Environment and Start MCP Server

.DESCRIPTION
    Complete initialization script that:
    1. Initializes the AitherZero environment
    2. Builds the MCP server if needed
    3. Starts the MCP server
    4. Optionally runs demonstration

.PARAMETER Demo
    Run demonstration after initialization

.PARAMETER BuildOnly
    Only build the server, don't start it

.EXAMPLE
    ./Initialize-MCPEnvironment.ps1
    ./Initialize-MCPEnvironment.ps1 -Demo
    ./Initialize-MCPEnvironment.ps1 -BuildOnly

.NOTES
    This is the complete one-command initialization for MCP server usage
#>

[CmdletBinding()]
param(
    [switch]$Demo,
    [switch]$BuildOnly
)

$ErrorActionPreference = 'Stop'
$rootPath = $PSScriptRoot

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════════════════╗" -ForegroundColor Magenta
Write-Host "║                                                                      ║" -ForegroundColor Magenta
Write-Host "║       🚀 AITHERZERO MCP SERVER - COMPLETE INITIALIZATION 🚀         ║" -ForegroundColor Magenta
Write-Host "║                                                                      ║" -ForegroundColor Magenta
Write-Host "╚══════════════════════════════════════════════════════════════════════╝" -ForegroundColor Magenta
Write-Host ""

# Step 1: Initialize AitherZero Environment
Write-Host "Step 1: Initializing AitherZero Environment" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

$initScript = Join-Path $rootPath "Initialize-AitherEnvironment.ps1"
if (Test-Path $initScript) {
    Write-Host "   Running Initialize-AitherEnvironment.ps1..." -ForegroundColor Yellow
    try {
        & $initScript -ErrorAction Stop
        Write-Host "   ✓ AitherZero environment initialized" -ForegroundColor Green
    } catch {
        Write-Host "   ⚠ Warning: Environment initialization had issues" -ForegroundColor Yellow
        Write-Host "   Continuing anyway..." -ForegroundColor Yellow
    }
} else {
    Write-Host "   ℹ Initialize-AitherEnvironment.ps1 not found, skipping..." -ForegroundColor Yellow
}
Write-Host ""

# Step 2: Build MCP Server
Write-Host "Step 2: Building MCP Server" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

$buildScript = Join-Path $rootPath "automation-scripts" "0750_Build-MCPServer.ps1"
if (Test-Path $buildScript) {
    & $buildScript
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Build failed" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "❌ Build script not found: $buildScript" -ForegroundColor Red
    exit 1
}
Write-Host ""

if ($BuildOnly) {
    Write-Host "✅ Build complete. Use ./automation-scripts/0751_Start-MCPServer.ps1 to start" -ForegroundColor Green
    exit 0
}

# Step 3: Test/Demo MCP Server
if ($Demo) {
    Write-Host "Step 3: Running MCP Server Demonstration" -ForegroundColor Cyan
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
    
    $demoScript = Join-Path $rootPath "automation-scripts" "0752_Demo-MCPServer.ps1"
    if (Test-Path $demoScript) {
        & $demoScript
    }
    Write-Host ""
}

Write-Host "╔══════════════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║                                                                      ║" -ForegroundColor Green
Write-Host "║              ✅ INITIALIZATION COMPLETE! ✅                           ║" -ForegroundColor Green
Write-Host "║                                                                      ║" -ForegroundColor Green
Write-Host "║  The MCP server is ready to use!                                     ║" -ForegroundColor Green
Write-Host "║                                                                      ║" -ForegroundColor Green
Write-Host "║  Quick Commands:                                                     ║" -ForegroundColor Green
Write-Host "║  • Test server:  ./automation-scripts/0751_Start-MCPServer.ps1 -Test ║" -ForegroundColor Green
Write-Host "║  • Start server: ./automation-scripts/0751_Start-MCPServer.ps1       ║" -ForegroundColor Green
Write-Host "║  • Demo server:  ./automation-scripts/0752_Demo-MCPServer.ps1        ║" -ForegroundColor Green
Write-Host "║                                                                      ║" -ForegroundColor Green
Write-Host "║  See: mcp-server/QUICKSTART.md for AI assistant setup                ║" -ForegroundColor Green
Write-Host "║                                                                      ║" -ForegroundColor Green
Write-Host "╚══════════════════════════════════════════════════════════════════════╝" -ForegroundColor Green

exit 0

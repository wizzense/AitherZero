#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Build the AitherZero MCP Server

.DESCRIPTION
    Installs dependencies and builds the TypeScript MCP server.
    This automation script is part of the AitherZero numbered system (0700-0799: AI Tools).

.PARAMETER Clean
    Clean build (remove node_modules and dist before building)

.EXAMPLE
    ./0750_Build-MCPServer.ps1
    ./0750_Build-MCPServer.ps1 -Clean

.NOTES
    Script Number: 0750
    Category: AI Tools & Automation
#>

[CmdletBinding()]
param(
    [switch]$Clean
)

$ErrorActionPreference = 'Stop'
$mcpServerPath = Join-Path $PSScriptRoot ".." "mcp-server"

Write-Host "╔══════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                                                                      ║" -ForegroundColor Cyan
Write-Host "║              🔨 BUILDING AITHERZERO MCP SERVER 🔨                    ║" -ForegroundColor Cyan
Write-Host "║                                                                      ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Check if mcp-server directory exists
if (-not (Test-Path $mcpServerPath)) {
    Write-Host "❌ MCP Server directory not found: $mcpServerPath" -ForegroundColor Red
    exit 1
}

Set-Location $mcpServerPath

# Clean if requested
if ($Clean) {
    Write-Host "🧹 Cleaning previous build..." -ForegroundColor Yellow
    if (Test-Path "node_modules") {
        Remove-Item -Recurse -Force "node_modules"
        Write-Host "   ✓ Removed node_modules" -ForegroundColor Green
    }
    if (Test-Path "dist") {
        Remove-Item -Recurse -Force "dist"
        Write-Host "   ✓ Removed dist" -ForegroundColor Green
    }
    Write-Host ""
}

# Check Node.js
Write-Host "🔍 Checking prerequisites..." -ForegroundColor Cyan
try {
    $nodeVersion = node --version
    Write-Host "   ✓ Node.js: $nodeVersion" -ForegroundColor Green
} catch {
    Write-Host "   ❌ Node.js not found. Please install Node.js 18+" -ForegroundColor Red
    exit 1
}

try {
    $npmVersion = npm --version
    Write-Host "   ✓ npm: $npmVersion" -ForegroundColor Green
} catch {
    Write-Host "   ❌ npm not found" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Install dependencies
Write-Host "📦 Installing dependencies..." -ForegroundColor Cyan
$installOutput = npm install 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ npm install failed:" -ForegroundColor Red
    Write-Host $installOutput
    exit 1
}

Write-Host "   ✓ Dependencies installed successfully" -ForegroundColor Green
Write-Host ""

# Build TypeScript
Write-Host "🔨 Building TypeScript..." -ForegroundColor Cyan
$buildOutput = npm run build 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Build failed:" -ForegroundColor Red
    Write-Host $buildOutput
    exit 1
}
Write-Host "   ✓ TypeScript compilation successful" -ForegroundColor Green
Write-Host ""

# Verify build output
if (Test-Path "dist/index.js") {
    $distSize = (Get-Item "dist/index.js").Length
    Write-Host "   ✓ dist/index.js created ($([math]::Round($distSize/1KB, 1)) KB)" -ForegroundColor Green
} else {
    Write-Host "   ❌ dist/index.js not found" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║                                                                      ║" -ForegroundColor Green
Write-Host "║                  ✅ BUILD SUCCESSFUL! ✅                              ║" -ForegroundColor Green
Write-Host "║                                                                      ║" -ForegroundColor Green
Write-Host "║  MCP Server built and ready to use                                   ║" -ForegroundColor Green
Write-Host "║                                                                      ║" -ForegroundColor Green
Write-Host "║  Test it: npm run test:manual                                        ║" -ForegroundColor Green
Write-Host "║  Start it: node dist/index.js                                        ║" -ForegroundColor Green
Write-Host "║                                                                      ║" -ForegroundColor Green
Write-Host "╚══════════════════════════════════════════════════════════════════════╝" -ForegroundColor Green

exit 0

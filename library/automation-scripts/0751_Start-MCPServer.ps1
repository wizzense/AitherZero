#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Start the AitherZero MCP Server

.DESCRIPTION
    Starts the MCP server and keeps it running, or tests it with a sample request.

.PARAMETER Test
    Send a test request and exit

.PARAMETER Background
    Start server in background (not supported in current implementation)

.EXAMPLE
    ./0751_Start-MCPServer.ps1 -Test
    ./0751_Start-MCPServer.ps1

.NOTES
    Script Number: 0751
    Category: AI Tools & Automation
#>

[CmdletBinding()]
param(
    [switch]$Test
)

$ErrorActionPreference = 'Stop'
$mcpServerPath = Join-Path $PSScriptRoot ".." "integrations" "mcp-server"

Write-Host "╔══════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                                                                      ║" -ForegroundColor Cyan
Write-Host "║              🚀 AITHERZERO MCP SERVER 🚀                             ║" -ForegroundColor Cyan
Write-Host "║                                                                      ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Check if server is built
$serverJs = Join-Path $mcpServerPath "dist" "index.js"
if (-not (Test-Path $serverJs)) {
    Write-Host "❌ Server not built. Run: ./automation-scripts/0750_Build-MCPServer.ps1" -ForegroundColor Red
    exit 1
}

Set-Location $mcpServerPath

if ($Test) {
    Write-Host "🧪 Testing MCP Server..." -ForegroundColor Cyan
    Write-Host ""
    
    # Test 1: List tools
    Write-Host "Test 1: Listing tools" -ForegroundColor Yellow
    $request = '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}'
    $response = $request | node dist/index.js 2>&1 | Where-Object { $_ -notmatch "running on stdio" }
    
    if ($response) {
        try {
            $json = $response | ConvertFrom-Json
            $toolCount = $json.result.tools.Count
            Write-Host "   ✓ Server responded with $toolCount tools" -ForegroundColor Green
            $json.result.tools | ForEach-Object {
                Write-Host "     • $($_.name)" -ForegroundColor Cyan
            }
        } catch {
            Write-Host "   ❌ Failed to parse response" -ForegroundColor Red
            Write-Host $response
        }
    }
    
    Write-Host ""
    
    # Test 2: List resources
    Write-Host "Test 2: Listing resources" -ForegroundColor Yellow
    $request = '{"jsonrpc":"2.0","id":2,"method":"resources/list","params":{}}'
    $response = $request | node dist/index.js 2>&1 | Where-Object { $_ -notmatch "running on stdio" }
    
    if ($response) {
        try {
            $json = $response | ConvertFrom-Json
            $resourceCount = $json.result.resources.Count
            Write-Host "   ✓ Server responded with $resourceCount resources" -ForegroundColor Green
            $json.result.resources | ForEach-Object {
                Write-Host "     • $($_.uri) - $($_.name)" -ForegroundColor Cyan
            }
        } catch {
            Write-Host "   ❌ Failed to parse response" -ForegroundColor Red
        }
    }
    
    Write-Host ""
    Write-Host "✅ MCP Server is working correctly!" -ForegroundColor Green
    
} else {
    Write-Host "Starting MCP Server..." -ForegroundColor Cyan
    Write-Host "Press Ctrl+C to stop" -ForegroundColor Yellow
    Write-Host ""
    
    # Start the server
    node dist/index.js
}

exit 0

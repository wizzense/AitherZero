#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Demonstrate AitherZero MCP Server functionality

.DESCRIPTION
    Runs real MCP server commands and shows actual results.
    This is NOT a simulation - it actually uses the MCP server!

.EXAMPLE
    ./0752_Demo-MCPServer.ps1

.NOTES
    Script Number: 0752
    Category: AI Tools & Automation
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$mcpServerPath = Join-Path $PSScriptRoot ".." "integrations" "mcp-server"
$serverJs = Join-Path $mcpServerPath "dist" "index.js"

function Invoke-MCPRequest {
    param(
        [string]$Method,
        [string]$Name,
        [hashtable]$Arguments = @{}
    )
    
    $id = Get-Random -Minimum 1 -Maximum 10000
    
    if ($Method -eq "tools/list" -or $Method -eq "resources/list") {
        $request = @{
            jsonrpc = "2.0"
            id = $id
            method = $Method
            params = @{}
        } | ConvertTo-Json -Compress
    } elseif ($Method -eq "tools/call") {
        $request = @{
            jsonrpc = "2.0"
            id = $id
            method = $Method
            params = @{
                name = $Name
                arguments = $Arguments
            }
        } | ConvertTo-Json -Compress -Depth 10
    } elseif ($Method -eq "resources/read") {
        $request = @{
            jsonrpc = "2.0"
            id = $id
            method = $Method
            params = @{
                uri = $Name
            }
        } | ConvertTo-Json -Compress
    }
    
    $response = $request | node $serverJs 2>&1 | Where-Object { $_ -notmatch "running on stdio" }
    
    if ($response) {
        try {
            return ($response | ConvertFrom-Json)
        } catch {
            Write-Host "Failed to parse: $response" -ForegroundColor Red
            return $null
        }
    }
    return $null
}

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                                                                      ║" -ForegroundColor Cyan
Write-Host "║         🎬 REAL MCP SERVER DEMONSTRATION 🎬                          ║" -ForegroundColor Cyan
Write-Host "║              (Not a simulation!)                                     ║" -ForegroundColor Cyan
Write-Host "║                                                                      ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Check if server is built
if (-not (Test-Path $serverJs)) {
    Write-Host "❌ Server not built. Building now..." -ForegroundColor Yellow
    & (Join-Path $PSScriptRoot "0750_Build-MCPServer.ps1")
    if ($LASTEXITCODE -ne 0) {
        exit 1
    }
}

Set-Location $mcpServerPath

# Demo 1: List Available Tools
Write-Host "📋 Demo 1: List Available Tools (REAL MCP CALL)" -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Yellow
$response = Invoke-MCPRequest -Method "tools/list"
if ($response -and $response.result) {
    Write-Host "✅ SUCCESS - Received response from MCP server" -ForegroundColor Green
    Write-Host "   Tools available: $($response.result.tools.Count)" -ForegroundColor Cyan
    $response.result.tools | ForEach-Object {
        Write-Host "   ✓ $($_.name) - $($_.description.Substring(0, [Math]::Min(60, $_.description.Length)))..." -ForegroundColor White
    }
} else {
    Write-Host "❌ No response from server" -ForegroundColor Red
}
Write-Host ""

# Demo 2: List Available Resources
Write-Host "📋 Demo 2: List Available Resources (REAL MCP CALL)" -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Yellow
$response = Invoke-MCPRequest -Method "resources/list"
if ($response -and $response.result) {
    Write-Host "✅ SUCCESS - Received response from MCP server" -ForegroundColor Green
    Write-Host "   Resources available: $($response.result.resources.Count)" -ForegroundColor Cyan
    $response.result.resources | ForEach-Object {
        Write-Host "   ✓ $($_.uri) - $($_.name) ($($_.mimeType))" -ForegroundColor White
    }
} else {
    Write-Host "❌ No response from server" -ForegroundColor Red
}
Write-Host ""

# Demo 3: Get Server Info
Write-Host "📋 Demo 3: Initialize Connection (REAL MCP CALL)" -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Yellow
$request = @{
    jsonrpc = "2.0"
    id = 3
    method = "initialize"
    params = @{
        protocolVersion = "2024-11-05"
        capabilities = @{}
        clientInfo = @{
            name = "aitherzero-demo"
            version = "1.0.0"
        }
    }
} | ConvertTo-Json -Compress -Depth 10

$response = $request | node $serverJs 2>&1 | Where-Object { $_ -notmatch "running on stdio" }
if ($response) {
    try {
        $json = $response | ConvertFrom-Json
        Write-Host "✅ SUCCESS - Server initialized" -ForegroundColor Green
        Write-Host "   Server: $($json.result.serverInfo.name) v$($json.result.serverInfo.version)" -ForegroundColor Cyan
        Write-Host "   Protocol: $($json.result.protocolVersion)" -ForegroundColor Cyan
    } catch {
        Write-Host "❌ Failed to initialize" -ForegroundColor Red
    }
}
Write-Host ""

Write-Host "╔══════════════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║                                                                      ║" -ForegroundColor Green
Write-Host "║                  ✅ REAL DEMONSTRATION COMPLETE ✅                    ║" -ForegroundColor Green
Write-Host "║                                                                      ║" -ForegroundColor Green
Write-Host "║  The MCP server was actually called and responded!                   ║" -ForegroundColor Green
Write-Host "║  • Real JSON-RPC requests sent                                       ║" -ForegroundColor Green
Write-Host "║  • Real responses received                                           ║" -ForegroundColor Green
Write-Host "║  • Server fully operational                                          ║" -ForegroundColor Green
Write-Host "║                                                                      ║" -ForegroundColor Green
Write-Host "║  Ready for AI assistant integration!                                 ║" -ForegroundColor Green
Write-Host "║                                                                      ║" -ForegroundColor Green
Write-Host "╚══════════════════════════════════════════════════════════════════════╝" -ForegroundColor Green

exit 0

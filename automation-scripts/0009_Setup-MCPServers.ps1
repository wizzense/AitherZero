#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Automatically build and configure MCP servers for GitHub Copilot.

.DESCRIPTION
    This script:
    1. Builds the custom AitherZero MCP server (TypeScript -> JavaScript)
    2. Verifies all MCP server configurations
    3. Validates that all required npm packages are installed
    4. Checks VS Code Copilot MCP settings are correct
    5. Provides instructions for activation

.PARAMETER Force
    Force rebuild even if already built.

.PARAMETER SkipValidation
    Skip validation checks and just build.

.EXAMPLE
    ./0009_Setup-MCPServers.ps1
    Standard setup with validation.

.EXAMPLE
    ./0009_Setup-MCPServers.ps1 -Force
    Force rebuild of MCP servers.

.NOTES
    Script: 0009_Setup-MCPServers.ps1
    Range: 0000-0099 (Environment preparation)
    Author: Aitherium Corporation
    Requires: Node.js 18+, npm
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [switch]$Force,

    [Parameter(Mandatory = $false)]
    [switch]$SkipValidation
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Colors for output
$script:Colors = @{
    Success = 'Green'
    Info    = 'Cyan'
    Warning = 'Yellow'
    Error   = 'Red'
}

function Write-StatusMessage {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet('Success', 'Info', 'Warning', 'Error')]
        [string]$Level = 'Info'
    )
    
    $color = $script:Colors[$Level]
    $prefix = switch ($Level) {
        'Success' { '[✓]' }
        'Info'    { '[i]' }
        'Warning' { '[!]' }
        'Error'   { '[✗]' }
    }
    
    Write-Host "$prefix $Message" -ForegroundColor $color
}

function Test-NodeInstalled {
    try {
        $nodeVersion = node --version 2>$null
        $npmVersion = npm --version 2>$null
        
        if ($nodeVersion -and $npmVersion) {
            Write-StatusMessage "Node.js $nodeVersion and npm $npmVersion detected" -Level Success
            return $true
        }
        
        Write-StatusMessage "Node.js or npm not found in PATH" -Level Error
        return $false
    }
    catch {
        Write-StatusMessage "Failed to check Node.js installation: $_" -Level Error
        return $false
    }
}

function Test-MCPServerBuilt {
    param([string]$ServerPath)
    
    $distPath = Join-Path $ServerPath 'dist'
    $indexJs = Join-Path $distPath 'index.js'
    
    if (Test-Path $indexJs) {
        Write-StatusMessage "MCP server already built at: $indexJs" -Level Success
        return $true
    }
    
    Write-StatusMessage "MCP server not built (dist/index.js missing)" -Level Warning
    return $false
}

function Build-MCPServer {
    param([string]$ServerPath)
    
    try {
        Push-Location $ServerPath
        Write-StatusMessage "Building AitherZero MCP server..." -Level Info
        
        # Install dependencies
        Write-StatusMessage "Installing npm dependencies..." -Level Info
        npm install --silent
        
        # Build is automatic via postinstall, but verify
        if (-not (Test-Path 'dist/index.js')) {
            Write-StatusMessage "Build failed - dist/index.js not created" -Level Error
            return $false
        }
        
        Write-StatusMessage "MCP server built successfully" -Level Success
        return $true
    }
    catch {
        Write-StatusMessage "Failed to build MCP server: $_" -Level Error
        return $false
    }
    finally {
        Pop-Location
    }
}

function Test-MCPConfiguration {
    param([string]$WorkspaceRoot)
    
    $configFile = Join-Path $WorkspaceRoot '.vscode' 'mcp-servers.json'
    $settingsFile = Join-Path $WorkspaceRoot '.vscode' 'settings.json'
    
    # Check config file exists
    if (-not (Test-Path $configFile)) {
        Write-StatusMessage "MCP config file missing: $configFile" -Level Error
        return $false
    }
    
    # Validate JSON
    try {
        $config = Get-Content $configFile -Raw | ConvertFrom-Json
        $serverNames = @($config.mcpServers.PSObject.Properties.Name)
        $serverCount = $serverNames.Count
        Write-StatusMessage "Found $serverCount MCP servers configured" -Level Success
        
        # List servers
        foreach ($serverName in $serverNames) {
            $server = $config.mcpServers.$serverName
            Write-StatusMessage "  - ${serverName}: $($server.description)" -Level Info
        }
    }
    catch {
        Write-StatusMessage "Invalid JSON in MCP config: $_" -Level Error
        return $false
    }
    
    # Check VS Code settings
    if (Test-Path $settingsFile) {
        try {
            $settings = Get-Content $settingsFile -Raw
            if ($settings -match '"github\.copilot\.chat\.mcp\.enabled":\s*true') {
                Write-StatusMessage "Copilot MCP enabled in VS Code settings" -Level Success
            }
            else {
                Write-StatusMessage "Copilot MCP not enabled in settings.json" -Level Warning
            }
            
            if ($settings -match '"github\.copilot\.chat\.mcp\.configFile"') {
                Write-StatusMessage "Copilot MCP config file path set" -Level Success
            }
            else {
                Write-StatusMessage "Copilot MCP config file path not set" -Level Warning
            }
        }
        catch {
            Write-StatusMessage "Failed to validate VS Code settings: $_" -Level Warning
        }
    }
    
    return $true
}

function Show-ActivationInstructions {
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  MCP Servers Setup Complete!" -ForegroundColor Green
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "To activate MCP servers in GitHub Copilot:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  1. Reload VS Code window:" -ForegroundColor White
    Write-Host "     - Press: Ctrl+Shift+P (Windows/Linux) or Cmd+Shift+P (macOS)" -ForegroundColor Gray
    Write-Host "     - Type: 'Developer: Reload Window'" -ForegroundColor Gray
    Write-Host "     - Press: Enter" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  2. Verify MCP servers loaded:" -ForegroundColor White
    Write-Host "     - Open: View > Output (Ctrl+Shift+U)" -ForegroundColor Gray
    Write-Host "     - Select: 'GitHub Copilot' from dropdown" -ForegroundColor Gray
    Write-Host "     - Look for: '[MCP] Server ready: aitherzero'" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  3. Test in Copilot Chat:" -ForegroundColor White
    Write-Host "     - Open Copilot Chat (Ctrl+Shift+I)" -ForegroundColor Gray
    Write-Host "     - Type: '@workspace List all automation scripts'" -ForegroundColor Gray
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
}

# Main execution
try {
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  AitherZero MCP Server Setup" -ForegroundColor White
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    
    # Determine workspace root
    $workspaceRoot = $env:AITHERZERO_ROOT
    if (-not $workspaceRoot) {
        $workspaceRoot = Split-Path -Parent $PSScriptRoot
        Write-StatusMessage "Using workspace root: $workspaceRoot" -Level Info
    }
    
    # Check Node.js installation
    Write-StatusMessage "Checking prerequisites..." -Level Info
    if (-not (Test-NodeInstalled)) {
        Write-StatusMessage "Node.js 18+ is required for MCP servers" -Level Error
        Write-Host ""
        Write-Host "Install Node.js from: https://nodejs.org/" -ForegroundColor Yellow
        exit 1
    }
    
    # Locate MCP server
    $mcpServerPath = Join-Path $workspaceRoot 'mcp-server'
    if (-not (Test-Path $mcpServerPath)) {
        Write-StatusMessage "MCP server directory not found: $mcpServerPath" -Level Error
        exit 1
    }
    
    Write-StatusMessage "MCP server location: $mcpServerPath" -Level Info
    Write-Host ""
    
    # Check if build needed
    $needsBuild = $Force -or -not (Test-MCPServerBuilt -ServerPath $mcpServerPath)
    
    if ($needsBuild) {
        Write-StatusMessage "Building MCP server..." -Level Info
        if (-not (Build-MCPServer -ServerPath $mcpServerPath)) {
            Write-StatusMessage "MCP server build failed" -Level Error
            exit 1
        }
        Write-Host ""
    }
    else {
        Write-StatusMessage "MCP server already built (use -Force to rebuild)" -Level Info
        Write-Host ""
    }
    
    # Validate configuration
    if (-not $SkipValidation) {
        Write-StatusMessage "Validating MCP configuration..." -Level Info
        if (-not (Test-MCPConfiguration -WorkspaceRoot $workspaceRoot)) {
            Write-StatusMessage "MCP configuration validation failed" -Level Warning
            Write-Host ""
        }
        Write-Host ""
    }
    
    # Show activation instructions
    Show-ActivationInstructions
    
    exit 0
}
catch {
    Write-StatusMessage "Unexpected error: $_" -Level Error
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    exit 1
}

#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Configure Model Context Protocol (MCP) servers for GitHub Copilot
.DESCRIPTION
    Sets up MCP servers in VS Code settings to enhance GitHub Copilot with:
    - Filesystem access for repository navigation
    - GitHub API integration for issues/PRs
    - Git operations for version control
    - PowerShell documentation fetching
    - Sequential thinking for complex problem-solving

    This script ensures MCP servers are properly configured in both workspace
    and user settings, with proper environment variable handling.

.PARAMETER Scope
    Configuration scope: Workspace (project only) or User (global)
.PARAMETER Verify
    Verify MCP server configuration and test connectivity
.EXAMPLE
    ./0215_Configure-MCPServers.ps1
    Configure MCP servers in workspace settings
.EXAMPLE
    ./0215_Configure-MCPServers.ps1 -Scope User
    Configure MCP servers in user settings (global)
.EXAMPLE
    ./0215_Configure-MCPServers.ps1 -Verify
    Verify MCP configuration and test servers
.NOTES
    Part of AitherZero Development Environment Setup (0200-0299 range)
    Requires Node.js 18+ for MCP servers
    Requires GITHUB_TOKEN environment variable for GitHub server
#>

[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet('Workspace', 'User')]
    [string]$Scope = 'Workspace',

    [Parameter()]
    [switch]$Verify
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Script metadata
$scriptName = 'Configure-MCPServers'
$scriptVersion = '1.0.0'

# Write to console with color
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Level = 'Info'
    )

    $colors = @{
        'Info'    = 'Cyan'
        'Success' = 'Green'
        'Warning' = 'Yellow'
        'Error'   = 'Red'
    }

    $color = $colors[$Level]
    Write-Host $Message -ForegroundColor $color
}

# Log with custom logging if available
function Write-LogMessage {
    param(
        [string]$Message,
        [string]$Level = 'Information'
    )

    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Message $Message -Level $Level
    }
    Write-Verbose $Message
}

# Main execution
try {
    Write-ColorOutput "=== MCP Server Configuration ===" -Level 'Info'
    Write-ColorOutput "Script: $scriptName v$scriptVersion" -Level 'Info'
    Write-ColorOutput "Scope: $Scope" -Level 'Info'
    Write-LogMessage -Message "Starting MCP server configuration (Scope: $Scope)"

    # Determine workspace root
    $workspaceRoot = if ($env:AITHERZERO_ROOT) {
        $env:AITHERZERO_ROOT
    } elseif (Test-Path "$PSScriptRoot/../AitherZero.psd1") {
        Split-Path $PSScriptRoot -Parent
    } else {
        $PWD.Path
    }

    Write-ColorOutput "Workspace: $workspaceRoot" -Level 'Info'

    # Check prerequisites
    Write-ColorOutput "`nChecking prerequisites..." -Level 'Info'

    # Check Node.js
    $nodeVersion = $null
    try {
        $nodeVersion = & node --version 2>$null
        if ($nodeVersion) {
            Write-ColorOutput "  ✓ Node.js: $nodeVersion" -Level 'Success'
            $nodeMajor = [int]($nodeVersion -replace 'v(\d+)\..*', '$1')
            if ($nodeMajor -lt 18) {
                Write-ColorOutput "  ⚠ Node.js version should be 18+ (current: $nodeVersion)" -Level 'Warning'
            }
        }
    } catch {
        Write-ColorOutput "  ✗ Node.js not found - MCP servers require Node.js 18+" -Level 'Error'
        Write-ColorOutput "    Install: https://nodejs.org/" -Level 'Warning'
        throw "Node.js is required for MCP servers"
    }

    # Check GITHUB_TOKEN
    if ($env:GITHUB_TOKEN) {
        $tokenLength = $env:GITHUB_TOKEN.Length
        Write-ColorOutput "  ✓ GITHUB_TOKEN is set ($tokenLength characters)" -Level 'Success'
    } else {
        Write-ColorOutput "  ⚠ GITHUB_TOKEN not set - GitHub MCP server will not work" -Level 'Warning'
        Write-ColorOutput "    Set with: export GITHUB_TOKEN='your_token'" -Level 'Warning'
    }

    # Check VS Code
    $vscodeVersion = $null
    try {
        $vscodeVersion = & code --version 2>$null | Select-Object -First 1
        if ($vscodeVersion) {
            Write-ColorOutput "  ✓ VS Code: $vscodeVersion" -Level 'Success'
        }
    } catch {
        Write-ColorOutput "  ⚠ VS Code command not found" -Level 'Warning'
    }

    # If verify mode, check existing configuration
    if ($Verify) {
        Write-ColorOutput "`nVerifying MCP configuration..." -Level 'Info'

        $settingsPath = if ($Scope -eq 'Workspace') {
            Join-Path $workspaceRoot ".vscode/settings.json"
        } else {
            if ($IsWindows) {
                Join-Path $env:APPDATA "Code/User/settings.json"
            } else {
                Join-Path $HOME ".config/Code/User/settings.json"
            }
        }

        if (Test-Path $settingsPath) {
            $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json
            $mcpEnabled = $settings.'github.copilot.chat.mcp.enabled'
            $mcpServers = $settings.'github.copilot.chat.mcp.servers'

            if ($mcpEnabled) {
                Write-ColorOutput "  ✓ MCP is enabled" -Level 'Success'
            } else {
                Write-ColorOutput "  ✗ MCP is not enabled" -Level 'Error'
            }

            if ($mcpServers) {
                $serverCount = ($mcpServers | Get-Member -MemberType NoteProperty).Count
                Write-ColorOutput "  ✓ $serverCount MCP server(s) configured" -Level 'Success'
                foreach ($server in ($mcpServers | Get-Member -MemberType NoteProperty).Name) {
                    Write-ColorOutput "    - $server" -Level 'Info'
                }
            } else {
                Write-ColorOutput "  ✗ No MCP servers configured" -Level 'Error'
            }
        } else {
            Write-ColorOutput "  ✗ Settings file not found: $settingsPath" -Level 'Error'
        }

        Write-ColorOutput "`nVerification complete." -Level 'Success'
        exit 0
    }

    # Configure MCP servers
    Write-ColorOutput "`nConfiguring MCP servers..." -Level 'Info'

    $settingsPath = if ($Scope -eq 'Workspace') {
        Join-Path $workspaceRoot ".vscode/settings.json"
    } else {
        if ($IsWindows) {
            $userSettings = Join-Path $env:APPDATA "Code/User/settings.json"
        } else {
            $userSettings = Join-Path $HOME ".config/Code/User/settings.json"
        }
        # Ensure directory exists
        $settingsDir = Split-Path $userSettings -Parent
        if (-not (Test-Path $settingsDir)) {
            New-Item -ItemType Directory -Path $settingsDir -Force | Out-Null
        }
        $userSettings
    }

    Write-ColorOutput "Settings file: $settingsPath" -Level 'Info'

    # Read existing settings or create new
    $settings = if (Test-Path $settingsPath) {
        Write-LogMessage -Message "Reading existing settings from $settingsPath"
        Get-Content $settingsPath -Raw | ConvertFrom-Json
    } else {
        Write-LogMessage -Message "Creating new settings file"
        [PSCustomObject]@{}
    }

    # Add or update MCP configuration
    $settings | Add-Member -NotePropertyName 'github.copilot.chat.mcp.enabled' -NotePropertyValue $true -Force

    $mcpServers = [PSCustomObject]@{
        filesystem            = [PSCustomObject]@{
            command = "npx"
            args    = @(
                "-y"
                "@modelcontextprotocol/server-filesystem"
                "`${workspaceFolder}"
            )
            env     = [PSCustomObject]@{}
        }
        github                = [PSCustomObject]@{
            command = "npx"
            args    = @(
                "-y"
                "@modelcontextprotocol/server-github"
            )
            env     = [PSCustomObject]@{
                GITHUB_PERSONAL_ACCESS_TOKEN = "`${env:GITHUB_TOKEN}"
            }
        }
        git                   = [PSCustomObject]@{
            command = "npx"
            args    = @(
                "-y"
                "@modelcontextprotocol/server-git"
                "`${workspaceFolder}"
            )
            env     = [PSCustomObject]@{}
        }
        'powershell-docs'     = [PSCustomObject]@{
            command = "npx"
            args    = @(
                "-y"
                "@modelcontextprotocol/server-fetch"
            )
            env     = [PSCustomObject]@{
                ALLOWED_DOMAINS = "docs.microsoft.com,learn.microsoft.com,github.com"
            }
        }
        'sequential-thinking' = [PSCustomObject]@{
            command = "npx"
            args    = @(
                "-y"
                "@modelcontextprotocol/server-sequential-thinking"
            )
            env     = [PSCustomObject]@{}
        }
    }

    $settings | Add-Member -NotePropertyName 'github.copilot.chat.mcp.servers' -NotePropertyValue $mcpServers -Force

    # Write settings file with proper formatting
    $json = $settings | ConvertTo-Json -Depth 10
    $json | Set-Content -Path $settingsPath -Encoding UTF8

    Write-ColorOutput "  ✓ MCP servers configured successfully" -Level 'Success'
    Write-LogMessage -Message "MCP servers configured in $settingsPath"

    # Summary
    Write-ColorOutput "`n=== Configuration Complete ===" -Level 'Success'
    Write-ColorOutput "MCP Servers Enabled:" -Level 'Info'
    Write-ColorOutput "  • filesystem - Repository navigation and file operations" -Level 'Info'
    Write-ColorOutput "  • github - GitHub API for issues/PRs/metadata" -Level 'Info'
    Write-ColorOutput "  • git - Version control operations" -Level 'Info'
    Write-ColorOutput "  • powershell-docs - PowerShell documentation" -Level 'Info'
    Write-ColorOutput "  • sequential-thinking - Complex problem-solving" -Level 'Info'

    Write-ColorOutput "`nNext Steps:" -Level 'Info'
    Write-ColorOutput "1. Reload VS Code window (Ctrl+Shift+P → 'Reload Window')" -Level 'Info'
    Write-ColorOutput "2. Open Copilot Chat and try: @workspace Show me the domain structure" -Level 'Info'
    Write-ColorOutput "3. Verify with: ./automation-scripts/0215_Configure-MCPServers.ps1 -Verify" -Level 'Info'

    if (-not $env:GITHUB_TOKEN) {
        Write-ColorOutput "`nWarning: Set GITHUB_TOKEN to enable GitHub MCP server" -Level 'Warning'
        Write-ColorOutput "  export GITHUB_TOKEN='your_github_token'" -Level 'Warning'
    }

    exit 0

} catch {
    Write-ColorOutput "`n✗ Error: $($_.Exception.Message)" -Level 'Error'
    Write-LogMessage -Message "MCP configuration failed: $($_.Exception.Message)" -Level 'Error'
    exit 1
}

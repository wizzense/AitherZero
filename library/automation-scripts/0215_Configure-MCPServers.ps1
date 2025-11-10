#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Configure Model Context Protocol (MCP) servers for GitHub Copilot
.DESCRIPTION
    Sets up MCP servers in VS Code using the .vscode/mcp.json format.
    Configures MCP servers to enhance GitHub Copilot with:
    - Filesystem access for repository navigation
    - GitHub API integration for issues/PRs
    - Git operations for version control
    - PowerShell documentation fetching
    - Sequential thinking for complex problem-solving

    Uses the official VS Code MCP configuration format with .vscode/mcp.json
    or user profile mcp.json file as documented at:
    https://code.visualstudio.com/library/copilot/customization/mcp-servers
    
    Stage: Development
    Category: Development Environment Setup

.PARAMETER Scope
    Configuration scope: Workspace (project .vscode/mcp.json) or User (global profile)
.PARAMETER Verify
    Verify MCP server configuration and test connectivity
.EXAMPLE
    ./0215_Configure-MCPServers.ps1
    Configure MCP servers in workspace .vscode/mcp.json
.EXAMPLE
    ./0215_Configure-MCPServers.ps1 -Scope User
    Configure MCP servers in user profile mcp.json (global)
.EXAMPLE
    ./0215_Configure-MCPServers.ps1 -Verify
    Verify MCP configuration and test servers
.NOTES
    Part of AitherZero Development Environment Setup (0200-0299 range)
    Requires Node.js 18+ for MCP servers
    Requires GITHUB_TOKEN environment variable for GitHub server
    
    Format follows VS Code MCP specification:
    https://code.visualstudio.com/library/copilot/customization/mcp-servers
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
param(
    [Parameter()]
    [ValidateSet('Workspace', 'User')]
    [string]$Scope = 'Workspace',

    [Parameter()]
    [switch]$Verify
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Determine project root
$projectRoot = if ($env:AITHERZERO_ROOT) {
    $env:AITHERZERO_ROOT
} elseif ($PSScriptRoot) {
    Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
} else {
    Get-Location
}

# Import ScriptUtilities for centralized logging
$scriptUtilsPath = Join-Path $projectRoot "aithercore/automation/ScriptUtilities.psm1"
if (Test-Path $scriptUtilsPath) {
    Import-Module $scriptUtilsPath -Force -ErrorAction SilentlyContinue
}

# Script metadata
$scriptName = 'Configure-MCPServers'
$scriptVersion = '2.0.0'

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

# Main execution
try {
    Write-ColorOutput "=== MCP Server Configuration ===" -Level 'Info'
    Write-ColorOutput "Script: $scriptName v$scriptVersion" -Level 'Info'
    Write-ColorOutput "Scope: $Scope" -Level 'Info'
    Write-ScriptLog -Message "Starting MCP server configuration (Scope: $Scope)"

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
            Write-ColorOutput "  ✓ Node.js: $nodeVersion" -Level Information
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
        Write-ColorOutput "  ✓ GITHUB_TOKEN is set ($tokenLength characters)" -Level Information
    } else {
        Write-ColorOutput "  ⚠ GITHUB_TOKEN not set - GitHub MCP server will not work" -Level 'Warning'
        Write-ColorOutput "    Set with: export GITHUB_TOKEN='your_token'" -Level 'Warning'
    }

    # Check VS Code
    $vscodeVersion = $null
    try {
        $vscodeVersion = & code --version 2>$null | Select-Object -First 1
        if ($vscodeVersion) {
            Write-ColorOutput "  ✓ VS Code: $vscodeVersion" -Level Information
        }
    } catch {
        Write-ColorOutput "  ⚠ VS Code command not found" -Level 'Warning'
    }

    # Determine mcp.json path based on scope
    $mcpJsonPath = if ($Scope -eq 'Workspace') {
        $vscodeDir = Join-Path $workspaceRoot ".vscode"
        if (-not (Test-Path $vscodeDir)) {
            if ($PSCmdlet.ShouldProcess($vscodeDir, "Create .vscode directory")) {
                New-Item -ItemType Directory -Path $vscodeDir -Force | Out-Null
                Write-ScriptLog -Message "Created .vscode directory"
            }
        }
        Join-Path $vscodeDir "mcp.json"
    } else {
        # User profile mcp.json location
        if ($IsWindows) {
            $appData = $env:APPDATA
            $userMcpPath = Join-Path $appData "Code\User\mcp.json"
        } elseif ($IsMacOS) {
            $userMcpPath = Join-Path $HOME "Library/Application Support/Code/User/mcp.json"
        } else {
            $userMcpPath = Join-Path $HOME ".config/Code/User/mcp.json"
        }
        
        $userDir = Split-Path $userMcpPath -Parent
        if (-not (Test-Path $userDir)) {
            if ($PSCmdlet.ShouldProcess($userDir, "Create user settings directory")) {
                New-Item -ItemType Directory -Path $userDir -Force | Out-Null
                Write-ScriptLog -Message "Created user settings directory"
            }
        }
        $userMcpPath
    }

    Write-ColorOutput "MCP config file: $mcpJsonPath" -Level 'Info'

    # If verify mode, check existing configuration
    if ($Verify) {
        Write-ColorOutput "`nVerifying MCP configuration..." -Level 'Info'

        if (Test-Path $mcpJsonPath) {
            try {
                $mcpConfig = Get-Content $mcpJsonPath -Raw | ConvertFrom-Json
                
                if ($mcpConfig.servers) {
                    $serverCount = ($mcpConfig.servers | Get-Member -MemberType NoteProperty).Count
                    Write-ColorOutput "  ✓ $serverCount MCP server(s) configured" -Level Information
                    foreach ($serverName in ($mcpConfig.servers | Get-Member -MemberType NoteProperty).Name) {
                        $server = $mcpConfig.servers.$serverName
                        $serverType = if ($server.type) { $server.type } else { "stdio" }
                        Write-ColorOutput "    - $serverName (type: $serverType)" -Level 'Info'
                    }
                } else {
                    Write-ColorOutput "  ✗ No MCP servers configured" -Level 'Error'
                }

                if ($mcpConfig.inputs) {
                    $inputCount = $mcpConfig.inputs.Count
                    Write-ColorOutput "  ✓ $inputCount input variable(s) defined" -Level Information
                }
            } catch {
                Write-ColorOutput "  ✗ Failed to parse mcp.json: $($_.Exception.Message)" -Level 'Error'
            }
        } else {
            Write-ColorOutput "  ✗ MCP config file not found: $mcpJsonPath" -Level 'Error'
        }

        Write-ColorOutput "`nVerification complete." -Level Information
        exit 0
    }

    # Configure MCP servers
    Write-ColorOutput "`nConfiguring MCP servers..." -Level 'Info'

    # Read existing configuration or create new
    $mcpConfig = if (Test-Path $mcpJsonPath) {
        Write-ScriptLog -Message "Reading existing MCP configuration from $mcpJsonPath"
        try {
            Get-Content $mcpJsonPath -Raw | ConvertFrom-Json
        } catch {
            Write-ColorOutput "  ⚠ Failed to parse existing mcp.json, creating new: $($_.Exception.Message)" -Level 'Warning'
            [PSCustomObject]@{
                servers = [PSCustomObject]@{}
                inputs = @()
            }
        }
    } else {
        Write-ScriptLog -Message "Creating new MCP configuration file"
        [PSCustomObject]@{
            servers = [PSCustomObject]@{}
            inputs = @()
        }
    }

    # Ensure servers object exists
    if (-not $mcpConfig.servers) {
        $mcpConfig | Add-Member -NotePropertyName 'servers' -NotePropertyValue ([PSCustomObject]@{}) -Force
    }

    # Define MCP servers using official VS Code format
    $servers = [PSCustomObject]@{
        'aitherzero' = [PSCustomObject]@{
            type = "stdio"
            command = "node"
            args = @(
                "`${workspaceFolder}/integrations/mcp-server/scripts/start-with-build.mjs"
            )
            env = [PSCustomObject]@{
                AITHERZERO_ROOT = "`${workspaceFolder}"
                AITHERZERO_NONINTERACTIVE = "1"
            }
        }
        'filesystem' = [PSCustomObject]@{
            type = "stdio"
            command = "npx"
            args = @(
                "-y"
                "@modelcontextprotocol/server-filesystem"
                "`${workspaceFolder}"
            )
        }
        'github' = [PSCustomObject]@{
            type = "stdio"
            command = "npx"
            args = @(
                "-y"
                "@modelcontextprotocol/server-github"
            )
            env = [PSCustomObject]@{
                GITHUB_PERSONAL_ACCESS_TOKEN = "`${env:GITHUB_TOKEN}"
            }
        }
        'git' = [PSCustomObject]@{
            type = "stdio"
            command = "npx"
            args = @(
                "-y"
                "@modelcontextprotocol/server-git"
                "--repository"
                "`${workspaceFolder}"
            )
        }
        'sequential-thinking' = [PSCustomObject]@{
            type = "stdio"
            command = "npx"
            args = @(
                "-y"
                "@modelcontextprotocol/server-sequential-thinking"
            )
        }
    }

    # Add/update each server
    foreach ($serverName in ($servers | Get-Member -MemberType NoteProperty).Name) {
        $mcpConfig.servers | Add-Member -NotePropertyName $serverName -NotePropertyValue $servers.$serverName -Force
    }

    # Add input variable for GITHUB_TOKEN if not present
    if (-not $mcpConfig.inputs) {
        $mcpConfig | Add-Member -NotePropertyName 'inputs' -NotePropertyValue @() -Force
    }

    # Check if github-token input already exists
    $hasGitHubTokenInput = $false
    foreach ($input in $mcpConfig.inputs) {
        if ($input.id -eq 'github-token') {
            $hasGitHubTokenInput = $true
            break
        }
    }

    if (-not $hasGitHubTokenInput) {
        $mcpConfig.inputs += [PSCustomObject]@{
            id = "github-token"
            type = "promptString"
            description = "GitHub Personal Access Token for API access"
            password = $true
        }
    }

    # Write mcp.json file with proper formatting
    $json = $mcpConfig | ConvertTo-Json -Depth 10
    
    if ($PSCmdlet.ShouldProcess($mcpJsonPath, "Write MCP configuration")) {
        $json | Set-Content -Path $mcpJsonPath -Encoding UTF8
        Write-ColorOutput "  ✓ MCP servers configured successfully" -Level Information
        Write-ScriptLog -Message "MCP servers configured in $mcpJsonPath"
    } else {
        Write-ColorOutput "  [WhatIf] Would write MCP configuration to: $mcpJsonPath" -Level 'Info'
    }

    # Summary
    Write-ColorOutput "`n=== Configuration Complete ===" -Level Information
    Write-ColorOutput "MCP Servers Configured (stdio transport):" -Level 'Info'
    Write-ColorOutput "  • aitherzero - AitherZero infrastructure automation" -Level 'Info'
    Write-ColorOutput "  • filesystem - Repository navigation and file operations" -Level 'Info'
    Write-ColorOutput "  • github - GitHub API for issues/PRs/metadata" -Level 'Info'
    Write-ColorOutput "  • git - Version control operations" -Level 'Info'
    Write-ColorOutput "  • sequential-thinking - Complex problem-solving" -Level 'Info'

    Write-ColorOutput "`nNext Steps:" -Level 'Info'
    Write-ColorOutput "1. Reload VS Code window (Ctrl+Shift+P → 'Developer: Reload Window')" -Level 'Info'
    Write-ColorOutput "2. VS Code will prompt you to trust each MCP server on first use" -Level 'Info'
    Write-ColorOutput "3. Open Copilot Chat (Ctrl+Alt+I) and use agent mode or # to access MCP tools" -Level 'Info'
    Write-ColorOutput "4. Try: 'List my GitHub issues' (auto-invokes GitHub MCP server)" -Level 'Info'
    Write-ColorOutput "5. Or type '#' to see available MCP tools" -Level 'Info'
    Write-ColorOutput "6. Verify with: ./automation-scripts/0215_Configure-MCPServers.ps1 -Verify" -Level 'Info'

    if (-not $env:GITHUB_TOKEN) {
        Write-ColorOutput "`nNote: Set GITHUB_TOKEN environment variable for GitHub MCP server" -Level 'Warning'
        Write-ColorOutput "  Or VS Code will prompt you for it when starting the server" -Level 'Warning'
    }

    Write-ColorOutput "`nDocumentation: https://code.visualstudio.com/library/copilot/customization/mcp-servers" -Level 'Info'

    exit 0

} catch {
    Write-ColorOutput "`n✗ Error: $($_.Exception.Message)" -Level 'Error'
    Write-ScriptLog -Message "MCP configuration failed: $($_.Exception.Message)" -Level 'Error'
    exit 1
}

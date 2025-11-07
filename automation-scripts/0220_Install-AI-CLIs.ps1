#Requires -Version 7.0

<#
.SYNOPSIS
    Install AI CLI tools (Claude, Gemini, Codex)
.DESCRIPTION
    Installs command-line interfaces for AI services.
    Supports Claude CLI, Gemini CLI, and OpenAI Codex CLI.
.PARAMETER Tool
    Which AI tool to install: Claude, Gemini, Codex, or All
.PARAMETER Force
    Force reinstallation even if already installed
.EXAMPLE
    ./0220_Install-AI-CLIs.ps1 -Tool Claude
.EXAMPLE
    ./0220_Install-AI-CLIs.ps1 -Tool All
.NOTES
    Stage: AI Tools
    Dependencies: Node.js (for npm-based tools)
    Tags: ai, claude, gemini, openai, cli, development
    
    API Keys required:
    - Claude: ANTHROPIC_API_KEY
    - Gemini: GOOGLE_API_KEY or GEMINI_API_KEY
    - Codex: OPENAI_API_KEY
#>

[CmdletBinding()]
param(
    [ValidateSet('Claude', 'Gemini', 'Codex', 'All')]
    [string]$Tool = 'All',
    
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

function Install-ClaudeCLI {
    Write-Host "[i] Installing Claude CLI..." -ForegroundColor Cyan
    
    # Check if Node.js is installed
    if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
        Write-Warning "Node.js/npm is required for Claude CLI. Please install Node.js first."
        return $false
    }
    
    try {
        # Install via npm
        npm install -g @anthropic-ai/cli 2>$null
        
        if (Get-Command claude -ErrorAction SilentlyContinue) {
            Write-Host "[✓] Claude CLI installed successfully" -ForegroundColor Green
            Write-Host "  Configure with: claude config" -ForegroundColor Gray
            Write-Host "  Set ANTHROPIC_API_KEY environment variable" -ForegroundColor Gray
            return $true
        }
        else {
            Write-Warning "Claude CLI installation completed but command not found"
            return $false
        }
    }
    catch {
        Write-Error "Failed to install Claude CLI: $($_.Exception.Message)"
        return $false
    }
}

function Install-GeminiCLI {
    Write-Host "[i] Installing Gemini CLI..." -ForegroundColor Cyan
    
    # Check if Node.js is installed
    if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
        Write-Warning "Node.js/npm is required for Gemini CLI. Please install Node.js first."
        return $false
    }
    
    try {
        # Install via npm (using Google's generative AI CLI)
        npm install -g @google/generative-ai-cli 2>$null
        
        if (Get-Command genai -ErrorAction SilentlyContinue) {
            Write-Host "[✓] Gemini CLI installed successfully" -ForegroundColor Green
            Write-Host "  Set GOOGLE_API_KEY or GEMINI_API_KEY environment variable" -ForegroundColor Gray
            return $true
        }
        else {
            Write-Warning "Gemini CLI installation completed but command not found"
            return $false
        }
    }
    catch {
        Write-Error "Failed to install Gemini CLI: $($_.Exception.Message)"
        return $false
    }
}

function Install-CodexCLI {
    Write-Host "[i] Installing OpenAI Codex CLI..." -ForegroundColor Cyan
    
    # Check if Node.js is installed
    if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
        Write-Warning "Node.js/npm is required for Codex CLI. Please install Node.js first."
        return $false
    }
    
    try {
        # Install via npm (OpenAI official CLI)
        npm install -g openai-cli 2>$null
        
        if (Get-Command openai -ErrorAction SilentlyContinue) {
            Write-Host "[✓] OpenAI CLI installed successfully" -ForegroundColor Green
            Write-Host "  Configure with: openai api configure" -ForegroundColor Gray
            Write-Host "  Set OPENAI_API_KEY environment variable" -ForegroundColor Gray
            return $true
        }
        else {
            Write-Warning "OpenAI CLI installation completed but command not found"
            return $false
        }
    }
    catch {
        Write-Error "Failed to install OpenAI CLI: $($_.Exception.Message)"
        return $false
    }
}

# Main execution
try {
    $results = @{}
    
    if ($Tool -eq 'Claude' -or $Tool -eq 'All') {
        $results['Claude'] = Install-ClaudeCLI
    }
    
    if ($Tool -eq 'Gemini' -or $Tool -eq 'All') {
        $results['Gemini'] = Install-GeminiCLI
    }
    
    if ($Tool -eq 'Codex' -or $Tool -eq 'All') {
        $results['Codex'] = Install-CodexCLI
    }
    
    # Summary
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  AI CLI Installation Summary" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
    
    foreach ($key in $results.Keys) {
        $status = if ($results[$key]) { "✓ Installed" } else { "✗ Failed" }
        $color = if ($results[$key]) { "Green" } else { "Red" }
        Write-Host "  $key : $status" -ForegroundColor $color
    }
    
    Write-Host ""
    Write-Host "  Next steps:" -ForegroundColor Yellow
    Write-Host "    • Set API keys as environment variables" -ForegroundColor Gray
    Write-Host "    • Claude: ANTHROPIC_API_KEY" -ForegroundColor Gray
    Write-Host "    • Gemini: GOOGLE_API_KEY or GEMINI_API_KEY" -ForegroundColor Gray
    Write-Host "    • Codex: OPENAI_API_KEY" -ForegroundColor Gray
    Write-Host ""
    
    $allSuccess = $results.Values | Where-Object { -not $_ } | Measure-Object | Select-Object -ExpandProperty Count
    exit $(if ($allSuccess -eq 0) { 0 } else { 1 })
}
catch {
    Write-Error "AI CLI installation failed: $($_.Exception.Message)"
    exit 1
}

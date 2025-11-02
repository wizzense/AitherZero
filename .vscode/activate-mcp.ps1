#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Quick command to reload VS Code and activate MCP servers.

.DESCRIPTION
    This script provides instructions for reloading VS Code to activate
    MCP servers. In a dev container/Codespaces environment, it prompts
    the user to manually reload.

.NOTES
    Since we can't programmatically reload VS Code window from a script,
    this provides clear instructions to the user.
#>

param()

Write-Host ""
Write-Host "════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  🚀 Activate MCP Servers in GitHub Copilot" -ForegroundColor Green
Write-Host "════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "MCP servers are built and configured!" -ForegroundColor White
Write-Host ""
Write-Host "To activate them in GitHub Copilot Chat:" -ForegroundColor Yellow
Write-Host ""
Write-Host "  1️⃣  Reload VS Code window:" -ForegroundColor White
Write-Host "      Press: " -NoNewline -ForegroundColor Gray
Write-Host "Ctrl+Shift+P" -NoNewline -ForegroundColor Cyan
Write-Host " (or " -NoNewline -ForegroundColor Gray
Write-Host "Cmd+Shift+P" -NoNewline -ForegroundColor Cyan
Write-Host " on macOS)" -ForegroundColor Gray
Write-Host "      Type:  " -NoNewline -ForegroundColor Gray
Write-Host "Developer: Reload Window" -ForegroundColor Cyan
Write-Host "      Press: " -NoNewline -ForegroundColor Gray
Write-Host "Enter" -ForegroundColor Cyan
Write-Host ""
Write-Host "  2️⃣  Check MCP servers loaded:" -ForegroundColor White
Write-Host "      Open:   " -NoNewline -ForegroundColor Gray
Write-Host "View > Output (Ctrl+Shift+U)" -ForegroundColor Cyan
Write-Host "      Select: " -NoNewline -ForegroundColor Gray
Write-Host "'GitHub Copilot'" -NoNewline -ForegroundColor Cyan
Write-Host " from dropdown" -ForegroundColor Gray
Write-Host "      Look for messages like:" -ForegroundColor Gray
Write-Host "        • [MCP] Starting server: aitherzero" -ForegroundColor DarkGray
Write-Host "        • [MCP] Server ready: aitherzero (8 tools)" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  3️⃣  Test in Copilot Chat:" -ForegroundColor White
Write-Host "      Open:  " -NoNewline -ForegroundColor Gray
Write-Host "Ctrl+Shift+I" -NoNewline -ForegroundColor Cyan
Write-Host " (or " -NoNewline -ForegroundColor Gray
Write-Host "Cmd+Shift+I" -NoNewline -ForegroundColor Cyan
Write-Host " on macOS)" -ForegroundColor Gray
Write-Host "      Type:  " -NoNewline -ForegroundColor Gray
Write-Host "@workspace List all automation scripts" -ForegroundColor Cyan
Write-Host ""
Write-Host "════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "Available MCP Servers:" -ForegroundColor Yellow
Write-Host "  • " -NoNewline -ForegroundColor Gray
Write-Host "aitherzero" -NoNewline -ForegroundColor Green
Write-Host "       - AitherZero automation (8 tools)" -ForegroundColor Gray
Write-Host "  • " -NoNewline -ForegroundColor Gray
Write-Host "filesystem" -NoNewline -ForegroundColor Green
Write-Host "       - Repository file access" -ForegroundColor Gray
Write-Host "  • " -NoNewline -ForegroundColor Gray
Write-Host "github" -NoNewline -ForegroundColor Green
Write-Host "           - GitHub API integration" -ForegroundColor Gray
Write-Host "  • " -NoNewline -ForegroundColor Gray
Write-Host "git" -NoNewline -ForegroundColor Green
Write-Host "              - Git operations" -ForegroundColor Gray
Write-Host "  • " -NoNewline -ForegroundColor Gray
Write-Host "powershell-docs" -NoNewline -ForegroundColor Green
Write-Host "  - PowerShell documentation" -ForegroundColor Gray
Write-Host "  • " -NoNewline -ForegroundColor Gray
Write-Host "sequential-thinking" -NoNewline -ForegroundColor Green
Write-Host " - Complex problem solving" -ForegroundColor Gray
Write-Host ""
Write-Host "════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

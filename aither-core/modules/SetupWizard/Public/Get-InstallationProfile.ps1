function Get-InstallationProfile {
    <#
    .SYNOPSIS
        Interactive profile selection for AitherZero installation
    .DESCRIPTION
        Presents an interactive menu for users to select their preferred installation profile
    .EXAMPLE
        $profile = Get-InstallationProfile
    #>
    [CmdletBinding()]
    param()

    # In non-interactive environments, return default
    if ([System.Console]::IsInputRedirected -or $env:NO_PROMPT -or $global:WhatIfPreference) {
        Write-Host "Non-interactive environment detected, using developer profile" -ForegroundColor Yellow
        return 'developer'
    }

    try {
        Write-Host ""
        Write-Host "  📦 Choose your installation profile:" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "    1. 🏃 Minimal     - Core AitherZero + Infrastructure tools only" -ForegroundColor Green
        Write-Host "    2. 👨‍💻 Developer   - Minimal + AI tools + Development utilities" -ForegroundColor Blue
        Write-Host "    3. 🚀 Full        - Everything including advanced integrations" -ForegroundColor Magenta
        Write-Host ""

        do {
            $choice = Read-Host "  Enter your choice (1-3)"
            switch ($choice) {
                '1' { return 'minimal' }
                '2' { return 'developer' }
                '3' { return 'full' }
                default {
                    Write-Host "  ❌ Invalid choice. Please enter 1, 2, or 3." -ForegroundColor Red
                }
            }
        } while ($true)

    } catch {
        Write-Warning "Failed to get interactive profile selection: $_"
        Write-Host "Defaulting to developer profile" -ForegroundColor Yellow
        return 'developer'
    }
}

Export-ModuleMember -Function Get-InstallationProfile
#!/usr/bin/env pwsh
#Requires -Version 7.0
<#
.SYNOPSIS
    Installs or uninstalls the global 'aitherzero' command
.DESCRIPTION
    This script manages the installation of the global aitherzero launcher,
    making it accessible from anywhere on the system.
.PARAMETER Action
    Action to perform: Install or Uninstall
.PARAMETER InstallPath
    Path to AitherZero installation (defaults to script location)
.EXAMPLE
    ./Install-GlobalCommand.ps1 -Action Install
.EXAMPLE
    ./Install-GlobalCommand.ps1 -Action Uninstall
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [ValidateSet('Install', 'Uninstall')]
    [string]$Action,

    [Parameter()]
    [string]$InstallPath = (Split-Path $PSScriptRoot -Parent)
)

# Determine platform
$IsWindowsPlatform = $IsWindows -or ($PSVersionTable.PSVersion.Major -lt 6)

function Get-GlobalBinPath {
    <#
    .SYNOPSIS
        Gets the appropriate global bin directory for the current platform
    #>
    if ($IsWindowsPlatform) {
        # Windows: Use a custom bin directory in LocalAppData
        $binPath = Join-Path $env:LOCALAPPDATA "AitherZero\bin"
    } else {
        # Linux/macOS: Use ~/.local/bin which is typically in PATH
        $binPath = Join-Path $HOME ".local/bin"
    }

    return $binPath
}

function Test-PathInEnvironment {
    <#
    .SYNOPSIS
        Checks if a path is in the system PATH
    #>
    param([string]$PathToCheck)

    $pathSeparator = if ($IsWindowsPlatform) { ';' } else { ':' }
    $currentPath = [Environment]::GetEnvironmentVariable('PATH', 'User')
    
    if (-not $currentPath) {
        $currentPath = $env:PATH
    }

    $paths = $currentPath -split $pathSeparator
    return ($paths -contains $PathToCheck)
}

function Add-ToUserPath {
    <#
    .SYNOPSIS
        Adds a directory to the user's PATH environment variable
    #>
    param([string]$PathToAdd)

    if (Test-PathInEnvironment -PathToCheck $PathToAdd) {
        Write-Verbose "Path already in environment: $PathToAdd"
        return $true
    }

    try {
        $pathSeparator = if ($IsWindowsPlatform) { ';' } else { ':' }
        
        if ($IsWindowsPlatform) {
            # Windows: Update user PATH in registry
            $currentPath = [Environment]::GetEnvironmentVariable('PATH', 'User')
            $newPath = if ($currentPath) {
                "$PathToAdd$pathSeparator$currentPath"
            } else {
                $PathToAdd
            }
            
            [Environment]::SetEnvironmentVariable('PATH', $newPath, 'User')
            
            # Update current session
            $env:PATH = "$PathToAdd$pathSeparator$env:PATH"
            
            Write-Host "Added to PATH (requires new terminal): $PathToAdd" -ForegroundColor Green
        } else {
            # Linux/macOS: Update shell profile
            $shellProfiles = @(
                (Join-Path $HOME ".bashrc"),
                (Join-Path $HOME ".zshrc"),
                (Join-Path $HOME ".profile")
            )

            $exportLine = "export PATH=`"$PathToAdd`$pathSeparator`$PATH`""
            $addedTo = @()

            foreach ($shellProfile in $shellProfiles) {
                if (Test-Path $shellProfile) {
                    $content = Get-Content $shellProfile -Raw -ErrorAction SilentlyContinue
                    if ($content -notmatch [regex]::Escape($PathToAdd)) {
                        Add-Content -Path $shellProfile -Value "`n# AitherZero global command`n$exportLine"
                        $addedTo += $shellProfile
                    }
                }
            }

            # Update current session
            $env:PATH = "$PathToAdd$pathSeparator$env:PATH"

            if ($addedTo.Count -gt 0) {
                Write-Host "Added to PATH in: $($addedTo -join ', ')" -ForegroundColor Green
                Write-Host "Run 'source ~/.bashrc' or 'source ~/.zshrc' to update current shell" -ForegroundColor Yellow
            }
        }
        
        return $true
    } catch {
        Write-Warning "Failed to add to PATH: $_"
        return $false
    }
}

function Remove-FromUserPath {
    <#
    .SYNOPSIS
        Removes a directory from the user's PATH environment variable
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param([string]$PathToRemove)

    try {
        $pathSeparator = if ($IsWindowsPlatform) { ';' } else { ':' }
        
        if ($IsWindowsPlatform) {
            # Windows: Update user PATH in registry
            $currentPath = [Environment]::GetEnvironmentVariable('PATH', 'User')
            if ($currentPath) {
                $paths = $currentPath -split $pathSeparator
                $newPaths = $paths | Where-Object { $_ -ne $PathToRemove }
                $newPath = $newPaths -join $pathSeparator
                
                [Environment]::SetEnvironmentVariable('PATH', $newPath, 'User')
                
                # Update current session
                $env:PATH = ($env:PATH -split $pathSeparator | Where-Object { $_ -ne $PathToRemove }) -join $pathSeparator
                
                Write-Host "Removed from PATH: $PathToRemove" -ForegroundColor Green
            }
        } else {
            # Linux/macOS: Update shell profiles
            $shellProfiles = @(
                (Join-Path $HOME ".bashrc"),
                (Join-Path $HOME ".zshrc"),
                (Join-Path $HOME ".profile")
            )

            foreach ($shellProfile in $shellProfiles) {
                if (Test-Path $shellProfile) {
                    $content = Get-Content $shellProfile -Raw -ErrorAction SilentlyContinue
                    if ($content -match [regex]::Escape($PathToRemove)) {
                        # Remove lines containing the path
                        $lines = $content -split "`n" | Where-Object { $_ -notmatch [regex]::Escape($PathToRemove) }
                        Set-Content -Path $shellProfile -Value ($lines -join "`n")
                        Write-Host "Removed from PATH in: $shellProfile" -ForegroundColor Green
                    }
                }
            }
        }
        
        return $true
    } catch {
        Write-Warning "Failed to remove from PATH: $_"
        return $false
    }
}

function Install-GlobalCommand {
    <#
    .SYNOPSIS
        Installs the global aitherzero command
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param([string]$AitherZeroRoot)

    Write-Host "`nInstalling global 'aitherzero' command..." -ForegroundColor Cyan

    # Get the global bin path
    $binPath = Get-GlobalBinPath
    Write-Verbose "Using bin path: $binPath"

    # Create bin directory if it doesn't exist
    if (-not (Test-Path $binPath)) {
        if ($PSCmdlet.ShouldProcess($binPath, "Create directory")) {
            New-Item -ItemType Directory -Path $binPath -Force | Out-Null
            Write-Host "Created bin directory: $binPath" -ForegroundColor Green
        }
    }

    # Copy the launcher script
    $launcherSource = Join-Path $AitherZeroRoot "tools/aitherzero-launcher.ps1"
    
    if (-not (Test-Path $launcherSource)) {
        Write-Error "Launcher script not found at: $launcherSource"
        return $false
    }

    if ($IsWindowsPlatform) {
        # Windows: Create both .ps1 and wrapper files
        $launcherDest = Join-Path $binPath "aitherzero.ps1"
        $wrapperDest = Join-Path $binPath "aitherzero.cmd"
        
        if ($PSCmdlet.ShouldProcess($launcherDest, "Copy launcher")) {
            Copy-Item -Path $launcherSource -Destination $launcherDest -Force
            Write-Host "Installed launcher: $launcherDest" -ForegroundColor Green
        }

        # Create CMD wrapper for Windows
        $wrapperContent = @"
@echo off
pwsh -NoProfile -ExecutionPolicy Bypass -File "$launcherDest" %*
"@
        if ($PSCmdlet.ShouldProcess($wrapperDest, "Create CMD wrapper")) {
            Set-Content -Path $wrapperDest -Value $wrapperContent -Encoding ASCII
            Write-Host "Created CMD wrapper: $wrapperDest" -ForegroundColor Green
        }
    } else {
        # Linux/macOS: Create executable script
        $launcherDest = Join-Path $binPath "aitherzero"
        
        if ($PSCmdlet.ShouldProcess($launcherDest, "Copy launcher")) {
            Copy-Item -Path $launcherSource -Destination $launcherDest -Force
            
            # Make it executable (PowerShell 7+ cross-platform approach)
            try {
                [System.IO.File]::SetUnixFileMode($launcherDest, @(
                    'UserRead', 'UserWrite', 'UserExecute',
                    'GroupRead', 'GroupExecute',
                    'OtherRead', 'OtherExecute'
                ))
                Write-Host "Set executable permissions using SetUnixFileMode: $launcherDest" -ForegroundColor Green
            } catch {
                # Fallback to chmod if SetUnixFileMode is unavailable
                Write-Host "SetUnixFileMode failed, falling back to chmod..." -ForegroundColor Yellow
                chmod +x $launcherDest
                Write-Host "Set executable permissions using chmod: $launcherDest" -ForegroundColor Green
            }
            Write-Host "Installed launcher: $launcherDest" -ForegroundColor Green
        }
    }

    # Set AITHERZERO_ROOT environment variable
    try {
        if ($IsWindowsPlatform) {
            [Environment]::SetEnvironmentVariable('AITHERZERO_ROOT', $AitherZeroRoot, 'User')
            $env:AITHERZERO_ROOT = $AitherZeroRoot
            Write-Host "Set AITHERZERO_ROOT environment variable" -ForegroundColor Green
        } else {
            # Linux/macOS: Add to shell profiles
            $shellProfiles = @(
                (Join-Path $HOME ".bashrc"),
                (Join-Path $HOME ".zshrc"),
                (Join-Path $HOME ".profile")
            )

            $exportLine = "export AITHERZERO_ROOT=`"$AitherZeroRoot`""
            
            foreach ($shellProfile in $shellProfiles) {
                if (Test-Path $shellProfile) {
                    $content = Get-Content $shellProfile -Raw -ErrorAction SilentlyContinue
                    if ($content -notmatch 'AITHERZERO_ROOT') {
                        Add-Content -Path $shellProfile -Value "`n$exportLine"
                    }
                }
            }
            
            $env:AITHERZERO_ROOT = $AitherZeroRoot
            Write-Host "Set AITHERZERO_ROOT in shell profiles" -ForegroundColor Green
        }
    } catch {
        Write-Warning "Failed to set AITHERZERO_ROOT: $_"
    }

    # Add bin path to PATH if needed
    if (-not (Test-PathInEnvironment -PathToCheck $binPath)) {
        Write-Host "Adding bin directory to PATH..." -ForegroundColor Yellow
        Add-ToUserPath -PathToAdd $binPath
    } else {
        Write-Host "Bin directory already in PATH" -ForegroundColor Green
    }

    Write-Host "`n✓ Global 'aitherzero' command installed successfully!" -ForegroundColor Green
    Write-Host "  You can now run 'aitherzero' from anywhere" -ForegroundColor Cyan
    
    if (-not $IsWindowsPlatform) {
        Write-Host "`nNote: Run 'source ~/.bashrc' or open a new terminal for PATH changes to take effect" -ForegroundColor Yellow
    } else {
        Write-Host "`nNote: Open a new terminal for PATH changes to take effect" -ForegroundColor Yellow
    }

    return $true
}

function Uninstall-GlobalCommand {
    <#
    .SYNOPSIS
        Uninstalls the global aitherzero command
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param()
    Write-Host "`nUninstalling global 'aitherzero' command..." -ForegroundColor Cyan

    # Get the global bin path
    $binPath = Get-GlobalBinPath
    $removed = $false

    if ($IsWindowsPlatform) {
        $launcherPath = Join-Path $binPath "aitherzero.ps1"
        $wrapperPath = Join-Path $binPath "aitherzero.cmd"
        
        if (Test-Path $launcherPath) {
            if ($PSCmdlet.ShouldProcess($launcherPath, "Remove launcher")) {
                Remove-Item -Path $launcherPath -Force
                Write-Host "Removed: $launcherPath" -ForegroundColor Green
                $removed = $true
            }
        }
        
        if (Test-Path $wrapperPath) {
            if ($PSCmdlet.ShouldProcess($wrapperPath, "Remove wrapper")) {
                Remove-Item -Path $wrapperPath -Force
                Write-Host "Removed: $wrapperPath" -ForegroundColor Green
                $removed = $true
            }
        }
    } else {
        $launcherPath = Join-Path $binPath "aitherzero"
        
        if (Test-Path $launcherPath) {
            if ($PSCmdlet.ShouldProcess($launcherPath, "Remove launcher")) {
                Remove-Item -Path $launcherPath -Force
                Write-Host "Removed: $launcherPath" -ForegroundColor Green
                $removed = $true
            }
        }
    }

    # Optionally remove from PATH (keeping it in case other tools use it)
    # Remove-FromUserPath -PathToRemove $binPath

    # Remove AITHERZERO_ROOT environment variable
    try {
        if ($IsWindowsPlatform) {
            [Environment]::SetEnvironmentVariable('AITHERZERO_ROOT', $null, 'User')
            Remove-Item Env:\AITHERZERO_ROOT -ErrorAction SilentlyContinue
            Write-Host "Removed AITHERZERO_ROOT environment variable" -ForegroundColor Green
        } else {
            # Note: We're not removing from shell profiles automatically to avoid breaking
            # user customizations. Users should manually remove if desired.
            Write-Host "Note: AITHERZERO_ROOT in shell profiles not automatically removed" -ForegroundColor Yellow
            Write-Host "  Remove manually if desired from ~/.bashrc, ~/.zshrc, ~/.profile" -ForegroundColor Gray
        }
    } catch {
        Write-Warning "Failed to remove AITHERZERO_ROOT: $_"
    }

    if ($removed) {
        Write-Host "`n✓ Global 'aitherzero' command uninstalled" -ForegroundColor Green
    } else {
        Write-Host "`nNo global 'aitherzero' command found to remove" -ForegroundColor Yellow
    }

    return $true
}

# Main execution
try {
    switch ($Action) {
        'Install' {
            Install-GlobalCommand -AitherZeroRoot $InstallPath
        }
        'Uninstall' {
            Uninstall-GlobalCommand
        }
    }
} catch {
    Write-Error "Failed to $Action global command: $_"
    Write-Error $_.ScriptStackTrace
    exit 1
}

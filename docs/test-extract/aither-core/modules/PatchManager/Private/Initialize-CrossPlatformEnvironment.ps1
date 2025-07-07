#Requires -Version 7.0

<#
.SYNOPSIS
    Initialize cross-platform environment variables for PatchManager

.DESCRIPTION
    Sets up PROJECT_ROOT and other environment variables needed for cross-platform path resolution.
    This ensures that all scripts can work regardless of Windows, Linux, or macOS environment.

.NOTES
    This function is called automatically by PatchManager to ensure environment consistency.
#>

function Initialize-CrossPlatformEnvironment {
    [CmdletBinding()]
    param()

    begin {
        Write-Verbose 'Initializing cross-platform environment variables...'
    }

    process {
        try {
            # Detect project root using multiple strategies
            $projectRoot = $null            # Strategy 1: Environment variable (if already set and valid)
            if ($env:PROJECT_ROOT -and (Test-Path $env:PROJECT_ROOT) -and (Test-Path (Join-Path $env:PROJECT_ROOT 'aither-core'))) {
                $projectRoot = $env:PROJECT_ROOT
                Write-Verbose "Using existing valid PROJECT_ROOT: $projectRoot"
            }

            # Strategy 2: Look for PROJECT-MANIFEST.json starting from current location
            if (-not $projectRoot) {
                $current = Get-Location
                while ($current -and $current.Path -ne '/' -and $current.Path -notmatch '^[A-Z]:\\$') {
                    try {
                        $currentPath = if ($current -is [System.Management.Automation.PathInfo]) { $current.Path } else { $current.ToString() }
                        $manifestPath = Join-Path $currentPath 'PROJECT-MANIFEST.json'
                        if (Test-Path $manifestPath) {
                            $projectRoot = $currentPath
                            Write-Verbose "Found PROJECT-MANIFEST.json at: $projectRoot"
                            break
                        }
                        $parentPath = Split-Path $currentPath -Parent
                        if (-not $parentPath -or $parentPath -eq $currentPath) { break }
                        $current = Get-Item $parentPath -ErrorAction SilentlyContinue
                        if (-not $current) { break }
                    } catch {
                        Write-Verbose "Error in path detection: $_"
                        break
                    }
                }
            }

            # Strategy 3: Use PSScriptRoot-based detection (for modules)
            if (-not $projectRoot) {
                $moduleRoot = $PSScriptRoot
                # Go up from PatchManager/Private to project root
                if ($moduleRoot) {
                    try {
                        # Go up three levels: Private -> PatchManager -> modules -> aither-core -> project root
                        $step1 = Split-Path $moduleRoot -Parent  # PatchManager
                        $step2 = Split-Path $step1 -Parent       # modules
                        $step3 = Split-Path $step2 -Parent       # aither-core
                        $candidate = Split-Path $step3 -Parent   # project root

                        if ($candidate -and (Test-Path (Join-Path $candidate 'aither-core'))) {
                            $projectRoot = $candidate
                            Write-Verbose "Detected project root via module location: $projectRoot"
                        }
                    } catch {
                        Write-Verbose "Failed to detect project root via module location: $_"
                    }
                }
            }            # Strategy 4: Hard-coded known paths (last resort)
            if (-not $projectRoot) {
                $knownPaths = @(
                    "$env:USERPROFILE\OneDrive\Documents\0. wizzense\AitherZero", # Prioritize correct path
                    '/workspaces/AitherZero',
                    'C:\workspaces\AitherZero',
                    "$env:USERPROFILE\Documents\0. wizzense\AitherZero",
                    "$HOME/AitherZero"
                )

                foreach ($path in $knownPaths) {
                    if (Test-Path $path) {
                        $projectRoot = $path
                        Write-Verbose "Using known path: $projectRoot"
                        break
                    }
                }
            }

            # Strategy 5: Use current location if it contains aither-core
            if (-not $projectRoot) {
                try {
                    $currentPath = (Get-Location).Path
                    if ($currentPath -and (Test-Path (Join-Path $currentPath 'aither-core'))) {
                        $projectRoot = $currentPath
                        Write-Verbose "Using current directory with aither-core: $projectRoot"
                    }
                } catch {
                    Write-Verbose "Error checking current directory: $_"
                }
            }

            # Final fallback
            if (-not $projectRoot) {
                $projectRoot = (Get-Location).Path
                Write-Warning "Could not detect project root, using current directory: $projectRoot"
            }

            # Ensure $projectRoot is a string path
            if ($projectRoot -is [System.Management.Automation.PathInfo]) {
                $projectRoot = $projectRoot.Path
            }

            # Set environment variables for cross-platform use
            $env:PROJECT_ROOT = $projectRoot
            $env:PWSH_MODULES_PATH = Join-Path $projectRoot 'aither-core' 'modules'
            $env:PROJECT_SCRIPTS_PATH = Join-Path $projectRoot 'scripts'

            # Platform-specific settings
            if ($IsWindows) {
                $env:PLATFORM = 'Windows'
                $env:PATH_SEP = '\'
            } elseif ($IsLinux) {
                $env:PLATFORM = 'Linux'
                $env:PATH_SEP = '/'
            } elseif ($IsMacOS) {
                $env:PLATFORM = 'macOS'
                $env:PATH_SEP = '/'
            } else {
                $env:PLATFORM = 'Unknown'
                $env:PATH_SEP = '/'
            }

            Write-Host 'Cross-platform environment initialized:' -ForegroundColor Green
            Write-Host "  PROJECT_ROOT: $env:PROJECT_ROOT" -ForegroundColor Cyan
            Write-Host "  PLATFORM: $env:PLATFORM" -ForegroundColor Cyan
            Write-Host "  PWSH_MODULES_PATH: $env:PWSH_MODULES_PATH" -ForegroundColor Cyan

            return @{
                Success     = $true
                ProjectRoot = $env:PROJECT_ROOT
                Platform    = $env:PLATFORM
                ModulesPath = $env:PWSH_MODULES_PATH
            }

        } catch {
            Write-Error "Failed to initialize cross-platform environment: $($_.Exception.Message)"
            return @{
                Success = $false
                Error   = $_.Exception.Message
            }
        }
    }
}

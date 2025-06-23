#Requires -Version 7.0

<#
.SYNOPSIS
    Find the project root directory using multiple detection strategies (SHARED UTILITY)

.DESCRIPTION
    This function implements robust project root detection that works regardless of
    where it's called from within the project structure. It uses multiple strategies
    to locate the project root, making all scripts and tests work reliably from any
    subdirectory or file location.

    This is a SHARED UTILITY function available to all modules, scripts, and tests.
    It should be dot-sourced or imported by any component that needs reliable
    project root detection.

.PARAMETER StartPath
    Optional starting path for detection. Defaults to current location or calling script location.

.PARAMETER Force
    Force re-detection even if PROJECT_ROOT environment variable is already set

.EXAMPLE
    # From any module or script:
    . "$PSScriptRoot/../shared/Find-ProjectRoot.ps1"
    $projectRoot = Find-ProjectRoot

.EXAMPLE
    # Force detection from specific path:
    $projectRoot = Find-ProjectRoot -StartPath $PSScriptRoot -Force

.EXAMPLE
    # From tests:
    . "$PSScriptRoot/../../../aither-core/shared/Find-ProjectRoot.ps1"
    $projectRoot = Find-ProjectRoot

.NOTES
    Detection strategies (in order):
    1. Environment variable PROJECT_ROOT (unless -Force)
    2. Look for characteristic files (aither-core, .git, etc.) starting from current/start path
    3. PSScriptRoot-based detection for modules
    4. Git repository root detection
    5. Known path patterns for AitherZero/AitherLabs/Aitherium repos
    6. Current directory as fallback

    This function is designed to be called from anywhere in the project structure
    and will reliably find the project root.

    USAGE PATTERN FOR MODULES:
    Add this to the top of any module that needs project root detection:
    . "$PSScriptRoot/../../shared/Find-ProjectRoot.ps1"
    $script:ProjectRoot = Find-ProjectRoot

    USAGE PATTERN FOR TESTS:
    Add this to the top of any test file:
    . "$PSScriptRoot/../../../aither-core/shared/Find-ProjectRoot.ps1"
    $ProjectRoot = Find-ProjectRoot
#>

function Find-ProjectRoot {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$StartPath,

        [Parameter()]
        [switch]$Force
    )

    begin {
        Write-Verbose "Finding project root..."

        # Determine starting path
        if (-not $StartPath) {
            if ($PSScriptRoot) {
                $StartPath = $PSScriptRoot
            } else {
                $StartPath = (Get-Location).Path
            }
        }

        Write-Verbose "Starting detection from: $StartPath"
    }

    process {
        try {
            $projectRoot = $null

            # Strategy 1: Environment variable (if already set and not forcing)
            if (-not $Force -and $env:PROJECT_ROOT -and (Test-Path $env:PROJECT_ROOT)) {
                # Verify it's actually a project root by checking for characteristic files
                $aithercorePath = Join-Path $env:PROJECT_ROOT "aither-core"
                $gitPath = Join-Path $env:PROJECT_ROOT ".git"

                if ((Test-Path $aithercorePath) -or (Test-Path $gitPath)) {
                    $projectRoot = $env:PROJECT_ROOT
                    Write-Verbose "Using existing PROJECT_ROOT: $projectRoot"
                }
            }

            # Strategy 2: Look for characteristic files starting from StartPath
            if (-not $projectRoot) {
                $current = Get-Item $StartPath -ErrorAction SilentlyContinue

                while ($current -and $current.FullName -ne "/" -and $current.FullName -notmatch "^[A-Z]:\\?$") {
                    $currentPath = $current.FullName

                    # Check for characteristic project files/directories
                    $characteristicPaths = @(
                        "aither-core",
                        ".git",
                        "README.md",
                        "go.ps1",
                        "kicker-git.ps1"
                    )

                    $foundCharacteristic = $false
                    foreach ($charPath in $characteristicPaths) {
                        if (Test-Path (Join-Path $currentPath $charPath)) {
                            $foundCharacteristic = $true
                            break
                        }
                    }
                      # Additional check: if we find aither-core, this is definitely the root
                    if (Test-Path (Join-Path $currentPath "aither-core")) {
                        $projectRoot = $currentPath
                        Write-Verbose "Found project root via aither-core: $projectRoot"
                        break
                    }

                    # If we found multiple characteristic files, check if this could be the root
                    if ($foundCharacteristic) {
                        # Make sure we're not in a subdirectory that just happens to have some files
                        # Look for the definitive project root indicators
                        $definitiveFiles = @("README.md", "go.ps1", ".git")
                        $foundDefinitive = 0
                        foreach ($defFile in $definitiveFiles) {
                            if (Test-Path (Join-Path $currentPath $defFile)) {
                                $foundDefinitive++
                            }
                        }

                        # If we found multiple definitive files, this is likely the root
                        if ($foundDefinitive -ge 2) {
                            $projectRoot = $currentPath
                            Write-Verbose "Found project root via characteristic files: $projectRoot"
                            break
                        }
                    }

                    # Move up one directory
                    $parentPath = Split-Path $currentPath -Parent
                    if (-not $parentPath -or $parentPath -eq $currentPath) {
                        break
                    }
                    $current = Get-Item $parentPath -ErrorAction SilentlyContinue
                }
            }

            # Strategy 3: PSScriptRoot-based detection (for modules)
            if (-not $projectRoot -and $PSScriptRoot) {
                $moduleRoot = $PSScriptRoot

                # Common module path patterns to try
                $pathsToTry = @(
                    # From shared directory
                    (Split-Path (Split-Path $moduleRoot -Parent) -Parent),
                    # From PatchManager/Private or any module
                    (Split-Path (Split-Path (Split-Path $moduleRoot -Parent) -Parent) -Parent),
                    # From any module/Public or module/Private
                    (Split-Path (Split-Path (Split-Path $moduleRoot -Parent) -Parent) -Parent),
                    # From module root
                    (Split-Path (Split-Path $moduleRoot -Parent) -Parent),
                    # From tests directory structure
                    (Split-Path (Split-Path (Split-Path (Split-Path $moduleRoot -Parent) -Parent) -Parent) -Parent)
                )

                foreach ($candidatePath in $pathsToTry) {
                    if ($candidatePath -and (Test-Path $candidatePath)) {
                        if (Test-Path (Join-Path $candidatePath "aither-core")) {
                            $projectRoot = $candidatePath
                            Write-Verbose "Detected project root via module structure: $projectRoot"
                            break
                        }
                    }
                }
            }

            # Strategy 4: Git repository root detection
            if (-not $projectRoot) {
                try {
                    Push-Location $StartPath -ErrorAction SilentlyContinue
                    $gitRoot = git rev-parse --show-toplevel 2>$null
                    if ($gitRoot -and (Test-Path $gitRoot)) {
                        # Verify this is our project by checking for aither-core
                        if (Test-Path (Join-Path $gitRoot "aither-core")) {
                            $projectRoot = $gitRoot
                            Write-Verbose "Found project root via git: $projectRoot"
                        }
                    }
                } catch {
                    Write-Verbose "Git detection failed: $($_.Exception.Message)"
                } finally {
                    Pop-Location -ErrorAction SilentlyContinue
                }
            }

            # Strategy 5: Known path patterns
            if (-not $projectRoot) {
                $knownPatterns = @(
                    "*AitherZero*",
                    "*AitherLabs*",
                    "*Aitherium*",
                    "*opentofu-lab-automation*"
                )

                $currentSearchPath = $StartPath

                foreach ($pattern in $knownPatterns) {
                    # Check if current path contains the pattern
                    if ($currentSearchPath -like $pattern) {
                        # Find the actual project root by looking for aither-core
                        $testPath = $currentSearchPath
                        while ($testPath -and $testPath -ne "/" -and $testPath -notmatch "^[A-Z]:\\?$") {
                            if (Test-Path (Join-Path $testPath "aither-core")) {
                                $projectRoot = $testPath
                                Write-Verbose "Found project root via pattern matching: $projectRoot"
                                break 2
                            }
                            $testPath = Split-Path $testPath -Parent
                        }
                    }
                }
            }

            # Strategy 6: Common development locations (last resort)
            if (-not $projectRoot) {
                $commonPaths = @(
                    "/workspaces/AitherZero",
                    "C:/workspaces/AitherZero",
                    "$env:USERPROFILE/OneDrive/Documents/0. wizzense/AitherZero",
                    "$env:USERPROFILE/Documents/0. wizzense/AitherZero",
                    "$HOME/AitherZero",
                    "/workspaces/AitherLabs",
                    "C:/workspaces/AitherLabs",
                    "$env:USERPROFILE/AitherLabs",
                    "$HOME/AitherLabs",
                    "/workspaces/Aitherium",
                    "C:/workspaces/Aitherium",
                    "$env:USERPROFILE/Aitherium",
                    "$HOME/Aitherium"
                )

                foreach ($path in $commonPaths) {
                    $expandedPath = $ExecutionContext.InvokeCommand.ExpandString($path)
                    if (Test-Path $expandedPath) {
                        if (Test-Path (Join-Path $expandedPath "aither-core")) {
                            $projectRoot = $expandedPath
                            Write-Verbose "Found project root via common paths: $projectRoot"
                            break
                        }
                    }
                }
            }

            # Final fallback: use current directory but warn
            if (-not $projectRoot) {
                $projectRoot = (Get-Location).Path
                Write-Warning "Could not detect project root reliably. Using current directory: $projectRoot"
                Write-Warning "Consider setting PROJECT_ROOT environment variable or running from project directory."
            }

            # Normalize path (resolve relative paths, etc.)
            try {
                $projectRoot = (Resolve-Path $projectRoot).Path
            } catch {
                # If resolve fails, use as-is
                Write-Verbose "Could not resolve path, using as-is: $projectRoot"
            }

            # Set environment variable for future use
            $env:PROJECT_ROOT = $projectRoot
            Write-Verbose "Project root set: $projectRoot"

            return $projectRoot

        } catch {
            Write-Error "Failed to detect project root: $($_.Exception.Message)"
            throw
        }
    }
}

# Note: Export-ModuleMember is only needed when this file is imported as a module
# When dot-sourced directly, the function is automatically available

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
        Write-Verbose "Initializing cross-platform environment variables..."
    }
    
    process {
        try {
            # Detect project root using multiple strategies
            $projectRoot = $null
            
            # Strategy 1: Environment variable (if already set)
            if ($env:PROJECT_ROOT -and (Test-Path $env:PROJECT_ROOT)) {
                $projectRoot = $env:PROJECT_ROOT
                Write-Verbose "Using existing PROJECT_ROOT: $projectRoot"
            }
            
            # Strategy 2: Look for PROJECT-MANIFEST.json starting from current location
            if (-not $projectRoot) {
                $current = Get-Location
                while ($current -and $current.Path -ne "/" -and $current.Path -notmatch "^[A-Z]:\\$") {
                    $manifestPath = Join-Path $current.Path "PROJECT-MANIFEST.json"
                    if (Test-Path $manifestPath) {
                        $projectRoot = $current.Path
                        Write-Verbose "Found PROJECT-MANIFEST.json at: $projectRoot"
                        break
                    }
                    $current = Split-Path $current.Path -Parent
                    if (-not $current) { break }
                    $current = Get-Item $current -ErrorAction SilentlyContinue
                }
            }
            
            # Strategy 3: Use PSScriptRoot-based detection (for modules)
            if (-not $projectRoot) {
                $moduleRoot = $PSScriptRoot
                # Go up from PatchManager/Private to project root
                $candidate = Split-Path (Split-Path (Split-Path $moduleRoot -Parent) -Parent) -Parent
                if (Test-Path (Join-Path $candidate "PROJECT-MANIFEST.json")) {
                    $projectRoot = $candidate
                    Write-Verbose "Detected project root via module location: $projectRoot"
                }
            }
            
            # Strategy 4: Hard-coded known paths (last resort)
            if (-not $projectRoot) {
                $knownPaths = @(
                    "/workspaces/opentofu-lab-automation",
                    "C:\workspaces\opentofu-lab-automation",
                    "$env:USERPROFILE\Documents\opentofu-lab-automation",
                    "$HOME/opentofu-lab-automation"
                )
                
                foreach ($path in $knownPaths) {
                    if (Test-Path $path) {
                        $projectRoot = $path
                        Write-Verbose "Using known path: $projectRoot"
                        break
                    }
                }
            }
            
            # Final fallback
            if (-not $projectRoot) {
                $projectRoot = Get-Location
                Write-Warning "Could not detect project root, using current directory: $projectRoot"
            }
            
            # Set environment variables for cross-platform use
            $env:PROJECT_ROOT = $projectRoot
            $env:PWSH_MODULES_PATH = Join-Path $projectRoot "src" "pwsh" "modules"
            $env:PROJECT_SCRIPTS_PATH = Join-Path $projectRoot "scripts"
            
            # Platform-specific settings
            if ($IsWindows) {
                $env:PLATFORM = "Windows"
                $env:PATH_SEP = "\"
            } elseif ($IsLinux) {
                $env:PLATFORM = "Linux"
                $env:PATH_SEP = "/"
            } elseif ($IsMacOS) {
                $env:PLATFORM = "macOS"
                $env:PATH_SEP = "/"
            } else {
                $env:PLATFORM = "Unknown"
                $env:PATH_SEP = "/"
            }
            
            Write-Host "Cross-platform environment initialized:" -ForegroundColor Green
            Write-Host "  PROJECT_ROOT: $env:PROJECT_ROOT" -ForegroundColor Cyan
            Write-Host "  PLATFORM: $env:PLATFORM" -ForegroundColor Cyan
            Write-Host "  PWSH_MODULES_PATH: $env:PWSH_MODULES_PATH" -ForegroundColor Cyan
            
            return @{
                Success = $true
                ProjectRoot = $env:PROJECT_ROOT
                Platform = $env:PLATFORM
                ModulesPath = $env:PWSH_MODULES_PATH
            }
            
        } catch {
            Write-Error "Failed to initialize cross-platform environment: $($_.Exception.Message)"
            return @{
                Success = $false
                Error = $_.Exception.Message
            }
        }
    }
}

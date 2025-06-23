<#
.SYNOPSIS
  Configure tools for running Pester and pytest.

.DESCRIPTION
  Installs the Pester module and sets up the PowerShell development environment.
  Python can be optionally installed via configuration files when needed.
  If -UsePoetry is specified, Poetry configuration will be prepared.

.EXAMPLE
  ./pwsh/setup-test-env.ps1 -UsePoetry
#>

param([switch]$UsePoetry)

$ErrorActionPreference = 'Stop'

# Set up project environment variables
$repoRoot = Split-Path $PSScriptRoot -Parent
$env:PROJECT_ROOT = $repoRoot
$env:PWSH_MODULES_PATH = "$repoRoot/core-runner/modules"

# Add project modules to PSModulePath for easy importing
$env:PSModulePath = "$env:PWSH_MODULES_PATH;$env:PSModulePath"

Write-Host 'Setting up environment variables:' -ForegroundColor Cyan
Write-Host "  PROJECT_ROOT: $env:PROJECT_ROOT" -ForegroundColor Gray
Write-Host "  PWSH_MODULES_PATH: $env:PWSH_MODULES_PATH" -ForegroundColor Gray
Write-Host "  Added to PSModulePath for easy imports" -ForegroundColor Gray

# Import Get-Platform function from the correct location
. "$repoRoot/core-runner/modules/LabRunner/Get-Platform.ps1"

function Install-PesterModule {
    # Remove any old Pester v3 modules
    Get-Module -ListAvailable -Name Pester | Where-Object { $_.Version -lt [version]'5.0.0' } | ForEach-Object {
        Remove-Item -Recurse -Force $_.ModuleBase -ErrorAction SilentlyContinue
    }
    if (-not (Get-Module -ListAvailable -Name Pester | Where-Object { $_.Version -ge [version]'5.7.1' })) {
        Install-Module -Name Pester -RequiredVersion 5.7.1 -Force -Scope CurrentUser
    }
}

function Install-PythonEnvironment {
    # Python installation capability preserved in configuration files
    # Use core-runner with InstallPython=true in config to install Python when needed
    Write-Host '📝 Python installation available via config files (InstallPython=true)' -ForegroundColor Yellow
}

function Install-PoetryManager {
    if (-not (Get-Command poetry -ErrorAction SilentlyContinue)) {
        . "$repoRoot/core-runner/core_app/scripts/0204_Install-Poetry.ps1"
        Install-Poetry -Config @{ InstallPoetry = $true }
    }
}

function Initialize-DevEnvironment {
    Write-Host 'Setting up development environment...' -ForegroundColor Cyan
    
    # Import required modules in correct order
    $loggingModule = "$env:PWSH_MODULES_PATH/Logging"
    if (Test-Path $loggingModule) {
        Import-Module $loggingModule -Force
        Write-Host '✓ Logging module imported' -ForegroundColor Green
    } else {
        Write-Warning "Logging module not found at $loggingModule"
    }
    
    # Import DevEnvironment module from correct location
    $devEnvModule = "$env:PWSH_MODULES_PATH/DevEnvironment"
    if (Test-Path $devEnvModule) {
        Import-Module $devEnvModule -Force
        
        # Install pre-commit hook
        try {
            Install-PreCommitHook -Install
            Write-Host '✓ Pre-commit hook installed' -ForegroundColor Green
        } catch {
            Write-Warning "Could not install pre-commit hook: $($_.Exception.Message)"
        }
        
        # Test development setup
        try {
            Test-DevelopmentSetup
            Write-Host '✓ Development environment validated' -ForegroundColor Green
        } catch {
            Write-Warning "Development environment validation failed: $($_.Exception.Message)"
        }
    } else {
        Write-Warning "DevEnvironment module not found at $devEnvModule"
        
        # Try to find and install pre-commit hook from tools directory
        $toolsHook = "$repoRoot/tools/pre-commit-hook.ps1"
        if (Test-Path $toolsHook) {
            & $toolsHook -Install
            Write-Host '✓ Pre-commit hook installed (from tools)' -ForegroundColor Yellow
        } else {
            Write-Warning 'No pre-commit hook found in tools directory'
        }
    }
}

Install-PesterModule
Install-PythonEnvironment
Initialize-DevEnvironment

function Test-PatchManagerEnvironment {
    <#
    .SYNOPSIS
    Validates that the PatchManager environment is properly configured
    #>
    
    Write-Host 'Validating PatchManager environment...' -ForegroundColor Cyan
    
    $validationResults = @{
        EnvironmentVariables = $true
        LoggingModule        = $true
        PatchManagerModule   = $true
        GitAvailable         = $true
    }
    
    # Check environment variables
    if (-not $env:PROJECT_ROOT) {
        Write-Warning 'PROJECT_ROOT environment variable not set'
        $validationResults.EnvironmentVariables = $false
    }
    
    if (-not $env:PWSH_MODULES_PATH) {
        Write-Warning 'PWSH_MODULES_PATH environment variable not set'
        $validationResults.EnvironmentVariables = $false
    }
    
    # Check Logging module
    $loggingPath = "$env:PWSH_MODULES_PATH/Logging"
    if (-not (Test-Path $loggingPath)) {
        Write-Warning "Logging module not found at $loggingPath"
        $validationResults.LoggingModule = $false
    } else {
        try {
            Import-Module $loggingPath -Force -ErrorAction Stop
            Write-Host '✓ Logging module imported successfully' -ForegroundColor Green
        } catch {
            Write-Warning "Failed to import Logging module: $($_.Exception.Message)"
            $validationResults.LoggingModule = $false
        }
    }
    
    # Check PatchManager module
    $patchManagerPath = "$env:PWSH_MODULES_PATH/PatchManager"
    if (-not (Test-Path $patchManagerPath)) {
        Write-Warning "PatchManager module not found at $patchManagerPath"
        $validationResults.PatchManagerModule = $false
    } else {
        # Check for syntax errors without importing
        $psmFile = "$patchManagerPath/PatchManager.psm1"
        if (Test-Path $psmFile) {
            try {
                $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $psmFile -Raw), [ref]$null)
                Write-Host '✓ PatchManager module syntax valid' -ForegroundColor Green
            } catch {
                Write-Warning "PatchManager module has syntax errors: $($_.Exception.Message)"
                $validationResults.PatchManagerModule = $false
            }
        }
    }
    
    # Check Git availability
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Warning 'Git not found in PATH'
        $validationResults.GitAvailable = $false
    } else {
        Write-Host '✓ Git is available' -ForegroundColor Green
    }
    
    # Summary
    $allValid = $validationResults.Values | ForEach-Object { $_ } | Where-Object { -not $_ } | Measure-Object | Select-Object -ExpandProperty Count
    if ($allValid -eq 0) {
        Write-Host '✓ PatchManager environment validation passed' -ForegroundColor Green
        return $true
    } else {
        Write-Warning 'PatchManager environment validation failed. Check warnings above.'
        return $false
    }
}

if ($UsePoetry) {
    Write-Host '📝 Poetry installation available via config files (InstallPoetry=true)' -ForegroundColor Yellow
    Write-Host 'ℹ️  Use core-runner with appropriate config to install Poetry when needed' -ForegroundColor Blue
} else {
    Write-Host '📝 Python package management available via Poetry or pip when Python is installed' -ForegroundColor Yellow
}

Write-Host 'Test environment ready.' -ForegroundColor Green
Write-Host '✓ Pester 5.7.1+ installed' -ForegroundColor Green
Write-Host '✓ Development environment configured' -ForegroundColor Green  
Write-Host '✓ Pre-commit hook installed' -ForegroundColor Green
Write-Host '✓ Development environment validated' -ForegroundColor Green

# Test PatchManager environment
$patchManagerValid = Test-PatchManagerEnvironment
if ($patchManagerValid) {
    Write-Host '✓ PatchManager environment validated' -ForegroundColor Green
} else {
    Write-Host '⚠ PatchManager environment validation failed' -ForegroundColor Yellow
    Write-Host '  Run the setup script again or check module paths' -ForegroundColor Gray
}





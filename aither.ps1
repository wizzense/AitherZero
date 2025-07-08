#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Aither CLI - Simplified command-line interface for AitherZero
.DESCRIPTION
    Provides a streamlined CLI experience for common AitherZero operations.
.PARAMETER Command
    The command to execute (init, deploy, test, etc.)
.PARAMETER Arguments
    Additional arguments for the command
.EXAMPLE
    ./aither init
    ./aither deploy -Environment dev
    ./aither test
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('init', 'deploy', 'test', 'setup', 'config', 'status', 'help', 'version')]
    [string]$Command = 'help',

    [Parameter(Position = 1, ValueFromRemainingArguments)]
    [string[]]$Arguments
)

# Ensure we're running in PowerShell 7+
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Host "Aither CLI requires PowerShell 7.0 or later." -ForegroundColor Red
    Write-Host "Please install PowerShell 7 from: https://aka.ms/powershell-release" -ForegroundColor Yellow
    exit 1
}

# Find project root
$scriptPath = $PSScriptRoot
if (-not $scriptPath) {
    $scriptPath = (Get-Location).Path
}

$mainScript = Join-Path $scriptPath "Start-AitherZero.ps1"
if (-not (Test-Path $mainScript)) {
    Write-Error "Cannot find Start-AitherZero.ps1 at: $mainScript"
    exit 1
}

# Execute command
switch ($Command) {
    'init' {
        Write-Host "`n🚀 Initializing AitherZero..." -ForegroundColor Green
        Write-Host ""

        # Check if already initialized
        $configPath = Join-Path $scriptPath "configs" "default-config.json"
        if (Test-Path $configPath) {
            Write-Host "AitherZero is already initialized!" -ForegroundColor Yellow
            $response = Read-Host "Would you like to run setup wizard? (Y/N)"
            if ($response -eq 'Y') {
                & $mainScript -Setup
            }
        } else {
            Write-Host "Running first-time setup..." -ForegroundColor Cyan
            & $mainScript -Setup -InstallationProfile interactive
        }
    }

    'deploy' {
        Write-Host "`n🚀 Starting deployment..." -ForegroundColor Green

        # Parse environment from arguments
        $environment = "dev"
        if ($Arguments -contains "-Environment" -or $Arguments -contains "-env") {
            $envIndex = [array]::IndexOf($Arguments, "-Environment")
            if ($envIndex -eq -1) { $envIndex = [array]::IndexOf($Arguments, "-env") }
            if ($envIndex -ge 0 -and $envIndex + 1 -lt $Arguments.Count) {
                $environment = $Arguments[$envIndex + 1]
            }
        }

        Write-Host "Environment: $environment" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Deployment functionality coming soon!" -ForegroundColor Yellow
        Write-Host "For now, use: $mainScript -Scripts OpenTofuProvider" -ForegroundColor Cyan
    }

    'test' {
        Write-Host "`n🧪 Running tests..." -ForegroundColor Green

        $testScript = Join-Path $scriptPath "tests" "Run-Tests.ps1"
        if (Test-Path $testScript) {
            & $testScript @Arguments
        } else {
            Write-Error "Test runner not found at: $testScript"
        }
    }

    'setup' {
        Write-Host "`n⚙️  Running setup wizard..." -ForegroundColor Green

        $profileType = "interactive"
        if ($Arguments -contains "-Profile") {
            $profileIndex = [array]::IndexOf($Arguments, "-Profile")
            if ($profileIndex -ge 0 -and $profileIndex + 1 -lt $Arguments.Count) {
                $profileType = $Arguments[$profileIndex + 1]
            }
        }

        & $mainScript -Setup -InstallationProfile $profileType
    }

    'config' {
        Write-Host "`n⚙️  Configuration Management" -ForegroundColor Green

        if ($Arguments.Count -eq 0) {
            # Show current configuration
            $configPath = Join-Path $scriptPath "configs" "default-config.json"
            if (Test-Path $configPath) {
                Write-Host "`nCurrent configuration:" -ForegroundColor Cyan
                Get-Content $configPath | ConvertFrom-Json | Format-List
            } else {
                Write-Host "No configuration found. Run 'aither init' first." -ForegroundColor Yellow
            }
        } elseif ($Arguments[0] -eq "edit") {
            # Launch main script for editing
            & $mainScript -NonInteractive
        } else {
            Write-Host "Usage: aither config [edit]" -ForegroundColor Yellow
        }
    }

    'status' {
        Write-Host "`n📊 AitherZero Status" -ForegroundColor Green
        Write-Host "$('=' * 50)" -ForegroundColor Cyan

        # Version
        $versionFile = Join-Path $scriptPath "VERSION"
        if (Test-Path $versionFile) {
            $version = Get-Content $versionFile -Raw -ErrorAction SilentlyContinue
            Write-Host "Version: $version" -ForegroundColor White
        }

        # PowerShell version
        Write-Host "PowerShell: $($PSVersionTable.PSVersion)" -ForegroundColor White

        # Check modules
        Write-Host "`nModules:" -ForegroundColor Yellow
        $modulesPath = Join-Path $scriptPath "aither-core" "modules"
        if (Test-Path $modulesPath) {
            $modules = Get-ChildItem $modulesPath -Directory | Select-Object -ExpandProperty Name
            foreach ($module in $modules) {
                $loaded = Get-Module $module -ErrorAction SilentlyContinue
                if ($loaded) {
                    Write-Host "  ✓ $module (loaded)" -ForegroundColor Green
                } else {
                    Write-Host "  - $module" -ForegroundColor Gray
                }
            }
        } else {
            Write-Host "  Modules directory not found" -ForegroundColor Red
        }

        # Check tools
        Write-Host "`nTools:" -ForegroundColor Yellow
        $tools = @(
            @{Name = 'Git'; Command = 'git'},
            @{Name = 'OpenTofu'; Command = 'tofu'},
            @{Name = 'Terraform'; Command = 'terraform'},
            @{Name = 'Docker'; Command = 'docker'}
        )

        foreach ($tool in $tools) {
            if (Get-Command $tool.Command -ErrorAction SilentlyContinue) {
                Write-Host "  ✓ $($tool.Name)" -ForegroundColor Green
            } else {
                Write-Host "  ✗ $($tool.Name)" -ForegroundColor Red
            }
        }
    }

    'version' {
        $versionFile = Join-Path $scriptPath "VERSION"
        if (Test-Path $versionFile) {
            $version = Get-Content $versionFile -Raw -ErrorAction SilentlyContinue
            Write-Host "AitherZero v$version" -ForegroundColor Green
        } else {
            Write-Host "AitherZero (version unknown)" -ForegroundColor Yellow
        }
    }

    'help' {
        Write-Host "`n🚀 Aither CLI" -ForegroundColor Green
        Write-Host "$('=' * 50)" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Usage: aither <command> [arguments]" -ForegroundColor White
        Write-Host ""
        Write-Host "Commands:" -ForegroundColor Yellow
        Write-Host "  init      Initialize AitherZero for first-time use" -ForegroundColor White
        Write-Host "  deploy    Deploy infrastructure (specify -env <environment>)" -ForegroundColor White
        Write-Host "  test      Run tests (pass arguments to test runner)" -ForegroundColor White
        Write-Host "  setup     Run setup wizard (specify -Profile <profile>)" -ForegroundColor White
        Write-Host "  config    View or edit configuration" -ForegroundColor White
        Write-Host "  status    Show AitherZero status and environment info" -ForegroundColor White
        Write-Host "  version   Show version information" -ForegroundColor White
        Write-Host "  help      Show this help message" -ForegroundColor White
        Write-Host ""
        Write-Host "Examples:" -ForegroundColor Yellow
        Write-Host "  aither init" -ForegroundColor Gray
        Write-Host "  aither deploy -env production" -ForegroundColor Gray
        Write-Host "  aither test -Setup" -ForegroundColor Gray
        Write-Host "  aither setup -Profile developer" -ForegroundColor Gray
        Write-Host "  aither config edit" -ForegroundColor Gray
        Write-Host ""
        Write-Host "For full functionality, use:" -ForegroundColor Cyan
        Write-Host "  $mainScript" -ForegroundColor White
        Write-Host ""
    }

    default {
        Write-Error "Unknown command: $Command"
        Write-Host "Run 'aither help' for usage information." -ForegroundColor Yellow
        exit 1
    }
}

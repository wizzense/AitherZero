#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    AitherZero - Simple Infrastructure Automation with OpenTofu/Terraform
.DESCRIPTION
    A minimal, focused automation framework for infrastructure deployment
.EXAMPLE
    ./Start-AitherZero.ps1
#>

[CmdletBinding()]
param(
    [switch]$Help,
    [switch]$Version
)

# Script configuration
$ErrorActionPreference = 'Stop'
$script:ProjectRoot = $PSScriptRoot

# Simple version info
if ($Version) {
    Write-Host "AitherZero v0.5-minimal" -ForegroundColor Cyan
    exit 0
}

# Help
if ($Help) {
    Get-Help $MyInvocation.MyCommand.Path -Detailed
    exit 0
}

# Banner
function Show-Banner {
    Clear-Host
    Write-Host @"
    _    _ _   _               ______               
   / \  (_) |_| |__   ___ _ _|__  /___ _ __ ___  
  / _ \ | | __| '_ \ / _ \ '__/ // _ \ '__/ _ \ 
 / ___ \| | |_| | | |  __/ | / /|  __/ | | (_) |
/_/   \_\_|\__|_| |_|\___|_|/____\___|_|  \___/ 
                                                 
Simple Infrastructure Automation
"@ -ForegroundColor Cyan
    Write-Host ""
}

# Simple menu
function Show-Menu {
    Write-Host "Main Menu:" -ForegroundColor Yellow
    Write-Host "1. Deploy Infrastructure (OpenTofu)" -ForegroundColor White
    Write-Host "2. Manage Lab VMs" -ForegroundColor White
    Write-Host "3. Configure Settings" -ForegroundColor White
    Write-Host "4. Exit" -ForegroundColor White
    Write-Host ""
}

# Load core modules
function Initialize-Modules {
    Write-Host "Loading modules..." -ForegroundColor Gray
    
    $modules = @(
        'Logging',
        'ConfigurationCore', 
        'SecureCredentials',
        'LabRunner',
        'OpenTofuProvider'
    )
    
    foreach ($module in $modules) {
        $modulePath = Join-Path $script:ProjectRoot "aither-core/modules/$module"
        if (Test-Path $modulePath) {
            try {
                Import-Module $modulePath -Force -Global
                Write-Host "  ✓ $module" -ForegroundColor Green
            }
            catch {
                Write-Host "  ✗ $module - $_" -ForegroundColor Red
            }
        }
    }
    Write-Host ""
}

# Main functions
function Invoke-Infrastructure {
    Write-Host "`nInfrastructure Deployment" -ForegroundColor Cyan
    Write-Host "1. Plan deployment" -ForegroundColor White
    Write-Host "2. Apply deployment" -ForegroundColor White
    Write-Host "3. Destroy infrastructure" -ForegroundColor White
    Write-Host "4. Back to main menu" -ForegroundColor White
    
    $choice = Read-Host "`nSelect option"
    
    switch ($choice) {
        '1' {
            Write-Host "`nPlanning infrastructure..." -ForegroundColor Yellow
            if (Get-Command Invoke-OpenTofuPlan -ErrorAction SilentlyContinue) {
                Invoke-OpenTofuPlan
            }
            else {
                Write-Host "OpenTofu planning not available" -ForegroundColor Red
            }
        }
        '2' {
            Write-Host "`nApplying infrastructure..." -ForegroundColor Yellow
            if (Get-Command Invoke-OpenTofuApply -ErrorAction SilentlyContinue) {
                Invoke-OpenTofuApply
            }
            else {
                Write-Host "OpenTofu apply not available" -ForegroundColor Red
            }
        }
        '3' {
            Write-Host "`nDestroying infrastructure..." -ForegroundColor Yellow
            if (Get-Command Invoke-OpenTofuDestroy -ErrorAction SilentlyContinue) {
                Invoke-OpenTofuDestroy
            }
            else {
                Write-Host "OpenTofu destroy not available" -ForegroundColor Red
            }
        }
        '4' { return }
    }
    
    Read-Host "`nPress Enter to continue"
}

function Invoke-LabManagement {
    Write-Host "`nLab VM Management" -ForegroundColor Cyan
    Write-Host "1. List VMs" -ForegroundColor White
    Write-Host "2. Create VM" -ForegroundColor White
    Write-Host "3. Start/Stop VM" -ForegroundColor White
    Write-Host "4. Back to main menu" -ForegroundColor White
    
    $choice = Read-Host "`nSelect option"
    
    switch ($choice) {
        '1' {
            Write-Host "`nListing VMs..." -ForegroundColor Yellow
            if (Get-Command Get-LabVMs -ErrorAction SilentlyContinue) {
                Get-LabVMs
            }
            else {
                Write-Host "Lab VM listing not available" -ForegroundColor Red
            }
        }
        '2' {
            Write-Host "`nCreating VM..." -ForegroundColor Yellow
            if (Get-Command New-LabVM -ErrorAction SilentlyContinue) {
                $vmName = Read-Host "Enter VM name"
                New-LabVM -Name $vmName
            }
            else {
                Write-Host "Lab VM creation not available" -ForegroundColor Red
            }
        }
        '3' {
            Write-Host "`nManaging VM state..." -ForegroundColor Yellow
            Write-Host "Feature not yet implemented" -ForegroundColor Red
        }
        '4' { return }
    }
    
    Read-Host "`nPress Enter to continue"
}

function Invoke-Configuration {
    Write-Host "`nConfiguration Settings" -ForegroundColor Cyan
    Write-Host "1. View current config" -ForegroundColor White
    Write-Host "2. Edit config" -ForegroundColor White
    Write-Host "3. Reset to defaults" -ForegroundColor White
    Write-Host "4. Back to main menu" -ForegroundColor White
    
    $choice = Read-Host "`nSelect option"
    
    switch ($choice) {
        '1' {
            Write-Host "`nCurrent Configuration:" -ForegroundColor Yellow
            if (Get-Command Get-Configuration -ErrorAction SilentlyContinue) {
                Get-Configuration | Format-List
            }
            else {
                Write-Host "Configuration not available" -ForegroundColor Red
            }
        }
        '2' {
            Write-Host "`nEdit configuration not yet implemented" -ForegroundColor Red
        }
        '3' {
            Write-Host "`nReset configuration not yet implemented" -ForegroundColor Red
        }
        '4' { return }
    }
    
    Read-Host "`nPress Enter to continue"
}

# Main loop
try {
    Show-Banner
    Initialize-Modules
    
    while ($true) {
        Show-Menu
        $choice = Read-Host "Select option"
        
        switch ($choice) {
            '1' { Invoke-Infrastructure }
            '2' { Invoke-LabManagement }
            '3' { Invoke-Configuration }
            '4' { 
                Write-Host "`nGoodbye!" -ForegroundColor Green
                exit 0
            }
            default {
                Write-Host "`nInvalid option. Please try again." -ForegroundColor Red
                Start-Sleep -Seconds 1
            }
        }
    }
}
catch {
    Write-Host "`nError: $_" -ForegroundColor Red
    exit 1
}
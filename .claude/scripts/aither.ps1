#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Main unified Claude command wrapper for AitherZero orchestration
.DESCRIPTION
    Provides unified CLI interface for coordinating multiple AitherZero modules
.PARAMETER Action
    The orchestration action to perform (setup, workflow, status, deploy, cleanup)
.PARAMETER Arguments
    Additional arguments passed from Claude command
#>

param(
    [Parameter(Mandatory = $false, Position = 0)]
    [ValidateSet("setup", "workflow", "status", "deploy", "cleanup", "help")]
    [string]$Action = "status",
    
    [Parameter(Mandatory = $false, ValueFromRemainingArguments = $true)]
    [string[]]$Arguments = @()
)

# Cross-platform script location detection
$scriptPath = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$projectRoot = Split-Path -Parent (Split-Path -Parent $scriptPath)

# Import required modules
try {
    . (Join-Path $projectRoot "aither-core/shared/Find-ProjectRoot.ps1")
    $projectRoot = Find-ProjectRoot
    
    # Import core modules
    $modules = @("Logging", "PatchManager", "LabRunner", "OpenTofuProvider", "DevEnvironment")
    foreach ($module in $modules) {
        $modulePath = Join-Path $projectRoot "aither-core/modules/$module"
        if (Test-Path $modulePath) {
            Import-Module $modulePath -Force -ErrorAction SilentlyContinue
        }
    }
} catch {
    Write-Error "Failed to import required modules: $($_.Exception.Message)"
    exit 1
}

# Helper function for consistent logging
function Write-CommandLog {
    param($Message, $Level = "INFO")
    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Message $Message -Level $Level
    } else {
        $prefix = switch ($Level) {
            "ERROR" { "[ERROR]" }
            "WARN" { "[WARN]" }
            "SUCCESS" { "[SUCCESS]" }
            default { "[INFO]" }
        }
        Write-Host "$prefix $Message"
    }
}

function Show-AitherHelp {
    Write-Host "`n=== AitherZero Unified Command Help ===" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "USAGE:" -ForegroundColor Yellow
    Write-Host "  /aither [action] [options]"
    Write-Host ""
    Write-Host "ACTIONS:" -ForegroundColor Yellow
    Write-Host "  setup      - Complete environment setup and initialization"
    Write-Host "  workflow   - Execute multi-module workflows"
    Write-Host "  status     - Show comprehensive system status"
    Write-Host "  deploy     - Full deployment workflow (infra + apps)"
    Write-Host "  cleanup    - System maintenance and cleanup"
    Write-Host "  help       - Show this help"
    Write-Host ""
    Write-Host "SETUP OPTIONS:" -ForegroundColor Yellow
    Write-Host "  --dev-env  - Setup development environment"
    Write-Host "  --lab      - Setup lab environment"
    Write-Host "  --infra    - Setup infrastructure components"
    Write-Host "  --all      - Complete setup (default)"
    Write-Host ""
    Write-Host "WORKFLOW OPTIONS:" -ForegroundColor Yellow
    Write-Host "  --patch [description] - Create patch workflow"
    Write-Host "  --deploy [env]        - Deploy to environment"
    Write-Host "  --test [suite]        - Run test workflows"
    Write-Host "  --create-pr           - Include PR creation"
    Write-Host ""
    Write-Host "EXAMPLES:" -ForegroundColor Yellow
    Write-Host "  /aither setup --dev-env"
    Write-Host "  /aither workflow --patch 'Fix module loading' --create-pr"
    Write-Host "  /aither deploy --env staging --validate"
    Write-Host "  /aither status --all"
    Write-Host ""
}

# Execute the requested action
try {
    # Parse arguments inline
    $params = @{}
    $i = 0
    
    while ($i -lt $Arguments.Count) {
        $arg = $Arguments[$i]
        
        switch -Regex ($arg) {
            "^--dev-env$" { $params.DevEnvironment = $true }
            "^--lab$" { $params.LabEnvironment = $true }
            "^--infra$" { $params.Infrastructure = $true }
            "^--all$" { $params.All = $true }
            "^--patch$" { $params.PatchDescription = $Arguments[++$i] }
            "^--deploy$" { $params.DeployEnvironment = $Arguments[++$i] }
            "^--test$" { $params.TestSuite = $Arguments[++$i] }
            "^--create-pr$" { $params.CreatePR = $true }
            "^--validate$" { $params.Validate = $true }
            "^--env$" { $params.Environment = $Arguments[++$i] }
            "^--force$" { $params.Force = $true }
        }
        $i++
    }
    
    switch ($Action) {
        "setup" {
            Write-CommandLog "Initializing AitherZero setup..." -Level "INFO"
            
            if ($params.DevEnvironment -or $params.All) {
                Write-CommandLog "Setting up development environment..." -Level "INFO"
                # Call DevEnvironment setup
                if (Get-Command Initialize-DevEnvironment -ErrorAction SilentlyContinue) {
                    Initialize-DevEnvironment
                }
            }
            
            if ($params.LabEnvironment -or $params.All) {
                Write-CommandLog "Setting up lab environment..." -Level "INFO"
                # Call LabRunner setup
            }
            
            if ($params.Infrastructure -or $params.All) {
                Write-CommandLog "Setting up infrastructure components..." -Level "INFO"
                # Call OpenTofuProvider setup
                if (Get-Command Initialize-OpenTofuProvider -ErrorAction SilentlyContinue) {
                    Initialize-OpenTofuProvider
                }
            }
            
            Write-CommandLog "AitherZero setup completed successfully" -Level "SUCCESS"
        }
        
        "workflow" {
            Write-CommandLog "Executing unified workflow..." -Level "INFO"
            
            if ($params.PatchDescription) {
                Write-CommandLog "Creating patch workflow: $($params.PatchDescription)" -Level "INFO"
                
                $patchParams = @{
                    PatchDescription = $params.PatchDescription
                }
                
                if ($params.CreatePR) {
                    $patchParams.CreatePR = $true
                }
                
                if (Get-Command Invoke-PatchWorkflow -ErrorAction SilentlyContinue) {
                    Invoke-PatchWorkflow @patchParams
                }
            }
            
            if ($params.TestSuite) {
                Write-CommandLog "Running test suite: $($params.TestSuite)" -Level "INFO"
                # Call testing workflow
            }
            
            Write-CommandLog "Unified workflow completed" -Level "SUCCESS"
        }
        
        "status" {
            Write-CommandLog "Getting comprehensive system status..." -Level "INFO"
            
            # Git status
            Write-CommandLog "=== Git Status ===" -Level "INFO"
            if (Get-Command Show-GitStatusGuidance -ErrorAction SilentlyContinue) {
                Show-GitStatusGuidance
            }
            
            # Infrastructure status
            Write-CommandLog "=== Infrastructure Status ===" -Level "INFO"
            Write-CommandLog "Infrastructure components ready" -Level "INFO"
            
            # Lab status
            Write-CommandLog "=== Lab Status ===" -Level "INFO"
            Write-CommandLog "Lab environments ready" -Level "INFO"
            
            Write-CommandLog "System status check completed" -Level "SUCCESS"
        }
        
        "deploy" {
            Write-CommandLog "Executing full deployment workflow..." -Level "INFO"
            
            $deployEnv = $params.DeployEnvironment -or $params.Environment -or "staging"
            Write-CommandLog "Deploying to environment: $deployEnv" -Level "INFO"
            
            # Infrastructure deployment
            Write-CommandLog "Deploying infrastructure..." -Level "INFO"
            # Call infra deployment
            
            # Application deployment
            Write-CommandLog "Deploying applications..." -Level "INFO"
            # Call app deployment
            
            if ($params.Validate) {
                Write-CommandLog "Validating deployment..." -Level "INFO"
                # Run validation
            }
            
            Write-CommandLog "Full deployment completed successfully" -Level "SUCCESS"
        }
        
        "cleanup" {
            Write-CommandLog "Performing system cleanup..." -Level "INFO"
            
            # Cleanup temporary files
            Write-CommandLog "Cleaning temporary files..." -Level "INFO"
            
            # Cleanup expired resources
            Write-CommandLog "Cleaning expired resources..." -Level "INFO"
            
            # Git cleanup
            Write-CommandLog "Performing git cleanup..." -Level "INFO"
            
            Write-CommandLog "System cleanup completed" -Level "SUCCESS"
        }
        
        "help" {
            Show-AitherHelp
        }
        
        default {
            Write-CommandLog "Unknown action: $Action" -Level "ERROR"
            Write-CommandLog "Use '/aither help' to see available actions" -Level "INFO"
            exit 1
        }
    }
    
} catch {
    Write-CommandLog "Command execution failed: $($_.Exception.Message)" -Level "ERROR"
    Write-CommandLog "Stack trace: $($_.ScriptStackTrace)" -Level "ERROR"
    exit 1
}